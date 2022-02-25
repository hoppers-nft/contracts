// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.11;

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ERC721} from "@solmate/tokens/ERC721.sol";

//slither-disable-next-line locked-ether
contract Market {
    using SafeTransferLib for address;

    address public owner;

    struct Listing {
        uint256 id;
        uint256 tokenId;
        uint256 price;
        address tokenAddress;
        address owner;
        bool active;
    }

    mapping(uint256 => Listing) public listings;
    uint256 public listingsLength;

    mapping(address => bool) public validTokenAddresses;

    /*///////////////////////////////////////////////////////////////
                       MARKET MANAGEMENT SETTINGS
    //////////////////////////////////////////////////////////////*/

    uint256 public marketFee;
    bool public isMarketOpen;
    bool public emergencyDelisting;

    /*///////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

    event OwnerUpdated(address indexed newOwner);
    event AddListingEv(
        uint256 listingId,
        address indexed tokenAddress,
        uint256 indexed tokenId,
        uint256 price
    );
    event UpdateListingEv(uint256 listingId, uint256 price);
    event CancelListingEv(uint256 listingId);
    event FulfillListingEv(uint256 listingId);

    /*///////////////////////////////////////////////////////////////
                                  ERRORS
    //////////////////////////////////////////////////////////////*/

    error Percentage0to100();
    error ClosedMarket();
    error InvalidListing();
    error InactiveListing();
    error InsufficientValue();
    error Unauthorized();
    error OnlyEmergency();
    error InvalidTokenAddress();

    /*///////////////////////////////////////////////////////////////
                    CONTRACT MANAGEMENT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    constructor(uint256 _marketFee) {
        owner = msg.sender;
        marketFee = _marketFee;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    function setOwner(address _newOwner) external onlyOwner {
        //slither-disable-next-line missing-zero-check
        owner = _newOwner;
        emit OwnerUpdated(_newOwner);
    }

    function addTokenAddress(address _tokenAddress) external onlyOwner {
        validTokenAddresses[_tokenAddress] = true;
    }

    function removeTokenAddress(address _tokenAddress) external onlyOwner {
        delete validTokenAddresses[_tokenAddress];
    }

    /*///////////////////////////////////////////////////////////////
                      MARKET MANAGEMENT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function openMarket() external onlyOwner {
        if (emergencyDelisting) {
            delete emergencyDelisting;
        }
        isMarketOpen = true;
    }

    function closeMarket() external onlyOwner {
        delete isMarketOpen;
    }

    function allowEmergencyDelisting() external onlyOwner {
        emergencyDelisting = true;
    }

    function adjustFees(uint256 newMarketFee) external onlyOwner {
        marketFee = newMarketFee;
    }

    // If something goes wrong, we can close the market and enable emergencyDelisting
    //    After that, anyone can delist active listings
    //slither-disable-next-line calls-loop
    function emergencyDelist(uint256[] calldata listingIDs) external {
        if (!(emergencyDelisting && !isMarketOpen)) revert OnlyEmergency();

        uint256 len = listingIDs.length;
        //slither-disable-next-line uninitialized-local
        for (uint256 i; i < len; ++i) {
            uint256 id = listingIDs[i];
            Listing memory listing = listings[id];
            if (listing.active) {
                listings[id].active = false;
                ERC721(listing.tokenAddress).transferFrom(
                    address(this),
                    listing.owner,
                    listing.tokenId
                );
            }
        }
    }

    function withdraw() external onlyOwner {
        msg.sender.safeTransferETH(address(this).balance);
    }

    /*///////////////////////////////////////////////////////////////
                        LISTINGS WRITE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function addListing(
        uint256 _tokenId,
        address _tokenAddress,
        uint256 _price
    ) external {
        if (!isMarketOpen) revert ClosedMarket();
        if (!validTokenAddresses[_tokenAddress]) revert InvalidTokenAddress();

        // overflow is unrealistic
        unchecked {
            uint256 id = listingsLength++;

            listings[id] = Listing(
                id,
                _tokenId,
                _price,
                _tokenAddress,
                msg.sender,
                true
            );

            emit AddListingEv(id, _tokenAddress, _tokenId, _price);

            ERC721(_tokenAddress).transferFrom(
                msg.sender,
                address(this),
                _tokenId
            );
        }
    }

    function updateListing(uint256 id, uint256 price) external {
        if (!isMarketOpen) revert ClosedMarket();
        if (id >= listingsLength) revert InvalidListing();
        if (listings[id].owner != msg.sender) revert Unauthorized();

        listings[id].price = price;
        emit UpdateListingEv(id, price);
    }

    function cancelListing(uint256 id) external {
        if (id >= listingsLength) revert InvalidListing();

        Listing memory listing = listings[id];

        if (!listing.active) revert InactiveListing();
        if (listing.owner != msg.sender) revert Unauthorized();

        delete listings[id];

        emit CancelListingEv(id);

        ERC721(listing.tokenAddress).transferFrom(
            address(this),
            listing.owner,
            listing.tokenId
        );
    }

    function fulfillListing(uint256 id) external payable {
        if (!isMarketOpen) revert ClosedMarket();
        if (id >= listingsLength) revert InvalidListing();

        Listing memory listing = listings[id];

        if (!listing.active) revert InactiveListing();
        if (msg.value < listing.price) revert InsufficientValue();
        if (msg.sender == listing.owner) revert Unauthorized();

        delete listings[id];

        emit FulfillListingEv(id);

        ERC721(listing.tokenAddress).transferFrom(
            address(this),
            msg.sender,
            listing.tokenId
        );

        listing.owner.safeTransferETH(
            listing.price - ((listing.price * marketFee) / 100)
        );
    }

    function getListings(uint256 from, uint256 length)
        external
        view
        returns (Listing[] memory listing)
    {
        unchecked {
            uint256 numListings = listingsLength;
            if (from + length > numListings) {
                length = numListings - from;
            }

            Listing[] memory _listings = new Listing[](length);
            //slither-disable-next-line uninitialized-local
            for (uint256 i; i < length; ++i) {
                _listings[i] = listings[from + i];
            }
            return _listings;
        }
    }
}
