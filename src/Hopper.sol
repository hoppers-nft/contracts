// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ERC721} from "@solmate/tokens/ERC721.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

//slither-disable-next-line locked-ether
contract HopperNFT is ERC721 {
    using SafeTransferLib for address;

    address public owner;

    uint256 public preSaleOpenTime;
    bytes32 public merkleRoot;

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

    mapping(uint256 => uint256) indexer;

    /*///////////////////////////////////////////////////////////////
                             
    //////////////////////////////////////////////////////////////*/

    // whitelist for leveling up
    mapping(address => bool) public zones;

    // unlabeled data [key -> tokenid -> data] for potential future zones
    mapping(bytes32 => mapping(uint256 => bytes32)) public unlabeledData;

    // unlabeled data [key -> data] for potential future zones
    mapping(bytes32 => bytes32) public unlabeledGlobalData;

    /*///////////////////////////////////////////////////////////////
                            HOPPER NAMES
    //////////////////////////////////////////////////////////////*/

    uint256 public nameFee;
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
    error TooSoon();

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
        preSaleOpenTime = type(uint256).max - 30 minutes;
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

    function setPreSale(uint256 _preSaleOpenTime, bytes32 _merkleRoot)
        external
        onlyOwner
    {
        preSaleOpenTime = _preSaleOpenTime;
        merkleRoot = _merkleRoot;
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

    function rebirth(uint256 _tokenId) external {
        Hopper memory hopper = hoppers[_tokenId];

        if (ownerOf[_tokenId] != msg.sender) revert Unauthorized();
        if (hopper.level < 100) revert OnlyLvL100();

        hoppers[_tokenId].agility = uint8(_ascend(hopper.agility));
        hoppers[_tokenId].intelligence = uint8(_ascend(hopper.intelligence));
        hoppers[_tokenId].strength = uint8(_ascend(hopper.strength));
        hoppers[_tokenId].vitality = uint8(_ascend(hopper.vitality));
        hoppers[_tokenId].fertility = uint8(_ascend(hopper.fertility));
        hoppers[_tokenId].level = 1;
    }

    function levelUp(uint256 tokenId) external onlyZone {
        // max level is checked on zone
        unchecked {
            ++(hoppers[tokenId].level);
        }
        emit LevelUp(hoppers[tokenId].level);
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

    function _mintHoppers(uint256 numberOfMints, uint256 preTotalHoppers)
        internal
    {
        uint256 seed = enoughRandom();

        uint256 _indexerLength = MAX_SUPPLY - preTotalHoppers;
        for (uint256 i; i < numberOfMints; ++i) {
            seed >>= i;

            // Find the next available tokenID
            uint256 index = seed % _indexerLength;
            uint256 tokenId = indexer[index];

            if (tokenId == 0) {
                tokenId = index;
            }

            // Swapped the picked tokenId for the last element
            uint256 last = indexer[_indexerLength - 1];
            if (last == 0) {
                indexer[index] = _indexerLength - 1;
            } else {
                indexer[index] = last;
            }
            _indexerLength -= 1;

            // Mint Hopper and generate its attributes
            _mint(msg.sender, tokenId);
            hoppers[tokenId] = generate(seed);
        }
    }

    /*///////////////////////////////////////////////////////////////
                            HOPPER MINTING
    //////////////////////////////////////////////////////////////*/

    function _handleMint(uint256 numberOfMints) internal {
        // solhint-disable-next-line
        if (msg.sender != tx.origin) revert OnlyEOAAllowed();

        unchecked {
            uint256 totalHoppers = hoppersLength + numberOfMints;

            if (numberOfMints > MAX_PER_ADDRESS || totalHoppers > MAX_SUPPLY)
                revert MintLimit();

            _mintHoppers(numberOfMints, totalHoppers - numberOfMints);
            hoppersLength = totalHoppers;
        }
    }

    function whitelistMint(uint256 numberOfMints, bytes32[] memory proof)
        external
        payable
    {
        if (block.timestamp < preSaleOpenTime) revert TooSoon();
        if (((MINT_COST * 70) / 10) * numberOfMints > msg.value)
            revert InsufficientAmount();

        if (
            !MerkleProof.verify(
                proof,
                merkleRoot,
                keccak256(abi.encodePacked(msg.sender))
            )
        ) revert Unauthorized();

        _handleMint(numberOfMints);
    }

    function normalMint(uint256 numberOfMints) external payable {
        unchecked {
            if (block.timestamp < preSaleOpenTime + 30 minutes)
                revert TooSoon();
        }
        if (MINT_COST * numberOfMints > msg.value) revert InsufficientAmount();

        _handleMint(numberOfMints);
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

    function _jsonString(uint256 tokenId) public returns (string memory) {
        return "todo";
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
