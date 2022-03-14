// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.12;

import {Zone} from "./Zone.sol";

contract BatchExit {
    function runIt(
        address[] calldata adventures,
        uint256[][] calldata tokenIds,
        address[] calldata users
    ) public {
        assert(adventures.length == tokenIds.length);
        assert(adventures.length == users.length);
        uint256 length = adventures.length;
        for (uint256 i; i < length; ) {
            Zone(adventures[i]).emergencyExit(tokenIds[i], users[i]);

            unchecked {
                ++i;
            }
        }
    }
}
