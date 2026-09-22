class_name BaseballPlayerData
extends Resource

## A player is bought with two stats. Strength covers batting, pitching and
## passing; dexterity covers catching, running and the fielding range that
## running buys. Everything the simulation tunes is derived from the pair, so a
## roster only ever authors two numbers per player.

enum IdleBehavior { STILL, PACE }

## Both stats run from 0 to this cap.
const MAX_STAT: int = 99
## What the cheapest and the dearest player cost in the shop.
const MIN_VALUE: int = 2
const MAX_VALUE: int = 9

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
		return lerpf(150.0, 460.0, strength_fraction())


func strength_fraction() -> float:
	return clampf(float(strength) / float(MAX_STAT), 0.0, 1.0)


func dexterity_fraction() -> float:
	return clampf(float(dexterity) / float(MAX_STAT), 0.0, 1.0)


## Shop price for this pair of stats. Worth is what ties the shop, the sell spot and
## a rolled opponent together, so it lives with the stats it is read from.
func value() -> int:
	var average := (strength_fraction() + dexterity_fraction()) / 2.0
	return int(roundf(lerpf(MIN_VALUE, MAX_VALUE, average)))


## The two numbers a player is bought on, strength first, dexterity second. They
## read bare: the labels beside a player are coloured and placed to say which is
## which, so spelling it out again only adds clutter.
func stat_texts() -> PackedStringArray:
	return PackedStringArray(["%d" % strength, "%d" % dexterity])
