import "ds-test/test.sol";

import {BaseTest, HEVM, HopperNFT, veFly, Zone, Pond} from "./BaseTest.sol";

contract mockZone is Zone {
    constructor(
        address fly,
        address vefly,
        address hopper
    ) Zone(fly, vefly, hopper) {}

    function canEnter(HopperNFT.Hopper memory hopper)
        public
        pure
        override
        returns (bool)
    {
        return true;
    }

    function _calculateBaseShare(HopperNFT.Hopper memory hopper)
        internal
        pure
        override
        returns (uint256)
    {
        return 2 * hopper.level;
    }

    function getGaugeLimit(uint256 level) external view returns (uint256) {
        return _getGaugeLimit(level);
    }
}

contract BugTest is BaseTest {
    function testTokenCapPrecisionLoss1() public {
        uint256 x = 5;
        // Setting up

        hevm.prank(owner);
        POND.setEmissionRate(0.000545234123 ether);
        hevm.prank(owner);
        POND.setBonusEmissionRate(0.00654645234123 ether);
        hevm.prank(user2);
        HOPPER.addHopper(2);
        hevm.prank(user2);
        HOPPER.addHopper(3);
        uint256[] memory tokenIds3 = new uint256[](2);
        tokenIds3[0] = 2;
        tokenIds3[1] = 3;
        // uint256[] memory tokenIds3 = new uint256[](1);
        // tokenIds3[0] = 3;

        FLY.mockMint(user2, 3000000 ether);

        hevm.prank(user2);
        FLY.approve(address(VEFLY), 1000 ether);
        hevm.prank(user2);
        VEFLY.deposit(1 ether);
        hevm.prank(owner);
        VEFLY.setGenerationDetails(100, 1000000, 1);

        // Start

        hevm.prank(user2);
        HOPPER.setApprovalForAll(address(POND), true);
        hevm.prank(user2);
        POND.enter(tokenIds3);

        hevm.warp(1);
        // hevm.prank(user2);
        // POND.vote(1 ether, false);
        hevm.warp(2);

        hevm.prank(user2);
        POND.claim();
        hevm.assume(x > 4);
        hevm.warp(x);
        hevm.prank(user2);
        POND.exit(tokenIds3);

        for (uint256 i; i < 98; i++) {
            x += 60 * 3 * 2;
            hevm.warp(x);
            hevm.prank(user2);
            POND.enter(tokenIds3);
            x += 60 * 3 * 2;
            hevm.warp(x);
            // hevm.prank(user2);
            // POND.claim();

            // x += 60 * 3 * 2;
            // if (i % 2 == 0) {
            //     hevm.warp(x);
            //     hevm.prank(user2);
            //     POND.levelUp(2, false);
            // }

            x += 60 * 3;

            x += 60 * 3;
            hevm.warp(x);
            hevm.prank(user2);
            POND.exit(tokenIds3);
            // x += 60 * 3;
            hevm.prank(user2);
            POND.levelUp(3, true);
        }
    }

    function testTokenCapPrecisionLoss(uint256 x) public {
        // uint256 x = 1513123;
        hevm.assume(x < 36525 days);
        // Setting up

        hevm.prank(owner);
        POND.setEmissionRate(0.000545234123 ether);
        hevm.prank(owner);
        POND.setBonusEmissionRate(0.00654645234123 ether);
        hevm.prank(user2);
        HOPPER.addHopper(2);
        hevm.prank(user2);
        HOPPER.addHopper(3);
        uint256[] memory tokenIds3 = new uint256[](2);
        tokenIds3[0] = 2;
        tokenIds3[1] = 3;
        // uint256[] memory tokenIds3 = new uint256[](1);
        // tokenIds3[0] = 3;

        FLY.mockMint(user2, 3000000 ether);

        hevm.prank(user2);
        FLY.approve(address(VEFLY), 1000 ether);
        hevm.prank(user2);
        VEFLY.deposit(1 ether);
        hevm.prank(owner);
        VEFLY.setGenerationDetails(100, 1000000, 1);

        // Start

        hevm.prank(user2);
        HOPPER.setApprovalForAll(address(POND), true);
        hevm.prank(user2);
        POND.enter(tokenIds3);

        hevm.warp(1);
        // hevm.prank(user2);
        // POND.vote(1 ether, false);
        hevm.warp(2);

        hevm.prank(user2);
        POND.claim();
        hevm.assume(x > 4);
        hevm.warp(x);
        hevm.prank(user2);
        POND.exit(tokenIds3);

        for (uint256 i; i < 98; i++) {
            x += 60 * 3;
            hevm.warp(x);
            hevm.prank(user2);
            POND.enter(tokenIds3);
            x += 60 * 3;
            hevm.warp(x);
            hevm.prank(user2);
            POND.claim();

            x += 60 * 3;
            if (i % 2 == 0) {
                hevm.warp(x);
                hevm.prank(user2);
                POND.levelUp(2, false);
            }

            if (i % 4 == 0) {
                x += 60 * 3;
                hevm.warp(x);
                hevm.prank(user2);
                POND.exit(tokenIds3);
                hevm.prank(user2);
                POND.enter(tokenIds3);
            }

            x += 60 * 3;
            hevm.warp(x);
            hevm.prank(user2);
            POND.levelUp(3, true);

            x += 60 * 3;
            hevm.prank(user2);
            POND.exit(tokenIds3);
        }
        emit log_uint(POND.userMaxFlyGeneration(user2));
        // assert(false);
    }

    function testLevelUpBoostfill() public {
        hevm.prank(owner);
        POND.setEmissionRate(0.545234123 ether);

        hevm.prank(owner);
        POND.setBonusEmissionRate(0.654645234123 ether);

        hevm.startPrank(user2, user2);
        HOPPER.setApprovalForAll(address(POND), true);

        HOPPER.addHopperLvl1(1);
        HOPPER.addHopperLvl1(2);

        uint256[] memory token1 = new uint256[](1);
        uint256[] memory token2 = new uint256[](1);
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        token1[0] = 1;
        tokenIds[1] = 2;
        token2[0] = 2;

        FLY.mockMint(user2, 3000000 ether);
        POND.enter(token1);
        hevm.warp(4);

        POND.enter(token2);
        hevm.warp(5);
        POND.claimable(user2);
        POND.levelUp(2, false);
        POND.exit(token2);
        assertEq(POND.userMaxFlyGeneration(user2), 0);

        assertEq(bytes32(0),HopperNFT(HOPPER).getData("LEVEL_GAUGE_KEY", 2));
        hevm.stopPrank();
    }
    
}
