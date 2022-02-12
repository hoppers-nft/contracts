// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

contract Fly is ERC20 {
    address public owner;

    // whitelist for minting mechanisms
    mapping(address => uint256) public zones;

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized();

    /*///////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event OwnerUpdated(address indexed newOwner);

    constructor(string memory _NFT_NAME, string memory _NFT_SYMBOL)
        ERC20(_NFT_NAME, _NFT_SYMBOL, 18)
    {
        owner = msg.sender;
    }

    /*///////////////////////////////////////////////////////////////
                    CONTRACT MANAGEMENT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    function setOwner(address newOwner) external onlyOwner {
        //slither-disable-next-line missing-zero-check
        owner = newOwner;
        emit OwnerUpdated(newOwner);
    }

    /*///////////////////////////////////////////////////////////////
                            Zones - mint ERC20

                            TODO: // should we set a delay
                            on a new zone being able to mint stuff?
    //////////////////////////////////////////////////////////////*/

    modifier onlyZone() {
        if (zones[msg.sender] == 0) revert Unauthorized();
        _;
    }

    function addZone(address zone) external onlyOwner {
        zones[zone] = 1;
    }

    function removeZone(address zone) external onlyOwner {
        delete zones[zone];
    }

    /*///////////////////////////////////////////////////////////////
                                MINT / BURN
    //////////////////////////////////////////////////////////////*/

    function mint(address receiver, uint256 amount) external onlyZone {
        _mint(receiver, amount);
    }

    function burn(address from, uint256 amount) external onlyZone {
        _burn(from, amount);
    }
}
