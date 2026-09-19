class_name Shop
extends Node3D

## Drives click-and-drag trading: picks up a [Buyable] under the cursor, drags it
## along a level plane, highlights the [BuyTarget] beneath it and resolves the
## trade on release. Refused drops slide back where they came from.

signal funds_changed(funds: int)
signal traded(buyable: Buyable, target: BuyTarget)

const RAY_LENGTH := 1000.0

## Roster the shop starts from. It is duplicated, so trading never edits the file.
@export var team: BaseballTeamData
@export var funds: int = 12

var roster: BaseballTeamData
var held: Buyable
var hovered: BuyTarget

var _grab_height: float = 0.0
var _hover_allowed: bool = false


func _ready() -> void:
	roster = team.duplicate(true) if team != null else BaseballTeamData.new()
	for target in _targets():
		target.roster = roster
		target.refresh()
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		if held != null:
			_drag(motion.position)
		return
	var button := event as InputEventMouseButton
	if button == null:
		return
	if button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_grab(button.position)
		else:
			_release(button.position)
	elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed and held != null:
		_cancel()


## True when the shop would let a buyable land on a target right now.
func can_trade(buyable: Buyable, target: BuyTarget) -> bool:
	if buyable == null or target == null:
		return false
	if not buyable.fits(target) or not target.accepts(buyable):
		return false
	return buyable.price(target) <= funds


## Move a buyable onto a target and settle the money, for tests and scripted trades.
func trade(buyable: Buyable, target: BuyTarget) -> bool:
	if not can_trade(buyable, target) or not buyable.apply_to(target):
		return false
	funds -= buyable.price(target)
	target.refresh()
	buyable.consume(target)
	funds_changed.emit(funds)
	traded.emit(buyable, target)
	_update_hud()
	return true
func _grab(screen: Vector2) -> void:
	var buyable := _pick(screen, Buyable.LAYER) as Buyable
	if buyable == null or not buyable.can_grab():
		return
	held = buyable
	_grab_height = buyable.global_position.y
	held.grab()
	_drag(screen)


func _drag(screen: Vector2) -> void:
	held.drag_to(_plane_point(screen))
	_set_hovered(_pick(screen, BuyTarget.LAYER) as BuyTarget)


func _release(screen: Vector2) -> void:
	if held == null:
		return
	var buyable := held
	var target := hovered
	var allowed := _hover_allowed
	_set_hovered(null)
	held = null
	if allowed and trade(buyable, target):
		return
	buyable.return_home()


func _cancel() -> void:
	var buyable := held
	held = null
	_set_hovered(null)
	buyable.return_home()


func _set_hovered(target: BuyTarget) -> void:
	if hovered != null and hovered != target:
		hovered.set_highlighted(false)
		hovered.preview(null)
	hovered = target
	_hover_allowed = can_trade(held, target)
	if hovered != null:
		hovered.set_highlighted(true, _hover_allowed)
		hovered.preview(held)


func _pick(screen: Vector2, layer: int) -> Node:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var origin := camera.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + camera.project_ray_normal(screen) * RAY_LENGTH
	)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = layer
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider") as Node


func _plane_point(screen: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return held.global_position
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	# A cursor ray running level with the drag plane leaves the buyable where it is.
	if absf(direction.y) < 0.001:
		return held.global_position
	return origin + direction * ((_grab_height - origin.y) / direction.y)


func _targets() -> Array[BuyTarget]:
	var found: Array[BuyTarget] = []
	for node in find_children("*", "BuyTarget", true, false):
		found.append(node)
	return found


func _update_hud() -> void:
	var label := get_node_or_null("HUD/Funds") as Label
	if label != null:
		label.text = "Funds  $%d" % funds
