import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {Contract} from 'ethers';
import hre from 'hardhat';
import {ArtzoneCreatorV2, ERC20FixedSupply} from '../typechain';

import {deploy, getSigners} from '../helpers/hardhat-helpers';

async function main() {
  const [deployer] = await getSigners();

  const ARTZONE_CREATOR_V2_PARAMS = ['Sunny Collection', 'Sunny Collection', 100]; // 1%

  const artzoneCreatorV2 = await deploy(
    deployer,
    'ArtzoneCreatorV2',
    ARTZONE_CREATOR_V2_PARAMS,
    false, // don't verify
    'ArtzoneCreatorV2'
  );
  const owner = await artzoneCreatorV2.owner();
  console.log('Owner of ArtzoneCreatorV2:', owner);

  // // Deploy Niftyzone Minter Contract
  // let minterContract = await deploy<NiftyzoneMinter>(deployer, 'NiftyzoneMinter', [], true);

  // Deploy Niftyzone Marketplace (UUPS) Contract
  // let marketplaceContract = await deployUUPSUpgradableContract<NiftyzoneMarketplace>(
  //   deployer,
  //   'NiftyzoneMarketplace',
  //   [],
  //   [[]],
  //   true,
  //   'NiftyzoneMarketplace'
  // );

  // // Upgrade NiftyzoneMarketplace Contract.
  // let upgradedMarketplaceContract = await upgradeUUPSUpgradeableContract(
  //   deployer,
  //   'NiftyzoneMarketplace',
  //   '0x2B7DBE2Ec5b2bcf35Ba2372d219A2731f2bB7888',
  //   '0x26E6aDf232455B4AeD8F464576fe37A20B76aE47',
  //   true,
  //   'NiftyzoneMarketplaceV3'
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
