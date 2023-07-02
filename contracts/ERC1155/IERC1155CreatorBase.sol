// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "../Helpers/Royalties/IRoyalties.sol";

interface IERC1155CreatorBase is IRoyalties {
  /**
   * @dev Update token uri after a token is minted by permissioned user.
   */
  function updateTokenURI(uint256 tokenId, string calldata uri) external;

  /**
   * @dev Total amount of tokens in with a given tokenId.
   */
  function totalSupply(uint256 tokenId) external view returns (uint256);
}
