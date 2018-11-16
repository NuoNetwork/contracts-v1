pragma solidity 0.4.19;

import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "zeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "./ILoanFactory.sol";
import "./Loan.sol";
import "./TokenRegistry.sol";

contract LoanFactory is ILoanFactory, Pausable {
    using SafeMath for uint;

    address public ticker;

    function setTokenTicker(address _ticker) external onlyOwner {
        require(_ticker != address(0));
        ticker = _ticker;
    }

    TokenRegistry public registry;

    function setTokenRegistry(TokenRegistry _registry) external onlyOwner {
        require(_registry != address(0));
        registry = _registry;
    }

    uint public maxDebtAmt = 5 ether;
    uint public minCollateralAmtMultiplier = 1;
    uint public maxInstLen = 10;
    uint public minPremiumPerct = 5;
    uint public maxTermPerInst = 10;

    function setMaxDebtAmt(uint _maxDebtAmt) external onlyOwner {
        maxDebtAmt = _maxDebtAmt;
    }

    function setMinCollateralAmtMultiplier(uint _minCollateralAmtMultiplier) external onlyOwner {
        minCollateralAmtMultiplier = _minCollateralAmtMultiplier;
    }

    function setMaxInstLen(uint _maxInstLen) external onlyOwner {
        maxInstLen = _maxInstLen;
    }

    function setMinPremiumPerct(uint _minPremiumPerct) external onlyOwner {
        minPremiumPerct = _minPremiumPerct;
    }

    function setMaxTermPerInst(uint _maxTermPerInst) external onlyOwner {
        maxTermPerInst = _maxTermPerInst;
    }

    event LogLoanCreated(address indexed _borrower, Loan _loanContract);

    function createLoan(
        address _borrower,
        address _owner,
        uint _debtAmt,
        uint _termPerInst,
        uint _instLen,
        uint _premiumPerct,
        uint _collateralAmt,
        address _tokenAddr) external onlyOwner whenNotPaused returns (Loan _loan)
    {
        require(ticker != address(0));
        require(registry != address(0));
        require(registry.isTokenSupported(_tokenAddr));
        
        uint tokenDecimals;
        (,,,tokenDecimals,,) = registry.getTokenMetaData(_tokenAddr);
        // additional validations
        require(_debtAmt <= maxDebtAmt);
        require(_instLen <= maxInstLen);
        require(_termPerInst <= maxTermPerInst);
        require(_premiumPerct >= minPremiumPerct);
        require(_collateralAmt >= minCollateralAmtMultiplier.mul(10**tokenDecimals));
        
        
        _loan = new Loan(_borrower, _owner, ERC20(_tokenAddr), _collateralAmt, ticker, _debtAmt, _termPerInst, _instLen, _premiumPerct);

        LogLoanCreated(_borrower, _loan);
        return _loan;
    }

}