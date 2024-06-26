require("@nomiclabs/hardhat-waffle");
require('@openzeppelin/hardhat-upgrades');
const { config } = require('dotenv');
const { resolve } = require('path');

config({ path: resolve(__dirname, "./.env") });

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
    const accounts = await ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

let mnemonic;
let privateKey;
if (!process.env.MNEMONIC && !process.env.PRIVATE_KEY) {
    throw new Error("Please set your MNEMONIC or PRIVATE_KEY in a .env file");
} else {
    mnemonic = process.env.MNEMONIC;
    privateKey = process.env.PRIVATE_KEY;
}

const accounts = privateKey ? [process.env.PRIVATE_KEY] : { mnemonic };

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
    solidity: "0.6.12",
    networks: {
        hardhat: {
        },
        mainnet: {
            url: 'https://andromeda.metis.io/?owner=1088',
            accounts,
        },
        testnet: {
            url: 'https://goerli.gateway.metisdevops.link',
            gasPrice: 1000000000,
            accounts,
        },
        metissepolia: {
            url: 'https://sepolia.metisdevops.link',
            accounts,
        },
    },
    solidity: {
        version: "0.6.12",
        settings: {
            optimizer: {
                enabled: true,
                runs: 9999
            }
        }
    },
};

