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
const RETURN_TIME := 0.18
## Radians of lean per world unit per second the cursor is yanked sideways.
const SWING_PER_SPEED := 0.025
## How far the body is allowed to trail behind the cursor.
const SWING_LIMIT := 0.6
## Spring that carries the body toward its lean, loose enough to overshoot a little.
const SWING_STIFFNESS := 90.0
const SWING_DAMPING := 9.0

@export var display_name: String = "Buyable"
@export var cost: int = 0
## Keep the buyable on its podium after a purchase instead of removing it.
@export var restocks: bool = false

var dragging: bool = false
var rest_position := Vector3.ZERO
## The point the cursor grips, at the top of the body. Subclasses with something to
## dangle set it, along with the part that has to keep facing the camera.
var hang: Node3D
var swing_body: Node3D
## Labels standing at the body's feet, STR on the left and DEX on the right.
var stat_labels: Array[Label3D] = []

## How far the body is leaning, in radians, while it hangs from the cursor.
var swing: float = 0.0
var _tween: Tween
var _swing_speed: float = 0.0
var _last_x: float = 0.0


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	rest_position = position
	_last_x = global_position.x
	refresh()


## Keep the body facing the camera and let it swing under the cursor.
func _process(delta: float) -> void:
	_face_camera()
	if delta <= 0.0 or hang == null:
		return
	var drift := (global_position.x - _last_x) / delta
	_last_x = global_position.x
	var lean := 0.0
	if dragging:
		# Hanging by the head, the body trails whichever way the cursor is yanked.
		lean = clampf(-drift * SWING_PER_SPEED, -SWING_LIMIT, SWING_LIMIT)
	var pull := (lean - swing) * SWING_STIFFNESS - _swing_speed * SWING_DAMPING
	_swing_speed += pull * delta
	swing += _swing_speed * delta
	hang.global_basis = Basis(_view_axis(), swing)


## How far above its feet the cursor grips the buyable.
func grip_height() -> float:
	return hang.position.y if hang != null else 0.0


## Virtual. True when this buyable has something to do with [param target].
func fits(_target: BuyTarget) -> bool:
	return false


## Virtual. Change the target. Returning false cancels the sale and charges nothing.
func apply_to(_target: BuyTarget) -> bool:
	return false


## Virtual. Show or hide whatever only matters while the cursor is on this.
func set_hovered(_on: bool) -> void:
	pass


## Virtual. What the shop charges for this drop. A negative price pays the player.
func price(_target: BuyTarget) -> int:
	return cost


## Virtual. Redraw labels and meshes after the data behind the buyable changed.
func refresh() -> void:
	pass


## Stand the two numbers a player is bought on at their feet. An empty buyable
## shows nothing.
func show_stats(data: BaseballPlayerData) -> void:
	var texts := data.stat_texts() if data != null else PackedStringArray(["", ""])
	for index in stat_labels.size():
		stat_labels[index].text = texts[index]


func can_grab() -> bool:
	return not dragging and is_inside_tree()


func grab() -> void:
	if _tween != null:
		_tween.kill()
	dragging = true
	picked_up.emit()


## Hang the body from [param point], the drag plane spot under the cursor.
func drag_to(point: Vector3) -> void:
	global_position = point - Vector3.UP * grip_height()


func return_home() -> void:
	dragging = false
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(self, "position", rest_position, RETURN_TIME)
	_tween.tween_callback(returned.emit)


## Virtual. True when the trade uses the buyable up, so it leaves the board. A drop
## that only moves it somewhere else says false and slides home to its new spot.
func spent_on(_target: BuyTarget) -> bool:
	return not restocks


## Called by the shop once a trade went through and the money moved.
func consume(target: BuyTarget) -> void:
	purchased.emit(target)
	if spent_on(target):
		queue_free()
		return
	return_home()


## The axis pointing back at the camera: the body swings and rolls around it, so a
## tilt reads the same on screen whatever the camera is doing.
func _view_axis() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	return camera.global_basis.z if camera != null else Vector3.BACK


## Stand the body square to the camera by hand, since a billboard would throw the
## swing away.
func _face_camera() -> void:
	if swing_body == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		swing_body.basis = camera.global_basis
