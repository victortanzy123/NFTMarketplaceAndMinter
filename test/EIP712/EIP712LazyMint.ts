import {loadFixture} from '@nomicfoundation/hardhat-network-helpers';
import {expect} from 'chai';
import {ethers, network} from 'hardhat';
import {signTypedData} from '../../helpers/utils/EIP712';
import {EIP712Domain, EIP712TypeDefinition} from '../../helpers/types/EIP712.types';
import {deploy, evm_revert, evm_snapshot} from '../../helpers/hardhat-helpers';
import {ERC721LazyMint} from '../../typechain/ERC721LazyMint';

describe('ERC721 Lazy Mint', function () {
  async function deployFixture() {
    const URI: string = 'BASE_URI_1';
    const [owner, otherAccount] = await ethers.getSigners();
    const ERC721LazyMint = await ethers.getContractFactory('ERC721LazyMint');

    // Create an EIP712 domainSeparator
    // https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator
    const domainName = 'LAZY_MINT'; // the user readable name of signing domain, i.e. the name of the DApp or the protocol.
    const signatureVersion = '1'; // the current major version of the signing domain. Signatures from different versions are not compatible.
    const chainId = network.config.chainId as number; // the EIP-155 chain id. The user-agent should refuse signing if it does not match the currently active chain.
    // The typeHash is designed to turn into a compile time constant in Solidity. For example:
    // bytes32 constant MAIL_TYPEHASH = keccak256("Mail(address from,address to,string contents)");
    // https://eips.ethereum.org/EIPS/eip-712#rationale-for-typehash
    //const typeHash = "NFTVoucher(uint256 tokenId,string uri)"
    //const argumentTypeHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(typeHash)); // convert to byteslike, then hash it

    const types: EIP712TypeDefinition = {
      NFTVoucher: [
        {name: 'tokenId', type: 'uint256'},
        {name: 'uri', type: 'string'},
      ],
    };

    const contract = await deploy<ERC721LazyMint>('ERC721LazyMint', []);
    const verifyingContract = contract.address;

    const domain: EIP712Domain = {
      name: domainName,
      version: signatureVersion,
      chainId,
      verifyingContract,
    };

    return {contract, owner, otherAccount, domain, types, URI};
  }

  describe('Signing data via EIP712 for voucher', function () {
    it('Should verify that the NFT voucher redeem has ben signed by owner', async function () {
      const {contract, owner, otherAccount, domain, types, URI} = await loadFixture(deployFixture);

      const NFTVoucher = {
        tokenId: 0,
        uri: URI,
      };

      const signature = await signTypedData(domain, types, NFTVoucher, owner);
      const invalidSignature = await signTypedData(domain, types, NFTVoucher, otherAccount);

      await expect(contract.connect(otherAccount).redeem(NFTVoucher, invalidSignature)).to.be.revertedWith(
        'INVALID_SIGNER'
      );
      await expect(contract.connect(otherAccount).redeem(NFTVoucher, signature)).to.not.be.reverted;
      await expect(contract.connect(otherAccount).redeem(NFTVoucher, signature)).to.be.revertedWith(
        'ERC721: token already minted'
      );
    });
  });
});
