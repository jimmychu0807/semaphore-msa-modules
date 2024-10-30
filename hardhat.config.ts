import "@nomicfoundation/hardhat-toolbox"
import "@nomicfoundation/hardhat-foundry"
import "@typechain/hardhat"
import { HardhatUserConfig } from "hardhat/config"

const hardhatConfig: HardhatUserConfig = {
  solidity: {
    version: "0.8.27",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    hardhat: {
      chainId: 31337,
      allowUnlimitedContractSize: true
    },
  },
  gasReporter: {
    currency: "USD",
    enabled: process.env.REPORT_GAS === "true",
    coinmarketcap: process.env.COINMARKETCAP_API_KEY
  },
  typechain: {
    target: "ethers-v6"
  },
};

export default hardhatConfig;
