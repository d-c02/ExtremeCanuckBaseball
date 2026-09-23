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
const LISTING := preload("res://game/shop/player_slot.tscn")
const SNACK := preload("res://game/shop/food.tscn")
const SHOP_STAGE: BaseballShopStage = preload("res://assets/field/shop_stage.tres")
const MATCH_SCENE := "res://main.tscn"
## Where a listing stands on its podium.
const PODIUM_TOP := 1.2
## What the first refresh of a visit costs.
const FIRST_REFRESH := 1

## Roster the shop starts a run from. It is duplicated, so trading never edits the
## file, and a run in progress keeps the team it has already signed instead.
@export var team: BaseballTeamData
## What the shop can stock, and from which round.
@export var pool: BaseballPlayerPool
## Snacks the shop sells, for the podiums that deal in them.
@export var foods: Array[BaseballFoodType] = []
## Seed for the players the shop rolls. Zero rolls a different shop every run.
@export var random_seed: int = 0

## The Blender shop preview scales the shared field around home by this amount.
var park_scale: float = SHOP_STAGE.field_scale

## The run's money, kept on the session so it lives across the scene change.
var funds: int:
	get:
		return BaseballSession.funds
	set(value):
		BaseballSession.funds = value
## Refreshes bought this visit. Each one costs a dollar more than the last.
var refreshes: int = 0
var roster: BaseballTeamData
var rng := RandomNumberGenerator.new()
## Whether the slots are lined up in batting order instead of out on the field.
var batting_view: bool = false
var park: BaseballBallpark
var held: Buyable
var hovered: BuyTarget
var pointed: Buyable

var _grab_height: float = 0.0
var _hover_allowed: bool = false


func _ready() -> void:
	roster = BaseballSession.roster
	if roster == null:
		roster = team.duplicate(true) if team != null else BaseballTeamData.new()
		BaseballSession.roster = roster
	if random_seed == 0:
		rng.randomize()
	else:
		rng.seed = random_seed
	park = get_node_or_null("Field") as BaseballBallpark
	_apply_stage()
	_build_park()
	for target in _targets():
		target.roster = roster
		target.refresh()
	_layout_slots(false)
	_update_order_button()
	_connect_button("Order", _toggle_view)
	_connect_button("Refresh", buy_refresh)
	_connect_button("Start", start_game)
	_connect_button("NewRun", new_run)
	refresh_stock()
	_update_hud()


func _connect_button(name: String, handler: Callable) -> void:
	var button := get_node_or_null("HUD/" + name) as Button
	if button != null:
		button.pressed.connect(handler)


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


func can_start_game() -> bool:
	return roster != null and roster.has_role("P") and roster.has_role("C")


## Move a buyable onto a target and settle the money, for tests and scripted trades.
func trade(buyable: Buyable, target: BuyTarget) -> bool:
	if not can_trade(buyable, target):
		return false
	# Ask before the drop lands: a merge changes the answers it would give after.
	var price := buyable.price(target)
	var spent := buyable.spent_on(target)
	if not buyable.apply_to(target):
		return false
	funds -= price
	target.refresh()
	buyable.consume(target, spent)
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
## one is held, judge the drop onto the target underneath it. Nothing is named while
## a player is being carried, because the cursor is busy saying where they will land.
func _point(screen: Vector2) -> void:
	if held != null:
		held.drag_to(_plane_point(screen))
	_set_hovered(_pick(screen, BuyTarget.LAYER) as BuyTarget)
	var under: Buyable = null
	if held == null:
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
	hovered.set_hovered(held == null)
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
	var run := get_node_or_null("HUD/Run") as Label
	if run != null:
		run.text = "Round %d    Lives %d" % [BaseballSession.round_number, BaseballSession.lives]
	var refresh := get_node_or_null("HUD/Refresh") as Button
	if refresh != null:
		refresh.text = "Refresh  $%d" % refresh_cost()
		refresh.disabled = refresh_cost() > funds
	var start := get_node_or_null("HUD/Start") as Button
	if start != null:
		var needs_pitcher := not roster.has_role("P")
		var needs_catcher := not roster.has_role("C")
		start.disabled = not can_start_game()
		if needs_pitcher and needs_catcher:
			start.text = "Sign pitcher + catcher"
		elif needs_pitcher:
			start.text = "Sign pitcher"
		elif needs_catcher:
			start.text = "Sign catcher"
		else:
			start.text = "Start game"


## Place interactive Godot nodes at the anchors authored in Blender.
func _apply_stage() -> void:
	var stands := podiums()
	if stands.size() != SHOP_STAGE.podium_positions.size():
		push_error("Shop podium count differs from the Blender stage")
		return
	for index in stands.size():
		stands[index].position = SHOP_STAGE.podium_positions[index]
	var sell := get_node_or_null("SellSpot") as SellSpot
	if sell != null:
		sell.position = SHOP_STAGE.sell_position
	var camera := get_node_or_null("Camera3D") as Camera3D
	if camera != null:
		camera.position = SHOP_STAGE.camera_position
		camera.look_at(SHOP_STAGE.camera_target)
		camera.fov = SHOP_STAGE.camera_fov


## Draw the same exported field mesh and layout used by the match.
func _build_park() -> void:
	var view := get_node_or_null("FieldView") as BaseballShopFieldView
	if park == null or view == null:
		return
	view.build_shop()
	# Use the same transform as the Blender shop preview.
	view.scale = Vector3.ONE * park_scale
	view.position = SHOP_STAGE.field_position


## Stand every slot where the current view wants it, sliding them over when the
## view is toggled rather than snapping.
func _layout_slots(animate: bool) -> void:
	_show_park_markings(not batting_view)
	var tween: Tween = null
	if animate:
		tween = create_tween().set_parallel(true)
	for target in _targets():
		var slot := target as TeamSlot
		if slot == null:
			continue
		slot.show_order(batting_view)
		var spot := _slot_spot(slot)
		if tween == null:
			slot.position = spot
		else:
			tween.tween_property(slot, "position", spot, LAYOUT_TIME).set_trans(Tween.TRANS_CUBIC)


## Fielding spots come from the visible placement markers in Blender.
func _slot_spot(slot: TeamSlot) -> Vector3:
	if batting_view:
		return _batting_spot(slot.slot_index)
	if slot.slot_index >= SHOP_STAGE.field_positions.size():
		return slot.position
	return SHOP_STAGE.field_positions[slot.slot_index]


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
	var lineup := get_node_or_null("LineupGround") as Node3D
	if lineup != null:
		lineup.visible = not on


## What the next refresh costs. The first is a dollar and each one after is a dollar
## more, so a shop picked clean gets dearer to pick over again.
func refresh_cost() -> int:
	return FIRST_REFRESH + refreshes


## Pay for a refresh and roll a new shelf. Refused when the money is not there.
func buy_refresh() -> bool:
	var price := refresh_cost()
	if price > funds:
		return false
	funds -= price
	refreshes += 1
	refresh_stock()
	funds_changed.emit(funds)
	_update_hud()
	return true


## Roll a fresh listing onto every podium. Sold podiums fill back up too, so a
## refresh is what puts the shop back in business, and each podium rolls its own
## kind of thing.
func refresh_stock() -> void:
	var taken := PackedStringArray()
	for podium in podiums():
		podium.stock(_roll_listing(podium, taken))


## What goes on one podium. Returns null when the shop has nothing of that kind.
func _roll_listing(podium: ShopPodium, taken: PackedStringArray) -> Buyable:
	if podium.sells == ShopPodium.Sells.FOOD:
		if foods.is_empty():
			return null
		var snack: Food = SNACK.instantiate()
		snack.food = foods[rng.randi() % foods.size()]
		snack.cost = snack.food.price
		snack.position = Vector3(0.0, PODIUM_TOP, 0.0)
		return snack
	var rolled := BaseballRecruit.roll(rng, _stock_types(), taken)
	if rolled == null:
		return null
	taken.append(rolled.player_name)
	var listing: PlayerSlot = LISTING.instantiate()
	listing.player = rolled
	listing.cost = rolled.value()
	listing.position = Vector3(0.0, PODIUM_TOP, 0.0)
	return listing


## Roll the team this roster will face. It is given what the run has paid the player
## so far and shops the same shelf the player does, so both sides have had the same
## money and the same podiums to spend it on.
func build_opponent() -> BaseballTeamData:
	return BaseballRecruit.roll_opponent(rng, roster, _shelf(), BaseballSession.income())


## The shop as a rolled team shops it: the kinds and snacks on offer, and as many
## podiums of each as this scene puts out.
func _shelf() -> BaseballShelf:
	var shelf := BaseballShelf.new()
	shelf.types = _stock_types()
	shelf.foods = foods
	shelf.player_podiums = 0
	shelf.snack_podiums = 0
	for podium in podiums():
		if podium.sells == ShopPodium.Sells.FOOD:
			shelf.snack_podiums += 1
		else:
			shelf.player_podiums += 1
	return shelf


## Hand the signed team and a fresh opponent to the match, and go and play it.
func start_game() -> void:
	if not can_start_game():
		return
	roster.finish_shopping()
	BaseballSession.carry(roster, build_opponent())
	get_tree().change_scene_to_file(MATCH_SCENE)


func new_run() -> void:
	BaseballSession.begin()
	get_tree().reload_current_scene()


## Every podium the shop sells from, left to right.
func podiums() -> Array[ShopPodium]:
	var found: Array[ShopPodium] = []
	for node in find_children("*", "ShopPodium", true, false):
		found.append(node)
	return found


## The kinds of player on offer this round. A shop with no pool sells nothing.
func _stock_types() -> Array[BaseballPlayerType]:
	if pool == null:
		return []
	return pool.available(BaseballSession.round_number)
