// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {HopperNFT, Zone} from "../Zone.sol";

contract Pond is Zone {
    constructor(address fly, address hopper) Zone(fly, hopper) {}

    function calculateFarmAmount(
        HopperNFT.Hopper memory hopper,
        uint256 tokenId,
        uint256 hourDuration
    ) internal pure override returns (uint256) {
        return ((1 + hopper.strength) * hourDuration * hopper.level) / 5;
    }
}
