// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../Helpers/BoringOwnable.sol";
import "../Helpers/ERC2981/ERC2981RoyaltiesPerToken.sol";

contract ArtzoneMinterV1 is ERC1155, ERC2981RoyaltiesPerToken, BoringOwnable, AccessControl {
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  string public constant name = "Artzone Collections";
  string public constant symbol = "ARTZONE COLLECTIONS";

  /*///////////////////////////////////////////////////////////////
                            Mappings
    //////////////////////////////////////////////////////////////*/

  mapping(uint256 => uint256) public tokenSupply;
  mapping(uint256 => uint256) public tokenMaxSupply;
  mapping(uint256 => string) private tokenIdUri;
  mapping(uint256 => bool) public tokenUpdateAccess;

  /*///////////////////////////////////////////////////////////////
                            Modifiers
    //////////////////////////////////////////////////////////////*/

  /// @dev Checks if the token has been initialised prior to minting.
  modifier validateInitialisedToken(uint256 _tokenId) {
    require(_tokenId <= _tokenIds.current(), "Uninitialised token.");
    _;
  }

  /// @dev Checks if the quantity specified for minting is valid.
  modifier validateMint(uint256 _tokenId, uint256 _quantity) {
    require(_quantity != 0, "Mint quantity cannot be 0.");
    require(
      tokenSupply[_tokenId] + _quantity <= tokenMaxSupply[_tokenId],
      "Invalid quantity specified."
    );
    _;
  }

  /// @dev Checks if the quantities specified for batch minting is valid.
  modifier validateBatchMint(uint256[] memory _tokens, uint256[] memory _quantities) {
    require(_tokens.length == _quantities.length, "Mismatch token quantities");
    for (uint256 i = 0; i < _tokens.length; ) {
      require(_quantities[i] != 0, "Mint quantity cannot be 0.");
      require(
        tokenSupply[_tokens[i]] + _quantities[i] <= tokenMaxSupply[_tokens[i]],
        "Invalid quantity specified."
      );

      unchecked {
        i++;
      }
    }
    _;
  }

  /// @dev Checks for admin role.
  modifier isMinter() {
    require(
      hasRole(MINTER_ROLE, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
      "Unauthorised role."
    );
    _;
  }

  /*///////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

  event TokenInitialisation(
    uint256 indexed tokenId,
    uint256 maxQuantity,
    uint256 royaltyPercent,
    address royaltyAddr,
    string tokenUri
  );

  event TokenAccessLock(uint256 tokenId);

  /*///////////////////////////////////////////////////////////////
                            Constructor
    //////////////////////////////////////////////////////////////*/
  constructor(address _minter) ERC1155("") {
    require(_minter != address(0), "null address.");
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(MINTER_ROLE, _minter);
  }

  /*///////////////////////////////////////////////////////////////
                    Artzone Minter External Functions
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Token initialisation before minting is allowed. Only permissable to whitelisted admin wallets.
   */
  function initialiseToken(
    string memory _tokenURI,
    uint256 _maxQuantity,
    address _royaltyRecipient,
    uint256 _royaltyValue,
    bool _accessToUpdateToken
  ) external isMinter {
    _tokenIds.increment();
    uint256 tokenId = _tokenIds.current();

    setURI(tokenId, _tokenURI);
    tokenMaxSupply[tokenId] = _maxQuantity;
    tokenUpdateAccess[tokenId] = _accessToUpdateToken;

    // Set Royalty Info if specified:
    if (_royaltyValue != 0) {
      setTokenRoyalty(tokenId, _royaltyRecipient, _royaltyValue);
    }

    emit TokenInitialisation(tokenId, _maxQuantity, _royaltyValue, _royaltyRecipient, _tokenURI);
  }

  /**
   * @notice Minting of a token to a receipient, permission only exclusive to whitelisted admin wallet.
   */
  function mintToken(
    uint256 _tokenId,
    uint256 _quantity,
    address _receiver
  ) external isMinter validateMint(_tokenId, _quantity) {
    // Update quantity count for tokenId created:
    tokenSupply[_tokenId] += _quantity;
    _mint(_receiver, _tokenId, _quantity);
  }

  /**
   * @notice Batch minting of multiple tokenIds with varying respective quantities to a receipient, permission only exclusive to whitelisted admin wallet.
   */
  function batchMintToken(
    uint256[] memory _tokens,
    uint256[] memory _quantities,
    address _receiver
  ) external isMinter validateBatchMint(_tokens, _quantities) {
    _mintBatch(_receiver, _tokens, _quantities, "");
  }

  /**
   * @notice One way lock of locking up tokenURI update access, only permissable by admins.
   */
  function lockTokenUpdateAccess(uint256 _tokenId)
    external
    isMinter
    validateInitialisedToken(_tokenId)
  {
    tokenUpdateAccess[_tokenId] = false;

    emit TokenAccessLock(_tokenId);
  }

  /**
   * @notice For admins to override existing tokenURI should it be allowed to.
   */
  function overrideExistingURI(uint256 _tokenId, string memory _newUri)
    external
    isMinter
    validateInitialisedToken(_tokenId)
  {
    require(tokenUpdateAccess[_tokenId], "Permissions to update denied");
    tokenIdUri[_tokenId] = _newUri;
    emit URI(_newUri, _tokenId);
  }

  function setApprovalForAll(address operator, bool approved) public virtual override {
    _setApprovalForAll(_msgSender(), operator, approved);
  }

  function burn(uint256 _id, uint256 _amount) external {
    uint256 balanceOfOwner = balanceOf(msg.sender, _id);

    require(balanceOfOwner != 0, "Invalid ownership balance");
    require(balanceOfOwner <= _amount, "invalid amount specified");
    _burn(msg.sender, _id, _amount);
  }

  /*///////////////////////////////////////////////////////////////
                        Internal/Private Functions
    //////////////////////////////////////////////////////////////*/

  function _mint(
    address _to,
    uint256 _id,
    uint256 _amount
  ) private {
    _mint(_to, _id, _amount, "");
  }

  function setURI(uint256 _id, string memory _uri) private {
    tokenIdUri[_id] = _uri;
    emit URI(_uri, _id);
  }

  /*///////////////////////////////////////////////////////////////
                            View Functions
    //////////////////////////////////////////////////////////////*/

  function uri(uint256 _tokenId) public view virtual override returns (string memory) {
    return tokenIdUri[_tokenId];
  }

  /**
   * @notice To query creator royalties info based on ERC2981 Implementation.
   */
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
    override(ERC1155, ERC2981Support, AccessControl)
    returns (bool)
  {
    return ERC1155.supportsInterface(interfaceId) || ERC2981Support.supportsInterface(interfaceId);
  }
}
