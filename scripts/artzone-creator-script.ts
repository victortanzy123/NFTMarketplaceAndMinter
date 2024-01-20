import {getSigners, getContractAt} from '../helpers/hardhat-helpers';
import {ArtzoneCreatorV2} from '../typechain';

const POLYGON_MUMBAI_ARTZONE_CREATOR_V2_ADDRESS = '0x5E04F56F0C5257c398C9A6F7E1e5caa318Eb7398';
const NEW_URI = 'https://cloudflare-ipfs.com/ipfs/QmdqJPJWWBFeZ7g8mXhTZGFHqHou4adZw1TrthbrPQMpgR';
async function main() {
  const [owner] = await getSigners();
  console.log('SEE OWNER ADDRESS:', await owner.getAddress());

  const artzoneCreator = await getContractAt('ArtzoneCreatorV2', POLYGON_MUMBAI_ARTZONE_CREATOR_V2_ADDRESS);
  const tokenIds: number[] = [8];

  for (const tokenId of tokenIds) {
    const tx = await artzoneCreator.connect(owner).updateTokenURI(tokenId, NEW_URI);
    console.log('Processing Token URI Update of token - ', tokenId);
    const receipt = await tx.wait();
    console.log(`Successfully updated token - ${tokenId} with new URI!`);
  }

  console.log('End of Script.');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
