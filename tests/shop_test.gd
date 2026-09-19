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


func click(screen: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = screen
	shop._unhandled_input(event)


## Drag a buyable onto a target the way the mouse does, then release it there.
func drag(buyable: Buyable, target: Node3D) -> void:
	click(screen_point(buyable), true)
	var motion := InputEventMouseMotion.new()
	motion.position = screen_point(target)
	shop._unhandled_input(motion)
	await process_frame
	click(motion.position, false)
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
	await check_roster_ready()
	quit(1 if failures > 0 else 0)


func check_signing() -> void:
	var slugger: PlayerSlot = shop.get_node("ForSale/Slugger")
	var pitcher: TeamSlot = shop.get_node("Roster/Slot1")
	var funds := shop.funds
	paid = slugger.cost
	var stats := slugger.player
	check(pitcher.is_empty(), "Roster slot started with a player")
	await drag(slugger, pitcher)
	check(not pitcher.is_empty(), "Dragging a player onto an open slot did not sign them")
	check(shop.funds == funds - paid, "Signing a player did not cost the asking price")
	check(pitcher.player != stats, "The signed player shares the shop listing's stats")
	check(pitcher.player.player_name == stats.player_name, "The signing lost the player stats")
	check(shop.roster.players[0] == pitcher.player, "The roster missed the signing")
	check(shop.roster.field_roles[0] == "P", "The roster missed the slot's fielding role")
	check(not is_instance_valid(slugger), "The signed player stayed on the podium")


func check_refused_drops() -> void:
	var wheels: PlayerSlot = shop.get_node("ForSale/Wheels")
	var filled: TeamSlot = shop.get_node("Roster/Slot1")
	var open: TeamSlot = shop.get_node("Roster/Slot2")
	var rest := wheels.global_position
	var funds := shop.funds
	await drag(wheels, filled)
	check(filled.player.player_name != "Wheels", "A taken slot took a second player")
	check(shop.funds == funds, "A refused drop still charged the shop")
	check(wheels.global_position.is_equal_approx(rest), "A refused drop stranded a player")
	shop.funds = wheels.cost - 1
	await drag(wheels, open)
	check(open.is_empty(), "A player was signed without the funds to pay for them")
	check(shop.funds == wheels.cost - 1, "An unaffordable drop still moved money")


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
	var wheels: PlayerSlot = shop.get_node("ForSale/Wheels")
	var open: TeamSlot = shop.get_node("Roster/Slot3")
	var sell: SellSpot = shop.get_node("SellSpot")
	var rest := wheels.global_position
	var funds := shop.funds
	await drag(wheels, sell)
	check(shop.funds == funds, "The sell spot paid for a player the shop never sold")
	check(wheels.global_position.is_equal_approx(rest), "A refused sale stranded a listing")
	await drag(wheels, open)
	var signed_player: SignedPlayer = open.occupant
	check(signed_player != null, "A signing after a refused sale did not go through")
	var slot_funds := shop.funds
	await drag(signed_player, shop.get_node("Roster/Slot4"))
	check(open.player != null, "Dropping a signed player on an empty slot emptied their own")
	check(shop.funds == slot_funds, "Moving a signed player between slots moved money")


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
