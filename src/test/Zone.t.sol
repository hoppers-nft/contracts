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

contract ZoneTest is BaseTest {
    function testZoneOwnership() public {
        address fakeBallot = address(0x8888);
        expectErrorAndSuccess(
            address(POND),
            Zone.Unauthorized.selector,
            abi.encodeWithSelector(Zone.setBallot.selector, fakeBallot),
            user1,
            owner
        );

        expectErrorAndSuccess(
            address(POND),
            Zone.Unauthorized.selector,
            abi.encodeWithSelector(Zone.setEmissionRate.selector, 1 ether),
            user1,
            owner
        );

        expectErrorAndSuccess(
            address(POND),
            Zone.Unauthorized.selector,
            abi.encodeWithSelector(Zone.setBonusEmissionRate.selector, 1 ether),
            user1,
            owner
        );

        expectErrorAndSuccess(
            address(POND),
            Zone.Unauthorized.selector,
            abi.encodeWithSelector(Zone.setBonusEmissionRate.selector, 1 ether),
            user1,
            fakeBallot
        );

        expectErrorAndSuccess(
            address(POND),
            Zone.Unauthorized.selector,
            abi.encodeWithSelector(Zone.setFlyLevelCapRatio.selector, 1 ether),
            user1,
            owner
        );

        expectErrorAndSuccess(
            address(POND),
            Zone.Unauthorized.selector,
            abi.encodeWithSelector(Zone.setOwner.selector, user1),
            user1,
            owner
        );
    }

    function testScenarioWithGauges() public {
        // Setting up
        uint256[] memory tokenIds1 = new uint256[](1);
        uint256[] memory tokenIds2 = new uint256[](1);
        uint256[] memory tokenIds3 = new uint256[](2);
        hevm.prank(user1);
        HOPPER.addHopper(0);
        hevm.prank(user1);
        HOPPER.addHopper(1);
        tokenIds2[0] = 1;

        hevm.prank(user2);
        HOPPER.addHopper(2);
        hevm.prank(user2);
        HOPPER.addHopper(3);
        tokenIds3[0] = 2;
        tokenIds3[1] = 3;

        hevm.prank(owner);
        POND.setEmissionRate(2 ether);
        hevm.prank(owner);
        POND.setBonusEmissionRate(2 ether);

        FLY.mockMint(user1, 2 ether);
        FLY.mockMint(user2, 2 ether);
        // Start

        hevm.prank(user1);
        POND.enter(tokenIds1);
        assertEq(POND.baseSharesBalance(user1), 2 * 2);
        assertEq(POND.userMaxFlyGeneration(user1) / 1e12, 3 ether);
        assertEq(POND.totalBaseShare(), 2 * 2);
        assertEq(POND.hopperOwners(0), user1);

        hevm.prank(user1);
        POND.enter(tokenIds2);
        assertEq(POND.totalBaseShare(), 2 * 2 * 2);
        assertEq(POND.baseSharesBalance(user1), 2 * 2 * 2);
        assertEq(POND.userMaxFlyGeneration(user1) / 1e12, 6 ether);

        hevm.prank(user2);
        HOPPER.setApprovalForAll(address(POND), true);
        hevm.prank(user2);
        POND.enter(tokenIds3);
        assertEq(POND.hopperOwners(2), user2);
        assertEq(POND.baseSharesBalance(user2), 2 * 2 * 2);
        assertEq(POND.totalBaseShare(), 2 * 2 * 2 + 2 * 2 * 2);

        hevm.warp(1);
        assertEq(POND.claimable(user1), 1 ether);
        assertEq(POND.claimable(user2), 1 ether);
        hevm.warp(6);
        assertEq(POND.claimable(user1), 6 ether);
        assertEq(POND.claimable(user2), 6 ether);
        hevm.warp(7);
        assertEq(POND.claimable(user1), 6 ether);
        assertEq(POND.claimable(user2), 6 ether);
        hevm.prank(user1);
        POND.claim();
        assertEq(FLY.balanceOf(user1), 2 ether + 6 ether);
        hevm.prank(user2);
        POND.claim();
        assertEq(FLY.balanceOf(user2), 2 ether + 6 ether);
        assertEq(POND.userMaxFlyGeneration(user1) / 1e12, 0 ether);
        assertEq(POND.userMaxFlyGeneration(user2) / 1e12, 0 ether);

        hevm.prank(user2);
        POND.exit(tokenIds3);
        assertEq(POND.baseSharesBalance(user2), 0);
        assertEq(POND.userMaxFlyGeneration(user2) / 1e12, 0);
        assertEq(POND.totalBaseShare(), 2 * 2 * 2);
        (
            HopperNFT.Hopper memory hopper,
            uint256 prevHopperGauge,
            uint256 gaugeLimit
        ) = POND.getHopperAndGauge(2);
        assertEq(prevHopperGauge, 3 ether);
        assertEq(prevHopperGauge, gaugeLimit);

        hevm.prank(user2);
        POND.enter(tokenIds3);
        assertEq(POND.hopperOwners(2), user2);
        assertEq(POND.baseSharesBalance(user2), 2 * 2 * 2);
        assertEq(POND.totalBaseShare(), 2 * 2 * 2 + 2 * 2 * 2);
        assertEq(POND.userMaxFlyGeneration(user2) / 1e12, 0);
    }

    function testVeFLYInfluence() public {
        // Setting up
        uint256[] memory tokenIds1 = new uint256[](1);
        uint256[] memory tokenIds2 = new uint256[](1);
        uint256[] memory tokenIds3 = new uint256[](2);
        hevm.prank(user1);
        HOPPER.addHopper(0);
        hevm.prank(user1);
        HOPPER.addHopper(1);
        tokenIds2[0] = 1;

        hevm.prank(user2);
        HOPPER.addHopper(2);
        hevm.prank(user2);
        HOPPER.addHopper(3);
        tokenIds3[0] = 2;
        tokenIds3[1] = 3;

        hevm.prank(owner);
        POND.setEmissionRate(2 ether);
        hevm.prank(owner);
        POND.setBonusEmissionRate(2 ether);

        FLY.mockMint(user1, 3 ether);
        FLY.mockMint(user2, 3 ether);

        hevm.prank(user1);
        FLY.approve(address(VEFLY), 1000 ether);
        hevm.prank(user1);
        VEFLY.deposit(1 ether);

        hevm.prank(user2);
        FLY.approve(address(VEFLY), 1000 ether);
        hevm.prank(user2);
        VEFLY.deposit(1 ether);
        hevm.prank(owner);
        VEFLY.setGenerationDetails(100, 1000000, 1);

        // Start

        hevm.prank(user1);
        POND.enter(tokenIds1);

        hevm.prank(user1);
        POND.enter(tokenIds2);

        hevm.prank(user2);
        HOPPER.setApprovalForAll(address(POND), true);
        hevm.prank(user2);
        POND.enter(tokenIds3);

        hevm.warp(1);
        hevm.prank(user2);
        POND.vote(1 ether, false);
        hevm.warp(2);
        assertEq(POND.veSharesBalance(user2), 2828427124);
        assertEq(POND.totalVeShare(), 2828427124);
        assertEq(POND.claimable(user2), 3999999999999999999); // precision loss
        hevm.warp(4);
        assertEq(POND.claimable(user2), 6 ether); // caps

        hevm.prank(user2);
        POND.claim();
        assertEq(FLY.balanceOf(user2), 2 ether + 6 ether);

        hevm.warp(5);
        assertEq(POND.claimable(user2), 0); // caps
        POND.claim();
        assertEq(FLY.balanceOf(user2), 2 ether + 6 ether);

        hevm.prank(user2);
        POND.exit(tokenIds3);
        assertEq(POND.veSharesBalance(user2), 0);
        assertEq(POND.totalVeShare(), 0);
        assertEq(POND.userMaxFlyGeneration(user2) / 1e12, 0);

        hevm.prank(user2);
        POND.enter(tokenIds3);

        hevm.warp(6);
        assertEq(POND.baseSharesBalance(user2), 2 * 2 * 2);
        assertEq(POND.totalBaseShare(), 2 * 2 * 2 + 2 * 2 * 2);
        assertEq(POND.userMaxFlyGeneration(user2) / 1e12, 0);
        assertEq(POND.veSharesBalance(user2), 2828427124);
        assertEq(POND.totalVeShare(), 2828427124);
        POND.claim();
        assertEq(FLY.balanceOf(user2), 2 ether + 6 ether);

        hevm.warp(8);
        hevm.prank(user2);
        POND.exit(tokenIds3);
        POND.claim();
        assertEq(POND.claimable(user2), 0);

        hevm.warp(9);
        assertEq(POND.claimable(user2), 0);
        assertEq(POND.veSharesBalance(user2), 0);
        assertEq(POND.totalVeShare(), 0);
        assertEq(POND.userMaxFlyGeneration(user2) / 1e12, 0);
        assertEq(FLY.balanceOf(user2), 2 ether + 6 ether);

        ////////////
        //// LEVEL UP
        ////////////
        tokenIds1[0] = 2;
        hevm.prank(user2);
        POND.levelUp(2, false);

        uint256 beforeBalance = FLY.balanceOf(user2);
        hevm.prank(user2);
        POND.enter(tokenIds1);

        assertEq(POND.veSharesBalance(user2), 2449489742);
        assertEq(POND.totalVeShare(), 2449489742);
        assertEq(POND.totalBaseShare(), 2 * 2 * 2 + 2 * 3);
        assertEq(POND.userMaxFlyGeneration(user2) / 1e12, 4.5 ether); // level 3

        hevm.warp(10);
        assertEq(POND.claimable(user2), 2857142857142857141); // 2 ether(bonus) + (6/14) * 2 ether(base)
        hevm.warp(11);
        assertEq(POND.claimable(user2), 4.5 ether); // cap hit

        hevm.prank(user2);
        POND.exit(tokenIds1);
        assertEq(POND.userMaxFlyGeneration(user2) / 1e12, 0);
        hevm.prank(user2);
        POND.claim();
        assertEq(POND.claimable(user2), 0);
        assertEq(FLY.balanceOf(user2), beforeBalance + 4.5 ether);

        hevm.warp(12);
        hevm.prank(user2);
        POND.claim();
        assertEq(POND.claimable(user2), 0);
        assertEq(POND.veSharesBalance(user2), 0);
        assertEq(POND.totalVeShare(), 0);
        assertEq(POND.userMaxFlyGeneration(user2) / 1e12, 0);
        assertEq(FLY.balanceOf(user2), beforeBalance + 4.5 ether);
    }

    function testVeFLYInfluenceWithStakedLevelUp() public {
        // Setting up
        uint256[] memory tokenIds1 = new uint256[](1);
        uint256[] memory tokenIds2 = new uint256[](1);
        uint256[] memory tokenIds3 = new uint256[](2);
        hevm.prank(user1);
        HOPPER.addHopper(0);
        hevm.prank(user1);
        HOPPER.addHopper(1);
        tokenIds2[0] = 1;

        hevm.prank(user2);
        HOPPER.addHopper(2);
        hevm.prank(user2);
        HOPPER.addHopper(3);
        tokenIds3[0] = 2;
        tokenIds3[1] = 3;

        hevm.prank(owner);
        POND.setEmissionRate(2 ether);
        hevm.prank(owner);
        POND.setBonusEmissionRate(2 ether);

        FLY.mockMint(user1, 3 ether);
        FLY.mockMint(user2, 3 ether);

        hevm.prank(user1);
        FLY.approve(address(VEFLY), 1000 ether);
        hevm.prank(user1);
        VEFLY.deposit(1 ether);

        hevm.prank(user2);
        FLY.approve(address(VEFLY), 1000 ether);
        hevm.prank(user2);
        VEFLY.deposit(1 ether);
        hevm.prank(owner);
        VEFLY.setGenerationDetails(100, 1000000, 1);

        // Start

        hevm.prank(user1);
        POND.enter(tokenIds1);

        hevm.prank(user1);
        POND.enter(tokenIds2);

        hevm.prank(user2);
        HOPPER.setApprovalForAll(address(POND), true);
        hevm.prank(user2);
        POND.enter(tokenIds3);

        hevm.warp(1);
        hevm.prank(user2);
        POND.vote(1 ether, false);
        hevm.warp(2);
        hevm.warp(4);

        hevm.prank(user2);
        POND.claim();

        hevm.warp(5);
        POND.claim();

        hevm.prank(user2);
        POND.exit(tokenIds3);

        hevm.prank(user2);
        POND.enter(tokenIds3);

        hevm.warp(6);
        POND.claim();

        hevm.warp(8);
        hevm.prank(user2);
        POND.exit(tokenIds3);
        POND.claim();

        hevm.warp(9);

        tokenIds1[0] = 2;
        hevm.prank(user2);
        POND.enter(tokenIds1);
        ////////////
        //// LEVEL UP
        ////////////
        hevm.prank(user2);
        POND.levelUp(2, false);

        uint256 beforeBalance = FLY.balanceOf(user2);
        hevm.warp(10);
        hevm.warp(11);
        hevm.prank(user2);
        VEFLY.withdraw(1);

        assertEq(VEFLY.balanceOf(user2), 0);
        assertEq(POND.veFlyBalance(user2), 0);
        assertEq(POND.veSharesBalance(user2), 0);
        assertEq(POND.totalVeShare(), 0);

        hevm.warp(12);
        assertEq(POND.claimable(user2), 4.5 ether); // cap hit

        // votes have to be cast again
        assertGt(VEFLY.balanceOf(user2), 0);
        assertEq(POND.veFlyBalance(user2), 0);
        assertEq(POND.veSharesBalance(user2), 0);
        assertEq(POND.totalVeShare(), 0);

        hevm.warp(13);
        hevm.prank(user2);
        POND.claim();
        assertEq(FLY.balanceOf(user2), beforeBalance + 1 + 4.5 ether);
        assertEq(POND.claimable(user2), 0); // cap hit

        hevm.prank(user2);
        POND.exit(tokenIds1);
        assertEq(POND.userMaxFlyGeneration(user2) / 1e12, 0);
        hevm.prank(user2);
        POND.claim();

        hevm.warp(14);
        hevm.prank(user2);
        POND.claim();
        assertEq(POND.claimable(user2), 0);
        assertEq(POND.veSharesBalance(user2), 0);
        assertEq(POND.totalVeShare(), 0);
        assertEq(POND.userMaxFlyGeneration(user2) / 1e12, 0);
    }

    function testLevelUpCosts() public {
        assertEq(POND.getLevelUpCost(2 - 1), 1.0 ether);
        assertEq(POND.getLevelUpCost(3 - 1), 1.5 ether);
        assertEq(POND.getLevelUpCost(4 - 1), 2.0 ether);
        assertEq(POND.getLevelUpCost(5 - 1), 2.5 ether);
        assertEq(POND.getLevelUpCost(6 - 1), 3.0 ether);
        assertEq(POND.getLevelUpCost(7 - 1), 3.5 ether);
        assertEq(POND.getLevelUpCost(8 - 1), 4.0 ether);
        assertEq(POND.getLevelUpCost(9 - 1), 4.5 ether);
        assertEq(POND.getLevelUpCost(10 - 1), 5.0 ether);
        assertEq(POND.getLevelUpCost(11 - 1), 5.5 ether);
        assertEq(POND.getLevelUpCost(12 - 1), 6.0 ether);
        assertEq(POND.getLevelUpCost(13 - 1), 6.5 ether);
        assertEq(POND.getLevelUpCost(14 - 1), 7.0 ether);
        assertEq(POND.getLevelUpCost(15 - 1), 7.5 ether);
        assertEq(POND.getLevelUpCost(16 - 1), 8.0 ether);
        assertEq(POND.getLevelUpCost(17 - 1), 8.5 ether);
        assertEq(POND.getLevelUpCost(18 - 1), 9.0 ether);
        assertEq(POND.getLevelUpCost(19 - 1), 9.5 ether);
        assertEq(POND.getLevelUpCost(20 - 1), 10.0 ether);
        assertEq(POND.getLevelUpCost(21 - 1), 10.0 ether);
        assertEq(POND.getLevelUpCost(22 - 1), 11.0 ether);
        assertEq(POND.getLevelUpCost(23 - 1), 12.0 ether);
        assertEq(POND.getLevelUpCost(24 - 1), 12.0 ether);
        assertEq(POND.getLevelUpCost(25 - 1), 13.0 ether);
        assertEq(POND.getLevelUpCost(26 - 1), 14.0 ether);
        assertEq(POND.getLevelUpCost(27 - 1), 15.0 ether);
        assertEq(POND.getLevelUpCost(28 - 1), 15.0 ether);
        assertEq(POND.getLevelUpCost(29 - 1), 16.0 ether);
        assertEq(POND.getLevelUpCost(30 - 1), 17.0 ether);
        assertEq(POND.getLevelUpCost(31 - 1), 18.0 ether);
        assertEq(POND.getLevelUpCost(32 - 1), 19.0 ether);
        assertEq(POND.getLevelUpCost(33 - 1), 20.0 ether);
        assertEq(POND.getLevelUpCost(34 - 1), 21.0 ether);
        assertEq(POND.getLevelUpCost(35 - 1), 21.0 ether);
        assertEq(POND.getLevelUpCost(36 - 1), 22.0 ether);
        assertEq(POND.getLevelUpCost(37 - 1), 23.0 ether);
        assertEq(POND.getLevelUpCost(38 - 1), 24.0 ether);
        assertEq(POND.getLevelUpCost(39 - 1), 25.0 ether);
        assertEq(POND.getLevelUpCost(40 - 1), 26.0 ether);
        assertEq(POND.getLevelUpCost(41 - 1), 27.0 ether);
        assertEq(POND.getLevelUpCost(42 - 1), 28.0 ether);
        assertEq(POND.getLevelUpCost(43 - 1), 29.0 ether);
        assertEq(POND.getLevelUpCost(44 - 1), 30.0 ether);
        assertEq(POND.getLevelUpCost(45 - 1), 31.0 ether);
        assertEq(POND.getLevelUpCost(46 - 1), 32.0 ether);
        assertEq(POND.getLevelUpCost(47 - 1), 33.0 ether);
        assertEq(POND.getLevelUpCost(48 - 1), 34.0 ether);
        assertEq(POND.getLevelUpCost(49 - 1), 35.0 ether);
        assertEq(POND.getLevelUpCost(50 - 1), 36.0 ether);
        assertEq(POND.getLevelUpCost(51 - 1), 37.0 ether);
        assertEq(POND.getLevelUpCost(52 - 1), 38.0 ether);
        assertEq(POND.getLevelUpCost(53 - 1), 39.0 ether);
        assertEq(POND.getLevelUpCost(54 - 1), 40.0 ether);
        assertEq(POND.getLevelUpCost(55 - 1), 41.0 ether);
        assertEq(POND.getLevelUpCost(56 - 1), 43.0 ether);
        assertEq(POND.getLevelUpCost(57 - 1), 44.0 ether);
        assertEq(POND.getLevelUpCost(58 - 1), 45.0 ether);
        assertEq(POND.getLevelUpCost(59 - 1), 46.0 ether);
        assertEq(POND.getLevelUpCost(60 - 1), 47.0 ether);
        assertEq(POND.getLevelUpCost(61 - 1), 48.0 ether);
        assertEq(POND.getLevelUpCost(62 - 1), 49.0 ether);
        assertEq(POND.getLevelUpCost(63 - 1), 50.0 ether);
        assertEq(POND.getLevelUpCost(64 - 1), 52.0 ether);
        assertEq(POND.getLevelUpCost(65 - 1), 53.0 ether);
        assertEq(POND.getLevelUpCost(66 - 1), 54.0 ether);
        assertEq(POND.getLevelUpCost(67 - 1), 55.0 ether);
        assertEq(POND.getLevelUpCost(68 - 1), 56.0 ether);
        assertEq(POND.getLevelUpCost(69 - 1), 58.0 ether);
        assertEq(POND.getLevelUpCost(70 - 1), 59.0 ether);
        assertEq(POND.getLevelUpCost(71 - 1), 60.0 ether);
        assertEq(POND.getLevelUpCost(72 - 1), 61.0 ether);
        assertEq(POND.getLevelUpCost(73 - 1), 62.0 ether);
        assertEq(POND.getLevelUpCost(74 - 1), 64.0 ether);
        assertEq(POND.getLevelUpCost(75 - 1), 65.0 ether);
        assertEq(POND.getLevelUpCost(76 - 1), 66.0 ether);
        assertEq(POND.getLevelUpCost(77 - 1), 67.0 ether);
        assertEq(POND.getLevelUpCost(78 - 1), 69.0 ether);
        assertEq(POND.getLevelUpCost(79 - 1), 70.0 ether);
        assertEq(POND.getLevelUpCost(80 - 1), 71.0 ether);
        assertEq(POND.getLevelUpCost(81 - 1), 73.0 ether);
        assertEq(POND.getLevelUpCost(82 - 1), 74.0 ether);
        assertEq(POND.getLevelUpCost(83 - 1), 75.0 ether);
        assertEq(POND.getLevelUpCost(84 - 1), 77.0 ether);
        assertEq(POND.getLevelUpCost(85 - 1), 78.0 ether);
        assertEq(POND.getLevelUpCost(86 - 1), 79.0 ether);
        assertEq(POND.getLevelUpCost(87 - 1), 81.0 ether);
        assertEq(POND.getLevelUpCost(88 - 1), 82.0 ether);
        assertEq(POND.getLevelUpCost(89 - 1), 83.0 ether);
        assertEq(POND.getLevelUpCost(90 - 1), 85.0 ether);
        assertEq(POND.getLevelUpCost(91 - 1), 86.0 ether);
        assertEq(POND.getLevelUpCost(92 - 1), 87.0 ether);
        assertEq(POND.getLevelUpCost(93 - 1), 89.0 ether);
        assertEq(POND.getLevelUpCost(94 - 1), 90.0 ether);
        assertEq(POND.getLevelUpCost(95 - 1), 91.0 ether);
        assertEq(POND.getLevelUpCost(96 - 1), 93.0 ether);
        assertEq(POND.getLevelUpCost(97 - 1), 94.0 ether);
        assertEq(POND.getLevelUpCost(98 - 1), 96.0 ether);
        assertEq(POND.getLevelUpCost(99 - 1), 97.0 ether);
        assertEq(POND.getLevelUpCost(100 - 1), 98.0 ether);
        assertEq(POND.getLevelUpCost(101 - 1), type(uint256).max);
    }

    function testGaugeLimit() public {
        mockZone _ZONE = new mockZone(address(FLY), address(FLY), address(FLY));
        assertEq(_ZONE.getGaugeLimit(1), 1.5 ether);
        assertEq(_ZONE.getGaugeLimit(2), 3 ether);
        assertEq(_ZONE.getGaugeLimit(3), 4.5 ether);
        assertEq(_ZONE.getGaugeLimit(4), 6 ether);
        assertEq(_ZONE.getGaugeLimit(5), 7.5 ether);
        assertEq(_ZONE.getGaugeLimit(6), 9 ether);
        assertEq(_ZONE.getGaugeLimit(7), 10.5 ether);
        assertEq(_ZONE.getGaugeLimit(8), 12 ether);
        assertEq(_ZONE.getGaugeLimit(9), 13.5 ether);
        assertEq(_ZONE.getGaugeLimit(10), 15 ether);
        assertEq(_ZONE.getGaugeLimit(11), 16.5 ether);
        assertEq(_ZONE.getGaugeLimit(12), 18 ether);
        assertEq(_ZONE.getGaugeLimit(13), 19.5 ether);
        assertEq(_ZONE.getGaugeLimit(14), 21 ether);
        assertEq(_ZONE.getGaugeLimit(15), 22.5 ether);
        assertEq(_ZONE.getGaugeLimit(16), 24 ether);
        assertEq(_ZONE.getGaugeLimit(17), 25.5 ether);
        assertEq(_ZONE.getGaugeLimit(18), 27 ether);
        assertEq(_ZONE.getGaugeLimit(19), 28.5 ether);
        assertEq(_ZONE.getGaugeLimit(20), 30 ether);
        assertEq(_ZONE.getGaugeLimit(21), 30 ether);
        assertEq(_ZONE.getGaugeLimit(22), 33 ether);
        assertEq(_ZONE.getGaugeLimit(23), 36 ether);
        assertEq(_ZONE.getGaugeLimit(24), 36 ether);
        assertEq(_ZONE.getGaugeLimit(25), 39 ether);
        assertEq(_ZONE.getGaugeLimit(26), 42 ether);
        assertEq(_ZONE.getGaugeLimit(27), 45 ether);
        assertEq(_ZONE.getGaugeLimit(28), 45 ether);
        assertEq(_ZONE.getGaugeLimit(29), 48 ether);
        assertEq(_ZONE.getGaugeLimit(30), 51 ether);
        assertEq(_ZONE.getGaugeLimit(31), 54 ether);
        assertEq(_ZONE.getGaugeLimit(32), 57 ether);
        assertEq(_ZONE.getGaugeLimit(33), 60 ether);
        assertEq(_ZONE.getGaugeLimit(34), 63 ether);
        assertEq(_ZONE.getGaugeLimit(35), 63 ether);
        assertEq(_ZONE.getGaugeLimit(36), 66 ether);
        assertEq(_ZONE.getGaugeLimit(37), 69 ether);
        assertEq(_ZONE.getGaugeLimit(38), 72 ether);
        assertEq(_ZONE.getGaugeLimit(39), 75 ether);
        assertEq(_ZONE.getGaugeLimit(40), 78 ether);
        assertEq(_ZONE.getGaugeLimit(41), 81 ether);
        assertEq(_ZONE.getGaugeLimit(42), 84 ether);
        assertEq(_ZONE.getGaugeLimit(43), 87 ether);
        assertEq(_ZONE.getGaugeLimit(44), 90 ether);
        assertEq(_ZONE.getGaugeLimit(45), 93 ether);
        assertEq(_ZONE.getGaugeLimit(46), 96 ether);
        assertEq(_ZONE.getGaugeLimit(47), 99 ether);
        assertEq(_ZONE.getGaugeLimit(48), 102 ether);
        assertEq(_ZONE.getGaugeLimit(49), 105 ether);
        assertEq(_ZONE.getGaugeLimit(50), 108 ether);
        assertEq(_ZONE.getGaugeLimit(51), 111 ether);
        assertEq(_ZONE.getGaugeLimit(52), 114 ether);
        assertEq(_ZONE.getGaugeLimit(53), 117 ether);
        assertEq(_ZONE.getGaugeLimit(54), 120 ether);
        assertEq(_ZONE.getGaugeLimit(55), 123 ether);
        assertEq(_ZONE.getGaugeLimit(56), 129 ether);
        assertEq(_ZONE.getGaugeLimit(57), 132 ether);
        assertEq(_ZONE.getGaugeLimit(58), 135 ether);
        assertEq(_ZONE.getGaugeLimit(59), 138 ether);
        assertEq(_ZONE.getGaugeLimit(60), 141 ether);
        assertEq(_ZONE.getGaugeLimit(61), 144 ether);
        assertEq(_ZONE.getGaugeLimit(62), 147 ether);
        assertEq(_ZONE.getGaugeLimit(63), 150 ether);
        assertEq(_ZONE.getGaugeLimit(64), 156 ether);
        assertEq(_ZONE.getGaugeLimit(65), 159 ether);
        assertEq(_ZONE.getGaugeLimit(66), 162 ether);
        assertEq(_ZONE.getGaugeLimit(67), 165 ether);
        assertEq(_ZONE.getGaugeLimit(68), 168 ether);
        assertEq(_ZONE.getGaugeLimit(69), 174 ether);
        assertEq(_ZONE.getGaugeLimit(70), 177 ether);
        assertEq(_ZONE.getGaugeLimit(71), 180 ether);
        assertEq(_ZONE.getGaugeLimit(72), 183 ether);
        assertEq(_ZONE.getGaugeLimit(73), 186 ether);
        assertEq(_ZONE.getGaugeLimit(74), 192 ether);
        assertEq(_ZONE.getGaugeLimit(75), 195 ether);
        assertEq(_ZONE.getGaugeLimit(76), 198 ether);
        assertEq(_ZONE.getGaugeLimit(77), 201 ether);
        assertEq(_ZONE.getGaugeLimit(78), 207 ether);
        assertEq(_ZONE.getGaugeLimit(79), 210 ether);
        assertEq(_ZONE.getGaugeLimit(80), 213 ether);
        assertEq(_ZONE.getGaugeLimit(81), 219 ether);
        assertEq(_ZONE.getGaugeLimit(82), 222 ether);
        assertEq(_ZONE.getGaugeLimit(83), 225 ether);
        assertEq(_ZONE.getGaugeLimit(84), 231 ether);
        assertEq(_ZONE.getGaugeLimit(85), 234 ether);
        assertEq(_ZONE.getGaugeLimit(86), 237 ether);
        assertEq(_ZONE.getGaugeLimit(87), 243 ether);
        assertEq(_ZONE.getGaugeLimit(88), 246 ether);
        assertEq(_ZONE.getGaugeLimit(89), 249 ether);
        assertEq(_ZONE.getGaugeLimit(90), 255 ether);
        assertEq(_ZONE.getGaugeLimit(91), 258 ether);
        assertEq(_ZONE.getGaugeLimit(92), 261 ether);
        assertEq(_ZONE.getGaugeLimit(93), 267 ether);
        assertEq(_ZONE.getGaugeLimit(94), 270 ether);
        assertEq(_ZONE.getGaugeLimit(95), 273 ether);
        assertEq(_ZONE.getGaugeLimit(96), 279 ether);
        assertEq(_ZONE.getGaugeLimit(97), 282 ether);
        assertEq(_ZONE.getGaugeLimit(98), 288 ether);
        assertEq(_ZONE.getGaugeLimit(99), 291 ether);
        assertEq(_ZONE.getGaugeLimit(100), 294 ether);
    }
}
