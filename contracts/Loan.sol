// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IAuthentication {
    function getUserLoggedIn(address caller) external view returns (bool);
}

contract Loan {
    error Loan__TransferFailed();

    IAuthentication iAuthentication;

    struct Lender {
        address lenderAddress;
        address borrowerAddress;
        uint256 lendingAmount;
        uint256 lendingPercentage;
        uint256 lendingTimeDuration;
    }

    struct Borrower {
        address lenderAddress;
        address borrowerAddress;
        uint256 borrowingAmount;
        uint256 borrowingPercentage;
        uint256 borrowingTimeDuration;
    }

    struct CurrentTransaction {
        address lenderAddress;
        uint256 lendingAmount;
        uint256 lendingPercentage;
        address borrowerAddress;
        uint256 borrowingAmount;
        uint256 borrowingPercentage;
    }

    uint8 poolFee = 2;
    uint256 minimumEth = 10;
    mapping(address => Lender) lenderDetails;
    mapping(address => address[]) borrowersOfLenders;
    address[] allLenders;

    mapping(address => Borrower) borrowerDetails;
    mapping(address => address[]) lendersOfBorrowers;
    address[] allBorrowers;

    mapping(address => mapping(address => CurrentTransaction)) currentTransactions;

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

    constructor(address _iAuthentication) {
        owner = payable(msg.sender);
        iAuthentication = IAuthentication(_iAuthentication);
    }

    function lendingLoan(
        uint256 _lendingAmount,
        uint256 _lendingPercentage,
        uint256 _lendingTimeDuration
    ) public payable userMustLoggedIn {
        require(_lendingAmount >= minimumEth, "Lending Amount must be 10 Eth.");
        require(msg.value >= minimumEth, "You have to lend minimum 10 Eth.");
        require(
            msg.value == (_lendingAmount * 1 ether),
            "Amount must be equal to LendingAmount."
        );
        Lender memory lender = Lender({
            lenderAddress: msg.sender,
            borrowerAddress: address(0),
            lendingAmount: _lendingAmount,
            lendingPercentage: _lendingPercentage,
            lendingTimeDuration: _lendingTimeDuration
        });
        lenderDetails[msg.sender] = lender;
        allLenders.push(msg.sender);
        CurrentTransaction memory currentTransaction = CurrentTransaction({
            lenderAddress: msg.sender,
            lendingAmount: _lendingAmount,
            lendingPercentage: _lendingPercentage,
            borrowerAddress: address(0),
            borrowingAmount: 0,
            borrowingPercentage: 0
        });
        currentTransactions[msg.sender][address(this)] = currentTransaction;
    }

    function borrowingLoan(
        uint256 _borrowingAmount,
        uint256 _borrowingPercentage,
        uint256 _borrowingTimeDuration
    ) public payable userMustLoggedIn {
        require(
            _borrowingAmount >= minimumEth,
            "Borrowing Amount must be 10 Eth."
        );
        require(
            address(this).balance >= _borrowingAmount,
            "Bank has Insufficiant balance."
        );
        Borrower memory borrower = Borrower({
            borrowerAddress: msg.sender,
            lenderAddress: address(0),
            borrowingAmount: _borrowingAmount,
            borrowingPercentage: _borrowingPercentage,
            borrowingTimeDuration: _borrowingTimeDuration
        });
        borrowerDetails[msg.sender] = borrower;
        allBorrowers.push(msg.sender);
        CurrentTransaction storage currentTransaction = currentTransactions[
            msg.sender
        ][address(this)];
        currentTransaction.borrowerAddress = msg.sender;
        currentTransaction.borrowingAmount = _borrowingAmount;
        currentTransaction.borrowingPercentage = _borrowingPercentage;

        borrowersOfLenders[currentTransaction.lenderAddress].push(msg.sender);
        lendersOfBorrowers[msg.sender].push(currentTransaction.lenderAddress);

        (bool success, ) = payable(msg.sender).call{
            value: _borrowingAmount * 1 ether
        }("");
        if (!success) {
            revert Loan__TransferFailed();
        }
    }

    // function borrowrPayLoan() public userMustLoggedIn{
    //     require(msg.sender == borrowerDetails[msg.sender].borrowerAddress,"Invalid Borrower.");

    // }

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

    function getCurrentTransaction()
        public
        view
        returns (
            address lenderAddress,
            uint256 lendingAmount,
            uint256 lendingPercentage,
            address borrowerAddress,
            uint256 borrowingAmount,
            uint256 borrowingPercentage
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
            currentTransaction.borrowingAmount,
            currentTransaction.borrowingPercentage
        );
    }
}
