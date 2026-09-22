class_name TeamSlot
extends BuyTarget

## One spot in the batting order. Empty slots take player buyables; filled slots
## hold a [SignedPlayer] that can be dragged out to another slot or the sell spot,
## and are where buyables aimed at a single player land.

signal filled(player: BaseballPlayerData)
signal cleared

const SIGNED_PLAYER := preload("res://game/shop/signed_player.tscn")

## Fielding role written into the roster. The slot's place on the field shows it,
## so nothing labels it.
@export var role: String = "P"
@export var slot_index: int = 0

var player: BaseballPlayerData
var occupant: SignedPlayer
var name_label: Label3D
var order_label: Label3D


func _ready() -> void:
	name_label = $Name
	order_label = $Order
	super()


func is_empty() -> bool:
	return player == null


## Stand a player in the slot. [param value] is what selling them pays back.
func fill(new_player: BaseballPlayerData) -> void:
	player = new_player
	_write_roster()
	occupant = SIGNED_PLAYER.instantiate()
	occupant.slot = self
	occupant.player = new_player
	add_child(occupant)
	refresh()
	filled.emit(new_player)


## Feed the player standing here, for good. Returns false when nobody is home.
func feed(food: BaseballFoodType) -> bool:
	if player == null or food == null:
		return false
	player.strength = mini(player.strength + food.strength_gain, BaseballPlayerData.MAX_STAT)
	player.dexterity = mini(player.dexterity + food.dexterity_gain, BaseballPlayerData.MAX_STAT)
	_write_roster()
	refresh()
	return true


## Merge a player into the one standing here, levelling them up when enough of
## their kind have gone in. Returns false when they are no match.
func absorb(incoming: BaseballPlayerData) -> bool:
	if player == null or not player.can_absorb(incoming):
		return false
	player.absorb(incoming)
	_write_roster()
	refresh()
	return true


## Trade players with [param other]. Either side may be empty, so this covers both
## moving a player to an open spot and swapping two of them. Each player takes the
## slot's fielding role and its spot in the batting order.
func swap_with(other: TeamSlot) -> void:
	var mine := occupant
	var theirs := other.occupant
	var my_player := player
	player = other.player
	other.player = my_player
	occupant = theirs
	other.occupant = mine
	if mine != null:
		mine.slot = other
		mine.reparent(other)
	if theirs != null:
		theirs.slot = self
		theirs.reparent(self)
		theirs.return_home()
	_write_roster()
	other._write_roster()
	refresh()
	other.refresh()


## Empty the slot. The player being sold frees their own node.
func clear() -> void:
	player = null
	occupant = null
	_write_roster()
	refresh()
	cleared.emit()


## Show what number this spot bats at, for the lineup view.
func show_order(on: bool) -> void:
	if order_label == null:
		return
	order_label.text = "%d" % (slot_index + 1)
	order_label.visible = on


func set_hovered(on: bool) -> void:
	if name_label != null:
		name_label.visible = on


func refresh() -> void:
	if name_label == null:
		return
	name_label.text = player.shop_card() if player != null else "open"
	if occupant != null:
		occupant.refresh()


## Keep the roster Resource in step with the slot. Field positions still come
## from the match scene, so a shop roster is not match-ready on its own.
func _write_roster() -> void:
	if roster == null:
		return
	while roster.players.size() <= slot_index:
		roster.players.append(null)
	while roster.field_roles.size() <= slot_index:
		roster.field_roles.append("")
	roster.players[slot_index] = player
	roster.field_roles[slot_index] = role
