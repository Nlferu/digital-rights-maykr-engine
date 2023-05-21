import { ethers } from "hardhat"

async function main() {
    // Get the Verse smart contract
    const Verse = await ethers.getContractFactory("Verse")
    const verse = await Verse.attach("VERSE_CONTRACT_ADDRESS")

    // Connect to the wallet
    const [deployer] = await ethers.getSigners()

    // Approve token transfer
    const verseToken = await ethers.getContractAt("VerseToken", "VERSE_TOKEN_ADDRESS")
    await verseToken.approve(verse.address, "AMOUNT_TO_STAKE")

    // Stake Verse tokens
    await verse.stakeTokens("AMOUNT_TO_STAKE")

    console.log("Tokens staked successfully!")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
