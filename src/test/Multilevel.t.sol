//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;
import "ds-test/test.sol";
import "../MultiLevelUp.sol";
import {BaseTest, HEVM, HopperNFT, Ballot} from "./BaseTest.sol";


contract MultilevelTestsV2 is BaseTest {

    address Bob = address(0x132323);
    MultilevelUp public MULTILEVELUP;

    /*///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    

    function initialPreperation() internal {
        MULTILEVELUP = new MultilevelUp(address(FLY),address(HOPPER));

        address[] memory zones = new address[](1);
        zones[0] = address(MULTILEVELUP);
        address owner = HOPPER.owner();
        
        hevm.prank(owner);
        HOPPER.addZones(zones);
        
        hevm.prank(owner);
        FLY.addZones(zones);

    }


    function getHopperLevel(uint tokenId) internal view returns (uint) {
        HopperNFT.Hopper memory hopper = HOPPER.getHopper(tokenId);
        return hopper.level;

    }

    function mintHopperForUser(address user, uint tokenId) internal   {
        hevm.prank(user);
        HOPPER.addHopper(tokenId);
    }

    function mintHopperwithLevel(address user, uint tokenId, uint200 startLevel) public {
        hevm.prank(user);
        HOPPER.mintHopperwithLevel(tokenId, startLevel);
    }

    /*///////////////////////////////////////////////////////////////
                          TEST FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    function testNaiveVsMultiWithFuzzing(uint levels) public {
        if(levels > 98) { // starts from level 2
            return;
        }
        initialPreperation();

        mintHopperForUser(Bob,12);
        FLY.mockMint(Bob, 11512 ether);
        uint initialBobBalance = FLY.balanceOf(Bob);
        
        hevm.prank(Bob);
        uint currentLevel = getHopperLevel(12);

        //naive level up 
        for (uint256 index = 0; index <  levels; index++) {
            hevm.prank(Bob);
            POND.levelUp(12, false);
        }
        uint LevelUpCost =  initialBobBalance - FLY.balanceOf(Bob) ;
        uint currentLevelAfter = getHopperLevel(12);
        assertEq(currentLevel + levels, currentLevelAfter);
        

        mintHopperForUser(Bob,13);
        uint initialBobBalanceBeforeMLU = FLY.balanceOf(Bob);

        uint HopperLevelBeforeMLU = getHopperLevel(13);
        hevm.prank(Bob);
        MULTILEVELUP.multiLevelUp(levels, 13);
        uint HopperLevelAfterMLU = getHopperLevel(13);


        uint LevelUpCostMLU =  initialBobBalanceBeforeMLU - FLY.balanceOf(Bob) ;
        assertEq(LevelUpCostMLU, LevelUpCost);
        assertEq(HopperLevelBeforeMLU + levels, HopperLevelAfterMLU);
        assertEq(HopperLevelAfterMLU, currentLevelAfter);


        
    }

    // 
    function testFailAfterLevel100() public {
    
        initialPreperation();
        FLY.mockMint(Bob, 11512 ether);
        mintHopperwithLevel(Bob,13,100);
        assertEq(getHopperLevel(13),100);
        hevm.prank(Bob);
        MULTILEVELUP.multiLevelUp(1, 13);

    
    }

    function testMultiLevelAfterRebirth() public {
    
        initialPreperation();
        FLY.mockMint(Bob, 11512 ether);
        mintHopperwithLevel(Bob,13,1);
        hevm.prank(Bob);
        MULTILEVELUP.multiLevelUp(99, 13);
        assertEq(getHopperLevel(13),100);

        hevm.prank(Bob);
        HOPPER.rebirth(13);
        assertEq(getHopperLevel(13),1);

        hevm.prank(Bob);
        MULTILEVELUP.multiLevelUp(17, 13);
        assertEq(getHopperLevel(13),18);

    
    }



    function testAlllevels() public {
        initialPreperation();
        uint tokenId = 1;
        
        FLY.mockMint(Bob, 11511111112 ether);

        for (uint200 startLevel = 1; startLevel < 100; startLevel++){
            for (uint256 levels = 1; levels < (100 - startLevel); levels++) {  
          
            mintHopperwithLevel(Bob,tokenId,startLevel);
            uint initialBalanceBob = FLY.balanceOf(Bob);
            uint initialLevelFirstHopper = getHopperLevel(tokenId);
    
            //naive level up 
            for (uint256 x = 0; x <  levels; x++) {
                hevm.prank(Bob);
                POND.levelUp(tokenId, false);
            }

            uint naiveLevelUpCost =  initialBalanceBob - FLY.balanceOf(Bob) ;
            uint levelAfterNaiveLevelUpFirstHopper = getHopperLevel(tokenId);
            assertEq(initialLevelFirstHopper + levels, levelAfterNaiveLevelUpFirstHopper);
            
            //mint another token
            tokenId++;
            mintHopperwithLevel(Bob,tokenId,startLevel);
            uint BobBalanceBeforeMulti = FLY.balanceOf(Bob);
    
            uint levelBeforeMultiSecondHopper = getHopperLevel(tokenId);
            assertEq(levelBeforeMultiSecondHopper, initialLevelFirstHopper);

            hevm.prank(Bob);
            MULTILEVELUP.multiLevelUp(levels, tokenId);
            uint HopperLevelAfterMLU = getHopperLevel(tokenId);
    
    
            uint LevelUpCostMulti =  BobBalanceBeforeMulti - FLY.balanceOf(Bob) ;
            assertEq(LevelUpCostMulti, naiveLevelUpCost);
            assertEq(levelBeforeMultiSecondHopper + levels, HopperLevelAfterMLU);
            assertEq(HopperLevelAfterMLU, levelAfterNaiveLevelUpFirstHopper);
            tokenId++;
            }

          }    
    }      



}
