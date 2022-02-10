// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

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

    mapping(uint256 => address) public hopperOwners;
    mapping(address => uint256) public numHoppersOfOwner;
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
        rewardPerShareStored = rewardPerShare();
        emissionRate = _emissionRate;
        emit UpdatedEmission(_emissionRate);
    }

    function setBonusEmissionRate(uint256 _bonusEmissionRate)
        external
        onlyBallotOrOwner
    {
        bonusRewardPerShareStored = bonusRewardPerShare();
        bonusEmissionRate = _bonusEmissionRate;
    }

    /*///////////////////////////////////////////////////////////////
                           REWARDS ACCOUNTING
    //////////////////////////////////////////////////////////////*/

    function rewardPerShare() public view returns (uint256) {
        if (totalSupply == 0) {
            return 0;
        }
        return
            rewardPerShareStored +
            (((block.timestamp - lastUpdatedTime) * emissionRate * 1e18) /
                totalSupply);
    }

    function earned(address account) public view returns (uint256) {
        return
            ((baseSharesBalance[account] *
                (rewardPerShare() - userRewardPerSharePaid[account])) / 1e18) +
            rewards[account];
    }

    function _updateAccountReward(address account) internal {
        rewardPerShareStored = rewardPerShare();
        lastUpdatedTime = block.timestamp;

        rewards[account] = earned(account);
        userRewardPerSharePaid[account] = rewardPerShareStored;

        _updateAccountBonusReward(account);
    }

    /*///////////////////////////////////////////////////////////////
                           BONUS REWARDS ACCOUNTING
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

    function earnedBonus(address account) public view returns (uint256) {
        return
            ((veSharesBalance[account] *
                (bonusRewardPerShare() -
                    userBonusRewardPerSharePaid[account])) / 1e18) +
            rewards[account];
    }

    function _updateAccountBonusReward(address account) internal {
        if (veSharesBalance[account] > 0) {
            bonusRewardPerShareStored = bonusRewardPerShare();
            lastBonusUpdatedTime = block.timestamp;

            rewards[account] = earnedBonus(account);
            userBonusRewardPerSharePaid[account] = bonusRewardPerShareStored;
        }
    }

    /*///////////////////////////////////////////////////////////////
                    NAMES & LEVELING
    //////////////////////////////////////////////////////////////*/

    function payAction(uint256 flyRequired, bool useOwnRewards) internal {
        if (useOwnRewards) {
            uint256 _rewards = rewards[msg.sender];

            // Pays for level up from the pending rewards
            if (_rewards >= flyRequired) {
                unchecked {
                    rewards[msg.sender] -= flyRequired;
                }
            } else if (_rewards > 0) {
                rewards[msg.sender] = 0;
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

    function getLevelUpCost(uint256 currentLevel)
        internal
        pure
        returns (uint256)
    {
        if (currentLevel == 1 && currentLevel <= 19) {
            unchecked {
                return (currentLevel + 1) * (10**18);
            }
        } else if (currentLevel == 99) {
            return type(uint256).max;
        } else {
            // todo (currentLevel + 1) $FLY **1.43522
            unchecked {
                return (currentLevel + 1) * (10**18);
            }
        }
    }

    function levelUp(uint256 tokenId, bool useOwnRewards) external {
        // Check hopper ownership
        address zoneHopperOwner = hopperOwners[tokenId];
        if (zoneHopperOwner != msg.sender) {
            // Saves gas in certain paths
            if (HopperNFT(HOPPER).ownerOf(tokenId) != msg.sender) {
                revert WrongTokenID();
            }
        }

        // Check if there's enough FLY (balance + pending rewards) to level up hopper
        HopperNFT.Hopper memory hopper = HopperNFT(HOPPER).getHopper(tokenId);
        payAction(getLevelUpCost(hopper.level), useOwnRewards);

        // Update owners shares if hopper is staked
        if (zoneHopperOwner == msg.sender) {
            _updateAccountReward(msg.sender);

            uint256 prevHopperShare = _calculateBaseShare(hopper);
            unchecked {
                ++hopper.level;
            }
            uint256 hopperShare = _calculateBaseShare(hopper);

            uint256 newBaseShare = baseSharesBalance[msg.sender] -
                prevHopperShare +
                hopperShare;
            baseSharesBalance[msg.sender] = newBaseShare;

            _updateAccountReward(msg.sender);
            _updateVeShares(newBaseShare, 0, false);
        }

        HopperNFT(HOPPER).levelUp(tokenId);
    }

    /*///////////////////////////////////////////////////////////////
                    STAKE / UNSTAKE NFT && CLAIM FLY
    //////////////////////////////////////////////////////////////*/

    function enter(uint256[] calldata tokenIds) external {
        _updateAccountReward(msg.sender);

        uint256 prevBaseShares = baseSharesBalance[msg.sender];
        uint256 _baseShares = prevBaseShares;
        uint256 numTokens = tokenIds.length;

        for (uint256 i; i < numTokens; ++i) {
            uint256 tokenId = tokenIds[i];

            // Can the hopper enter this zone?
            HopperNFT.Hopper memory hopper = HopperNFT(HOPPER).getHopper(
                tokenId
            );
            if (!canEnter(hopper)) revert UnfitHopper();

            // Increment user shares
            _baseShares += _calculateBaseShare(hopper);

            // Hopper Accounting
            hopperOwners[tokenId] = msg.sender;
            unchecked {
                ++numHoppersOfOwner[msg.sender];
            }
            HopperNFT(HOPPER).transferFrom(msg.sender, address(this), tokenId);
        }

        baseSharesBalance[msg.sender] = _baseShares;

        unchecked {
            totalSupply = totalSupply + _baseShares - prevBaseShares;
        }
        _updateVeShares(_baseShares, 0, false);
    }

    function exit(uint256[] calldata tokenIds) external {
        _updateAccountReward(msg.sender);

        uint256 prevBaseShares = baseSharesBalance[msg.sender];
        uint256 _baseShares = prevBaseShares;
        uint256 numTokens = tokenIds.length;

        for (uint256 i; i < numTokens; ++i) {
            uint256 tokenId = tokenIds[i];

            // Can the user unstake this hopper
            if (hopperOwners[tokenId] != msg.sender) revert WrongTokenID();
            HopperNFT.Hopper memory hopper = HopperNFT(HOPPER).getHopper(
                tokenId
            );

            // Decrement user shares
            _baseShares -= _calculateBaseShare(hopper);
            // todo would cached hopperBaseShare be cheaper?

            // Hopper Accounting
            delete hopperOwners[tokenId];
            unchecked {
                --numHoppersOfOwner[msg.sender];
            }

            HopperNFT(HOPPER).transferFrom(address(this), msg.sender, tokenId);
        }

        baseSharesBalance[msg.sender] = _baseShares;

        unchecked {
            totalSupply = totalSupply + _baseShares - prevBaseShares;
        }

        _updateVeShares(_baseShares, 0, false);
    }

    function claim() external {
        _updateAccountReward(msg.sender);

        uint256 _accountRewards = rewards[msg.sender];
        rewards[msg.sender] = 0;

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

    function _updateVeShares(
        uint256 baseShares,
        uint256 veFlyAmount,
        bool increment
    ) internal {
        uint256 beforeVeShare = veSharesBalance[msg.sender];

        if (beforeVeShare > 0 || veFlyAmount > 0) {
            uint256 currentVeFly;

            if (veFlyAmount > 0) {
                if (increment) {
                    currentVeFly = Ballot(ballot).vote(msg.sender, veFlyAmount);
                } else {
                    currentVeFly = Ballot(ballot).unvote(
                        msg.sender,
                        veFlyAmount
                    );
                }
                veFlyBalance[msg.sender] = currentVeFly;
            } else {
                currentVeFly = veFlyBalance[msg.sender];
            }

            uint256 currentVeShare = _calcVeShare(baseShares, currentVeFly);
            veSharesBalance[msg.sender] = currentVeShare;

            unchecked {
                totalVeShare = totalVeShare + currentVeShare - beforeVeShare;
            }
        }
    }

    function vote(uint256 veFlyAmount, bool recount) external {
        _updateAccountBonusReward(msg.sender);

        _updateVeShares(baseSharesBalance[msg.sender], veFlyAmount, true);

        if (recount) Ballot(ballot).count();
    }

    function unvote(uint256 veFlyAmount, bool recount) external {
        _updateAccountBonusReward(msg.sender);

        _updateVeShares(baseSharesBalance[msg.sender], veFlyAmount, false);

        if (recount) Ballot(ballot).count();
    }

    function forceUnvote(address user) external {
        if (msg.sender != ballot) revert Unauthorized();

        _updateAccountBonusReward(user);

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
    {}

    function _calculateBaseShare(HopperNFT.Hopper memory hopper)
        internal
        pure
        virtual
        returns (uint256)
    {} // solhint-disable-line
}
