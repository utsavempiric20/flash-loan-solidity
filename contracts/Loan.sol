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
        uint256 totalPaidAmount;
    }

    struct CurrentTransaction {
        address poolAddress;
        address lenderAddress;
        uint256 lendingAmount;
        uint256 lendingPercentage;
        address borrowerAddress;
        uint256 borrowingAmount;
    }

    uint256 poolFee = 2;
    uint256 minimumEth = 5;
    uint256 totalContractCommision;
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
        uint256 _lendingPercentage
    ) public payable // userMustLoggedIn
    {
        require(
            _lendingAmount >= minimumEth,
            "Lending Amount must be minimum Eth."
        );
        require(msg.value >= minimumEth, "You have to lend minimum Eth.");
        require(
            msg.value == _lendingAmount,
            "Amount must be equal to LendingAmount."
        );
        Lender memory lender = Lender({
            lenderAddress: msg.sender,
            lendingAmount: msg.value,
            lendingPercentage: _lendingPercentage,
            remainingAmount: msg.value
        });
        lenderDetails[msg.sender] = lender;
        allLenders.push(msg.sender);
        // CurrentTransaction memory currentTransaction = CurrentTransaction({
        //     lenderAddress: msg.sender,
        //     lendingAmount: _lendingAmount,
        //     lendingPercentage: _lendingPercentage,
        //     borrowerAddress: address(0),
        //     borrowingAmount: 0
        // });
        // currentTransactions[msg.sender][address(this)] = currentTransaction;
    }

    function borrowingLoan(
        uint256 _borrowingAmount /*userMustLoggedIn*/
    ) public payable {
        require(
            _borrowingAmount >= minimumEth,
            "Borrowing Amount must be minimum Eth."
        );
        require(
            address(this).balance >= _borrowingAmount,
            "Bank has Insufficiant balance."
        );

        uint256 lenderLength = allLenders.length;
        for (uint256 i = 0; i < lenderLength; i++) {
            for (uint256 j = i + 1; j < lenderLength; j++) {
                if (
                    lenderDetails[allLenders[i]].lendingPercentage >=
                    lenderDetails[allLenders[j]].lendingPercentage
                ) {
                    address temp = allLenders[i];
                    allLenders[i] = allLenders[j];
                    allLenders[j] = temp;
                }
            }
        }

        uint256 remainingAmount = 0;
        uint256 multipleRemainAmount = _borrowingAmount;
        uint256 totalAmountValue;
        uint256 payLoanToLender;

        // uint256 calculateContractCommission;

        for (uint256 i = 0; i < allLenders.length; i++) {
            Lender storage lender = lenderDetails[allLenders[i]];
            if (lender.remainingAmount >= multipleRemainAmount) {
                remainingAmount = lender.remainingAmount - multipleRemainAmount;
                lender.remainingAmount = remainingAmount;
                CurrentTransaction
                    memory currentTransaction = CurrentTransaction({
                        poolAddress: address(this),
                        lenderAddress: lender.lenderAddress,
                        lendingAmount: multipleRemainAmount,
                        lendingPercentage: lender.lendingPercentage,
                        borrowerAddress: msg.sender,
                        borrowingAmount: multipleRemainAmount
                    });
                currentTransactions[allLenders[i]][
                    msg.sender
                ] = currentTransaction;

                payLoanToLender =
                    (currentTransaction.lendingAmount * 10 ** 18) +
                    ((currentTransaction.lendingAmount *
                        (currentTransaction.lendingPercentage * 10 ** 18)) /
                        100);

                // calculateContractCommission = (payLoanToLender * poolFee) / 100;
                // totalContractCommision += calculateContractCommission;
                // payLoanToLender -= calculateContractCommission;
                totalAmountValue += payLoanToLender;

                borrowersOfLenders[lender.lenderAddress].push(msg.sender);
                lendersOfBorrowers[msg.sender].push(lender.lenderAddress);
                remainingAmount = 0;
                if (remainingAmount == 0) {
                    break;
                }
            } else {
                multipleRemainAmount =
                    multipleRemainAmount -
                    lender.remainingAmount;
                CurrentTransaction
                    memory currentTransaction = CurrentTransaction({
                        poolAddress: address(this),
                        lenderAddress: lender.lenderAddress,
                        lendingAmount: lender.lendingAmount,
                        lendingPercentage: lender.lendingPercentage,
                        borrowerAddress: msg.sender,
                        borrowingAmount: lender.lendingAmount
                    });
                currentTransactions[allLenders[i]][
                    msg.sender
                ] = currentTransaction;

                payLoanToLender =
                    (currentTransaction.lendingAmount * 10 ** 18) +
                    ((currentTransaction.lendingAmount *
                        (currentTransaction.lendingPercentage * 10 ** 18)) /
                        100);

                // calculateContractCommission = (payLoanToLender * poolFee) / 100;
                // totalContractCommision += calculateContractCommission;
                // payLoanToLender -= calculateContractCommission;
                totalAmountValue += payLoanToLender;

                borrowersOfLenders[lender.lenderAddress].push(msg.sender);
                lendersOfBorrowers[msg.sender].push(lender.lenderAddress);
                lender.remainingAmount = 0;
            }
        }

        Borrower memory borrower = Borrower({
            borrowerAddress: msg.sender,
            borrowingAmount: _borrowingAmount,
            totalPaidAmount: totalAmountValue
        });
        borrowerDetails[msg.sender] = borrower;
        allBorrowers.push(msg.sender);

        (bool success, ) = payable(msg.sender).call{value: _borrowingAmount}(
            ""
        );
        if (!success) {
            revert Loan__TransferFailed();
        }
    }

    function calculateEther() public view {
        uint256 payLoanToLender;
        payLoanToLender = (10 * 10 ** 18) + ((10 * (10 * 10 ** 18)) / 100);
        console.log("payLoanToLender : ", payLoanToLender);

        uint256 payLoanToLender2;
        payLoanToLender2 = (20 * 10 ** 18) + ((20 * (3 * 10 ** 18)) / 100);
        console.log("payLoanToLender2 : ", payLoanToLender2);

        uint256 contractInterest1 = (payLoanToLender * poolFee) / 100;
        console.log("contractInterest : ", contractInterest1);

        uint256 contractInterest2 = (payLoanToLender2 * poolFee) / 100;
        console.log("contractInterest : ", contractInterest2);

        uint256 calculateContractCommision = contractInterest1 +
            contractInterest2;
        console.log(
            "calculateContractCommision : ",
            calculateContractCommision
        );

        console.log(payLoanToLender + payLoanToLender2);
    }

    function borrowerPayLoan()
        public
        payable
        /* userMustLoggedIn*/
        onlyBorrower
    {
        require(
            msg.value >=
                (borrowerDetails[msg.sender].totalPaidAmount / 10 ** 18),
            "Pay atleast Your Borrowing Amount"
        );
        uint256 borrowerLoanAmount = msg.value;
        uint256 payLoanToLender;

        uint256 lenderLength = allLenders.length;
        for (uint256 i = 0; i < lenderLength; i++) {
            CurrentTransaction storage currentTransaction = currentTransactions[
                allLenders[i]
            ][msg.sender];

            payLoanToLender = currentTransaction.lendingAmount;
            if (payLoanToLender <= borrowerLoanAmount) {
                borrowerLoanAmount -= payLoanToLender;
                lenderDetails[allLenders[i]].remainingAmount += payLoanToLender;
                (bool success, ) = payable(allLenders[i]).call{
                    value: payLoanToLender
                }("");
                if (!success) {
                    revert Loan__TransferFailed();
                }
            }
        }

        // (bool successFee, ) = payable(address(this)).call{
        //     value: totalContractCommision / 10**17
        // }("");
        // if (!successFee) {
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

    function getCurrentTransaction(
        address lender,
        address borrower
    )
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
            lender
        ][borrower];
        return (
            currentTransaction.lenderAddress,
            currentTransaction.lendingAmount,
            currentTransaction.lendingPercentage,
            currentTransaction.borrowerAddress,
            currentTransaction.borrowingAmount
        );
    }
}
