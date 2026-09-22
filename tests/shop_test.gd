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
	var screen: Node = load("res://game/buy_screen.tscn").instantiate()
	root.add_child(screen)
	shop = screen
	# Roll the stock from a fixed seed so a failure can be repeated.
	shop.rng.seed = 9
	shop.refresh_stock()
	await settle()
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
	await check_roster_ready()
	await check_opponent()
	quit(1 if failures > 0 else 0)


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


## Refreshing rolls a whole new shelf, priced by the stats the players were given.
func check_refresh() -> void:
	var before: Array[BaseballPlayerData] = []
	for podium in shop.podiums():
		var sold := podium.listing as PlayerSlot
		before.append(sold.player if sold != null else null)
	var button: Button = shop.get_node("HUD/Refresh")
	button.pressed.emit()
	await settle()
	for index in shop.podiums().size():
		var rolled := listing(index)
		check(rolled != null, "A podium came back from a refresh empty")
		check(rolled.player != before[index], "A refresh kept the same player on a podium")
		check(rolled.cost == rolled.player.value(), "A rolled player was not priced on stats")
		check(
			rolled.player.sell_price() < rolled.cost, "A rolled player sold for the asking price"
		)


## The team rolled to play against the shop roster is worth about the same, and
## always has somebody to pitch and somebody to catch.
func check_opponent() -> void:
	var signed := 0
	var worth := 0
	for index in shop.roster.field_roles.size():
		var player := shop.roster.player_at(index)
		if player != null:
			signed += 1
			worth += player.value()
	check(signed > 0, "The roster was empty, so there was nothing to match")
	var enemy := shop.build_opponent()
	check(
		enemy.validation_error().is_empty(),
		"The rolled opponent was rejected: " + enemy.validation_error()
	)
	check(enemy.has_role("P"), "The rolled opponent had nobody to pitch")
	check(enemy.has_role("C"), "The rolled opponent had nobody to catch")
	var enemy_worth := 0
	var enemy_signed := 0
	for index in enemy.field_roles.size():
		var player := enemy.player_at(index)
		if player != null:
			enemy_signed += 1
			enemy_worth += player.value()
	check(enemy_signed == signed, "The rolled opponent did not field as many players")
	check(
		absi(enemy_worth - worth) <= enemy_signed,
		"The rolled opponent was worth %d against %d" % [enemy_worth, worth]
	)
	BaseballSession.carry(shop.roster, enemy)
	check(BaseballSession.ready_to_play(), "The session did not take the teams to the match")
	var start: Button = shop.get_node("HUD/Start")
	check(not start.pressed.get_connections().is_empty(), "The start button went nowhere")
	BaseballSession.clear()


## Two of a kind merge rather than crowd a slot: the same level is a level up on
## its own, and a level below counts half, so the second one finishes the job.
func check_merging() -> void:
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
	check(
		slot.occupant.level_label.text == "Lv 2½", "The badge did not show the half merge"
	)
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


## Players already signed merge the same way, and the slot the carried one left
## stands empty afterwards.
func check_signed_merging() -> void:
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
