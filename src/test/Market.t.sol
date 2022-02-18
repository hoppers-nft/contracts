// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import "ds-test/test.sol";

import {BaseTest, HEVM, HopperNFT} from "./BaseTest.sol";

import {Market} from "../Market.sol";

contract MarketTest is BaseTest {
    Market MARKET;
    uint256 marketFee = 2;

    function setUpMarket() public {
        MARKET = new Market(marketFee);

        hevm.startPrank(user1);
        HOPPER.setApprovalForAll(address(MARKET), true);
        TADPOLE.setApprovalForAll(address(MARKET), true);
        hevm.stopPrank();

        hevm.startPrank(user2);
        HOPPER.setApprovalForAll(address(MARKET), true);
        TADPOLE.setApprovalForAll(address(MARKET), true);
        hevm.stopPrank();

        hevm.prank(user1);
        hevm.expectRevert(abi.encodeWithSelector(Market.ClosedMarket.selector));
        MARKET.addListing(6, address(HOPPER), 1 ether);

        hevm.prank(user1);
        hevm.expectRevert(abi.encodeWithSelector(Market.Unauthorized.selector));
        MARKET.openMarket();

        MARKET.openMarket();

        MARKET.addTokenAddress(address(HOPPER));
        MARKET.addTokenAddress(address(TADPOLE));
    }

    /*///////////////////////////////////////////////////////////////
                       HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function updateListing(
        address agent,
        uint256 id,
        uint256 amount
    ) public {
        hevm.prank(agent);
        MARKET.updateListing(id, amount);
    }

    function addListing(
        address agent,
        uint256 tokenId,
        uint256 amount
    ) public {
        hevm.prank(agent);
        MARKET.addListing(tokenId, address(HOPPER), amount);
        assert(HOPPER.ownerOf(tokenId) == address(MARKET));
    }

    function cancelListing(address agent, uint256 id) public {
        Market.Listing memory listing = MARKET.getListings(id, 1)[0];
        hevm.prank(agent);
        MARKET.cancelListing(id);
        assert(HOPPER.ownerOf(listing.tokenId) == listing.owner);
    }

    function fulfillListing(
        address agent,
        uint256 id,
        uint256 amount
    ) public {
        Market.Listing memory listing = MARKET.getListings(id, 1)[0];

        uint256 prevAgentBalance = address(agent).balance;
        uint256 prevOwnerBalance = address(listing.owner).balance;
        uint256 prevMarketBalance = address(MARKET).balance;

        hevm.prank(agent);
        MARKET.fulfillListing{value: amount}(id);

        assert(HOPPER.ownerOf(listing.tokenId) != listing.owner);
        assert(HOPPER.ownerOf(listing.tokenId) == agent);

        uint256 _marketFee = (amount * marketFee) / 100;
        assert(prevAgentBalance - amount == address(agent).balance);
        assert(
            prevOwnerBalance + amount - _marketFee ==
                address(listing.owner).balance
        );
        assert(prevMarketBalance + _marketFee == address(MARKET).balance);
    }

    /*///////////////////////////////////////////////////////////////
                             TESTS
    //////////////////////////////////////////////////////////////*/

    function testMultiAssets() public {
        setUpMarket();

        HopperNFT ANOTHER_NFT = new HopperNFT(
            "ANOTHER_NFT",
            "ANOTHER_NFT",
            0.01 ether // namefee
        );
        ANOTHER_NFT.setPreSale(type(uint256).max - 30 minutes + 1, bytes32(0));

        MARKET.removeTokenAddress(address(HOPPER));
        MARKET.removeTokenAddress(address(ANOTHER_NFT));

        hevm.prank(user2, user2);
        ANOTHER_NFT.normalMint{value: MINT_COST * 10}(10);
        hevm.prank(user2, user2);
        ANOTHER_NFT.setApprovalForAll(address(MARKET), true);
        hevm.prank(user1, user1);
        HOPPER.normalMint{value: MINT_COST * 10}(10);

        hevm.prank(user1);
        hevm.expectRevert(
            abi.encodeWithSelector(Market.InvalidTokenAddress.selector)
        );
        MARKET.addListing(4142, address(HOPPER), 1 ether);

        hevm.prank(user2);
        hevm.expectRevert(
            abi.encodeWithSelector(Market.InvalidTokenAddress.selector)
        );
        MARKET.addListing(1450, address(ANOTHER_NFT), 1 ether);

        MARKET.addTokenAddress(address(HOPPER));
        MARKET.addTokenAddress(address(ANOTHER_NFT));

        hevm.prank(user1);
        MARKET.addListing(4142, address(HOPPER), 1 ether);

        hevm.startPrank(user2);
        MARKET.addListing(1450, address(ANOTHER_NFT), 1 ether);
        MARKET.fulfillListing{value: 1 ether}(0);
        assert(HOPPER.ownerOf(4142) == user2);
        hevm.stopPrank();

        hevm.prank(user1);
        MARKET.fulfillListing{value: 1 ether}(1);
        assert(ANOTHER_NFT.ownerOf(1450) == user1);
    }

    function testMarketOwnership() public {
        setUpMarket();

        hevm.prank(user1);
        hevm.expectRevert(abi.encodeWithSelector(Market.Unauthorized.selector));
        MARKET.setOwner(user1);

        MARKET.setOwner(user1);

        assert(user1 == MARKET.owner());

        hevm.prank(user1);
        MARKET.setOwner(user2);

        assert(user2 == MARKET.owner());
    }

    function testListings() public {
        setUpMarket();

        hevm.prank(user2, user2);
        HOPPER.normalMint{value: MINT_COST * 10}(10);
        hevm.prank(user1, user1);
        HOPPER.normalMint{value: MINT_COST * 10}(10);

        addListing(user2, 1450, 1 ether);
        addListing(user2, 504, 1 ether);
        addListing(user2, 8607, 1 ether);
        addListing(user2, 2791, 1 ether);
        addListing(user2, 2508, 0.01 ether);
        addListing(user2, 1204, 1 ether);

        Market.Listing[] memory user2Listings = MARKET.getListings(3, 2);

        assertEq(user2Listings[0].id, 3);
        assertEq(user2Listings[0].owner, user2);
        assertEq(user2Listings[0].tokenId, 2791);
        assertEq(user2Listings[0].price, 1 ether);

        assertEq(user2Listings[1].id, 4);
        assertEq(user2Listings[1].owner, user2);
        assertEq(user2Listings[1].tokenId, 2508);
        assertEq(user2Listings[1].price, 0.01 ether);

        // Invalid Owner Tests
        hevm.prank(user1);
        hevm.expectRevert(abi.encodeWithSelector(Market.InvalidOwner.selector));
        MARKET.updateListing(0, 0 ether);

        hevm.prank(user1);
        hevm.expectRevert(abi.encodeWithSelector(Market.InvalidOwner.selector));
        MARKET.cancelListing(0);

        updateListing(user2, 1, 1 ether);
        updateListing(user2, 2, 1 ether);
        updateListing(user2, 3, 1 ether);

        addListing(user1, 832, 1 ether);
        addListing(user1, 374, 1 ether);
        addListing(user1, 7765, 1 ether);
        addListing(user1, 2277, 1 ether);
        addListing(user1, 972, 1 ether);
        addListing(user1, 951, 1 ether);

        cancelListing(user2, 3);
        cancelListing(user2, 5);
        cancelListing(user2, 0);

        fulfillListing(user1, 1, 1 ether);
        fulfillListing(user2, 7, 1 ether);
        fulfillListing(user2, 6, 1 ether);

        cancelListing(user1, 9);
        cancelListing(user1, 8);
        cancelListing(user1, 11);
        cancelListing(user1, 10);

        // Withdrawing
        uint256 prevMarketBalance = address(MARKET).balance;
        uint256 prevOwner = address(user1).balance;

        assert(prevMarketBalance != 0);

        hevm.prank(user1);
        hevm.expectRevert(abi.encodeWithSelector(Market.Unauthorized.selector));
        MARKET.withdraw();

        MARKET.setOwner(user1);

        hevm.prank(user1);
        MARKET.withdraw();

        assert(prevMarketBalance + prevOwner == user1.balance);
        assert(address(MARKET).balance == 0);
    }

    function testEmergency() public {
        setUpMarket();

        hevm.prank(user1, user1);
        HOPPER.normalMint{value: MINT_COST * 10}(10);

        addListing(user1, 4142, 1 ether);
        addListing(user1, 2738, 1 ether);
        addListing(user1, 1267, 1 ether);
        addListing(user1, 3220, 1 ether);

        uint256[] memory arr = new uint256[](4);
        arr[0] = 0;
        arr[1] = 1;
        arr[2] = 2;
        arr[3] = 3;

        assertTrue(HOPPER.ownerOf(4142) == address(MARKET));
        hevm.prank(user2);
        hevm.expectRevert(
            abi.encodeWithSelector(Market.OnlyEmergency.selector)
        );
        MARKET.emergencyDelist(arr);

        hevm.prank(user2);
        hevm.expectRevert(abi.encodeWithSelector(Market.Unauthorized.selector));
        MARKET.closeMarket();

        hevm.prank(user2);
        hevm.expectRevert(abi.encodeWithSelector(Market.Unauthorized.selector));
        MARKET.allowEmergencyDelisting();

        MARKET.closeMarket();
        MARKET.allowEmergencyDelisting();

        Market.Listing[] memory beforeListings = MARKET.getListings(0, 4);
        for (uint256 i; i < beforeListings.length; ++i) {
            assert(beforeListings[i].active);
        }

        // Anyone can delist them, but they go to the original owner.
        hevm.prank(user2);
        MARKET.emergencyDelist(arr);

        Market.Listing[] memory listings = MARKET.getListings(0, 4);
        for (uint256 i; i < listings.length; ++i) {
            assert(!listings[i].active);
            assertTrue(
                HOPPER.ownerOf(listings[i].tokenId) == listings[i].owner
            );
        }
    }
}
