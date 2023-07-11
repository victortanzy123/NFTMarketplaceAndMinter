// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "../ERC1155/ERC1155CreatorBase.sol";
import "./IArtzoneCreator.sol";
import "../Helpers/Permissions/PermissionControl.sol";

contract ArtzoneCreator is ERC1155CreatorBase, IArtzoneCreator, PermissionControl {
  constructor(string memory _name, string memory _symbol) ERC1155CreatorBase(_name, _symbol) {}

  modifier checkTokenClaimable(uint256 tokenId, address user) {
    TokenClaimType claimStatus = _tokenMetadata[tokenId].claimStatus;
    if (isPermissionedUser(user)) {
      require(
        claimStatus == TokenClaimType.PUBLIC || claimStatus == TokenClaimType.ADMIN,
        "Token claim disabled"
      );
    } else {
      require(claimStatus == TokenClaimType.PUBLIC, "Public token claim disabled");
    }
    _;
  }

  /**
   * @dev See {IArtzoneCreator-initialiseNewSingleToken}.
   */
  function initialiseNewSingleToken(uint256 amount, string calldata uri)
    external
    onlyPermissionedUser
    returns (uint256 tokenId)
  {
    tokenId = _initialiseToken(amount, uri);
  }

  /**
   * @dev See {IArtzoneCreator-initialiseNewMultipleToken}.
   */
  function initialiseNewMultipleTokens(uint256[] calldata amounts, string[] calldata uris)
    external
    onlyPermissionedUser
    returns (uint256[] memory tokenIds)
  {
    require(amounts.length == uris.length, "Invalid inputs");
    uint256 length = amounts.length;
    tokenIds = new uint256[](length);

    for (uint256 i = 0; i < length; ) {
      uint256 tokenId = _initialiseToken(amounts[i], uris[i]);
      tokenIds[i] = tokenId;
      unchecked {
        i++;
      }
    }
  }

  /**
   * @dev See {IArtzoneCreator-_initialiseToken}.
   */
  function _initialiseToken(uint256 amount, string calldata uri)
    internal
    returns (uint256 tokenId)
  {
    require(amount > 0, "Invalid amount");

    tokenId = ++_tokenCount;

    TokenMetadataConfig storage metadataConfig = _tokenMetadata[tokenId];
    metadataConfig.maxSupply = amount;
    metadataConfig.uri = uri;
    metadataConfig.claimStatus = TokenClaimType.ADMIN;

    emit TokenInitialised(tokenId, amount, uri, msg.sender);
  }

  /**
   * @dev See {IArtzoneCreator-initialiseAndMintNewSingleToken}.
   */
  function initialiseAndMintNewSingleToken(
    address receiver,
    uint256 maxAmount,
    uint256 mintAmount,
    string calldata uri
  ) external onlyPermissionedUser returns (uint256 tokenId) {
    require(mintAmount <= maxAmount, "Mint amount must be less or equal to maxAmount");
    tokenId = _initialiseToken(maxAmount, uri);
    _mintExistingToken(tokenId, receiver, mintAmount);
  }

  /**
   * @dev See {IArtzoneCreator-initialiseAndMintNewMultipleToken}.
   */
  function initialiseAndMintNewMultipleTokens(
    address[] calldata receivers,
    uint256[] calldata maxAmounts,
    uint256[] calldata mintAmounts,
    string[] calldata uris
  ) external onlyPermissionedUser returns (uint256[] memory tokenIds) {
    require(
      receivers.length == maxAmounts.length &&
        maxAmounts.length == mintAmounts.length &&
        mintAmounts.length == uris.length,
      "Invalid inputs"
    );
    uint256 length = receivers.length;
    tokenIds = new uint256[](length);

    for (uint256 i = 0; i < length; ) {
      uint256 tokenId = _initialiseToken(maxAmounts[i], uris[i]);
      _mintExistingToken(tokenId, receivers[i], mintAmounts[i]);
      tokenIds[i] = tokenId;

      unchecked {
        i++;
      }
    }
  }

  /**
   * @dev See {IArtzoneCreator-mintExistingSingleToken}.
   */
  function mintExistingSingleToken(
    address receiver,
    uint256 tokenId,
    uint256 amount
  ) external onlyPermissionedUser {
    _mintExistingToken(tokenId, receiver, amount);
  }

  /**
   * @dev See {IArtzoneCreator-mintExistingSingleToken}.
   */
  function mintExistingSingleToken(uint256 tokenId, uint256 amount)
    external
    checkTokenClaimable(tokenId, msg.sender)
  {
    _mintExistingToken(tokenId, msg.sender, amount);
  }

  /**
   * @dev See {IArtzoneCreator-mintExistingMultipleToken}.
   */
  function mintExistingMultipleTokens(
    address[] calldata receivers,
    uint256[] calldata tokenIds,
    uint256[] calldata amounts
  ) external onlyPermissionedUser {
    require(
      receivers.length == tokenIds.length && tokenIds.length == amounts.length,
      "Invalid inputs"
    );
    uint256 length = receivers.length;

    for (uint256 i = 0; i < length; ) {
      _mintExistingToken(tokenIds[i], receivers[i], amounts[i]);
      unchecked {
        i++;
      }
    }
  }

  /**
   * @dev See {IArtzoneCreator-mintExistingMultipleToken}.
   */
  function mintExistingMultipleTokens(uint256[] calldata tokenIds, uint256[] calldata amounts)
    external
    onlyPermissionedUser
  {
    require(tokenIds.length == amounts.length, "Invalid inputs");
    uint256 length = tokenIds.length;

    for (uint256 i = 0; i < length; ) {
      _mintExistingToken(tokenIds[i], msg.sender, amounts[i]);
      unchecked {
        i++;
      }
    }
  }

  /**
   * @dev See {IArtzoneCreator-_mintExistingToken}.
   */
  function _mintExistingToken(
    uint256 tokenId,
    address receiver,
    uint256 amount
  ) internal checkTokenClaimable(tokenId, msg.sender) {
    require(tokenId <= _tokenCount, "Invalid tokenId specified");
    require(amount > 0, "Invalid mint amount specified");
    require(
      _tokenMetadata[tokenId].totalSupply + amount <= _tokenMetadata[tokenId].maxSupply,
      "Invalid amount specified"
    );

    _tokenMetadata[tokenId].totalSupply += amount;
    _mint(receiver, tokenId, amount, "");

    emit TokenMint(tokenId, amount, receiver, msg.sender);
  }

  /**
   * @dev Set token uri after a token is minted by permissioned user.
   */
  function updateTokenURI(uint256 tokenId, string calldata uri)
    external
    virtual
    override(ERC1155CreatorBase, IERC1155CreatorBase)
    onlyPermissionedUser
  {
    _setTokenURI(tokenId, uri);
  }

  /**
   * @dev Set token uri after a token is minted by permissioned user.
   */
  function updateTokenClaimStatus(uint256 tokenId, TokenClaimType claimStatus)
    external
    virtual
    override(ERC1155CreatorBase, IERC1155CreatorBase)
    onlyPermissionedUser
  {
    _setTokenClaimStatus(tokenId, claimStatus);
  }

  /**
   * @dev Set secondary royalties for a particular tokenId by permissioned user.
   */
  function setRoyalties(
    uint256 tokenId,
    address payable[] calldata receivers,
    uint256[] calldata basisPoints
  ) external override(ERC1155CreatorBase, IERC1155CreatorBase) onlyPermissionedUser {
    _setRoyalties(tokenId, receivers, basisPoints);
  }

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC1155CreatorBase, PermissionControl, IERC165)
    returns (bool)
  {
    return
      ERC1155CreatorBase.supportsInterface(interfaceId) ||
      PermissionControl.supportsInterface(interfaceId);
  }
}
