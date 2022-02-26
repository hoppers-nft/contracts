// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.12;

import {HopperNFT} from "../Hopper.sol";
import {Zone} from "../Zone.sol";

contract Stream is Zone {
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
        return true;
    }

    function _calculateBaseShare(HopperNFT.Hopper memory hopper)
        internal
        pure
        override
        returns (uint256)
    {
        return uint256(hopper.agility) * uint256(hopper.level);
    }
}
