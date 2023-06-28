// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "../Interfaces/INiftyzoneMinter.sol";
import "../Helpers/ERC2981/ERC2981RoyaltiesPerToken.sol";

/**
 * @dev Core ERC1155 creator implementation
 */
abstract contract NiftyzoneMinter is INiftyzoneMinter, ERC2981RoyaltiesPerToken {
  /*///////////////////////////////////////////////////////////////
                            Mappings
    //////////////////////////////////////////////////////////////*/

  mapping(uint256 => uint256) internal _tokenIdSupply;
  mapping(uint256 => string) internal _tokenIdToURI;
  mapping(uint256 => address) internal _tokenCreator;
  mapping(uint256 => bool) internal _tokenUpdateAccess;

  function lockTokenUpdateAccess(uint256 _id) external virtual;

  function overrideExistingURIByAdmin(uint256 _tokenId, string memory _newUri) external virtual;

  function _setUri(uint256 _tokenId, string memory _uri) internal virtual {
    _tokenIdToURI[_tokenId] = _uri;

    emit URIUpdate(_tokenId, _uri, msg.sender);
  }

  /*///////////////////////////////////////////////////////////////
                            View Functions
    //////////////////////////////////////////////////////////////*/

  function tokenUpdateAccess(uint256 _tokenId) external view returns (bool) {
    return _tokenUpdateAccess[_tokenId];
  }

  function tokenCreator(uint256 _tokenId) external view returns (address) {
    return _tokenCreator[_tokenId];
  }

  function totalSupply(uint256 _tokenId) external view returns (uint256) {
    return _tokenIdSupply[_tokenId];
  }

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return
      interfaceId == type(INiftyzoneMinter).interfaceId || super.supportsInterface(interfaceId);
  }

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function royaltyInfo(uint256 _tokenId, uint256 _value)
    public
    view
    virtual
    override(INiftyzoneMinter, ERC2981RoyaltiesPerToken)
    returns (address, uint256)
  {
    return super.royaltyInfo(_tokenId, _value);
  }
}
