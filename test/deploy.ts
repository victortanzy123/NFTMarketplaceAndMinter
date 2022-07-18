import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber, Contract } from 'ethers';
import hre from 'hardhat';
import {TestContract, ERC1967Proxy, NiftyzoneMarketplace, NiftyzoneNFTMinter } from '../typechain';

export async function getContractAt<CType extends Contract>(abiType: string, address: string) {
  return (await hre.ethers.getContractAt(abiType, address)) as CType;
}

export async function verifyContract(contract: string, constructor: any[]) {
  await hre.run('verify:verify', {
    address: contract,
    constructorArguments: constructor
  });
}

function toWei(amount: number, decimal: number) {
    return BigNumber.from(10).pow(decimal).mul(amount);
  }
  
  export async function _impersonateAccount(address: string) {
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [address],
    });
  }
  
  export async function impersonateSomeone(user: string) {
    await _impersonateAccount(user);
    return await hre.ethers.getSigner(user);
  }
  
  export async function getEth(user: string) {
    await hre.network.provider.send('hardhat_setBalance', [user, '0x56bc75e2d63100000000000000']);
  }

export async function deploy<CType extends Contract>(deployer: SignerWithAddress, abiType: string, args: any[], verify?: boolean, name?: string) {
  name = name || abiType;
  console.log(`Deploying ${name}...`);
  const contractFactory = await hre.ethers.getContractFactory(abiType);
//   const contract = await hre.upgrades.deployProxy(contractFactory)
  const contract = await contractFactory.connect(deployer).deploy(...args);
  await contract.deployed();
  console.log(`${name} deployed at address: ${(await contract).address}`);

  // Wait 1 minute before verifying on etherscan
  console.log("Awaiting sufficient block confirmation on the network...")
  setTimeout(async ()=>{
    if (verify === true) {
      await verifyContract(contract.address, args);
    }
  }, 60000)

  
  return contract as CType;
}

const timeout =  (ms) => {
  return new Promise(resolve => setTimeout(resolve, ms));
}

const sleep = async (fx, ...args) => {
  await timeout(60000);
  return fx(...args);
}

/// returning the address of the proxy, casted to the implementation type
export async function deployUUPSUpgradableContract<CType extends Contract>(deployer: SignerWithAddress, abiType: string, constructor: any[], initializer: any[], verify?: boolean, name?: string): Promise<{
  implementation: CType,
  proxy: CType
}> {
  name = name || abiType;
  console.log(`Deploying ${name}-implementation...`);
  const implementationFactory = await hre.ethers.getContractFactory(abiType);
  const implementation = await implementationFactory.connect(deployer).deploy(...constructor);
  await implementation.deployed();
  console.log(`${name}-implementation deployed at address: ${(await implementation).address}`);

  let initializeTx = (await implementation.populateTransaction.initialize(...initializer));

  console.log(`Deploying ${name}-proxy...`);
  const proxyFactory = await hre.ethers.getContractFactory("ERC1967Proxy");
  const proxy = await proxyFactory.deploy(implementation.address, initializeTx.data!);
  console.log(`${name}-proxy deployed at address: ${(await proxy).address}`);

  if (verify === true) { 
    console.log("Awaiting sufficient block confirmations before verifying...")
    await timeout(60000);
    console.log(`Verifying ${name}-implementation contract at ${implementation.address}...`)
    await verifyContract(implementation.address, constructor)

    console.log(`Verifying ${name}-proxy at ${proxy.address}`)
    await verifyContract(proxy.address, [implementation.address, initializeTx.data!]);
  }

  return {
    implementation: implementation as CType,
    proxy: await getContractAt<CType>(abiType, proxy.address)
  }
}

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  // let contract = await  deployUUPSUpgradableContract<TestContract>(deployer, "TestContract", [],[], true, "TestContract")

  let marketplaceContract = await  deployUUPSUpgradableContract<NiftyzoneMarketplace>(deployer, "NiftyzoneMarketplace", [],[["0x0CB481aa69B8eC20c5C9C4f8750370E1E59173ca"]], true, "NiftyzoneMarketplace");

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });