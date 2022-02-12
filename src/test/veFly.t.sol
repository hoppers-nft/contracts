import "ds-test/test.sol";

import {BaseTest, HEVM, HopperNFT} from "./BaseTest.sol";

contract veFlyTest is BaseTest {
    function testGenDetails() public {
        (
            uint128 maxRatio,
            uint64 generationRate,
            uint64 lastUpdatedTime
        ) = VEFLY.genDetails();
    }
}
