var LoanRegistry = artifacts.require("./LoanRegistry.sol");
var LoanFactory = artifacts.require("./LoanFactory.sol");
var TokenRegistry = artifacts.require("./TokenRegistry.sol");
var TokenTicker = artifacts.require("./TokenTicker.sol");

//var TestFixedToken = artifacts.require("./test/TestFixedToken.sol");
//var TestVariableToken = artifacts.require("./test/TestVariableToken.sol");

module.exports = function(deployer) {
  deployer.deploy(TokenTicker);
  deployer.deploy(TokenTickerProxy);
  deployer.deploy(TokenRegistry);
  deployer.deploy(LoanRegistry);
  deployer.deploy(LoanFactory);

  //deployer.deploy(TestFixedToken);
  //deployer.deploy(TestVariableToken);
  
};