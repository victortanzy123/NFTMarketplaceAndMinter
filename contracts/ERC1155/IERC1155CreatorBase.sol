// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "../Helpers/Royalties/IRoyalties.sol";

interface IERC1155CreatorBase is IRoyalties {
  struct RoyaltyConfig {
    address payable receiver;
    uint16 bps;
  }

  enum TokenClaimType {
    PUBLIC,
    ADMIN,
    DISABLED
  }

  struct TokenMetadataConfig {
    uint256 totalSupply;
    uint256 maxSupply;
    uint256 maxClaimPerUser;
    uint256 price;
    string uri;
    RoyaltyConfig[] royalties;
    TokenClaimType claimStatus;
  }

  event TokenClaimStatusUpdate(uint256 indexed tokenId, TokenClaimType claimStatus);

  /**
   * @dev Set secondary royalties configuration(s) for token by admin.
   */
  function setRoyalties(
    uint256 tokenId,
    address payable[] calldata receivers,
    uint256[] calldata basisPoints
  ) external;

  /**
   * @dev Update token uri after a token is minted by permissioned user.
   */
  function updateTokenURI(uint256 tokenId, string calldata uri) external;

  /**
   * @dev Toggle `claimable` flag for claiming of tokens
   */
  function updateTokenClaimStatus(uint256 tokenId, TokenClaimType claimStatus) external;

  /**
   * @dev Update token public minting price.
   */
  function updateTokenMintPrice(uint256 tokenId, uint256 newPrice) external;

  /**
   * @dev Total amount of tokens in with a given tokenId.
   */
  function totalSupply(uint256 tokenId) external view returns (uint256);

  /**
   * @dev Maximum amount of supply to be minted with a given tokenId.
   */
  function maxSupply(uint256 tokenId) external view returns (uint256);

  /**
   * @dev Price to mint a given initialised tokenId.
   */
  function publicMintPrice(uint256 tokenId) external view returns (uint256);

  /**
   * @dev Returns TokenMetadataConfig specified by a tokenId.
   */
  function tokenMetadata(uint256 tokenId)
    external
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256,
      string memory,
      TokenClaimType
    );
}
