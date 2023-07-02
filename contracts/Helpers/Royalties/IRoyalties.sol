// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IRoyalties is IERC165 {
  event RoyaltiesUpdated(
    uint256 indexed tokenId,
    address payable[] receivers,
    uint256[] basisPoints
  );

  /**
   * @dev Get royalites of a token.  Returns list of receivers and basisPoints
   */
  function getRoyalties(uint256 tokenId)
    external
    view
    returns (address payable[] memory, uint256[] memory);

  // Royalty support for various other standards
  function getFeeRecipients(uint256 tokenId) external view returns (address payable[] memory);

  function getFeeBps(uint256 tokenId) external view returns (uint256[] memory);

  function getFees(uint256 tokenId)
    external
    view
    returns (address payable[] memory, uint256[] memory);

  function royaltyInfo(uint256 tokenId, uint256 value) external view returns (address, uint256);
}
