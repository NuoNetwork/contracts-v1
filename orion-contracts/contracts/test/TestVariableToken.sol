pragma solidity 0.4.19;

import "zeppelin-solidity/contracts/token/ERC20/StandardToken.sol";

contract TestVariableToken is StandardToken {
    string public name = "Test Variable";
    string public symbol = "TVT";
    uint8 public decimals = 18;
    uint public INITIAL_SUPPLY = (2**256) - 1;

    function TestVariableToken() public {
        totalSupply_ = INITIAL_SUPPLY;
        balances[msg.sender] = INITIAL_SUPPLY;
    }
}