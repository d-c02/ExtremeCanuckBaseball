class_name BuyTarget
extends Area3D

## A place a [Buyable] can be dropped.
##
## Targets carry the roster being built so a buyable can reach the team it is
## changing. [TeamSlot] is the roster-spot target; team-wide targets subclass
## this directly once a team-wide buyable exists.

## Physics layer the shop raycasts to find drop targets under the cursor.
const LAYER := 2

@export var accept_color := Color("f6d36a")
@export var reject_color := Color("d2604f")

## The team this target edits. The [Shop] assigns it to every target it owns.
var roster: BaseballTeamData
var highlight: MeshInstance3D

var _highlight_material := StandardMaterial3D.new()


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	highlight = get_node_or_null("Highlight")
	_highlight_material.roughness = 1.0
	if highlight != null:
		highlight.material_override = _highlight_material
		highlight.visible = false
	refresh()


## Virtual. Narrow what the target takes beyond the buyable's own [method Buyable.fits].
func accepts(_buyable: Buyable) -> bool:
	return true


## Virtual. Show what a drop would do while [param buyable] hovers. Null clears it.
func preview(_buyable: Buyable) -> void:
	pass


## Virtual. Redraw after a purchase changed the target.
func refresh() -> void:
	pass


## Show whether a drop here would work. [param allowed] is false for a refused drop.
func set_highlighted(on: bool, allowed: bool = true) -> void:
	if highlight == null:
		return
	highlight.visible = on
	_highlight_material.albedo_color = accept_color if allowed else reject_color
