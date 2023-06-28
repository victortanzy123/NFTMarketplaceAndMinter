// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (metatx/ERC2771Context.sol)

pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @dev Context variant with ERC2771 support.
 */
abstract contract ERC2771ContextUpgradeable is Initializable, ContextUpgradeable {
  // Mapping of trusted entities for gas relay (metatx)
  mapping(address => bool) private _trustedForwarder;

  // Upgradeable contract initialiser:
  function __ERC2771Context_init(address[] memory trustedForwarders) internal onlyInitializing {
    // Context Upgradeable Initialise
    __Context_init_unchained();
    // ERC2771ContextUpgradeable Initialise
    __ERC2771Context_init_unchained(trustedForwarders);
  }

  // Initialiser constructor for ERC2771ContextUpgradeable
  function __ERC2771Context_init_unchained(address[] memory trustedForwarders)
    internal
    onlyInitializing
  {
    // Initalise all addresses as trusted forwarders:
    for (uint256 i = 0; i < trustedForwarders.length; i++) {
      _trustedForwarder[trustedForwarders[i]] = true;
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

  uint256[49] private __gap;
}
