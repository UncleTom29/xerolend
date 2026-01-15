import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-verify"; 
import dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
    },
  },

  networks: {
    hardhat: {
      chainId: 31337,
      allowUnlimitedContractSize: true,
    },

    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
    },

    // Mantle Sepolia Testnet
    "mantle-sepolia": {
      url: process.env.MANTLE_SEPOLIA_RPC_URL || "https://rpc.sepolia.mantle.xyz",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 5003,
      gasPrice: "auto",
    },

    // Mantle Mainnet
    mantle: {
      url: process.env.MANTLE_MAINNET_RPC_URL || "https://rpc.mantle.xyz",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 5000,
      gasPrice: "auto",
    },

  },

  // Etherscan V2 configuration (unified for all supported EVM chains)
etherscan: {
  apiKey: process.env.ETHERSCAN_API_KEY || "",

  customChains: [
    {
      network: "mantle-sepolia",
      chainId: 5003,
      urls: {
        apiURL: "https://api-sepolia.mantlescan.xyz/api", // V2 compatible
        browserURL: "https://sepolia.mantlescan.xyz"
      }
    },
    {
      network: "mantle",
      chainId: 5000,
      urls: {
        apiURL: "https://api.mantlescan.xyz/api", // V2 compatible
        browserURL: "https://mantlescan.xyz"
      }
    },
  ],


  enabled: true,
},

  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },

  gasReporter: {
    enabled: process.env.REPORT_GAS === "true",
    currency: "USD",
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
  },
};

export default config;