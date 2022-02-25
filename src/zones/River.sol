// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.12;

import {HopperNFT} from "../Hopper.sol";
import {Zone} from "../Zone.sol";

contract River is Zone {
    constructor(
        address fly,
        address vefly,
        address hopper
    ) Zone(fly, vefly, hopper) {}

    // solhint-disable-next-line
    function canEnter(HopperNFT.Hopper memory hopper)
        public
        pure
        override
        returns (bool)
    {
        if (
            hopper.strength != 5 ||
            hopper.intelligence != 5 ||
            hopper.level != 10
        ) return true;
        return false;
    }

    function _calculateBaseShare(HopperNFT.Hopper memory hopper)
        internal
        pure
        override
        returns (uint256)
    {
        return
            (uint256(hopper.strength) *
                uint256(hopper.intelligence) *
                uint256(hopper.level) *
                10e8) / (10 * 10 * 100);
    }
}
