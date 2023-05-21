import { DigitalRightsMaykr } from "../../typechain-types" //DateTime, ERC4671, IERC4671, IERC4671Enumerable, IERC4671Metadata
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { network, deployments, ethers } from "hardhat"
import { assert, expect } from "chai"
import { developmentChains } from "../../helper-hardhat-config"

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Digital Rights Maykr", () => {
          let digitalRightsMaykr: DigitalRightsMaykr
          let deployer: SignerWithAddress
          let resMintTx: any
          let recMintTx: any

          beforeEach(async () => {
              const accounts = await ethers.getSigners()
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
      })
