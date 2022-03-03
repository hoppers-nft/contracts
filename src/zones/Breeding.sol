// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.12;

import {HopperNFT} from "../Hopper.sol";
import {Fly} from "../Fly.sol";
import {TadpoleNFT} from "../Tadpole.sol";

import {ERC721} from "@solmate/tokens/ERC721.sol";

contract Breeding {
    address public owner;

    /*///////////////////////////////////////////////////////////////
                            IMMUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable FLY;
    address public immutable HOPPER;
    address public immutable TADPOLE;

    /*///////////////////////////////////////////////////////////////
                                HOPPERS
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => address) public hopperOwners;
    mapping(uint256 => uint256) public hopperUnlockTime;
    uint256 public breedingCost;

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error Unauthorized();
    error OnlyEOAAllowed();
    error TooSoon();

    /*///////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event UpdatedOwner(address indexed owner);

    /*///////////////////////////////////////////////////////////////
                           CONTRACT MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    constructor(
        address _fly,
        address _hopper,
        address _tadpole,
        uint256 _breedingCost
    ) {
        owner = msg.sender;

        FLY = _fly;
        HOPPER = _hopper;
        TADPOLE = _tadpole;

        breedingCost = _breedingCost;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
        emit UpdatedOwner(_owner);
    }

    function setBreedingCost(uint256 _breedingCost) external onlyOwner {
        breedingCost = _breedingCost;
    }

    /*///////////////////////////////////////////////////////////////
                                TADPOLE
    //////////////////////////////////////////////////////////////*/

    function enoughRandom() internal view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        // solhint-disable-next-line
                        block.timestamp,
                        msg.sender,
                        blockhash(block.number)
                    )
                )
            );
    }

    function _roll(uint256 _tokenId) internal {
        HopperNFT.Hopper memory hopper = HopperNFT(HOPPER).getHopper(_tokenId);

        uint256 rand = enoughRandom() % 10_000;

        uint256 chance;

        unchecked {
            chance =
                (90000 *
                    uint256(hopper.fertility) +
                    9000 *
                    3 *
                    uint256(hopper.level)) /
                400;
        }

        if (rand < chance) TadpoleNFT(TADPOLE).mint(msg.sender, rand >> 8);
    }

    /*///////////////////////////////////////////////////////////////
                                STAKING
    //////////////////////////////////////////////////////////////*/

    function enter(uint256 _tokenId) external {
        // solhint-disable-next-line
        if (msg.sender != tx.origin) revert OnlyEOAAllowed();

        hopperOwners[_tokenId] = msg.sender;

        unchecked {
            hopperUnlockTime[_tokenId] = block.timestamp + 1 days;
        }

        ERC721(HOPPER).transferFrom(msg.sender, address(this), _tokenId);
        Fly(FLY).burn(msg.sender, breedingCost);
    }

    function exit(uint256 _tokenId) external {
        if (hopperOwners[_tokenId] != msg.sender) revert Unauthorized();
        if (hopperUnlockTime[_tokenId] > block.timestamp) revert TooSoon();

        _roll(_tokenId);

        delete hopperOwners[_tokenId];
        delete hopperUnlockTime[_tokenId];

        ERC721(HOPPER).transferFrom(address(this), msg.sender, _tokenId);
    }
}
