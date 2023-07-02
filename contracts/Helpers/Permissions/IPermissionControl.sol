// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IPermissionControl is IERC165 {
  event PermissionGranted(address indexed newAdmin, address indexed assigner);
  event PermissionRevoked(address indexed oldAdmin, address indexed assigner);

  /**
   * @dev gets address of all admins
   */
  function getAllAdmins() external view returns (address[] memory);

  /**
   * @dev add an admin.  Can only be called by contract owner.
   */
  function grantPermissionToUser(address admin) external;

  /**
   * @dev remove an admin.  Can only be called by contract owner.
   */
  function revokePermission(address admin) external;

  /**
   * @dev checks whether or not given address is an admin
   * Returns True if they are
   */
  function isPermissionedUser(address admin) external view returns (bool);
}
