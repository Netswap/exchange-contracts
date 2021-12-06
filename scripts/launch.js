const hre = require("hardhat");
const fs = require('fs');

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[1].address;
    console.log('signer:', signer);

    const Multicall = await hre.ethers.getContractFactory('Multicall');
    const multicall = await Multicall.connect(accounts[1]).deploy();
    await multicall.deployed();
    console.log("Multicall depolyed to:", multicall.address);

    const Factory = await hre.ethers.getContractFactory('NetswapFactory');
    const factory = await Factory.connect(accounts[1]).deploy(signer);
    await factory.deployed();
    console.log("NetswapFactory depolyed to:", factory.address);

    const Router = await hre.ethers.getContractFactory('NetswapRouter');
    const router = await Router.connect(accounts[1]).deploy(factory.address, "0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000");
    await router.deployed();
    console.log("NetswapRouter depolyed to:", router.address);

    const addresses = {
        Multicall: multicall.address,
        NetswapFactory: factory.address,
        NetswapRouter: router.address
    };

    console.log(addresses);

    fs.writeFileSync(`${__dirname}/mainnet-address.json`, JSON.stringify(addresses, null, 4));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
