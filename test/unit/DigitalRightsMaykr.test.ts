import { DigitalRightsMaykr } from "../../typechain-types"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { network, deployments, ethers } from "hardhat"
import { assert, expect } from "chai"
import { developmentChains } from "../../helper-hardhat-config"

/**
    * @dev Tests to be done in order:
        
    1. Constructor()
        * It assigns correct owner ✔️
        * It gives contract correct name and symbol ✔️
        * It shows 0 minted tokens ✔️
    2. mintNFT()
        * It creates new certificate (tokenId/NFT) and emit's (owner, tokenId)
        * It assigns correct tokenURI to created NFT and emit's (tokenURI, tokenId)
    3. tokenURI()
        * It returns correct tokenURI assigned per given tokenId
    4. buyLicense()
        createClause()
    5. allowLending()
    6. blockLending()
    7. revokeCertificate()
    8. checkUpkeep()
    9. performUpkeep()
        licenseStatusUpdater()
            licenseExpirationCheck()
    10. withdrawProceeds()
        * It allows certificate lenders to withdraw their proceeds
        * It reverts if caller has nothing to withdraw
        * It emit's (amount, caller, success)
    11. getters()
        * It displays correct data
*/

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Digital Rights Maykr", () => {
          let digitalRightsMaykr: DigitalRightsMaykr
          let drmInstance: DigitalRightsMaykr
          let accounts: SignerWithAddress[]
          let deployer: SignerWithAddress
          let user: SignerWithAddress
          let tokenId: number
          let resMintTx: any
          let recMintTx: any

          beforeEach(async () => {
              accounts = await ethers.getSigners()
              deployer = accounts[0]

              await deployments.fixture(["all"])
              digitalRightsMaykr = await ethers.getContract("DigitalRightsMaykr")
          })
          describe("Constructor", () => {
              it("Initializes the NFT Correctly.", async () => {
                  const owner = await digitalRightsMaykr.owner()
                  const name = await digitalRightsMaykr.name()
                  const symbol = await digitalRightsMaykr.symbol()
                  const tokenCounter = await digitalRightsMaykr.emittedCount()

                  console.log(`Owner: ${owner} \nName: ${name} \nSymbol: ${symbol} \nTokens Amount: ${tokenCounter}`)

                  assert.equal(owner, deployer.address)
                  assert.equal(name, "Digital Rights Maykr")
                  assert.equal(symbol, "DRM")
                  assert.equal(tokenCounter.toString(), "0")
              })
          })
          describe("mintNFT", () => {
              it("Mints a new certificate (Token/NFT) with assigned tokenURI and emits", async () => {
                  resMintTx = await digitalRightsMaykr.mintNFT("tokenURIx")
                  recMintTx = await resMintTx.wait()

                  const minter = recMintTx.events[0].args.owner
                  tokenId = recMintTx.events[1].args.id
                  const uri = recMintTx.events[1].args.uri
                  console.log(`Minter: ${minter} TokenId: ${tokenId} URI: ${uri}`)
                  const tokenCounter = await digitalRightsMaykr.emittedCount()

                  assert.equal(uri, "tokenURIx")
                  assert.equal(tokenCounter.toString(), "1")
                  assert.equal(minter == deployer.address, tokenId == 0)
                  await expect(digitalRightsMaykr.mintNFT("tokenURIx")).to.emit(digitalRightsMaykr, `Minted`)
                  await expect(digitalRightsMaykr.mintNFT("tokenURIx")).to.emit(digitalRightsMaykr, `TokenUriSet`)
              })
          })
          describe("tokenURI", () => {
              it("Returns correct tokenURI per tokenId", async () => {
                  await digitalRightsMaykr.mintNFT("tokenURI_1")
                  await digitalRightsMaykr.mintNFT("tokenURI_2")

                  assert.equal(await digitalRightsMaykr.tokenURI(0), "tokenURI_1")
                  assert.equal(await digitalRightsMaykr.tokenURI(1), "tokenURI_2")
              })
              it("Reverts if called with wrong tokenId parameter", async () => {
                  await expect(digitalRightsMaykr.tokenURI(0)).to.be.revertedWith("Token does not exist")
              })
          })
          describe("buyLicense", () => {
              beforeEach(async () => {
                  tokenId = 0
                  user = accounts[1]
                  await digitalRightsMaykr.mintNFT("tokenURI")
              })
              it("Gives permission to borrower to use art with certain tokenId", async () => {
                  await expect(digitalRightsMaykr.allowLending(tokenId, 1, 777)).to.emit(digitalRightsMaykr, `LendingAllowed`)
                  assert.equal(await digitalRightsMaykr.getLendingStatus(tokenId), true)
                  await digitalRightsMaykr.buyLicense(tokenId, user.address, { value: "778" })
                  assert.equal(await digitalRightsMaykr.getLicenseValidity(tokenId, user.address), true)
              })
              it("Reverts if tokenId doesnt exists, if token revoked, if token not allowed to be borrowed, if not enough eth paid, if caller owns tokenId or has license already", async () => {
                  await expect(digitalRightsMaykr.buyLicense(1, user.address, { value: "777" })).to.revertedWith("Token does not exist")
                  await expect(digitalRightsMaykr.buyLicense(tokenId, deployer.address, { value: "777" })).to.revertedWith("DRM__AddressHasRightsAlready")
                  await expect(digitalRightsMaykr.buyLicense(tokenId, user.address, { value: "777" })).to.revertedWith("DRM__TokenNotBorrowable")
                  await digitalRightsMaykr.allowLending(tokenId, 1, 777)
                  await expect(digitalRightsMaykr.buyLicense(tokenId, user.address, { value: "776" })).to.revertedWith("DRM__NotEnoughETH")

                  const buyer = accounts[2]
                  await digitalRightsMaykr.buyLicense(0, buyer.address, { value: "777" })
                  await expect(digitalRightsMaykr.buyLicense(tokenId, buyer.address, { value: "777" })).to.revertedWith("DRM__AddressHasRightsAlready")

                  await expect(digitalRightsMaykr.revokeCertificate(tokenId)).to.emit(digitalRightsMaykr, "Revoked")
                  await expect(digitalRightsMaykr.buyLicense(tokenId, user.address, { value: "777" })).to.revertedWith("DRM__TokenNotValid")
              })
              it("Updating certificate struct values correctly", async () => {
                  await digitalRightsMaykr.allowLending(tokenId, 1, 777)
                  await digitalRightsMaykr.buyLicense(0, user.address, { value: "777" })

                  const borrowers = await digitalRightsMaykr.getCertsBorrowers(tokenId)
                  assert.equal(borrowers[0], user.address)
                  expect(borrowers).to.be.an("array")
                  expect(borrowers).to.include(user.address)

                  assert.equal((await digitalRightsMaykr.getExpirationTime(tokenId, user.address)).toString(), "86400")

                  const clause = await digitalRightsMaykr.getClause(tokenId, user.address)
                  expect(clause).to.include(`The Artist: ${deployer.address.toLocaleLowerCase()}` && user.address.toLocaleLowerCase())

                  expect(await digitalRightsMaykr.getLicenseValidity(tokenId, user.address)).to.be.true

                  const lender = await digitalRightsMaykr.getProceeds(deployer.address)
                  const notLender = await digitalRightsMaykr.getProceeds(user.address)
                  assert.equal(lender.toString() == "777", notLender.toString() == "0")
              })
              it("CreatesClause", async () => {
                  await digitalRightsMaykr.allowLending(tokenId, 1, 777)
                  await expect(digitalRightsMaykr.buyLicense(tokenId, user.address, { value: "777" })).to.emit(digitalRightsMaykr, `ClauseCreated`)
              })
              it("Emits LendingLicenseCreated", async () => {
                  await digitalRightsMaykr.allowLending(tokenId, 1, 777)
                  await expect(digitalRightsMaykr.buyLicense(tokenId, user.address, { value: "777" })).to.emit(digitalRightsMaykr, `LendingLicenseCreated`)
              })
          })
          //describe("allowLending", () => {})
          describe("blockLending", () => {
              it("Should block lending for specific tokenId and emit", async () => {
                  user = accounts[1]
                  drmInstance = digitalRightsMaykr.connect(user)

                  await expect(digitalRightsMaykr.blockLending(tokenId)).to.be.revertedWith("Token does not exist")
                  await digitalRightsMaykr.mintNFT("tokenURI")
                  await digitalRightsMaykr.allowLending(tokenId, 1, 777)
                  await expect(drmInstance.blockLending(tokenId)).to.be.revertedWith("DRM__NotTokenOwner")
                  assert.equal(await digitalRightsMaykr.getLendingStatus(tokenId), true)
                  await expect(digitalRightsMaykr.blockLending(tokenId)).to.emit(digitalRightsMaykr, `LendingBlocked`)
                  assert.equal(await digitalRightsMaykr.getLendingStatus(tokenId), false)
                  await expect(digitalRightsMaykr.blockLending(tokenId)).to.be.revertedWith("DRM__TokenAlreadyBlocked")
              })
          })
          //describe("revokeCertificate", () => {})
          describe("checkUpkeep", () => {})
          describe("performUpkeep", () => {})
          describe("withdrawProceeds", () => {})
          describe("getters", () => {})
      })
