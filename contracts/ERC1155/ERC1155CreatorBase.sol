// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./ERC1155Core.sol";
import "./IERC1155CreatorBase.sol";

/**
 * @dev Implementation of the basic standard multi-token.
 * See https://eips.ethereum.org/EIPS/eip-1155
 * Originally based on code by Enjin: https://github.com/enjin/erc-1155
 *
 * _Available since v3.1._
 */
abstract contract ERC1155CreatorBase is ERC1155Core, IERC1155CreatorBase, ReentrancyGuard {
  using Strings for uint256;

  uint256 internal _tokenCount = 0;

  mapping(uint256 => TokenMetadataConfig) internal _tokenMetadata;

  bytes4 private constant ERC1155_CREATORBASE_V1 = 0x28f10a21;

  /**
   * External interface identifiers for royalties
   */

  /**
   *  @dev CreatorCore
   *
   *  bytes4(keccak256('getRoyalties(uint256)')) == 0xbb3bafd6
   *
   *  => 0xbb3bafd6 = 0xbb3bafd6
   */
  bytes4 private constant INTERFACE_ID_ROYALTIES_CREATORBASE = 0xbb3bafd6;

  /**
   *  @dev Rarible: RoyaltiesV1
   *
   *  bytes4(keccak256('getFeeRecipients(uint256)')) == 0xb9c4d9fb
   *  bytes4(keccak256('getFeeBps(uint256)')) == 0x0ebd4c7f
   *
   *  => 0xb9c4d9fb ^ 0x0ebd4c7f = 0xb7799584
   */
  bytes4 private constant INTERFACE_ID_ROYALTIES_RARIBLE = 0xb7799584;

  /**
   *  @dev Foundation
   *
   *  bytes4(keccak256('getFees(uint256)')) == 0xd5a06d4c
   *
   *  => 0xd5a06d4c = 0xd5a06d4c
   */
  bytes4 private constant INTERFACE_ID_ROYALTIES_FOUNDATION = 0xd5a06d4c;

  /**
   *  @dev EIP-2981
   *
   * bytes4(keccak256("royaltyInfo(uint256,uint256)")) == 0x2a55205a
   *
   * => 0x2a55205a = 0x2a55205a
   */
  bytes4 private constant INTERFACE_ID_ROYALTIES_EIP2981 = 0x2a55205a;

  modifier isExistingToken(uint256 tokenId) {
    require(tokenId > 0 && tokenId <= _tokenCount, "Invalid token");
    _;
  }

  modifier onlyTokenCreator(uint256 tokenId) {
    require(_tokenMetadata[tokenId].creator == msg.sender, "Not token creator");
    _;
  }

  /**
   * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
   */
  constructor(string memory name_, string memory symbol_) {
    _name = name_;
    _symbol = symbol_;
  }

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC1155Core, IERC165)
    returns (bool)
  {
    return
      interfaceId == type(IERC1155CreatorBase).interfaceId ||
      interfaceId == ERC1155_CREATORBASE_V1 ||
      super.supportsInterface(interfaceId) ||
      interfaceId == INTERFACE_ID_ROYALTIES_CREATORBASE ||
      interfaceId == INTERFACE_ID_ROYALTIES_RARIBLE ||
      interfaceId == INTERFACE_ID_ROYALTIES_FOUNDATION ||
      interfaceId == INTERFACE_ID_ROYALTIES_EIP2981;
  }

  /**
   * @dev See {IERC1155CreatorBase-updateTokenURI}.
   */
  function updateTokenURI(uint256 tokenId, string calldata uri) external virtual {
    _setTokenURI(tokenId, uri);
  }

  /**
   * @dev See {IERC1155CreatorBase-updateTokenClaimStatus}.
   */
  function updateTokenClaimStatus(uint256 tokenId, TokenClaimType claimStatus) external virtual {
    _setTokenClaimStatus(tokenId, claimStatus);
  }

  /**
   * @dev See {IERC1155CreatorBase-updateTokenURI}.
   */
  function setRoyalties(
    uint256 tokenId,
    address payable[] calldata receivers,
    uint256[] calldata basisPoints
  ) external virtual {
    _setRoyalties(tokenId, receivers, basisPoints);
  }

  /**
   * @dev Set token uri for an existing tokenId.
   */
  function _setTokenURI(uint256 tokenId, string calldata uri)
    internal
    virtual
    isExistingToken(tokenId)
  {
    _tokenMetadata[tokenId].uri = uri;

    emit URI(uri, tokenId);
  }

  /**
   * @dev Set new public mint price for an existing tokenId.
   */
  function _setTokenMintPrice(uint256 tokenId, uint256 newPrice)
    internal
    virtual
    isExistingToken(tokenId)
  {
    _tokenMetadata[tokenId].price = newPrice;
  }

  /**
   * @dev Set claim status for an existing tokenId.
   */
  function _setTokenClaimStatus(uint256 tokenId, TokenClaimType claimStatus)
    internal
    virtual
    isExistingToken(tokenId)
  {
    _tokenMetadata[tokenId].claimStatus = claimStatus;

    emit TokenClaimStatusUpdate(tokenId, claimStatus);
  }

  /**
   * @dev See {IERC1155MetadataURI-uri}.
   */
  function uri(uint256 id) external view returns (string memory tokenURI) {
    tokenURI = _tokenURI(id);
  }

  /**
   * @dev See {IERC1155CreatorBase-totalSupply}.
   */
  function totalSupply(uint256 tokenId)
    external
    view
    isExistingToken(tokenId)
    returns (uint256 totalSupply)
  {
    totalSupply = _tokenMetadata[tokenId].totalSupply;
  }

  /**
   * @dev See {IERC1155CreatorBase-maxSupply}.
   */
  function maxSupply(uint256 tokenId)
    external
    view
    isExistingToken(tokenId)
    returns (uint256 maxSupply)
  {
    maxSupply = _tokenMetadata[tokenId].maxSupply;
  }

  /**
   * @dev See {IERC1155CreatorBase-publicMintPrice}.
   */
  function publicMintPrice(uint256 tokenId)
    external
    view
    isExistingToken(tokenId)
    returns (uint256 mintPrice)
  {
    mintPrice = _tokenMetadata[tokenId].price;
  }

  /**
   * @dev See {IERC1155CreatorBase-publicMintPrice}.
   */
  function updateTokenMintPrice(uint256 tokenId, uint256 newPrice) external {
    _tokenMetadata[tokenId].price = newPrice;
  }

  /**
   * @dev See {IERC1155CreatorBase-tokenMetadata}.
   */
  function tokenMetadata(uint256 tokenId)
    external
    view
    isExistingToken(tokenId)
    returns (
      uint256 totalSupply,
      uint256 maxSupply,
      uint256 maxClaimPerUser,
      uint256 mintPrice,
      uint256 expiry,
      string memory uri,
      address creator,
      TokenClaimType claimStatus
    )
  {
    TokenMetadataConfig memory tokenMetadata = _tokenMetadata[tokenId];
    totalSupply = tokenMetadata.totalSupply;
    maxSupply = tokenMetadata.maxSupply;
    mintPrice = tokenMetadata.price;
    maxClaimPerUser = tokenMetadata.maxClaimPerUser;
    expiry = tokenMetadata.expiry;
    uri = tokenMetadata.uri;
    creator = tokenMetadata.creator;
    claimStatus = tokenMetadata.claimStatus;
  }

  /**
   * @dev Retrieve an existing token's URI
   */
  function _tokenURI(uint256 tokenId)
    internal
    view
    isExistingToken(tokenId)
    returns (string memory uri)
  {
    uri = _tokenMetadata[tokenId].uri;
  }

  /**
   * @dev See {ICreatorCore-getRoyalties}.
   */
  function getRoyalties(uint256 tokenId)
    external
    view
    virtual
    override
    returns (address payable[] memory, uint256[] memory)
  {
    return _getRoyalties(tokenId);
  }

  /**
   * @dev See {ICreatorCore-getFees}.
   */
  function getFees(uint256 tokenId)
    external
    view
    virtual
    override
    returns (address payable[] memory, uint256[] memory)
  {
    return _getRoyalties(tokenId);
  }

  /**
   * @dev See {ICreatorCore-getFeeRecipients}.
   */
  function getFeeRecipients(uint256 tokenId)
    external
    view
    virtual
    override
    returns (address payable[] memory)
  {
    return _getRoyaltyReceivers(tokenId);
  }

  /**
   * @dev See {ICreatorCore-getFeeBps}.
   */
  function getFeeBps(uint256 tokenId) external view virtual override returns (uint256[] memory) {
    return _getRoyaltyBPS(tokenId);
  }

  /**
   * @dev See {ICreatorCore-royaltyInfo}.
   */
  function royaltyInfo(uint256 tokenId, uint256 value)
    external
    view
    virtual
    override
    returns (address, uint256)
  {
    return _getRoyaltyInfo(tokenId, value);
  }

  /**
   * Helper to get royalties for a token
   */
  function _getRoyalties(uint256 tokenId)
    internal
    view
    isExistingToken(tokenId)
    returns (address payable[] memory receivers, uint256[] memory bps)
  {
    RoyaltyConfig[] memory royalties = _tokenMetadata[tokenId].royalties;

    if (royalties.length == 0) {
      receivers = new address payable[](1);
      receivers[0] = payable(address(0));
      bps = new uint256[](1);
      bps[0] = 0;
    }

    if (royalties.length > 0) {
      receivers = new address payable[](royalties.length);
      bps = new uint256[](royalties.length);
      for (uint256 i; i < royalties.length; ) {
        receivers[i] = royalties[i].receiver;
        bps[i] = royalties[i].bps;
        unchecked {
          ++i;
        }
      }
    }
  }

  /**
   * Helper to get royalty receivers for a token
   */
  function _getRoyaltyReceivers(uint256 tokenId)
    internal
    view
    returns (address payable[] memory recievers)
  {
    (recievers, ) = _getRoyalties(tokenId);
  }

  /**
   * Helper to get royalty basis points for a token
   */
  function _getRoyaltyBPS(uint256 tokenId) internal view returns (uint256[] memory bps) {
    (, bps) = _getRoyalties(tokenId);
  }

  function _getRoyaltyInfo(uint256 tokenId, uint256 value)
    internal
    view
    returns (address receiver, uint256 amount)
  {
    (address payable[] memory receivers, uint256[] memory bps) = _getRoyalties(tokenId);
    require(receivers.length <= 1, "More than 1 royalty receiver");

    if (receivers.length == 0) {
      return (address(this), 0);
    }
    return (receivers[0], (bps[0] * value) / 10000);
  }

  /**
   * Set royalties for a token
   */
  function _setRoyalties(
    uint256 tokenId,
    address payable[] calldata receivers,
    uint256[] calldata basisPoints
  ) internal {
    _checkRoyalties(receivers, basisPoints);
    delete _tokenMetadata[tokenId].royalties;
    _setRoyalties(receivers, basisPoints, _tokenMetadata[tokenId].royalties);
    emit RoyaltiesUpdated(tokenId, receivers, basisPoints);
  }

  /**
   * Helper function to set royalties
   */
  function _setRoyalties(
    address payable[] calldata receivers,
    uint256[] calldata basisPoints,
    RoyaltyConfig[] storage royalties
  ) private {
    for (uint256 i; i < basisPoints.length; ) {
      royalties.push(RoyaltyConfig({receiver: receivers[i], bps: uint16(basisPoints[i])}));
      unchecked {
        ++i;
      }
    }
  }

  /**
   * Helper function to check that royalties provided are valid
   */
  function _checkRoyalties(address payable[] calldata receivers, uint256[] calldata basisPoints)
    private
    pure
  {
    require(receivers.length == basisPoints.length, "Invalid receivers & bps input");

    uint256 totalBasisPoints;
    for (uint256 i; i < basisPoints.length; ) {
      totalBasisPoints += basisPoints[i];
      unchecked {
        ++i;
      }
    }
    require(totalBasisPoints < 10000, "Invalid total royalties");
  }
}
