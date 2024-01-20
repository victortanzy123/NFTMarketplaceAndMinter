import {ArtzoneCreatorV2} from '../../typechain';
import {setNextBlockTimeStamp, deployMockContract} from '../../helpers/hardhat-helpers';
import {loadFixture} from '@nomicfoundation/hardhat-network-helpers';
import {expect} from 'chai';
import {ethers} from 'hardhat';
import {RoyaltyConfig, TokenMetadataConfig} from './types';

const TEST_TOKEN_EXPIRY = 1790000000;
const ZERO = '0';
const ONE = '1';

describe('Artzone Creator', function () {
  async function deployFixture() {
    const [owner, otherAccount1, otherAccount2, otherAccount3, otherAccount4, _] = await ethers.getSigners();

    const royaltyConfig: RoyaltyConfig = {
      receiver: otherAccount1.address,
      bps: 1000,
    };

    const TEST_TOKEN_1: TokenMetadataConfig = {
      totalSupply: 0,
      maxSupply: 1000,
      maxClaimPerUser: 5,
      price: 100,
      expiry: 0,
      uri: 'BASE_URI_1',
      creator: otherAccount1.address,
      royalties: [royaltyConfig] as RoyaltyConfig[],
      claimStatus: 0,
    };
    const TEST_TOKEN_2: TokenMetadataConfig = {
      totalSupply: 0,
      maxSupply: 1000,
      maxClaimPerUser: 5,
      price: 0,
      expiry: 0,
      uri: 'BASE_URI_2',
      creator: otherAccount2.address,
      royalties: [royaltyConfig] as RoyaltyConfig[],
      claimStatus: 0,
    };
    const TEST_TOKEN_3: TokenMetadataConfig = {
      totalSupply: 0,
      maxSupply: 1000,
      maxClaimPerUser: 5,
      price: 100,
      expiry: 0,
      uri: 'BASE_URI_3',
      creator: otherAccount3.address,
      royalties: [royaltyConfig] as RoyaltyConfig[],
      claimStatus: 0,
    };

    const TEST_TOKEN_4: TokenMetadataConfig = {
      totalSupply: 0,
      maxSupply: 1000,
      maxClaimPerUser: 5,
      price: 100,
      expiry: TEST_TOKEN_EXPIRY,
      uri: 'BASE_URI_4',
      creator: otherAccount3.address,
      royalties: [royaltyConfig] as RoyaltyConfig[],
      claimStatus: 0,
    };

    const artzoneContract = await deployMockContract<ArtzoneCreatorV2>('ArtzoneCreatorV2', [
      'Artzone Collections',
      'Artzone Collections',
      100,
    ]);

    return {
      artzoneContract,
      owner,
      otherAccount1,
      otherAccount2,
      otherAccount3,
      otherAccount4,
      TEST_TOKEN_1,
      TEST_TOKEN_2,
      TEST_TOKEN_3,
      TEST_TOKEN_4, // With Expiry
    };
  }

  describe('[Token Initialisation]', function () {
    it('should be able to initialise single token', async function () {
      const {artzoneContract, owner, otherAccount1, TEST_TOKEN_1} = await loadFixture(deployFixture);

      // Initialise token with price via `initialiseNewSingleToken`
      const token1MintTx = await artzoneContract.connect(owner).initialiseNewSingleToken(TEST_TOKEN_1);
      const token1TxReceipt = await token1MintTx.wait();
      const tokenId1 = Number(token1TxReceipt.logs[0].topics[1]);
      expect(tokenId1).to.be.equal(Number(ONE));

      const [totalSupply, maxSupply, maxClaimPerUser, mintPrice, expiry, uri, creator, claimStatus] =
        await artzoneContract.tokenMetadata(tokenId1);
      expect(totalSupply.toString()).to.be.equal(ZERO);
      expect(maxSupply.toString()).to.be.equal('1000');
      expect(maxClaimPerUser.toString()).to.be.equal('5');
      expect(mintPrice.toString()).to.be.equal('100');
      expect(expiry.toString()).to.be.equal(ZERO);
      expect(uri).to.be.equal('BASE_URI_1');
      expect(creator).to.be.equal(otherAccount1.address);
      expect(claimStatus).to.be.equal(Number(ZERO));
    });

    it('should be able to initialise new FREE single token', async function () {
      const {artzoneContract, owner, otherAccount2, TEST_TOKEN_2} = await loadFixture(deployFixture);

      // Initialise FREE token via `initialiseNewSingleToken`
      const token2MintTx = await artzoneContract.connect(owner).initialiseNewSingleToken(TEST_TOKEN_2);
      const token2TxReceipt = await token2MintTx.wait();
      const tokenId = Number(token2TxReceipt.logs[0].topics[1]);
      expect(tokenId).to.be.equal(Number(ONE));

      const [totalSupply, maxSupply, maxClaimPerUser, mintPrice, expiry, uri, creator, claimStatus] =
        await artzoneContract.tokenMetadata(tokenId);
      expect(totalSupply.toString()).to.be.equal(ZERO);
      expect(maxSupply.toString()).to.be.equal('1000');
      expect(maxClaimPerUser.toString()).to.be.equal('5');
      expect(mintPrice.toString()).to.be.equal(ZERO);
      expect(expiry.toString()).to.be.equal(ZERO);
      expect(uri).to.be.equal('BASE_URI_2');
      expect(creator).to.be.equal(otherAccount2.address);
      expect(claimStatus).to.be.equal(Number(ZERO));
    });

    it('should be able to initialise multiple single tokens via `initialiseNewMultipleTokens`', async function () {
      const {artzoneContract, owner, TEST_TOKEN_1, TEST_TOKEN_2, TEST_TOKEN_3} = await loadFixture(deployFixture);

      const tokensToInitialise: TokenMetadataConfig[] = [TEST_TOKEN_1, TEST_TOKEN_2, TEST_TOKEN_3];

      const tokensMintTx = await artzoneContract.connect(owner).initialiseNewMultipleTokens(tokensToInitialise);
      const tokensTxReceipt = await tokensMintTx.wait();

      const eventLogs = tokensTxReceipt.logs;
      eventLogs.forEach((logData: any, i: number) => {
        const tokenId = Number(logData.topics[1]);
        expect(tokenId).to.be.equal(i + 1);
      });
    });

    it('should  NOT be able to initialise tokens with an expiry before the current block timestamp.', async function () {
      const {artzoneContract, owner, TEST_TOKEN_4} = await loadFixture(deployFixture);

      await setNextBlockTimeStamp(1800000000); // Fast forward `block.timestamp`
      const token4InitTxPromise = artzoneContract.connect(owner).initialiseNewSingleToken(TEST_TOKEN_4);

      await expect(token4InitTxPromise).to.be.revertedWith('Invalid expiry timestamp');
    });
  });

  describe('[Token Mint]', function () {
    it('should be able to mint tokens that have been initialised.', async function () {
      const {artzoneContract, owner, otherAccount1, TEST_TOKEN_1} = await loadFixture(deployFixture);
      const token1MintTx = await artzoneContract.connect(owner).initialiseNewSingleToken(TEST_TOKEN_1);
      const token1TxReceipt = await token1MintTx.wait();
      const tokenId = Number(token1TxReceipt.logs[0].topics[1]);
      expect(tokenId).to.be.equal(Number(ONE));

      const otherAccount1BalanceBefore = await artzoneContract.balanceOf(otherAccount1.address, tokenId);
      expect(otherAccount1BalanceBefore).to.be.equal(ZERO);

      const weiToSend = ethers.utils.parseUnits('100', 'wei');
      const singleTokenMintTx = await artzoneContract
        .connect(otherAccount1)
        .mintExistingSingleToken(otherAccount1.address, tokenId, 1, {value: weiToSend});
      const singleTokenMintTxReceipt = await singleTokenMintTx.wait();

      const otherAccount1BalanceAfter = await artzoneContract.balanceOf(otherAccount1.address, tokenId);
      expect(otherAccount1BalanceAfter).to.be.equal(ONE);
    });

    it('should  NOT be able to mint tokens with an expiry before the current block timestamp.', async function () {
      const {artzoneContract, owner, otherAccount1, TEST_TOKEN_4} = await loadFixture(deployFixture);

      const token4MintTx = await artzoneContract.connect(owner).initialiseNewSingleToken(TEST_TOKEN_4);
      const token4TxReceipt = await token4MintTx.wait();
      const tokenId = Number(token4TxReceipt.logs[0].topics[1]);
      expect(tokenId).to.be.equal(Number(ONE));

      await setNextBlockTimeStamp(1800000000); // Fast forward `block.timestamp`
      const weiToSend = ethers.utils.parseUnits('100', 'wei');
      const token4MintTxPromise = artzoneContract
        .connect(otherAccount1)
        .mintExistingSingleToken(otherAccount1.address, tokenId, 1, {value: weiToSend});

      await expect(token4MintTxPromise).to.be.revertedWith('Expired mint window');
    });

    it('should be able to mint tokens with expiry before the deadline.', async function () {
      const {artzoneContract, owner, otherAccount1, TEST_TOKEN_4} = await loadFixture(deployFixture);
      const token4MintTx = await artzoneContract.connect(owner).initialiseNewSingleToken(TEST_TOKEN_4);
      const token4TxReceipt = await token4MintTx.wait();
      const tokenId = Number(token4TxReceipt.logs[0].topics[1]);
      expect(tokenId).to.be.equal(Number(ONE));

      const tokenMetadata = await artzoneContract.tokenMetadata(tokenId);
      expect(tokenMetadata.expiry.toString()).to.be.equal(TEST_TOKEN_EXPIRY.toString());

      const otherAccount1BalanceBefore = await artzoneContract.balanceOf(otherAccount1.address, tokenId);
      expect(otherAccount1BalanceBefore).to.be.equal(ZERO);

      const weiToSend = ethers.utils.parseUnits('100', 'wei');
      const singleTokenMintTx = await artzoneContract
        .connect(otherAccount1)
        .mintExistingSingleToken(otherAccount1.address, tokenId, 1, {value: weiToSend});
      const singleTokenMintTxReceipt = await singleTokenMintTx.wait();

      const otherAccount1BalanceAfter = await artzoneContract.balanceOf(otherAccount1.address, tokenId);
      expect(otherAccount1BalanceAfter).to.be.equal(ONE);
    });

    it('should be able to mint batch tokens and process fees accordingly', async function () {
      const {
        artzoneContract,
        owner,
        otherAccount1,
        otherAccount2,
        otherAccount3,
        otherAccount4,
        TEST_TOKEN_1,
        TEST_TOKEN_2,
        TEST_TOKEN_3,
      } = await loadFixture(deployFixture);

      const tokensToInitialise: TokenMetadataConfig[] = [TEST_TOKEN_1, TEST_TOKEN_2, TEST_TOKEN_3];

      const tokensMintTx = await artzoneContract.connect(owner).initialiseNewMultipleTokens(tokensToInitialise);
      const tokensTxReceipt = await tokensMintTx.wait();

      const provider = ethers.provider;

      const balanceWeiOfAcc1Before = await provider.getBalance(otherAccount1.address);
      const balanceWeiOfAcc2Before = await provider.getBalance(otherAccount2.address);
      const balanceWeiOfAcc3Before = await provider.getBalance(otherAccount3.address);

      const weiToSend = ethers.utils.parseUnits('300', 'wei'); // Convert to BigNumber -> since 10 + 0 + 10 = 20
      const batchTokenMintTx = await artzoneContract
        .connect(otherAccount4)
        .mintExistingMultipleTokens([owner.address, owner.address, owner.address], [1, 2, 3], [2, 1, 1], {
          value: weiToSend,
        });

      const balanceWeiOfAcc1After = await provider.getBalance(otherAccount1.address);
      const balanceWeiOfAcc2After = await provider.getBalance(otherAccount2.address);
      const balanceWeiOfAcc3After = await provider.getBalance(otherAccount3.address);

      const artzoneBalanceAfter = await provider.getBalance(artzoneContract.address);
      // console.log(
      //   'See balances',
      //   balanceWeiOfAcc1After,
      //   balanceWeiOfAcc2After,
      //   balanceWeiOfAcc3After,
      //   artzoneBalanceAfter
      // );

      // Expect Acc1 to increase by (200 * 990) / 10_000 = 198
      expect(balanceWeiOfAcc1After.sub(balanceWeiOfAcc1Before)).to.be.equal(ethers.BigNumber.from(198));

      // Expect Acc2 to increase by (100 * 990) / 10_000 = 99
      expect(balanceWeiOfAcc2After.sub(balanceWeiOfAcc2Before)).to.be.equal(ethers.BigNumber.from(0));

      // Expect Acc3 to increase by (100 * 990) / 10_000 = 99
      expect(balanceWeiOfAcc3After.sub(balanceWeiOfAcc3Before)).to.be.equal(ethers.BigNumber.from(99));

      // expect Artzone Contract to gain (3 * 100 * 100) / 10_000 = 3
      const expectedArtzoneFundsReceived = ethers.BigNumber.from(3);
      expect(artzoneBalanceAfter).to.be.equal(expectedArtzoneFundsReceived);
    });
  });

  describe('[Simulataneous Token Initialisation And Mint]', function () {
    it('should be able to initialise and mint a single token in a single function call.', async function () {
      const {artzoneContract, owner, otherAccount1, TEST_TOKEN_2} = await loadFixture(deployFixture);

      const token2InitAndMintTx = await artzoneContract
        .connect(owner)
        .initialiseAndMintNewSingleToken(TEST_TOKEN_2, otherAccount1.address, 1);
      const token2TxReceipt = await token2InitAndMintTx.wait();
      const tokenId = Number(token2TxReceipt.logs[0].topics[1]);
      expect(tokenId).to.be.equal(Number(ONE));

      const [totalSupply, maxSupply] = await artzoneContract.tokenMetadata(tokenId);
      expect(totalSupply.toString()).to.be.equal(ONE);
      expect(maxSupply.toString()).to.be.equal('1000');

      const account1Balance = await artzoneContract.balanceOf(otherAccount1.address, tokenId);
      expect(account1Balance.toString()).to.be.equal(ONE);
    });

    it('should NOT be able to initialise and mint if an incorrect mint amount is specified.', async function () {
      const {artzoneContract, owner, otherAccount1, TEST_TOKEN_2} = await loadFixture(deployFixture);

      const token2InitAndMintTxPromise = artzoneContract
        .connect(owner)
        .initialiseAndMintNewSingleToken(TEST_TOKEN_2, otherAccount1.address, 6);
      await expect(token2InitAndMintTxPromise).to.be.revertedWith('Exceed token max claim limit');
    });
  });

  describe('[Platform Revenue Withdrawal]', () => {
    it('should allow owner to withdraw platform fees.', async () => {
      const {artzoneContract, owner, otherAccount4, TEST_TOKEN_1, TEST_TOKEN_2, TEST_TOKEN_3} = await loadFixture(
        deployFixture
      );

      const tokensToInitialise: TokenMetadataConfig[] = [TEST_TOKEN_1, TEST_TOKEN_2, TEST_TOKEN_3];

      // Initialise tokens
      const tokensMintTx = await artzoneContract.connect(owner).initialiseNewMultipleTokens(tokensToInitialise);
      const tokensTxReceipt = await tokensMintTx.wait();

      // Mint tokens
      const weiToSend = ethers.utils.parseUnits('300', 'wei'); // Convert to BigNumber -> since 10 + 0 + 10 = 20
      const batchTokenMintTx = await artzoneContract
        .connect(otherAccount4)
        .mintExistingMultipleTokens([owner.address, owner.address, owner.address], [1, 2, 3], [2, 1, 1], {
          value: weiToSend,
        });

      const provider = ethers.provider;

      // expect Artzone Contract to gain (3 * 100 * 100) / 10_000 = 3
      const expectedArtzoneFundsReceived = ethers.BigNumber.from(3);
      const account4BalanceBefore = await provider.getBalance(otherAccount4.address);

      // Withdraw funds by owner to `otherAccount4`
      const withdrawFundsTx = await artzoneContract.connect(owner).withdraw(otherAccount4.address);
      await withdrawFundsTx.wait();

      const account4BalanceAfter = await provider.getBalance(otherAccount4.address);
      expect(account4BalanceAfter.sub(account4BalanceBefore)).to.be.equal(expectedArtzoneFundsReceived);
    });

    it('should NOT allow an external entity to withdraw collected revenue.', async () => {
      const {artzoneContract, owner, otherAccount1, otherAccount4, TEST_TOKEN_1, TEST_TOKEN_2, TEST_TOKEN_3} =
        await loadFixture(deployFixture);

      const tokensToInitialise: TokenMetadataConfig[] = [TEST_TOKEN_1, TEST_TOKEN_2, TEST_TOKEN_3];

      // Initialise tokens
      const tokensMintTx = await artzoneContract.connect(owner).initialiseNewMultipleTokens(tokensToInitialise);
      const tokensTxReceipt = await tokensMintTx.wait();

      // Mint tokens
      const weiToSend = ethers.utils.parseUnits('300', 'wei'); // Convert to BigNumber -> since 10 + 0 + 10 = 20
      const batchTokenMintTx = await artzoneContract
        .connect(otherAccount4)
        .mintExistingMultipleTokens([owner.address, owner.address, owner.address], [1, 2, 3], [2, 1, 1], {
          value: weiToSend,
        });

      const invalidExternalWithdrawTxPromise = artzoneContract.connect(otherAccount1).withdraw(otherAccount1.address);
      await expect(invalidExternalWithdrawTxPromise).to.be.revertedWith('Ownable: caller is not the owner');
    });
  });
});
