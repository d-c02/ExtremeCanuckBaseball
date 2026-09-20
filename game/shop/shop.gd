class_name Shop
extends Node3D

## Drives click-and-drag trading: picks up a [Buyable] under the cursor, drags it
## along a level plane, highlights the [BuyTarget] beneath it and resolves the
## trade on release. Refused drops slide back where they came from.

signal funds_changed(funds: int)
signal traded(buyable: Buyable, target: BuyTarget)

const RAY_LENGTH := 1000.0
## The lineup stands in a grid in front of the podiums, first hitter top left and
## reading across. Rows and columns are an even distance apart on the ground, so
## every neighbour sits the same way from its neighbours however far back it is.
const BATTING_COLUMNS := 3
const BATTING_CORNER := Vector3(-7.0, 0.0, -3.0)
const BATTING_COLUMN_STEP := 7.0
const BATTING_ROW_STEP := 6.0
const LAYOUT_TIME := 0.3

## Roster the shop starts from. It is duplicated, so trading never edits the file.
@export var team: BaseballTeamData
@export var funds: int = 12
## How far the drawn park and the fielding spots pull in toward home plate. The
## roster keeps its real match positions; only the buy screen is condensed.
@export_range(0.3, 1.0) var park_scale: float = 0.6

var roster: BaseballTeamData
## Whether the slots are lined up in batting order instead of out on the field.
var batting_view: bool = false
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
	_layout_slots(false)
	_update_order_button()
	var button := get_node_or_null("HUD/Order") as Button
	if button != null:
		button.pressed.connect(_toggle_view)
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


## Line the slots up in batting order, or send them back out to their positions.
func set_batting_view(on: bool) -> void:
	if batting_view == on:
		return
	batting_view = on
	_layout_slots(true)
	_update_order_button()


func _toggle_view() -> void:
	set_batting_view(not batting_view)


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
	var view := get_node_or_null("FieldView") as BaseballShopFieldView
	if park == null or view == null:
		return
	view.build(park)
	# Shrink the drawn park around home so the whole thing reads at shop range.
	view.scale = Vector3.ONE * park_scale
	view.position = _home_point() * (1.0 - park_scale)


func _home_point() -> Vector3:
	return BaseballWorld.world_position(park.home.position) if park != null else Vector3.ZERO


## Stand every slot where the current view wants it, sliding them over when the
## view is toggled rather than snapping.
func _layout_slots(animate: bool) -> void:
	var home := _home_point()
	_show_park_markings(not batting_view)
	var tween: Tween = null
	if animate:
		tween = create_tween().set_parallel(true)
	for target in _targets():
		var slot := target as TeamSlot
		if slot == null:
			continue
		slot.show_order(batting_view)
		var spot := _slot_spot(slot, home)
		if tween == null:
			slot.position = spot
		else:
			tween.tween_property(slot, "position", spot, LAYOUT_TIME).set_trans(Tween.TRANS_CUBIC)


## Where one slot stands: a rung of the batting order list, or the spot on the field
## where that fielder plays, pulled in by [member park_scale]. A slot the roster has
## no position for keeps the spot it was placed at in the scene.
func _slot_spot(slot: TeamSlot, home: Vector3) -> Vector3:
	if batting_view:
		return _batting_spot(slot.slot_index)
	if slot.slot_index >= roster.field_positions.size():
		return slot.position
	var spot := BaseballWorld.world_position(roster.field_positions[slot.slot_index])
	return home + (spot - home) * park_scale


## Grid spots are spaced on the ground rather than across the screen, so the gap
## between two of them always looks the same next to the players standing on them.
func _batting_spot(index: int) -> Vector3:
	var column := index % BATTING_COLUMNS
	var row := floori(float(index) / BATTING_COLUMNS)
	return BATTING_CORNER + Vector3(column * BATTING_COLUMN_STEP, 0.0, row * BATTING_ROW_STEP)
func _update_order_button() -> void:
	var button := get_node_or_null("HUD/Order") as Button
	if button != null:
		button.text = "Fielding" if batting_view else "Batting order"


## Clear the diamond off the grass while the lineup is laid out on it, so the batting
## order reads as a list rather than as nine fielders standing in odd places.
func _show_park_markings(on: bool) -> void:
	var view := get_node_or_null("FieldView") as BaseballShopFieldView
	if view != null and view.markings != null:
		view.markings.visible = on
