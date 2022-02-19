import "ds-test/test.sol";

import {BaseTest, HEVM, HopperNFT} from "./BaseTest.sol";

contract HopperTest is BaseTest {
    function testHopperMint() public {
        hevm.startPrank(user1, user1);

        hevm.expectRevert(
            abi.encodeWithSelector(HopperNFT.InsufficientAmount.selector)
        );
        HOPPER.normalMint(1);

        hevm.expectRevert(abi.encodeWithSelector(HopperNFT.MintLimit.selector));
        HOPPER.normalMint{value: MINT_COST * (MAX_MINT_PER_CALL + 1)}(
            MAX_MINT_PER_CALL + 1
        );

        HOPPER.normalMint{value: MINT_COST * MAX_MINT_PER_CALL}(
            MAX_MINT_PER_CALL
        );

        // Withdraw
        hevm.expectRevert(
            abi.encodeWithSelector(HopperNFT.Unauthorized.selector)
        );
        HOPPER.withdraw();

        hevm.stopPrank();

        hevm.prank(owner);
        HOPPER.setOwner(user1);
        hevm.startPrank(user1, user1);
        uint256 before = user1.balance;
        assertEq(address(HOPPER).balance, MINT_COST * MAX_MINT_PER_CALL);
        HOPPER.withdraw();
        assertEq(user1.balance, before + MINT_COST * MAX_MINT_PER_CALL);
        hevm.stopPrank();
    }

    function testNames() public {
        hevm.prank(user1, user1);
        HOPPER.normalMint{value: MINT_COST}(1);
        uint256 tokenId = 4142;

        // Default name is "Unnamed"
        assert(
            keccak256(bytes("Unnamed")) ==
                keccak256(bytes(HOPPER.getHopperName(tokenId)))
        );

        // Users cannot call the contract directly to change the name
        hevm.prank(user2);
        hevm.expectRevert(
            abi.encodeWithSelector(HopperNFT.Unauthorized.selector)
        );
        HOPPER.changeHopperName(tokenId, "hopper");

        // Only Zones can change the name of an hopper
        hevm.prank(address(POND));
        HOPPER.changeHopperName(tokenId, "hopper");
        assert(
            keccak256(bytes("hopper")) ==
                keccak256(bytes(HOPPER.getHopperName(tokenId)))
        );

        // Names are unique
        hevm.prank(address(POND));
        hevm.expectRevert(abi.encodeWithSelector(HopperNFT.NameTaken.selector));
        HOPPER.changeHopperName(tokenId, "hopper");

        hevm.prank(address(POND));
        HOPPER.changeHopperName(tokenId, "hopper1");

        hevm.prank(address(POND));
        HOPPER.changeHopperName(tokenId, "hopper");

        // Names are tied to the hopper not user
        hevm.prank(user1);
        HOPPER.transferFrom(user1, user2, tokenId);
        assert(
            keccak256(bytes("hopper")) ==
                keccak256(bytes(HOPPER.getHopperName(tokenId)))
        );

        // Name Fee
        hevm.prank(user1);
        hevm.expectRevert(
            abi.encodeWithSelector(HopperNFT.Unauthorized.selector)
        );
        HOPPER.setNameChangeFee(2);

        hevm.prank(owner);
        HOPPER.setNameChangeFee(1337);
        assertEq(HOPPER.nameFee(), 1337);
    }

    function testLevels() public {
        hevm.prank(user1, user1);
        HOPPER.normalMint{value: MINT_COST}(1);
        uint256 tokenId = 4142;

        // Users cannot call the contract directly to level up
        hevm.prank(user1);
        hevm.expectRevert(
            abi.encodeWithSelector(HopperNFT.Unauthorized.selector)
        );
        HOPPER.levelUp(tokenId);

        // Only token owners can rebirth
        hevm.prank(user2);
        hevm.expectRevert(
            abi.encodeWithSelector(HopperNFT.Unauthorized.selector)
        );
        HOPPER.rebirth(tokenId);

        // Rebirth can only happen at lvl100
        hevm.prank(user1);
        hevm.expectRevert(
            abi.encodeWithSelector(HopperNFT.OnlyLvL100.selector)
        );
        HOPPER.rebirth(tokenId);

        increaseLevels(tokenId, 1);
        (uint200 level, , , , , ,) = HOPPER.hoppers(tokenId);
        assert(level == 2);

        increaseLevels(tokenId, 98);
        (level, , , , , ,) = HOPPER.hoppers(tokenId);
        assert(level == 100); // CAP CHECK IS DONE ON THE ZONE

        // Rebirth Basic
        HopperNFT.Hopper memory beforeHopper = HOPPER.getHopper(tokenId);
        hevm.prank(user1);
        HOPPER.rebirth(tokenId);
        HopperNFT.Hopper memory currentHopper = HOPPER.getHopper(tokenId);

        assertEq(beforeHopper.agility + 1, currentHopper.agility);
        assertEq(beforeHopper.strength + 1, currentHopper.strength);
        assertEq(beforeHopper.vitality + 1, currentHopper.vitality);
        assertEq(beforeHopper.intelligence + 1, currentHopper.intelligence);
        assertEq(beforeHopper.fertility + 1, currentHopper.fertility);
        assertEq(currentHopper.level, 1);

        // Rebirth Attribute Cap Check
        for (uint256 i; i < 12; ++i) {
            increaseLevels(tokenId, 99);
            hevm.prank(user1);
            HOPPER.rebirth(tokenId);
        }

        currentHopper = HOPPER.getHopper(tokenId);

        assertEq(currentHopper.agility, 10);
        assertEq(currentHopper.strength, 10);
        assertEq(currentHopper.vitality, 10);
        assertEq(currentHopper.intelligence, 10);
        assertEq(currentHopper.fertility, 10);
        assertEq(currentHopper.level, 1);
    }

    function testHopperMintAll() public {
        hevm.startPrank(user1, user1);

        for (uint256 i; i < MAX_HOPPER_SUPPLY / MAX_MINT_PER_CALL; ++i) {
            HOPPER.normalMint{value: MINT_COST * MAX_MINT_PER_CALL}(
                MAX_MINT_PER_CALL
            );
        }
        assertEq(HOPPER.hoppersLength(), MAX_HOPPER_SUPPLY);

        hevm.expectRevert(abi.encodeWithSelector(HopperNFT.MintLimit.selector));
        HOPPER.normalMint{value: MINT_COST * MAX_MINT_PER_CALL}(
            MAX_MINT_PER_CALL
        );

        for (
            uint256 i = HOPPER.LEGENDARY_ID_START();
            i < MAX_HOPPER_SUPPLY;
            ++i
        ) {
            HopperNFT.Hopper memory hopper = HOPPER.getHopper(i);
            assertGe(hopper.strength, 5);
            assertGe(hopper.agility, 5);
            assertGe(hopper.vitality, 5);
            assertGe(hopper.intelligence, 5);
            assertGe(hopper.fertility, 5);
            assertEq(hopper.level, 1);
        }

        hevm.stopPrank();
    }

    function testHopperWhiteList() public {
        bytes32 l1 = keccak256(abi.encodePacked(user1));
        bytes32 l2 = keccak256(abi.encodePacked(user2));

        bytes32 root = keccak256(abi.encodePacked(l1, l2));
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = l2;

        hevm.startPrank(user1, user1);
        hevm.expectRevert(abi.encodeWithSelector(HopperNFT.TooSoon.selector));
        HOPPER.whitelistMint{value: WL_MINT_COST}(proof);

        hevm.prank(owner);
        HOPPER.setSaleDetails(0, root, bytes32(0), 0);

        hevm.expectRevert(
            abi.encodeWithSelector(HopperNFT.InsufficientAmount.selector)
        );
        HOPPER.whitelistMint{value: WL_MINT_COST - 1}(proof);

        HOPPER.whitelistMint{value: WL_MINT_COST}(proof);

        hevm.expectRevert(
            abi.encodeWithSelector(HopperNFT.Unauthorized.selector)
        );
        HOPPER.whitelistMint{value: WL_MINT_COST}(proof);

        hevm.stopPrank();
    }
}
