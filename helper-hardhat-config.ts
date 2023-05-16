export interface networkConfigItem {
    name?: string
    keepersUpdateInterval?: string
    blockConfirmations?: number
}

export interface networkConfigInfo {
    [key: number]: networkConfigItem
}

export const networkConfig: networkConfigInfo = {
    31337: {
        name: "localhost",
        keepersUpdateInterval: "30",
        blockConfirmations: 1,
    },
    11155111: {
        name: "sepolia",
        keepersUpdateInterval: "30",
        blockConfirmations: 6,
    },
    5: {
        name: "goerli",
        keepersUpdateInterval: "30",
        blockConfirmations: 6,
    },
    1: {
        name: "mainnet",
        keepersUpdateInterval: "30",
        blockConfirmations: 6,
    },
}

export const developmentChains = ["hardhat", "localhost"]
export const imgPath = "../Digital_Rights_Maykr/images"
export const uploadedImagesURIs = "../Digital_Rights_Maykr/utils/uploadedURIs/uploadedImagesURIs.md"
export const uploadedMetadataURIs = "../Digital_Rights_Maykr/utils/uploadedURIs/uploadedMetadataURIs.md"
