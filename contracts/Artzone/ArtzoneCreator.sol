// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "../ERC1155/ERC1155CreatorBase.sol";
import "./IArtzoneCreator.sol";
import "../Helpers/Permissions/PermissionControl.sol";

contract ArtzoneCreator is ERC1155CreatorBase, IArtzoneCreator, PermissionControl {
  uint64 public constant MAX_BPS = 10_000;
  uint256 public ARTZONE_MINTER_FEE_BPS;

  mapping(uint256 => address) internal _tokenRevenueRecipient;

  constructor(
    string memory _name,
    string memory _symbol,
    uint256 feeBps_
  ) ERC1155CreatorBase(_name, _symbol) {
    ARTZONE_MINTER_FEE_BPS = feeBps_;
  }

  modifier checkTokenClaimable(uint256 tokenId, address user) {
    TokenClaimType claimStatus = _tokenMetadata[tokenId].claimStatus;
    if (isPermissionedUser(user)) {
      require(
        claimStatus == TokenClaimType.PUBLIC || claimStatus == TokenClaimType.ADMIN,
        "Token mint disabled"
      );
    } else {
      require(claimStatus == TokenClaimType.PUBLIC, "Token public mint disabled");
    }
    _;
  }

  /**
   * @dev See {IArtzoneCreator-initialiseNewSingleToken}.
   */
  function initialiseNewSingleToken(
    uint256 amount,
    uint256 price,
    string calldata uri,
    address revenueReceipient
  ) external onlyPermissionedUser returns (uint256 tokenId) {
    tokenId = _initialiseToken(amount, price, uri, revenueReceipient);
  }

  /**
   * @dev See {IArtzoneCreator-initialiseNewMultipleToken}.
   */
  function initialiseNewMultipleTokens(
    uint256[] calldata amounts,
    uint256[] calldata prices,
    string[] calldata uris,
    address[] calldata revenueReceipients
  ) external onlyPermissionedUser returns (uint256[] memory tokenIds) {
    require(
      amounts.length == prices.length &&
        prices.length == uris.length &&
        uris.length == revenueReceipients.length,
      "Invalid inputs"
    );
    uint256 length = amounts.length;
    tokenIds = new uint256[](length);

    for (uint256 i = 0; i < length; ) {
      uint256 tokenId = _initialiseToken(amounts[i], prices[i], uris[i], revenueReceipients[i]);
      tokenIds[i] = tokenId;
      unchecked {
        i++;
      }
    }
  }

  /**
   * @dev See {IArtzoneCreator-_initialiseToken}.
   */
  function _initialiseToken(
    uint256 amount,
    uint256 price,
    string calldata uri,
    address revenueReceipient
  ) internal returns (uint256 tokenId) {
    require(amount > 0, "Invalid amount");

    tokenId = ++_tokenCount;

    TokenMetadataConfig storage metadataConfig = _tokenMetadata[tokenId];
    metadataConfig.maxSupply = amount;
    metadataConfig.price = price;
    metadataConfig.uri = uri;
    metadataConfig.claimStatus = TokenClaimType.ADMIN;

    _tokenRevenueRecipient[tokenId] = revenueReceipient;

    emit TokenInitialised(tokenId, amount, price, uri, revenueReceipient);
  }

  /**
   * @dev See {IArtzoneCreator-mintExistingSingleToken}.
   */
  function mintExistingSingleToken(
    address receiver,
    uint256 tokenId,
    uint256 amount
  ) external payable onlyPermissionedUser {
    _mintExistingToken(tokenId, receiver, amount);
  }

  /**
   * @dev See {IArtzoneCreator-mintExistingSingleToken}.
   */
  function mintExistingSingleToken(uint256 tokenId, uint256 amount) external payable {
    _mintExistingToken(tokenId, msg.sender, amount);
  }

  /**
   * @dev See {IArtzoneCreator-mintExistingMultipleToken}.
   */
  function mintExistingMultipleTokens(
    address[] calldata receivers,
    uint256[] calldata tokenIds,
    uint256[] calldata amounts
  ) external payable onlyPermissionedUser {
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
    payable
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

    uint256 mintPrice = _tokenMetadata[tokenId].price;
    uint256 totalPayableAmount = 0;
    if (!isPermissionedUser(msg.sender) && mintPrice > 0) {
      totalPayableAmount = mintPrice * amount;
      require(msg.value == totalPayableAmount, "Unmatched value sent");

      uint256 artzoneFee = (totalPayableAmount * ARTZONE_MINTER_FEE_BPS) / MAX_BPS;
      payable(address(this)).transfer(artzoneFee);
      payable(_tokenRevenueRecipient[tokenId]).transfer(totalPayableAmount);
    }
    _tokenMetadata[tokenId].totalSupply += amount;

    emit TokenMint(tokenId, amount, receiver, msg.sender, totalPayableAmount);
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
   * @dev See {IArtzoneCreator-updateTokenRevenueReceipient}.
   */
  function updateTokenRevenueReceipient(uint256 tokenId, address newReceipient)
    external
    isExistingToken(tokenId)
    onlyPermissionedUser
  {
    require(newReceipient != address(0), "Null address");
    _tokenRevenueRecipient[tokenId] = newReceipient;

    emit TokenRevenueReceipientUpdate(tokenId, newReceipient);
  }

  /**
   * @dev See {IArtzoneCreator-updateArtzoneFeeBps}.
   */
  function updateArtzoneFeeBps(uint256 bps) external onlyPermissionedUser {
    require(bps < MAX_BPS, "Invalid basis points");
    ARTZONE_MINTER_FEE_BPS = bps;
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

  /// @dev Lets the contract receives native tokens from `nativeTokenWrapper` withdraw.
  receive() external payable {}
}
