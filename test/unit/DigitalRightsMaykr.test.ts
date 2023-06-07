import { DigitalRightsMaykr } from "../../typechain-types"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { network, deployments, ethers } from "hardhat"
import { assert, expect } from "chai"
import { developmentChains } from "../../helper-hardhat-config"
import { parseEther } from "ethers/lib/utils"

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
          describe("allowLending", () => {
              beforeEach(async () => {
                  tokenId = 0
                  user = accounts[1]
                  await digitalRightsMaykr.mintNFT("tokenURI")
              })
              it("Allows token to be borrowable by other users and updates cert struct accordingly", async () => {
                  await digitalRightsMaykr.allowLending(tokenId, 2, 777)

                  assert.equal((await digitalRightsMaykr.getCertificatePrice(tokenId)).toString(), "777")
                  assert.equal((await digitalRightsMaykr.getLendingPeriod(tokenId)).toString(), "172800")
                  expect(await digitalRightsMaykr.getLendingStatus(tokenId)).to.be.true
              })
              it("Reverts if called by not token owner or token doesnt exists, if token is invalid, if token already allowed, if lending period too short", async () => {
                  drmInstance = digitalRightsMaykr.connect(user)
                  await expect(drmInstance.allowLending(tokenId, 1, 777)).to.revertedWith("DRM__NotTokenOwner")
                  await expect(digitalRightsMaykr.allowLending(2, 1, 777)).to.revertedWith("Token does not exist")

                  await digitalRightsMaykr.allowLending(tokenId, 1, 777)
                  await expect(digitalRightsMaykr.allowLending(tokenId, 1, 777)).to.revertedWith("DRM__TokenAlreadyAllowed")

                  await digitalRightsMaykr.revokeCertificate(tokenId)
                  await expect(digitalRightsMaykr.allowLending(tokenId, 1, 777)).to.revertedWith("DRM__TokenNotValid")
              })
              it("Emits LendingAllowed event", async () => {
                  await expect(digitalRightsMaykr.allowLending(tokenId, 1, 777)).to.emit(digitalRightsMaykr, "LendingAllowed")
              })
          })
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
          describe("revokeCertificate", () => {
              it("It revokes tokenId from usage and emits Revoked event, can be called only by contract owner", async () => {
                  await digitalRightsMaykr.mintNFT("tokenURI")
                  await expect(digitalRightsMaykr.revokeCertificate(tokenId)).to.emit(digitalRightsMaykr, "Revoked")

                  await digitalRightsMaykr.mintNFT("tokenURI")
                  user = accounts[1]
                  drmInstance = digitalRightsMaykr.connect(user)
                  await expect(drmInstance.revokeCertificate(1)).to.revertedWith("Ownable: caller is not the owner")
              })
          })
          describe("checkUpkeep", () => {
              it("Check if upkeep is needed and throws false if just one requirement is false or all", async () => {
                  const { upkeepNeeded } = await digitalRightsMaykr.callStatic.checkUpkeep("0x")
                  assert(upkeepNeeded == false)
              })
              it("Check if upkeep is needed and throws true if all requirements are met", async () => {
                  await digitalRightsMaykr.mintNFT("tokenURI")
                  await digitalRightsMaykr.allowLending(tokenId, 1, 777)

                  user = accounts[1]
                  drmInstance = digitalRightsMaykr.connect(user)
                  await drmInstance.buyLicense(0, user.address, { value: "777" })

                  const time = await digitalRightsMaykr.getLendingPeriod(tokenId)
                  // Moving time by 1 day (from lending period)
                  await network.provider.send("evm_increaseTime", [time.toNumber() + 1])
                  await network.provider.send("evm_mine", [])

                  const { upkeepNeeded } = await digitalRightsMaykr.callStatic.checkUpkeep("0x")
                  assert(upkeepNeeded == true)
              })
          })
          describe("performUpkeep", () => {
              it("Reverts if upkeep not needed", async () => {
                  await expect(digitalRightsMaykr.performUpkeep([])).to.be.revertedWith("DRM__UpkeepNotNeeded")
              })
              it("Erases borrowers, whos license have expired and emits ExpiredLicensesRemoved", async () => {
                  await digitalRightsMaykr.mintNFT("tokenURIFirst")
                  await digitalRightsMaykr.mintNFT("tokenURISecond")
                  await digitalRightsMaykr.allowLending(tokenId, 1, 777)
                  await digitalRightsMaykr.allowLending(1, 2, 999)

                  user = accounts[1]
                  const buyer = accounts[2]
                  drmInstance = digitalRightsMaykr.connect(user)
                  const drmInstanceBuyer = digitalRightsMaykr.connect(buyer)
                  await drmInstance.buyLicense(0, user.address, { value: "777" })
                  await drmInstanceBuyer.buyLicense(1, buyer.address, { value: "999" })

                  const timeFirstNFT = await digitalRightsMaykr.getLendingPeriod(tokenId)
                  const timeSecondNFT = await digitalRightsMaykr.getLendingPeriod(1)
                  console.log(`First NFT Lending Time: ${timeFirstNFT} Second NFT Lending Time: ${timeSecondNFT}`)

                  let borrowersF = await digitalRightsMaykr.getCertsBorrowers(tokenId)
                  let borrowersS = await digitalRightsMaykr.getCertsBorrowers(1)
                  console.log(`Borrowers Of First NFT: ${borrowersF} Borrowers Of Second NFT: ${borrowersS}`)
                  assert.equal(borrowersF[0], "0x70997970C51812dc3A010C7d01b50e0d17dc79C8")
                  assert.equal(borrowersS[0], "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC")

                  // Moving time by 1 day (from lending period of first NFT)
                  await network.provider.send("evm_increaseTime", [timeFirstNFT.toNumber() + 1])
                  await network.provider.send("evm_mine", [])

                  await expect(digitalRightsMaykr.performUpkeep([])).to.emit(digitalRightsMaykr, "ExpiredLicensesRemoved")

                  borrowersF = await digitalRightsMaykr.getCertsBorrowers(tokenId)
                  borrowersS = await digitalRightsMaykr.getCertsBorrowers(1)
                  console.log(`Borrowers Of First NFT: ${borrowersF} Borrowers Of Second NFT: ${borrowersS}`)
                  assert.lengthOf(borrowersF, 0, "Array should be empty")
                  assert.equal(borrowersS[0], "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC")
              })
          })
          describe("withdrawProceeds", () => {
              beforeEach(async () => {
                  user = accounts[3]
                  drmInstance = digitalRightsMaykr.connect(user)
              })
              it("Reverts if amount to withdraw is 0", async () => {
                  await expect(drmInstance.withdrawProceeds()).to.be.revertedWith("DRM__NothingToWithdraw")
              })
              it("Reverts if transaction fails and keep pending amount to withdraw", async () => {})
              it("Withdraws proceeds to lender", async () => {
                  let contractBalance = await ethers.provider.getBalance(digitalRightsMaykr.address)
                  let userBalance = await ethers.provider.getBalance(user.address)
                  const lender = accounts[4]
                  let lenderBalance = await ethers.provider.getBalance(lender.address)
                  const drmInstanceLender = digitalRightsMaykr.connect(lender)

                  assert.equal(contractBalance.toString(), "0")
                  assert.equal(userBalance.toString(), parseEther("10000").toString())
                  assert.equal(lenderBalance.toString(), parseEther("10000").toString())

                  await drmInstanceLender.mintNFT("SomeOtherNFT")
                  await drmInstanceLender.allowLending(tokenId, 1, 777)
                  const lenderBalanceAfter = await ethers.provider.getBalance(lender.address)

                  const resTx = await drmInstance.buyLicense(0, user.address, { value: parseEther("72") })
                  const recTx = await resTx.wait()

                  const gas = recTx.gasUsed
                  const gasPrice = recTx.effectiveGasPrice
                  const gasCost = gas.mul(gasPrice)

                  contractBalance = await ethers.provider.getBalance(digitalRightsMaykr.address)
                  userBalance = await ethers.provider.getBalance(user.address)

                  assert.equal(contractBalance.toString(), parseEther("72").toString())
                  assert.equal(userBalance.toString(), parseEther("10000").sub(parseEther("72")).sub(gasCost).toString())

                  const wResTx = await drmInstanceLender.withdrawProceeds()
                  const wRecTx = await wResTx.wait()
                  const finalLenderBalance = await ethers.provider.getBalance(lender.address)

                  const wGas = wRecTx.gasUsed
                  const wGasPrice = wRecTx.effectiveGasPrice
                  const wGasCost = wGas.mul(wGasPrice)

                  assert.equal(finalLenderBalance.toString(), lenderBalanceAfter.add(parseEther("72")).sub(wGasCost).toString())
              })
          })
      })
