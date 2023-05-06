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
export const imgPath = "../Digital_Rights_Maykr/images"
export const uploadedImagesURIs = "../Digital_Rights_Maykr/utils/uploadedURIs/uploadedImagesURIs.md"
export const uploadedMetadataURIs = "../Digital_Rights_Maykr/utils/uploadedURIs/uploadedMetadataURIs.md"
