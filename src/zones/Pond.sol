// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FrogNFT, Zone} from "../Zone.sol";

contract Pond is Zone {
    constructor(address fly, address frog) Zone(fly, frog) {}

    function calculateFarmAmount(
        FrogNFT.Frog memory frog,
        uint256 tokenId,
        uint256 hourDuration
    ) internal pure override returns (uint256) {
        return ((1 + frog.strength) * hourDuration * frog.level) / 5;
    }
}
