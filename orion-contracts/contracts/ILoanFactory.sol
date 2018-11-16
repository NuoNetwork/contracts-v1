pragma solidity 0.4.19;

import "./Loan.sol";

interface ILoanFactory {
    function createLoan(
        address _borrower,
        address _owner,
        uint _debtAmt,
        uint _termPerInst,
        uint _instLen,
        uint _premiumPerct,
        uint _collateralAmt,
        address _tokenAddr
        ) external returns (Loan _loan);

    function transferOwnership(address _owner) public; 
}