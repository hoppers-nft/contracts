// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.12;

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ERC721} from "@solmate/tokens/ERC721.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

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
    uint256 public immutable WL_MINT_COST;
    uint256 public immutable LEGENDARY_ID_START;

    /*///////////////////////////////////////////////////////////////
                              SALE DETAILS
    //////////////////////////////////////////////////////////////*/

    uint256 public reserved;
    uint256 public preSaleOpenTime;
    bytes32 public freeMerkleRoot;
    bytes32 public wlMerkleRoot;
    mapping(address => uint256) public freeRedeemed;
    mapping(address => uint256) public wlRedeemed;

    /*///////////////////////////////////////////////////////////////
                                HOPPERS
    //////////////////////////////////////////////////////////////*/

    struct Hopper {
        uint200 level; // capped by zone
        uint16 rebirths;
        uint8 strength;
        uint8 agility;
        uint8 vitality;
        uint8 intelligence;
        uint8 fertility;
    }

    mapping(uint256 => Hopper) public hoppers;
    uint256 public hoppersLength;
    uint256 public hopperMaxAttributeValue;

    mapping(uint256 => uint256) public indexer;

    string public baseURI;
    string public imageURL;

    /*///////////////////////////////////////////////////////////////
                             
    //////////////////////////////////////////////////////////////*/

    // whitelist for leveling up
    mapping(address => bool) public zones;

    // unlabeled data [key -> tokenid -> data] for potential future zones
    mapping(string => mapping(uint256 => bytes32)) public unlabeledData;

    // unlabeled data [key -> data] for potential future zones
    mapping(string => bytes32) public unlabeledGlobalData;

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
    event Rebirth(uint256 tokenId);
    event UnlabeledData(string key, uint256 tokenId);

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
    error ReservedAmountInvalid();
    error OnlyAlphanumeric();

    constructor(
        string memory _NFT_NAME,
        string memory _NFT_SYMBOL,
        uint256 _NAME_FEE
    ) ERC721(_NFT_NAME, _NFT_SYMBOL) {
        owner = msg.sender;

        MINT_COST = 1.75 ether;
        WL_MINT_COST = 1.2 ether;
        MAX_SUPPLY = 10_000;
        MAX_PER_ADDRESS = 10;
        LEGENDARY_ID_START = 9968;

        nameFee = _NAME_FEE;
        hopperMaxAttributeValue = 10;
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

    function setHopperMaxAttributeValue(uint256 _hopperMaxAttributeValue)
        external
        onlyOwner
    {
        hopperMaxAttributeValue = _hopperMaxAttributeValue;
    }

    function setNameChangeFee(uint256 _nameFee) external onlyOwner {
        nameFee = _nameFee;
        emit UpdatedNameFee(_nameFee);
    }

    function setBaseURI(string calldata _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    function setImageURL(string calldata _imageURL) external onlyOwner {
        imageURL = _imageURL;
    }

    function setSaleDetails(
        uint256 _preSaleOpenTime,
        bytes32 _wlMerkleRoot,
        bytes32 _freeMerkleRoot,
        uint256 _reserved
    ) external onlyOwner {
        preSaleOpenTime = _preSaleOpenTime;

        freeMerkleRoot = _freeMerkleRoot;
        wlMerkleRoot = _wlMerkleRoot;

        reserved = _reserved;
    }

    function withdraw() external onlyOwner {
        owner.safeTransferETH(address(this).balance);
    }

    /*///////////////////////////////////////////////////////////////
                    HOPPER VALID ZONES/ADVENTURES
    //////////////////////////////////////////////////////////////*/

    function addZones(address[] calldata _zones) external onlyOwner {
        uint256 length = _zones.length;
        for (uint256 i; i < length; ++i) {
            zones[_zones[i]] = true;
        }
    }

    function removeZone(address _zone) external onlyOwner {
        delete zones[_zone];
    }

    /*///////////////////////////////////////////////////////////////
                            Unlabeled Data
    //////////////////////////////////////////////////////////////*/

    function setGlobalData(string calldata _key, bytes32 _data)
        external
        onlyOwnerOrZone
    {
        unlabeledGlobalData[_key] = _data;
    }

    function unsetGlobalData(string calldata _key) external onlyOwnerOrZone {
        delete unlabeledGlobalData[_key];
    }

    function getGlobalData(string calldata _key)
        external
        view
        returns (bytes32)
    {
        return unlabeledGlobalData[_key];
    }

    function setData(
        string calldata _key,
        uint256 _tokenId,
        bytes32 _data
    ) external onlyOwnerOrZone {
        unlabeledData[_key][_tokenId] = _data;

        emit UnlabeledData(_key, _tokenId);
    }

    function unsetData(string calldata _key, uint256 _tokenId)
        external
        onlyOwnerOrZone
    {
        delete unlabeledData[_key][_tokenId];
    }

    function getData(string calldata _key, uint256 _tokenId)
        external
        view
        returns (bytes32)
    {
        return unlabeledData[_key][_tokenId];
    }

    function getHopperWithData(string[] calldata _keys, uint256 _tokenId)
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

    function rebirth(uint256 _tokenId) external {
        Hopper memory hopper = hoppers[_tokenId];

        if (ownerOf[_tokenId] != msg.sender) revert Unauthorized();
        if (hopper.level < 100) revert OnlyLvL100();

        uint256 _hopperMaxAttributeValue = hopperMaxAttributeValue;

        unchecked {
            if (hopper.strength < _hopperMaxAttributeValue) {
                hoppers[_tokenId].strength = uint8(hopper.strength + 1);
            }

            if (hopper.intelligence < _hopperMaxAttributeValue) {
                hoppers[_tokenId].intelligence = uint8(hopper.intelligence + 1);
            }

            if (hopper.agility < _hopperMaxAttributeValue) {
                hoppers[_tokenId].agility = uint8(hopper.agility + 1);
            }

            if (hopper.vitality < _hopperMaxAttributeValue) {
                hoppers[_tokenId].vitality = uint8(hopper.vitality + 1);
            }

            if (hopper.fertility < _hopperMaxAttributeValue) {
                hoppers[_tokenId].fertility = uint8(hopper.fertility + 1);
            }

            ++hoppers[_tokenId].rebirths;
        }

        hoppers[_tokenId].level = 1;

        delete unlabeledData["LEVEL_GAUGE_KEY"][_tokenId];

        emit Rebirth(_tokenId);
    }

    function levelUp(uint256 tokenId) external onlyZone {
        // max level is checked on zone
        unchecked {
            ++(hoppers[tokenId].level);
        }
        emit LevelUp(hoppers[tokenId].level);
    }

    function changeHopperName(uint256 tokenId, string calldata _newName)
        external
        onlyZone
        returns (uint256)
    {
        bytes memory newName = bytes(_newName);
        uint256 newLength = newName.length;

        if (newLength > 25) revert MaxLength25();

        // Checks it's only alphanumeric characters
        for (uint256 i; i < newLength; i++) {
            bytes1 char = newName[i];

            if (
                !(char >= 0x30 && char <= 0x39) && //9-0
                !(char >= 0x41 && char <= 0x5A) && //A-Z
                !(char >= 0x61 && char <= 0x7A) && //a-z
                !(char == 0x2E) //.
            ) {
                revert OnlyAlphanumeric();
            }
        }

        // Checks new name uniqueness
        bytes32 nameHash = keccak256(newName);
        if (takenNames[nameHash]) revert NameTaken();

        // Free previous name
        takenNames[keccak256(bytes(hoppersNames[tokenId]))] = false;

        // Reserve name
        takenNames[nameHash] = true;
        hoppersNames[tokenId] = _newName;

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
    function generate(
        uint256 seed,
        uint256 minAttributeValue,
        uint256 randCap
    ) internal pure returns (Hopper memory) {
        unchecked {
            return
                Hopper({
                    strength: uint8(
                        ((seed >> (8 * 1)) % randCap) + minAttributeValue
                    ),
                    agility: uint8(
                        ((seed >> (8 * 2)) % randCap) + minAttributeValue
                    ),
                    vitality: uint8(
                        ((seed >> (8 * 3)) % randCap) + minAttributeValue
                    ),
                    intelligence: uint8(
                        ((seed >> (8 * 4)) % randCap) + minAttributeValue
                    ),
                    fertility: uint8(
                        ((seed >> (8 * 5)) % randCap) + minAttributeValue
                    ),
                    level: 1,
                    rebirths: 0
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

            // Swap the picked tokenId for the last element
            --_indexerLength;
            uint256 last = indexer[_indexerLength];
            if (last == 0) {
                // this _indexerLength value had not been picked before
                indexer[index] = _indexerLength;
            } else {
                // this _indexerLength value had been picked and swapped before
                indexer[index] = last;
            }

            // Mint Hopper and generate its attributes
            _mint(msg.sender, tokenId);

            if (tokenId >= LEGENDARY_ID_START) {
                hoppers[tokenId] = generate(seed, 5, 6);
            } else {
                hoppers[tokenId] = generate(seed, 1, 10);
            }
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

            if (
                numberOfMints > MAX_PER_ADDRESS ||
                totalHoppers > (MAX_SUPPLY - reserved)
            ) revert MintLimit();

            _mintHoppers(numberOfMints, totalHoppers - numberOfMints);
            hoppersLength = totalHoppers;
        }
    }

    function freeMint(
        uint256 numberOfMints,
        uint256 totalGiven,
        bytes32[] memory proof
    ) external {
        unchecked {
            if (block.timestamp < preSaleOpenTime + 30 minutes)
                revert TooSoon();
        }

        if (freeRedeemed[msg.sender] + numberOfMints > totalGiven)
            revert Unauthorized();
        if (reserved < numberOfMints) revert ReservedAmountInvalid();

        if (
            !MerkleProof.verify(
                proof,
                freeMerkleRoot,
                keccak256(abi.encodePacked(msg.sender, totalGiven))
            )
        ) revert Unauthorized();

        unchecked {
            freeRedeemed[msg.sender] += numberOfMints;
            reserved -= numberOfMints;
        }

        _handleMint(numberOfMints);
    }

    function whitelistMint(bytes32[] memory proof) external payable {
        if (wlRedeemed[msg.sender] == 1) revert Unauthorized();
        if (block.timestamp < preSaleOpenTime) revert TooSoon();
        if (WL_MINT_COST > msg.value) revert InsufficientAmount();

        if (
            !MerkleProof.verify(
                proof,
                wlMerkleRoot,
                keccak256(abi.encodePacked(msg.sender))
            )
        ) revert Unauthorized();

        wlRedeemed[msg.sender] = 1;

        _handleMint(1);
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
            name = string(bytes.concat("hopper #", bytes(_toString(tokenId))));
        }
    }

    function _getTraits(Hopper memory hopper)
        internal
        pure
        returns (string memory)
    {
        return string(bytes.concat(
                '{"trait_type": "rebirths", "value": ',
                bytes(_toString(hopper.rebirths)),
                "},",
                '{"trait_type": "strength", "value": ',
                bytes(_toString(hopper.strength)),
                "},",
                '{"trait_type": "agility", "value": ',
                bytes(_toString(hopper.agility)),
                "},",
                '{"trait_type": "vitality", "value": ',
                bytes(_toString(hopper.vitality)),
                "},",
                '{"trait_type": "intelligence", "value": ',
                bytes(_toString(hopper.intelligence)),
                "},",
                '{"trait_type": "fertility", "value": ',
                bytes(_toString(hopper.fertility)),
                "}"
            ));
    }

    function _jsonString(uint256 tokenId)
        external
        view
        returns (string memory)
    {
        Hopper memory hopper = hoppers[tokenId];
        if (hopper.level == 0) revert InvalidTokenID();
        return string(bytes.concat(
                '{"name":"',
                bytes(getHopperName(tokenId)),
                '", "description":"Hopper", "attributes":[',
                '{"trait_type": "level", "value": ',
                bytes(_toString(hopper.level)),
                "},",
                bytes(_getTraits(hopper)),
                "],",
                '"image":"',
                bytes(imageURL),
                bytes(_toString(tokenId)),
                '.png"}'
            ));
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        if (hoppers[tokenId].level == 0) revert InvalidTokenID();

        return string(bytes.concat(bytes(baseURI), bytes(_toString(tokenId))));
    }

    function supportsInterface(bytes4 interfaceId)
        public
        pure
        override(ERC721)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
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
