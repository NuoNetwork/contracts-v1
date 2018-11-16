const HDWalletProvider = require("truffle-hdwallet-provider");

var mnemonic = "";

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*" // Match any network id
    },
    rinkeby: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "")
      },
      network_id: "4"// Rinkeby ID 4
     },
     kovan: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "")
      },
      network_id: "42"// Koven ID 42
     },
     mainnet: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "")
      },
      gasPrice: 7000000000, 
      network_id: "1"// Mainnet ID 1
     }
  }
}
