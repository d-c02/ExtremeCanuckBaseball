class_name BaseballPlayerData
extends Resource

## A player is bought with two stats. Strength covers batting, pitching and
## passing; dexterity covers catching, running and the fielding range that
## running buys. Everything the simulation tunes is derived from the pair, so a
## roster only ever authors two numbers per player.

enum IdleBehavior { STILL, PACE }

## Both stats run from 0 to this cap.
const MAX_STAT: int = 99
## Levels run 1 to 3. Merging a player of the same level is a level up on its own;
## one level below counts half, so two of those do it.
const MAX_LEVEL: int = 3
const STEPS_PER_LEVEL: int = 2
## What every level up puts on, whatever kind somebody is.
const LEVEL_GAIN: int = 1
## What the shop keeps when it buys a player back.
const SELL_LOSS: int = 2
## What the cheapest and the dearest player cost in the shop.
const MIN_VALUE: int = 2
const MAX_VALUE: int = 9

@export var player_name: String = "Player"
## What kind of player this is. It sets the stats they start with and the passive
## that grows as they level. Shared, never copied, so merging can tell two players
## of a kind apart from two that only look alike.
@export var type: BaseballPlayerType
@export_range(1, 3) var level: int = 1
## Half-levels merged in since the last level up.
@export var steps: int = 0
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


## Shop price for this player: what the pair of stats is worth, doubled for every
## level, because a level costs the players that went into it.
func value() -> int:
	var average := (strength_fraction() + dexterity_fraction()) / 2.0
	return int(roundf(lerpf(MIN_VALUE, MAX_VALUE, average))) * copies()


## How many level ones stand behind this player.
func copies() -> int:
	return 1 << (level - 1)


## What the sell spot pays for them.
func sell_price() -> int:
	return maxi(1, value() - SELL_LOSS)


## Whether [param other] can be merged into this player: the same kind, either the
## same level or one below, and room left to grow.
func can_absorb(other: BaseballPlayerData) -> bool:
	if other == null or other == self or type == null or other.type != type:
		return false
	if level >= MAX_LEVEL:
		return false
	return other.level == level or other.level == level - 1


## Merge [param other] in and report whether that took a level. Two of this level
## is a level up on its own; one below counts half, so the second one does it.
func absorb(other: BaseballPlayerData) -> bool:
	if not can_absorb(other):
		return false
	steps += STEPS_PER_LEVEL if other.level == level else 1
	if steps < STEPS_PER_LEVEL:
		return false
	steps -= STEPS_PER_LEVEL
	return gain_level()


## Eat a snack: the point goes on for good, and a kind whose passive is making the
## most of that sort of food adds a point of it for every level it has.
func eat(food: BaseballFoodType) -> void:
	strength = mini(strength + _bite(food.strength_gain, _food_bonus(true)), MAX_STAT)
	dexterity = mini(dexterity + _bite(food.dexterity_gain, _food_bonus(false)), MAX_STAT)


## What a snack is really worth here. A snack that feeds nothing of a stat feeds
## nothing extra of it either, whatever the passive.
func _bite(gain: int, per_level: int) -> int:
	return (gain + level * per_level) if gain > 0 else 0


func _food_bonus(for_strength: bool) -> int:
	if type == null:
		return 0
	return type.strength_per_food_level if for_strength else type.dexterity_per_food_level


## Take a level with nobody merged in, for rolling a team that already has some.
## Everybody puts on [constant LEVEL_GAIN] of each stat; a kind with growth in it
## puts on that much more again for every level it has taken.
func gain_level() -> bool:
	if level >= MAX_LEVEL:
		return false
	level += 1
	var taken := level - 1
	var strength_growth := type.strength_growth if type != null else 0
	var dexterity_growth := type.dexterity_growth if type != null else 0
	strength = mini(strength + LEVEL_GAIN + taken * strength_growth, MAX_STAT)
	dexterity = mini(dexterity + LEVEL_GAIN + taken * dexterity_growth, MAX_STAT)
	return true


## What this player hands each teammate when the shop closes, for a kind whose
## passive is coaching the rest of them.
func coaching_gain() -> int:
	return level * type.coaching if type != null else 0


## How long the fielders lose when this player puts the ball in play, for a kind
## whose passive reaches across the diamond.
func freeze_gain() -> float:
	return level * type.freeze_per_level if type != null else 0.0


## What a frozen field does for this player instead of holding them: the share of
## their top speed it adds, nothing at all for a kind with no skates.
func skating_gain() -> float:
	return level * type.frozen_speed_per_level if type != null else 0.0


## The badge that stands over a player: what level they are, and a half when they
## are one merge short of the next.
func level_text() -> String:
	return "Lv %d%s" % [level, "½" if steps > 0 else ""]


## The two lines the shop shows while the cursor is on a player: what kind they
## are, and what their passive does. The level stands over them either way.
func shop_card() -> String:
	if type == null:
		return player_name
	return "%s\n%s" % [type.type_name, type.passive]


## One stat as its label reads it. They read bare: the labels beside a player are
## coloured and placed to say which is which, so spelling it out again only adds
## clutter. Live values, such as a tiring arm, are worded here too.
static func stat_text(value: int) -> String:
	return "%d" % value


## The two numbers a player is bought on, strength first, dexterity second.
func stat_texts() -> PackedStringArray:
	return PackedStringArray([stat_text(strength), stat_text(dexterity)])
