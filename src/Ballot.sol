// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.12;

import {Fly} from "./Fly.sol";
import {Zone} from "./Zone.sol";
import {veFly} from "./veFly.sol";

contract Ballot {
    address public owner;

    /*///////////////////////////////////////////////////////////////
                            IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    address public immutable VEFLY;
    address public immutable FLY;

    /*///////////////////////////////////////////////////////////////
                              ZONES
    //////////////////////////////////////////////////////////////*/

    address[] public arrZones;
    mapping(address => bool) public zones;
    mapping(address => uint256) public zonesVotes;

    mapping(address => mapping(address => uint256)) public zonesUserVotes;
    mapping(address => uint256) public userVeFlyUsed;

    /*///////////////////////////////////////////////////////////////
                              EMISSIONS
    //////////////////////////////////////////////////////////////*/

    uint256 public bonusEmissionRate;
    uint256 public rewardSnapshot;
    uint256 public countRewardRate;

    /*///////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event UpdatedOwner(address indexed owner);
    event Helper(uint256);

    /*///////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized();
    error TooSoon();
    error NotEnoughVeFly();

    /*///////////////////////////////////////////////////////////////
                            CONTRACT MANAGEMENT
    //////////////////////////////////////////////////////////////*/

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

    function openBallot(uint256 _countRewardRate, uint256 _bonusEmissionRate)
        external
        onlyOwner
    {
        rewardSnapshot = block.timestamp;
        countRewardRate = _countRewardRate;
        bonusEmissionRate = _bonusEmissionRate;
    }

    function closeBallot() external onlyOwner {
        rewardSnapshot = type(uint256).max;
    }

    function setBonusEmissionRate(uint256 _bonusEmissionRate)
        external
        onlyOwner
    {
        bonusEmissionRate = _bonusEmissionRate;
    }

    function setCountRewardRate(uint256 _countRewardRate) external onlyOwner {
        countRewardRate = _countRewardRate;
    }

    /*///////////////////////////////////////////////////////////////
                                ZONES
    //////////////////////////////////////////////////////////////*/

    modifier onlyZone() {
        if (!zones[msg.sender]) revert Unauthorized();
        _;
    }

    function addZones(address[] calldata _zones) external onlyOwner {
        uint256 length = _zones.length;
        for (uint256 i; i < length; ++i) {
            address zone = _zones[i];
            arrZones.push(_zones[i]);
            zones[zone] = true;
        }
    }

    function removeZone(uint256 index) external onlyOwner {
        address removed = arrZones[index];
        arrZones[index] = arrZones[arrZones.length - 1];
        arrZones.pop();
        delete zones[removed];
    }

    /*///////////////////////////////////////////////////////////////
                            VOTING
    //////////////////////////////////////////////////////////////*/

    function forceUnvote(address _user) external {
        if (msg.sender != VEFLY) revert Unauthorized();

        uint256 length = arrZones.length;

        for (uint256 i; i < length; ++i) {
            address zone = arrZones[i];

            uint256 zoneUserVotes = zonesUserVotes[zone][_user];

            if (zoneUserVotes > 0) {
                zonesVotes[zone] -= zonesUserVotes[zone][_user];
                delete userVeFlyUsed[_user];
                delete zonesUserVotes[zone][_user];

                // Done already by veFly on its _forceUncastAllVotes
                // veFly(VEFLY).unsetHasVoted(user)

                Zone(zone).forceUnvote(_user);
            }
        }
    }

    function _updateVotes(address user, uint256 vefly) internal {
        zonesVotes[msg.sender] =
            zonesVotes[msg.sender] -
            zonesUserVotes[msg.sender][user] +
            vefly;

        zonesUserVotes[msg.sender][user] = vefly;
    }

    function vote(address user, uint256 vefly) external onlyZone {
        // veFly Accounting
        uint256 totalVeFly = userVeFlyUsed[user] + vefly;

        if (totalVeFly > veFly(VEFLY).balanceOf(user)) revert NotEnoughVeFly();

        if (vefly > 0) {
            userVeFlyUsed[user] = totalVeFly;
            veFly(VEFLY).setHasVoted(user);

            _updateVotes(user, zonesUserVotes[msg.sender][user] + vefly);
        }
    }

    function unvote(address user, uint256 vefly) external onlyZone {
        // veFly Accounting
        if (userVeFlyUsed[user] < vefly) revert NotEnoughVeFly();
        uint256 remainingVeFly = userVeFlyUsed[user] - vefly;
        userVeFlyUsed[user] = remainingVeFly;

        uint256 zoneUserVotes = zonesUserVotes[msg.sender][user];

        if (zoneUserVotes < vefly) revert NotEnoughVeFly();

        if (remainingVeFly == 0) veFly(VEFLY).unsetHasVoted(user);

        _updateVotes(user, zoneUserVotes - vefly);
    }

    /*///////////////////////////////////////////////////////////////
                            COUNTING
    //////////////////////////////////////////////////////////////*/

    function countReward() public view returns (uint256) {
        uint256 _rewardSnapshot = rewardSnapshot;

        if (block.timestamp < _rewardSnapshot) return 0;

        return countRewardRate * (block.timestamp - _rewardSnapshot);
    }

    function count() external {
        uint256 reward = countReward();
        rewardSnapshot = block.timestamp;

        uint256 totalVotes;
        address[] memory _arrZones = arrZones;
        uint256 length = _arrZones.length;

        for (uint256 i; i < length; ++i) {
            totalVotes += zonesVotes[_arrZones[i]];
        }

        for (uint256 i; i < length; ++i) {
            if (totalVotes == 0) {
                Zone(_arrZones[i]).setBonusEmissionRate(0);
            } else {
                Zone(_arrZones[i]).setBonusEmissionRate(
                    (bonusEmissionRate * zonesVotes[_arrZones[i]]) / totalVotes
                );
            }
        }

        if (reward > 0) {
            Fly(FLY).mint(tx.origin, reward);
        }
    }
}
