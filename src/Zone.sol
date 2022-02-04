// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import {Fly} from "./Fly.sol";
import {HopperNFT} from "./Hopper.sol";

abstract contract Zone {
    /*///////////////////////////////////////////////////////////////
                            IMMUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable FLY;
    address public immutable HOPPER;

    /*///////////////////////////////////////////////////////////////
                                HOPPERS
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => address) public hopperOwners;
    mapping(address => uint256) public numHoppersOfOwner;
    mapping(uint256 => uint256) public hopperBaseShare;

    // mapping(uint256 => uint256) public hopperSnapshots;

    address public owner;
    address public architect;

    /*///////////////////////////////////////////////////////////////
                                Accounting
    //////////////////////////////////////////////////////////////*/
    uint256 public baseEmissionRate;
    uint256 public emissionRate;
    uint256 public lastEmissionUpdatedTime;

    uint256 public totalSupply;
    uint256 public lastUpdatedTime;
    uint256 public rewardPerShareStored;

    mapping(address => uint256) public baseSharesBalance;
    mapping(address => uint256) public actualSharesBalance;
    mapping(address => uint256) public userRewardPerSharePaid;
    mapping(address => uint256) public rewards;

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error Unauthorized();
    error UnfitHopper();
    error TooSoon();
    error WrongTokenID();

    /*///////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event UpdatedOwner(address indexed owner);
    event UpdatedArchitect(address indexed architect);
    event UpdatedEmission(uint256 emissionRate);

    /*///////////////////////////////////////////////////////////////
                           CONTRACT MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    constructor(address fly, address hopper) {
        owner = msg.sender;

        FLY = fly;
        HOPPER = hopper;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyArchitect() {
        if (msg.sender != architect) revert Unauthorized();
        _;
    }

    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
        emit UpdatedOwner(_owner);
    }

    function setArchitect(address _architect) external onlyOwner {
        architect = _architect;
        emit UpdatedArchitect(_architect);
    }

    function updateEmissionRate(uint256 _emissionRate) external onlyOwner {
        emissionRate = _emissionRate;
        emit UpdatedEmission(emissionRate);
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
        // todo hmmmm
        return
            ((actualSharesBalance[account] *
                (rewardPerShare() - userRewardPerSharePaid[account])) / 1e18) +
            rewards[account];
    }

    function _updateAccountReward(address account) internal {
        rewardPerShareStored = rewardPerShare();
        lastUpdatedTime = block.timestamp;

        rewards[account] = earned(account);
        userRewardPerSharePaid[account] = rewardPerShareStored;
    }

    function _updateVeFlyShare(uint256 userShare) internal {
        //todo
    }

    /*///////////////////////////////////////////////////////////////
                    LEVEL UP REQUIREMENTS
    //////////////////////////////////////////////////////////////*/

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
        uint256 flyRequired = getLevelUpCost(hopper.level);

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

        // Sender pays for level up. Will revert, if not enough balance
        if (flyRequired > 0) {
            Fly(FLY).burn(msg.sender, flyRequired);
        }

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

            // todo does this require level to be taken into account?
            _updateVeFlyShare(newBaseShare);
        }

        HopperNFT(HOPPER).levelUp(tokenId);
    }

    /*///////////////////////////////////////////////////////////////
                    EXTERNAL REWARD MODIFIERS
    //////////////////////////////////////////////////////////////*/

    function enter(uint256[] calldata tokenIds) external {
        _updateAccountReward(msg.sender);

        uint256 prevBaseShares = baseSharesBalance[msg.sender];
        uint256 _baseShares = prevBaseShares;
        uint256 numTokens = tokenIds.length;

        for (uint256 i; i < numTokens; ++i) {
            uint256 tokenId = tokenIds[i];
            HopperNFT.Hopper memory hopper = HopperNFT(HOPPER).getHopper(
                tokenId
            );

            if (!canEnter(hopper)) revert UnfitHopper();

            _baseShares += _calculateBaseShare(hopper);

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

        _updateVeFlyShare(_baseShares);
    }

    function exit(uint256[] calldata tokenIds) external {
        _updateAccountReward(msg.sender);

        uint256 prevBaseShares = baseSharesBalance[msg.sender];
        uint256 _baseShares = prevBaseShares;
        uint256 numTokens = tokenIds.length;

        for (uint256 i; i < numTokens; ++i) {
            uint256 tokenId = tokenIds[i];

            if (hopperOwners[tokenId] != msg.sender) revert WrongTokenID();

            HopperNFT.Hopper memory hopper = HopperNFT(HOPPER).getHopper(
                tokenId
            );

            _baseShares -= _calculateBaseShare(hopper);
            // todo would cached hopperBaseShare be cheaper?

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

        _updateVeFlyShare(_baseShares);
    }

    function claim() external {
        _updateAccountReward(msg.sender);

        uint256 _accountRewards = rewards[msg.sender];
        rewards[msg.sender] = 0;

        Fly(FLY).mint(msg.sender, _accountRewards);
    }

    /*///////////////////////////////////////////////////////////////
                    ZONE SPECIFIC FUNCTIONALITY
    //////////////////////////////////////////////////////////////*/

    function canEnter(HopperNFT.Hopper memory hopper)
        public
        pure
        returns (bool)
    {}

    function _calculateBaseShare(HopperNFT.Hopper memory hopper)
        internal
        pure
        virtual
        returns (uint256)
    {} // solhint-disable-line
}
