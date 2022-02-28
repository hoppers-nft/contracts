import "ds-test/test.sol";

import {BaseTest, HEVM, HopperNFT, veFly, Zone} from "./BaseTest.sol";

contract ZoneTest is BaseTest {
    function testZoneOwnership() public {
        address fakeBallot = address(0x8888);
        expectErrorAndSuccess(
            address(POND),
            Zone.Unauthorized.selector,
            abi.encodeWithSelector(Zone.setBallot.selector, fakeBallot),
            user1,
            owner
        );

        expectErrorAndSuccess(
            address(POND),
            Zone.Unauthorized.selector,
            abi.encodeWithSelector(Zone.setEmissionRate.selector, 1 ether),
            user1,
            owner
        );

        expectErrorAndSuccess(
            address(POND),
            Zone.Unauthorized.selector,
            abi.encodeWithSelector(Zone.setBonusEmissionRate.selector, 1 ether),
            user1,
            owner
        );

        expectErrorAndSuccess(
            address(POND),
            Zone.Unauthorized.selector,
            abi.encodeWithSelector(Zone.setBonusEmissionRate.selector, 1 ether),
            user1,
            fakeBallot
        );

        expectErrorAndSuccess(
            address(POND),
            Zone.Unauthorized.selector,
            abi.encodeWithSelector(Zone.setFlyLevelCapRatio.selector, 1 ether),
            user1,
            owner
        );

        expectErrorAndSuccess(
            address(POND),
            Zone.Unauthorized.selector,
            abi.encodeWithSelector(Zone.setOwner.selector, user1),
            user1,
            owner
        );
    }
}
