pragma solidity 0.4.19;

import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "./ITokenTicker.sol";

contract Loan {
    using SafeMath for uint;

    enum State {New, Unfunded, Funded, InProgress, Repaid, Completed, Defaulted, Cancelled, Disputed}
    
    address public lender;
    address public borrower;
    address public owner;

    uint public debtAmt;
    uint public termPerInst;
    uint public instLen;
    uint public premiumPerct;
    uint public collateralAmt;
    address public ticker;

    function setTicker(address _ticker) external onlyOwner {
        require(_ticker != address(0));
        ticker = _ticker;
    }

    ERC20 public collateralToken;
    State public state;
    mapping (uint => uint) public stateToTimestamp;

    function getAllStateTimestamps() public view returns (uint[]) {
        uint[] memory stateTimestamps = new uint[](9);
        for(uint i = 0; i < 9; i++ ) {
            stateTimestamps[i] = stateToTimestamp[i];
        }
        return stateTimestamps;
    }

    uint[] public instToTimestamp;

    function getInstallmentsPaid() public view returns (uint) {
        return instToTimestamp.length;
    }

    function getInstallmentTimestamps() public view returns (uint[]) {
        return instToTimestamp;
    }

    uint public lastUpdated; 

    mapping (address => uint) public ethAddrAllowedToWithdraw;

    function getEthAllAddrAllowedToWithdraw() public view returns (uint[]) {
        uint[] memory ethAllAddrAllowedToWithdraw = new uint[](2);
        ethAllAddrAllowedToWithdraw[0] = ethAddrAllowedToWithdraw[borrower];
        ethAllAddrAllowedToWithdraw[1] = ethAddrAllowedToWithdraw[lender];
        return ethAllAddrAllowedToWithdraw;
    }

    mapping (address => uint) public tokensAddrAllowedToWithdraw;

    function getTokensAllAddrAllowedToWithdraw() public view returns (uint[]) {
        uint[] memory tokensAllAddrAllowedToWithdraw = new uint[](2);
        tokensAllAddrAllowedToWithdraw[0] = tokensAddrAllowedToWithdraw[borrower];
        tokensAllAddrAllowedToWithdraw[1] = tokensAddrAllowedToWithdraw[lender];
        return tokensAllAddrAllowedToWithdraw;
    }
    
    event LogDepositCollateral(address _borrower, uint _tokensDeposited, State _newState);
    event LogFundWithEther(address _lender, uint _amtFunded, State _newState);
    event LogWithdrawDebtAmt(address _borrower, uint _amtFunded, State _newState);
    event LogDepositInstallment(address _borrower, uint _amtForLender, uint _amtForOwner, uint _tokensForBorrower);
    event LogWithdrawPayment(address _address, uint _amtWithdrawn);
    event LogWithdrawCollateral(address _borrower, uint _tokensWithdrawn);
    event LogWithdrawCollateralIfNotFunded(address _borrower, uint _tokensWithdrawn, State _newState);
    event LogDefault(address _caller, uint _tokensForLender, string _reason);
    event LogCollateralThresholdBreach(uint _amtPrincipalLeft, uint _tokensLeft, uint _relTokenAmt, uint _tokenValueInEth, uint _tokenValueTimestamp);

    event LogDisputedEthTransfer(address _to, uint _value);
    event LogDisputedTokenTransfer(address _to, uint _value);
    event LogDisputedStateChange(State _oldState, State _newState);

    function Loan(
        address _borrower,
        address _owner,
        ERC20 _collateralToken,
        uint _collateralAmt,
        address _ticker, 
        uint _debtAmt,
        uint _termPerInst,
        uint _instLen,
        uint _premiumPerct) public 
    {   
        require(_borrower != address(0));
        require(_owner != address(0));
        require(_collateralToken != address(0));
        require(_ticker != address(0));
        require(_debtAmt > 0);
        require(_termPerInst > 0);
        require(_premiumPerct > 0);
        require(_instLen > 0);

        borrower = _borrower;
        owner = _owner;

        debtAmt = _debtAmt;
        termPerInst = _termPerInst * 1 days; 
        instLen = _instLen;
        premiumPerct = _premiumPerct;
        
        collateralToken = _collateralToken;

        ticker = _ticker;
        collateralAmt = _collateralAmt;
        require(_isCollateralAmtValid(_collateralAmt, _debtAmt, 2));
        state = State.New;
        _putTimestampForState(state);
        lastUpdated = now;
    }

    function getBasicDetails() 
    external view returns(
        address _borrower,
        address _lender,
        address _owner,
        address _collateralToken,
        uint _debtAmt,
        uint _collateralAmt,
        uint _termPerInst,
        uint _premiumPerct,
        State _state,
        uint _instPaid,
        uint _instLen,
        uint _ethWithContract,
        uint _tokensWithContract,
        uint _lastUpdated
        ){
        return (borrower,
        lender,
        owner,
        collateralToken,
        debtAmt,
        collateralAmt,
        termPerInst,
        premiumPerct,
        state,
        getInstallmentsPaid(),
        instLen,
        this.balance,
        collateralToken.balanceOf(this),
        lastUpdated
        );
    }

    function getAdditionalDetails() 
    external view returns(
        uint[] _calcInsts,
        uint[] _calcColTrans,
        uint[] _ethAllAddrAllowedToWithdraw,
        uint[] _tokensAllAddrAllowedToWithdraw,
        uint[] _stateTimestamps,
        uint[] _instTimestamps
        ){
        return (
        getCalculatedInstallments(),
        getCalculatedCollateralTransfers(),
        getEthAllAddrAllowedToWithdraw(),
        getTokensAllAddrAllowedToWithdraw(),
        getAllStateTimestamps(),
        getInstallmentTimestamps()
        );
    }
    
    modifier onlyLender() {
        require(msg.sender != address(0)); 
        require(msg.sender == lender);
        _;
    }

    modifier onlyBorrower() {
        require(msg.sender == borrower);
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier inState(State _state) {
        require(state == _state);
        _;
    }

    function depositCollateralForBorrower() external onlyBorrower inState(State.New) {
        require(collateralToken.balanceOf(borrower) >= collateralAmt);
        require(collateralToken.allowance(borrower, this) >= collateralAmt);
        require(collateralToken.transferFrom(borrower, this, collateralAmt));

        state = State.Unfunded;
        _putTimestampForState(state);
        lastUpdated = now;

        LogDepositCollateral(borrower, collateralAmt, state);
    }

    function withdrawCollateralIfNotFundedForBorrower() external onlyBorrower inState(State.Unfunded) {
        uint tokensWithContract = collateralToken.balanceOf(this);
        require(tokensWithContract > 0);

        state = State.Cancelled;
        _putTimestampForState(state);
        lastUpdated = now;

        require(collateralToken.transfer(borrower, tokensWithContract));

        LogWithdrawCollateralIfNotFunded(borrower, tokensWithContract, state);
    } 

    function fundWithEtherForLender() external payable inState(State.Unfunded) {
        require(msg.sender != address(0));
        require(msg.sender != borrower);
        require(msg.value >= debtAmt);
        require(lender == address(0));
        require(_doIsCollateralAmtValid());
        
        lender = msg.sender;

        state = State.Funded;
        _putTimestampForState(state);
        lastUpdated = now;

        _putEthAllowedForAddress(borrower, debtAmt);
        
        LogFundWithEther(lender, msg.value, state);
    }

    function withdrawDebtAmtForBorrower() external onlyBorrower inState(State.Funded){
        require(this.balance >= debtAmt); 
        
        state = State.InProgress;
        _putTimestampForState(state);
        lastUpdated = now;

        uint ethAmtAllowed = _getEthAllowedForAddress(borrower);
        _putEthAllowedForAddress(borrower, 0);
        borrower.transfer(ethAmtAllowed);

        LogWithdrawDebtAmt(borrower, ethAmtAllowed, state);
    }

    function depositInstallmentForBorrower() external payable onlyBorrower inState(State.InProgress){
        uint instPaid = getInstallmentsPaid();
        uint inst = _calculateInstallment(instPaid.add(1));
        require(msg.value >= inst);
        require(instPaid < instLen);

        uint ownerCut = _calculateOwnersCut(inst);
        uint lenderCut = inst.sub(ownerCut);
        uint tokensReleased = _calulateTokenReleaseAmt(instPaid.add(1));
        _increaseInstPaid();

        _putEthAllowedForAddress(lender, _getEthAllowedForAddress(lender).add(lenderCut));
        _putEthAllowedForAddress(owner, _getEthAllowedForAddress(owner).add(ownerCut));
        _putTokensAllowedForAddress(borrower, _getTokensAllowedForAddress(borrower).add(tokensReleased));
            
        lastUpdated = now;

        LogDepositInstallment(borrower, lenderCut, ownerCut, tokensReleased);
    } 

    function withdrawPaymentForLender() external onlyLender {
        require(state == State.InProgress || state == State.Repaid || state == State.Defaulted);
        require(_getEthAllowedForAddress(lender) != 0);
        uint ethToTransfer = _getEthAllowedForAddress(lender);
        _putEthAllowedForAddress(lender, 0);
        lender.transfer(ethToTransfer);

        lastUpdated = now;

        LogWithdrawPayment(lender, ethToTransfer);
    }

    function withdrawPaymentForOwner() external onlyOwner {
        require(state == State.InProgress || state == State.Repaid || state == State.Defaulted || state == State.Completed);
        uint ethToTransfer = _getEthAllowedForAddress(owner);
        _putEthAllowedForAddress(owner, 0);
        owner.transfer(ethToTransfer);

        lastUpdated = now;

        LogWithdrawPayment(owner, ethToTransfer);
    }

    function withdrawCollateralForBorrower() external onlyBorrower {
        require(state == State.InProgress || state == State.Repaid || state == State.Defaulted);
        require(_getTokensAllowedForAddress(borrower) != 0);
        uint tokensToTransfer = _getTokensAllowedForAddress(borrower);
        _putTokensAllowedForAddress(borrower, 0);
        require(collateralToken.transfer(borrower, tokensToTransfer));

        lastUpdated = now;

        LogWithdrawCollateral(borrower, tokensToTransfer);
    }

    function withdrawCollateralForLender() external onlyLender inState(State.Defaulted) {
        require(_getTokensAllowedForAddress(lender) != 0);
        uint tokensToTransfer = _getTokensAllowedForAddress(lender);
        _putTokensAllowedForAddress(lender, 0);
        require(collateralToken.transfer(lender, tokensToTransfer));

        lastUpdated = now;

        LogWithdrawCollateral(lender, tokensToTransfer);
    }

    function withdrawDebtAmtForBorrowerInDefault() external onlyBorrower inState(State.Defaulted){
        require(_getEthAllowedForAddress(borrower) != 0);
        uint ethAmtAllowed = _getEthAllowedForAddress(borrower);
        _putEthAllowedForAddress(borrower, 0);
        borrower.transfer(ethAmtAllowed);

        LogWithdrawDebtAmt(borrower, ethAmtAllowed, state);
        lastUpdated = now;
    }

    function raiseDispute() external onlyOwner {
        State oldState = state;
        state = State.Disputed;

        _putTimestampForState(state);
        lastUpdated = now;

        LogDisputedStateChange(oldState, state);
    }

    function transferEth(address _to, uint _value) external onlyOwner inState(State.Disputed) {
        require(_to != address(0));
        _to.transfer(_value);
        lastUpdated = now;
        LogDisputedEthTransfer(_to, _value);
    }
    
    function transferTokens(address _to, uint _value) external onlyOwner inState(State.Disputed) {
        require(_to != address(0));
        require(collateralToken.transfer(_to, _value));
        lastUpdated = now;
        LogDisputedTokenTransfer(_to, _value);
    }
    
    function process() external {
        require(msg.sender != address(0));
        address caller = msg.sender;
        uint tokensLeft = 0; // declared here to void scoping issues with solidity
        uint relTokenAmt = 0;
        uint tokenValueInEth = 0;
        uint tokenValueTimestamp = 0;
        uint amtPrincipalLeft = 0;

        if (state == State.Funded || state == State.InProgress) {
            if (_isRepaid()) {
                _makeStateRepaid();
            } else if (_isOverdue()) {
                tokensLeft = _processRecovery();
                LogDefault(caller, tokensLeft, "OVERDUE");

            } else if (_isTokenValueThresholdBreached()){
                (amtPrincipalLeft, tokensLeft, relTokenAmt, tokenValueInEth, tokenValueTimestamp) = _fetchDetailsForTokenValueThresholdBreachCheck();
                LogCollateralThresholdBreach(amtPrincipalLeft, tokensLeft, relTokenAmt, tokenValueInEth, tokenValueTimestamp);
                
                tokensLeft = _processRecovery();
                LogDefault(caller, tokensLeft, "THRESHOLD_BREACH");

            }
        } else if (state == State.Repaid){
            if ((_getEthAllowedForAddress(lender) == 0 ) && (_getTokensAllowedForAddress(borrower) == 0)) {
                _makeStateCompleted();
            }
        }
        
        lastUpdated = now;
    } 

    function _processRecovery() private returns (uint){
        _makeStateDefault();
        uint tokensLeft = _getTokensLeftToTransfer();
        _putTokensAllowedForAddress(lender, _getTokensAllowedForAddress(lender).add(tokensLeft));
        return tokensLeft;
    }

    function _makeStateDefault() private {
        state = State.Defaulted;
        _putTimestampForState(state);
    }
    
    function _getTokensLeftToTransfer() private view returns (uint){
        uint instPaid = getInstallmentsPaid();
        uint tokensAlreadyTransferred = 0;

        for (uint i = 1; i <= instPaid; i++) {
            tokensAlreadyTransferred = tokensAlreadyTransferred.add(_calulateTokenReleaseAmt(i));
        }

        return collateralAmt.sub(tokensAlreadyTransferred);
    }

    function _isOverdue() private view returns (bool){
        return now >= _getNextInstallmentDueDate();
    }
    
    // calculating installments from date funded
    function _getNextInstallmentDueDate() private view returns (uint){
        uint instPaid = getInstallmentsPaid();
        if (instPaid == instLen) {
            return now.add(1);
        } else {
            return _getTimestampForState(State.Funded).add(termPerInst.mul(instPaid.add(1)));
        }
    }

    function _doIsCollateralAmtValid() private view returns (bool) {
        return _isCollateralAmtValid(collateralAmt, debtAmt, 4);
    }

    function _isCollateralAmtValid(uint _collateralAmt, uint _debtAmt, uint _partDivisor) private view returns (bool) {
        uint tokenValueInEth;
        uint tokenValueTimestamp;
        uint relTokenAmt;
        (relTokenAmt, tokenValueInEth, tokenValueTimestamp) = _getLatestPriceForToken();
        uint totalTokenValueInEth = (_collateralAmt.mul(tokenValueInEth)).div(relTokenAmt);
        uint requiredTotalTokenValueInEth = _debtAmt.add(_debtAmt.div(_partDivisor)); // 1.5x
        return requiredTotalTokenValueInEth <= totalTokenValueInEth;
    }

    function _isTokenValueThresholdBreached() private view returns (bool) {
        bool isBreached = false; // making not breached as default
        uint amtPrincipalLeft;
        uint tokensLeft;
        uint tokenValueInEth;
        uint relTokenAmt;

        (amtPrincipalLeft, tokensLeft, relTokenAmt, tokenValueInEth,) = _fetchDetailsForTokenValueThresholdBreachCheck();

        uint totalTokenValueInEth = (tokenValueInEth.mul(tokensLeft)).div(relTokenAmt);

        if (totalTokenValueInEth <= amtPrincipalLeft) {
            isBreached = true;
        }
        return isBreached;
    }

    function _fetchDetailsForTokenValueThresholdBreachCheck() private view returns (uint, uint, uint, uint, uint) {
        uint tokenValueInEth;
        uint tokenValueTimestamp;
        uint relTokenAmt;
        (relTokenAmt, tokenValueInEth, tokenValueTimestamp) = _getLatestPriceForToken();
        uint tokensLeft = _getTokensLeftToTransfer();
        uint amtPrincipalLeft = _getAmtOfPrincipalLeftToPay();
        return (amtPrincipalLeft, tokensLeft, relTokenAmt, tokenValueInEth, tokenValueTimestamp);
    }
    
    function _getAmtOfPrincipalLeftToPay() private view returns (uint){
        uint instPaid = getInstallmentsPaid();
        uint amtPrincipalTransferred = 0;

        for (uint i = 1; i <= instPaid; i++) {
            amtPrincipalTransferred = amtPrincipalTransferred.add(_calculateInstallmentWithoutPremium(i));
        }

        return debtAmt.sub(amtPrincipalTransferred);
    }

    function _getLatestPriceForToken() private view returns (uint _relTokenAmt, uint _tokenValueInEth, uint _tokenValueTimestamp){
        return ITokenTicker(ticker).getLatestPriceAndTimestampForToken(collateralToken);
    }

    function _isRepaid() private view returns (bool){
        uint instPaid = getInstallmentsPaid();
        return instLen == instPaid;
    }

    function _makeStateRepaid() private {
        state = State.Repaid;
        _putTimestampForState(state);
    }

    function _makeStateCompleted() private {
        state = State.Completed;
        _putTimestampForState(state);
    }

    function getCalculatedInstallments() public view returns (uint[]) {
        uint[] memory insts = new uint[](instLen);
        for(uint i = 0; i < instLen; i++ ) {
            insts[i] = _calculateInstallment(i.add(1));
        }
        return insts;
    }

    function _calculateInstallment(uint _instIndex) private view returns (uint) {
        require(_instIndex <= instLen);
        uint totalAmt = _calculateTotalAmtToBePaid();
        uint installAmt = totalAmt.div(instLen);
        uint installAmtRemainder = totalAmt % instLen;
        if ((installAmtRemainder != 0) && (_instIndex == 1)) {
            installAmt = installAmt.add(installAmtRemainder);
        }
        return installAmt;
    }

    function _calculateTotalAmtToBePaid() private view returns (uint) {
        uint premiumAmt = premiumPerct.mul(debtAmt).div(100);
        uint totalAmt = premiumAmt.add(debtAmt);
        return totalAmt;
    }

    function _calculateInstallmentWithoutPremium(uint _instIndex) private view returns (uint) {
        require(_instIndex <= instLen);
        uint installAmt = debtAmt.div(instLen);
        uint installAmtRemainder = debtAmt % instLen;
        if ((installAmtRemainder != 0) && (_instIndex == 1)) {
            installAmt = installAmt.add(installAmtRemainder);
        }
        return installAmt;
    }

    function getCalculatedCollateralTransfers() public view returns (uint[]) {
        uint[] memory insts = new uint[](instLen);
        for(uint i = 0; i < instLen; i++ ) {
            insts[i] = _calulateTokenReleaseAmt(i.add(1));
        }
        return insts;
    }

    function _calulateTokenReleaseAmt(uint _instIndex) private view returns (uint) {
        require(_instIndex <= instLen); 
        uint tokenRelease = collateralAmt.div(instLen);
        uint tokenReleaseRemainder = collateralAmt % instLen;
        if ((tokenReleaseRemainder != 0) && (_instIndex == instLen)) {
            tokenRelease = tokenRelease.add(tokenReleaseRemainder);
        }
        return tokenRelease;
    }

    // fixing 1%
    // TODO: make it variable
    function _calculateOwnersCut(uint _amt) private pure returns (uint) {
        return _amt.div(100);
    }

    function _putTimestampForState(State _state) private {
        stateToTimestamp[uint(_state)] = now;
    }

    function _getTimestampForState(State _state) private view returns (uint) {
        return stateToTimestamp[uint(_state)];
    }

    function _increaseInstPaid() private {
        instToTimestamp.push(now);
    }

    function _getTimestampForInst(uint _instIndex) private view returns (uint) {
        return instToTimestamp[_instIndex];
    }

    function _putEthAllowedForAddress(address _address, uint _value) private {
        ethAddrAllowedToWithdraw[_address] = _value;
    }

    function _getEthAllowedForAddress(address _address) private view returns(uint){
        return ethAddrAllowedToWithdraw[_address];
    }

    function _putTokensAllowedForAddress(address _address, uint _value) private {
        tokensAddrAllowedToWithdraw[_address] = _value;
    }

    function _getTokensAllowedForAddress(address _address) private view returns(uint){
        return tokensAddrAllowedToWithdraw[_address];
    }

}