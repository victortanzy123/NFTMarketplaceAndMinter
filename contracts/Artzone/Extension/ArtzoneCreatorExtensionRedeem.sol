// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./IArtzoneCreatorExtensionRedeem.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "../IArtzoneCreator.sol";

abstract contract ArtzoneCreatorExtensionRedeem is IArtzoneCreatorExtensionRedeem, ERC165, EIP712 {
  address immutable ARTZONE_CREATOR;
  string private constant SIGNING_DOMAIN = "ARTZONE_CREATOR_REDEEM";
  string private constant SIGNATURE_VERSION = "1";

  constructor(address artzoneCreator_) EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) {
    ARTZONE_CREATOR = artzoneCreator_;
  }

  bytes32 typeHash = keccak256("Token(uint256 tokenId,uint256 amount,address receiver)");

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC165, IERC165)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  /// @notice Returns a hash of the given tokenId & receiver, prepared using EIP712 typed data hashing rules.
  /// @param tokenId - tokenId of NFT.
  /// @param amount - Amount to be minted.
  /// @param receiver- Address of receiver.
  function _getTypedDataHash(
    uint256 tokenId,
    uint256 amount,
    address receiver
  ) internal view returns (bytes32 hashTypedData) {
    return _hashTypedDataV4(keccak256(abi.encode(typeHash, tokenId, amount, receiver)));
  }

  /// @notice Verifies the signature for a given mint instruction of a tokenId to a receiver, returning the address of the signer.
  /// @dev Will revert if the signature is invalid. Does not verify that the signer is authorized to mint NFTs.
  /// @param tokenId -  tokenId belonging to the NFT to be minted.
  /// @param amount -  Amount to be minted.
  /// @param receiver - Address of the receiver.
  /// @param signature - EIP712 signature by the receiver.
  function _verify(
    uint256 tokenId,
    uint256 amount,
    address receiver,
    bytes memory signature
  ) internal view returns (address decodedSigner) {
    bytes32 digest = _getTypedDataHash(tokenId, amount, receiver);
    decodedSigner = ECDSA.recover(digest, signature);
  }
}
