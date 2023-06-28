// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

// Supporting Contracts:
import "@openzeppelin/contracts/utils/Counters.sol";

// Token Standard Interfaces:
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

// ERC-721 & ERC-1155 Receiver Interfaces:
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";

// Supporting Contracts:
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "../Helpers/BoringOwnableUpgradeable.sol";

// ERC165 Supported Interfaces & Royalties:
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";

// Smart Contract Standard Introspection:
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

// Internal Imports - Meta-Transactions:
import "../Helpers/ERC2771ContextUpgradeable.sol";

// Proxy Configurations:
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// Marketplace Interface:
import "../Interfaces/INiftyzoneMarketplace.sol";

contract NiftyzoneMarketplace is
  Initializable,
  INiftyzoneMarketplace,
  ReentrancyGuardUpgradeable,
  BoringOwnableUpgradeable,
  ERC2771ContextUpgradeable,
  IERC1155ReceiverUpgradeable,
  IERC721ReceiverUpgradeable,
  UUPSUpgradeable
{
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using ERC165Checker for address;

  // For Counting of NFT/Market items
  using Counters for Counters.Counter;
  Counters.Counter public currentListingIndex;
  Counters.Counter public totalSold;
  Counters.Counter public totalListings;

  /// @dev Marketplace Edition State Variables:
  bytes32 private constant MODULE_TYPE = bytes32("MarketplaceV2");
  uint256 private constant VERSION = 3;

  /// @dev The max bps of the contract. So, 10_000 == 100 %
  uint64 public constant MAX_BPS = 10_000;

  /// @dev Royalty  (out of 10000) -> 250 /10000 = 2.5%
  uint256 public marketplaceFee;
  bool public marketplaceStatus;

  /// @dev NFT Token Standards:
  bytes4 private constant IID_NFTStandardChecker = type(INFTStandardChecker).interfaceId;
  bytes4 private constant IID_IERC165 = type(IERC165Upgradeable).interfaceId;
  bytes4 private constant IID_IERC20 = type(IERC20Upgradeable).interfaceId;
  bytes4 private constant IID_IERC721 = type(IERC721Upgradeable).interfaceId;
  bytes4 private constant IID_IERC1155 = type(IERC1155Upgradeable).interfaceId;
  // bytes4 public constant _INTERFACE_ID_ERC2981 = 0x2a55205a;
  bytes4 private constant IID_IERC2981 = type(IERC2981Upgradeable).interfaceId;

  /*///////////////////////////////////////////////////////////////
                                Mappings
    //////////////////////////////////////////////////////////////*/

  /// @dev Mapping for each MarketItem Struct
  mapping(uint256 => MarketItem) private idToMarketItem;

  /// @dev Offers made on listings via an Offer Struct belonging to each unique address
  mapping(uint256 => mapping(address => Offer)) private offers;

  /// @dev Support ERC-20 currencies for bidding
  mapping(address => bool) private supportedCurrencies;

  /*///////////////////////////////////////////////////////////////
                                Modifiers
    //////////////////////////////////////////////////////////////*/

  /// @dev Checks whether caller is a listing creator/seller.
  modifier onlyListingCreator(uint256 _listingId) {
    require(idToMarketItem[_listingId].seller == _msgSender(), "Only seller is authorised");
    _;
  }

  /// @dev Checks whether listing specified by listingId is a valid one.
  modifier onlyValidListing(uint256 _listingId) {
    MarketItem memory selectedListing = idToMarketItem[_listingId];
    require(selectedListing.listed, "invalid listing");
    require(selectedListing.deadline > block.timestamp, "listing expired");
    _;
  }

  /// @dev Checks whether marketplace currently is active
  modifier marketplaceActive() {
    require(marketplaceStatus, "Niftyzone Marketplace paused");
    _;
  }

  /// @dev Checks whether quantity specified is non-zero
  modifier validQuantity(uint256 _quantity) {
    require(_quantity != 0, "zero quantity");
    _;
  }

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

    marketplaceFee = 250;
    marketplaceStatus = true;
  }

  /*///////////////////////////////////////////////////////////////
                        Marketplace Metadata
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
    address _currency,
    uint256 _tokenId,
    uint256 _price,
    uint256 _quantity,
    uint256 _expirationTimestamp
  ) public nonReentrant validQuantity(_quantity) marketplaceActive {
    require(_price != 0, "zero price");
    require(_expirationTimestamp > block.timestamp, "invalid listing period");

    currentListingIndex.increment();
    uint256 listingId = currentListingIndex.current();

    address seller = _msgSender();
    uint256 tokenType = _getTokenType(_nftContract);

    _validateOwnershipAndApproval(seller, _nftContract, _tokenId, _quantity, tokenType);

    if (_currency != address(0)) {
      require(supportedCurrencies[_currency], "not supported currency");
    }

    // Creating the Market Item data saved via mapping
    idToMarketItem[listingId] = MarketItem(
      listingId,
      _nftContract,
      _tokenId,
      payable(seller),
      _currency,
      _price,
      _quantity,
      _quantity,
      tokenType,
      _expirationTimestamp,
      true
    );

    totalListings.increment();

    emit MarketItemCreated(
      listingId,
      _nftContract,
      _tokenId,
      _msgSender(),
      _currency,
      _price,
      _quantity,
      tokenType,
      _expirationTimestamp
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
    uint256 listingId = _listingId;
    uint256 quantityToBuy = _quantity;
    MarketItem memory selectedListing = idToMarketItem[listingId];

    address nftContract = selectedListing.nftContract;
    address currency = selectedListing.currency;
    uint256 tokenId = selectedListing.tokenId;

    uint256 totalTxValue = selectedListing.price * quantityToBuy;
    // Owner of NFT to be sold:
    address payable listingOwner = selectedListing.seller;
    require(listingOwner != _msgSender(), "Cannot buy your own NFT");

    require(quantityToBuy <= selectedListing.quantity, "Invalid quantity");
    if (currency == address(0)) {
      require(msg.value == totalTxValue, "Unmatched value sent");

      // (If Applicable) Payout to the creator by the royalties specified:

      uint256 marketplaceCut = (totalTxValue * marketplaceFee) / MAX_BPS;

      if (_checkRoyalties(nftContract)) {
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
      payable(owner).transfer(marketplaceCut);

      // Transfer the fee to the seller:
      listingOwner.transfer(address(this).balance);
    } else {
      _validateERC20BalanceAndAllowance(_msgSender(), currency, totalTxValue);

      processERC20CurrencyTransaction(
        _msgSender(),
        listingOwner,
        currency,
        totalTxValue,
        selectedListing
      );
    }

    // Validate Ownership and Approval before transaction:
    _validateOwnershipAndApproval(
      listingOwner,
      nftContract,
      tokenId,
      quantityToBuy,
      selectedListing.contractType
    );

    // Next, Transfer Ownership of the NFT to the buyer from Niftyzone Marketplace Contract:
    _processAssetTransfer(listingId, _msgSender(), quantityToBuy);

    emit MarketItemSale(
      listingId,
      nftContract,
      tokenId,
      quantityToBuy,
      totalTxValue,
      block.timestamp,
      selectedListing.contractType,
      currency,
      listingOwner,
      _msgSender()
    );
  }

  /// @dev For seller/owner of marketplace listing to invalidate his/her current valid listing.
  function delistMarketItem(uint256 _listingId)
    external
    nonReentrant
    onlyListingCreator(_listingId)
    onlyValidListing(_listingId)
    marketplaceActive
  {
    MarketItem storage selectedListing = idToMarketItem[_listingId];

    selectedListing.listed = false;

    totalListings.decrement();

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
  function updateMarketItem(
    uint256 _listingId,
    uint256 _updatedPrice,
    uint256 _extendedTimestamp
  )
    external
    nonReentrant
    onlyListingCreator(_listingId)
    onlyValidListing(_listingId)
    marketplaceActive
    returns (uint256 updatedPrice, uint256 updatedDeadline)
  {
    MarketItem storage selectedListing = idToMarketItem[_listingId];

    // Validate ownership and approval:
    _validateOwnershipAndApproval(
      selectedListing.seller,
      selectedListing.nftContract,
      selectedListing.tokenId,
      selectedListing.quantity,
      selectedListing.contractType
    );

    require(_updatedPrice < selectedListing.price, "Only lower price");

    // Once all check is completed, update price & deadline accordingly:
    selectedListing.price = _updatedPrice;
    selectedListing.deadline = _extendedTimestamp == 0
      ? selectedListing.deadline
      : selectedListing.deadline + _extendedTimestamp;

    updatedPrice = selectedListing.price;
    updatedDeadline = selectedListing.deadline;

    emit MarketItemPriceUpdate(
      _listingId,
      selectedListing.nftContract,
      selectedListing.tokenId,
      msg.sender,
      selectedListing.currency,
      updatedPrice,
      updatedDeadline
    );
  }

  /// @dev Need to get user to approve allowance for ERC20 token specified before offerring for marketplace to transact on offeror's behalf. Each new offer fom the same address on the same listing will override the older one.
  function offer(
    uint256 _listingId,
    uint256 _quantityDesired,
    address _currency,
    uint256 _pricePerToken,
    uint256 _expirationTimestamp
  ) external nonReentrant onlyValidListing(_listingId) marketplaceActive {
    require(_pricePerToken != 0, "zero price offered");
    require(_expirationTimestamp > block.timestamp, "invalid offering period");
    require(_quantityDesired != 0, "zero quantity desired");

    MarketItem memory selectedListing = idToMarketItem[_listingId];

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

    _processOffer(selectedListing, newOffer);
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
    Offer memory selectedOffer = offers[_listingId][_offeror];
    MarketItem memory selectedListing = idToMarketItem[_listingId];

    require(selectedOffer.expirationTimestamp > block.timestamp, "offer expired");
    require(
      _totalPrice == selectedOffer.pricePerToken * selectedOffer.quantityWanted,
      "invalid total value"
    );

    _validateDirectSale(
      selectedListing,
      _offeror,
      selectedOffer.quantityWanted,
      _currency,
      _totalPrice
    );

    // Delete offer since stored in memory for use
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
    _processAssetTransfer(
      selectedListing.listingId,
      selectedOffer.offeror,
      selectedOffer.quantityWanted
    );

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

  /*///////////////////////////////////////////////////////////////
                    Marketplace Internal Logic
    //////////////////////////////////////////////////////////////*/

  /// @dev Validate and process if the offer can be made valid by ensuring that the quantity specified to be bought in the offer and the offeror's desired currency balance is enough to pay off the total amount tabulated based on his price offered.
  function _processOffer(MarketItem memory _selectedListing, Offer memory _newOffer) internal {
    _validateSafeQuantity(_newOffer.quantityWanted, _selectedListing.quantity);

    uint256 totalOfferValue = _newOffer.quantityWanted * _newOffer.pricePerToken;

    _validateERC20BalanceAndAllowance(_newOffer.offeror, _newOffer.currency, totalOfferValue);

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
  function _processAssetTransfer(
    uint256 _selectedListingId,
    address _buyer,
    uint256 _quantityToBuy
  ) internal {
    MarketItem storage selectedListing = idToMarketItem[_selectedListingId];

    selectedListing.quantity -= _quantityToBuy;

    if (selectedListing.quantity == 0) {
      selectedListing.listed = false;

      totalSold.increment();
      totalListings.decrement();
    }

    uint256 tokenStandard = selectedListing.contractType;

    if (tokenStandard == 721) {
      IERC721Upgradeable(selectedListing.nftContract).safeTransferFrom(
        selectedListing.seller,
        _buyer,
        selectedListing.tokenId
      );
    } else {
      IERC1155Upgradeable(selectedListing.nftContract).safeTransferFrom(
        selectedListing.seller,
        _buyer,
        selectedListing.tokenId,
        _quantityToBuy,
        ""
      );
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

    if (_checkRoyalties(_selectedListing.nftContract)) {
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
                                Validation Queries
    //////////////////////////////////////////////////////////////*/

  /// @dev Validate the ownership of the quantity of NFT tokens specified to be listed and also the approval to transact on the user's behalf when a buyer commits a direct sale.
  function _validateOwnershipAndApproval(
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
        "ERC721: Contract not approved"
      );
      require(
        IERC721Upgradeable(_nftContract).ownerOf(_tokenId) == _tokenOwner,
        "ERC721: Invalid token ownership"
      );
    } else {
      require(
        _quantity <= IERC1155Upgradeable(_nftContract).balanceOf(_tokenOwner, _tokenId),
        "ERC1155: Insufficient quantity"
      );
      require(
        IERC1155Upgradeable(_nftContract).isApprovedForAll(_tokenOwner, address(this)),
        "ERC1155: Contract not approved"
      );
    }
  }

  /// @dev Validate if there is sufficient balance and approval of allowance for the marketplace contract to transact on the buyer's behalf.
  function _validateERC20BalanceAndAllowance(
    address _account,
    address _currency,
    uint256 _value
  ) internal view {
    require(
      IERC20Upgradeable(_currency).balanceOf(_account) >= _value,
      "insufficient ERC20 balance"
    );
    require(
      IERC20Upgradeable(_currency).allowance(_account, address(this)) >= _value,
      "insufficient ERC20 allowance"
    );
  }

  /// @dev Validate the pending listing sale by ensuring that the listing is valid, quantity specified to transact is safe, sufficient ERC20 balance & allowance from buyer and also the asset ownership & approval for marketplace to transact on their behalf.
  function _validateDirectSale(
    MarketItem memory _selectedListing,
    address _buyer,
    uint256 _quantityToBuy,
    address _currency,
    uint256 _totalOfferValue
  ) internal view {
    _validateSafeQuantity(_quantityToBuy, _selectedListing.quantity);

    _validateERC20BalanceAndAllowance(_buyer, _currency, _totalOfferValue);

    _validateOwnershipAndApproval(
      _selectedListing.seller,
      _selectedListing.nftContract,
      _selectedListing.tokenId,
      _quantityToBuy,
      _selectedListing.contractType
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
  function _validateSafeQuantity(uint256 _quantity, uint256 _curListedQuantity) internal pure {
    require(_quantity != 0, "invalid quantity");
    require(_quantity <= _curListedQuantity, "insufficient listed");
  }

  /// @dev To check if the NFT contract supports EIP-2981 royalties structure.
  function _checkRoyalties(address _contract) internal view returns (bool) {
    return IERC165(_contract).supportsInterface(IID_IERC2981);
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
    require(_token != address(0), "zero address");
    require(_isERC20(IERC20Upgradeable(_token)), "not ERC20 token standard");
    supportedCurrencies[_token] = _status;
  }

  /*///////////////////////////////////////////////////////////////
                                Proxy Upgrade Functions
    //////////////////////////////////////////////////////////////*/

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

  /*///////////////////////////////////////////////////////////////
                    ERC 165 / 721 / 1155 / 20 logic
    //////////////////////////////////////////////////////////////*/

  /// @dev Checks if the address is of ERC-721 token standard.
  function _isERC721(IERC721Upgradeable _721Contract) internal view returns (bool) {
    try _721Contract.supportsInterface(IID_IERC721) returns (bool) {
      return true;
    } catch {
      return false;
    }
  }

  /// @dev Checks if the address is of ERC-1155 token standard.
  function _isERC1155(IERC1155Upgradeable _1155Contract) internal view returns (bool) {
    try _1155Contract.supportsInterface(IID_IERC1155) returns (bool) {
      return true;
    } catch {
      return false;
    }
  }

  // /// @dev Checks if the address is of ERC-20 token standard.
  function _isERC20(IERC20Upgradeable _20Contract) internal view returns (bool) {
    try _20Contract.totalSupply() returns (uint256) {
      return true;
    } catch {
      return false;
    }
  }

  /// @dev Returns the NFT interface supported by a contract, else it will revert.
  function _getTokenType(address _assetContract) internal view returns (uint256 tokenType) {
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
      interfaceID == IID_IERC165 ||
      interfaceID == IID_IERC20 ||
      interfaceID == IID_IERC721 ||
      interfaceID == IID_IERC1155 ||
      interfaceID == IID_IERC2981;
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
