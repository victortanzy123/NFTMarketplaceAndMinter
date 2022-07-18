// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/utils/Counters.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./Helpers/BoringOwnableUpgradeable.sol";

// ERC165 Supported Interfaces & Royalties:
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";

// Smart Contract Standard Introspection:
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

// Internal Imports - Meta-Transactions:
import "./Helpers/ERC2771ContextUpgradeable.sol";

// // For Differentiation between ERC-721 and ERC-1155 Token Standard:
// import "./Interfaces/INFTStandardChecker.sol";

// Proxy Configurations:
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// Marketplace Interface:
import "./Interfaces/INiftyzoneMarketplace.sol";

contract NiftyzoneMarketplace is
  Initializable,
  INiftyzoneMarketplace,
  ReentrancyGuardUpgradeable,
  IERC1155ReceiverUpgradeable,
  IERC721ReceiverUpgradeable,
  ERC2771ContextUpgradeable,
  BoringOwnableUpgradeable,
  UUPSUpgradeable
{
  using SafeERC20Upgradeable for IERC20Upgradeable;
  // For NFT Token Standard Introspection:
  using ERC165Checker for address;

  // For Counting of NFT/Market items
  using Counters for Counters.Counter;
  Counters.Counter public currentListingIndex;
  Counters.Counter public totalSold;
  // For listed items (SET):
  Counters.Counter public totalListings;

  // Marketplace Edition State Variables:
  bytes32 private constant MODULE_TYPE = bytes32("Marketplace");
  uint256 private constant VERSION = 2;

  /// @dev The max bps of the contract. So, 10_000 == 100 %
  uint64 public constant MAX_BPS = 10_000;

  // NFT Token Standards:
  bytes4 public constant IID_NFTStandardChecker = type(INFTStandardChecker).interfaceId;
  bytes4 public constant IID_IERC165 = type(IERC165Upgradeable).interfaceId;
  bytes4 public constant IID_IERC20 = type(IERC20Upgradeable).interfaceId;
  bytes4 public constant IID_IERC721 = type(IERC721Upgradeable).interfaceId;
  bytes4 public constant IID_IERC1155 = type(IERC1155Upgradeable).interfaceId;
  // bytes4 public constant _INTERFACE_ID_ERC2981 = 0x2a55205a;
  bytes4 public constant IID_IERC2981 = type(IERC2981Upgradeable).interfaceId;

  // Royalty  (out of 10000) -> 250 /10000 = 2.5%
  uint256 marketplaceFee = 250;
  bool marketplaceStatus = true;

  /*///////////////////////////////////////////////////////////////
            Constructor + initializer for Upgradeable Interface
    //////////////////////////////////////////////////////////////*/

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {}

  /// @dev Initiliazes the contract, like a constructor.
  function initialize(address[] memory _trustedForwarders) external initializer {
    // Initialise inherited Upgradeable Contracts
    __ReentrancyGuard_init();
    __BoringOwnable_init();
    __ERC2771Context_init(_trustedForwarders);
  }

  /*///////////////////////////////////////////////////////////////
                                Mappings
    //////////////////////////////////////////////////////////////*/

  // Mapping for each MarketItem Struct:
  mapping(uint256 => MarketItem) private idToMarketItem;

  // Offers made on listings
  mapping(uint256 => mapping(address => Offer)) private offers;

  // Support ERC-20 currencies for bidding:
  mapping(address => bool) private supportedCurrencies;

  /*///////////////////////////////////////////////////////////////
                                Modifiers
    //////////////////////////////////////////////////////////////*/

  /// @dev Checks whether caller is a listing creator/seller.
  modifier onlyListingCreator(uint256 _listingId) {
    require(idToMarketItem[_listingId].seller == _msgSender(), "Only Owner is authorised.");
    _;
  }

  /// @dev Checks whether listing specified by listingId is a valid one.
  modifier onlyValidListing(uint256 _listingId) {
    MarketItem memory selectedListing = idToMarketItem[_listingId];
    require(selectedListing.listed, "Invalid Listing");
    require(selectedListing.deadline > block.timestamp, "listing expired");
    _;
  }

  /// @dev Checks whether marketplace currently is active
  modifier marketplaceActive() {
    require(marketplaceStatus, "Niftyzone Marketplace paused.");
    _;
  }

  /// @dev Checks whether quantity specified is non-zero
  modifier validQuantity(uint256 _quantity) {
    require(_quantity != 0, "zero quantity");
    _;
  }

  /*///////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

  /// @dev Returns the type of the contract.
  function contractType() external pure returns (bytes32) {
    return MODULE_TYPE;
  }

  /// @dev Returns the version of the contract.
  function contractVersion() external pure returns (uint8) {
    return uint8(VERSION);
  }

  /*///////////////////////////////////////////////////////////////
                            Marketplace Logic
    //////////////////////////////////////////////////////////////*/

  /// @dev For any account to list their existing NFTs (both ERC-721 or ERC-1155) on the marketplace by specifying a desired price, quantity to put up for sale and deadline.
  function createMarketItem(
    address _nftContract,
    uint256 _tokenId,
    uint256 _price,
    uint256 _quantity,
    uint256 _numberOfDays
  ) public payable nonReentrant validQuantity(_quantity) marketplaceActive {
    require(_price != 0, "zero price");
    require(_numberOfDays >= 1, "Too short listing period");
    require(isERC721(_nftContract) || isERC1155(_nftContract), "Invalid NFT Token Standard");

    currentListingIndex.increment();
    uint256 listingId = currentListingIndex.current();
    address seller = _msgSender();

    uint256 tokenType = getTokenType(_nftContract);
    validateOwnershipAndApproval(seller, _nftContract, _tokenId, _quantity, tokenType);

    // Setting the deadline:
    uint256 deadline = block.timestamp + _numberOfDays * 1 days;

    // Creating the Market Item data saved via mapping
    idToMarketItem[listingId] = MarketItem(
      listingId,
      _nftContract,
      _tokenId,
      payable(seller),
      _price,
      _quantity,
      _quantity,
      tokenType,
      deadline,
      true
    );

    totalListings.increment();

    emit MarketItemCreated(
      listingId,
      _nftContract,
      _tokenId,
      msg.sender,
      _price,
      _quantity,
      tokenType,
      deadline
    );
  }

  /// @dev For any buyer to execute a direct market sale based on a valid listing by matching the specified price (in NATIVE TOKEN) per quantity.
  function createMarketSale(uint256 _listingId, uint256 _quantity)
    external
    payable
    nonReentrant
    validQuantity(_quantity)
    marketplaceActive
    onlyValidListing(_listingId)
  {
    MarketItem memory selectedListing = idToMarketItem[_listingId];

    address nftContract = selectedListing.nftContract;
    uint256 price = selectedListing.price;
    uint256 tokenId = selectedListing.tokenId;
    uint256 quantityToBuy = _quantity;

    require(quantityToBuy <= selectedListing.quantity, "Invalid quantity");
    require(msg.value == price * quantityToBuy, "Unmatched value sent");

    // NFT Token Standard:
    uint256 tokenType = selectedListing.contractType;

    // Owner of NFT to be sold:
    address payable ownerNFTAddress = selectedListing.seller;
    require(ownerNFTAddress != msg.sender, "Cannot buy your own NFT");

    // Set by default:
    address seller = selectedListing.seller;

    // Validate Ownership and Approval before transaction:
    validateOwnershipAndApproval(seller, nftContract, tokenId, quantityToBuy, tokenType);

    // Next, Transfer Ownership of the NFT to the buyer from Niftyzone Marketplace Contract:
    processAssetTransfer(selectedListing, msg.sender, quantityToBuy);

    // (If Applicable) Payout to the creator by the royalties specified:
    uint256 totalValue = msg.value;

    if (checkRoyalties(nftContract)) {
      try IERC2981Upgradeable(nftContract).royaltyInfo(tokenId, msg.value) returns (
        address royaltyFeeReceipient,
        uint256 royaltyFeeAmount
      ) {
        if (royaltyFeeAmount > 0) {
          payable(royaltyFeeReceipient).transfer(royaltyFeeAmount);
        }
      } catch {}
    }

    // Pay Royalty to markerplace Manager/Owner:
    payable(owner).transfer((totalValue * marketplaceFee) / MAX_BPS);

    // Transfer the fee to the seller:
    payable(seller).transfer(address(this).balance);

    emit MarketItemSale(
      _listingId,
      nftContract,
      tokenId,
      quantityToBuy,
      msg.value,
      block.timestamp,
      tokenType,
      address(0),
      ownerNFTAddress,
      msg.sender
    );
  }

  /// @dev For seller/owner of marketplace listing to invalidate his/her current valid listing.
  function delistMarketItem(uint256 _listingId)
    external
    nonReentrant
    onlyListingCreator(_listingId)
    marketplaceActive
  {
    // Instantiate marketItem
    MarketItem storage selectedListing = idToMarketItem[_listingId];

    // Checks for listing status listed:
    require(selectedListing.listed, "Item not listed or sold out.");

    // Change the price of listing and switch off the listed boolean:
    selectedListing.listed = false;

    // Decrement itemListed:
    totalListings.decrement();

    // Emit Delisting event:
    emit MarketItemDelisted(
      selectedListing.listingId,
      selectedListing.nftContract,
      selectedListing.tokenId,
      selectedListing.contractType,
      block.timestamp,
      selectedListing.seller
    );
  }

  /// @dev For seller/owner of valid marketplace listing to update the price for sale for each token within the listing.
  function updateMarketItem(uint256 _listingId, uint256 _updatedPrice)
    external
    nonReentrant
    onlyListingCreator(_listingId)
    marketplaceActive
    returns (uint256)
  {
    MarketItem storage selectedListing = idToMarketItem[_listingId];

    // check if the item belongs to the owner aka seller:
    require(selectedListing.seller == payable(msg.sender), "Not authorised, not owner of item.");
    // Check if the item is CURRENTLY LISTED on Marketplace:
    require(selectedListing.listed == true, "Item not listed or sold out.");

    // Validate ownership and approval:
    validateOwnershipAndApproval(
      selectedListing.seller,
      selectedListing.nftContract,
      selectedListing.tokenId,
      selectedListing.quantity,
      selectedListing.contractType
    );

    // Once all check is completed, update price accordingly:
    selectedListing.price = _updatedPrice;

    return selectedListing.price;
  }

  // @dev Need to get user to approve allowance for ERC20 token specified before offerring for marketplace to transact on offeror's behalf.
  function offer(
    uint256 _listingId,
    uint256 _quantityDesired,
    address _currency,
    uint256 _pricePerToken,
    uint256 _expirationTimestamp
  ) external payable nonReentrant onlyValidListing(_listingId) marketplaceActive {
    MarketItem memory selectedListing = idToMarketItem[_listingId];

    require(selectedListing.deadline <= block.timestamp, "listing expired");
    require(selectedListing.listed, "invalid listing");

    // Need check if _currency complies with ERC20 standard or support currency.
    Offer memory newOffer = Offer({
      listingId: _listingId,
      offeror: _msgSender(),
      quantityWanted: _quantityDesired,
      currency: _currency,
      pricePerToken: _pricePerToken,
      expirationTimestamp: _expirationTimestamp
    });

    require(supportedCurrencies[_currency], "unsupported currency");
    require(msg.value == 0, "unecessary additional value");

    processOffer(selectedListing, newOffer);
  }

  /// @dev For seller/owner of valid marketplace listing to accept a pending offer with a currency that is strictly ERC-20 standard and is approved as one of the supported currencies from an potential buyer.
  function acceptOffer(
    uint256 _listingId,
    address _offeror,
    address _currency,
    uint256 _totalPrice
  )
    external
    nonReentrant
    marketplaceActive
    onlyListingCreator(_listingId)
    onlyValidListing(_listingId)
  {
    // Storage or memory?
    Offer memory selectedOffer = offers[_listingId][_offeror];
    MarketItem memory selectedListing = idToMarketItem[_listingId];

    require(selectedOffer.expirationTimestamp > block.timestamp, "offer expired");
    require(
      _totalPrice == selectedOffer.pricePerToken * selectedOffer.quantityWanted,
      "invalid total value"
    );

    validateDirectSale(
      selectedListing,
      _offeror,
      selectedOffer.quantityWanted,
      _currency,
      _totalPrice
    );

    // Update states of Listing
    selectedListing.quantity -= selectedOffer.quantityWanted;
    delete offers[_listingId][_offeror];

    // Process payment for the offer
    processERC20CurrencyTransaction(
      selectedOffer.offeror,
      selectedListing.seller,
      selectedOffer.currency,
      selectedOffer.quantityWanted * selectedOffer.pricePerToken,
      selectedListing
    );

    // Process Transfer of Assets
    processAssetTransfer(selectedListing, selectedOffer.offeror, selectedOffer.quantityWanted);

    emit MarketItemSale(
      _listingId,
      selectedListing.nftContract,
      selectedListing.tokenId,
      selectedOffer.quantityWanted,
      _totalPrice,
      block.timestamp,
      selectedListing.contractType,
      selectedOffer.currency,
      selectedListing.seller,
      selectedOffer.offeror
    );
  }

  /// @dev Validate the pending listing sale by ensuring that the listing is valid, quantity specified to transact is safe, sufficient ERC20 balance & allowance from buyer and also the asset ownership & approval for marketplace to transact on their behalf.
  function validateDirectSale(
    MarketItem memory _selectedListing,
    address _buyer,
    uint256 _quantityToBuy,
    address _currency,
    uint256 _totalOfferValue
  ) internal view {
    require(_selectedListing.listed, "invalid listing");
    require(_selectedListing.deadline > block.timestamp, "expired listing");

    validateSafeQuantity(_quantityToBuy, _selectedListing.quantity);

    validateERC20BalanceAndAllowance(_buyer, _currency, _totalOfferValue);

    validateOwnershipAndApproval(
      _selectedListing.seller,
      _selectedListing.nftContract,
      _selectedListing.tokenId,
      _quantityToBuy,
      _selectedListing.contractType
    );
  }

  /// @dev Validate and process if the offer can be made valid by ensuring that the quantity specified to be bought in the offer and the offeror's desired currency balance is enough to pay off the total amount tabulated based on his price offered.
  function processOffer(MarketItem memory _selectedListing, Offer memory _newOffer) internal {
    validateSafeQuantity(_newOffer.quantityWanted, _selectedListing.quantity);

    uint256 totalOfferValue = _newOffer.quantityWanted * _newOffer.pricePerToken;

    validateERC20BalanceAndAllowance(_newOffer.offeror, _newOffer.currency, totalOfferValue);

    offers[_selectedListing.listingId][_newOffer.offeror] = _newOffer;

    emit NewOffer(
      _selectedListing.listingId,
      _newOffer.offeror,
      _newOffer.currency,
      _newOffer.quantityWanted,
      totalOfferValue
    );
  }

  /// @dev Process the respective asset transfer from seller to buyer after all checks have been validated and payment has been completed successfully.
  function processAssetTransfer(
    MarketItem memory _selectedListing,
    address _buyer,
    uint256 _quantityToBuy
  ) internal {
    uint256 tokenStandard = _selectedListing.contractType;

    if (tokenStandard == 721) {
      require(_quantityToBuy == 1, "invalid quantity for ERC721");
      _selectedListing.quantity = 0;
      IERC721Upgradeable(_selectedListing.nftContract).safeTransferFrom(
        _selectedListing.seller,
        _buyer,
        _selectedListing.tokenId
      );
    } else {
      _selectedListing.quantity -= _quantityToBuy;
      IERC1155Upgradeable(_selectedListing.nftContract).safeTransferFrom(
        _selectedListing.seller,
        _buyer,
        _selectedListing.tokenId,
        _quantityToBuy,
        ""
      );
    }

    if (_selectedListing.quantity == 0) {
      _selectedListing.listed = false;

      totalSold.increment();
      totalListings.decrement();
    }
  }

  /// @dev Process the payment split to the relevant parties - marketplaceOwnership, secondary royalties receiver (if applicable) and lastly the seller.
  // Assumes that all balances and allowances has been validated prior to calling this function to process sale transaction.
  function processERC20CurrencyTransaction(
    address _buyer,
    address _seller,
    address _currency,
    uint256 _totalValue,
    MarketItem memory _selectedListing
  ) internal {
    uint256 marketplaceCut = (_totalValue * marketplaceFee) / MAX_BPS;
    uint256 secondaryRoyalties;

    if (checkRoyalties(_selectedListing.nftContract)) {
      try
        IERC2981Upgradeable(_selectedListing.nftContract).royaltyInfo(
          _selectedListing.tokenId,
          _totalValue
        )
      returns (address royaltyFeeReceipient, uint256 royaltyFeeAmount) {
        if (royaltyFeeAmount > 0) {
          secondaryRoyalties = royaltyFeeAmount;
          IERC20Upgradeable(_currency).safeTransferFrom(
            _buyer,
            royaltyFeeReceipient,
            royaltyFeeAmount
          );
        }
      } catch {}
    }

    IERC20Upgradeable(_currency).safeTransferFrom(_buyer, owner, marketplaceCut);

    IERC20Upgradeable(_currency).safeTransferFrom(
      _buyer,
      _seller,
      _totalValue - marketplaceCut - secondaryRoyalties
    );
  }

  /*///////////////////////////////////////////////////////////////
                                Marketplace Queries
    //////////////////////////////////////////////////////////////*/

  /// @dev Validate the ownership of the quantity of NFT tokens specified to be listed and also the approval to transact on the user's behalf when a buyer commits a direct sale.
  function validateOwnershipAndApproval(
    address _tokenOwner,
    address _nftContract,
    uint256 _tokenId,
    uint256 _quantity,
    uint256 _tokenType
  ) internal view {
    address marketplace = address(this);

    if (_tokenType == 721) {
      require(
        IERC721Upgradeable(_nftContract).isApprovedForAll(_tokenOwner, address(this)) ||
          IERC721Upgradeable(_nftContract).getApproved(_tokenId) == marketplace,
        "ERC721: Contract not approved."
      );
      require(
        IERC721Upgradeable(_nftContract).ownerOf(_tokenId) == _tokenOwner,
        "ERC721: Invalid token ownership."
      );
    } else {
      require(
        _quantity <= IERC1155Upgradeable(_nftContract).balanceOf(_tokenOwner, _tokenId),
        "ERC1155: Insufficient quantity to list."
      );
      require(
        IERC1155Upgradeable(_nftContract).isApprovedForAll(_tokenOwner, address(this)),
        "ERC1155: Contract not approved."
      );
    }
  }

  /// @dev Validate if there is sufficient balance and approval of allowance for the marketplace contract to transact on the buyer's behalf.
  function validateERC20BalanceAndAllowance(
    address _account,
    address _currency,
    uint256 _value
  ) internal view {
    require(IERC20Upgradeable(_currency).balanceOf(_account) >= _value, "insufficient balance");
    require(
      IERC20Upgradeable(_currency).allowance(_account, address(this)) >= _value,
      "insufficient allowance"
    );
  }

  /*///////////////////////////////////////////////////////////////
                            View/Pure functions
    //////////////////////////////////////////////////////////////*/

  /// @dev Fetch market item aka. listing based on the unique identifier listingId.
  function getMarketItem(uint256 _listingId) external view returns (MarketItem memory) {
    return idToMarketItem[_listingId];
  }

  /// @dev Fetch particular pending offer made by a potential buyer on a particular valid listing
  function getPendingOffer(uint256 _listingId, address _account)
    external
    view
    returns (Offer memory)
  {
    return offers[_listingId][_account];
  }

  /// @dev Checks if the ERC20 token address is approved as one of the supported currencies for offers.
  function checkSupportedCurrency(address _currency) external view returns (bool) {
    return supportedCurrencies[_currency];
  }

  /// @dev Pure function to validate if the quantity specified by buyer is validate on the particular listing based on the token standard.
  function validateSafeQuantity(uint256 _quantity, uint256 _curListedQuantity) internal pure {
    require(_quantity != 0, "invalid quantity");
    require(_quantity <= _curListedQuantity, "insufficient listed");
  }

  /// @dev To check if the NFT contract supports EIP-2981 royalties structure.
  function checkRoyalties(address _contract) internal view returns (bool) {
    bool success = IERC165(_contract).supportsInterface(IID_IERC2981);
    return success;
  }

  /// @dev Fetch prevailing marketplace platform fee specified by owner of contract.
  function getMarketplaceFee() public view returns (uint256) {
    return marketplaceFee;
  }

  /*///////////////////////////////////////////////////////////////
                                Admin Functions
    //////////////////////////////////////////////////////////////*/

  /// @dev For owner of marketplace to custom set marketplace platform fee cut.
  function setMarketplaceFee(uint256 _newMarketplaceFee) external onlyOwner {
    marketplaceFee = _newMarketplaceFee;
  }

  /// @dev For owner to toggle the switch that allows the marketplace to be active or not.
  function setMarketplaceStatus(bool _status) external onlyOwner {
    marketplaceStatus = _status;
  }

  /// @dev For owner to approve or revoke approval on any ERC20 supported currencies used for offers on prevailing valid listings.
  function setSupportedCurrencies(address _token, bool _status) external onlyOwner {
    require(isERC20(_token), "invalid token standard");
    supportedCurrencies[_token] = _status;
  }

  /*///////////////////////////////////////////////////////////////
                                Proxy Upgrade Functions
    //////////////////////////////////////////////////////////////*/

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

  /*///////////////////////////////////////////////////////////////
                        ERC 165 / 721 / 1155 logic
    //////////////////////////////////////////////////////////////*/

  /// @dev Checks if the address is of ERC-721 token standard.
  function isERC721(address _nftAddress) internal view returns (bool) {
    return _nftAddress.supportsInterface(IID_IERC721);
  }

  /// @dev Checks if the address is of ERC-1155 token standard.
  function isERC1155(address _nftAddress) internal view returns (bool) {
    return _nftAddress.supportsInterface(IID_IERC1155);
  }

  /// @dev Checks if the address is of ERC-20 token standard.
  function isERC20(address _tokenAddress) internal view returns (bool) {
    return _tokenAddress.supportsInterface(IID_IERC20);
  }

  /// @dev For marketplace contract to transact ERC-1155 token standard on behalf of seller and buyer.
  function onERC1155Received(
    address,
    address,
    uint256,
    uint256,
    bytes memory
  ) public virtual override returns (bytes4) {
    return this.onERC1155Received.selector;
  }

  /// @dev For marketplace contract to transact ERC-1155 token standard in batches on behalf of seller and buyer.
  function onERC1155BatchReceived(
    address,
    address,
    uint256[] memory,
    uint256[] memory,
    bytes memory
  ) public virtual override returns (bytes4) {
    return this.onERC1155BatchReceived.selector;
  }

  /// @dev For marketplace contract to transact ERC-721 token standard on behalf of seller and buyer.
  function onERC721Received(
    address,
    address,
    uint256,
    bytes memory
  ) public virtual override returns (bytes4) {
    return this.onERC721Received.selector;
  }

  /// @dev Universal standardised function across various token standards to validate their interfaceId.
  function supportsInterface(bytes4 interfaceID) external view virtual override returns (bool) {
    return
      interfaceID == type(IERC165Upgradeable).interfaceId ||
      interfaceID == type(IERC1155ReceiverUpgradeable).interfaceId ||
      interfaceID == type(IERC721ReceiverUpgradeable).interfaceId ||
      interfaceID == type(IERC2981Upgradeable).interfaceId;
  }

  /// @dev Returns the interface supported by a contract.
  function getTokenType(address _assetContract) internal view returns (uint256 tokenType) {
    if (
      IERC165Upgradeable(_assetContract).supportsInterface(type(IERC1155Upgradeable).interfaceId)
    ) {
      tokenType = 1155;
    } else if (
      IERC165Upgradeable(_assetContract).supportsInterface(type(IERC721Upgradeable).interfaceId)
    ) {
      tokenType = 721;
    } else {
      revert("token must be ERC1155 or ERC721.");
    }
  }

  /*///////////////////////////////////////////////////////////////
                        Context/MetaTx Functions
    //////////////////////////////////////////////////////////////*/

  /// GSN Lets the gas station pay the fee instead of your user who is sending the transaction. Essentially what happens is that you ask the GSN to send the transaction to the network through a signed message.
  function _msgSender()
    internal
    view
    virtual
    override(ERC2771ContextUpgradeable)
    returns (address sender)
  {
    return ERC2771ContextUpgradeable._msgSender();
  }

  function _msgData()
    internal
    view
    virtual
    override(ERC2771ContextUpgradeable)
    returns (bytes calldata)
  {
    return ERC2771ContextUpgradeable._msgData();
  }

  /// @dev Lets the contract receives native tokens from `nativeTokenWrapper` withdraw.
  receive() external payable {}
}
