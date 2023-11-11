import {ArtzoneCreator} from "../../typechain/ArtzoneCreator";
import {deploy, evm_revert, evm_snapshot} from '../../helpers/hardhat-helpers';
import {loadFixture} from '@nomicfoundation/hardhat-network-helpers';
import {expect} from 'chai';
import {ethers, network} from 'hardhat';
import { RoyaltyConfig, TokenMetadataConfig } from "./types"; 
describe("Artzone Creator", function() {
    async function deployFixture() {
        
        const [owner, otherAccount1, otherAccount2, otherAccount3, otherAccount4, _] = await ethers.getSigners();

        const royaltyConfig: RoyaltyConfig = {
            receiver: otherAccount1.address,
            bps: 1000,
        }

        const TEST_TOKEN_1 : TokenMetadataConfig = {
            totalSupply: 0,
            maxSupply: 1000,
            maxClaimPerUser: 5,
            price: 100,
            uri: "BASE_URI_1",
            royalties: [royaltyConfig] as RoyaltyConfig[],
            claimStatus: 0,
        };
        const TEST_TOKEN_2 : TokenMetadataConfig = {
            totalSupply: 0,
            maxSupply: 1000,
            maxClaimPerUser: 5,
            price: 0,
            uri: "BASE_URI_2",
            royalties: [royaltyConfig] as RoyaltyConfig[],
            claimStatus: 0,
        };
        const TEST_TOKEN_3 : TokenMetadataConfig = {
            totalSupply: 0,
            maxSupply: 1000,
            maxClaimPerUser: 5,
            price: 100,
            uri: "BASE_URI_3",
            royalties: [royaltyConfig] as RoyaltyConfig[],
            claimStatus: 0,
        };

        const artzoneContract = await deploy<ArtzoneCreator>("ArtzoneCreator", ["Artzone Collections", "Artzone Collections", 100]);

        return {artzoneContract, owner, otherAccount1, otherAccount2, otherAccount3, otherAccount4,  TEST_TOKEN_1, TEST_TOKEN_2, TEST_TOKEN_3}
    }

    describe("[Token Initialisation]", function() {
        it("should be able to initialise single token", async function () {
            const {artzoneContract, owner, otherAccount1, TEST_TOKEN_1, TEST_TOKEN_2} = await loadFixture(deployFixture);

            // Initialise token with price via `initialiseNewSingleToken`
            const token1MintTx = await artzoneContract.connect(owner).initialiseNewSingleToken(TEST_TOKEN_1, otherAccount1.address);
            const token1TxReceipt = await token1MintTx.wait();
            const tokenId1 = Number(token1TxReceipt.logs[0].topics[1]);
            expect(tokenId1).to.be.equal(1);
        })
        
        it("should be able to initialise new FREE single token", async function() {
                const {artzoneContract, owner, otherAccount1, TEST_TOKEN_1, TEST_TOKEN_2} = await loadFixture(deployFixture);

                // Initialise FREE token via `initialiseNewSingleToken`
                const token2MintTx = await artzoneContract.connect(owner).initialiseNewSingleToken(TEST_TOKEN_2, owner.address);
                const token2TxReceipt = await token2MintTx.wait();
                const tokenId2 = Number(token2TxReceipt.logs[0].topics[1]);
                expect(tokenId2).to.be.equal(1);
        })

        it("should be able to initialise multiple single tokens via `initialiseNewMultipleTokens", async function() {
                const {artzoneContract, owner, otherAccount1, otherAccount2, otherAccount3, TEST_TOKEN_1, TEST_TOKEN_2, TEST_TOKEN_3} = await loadFixture(deployFixture);

                const tokensToInitialise: TokenMetadataConfig[] = [TEST_TOKEN_1, TEST_TOKEN_2, TEST_TOKEN_3];
                const revenueRecipients = [otherAccount1.address, otherAccount2.address, otherAccount3.address]

                const tokensMintTx = await artzoneContract.connect(owner).initialiseNewMultipleTokens(tokensToInitialise, revenueRecipients);
                const tokensTxReceipt = await tokensMintTx.wait();

                const eventLogs = tokensTxReceipt.logs;
                eventLogs.forEach((logData: any, i: number) => {
                    const tokenId = Number(logData.topics[1]);
                    expect(tokenId).to.be.equal(i + 1);
                })
        })
    });

    describe("[Token Mint]", function() {
        it("should be able to mint batch tokens and process fees accordingly", async function () {
            const {artzoneContract, owner, otherAccount1, otherAccount2, otherAccount3, otherAccount4, TEST_TOKEN_1, TEST_TOKEN_2, TEST_TOKEN_3} = await loadFixture(deployFixture);

            const tokensToInitialise: TokenMetadataConfig[] = [TEST_TOKEN_1, TEST_TOKEN_2, TEST_TOKEN_3];
            const revenueRecipients = [otherAccount1.address, otherAccount2.address, otherAccount3.address]

            const tokensMintTx = await artzoneContract.connect(owner).initialiseNewMultipleTokens(tokensToInitialise, revenueRecipients);
            const tokensTxReceipt = await tokensMintTx.wait();

            const provider = ethers.provider;

            const balanceWeiOfAcc1Before = await provider.getBalance(otherAccount1.address);
            const balanceWeiOfAcc2Before = await provider.getBalance(otherAccount2.address);
            const balanceWeiOfAcc3Before = await provider.getBalance(otherAccount3.address);

            const weiToSend = ethers.utils.parseUnits('300', 'wei');  // Convert to BigNumber -> since 10 + 0 + 10 = 20
            const batchTokenMintTx = await artzoneContract.connect(otherAccount4).mintExistingMultipleTokens([owner.address, owner.address, owner.address], [1,2,3], [2,1,1], {value: weiToSend});

            const balanceWeiOfAcc1After = await provider.getBalance(otherAccount1.address);
            const balanceWeiOfAcc2After = await provider.getBalance(otherAccount2.address);
            const balanceWeiOfAcc3After = await provider.getBalance(otherAccount3.address);

            const artzoneBalanceAfter = await provider.getBalance(artzoneContract.address);
            console.log("See balances", balanceWeiOfAcc1After, balanceWeiOfAcc2After, balanceWeiOfAcc3After, artzoneBalanceAfter)

            // Expect Acc1 to increase by (200 * 990) / 10_000 = 198
            expect(balanceWeiOfAcc1After.sub(balanceWeiOfAcc1Before)).to.be.equal(ethers.BigNumber.from(198))

            // Expect Acc2 to increase by (100 * 990) / 10_000 = 99
            expect(balanceWeiOfAcc2After.sub(balanceWeiOfAcc2Before)).to.be.equal(ethers.BigNumber.from(0))
            
            // Expect Acc3 to increase by (100 * 990) / 10_000 = 99
            expect(balanceWeiOfAcc3After.sub(balanceWeiOfAcc3Before)).to.be.equal(ethers.BigNumber.from(99))

            // expect Artzone Contract to gain (3 * 100 * 100) / 10_000 = 3
            const expectedArtzoneFundsReceived = ethers.BigNumber.from(3);
            expect(artzoneBalanceAfter).to.be.equal(expectedArtzoneFundsReceived);
            

            const account4BalanceBefore = await provider.getBalance(otherAccount4.address);
            
            // Withdraw funds by owner to `otherAccount4`
            const withdrawFundsTx = await artzoneContract.connect(owner).withdraw(otherAccount4.address);
            await withdrawFundsTx.wait();

            const account4BalanceAfter = await provider.getBalance(otherAccount4.address);
            expect(account4BalanceAfter.sub(account4BalanceBefore)).to.be.equal(expectedArtzoneFundsReceived);
        })
    })

})