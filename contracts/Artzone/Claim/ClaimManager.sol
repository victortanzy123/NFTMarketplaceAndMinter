// // SPDX-License-Identifier: MIT

// pragma solidity ^0.8.11;

// interface IClaimManager {
//   /*///////////////////////////////////////////////////////////////
//                         Main Data Structures
//     //////////////////////////////////////////////////////////////*/

//   /**
//    *  @notice For basic creation of marketplace listing.
//    *
//    *
//    *  @param tokenId The specific tokenId listed for claims.
//    *  @param receiver      The receiver address for the claim funds.
//    *  @param currency  Address of ERC20 token, if native would be zero address
//    *  @param price  The price per token offered to the lister.
//    *  @param quantity The remaining quantity allocated for claiming.
//    *  @param deadline The deadline of claiming in timestamp.
//    *  @param claimable A boolean to denote if the token claiming is still valid.
//    */
//   struct TokenClaimData {
//     uint256 tokenId;
//     address payable receiver;
//     address currency;
//     uint256 price;
//     uint256 quantity;
//     uint256 deadline;
//     bool claimable;
//   }

//   /*///////////////////////////////////////////////////////////////
//                                 Events
//     //////////////////////////////////////////////////////////////*/
//   /**
//    * @dev Emitted when a token has been claimed by a specified user.
//    */
//   event TokenClaimed(uint256 indexed tokenId, address indexed user, uint256 quantity);

//   /**
//    * @dev Emitted when a token's claimable boolean flagged has been toggled in TokenClaimData.
//    */
//   event TokenClaimableToggled(uint256 indexed tokenId, bool claimable);

//   /*///////////////////////////////////////////////////////////////
//                         Marketplace Functions
//     //////////////////////////////////////////////////////////////*/

//   function claimToken(uint256 tokenId, uint256 quantity) external;

//   function setUpTokenClaim(
//     uint256 tokenId,
//     uint256 quantity,
//     uint256 deadline,
//     address currency,
//     uint256 price,
//     address receiver,
//     bool claimable
//   ) external;

//   function toggleTokenClaimableStatus(uint256 tokenId, bool claimable) external;

//   function getTokenClaimData(uint256 tokenId) external view returns (TokenClaimData calldata);

//   function checkTokenClaimAvailable(uint256 tokenId) external view returns (bool);
// }
