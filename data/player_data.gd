class_name BaseballPlayerData
extends Resource

## A player is bought with two stats. Strength covers batting, pitching and
## passing; dexterity covers catching, running and the fielding range that
## running buys. Everything the simulation tunes is derived from the pair, so a
## roster only ever authors two numbers per player.

enum IdleBehavior { STILL, PACE }

## Both stats run from 0 to this cap.
const MAX_STAT: int = 99

@export var player_name: String = "Player"
## Batting power, pitching stamina and throwing speed.
@export_range(0, 99) var strength: int = 50
## Catching, running speed and the ground a fielder can cover.
@export_range(0, 99) var dexterity: int = 50
@export_range(0.0, 1.0) var reaction_time: float = 0.25
@export_range(0.0, 1.0) var anticipation: float = 0.7
@export var idle_behavior: IdleBehavior = IdleBehavior.STILL

## Running: top speed in simulation units per second.
var speed: float:
	get:
		return lerpf(90.0, 190.0, dexterity_fraction())

## Running: how fast that top speed is reached or shed.
var acceleration: float:
	get:
		return lerpf(260.0, 460.0, dexterity_fraction())

## Catching: the share of reachable balls collected without a bobble.
var catching: float:
	get:
		return lerpf(0.66, 0.98, dexterity_fraction())

## Passing: throw speed in simulation units per second.
var throwing_speed: float:
	get:
		return lerpf(240.0, 480.0, strength_fraction())

## Batting: batted-ball speed before contact quality scales it.
var batting_power: float:
	get:
		return lerpf(200.0, 380.0, strength_fraction())


func strength_fraction() -> float:
	return clampf(float(strength) / float(MAX_STAT), 0.0, 1.0)


func dexterity_fraction() -> float:
	return clampf(float(dexterity) / float(MAX_STAT), 0.0, 1.0)


## The two numbers a player is bought on, worded as the labels beside them read:
## STR first, DEX second.
func stat_texts() -> PackedStringArray:
	return PackedStringArray(["STR %d" % strength, "DEX %d" % dexterity])


## Hover caption for the buy screen: the name above the same two numbers.
func stat_line() -> String:
	var texts := stat_texts()
	return "%s\n%s  %s" % [player_name, texts[0], texts[1]]
