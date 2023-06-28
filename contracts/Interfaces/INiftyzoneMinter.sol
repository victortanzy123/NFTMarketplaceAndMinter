// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface INiftyzoneMinter {
  /*///////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/
  /**
   * @dev Emitted when a token is created on Niftyzone Minter.
   */
  event TokenCreation(
    uint256 indexed tokenId,
    uint256 timestamp,
    uint256 quantity,
    uint256 royaltyPercent,
    address royaltyAddr,
    address creator
  );

  /**
   * @dev Emitted when a token tokenURI has been updated.
   */
  event URIUpdate(uint256 indexed tokenId, string newUri, address submitter);

  /*///////////////////////////////////////////////////////////////
                        Main Functions
    //////////////////////////////////////////////////////////////*/

  /**
   *  @notice Initialise metadata parameters of a token to allow subsequent minting.
   *
   *  @param _tokenURI       The tokenURI of token.
   *
   *  @param _quantity     Quantity of copies for the token to be minted.
   *
   *  @param _royaltyRecipient   Secondary royalty receipient address.
   *
   *  @param _royaltyValue    Percentage value of royalties for each secondary sale of token based on ERC-2981 standard (out of 10,000 BPS).
   *
   *  @param _accessToUpdateToken   Edit access to override tokenURI of token in the future.
   *
   */
  function createToken(
    string memory _tokenURI,
    uint256 _quantity,
    address _royaltyRecipient,
    uint256 _royaltyValue,
    bool _accessToUpdateToken
  ) external returns (uint256);

  /**
   * @notice One way lock of locking up tokenURI update access, only permissable by admins/creator.
   *
   *  @param _tokenId   TokenId to lock token access update.
   */
  function lockTokenUpdateAccess(uint256 _tokenId) external;

  /**
   * @notice For creator to override existing tokenURI should it be allowed to.
   *
   *  @param _tokenId   TokenId to override existing tokenURI with new one.
   *
   *  @param _newUri    New tokenURI to override existing one.
   *
   */
  function overrideExistingURIByCreator(uint256 _tokenId, string memory _newUri) external;

  /**
   * @notice For contract admin to override existing tokenURI should it be allowed to.
   *
   *  @param _tokenId   TokenId to override existing tokenURI with new one.
   *
   *  @param _newUri    New tokenURI to override existing one.
   *
   */
  function overrideExistingURIByAdmin(uint256 _tokenId, string memory _newUri) external;

  /**
   * @notice To query creator royalties info based on ERC2981 Implementation.
   *
   * @param _tokenId    The tokenId initialised on NiftyzoneMinter to be queried for.
   *
   * @param _value      The base value of sale to be calculated from.
   */
  function royaltyInfo(uint256 _tokenId, uint256 _value) external view returns (address, uint256);

  /**
   * @notice Total amount of tokens minted in with a given tokenId.
   *
   * @param _tokenId    The tokenId initialised on NiftyzoneMinter to be queried for.
   *
   */
  function totalSupply(uint256 _tokenId) external view returns (uint256);

  /**
   * @notice Retrieve creator address of token.
   *
   * @param _tokenId    The tokenId initialised on NiftyzoneMinter to be queried for.
   *
   */
  function tokenCreator(uint256 _tokenId) external view returns (address);

  /**
   * @notice Retrieve boolean of token update access.
   *
   * @param _tokenId    The tokenId initialised on NiftyzoneMinter to be queried for.
   *
   */
  function tokenUpdateAccess(uint256 _tokenId) external view returns (bool);
}
