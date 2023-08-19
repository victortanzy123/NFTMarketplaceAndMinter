// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "../ERC1155/IERC1155CreatorBase.sol";

interface IArtzoneCreator is IERC1155CreatorBase {
  /**
   * @dev Event when a Token parameters are initialised.
   */
  event TokenInitialised(
    uint256 indexed tokenId,
    uint256 maxSupply,
    uint256 price,
    uint256 maxClaimPerUser,
    string tokenUri,
    address revenueReceipient
  );

  /**
   * @dev Event when an Initialised Token has been minted.
   */
  event TokenMint(
    uint256 indexed tokenId,
    uint256 amount,
    address receiver,
    address minter,
    uint256 value
  );

  /**
   * @dev Event when a revenue receipient of an initialised token has been updated.
   */
  event TokenRevenueReceipientUpdate(uint256 indexed tokenId, address revenueReceipient);

  /**
   * @dev Set the parameters for a tokenId - tokenUri and maximum amount to be minted.  Can only be called by owner/admin. Returns tokenId assigned.
   */
  function initialiseNewSingleToken(
    uint256 amount,
    uint256 price,
    uint256 maxClaimPerUser,
    string calldata uri,
    address revenueReceipient
  ) external returns (uint256);

  /**
   * @dev Set the parameters for multiple tokenIds - tokenUri and maximum amount to be minted.  Can only be called by owner/admin. Returns array of tokenIds assigned.
   */
  function initialiseNewMultipleTokens(
    uint256[] calldata amounts,
    uint256[] calldata prices,
    uint256[] calldata maxClaimPerUsers,
    string[] calldata uris,
    address[] calldata revenueReceipients
  ) external returns (uint256[] memory);

  /**
   * @dev Mints existing single token.  Can only be called by any user. Returns tokenId assigned.
   */
  function mintExistingSingleToken(
    address receiver,
    uint256 tokenId,
    uint256 amount
  ) external payable;

  /**
   * @dev Mints existing single token for owneself.  Can only be called by any user. Returns tokenId assigned.
   */
  function mintExistingSingleToken(uint256 tokenId, uint256 amount) external payable;

  /**
   * @dev Mints multiple tokens.  Can only be called by any user. Returns tokenId assigned.
   */
  function mintExistingMultipleTokens(
    address[] calldata receivers,
    uint256[] calldata tokenIds,
    uint256[] calldata amounts
  ) external payable;

  /**
   * @dev Mints multiple tokens for ownself.  Can only be called by any user. Returns tokenId assigned.
   */
  function mintExistingMultipleTokens(uint256[] calldata tokenIds, uint256[] calldata amounts)
    external
    payable;

  /**
   * @dev Update revenue receipient for an initialised token. Can only be called by Admin.
   */
  function updateTokenRevenueReceipient(uint256 tokenId, address newReceipient) external;

  /**
   * @dev Update Artzone Minter fee basis points for NFT minting sale. Can only be called by Admin.
   */
  function updateArtzoneFeeBps(uint256 bps) external;
}
