const hre = require("hardhat");
const fs = require('fs');

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[0].address;
    console.log('signer:', signer);

    const TestERC20 = await hre.ethers.getContractFactory('TestERC20');

    const tokenA = await TestERC20.deploy('Test USDT', 'TUSDT', 6);
    await tokenA.deployed();
    console.log("Test USDT depolyed to:", tokenA.address);

    const tokenB = await TestERC20.deploy('Test USDC', 'TUSDC', 6);
    await tokenB.deployed();
    console.log("Test USDC depolyed to:", tokenB.address);

    const tokenC = await TestERC20.deploy('Test WBTC', 'TWBTC', 8);
    await tokenC.deployed();
    console.log("Test WBTC depolyed to:", tokenC.address);

    const tokenD = await TestERC20.deploy('Test LINK', 'TLINK', 18);
    await tokenD.deployed();
    console.log("Test LINK depolyed to:", tokenD.address);

    const tokenE = await TestERC20.deploy('Test UNI', 'TUNI', 18);
    await tokenE.deployed();
    console.log("Test UNI depolyed to:", tokenE.address);

    const addresses = {
        TUSDT: tokenA.address,
        TUSDC: tokenB.address,
        TWBTC: tokenC.address,
        TLINK: tokenD.address,
        TUNI: tokenE.address,
    };

    console.log(addresses);

    const chainId = await hre.ethers.provider.getNetwork().then(network => network.chainId);
    fs.writeFileSync(`${__dirname}/test-tokens-address-${chainId}.json`, JSON.stringify(addresses, null, 4));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
