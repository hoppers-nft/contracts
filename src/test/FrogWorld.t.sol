// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import "ds-test/test.sol";

import "../Fly.sol";
import "../Frog.sol";
import "../Caretaker.sol";
import "../zones/Pond.sol";

interface HEVM {
    function warp(uint256 time) external;

    function prank(address) external;

    function startPrank(address) external;

    function stopPrank() external;

    function deal(address, uint256) external;

    function expectRevert(bytes calldata) external;
}


contract FrogWorld is DSTest {

    // Cheatcodes
    HEVM private hevm = HEVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    // Users
    address public owner;
    address public user1 = address(0x1337);
    address public user2 = address(0x1338);
    address public user3 = address(0x1339);

    // Settings
    uint256 public MAX_MINT_PER_CALL = 10;
    uint256 public MINT_COST = 1 ether;

    // Deployments
    FrogNFT public FROG;
    Fly public FLY;
    CareTaker public CARETAKER;
    Pond public POND;
    
    function setUp() public {
        owner = msg.sender;

        // Deploy
        FROG = new FrogNFT(
            "Frog",
            "Frog",
            MINT_COST,
            10_000,
            MAX_MINT_PER_CALL,
            address(0x1337),
            5,
            0
        );
        FLY = new Fly("FLY", "FLY");
        CARETAKER = new CareTaker(address(FLY), address(FROG));
        POND = new Pond(address(FLY), address(FROG));

        // Add funds
        hevm.deal(user1, 10_000 ether);
        hevm.deal(user2, 10_000 ether);
        hevm.deal(user3, 10_000 ether);
    }

    function testFrogMint() public {
        hevm.startPrank(user1);

        hevm.expectRevert(
            abi.encodeWithSelector(FrogNFT.InsufficientAmount.selector)
        );
        FROG.mint(1);

        hevm.expectRevert(
            abi.encodeWithSelector(FrogNFT.MintLimit.selector)
        );
        FROG.mint{value: MINT_COST * (MAX_MINT_PER_CALL + 1)}(MAX_MINT_PER_CALL + 1);

        hevm.stopPrank();
    }

    function testScenario() public {
        
        // hevm.prank(user1);
        // FROG.mint(10);


    }
}
