class_name PlayerSlot
extends Buyable

## A player standing on a podium, for sale. Dropping one on an empty [TeamSlot]
## signs a copy into that spot in the batting order; dropping one on a player of
## the same kind merges into them instead. The podium shows the asking price, and
## the kind and its passive only show while the cursor is on the player.

@export var player: BaseballPlayerData

var sprite: Sprite3D
var name_label: Label3D


func _ready() -> void:
	sprite = $Hang/Sprite
	hang = $Hang
	swing_body = sprite
	name_label = $Name
	stat_labels = [$Hang/Strength, $Hang/Dexterity]
	level_label = $Hang/Level
	super()


func fits(target: BuyTarget) -> bool:
	var slot := target as TeamSlot
	if player == null or slot == null:
		return false
	return slot.is_empty() or slot.player.can_absorb(player)


func apply_to(target: BuyTarget) -> bool:
	if not fits(target):
		return false
	var slot := target as TeamSlot
	# Sign a copy, so later level ups never reach back into the shop listing. The
	# copy is shallow on purpose: the type is shared, because it is the same kind
	# of player either way.
	if slot.is_empty():
		slot.fill(player.duplicate())
		return true
	slot.absorb(player.duplicate())
	return true


func set_hovered(on: bool) -> void:
	if name_label != null:
		name_label.visible = on


func refresh() -> void:
	if name_label == null:
		return
	if player != null:
		display_name = player.player_name
	name_label.text = player.shop_card() if player != null else display_name
	show_stats(player)
