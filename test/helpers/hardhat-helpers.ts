import hre, {ethers} from 'hardhat';
import {assert} from 'console';
import {BigNumber as BN, BigNumberish, Contract, Wallet} from 'ethers';

export async function impersonateAccount(address: string) {
  await hre.network.provider.request({
    method: 'hardhat_impersonateAccount',
    params: [address],
  });
}

export async function impersonateAccountStop(address: string) {
  await hre.network.provider.request({
    method: 'hardhat_stopImpersonatingAccount',
    params: [address],
  });
}

export async function evm_snapshot() {
  return (await hre.network.provider.request({
    method: 'evm_snapshot',
    params: [],
  })) as string;
}

export async function evm_revert(snapshotId: string) {
  return (await hre.network.provider.request({
    method: 'evm_revert',
    params: [snapshotId],
  })) as string;
}

export async function toNumber(bn: BigNumberish) {
  return BN.from(bn).toNumber();
}

export async function advanceTime(duration: BigNumberish) {
  await hre.network.provider.send('evm_increaseTime', [await toNumber(duration)]);
  await hre.network.provider.send('evm_mine', []);
}

export async function setNextBlockTimeStamp(time: BigNumberish) {
  await hre.network.provider.send('evm_setNextBlockTimestamp', [await toNumber(time)]);
}

export async function setTimeStamp(time: BigNumberish) {
  await hre.network.provider.send('evm_setNextBlockTimestamp', [await toNumber(time)]);
  await hre.network.provider.send('evm_mine', []);
}

export async function moveToTimestamp(time: BigNumberish) {
  await hre.network.provider.send('evm_setNextBlockTimestamp', [await toNumber(time)]);
  await hre.network.provider.send('evm_mine', []);
}

export async function advanceTimeAndBlock(time: BigNumberish, blockCount: number) {
  assert(blockCount >= 1);
  await advanceTime(time);
  await mineBlock(blockCount - 1);
}

export async function mineAllPendingTransactions() {
  let pendingBlock: any = await hre.network.provider.send('eth_getBlockByNumber', ['pending', false]);
  await mineBlock();
  pendingBlock = await hre.network.provider.send('eth_getBlockByNumber', ['pending', false]);
  assert(pendingBlock.transactions.length == 0);
}

export async function mineBlock(count?: number) {
  if (count == null) count = 1;
  while (count-- > 0) {
    await hre.network.provider.send('evm_mine', []);
  }
}

export async function minerStart() {
  await hre.network.provider.send('evm_setAutomine', [true]);
}

export async function minerStop() {
  await hre.network.provider.send('evm_setAutomine', [false]);
}

export async function getEth(user: string) {
  await hre.network.provider.send('hardhat_setBalance', [user, '0x56bc75e2d63100000000000000']);
}

export async function deploy<CType extends Contract>(abiType: string, args: any[], verify?: boolean, name?: string) {
  name = name || abiType;
  console.log(`Deploying ${name}...`);
  const contractFactory = await hre.ethers.getContractFactory(abiType);
  const contract = await contractFactory.deploy(...args);
  await contract.deployed();
  console.log(`${name} deployed at address: ${(await contract).address}`);

  if (verify === true) {
    await verifyContract(contract.address, args);
  }
  return contract as CType;
}

export async function verifyContract(contract: string, constructor: any[]) {
  await hre.run('verify:verify', {
    address: contract,
    constructorArguments: constructor,
  });
}

export async function getContractAt<CType extends Contract>(abiType: string, address: string) {
  return (await hre.ethers.getContractAt(abiType, address)) as CType;
}

export function toWei(amount: number, decimals: number) {
  return BN.from(amount).mul(BN.from(10).pow(decimals));
}
