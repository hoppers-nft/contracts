.id name

.declare
    EMPTY_BYTES_32 00*32

    # URLS

    HOPPER_IMAGE_URL "https://ipfs.io/ipfs/QmPaq4Gh7sXsQ2W8wxZxFXs6fihiZgs7KsQUEe2FYj8AtS/"
    HOPPER_URI "https://hoppersgame.io/api/uri/hopper/"
    TADPOLE_URI "https://hoppersgame.io/api/tadpole/"

    # EMISSION RATES
    
    # 30 % From eShare per second
    POND_EMISSION_RATE 0.11574ether
    STREAM_EMISSION_RATE 0.11574ether
    SWAMP_EMISSION_RATE 0.11574ether

    # 30 % From eShare per second
    RIVER_EMISSION_RATE 0.3472ether
    
    # 25 % From eShare per second
    FOREST_EMISSION_RATE 0.23148ether
    
    # 15 % From eShare per second
    LAKE_EMISSION_RATE 0.173611ether

    # From veShare per second
    BONUS_EMISSION_RATE 0.5787ether

    # To whoever recounts the votes per second
    REWARD_EMISSION_RATE 0.00007ether

    # veFLY generation per second
    VEFLY_NUMERATOR 14
    VEFLY_DENOMINATOR 3600000
    VEFLY_RATIO_CAP 100

    # Payable Actions
    
    BREEDING_COST 10ether
    NAME_CHANGE_COST 100ether

    # %
    MARKET_FEE 2


.contracts
    # NFTs
    HOPPER "src/Hopper.sol:HopperNFT"
    TADPOLE "src/Tadpole.sol:TadpoleNFT"

    # Currencies
    FLY "src/Fly.sol:Fly"
    VEFLY "src/veFly.sol:veFly"

    # Adventures
    POND "src/zones/Pond.sol:Pond"
    STREAM "src/zones/Stream.sol:Stream"
    SWAMP "src/zones/Swamp.sol:Swamp"
    RIVER "src/zones/River.sol:River"
    FOREST "src/zones/Forest.sol:Forest"
    LAKE "src/zones/Lake.sol:Lake"
    BREEDING "src/zones/Breeding.sol:Breeding"

    BALLOT "src/Ballot.sol:Ballot"

    MARKET "src/Market.sol:Market"

.deployer my_deployer
    network fuji
    signer trezor
    legacy
    # no_cache
    # debug

.use my_deployer
    ###
    # Deployments
    ##

    deploy HOPPER (Hopper, hopper, @NAME_CHANGE_COST)
    deploy TADPOLE (Tad, Tad)

    deploy FLY (FLY, FLY)

    deploy VEFLY ($FLY, @VEFLY_NUMERATOR, @VEFLY_DENOMINATOR, @VEFLY_RATIO_CAP)

    deploy POND ($FLY, $VEFLY, $HOPPER)
    deploy STREAM ($FLY, $VEFLY, $HOPPER)
    deploy BALLOT ($FLY, $VEFLY)

    deploy BREEDING ($FLY, $HOPPER, $TADPOLE, @BREEDING_COST)

    deploy MARKET (@MARKET_FEE)

    ####
    # Setting Parameters
    ####
    send HOPPER setBaseURI (...)
    send HOPPER setImageURL (...)
    send HOPPER setSaleDetails(1, @EMPTY_BYTES_32, @EMPTY_BYTES_32, 0)

    send TADPOLE setBreedingSpot ($BREEDING)
    # send TADPOLE setExchanger($EXCHANGER)
    send TADPOLE setBaseURI(@TADPOLE_URI)

    # Zones
    send POND setEmissionRate(@POND_EMISSION_RATE)
    send POND setBallot($BALLOT)

    send STREAM setEmissionRate(@STREAM_EMISSION_RATE)
    send STREAM setBallot($BALLOT)

    send SWAMP setEmissionRate(@SWAMP_EMISSION_RATE)
    send SWAMP setBallot($BALLOT)

    send RIVER setEmissionRate(@RIVER_EMISSION_RATE)
    send RIVER setBallot($BALLOT)

    send FOREST setEmissionRate(@FOREST_EMISSION_RATE)
    send FOREST setBallot($BALLOT)

    send LAKE setEmissionRate(@LAKE_EMISSION_RATE)
    send LAKE setBallot($BALLOT)

    # Zone FLY Minting
    send FLY addZone($POND)
    send FLY addZone($STREAM)
    send FLY addZone($SWAMP)
    send FLY addZone($RIVER)
    send FLY addZone($FOREST)
    send FLY addZone($LAKE)
    send FLY addZone($BALLOT)

    # Ballots
    send BALLOT addZones([$POND,$STREAM,$SWAMP,$RIVER,$FOREST,$LAKE])
    send BALLOT setBonusEmissionRate(@BONUS_EMISSION_RATE)
    send BALLOT setCountRewardRate(@REWARD_EMISSION_RATE)
    send BALLOT openBallot()

    send VEFLY addBallot($BALLOT)

    send HOPPER addZone($POND)
    send HOPPER addZone($STREAM)
    send HOPPER addZone($SWAMP)
    send HOPPER addZone($RIVER)
    send HOPPER addZone($FOREST)
    send HOPPER addZone($LAKE)

    # Market
    send MARKET openMarket ()
    send MARKET addTokenAddress($HOPPER)
    send MARKET addTokenAddress($TADPOLE)

    ## Test Accounts
    send HOPPER setApprovalForAll($POND, true)
    send HOPPER setApprovalForAll($STREAM, true)
    send FLY approve($VEFLY, 1000000000ether)

    # Set owner