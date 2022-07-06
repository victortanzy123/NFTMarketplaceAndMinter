// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

// UUPS
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// ERC1967 Proxy
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TestContract is Initializable, ERC20Upgradeable, UUPSUpgradeable, OwnableUpgradeable {
    function initialize() public initializer {
        __ERC20_init("Mars", "MARS");
        __Ownable_init();
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    // UUPS always need the _authorizeUpgrade(address newImplementation) function
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

// UUPS Upgradeable Contract:
contract TestContractV2 is TestContract {
    function version() pure public returns (string memory){
        return "V2";
    }
}
