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
@warning_ignore("unused_signal")
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
signal game_reset
signal simulation_stepped(steps: int)

enum Phase {
	READY,
	PREPARING,
	RETURN_BALL,
	WINDUP,
	PITCH,
	RECEIVE,
	FIELDING,
	THROW,
	TAG,
	HOME_RUN,
	SETTLING,
	FINISHED,
	FOUL
}
const PLAYER_SCENE = preload("res://game/actors/player.tscn")

@export var visiting_team: BaseballTeamData
@export var home_team: BaseballTeamData
@export var random_seed: int = 0
@export_range(1, 9) var innings: int = 3
@export_range(0.2, 4.0) var between_play_delay: float = 2.2
@export_range(0.3, 4.0) var windup_duration: float = 1.5
@export_range(1, 8) var transition_speed: int = 3

var active_seed: int = 0
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
var last_result: String = "Space: start game"
var ball_return: BaseballBallReturn
var equipment: BaseballEquipment
var error_message: String = ""
## Side that lost by forfeit, or -1.
var forfeit_side: int = -1

@onready var ball: BaseballBall = $Ball
@onready var field: BaseballBallpark = $Field
@onready var home: Marker2D = field.home
@onready var mound: Marker2D = field.mound
@onready var status: Label = $HUD/Status
@onready var outfield: BaseballOutfield = field.outfield
@onready var dugouts: Array[Node2D] = field.dugouts


func _ready() -> void:
	teams = [visiting_team, home_team]
	for team in teams:
		if team == null:
			simulation_error("Both teams need a team Resource")
			return
		var roster_error := team.validation_error()
		if not roster_error.is_empty():
			simulation_error("%s: %s" % [team.team_name, roster_error])
			return
	base_positions = field.base_positions
	for side in 2:
		var squad: Array[BaseballPlayer] = []
		for index in 9:
			var player_data := teams[side].player_at(index)
			if player_data == null:
				continue
			var player: BaseballPlayer = PLAYER_SCENE.instantiate()
			$Players.add_child(player)
			player.team_index = side
			player.roster_index = index
			player.lineup_index = squad.size()
			player.configure(player_data)
			squad.append(player)
		squads.append(squad)
	equipment = BaseballEquipment.new()
	add_child(equipment)
	equipment.configure(self)
	reset_game()


func reset_game(replay: bool = false) -> void:
	if squads.size() != 2:
		return
	if not replay or active_seed == 0:
		if random_seed == 0:
			rng.randomize()
			active_seed = rng.randi_range(1, 2147483647)
		else:
			active_seed = random_seed
	rng.seed = active_seed
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
	forfeit_side = -1
	last_result = "Ready: Space starts the whole game"
	for squad in squads:
		for player in squad:
			player.position = dugouts[player.team_index].seat_position(player.roster_index)
			player.stop("In dugout")
			player.swing_visible = false
			player.set_label(str(player.roster_index + 1))
	fielders = squads[1]
	batter = null if squads[0].is_empty() else squads[0][0]
	ball_return = null
	equipment.reset()
	_refresh_status()
	game_reset.emit()


func start_game() -> void:
	if phase != Phase.READY:
		return
	if not _forfeit_half():
		_prepare_pitch()


func _physics_process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if not error_message.is_empty() or paused:
		simulation_stepped.emit(0)
		return
	# Keep movement and collision steps fixed when speeding up transitions.
	var steps := transition_speed if is_fast_forwarding() else 1
	var completed_steps := 0
	for step_index in steps:
		if step_index > 0 and (not is_fast_forwarding() or not error_message.is_empty()):
			break
		_step_simulation(delta)
		completed_steps += 1
	simulation_stepped.emit(completed_steps)
	_refresh_status()


func is_fast_forwarding() -> bool:
	return phase == Phase.PREPARING and pitch_count > 0


func _step_simulation(delta: float) -> void:
	for squad in squads:
		for player in squad:
			player.step(delta)
	equipment.step(delta)
	phase_elapsed += delta
	match phase:
		Phase.PREPARING, Phase.RETURN_BALL:
			_step_preparation(delta)
		_ when play != null and not play.done and phase != Phase.FINISHED:
			play.step(delta)
			if play.done:
				_complete_play()
		Phase.SETTLING, Phase.FINISHED:
			if play != null and play.holder != null:
				ball.hold_at(play.holder.position)
			else:
				ball.step(delta)
			if phase == Phase.SETTLING and phase_elapsed >= between_play_delay:
				if outs >= 3:
					_end_half()
				elif batting_side == 1 and inning >= innings and scores[1] > scores[0]:
					_finish_game()
				elif not _skip_to_free_batter():
					_end_half()
				else:
					_prepare_pitch()
	if phase == Phase.PREPARING and phase_elapsed > 40.0:
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
		player.move_via(
			dugouts[player.team_index].route_out(player.position, field_position(player)),
			"Taking field position"
		)
	for player in squads[batting_side]:
		player.swing_visible = false
		player.set_label("%d %s" % [player.roster_index + 1, player.data.player_name])
		var run := runner_for(player)
		if run != null:
			player.move_to(base_positions[run.reached - 1] + Vector2(10, 9), "Holding base")
		elif player == batter:
			player.move_via(
				equipment.batting_route(player, home.position + Vector2(25, 0)), "Walking to bat"
			)
		elif player.lineup_index == (next_batter[batting_side] + 1) % squads[batting_side].size():
			_send_on_deck(player)
		else:
			_send_to_dugout(player)
	ball_return = BaseballBallReturn.new(self, play.holder if play != null else null)
	last_result = "Players getting ready: %s batting" % batter.data.player_name


## A short lineup can wrap around to hitters still on base; they keep running
## and the order passes to the next hitter. False when everyone is on base.
func _skip_to_free_batter() -> bool:
	var squad: Array = squads[batting_side]
	for attempt in squad.size():
		if runner_for(squad[next_batter[batting_side]]) == null:
			return true
		next_batter[batting_side] = (next_batter[batting_side] + 1) % squad.size()
	return false


func _step_preparation(delta: float) -> void:
	ball_return.step(delta)
	if (
		ball_return.ready
		and _everyone_arrived()
		and equipment.bat_for(batter).carrier == batter
		and phase_elapsed >= between_play_delay
	):
		pitch_count += 1
		play = BaseballLivePlay.new(self)
		phase_elapsed = 0.0


func _complete_play() -> void:
	box_score.record_play(self)
	scores[batting_side] += play.pending_runs
	runners = runners.filter(func(run): return not run.retired and not run.scored)
	if play.batter_done:
		next_batter[batting_side] = (next_batter[batting_side] + 1) % squads[batting_side].size()
		strikes = 0
	phase = Phase.SETTLING
	phase_elapsed = 0.0
	last_result = play.result
	for squad in squads:
		for player in squad:
			player.swing_visible = false
			if player.moving or player.velocity.length() > 0.0:
				player.brake("Play ended")
	play_finished.emit(last_result)


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
	if _forfeit_half():
		return
	_prepare_pitch()
	last_result = "Change sides: %s taking the field" % teams[1 - batting_side].team_name
	sides_changed.emit()


## A defense without a pitcher or catcher cannot field the half, so the batting
## team wins by default. A batting team with nobody to send up forfeits instead.
func _forfeit_half() -> bool:
	var offense := teams[batting_side]
	var defense := teams[1 - batting_side]
	if not defense.has_role("P") or not defense.has_role("C"):
		forfeit_side = 1 - batting_side
		var missing := "pitcher" if not defense.has_role("P") else "catcher"
		var reason := "%s has no %s" % [defense.team_name, missing]
		_finish_game("%s wins by forfeit: %s" % [offense.team_name, reason])
		return true
	if squads[batting_side].is_empty():
		forfeit_side = batting_side
		var reason := "%s has no batters" % offense.team_name
		_finish_game("%s wins by forfeit: %s" % [defense.team_name, reason])
		return true
	return false


func winner() -> int:
	if forfeit_side >= 0:
		return 1 - forfeit_side
	return -1 if scores[0] == scores[1] else (0 if scores[0] > scores[1] else 1)


func _finish_game(result: String = "") -> void:
	box_score.teams[batting_side].LOB += runners.size()
	phase = Phase.FINISHED
	last_result = result
	if result.is_empty():
		last_result = "Draw" if winner() < 0 else "%s wins" % teams[winner()].team_name
	for squad in squads:
		for player in squad:
			_send_to_dugout(player)
	game_finished.emit(scores.duplicate())


func runner_for(player: BaseballPlayer) -> BaseballBaseRunning:
	for run in runners:
		if run.runner == player:
			return run
	return null


func field_position(player: BaseballPlayer) -> Vector2:
	var point: Vector2 = teams[player.team_index].field_positions[player.roster_index]
	match player.role:
		"P":
			return point + mound.position
		"C":
			return point + home.position - Vector2(0, 220)
		"1B":
			return point + base_positions[0] - Vector2(220, 0)
		"2B", "SS":
			return point + base_positions[1] - Vector2(0, -220)
		"3B":
			return point + base_positions[2] - Vector2(-220, 0)
		_:
			var offset := point - Vector2(0, 220)
			offset *= Vector2(
				(outfield.flat_half_width + outfield.corner_radius) / 800.0,
				outfield.fence_distance / 950.0
			)
			return outfield.clamp_inside(home.position + offset)


func fielder_for(role: String) -> BaseballPlayer:
	for player in fielders:
		if teams[player.team_index].field_roles[player.roster_index] == role:
			return player
	return null


func _send_to_dugout(player: BaseballPlayer) -> void:
	player.swing_visible = false
	player.set_label(str(player.roster_index + 1))
	player.move_via(
		dugouts[player.team_index].route_in(player.position, player.roster_index),
		"Returning to dugout"
	)


func _send_on_deck(player: BaseballPlayer) -> void:
	player.set_label("%d next" % (player.roster_index + 1))
	player.move_via(
		equipment.batting_route(player, dugouts[player.team_index].on_deck_position()), "On deck"
	)


func _everyone_arrived() -> bool:
	for squad in squads:
		for player in squad:
			if player.moving:
				return false
	return true


func simulation_error(message: String) -> void:
	error_message = message
	phase = Phase.FINISHED
	status.text = message
	push_error(message)


func _unhandled_key_input(event: InputEvent) -> void:
	if box_score == null:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			start_game()
		KEY_R:
			reset_game(event.shift_pressed)
		KEY_P:
			paused = not paused
			_refresh_status()
		KEY_D:
			debug_visible = not debug_visible


func _refresh_status() -> void:
	status.text = (
		(
			"%s %d / %d %s | %s %d/%d | %d out(s), %d strike(s)\n%s%s\n"
			+ "Space: play   P: pause   R: new   Shift+R: replay   B: score   "
			+ "D/C: guides"
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
			last_result + " · seed %d" % active_seed,
			" [PAUSED]" if paused else ""
		]
	)
