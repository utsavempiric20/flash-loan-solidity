// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "hardhat/console.sol";

interface IAuthentication {
    function getUserLoggedIn(address caller) external view returns (bool);
}

contract Loan {
    error Loan__TransferFailed();

    IAuthentication iAuthentication;

    struct Lender {
        address lenderAddress;
        uint256 lendingAmount;
        uint256 lendingPercentage;
        uint256 remainingAmount;
    }

    struct Borrower {
        address borrowerAddress;
        uint256 borrowingAmount;
    }

    struct CurrentTransaction {
        address lenderAddress;
        uint256 lendingAmount;
        uint256 lendingPercentage;
        address borrowerAddress;
        uint256 borrowingAmount;
    }

    uint8 poolFee = 2;
    uint256 minimumEth = 5;
    mapping(address => Lender) lenderDetails;
    mapping(address => address[]) borrowersOfLenders;
    address[] allLenders;

    mapping(address => Borrower) borrowerDetails;
    mapping(address => address[]) lendersOfBorrowers;
    address[] allBorrowers;

    mapping(address => mapping(address => CurrentTransaction)) currentTransactions;
    mapping(address => mapping(address => CurrentTransaction)) tempTransactions;

    address payable owner;

    modifier onlyOwner() {
        require(owner == msg.sender, "Only Owner can perform this operation.");
        _;
    }

    modifier userMustLoggedIn() {
        require(
            iAuthentication.getUserLoggedIn(msg.sender),
            "User not LoggedIn"
        );
        _;
    }

    modifier onlyLender() {
        require(
            msg.sender == lenderDetails[msg.sender].lenderAddress,
            "Only Lender can perform this opearion."
        );
        _;
    }

    modifier onlyBorrower() {
        require(
            msg.sender == borrowerDetails[msg.sender].borrowerAddress,
            "Only Borrower can perform this operation."
        );
        _;
    }

    constructor() /*address _iAuthentication*/
    {
        owner = payable(msg.sender);
        // iAuthentication = IAuthentication(_iAuthentication);
    }

    function lendingLoan(
        uint256 _lendingAmount,
        uint256 _lendingPercentage // payable
    ) public // userMustLoggedIn
    {
        require(_lendingAmount >= minimumEth, "Lending Amount must be 10 Eth.");
        // require(msg.value >= minimumEth, "You have to lend minimum 10 Eth.");
        // require(
        //     msg.value == (_lendingAmount * 1 ether),
        //     "Amount must be equal to LendingAmount."
        // );
        Lender memory lender = Lender({
            lenderAddress: msg.sender,
            lendingAmount: _lendingAmount,
            lendingPercentage: _lendingPercentage,
            remainingAmount: 0
        });
        lenderDetails[msg.sender] = lender;
        allLenders.push(msg.sender);
        CurrentTransaction memory currentTransaction = CurrentTransaction({
            lenderAddress: msg.sender,
            lendingAmount: _lendingAmount,
            lendingPercentage: _lendingPercentage,
            borrowerAddress: address(0),
            borrowingAmount: 0
        });
        currentTransactions[msg.sender][address(this)] = currentTransaction;
    }

    function borrowingLoan(
        uint256 _borrowingAmount /*userMustLoggedIn*/
    ) public {
        require(
            _borrowingAmount >= minimumEth,
            "Borrowing Amount must be 10 Eth."
        );
        // require(
        //     address(this).balance >= _borrowingAmount,
        //     "Bank has Insufficiant balance."
        // );
        Borrower memory borrower = Borrower({
            borrowerAddress: msg.sender,
            borrowingAmount: _borrowingAmount
        });
        borrowerDetails[msg.sender] = borrower;
        allBorrowers.push(msg.sender);

        uint256 lenderLength = allLenders.length;
        for (uint256 i = 0; i < lenderLength; i++) {
            for (uint256 j = 0; j < lenderLength - i - 1; j++) {
                if (
                    currentTransactions[allLenders[j]][address(this)]
                        .lendingPercentage >=
                    currentTransactions[allLenders[j + 1]][address(this)]
                        .lendingPercentage
                ) {
                    tempTransactions[allLenders[j]][
                        address(this)
                    ] = currentTransactions[allLenders[j]][address(this)];
                    currentTransactions[allLenders[j]][
                        address(this)
                    ] = currentTransactions[allLenders[j + 1]][address(this)];
                    currentTransactions[allLenders[j + 1]][
                        address(this)
                    ] = tempTransactions[allLenders[j]][address(this)];
                }
            }
        }

        // address lenderAddress;
        CurrentTransaction storage currentTransaction;
        uint256 remainingAmount = 0;
        uint256 multipleRemainAmount = _borrowingAmount;
        for (uint256 i = 0; i < allLenders.length; i++) {
            Lender storage lender = lenderDetails[allLenders[i]];
            currentTransaction = currentTransactions[allLenders[i]][
                address(this)
            ];
            currentTransaction.borrowerAddress = msg.sender;
            if (
                currentTransactions[allLenders[i]][address(this)]
                    .lendingAmount >= multipleRemainAmount
            ) {
                remainingAmount =
                    currentTransactions[allLenders[i]][address(this)]
                        .lendingAmount -
                    multipleRemainAmount;

                currentTransaction.borrowingAmount =
                    remainingAmount +
                    currentTransactions[allLenders[i]][address(this)]
                        .lendingAmount;
                lender.remainingAmount = remainingAmount;
                console.log(remainingAmount);
                break;
            } else {
                multipleRemainAmount =
                    multipleRemainAmount -
                    currentTransactions[allLenders[i]][address(this)]
                        .lendingAmount;
                currentTransaction.borrowingAmount = currentTransactions[
                    allLenders[i]
                ][address(this)].lendingAmount;
            }
        }

        // CurrentTransaction storage currentTransaction = currentTransactions[
        //     lenderAddress
        // ][address(this)];
        // currentTransaction.borrowerAddress = msg.sender;
        // currentTransaction.borrowingAmount = _borrowingAmount;

        // borrowersOfLenders[lenderAddress].push(msg.sender);
        // lendersOfBorrowers[msg.sender].push(lenderAddress);

        // (bool success, ) = payable(msg.sender).call{
        //     value: _borrowingAmount * 1 ether
        // }("");
        // if (!success) {
        //     revert Loan__TransferFailed();
        // }
    }

    function getAllLendersNBorrowers(
        bool lenderOrborrower
    ) public view onlyOwner returns (address[] memory) {
        return lenderOrborrower == true ? allLenders : allBorrowers;
    }

    function getLenderDetails() public view onlyLender returns (Lender memory) {
        return lenderDetails[msg.sender];
    }

    function getBorrowerDetails()
        public
        view
        onlyBorrower
        returns (Borrower memory)
    {
        return borrowerDetails[msg.sender];
    }

    function getLendersOfBorrowers() public view returns (address[] memory) {
        return lendersOfBorrowers[msg.sender];
    }

    function getBorrowersOfLenders() public view returns (address[] memory) {
        return borrowersOfLenders[msg.sender];
    }

    function getCurrentTransaction()
        public
        view
        returns (
            address lenderAddress,
            uint256 lendingAmount,
            uint256 lendingPercentage,
            address borrowerAddress,
            uint256 borrowingAmount
        )
    {
        CurrentTransaction memory currentTransaction = currentTransactions[
            msg.sender
        ][address(this)];
        return (
            currentTransaction.lenderAddress,
            currentTransaction.lendingAmount,
            currentTransaction.lendingPercentage,
            currentTransaction.borrowerAddress,
            currentTransaction.borrowingAmount
        );
    }
}
