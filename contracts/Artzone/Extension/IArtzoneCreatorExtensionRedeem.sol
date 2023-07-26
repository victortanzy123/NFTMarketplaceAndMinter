// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IArtzoneCreatorExtensionRedeem is IERC165 {
  /**
   * @dev Function for Permissioned User to redeem on a receipient's behalf
   */
  function redeemTokenForUser(
    uint256 tokenId,
    uint256 amount,
    address receiver,
    bytes memory signature
  ) external;
}
