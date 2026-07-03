require("@nomicfoundation/hardhat-toolbox");

const SEPOLIA_PRIVATE_KEY = process.env.SEPOLIA_PRIVATE_KEY || "";

module.exports = {
  solidity: "0.8.28",
  networks: {
    sepolia: {
      url: "https://sepolia.drpc.org",
      accounts: SEPOLIA_PRIVATE_KEY ? [SEPOLIA_PRIVATE_KEY] : [],
    },
  },
};