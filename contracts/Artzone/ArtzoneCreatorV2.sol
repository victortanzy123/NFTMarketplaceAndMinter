// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "../ERC1155/ERC1155CreatorBase.sol";
import "./IArtzoneCreatorV2.sol";
import "../Helpers/Permissions/PermissionControl.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ArtzoneCreatorV2 is
  ReentrancyGuard,
  ERC1155CreatorBase,
  IArtzoneCreatorV2,
  PermissionControl
{
  uint64 public constant MAX_BPS = 10_000;
  uint256 public ARTZONE_MINTER_FEE_BPS;

  mapping(uint256 => mapping(address => uint256)) internal _userTokenClaimCount;

  constructor(
    string memory name_,
    string memory symbol_,
    uint256 feeBps_
  ) ERC1155CreatorBase(name_, symbol_) {
    ARTZONE_MINTER_FEE_BPS = feeBps_;
  }

  modifier checkTokenClaimable(uint256 tokenId, address user) {
    TokenClaimType claimStatus = _tokenMetadata[tokenId].claimStatus;
    uint256 expiry = _tokenMetadata[tokenId].expiry;
    if (isPermissionedUser(user)) {
      require(
        claimStatus == TokenClaimType.PUBLIC || claimStatus == TokenClaimType.ADMIN,
        "Token mint disabled"
      );
    } else {
      require(claimStatus == TokenClaimType.PUBLIC, "Token public mint disabled");
    }
    require(expiry == 0 || expiry > block.timestamp, "Expired mint window");
    _;
  }

  /**
   * @dev See {IArtzoneCreator-initialiseNewSingleToken}.
   */
  function initialiseNewSingleToken(TokenMetadataConfig calldata tokenConfig)
    external
    returns (uint256 tokenId)
  {
    tokenId = _initialiseToken(tokenConfig);
  }

  /**
   * @dev See {IArtzoneCreator-initialiseNewMultipleToken}.
   */
  function initialiseNewMultipleTokens(TokenMetadataConfig[] calldata tokenConfigs)
    external
    returns (uint256[] memory tokenIds)
  {
    uint256 length = tokenConfigs.length;
    tokenIds = new uint256[](length);

    for (uint256 i = 0; i < length; ) {
      uint256 tokenId = _initialiseToken(tokenConfigs[i]);
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
  ) external payable {
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
   * @dev See {IArtzoneCreatorV2-initialiseAndMintNewSingleToken}.
   */
  function initialiseAndMintNewSingleToken(
    TokenMetadataConfig calldata tokenConfig,
    address receiver,
    uint256 amount
  ) external returns (uint256 tokenId) {
    tokenId = _initialiseToken(tokenConfig);
    _mintExistingToken(tokenId, receiver, amount);
  }

  /**
   * @dev Internal function to initialise a token via all the parameters of `TokenMetadataConfig` specified alongside with the `revenueRecipient` for mint fee collection.
   */
  function _initialiseToken(TokenMetadataConfig calldata tokenConfig)
    internal
    returns (uint256 tokenId)
  {
    require(tokenConfig.totalSupply == 0, "Initial total supply should be 0");
    require(tokenConfig.maxSupply > 0, "Invalid amount");
    require(tokenConfig.maxClaimPerUser > 0, "Invalid max claim quantity");
    require(
      tokenConfig.maxClaimPerUser <= tokenConfig.maxSupply,
      "Invalid individual claim quantity"
    );
    require(
      tokenConfig.expiry == 0 || tokenConfig.expiry > block.timestamp,
      "Invalid expiry timestamp"
    );

    tokenId = ++_tokenCount;
    _tokenMetadata[tokenId] = tokenConfig;

    emit TokenInitialised(
      tokenId,
      tokenConfig.maxSupply,
      tokenConfig.maxClaimPerUser,
      tokenConfig.price,
      tokenConfig.expiry,
      tokenConfig.uri,
      tokenConfig.creator
    );
  }

  /**
   * @dev Internal function to process minting of a valid `tokenId` with the specified `amount` and `receiver`.
   */
  function _mintExistingToken(
    uint256 tokenId,
    address receiver,
    uint256 amount
  ) internal nonReentrant checkTokenClaimable(tokenId, msg.sender) {
    require(amount > 0, "Amount be at least one");
    require(tokenId <= _tokenCount, "Invalid tokenId specified");
    require(
      _tokenMetadata[tokenId].totalSupply + amount <= _tokenMetadata[tokenId].maxSupply,
      "Invalid amount specified"
    );
    require(
      _userTokenClaimCount[tokenId][receiver] + amount <= _tokenMetadata[tokenId].maxClaimPerUser,
      "Exceed token max claim limit"
    );

    _tokenMetadata[tokenId].totalSupply += amount;
    _userTokenClaimCount[tokenId][receiver] += amount;
    _mint(receiver, tokenId, amount, "");

    emit TokenMint(tokenId, amount, receiver, msg.sender, _tokenMetadata[tokenId].price * amount);
  }

  /**
   * @dev Internal function to handle multiple processing of mint fees when `mintExistingMultipleTokens` is called via a non-permissioned user.
   */
  function _batchProcessMintFees(uint256[] calldata tokenIds, uint256[] memory payableAmounts)
    internal
  {
    for (uint256 i = 0; i < tokenIds.length; ) {
      if (payableAmounts[i] > 0) {
        _processMintFees(tokenIds[i], payableAmounts[i]);
      }
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
    payable(_tokenMetadata[tokenId].creator).transfer(totalPayableAmount - artzoneFee);
  }

  /**
   * @dev Set token uri after a token is minted by permissioned user from Artzone.
   */
  function updateTokenURI(uint256 tokenId, string calldata uri)
    external
    override(ERC1155CreatorBase, IERC1155CreatorBase)
    onlyPermissionedUser
  {
    _setTokenURI(tokenId, uri);
  }

  /**
   * @dev Set token uri after a token is minted by permissioned user from Artzone.
   */
  function updateTokenClaimStatus(uint256 tokenId, TokenClaimType claimStatus)
    external
    override(ERC1155CreatorBase, IERC1155CreatorBase)
    onlyPermissionedUser
  {
    _setTokenClaimStatus(tokenId, claimStatus);
  }

  /**
   * @dev Set secondary royalties for a particular tokenId by current registered creator.
   */
  function setRoyalties(
    uint256 tokenId,
    address payable[] calldata receivers,
    uint256[] calldata basisPoints
  ) external override(ERC1155CreatorBase, IERC1155CreatorBase) onlyTokenCreator(tokenId) {
    _setRoyalties(tokenId, receivers, basisPoints);
  }

  /**
   * @dev Admin manual override for secondary royalties for a particular tokenId.
   */
  function adminOverrideRoyalties(
    uint256 tokenId,
    address payable[] calldata receivers,
    uint256[] calldata basisPoints
  ) external onlyPermissionedUser {
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
    _tokenMetadata[tokenId].creator = newRecipient;

    emit TokenRevenueRecipientUpdate(tokenId, newRecipient);
  }

  /**
   * @dev See {IArtzoneCreator-extendTokenMintExpiry}.
   */
  function extendTokenMintExpiry(uint256 tokenId, uint256 newExpiry)
    external
    isExistingToken(tokenId)
    onlyPermissionedUser
  {
    uint256 currentExpiry = _tokenMetadata[tokenId].expiry;
    require(currentExpiry != 0, "No expiry initialised.");
    require(
      newExpiry == 0 || newExpiry > currentExpiry,
      "Invalid new expiry, only extension allowed."
    );
    _tokenMetadata[tokenId].expiry = newExpiry;

    emit TokenMintExpiryExtension(tokenId, newExpiry);
  }

  /**
   * @dev See {IArtzoneCreator-updateArtzoneFeeBps}.
   */
  function updateArtzoneFeeBps(uint256 bps) external onlyPermissionedUser {
    require(bps < MAX_BPS, "Invalid basis points");
    ARTZONE_MINTER_FEE_BPS = bps;
  }

  /**
   * @dev See {IArtzoneCreator-updateArtzoneFeeBps}.
   */
  function tokenAmountClaimedByUser(uint256 tokenId, address recipient)
    external
    view
    returns (uint256)
  {
    return _userTokenClaimCount[tokenId][recipient];
  }

  /**
   * @dev See {IArtzoneCreator-tokenMintExpiry}.
   */
  function tokenMintExpiry(uint256 tokenId) external view returns (uint256) {
    return _tokenMetadata[tokenId].expiry;
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
      super.supportsInterface(interfaceId) ||
      ERC1155CreatorBase.supportsInterface(interfaceId) ||
      PermissionControl.supportsInterface(interfaceId);
  }

  /**
   * @dev See {IArtzoneCreator-withdraw}.
   */
  function withdraw(address recipient) external payable onlyOwner {
    payable(recipient).transfer(address(this).balance);
  }

  /// @dev Lets the contract receives native tokens from `nativeTokenWrapper` withdraw.
  receive() external payable {}
}
