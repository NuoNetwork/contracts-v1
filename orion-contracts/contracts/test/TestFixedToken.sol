pragma solidity 0.4.19;

import "zeppelin-solidity/contracts/token/ERC20/StandardToken.sol";

contract TestFixedToken is StandardToken {
    string public name = "Test Fixed";
    string public symbol = "TFT";
    uint8 public decimals = 18;
    uint public INITIAL_SUPPLY = (2**256) - 1;

    function TestFixedToken() public {
        totalSupply_ = INITIAL_SUPPLY;
        balances[msg.sender] = INITIAL_SUPPLY;
    }
}