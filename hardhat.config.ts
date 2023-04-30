import { HardhatUserConfig } from "hardhat/config"
import "@nomiclabs/hardhat-etherscan"
import "@nomiclabs/hardhat-waffle"
import "@nomiclabs/hardhat-ethers"
import "hardhat-gas-reporter"
import "@typechain/hardhat"
import "solidity-coverage"
import "hardhat-deploy"
import "dotenv/config"

const MAINNET_RPC_URL = process.env.MAINNET_RPC_URL || "https://eth-mainnet.alchemyapi.io/v2/your-api-key"
const GOERLI_RPC_URL = process.env.GOERLI_RPC_URL || "https://eth-mainnet.alchemyapi.io/v2/your-api-key"
const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL || "https://eth-mainnet.alchemyapi.io/v2/your-api-key"
const PRIVATE_KEY = process.env.PRIVATE_KEY || ""
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || ""
const COINMARKETCAP_API_KEY = process.env.COINMARKETCAP_API_KEY || ""

const config: HardhatUserConfig = {
    defaultNetwork: "hardhat",
    networks: {
        hardhat: {
            chainId: 31337,
        },
        localhost: {
            chainId: 31337,
        },
        goerli: {
            url: GOERLI_RPC_URL,
            accounts: [PRIVATE_KEY],
            chainId: 5,
        },
        sepolia: {
            url: SEPOLIA_RPC_URL,
            accounts: [PRIVATE_KEY],
            chainId: 11155111,
        },
        mainnet: {
            url: MAINNET_RPC_URL,
            accounts: [PRIVATE_KEY],
            chainId: 1,
        },
    },
    solidity: {
        compilers: [
            {
                version: "0.8.0",
            },
            {
                version: "0.8.4",
            },
            {
                version: "0.8.7",
            },
            {
                version: "0.8.18",
            },
        ],
    },
    etherscan: {
        apiKey: ETHERSCAN_API_KEY,
    },
    gasReporter: {
        enabled: false,
        currency: "USD",
        outputFile: "gas-report.txt",
        noColors: true,
        coinmarketcap: COINMARKETCAP_API_KEY,
        token: "ETH",
    },
    namedAccounts: {
        deployer: {
            default: 0,
            1: 0,
        },
        user: {
            default: 1,
        },
    },
    mocha: {
        timeout: 500000,
    },
}

export default config
