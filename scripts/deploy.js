const hre = require("hardhat");

async function main() {
  const BullBear = await hre.ethers.getContractFactory("BullBear");
  const bullBear = await BullBear.deploy(
    "60",
    "0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D",
    "0xA39434A63A52E749F02807ae27335515BA4b07F7"
  );

  await bullBear.deployed();

  console.log(`Contract deployed to: ${bullBear.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
