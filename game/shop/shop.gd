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
## How far the drawn park and the fielding spots pull in toward home plate. The
## roster keeps its real match positions; only the buy screen is condensed.
@export_range(0.3, 1.0) var park_scale: float = 0.6

var roster: BaseballTeamData
var park: BaseballBallpark
var held: Buyable
var hovered: BuyTarget
var pointed: Buyable

var _grab_height: float = 0.0
var _hover_allowed: bool = false


func _ready() -> void:
	roster = team.duplicate(true) if team != null else BaseballTeamData.new()
	park = get_node_or_null("Field") as BaseballBallpark
	_build_park()
	for target in _targets():
		target.roster = roster
		target.refresh()
	_place_slots()
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_point(motion.position)
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
	_grab_height = buyable.global_position.y + buyable.grip_height()
	held.grab()
	_point(screen)


## Follow the cursor: name whatever it is over, carry the held buyable, and while
## one is held, judge the drop onto the target underneath it.
func _point(screen: Vector2) -> void:
	if held != null:
		held.drag_to(_plane_point(screen))
	_set_hovered(_pick(screen, BuyTarget.LAYER) as BuyTarget)
	var under := held
	if under == null:
		under = _pick(screen, Buyable.LAYER) as Buyable
	_set_pointed(under)


func _release(screen: Vector2) -> void:
	if held == null:
		return
	var buyable := held
	var target := hovered
	var allowed := _hover_allowed
	held = null
	if not (allowed and trade(buyable, target)):
		buyable.return_home()
	_point(screen)


func _cancel() -> void:
	var buyable := held
	held = null
	_set_hovered(null)
	_set_pointed(null)
	buyable.return_home()


func _set_hovered(target: BuyTarget) -> void:
	if hovered != null:
		if hovered != target:
			hovered.set_hovered(false)
		hovered.set_highlighted(false)
		hovered.preview(null)
	hovered = target
	_hover_allowed = can_trade(held, target)
	if hovered == null:
		return
	hovered.set_hovered(true)
	if held != null:
		hovered.set_highlighted(true, _hover_allowed)
		hovered.preview(held)


func _set_pointed(buyable: Buyable) -> void:
	if pointed == buyable:
		return
	if is_instance_valid(pointed):
		pointed.set_hovered(false)
	pointed = buyable
	if pointed != null:
		pointed.set_hovered(true)


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


## Draw the ballpark the shop stands on, when the scene has one.
func _build_park() -> void:
	var view := get_node_or_null("FieldView") as BaseballFieldView
	if park == null or view == null:
		return
	view.build(park)
	# Shrink the drawn park around home so the whole thing reads at shop range.
	view.scale = Vector3.ONE * park_scale
	view.position = _home_point() * (1.0 - park_scale)


func _home_point() -> Vector3:
	return BaseballWorld.world_position(park.home.position) if park != null else Vector3.ZERO


## Stand each slot where that fielder plays, pulled in by the same [member
## park_scale] as the park. Slots the roster has no position for keep the spot they
## were placed at in the scene.
func _place_slots() -> void:
	var home := _home_point()
	for target in _targets():
		var slot := target as TeamSlot
		if slot == null or slot.slot_index >= roster.field_positions.size():
			continue
		var spot := BaseballWorld.world_position(roster.field_positions[slot.slot_index])
		slot.position = home + (spot - home) * park_scale
