const hre = require("hardhat")

async function main() {
    // Get the Verse smart contract
    const Verse = await hre.ethers.getContractFactory("Verse")
    const verse = await Verse.attach("VERSE_CONTRACT_ADDRESS")

    // Connect to the wallet
    const [deployer] = await hre.ethers.getSigners()

    // Approve token transfer
    const verseToken = await hre.ethers.getContractAt("VerseToken", "VERSE_TOKEN_ADDRESS")
    await verseToken.approve(verse.address, "AMOUNT_TO_STAKE")

    // Stake Verse tokens
    await verse.stakeTokens("AMOUNT_TO_STAKE")

    // Wait for the staking transaction to be mined
    await verse.provider.waitForTransaction(tx.hash)

    console.log("Tokens staked successfully!")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
