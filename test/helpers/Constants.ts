import { BigNumber, constants } from "ethers";

export const _1E18 = BigNumber.from(10).pow(18);
export const ZERO_ADDRESS = constants.AddressZero;
export const ZERO = constants.Zero;
export const ONE = constants.One;
export const TWO = constants.Two;
export const PRECISION = constants.WeiPerEther;
export const ONE_DAY = BigNumber.from(86400);
export const ONE_WEEK = ONE_DAY.mul(7);
export const ONE_MONTH = ONE_DAY.mul(31);
export const ONE_YEAR = ONE_DAY.mul(365);
export const MAX_UINT_96 = TWO.pow(96).sub(ONE);
export const MAX_UINT = constants.MaxUint256;
export const INF = BigNumber.from(2).pow(256).sub(1);
