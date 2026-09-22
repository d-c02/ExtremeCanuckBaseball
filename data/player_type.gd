class_name BaseballPlayerType
extends Resource

## What kind of player somebody is. A type sets the stats a level one is bought
## with and owns the passive that grows every time players are merged into it. The
## only passive written so far is a flat stat gain per level, so a type that wants
## to do something else will need more than the two numbers here.

@export var type_name: String = "Baseball Player"
## The round this kind starts turning up in the shop.
@export_range(1, 20) var from_round: int = 1
## Stats a level one of this type starts with.
@export_range(0, 99) var base_strength: int = 1
@export_range(0, 99) var base_dexterity: int = 1
## The passive in words, for the shop to show under the name.
@export var passive: String = ""
## What the passive adds to each stat for every level above the first.
@export_range(0, 20) var strength_per_level: int = 2
@export_range(0, 20) var dexterity_per_level: int = 2


## A fresh level one of this type. The type itself is shared, never copied: two
## players count as the same kind by pointing at the same one.
func recruit() -> BaseballPlayerData:
	var player := BaseballPlayerData.new()
	player.type = self
	player.player_name = type_name
	player.strength = base_strength
	player.dexterity = base_dexterity
	return player
