// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../BoringOwnable.sol";
import "./IPermissionControl.sol";

abstract contract PermissionControl is IPermissionControl, BoringOwnable, ERC165 {
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet private _permissionedUsers;

  /**
   * @dev Only allows approved admins or owner to call the specified function
   */
  modifier onlyPermissionedUser() {
    require(
      owner == msg.sender || _permissionedUsers.contains(msg.sender),
      "PermissionControl: Only owner or existing admin allowed."
    );
    _;
  }

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
    return
      interfaceId == type(IPermissionControl).interfaceId || super.supportsInterface(interfaceId);
  }

  /**
   * @dev See {IAdminControl-getAdmins}.
   */
  function getAllPermissionedUsers()
    external
    view
    override
    returns (address[] memory permissionedUsers)
  {
    permissionedUsers = new address[](_permissionedUsers.length());
    for (uint256 i = 0; i < _permissionedUsers.length(); i++) {
      permissionedUsers[i] = _permissionedUsers.at(i);
    }
  }

  /**
   * @dev See {IPernissionControl-grantPermissionToUser}.
   */
  function grantPermissionToUser(address newAdmin) external override onlyOwner {
    if (!_permissionedUsers.contains(newAdmin)) {
      emit PermissionGranted(newAdmin, msg.sender);
      _permissionedUsers.add(newAdmin);
    }
  }

  /**
   * @dev See {IPernissionControl-revokePermission}.
   */
  function revokePermission(address newAdmin) external override onlyOwner {
    if (_permissionedUsers.contains(newAdmin)) {
      emit PermissionRevoked(newAdmin, msg.sender);
      _permissionedUsers.remove(newAdmin);
    }
  }

  /**
   * @dev See {IAdminControl-isAdmin}.
   */
  function isPermissionedUser(address user) public view override returns (bool) {
    return (owner == user || _permissionedUsers.contains(user));
  }
}
