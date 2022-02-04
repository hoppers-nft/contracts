# Hopper

# Contracts
* `Hopper.sol`: NFT
  * Leveling up can only be done by an external contract approved by the contract owner.
* `Fly.sol`: ERC20
  * Minting can only be done by a `Zone` approved by the contract owner.
* `Zone.sol`:
  * Template/abstract contract for zones which can mint `Fly`
  * Contracts using the template have to override `calculateFarmAmount`
  * Example: `zones/Pond.sol`
* `Caretaker.sol`
  * Contract which can issue a level_up from the user. 

# Description
## Attributes
All of the attiributes will be stored on chain. Name of the hopper, accessories and the ipfs link will be stored offchain.

 * Strength (Randomly assigned a value between 1-10 during minting)

  * Agility (Randomly assigned a value between 1-10 during minting)

*  Vitality (Randomly assigned a value between 1-10 during minting)

 * Intelligence (Randomly assigned a value between 1-10 during minting)

* Fertility (Randomly assigned a value between 1-10 during minting)

 * Level (Starts with level 1, no hard level cap)

	* Experience (Starts with 0)

## Farming Zones
### Pond

* Contains fly

* $fly farming rate is dependant on Strength level. 

* Farming formula is ( 1 + Strength/5 ) * hour * level

### Stream

* Contains fly

* $fly farming rate is dependant on Agility level.

* Farming formula is ( 1 + Agility/5) * hour * level

### Swamp

* Contains fly

* $fly farming rate is dependant on Vitality level.

* Farming formula is ( 1 + Vitality/5 ) * hour * level

### River

* Contains fly

* Requires Intelligence > 5, Strength > 5

* $fly farming rate is dependant on Intelligence & Strength .

* Farming formula is ( 1 + Strength/5 + Intelligence/5 ) * hour * level

### Forest

* Contains fly

* $fly farming is dependant on Agility  >  5,  Vitality > 5 , Intelligence > 5 . 

* Farming formula is (1 + Agility/5+ Vitality/5 + Intelligence/5) * hour * level

More adventures can be added so the smart contract should be designed in a way which makes it extendable.

## $fly Token
$fly is an erc20 token without a supply capacity, since its only usecase is burning it to gain levels, being it inflationary can be handled. We can allocate a team budget for the token and linear vest it over a year. If project gets a traction, it can be a nice revenue source.

## Leveling up
Hoppers have to consume $fly an erc20 token to be able to gain experience and level up. Levelling up may or may not have effect on the attributes such as str, agi, vit, int (TO BE DECIDED).

Experience required to level up should get progressively harder, this acts as a sink for the $fly supply and keep the price in check.

## Breeding
We can release the hoppers into a lake and depending on the Fertility value, hopper can return with a tadpole which can hatch into a gen2 hopper. This can be implemented in the future as it is not crucial for the execution.


## Notes

* Multiplier of level can be increased for farming to incentivize people consuming `$fly`.
* Levelling up doesnt increase the attributes for the sake of simplicity, open for discussion.
* Fertility attribute can be used for a secondary game right off the bat, open for suggestions.
* Experience required to level up should be calculated algorithmically.
* More Adventures can be added before the game release also feel free to adjust the token issuance ratios.
