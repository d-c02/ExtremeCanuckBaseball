class_name BaseballMatch
extends Node2D

# Live-play events are emitted by BaseballLivePlay through the match.
@warning_ignore("unused_signal")
signal ball_hit(quality: float)
@warning_ignore("unused_signal")
signal ball_caught(player: BaseballPlayer)
@warning_ignore("unused_signal")
signal runner_reached_base(player: BaseballPlayer)
signal play_finished(result: String)
signal ball_thrown(origin: Vector2)
@warning_ignore("unused_signal")
signal strike_called(strikeout: bool)
@warning_ignore("unused_signal")
signal foul_called
signal sides_changed
@warning_ignore("unused_signal")
signal home_run
@warning_ignore("unused_signal")
signal run_scored
@warning_ignore("unused_signal")
signal out_recorded(player: BaseballPlayer)
signal half_inning_finished(inning: int, batting_side: int)
signal game_finished(scores: Array[int])

enum Phase {
	READY, PREPARING, PITCH, FIELDING, THROW, TAG, HOME_RUN, SETTLING, RETURNING, FINISHED, FOUL
}
const PLAYER_SCENE = preload("res://game/actors/player.tscn")

@export var visiting_team: BaseballTeamData
@export var home_team: BaseballTeamData
@export var random_seed: int = 42
@export_range(1, 9) var innings: int = 3
@export_range(0.2, 4.0) var between_play_delay: float = 1.8
@export_range(1, 8) var transition_speed: int = 3

var rng := RandomNumberGenerator.new()
var phase: Phase = Phase.READY
var teams: Array[BaseballTeamData] = []
var squads: Array = []
var fielders: Array[BaseballPlayer] = []
var batter: BaseballPlayer
var runners: Array[BaseballBaseRunning] = []
var play: BaseballLivePlay
var base_positions: PackedVector2Array
var scores: Array[int] = [0, 0]
var box_score: BaseballBoxScore
var next_batter: Array[int] = [0, 0]
var batting_side: int = 0
var inning: int = 1
var outs: int = 0
var strikes: int = 0
var pitch_count: int = 0
var phase_elapsed: float = 0.0
var paused: bool = false
var debug_visible: bool = false
var dugout_view: bool = false
var last_result: String = "Space: start game"
var return_ball_time: float = 0.0
var error_message: String = ""

@onready var ball: BaseballBall = $Ball
@onready var home: Marker2D = $Field/Home
@onready var mound: Marker2D = $Field/Mound
@onready var status: Label = $HUD/Status
@onready var outfield: BaseballOutfield = $Field/Outfield
@onready var dugouts: Array[Node2D] = [$Dugouts/Visitors, $Dugouts/Home]


func _ready() -> void:
	teams = [visiting_team, home_team]
	for team in teams:
		if (
			team == null
			or team.players.size() != 9
			or team.field_positions.size() != 9
			or team.field_roles.size() != 9
		):
			simulation_error("Each team needs nine players, field positions, and field roles")
			return
	base_positions = PackedVector2Array(
		[
			$Field/FirstBase.position,
			$Field/SecondBase.position,
			$Field/ThirdBase.position,
			home.position
		]
	)
	for side in 2:
		var squad: Array[BaseballPlayer] = []
		for index in 9:
			var player: BaseballPlayer = PLAYER_SCENE.instantiate()
			$Players.add_child(player)
			player.team_index = side
			player.roster_index = index
			player.configure(teams[side].players[index], teams[side].color)
			squad.append(player)
		squads.append(squad)
	reset_game()


func reset_game() -> void:
	rng.seed = random_seed
	scores = [0, 0]
	box_score = BaseballBoxScore.new(teams)
	next_batter = [0, 0]
	batting_side = 0
	inning = 1
	outs = 0
	strikes = 0
	pitch_count = 0
	runners.clear()
	play = null
	paused = false
	phase = Phase.READY
	phase_elapsed = 0.0
	error_message = ""
	last_result = "Ready: Space starts the whole game"
	for squad in squads:
		for player in squad:
			player.position = dugouts[player.team_index].seat_position(player.roster_index)
			player.stop("In dugout")
			player.bat.visible = false
			player.set_label(str(player.roster_index + 1))
	fielders = squads[1]
	batter = squads[0][0]
	ball.hold_at(mound.position)
	_update_dugouts()
	_refresh_status()


func start_game() -> void:
	if phase != Phase.READY:
		return
	_prepare_pitch()


func _physics_process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if not error_message.is_empty() or paused:
		return
	# Keep movement and collision steps fixed when speeding up transitions.
	var steps := transition_speed if is_fast_forwarding() else 1
	for step_index in steps:
		if step_index > 0 and (not is_fast_forwarding() or not error_message.is_empty()):
			break
		_step_simulation(delta)
	_refresh_status()
	queue_redraw()


func is_fast_forwarding() -> bool:
	return phase == Phase.RETURNING or (phase == Phase.PREPARING and pitch_count > 0)


func _step_simulation(delta: float) -> void:
	for squad in squads:
		for player in squad:
			player.step(delta)
	phase_elapsed += delta
	match phase:
		Phase.PREPARING:
			_step_preparation(delta)
		Phase.PITCH, Phase.FIELDING, Phase.THROW, Phase.TAG, Phase.HOME_RUN, Phase.FOUL:
			play.step(delta)
			if play.done:
				_complete_play()
		Phase.SETTLING:
			if play.holder != null:
				ball.hold_at(play.holder.position)
			if phase_elapsed >= between_play_delay:
				if outs >= 3:
					_end_half()
				elif batting_side == 1 and inning >= innings and scores[1] > scores[0]:
					_finish_game()
				else:
					_prepare_pitch()
		Phase.RETURNING:
			if _everyone_arrived():
				_prepare_pitch()
	if phase in [Phase.PREPARING, Phase.RETURNING] and phase_elapsed > 40.0:
		simulation_error("Players failed to reach their positions")


func _prepare_pitch() -> void:
	phase = Phase.PREPARING
	phase_elapsed = 0.0
	box_score.begin_half(batting_side, inning)
	fielders = squads[1 - batting_side]
	batter = squads[batting_side][next_batter[batting_side]]
	for player in fielders:
		var index := player.roster_index
		player.role = teams[1 - batting_side].field_roles[index]
		player.set_label(player.role)
		player.move_to(teams[1 - batting_side].field_positions[index], "Taking field position")
	for player in squads[batting_side]:
		player.bat.visible = false
		player.set_label("%d %s" % [player.roster_index + 1, player.data.player_name])
		var run := runner_for(player)
		if run != null:
			player.move_to(base_positions[run.reached - 1] + Vector2(10, 9), "Holding base")
		elif player == batter:
			player.move_to(home.position, "Walking to bat")
		elif player.roster_index == (next_batter[batting_side] + 1) % 9:
			_send_on_deck(player)
		else:
			_send_to_dugout(player)
	var origin := ball.position
	return_ball_time = maxf(0.25, origin.distance_to(mound.position) / 400.0)
	ball.launch(
		origin,
		(mound.position - origin) / return_ball_time,
		12.0,
		BaseballBall.GRAVITY * return_ball_time / 2.0
	)
	if pitch_count > 0:
		ball_thrown.emit(origin)
	last_result = "Players getting ready: %s batting" % batter.data.player_name
	_update_dugouts()


func _step_preparation(delta: float) -> void:
	if return_ball_time > 0.0:
		return_ball_time -= delta
		ball.step(delta)
		if return_ball_time <= 0.0:
			ball.hold_at(mound.position)
	if _everyone_arrived() and return_ball_time <= 0.0 and phase_elapsed >= between_play_delay:
		pitch_count += 1
		play = BaseballLivePlay.new(self)
		phase_elapsed = 0.0


func _complete_play() -> void:
	box_score.record_play(self)
	scores[batting_side] += play.pending_runs
	runners = runners.filter(func(run): return not run.retired and not run.scored)
	if play.batter_done:
		next_batter[batting_side] = (next_batter[batting_side] + 1) % 9
		strikes = 0
	phase = Phase.SETTLING
	phase_elapsed = 0.0
	last_result = play.result
	for squad in squads:
		for player in squad:
			player.bat.visible = false
			if player.moving or player.velocity.length() > 0.0:
				player.brake("Play ended")
	play_finished.emit(last_result)
	_update_dugouts()


func _end_half() -> void:
	box_score.teams[batting_side].LOB += runners.size()
	half_inning_finished.emit(inning, batting_side)
	runners.clear()
	if (
		inning >= innings
		and (
			(batting_side == 1 and scores[0] != scores[1])
			or (batting_side == 0 and scores[1] > scores[0])
		)
	):
		_finish_game()
		return
	if batting_side == 1:
		inning += 1
	batting_side = 1 - batting_side
	outs = 0
	strikes = 0
	play = null
	phase = Phase.RETURNING
	phase_elapsed = 0.0
	sides_changed.emit()
	last_result = "Change sides: players returning to their dugouts"
	for squad in squads:
		for player in squad:
			_send_to_dugout(player)
	_update_dugouts()


func _finish_game() -> void:
	box_score.teams[batting_side].LOB += runners.size()
	phase = Phase.FINISHED
	last_result = (
		"Draw"
		if scores[0] == scores[1]
		else "%s wins" % teams[0 if scores[0] > scores[1] else 1].team_name
	)
	for squad in squads:
		for player in squad:
			_send_to_dugout(player)
	game_finished.emit(scores.duplicate())


func runner_for(player: BaseballPlayer) -> BaseballBaseRunning:
	for run in runners:
		if run.runner == player:
			return run
	return null


func camera_runner() -> BaseballBaseRunning:
	var selected: BaseballBaseRunning
	var distance := -1.0
	for run in runners:
		if run.active and not run.retired and not run.scored:
			var candidate := run.runner.position.distance_squared_to(ball.position)
			if candidate > distance:
				distance = candidate
				selected = run
	return selected


func _send_to_dugout(player: BaseballPlayer) -> void:
	player.bat.visible = false
	player.set_label(str(player.roster_index + 1))
	player.move_to(
		dugouts[player.team_index].seat_position(player.roster_index), "Returning to dugout"
	)


func _send_on_deck(player: BaseballPlayer) -> void:
	player.set_label("%d next" % (player.roster_index + 1))
	player.move_to(dugouts[player.team_index].on_deck_position(), "On deck")


func _everyone_arrived() -> bool:
	for squad in squads:
		for player in squad:
			if player.moving:
				return false
	return true


func _update_dugouts() -> void:
	for side in 2:
		dugouts[side].show_order(teams[side], next_batter[side], side == batting_side)


func simulation_error(message: String) -> void:
	error_message = message
	phase = Phase.FINISHED
	status.text = message
	push_error(message)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			start_game()
		KEY_R:
			reset_game()
		KEY_P:
			paused = not paused
			_refresh_status()
		KEY_D:
			debug_visible = not debug_visible
			queue_redraw()
		KEY_H:
			dugout_view = not dugout_view


func _refresh_status() -> void:
	status.text = (
		(
			"%s %d / %d %s | %s %d/%d | %d out(s), %d strike(s)\n%s%s\n"
			+ "Space: start game   P: pause   R: reset   B: box score   "
			+ "H: dugouts   D: targets   C: camera zones"
		)
		% [
			teams[0].team_name,
			scores[0],
			scores[1],
			teams[1].team_name,
			"Top" if batting_side == 0 else "Bottom",
			inning,
			innings,
			outs,
			strikes,
			last_result,
			" [PAUSED]" if paused else ""
		]
	)


func _draw() -> void:
	if not debug_visible:
		return
	for player in fielders:
		if player.moving:
			draw_line(player.position, player.target, Color(1, 1, 1, 0.4), 1.0)
			draw_circle(player.target, 3.0, Color.WHITE)
