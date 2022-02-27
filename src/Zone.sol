// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.12;

import {veFly} from "./veFly.sol";
import {Fly} from "./Fly.sol";
import {Ballot} from "./Ballot.sol";
import {HopperNFT} from "./Hopper.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

abstract contract Zone {
    /*///////////////////////////////////////////////////////////////
                            IMMUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable FLY;
    address public immutable VE_FLY;
    address public immutable HOPPER;

    /*///////////////////////////////////////////////////////////////
                                HOPPERS
    //////////////////////////////////////////////////////////////*/
    string public LEVEL_GAUGE_KEY;

    mapping(uint256 => address) public hopperOwners;
    mapping(uint256 => uint256) public hopperBaseShare;
    mapping(address => uint256) public rewards;

    address public owner;
    address public ballot;

    /*///////////////////////////////////////////////////////////////
                        Accounting/Rewards NFT
    //////////////////////////////////////////////////////////////*/
    uint256 public emissionRate;

    uint256 public totalSupply;
    uint256 public lastUpdatedTime;
    uint256 public rewardPerShareStored;

    mapping(address => uint256) public baseSharesBalance;
    mapping(address => uint256) public userRewardPerSharePaid;
    mapping(address => uint256) public userMaxFlyGeneration;

    mapping(address => uint256) public generatedPerShareStored;
    mapping(uint256 => uint256) public tokenCapFilledPerShare;

    uint256 public flyLevelCapRatio;

    /*///////////////////////////////////////////////////////////////
                        Accounting/Rewards veFLY
    //////////////////////////////////////////////////////////////*/
    uint256 public bonusEmissionRate;

    uint256 public totalVeShare;
    uint256 public lastBonusUpdatedTime;
    uint256 public bonusRewardPerShareStored;

    mapping(address => uint256) public veSharesBalance;
    mapping(address => uint256) public userBonusRewardPerSharePaid;
    mapping(address => uint256) public veFlyBalance;

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error Unauthorized();
    error UnfitHopper();
    error WrongTokenID();
    error NoHopperStaked();

    /*///////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event UpdatedOwner(address indexed owner);
    event UpdatedBallot(address indexed ballot);
    event UpdatedEmission(uint256 emissionRate);

    /*///////////////////////////////////////////////////////////////
                           CONTRACT MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    constructor(
        address fly,
        address vefly,
        address hopper
    ) {
        owner = msg.sender;

        FLY = fly;
        VE_FLY = vefly;
        HOPPER = hopper;

        flyLevelCapRatio = 3;
        LEVEL_GAUGE_KEY = "LEVEL_GAUGE_KEY";
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyBallotOrOwner() {
        if (msg.sender != owner && msg.sender != ballot) revert Unauthorized();
        _;
    }

    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
        emit UpdatedOwner(_owner);
    }

    function setBallot(address _ballot) external onlyOwner {
        ballot = _ballot;
        emit UpdatedBallot(_ballot);
    }

    function setEmissionRate(uint256 _emissionRate) external onlyOwner {
        _updateBaseRewardPerShareStored();

        emissionRate = _emissionRate;
        emit UpdatedEmission(_emissionRate);
    }

    function setBonusEmissionRate(uint256 _bonusEmissionRate)
        external
        onlyBallotOrOwner
    {
        _updateBonusRewardPerShareStored();

        bonusEmissionRate = _bonusEmissionRate;
    }

    function setFlyLevelCapRatio(uint256 _flyLevelCapRatio) external onlyOwner {
        flyLevelCapRatio = _flyLevelCapRatio;
    }

    /*///////////////////////////////////////////////////////////////
                        HOPPER GENERATION CAP
    //////////////////////////////////////////////////////////////*/

    function getUserBonusGeneratedFly(
        address account,
        uint256 _totalAccountShares
    ) public view returns (uint256, uint256) {
        uint256 cappedFly = userMaxFlyGeneration[account];
        uint256 generatedFly = ((_totalAccountShares *
            (bonusRewardPerShare() - userBonusRewardPerSharePaid[account])) /
            1e18);

        return (
            generatedFly > cappedFly ? cappedFly : generatedFly,
            generatedFly
        );
    }

    function getUserGeneratedFly(address account, uint256 _totalBaseShares)
        public
        view
        returns (uint256, uint256)
    {
        uint256 cappedFly = userMaxFlyGeneration[account];
        uint256 generatedFly = ((_totalBaseShares *
            (baseRewardPerShare() - userRewardPerSharePaid[account])) / 1e18);

        return (
            generatedFly > cappedFly ? cappedFly : generatedFly,
            generatedFly
        );
    }

    function _updateHopperGenerationData(
        address _account,
        uint256 _totalAccountShares,
        bool isBonus
    ) internal returns (uint256) {
        uint256 cappedFly;
        uint256 generatedFly;

        if (isBonus) {
            (cappedFly, generatedFly) = getUserBonusGeneratedFly(
                _account,
                _totalAccountShares
            );
        } else {
            (cappedFly, generatedFly) = getUserGeneratedFly(
                _account,
                _totalAccountShares
            );
        }

        // todo scale?
        generatedPerShareStored[_account] += (generatedFly /
            _totalAccountShares);
        return cappedFly;
    }

    /*///////////////////////////////////////////////////////////////
                           REWARDS ACCOUNTING
    //////////////////////////////////////////////////////////////*/

    function _updateAccountRewards(address _account) internal {
        _updateAccountBaseReward(_account, baseSharesBalance[_account]);
        _updateAccountBonusReward(_account, veSharesBalance[_account]);
    }

    /*///////////////////////////////////////////////////////////////
                           BASE REWARDS
    //////////////////////////////////////////////////////////////*/

    function baseRewardPerShare() public view returns (uint256) {
        if (totalSupply == 0) {
            return 0;
        }
        return
            rewardPerShareStored +
            (((block.timestamp - lastUpdatedTime) * emissionRate * 1e18) /
                totalSupply);
    }

    function _updateBaseRewardPerShareStored() internal {
        rewardPerShareStored = baseRewardPerShare();
        lastUpdatedTime = block.timestamp;
    }

    function _updateAccountBaseReward(
        address _account,
        uint256 _totalAccountShares
    ) internal {
        _updateBaseRewardPerShareStored();

        if (_totalAccountShares > 0) {
            uint256 cappedFly = _updateHopperGenerationData(
                _account,
                _totalAccountShares,
                false
            );

            unchecked {
                rewards[_account] += cappedFly;
                userMaxFlyGeneration[_account] -= cappedFly;
            }
        }

        userRewardPerSharePaid[_account] = rewardPerShareStored;
    }

    /*///////////////////////////////////////////////////////////////
                           BONUS REWARDS
    //////////////////////////////////////////////////////////////*/

    function bonusRewardPerShare() public view returns (uint256) {
        if (totalVeShare == 0) {
            return 0;
        }
        return
            bonusRewardPerShareStored +
            (((block.timestamp - lastBonusUpdatedTime) *
                bonusEmissionRate *
                1e18) / totalVeShare);
    }

    function _updateBonusRewardPerShareStored() internal {
        bonusRewardPerShareStored = bonusRewardPerShare();
        lastBonusUpdatedTime = block.timestamp;
    }

    function _updateAccountBonusReward(
        address _account,
        uint256 _totalAccountShares
    ) internal {
        _updateBonusRewardPerShareStored();

        if (veSharesBalance[_account] > 0) {
            uint256 cappedFly = _updateHopperGenerationData(
                _account,
                _totalAccountShares,
                true
            );

            unchecked {
                rewards[_account] += cappedFly;
                userMaxFlyGeneration[_account] -= cappedFly;
            }
        }

        userBonusRewardPerSharePaid[_account] = bonusRewardPerShareStored;
    }

    /*///////////////////////////////////////////////////////////////
                    NAMES & LEVELING
    //////////////////////////////////////////////////////////////*/

    function payAction(uint256 flyRequired, bool useOwnRewards) internal {
        if (useOwnRewards) {
            uint256 _rewards = rewards[msg.sender];

            // Pays from the pending rewards
            if (_rewards >= flyRequired) {
                unchecked {
                    rewards[msg.sender] -= flyRequired;
                    flyRequired = 0;
                }
            } else if (_rewards > 0) {
                delete rewards[msg.sender];
                unchecked {
                    flyRequired -= _rewards;
                }
            }
        }

        // Sender pays for action. Will revert, if not enough balance
        if (flyRequired > 0) {
            Fly(FLY).burn(msg.sender, flyRequired);
        }
    }

    function changeHopperName(
        uint256 tokenId,
        string calldata name,
        bool useOwnRewards
    ) external {
        if (useOwnRewards) {
            _updateAccountRewards(msg.sender);
        }

        // Check hopper ownership
        address zoneHopperOwner = hopperOwners[tokenId];
        if (zoneHopperOwner != msg.sender) {
            // Saves gas in certain paths
            if (HopperNFT(HOPPER).ownerOf(tokenId) != msg.sender) {
                revert WrongTokenID();
            }
        }

        payAction(
            HopperNFT(HOPPER).changeHopperName(tokenId, name), // returns price
            useOwnRewards
        );
    }

    function _getLevelUpCost(uint256 level) internal pure returns (uint256) {
        unchecked {
            ++level;
        }

        // x**(1.43522) / 7.5 for x >= 21 where x is next level
        // packing costs in 7 bits

        if (level > 1 && level < 21) {
            return (level * 1e18) >> 1;
        } else if (level >= 21 && level < 51) {
            return
                ((0x1223448501f3c74e1b3464c172c54a9426488901e3c70d183058a >>
                    (7 * (level - 21))) & 127) * 1e18;
        } else if (level >= 51 && level < 81) {
            return
                ((0x23c68b0e14180f9ebc76e9c376cd5a3262c17ae5ab15a9509d325 >>
                    (7 * (level - 51))) & 127) * 1e18;
        } else if (level >= 81 && level < 101) {
            return
                ((0xc58705ebb6ed59af5aad3a5467ce9b2e549 >> (7 * (level - 81))) &
                    127) * 1e18;
        } else {
            return type(uint256).max;
        }
    }

    function getLevelUpCost(uint256 currentLevel)
        public
        pure
        returns (uint256)
    {
        return _getLevelUpCost(currentLevel);
    }

    //slither-disable-next-line reentrancy-no-eth
    function levelUp(uint256 tokenId, bool useOwnRewards) external {
        if (useOwnRewards) {
            _updateAccountRewards(msg.sender);
        }

        // Check hopper ownership
        address zoneHopperOwner = hopperOwners[tokenId];
        if (zoneHopperOwner != msg.sender) {
            // Saves gas in certain paths
            if (HopperNFT(HOPPER).ownerOf(tokenId) != msg.sender) {
                revert WrongTokenID();
            }
        }

        HopperNFT.Hopper memory hopper = HopperNFT(HOPPER).getHopper(tokenId);

        // Update owners shares if hopper is staked
        if (zoneHopperOwner == msg.sender) {
            // Resets this hopper generation tracking
            tokenCapFilledPerShare[tokenId] = generatedPerShareStored[
                msg.sender
            ];

            uint256 prevHopperShare = _calculateBaseShare(hopper);
            unchecked {
                ++hopper.level;
            }
            uint256 hopperShare = _calculateBaseShare(hopper);

            uint256 newBaseShare = baseSharesBalance[msg.sender] -
                prevHopperShare +
                hopperShare;
            baseSharesBalance[msg.sender] = newBaseShare;

            _updateAccountRewards(msg.sender);
            _updateVeShares(newBaseShare, 0, false);

            // Make sure getLevelUpCost is passed its current level
            unchecked {
                --hopper.level;
            }
        }

        payAction(getLevelUpCost(hopper.level), useOwnRewards);

        HopperNFT(HOPPER).levelUp(tokenId);

        // Reset Hopper internal gauge
        HopperNFT(HOPPER).setData(LEVEL_GAUGE_KEY, tokenId, 0);
    }

    /*///////////////////////////////////////////////////////////////
                    STAKE / UNSTAKE NFT && CLAIM FLY
    //////////////////////////////////////////////////////////////*/

    function _getHopperAndGauge(uint256 _tokenId)
        internal
        view
        returns (
            HopperNFT.Hopper memory,
            uint256,
            uint256
        )
    {
        string[] memory arrData = new string[](1);
        arrData[0] = LEVEL_GAUGE_KEY;
        (HopperNFT.Hopper memory hopper, bytes32[] memory _data) = HopperNFT(
            HOPPER
        ).getHopperWithData(arrData, _tokenId);

        uint256 levelCost = hopper.level == 1
            ? 1.5 ether
            : _getLevelUpCost(hopper.level - 1);

        return (
            hopper,
            uint256(_data[0]), // hopperGauge
            uint256(hopper.level) == 100
                ? type(uint256).max
                : flyLevelCapRatio * levelCost // gaugeLimit
        );
    }

    function enter(uint256[] calldata tokenIds) external {
        _updateAccountRewards(msg.sender);

        uint256 prevBaseShares = baseSharesBalance[msg.sender];
        uint256 _baseShares = prevBaseShares;
        uint256 numTokens = tokenIds.length;

        uint256 flyCapIncrease;

        for (uint256 i; i < numTokens; ++i) {
            uint256 tokenId = tokenIds[i];

            // Resets this hopper generation tracking
            tokenCapFilledPerShare[tokenId] = generatedPerShareStored[
                msg.sender
            ];

            (
                HopperNFT.Hopper memory hopper,
                uint256 hopperGauge,
                uint256 gaugeLimit
            ) = _getHopperAndGauge(tokenId);

            if (!canEnter(hopper)) revert UnfitHopper();

            unchecked {
                // Increment user shares
                _baseShares += _calculateBaseShare(hopper);

                // Update the maximum FLY this user can generate
                // todo gaugeLimit should always be less than hopperGauge, should..
                flyCapIncrease += (gaugeLimit - hopperGauge);
            }

            // Hopper Accounting
            hopperOwners[tokenId] = msg.sender;
            HopperNFT(HOPPER).transferFrom(msg.sender, address(this), tokenId);
        }

        unchecked {
            baseSharesBalance[msg.sender] = _baseShares;
            userMaxFlyGeneration[msg.sender] += flyCapIncrease;

            totalSupply = totalSupply + _baseShares - prevBaseShares;
        }

        _updateVeShares(_baseShares, 0, false);
    }

    //slither-disable-next-line reentrancy-no-eth
    function exit(uint256[] calldata tokenIds) external {
        _updateAccountRewards(msg.sender);

        uint256 prevBaseShares = baseSharesBalance[msg.sender];
        uint256 _baseShares = prevBaseShares;
        uint256 numTokens = tokenIds.length;

        uint256 flyCapDecrease;

        for (uint256 i; i < numTokens; ++i) {
            uint256 tokenId = tokenIds[i];

            // Can the user unstake this hopper
            if (hopperOwners[tokenId] != msg.sender) revert WrongTokenID();

            // Find the amount of uncapped FLY generated by this Hopper
            uint256 filledCapPerShare = generatedPerShareStored[msg.sender] -
                tokenCapFilledPerShare[tokenId];

            (
                HopperNFT.Hopper memory hopper,
                uint256 prevHopperGauge,
                uint256 gaugeLimit
            ) = _getHopperAndGauge(tokenId);

            uint256 _hopperShare = _calculateBaseShare(hopper);
            uint256 currentGauge = prevHopperGauge +
                filledCapPerShare *
                _hopperShare;

            // Update the HOPPER gauge
            HopperNFT(HOPPER).setData(
                LEVEL_GAUGE_KEY,
                tokenId,
                currentGauge > gaugeLimit
                    ? bytes32(gaugeLimit)
                    : bytes32(currentGauge)
            );

            unchecked {
                // Decrement user shares
                _baseShares -= _hopperShare;

                // Update the maximum FLY this user can generate
                flyCapDecrease += (gaugeLimit - prevHopperGauge);
            }

            // Hopper Accounting
            //slither-disable-next-line costly-loop
            delete hopperOwners[tokenId];
            HopperNFT(HOPPER).transferFrom(address(this), msg.sender, tokenId);
        }

        unchecked {
            baseSharesBalance[msg.sender] = _baseShares;
            userMaxFlyGeneration[msg.sender] -= flyCapDecrease;

            totalSupply = totalSupply + _baseShares - prevBaseShares;
        }

        _updateVeShares(_baseShares, 0, false);
    }

    // todo test
    function claimable(address _account) external view returns (uint256) {
        uint256 cappedFly = userMaxFlyGeneration[_account];

        (uint256 gen, ) = getUserGeneratedFly(
            _account,
            baseSharesBalance[_account]
        );
        (uint256 bonusGen, ) = getUserBonusGeneratedFly(
            _account,
            veSharesBalance[_account]
        );

        gen += bonusGen;
        cappedFly = gen > cappedFly ? cappedFly : gen;

        return rewards[msg.sender] + gen;
    }

    function claim() external {
        _updateAccountRewards(msg.sender);

        uint256 _accountRewards = rewards[msg.sender];
        delete rewards[msg.sender];

        Fly(FLY).mint(msg.sender, _accountRewards);
    }

    /*///////////////////////////////////////////////////////////////
                            VOTE veFLY 
    //////////////////////////////////////////////////////////////*/

    function _calcVeShare(uint256 eshares, uint256 vefly)
        internal
        pure
        returns (uint256)
    {
        return FixedPointMathLib.sqrt(eshares * vefly);
    }

    //slither-disable-next-line reentrancy-no-eth
    function _updateVeShares(
        uint256 baseShares,
        uint256 veFlyAmount,
        bool increment
    ) internal {
        uint256 beforeVeShare = veSharesBalance[msg.sender];

        if (beforeVeShare > 0 || veFlyAmount > 0) {
            if (veFlyAmount > 0) {
                if (increment) {
                    //slither-disable-next-line reentrancy-benign
                    Ballot(ballot).vote(msg.sender, veFlyAmount);
                    veFlyBalance[msg.sender] += veFlyAmount;
                } else {
                    //slither-disable-next-line reentrancy-benign
                    Ballot(ballot).unvote(msg.sender, veFlyAmount);
                    veFlyBalance[msg.sender] -= veFlyAmount;
                }
            }

            uint256 currentVeShare = _calcVeShare(
                baseShares,
                veFlyBalance[msg.sender]
            );
            veSharesBalance[msg.sender] = currentVeShare;

            unchecked {
                totalVeShare = totalVeShare + currentVeShare - beforeVeShare;
            }
        }
    }

    function vote(uint256 veFlyAmount, bool recount) external {
        _updateAccountBonusReward(msg.sender, veSharesBalance[msg.sender]);

        _updateVeShares(baseSharesBalance[msg.sender], veFlyAmount, true);

        if (recount) Ballot(ballot).count();
    }

    function unvote(uint256 veFlyAmount, bool recount) external {
        _updateAccountBonusReward(msg.sender, veSharesBalance[msg.sender]);

        _updateVeShares(baseSharesBalance[msg.sender], veFlyAmount, false);

        if (recount) Ballot(ballot).count();
    }

    function forceUnvote(address user) external {
        if (msg.sender != ballot) revert Unauthorized();

        _updateAccountBonusReward(user, veSharesBalance[user]);

        delete veSharesBalance[user];
        delete veFlyBalance[user];
    }

    /*///////////////////////////////////////////////////////////////
                    ZONE SPECIFIC FUNCTIONALITY
    //////////////////////////////////////////////////////////////*/

    function canEnter(HopperNFT.Hopper memory hopper)
        public
        pure
        virtual
        returns (bool)
    {} // solhint-disable-line

    function _calculateBaseShare(HopperNFT.Hopper memory hopper)
        internal
        pure
        virtual
        returns (uint256)
    {} // solhint-disable-line
}
