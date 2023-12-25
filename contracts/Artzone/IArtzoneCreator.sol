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
    uint256 expiry,
    string tokenUri,
    address revenueRecipient
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
   * @dev Event when a revenue recipient of an initialised token has been updated.
   */
  event TokenRevenueRecipientUpdate(uint256 indexed tokenId, address revenueRecipient);

  /**
   * @dev Set the parameters for a tokenId - tokenUri and maximum amount to be minted. Returns tokenId assigned. Can only be called by Admin.
   */
  function initialiseNewSingleToken(
    TokenMetadataConfig calldata tokenConfig,
    address revenueRecipient,
    uint256 expiry
  ) external returns (uint256);

  /**
   * @dev Set the parameters for multiple tokenIds - tokenUri and maximum amount to be minted.  Can only be called by owner/admin. Returns array of tokenIds assigned.
   */
  function initialiseNewMultipleTokens(
    TokenMetadataConfig[] calldata tokenConfigs,
    address[] calldata revenueRecipients
  ) external returns (uint256[] memory);

  /**
   * @dev Mints existing single token.  Can be called by any user. Returns tokenId assigned.
   */
  function mintExistingSingleToken(
    address receiver,
    uint256 tokenId,
    uint256 amount
  ) external payable;

  /**
   * @dev Mints multiple tokens.  Can be called by any user. Returns tokenId assigned.
   */
  function mintExistingMultipleTokens(
    address[] calldata receivers,
    uint256[] calldata tokenIds,
    uint256[] calldata amounts
  ) external payable;

  /**
   * @dev Returns the total quantity claimed by a user for a token.
   */
  function tokenAmountClaimedByUser(uint256 tokenId, address recipient)
    external
    view
    returns (uint256);

  /**
   * @dev Returns the timestamp of the token mint expiry based on tokenId specified.
   */
  function tokenMintExpiry(uint256 tokenId) external view returns (uint256);

  /**
   * @dev Update revenue recipient for an initialised token. Can only be called by Admin.
   */
  function updateTokenRevenueRecipient(uint256 tokenId, address newRecipient) external;

  /**
   * @dev Update Artzone Minter fee basis points for NFT minting sale. Can only be called by Admin.
   */
  function updateArtzoneFeeBps(uint256 bps) external;

  /**
   * @dev Withdraw function to withdraw fees collected from each paid NFT mint by public users to a specified recipient. To only be called by Admin.
   */
  function withdraw(address recipient) external payable;
}
