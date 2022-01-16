// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {Fly} from "./Fly.sol";
import {FrogNFT} from "./Frog.sol";

contract CareTaker {
    /*///////////////////////////////////////////////////////////////
                            IMMUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable FLY;
    address public immutable FROG;

    error InvalidOwner();

    constructor(address fly, address frog) {
        // slither-disable-next-line missing-zero-check
        FLY = fly;
        // slither-disable-next-line missing-zero-check
        FROG = frog;
    }

    function levelUp(uint256 tokenId) external {
        if (FrogNFT(FROG).ownerOf(tokenId) != msg.sender) revert InvalidOwner();

        // todo how much fly
        // todo how much XP (FrogNFT might have to consume internally)
    }
}
