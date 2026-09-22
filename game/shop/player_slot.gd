class_name PlayerSlot
extends Buyable

## A player standing on a podium, for sale. Dropping one on an empty [TeamSlot]
## signs a copy of their stats into that spot in the batting order. The podium
## shows the asking price; the name only shows while the cursor is on the player.

@export var player: BaseballPlayerData
## What the shop pays to take this player back once they are signed.
@export var sell_value: int = 2

var sprite: Sprite3D
var name_label: Label3D


func _ready() -> void:
	sprite = $Hang/Sprite
	hang = $Hang
	swing_body = sprite
	name_label = $Name
	stat_labels = [$Hang/Strength, $Hang/Dexterity]
	super()


func fits(target: BuyTarget) -> bool:
	var slot := target as TeamSlot
	return player != null and slot != null and slot.is_empty()


func apply_to(target: BuyTarget) -> bool:
	if not fits(target):
		return false
	# Sign a copy so later upgrades never reach back into the shop listing.
	(target as TeamSlot).fill(player.duplicate(true), sell_value)
	return true


func set_hovered(on: bool) -> void:
	if name_label != null:
		name_label.visible = on


func refresh() -> void:
	if name_label == null:
		return
	if player != null:
		display_name = player.player_name
	name_label.text = player.player_name if player != null else display_name
	show_stats(player)
