class_name TeamSlot
extends BuyTarget

## One spot in the batting order. Empty slots take player buyables; filled slots
## hold a [SignedPlayer] that can be dragged back out, and are where buyables
## aimed at a single player land.

signal filled(player: BaseballPlayerData)
signal cleared

const SIGNED_PLAYER := preload("res://game/shop/signed_player.tscn")

## Fielding role written into the roster when the slot is filled.
@export var role: String = "P"
@export var slot_index: int = 0

var player: BaseballPlayerData
var occupant: SignedPlayer
var role_label: Label3D
var name_label: Label3D


func _ready() -> void:
	role_label = $Role
	name_label = $Name
	super()


func is_empty() -> bool:
	return player == null


## Stand a player in the slot. [param value] is what selling them pays back.
func fill(new_player: BaseballPlayerData, value: int) -> void:
	player = new_player
	_write_roster()
	occupant = SIGNED_PLAYER.instantiate()
	occupant.slot = self
	occupant.player = new_player
	occupant.sell_value = value
	add_child(occupant)
	refresh()
	filled.emit(new_player)


## Empty the slot. The player being sold frees their own node.
func clear() -> void:
	player = null
	occupant = null
	_write_roster()
	refresh()
	cleared.emit()


func refresh() -> void:
	if role_label == null:
		return
	role_label.text = role
	name_label.text = player.player_name if player != null else "open"
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
