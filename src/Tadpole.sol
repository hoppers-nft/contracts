// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.12;

import {ERC721} from "@solmate/tokens/ERC721.sol";

//slither-disable-next-line locked-ether
contract TadpoleNFT is ERC721 {
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

    struct Tadpole {
        uint128 category;
        uint64 skin;
        uint56 hat;
        uint8 background;
    }

    mapping(uint256 => Tadpole) public tadpoles;

    uint256 public nextTokenID;
    string public baseURI;

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized();
    error InvalidTokenID();

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

    function _getCategory(uint256 _seed) internal pure returns (uint256) {
        uint256 randomness = _seed % 1000;

        // 0 Common
        // 1 Rare
        // 2 Exceptional
        // 3 Epic
        // 4 Legendary

        if (randomness >= 500) {
            return 0;
        } else if (randomness < 500 && randomness >= 200) {
            return 1;
        } else if (randomness < 200 && randomness >= 50) {
            return 2;
        } else if (randomness < 50 && randomness >= 4) {
            return 3;
        } else {
            return 4;
        }
    }

    function _getHat(uint256 category, uint256 seed)
        internal
        pure
        returns (uint256)
    {
        // 0 Common
        // 1 Rare
        // 2 Exceptional
        // 3 Epic
        // 4 Legendary

        if (category == 4) {
            return seed % 5;
        } else if (category == 3) {
            return seed % 6;
        } else if (category == 2) {
            return seed % 8;
        } else if (category == 1) {
            return seed % 10;
        } else {
            // if (category == 0)
            return seed % 15;
        }
    }

    function mint(address _receiver, uint256 _seed) external {
        if (breedingSpot != msg.sender) revert Unauthorized();

        unchecked {
            uint256 tokenId = nextTokenID++;
            _mint(_receiver, tokenId);

            uint256 category = _getCategory(_seed);

            tadpoles[tokenId] = Tadpole({
                category: uint128(category),
                skin: uint64((_seed >> 1) % 8),
                hat: uint56(_getHat(category, _seed >> 2)),
                background: uint8((_seed >> 3) % 9)
            });
        }
    }

    function burn(address _tadOwner, uint256 _tokenId) external {
        if (exchanger != msg.sender) revert Unauthorized();
        if (ownerOf[_tokenId] != _tadOwner) revert Unauthorized();

        delete tadpoles[_tokenId];

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
        } else if (category == 1) {
            return "Rare";
        } else if (category == 2) {
            return "Exceptional";
        } else if (category == 3) {
            return "Epic";
        } else if (category == 4) {
            return "Legendary";
        }
        return "Undefined";
    }

    function _jsonString(uint256 tokenId) public view returns (string memory) {
        Tadpole memory tadpole = tadpoles[tokenId];
        return
            string.concat(
                '{"name":"tadpole #',
                _toString(tokenId),
                '", "description":"Tadpole", "attributes":[',
                '{"trait_type": "category", "value": "',
                _getCategoryName(tadpole.category),
                '"},',
                '{"trait_type": "background", "value": ',
                _toString(tadpole.background),
                "},",
                '{"trait_type": "hat", "value": ',
                _toString(tadpole.hat),
                "},",
                '{"trait_type": "skin", "value": ',
                _toString(tadpole.skin),
                "}",
                "],",
                '"image":"',
                baseURI,
                _toString(tokenId),
                '"}'
            );
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        if (ownerOf[tokenId] == address(0)) revert InvalidTokenID();

        return _jsonString(tokenId);
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
