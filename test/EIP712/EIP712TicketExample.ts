import {loadFixture} from '@nomicfoundation/hardhat-network-helpers';
import {expect} from 'chai';
import {ethers, network} from 'hardhat';
import {signTypedData} from '../../helpers/utils/EIP712';
import {EIP712Domain, EIP712TypeDefinition} from '../../helpers/types/EIP712.types';
import {deploy, evm_revert, evm_snapshot} from '../../helpers/hardhat-helpers';
import {EIP712TicketExample} from '../../typechain/EIP712TicketExample';

describe('EIP712 Ticket Example', function () {
  async function deployFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();
    const EIP712TicketExample = await ethers.getContractFactory('EIP712TicketExample');

    // Create EIP712 Domain Separator
    const domainName = 'TicketExample';
    const signatureVersion = '1';
    const chainId = network.config.chainId as number;
    // The typeHash is designed to turn into a compile time constant in Solidity. For example:
    // bytes32 constant MAIL_TYPEHASH = keccak256("Mail(address from,address to,string contents)");
    // https://eips.ethereum.org/EIPS/eip-712#rationale-for-typehash
    const typeHash = 'Ticket(string eventName,uint256 price)';
    const argumentTypeHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(typeHash)); // convert to byteslike, then hash it

    // https://eips.ethereum.org/EIPS/eip-712#specification-of-the-eth_signtypeddata-json-rpc
    const types: EIP712TypeDefinition = {
      Ticket: [
        {name: 'eventName', type: 'string'},
        {name: 'price', type: 'uint256'},
      ],
    };

    const contract = await deploy<EIP712TicketExample>('EIP712TicketExample', [
      domainName,
      signatureVersion,
      argumentTypeHash,
    ]);
    const verifyingContract = contract.address;

    const domain: EIP712Domain = {
      name: domainName,
      version: signatureVersion,
      chainId,
      verifyingContract,
    };

    return {contract, owner, otherAccount, domain, types};
  }

  describe('Signing Data via EIP712', function () {
    it('Should verify that a ticket has been signed by the proper address', async function () {
      const {contract, domain, types, owner} = await loadFixture(deployFixture);

      const ticket = {
        eventName: 'PendleEvent',
        price: ethers.constants.WeiPerEther,
      };

      const signature = await signTypedData(domain, types, ticket, owner);

      expect(await contract.getSigner(ticket.eventName, ticket.price, signature)).to.equal(owner.address);
    });
  });
});
