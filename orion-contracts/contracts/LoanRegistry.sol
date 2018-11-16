pragma solidity 0.4.19; // fix version number

import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "./Loan.sol";
import "./ILoanFactory.sol";

contract LoanRegistry is Pausable {
    Loan[] public loans;
    ILoanFactory public factory;

    function setLoanFactory(ILoanFactory _factory) external onlyOwner {
        require(_factory != address(0));
        factory = _factory;
    }

    event LogLoanCreated(address indexed _borrower, Loan _loanContract);

    function createLoan(
        uint _debtAmt,
        uint _termPerInst,
        uint _instLen,
        uint _premiumPerct,
        uint _collateralAmt,
        address _tokenAddr) external whenNotPaused() 
    {
        require(factory != address(0));

        require(msg.sender != address(0)); // redundant
        address borrower = msg.sender;

        Loan loan = factory.createLoan(borrower, owner, _debtAmt, 
            _termPerInst, _instLen, _premiumPerct, _collateralAmt, _tokenAddr);
        
        loans.push(loan);

        LogLoanCreated(borrower, loan);
    }

    function getLoans() external view returns(Loan[]) {
        return loans;
    }

    function getLoansCountBasedOnState() external view returns(uint[]) {
        uint[] memory lnsCountBasedOnStates = new uint[](10);

        for (uint i = 0; i < 9; i++) {
            lnsCountBasedOnStates[i] = findLoanCountFromState(i);
        }

        lnsCountBasedOnStates[9] = findCallerLoanCount();
        return lnsCountBasedOnStates;
    }

    function findLoanCountFromState(uint _state) public view returns (uint) {
        uint count = 0;
        for (uint i = 0; i < loans.length; i++) {
            Loan loan = Loan(loans[i]);
            uint state = uint(loan.state());

            if ( state == _state) {
                count++;
            }
        }
        return count;
    }

    function findCallerLoanCount() public view returns (uint) {
        address caller = msg.sender;

        uint count = 0;
        for (uint i = 0; i < loans.length; i++) {
            if (Loan(loans[i]).borrower() == caller || Loan(loans[i]).lender() == caller) {
                count++;
            }
        }
        return count;
    }

    function transferFactoryOwnership(address _owner) public onlyOwner {
        require(_owner != address(0));
        factory.transferOwnership(_owner);
    }
}


