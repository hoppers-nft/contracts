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
    function testTokenCapPrecisionLoss(uint256 x) public {
        hevm.assume(x < 36525 days);
        // Setting up
        uint256[] memory tokenIds3 = new uint256[](2);
        hevm.prank(owner);
        POND.setEmissionRate(0.000545234123 ether);
        hevm.prank(owner);
        POND.setBonusEmissionRate(0.00654645234123 ether);
        hevm.prank(user2);
        HOPPER.addHopper(2);
        hevm.prank(user2);
        HOPPER.addHopper(3);
        tokenIds3[0] = 2;
        tokenIds3[1] = 3;

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
        hevm.prank(user2);
        POND.vote(1 ether, false);
        hevm.warp(2);

        hevm.prank(user2);
        POND.claim();
        hevm.assume(x > 4);
        hevm.warp(x);
        hevm.prank(user2);
        POND.exit(tokenIds3);
        hevm.prank(user2);
        POND.enter(tokenIds3);
        hevm.warp(x*2);
        POND.claim();
        hevm.warp(x*3);
        hevm.prank(user2);
        POND.levelUp(2, false);
        hevm.warp(x*4);
        hevm.prank(user2);
        POND.levelUp(3, true);
    }
}
