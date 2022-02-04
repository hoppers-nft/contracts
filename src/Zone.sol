// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {Fly} from "./Fly.sol";
import {HopperNFT} from "./Hopper.sol";

abstract contract Zone {
    /*///////////////////////////////////////////////////////////////
                            IMMUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable FLY;
    address public immutable HOPPER;

    /*///////////////////////////////////////////////////////////////
                                HOPPERS
    //////////////////////////////////////////////////////////////*/
    mapping(uint256 => address) public hopperOwners;
    mapping(uint256 => uint256) public hopperSnapshots;

    constructor(address fly, address hopper) {
        FLY = fly;
        HOPPER = hopper;
    }

    function enter(uint256 tokenId) external {
        hopperOwners[tokenId] = msg.sender;
        // solhint-disable-next-line
        hopperSnapshots[tokenId] = block.timestamp;
        HopperNFT(HOPPER).transferFrom(msg.sender, address(this), tokenId);
    }

    function exit(uint256 tokenId) external {
        uint256 hourDuration;
        unchecked {
            // todo
            hourDuration =
                // solhint-disable-next-line
                ((block.timestamp - hopperSnapshots[tokenId]) / 60) /
                60;
        }

        HopperNFT.Hopper memory hopper = HopperNFT(HOPPER).getHopper(tokenId);
        uint256 amount = calculateFarmAmount(hopper, tokenId, hourDuration);

        delete hopperOwners[tokenId];
        delete hopperSnapshots[tokenId];

        Fly(FLY).mint(msg.sender, amount);
        HopperNFT(HOPPER).transferFrom(address(this), msg.sender, tokenId);
    }

    function calculateFarmAmount(
        HopperNFT.Hopper memory hopper,
        uint256 tokenId,
        uint256 hourDuration
    ) internal pure virtual returns (uint256) {} // solhint-disable-line
}
