export type RoyaltyConfig = {
  receiver: string;
  bps: number;
};

export type TokenMetadataConfig = {
  totalSupply: number;
  maxSupply: number;
  maxClaimPerUser: number;
  price: number;
  expiry: number;
  uri: string;
  creator: string;
  royalties: RoyaltyConfig[];
  claimStatus: number;
};
