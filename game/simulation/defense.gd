class_name BaseballDefense
extends RefCounted

const REASSESS_INTERVAL: float = 0.15

var game: BaseballMatch
var fielders: Array[BaseballPlayer] = []
var chaser: BaseballPlayer
var receiver: BaseballPlayer
var backup: BaseballPlayer
var reassess_remaining: float = 0.0
var reads: Dictionary = {}
var elapsed: float = 0.0


func _init(match_scene: BaseballMatch) -> void:
	game = match_scene
	fielders = game.fielders


func assign() -> void:
	var trajectory: Array[Dictionary] = game.outfield.forecast_path(game.ball, 6.0)
	for player in fielders:
		var read := BaseballFieldingRead.new(game.rng)
		read.update(player, game, 0.0, trajectory)
		reads[player] = read
	_reassign(true)
	reassess_remaining = REASSESS_INTERVAL


func step(delta: float) -> void:
	elapsed += delta
	reassess_remaining -= delta
	if reassess_remaining <= 0.0:
		var trajectory: Array[Dictionary] = game.outfield.forecast_path(game.ball, 6.0)
		for player in fielders:
			reads[player].update(player, game, REASSESS_INTERVAL - reassess_remaining, trajectory)
		_reassign(false)
		reassess_remaining = REASSESS_INTERVAL


func pursuit_score(player: BaseballPlayer) -> float:
	if game.ball.bounced and player.position.distance_to(game.ball.position) <= 20.0:
		return -1.0 + player.position.distance_to(game.ball.position) / player.data.speed
	var read: BaseballFieldingRead = reads[player]
	var arrival := (
		player.position.distance_to(read.target) / player.data.speed + player.reaction_remaining
	)
	var station: Vector2 = game.teams[1 - game.batting_side].field_positions[player.roster_index]
	var departure_cost := minf(maxf(station.distance_to(read.target) - 180.0, 0.0) / 450.0, 1.5)
	var nearby_weight := clampf(player.position.distance_to(game.ball.position) / 120.0, 0.0, 1.0)
	return (
		maxf(arrival, read.playable_in)
		+ departure_cost * nearby_weight
		- (0.25 if player == chaser else 0.0)
	)


func idle_target(player: BaseballPlayer, anchor: Vector2) -> Vector2:
	if player.data.idle_behavior == BaseballPlayerData.IdleBehavior.STILL:
		return anchor
	return anchor + Vector2(sin(elapsed * 1.3 + player.roster_index * 1.7) * 8.0, 0.0)


func _reassign(initial: bool) -> void:
	var ranked: Array[BaseballPlayer] = fielders.duplicate()
	ranked.sort_custom(func(a, b): return pursuit_score(a) < pursuit_score(b))
	chaser = ranked[0]
	var read: BaseballFieldingRead = reads[chaser]
	var point := read.target
	var helper: BaseballPlayer = ranked[1]
	var arrival := (
		chaser.position.distance_to(point) / chaser.data.speed + chaser.reaction_remaining
	)
	var recovering: bool = game.play != null and game.play.catch_retries.get(chaser, 0.0) > 0.0
	var covered: bool = (
		arrival < 0.4
		or (
			not game.ball.bounced
			and arrival + 0.2 < read.playable_in
			and chaser.data.anticipation >= 0.55
		)
	)
	backup = null
	if not covered or recovering:
		if helper.position.distance_to(point) < 320.0:
			backup = helper
	var excluded: Array = [chaser]
	if backup != null:
		excluded.append(backup)
	receiver = nearest(game.base_positions[0], excluded)
	excluded.append(receiver)
	var second := nearest(game.base_positions[1], excluded)
	for player in fielders:
		var station: Vector2 = game.teams[1 - game.batting_side].field_positions[
			player.roster_index
		]
		var destination := idle_target(player, station)
		var action := "Holding position"
		if player == chaser:
			destination = reads[player].target
			action = "Intercepting ball"
		elif player == backup:
			if game.ball.bounced and player.position.distance_to(game.ball.position) < 55.0:
				destination = reads[player].target
				action = "Collecting loose ball"
			else:
				var behind: Vector2 = point + game.home.position.direction_to(point) * 75.0
				destination = station + (behind - station).limit_length(140.0)
				action = "Backing up catch"
		elif player == receiver:
			destination = idle_target(player, game.base_positions[0] + Vector2(-10, -7))
			action = "Covering first"
		elif player == second and game.runners.size() > 1:
			destination = idle_target(player, game.base_positions[1] + Vector2(-10, -7))
			action = "Covering second"
		destination = game.outfield.clamp_inside(destination)
		if initial:
			player.move_to(destination, action, player.data.reaction_time)
		else:
			player.target = destination
			player.intention = action
			player.moving = player.moving or player.position.distance_to(destination) > 3.0


func nearest(point: Vector2, excluded: Array) -> BaseballPlayer:
	var selected: BaseballPlayer
	var best_time := INF
	for player in fielders:
		if player in excluded:
			continue
		var arrival := (
			player.position.distance_to(point) / player.data.speed + player.data.reaction_time
		)
		if arrival < best_time:
			selected = player
			best_time = arrival
	return selected
