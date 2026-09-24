class_name BaseballPlayerType
extends Resource

## What kind of player somebody is. A type sets the stats a level one is bought
## with and owns the passive that grows every time players are merged into it. A
## passive either quickens the stats a level puts on, makes more of a snack, works on
## the rest of the team, or reaches the other team once the ball is in play.

@export var type_name: String = "Baseball Player"
## The round this kind starts turning up in the shop.
@export_range(1, 20) var from_round: int = 1
## Stats a level one of this type starts with.
@export_range(0, 99) var base_strength: int = 1
@export_range(0, 99) var base_dexterity: int = 1
## The passive in words, one line per level, for the shop to show under the name.
## Short: a card is read at a glance. A kind with fewer lines than levels reads its
## last one from then on.
@export var passives: PackedStringArray = []
## What this kind puts on over and above the level everybody gets, growing by this
## much for every level it has taken: one of these makes a level two worth +2/+2 and
## a level three +3/+3.
@export_range(0, 5) var strength_growth: int = 0
@export_range(0, 5) var dexterity_growth: int = 0
## What this kind adds to a snack that feeds this stat: its level, times this. One
## of these turns a one-point snack into two at level one and three at level two.
@export_range(0, 3) var strength_per_food_level: int = 0
@export_range(0, 3) var dexterity_per_food_level: int = 0
## What this kind hands every teammate when the shop closes: its level, times this.
@export_range(0, 3) var coaching: int = 0
## What this kind hands every teammate on its way out of the team: its level, times
## this. A kind bought to be sold is bought on this.
@export_range(0, 3) var severance: int = 0
## How long the fielders stand and stare when one of these puts the ball in play:
## its level, times this many seconds.
@export_range(0.0, 1.0, 0.05) var freeze_per_level: float = 0.0
## What a frozen field is worth to a kind at home on one. A fielder of one skates
## instead of standing still, at their top speed times one plus this per level.
@export_range(0.0, 1.0, 0.05) var frozen_speed_per_level: float = 0.0
## What this kind covers ground at whatever the weather: their top speed times one
## plus this per level. A kind that drives to the ball is bought on this.
@export_range(0.0, 1.0, 0.05) var speed_per_level: float = 0.0
## The share of catches this kind drops on top of the ones their hands lose. It is
## what a kind that arrives too fast to stop pays for the ride.
@export_range(0.0, 1.0, 0.05) var fumble_chance: float = 0.0


## A fresh level one of this type. The type itself is shared, never copied: two
## players count as the same kind by pointing at the same one.
## What this kind does at [param level], in the few words a card has room for.
func passive_for(level: int) -> String:
	if passives.is_empty():
		return ""
	return passives[clampi(level - 1, 0, passives.size() - 1)]


func recruit() -> BaseballPlayerData:
	var player := BaseballPlayerData.new()
	player.type = self
	player.player_name = type_name
	player.strength = base_strength
	player.dexterity = base_dexterity
	return player
