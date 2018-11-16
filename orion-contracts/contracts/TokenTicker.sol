pragma solidity 0.4.19;

import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "./ITokenTicker.sol";

contract TokenTicker is Ownable, ITokenTicker {

    event LogPriceUpdated(address indexed _tokenAddr, uint _oldRelTokenAmt, uint _oldValueInEth, uint _newRelTokenAmt , uint _newValueInEth);

    struct Price {
        uint timestamp;
        uint relTokenAmt;
        uint valueInEth;  
    }
    
    mapping (address => Price) public tokenAddrToPrice;

    function updatePriceForToken(address _tokenAddr, uint _relTokenAmt, uint _valueInEth) public onlyOwner {
        require(_tokenAddr != address(0));
        require(_valueInEth != 0);
        require(_relTokenAmt != 0);
        uint oldValueInEth = tokenAddrToPrice[_tokenAddr].valueInEth;
        uint oldRelTokenAmt = tokenAddrToPrice[_tokenAddr].relTokenAmt;

        tokenAddrToPrice[_tokenAddr] = Price(now, _relTokenAmt, _valueInEth);

        LogPriceUpdated(_tokenAddr, oldRelTokenAmt, oldValueInEth, _relTokenAmt, _valueInEth);
    }

    function batchUpdatePriceForTokens(address[] _tokenAddrs, uint[] _relTokenAmts, uint[] _valuesInEth) external onlyOwner {
        require(_tokenAddrs.length != 0 && _tokenAddrs.length == _relTokenAmts.length && _tokenAddrs.length == _valuesInEth.length);
        for (uint i = 0; i < _tokenAddrs.length; i++) {
            updatePriceForToken(_tokenAddrs[i], _relTokenAmts[i], _valuesInEth[i]);
        }
    }

    function getLatestPriceAndTimestampForToken(address _tokenAddr) external view returns (uint _relTokenAmt, uint _valueInEth, uint _timestamp){
        return (tokenAddrToPrice[_tokenAddr].relTokenAmt, tokenAddrToPrice[_tokenAddr].valueInEth, tokenAddrToPrice[_tokenAddr].timestamp);
    }
    
}