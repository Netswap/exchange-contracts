const hre = require("hardhat");
const fs = require('fs');

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[1];
    console.log('signer:', signer.address);

    const BaseOracleFactory = await hre.ethers.getContractFactory('BaseOracle');
    const BaseOracle = await BaseOracleFactory.connect(signer).deploy('0x70f51d68D16e8f9e418441280342BD43AC9Dff9f');
    await BaseOracle.deployed();
    console.log("BaseOracle depolyed to:", BaseOracle.address);

    const addresses = {
        BaseOracle: BaseOracle.address,
    };

    console.log(addresses);

    fs.writeFileSync(`${__dirname}/BaseOracle-address.json`, JSON.stringify(addresses, null, 4));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
