const hre = require("hardhat");
const fs = require('fs');

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[0].address;
    console.log('signer:', signer);

    const Multicall = await hre.ethers.getContractFactory('Multicall');
    const multicall = await Multicall.deploy();
    await multicall.deployed();
    console.log("Multicall depolyed to:", multicall.address);

    const addresses = {
        Multicall: multicall.address,
    };

    console.log(addresses);

    const chainId = await hre.ethers.provider.getNetwork().then(network => network.chainId);
    fs.writeFileSync(`${__dirname}/multicall-address-${chainId}.json`, JSON.stringify(addresses, null, 4));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
