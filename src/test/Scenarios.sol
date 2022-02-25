// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.12;

import "ds-test/test.sol";

import {BaseTest, HEVM, ERC721} from "./BaseTest.sol";

contract HopperWorld is BaseTest {
    function getHoppers(uint256 numHoppers, bool firstBatch)
        public
        returns (uint256, uint256[] memory)
    {
        // Setting up
        uint256[] memory tokenIds = new uint256[](numHoppers);

        if (firstBatch) {
            tokenIds[0] = 4142;
            tokenIds[1] = 2738;
        } else {
            tokenIds[0] = 144;
            tokenIds[1] = 3093;
        }

        // Mint 2 hoppers
        hevm.prank(user1, user1);
        HOPPER.normalMint{value: MINT_COST * numHoppers}(numHoppers);

        return (numHoppers, tokenIds);
    }

    function setVotingScenario() public returns (uint256 earnIn1Hour) {
        (, uint256[] memory tokenIds0_1) = getHoppers(2, true);
        (, uint256[] memory tokenIds2_3) = getHoppers(2, false);

        hevm.startPrank(user1, user1);

        // Stake hoppers to earn FLY for a day
        STREAM.enter(tokenIds0_1);
        POND.enter(tokenIds2_3);
        hevm.warp(1 hours);
        POND.claim();
        STREAM.claim();
        earnIn1Hour = FLY.balanceOf(user1);
        assertGt(earnIn1Hour, 0);

        // Stake FLY to earn veFly
        VEFLY.deposit(earnIn1Hour);
        hevm.warp(2 hours);
        assertGt(VEFLY.balanceOf(user1), 0);
        POND.claim();
        STREAM.claim();
        assertEq(FLY.balanceOf(user1), earnIn1Hour);

        // Vote with veFly
        uint256 amountveFLY = VEFLY.balanceOf(user1);
        uint256 countReward = BALLOT.countReward();

        assertGt(countReward, 0);

        POND.vote(amountveFLY / 2, false);
        STREAM.vote(amountveFLY / 2, true);

        // User should have received the voting count reward
        assertEq(FLY.balanceOf(user1), earnIn1Hour + countReward);

        // Get rid of reward it, to have cleaner scenarios
        FLY.transfer(address(0), countReward);

        assertGt(POND.veSharesBalance(user1), 0);
        assertGt(STREAM.veSharesBalance(user1), 0);
    }

    function testSimpleScenario() public {
        uint256 earnIn1Hour = setVotingScenario();

        hevm.startPrank(user1, user1);

        // FLY reward should be higher than 3 hours because of veShare
        hevm.warp(3 hours);
        POND.claim();
        STREAM.claim();
        // 2 * earnIn1Hour because of the staked FLY
        assertGt(FLY.balanceOf(user1), 2 * earnIn1Hour);

        hevm.stopPrank();
    }

    function testScenarioForceUnvote() public {
        uint256 earnIn1Hour = setVotingScenario();

        hevm.startPrank(user1, user1);

        // veFLY unstake forces unvotes
        VEFLY.withdraw(earnIn1Hour);

        assertEq(POND.veSharesBalance(user1), 0);
        assertEq(STREAM.veSharesBalance(user1), 0);
        assertEq(VEFLY.balanceOf(user1), 0);

        // Since time hasn't passed, should only get the earnIn1Hour after 3 hours
        hevm.warp(3 hours);
        POND.claim();
        STREAM.claim();
        assertEq(FLY.balanceOf(user1), 3 * earnIn1Hour);

        hevm.stopPrank();
    }

    function testScenarioUnvote() public {
        uint256 earnIn1Hour = setVotingScenario();

        hevm.startPrank(user1, user1);

        uint256 beforeVeFlyBalance = VEFLY.balanceOf(user1);
        assertGt(beforeVeFlyBalance, 0);

        // veFLY unstake forces unvotes
        POND.unvote(VEFLY.balanceOf(user1) / 2, false);
        STREAM.unvote(VEFLY.balanceOf(user1) / 2, false);

        assertEq(POND.veSharesBalance(user1), 0);
        assertEq(STREAM.veSharesBalance(user1), 0);
        assertEq(VEFLY.balanceOf(user1), beforeVeFlyBalance);

        // Since time hasn't passed, should only get the earnIn1Hour after 3 hours
        hevm.warp(3 hours);
        POND.claim();
        STREAM.claim();
        assertEq(FLY.balanceOf(user1), 2 * earnIn1Hour);

        hevm.stopPrank();
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
}
