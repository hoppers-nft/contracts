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

    function testLevels() public {
        hevm.prank(user1, user1);
        HOPPER.mint{value: MINT_COST}(1);

        // Users cannot call the contract directly to level up
        hevm.prank(user1);
        hevm.expectRevert(
            abi.encodeWithSelector(HopperNFT.Unauthorized.selector)
        );
        HOPPER.levelUp(0);

        // Only Zones can level an hopper up
        hevm.startPrank(address(POND));
        HOPPER.levelUp(0);

        (uint208 level, , , , , , ) = HOPPER.hoppers(0);
        assert(level == 2);

        for (uint256 i; i < 98; ++i) {
            HOPPER.levelUp(0);
        }
        (level, , , , , , ) = HOPPER.hoppers(0);
        assert(level == 100);

        hevm.stopPrank();
    }
}
