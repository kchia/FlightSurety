const HDWalletProvider = require("truffle-hdwallet-provider");
const mnemonic =
  "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat";

module.exports = {
  networks: {
    development: {
      provider: function () {
        return new HDWalletProvider(mnemonic, "http://127.0.0.1:8545/");
      },
      network_id: "5777",
    },
  },
  compilers: {
    solc: {
      version: "0.5.7",
    },
  },
};
