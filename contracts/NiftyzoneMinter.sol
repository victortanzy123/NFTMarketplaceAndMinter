// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// Royalties Standard - EIP2981:
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

// @dev: Contract used to add ERC2981 Support to ERC721 or ERC1155
abstract contract ERC2981Support is IERC2981, ERC165 {
  struct RoyaltyInfo {
    address recipient;
    uint24 amount;
  }

  // @inherit from ERC165:
  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC165, IERC165)
    returns (bool)
  {
    return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
  }
}

// Contract to extend functionality for minter to specify royalty for each tokenId minted:
abstract contract ERC2981RoyaltiesPerToken is ERC2981Support {
  // tokenId mapped to its individual specified royalty:
  mapping(uint256 => RoyaltyInfo) internal royalties;

  /// @dev Sets token royalties
  /// @param _tokenId the token id fir which we register the royalties
  /// @param _recipient recipient of the royalties
  /// @param _royaltyValue percentage (using 2 decimals - 10000 = 100, 0 = 0)
  function setTokenRoyalty(
    uint256 _tokenId,
    address _recipient,
    uint256 _royaltyValue
  ) internal {
    require(_royaltyValue <= 10000, "ERC2981Royalties: Invalid Range");
    royalties[_tokenId] = RoyaltyInfo(_recipient, uint24(_royaltyValue));
  }

  // @inherit from IERC2981:
  function royaltyInfo(uint256 _tokenId, uint256 _value)
    public
    view
    virtual
    override
    returns (address receiver, uint256 royaltyAmount)
  {
    RoyaltyInfo memory royalty = royalties[_tokenId];
    receiver = royalty.recipient;
    royaltyAmount = (_value * royalty.amount) / 10000;
  }
}

contract NiftyzoneMinter is ERC1155, Ownable, ERC2981RoyaltiesPerToken {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  string public name;
  string public symbol;

  mapping(uint256 => uint256) public tokenIdQuantityCount;
  mapping(uint256 => string) public tokenIdToURI;
  mapping(uint256 => address) public tokenCreator;
  mapping(uint256 => bool) public tokenUpdateAccess;

  // Event to track creator minting:
  event tokenCreation(
    uint256 indexed tokenId,
    uint256 timestamp,
    uint256 quantity,
    uint256 royaltyPercent,
    address royaltyAddr,
    address creator
  );

  event URIUpdate(uint256 indexed tokenId, string newUri, address submitter);

  constructor() ERC1155("") {
    name = "Niftyzone Collections";
    symbol = "NIFTYZONE COLLECTIONS";
  }

  // For marketplace creation of NFT:
  function createToken(
    string memory _tokenURI,
    uint256 _quantity,
    address _royaltyRecipient,
    uint256 _royaltyValue,
    bool _accessToUpdateToken
  ) external returns (uint256) {
    // Increment tokenId:
    _tokenIds.increment();

    uint256 currentTokenId = _tokenIds.current();

    // Update quantity count for tokenId created:
    tokenIdQuantityCount[currentTokenId] = _quantity;

    mint(msg.sender, currentTokenId, _quantity);
    tokenUpdateAccess[currentTokenId] = _accessToUpdateToken;
    tokenCreator[currentTokenId] = msg.sender;

    // Set metadata after minting:
    setURI(currentTokenId, _tokenURI);

    // Update Royalty Info if specified:
    if (_royaltyValue > 0) {
      setTokenRoyalty(currentTokenId, _royaltyRecipient, _royaltyValue);
    }

    emit tokenCreation(
      currentTokenId,
      block.timestamp,
      _quantity,
      _royaltyValue,
      _royaltyRecipient,
      msg.sender
    );

    // Return newItemId for frontend purposes:
    return currentTokenId;
  }

  function mint(
    address _to,
    uint256 _id,
    uint256 _amount
  ) private {
    _mint(_to, _id, _amount, "");
  }

  function setApprovalForAll(address operator, bool approved) public virtual override {
    _setApprovalForAll(_msgSender(), operator, approved);
  }

  function burn(uint256 _id, uint256 _amount) external {
    uint256 balanceOfOwner = balanceOf(msg.sender, _id);

    require(balanceOfOwner >= 1, "Invalid ownership balance.");
    require(balanceOfOwner <= _amount, "invalid amount specified.");
    _burn(msg.sender, _id, _amount);
  }

  function setURI(uint256 _id, string memory _uri) private {
    tokenIdToURI[_id] = _uri;
    emit URI(_uri, _id);
  }

  // One-way locking function to prevent editing access of tokenURI:
  function lockTokenUpdateAccess(uint256 _id) external {
    require(tokenCreator[_id] == msg.sender, "Unauthorised, not creator.");
    require(tokenUpdateAccess[_id], "Permissions already locked.");
    tokenUpdateAccess[_id] = false;
  }

  function overrideExistingURI(uint256 _id, string memory _uri) external onlyOwner {
    tokenIdToURI[_id] = _uri;
    emit URI(_uri, _id);
  }

  function overrideExistingURIByContractOwner(uint256 _id, string memory _newUri)
    external
    onlyOwner
  {
    require(tokenUpdateAccess[_id], "Permissions to update denied.");
    tokenIdToURI[_id] = _newUri;
    emit URIUpdate(_id, _newUri, msg.sender);
  }

  function overrideExistingURIByCreator(uint256 _id, string memory _newUri) external {
    require(msg.sender == tokenCreator[_id], "Unauthorised, not creator.");
    require(tokenUpdateAccess[_id], "Permissions to update denied.");
    tokenIdToURI[_id] = _newUri;
    emit URIUpdate(_id, _newUri, msg.sender);
  }

  function getTokenCreator(uint256 _tokenId) external view returns (address) {
    return tokenCreator[_tokenId];
  }

  function uri(uint256 _id) public view virtual override returns (string memory) {
    return tokenIdToURI[_id];
  }

  // Query current Royalty Structure for a specific tokenId:
  function royaltyInfo(uint256 _tokenId, uint256 _value)
    public
    view
    virtual
    override
    returns (address, uint256)
  {
    return super.royaltyInfo(_tokenId, _value);
  }

  /// @inheritdoc	ERC165
  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC1155, ERC2981Support)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }
}
