import "ds-test/test.sol";

import {BaseTest, HEVM, HopperNFT, veFly} from "./BaseTest.sol";

contract veFlyTest is BaseTest {
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
        (uint128 maxRatio, uint64 generationRate, ) = VEFLY.genDetails();

        expectErrorAndSuccess(
            address(VEFLY),
            veFly.Unauthorized.selector,
            abi.encodeWithSelector(
                veFly.setGenerationDetails.selector,
                maxRatio + 1,
                generationRate + 1
            ),
            user1,
            owner
        );

        (uint128 _maxRatio, uint64 _generationRate, ) = VEFLY.genDetails();
        assertEq(maxRatio + 1, _maxRatio);
        assertEq(generationRate + 1, _generationRate);
    }

    function testBallots() public {

        hevm.prank(owner);
        veFly _VEFLY = new veFly(address(FLY), VEFLY_RATE, VEFLY_CAP);

        address ballot1 = address(0xf2f2);
        address ballot2 = address(0xf1f1);

        expectErrorAndSuccess(
            address(_VEFLY),
            veFly.Unauthorized.selector,
            abi.encodeWithSelector(
                veFly.addBallot.selector,
                ballot1
            ),
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
            abi.encodeWithSelector(
                veFly.removeBallot.selector,
                0
            ),
            user1,
            owner
        );
        assertEq(_VEFLY.arrValidBallots(0), ballot2);

        expectErrorAndSuccess(
            address(_VEFLY),
            veFly.Unauthorized.selector,
            abi.encodeWithSelector(
                veFly.setHasVoted.selector,
                user1
            ),
            user1,
            ballot2
        );

        assert(_VEFLY.hasUserVoted(ballot2, user1));

        expectErrorAndSuccess(
            address(_VEFLY),
            veFly.Unauthorized.selector,
            abi.encodeWithSelector(
                veFly.unsetHasVoted.selector,
                user1
            ),
            user1,
            ballot2
        );

        assert(!_VEFLY.hasUserVoted(ballot2, user1));

    }

    function testDeposit() public {
        // VEFLY.deposit(amount);
    }
}
