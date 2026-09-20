extends SceneTree

## Checks the buy screen: dragging a player onto an open roster slot signs them,
## dragging them onto the sell spot cashes them in, and refused drops leave the
## player and the funds alone.

var failures := 0
var shop: Shop
## What the first signing cost, to compare against what selling pays back.
var paid := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


## Let physics register the areas and any return-home tween finish.
func settle() -> void:
	await physics_frame
	await physics_frame
	for frame in 24:
		await process_frame


func screen_point(node: Node3D) -> Vector2:
	return shop.get_viewport().get_camera_3d().unproject_position(node.global_position)


func motion_at(screen: Vector2) -> InputEventMouseMotion:
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	return motion


## Find a listing by name, wherever its podium stands.
func listing(display_name: String) -> PlayerSlot:
	return shop.find_child(display_name, true, false) as PlayerSlot


func click(screen: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = screen
	shop._unhandled_input(event)


## Drag a buyable onto a target the way the mouse does, then release it there.
func drag(buyable: Buyable, target: Node3D) -> void:
	click(screen_point(buyable), true)
	var screen := screen_point(target)
	shop._unhandled_input(motion_at(screen))
	await process_frame
	click(screen, false)
	await settle()


func run() -> void:
	var screen: Node = load("res://game/buy_screen.tscn").instantiate()
	root.add_child(screen)
	shop = screen
	await settle()
	await check_signing()
	await check_refused_drops()
	await check_selling()
	await check_refused_sales()
	await check_moving()
	await check_hover_names()
	await check_dangle()
	await check_roster_ready()
	quit(1 if failures > 0 else 0)


func check_signing() -> void:
	var jack: PlayerSlot = listing("Jack")
	var pitcher: TeamSlot = shop.get_node("Roster/Slot1")
	var funds := shop.funds
	paid = jack.cost
	var stats := jack.player
	check(pitcher.is_empty(), "Roster slot started with a player")
	await drag(jack, pitcher)
	check(not pitcher.is_empty(), "Dragging a player onto an open slot did not sign them")
	check(shop.funds == funds - paid, "Signing a player did not cost the asking price")
	check(pitcher.player != stats, "The signed player shares the shop listing's stats")
	check(pitcher.player.player_name == stats.player_name, "The signing lost the player stats")
	check(shop.roster.players[0] == pitcher.player, "The roster missed the signing")
	check(shop.roster.field_roles[0] == "P", "The roster missed the slot's fielding role")
	check(not is_instance_valid(jack), "The signed player stayed on the podium")


func check_refused_drops() -> void:
	var arthur: PlayerSlot = listing("Arthur")
	var filled: TeamSlot = shop.get_node("Roster/Slot1")
	var open: TeamSlot = shop.get_node("Roster/Slot2")
	var rest := arthur.global_position
	var funds := shop.funds
	await drag(arthur, filled)
	check(filled.player.player_name != "Arthur", "A taken slot took a second player")
	check(shop.funds == funds, "A refused drop still charged the shop")
	check(arthur.global_position.is_equal_approx(rest), "A refused drop stranded a player")
	shop.funds = arthur.cost - 1
	await drag(arthur, open)
	check(open.is_empty(), "A player was signed without the funds to pay for them")
	check(shop.funds == arthur.cost - 1, "An unaffordable drop still moved money")


func check_selling() -> void:
	var pitcher: TeamSlot = shop.get_node("Roster/Slot1")
	var sell: SellSpot = shop.get_node("SellSpot")
	var signed_player: SignedPlayer = pitcher.occupant
	var value := signed_player.sell_value
	var funds := shop.funds
	check(value != paid, "The sell value matched the asking price")
	await drag(signed_player, sell)
	check(pitcher.is_empty(), "Selling a player left them in the roster slot")
	check(shop.funds == funds + value, "Selling a player did not pay the sell value")
	check(shop.roster.players[0] == null, "The roster kept the sold player")
	check(not is_instance_valid(signed_player), "The sold player stayed in the slot")
	check(sell.label.text == "Sell", "The sell spot kept a stale price preview")


func check_refused_sales() -> void:
	var arthur: PlayerSlot = listing("Arthur")
	var open: TeamSlot = shop.get_node("Roster/Slot3")
	var sell: SellSpot = shop.get_node("SellSpot")
	var rest := arthur.global_position
	var funds := shop.funds
	await drag(arthur, sell)
	check(shop.funds == funds, "The sell spot paid for a player the shop never sold")
	check(arthur.global_position.is_equal_approx(rest), "A refused sale stranded a listing")
	await drag(arthur, open)
	var signed_player: SignedPlayer = open.occupant
	check(signed_player != null, "A signing after a refused sale did not go through")


## The shop roster starts with every fielding position, so filling all nine slots
## has to leave a roster a match would accept.
func check_roster_ready() -> void:
	for target in shop._targets():
		var slot := target as TeamSlot
		if slot == null or not slot.is_empty():
			continue
		var recruit := BaseballPlayerData.new()
		recruit.player_name = slot.role
		slot.fill(recruit, 1)
	await settle()
	check(
		shop.roster.validation_error().is_empty(),
		"A full shop roster was rejected: " + shop.roster.validation_error()
	)


## Names are clutter on a full field, so they only show under the cursor.
func check_hover_names() -> void:
	var harrhy := listing("Harrhy")
	var slot: TeamSlot = shop.get_node("Roster/Slot5")
	check(not harrhy.name_label.visible, "A listing named itself before being hovered")
	check(not slot.name_label.visible, "A roster slot named itself before being hovered")
	shop._unhandled_input(motion_at(screen_point(harrhy)))
	check(harrhy.name_label.visible, "Hovering a listing did not show its name")
	shop._unhandled_input(motion_at(screen_point(slot)))
	check(not harrhy.name_label.visible, "A listing kept its name after the cursor left")
	check(slot.name_label.visible, "Hovering a roster slot did not show its name")
	check(not slot.highlight.visible, "A roster slot lit up with nothing being dragged")


func cancel_drag() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	shop._unhandled_input(event)


## Drag the cursor in steps, a frame apart, so the carried body builds up speed.
func sweep(from: Vector2, step: Vector2, steps: int) -> Vector2:
	var at := from
	for frame in steps:
		at += step
		shop._unhandled_input(motion_at(at))
		await process_frame
	return at


## A carried player hangs from the cursor by the head and trails behind a yank.
func check_dangle() -> void:
	var harrhy := listing("Harrhy")
	var grip := harrhy.grip_height()
	check(grip > 1.0, "A carried player has no head to hang from")
	var at := screen_point(harrhy)
	click(at, true)
	at = await sweep(at, Vector2(45, 0), 8)
	var head := harrhy.global_position.y + grip
	check(harrhy.swing < -0.05, "Sweeping right did not trail the body left")
	at = await sweep(at, Vector2(-45, 0), 8)
	check(harrhy.swing > 0.05, "Sweeping left did not trail the body right")
	for frame in 60:
		await process_frame
	check(absf(harrhy.swing) < 0.05, "The body never settled under a still cursor")
	check(
		absf(harrhy.global_position.y + grip - head) < 0.01,
		"The body stopped hanging at the cursor"
	)
	cancel_drag()
	await settle()
	check(harrhy.position.is_equal_approx(harrhy.rest_position), "A cancel stranded a player")


## Players can be shuffled around the field for free: an open spot takes them, and
## a taken one trades back whoever was standing there.
func check_moving() -> void:
	var from: TeamSlot = shop.get_node("Roster/Slot3")
	var open: TeamSlot = shop.get_node("Roster/Slot5")
	var mover := from.occupant
	var moved := from.player
	var funds := shop.funds
	check(mover != null, "Nobody was on the field to move")
	await drag(mover, from)
	check(from.player == moved, "Dropping a player on their own slot moved them")
	await drag(mover, open)
	check(from.is_empty(), "Moving a player left them in their old spot")
	check(open.player == moved, "A moved player did not take the open spot")
	check(mover.slot == open, "The moved player did not follow their slot")
	check(shop.funds == funds, "Moving a player cost money")
	check(shop.roster.players[open.slot_index] == moved, "The roster missed the move")
	check(shop.roster.players[from.slot_index] == null, "The roster kept the old spot filled")
	check(shop.roster.field_roles[open.slot_index] == open.role, "A move rewrote the role")
	var bench := BaseballPlayerData.new()
	bench.player_name = "Bench"
	from.fill(bench, 1)
	await settle()
	await drag(open.occupant, from)
	check(from.player == moved, "A swap did not bring the dragged player over")
	check(open.player == bench, "A swap did not send the other player back")
	check(shop.roster.players[from.slot_index] == moved, "The roster missed the swap")
	check(shop.funds == funds, "Swapping players cost money")
