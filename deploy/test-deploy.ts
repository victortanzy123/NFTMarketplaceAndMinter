import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {Contract} from 'ethers';
import hre from 'hardhat';
import {SyntheticERC721} from '../typechain';

import {deploy, getSigners, getContractAt, verifyContract} from '../helpers/hardhat-helpers';

const SYNTHETIC_ERC721_NAME = 'SyntheticERC721';
const SYNTHETIC_ERC721_ADDRESS = '0xfDf291E5e911973549AFf90F4BD20eb5015d302A';
const OST_NAME = 'ERC20FixedSupply';
const OPEN_SYNTHETIC_TOKEN_ADDRESS = '0x871964d95fA2099aa31a926FBb9A5207C29fE1b2';

const ARTZONE_POLYGON_V2_MAIN_ADDRESS = '0x11392b95aa4e7edba47c07c64bb1ffe97eb495b7';
const TOKEN_URI = 'https://cloudflare-ipfs.com/ipfs/QmdqJPJWWBFeZ7g8mXhTZGFHqHou4adZw1TrthbrPQMpgR';

const NARUTO_TOKEN_URI = 'https://cloudflare-ipfs.com/ipfs/QmZQ55grJL52Qnmf7wLtFbB1CRSp1U9rR6XtKCp9mq4bWT';
const COOL_CAT_TOKEN_URI = 'https://cloudflare-ipfs.com/ipfs/QmeMaBzhPGMLrVsU3HyDSHXgtvU4ynXnmWees3rUGJcYxy';
const ENCHANTED_FOREST_TOKEN_URI = 'https://cloudflare-ipfs.com/ipfs/QmS1pLnWs2U7GwrNHB1GMKrXQimJaGogxV9i2ftEMbLk2Y';
const ANCIENT_IRONMAN_TOKEN_URI = 'https://cloudflare-ipfs.com/ipfs/QmVrvoHao7U5jHiLvZAcENMghFNjnLN7wB199xL23GwGer';
const RECEIVER_7AC = '0x6F17961EE6bbDd1913942c6368C6DCE386F0b7AC';
const SUNNY_COLLECTION_ADDRESS = '0x1064360b573cd47224edcaac4b6de49dc2d256cb';

async function main() {
  const [deployer] = await getSigners();
  // const syntheticERC721 = await deploy(deployer, SYNTHETIC_ERC721_NAME, [], true, SYNTHETIC_ERC721_NAME);
  // const sunnyCollection = await getContractAt('ArtzoneCreatorV2', SUNNY_COLLECTION_ADDRESS);
  // const updateTx = await sunnyCollection.updateTokenURI(12, COOL_CAT_TOKEN_URI);
  // const mintTxReceipt = await updateTx.wait();
  // console.log('UPDATED TOKEN 12:', mintTxReceipt.transactionHash);
  // const res = await sunnyCollection.tokenMetadata(3);
  // console.log('SEE METADATA OF TOKEN:', res);
  const artzoneV2Polygon = await getContractAt('ArtzoneCreatorV2', ARTZONE_POLYGON_V2_MAIN_ADDRESS);
  const TOKEN = {
    totalSupply: 0,
    maxSupply: 200,
    maxClaimPerUser: 1,
    price: 1000000000000000,
    expiry: 0,
    uri: ANCIENT_IRONMAN_TOKEN_URI,
    creator: deployer.address,
    royalties: [],
    claimStatus: 0,
  };
  console.log('Initialising token...');
  // const initialiseTokenTx = await artzoneV2Polygon.initialiseNewSingleToken(TOKEN);
  // const initialiseTokenTx = await sunnyCollection.initialiseNewSingleToken(TOKEN);
  // const initialiseTxReceipt = await initialiseTokenTx.wait();
  // console.log('INITIALISE TX:', initialiseTxReceipt.transactionHash);

  // Update Token URI
  const updateUriTx = await artzoneV2Polygon.updateTokenURI(4, ANCIENT_IRONMAN_TOKEN_URI);
  const txReceipt = await updateUriTx.wait();
  console.log('UPDATE TOKEN TX:', txReceipt.transactionHash);
  // const res = await sunnyCollection.tokenMetadata(11);
  // console.log('Res', res);
  // const mintTx = await sunnyCollection.mintExistingSingleToken(deployer.address, 10, 1);

  // const updateTokenUriTx = await sunnyCollection.updateTokenURI(
  //   1,
  //   'https://cloudflare-ipfs.com/ipfs/QmdqJPJWWBFeZ7g8mXhTZGFHqHou4adZw1TrthbrPQMpgR'
  // );
  // updateTokenUriTx.wait();
  // const token1Metadata = await sunnyCollection.tokenMetadata(1);
  // console.log('SEE TOKEN 1 Metadata:', token1Metadata);
  // const syntheticERC721 = await getContractAt(SYNTHETIC_ERC721_NAME, SYNTHETIC_ERC721_ADDRESS);
  // const openSyntheticToken = await getContractAt(OST_NAME, OPEN_SYNTHETIC_TOKEN_ADDRESS);
  // console.log('Minting SyntheticERC721...');
  // const tx1 = await syntheticERC721.connect(deployer).mint(TOKEN_URI);
  // await tx1.wait();
  // console.log('S-ERC721 minted!');

  // console.log('Transfering OST...');
  // const transferTx1 = await openSyntheticToken.transfer(RECEIVER_7AC, 10000);
  // await transferTx1.wait();
  // console.log('OST Transfer completed!');

  // const tx2 = await syntheticERC721.mint(TOKEN_URI);
  // await tx2.wait();

  // const tx3 = await syntheticERC721.mint(TOKEN_URI);
  // await tx3.wait();

  // const tx4 = await syntheticERC721.mint(TOKEN_URI);
  // await tx4.wait();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
