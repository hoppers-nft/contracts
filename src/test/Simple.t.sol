// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import "ds-test/test.sol";

// import "../veFly.sol";
// import "../Fly.sol";
// import "../Hopper.sol";
// import "../Ballot.sol";
// import "../zones/Pond.sol";
// import "../zones/Stream.sol";
import {BaseTest, HEVM} from "./BaseTest.sol";

contract HopperWorld is BaseTest {
    function testSimpleScenario() public {
        // Setting up
        uint256 numHoppers = 2;
        uint256[] memory tokenIds = new uint256[](numHoppers);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        // Mint 2 hoppers
        hevm.startPrank(user1, user1);
        HOPPER.mint{value: MINT_COST * numHoppers}(numHoppers);

        // Stake hoppers to earn FLY for a day
        POND.enter(tokenIds);
        hevm.warp(100 days);
        POND.claim();
        uint256 earn100days = FLY.balanceOf(user1);
        assert(earn100days > 0);

        // Stake FLY to earn veFly
        VEFLY.deposit(earn100days);
        hevm.warp(200 days);
        assert(VEFLY.balanceOf(user1) > 0);
        POND.claim();
        assert(FLY.balanceOf(user1) == earn100days);

        // Vote with veFly
        uint256 amountveFLY = VEFLY.balanceOf(user1);
        bool forceRecount = true;
        POND.vote(amountveFLY, forceRecount);
        assert(POND.veSharesBalance(user1) > 0);

        // FLY reward should be higher than 100 days because of veShare
        hevm.warp(300 days);
        POND.claim();
        assert(FLY.balanceOf(user1) > 2 * earn100days);
        emit log_uint(FLY.balanceOf(user1));
        emit log_uint(2 * earn100days);

        hevm.stopPrank();
    }
}
