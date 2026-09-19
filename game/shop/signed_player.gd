class_name SignedPlayer
extends Buyable

## A player already on the roster, standing in their [TeamSlot]. Dragging them to
## a [SellSpot] sells them back and empties the slot they came from.

var slot: TeamSlot
var player: BaseballPlayerData
var sell_value: int = 0
var sprite: Sprite3D


func _ready() -> void:
	sprite = $Hang/Sprite
	hang = $Hang
	swing_body = sprite
	super()


func fits(target: BuyTarget) -> bool:
	return slot != null and target is SellSpot


func price(_target: BuyTarget) -> int:
	return -sell_value


func apply_to(target: BuyTarget) -> bool:
	if not fits(target):
		return false
	slot.clear()
	return true


func refresh() -> void:
	if sprite == null:
		return
	if player != null:
		display_name = player.player_name
	if slot != null and slot.roster != null:
		sprite.modulate = slot.roster.color
