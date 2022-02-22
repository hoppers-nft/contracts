// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.12;

import {ERC721} from "@solmate/tokens/ERC721.sol";

//slither-disable-next-line locked-ether
contract Tadpole is ERC721 {
    address public owner;
    address public breedingSpot;
    address public exchanger;

    /*///////////////////////////////////////////////////////////////
                                  TADPOLES
    //////////////////////////////////////////////////////////////*/

    // 0 Common
    // 1 Rare
    // 2 Exceptional
    // 3 Epic
    // 4 Legendary
    // mapping(uint256 => uint256) public tadpoleCategory;

    struct Tadpole {
        uint128 category;
        uint64 skin;
        uint64 hat;
    }

    mapping(uint256 => Tadpole) public tadpoles;

    uint256 public totalSupply;
    string public baseURI;

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized();

    /*///////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event OwnerUpdated(address indexed newOwner);

    /*///////////////////////////////////////////////////////////////
                           CONTRACT MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    constructor(string memory _NFT_NAME, string memory _NFT_SYMBOL)
        ERC721(_NFT_NAME, _NFT_SYMBOL)
    {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    function setOwner(address _newOwner) external onlyOwner {
        //slither-disable-next-line missing-zero-check
        owner = _newOwner;
        emit OwnerUpdated(_newOwner);
    }

    function setBreedingSpot(address _breedingSpot) external onlyOwner {
        breedingSpot = _breedingSpot;
    }

    function setExchanger(address _exchanger) external onlyOwner {
        exchanger = _exchanger;
    }

    function setBaseURI(string calldata _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    /*///////////////////////////////////////////////////////////////
                           TADPOLE
    //////////////////////////////////////////////////////////////*/

    function _getCategory(uint256 _seed) internal returns (uint256) {
        uint256 randomness = _seed % 1000;

        // 0 Common
        // 1 Rare
        // 2 Exceptional
        // 3 Epic
        // 4 Legendary

        if (randomness >= 600) {
            return 0;
        } else if (randomness < 600 && randomness >= 300) {
            return 1;
        } else if (randomness < 300 && randomness >= 100) {
            return 2;
        } else if (randomness < 100 && randomness >= 10) {
            return 3;
        } else {
            return 4;
        }
    }

    function _getHat(uint256 category, uint256 seed) internal returns (uint256) {
        if (category == 4) {
            return seed % 5;
        } else if (category == 3) {
            return seed % 6;
        } else if (category == 2) {
            return seed % 6;
        } else if (category == 1) {
            return seed % 6;
        } else {    // if (category == 0)
            return seed % 6;
        }
    }

    function mint(address _receiver, uint256 _seed) external {
        if (breedingSpot != msg.sender) revert Unauthorized();

        unchecked {
            uint256 tokenId = totalSupply++;
            _mint(_receiver, tokenId);

            uint256 category = _getCategory(_seed);

            tadpoles[tokenId] = Tadpole({
                category: uint128(category),
                hat: uint64(_getHat(_seed >> 1, category)),
                skin: uint64((_seed >> 2) % 10)
            });
        }
    }

    function burn(address _owner, uint256 _tokenId) external {
        if (exchanger != msg.sender) revert Unauthorized();
        if (ownerOf[_tokenId] != _owner) revert Unauthorized();

        _burn(_tokenId);
    }

    /*///////////////////////////////////////////////////////////////
                           ERC721 VIEW
    //////////////////////////////////////////////////////////////*/

    function _getCategoryName(uint256 category)
        internal
        pure
        returns (string memory)
    {
        if (category == 0) {
            return "Common";
        } else if (category == 0) {
            return "Rare";
        } else if (category == 0) {
            return "Exceptional";
        } else if (category == 0) {
            return "Epic";
        } else if (category == 0) {
            return "Legendary";
        }
        return "Undefined";
    }

    function _jsonString(uint256 tokenId) public view returns (string memory) {
        Tadpole memory tadpole = tadpoles[tokenId];
        return
            string(
                bytes.concat(
                    '{"name":"tadpole #',
                    bytes(_toString(tokenId)),
                    '", "description":"Tadpole", "attributes":[',
                    '{"trait_type": "category", "value": "',
                    bytes(_getCategoryName(tadpole.category)),
                    '"},',
                    '{"trait_type": "hat", "value": ',
                    bytes(_toString(tadpole.hat)),
                    '},',
                    '{"trait_type": "skin", "value": ',
                    bytes(_toString(tadpole.skin)),
                    '}',
                    "],",
                    '"image":"https://',
                    bytes(baseURI),
                    bytes(_toString(tokenId)),
                    '"}'
                )
            );
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        //slither-disable-next-line redundant-statements
        tokenId;
        return "TODO"; // todo
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
