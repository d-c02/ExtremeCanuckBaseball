class_name Buyable
extends Area3D

## Something the player can pick up and drop onto a [BuyTarget] to spend money.
##
## The base class only knows how to be dragged and returned. Subclasses decide
## which targets they fit and what buying them changes, so a buyable can sign a
## player, upgrade one player, or apply to a whole team without new drag code.

signal picked_up
signal returned
signal purchased(target: BuyTarget)

## Physics layer the shop raycasts to find buyables under the cursor.
const LAYER := 1
## How far the buyable floats above the cursor plane while held.
const LIFT := 0.2
const RETURN_TIME := 0.18

@export var display_name: String = "Buyable"
@export var cost: int = 0
## Keep the buyable on its podium after a purchase instead of removing it.
@export var restocks: bool = false

var dragging: bool = false
var rest_position := Vector3.ZERO

var _tween: Tween


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	rest_position = position
	refresh()


## Virtual. True when this buyable has something to do with [param target].
func fits(_target: BuyTarget) -> bool:
	return false


## Virtual. Change the target. Returning false cancels the sale and charges nothing.
func apply_to(_target: BuyTarget) -> bool:
	return false


## Virtual. What the shop charges for this drop. A negative price pays the player.
func price(_target: BuyTarget) -> int:
	return cost


## Virtual. Redraw labels and meshes after the data behind the buyable changed.
func refresh() -> void:
	pass


func can_grab() -> bool:
	return not dragging and is_inside_tree()


func grab() -> void:
	if _tween != null:
		_tween.kill()
	dragging = true
	picked_up.emit()


## Follow the cursor. [param point] is the drag plane point under the mouse.
func drag_to(point: Vector3) -> void:
	global_position = point + Vector3.UP * LIFT


func return_home() -> void:
	dragging = false
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(self, "position", rest_position, RETURN_TIME)
	_tween.tween_callback(returned.emit)


## Called by the shop once a sale went through and the money was taken.
func consume(target: BuyTarget) -> void:
	purchased.emit(target)
	if restocks:
		return_home()
		return
	queue_free()
