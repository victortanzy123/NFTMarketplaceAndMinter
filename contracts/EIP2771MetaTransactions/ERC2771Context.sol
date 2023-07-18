// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/utils/Context.sol";

contract ERC2771Context is Context {
  mapping(address => bool) private _trustedForwarder;

  constructor(address[] memory trustedForwarders_) {
    for (uint256 i = 0; i < trustedForwarders_.length; i++) {
      _trustedForwarder[trustedForwarders_[i]] = true;
    }
  }

  function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
    return _trustedForwarder[forwarder];
  }

  /*///////////////////////////////////////////////////////////////
                        Standard Context Functions
    //////////////////////////////////////////////////////////////*/

  function _msgSender() internal view virtual override returns (address sender) {
    if (isTrustedForwarder(msg.sender)) {
      // The assembly code is more direct than the Solidity version using `abi.decode`.
      assembly {
        sender := shr(96, calldataload(sub(calldatasize(), 20)))
      }
    } else {
      return super._msgSender();
    }
  }

  function _msgData() internal view virtual override returns (bytes calldata) {
    if (isTrustedForwarder(msg.sender)) {
      return msg.data[:msg.data.length - 20];
    } else {
      return super._msgData();
    }
  }
}
