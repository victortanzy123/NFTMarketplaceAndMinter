// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../Helpers/BoringOwnableUpgradeable.sol";
import "./NiftyzoneMinterV2.sol";

// Proxy Configurations:
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract NiftyzoneMinterUpgradeable is
  ERC1155Upgradeable,
  BoringOwnableUpgradeable,
  NiftyzoneMinter,
  UUPSUpgradeable
{
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  string public constant name = "Niftyzone Collections";
  string public constant symbol = "NIFTYZONE COLLECTIONS";

  uint256 private constant VERSION = 2;

  /*///////////////////////////////////////////////////////////////
                            Initializer
    //////////////////////////////////////////////////////////////*/

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {}

  /**
   * Initializer
   */
  function initialize() external initializer {
    __ERC1155_init("");
    __BoringOwnable_init();
  }

    /*///////////////////////////////////////////////////////////////
                            Main Functions
    //////////////////////////////////////////////////////////////*/

  function createToken(
    string memory _tokenURI,
    uint256 _quantity,
    address _royaltyRecipient,
    uint256 _royaltyValue,
    bool _accessToUpdateToken
  ) external returns (uint256) {
    // Increment tokenId:
    _tokenIds.increment();

    uint256 curTokenId = _tokenIds.current();

    // Update quantity count for tokenId created:
    _tokenIdSupply[curTokenId] = _quantity;

    _mint(msg.sender, curTokenId, _quantity, "");
    _tokenUpdateAccess[curTokenId] = _accessToUpdateToken;
    _tokenCreator[curTokenId] = msg.sender;

    // Set metadata after minting:
    _setUri(curTokenId, _tokenURI);

    // Update Royalty Info if specified:
    if (_royaltyValue > 0) {
      setTokenRoyalty(curTokenId, _royaltyRecipient, _royaltyValue);
    }

    emit TokenCreation(
      curTokenId,
      block.timestamp,
      _quantity,
      _royaltyValue,
      _royaltyRecipient,
      msg.sender
    );

    // Return newItemId for frontend purposes:
    return curTokenId;
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

  // One-way locking function to prevent editing access of tokenURI:
  function lockTokenUpdateAccess(uint256 _id) external override {
    require(_tokenCreator[_id] == msg.sender, "Unauthorised, not creator.");
    require(_tokenUpdateAccess[_id], "Permissions already locked.");
    _tokenUpdateAccess[_id] = false;
  }

  function overrideExistingURIByAdmin(uint256 _tokenId, string memory _newUri) external override onlyOwner {
    require(_tokenUpdateAccess[_tokenId], "Permissions to update tokenUri denied.");
    _setUri(_tokenId, _newUri);
  }

  function overrideExistingURIByCreator(uint256 _tokenId, string memory _newUri) external override {
    require(msg.sender == _tokenCreator[_tokenId], "Unauthorised, not creator.");
    require(_tokenUpdateAccess[_tokenId], "Permissions to update denied.");
    _setUri(_tokenId, _newUri);
  }

  /*///////////////////////////////////////////////////////////////
                            View Functions
    //////////////////////////////////////////////////////////////*/

    function uri(uint256 _id) public view virtual override returns (string memory) {
    return _tokenIdToURI[_id];
  }

  function royaltyInfo(uint256 _tokenId, uint256 _value)
    public
    view
    virtual
    override
    returns (address, uint256)
  {
    return super.royaltyInfo(_tokenId, _value);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC1155Upgradeable, NiftyzoneMinter)
    returns (bool)
  {
    return
      ERC1155Upgradeable.supportsInterface(interfaceId) ||
      NiftyzoneMinter.supportsInterface(interfaceId) ||
      super.supportsInterface(interfaceId);
  }

  /*///////////////////////////////////////////////////////////////
                                Proxy Upgrade Functions
    //////////////////////////////////////////////////////////////*/
  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
