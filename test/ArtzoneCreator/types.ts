export type RoyaltyConfig = {
    receiver: string;
    bps: number;
}

export type TokenMetadataConfig =  {
    totalSupply: number;
    maxSupply: number;
    maxClaimPerUser: number;
    price: number;
    uri: string;
    royalties: RoyaltyConfig[];
    claimStatus: number;
}