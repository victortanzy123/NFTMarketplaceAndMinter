// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

interface INFTStandardChecker {
  function isERC721(address nftAddress) external view returns (bool);

  function isERC1155(address nftAddress) external view returns (bool);
}
