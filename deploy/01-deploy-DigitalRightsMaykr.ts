import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/dist/types"
import { networkConfig, developmentChains } from "../helper-hardhat-config"
import verify from "../utils/verify"

const deployDigitalRightsMaykr: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { getNamedAccounts, deployments, network } = hre
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()

    const digitalRightsMaykr = await deploy("DigitalRightsMaykr", {
        from: deployer,
        args: [networkConfig[network.config.chainId!]["keepersUpdateInterval"]],
        log: true,
        waitConfirmations: networkConfig[network.config.chainId!]["blockConfirmations"] || 1,
    })

    /** @dev Verify */
    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        await verify(digitalRightsMaykr.address, [])
    }

    const networkName = network.name == "hardhat" ? "localhost" : network.name
    log(`Working on ${networkName} network...`)
}

export default deployDigitalRightsMaykr
deployDigitalRightsMaykr.tags = ["all", "maykr"]
