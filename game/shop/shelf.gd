class_name BaseballShelf

## What a shop visit puts out: the kinds it can roll, the snacks it stocks, and how
## many podiums it fills with each. A rolled opponent shops against one of these, so
## it works from the same shelf the player does and has to pay for a new one once it
## has picked this one clean.

var types: Array[BaseballPlayerType] = []
var foods: Array[BaseballFoodType] = []
var player_podiums: int = 4
var snack_podiums: int = 2
var players: Array[BaseballPlayerData] = []
var snacks: Array[BaseballFoodType] = []


## Fill every podium again. [param taken] collects the names already handed out, so
## one team never fields two of the same.
func restock(rng: RandomNumberGenerator, taken: PackedStringArray) -> void:
	players.clear()
	snacks.clear()
	for podium in player_podiums:
		var rolled := BaseballRecruit.roll(rng, types, taken)
		if rolled == null:
			break
		taken.append(rolled.player_name)
		players.append(rolled)
	if foods.is_empty():
		return
	for podium in snack_podiums:
		snacks.append(foods[rng.randi() % foods.size()])
