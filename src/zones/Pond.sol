// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {HopperNFT, Zone} from "../Zone.sol";

contract Pond is Zone {
    constructor(address fly,
        address vefly,
        address hopper) Zone(fly, vefly, hopper) {}

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
        return (hopper.strength * hopper.level * 10e8) / (10 * 100);
    }
}
