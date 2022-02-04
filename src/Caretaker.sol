// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {Fly} from "./Fly.sol";
import {HopperNFT} from "./Hopper.sol";

contract CareTaker {
    /*///////////////////////////////////////////////////////////////
                            IMMUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable FLY;
    address public immutable HOPPER;

    error InvalidOwner();

    constructor(address fly, address hopper) {
        // slither-disable-next-line missing-zero-check
        FLY = fly;
        // slither-disable-next-line missing-zero-check
        HOPPER = hopper;
    }

    function levelUp(uint256 tokenId) external {
        if (HopperNFT(HOPPER).ownerOf(tokenId) != msg.sender)
            revert InvalidOwner();

        // todo how much fly
        // todo how much XP (HopperNFT might have to consume internally)
    }
}
