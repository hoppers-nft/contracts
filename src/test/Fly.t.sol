import "ds-test/test.sol";

import {BaseTest, HEVM, HopperNFT, Fly} from "./BaseTest.sol";

contract FLYTest is BaseTest {
    function testOwnerShip() public {
        expectErrorAndSuccess(
            address(FLY),
            Fly.Unauthorized.selector,
            abi.encodeWithSelector(Fly.setOwner.selector, user1),
            user1,
            owner
        );
    }

    function testZones() public {
        hevm.prank(owner);
        Fly _FLY = new Fly("FLY", "FLY");

        address zone1 = address(0xe1e1);

        expectErrorAndSuccess(
            address(_FLY),
            Fly.Unauthorized.selector,
            abi.encodeWithSelector(Fly.addZone.selector, zone1),
            user1,
            owner
        );

        assert(_FLY.zones(zone1));

        expectErrorAndSuccess(
            address(_FLY),
            Fly.Unauthorized.selector,
            abi.encodeWithSelector(Fly.removeZone.selector, zone1),
            user1,
            owner
        );

        assert(!_FLY.zones(zone1));

        hevm.prank(owner);
        _FLY.addZone(zone1);

        assertEq(_FLY.totalSupply(), 0);

        expectErrorAndSuccess(
            address(_FLY),
            Fly.Unauthorized.selector,
            abi.encodeWithSelector(Fly.mint.selector, user1, 1 ether),
            owner,
            zone1
        );

        assertEq(_FLY.totalSupply(), 1 ether);
        assertEq(_FLY.balanceOf(user1), 1 ether);

        expectErrorAndSuccess(
            address(_FLY),
            Fly.Unauthorized.selector,
            abi.encodeWithSelector(Fly.burn.selector, user1, 0.5 ether),
            owner,
            zone1
        );

        assertEq(_FLY.totalSupply(), 0.5 ether);
        assertEq(_FLY.balanceOf(user1), 0.5 ether);
    }
}
