// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.12;

import {HopperNFT} from "../Hopper.sol";
import {Zone} from "../Zone.sol";

contract Forest is Zone {
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
            hopper.agility != 5 ||
            hopper.vitality != 5 ||
            hopper.intelligence != 5 ||
            hopper.level != 15
        ) return false;
        return true;
    }

    function _calculateBaseShare(HopperNFT.Hopper memory hopper)
        internal
        pure
        override
        returns (uint256)
    {
        return
            uint256(hopper.agility) *
                uint256(hopper.vitality) *
                uint256(hopper.intelligence) *
                uint256(hopper.level);
    }
}
