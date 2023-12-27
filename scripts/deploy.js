const hre = require("hardhat");
const fs = require('fs');

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[0].address;
    console.log('signer:', signer);

    const Factory = await hre.ethers.getContractFactory('NetswapFactory');
    const factory = await Factory.deploy(signer);
    await factory.deployed();
    console.log("NetswapFactory depolyed to:", factory.address);

    const Router = await hre.ethers.getContractFactory('NetswapRouter');
    const router = await Router.deploy(factory.address, "0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000");
    await router.deployed();
    console.log("NetswapRouter depolyed to:", router.address);

    const addresses = {
        NetswapFactory: factory.address,
        NetswapRouter: router.address
    };

    console.log(addresses);

    const chainId = await hre.ethers.provider.getNetwork().then(network => network.chainId);
    fs.writeFileSync(`${__dirname}/exchange-address-${chainId}.json`, JSON.stringify(addresses, null, 4));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
