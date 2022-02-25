// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.12;

import "ds-test/test.sol";

import "../Hopper.sol";
import "../Fly.sol";
import "../veFly.sol";
import "../Ballot.sol";

import "../zones/Pond.sol";
import "../zones/Stream.sol";

import "../zones/Breeding.sol";
import "../Tadpole.sol";

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
    uint256 public MAX_HOPPER_SUPPLY = 10_000;
    uint256 public MAX_MINT_PER_CALL = 10;
    uint256 public MINT_COST = 1.75 ether;
    uint256 public WL_MINT_COST = 1.2 ether;
    uint256 public BREEDING_COST = 1.5 ether;

    // Deployments
    address public EXCHANGER = address(0xabab);
    TadpoleNFT public TADPOLE;
    Breeding public BREEDING;
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
    uint256 public VEFLY_NUM_RATE = 1;
    uint256 public VEFLY_DENOM_RATE = 1;
    uint256 public VEFLY_CAP = 100;

    function expectErrorAndSuccess(
        address addr,
        bytes4 errorSelector,
        bytes memory _callData,
        address firstUser,
        address secondUser
    ) internal {
        // Call expecting Failure
        hevm.prank(firstUser);
        (bool success, bytes memory data) = addr.call(_callData);
        assert(!success);
        assertEq(bytes4(data), errorSelector);

        // Call expecting Success
        hevm.prank(secondUser);
        (success, data) = addr.call(_callData);
        assert(success);
    }

    function getZones() internal returns (address[] memory) {
        address[] memory _zones = new address[](2);
        _zones[0] = address(POND);
        _zones[1] = address(STREAM);
        return _zones;
    }

    function increaseLevels(uint256 tokenId, uint256 num) internal {
        // Only Zones can level an hopper up
        hevm.startPrank(address(POND));
        for (uint256 i; i < num; ++i) {
            HOPPER.levelUp(tokenId);
        }
        hevm.stopPrank();
    }

    function setUp() public {
        owner = address(0x13371337);

        hevm.startPrank(owner);

        // NFT
        HOPPER = new HopperNFT(
            "Hopper",
            "Hopper",
            0.01 ether // namefee
        );

        HOPPER.setSaleDetails(
            type(uint256).max - 30 minutes + 1,
            bytes32(0),
            bytes32(0),
            0
        );

        // Initiate Contracts
        FLY = new Fly("FLY", "FLY");
        VEFLY = new veFly(
            address(FLY),
            VEFLY_NUM_RATE,
            VEFLY_DENOM_RATE,
            VEFLY_CAP
        );
        POND = new Pond(address(FLY), address(VEFLY), address(HOPPER));
        STREAM = new Stream(address(FLY), address(VEFLY), address(HOPPER));
        BALLOT = new Ballot(address(FLY), address(VEFLY));

        TADPOLE = new TadpoleNFT("TADP", "TADP");
        BREEDING = new Breeding(
            address(FLY),
            address(HOPPER),
            address(TADPOLE),
            BREEDING_COST
        );

        TADPOLE.setBreedingSpot(address(BREEDING));
        TADPOLE.setExchanger(address(EXCHANGER));
        TADPOLE.setBaseURI("tadpole.io/id/");

        // Setting up zones
        address[] memory _zones = getZones();

        POND.setEmissionRate(ZONE_EMISSION_RATE);
        POND.setBallot(address(BALLOT));
        STREAM.setEmissionRate(ZONE_EMISSION_RATE);
        STREAM.setBallot(address(BALLOT));

        // FLY minters
        FLY.addZone(_zones[0]);
        FLY.addZone(_zones[1]);
        FLY.addZone(address(BALLOT)); // for reward

        // BALLOT
        BALLOT.addZones(_zones);
        BALLOT.setBonusEmissionRate(BONUS_EMISSION_RATE);
        BALLOT.setCountRewardRate(REWARD_EMISSION_RATE);
        BALLOT.openBallot();

        // Valid Voting
        VEFLY.addBallot(address(BALLOT));

        // Add funds
        hevm.deal(user1, 100_000 ether);
        hevm.deal(user2, 100_000 ether);
        hevm.deal(user3, 100_000 ether);

        // LevelUp && Name Authorization
        HOPPER.addZone(_zones[0]);
        HOPPER.addZone(_zones[1]);

        // Approvals
        hevm.startPrank(user1);
        HOPPER.setApprovalForAll(address(POND), true);
        HOPPER.setApprovalForAll(address(STREAM), true);

        FLY.approve(address(VEFLY), type(uint256).max);
        hevm.stopPrank();
        hevm.stopPrank();
    }

    fallback() external payable {}
}
