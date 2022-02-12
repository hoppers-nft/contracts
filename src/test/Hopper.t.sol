import "ds-test/test.sol";

import {BaseTest, HEVM, HopperNFT} from "./BaseTest.sol";

contract HopperTest is BaseTest {
    function testHopperMint() public {
        hevm.startPrank(user1, user1);

        hevm.expectRevert(
            abi.encodeWithSelector(HopperNFT.InsufficientAmount.selector)
        );
        HOPPER.mint(1);

        hevm.expectRevert(abi.encodeWithSelector(HopperNFT.MintLimit.selector));
        HOPPER.mint{value: MINT_COST * (MAX_MINT_PER_CALL + 1)}(
            MAX_MINT_PER_CALL + 1
        );

        HOPPER.mint{value: MINT_COST * MAX_MINT_PER_CALL}(MAX_MINT_PER_CALL);

        hevm.stopPrank();
    }

    function testNames() public {
        hevm.prank(user1, user1);
        HOPPER.mint{value: MINT_COST}(1);

        // Default name is "Unnamed"
        assert(
            keccak256(bytes("Unnamed")) ==
                keccak256(bytes(HOPPER.getHopperName(0)))
        );

        // Users cannot call the contract directly to change the name
        hevm.prank(user2);
        hevm.expectRevert(
            abi.encodeWithSelector(HopperNFT.Unauthorized.selector)
        );
        HOPPER.changeHopperName(0, "hopper");

        // Only Zones can change the name of an hopper
        hevm.prank(address(POND));
        HOPPER.changeHopperName(0, "hopper");
        assert(
            keccak256(bytes("hopper")) ==
                keccak256(bytes(HOPPER.getHopperName(0)))
        );

        // Names are unique
        hevm.prank(address(POND));
        hevm.expectRevert(abi.encodeWithSelector(HopperNFT.NameTaken.selector));
        HOPPER.changeHopperName(0, "hopper");

        hevm.prank(address(POND));
        HOPPER.changeHopperName(0, "hopper1");

        hevm.prank(address(POND));
        HOPPER.changeHopperName(0, "hopper");

        // Names are tied to the hopper not user
        hevm.prank(user1);
        HOPPER.transferFrom(user1, user2, 0);
        assert(
            keccak256(bytes("hopper")) ==
                keccak256(bytes(HOPPER.getHopperName(0)))
        );
    }

    function increaseLevels(uint256 tokenId, uint256 num) internal {
        // Only Zones can level an hopper up
        hevm.startPrank(address(POND));
        for (uint256 i; i < num; ++i) {
            HOPPER.levelUp(tokenId);
        }
        hevm.stopPrank();
    }

    function testLevels() public {
        hevm.prank(user1, user1);
        HOPPER.mint{value: MINT_COST}(1);
        uint256 tokenId = 0;

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
        (uint208 level, , , , , , ) = HOPPER.hoppers(tokenId);
        assert(level == 2);

        increaseLevels(tokenId, 98);
        (level, , , , , , ) = HOPPER.hoppers(tokenId);
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
}
