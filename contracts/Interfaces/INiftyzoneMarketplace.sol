// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "./IMarketplaceMetadata.sol";
import "./INFTStandardChecker.sol";

interface INiftyzoneMarketplace is IMarketplaceMetadata {


    /*///////////////////////////////////////////////////////////////
                        Main Data Structures
    //////////////////////////////////////////////////////////////*/

  /**
   *  @notice For basic creation of marketplace listing.
   *
   *
   *  @param listingId      The uid of the listing the offer is made to.
   *  @param nftContract        The asset contract.
   *  @param tokenId The specific tokenId listed for sale.
   *  @param seller       The owner creating the listing.
   *  @param price  The price per token offered to the lister.
   *  @param originalQuantity The original quantity of tokens (>= 1 for ERC-1155 token standards).
   *  @param quantity The remaining quantity left in the listing.
   *  @param contractType The int of contract type - i.e. 721 or 1155 for ERC-721 or ERC-1155 respectively.
   *  @param deadline The deadline of listing in timestamp.
   *  @param listed A boolean to denote if the listing is still valid.
   */

  struct MarketItem {
    uint256 listingId;
    address nftContract;
    uint256 tokenId;
    address payable seller;
    uint256 price;
    uint256 originalQuantity;
    uint256 quantity;
    uint256 contractType;
    uint256 deadline;
    bool listed;
  }
  /**
   *  @notice The information related to either (1) an offer on a direct listing, or (2) a bid in an auction.
   *
   *  @dev The type of the listing at ID `lisingId` determins how the `Offer` is interpreted.
   *      If the listing is of type `Direct`, the `Offer` is interpreted as an offer to a direct listing.
   *      If the listing is of type `Auction`, the `Offer` is interpreted as a bid in an auction.
   *
   *  @param listingId      The uid of the listing the offer is made to.
   *  @param offeror        The account making the offer.
   *  @param quantityWanted The quantity of tokens from the listing wanted by the offeror.
   *                        This is the entire listing quantity if the listing is an auction.
   *  @param currency       The currency in which the offer is made.
   *  @param pricePerToken  The price per token offered to the lister.
   *  @param expirationTimestamp The timestamp after which a seller cannot accept this offer.
   */
  struct Offer {
    uint256 listingId;
    address offeror;
    uint256 quantityWanted;
    address currency;
    uint256 pricePerToken;
    uint256 expirationTimestamp;
  }
  /*///////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/
  // Events for MarketItem Created:
  event MarketItemCreated(
    uint256 indexed listingId,
    address indexed nftContract,
    uint256 tokenId,
    address indexed seller,
    uint256 price,
    uint256 quantity,
    uint256 contractType,
    uint256 deadline
  );

  // Events for MarketItem Price Update:
  event MarketItemPriceUpdate(
    uint256 indexed listingId,
    address indexed nftContract,
    uint256 tokenid,
    address indexed seller,
    uint256 newPrice
  );

  // Events for MarketItem Delisted:
  event MarketItemDelisted(
    uint256 indexed listingId,
    address indexed nftContract,
    uint256 tokenId,
    uint256 timeDelisted,
    uint256 contractType,
    address indexed seller
  );

  /**
   * @dev Emitted when a buyer buys from a direct listing, or a lister accepts some
   *      buyer's offer to their direct listing.
   */
  event MarketItemSale(
    uint256 indexed listingId,
    address nftContract,
    uint256 tokenId,
    uint256 quantityBought,
    uint256 totalPricePaid,
    uint256 timeSold,
    uint256 contractType,
    address currency,
    address indexed seller,
    address indexed buyer
  );

  event NewOffer(
    uint256 indexed listingId,
    address indexed offeror,
    address _currency,
    uint256 desiredQuantity,
    uint256 totalOfferAmount
  );

  /*///////////////////////////////////////////////////////////////
                        Marketplace Functions
    //////////////////////////////////////////////////////////////*/

  /**
   *  @notice Lets someone list an NFT they owned regardless if its ERC-721 or ERC-1155 token standard, supporting multiple copy listing for ERC-1155 standard..
   *
   *  @param _nftContract        The asset contract address - has to comply to ERC-721 or ERC-1155.
   *
   *  @param _tokenId   The asset's tokenId.
   *
   *  @param _price    Price per token listed.
   *
   *
   *  @param _quantity   Quantity of tokens to be listed -> only 1 for ERC-721 and >= 1 for ERC-1155.
   *
   *  @param _numberOfDays The number of days valid for the marketplace listing.
   */

  function createMarketItem(
    address _nftContract,
    uint256 _tokenId,
    uint256 _price,
    uint256 _quantity,
    uint256 _numberOfDays
  ) external payable;

  /**
   *  @notice Lets someone buy NFT(s) from a valid marketplace listing.
   *
   *  @param _listingId   Unique listing ID pointing to the marketplace listing for purchase.
   *
   *  @param _quantity The desired quantity to be bought by buyer.
   */
  function createMarketSale(
    uint256 _listingId,
    uint256 _quantity
  ) external payable;

  /**
   *  @notice Lets the owner of a valid marketplace listing delist his own listing.
   *
   *  @param _listingId   Unique listing ID pointing to the marketplace listing to delist.
   */
  function delistMarketItem(uint256 _listingId) external;

  /**
   *  @notice Lets the owner of a valid marketplace listing update the price per token of his own listing.
   *
   *  @param _listingId   Unique listing ID pointing to the marketplace listing to delist.
   *
   *  @param _updatedPrice   New price per token set by owner.
   */
  function updateMarketItem(uint256 _listingId, uint256 _updatedPrice) external returns(uint256);

  /**
   *  @notice Lets someone make an offer to a direct listing, or bid in an auction.
   *
   *  @dev Each (address, listing ID) pair maps to a single unique offer. So e.g. if a buyer makes
   *       makes two offers to the same direct listing, the last offer is counted as the buyer's
   *       offer to that listing.
   *
   *  @param _listingId        The unique ID of the lisitng to make an offer/bid to.
   *
   *  @param _quantityDesired   For auction listings: the 'quantity wanted' is the total amount of NFTs
   *                           being auctioned, regardless of the value of `_quantityWanted` passed.
   *                           For direct listings: `_quantityWanted` is the quantity of NFTs from the
   *                           listing, for which the offer is being made.
   *
   *  @param _currency         For auction listings: the 'currency of the bid' is the currency accepted
   *                           by the auction, regardless of the value of `_currency` passed. For direct
   *                           listings: this is the currency in which the offer is made.
   *
   *  @param _pricePerToken    For direct listings: offered price per token. For auction listings: the bid
   *                           amount per token. The total offer/bid amount is `_quantityWanted * _pricePerToken`.
   *
   *  @param _expirationTimestamp For aution listings: inapplicable. For direct listings: The timestamp after which
   *                              the seller can no longer accept the offer.
   */
  function offer(
    uint256 _listingId,
    uint256 _quantityDesired,
    address _currency,
    uint256 _pricePerToken,
    uint256 _expirationTimestamp
  ) external payable;

  /**
   * @notice Lets a listing's creator accept an offer to their direct listing.
   * @param _listingId The unique ID of the listing for which to accept the offer.
   * @param _offeror The address of the buyer whose offer is to be accepted.
   * @param _currency The currency of the offer that is to be accepted.
   * @param _totalPrice The total price of the offer that is to be accepted.
   */
  function acceptOffer(
    uint256 _listingId,
    address _offeror,
    address _currency,
    uint256 _totalPrice
  ) external;
}
