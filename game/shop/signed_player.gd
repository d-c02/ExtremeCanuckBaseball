class_name SignedPlayer
extends Buyable

## A player already on the roster, standing in their [TeamSlot]. Drag them to a
## [SellSpot] to sell them back, or to another slot: a player of the same kind
## takes them in and levels up, an empty slot takes them as they are, and anybody
## else trades places with them. Moving is free, and a player takes over the
## batting order spot of the slot they land in, because a slot is one place in the
## order as well as one fielding spot.

var slot: TeamSlot
var player: BaseballPlayerData
var sprite: Sprite3D


func _ready() -> void:
	sprite = $Hang/Sprite
	hang = $Hang
	swing_body = sprite
	stat_labels = [$Hang/Strength, $Hang/Dexterity]
	level_label = $Hang/Level
	super()


func fits(target: BuyTarget) -> bool:
	if slot == null:
		return false
	if target is SellSpot:
		return true
	var other := target as TeamSlot
	return other != null and other != slot


func price(target: BuyTarget) -> int:
	return -player.sell_price() if target is SellSpot else 0


func spent_on(target: BuyTarget) -> bool:
	if target is SellSpot:
		return true
	# A merge uses the carried player up; a move only puts them somewhere else.
	return merges_into(target as TeamSlot)


func apply_to(target: BuyTarget) -> bool:
	if not fits(target):
		return false
	if target is SellSpot:
		slot.clear()
		return true
	var other := target as TeamSlot
	if merges_into(other):
		other.absorb(player)
		slot.clear()
		return true
	slot.swap_with(other)
	return true


## Whether dropping on [param other] would merge rather than move or trade.
func merges_into(other: TeamSlot) -> bool:
	return other != null and other.player != null and other.player.can_absorb(player)


func refresh() -> void:
	if sprite == null:
		return
	if player != null:
		display_name = player.player_name
	show_stats(player)
	if slot != null and slot.roster != null:
		sprite.modulate = slot.roster.color
