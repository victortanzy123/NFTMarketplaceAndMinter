// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./ArtzoneCreator.sol";
import "./Extension/ArtzoneCreatorExtensionRedeem.sol";

contract ArtzoneCreatorRedeem is ArtzoneCreator, ArtzoneCreatorExtensionRedeem {
  constructor(
    string memory name_,
    string memory symbol_,
    uint256 feeBps_
  ) ArtzoneCreator(name_, symbol_, feeBps_) ArtzoneCreatorExtensionRedeem(address(this)) {}

  /**
   * @dev See {IArtzoneCreatorExtensionRedeem-redeemTokenForUser}.
   */
  function redeemTokenForUser(
    uint256 tokenId,
    uint256 amount,
    address receiver,
    bytes memory signature
  ) external {
    address signer = _verify(tokenId, amount, receiver, signature);

    require(signer == receiver, "Receiver did not authorise via signature");

    _mintExistingToken(tokenId, receiver, amount);
  }

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ArtzoneCreator, ArtzoneCreatorExtensionRedeem)
    returns (bool)
  {
    return
      ArtzoneCreator.supportsInterface(interfaceId) ||
      ArtzoneCreatorExtensionRedeem.supportsInterface(interfaceId) ||
      super.supportsInterface(interfaceId);
  }
}
