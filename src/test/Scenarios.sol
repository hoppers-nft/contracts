// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.12;

import "ds-test/test.sol";

import {BaseTest, HEVM, ERC721, Ballot, veFly, HopperNFT} from "./BaseTest.sol";

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

    function setWithVeFLY() public returns (uint256 earnIn1Hour) {
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
        assertGt(amountveFLY, 0);
    }

    function setVotingScenario() public returns (uint256 earnIn1Hour) {
        earnIn1Hour = setWithVeFLY();

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
        assertEq(POND.claimable(user1), earnIn1Hour / 2);
        assertEq(STREAM.claimable(user1), earnIn1Hour / 2);

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

    // function testFuzzedScenario(
    //     bool[10] calldata acts,
    //     uint256[10] calldata amounts
    // ) public {
    //     uint256 earnIn1Hour = setWithVeFLY();

    //     assert(VEFLY.balanceOf(user1) > 0);
    //     assert(FLY.balanceOf(user1) > 0);

    //     // Setting up
    //     uint256[] memory tokenIds = new uint256[](2);
    //     tokenIds[0] = 144;
    //     tokenIds[1] = 3093;

    //     uint256 timeChunks = 1 hours;
    //     uint256 time;
    //     bool act;

    //     (, uint256[] memory tokenIds0_1) = getHoppers(2, true);
    //     hevm.startPrank(user1, user1);
    //     uint256 whichAct;
    //     for (uint256 i; i < acts.length; i++) {
    //         act = acts[i];
    //         time += timeChunks;
    //         hevm.warp(2 hours + time);
    //         if (act && whichAct == 0) {
    //             emit log_uint(whichAct);
    //             if (
    //                 amounts[i] >
    //                 (VEFLY.balanceOf(user1) - BALLOT.userVeFlyUsed(user1))
    //             ) {
    //                 hevm.expectRevert(
    //                     abi.encodeWithSelector(Ballot.NotEnoughVeFly.selector)
    //                 );
    //             }
    //             POND.vote(amounts[i], amounts[i] % 2 == 0);
    //             whichAct = 1;
    //         }
    //         act = acts[i];
    //         time += timeChunks;
    //         hevm.warp(2 hours + time);
    //         if (act && whichAct == 1) {
    //             emit log_uint(whichAct);
    //             if (amounts[i] > BALLOT.userVeFlyUsed(user1)) {
    //                 hevm.expectRevert(
    //                     abi.encodeWithSelector(Ballot.NotEnoughVeFly.selector)
    //                 );
    //             }
    //             POND.unvote(amounts[i], amounts[i] % 2 == 0);
    //             whichAct = 2;
    //         }
    //         act = acts[i];
    //         time += timeChunks;
    //         hevm.warp(2 hours + time);
    //         if (act && whichAct == 2) {
    //             emit log_uint(whichAct);
    //             if (amounts[i] > VEFLY.flyBalanceOf(user1)) {
    //                 hevm.expectRevert(
    //                     abi.encodeWithSelector(veFly.InvalidAmount.selector)
    //                 );
    //             }
    //             VEFLY.withdraw(amounts[i]);
    //             whichAct = 3;
    //         }
    //         act = acts[i];
    //         time += timeChunks;
    //         hevm.warp(2 hours + time);
    //         if (act && whichAct == 3) {
    //             emit log_uint(whichAct);
    //             hevm.assume(amounts[i] <= FLY.balanceOf(user1));
    //             VEFLY.deposit(amounts[i]);
    //             whichAct = 4;
    //         }
    //         act = acts[i];
    //         time += timeChunks;
    //         hevm.warp(2 hours + time);
    //         if (act && whichAct == 4) {
    //             emit log_uint(whichAct);
    //             // tokenId
    //             uint256 tokenId = tokenIds[amounts[i] % 2];
    //             uint256[] memory _tokenIds = new uint256[](1);
    //             _tokenIds[0] = tokenId;
    //             if (HOPPER.ownerOf(tokenId) == user1) {
    //                 POND.enter(_tokenIds);
    //             } else {
    //                 POND.exit(_tokenIds);
    //             }
    //             whichAct = 0;
    //         }
    //     }

    //     VEFLY.withdraw(VEFLY.flyBalanceOf(user1));
    //     assertEq(POND.veSharesBalance(user1), 0);
    //     assertEq(BALLOT.zonesUserVotes(address(POND), user1), 0);

    //     hevm.stopPrank();
    // }
}
