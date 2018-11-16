pragma solidity 0.4.19;

interface ITokenTicker {
    function getLatestPriceAndTimestampForToken(address _tokenAddr) 
        external view returns (uint _relTokenAmt, uint _valueInEth, uint _timestamp);
}
