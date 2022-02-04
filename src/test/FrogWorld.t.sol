// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import "ds-test/test.sol";

import "../Fly.sol";
import "../Hopper.sol";
import "../Caretaker.sol";
import "../zones/Pond.sol";

interface HEVM {
    function warp(uint256 time) external;

    function prank(address) external;

    function prank(address, address) external;

    function startPrank(address) external;
    
    function startPrank(address, address) external;

    function stopPrank() external;

    function deal(address, uint256) external;

    function expectRevert(bytes calldata) external;
}


contract HopperWorld is DSTest {

    // Cheatcodes
    HEVM private hevm = HEVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    // Users
    address public owner;
    address public user1 = address(0x1337);
    address public user2 = address(0x1338);
    address public user3 = address(0x1339);
    address public caretakerUser = address(0x1340);

    // Settings
    uint256 public MAX_MINT_PER_CALL = 10;
    uint256 public MINT_COST = 1 ether;

    // Deployments
    HopperNFT public HOPPER;
    Fly public FLY;
    CareTaker public CARETAKER;
    Pond public POND;
    
    function setUp() public {
        owner = msg.sender;

        // Deploy
        HOPPER = new HopperNFT(
            "Hopper",
            "Hopper",
            MINT_COST,
            10_000,
            MAX_MINT_PER_CALL,
            address(0x1337),
            5,
            0
        );
        FLY = new Fly("FLY", "FLY");
        CARETAKER = new CareTaker(address(FLY), address(HOPPER));
        POND = new Pond(address(FLY), address(HOPPER));

        // Add funds
        hevm.deal(user1, 10_000 ether);
        hevm.deal(user2, 10_000 ether);
        hevm.deal(user3, 10_000 ether);

        HOPPER.addCaretaker(caretakerUser);
    }

    function testHopperMint() public {
        hevm.startPrank(user1, user1);

        hevm.expectRevert(
            abi.encodeWithSelector(HopperNFT.InsufficientAmount.selector)
        );
        HOPPER.mint(1);

        hevm.expectRevert(
            abi.encodeWithSelector(HopperNFT.MintLimit.selector)
        );
        HOPPER.mint{value: MINT_COST * (MAX_MINT_PER_CALL + 1)}(MAX_MINT_PER_CALL + 1);

        HOPPER.mint{value: MINT_COST * MAX_MINT_PER_CALL}(MAX_MINT_PER_CALL);


        hevm.stopPrank();
    }

    function testScenario() public {
        
        // hevm.prank(user1);
        // HOPPER.mint(10);


    }

    function testNames() public {
        hevm.prank(user1, user1);
        HOPPER.mint{value: MINT_COST}(1);

        assert(
            keccak256(bytes("Unnamed")) ==
                keccak256(bytes(HOPPER.getHopperName(0)))
        );

        hevm.prank(user2);
        hevm.expectRevert(
            abi.encodeWithSelector(HopperNFT.Unauthorized.selector)
        );
        HOPPER.changeHopperName(0, "hopper");

        hevm.prank(caretakerUser);
        HOPPER.changeHopperName(0, "hopper");
        assert(
            keccak256(bytes("hopper")) ==
                keccak256(bytes(HOPPER.getHopperName(0)))
        );

        hevm.prank(user1);
        HOPPER.transferFrom(user1, user2, 0);
        assert(
            keccak256(bytes("hopper")) ==
                keccak256(bytes(HOPPER.getHopperName(0)))
        );

        hevm.prank(caretakerUser);
        HOPPER.changeHopperName(0, "myhopper");
        assert(
            keccak256(bytes("myhopper")) ==
                keccak256(bytes(HOPPER.getHopperName(0)))
        );
    }
}
