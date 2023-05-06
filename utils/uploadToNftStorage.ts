import { imgPath, uploadedImagesURIs, uploadedMetadataURIs } from "../helper-hardhat-config"
import { NFTStorage, File } from "nft.storage"
import mime from "mime"
import path from "path"
import fs from "fs"
import "dotenv/config"

const NFT_STORAGE_KEY = process.env.NFT_STORAGE_KEY

/**
 * Reads an image file from `imagePath` and stores an NFT with the given name and description.
 * @param {string} imagePath the path to an image file
 * @param {string} name a name for the NFT
 * @param {string} description a text description for the NFT
 */
/** @dev We will probably need to pass all response @params into below function sent by user via front-end website */
async function storeNFTs(imagesPath) {
    console.log("Uploading Images and Metadata To NFT.Storage...")
    const fullImagesPath = path.resolve(imagesPath)
    const files = fs.readdirSync(fullImagesPath)
    let metadataArray = []
    let imgArray = []
    for (const fileIndex in files) {
        const image = await fileFromPath(`${fullImagesPath}/${files[fileIndex]}`)

        //@ts-ignore
        const nftstorage = new NFTStorage({ token: NFT_STORAGE_KEY })
        // We have to start counting from 0 here, and every single upload should have number instead of name as those will be our certs
        const dogName = files[fileIndex].replace(".jpg", "")
        const timeStamp = new Date()
        const creationDate = timeStamp.toString()

        // Adding metadata to image and uploading to NFT.Storage
        const response = await nftstorage.store({
            image,
            name: dogName,
            description: `Some Certificate Description ${dogName}`,
            hash: "",
            author: "Melani Parker",
            address: "",
            date: creationDate,
            certificate: "hash+tokenId(name)",
        })

        //@ts-ignore
        metadataArray.push(`https://ipfs.io/ipfs/${response.ipnft}/metadata.json` + "\n")
        //@ts-ignore
        imgArray.push(`${response.data.image.toString().replace("ipfs://", "https://ipfs.io/ipfs/")}` + "\n")

        // Saving generated metadata and images URIs in correct files, without any ","
        fs.writeFileSync(uploadedImagesURIs, imgArray.toString().replace(/,/g, ""))
        fs.writeFileSync(uploadedMetadataURIs, metadataArray.toString().replace(/,/g, ""))
    }
    console.log(`Images URIs: ${imgArray}` + "\n" + `Metadata URIs: ${metadataArray}`)
    console.log("Images Uploaded And Saved!")
}

/**
 * A helper to read a file from a location on disk and return a File object.
 * Note that this reads the entire file into memory and should not be used for
 * very large files.
 * @param {string} filePath the path to a file to store
 * @returns {File} a File object containing the file content
 */
export async function fileFromPath(filePath) {
    const content = await fs.promises.readFile(filePath)
    const type = mime.getType(filePath)
    return new File([content], path.basename(filePath), { type })
}

storeNFTs(imgPath)
