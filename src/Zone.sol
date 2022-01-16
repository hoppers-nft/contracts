// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;


import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {Fly} from "./Fly.sol";
import {FrogNFT} from "./Frog.sol";

abstract contract Zone {

    /*///////////////////////////////////////////////////////////////
                            IMMUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable FLY;
    address public immutable FROG;

    /*///////////////////////////////////////////////////////////////
                                FROGS
    //////////////////////////////////////////////////////////////*/
    mapping(uint256 => address) frogOwners;
    mapping(uint256 => uint256) frogSnapshots;

    constructor(address fly, address frog) {
        FLY = fly;
        FROG = frog;
    }

    function enter(uint256 tokenId) external {
        FrogNFT(FROG).transferFrom(msg.sender, address(this), tokenId);
        frogOwners[tokenId] = msg.sender;
        frogSnapshots[tokenId] = block.timestamp;
    }

    function exit(uint256 tokenId) external {
        uint256 hourDuration;
        unchecked {
            // todo
            hourDuration = ((block.timestamp - frogSnapshots[tokenId]) / 60) / 60;
        }

        FrogNFT.Frog memory frog = FrogNFT(FROG).getFrog(tokenId);
        uint256 amount = calculateFarmAmount(frog, tokenId, hourDuration);

        delete frogOwners[tokenId];
        delete frogSnapshots[tokenId];

        Fly(FLY).mint(msg.sender, amount);
        FrogNFT(FROG).transferFrom(address(this), msg.sender, tokenId);
    }

    function calculateFarmAmount(FrogNFT.Frog memory frog, uint256 tokenId, uint256 hourDuration) internal pure virtual returns (uint256);
}