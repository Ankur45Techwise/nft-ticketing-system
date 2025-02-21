require('@nomiclabs/hardhat-waffle');
require('dotenv').config();

module.exports = {
    solidity: "0.8.20",
    networks: {
        sepolia: {
            url: `https://eth-sepolia.g.alchemy.com/v2/OejZnBAo05afDV2b-kB7Q-E04VOV4dv3`,
            accounts: [`0x${process.env.PRIVATE_KEY}`]
        }
    }
};