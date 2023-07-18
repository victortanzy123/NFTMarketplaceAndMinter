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
    string tokenUri,
    address
  );

  /**
   * @dev Event when an Initialised Token has been minted.
   */
  event TokenMint(uint256 indexed tokenId, uint256 amount, address receiver, address minter);

  /**
   * @dev Set the parameters for a tokenId - tokenUri and maximum amount to be minted.  Can only be called by owner/admin. Returns tokenId assigned.
   */
  function initialiseNewSingleToken(
    uint256 amount,
    uint256 price,
    string calldata uri
  ) external returns (uint256);

  /**
   * @dev Set the parameters for multiple tokenIds - tokenUri and maximum amount to be minted.  Can only be called by owner/admin. Returns array of tokenIds assigned.
   */
  function initialiseNewMultipleTokens(
    uint256[] calldata amounts,
    uint256[] calldata prices,
    string[] calldata uris
  ) external returns (uint256[] memory);

  /**
   * @dev Initialise and mints a single token.  Can only be called by owner/admin. Returns tokenId assigned.
   */
  function initialiseAndMintNewSingleToken(
    address receiver,
    uint256 maxAmount,
    uint256 price,
    uint256 mintAmount,
    string calldata uri
  ) external returns (uint256);

  /**
   * @dev Initialise and mints multiple tokens.  Can only be called by owner/admin. Returns array of tokenIds assigned.
   */
  function initialiseAndMintNewMultipleTokens(
    address[] calldata receivers,
    uint256[] calldata maxAmounts,
    uint256[] calldata prices,
    uint256[] calldata mintAmounts,
    string[] calldata uris
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
   * @dev Returns the total revenue collected from public minting of a tokenId.
   */
  function revenue(uint256 tokenId) external view returns (uint256);

  /**
   * @dev Withdraws total accumulated revenue by public minting of an existing token.  Can only be called by permissioned user.
   */
  function withdrawTokenRevenue(uint256 tokenId, address payable receiver) external payable;
}
