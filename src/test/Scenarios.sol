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

        for(uint256 i; i < numHoppers; ++i) {
            tokenIds[i] =  i + HOPPER.hoppersLength();
        }

        // Mint 2 hoppers
        hevm.prank(user1, user1);
        HOPPER.mint{value: MINT_COST * numHoppers}(numHoppers);

        return (numHoppers, tokenIds);
    }

    function setVotingScenario() public returns (uint256 earn100days) {

        (, uint256[] memory tokenIds0_1) = getHoppers(2);
        (, uint256[] memory tokenIds2_3) = getHoppers(2);

        hevm.startPrank(user1, user1);

        // Stake hoppers to earn FLY for a day
        STREAM.enter(tokenIds0_1);
        POND.enter(tokenIds2_3);
        hevm.warp(100 days);
        POND.claim();
        STREAM.claim();
        earn100days = FLY.balanceOf(user1);
        assertGt(earn100days, 0);

        // Stake FLY to earn veFly
        VEFLY.deposit(earn100days);
        hevm.warp(200 days);
        assertGt(VEFLY.balanceOf(user1), 0);
        POND.claim();
        STREAM.claim();
        assertEq(FLY.balanceOf(user1), earn100days);

        // Vote with veFly
        uint256 amountveFLY = VEFLY.balanceOf(user1);
        POND.vote(amountveFLY / 2, false);
        STREAM.vote(amountveFLY / 2, true);

        assertGt(POND.veSharesBalance(user1), 0);
        assertGt(STREAM.veSharesBalance(user1), 0);

    }

    function testSimpleScenario() public {
        uint256 earn100days = setVotingScenario();
        
        hevm.startPrank(user1, user1);
        
        // FLY reward should be higher than 100 days because of veShare
        hevm.warp(300 days);
        POND.claim();
        STREAM.claim();
        assertGt(FLY.balanceOf(user1), 2 * earn100days);

        hevm.stopPrank();
    }

    function testScenarioForceUnvote() public {

        uint256 earn100days = setVotingScenario();

        hevm.startPrank(user1, user1);

        // veFLY unstake forces unvotes
        VEFLY.withdraw(earn100days);
        assertEq(POND.veSharesBalance(user1), 0);
        assertEq(STREAM.veSharesBalance(user1), 0);
        assertEq(VEFLY.balanceOf(user1), 0);

        // Since time hasn't passed, should only get the earn100days
        hevm.warp(300 days);
        assertEq(FLY.balanceOf(user1), 2 * earn100days);

        hevm.stopPrank();
    }
}
