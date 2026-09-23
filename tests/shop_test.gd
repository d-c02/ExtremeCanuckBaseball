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


## Hold the shop to a single kind and hand back what it was stocking, so a check
## that needs two of a kind can count on the shelf having them.
func pin_one_kind() -> Array[BaseballPlayerType]:
	var kinds := shop.pool.types.duplicate()
	var single: Array[BaseballPlayerType] = [kinds[0]]
	shop.pool.types = single
	return kinds


## The listing on one podium, left to right. The shop rolls its stock, so the tests
## ask for a spot rather than a name.
func listing(index: int) -> PlayerSlot:
	return shop.podiums()[index].listing as PlayerSlot


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
	# Start every run of the suite from a fresh purse and an empty roster.
	BaseballSession.begin()
	var screen: Node = load("res://game/buy_screen.tscn").instantiate()
	root.add_child(screen)
	shop = screen
	# Roll the stock from a fixed seed so a failure can be repeated.
	shop.rng.seed = 9
	shop.refresh_stock()
	await settle()
	check_blender_stage()
	await check_signing()
	await check_refused_drops()
	await check_selling()
	await check_refused_sales()
	await check_moving()
	await check_merging()
	await check_signed_merging()
	await check_batting_view()
	await check_hover_names()
	await check_dangle()
	await check_quiet_drag()
	await check_refresh()
	await check_podium_kinds()
	await check_food()
	await check_level_growth()
	await check_food_passives()
	await check_coaching()
	await check_roster_ready()
	await check_refresh_cost()
	await check_pool()
	await check_opponent()
	await check_opponent_spends()
	await check_opponent_pool()
	await check_run_banking()
	print("Shop failures: %d" % failures)
	quit(1 if failures > 0 else 0)


func check_blender_stage() -> void:
	var stage: BaseballShopStage = load("res://assets/field/shop_stage.tres")
	var view: BaseballShopFieldView = shop.get_node("FieldView")
	check(shop.park.use_exported_layout, "The shop did not apply the Blender field layout")
	check(
		view.model.scene_file_path == "res://assets/field/baseball_field.glb",
		"The shop did not instantiate the match's field GLB"
	)
	check(
		view.position.is_equal_approx(stage.field_position),
		"The shop field missed its Blender anchor"
	)
	check(
		view.scale.is_equal_approx(Vector3.ONE * stage.field_scale),
		"The shop field missed its Blender scale"
	)
	check(stage.field_positions.size() == 9, "The Blender stage needs nine roster anchors")
	var stands := shop.podiums()
	check(
		stands.size() == stage.podium_positions.size(), "The podium anchors do not match the shop"
	)
	for index in mini(stands.size(), stage.podium_positions.size()):
		check(
			stands[index].position.is_equal_approx(stage.podium_positions[index]),
			"A podium missed its Blender anchor"
		)
	check(
		shop.get_node("SellSpot").position.is_equal_approx(stage.sell_position),
		"The sell target missed its Blender anchor"
	)
	check(shop.get_node("ShopFixtures").get_child_count() > 0, "The Blender fixtures are absent")


func check_signing() -> void:
	var jack := listing(0)
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


## A drop is refused when the player standing there is another kind, or when the
## shop cannot cover the asking price.
func check_refused_drops() -> void:
	var arthur := listing(1)
	var stranger: TeamSlot = shop.get_node("Roster/Slot6")
	var open: TeamSlot = shop.get_node("Roster/Slot2")
	var other_type := BaseballPlayerType.new()
	other_type.type_name = "Groundskeeper"
	var outsider := other_type.recruit()
	stranger.fill(outsider)
	await settle()
	var rest := arthur.global_position
	var funds := shop.funds
	await drag(arthur, stranger)
	check(stranger.player == outsider, "Another kind of player took the drop")
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
	var value := signed_player.player.sell_price()
	var funds := shop.funds
	check(value != paid, "The sell value matched the asking price")
	await drag(signed_player, sell)
	check(pitcher.is_empty(), "Selling a player left them in the roster slot")
	check(shop.funds == funds + value, "Selling a player did not pay the sell value")
	check(shop.roster.players[0] == null, "The roster kept the sold player")
	check(not is_instance_valid(signed_player), "The sold player stayed in the slot")
	check(sell.label.text == "Sell", "The sell spot kept a stale price preview")


func check_refused_sales() -> void:
	var arthur := listing(1)
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
		slot.fill(recruit)
	await settle()
	check(
		shop.roster.validation_error().is_empty(),
		"A full shop roster was rejected: " + shop.roster.validation_error()
	)


## Names are clutter on a full field, so they only show under the cursor.
func check_hover_names() -> void:
	var harrhy := listing(2)
	var slot: TeamSlot = shop.get_node("Roster/Slot5")
	check(not harrhy.name_label.visible, "A listing named itself before being hovered")
	check(not slot.name_label.visible, "A roster slot named itself before being hovered")
	shop._unhandled_input(motion_at(screen_point(harrhy)))
	check(harrhy.name_label.visible, "Hovering a listing did not show its name")
	check(
		(
			harrhy.name_label.text.begins_with(harrhy.player.type.type_name)
			and harrhy.name_label.text.ends_with(harrhy.player.type.passive)
		),
		"The card did not name the kind of player and what its passive does"
	)
	shop._unhandled_input(motion_at(screen_point(slot)))
	check(not harrhy.name_label.visible, "A listing kept its name after the cursor left")
	check(slot.name_label.visible, "Hovering a roster slot did not show its name")
	check(not slot.highlight.visible, "A roster slot lit up with nothing being dragged")
	# The two numbers a player is bought on stay readable without the cursor.
	check(
		(
			harrhy.stat_labels[0].text == "%d" % harrhy.player.strength
			and harrhy.stat_labels[1].text == "%d" % harrhy.player.dexterity
			and harrhy.stat_labels[0].visible
		),
		"A listing hid the STR and DEX it is bought on"
	)


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
	var harrhy := listing(2)
	var grip := harrhy.grip_height()
	check(grip > 1.0, "A carried player has no head to hang from")
	var at := screen_point(harrhy)
	click(at, true)
	at = await sweep(at, Vector2(55, 0), 12)
	var head := harrhy.global_position.y + grip
	check(harrhy.swing < -0.05, "Sweeping right did not trail the body left")
	at = await sweep(at, Vector2(-55, 0), 12)
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
	from.fill(bench)
	await settle()
	await drag(open.occupant, from)
	check(from.player == moved, "A swap did not bring the dragged player over")
	check(open.player == bench, "A swap did not send the other player back")
	check(shop.roster.players[from.slot_index] == moved, "The roster missed the swap")
	check(shop.funds == funds, "Swapping players cost money")


## The lineup view stands everyone in a numbered column instead of out on the field.
func check_batting_view() -> void:
	var first: TeamSlot = shop.get_node("Roster/Slot1")
	var last: TeamSlot = shop.get_node("Roster/Slot9")
	var button: Button = shop.get_node("HUD/Order")
	var fielding := first.position
	check(not first.order_label.visible, "A batting number showed out on the field")
	button.pressed.emit()
	await settle()
	check(shop.batting_view, "The button did not switch to the lineup")
	check(first.order_label.visible, "The lineup did not number the spots")
	check(first.order_label.text == "1", "The leadoff spot was not numbered 1")
	check(last.order_label.text == "9", "The last spot was not numbered 9")
	check(not first.position.is_equal_approx(fielding), "The lineup left a slot on the field")
	var view: BaseballShopFieldView = shop.get_node("FieldView")
	check(not view.markings.visible, "The diamond stayed under the batting order")
	check(shop.get_node("LineupGround").visible, "The Blender lineup floor did not appear")
	var camera := shop.get_viewport().get_camera_3d()
	var spots: Array[Vector3] = []
	var screens: Array[Vector2] = []
	for index in 9:
		var slot: TeamSlot = shop.get_node("Roster/Slot%d" % (index + 1))
		spots.append(slot.position)
		screens.append(camera.unproject_position(slot.global_position))
	check(is_equal_approx(spots[0].z, spots[2].z), "The first three spots were not one row")
	check(is_equal_approx(spots[0].x, spots[6].x), "The first column did not line up")
	check(
		is_equal_approx(spots[0].distance_to(spots[3]), spots[3].distance_to(spots[6])),
		"The rows were not spaced evenly on the ground"
	)
	check(screens[0].y < screens[8].y, "The leadoff hitter was not at the top of the grid")
	var closest := INF
	for a in 9:
		for b in range(a + 1, 9):
			closest = minf(closest, screens[a].distance_to(screens[b]))
	check(closest > 100.0, "Two batting spots crowded each other, %.0f px apart" % closest)
	button.pressed.emit()
	await settle()
	check(first.position.is_equal_approx(fielding), "Leaving the lineup stranded a slot")
	check(not first.order_label.visible, "A batting number stayed after leaving the lineup")
	check(view.markings.visible, "The diamond did not come back with the fielders")
	check(not shop.get_node("LineupGround").visible, "The lineup floor stayed under the field")


## Refreshing rolls a whole new shelf: every podium comes back with something of its
## own kind, and a rolled player is priced by the stats they were given.
func check_refresh() -> void:
	var before: Array[Buyable] = []
	for podium in shop.podiums():
		before.append(podium.listing)
	shop.funds = 99
	var button: Button = shop.get_node("HUD/Refresh")
	button.pressed.emit()
	await settle()
	for podium in shop.podiums():
		check(podium.listing != null, "A podium came back from a refresh empty")
		check(not before.has(podium.listing), "A refresh left the same thing on a podium")
		var rolled := podium.listing as PlayerSlot
		if rolled == null:
			continue
		check(rolled.cost == rolled.player.value(), "A rolled player was not priced on stats")
		check(rolled.player.sell_price() < rolled.cost, "A rolled player sold for the asking price")


## The rolled opponent spends what the run has paid the player by this round, and
## always has somebody to pitch and somebody to catch.
func check_opponent() -> void:
	BaseballSession.round_number = 2
	check(BaseballSession.income() == 50, "Round two was not the purse on top of the start")
	var budget := BaseballSession.income()
	var enemy := shop.build_opponent()
	check(
		enemy.validation_error().is_empty(),
		"The rolled opponent was rejected: " + enemy.validation_error()
	)
	check(enemy.has_role("P"), "The rolled opponent had nobody to pitch")
	check(enemy.has_role("C"), "The rolled opponent had nobody to catch")
	var worth := 0
	var signed := 0
	for index in enemy.field_roles.size():
		var player := enemy.player_at(index)
		if player != null:
			signed += 1
			worth += player.value()
	check(signed >= 2, "The rolled opponent could not field a battery")
	check(worth <= budget, "The rolled opponent spent $%d of $%d" % [worth, budget])
	# A run that has paid out more fields at least as much team.
	BaseballSession.round_number = 8
	var rich := shop.build_opponent()
	var rich_signed := 0
	for index in rich.field_roles.size():
		if rich.player_at(index) != null:
			rich_signed += 1
	check(rich_signed >= signed, "A richer run did not field at least as many players")
	BaseballSession.round_number = 1
	BaseballSession.carry(shop.roster, enemy)
	check(BaseballSession.ready_to_play(), "The session did not take the teams to the match")
	var start: Button = shop.get_node("HUD/Start")
	check(not start.pressed.get_connections().is_empty(), "The start button went nowhere")
	BaseballSession.clear()


## Every refresh costs a dollar more than the last, and the shop will not sell one
## it cannot be paid for.
func check_refresh_cost() -> void:
	shop.refreshes = 0
	shop.funds = 10
	check(shop.refresh_cost() == 1, "The first refresh of a visit was not a dollar")
	check(shop.buy_refresh(), "A refresh the shop could pay for was refused")
	check(shop.funds == 9, "The first refresh did not cost a dollar")
	check(shop.refresh_cost() == 2, "The second refresh cost the same as the first")
	check(shop.buy_refresh(), "The second refresh was refused")
	check(shop.funds == 7, "The second refresh did not cost two dollars")
	await settle()
	var button: Button = shop.get_node("HUD/Refresh")
	check(button.text == "Refresh  $3", "The button did not price the next refresh")
	shop.funds = 2
	shop._update_hud()
	check(button.disabled, "The button stayed live with the price out of reach")
	check(not shop.buy_refresh(), "A refresh went through without the money for it")
	check(shop.funds == 2, "A refused refresh still took money")


## A pool only offers kinds the run has reached.
func check_pool() -> void:
	var opened := shop.pool.available(1).size()
	var later := BaseballPlayerType.new()
	later.type_name = "Ace"
	later.from_round = 3
	shop.pool.types.append(later)
	check(shop.pool.available(1).size() == opened, "A later kind turned up in round one")
	check(shop.pool.available(3).size() == opened + 1, "A kind never opened up")
	check(shop._stock_types().size() == opened, "The shop stocked ahead of the round")
	BaseballSession.round_number = 3
	check(shop._stock_types().size() == opened + 1, "The shop missed a kind that opened up")
	BaseballSession.round_number = 1
	shop.pool.types.remove_at(shop.pool.types.size() - 1)


## Finishing a match pays the purse either way, and a loss costs a life.
func check_run_banking() -> void:
	BaseballSession.begin()
	check(BaseballSession.funds == 30, "A run did not start with thirty dollars")
	check(BaseballSession.lives == 5, "A run did not start with five lives")
	check(BaseballSession.round_number == 1, "A run did not start at round one")
	BaseballSession.finish_match(true)
	check(BaseballSession.funds == 50, "Winning did not pay the purse")
	check(BaseballSession.lives == 5, "Winning cost a life")
	check(BaseballSession.round_number == 2, "Winning did not move the run on")
	BaseballSession.finish_match(false)
	check(BaseballSession.funds == 70, "Losing did not pay the purse")
	check(BaseballSession.lives == 4, "Losing did not cost a life")
	for loss in 4:
		BaseballSession.finish_match(false)
	check(BaseballSession.over(), "A run with no lives left was not over")
	BaseballSession.begin()


## A snack is bought like a player and eaten by one: the point goes on for good and
## the snack is gone. Nobody to eat it means no sale.
func check_food() -> void:
	shop.refresh_stock()
	await settle()
	var slot: TeamSlot = null
	var empty: TeamSlot = null
	for target in shop._targets():
		var candidate := target as TeamSlot
		if candidate == null:
			continue
		if slot == null and not candidate.is_empty():
			slot = candidate
		if empty == null and candidate.is_empty():
			empty = candidate
	check(slot != null, "Nobody was signed to eat a snack")
	check(empty != null, "Every slot was taken, so nothing could refuse a snack")
	var snack: Food = null
	for podium in shop.podiums():
		if podium.sells == ShopPodium.Sells.FOOD:
			snack = podium.listing as Food
			break
	check(snack != null, "No podium was selling snacks")
	shop.funds = 20
	# This check is about the sale, not the passives: the kinds that make more of a
	# snack are checked on their own, so the eater here is the plain sort.
	slot.player.type = shop.pool.types[0]
	var strength := slot.player.strength
	var dexterity := slot.player.dexterity
	# The snack frees itself once eaten, so read what it does while it is still here.
	var gains := Vector2i(snack.food.strength_gain, snack.food.dexterity_gain)
	var price := snack.food.price
	var rest := snack.global_position
	await drag(snack, empty)
	check(shop.funds == 20, "An empty slot bought a snack with nobody to eat it")
	check(snack.global_position.is_equal_approx(rest), "A refused snack was stranded")
	await drag(snack, slot)
	check(
		slot.player.strength == strength + gains.x and slot.player.dexterity == dexterity + gains.y,
		"A snack was eaten without feeding the player"
	)
	check(shop.funds == 20 - price, "A snack did not cost its price")
	check(not is_instance_valid(snack), "An eaten snack stayed on its podium")
	check(
		shop.roster.player_at(slot.slot_index).strength == slot.player.strength,
		"The roster missed what a snack fed"
	)


## A podium deals in one kind of thing and keeps to it, refresh after refresh.
func check_podium_kinds() -> void:
	var players := 0
	var snacks := 0
	for podium in shop.podiums():
		if podium.sells == ShopPodium.Sells.FOOD:
			snacks += 1
		else:
			players += 1
	check(players == 4, "The shop was not selling players from four podiums")
	check(snacks == 2, "The shop was not selling snacks from two podiums")
	for attempt in 4:
		shop.refresh_stock()
		await settle()
		for podium in shop.podiums():
			if podium.sells == ShopPodium.Sells.FOOD:
				check(podium.listing is Food, "A snack podium stocked something else")
			else:
				check(podium.listing is PlayerSlot, "A player podium stocked something else")


## Two of a kind merge rather than crowd a slot: the same level is a level up on
## its own, and a level below counts half, so the second one finishes the job.
func check_merging() -> void:
	var kinds := pin_one_kind()
	var slot: TeamSlot = shop.get_node("Roster/Slot8")
	shop.refresh_stock()
	await settle()
	shop.funds = 99
	await drag(listing(0), slot)
	check(slot.player.level == 1, "A signing did not start at level one")
	var strength := slot.player.strength
	shop.refresh_stock()
	await settle()
	var second := listing(0)
	await drag(second, slot)
	check(slot.player.level == 2, "Two of a level did not merge into the next one")
	check(slot.player.strength == strength + 2, "The level up did not pay the passive")
	check(slot.occupant.level_label.text == "Lv 2", "The badge missed the level up")
	check(not is_instance_valid(second), "A merged listing stayed on its podium")
	shop.refresh_stock()
	await settle()
	await drag(listing(0), slot)
	check(slot.player.level == 2, "One level below levelled a player on its own")
	check(slot.player.steps == 1, "A half merge was not remembered")
	check(slot.occupant.level_label.text == "Lv 2½", "The badge did not show the half merge")
	shop.refresh_stock()
	await settle()
	await drag(listing(0), slot)
	check(slot.player.level == 3, "The second half merge did not finish the level up")
	shop.refresh_stock()
	await settle()
	var spare := listing(0)
	var rest := spare.global_position
	await drag(spare, slot)
	check(slot.player.level == 3, "A player at the cap took another merge")
	check(spare.global_position.is_equal_approx(rest), "A refused merge stranded a player")
	shop.pool.types = kinds


## Players already signed merge the same way, and the slot the carried one left
## stands empty afterwards.
func check_signed_merging() -> void:
	var kinds := pin_one_kind()
	var keeper: TeamSlot = shop.get_node("Roster/Slot4")
	var giver: TeamSlot = shop.get_node("Roster/Slot7")
	shop.refresh_stock()
	await settle()
	shop.funds = 99
	await drag(listing(0), keeper)
	shop.refresh_stock()
	await settle()
	await drag(listing(0), giver)
	var carried := giver.occupant
	var funds := shop.funds
	await drag(carried, keeper)
	check(keeper.player.level == 2, "Two signed players of a kind did not merge")
	check(giver.is_empty(), "A merged player was left behind in their old slot")
	check(shop.roster.player_at(giver.slot_index) == null, "The roster kept the merged player")
	check(shop.funds == funds, "Merging two signed players cost money")
	check(not is_instance_valid(carried), "The merged player stayed on the field")
	shop.pool.types = kinds


## Nothing is named while a player is being carried: the cards would only get in
## the way of seeing where they are going.
func check_quiet_drag() -> void:
	shop.refresh_stock()
	await settle()
	var carried := listing(0)
	var slot: TeamSlot = shop.get_node("Roster/Slot9")
	shop._unhandled_input(motion_at(screen_point(carried)))
	check(carried.name_label.visible, "A listing under the cursor did not name itself")
	click(screen_point(carried), true)
	shop._unhandled_input(motion_at(screen_point(slot)))
	await process_frame
	check(not carried.name_label.visible, "A carried player kept their card up")
	check(not slot.name_label.visible, "A slot named itself under a carried player")
	check(slot.highlight.visible, "A slot stopped lighting up under a carried player")
	cancel_drag()
	await settle()


## A rolled team spends its money on itself. It only pays for a new shelf once the
## one it has holds nothing it can use, so the money ends up on the field.
func check_opponent_spends() -> void:
	BaseballSession.round_number = 5
	var budget := BaseballSession.income()
	var worth := 0
	var signed := 0
	var enemy := shop.build_opponent()
	for index in enemy.field_roles.size():
		var player := enemy.player_at(index)
		if player != null:
			signed += 1
			worth += player.value()
	check(signed == 9, "A run this rich did not fill the field")
	# Nine level ones would be worth 18; anything above that is money that went
	# into merges and snacks rather than into rerolls.
	check(worth > 18, "A rolled team put its money into rerolls instead of its team")
	check(worth <= budget, "A rolled team spent $%d of $%d" % [worth, budget])
	BaseballSession.round_number = 1


## A rolled team shops the same shelf the player does, so a kind the run has not
## reached cannot turn out for it either.
func check_opponent_pool() -> void:
	var kinds := shop.pool.types.duplicate()
	var later := BaseballPlayerType.new()
	later.type_name = "Ace"
	later.from_round = 3
	shop.pool.types.append(later)
	BaseballSession.round_number = 1
	var early := shop.build_opponent()
	for index in early.field_roles.size():
		var player := early.player_at(index)
		if player != null:
			check(player.type != later, "A rolled team signed a kind the round had not opened")
	# With the later kind the only one open, everybody it signs has to be one.
	var only: Array[BaseballPlayerType] = [later]
	shop.pool.types = only
	BaseballSession.round_number = 3
	var late := shop.build_opponent()
	var signed := 0
	for index in late.field_roles.size():
		var player := late.player_at(index)
		if player != null:
			signed += 1
			check(player.type == later, "A rolled team signed a kind that was not on the shelf")
	check(signed > 0, "A rolled team signed nobody from the only kind on offer")
	shop.pool.types = kinds
	BaseballSession.round_number = 1


## Every level up puts on a point of each stat. A kind with growth in it puts on
## that much again for every level it has taken, so the plain player is +2/+2 to
## level two and +3/+3 to level three.
func check_level_growth() -> void:
	var plain: BaseballPlayerType = load("res://data/types/baseball_player.tres")
	var lifter: BaseballPlayerType = load("res://data/types/bodybuilder.tres")
	var dog: BaseballPlayerType = load("res://data/types/dog.tres")
	check(lifter.recruit().strength == 3, "A bodybuilder did not start at three strength")
	check(lifter.recruit().dexterity == 1, "A bodybuilder did not start at one dexterity")
	check(dog.recruit().strength == 1, "A dog did not start at one strength")
	check(dog.recruit().dexterity == 3, "A dog did not start at three dexterity")
	var grown := plain.recruit()
	var start := Vector2i(grown.strength, grown.dexterity)
	grown.gain_level()
	check(
		Vector2i(grown.strength, grown.dexterity) - start == Vector2i(2, 2),
		"A plain player did not gain +2/+2 to level two"
	)
	start = Vector2i(grown.strength, grown.dexterity)
	grown.gain_level()
	check(
		Vector2i(grown.strength, grown.dexterity) - start == Vector2i(3, 3),
		"A plain player did not gain +3/+3 to level three"
	)
	var others: Array[BaseballPlayerType] = [lifter, dog]
	for type in others:
		var other := type.recruit()
		start = Vector2i(other.strength, other.dexterity)
		other.gain_level()
		check(
			Vector2i(other.strength, other.dexterity) - start == Vector2i(1, 1),
			"%s did not take the level everybody gets" % type.type_name
		)


## A kind whose passive is making the most of a snack adds a point of it for every
## level it has, and nothing at all to the other sort.
func check_food_passives() -> void:
	var hot_dog: BaseballFoodType = load("res://data/foods/hot_dog.tres")
	var peanuts: BaseballFoodType = load("res://data/foods/peanuts.tres")
	var plain: BaseballPlayerType = load("res://data/types/baseball_player.tres")
	var lifter: BaseballPlayerType = load("res://data/types/bodybuilder.tres")
	var dog: BaseballPlayerType = load("res://data/types/dog.tres")
	for level in [1, 2, 3]:
		check(
			_fed(plain, hot_dog, level).x == hot_dog.strength_gain,
			"A plain player got more than a hot dog feeds at level %d" % level
		)
		check(
			_fed(lifter, hot_dog, level).x == hot_dog.strength_gain + level,
			"A bodybuilder did not add a level to a hot dog at level %d" % level
		)
		check(
			_fed(dog, peanuts, level).y == peanuts.dexterity_gain + level,
			"A dog did not add a level to peanuts at level %d" % level
		)
	check(
		_fed(lifter, peanuts, 3).y == peanuts.dexterity_gain,
		"A bodybuilder made something of peanuts as well as hot dogs"
	)
	check(
		_fed(dog, hot_dog, 3).x == hot_dog.strength_gain,
		"A dog made something of hot dogs as well as peanuts"
	)
	check(_fed(lifter, hot_dog, 1).y == 0, "A hot dog fed a bodybuilder dexterity as well")


## What one of [param type], levelled to [param level], puts on after eating
## [param food], as strength by dexterity.
func _fed(type: BaseballPlayerType, food: BaseballFoodType, level: int) -> Vector2i:
	var eater := type.recruit()
	for step in level - 1:
		eater.gain_level()
	var before := Vector2i(eater.strength, eater.dexterity)
	eater.eat(food)
	return Vector2i(eater.strength, eater.dexterity) - before


## A coach hands every teammate their own level in both stats as the shop closes,
## keeps nothing back for themselves, and two of them both put their work in.
func check_coaching() -> void:
	var coach: BaseballPlayerType = load("res://data/types/coach.tres")
	var plain: BaseballPlayerType = load("res://data/types/baseball_player.tres")
	var one := _lineup([coach, plain, plain], [1, 1, 1])
	var before := _stats(one)
	one.finish_shopping()
	var after := _stats(one)
	check(after[0] == before[0], "A coach coached themselves")
	check(after[1] - before[1] == Vector2i(1, 1), "A level one coach did not give +1/+1")
	check(after[2] - before[2] == Vector2i(1, 1), "A coach left a teammate out")
	var senior := _lineup([coach, plain], [3, 1])
	before = _stats(senior)
	senior.finish_shopping()
	check(_stats(senior)[1] - before[1] == Vector2i(3, 3), "A level three coach did not give +3/+3")
	var pair := _lineup([coach, coach, plain], [1, 2, 1])
	before = _stats(pair)
	pair.finish_shopping()
	after = _stats(pair)
	check(after[2] - before[2] == Vector2i(3, 3), "Two coaches did not both put their work in")
	check(after[0] - before[0] == Vector2i(2, 2), "A coach was not coached by the other one")
	check(after[1] - before[1] == Vector2i(1, 1), "A coach was not coached by the other one")
	var none := _lineup([plain, plain], [1, 1])
	before = _stats(none)
	none.finish_shopping()
	check(_stats(none) == before, "A team with no coach came out of the shop changed")


## A roster of the given kinds at the given levels, in batting order.
func _lineup(types: Array[BaseballPlayerType], levels: Array[int]) -> BaseballTeamData:
	var team := BaseballTeamData.new()
	team.field_roles = PackedStringArray(["P", "C", "1B", "2B", "3B", "SS", "LF", "CF", "RF"])
	team.players.resize(9)
	for index in types.size():
		var player := types[index].recruit()
		for step in levels[index] - 1:
			player.gain_level()
		team.players[index] = player
	return team


## Every player's stats, in batting order, for comparing before and after.
func _stats(team: BaseballTeamData) -> Array[Vector2i]:
	var stats: Array[Vector2i] = []
	for index in team.players.size():
		var player := team.player_at(index)
		if player != null:
			stats.append(Vector2i(player.strength, player.dexterity))
	return stats
