class_name SignedPlayer
extends Buyable

## A player already on the roster, standing in their [TeamSlot]. Drag them to a
## [SellSpot] to sell them back, or to another slot to move them there: an open
## slot takes them and a taken one trades players with the slot they came from.
## Moving is free, and a player takes over the batting order spot of the slot they
## land in, because a slot is one place in the order as well as one fielding spot.

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
	if slot == null:
		return false
	if target is SellSpot:
		return true
	var other := target as TeamSlot
	return other != null and other != slot


func price(target: BuyTarget) -> int:
	return -sell_value if target is SellSpot else 0


func spent_on(target: BuyTarget) -> bool:
	return target is SellSpot


func apply_to(target: BuyTarget) -> bool:
	if not fits(target):
		return false
	if target is SellSpot:
		slot.clear()
		return true
	slot.swap_with(target as TeamSlot)
	return true


func refresh() -> void:
	if sprite == null:
		return
	if player != null:
		display_name = player.player_name
	if slot != null and slot.roster != null:
		sprite.modulate = slot.roster.color
