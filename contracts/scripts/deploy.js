const hre = require("hardhat");

async function main() {
  const SplitEscrow = await hre.ethers.getContractFactory("SplitEscrow");
  const contract = await SplitEscrow.deploy();
  await contract.waitForDeployment();

  const address = await contract.getAddress();
  console.log("SplitEscrow deployed to:", address);
  console.log("View on Sepolia Etherscan: https://sepolia.etherscan.io/address/" + address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});