class_name BaseballEquipment
extends Node2D

var game: BaseballMatch
var bats: Array[BaseballBat] = []
var attendants: Array[BaseballPlayer] = []
var jobs: Array[BaseballBat] = [null, null]
var balls: Array[BaseballBall] = []
var used_balls: Array[BaseballBall] = []
var stock_index: int = 0


func configure(match_scene: BaseballMatch) -> void:
	game = match_scene
	for side in 2:
		for player in game.squads[side]:
			var bat := BaseballBat.new()
			bat.owner_player = player
			bat.rack = game.dugouts[side].seat_position(player.roster_index)
			add_child(bat)
			bats.append(bat)
		var attendant: BaseballPlayer = game.PLAYER_SCENE.instantiate()
		add_child(attendant)
		attendant.configure(BaseballPlayerData.new())
		attendant.team_index = side
		attendant.set_label("KIT")
		attendants.append(attendant)
	balls.append(game.ball)
	for index in 127:
		var spare := BaseballBall.new()
		add_child(spare)
		balls.append(spare)


func reset() -> void:
	stock_index = 0
	used_balls.clear()
	game.ball = balls[0]
	for index in balls.size():
		var point := (
			game.home.position + Vector2(95 + (index % 8) * 6, 100 + (floori(index / 8.0) % 4) * 6)
		)
		balls[index].hold_at(point)
		balls[index].height = 3.0 + floori(index / 32.0) * 6.0
	for bat in bats:
		bat.reset()
	for side in 2:
		attendants[side].position = game.dugouts[side].seat_position(4)
		attendants[side].stop("Equipment duty")
		jobs[side] = null
	game.ball.held = false


func bat_for(player: BaseballPlayer) -> BaseballBat:
	return bats[player.team_index * 9 + player.roster_index]


func batting_route(player: BaseballPlayer, destination: Vector2) -> PackedVector2Array:
	var dugout = game.dugouts[player.team_index]
	var bat := bat_for(player)
	if bat.carrier == player:
		return dugout.route_out(player.position, destination)
	var route: PackedVector2Array = dugout.route_in(player.position, player.roster_index)
	route.append_array(dugout.route_out(bat.rack, destination))
	return route


func step(delta: float) -> void:
	for ball in used_balls:
		ball.step(delta)
	for bat in bats:
		bat.step(delta)
		var player := bat.owner_player
		if bat.carrier == player and player in game.fielders:
			bat.carrier = null
			bat.dropping = true
		if bat.carrier == player and player.position.distance_to(bat.rack) < 8.0:
			bat.reset()
		if (
			bat.carrier == null
			and bat.position.distance_to(bat.rack) < 5.0
			and player.position.distance_to(bat.position) < 12.0
			and player.intention in ["Walking to bat", "On deck"]
		):
			bat.carrier = player
	for side in 2:
		_step_attendant(side, delta)


func _step_attendant(side: int, delta: float) -> void:
	var attendant := attendants[side]
	attendant.step(delta)
	var bat := jobs[side]
	if bat != null:
		if attendant.moving:
			return
		if bat.carrier == attendant:
			bat.reset()
			jobs[side] = null
		else:
			bat.carrier = attendant
			attendant.move_via(
				game.dugouts[side].route_in(attendant.position, bat.owner_player.roster_index),
				"Returning bat"
			)
		return
	if game.phase not in [game.Phase.PREPARING, game.Phase.RETURN_BALL, game.Phase.FINISHED]:
		return
	for candidate in bats:
		if (
			candidate.owner_player.team_index != side
			or candidate.carrier != null
			or candidate.dropping
		):
			continue
		if candidate.position.distance_to(candidate.rack) <= 5.0:
			continue
		jobs[side] = candidate
		attendant.move_via(
			game.dugouts[side].route_out(attendant.position, candidate.position), "Collecting bat"
		)
		return


func issue_ball() -> void:
	used_balls.append(game.ball)
	stock_index += 1
	if stock_index >= balls.size():
		game.simulation_error("Ball supply exhausted")
		return
	game.ball = balls[stock_index]
	game.ball.held = false
