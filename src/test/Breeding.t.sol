// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.12;

import "ds-test/test.sol";

import {BaseTest, HEVM, TadpoleNFT, Breeding} from "./BaseTest.sol";

contract BreedingTest is BaseTest {
    function testOwnerShip() public {
        expectErrorAndSuccess(
            address(TADPOLE),
            TadpoleNFT.Unauthorized.selector,
            abi.encodeWithSelector(TadpoleNFT.setOwner.selector, user1),
            user1,
            owner
        );

        expectErrorAndSuccess(
            address(BREEDING),
            Breeding.Unauthorized.selector,
            abi.encodeWithSelector(Breeding.setOwner.selector, user1),
            user1,
            owner
        );
    }

    function testTadpoleNFTParameterChange() public {
        assertEq(TADPOLE.breedingSpot(), address(BREEDING));
        expectErrorAndSuccess(
            address(TADPOLE),
            TadpoleNFT.Unauthorized.selector,
            abi.encodeWithSelector(TadpoleNFT.setBreedingSpot.selector, user1),
            user1,
            owner
        );
        assertEq(TADPOLE.breedingSpot(), user1);

        assertEq(TADPOLE.exchanger(), address(EXCHANGER));
        expectErrorAndSuccess(
            address(TADPOLE),
            TadpoleNFT.Unauthorized.selector,
            abi.encodeWithSelector(TadpoleNFT.setExchanger.selector, user1),
            user1,
            owner
        );
        assertEq(TADPOLE.exchanger(), user1);

        assertEq(TADPOLE.baseURI(), "tadpole.io/id/");
        expectErrorAndSuccess(
            address(TADPOLE),
            TadpoleNFT.Unauthorized.selector,
            abi.encodeWithSelector(TadpoleNFT.setBaseURI.selector, "no"),
            user1,
            owner
        );
        assertEq(TADPOLE.baseURI(), "no");
    }

    function testBreedingParameterChange() public {
        expectErrorAndSuccess(
            address(BREEDING),
            Breeding.Unauthorized.selector,
            abi.encodeWithSelector(
                Breeding.setBreedingCost.selector,
                1337 ether
            ),
            user1,
            owner
        );
        assertEq(BREEDING.breedingCost(), 1337 ether);
    }

    function testBreedingScenario() public {
        // Set up
        hevm.prank(owner);
        FLY.addZone(address(BREEDING));

        hevm.prank(address(POND));
        FLY.mint(user1, 100 ether);

        hevm.startPrank(user1, user1);

        // Set up
        HOPPER.normalMint{value: MINT_COST * 10}(10);
        FLY.approve(address(BREEDING), 100 ether);
        HOPPER.setApprovalForAll(address(BREEDING), true);

        // Stake Hopper
        uint256 tokenId = 4142;
        uint256 beforeBalance = FLY.balanceOf(user1);
        uint256 beforeSupply = FLY.totalSupply();
        BREEDING.enter(tokenId);
        assertEq(beforeBalance - BREEDING_COST, FLY.balanceOf(user1));
        assertEq(beforeSupply - BREEDING_COST, FLY.totalSupply());
        assertEq(HOPPER.ownerOf(tokenId), address(BREEDING));

        // Cannot unstake it if not hopper user
        hevm.prank(owner);
        hevm.expectRevert(
            abi.encodeWithSelector(Breeding.Unauthorized.selector)
        );
        BREEDING.exit(tokenId);

        // Cannot unstake it if a day has not passed
        hevm.expectRevert(abi.encodeWithSelector(Breeding.TooSoon.selector));
        BREEDING.exit(tokenId);

        // Unlucky
        hevm.warp(1 days);
        BREEDING.exit(tokenId);
        assertEq(TADPOLE.nextTokenID(), 0);
        assertEq(HOPPER.ownerOf(tokenId), user1);

        // Lucky
        hevm.warp(0 days);
        BREEDING.enter(tokenId);
        hevm.warp(2 days);
        BREEDING.exit(tokenId);
        assertEq(TADPOLE.nextTokenID(), 1);
        assertEq(TADPOLE.ownerOf(0), user1);
        assertEq(HOPPER.ownerOf(tokenId), user1);

        hevm.expectRevert(
            abi.encodeWithSelector(Breeding.Unauthorized.selector)
        );
        TADPOLE.burn(user1, 0);

        hevm.stopPrank();

        // Exchanger
        hevm.startPrank(address(EXCHANGER));
        hevm.expectRevert(
            abi.encodeWithSelector(Breeding.Unauthorized.selector)
        );
        TADPOLE.burn(user2, 0);

        expectErrorAndSuccess(
            address(TADPOLE),
            TadpoleNFT.Unauthorized.selector,
            abi.encodeWithSelector(TadpoleNFT.burn.selector, user1, 0),
            user1,
            EXCHANGER
        );

        assertEq(TADPOLE.nextTokenID(), 1);
        assertEq(TADPOLE.ownerOf(0), address(0));

        hevm.stopPrank();
    }

    function testTadPoleMinting() public {
        hevm.startPrank(address(BREEDING));
        TADPOLE.mint(user1, 0);
        assertEq(TADPOLE.nextTokenID(), 1);
        hevm.stopPrank();
    }

    function testTadURI() public {
        hevm.prank(address(BREEDING));
        TADPOLE.mint(user1, type(uint256).max);
        uint256 tokenId = 0;

        string memory baseURI = "https://dot.com/img/id/";

        expectErrorAndSuccess(
            address(TADPOLE),
            TadpoleNFT.Unauthorized.selector,
            abi.encodeWithSelector(TadpoleNFT.setBaseURI.selector, baseURI),
            user1,
            owner
        );

        assertEq(
            TADPOLE._jsonString(tokenId),
            '{"name":"tadpole #0", "description":"Tadpole", "attributes":[{"trait_type": "category", "value": "Common"},{"trait_type": "background", "value": 1},{"trait_type": "hat", "value": 3},{"trait_type": "skin", "value": 7}],"image":"https://dot.com/img/id/0"}'
        );

        assertEq(TADPOLE.tokenURI(tokenId), TADPOLE._jsonString(tokenId));

        hevm.expectRevert(
            abi.encodeWithSelector(TadpoleNFT.InvalidTokenID.selector)
        );
        TADPOLE.tokenURI(1);
    }
}
