// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.11;

import {Fly} from "./Fly.sol";
import {Ballot} from "./Ballot.sol";

contract veFly {
    /*///////////////////////////////////////////////////////////////
                             METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    address public owner;

    string public name = "veFLY";
    string public symbol = "veFLY";

    address public immutable FLY;

    /*///////////////////////////////////////////////////////////////
                           FLY/VEFLY GENERATION
    //////////////////////////////////////////////////////////////*/

    struct GenerationDetails {
        uint128 maxRatio;
        uint32 generationRateNumerator;
        uint32 generationRateDenominator;
        uint64 lastUpdatedTime;
    }

    GenerationDetails public genDetails;

    mapping(address => uint256) public flyBalanceOf;
    mapping(address => uint256) private veFlyBalance;
    mapping(address => uint256) private userSnapshot;

    /*///////////////////////////////////////////////////////////////
                              VOTING
    //////////////////////////////////////////////////////////////*/

    address[] public arrValidBallots;
    mapping(address => bool) public validBallots;
    mapping(address => mapping(address => bool)) public hasUserVoted;

    /*///////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/
    error Unauthorized();
    error InvalidAmount();
    error InvalidProposal();

    /*///////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/
    event UpdatedOwner(address indexed owner);
    event AddedBallot(address indexed ballot);
    event RemovedBallot(address indexed ballot);

    /*///////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _flyAddress,
        uint256 _generationRateNumerator,
        uint256 _generationRateDenominator,
        uint256 _maxRatio
    ) {
        owner = msg.sender;

        FLY = _flyAddress;

        genDetails = GenerationDetails({
            maxRatio: uint128(_maxRatio),
            generationRateNumerator: uint32(_generationRateNumerator),
            generationRateDenominator: uint32(_generationRateDenominator),
            lastUpdatedTime: uint64(block.timestamp)
        });
    }

    modifier onlyOwner() {
        if (owner != msg.sender) revert Unauthorized();
        _;
    }

    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
        emit UpdatedOwner(_owner);
    }

    function setGenerationDetails(
        uint256 _maxRatio,
        uint256 _generationRateNumerator,
        uint256 _generationRateDenominator
    ) external onlyOwner {
        GenerationDetails storage gen = genDetails;
        gen.maxRatio = uint128(_maxRatio);
        gen.generationRateNumerator = uint32(_generationRateNumerator);
        gen.generationRateDenominator = uint32(_generationRateDenominator);
    }

    /*///////////////////////////////////////////////////////////////
                               BALLOTS
    //////////////////////////////////////////////////////////////*/

    modifier onlyBallot() {
        if (!validBallots[msg.sender]) revert Unauthorized();
        _;
    }

    function addBallot(address ballot) external onlyOwner {
        if (!validBallots[ballot]) {
            arrValidBallots.push(ballot);
            validBallots[ballot] = true;
            emit AddedBallot(ballot);
        }
    }

    function removeBallot(uint256 index) external onlyOwner {
        address removed = arrValidBallots[index];

        arrValidBallots[index] = arrValidBallots[arrValidBallots.length - 1];
        arrValidBallots.pop();

        delete validBallots[removed];

        emit RemovedBallot(removed);
    }

    function _forceUncastAllVotes() internal {
        uint256 length = arrValidBallots.length;
        for (uint256 i; i < length; ++i) {
            address ballot = arrValidBallots[i];

            Ballot(ballot).forceUnvote(msg.sender);
            delete hasUserVoted[ballot][msg.sender];
        }
    }

    function setHasVoted(address user) external onlyBallot {
        hasUserVoted[msg.sender][user] = true;
    }

    function unsetHasVoted(address user) external onlyBallot {
        delete hasUserVoted[msg.sender][user];
    }

    /*///////////////////////////////////////////////////////////////
                               STAKING
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 amount) external {
        // Reset veFly calculations
        veFlyBalance[msg.sender] = balanceOf(msg.sender);
        userSnapshot[msg.sender] = block.timestamp;

        unchecked {
            flyBalanceOf[msg.sender] += amount;
        }
        Fly(FLY).transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) external {
        if (flyBalanceOf[msg.sender] < amount) revert InvalidAmount();

        _forceUncastAllVotes();

        // Reset veFly calculations
        delete veFlyBalance[msg.sender];
        userSnapshot[msg.sender] = block.timestamp;

        unchecked {
            flyBalanceOf[msg.sender] -= amount;
        }
        Fly(FLY).transfer(msg.sender, amount);
    }

    /*///////////////////////////////////////////////////////////////
                               veFly
    //////////////////////////////////////////////////////////////*/

    function balanceOf(address account) public view returns (uint256) {
        GenerationDetails memory gen = genDetails;

        uint256 flyBalance = flyBalanceOf[account];

        uint256 veBalance = veFlyBalance[account] +
            (flyBalance / gen.generationRateDenominator) *
            (block.timestamp - userSnapshot[account]) *
            gen.generationRateNumerator;

        uint256 maxVe = gen.maxRatio * flyBalance;
        if (veBalance > maxVe) {
            return maxVe;
        } else {
            return veBalance;
        }
    }

    function canWithdraw(address account) public view returns (bool) {
        uint256 length = arrValidBallots.length;
        for (uint256 i; i < length; ++i) {
            if (hasUserVoted[arrValidBallots[i]][account]) return false;
        }
        return true;
    }
}
