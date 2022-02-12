// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ERC721} from "@solmate/tokens/ERC721.sol";

//slither-disable-next-line locked-ether
contract HopperNFT is ERC721 {
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
        uint208 level; // capped by zone
        uint8 strength;
        uint8 agility;
        uint8 vitality;
        uint8 intelligence;
        uint8 fertility;
        uint8 category;
        // name ?
    }

    mapping(uint256 => Hopper) public hoppers;
    uint256 public hoppersLength;

    // whitelist for leveling up
    mapping(address => bool) public zones;

    // unlabeled data [key -> tokenid -> data] for potential future adventures
    mapping(bytes32 => mapping(uint256 => bytes32)) public unlabeledData;

    // unlabeled data [key -> data] for potential future adventures
    mapping(bytes32 => bytes32) public unlabeledGlobalData;

    /*///////////////////////////////////////////////////////////////
                            HOPPER NAMES
    //////////////////////////////////////////////////////////////*/

    uint256 nameFee;
    mapping(bytes32 => bool) public takenNames;
    mapping(uint256 => string) public hoppersNames;

    /*///////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event OwnerUpdated(address indexed newOwner);
    event LevelUp(uint256 tokenId);
    event NameChange(uint256 tokenId);
    event UpdatedNameFee(uint256 namefee);

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error MintLimit();
    error InsufficientAmount();
    error Unauthorized();
    error InvalidTokenID();
    error MaxLength25();
    error OnlyEOAAllowed();
    error NameTaken();
    error OnlyLvL100();

    constructor(
        string memory _NFT_NAME,
        string memory _NFT_SYMBOL,
        uint256 _MINT_COST,
        uint256 _MAX_SUPPLY,
        uint256 _MAX_PER_ADDRESS,
        uint256 _SALE_TIME,
        uint256 _NAME_FEE
    ) ERC721(_NFT_NAME, _NFT_SYMBOL) {
        owner = msg.sender;

        MINT_COST = _MINT_COST;
        MAX_SUPPLY = _MAX_SUPPLY;
        SALE_TIME = _SALE_TIME;
        //slither-disable-next-line missing-zero-check
        MAX_PER_ADDRESS = _MAX_PER_ADDRESS;

        nameFee = _NAME_FEE;
    }

    /*///////////////////////////////////////////////////////////////
                    CONTRACT MANAGEMENT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyZone() {
        if (!zones[msg.sender]) revert Unauthorized();
        _;
    }

    modifier onlyOwnerOrZone() {
        if (msg.sender != owner && !zones[msg.sender]) revert Unauthorized();
        _;
    }

    function setOwner(address newOwner) external onlyOwner {
        //slither-disable-next-line missing-zero-check
        owner = newOwner;
        emit OwnerUpdated(newOwner);
    }

    function setNameChangeFee(uint256 _nameFee) external onlyOwner {
        nameFee = _nameFee;
        emit UpdatedNameFee(_nameFee);
    }

    function withdraw() external onlyOwner {
        owner.safeTransferETH(address(this).balance);
    }

    /*///////////////////////////////////////////////////////////////
                    HOPPER VALID ZONES/ADVENTURES
    //////////////////////////////////////////////////////////////*/

    function addZone(address _zone) external onlyOwner {
        zones[_zone] = true;
    }

    function removeZone(address _zone) external onlyOwner {
        delete zones[_zone];
    }

    /*///////////////////////////////////////////////////////////////
                            Unlabeled Data
    //////////////////////////////////////////////////////////////*/

    function setGlobalData(bytes32 _key, bytes32 _data)
        external
        onlyOwnerOrZone
    {
        unlabeledGlobalData[_key] = _data;
    }

    function unsetGlobalData(bytes32 _key) external onlyOwnerOrZone {
        delete unlabeledGlobalData[_key];
    }

    function getGlobalData(bytes32 _key) external view returns (bytes32) {
        return unlabeledGlobalData[_key];
    }

    function setData(
        bytes32 _key,
        uint256 _tokenId,
        bytes32 _data
    ) external onlyOwnerOrZone {
        unlabeledData[_key][_tokenId] = _data;
    }

    function unsetData(bytes32 _key, uint256 _tokenId)
        external
        onlyOwnerOrZone
    {
        delete unlabeledData[_key][_tokenId];
    }

    function getData(bytes32 _key, uint256 _tokenId)
        external
        view
        returns (bytes32)
    {
        return unlabeledData[_key][_tokenId];
    }

    function getHopperWithData(bytes32[] calldata _keys, uint256 _tokenId)
        external
        view
        returns (Hopper memory hopper, bytes32[] memory arrData)
    {
        hopper = hoppers[_tokenId];

        uint256 length = _keys.length;
        arrData = new bytes32[](length);

        for (uint256 i; i < length; i++) {
            arrData[i] = unlabeledData[_keys[i]][_tokenId];
        }
    }

    /*///////////////////////////////////////////////////////////////
                        HOPPER LEVEL SYSTEM
    //////////////////////////////////////////////////////////////*/

    function _ascend(uint256 attribute) internal pure returns (uint256) {
        return attribute == 10 ? 10 : (attribute + 1);
    }

    function rebirth(uint256 tokenId) external {
        Hopper memory hopper = hoppers[tokenId];

        if (ownerOf[tokenId] != msg.sender) revert Unauthorized();
        if (hopper.level != 100) revert OnlyLvL100();

        hoppers[tokenId].agility = uint8(_ascend(hopper.agility));
        hoppers[tokenId].intelligence = uint8(_ascend(hopper.intelligence));
        hoppers[tokenId].strength = uint8(_ascend(hopper.strength));
        hoppers[tokenId].vitality = uint8(_ascend(hopper.vitality));
        hoppers[tokenId].fertility = uint8(_ascend(hopper.fertility));
        hoppers[tokenId].level = 1;
    }

    function levelUp(uint256 tokenId) external onlyZone {
        // max level is checked on zone
        unchecked {
            ++(hoppers[tokenId].level);
        }
    }

    function changeHopperName(uint256 tokenId, string calldata newName)
        external
        onlyZone
        returns (uint256)
    {
        if (bytes(newName).length > 25) revert MaxLength25();

        // Checks new name uniqueness
        bytes32 nameHash = keccak256(bytes(newName));
        if (takenNames[nameHash]) revert NameTaken();

        // Free previous name
        takenNames[keccak256(bytes(hoppersNames[tokenId]))] = false;

        // Reserve name
        takenNames[nameHash] = true;
        hoppersNames[tokenId] = newName;

        emit NameChange(tokenId);

        return nameFee;
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
                    level: 1,
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
        override(ERC721)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
