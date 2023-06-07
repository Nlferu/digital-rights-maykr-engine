import { ethers } from "hardhat"
import { motherContract } from "../helper-hardhat-config"

/** @dev Function To Revoking Reported Suspicious Certificates, Which Breaks Plagiarism Rule */
/* In future this function in contract can be restricted by voting system (DAO) */
async function revokeCertificate() {
    const tokenId = 0
    const digitalRightsMaykr = await ethers.getContractAt("DigitalRightsMaykr", motherContract)

    await digitalRightsMaykr.revokeCertificate(tokenId)
    console.log(`Certificate With Id: ${tokenId} Has Been Successfully Revoked!`)
}

revokeCertificate()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
