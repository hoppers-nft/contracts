// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ERC721} from "@solmate/tokens/ERC721.sol";
import {ERC2981} from "./ERC2981.sol";

//slither-disable-next-line locked-ether
contract HopperNFT is ERC721, ERC2981 {
    using SafeTransferLib for address;

    address public owner;

    /*///////////////////////////////////////////////////////////////
                            IMMUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/
    uint256 public immutable MAX_PER_ADDRESS;
    uint256 public immutable MAX_SUPPLY;
    uint256 public immutable MINT_COST;
    uint256 public immutable SALE_TIME;

    /*///////////////////////////////////////////////////////////////
                                HOPPERS
    //////////////////////////////////////////////////////////////*/

    struct Hopper {
        uint208 level;
        uint8 strength;
        uint8 agility;
        uint8 vitality;
        uint8 intelligence;
        uint8 fertility;
        uint8 category;
    }

    mapping(uint256 => string) public hoppersNames;
    mapping(uint256 => Hopper) public hoppers;
    uint256 public hoppersLength;

    // whitelist for leveling up
    mapping(address => uint256) public caretakers;

    /*///////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event OwnerUpdated(address indexed newOwner);
    event LevelUp(uint256 tokenId);
    event NameChange(uint256 tokenId);

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error MintLimit();
    error InsufficientAmount();
    error Unauthorized();
    error InvalidTokenID();
    error MaxLength25();
    error OnlyEOAAllowed();
    error MaxLevelReached();

    constructor(
        string memory _NFT_NAME,
        string memory _NFT_SYMBOL,
        uint256 _MINT_COST,
        uint256 _MAX_SUPPLY,
        uint256 _MAX_PER_ADDRESS,
        address _ROYALTY_ADDRESS,
        uint256 _ROYALTY_FEE,
        uint256 _SALE_TIME
    ) ERC721(_NFT_NAME, _NFT_SYMBOL) ERC2981(_ROYALTY_ADDRESS, _ROYALTY_FEE) {
        owner = msg.sender;

        MINT_COST = _MINT_COST;
        MAX_SUPPLY = _MAX_SUPPLY;
        SALE_TIME = _SALE_TIME;

        //slither-disable-next-line missing-zero-check
        MAX_PER_ADDRESS = _MAX_PER_ADDRESS;
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

    function withdraw() external onlyOwner {
        owner.safeTransferETH(address(this).balance);
    }

    /*///////////////////////////////////////////////////////////////
                        HOPPER LEVEL MECHANICS
            Caretakers are other authorized contracts that
                according to their own logic can issue a hopper
                    to level up
    //////////////////////////////////////////////////////////////*/

    modifier onlyCareTaker() {
        if (caretakers[msg.sender] == 0) revert Unauthorized();
        _;
    }

    function addCaretaker(address caretaker) external onlyOwner {
        caretakers[caretaker] = 1;
    }

    function removeCaretaker(address caretaker) external onlyOwner {
        delete caretakers[caretaker];
    }

    function levelUp(uint256 tokenId) external onlyCareTaker {
        // max level is checked on zone
        unchecked {
            ++(hoppers[tokenId].level);
        }
    }

    function changeHopperName(uint256 tokenId, string calldata name)
        external
        onlyCareTaker
    {
        if (bytes(name).length > 25) revert MaxLength25();

        hoppersNames[tokenId] = name;

        emit NameChange(tokenId);
    }

    /*///////////////////////////////////////////////////////////////
                          HOPPER GENERATION
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

    //slither-disable-next-line weak-prng
    function generate(uint256 seed) internal pure returns (Hopper memory) {
        unchecked {
            return
                Hopper({
                    strength: uint8((seed >> (8 * 1)) % 10) + 1,
                    agility: uint8((seed >> (8 * 2)) % 10) + 1,
                    vitality: uint8((seed >> (8 * 3)) % 10) + 1,
                    intelligence: uint8((seed >> (8 * 4)) % 10) + 1,
                    fertility: uint8((seed >> (8 * 5)) % 10) + 1,
                    level: 0,
                    category: 0
                });
        }
    }

    function mint(uint256 numberOfMints) external payable {
        if (MINT_COST * numberOfMints > msg.value) revert InsufficientAmount();
        if (msg.sender != tx.origin) revert OnlyEOAAllowed();

        uint256 hopperID = hoppersLength;

        if (
            numberOfMints > MAX_PER_ADDRESS ||
            hopperID + numberOfMints > MAX_SUPPLY
        ) revert MintLimit();

        // overflow is unrealistic
        unchecked {
            hoppersLength += numberOfMints;

            uint256 seed = enoughRandom();
            for (uint256 i; i < numberOfMints; ++i) {
                _mint(msg.sender, hopperID + i);
                hoppers[hopperID + i] = generate(seed >> i);
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                          HOPPER VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // todo fix
    function getHopper(uint256 tokenId) external view returns (Hopper memory) {
        return hoppers[tokenId];
    }

    function getHopperName(uint256 tokenId)
        public
        view
        returns (string memory name)
    {
        name = hoppersNames[tokenId];

        if (bytes(name).length == 0) {
            name = "Unnamed";
        }
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

    function supportsInterface(bytes4 interfaceId)
        public
        pure
        override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
