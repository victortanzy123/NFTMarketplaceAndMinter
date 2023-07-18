// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./ERC2771Context.sol";

contract EIP2771ExampleMetaTx is ERC2771Context {
  constructor(address[] memory trustedForwarders_) ERC2771Context(trustedForwarders_) {}
}
