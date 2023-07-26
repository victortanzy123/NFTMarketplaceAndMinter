// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "../ERC1155/ERC1155CreatorBase.sol";
import "./IArtzoneCreator.sol";
import "../Helpers/Permissions/PermissionControl.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ArtzoneCreator is
  ReentrancyGuard,
  ERC1155CreatorBase,
  IArtzoneCreator,
  PermissionControl
{
  uint64 public constant MAX_BPS = 10_000;
  uint256 public ARTZONE_MINTER_FEE_BPS;

  mapping(uint256 => address) internal _tokenRevenueRecipient;

  constructor(
    string memory name_,
    string memory symbol_,
    uint256 feeBps_
  ) ERC1155CreatorBase(name_, symbol_) {
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
    address revenueRecipient
  ) external onlyPermissionedUser returns (uint256 tokenId) {
    tokenId = _initialiseToken(amount, price, uri, revenueRecipient);
  }

  /**
   * @dev See {IArtzoneCreator-initialiseNewMultipleToken}.
   */
  function initialiseNewMultipleTokens(
    uint256[] calldata amounts,
    uint256[] calldata prices,
    string[] calldata uris,
    address[] calldata revenueRecipients
  ) external onlyPermissionedUser returns (uint256[] memory tokenIds) {
    require(
      amounts.length == prices.length &&
        prices.length == uris.length &&
        uris.length == revenueRecipients.length,
      "Invalid inputs"
    );
    uint256 length = amounts.length;
    tokenIds = new uint256[](length);

    for (uint256 i = 0; i < length; ) {
      uint256 tokenId = _initialiseToken(amounts[i], prices[i], uris[i], revenueRecipients[i]);
      tokenIds[i] = tokenId;
      unchecked {
        i++;
      }
    }
  }

  /**
   * @dev Internal function to initialise a token via all the parameters of `TokenMetadataConfig` specified alongside with the `revenueRecipient` for mint fee collection.
   */
  function _initialiseToken(
    uint256 amount,
    uint256 price,
    string calldata uri,
    address revenueRecipient
  ) internal returns (uint256 tokenId) {
    require(revenueRecipient != address(0), "Null address");
    require(amount > 0, "Invalid amount");

    tokenId = ++_tokenCount;

    TokenMetadataConfig storage metadataConfig = _tokenMetadata[tokenId];
    metadataConfig.maxSupply = amount;
    metadataConfig.price = price;
    metadataConfig.uri = uri;
    metadataConfig.claimStatus = TokenClaimType.ADMIN;

    _tokenRevenueRecipient[tokenId] = revenueRecipient;

    emit TokenInitialised(tokenId, amount, price, uri, revenueRecipient);
  }

  /**
   * @dev See {IArtzoneCreator-mintExistingSingleToken}.
   */
  function mintExistingSingleToken(
    address receiver,
    uint256 tokenId,
    uint256 amount
  ) external payable {
    require(amount > 0, "Invalid amount");
    if (!isPermissionedUser(msg.sender) && _tokenMetadata[tokenId].price > 0) {
      uint256 totalPayableAmount = _tokenMetadata[tokenId].price * amount;
      require(msg.value == totalPayableAmount, "Unmatched value sent");
      _processMintFees(tokenId, totalPayableAmount);
    }
    _mintExistingToken(tokenId, receiver, amount);
  }

  /**
   * @dev See {IArtzoneCreator-mintExistingMultipleToken}.
   */
  function mintExistingMultipleTokens(
    address[] calldata receivers,
    uint256[] calldata tokenIds,
    uint256[] calldata amounts
  ) external payable {
    require(
      receivers.length == tokenIds.length && tokenIds.length == amounts.length,
      "Invalid inputs"
    );
    uint256 length = receivers.length;

    if (!isPermissionedUser(msg.sender)) {
      uint256 totalPayableAmount;
      uint256[] memory payableAmounts = new uint256[](length);
      for (uint256 i = 0; i < length; ) {
        uint256 payableAmount = _tokenMetadata[tokenIds[i]].price * amounts[i];
        totalPayableAmount += payableAmount;
        payableAmounts[i] = payableAmount;
        unchecked {
          i++;
        }
      }
      require(msg.value == totalPayableAmount, "Unmatched value sent");
      _batchProcessMintFees(tokenIds, payableAmounts);
    }

    for (uint256 i = 0; i < length; ) {
      require(amounts[i] > 0, "Invalid amount");
      _mintExistingToken(tokenIds[i], receivers[i], amounts[i]);
      unchecked {
        i++;
      }
    }
  }

  /**
   * @dev Internal function to process minting of a valid `tokenId` with the specified `amount` and `receiver`.
   */
  function _mintExistingToken(
    uint256 tokenId,
    address receiver,
    uint256 amount
  ) internal nonReentrant checkTokenClaimable(tokenId, msg.sender) {
    require(tokenId <= _tokenCount, "Invalid tokenId specified");
    require(
      _tokenMetadata[tokenId].totalSupply + amount <= _tokenMetadata[tokenId].maxSupply,
      "Invalid amount specified"
    );

    _mint(receiver, tokenId, amount, "");
    _tokenMetadata[tokenId].totalSupply += amount;

    emit TokenMint(tokenId, amount, receiver, msg.sender, _tokenMetadata[tokenId].price * amount);
  }

  /**
   * @dev Internal function to handle multiple processing of mint fees when `mintExistingMultipleTokens` is called via a non-permissioned user.
   */
  function _batchProcessMintFees(uint256[] calldata tokenIds, uint256[] memory payableAmounts)
    internal
  {
    for (uint256 i = 0; i < tokenIds.length; ) {
      _processMintFees(tokenIds[i], payableAmounts[i]);
      unchecked {
        i++;
      }
    }
  }

  /**
   * @dev Internal function to process mint fees and transfer outstanding payable revenue to `revenueRecipient` after deducting from Artzone's fee cut portion.
   */
  function _processMintFees(uint256 tokenId, uint256 totalPayableAmount) internal nonReentrant {
    uint256 artzoneFee = (totalPayableAmount * ARTZONE_MINTER_FEE_BPS) / MAX_BPS;
    payable(_tokenRevenueRecipient[tokenId]).transfer(totalPayableAmount - artzoneFee);
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
   * @dev See {IArtzoneCreator-updateTokenRevenueRecipient}.
   */
  function updateTokenRevenueRecipient(uint256 tokenId, address newRecipient)
    external
    isExistingToken(tokenId)
    onlyPermissionedUser
  {
    require(newRecipient != address(0), "Null address");
    _tokenRevenueRecipient[tokenId] = newRecipient;

    emit TokenRevenueRecipientUpdate(tokenId, newRecipient);
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

  /**
   * @dev See {IArtzoneCreator-withdraw}.
   */
  function withdraw(address recipient) external payable onlyPermissionedUser {
    payable(recipient).transfer(address(this).balance);
  }

  /// @dev Lets the contract receives native tokens from `nativeTokenWrapper` withdraw.
  receive() external payable {}
}
