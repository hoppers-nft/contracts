// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.12;

import {Fly} from "./Fly.sol";
import {Ballot} from "./Ballot.sol";

// solhint-disable-next-line
contract veFly {
    /*///////////////////////////////////////////////////////////////
                             METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    address public owner;

    // solhint-disable-next-line const-name-snakecase
    string public constant name = "veFLY";
    // solhint-disable-next-line const-name-snakecase
    string public constant symbol = "veFLY";

    address public immutable FLY;

    /*///////////////////////////////////////////////////////////////
                           FLY/VEFLY GENERATION
    //////////////////////////////////////////////////////////////*/

    struct GenerationDetails {
        uint128 maxRatio;
        uint64 generationRateNumerator;
        uint64 generationRateDenominator;
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
                            CONTRACT MANAGEMENT
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
            generationRateNumerator: uint64(_generationRateNumerator),
            generationRateDenominator: uint64(_generationRateDenominator)
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
        gen.generationRateNumerator = uint64(_generationRateNumerator);
        gen.generationRateDenominator = uint64(_generationRateDenominator);
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
        for (uint256 i; i < length; ) {
            address ballot = arrValidBallots[i];
            delete hasUserVoted[ballot][msg.sender];

            Ballot(ballot).forceUnvote(msg.sender);
            unchecked {
                ++i;
            }
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
        //slither-disable-next-line incorrect-equality
        if(genDetails.maxRatio == 0) revert Unauthorized(); 

        // Reset veFly calculations
        veFlyBalance[msg.sender] = balanceOf(msg.sender);
        userSnapshot[msg.sender] = block.timestamp;

        unchecked {
            flyBalanceOf[msg.sender] += amount;
        }

        // slither-disable-next-line unchecked-transfer
        Fly(FLY).transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) external {
        if (flyBalanceOf[msg.sender] < amount) revert InvalidAmount();

        // Reset veFly calculations
        delete veFlyBalance[msg.sender];
        userSnapshot[msg.sender] = block.timestamp;

        unchecked {
            flyBalanceOf[msg.sender] -= amount;
        }

        _forceUncastAllVotes();

        // slither-disable-next-line unchecked-transfer
        Fly(FLY).transfer(msg.sender, amount);
    }

    /*///////////////////////////////////////////////////////////////
                               veFly
    //////////////////////////////////////////////////////////////*/

    function balanceOf(address account) public view returns (uint256) {
        GenerationDetails memory gen = genDetails;

        uint256 flyBalance = flyBalanceOf[account];

        uint256 veBalance = veFlyBalance[account] +
            ((flyBalance * gen.generationRateNumerator) *
                (block.timestamp - userSnapshot[account])) /
            gen.generationRateDenominator;

        uint256 maxVe = gen.maxRatio * flyBalance;
        if (veBalance > maxVe) {
            return maxVe;
        } else {
            return veBalance;
        }
    }

    function hasUserVotedAny(address account) external view returns (bool) {
        uint256 length = arrValidBallots.length;
        for (uint256 i; i < length; ) {
            if (hasUserVoted[arrValidBallots[i]][account]) return false;
            unchecked {
                ++i;
            }
        }
        return true;
    }
}
