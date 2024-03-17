import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {Contract} from 'ethers';
import hre from 'hardhat';
import {
  ArtzoneCreatorV2,
  ERC20FixedSupply,
  NiftyzoneMinterV1,
  NiftyzoneMarketplace,
  NiftyzoneMinter,
  ERC1967Proxy,
} from '../typechain';

import {
  deploy,
  getContractAt,
  getSigners,
  verifyContract,
  deployUUPSUpgradableContract,
} from '../helpers/hardhat-helpers';

const ARTZONE_MAIN_ADDRESS = '0x11392b95Aa4e7EDba47C07C64BB1ffe97EB495b7';

async function main() {
  const [deployer] = await getSigners();

  const ARTZONE_CREATOR_V2_PARAMS = ['Artzone AI', 'Artzone AI', 100]; // 1%

  // const artzoneCreatorV2 = await deploy(
  //   deployer,
  //   'ArtzoneCreatorV2',
  //   ARTZONE_CREATOR_V2_PARAMS,
  //   true,
  //   'ArtzoneCreatorV2'
  // );
  // const artzone = await getContractAt('ArtzoneCreatorV2', ARTZONE_MAIN_ADDRESS);
  // console.log('Verifying contract...');
  // await verifyContract(ARTZONE_MAIN_ADDRESS, ARTZONE_CREATOR_V2_PARAMS);
  // console.log('Success!');
  // const owner = await artzoneCreatorV2.owner();
  // console.log('Owner of ArtzoneCreatorV2:', owner);

  // Deploy Niftyzone Minter Contract
  let minterContract = await deploy<NiftyzoneMinterV1>(deployer, 'NiftyzoneMinterV1', [], true, 'SunnyMinterV1');

  // Deploy Niftyzone Marketplace (UUPS) Contract
  // let marketplaceContract = await deployUUPSUpgradableContract<NiftyzoneMarketplace>(
  //   deployer,
  //   'NiftyzoneMarketplace',
  //   [],
  //   [[]],
  //   false,
  //   'SUNNY MARKETPLACE'
  // );

  // let marketplaceProxy = await deploy<ERC1967Proxy>(
  //   deployer,
  //   'ERC1967Proxy',
  //   [
  //     '0x08D14f412C286BAcB804Bd9b9DA222131E92A2DC',
  //     '0xa224cee700000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000',
  //   ],
  //   true,
  //   'ERC1967Proxy'
  // );

  // // Upgrade NiftyzoneMarketplace Contract.
  // let upgradedMarketplaceContract = await upgradeUUPSUpgradeableContract(
  //   deployer,
  //   'NiftyzoneMarketplace',
  //   '0x2B7DBE2Ec5b2bcf35Ba2372d219A2731f2bB7888',
  //   '0x26E6aDf232455B4AeD8F464576fe37A20B76aE47',
  //   true,
  //   'TESTING VERSION'
  // );

  // // Deploy Artzone Minter Contract
  // let artzoneMinterContract = await deploy<ArtzoneMinter>(
  //   deployer,
  //   'ArtzoneMinter',
  //   ['0x8eA7508BE9b5291c00F4364C64a174289C0f5D2F'],
  //   true
  // );

  // // Deploy Artzone Minter Upgradeable (UUPS) Contract
  // let artzoneMinterUpgradeableContract = await deployUUPSUpgradableContract<ArtzoneMinterUpgradeable>(
  //   deployer,
  //   'ArtzoneMinterUpgradeable',
  //   [],
  //   [
  //     [
  //       '0x8eA7508BE9b5291c00F4364C64a174289C0f5D2F',
  //       '0x29A768F1688722EcbCCa3c11C1dE41FF314265bD',
  //       '0x1D7e965D07a740FEd34D3Fb39805A7AFd121F34e',
  //     ],
  //   ],
  //   true,
  //   'ArtzoneMinterUpgradeable'
  // );

  // let niftyzoneMinterUpgradeableContract = await deployUUPSUpgradableContract<NiftyzoneMinterUpgradeable>(
  //   deployer,
  //   'NiftyzoneMinterUpgradeable',
  //   [],
  //   [],
  //   true,
  //   'NiftyzoneMinterUpgradeable'
  // );

  // await deployUUPSUpgradableContract<TestContract>(deployer, 'TestContract', [], [], true, 'TestContract');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
