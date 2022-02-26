import "ds-test/test.sol";

import {BaseTest, HEVM, HopperNFT, Ballot} from "./BaseTest.sol";

contract mockZone {
    uint256 public bonusEmissionRate;

    function forceUnvote(address user) public {
        // user1
        assert(user == address(0x3333));
    }

    function setBonusEmissionRate(uint256 fakeRate) public {
        bonusEmissionRate = fakeRate;
    }
}

contract mockVeFly {
    function balanceOf(address) public returns (uint256) {
        return 1 ether;
    }

    function setHasVoted(address) public {}

    function unsetHasVoted(address) public {}
}

contract mockFly {
    function mint(address user, uint256 amount) public returns (uint256) {
        // user2
        assert(user == address(0x1338));
        assert(amount == 1 ether);
    }
}

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
            abi.encodeWithSelector(
                Ballot.openBallot.selector,
                REWARD_EMISSION_RATE,
                BONUS_EMISSION_RATE
            ),
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

    function testBallotVoting() public {
        mockZone _ZONE1 = new mockZone();
        mockZone _ZONE2 = new mockZone();
        mockFly _FLY = new mockFly();
        mockVeFly _VEFLY = new mockVeFly();
        Ballot _BALLOT = new Ballot(address(_FLY), address(_VEFLY));

        _BALLOT.openBallot(1 ether, 1 ether);

        address[] memory _zones = new address[](2);
        _zones[0] = address(_ZONE1);
        _zones[1] = address(_ZONE2);
        _BALLOT.addZones(_zones);

        // Not enough veFLY to Vote
        hevm.prank(address(_ZONE1));
        hevm.expectRevert(
            abi.encodeWithSelector(Ballot.NotEnoughVeFly.selector)
        );
        _BALLOT.vote(user1, 1.1 ether);

        // Can vote multiple times in different zones
        hevm.prank(address(_ZONE1));
        _BALLOT.vote(user1, 0.5 ether);
        assertEq(_BALLOT.userVeFlyUsed(user1), 0.5 ether);

        hevm.prank(address(_ZONE2));
        _BALLOT.vote(user1, 0.5 ether);

        // Make sure zoneVotes are accounted correctly
        assertEq(_BALLOT.userVeFlyUsed(user1), 1 ether);
        assertEq(_BALLOT.zonesVotes(address(_ZONE1)), 0.5 ether);
        assertEq(_BALLOT.zonesVotes(address(_ZONE2)), 0.5 ether);
        assertEq(_BALLOT.zonesUserVotes(address(_ZONE1), user1), 0.5 ether);
        assertEq(_BALLOT.zonesUserVotes(address(_ZONE2), user1), 0.5 ether);

        hevm.prank(address(_ZONE1));
        hevm.expectRevert(
            abi.encodeWithSelector(Ballot.NotEnoughVeFly.selector)
        );
        _BALLOT.unvote(user1, 0.6 ether);

        // Make sure
        hevm.prank(address(_ZONE1));
        hevm.expectRevert(
            abi.encodeWithSelector(Ballot.NotEnoughVeFly.selector)
        );
        _BALLOT.vote(user1, 0.1 ether);

        ////////////////////
        ////////////////////
        hevm.warp(1);
        assertEq(_BALLOT.countReward(), 1 ether);

        // assertions happen inside mockFly
        hevm.prank(user2, user2);
        _BALLOT.count();

        assertEq(_ZONE1.bonusEmissionRate(), 0.5 ether);
        assertEq(_ZONE2.bonusEmissionRate(), 0.5 ether);

        // Unvote from zone1
        hevm.prank(address(_ZONE1));
        _BALLOT.unvote(user1, 0.5 ether);

        // Count again
        _BALLOT.count();
        assertEq(_ZONE1.bonusEmissionRate(), 0 ether);
        assertEq(_ZONE2.bonusEmissionRate(), 1 ether);

        // Unvote from zone2
        hevm.prank(address(_ZONE2));
        _BALLOT.unvote(user1, 0.5 ether);
        _BALLOT.count();

        assertEq(_ZONE1.bonusEmissionRate(), 0 ether);
        assertEq(_ZONE2.bonusEmissionRate(), 0 ether);

        ////////////////////
        ////////////////////
        /// Force unvoting

        hevm.prank(address(_ZONE1));
        _BALLOT.vote(address(0x3333), 0.5 ether);

        hevm.prank(address(_ZONE2));
        _BALLOT.vote(address(0x3333), 0.5 ether);

        _BALLOT.count();

        assertEq(_ZONE1.bonusEmissionRate(), 0.5 ether);
        assertEq(_ZONE2.bonusEmissionRate(), 0.5 ether);

        hevm.prank(address(_VEFLY));
        _BALLOT.forceUnvote(address(0x3333));

        _BALLOT.count();

        assertEq(_ZONE1.bonusEmissionRate(), 0 ether);
        assertEq(_ZONE2.bonusEmissionRate(), 0 ether);

        assertEq(_BALLOT.userVeFlyUsed(address(0x3333)), 0 ether);
        assertEq(_BALLOT.zonesVotes(address(_ZONE1)), 0 ether);
        assertEq(_BALLOT.zonesVotes(address(_ZONE2)), 0 ether);
        assertEq(
            _BALLOT.zonesUserVotes(address(_ZONE1), address(0x3333)),
            0 ether
        );
        assertEq(
            _BALLOT.zonesUserVotes(address(_ZONE2), address(0x3333)),
            0 ether
        );

        ////////////////////
        ////////////////////
        // Auth
        expectErrorAndSuccess(
            address(_BALLOT),
            Ballot.Unauthorized.selector,
            abi.encodeWithSelector(Ballot.vote.selector, 0x3333, 2),
            user1,
            address(_ZONE1)
        );
        expectErrorAndSuccess(
            address(_BALLOT),
            Ballot.Unauthorized.selector,
            abi.encodeWithSelector(Ballot.unvote.selector, 0x3333, 2),
            user1,
            address(_ZONE1)
        );
        expectErrorAndSuccess(
            address(_BALLOT),
            Ballot.Unauthorized.selector,
            abi.encodeWithSelector(Ballot.forceUnvote.selector, 0x3333),
            user1,
            address(_VEFLY)
        );
    }
}
