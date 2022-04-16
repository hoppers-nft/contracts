//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {HopperNFT} from "./Hopper.sol";
import {Fly} from "./Fly.sol";


//slither-disable-next-line locked-ether
contract MultilevelUp {
    address public immutable FLY;
    address public immutable HOPPER;
    address public owner;

    string public immutable LEVEL_GAUGE_KEY;
    uint public constant LEVEL_UP_COST_CATEGORY_0 = 1051288022900527273848688253688596547214916831956288517063648523173704499200;
    uint public constant LEVEL_UP_COST_CATEGORY_1 = 4549695761791932346867726865992642700429225143980401255780434475327577129635;
    uint public constant LEVEL_UP_COST_CATEGORY_2 = 11811543960987259923365662880439990815517098782391593173251212966463154752205;
    uint public constant LEVEL_UP_COST_CATEGORY_3 = 23684932826573291205163703188724542792741345673977579048319878367674389961585;
    uint public constant LEVEL_UP_COST_CATEGORY_4 = 40841274218494176753190239841356774803731824592103246109976028595510861837925;
    uint public constant LEVEL_UP_COST_CATEGORY_5 = 63828299623757599652339988891003529005521872508617173962538202162096509771025;
    uint public constant LEVEL_UP_COST_CATEGORY_6 = 754575304390847322886335;


    event UpdatedOwner(address indexed owner);
    error LevelOutofBounds();
    error WrongTokenID();
    error Unauthorized();

    constructor(  address fly,address hopper
    ) {
        owner = msg.sender;
        FLY = fly;
        HOPPER = hopper;
        LEVEL_GAUGE_KEY = "LEVEL_GAUGE_KEY";

    }
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
        emit UpdatedOwner(_owner);
    }

    function calculateMultiLevelUpCost(uint currentLevel, uint targetLevel) public pure returns (uint) {
        if(targetLevel > 100) { revert LevelOutofBounds(); }
        return (getCumulativeLevelUpCost(targetLevel) - getCumulativeLevelUpCost(currentLevel)) * 10**17; 
    }


    function getValueFromBitMap(uint256 x, uint position) internal pure returns (uint) {
        return (((x >> ((position) * 16)) & type(uint16).max));
    }

    function getCumulativeLevelUpCost(uint level) internal pure returns  (uint) {

        uint category = level / 16;
        if (category == 0){
            category = LEVEL_UP_COST_CATEGORY_0;
        }
        else if (category == 1){
            category = LEVEL_UP_COST_CATEGORY_1;
        }
        else if (category == 2){
            category = LEVEL_UP_COST_CATEGORY_2;
        }
        else if (category == 3){
            category = LEVEL_UP_COST_CATEGORY_3;
        }
        else if (category == 4){
            category = LEVEL_UP_COST_CATEGORY_4;
        }
        else if (category == 5){
            category = LEVEL_UP_COST_CATEGORY_5;
        }
        else if (category == 6){
            category = LEVEL_UP_COST_CATEGORY_6;
        }    
        uint position = level % 16;
        return getValueFromBitMap(category,position);

    }


    function multiLevelUp(uint levels, uint tokenId) external {

        HopperNFT IHOPPER = HopperNFT(HOPPER);
        if (IHOPPER.ownerOf(tokenId) != msg.sender) {
            revert WrongTokenID();
        }

        HopperNFT.Hopper memory hopper = IHOPPER.getHopper(tokenId);
        uint currentLevel = hopper.level;
        uint levelUpCost = calculateMultiLevelUpCost(currentLevel,currentLevel + levels);
        Fly(FLY).burn(msg.sender, levelUpCost);
        
        
        for(uint i ;i<levels; ++i){
            IHOPPER.levelUp(tokenId);
        }

        // Reset Hopper internal gauge
        IHOPPER.setData(LEVEL_GAUGE_KEY, tokenId, 0);

    }

}