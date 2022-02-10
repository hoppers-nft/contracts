// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.11;

import {Fly} from "./Fly.sol";
import {Zone} from "./Zone.sol";
import {veFly} from "./veFly.sol";

contract Ballot {
    address owner;
    address[] validZones;

    bool enabled;
    uint256 rewardSnapshot;
    uint256 bonusEmissionRate;
    uint256 countRewardRate;

    ///

    address immutable VEFLY;
    address immutable FLY;

    address[] public arrAdventures;
    mapping(address => bool) adventures;
    mapping(address => uint256) adventuresVotes;
    mapping(address => mapping(address => uint256)) adventuresUserVotes;
    mapping(address => uint256) userVeFlyUsed;

    //

    event UpdatedOwner(address indexed owner);

    error Unauthorized();
    error TooSoon();
    error NotEnoughVeFly();

    constructor(address _flyAddress, address _veFlyAddress) {
        owner = msg.sender;
        rewardSnapshot = type(uint256).max;
        FLY = _flyAddress;
        VEFLY = _veFlyAddress;
    }

    modifier onlyOwner() {
        if (owner != msg.sender) revert Unauthorized();
        _;
    }

    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
        emit UpdatedOwner(_owner);
    }

    function openBallot() external onlyOwner {
        rewardSnapshot = block.timestamp;
    }

    function closeBallot() external onlyOwner {
        rewardSnapshot = type(uint256).max;
    }

    function addAdventures(address[] calldata _adventures) external onlyOwner {
        uint256 length = _adventures.length;
        for (uint256 i; i < length; ++i) {
            address adventure = _adventures[i];
            arrAdventures.push(_adventures[i]);
            adventures[adventure] = true;
        }
    }

    function removeAdventure(uint256 index) external onlyOwner {
        address removed = arrAdventures[index];
        arrAdventures[index] = arrAdventures[arrAdventures.length - 1];
        arrAdventures.pop();
        delete adventures[removed];
    }

    function setBonusEmissionRate(uint256 _bonusEmissionRate)
        external
        onlyOwner
    {
        bonusEmissionRate = _bonusEmissionRate;
    }

    function forceUnvote(address user) external {
        if (msg.sender != VEFLY) revert Unauthorized();

        uint256 length = arrAdventures.length;
        for (uint256 i; i < length; ++i) {
            address adventure = arrAdventures[i];
            uint256 userVotes = adventuresUserVotes[adventure][user];

            delete userVeFlyUsed[user];
            delete adventuresUserVotes[adventure][user];
            adventuresVotes[adventure] -= userVotes;
        }
    }

    function _updateVotes(address user, uint256 vefly) internal {
        adventuresVotes[msg.sender] =
            adventuresVotes[msg.sender] -
            adventuresUserVotes[msg.sender][user] +
            vefly;

        adventuresUserVotes[msg.sender][user] = vefly;
    }

    function vote(address user, uint256 vefly) external returns (uint256) {
        if (!adventures[msg.sender]) revert Unauthorized();

        // veFly Accounting
        uint256 totalVeFly = userVeFlyUsed[user] + vefly;
        if (totalVeFly > veFly(VEFLY).balanceOf(user)) revert NotEnoughVeFly();

        userVeFlyUsed[user] = totalVeFly;

        if (totalVeFly > 0) veFly(VEFLY).setHasVoted(user);

        _updateVotes(user, totalVeFly);

        return totalVeFly;
    }

    function unvote(address user, uint256 vefly) external returns (uint256) {
        if (!adventures[msg.sender]) revert Unauthorized();

        // veFly Accounting
        if (userVeFlyUsed[user] < vefly) revert NotEnoughVeFly();
        uint256 remainingVeFly = userVeFlyUsed[user] - vefly;
        userVeFlyUsed[user] = remainingVeFly;

        if (remainingVeFly == 0) veFly(VEFLY).unsetHasVoted(user);

        _updateVotes(user, remainingVeFly);

        return remainingVeFly;
    }

    function setCountRewardRate(uint256 _countRewardRate) external onlyOwner {
        countRewardRate = _countRewardRate;
    }

    function countReward() public view returns (uint256) {
        uint256 _rewardSnapshot = rewardSnapshot;

        if (block.timestamp < _rewardSnapshot) return 0;

        return countRewardRate * (block.timestamp - _rewardSnapshot);
    }

    function count() external {
        uint256 reward = countReward();
        rewardSnapshot = block.timestamp;

        if (reward == 0) revert TooSoon();

        uint256 totalVotes;
        address[] memory _arrAdventures = arrAdventures;
        uint256 length = _arrAdventures.length;

        for (uint256 i; i < length; ++i) {
            totalVotes += adventuresVotes[_arrAdventures[i]];
        }

        for (uint256 i; i < length; ++i) {
            Zone(_arrAdventures[i]).setBonusEmissionRate(
                (bonusEmissionRate * adventuresVotes[_arrAdventures[i]]) /
                    totalVotes
            );
        }

        Fly(FLY).mint(msg.sender, reward);
    }
}
