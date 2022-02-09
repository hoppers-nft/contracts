// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import "ds-test/test.sol";

import "../Hopper.sol";
import "../Fly.sol";
import "../veFly.sol";
import "../Ballot.sol";

import "../zones/Pond.sol";
import "../zones/Stream.sol";

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

contract BaseTest is DSTest {
    // Cheatcodes
    HEVM public hevm = HEVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    // Users
    address public owner;
    address public user1 = address(0x1337);
    address public user2 = address(0x1338);
    address public user3 = address(0x1339);

    // Settings
    uint256 public MAX_MINT_PER_CALL = 10;
    uint256 public MINT_COST = 1 ether;

    // Deployments
    HopperNFT public HOPPER;
    Fly public FLY;
    veFly public VEFLY;
    Pond public POND;
    Stream public STREAM;
    Ballot public BALLOT;

    // EmissionRates
    uint256 public ZONE_EMISSION_RATE = 3;
    uint256 public BONUS_EMISSION_RATE = 2;
    uint256 public REWARD_EMISSION_RATE = 1;
    uint256 public VEFLY_RATE = 2;
    uint256 public VEFLY_CAP = 100;

    function setUp() public {
        owner = msg.sender;

        // NFT
        HOPPER = new HopperNFT(
            "Hopper",
            "Hopper",
            MINT_COST,
            10_000,
            MAX_MINT_PER_CALL,
            address(0x1337), // royalty address
            5, // royalty fee
            0, // sale time
            0.01 ether // namefee
        );

        // Initiate Contracts
        FLY = new Fly("FLY", "FLY");
        VEFLY = new veFly(address(FLY), VEFLY_RATE, VEFLY_CAP);
        POND = new Pond(address(FLY), address(VEFLY), address(HOPPER));
        STREAM = new Stream(address(FLY), address(VEFLY), address(HOPPER));
        BALLOT = new Ballot(address(FLY), address(VEFLY));

        // Setting up adventures
        address[] memory _adventures = new address[](2);
        _adventures[0] = address(POND);
        _adventures[1] = address(STREAM);

        POND.setEmissionRate(ZONE_EMISSION_RATE);
        POND.setBallot(address(BALLOT));
        STREAM.setEmissionRate(ZONE_EMISSION_RATE);
        STREAM.setBallot(address(BALLOT));

        // FLY minters
        FLY.addZone(_adventures[0]);
        FLY.addZone(_adventures[1]);
        FLY.addZone(address(BALLOT)); // for reward

        // BALLOT
        BALLOT.addAdventures(_adventures);
        BALLOT.setBonusEmissionRate(BONUS_EMISSION_RATE);
        BALLOT.setCountRewardRate(REWARD_EMISSION_RATE);
        BALLOT.openBallot();

        // Valid Voting
        VEFLY.addBallot(address(BALLOT));

        // Add funds
        hevm.deal(user1, 10_000 ether);
        hevm.deal(user2, 10_000 ether);
        hevm.deal(user3, 10_000 ether);

        // Approvals
        hevm.startPrank(user1);
        HOPPER.setApprovalForAll(address(POND), true);
        HOPPER.setApprovalForAll(address(STREAM), true);

        FLY.approve(address(VEFLY), type(uint256).max);
        hevm.stopPrank();
    }
}
