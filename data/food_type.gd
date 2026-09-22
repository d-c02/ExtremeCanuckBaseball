class_name BaseballFoodType
extends Resource

## Something a player eats for a point of a stat. The shop sells it on the podiums
## beside the players, and feeding somebody is for good: the point goes onto their
## stats and the snack is gone.

@export var food_name: String = "Snack"
@export_range(0, 9) var strength_gain: int = 0
@export_range(0, 9) var dexterity_gain: int = 0
@export var price: int = 2
## What the snack is made of, since the art is a placeholder box.
@export var color: Color = Color.WHITE


## The gain, bare, for the label that stands on the snack. Its colour says which
## stat it feeds, the same way the numbers at a player's feet do.
func gain_text() -> String:
	if strength_gain > 0 and dexterity_gain > 0:
		return "+%d/+%d" % [strength_gain, dexterity_gain]
	return "+%d" % maxi(strength_gain, dexterity_gain)


## The colour of the stat it feeds, matching the numbers at a player's feet.
func gain_color() -> Color:
	if dexterity_gain > strength_gain:
		return Color(0.56, 0.86, 0.98)
	return Color(0.98, 0.7, 0.38)


## The two lines the shop shows while the cursor is on a snack.
func card() -> String:
	var gains := PackedStringArray()
	if strength_gain > 0:
		gains.append("+%d strength" % strength_gain)
	if dexterity_gain > 0:
		gains.append("+%d dexterity" % dexterity_gain)
	return "%s\n%s" % [food_name, ", ".join(gains)]
