// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.11;

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ERC721} from "@solmate/tokens/ERC721.sol";

contract Market {
    using SafeTransferLib for address;

    address public owner;
    address public ownerCandidate;

    address public immutable tokenAddress;

    struct Listing {
        uint256 id;
        uint256 tokenId;
        uint256 price;
        address owner;
        bool active;
    }

    mapping(uint256 => Listing) public listings;
    uint256 public listingsLength;

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
    error InvalidOwner();
    error OnlyEmergency();
    error Unauthorized();

    /*///////////////////////////////////////////////////////////////
                    CONTRACT MANAGEMENT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    constructor(address _tokenAddress, uint256 _marketFee) {
        owner = msg.sender;

        if (_marketFee > 100) {
            revert Percentage0to100();
        }

        tokenAddress = _tokenAddress;
        marketFee = _marketFee;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    function setOwner(address _newOwner) external onlyOwner {
        owner = _newOwner;
        emit OwnerUpdated(_newOwner);
    }

    /*///////////////////////////////////////////////////////////////
                      MARKET MANAGEMENT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function openMarket() external onlyOwner {
        if (emergencyDelisting) {
            emergencyDelisting = false;
        }
        isMarketOpen = true;
    }

    function closeMarket() external onlyOwner {
        isMarketOpen = false;
    }

    function allowEmergencyDelisting() external onlyOwner {
        emergencyDelisting = true;
    }

    function adjustFees(uint256 newMarketFee) external onlyOwner {
        if (newMarketFee > 100) {
            revert Percentage0to100();
        }

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
                ERC721(tokenAddress).transferFrom(
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

    function addListing(uint256 tokenId, uint256 price) external {
        if (!isMarketOpen) revert ClosedMarket();

        // overflow is unrealistic
        unchecked {
            uint256 id = listingsLength++;

            listings[id] = Listing(id, tokenId, price, msg.sender, true);

            emit AddListingEv(id, tokenId, price);

            ERC721(tokenAddress).transferFrom(
                msg.sender,
                address(this),
                tokenId
            );
        }
    }

    function updateListing(uint256 id, uint256 price) external {
        if (!isMarketOpen) revert ClosedMarket();
        if (id >= listingsLength) revert InvalidListing();
        if (listings[id].owner != msg.sender) revert InvalidOwner();

        listings[id].price = price;
        emit UpdateListingEv(id, price);
    }

    function cancelListing(uint256 id) external {
        if (id >= listingsLength) revert InvalidListing();

        Listing memory listing = listings[id];

        if (!listing.active) revert InactiveListing();
        if (listing.owner != msg.sender) revert InvalidOwner();

        listings[id].active = false;

        emit CancelListingEv(id);

        ERC721(tokenAddress).transferFrom(
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
        if (msg.sender == listing.owner) revert InvalidOwner();

        listing.owner.safeTransferETH(
            listing.price - (listing.price * marketFee) / 100
        );

        emit FulfillListingEv(id);

        ERC721(tokenAddress).transferFrom(
            address(this),
            msg.sender,
            listing.tokenId
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
