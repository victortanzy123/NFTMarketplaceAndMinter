import {loadFixture} from '@nomicfoundation/hardhat-network-helpers';
import {expect} from 'chai';
import {ethers, network} from 'hardhat';
import {signTypedData} from '../../helpers/utils/EIP712';
import {EIP712Domain, EIP712TypeDefinition} from '../../helpers/types/EIP712.types';

import {deploy} from '../../helpers/hardhat-helpers';
import {ArtzoneCreatorRedeem} from '../../typechain/ArtzoneCreatorRedeem';

type ArtzoneTokenInitDetails = {
  amount: number;
  price: number;
  uri: string;
  revenueRecipient: string;
};

const MOCK_NFT_1: ArtzoneTokenInitDetails = {
  amount: 1000,
  price: 1,
  uri: 'BASE_URI_1',
  revenueRecipient: '0xa76E79fb4A357A9828e5bA1843A81E253ABB3C5c',
};

describe('ERC721 Lazy Mint', function () {
  async function deployFixture() {
    const [owner, otherAccount] = await ethers.getSigners();
    const ArtzoneCreatorRedeem = await ethers.getContractFactory('ArtzoneCreatorRedeem');
    const ERC721LazyMint = await ethers.getContractFactory('ERC721LazyMint');

    // Create an EIP712 domainSeparator
    // https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator
    const domainName = 'ARTZONE_CREATOR_REDEEM'; // the user readable name of signing domain, i.e. the name of the DApp or the protocol.
    const signatureVersion = '1'; // the current major version of the signing domain. Signatures from different versions are not compatible.
    const chainId = network.config.chainId as number; // the EIP-155 chain id. The user-agent should refuse signing if it does not match the currently active chain.
    // The typeHash is designed to turn into a compile time constant in Solidity. For example:
    // bytes32 constant MAIL_TYPEHASH = keccak256("Mail(address from,address to,string contents)");
    // https://eips.ethereum.org/EIPS/eip-712#rationale-for-typehash
    //const typeHash = "NFTVoucher(uint256 tokenId,string uri)"
    //const argumentTypeHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(typeHash)); // convert to byteslike, then hash it

    const types: EIP712TypeDefinition = {
      Token: [
        {name: 'tokenId', type: 'uint256'},
        {name: 'amount', type: 'uint256'},
        {name: 'receiver', type: 'address'},
      ],
    };

    const contract = await deploy<ArtzoneCreatorRedeem>('ArtzoneCreatorRedeem', ['test', 'test', 1000]);
    const verifyingContract = contract.address;

    const domain: EIP712Domain = {
      name: domainName,
      version: signatureVersion,
      chainId,
      verifyingContract,
    };

    return {contract, owner, otherAccount, domain, types};
  }

  describe('Signing data via EIP712 for receiving authorisation', function () {
    it('Should verify that the specified tokenId to be minted to should tally with the signer', async function () {
      const {contract, owner, otherAccount, domain, types} = await loadFixture(deployFixture);

      await contract
        .connect(owner)
        .initialiseNewSingleToken(MOCK_NFT_1.amount, MOCK_NFT_1.price, MOCK_NFT_1.uri, MOCK_NFT_1.revenueRecipient);

      const token = {
        tokenId: 1,
        amount: 2,
        receiver: otherAccount.address,
      };

      const signature = await signTypedData(domain, types, token, otherAccount); // Signed by correct receiver -> `otherAccount`
      const invalidSignature = await signTypedData(domain, types, token, owner);

      await expect(contract.connect(owner).redeemTokenForUser(token.tokenId, token.amount, token.receiver, signature))
        .to.not.be.reverted; // If Signature was signed by receiver `otherAccount`
      await expect(
        contract.connect(owner).redeemTokenForUser(token.tokenId, token.amount, token.receiver, invalidSignature)
      ).to.be.revertedWith('Receiver did not authorise via signature'); // If Signature was signed not by the receiver aka NOT `otherAccount`

      await contract.connect(owner).redeemTokenForUser(token.tokenId, token.amount, token.receiver, signature);
      const balanceOfReceiver = await contract.tokenMetadata(token.tokenId);
      console.log('See balance Of Receiver', balanceOfReceiver);
      // await expect(balanceOfReceiver).to.be.eq(token.amount);
    });
  });
});
