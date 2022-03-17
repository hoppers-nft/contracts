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
    bool public emergency;

    /*///////////////////////////////////////////////////////////////
                        Accounting/Rewards NFT
    //////////////////////////////////////////////////////////////*/
    uint256 public emissionRate;

    uint256 public totalBaseShare;
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
        lastUpdatedTime = block.timestamp;
        lastBonusUpdatedTime = block.timestamp;
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

    function enableEmergency() external onlyOwner {
        // no going back
        emergency = true;
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
        uint256 _totalUserBonusShares
    ) public view returns (uint256, uint256) {
        // userMaxFlyGeneration gets updated at _updateAccountBaseReward which happens before this is called
        uint256 cappedFly = userMaxFlyGeneration[account] / 1e12;
        uint256 generatedFly = ((_totalUserBonusShares *
            (bonusRewardPerShare() - userBonusRewardPerSharePaid[account])) /
            1e18);

        return (
            generatedFly > cappedFly ? cappedFly : generatedFly,
            generatedFly
        );
    }

    function getUserGeneratedFly(address account, uint256 _totalUserBaseShares)
        public
        view
        returns (uint256, uint256)
    {
        uint256 cappedFly = userMaxFlyGeneration[account] / 1e12;
        uint256 generatedFly = ((_totalUserBaseShares *
            (baseRewardPerShare() - userRewardPerSharePaid[account])) / 1e18);

        return (
            generatedFly > cappedFly ? cappedFly : generatedFly,
            generatedFly
        );
    }

    function _updateHopperGenerationData(
        address _account,
        uint256 _totalAccountKindShares,
        bool isBonus
    ) internal returns (uint256) {
        uint256 cappedFly;
        uint256 generatedFly;

        if (isBonus) {
            (cappedFly, generatedFly) = getUserBonusGeneratedFly(
                _account,
                _totalAccountKindShares
            );

            // Makes calculations easier, since we don't need to add another
            //    state keeping track of generatedPerVeshare
            generatedPerShareStored[_account] += FixedPointMathLib.mulDivUp(
                generatedFly,
                1e12,
                baseSharesBalance[_account]
            );
        } else {
            (cappedFly, generatedFly) = getUserGeneratedFly(
                _account,
                _totalAccountKindShares
            );
            generatedPerShareStored[_account] += FixedPointMathLib.mulDivUp(
                generatedFly,
                1e12,
                _totalAccountKindShares
            );
        }
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
        uint256 _totalBaseShare = totalBaseShare;
        //slither-disable-next-line incorrect-equality
        if (_totalBaseShare == 0) {
            return rewardPerShareStored;
        }
        return
            rewardPerShareStored +
            (((block.timestamp - lastUpdatedTime) * emissionRate * 1e18) /
                _totalBaseShare);
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
            }
            userMaxFlyGeneration[_account] -= cappedFly * 1e12;
        }

        userRewardPerSharePaid[_account] = rewardPerShareStored;
    }

    /*///////////////////////////////////////////////////////////////
                           BONUS REWARDS
    //////////////////////////////////////////////////////////////*/

    function bonusRewardPerShare() public view returns (uint256) {
        uint256 _totalVeShare = totalVeShare;
        //slither-disable-next-line incorrect-equality
        if (_totalVeShare == 0) {
            return bonusRewardPerShareStored;
        }
        return
            bonusRewardPerShareStored +
            (((block.timestamp - lastBonusUpdatedTime) *
                bonusEmissionRate *
                1e18) / _totalVeShare);
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

        if (_totalAccountShares > 0) {
            uint256 cappedFly = _updateHopperGenerationData(
                _account,
                _totalAccountShares,
                true
            );

            unchecked {
                rewards[_account] += cappedFly;
            }
            userMaxFlyGeneration[_account] -= cappedFly * 1e12;
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

            if (level == 100) {
                return 598 ether;
            }
            // x**(1.43522) / 7.5 for x >= 21 where x is next level
            // packing costs in 7 bits
            else if (level > 1 && level < 21) {
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
                    ((0xc58705ebb6ed59af5aad3a5467ce9b2e549 >>
                        (7 * (level - 81))) & 127) * 1e18;
            } else {
                return type(uint256).max;
            }
        }
    }

    //slither-disable-next-line reentrancy-no-eth
    function levelUp(uint256 tokenId, bool useOwnRewards) external {
        HopperNFT IHOPPER = HopperNFT(HOPPER);
        if (useOwnRewards) {
            _updateAccountRewards(msg.sender);
        }

        // Check hopper ownership
        address zoneHopperOwner = hopperOwners[tokenId];
        if (zoneHopperOwner != msg.sender) {
            // Saves gas in certain paths
            if (IHOPPER.ownerOf(tokenId) != msg.sender) {
                revert WrongTokenID();
            }
        }

        HopperNFT.Hopper memory hopper = IHOPPER.getHopper(tokenId);

        // Update owners shares if hopper is staked
        if (zoneHopperOwner == msg.sender) {
            // Updated above if true
            if (!useOwnRewards) {
                _updateAccountRewards(msg.sender);
            }

            // Fill hopper gauge so we can find whats the remaining
            (, uint256 remainingGauge, ) = _updateHopperGaugeFill(tokenId);

            // Calculate the baseShare that we need to subtract from the user and total
            uint256 prevHopperShare = _calculateBaseShare(hopper);
            unchecked {
                ++hopper.level;
            }
            // Calculate the baseShare that we need to add to the user and total
            uint256 newHopperShare = _calculateBaseShare(hopper);

            // Calculate new baseShares
            uint256 diff = newHopperShare - prevHopperShare;
            unchecked {
                uint256 newBaseShare = baseSharesBalance[msg.sender] + diff;
                baseSharesBalance[msg.sender] = newBaseShare;

                totalBaseShare += diff;

                // Update new value of veShares
                _updateVeShares(newBaseShare, 0, false);
            }

            uint256 boostFill = 0;
            uint256 userMax = userMaxFlyGeneration[msg.sender];
            if (userMax < remainingGauge) {
                boostFill = remainingGauge - userMax;
            }

            // Update the new cap
            userMaxFlyGeneration[msg.sender] += (_getGaugeLimit(hopper.level) *
                1e12 -
                (remainingGauge - boostFill));

            // Make sure getLevelUpCost is passed its current level
            unchecked {
                --hopper.level;
            }
        }

        payAction(getLevelUpCost(hopper.level), useOwnRewards);

        IHOPPER.levelUp(tokenId);

        // Reset Hopper internal gauge
        IHOPPER.setData(LEVEL_GAUGE_KEY, tokenId, 0);
    }

    /*///////////////////////////////////////////////////////////////
                    STAKE / UNSTAKE NFT && CLAIM FLY
    //////////////////////////////////////////////////////////////*/

    function enter(uint256[] calldata tokenIds) external {
        if (emergency) revert Unauthorized();

        _updateAccountRewards(msg.sender);

        uint256 prevBaseShares = baseSharesBalance[msg.sender];
        uint256 _baseShares = prevBaseShares;
        uint256 numTokens = tokenIds.length;

        uint256 flyCapIncrease;

        uint256 _generatedPerShareStored = generatedPerShareStored[msg.sender];
        for (uint256 i; i < numTokens; ) {
            uint256 tokenId = tokenIds[i];

            // Resets this hopper generation tracking
            tokenCapFilledPerShare[tokenId] = _generatedPerShareStored;

            (
                HopperNFT.Hopper memory hopper,
                uint256 hopperGauge,
                uint256 gaugeLimit
            ) = _getHopperAndGauge(tokenId);

            if (!canEnter(hopper)) revert UnfitHopper();

            unchecked {
                // Increment user shares
                _baseShares += _calculateBaseShare(hopper);
            }

            // Update the maximum FLY this user can generate
            flyCapIncrease += (gaugeLimit - hopperGauge);

            // Hopper Accounting
            hopperOwners[tokenId] = msg.sender;
            HopperNFT(HOPPER).transferFrom(msg.sender, address(this), tokenId);

            unchecked {
                ++i;
            }
        }

        baseSharesBalance[msg.sender] = _baseShares;
        unchecked {
            userMaxFlyGeneration[msg.sender] += flyCapIncrease;

            totalBaseShare = totalBaseShare + _baseShares - prevBaseShares;
        }

        _updateVeShares(_baseShares, 0, false);
    }

    //slither-disable-next-line reentrancy-no-eth
    function exit(uint256[] calldata tokenIds) external {
        if (emergency) revert Unauthorized();

        _updateAccountRewards(msg.sender);

        uint256 prevBaseShares = baseSharesBalance[msg.sender];
        uint256 _baseShares = prevBaseShares;
        uint256 numTokens = tokenIds.length;

        uint256 flyCapDecrease;
        uint256 userMax = userMaxFlyGeneration[msg.sender];

        uint256[] memory rTokensRemaining = new uint256[](tokenIds.length);
        uint256[] memory rTokensLimit = new uint256[](tokenIds.length);

        for (uint256 i; i < numTokens; ) {
            uint256 tokenId = tokenIds[i];

            // Can the user unstake this hopper
            if (hopperOwners[tokenId] != msg.sender) revert WrongTokenID();

            (
                uint256 _hopperShare,
                uint256 _remainingGauge,
                uint256 _gaugeLimit
            ) = _updateHopperGaugeFill(tokenId);

            // Decrement user shares
            _baseShares -= _hopperShare;

            // Update the maximum FLY this user can generate
            flyCapDecrease += _remainingGauge;

            // To fill gauge later
            rTokensRemaining[i] = _remainingGauge;
            rTokensLimit[i] = _gaugeLimit;

            // Hopper Accounting
            //slither-disable-next-line costly-loop
            delete hopperOwners[tokenId];
            HopperNFT(HOPPER).transferFrom(address(this), msg.sender, tokenId);

            unchecked {
                ++i;
            }
        }

        baseSharesBalance[msg.sender] = _baseShares;

        if (userMax < flyCapDecrease) {
            // Being boosted, we need to go back and refill uncapped tokens
            refill(
                tokenIds,
                rTokensRemaining,
                rTokensLimit,
                flyCapDecrease - userMax
            );
            delete userMaxFlyGeneration[msg.sender];
        } else if (_baseShares == 0) {
            delete userMaxFlyGeneration[msg.sender];
        } else {
            userMaxFlyGeneration[msg.sender] -= flyCapDecrease;
        }

        unchecked {
            totalBaseShare = totalBaseShare + _baseShares - prevBaseShares;
        }
        _updateVeShares(_baseShares, 0, false);
    }

    function refill(
        uint256[] calldata tokenIds,
        uint256[] memory remaining,
        uint256[] memory limit,
        uint256 leftover
    ) internal {
        uint256 length = tokenIds.length;

        for (uint256 i; i < length; ) {
            if (remaining[i] != 0) {
                if (leftover > remaining[i]) {
                    HopperNFT(HOPPER).setData(
                        LEVEL_GAUGE_KEY,
                        tokenIds[i],
                        bytes32(limit[i] / 1e12)
                    );
                    leftover -= remaining[i];
                } else {
                    HopperNFT(HOPPER).setData(
                        LEVEL_GAUGE_KEY,
                        tokenIds[i],
                        bytes32((limit[i] - remaining[i] + leftover) / 1e12)
                    );
                    leftover = 0;
                    break;
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    function emergencyExit(uint256[] calldata tokenIds, address user) external {
        if (!emergency) revert Unauthorized();

        uint256 numTokens = tokenIds.length;
        for (uint256 i; i < numTokens; ) {
            uint256 tokenId = tokenIds[i];

            // Can the user unstake this hopper
            if (hopperOwners[tokenId] != user) revert WrongTokenID();

            //slither-disable-next-line costly-loop
            delete hopperOwners[tokenId];
            HopperNFT(HOPPER).transferFrom(address(this), user, tokenId);

            unchecked {
                ++i;
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                            CLAIMING
    //////////////////////////////////////////////////////////////*/

    function claimable(address _account) external view returns (uint256) {
        uint256 cappedFly = userMaxFlyGeneration[_account] / 1e12;

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

        unchecked {
            return rewards[_account] + cappedFly;
        }
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

    function _calcVeShare(uint256 accountTotalBaseShares, uint256 vefly)
        internal
        pure
        returns (uint256)
    {
        return FixedPointMathLib.sqrt(accountTotalBaseShares * vefly);
    }

    //slither-disable-next-line reentrancy-no-eth
    function _updateVeShares(
        uint256 baseShares,
        uint256 veFlyAmount,
        bool incrementVeFlyAmount
    ) internal {
        uint256 beforeVeShare = veSharesBalance[msg.sender];
        if (veFlyAmount > 0) {
            // Ballot checks if the user has the veFly amount necessary, otherwise reverts
            if (incrementVeFlyAmount) {
                //slither-disable-next-line reentrancy-benign
                Ballot(ballot).vote(msg.sender, veFlyAmount);
                unchecked {
                    veFlyBalance[msg.sender] += veFlyAmount;
                }
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

        uint256 userVeShares = veSharesBalance[user];
        _updateAccountBonusReward(user, userVeShares);

        totalVeShare -= userVeShares;
        delete veSharesBalance[user];
        delete veFlyBalance[user];
    }

    /*///////////////////////////////////////////////////////////////
                    HELPER GAUGE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // _remaining is scaled with 1e12
    function _updateHopperGaugeFill(uint256 tokenId)
        internal
        returns (
            uint256 _hopperShare,
            uint256 _remaining,
            uint256
        )
    {
        uint256 _generatedPerShareStored = generatedPerShareStored[msg.sender];

        // Resets this hopper generation tracking
        uint256 filledCapPerShare = _generatedPerShareStored -
            tokenCapFilledPerShare[tokenId];

        tokenCapFilledPerShare[tokenId] = _generatedPerShareStored;

        (
            HopperNFT.Hopper memory hopper,
            uint256 prevHopperGauge,
            uint256 gaugeLimit
        ) = _getHopperAndGauge(tokenId);

        _hopperShare = _calculateBaseShare(hopper);

        uint256 flyGeneratedAndBurned = prevHopperGauge +
            filledCapPerShare *
            _hopperShare;

        uint256 currentGauge = flyGeneratedAndBurned > gaugeLimit
            ? gaugeLimit
            : flyGeneratedAndBurned;

        // Update the HOPPER gauge
        HopperNFT(HOPPER).setData(
            LEVEL_GAUGE_KEY,
            tokenId,
            bytes32(currentGauge / 1e12)
        );

        return (_hopperShare, (gaugeLimit - currentGauge), gaugeLimit);
    }

    function _getGaugeLimit(uint256 level) internal view returns (uint256) {
        if (level == 1) return 1.5 ether;
        if (level == 100) return 294 ether;
        unchecked {
            return flyLevelCapRatio * _getLevelUpCost(level - 1);
        }
    }

    function _getHopperAndGauge(uint256 _tokenId)
        internal
        view
        returns (
            HopperNFT.Hopper memory,
            uint256, // hopperGauge
            uint256 // gaugeLimit
        )
    {
        string[] memory arrData = new string[](1);
        arrData[0] = LEVEL_GAUGE_KEY;
        (HopperNFT.Hopper memory hopper, bytes32[] memory _data) = HopperNFT(
            HOPPER
        ).getHopperWithData(arrData, _tokenId);

        return (
            hopper,
            uint256(_data[0]) * 1e12,
            _getGaugeLimit(hopper.level) * 1e12
        );
    }

    function getHopperAndGauge(uint256 tokenId)
        external
        view
        returns (
            HopperNFT.Hopper memory hopper,
            uint256 hopperGauge,
            uint256 gaugeLimit
        )
    {
        (hopper, hopperGauge, gaugeLimit) = _getHopperAndGauge(tokenId);
        return (hopper, hopperGauge / 1e12, gaugeLimit / 1e12);
    }

    /*///////////////////////////////////////////////////////////////
                                VIEW
    //////////////////////////////////////////////////////////////*/

    function getLevelUpCost(uint256 currentLevel)
        public
        pure
        returns (uint256)
    {
        return _getLevelUpCost(currentLevel);
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
