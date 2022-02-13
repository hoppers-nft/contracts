import "ds-test/test.sol";

import {BaseTest, HEVM, HopperNFT, Ballot} from "./BaseTest.sol";

contract BallotTest is BaseTest {
    function testOwnerShip() public {
        expectErrorAndSuccess(
            address(BALLOT),
            Ballot.Unauthorized.selector,
            abi.encodeWithSelector(Ballot.setOwner.selector, user1),
            user1,
            owner
        );

        expectErrorAndSuccess(
            address(BALLOT),
            Ballot.Unauthorized.selector,
            abi.encodeWithSelector(
                Ballot.setBonusEmissionRate.selector,
                0x1337
            ),
            owner, // it changed on the first call
            user1
        );
        assertEq(BALLOT.bonusEmissionRate(), 0x1337);

        expectErrorAndSuccess(
            address(BALLOT),
            Ballot.Unauthorized.selector,
            abi.encodeWithSelector(Ballot.setCountRewardRate.selector, 0x1338),
            owner, // it changed on the first call
            user1
        );
    }

    function testOpenClose() public {
        expectErrorAndSuccess(
            address(BALLOT),
            Ballot.Unauthorized.selector,
            abi.encodeWithSelector(Ballot.openBallot.selector),
            user1,
            owner
        );

        hevm.warp(1 days);
        assert(BALLOT.countReward() > 0);

        expectErrorAndSuccess(
            address(BALLOT),
            Ballot.Unauthorized.selector,
            abi.encodeWithSelector(Ballot.closeBallot.selector),
            user1,
            owner
        );

        hevm.warp(1 days);
        assert(BALLOT.countReward() == 0);
    }

    function testZones() public {
        address[] memory zones = getZones();

        expectErrorAndSuccess(
            address(BALLOT),
            Ballot.Unauthorized.selector,
            abi.encodeWithSelector(Ballot.addZones.selector, zones),
            user1,
            owner
        );
        assertEq(BALLOT.arrZones(1), zones[1]);

        expectErrorAndSuccess(
            address(BALLOT),
            Ballot.Unauthorized.selector,
            abi.encodeWithSelector(Ballot.removeZone.selector, 0),
            user1,
            owner
        );

        // swapped last 4th element to first position
        assertEq(BALLOT.arrZones(0), zones[1]);
    }
}
