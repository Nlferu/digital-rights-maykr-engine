export interface networkConfigItem {
    blockConfirmations?: number
}

export interface networkConfigInfo {
    [key: string]: networkConfigItem
}

export const networkConfig: networkConfigInfo = {
    localhost: { blockConfirmations: 1 },
    hardhat: { blockConfirmations: 1 },
    sepolia: { blockConfirmations: 6 },
    goerli: { blockConfirmations: 6 },
    mainnet: { blockConfirmations: 6 },
}

export const developmentChains = ["hardhat", "localhost"]
export const imgPath = "./images"
