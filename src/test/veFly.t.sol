import "ds-test/test.sol";

import {BaseTest, HEVM, HopperNFT, veFly} from "./BaseTest.sol";

contract veFlyTest is BaseTest {

    function faucet() internal {
        hevm.startPrank(address(POND));
        FLY.mint(user1, 10_000 ether);
        hevm.stopPrank();
    }

    function testOwnerShip() public {
        expectErrorAndSuccess(
            address(VEFLY),
            veFly.Unauthorized.selector,
            abi.encodeWithSelector(veFly.setOwner.selector, user1),
            user1,
            owner
        );
    }

    function testGenDetails() public {
        (
            uint128 maxRatio,
            uint32 generationRateNumerator,
            uint32 generationRateDenominator,

        ) = VEFLY.genDetails();

        expectErrorAndSuccess(
            address(VEFLY),
            veFly.Unauthorized.selector,
            abi.encodeWithSelector(
                veFly.setGenerationDetails.selector,
                maxRatio + 1,
                generationRateNumerator + 1,
                generationRateDenominator + 1
            ),
            user1,
            owner
        );

        (
            uint128 _maxRatio,
            uint32 _generationRateNumerator,
            uint32 _generationRateDenominator,

        ) = VEFLY.genDetails();
        assertEq(maxRatio + 1, _maxRatio);
        assertEq(generationRateNumerator + 1, _generationRateNumerator);
        assertEq(generationRateDenominator + 1, _generationRateDenominator);
    }

    function testBallots() public {
        hevm.prank(owner);
        veFly _VEFLY = new veFly(
            address(FLY),
            VEFLY_NUM_RATE,
            VEFLY_DENOM_RATE,
            VEFLY_CAP
        );

        address ballot1 = address(0xf2f2);
        address ballot2 = address(0xf1f1);

        expectErrorAndSuccess(
            address(_VEFLY),
            veFly.Unauthorized.selector,
            abi.encodeWithSelector(veFly.addBallot.selector, ballot1),
            user1,
            owner
        );

        hevm.prank(owner);
        _VEFLY.addBallot(ballot2);

        assertEq(_VEFLY.arrValidBallots(0), ballot1);
        assertEq(_VEFLY.arrValidBallots(1), ballot2);
        assert(_VEFLY.validBallots(ballot1));
        assert(_VEFLY.validBallots(ballot2));

        expectErrorAndSuccess(
            address(_VEFLY),
            veFly.Unauthorized.selector,
            abi.encodeWithSelector(veFly.removeBallot.selector, 0),
            user1,
            owner
        );
        assertEq(_VEFLY.arrValidBallots(0), ballot2);

        expectErrorAndSuccess(
            address(_VEFLY),
            veFly.Unauthorized.selector,
            abi.encodeWithSelector(veFly.setHasVoted.selector, user1),
            user1,
            ballot2
        );

        assert(_VEFLY.hasUserVoted(ballot2, user1));

        expectErrorAndSuccess(
            address(_VEFLY),
            veFly.Unauthorized.selector,
            abi.encodeWithSelector(veFly.unsetHasVoted.selector, user1),
            user1,
            ballot2
        );

        assert(!_VEFLY.hasUserVoted(ballot2, user1));
    }

    function testGenerationRate() public {

        faucet();

        (
            uint128 _maxRatio,
            uint32 _generationRateNumerator,
            uint32 _generationRateDenominator,

        ) = VEFLY.genDetails();

        hevm.prank(user1);
        VEFLY.deposit(1 ether);
        assertEq(VEFLY.balanceOf(user1), 0);

        // Current rate is 1 veFly per FLY per second, so we cap at maxRatio 1:100
        hevm.warp(1 days);
        assertEq(VEFLY.balanceOf(user1), _maxRatio * 1 ether);

        // Current rate is 1/1e8 veFly per FLY per second
        hevm.prank(owner);
        VEFLY.setGenerationDetails(_maxRatio, 1, 1e8);
        assertEq(VEFLY.balanceOf(user1), 0.000864 ether);

        hevm.warp(115000 days);
        assertEq(VEFLY.balanceOf(user1), 99.36 ether);

        hevm.warp(125000 days);
        assertEq(VEFLY.balanceOf(user1), _maxRatio * 1 ether);
    }

    function testDepositAndWithdrawals() public {
        faucet();

        hevm.startPrank(user1);
        
        VEFLY.deposit(1 ether);
        hevm.warp(1 days); // capped veFLY
        assert(VEFLY.balanceOf(user1) > 0);

        // todo withdrawal with votes casted
        // Any withdrawal triggers the veFLY reset
        assert(VEFLY.canWithdraw(user1));
        VEFLY.withdraw(0.001 ether);
        assert(VEFLY.balanceOf(user1) == 0);

        VEFLY.deposit(1 ether);
        hevm.warp(2 days); // capped veFLY
        assert(VEFLY.balanceOf(user1) > 0);

        hevm.stopPrank();
    }  
}
