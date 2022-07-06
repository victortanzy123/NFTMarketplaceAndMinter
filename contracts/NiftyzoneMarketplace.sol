// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
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

// For Differentiation between ERC-721 and ERC-1155 Token Standard:
import "./Helpers/INFTStandardChecker.sol";

// Proxy Configurations:
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";


contract NiftyzoneMarketplace is
    Initializable,
    ReentrancyGuardUpgradeable,
    IERC1155ReceiverUpgradeable,
    IERC721ReceiverUpgradeable,
    ERC2771ContextUpgradeable,
    BoringOwnableUpgradeable,
    UUPSUpgradeable
{
    // For arimethic functionalities:
    using SafeMath for uint256;

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
    bytes4 public constant IID_NFTStandardChecker =
        type(INFTStandardChecker).interfaceId;
    bytes4 public constant IID_IERC165 = type(IERC165Upgradeable).interfaceId;
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

    struct MarketItem {
        uint256 itemId;
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

    /// @notice Type of the tokens that can be listed for sale.
    enum TokenType {
        ERC1155,
        ERC721
    }

    /*///////////////////////////////////////////////////////////////
                                Mappings
    //////////////////////////////////////////////////////////////*/

    // Mapping for each MarketItem Struct:
    mapping(uint256 => MarketItem) private idToMarketItem;

    /*///////////////////////////////////////////////////////////////
                                Modifiers
    //////////////////////////////////////////////////////////////*/

    /// @dev Checks whether caller is a listing creator/seller.
    modifier onlyListingCreator(uint256 _itemId) {
        require(idToMarketItem[_itemId].seller == _msgSender(), "Only Owner is authorised.");
        _;
    }

    modifier onlyValidListing(uint256 listingId) {
        require(idToMarketItem[listingId].nftContract != address(0), "Invalid Listing");
        _;
    }

    /// @dev Checks whether marketplace currently is active
    modifier marketplaceActive(){
        require(marketplaceStatus, "Niftyzone Marketplace paused.");
        _;
    }

    /*///////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    // Events for MarketItem Created:
    event MarketItemCreated(
        uint256 indexed itemId,
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
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 tokenid,
        address indexed seller,
        uint256 newPrice
    );

    // Events for MarketItem Delisted:
    event MarketItemDelisted(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 tokenId,
        uint256 timeDelisted,
        uint256 contractType,
        address indexed seller
    );

    // Event for MarketItem Sale:
    event MarketItemSale(
        uint256 indexed itemId,
        address nftContract,
        uint256 tokenId,
        uint256 quantityBought,
        uint256 totalPricePaid,
        uint256 timeSold,
        uint256 contractType,
        address indexed seller,
        address indexed buyer
    );

    /// @dev Returns the type of the contract.
    function getContractType() external pure returns (bytes32) {
        return MODULE_TYPE;
    }

    /// @dev Returns the version of the contract.
    function getContractVersion() external pure returns (uint8) {
        return uint8(VERSION);
    }

    /*///////////////////////////////////////////////////////////////
                            Marketplace Logic
    //////////////////////////////////////////////////////////////*/

    // Function for creating marketItem:
    function createMarketItem(
        address _nftContract,
        uint256 _tokenId,
        uint256 _price,
        uint256 _quantity,
        uint256 _numberOfDays
    )
        public
        payable
        nonReentrant
        marketplaceActive
    {
        require(_price > 0, "Price must be at least 1 wei");
        require(_numberOfDays >= 1, "Too short listing period");
        require(
            isERC721(_nftContract) || isERC1155(_nftContract),
            "Invalid NFT Token Standard"
        );

        currentListingIndex.increment();
        uint256 itemId = currentListingIndex.current();
        address seller = _msgSender();

        uint256 tokenType = getTokenType(_nftContract);
        validateOwnershipAndApproval(
            seller,
            _nftContract,
            _tokenId,
            _quantity,
            tokenType
        );

        // Setting the deadline:
        uint256 deadline = block.timestamp + _numberOfDays * 1 days;

        // Creating the Market Item data saved via mapping
        idToMarketItem[itemId] = MarketItem(
            itemId,
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

        // Since listed, increment itemListed counter:
        totalListings.increment();

        // Once listed, emit MarketItemCreated Event:
        emit MarketItemCreated(
            itemId,
            _nftContract,
            _tokenId,
            msg.sender,
            _price,
            _quantity,
            tokenType,
            deadline
        );
    }

    // For market sale:
    function createMarketSale(
        address _nftContract,
        uint256 _itemId,
        uint256 _quantity
    ) public payable nonReentrant marketplaceActive onlyValidListing(_itemId) {
        require(
            isERC721(_nftContract) || isERC1155(_nftContract),
            "Invalid NFT Token Standard"
        );
        uint256 price = idToMarketItem[_itemId].price;
        uint256 tokenId = idToMarketItem[_itemId].tokenId;

        require(idToMarketItem[_itemId].listed, "Item not for sale.");
        require(
            idToMarketItem[_itemId].deadline > block.timestamp,
            "Expired listing"
        );
        require(
            _quantity >= 1,
            "Quantity must be at least 1"
        );
        require(_quantity <= idToMarketItem[_itemId].quantity, "Invalid quantity");
        require(
            msg.value == price * _quantity,
            "Please submit the asking price in order to complete the purchase"
        );

        // NFT Token Standard:
        uint256 tokenType = idToMarketItem[_itemId].contractType;

        // Owner of NFT to be sold:
        address payable ownerNFTAddress = idToMarketItem[_itemId].seller;
        require(ownerNFTAddress != msg.sender, "Cannot buy your own NFT");

        // Set by default:
        address seller = idToMarketItem[_itemId].seller;

        // Validate Ownership and Approval before transaction:
        validateOwnershipAndApproval(
            seller,
            _nftContract,
            tokenId,
            _quantity,
            tokenType
        );

        // Next, Transfer Ownership of the NFT to the buyer from Niftyzone Marketplace Contract:
        if (tokenType == 721) {
            idToMarketItem[_itemId].quantity = 0;
            IERC721Upgradeable(_nftContract).transferFrom(seller, msg.sender, tokenId);
        } else {
            // Transfer the appropriate quantity specified:
            idToMarketItem[_itemId].quantity -= _quantity;
            IERC1155Upgradeable(_nftContract).safeTransferFrom(
                seller,
                msg.sender,
                tokenId,
                _quantity,
                ""
            );
        }

        if (idToMarketItem[_itemId].quantity == 0) {
            // Update Listing Status:
             idToMarketItem[_itemId].listed = false;
            // Update counters:
            totalSold.increment();
            totalListings.decrement();
        }


        // (If Applicable) Payout to the creator by the royalties specified:
        uint256 totalValue = msg.value;

        if (checkRoyalties(_nftContract)) {
            try
                IERC2981Upgradeable(_nftContract).royaltyInfo(
                    tokenId,
                    msg.value
                )
            returns (address royaltyFeeReceipient, uint256 royaltyFeeAmount) {
                if (royaltyFeeAmount > 0) {
                    payable(royaltyFeeReceipient).transfer(royaltyFeeAmount);
                }
            } catch {}
        }

        // Pay Royalty to markerplace Manager/Owner:
        payable(owner).transfer(totalValue.div(MAX_BPS).mul(marketplaceFee));

        // Transfer the fee to the seller:
        payable(seller).transfer(address(this).balance);

        emit MarketItemSale(
            _itemId,
            _nftContract,
            tokenId,
            _quantity,
            msg.value,
            block.timestamp,
            tokenType,
            ownerNFTAddress,
            msg.sender
        );
    }

    // Function to Delist NFT from marketplace:
    function delistNFT(uint256 _itemId) public nonReentrant onlyListingCreator(_itemId) marketplaceActive {

        // Instantiate marketItem
        MarketItem storage currentItem = idToMarketItem[_itemId];

        // Checks for listing status listed:
        require(currentItem.listed, "Item not listed or sold out.");

        // Change the price of listing and switch off the listed boolean:
        currentItem.listed = false;

        // Decrement itemListed:
        totalListings.decrement();

        // Emit Delisting event:
        emit MarketItemDelisted(
            currentItem.itemId,
            currentItem.nftContract,
            currentItem.tokenId,
            currentItem.contractType,
            block.timestamp,
            currentItem.seller
        );
    }

    // Function to update the price of NFT:
    function updatePrice(uint256 _itemId, uint256 _updatedPrice)
        external
        nonReentrant onlyListingCreator(_itemId) marketplaceActive
        returns (uint256)
    {
        MarketItem storage currentItem = idToMarketItem[_itemId];

        // check if the item belongs to the owner aka seller:
        require(
            currentItem.seller == payable(msg.sender),
            "Not authorised, not owner of item."
        );
        // Check if the item is CURRENTLY LISTED on Marketplace:
        require(currentItem.listed == true, "item not listed on marketplace");

        // Validate ownership and approval:
        validateOwnershipAndApproval(
            currentItem.seller,
            currentItem.nftContract,
            currentItem.tokenId,
            currentItem.quantity,
            currentItem.contractType
        );

        // Once all check is completed, update price accordingly:
        currentItem.price = _updatedPrice;

        return currentItem.price;
    }

    /*///////////////////////////////////////////////////////////////
                                Marketplace Queries
    //////////////////////////////////////////////////////////////*/

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
                IERC721Upgradeable(_nftContract).isApprovedForAll(
                    _tokenOwner,
                    address(this)
                ) || IERC721Upgradeable(_nftContract).getApproved(_tokenId) == marketplace,
                "ERC721: Contract not approved."
            );
            require(
                IERC721Upgradeable(_nftContract).ownerOf(_tokenId) == _tokenOwner,
                "ERC721: Invalid token ownership."
            );
        } else {
            require(
                _quantity <=
                    IERC1155Upgradeable(_nftContract).balanceOf(_tokenOwner, _tokenId),
                "ERC1155: Insufficient quantity to list."
            );
            require(
                IERC1155Upgradeable(_nftContract).isApprovedForAll(
                    _tokenOwner,
                    address(this)
                ),
                "ERC1155: Contract not approved."
            );
        }
    }

    function getMarketItem(uint256 _itemId)
        external
        view
        returns (MarketItem memory)
    {
        return idToMarketItem[_itemId];
    }

    /*///////////////////////////////////////////////////////////////
                                Royalties
    //////////////////////////////////////////////////////////////*/

    function checkRoyalties(address _contract) internal view returns (bool) {
        bool success = IERC165(_contract).supportsInterface(IID_IERC2981);
        return success;
    }

    function getMarketplaceFee() public view returns (uint256) {
        return marketplaceFee;
    }

    /*///////////////////////////////////////////////////////////////
                                Admin Functions
    //////////////////////////////////////////////////////////////*/
    function setListingPrice(uint256 _newMarketplaceFee) external onlyOwner {
        marketplaceFee = _newMarketplaceFee;
    }

    function setOwnership(address _newOwner) external onlyOwner {
        owner = payable(_newOwner);
    }

    function setMarketplaceStatus(bool _status) external onlyOwner {
        marketplaceStatus = _status;
    }

       /*///////////////////////////////////////////////////////////////
                                Proxy Upgrade Functions
    //////////////////////////////////////////////////////////////*/

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /*///////////////////////////////////////////////////////////////
                        ERC 165 / 721 / 1155 logic
    //////////////////////////////////////////////////////////////*/

    function isERC721(address nftAddress) internal view returns (bool) {
        return nftAddress.supportsInterface(IID_IERC721);
    }

    function isERC1155(address nftAddress) internal view returns (bool) {
        return nftAddress.supportsInterface(IID_IERC1155);
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function supportsInterface(bytes4 interfaceID)
        external
        view
        virtual
        override
        returns (bool)
    {
        return
            interfaceID == type(IERC165Upgradeable).interfaceId ||
            interfaceID == type(IERC1155ReceiverUpgradeable).interfaceId ||
            interfaceID == type(IERC721ReceiverUpgradeable).interfaceId ||
            interfaceID == type(IERC2981Upgradeable).interfaceId;
    }

    /// @dev Returns the interface supported by a contract.
    function getTokenType(address _assetContract)
        internal
        view
        returns (uint256 tokenType)
    {
        if (
            IERC165Upgradeable(_assetContract).supportsInterface(
                type(IERC1155Upgradeable).interfaceId
            )
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
    function _msgSender() internal view virtual override (ERC2771ContextUpgradeable) returns (address sender){
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
