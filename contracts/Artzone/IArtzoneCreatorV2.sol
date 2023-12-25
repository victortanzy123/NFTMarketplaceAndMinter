// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "../ERC1155/IERC1155CreatorBase.sol";

interface IArtzoneCreatorV2 is IERC1155CreatorBase {
  /**
   * @dev Event when a Token parameters are initialised.
   */
  event TokenInitialised(
    uint256 indexed tokenId,
    uint256 maxSupply,
    uint256 maxClaimPerUser,
    uint256 price,
    uint256 expiry,
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
  event TokenRevenueRecipientUpdate(uint256 indexed tokenId, address revenueReceipient);

  /**
   * @dev Event when a revenue receipient of an initialised token has been updated.
   */
  event TokenMintExpiryExtension(uint256 indexed tokenId, uint256 deadline);

  /**
   * @dev Set the parameters for a tokenId - tokenUri and maximum amount to be minted. Returns tokenId assigned. Can only be called by Admin.
   */
  function initialiseNewSingleToken(
    TokenMetadataConfig calldata tokenConfig
  ) external returns (uint256);

  /**
   * @dev Set the parameters for multiple tokenIds - tokenUri and maximum amount to be minted.  Can only be called by owner/admin. Returns array of tokenIds assigned.
   */
  function initialiseNewMultipleTokens(
    TokenMetadataConfig[] calldata tokenConfigs
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
   * @dev Mints multiple tokens.  Can only be called by any user. Returns tokenId assigned.
   */
  function mintExistingMultipleTokens(
    address[] calldata receivers,
    uint256[] calldata tokenIds,
    uint256[] calldata amounts
  ) external payable;

  /**
   * @dev Update revenue receipient for an initialised token. Can only be called by Admin.
   */
  function updateTokenRevenueRecipient(uint256 tokenId, address newReceipient) external;

  /**
   * @dev Update deadline for an initialised token. Deadline can only be prolonged, not reduced. Can only be called by Admin or creator.
   */
  function extendTokenMintExpiry(uint256 tokenId, uint256 newExpiry) external;

  /**
   * @dev Update Artzone Minter fee basis points for NFT minting sale. Can only be called by Admin.
   */
  function updateArtzoneFeeBps(uint256 bps) external;
}
