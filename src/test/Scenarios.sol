// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import "ds-test/test.sol";

import {BaseTest, HEVM, ERC721} from "./BaseTest.sol";

contract HopperWorld is BaseTest {
    function getHoppers(uint256 numHoppers)
        public
        returns (uint256, uint256[] memory)
    {
        // Setting up
        uint256[] memory tokenIds = new uint256[](numHoppers);

        for (uint256 i; i < numHoppers; ++i) {
            tokenIds[i] = i + HOPPER.hoppersLength();
        }

        // Mint 2 hoppers
        hevm.prank(user1, user1);
        HOPPER.mint{value: MINT_COST * numHoppers}(numHoppers);

        return (numHoppers, tokenIds);
    }

    function setVotingScenario() public returns (uint256 earnIn1Hour) {
        (, uint256[] memory tokenIds0_1) = getHoppers(2);
        (, uint256[] memory tokenIds2_3) = getHoppers(2);

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
        POND.vote(amountveFLY / 2, false);
        STREAM.vote(amountveFLY / 2, true);

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
}
