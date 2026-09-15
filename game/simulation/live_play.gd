class_name BaseballLivePlay
extends RefCounted

const PITCH_DURATION: float = 0.85
var game: BaseballMatch
var defense: BaseballDefense
var batter_run: BaseballBaseRunning
var target_runner: BaseballBaseRunning
var holder: BaseballPlayer
var throw_base: int = 1
var timer: float = 0.0
var elapsed: float = 0.0
var swing_time: float
var aim_error: float
var throw_started: bool = false
var ground_released: bool = false
var catch_retries: Dictionary = {}
var pending_runs: int = 0
var done: bool = false
var batter_done: bool = true
var result: String = ""
var is_home_run: bool = false
var fly_caught: bool = false
var outs_made: int = 0
var strikeout: bool = false
var ground_double_play: bool = false
var force_outs: int = 0
var hit_limit: int = 4
var scoring_order: Array[BaseballPlayer] = []


func _init(match_scene: BaseballMatch) -> void:
	game = match_scene
	defense = BaseballDefense.new(game)
	for run in game.runners:
		run.start_base = run.reached
		run.awarded_base = 0
		run.returning = false
		run.contact_judgement = game.rng.randfn(0.0, lerpf(0.8, 0.05, run.runner.data.anticipation))
	var spread := lerpf(0.18, 0.025, game.batter.data.hitting)
	swing_time = PITCH_DURATION + game.rng.randfn(0.0, spread)
	aim_error = game.rng.randfn(0.0, lerpf(1.0, 0.18, game.batter.data.hitting))
	game.ball.launch(
		game.mound.position, (game.home.position - game.mound.position) / PITCH_DURATION, 12.0, 0.0
	)
	game.batter.show_swing(0.0)
	game.phase = game.Phase.PITCH
	game.ball_thrown.emit(game.mound.position)
	game.last_result = "Pitch to %s" % game.batter.data.player_name


func step(delta: float) -> void:
	if done:
		return
	timer += delta
	elapsed += delta
	if game.phase == game.Phase.PITCH:
		game.ball.position = game.mound.position.lerp(game.home.position, timer / PITCH_DURATION)
		game.ball.update_visuals()
		game.batter.show_swing((timer - swing_time + 0.12) / 0.24)
		if timer >= swing_time:
			_resolve_swing()
		return
	if game.phase == game.Phase.FOUL:
		game.ball.step(delta)
		game.outfield.check_crossing(game.ball)
		if timer >= 1.5:
			_end("Foul: %d strike(s)" % game.strikes)
		return
	if game.phase != game.Phase.HOME_RUN:
		game.ball.step(delta)
	if game.phase == game.Phase.FIELDING:
		var crossing: String = game.outfield.check_crossing(game.ball)
		if crossing == "home_run":
			award_home_run()
		elif crossing == "wall":
			game.last_result = "Off the wall!"
		if game.ball.bounced:
			ground_released = true
	for run in game.runners:
		if run.retired or run.scored:
			continue
		var previous: int = run.reached
		run.step()
		if run.reached != previous:
			_on_base(run)
		if done:
			return
	_check_walk_off()
	if done:
		return
	if game.phase == game.Phase.HOME_RUN:
		if _active_runners().is_empty():
			_end("Home run! %d run(s)" % pending_runs)
	elif game.phase == game.Phase.FIELDING:
		if ground_released and not fly_caught:
			_advance_runners()
		_step_fielding(delta)
	elif game.phase == game.Phase.THROW:
		_step_throw()
	elif game.phase == game.Phase.TAG:
		_step_tag()
	if elapsed > 45.0 and not done:
		game.simulation_error("Live play stalled")


func _resolve_swing() -> void:
	var timing_error := (swing_time - PITCH_DURATION) / 0.16
	var quality := clampf(1.0 - absf(timing_error) * 0.55 - absf(aim_error) * 0.35, 0, 1)
	if absf(timing_error) > 1.0 or absf(aim_error) > 1.4:
		game.strikes += 1
		batter_done = game.strikes >= 3
		game.strike_called.emit(batter_done)
		if batter_done:
			strikeout = true
			outs_made = 1
			var fielding_side := 1 - game.batting_side
			var catcher_index := game.teams[fielding_side].field_roles.find("C")
			game.box_score.teams[fielding_side].players[catcher_index].PO += 1
			game.outs += 1
			game.batter.set_label("%d OUT" % (game.batter.roster_index + 1))
			game.out_recorded.emit(game.batter)
		_end("Strikeout" if batter_done else "Swing and miss: strike %d" % game.strikes)
		return
	var angle := timing_error * 1.15 + aim_error * 0.35
	if absf(angle) > PI / 4.0:
		game.strikes = mini(2, game.strikes + 1)
		batter_done = false
		game.ball.launch(game.home.position, Vector2.UP.rotated(angle) * 320.0, 10.0, 130.0)
		game.batter.bat.visible = false
		game.phase = game.Phase.FOUL
		game.last_result = "Foul ball!"
		game.foul_called.emit()
		timer = 0.0
		return
	angle = clampf(angle + game.rng.randf_range(-0.5, 0.5), -0.77, 0.77)
	var power: float = game.batter.data.batting_power * lerpf(0.65, 1.6, quality)
	var lift: float = game.rng.randf_range(180.0, 410.0)
	if game.rng.randf() < 0.3:
		lift = game.rng.randf_range(20.0, 80.0)
	game.ball.launch(game.home.position, Vector2.UP.rotated(angle) * power, 10.0, lift)
	game.batter.bat.visible = false
	batter_run = BaseballBaseRunning.new()
	batter_run.reset(game.batter, game.base_positions)
	game.runners.append(batter_run)
	batter_run.advance(game.batter.data.reaction_time)
	defense.assign()
	_advance_on_contact()
	game.phase = game.Phase.FIELDING
	timer = 0.0
	game.ball_hit.emit(quality)
	game.last_result = "Fair hit: %s fielding" % defense.chaser.role


func _advance_on_contact() -> void:
	var ball: BaseballBall = game.ball
	var flight := (
		(
			ball.vertical_velocity
			+ sqrt(
				(
					ball.vertical_velocity * ball.vertical_velocity
					+ 2.0 * BaseballBall.GRAVITY * ball.height
				)
			)
		)
		/ BaseballBall.GRAVITY
	)
	var prediction: Dictionary = game.outfield.forecast(ball, flight)
	var landing: Vector2 = prediction.point
	var fielder := defense.nearest(landing, [])
	var arrival := (
		fielder.position.distance_to(landing) / fielder.data.speed + fielder.data.reaction_time
	)
	var ordered: Array = game.runners.duplicate()
	ordered.sort_custom(func(a, b): return a.reached > b.reached)
	for run in ordered:
		if run == batter_run or run.active or run.retired or run.scored:
			continue
		var expects_drop: bool = (
			prediction.home_run or flight < 0.55 or arrival + run.contact_judgement > flight + 0.2
		)
		if _base_available(run.reached + 1, run) and (game.outs == 2 or expects_drop):
			run.advance(run.runner.data.reaction_time)
		elif arrival + run.contact_judgement > flight - 0.5:
			var base: Vector2 = game.base_positions[run.reached - 1] + Vector2(10, 9)
			var next: Vector2 = game.base_positions[run.reached] + Vector2(10, 9)
			run.runner.move_to(
				base.move_toward(next, 55.0),
				"Reading fly: short lead",
				run.runner.data.reaction_time
			)


func _advance_runners() -> void:
	var ordered: Array = game.runners.duplicate()
	ordered.sort_custom(func(a, b): return a.reached > b.reached)
	for run in ordered:
		if run.retired or run.scored or run.active or run.reached >= 4:
			continue
		if _base_available(run.reached + 1, run) and (is_forced(run) or _worth_advancing(run)):
			run.advance()


func _base_available(index: int, runner: BaseballBaseRunning) -> bool:
	if index == 4:
		return true
	for other in game.runners:
		if other == runner or other.retired or other.scored:
			continue
		if (
			(other.active and other.target_base == index)
			or (not other.active and other.reached == index)
		):
			return false
	return true


func is_forced(run: BaseballBaseRunning) -> bool:
	if run.retired or run.scored or run.reached > run.start_base:
		return false
	for required in range(run.start_base):
		var found := false
		for other in game.runners:
			if other.start_base == required and not other.retired and not other.scored:
				found = true
		if not found:
			return false
	return true


func _worth_advancing(run: BaseballBaseRunning) -> bool:
	var next_base: Vector2 = game.base_positions[run.reached]
	var fielder := defense.nearest(game.ball.position, [])
	var run_time := run.runner.position.distance_to(next_base) / run.runner.data.speed
	var pickup_time: float = fielder.position.distance_to(game.ball.position) / fielder.data.speed
	var throw_time: float = game.ball.position.distance_to(next_base) / fielder.data.throwing_speed
	return run_time < pickup_time + throw_time + fielder.data.reaction_time + 0.5


func _step_fielding(delta: float) -> void:
	defense.step(delta)
	if game.last_result.begins_with("Fair hit"):
		game.last_result = "Fair hit: %s pursuing" % defense.chaser.role
	for player in catch_retries:
		catch_retries[player] = maxf(0.0, catch_retries[player] - delta)
	var candidates: Array[BaseballPlayer] = game.fielders.duplicate()
	candidates.sort_custom(
		func(a, b):
			return (
				a.position.distance_squared_to(game.ball.position)
				< b.position.distance_squared_to(game.ball.position)
			)
	)
	for player in candidates:
		if (
			player.reaction_remaining > 0
			or catch_retries.get(player, 0.0) > 0.0
			or not within_reach(player)
		):
			continue
		if game.rng.randf() > lerpf(0.45, 0.98, player.data.fielding):
			catch_retries[player] = 0.65
			game.box_score.teams[player.team_index].players[player.roster_index].bobbles += 1
			game.last_result = "%s bobbled it" % player.data.player_name
			continue
		holder = player
		holder.brake("Caught ball")
		game.ball.hold_at(holder.position)
		game.ball_caught.emit(holder)
		if not game.ball.bounced:
			fly_caught = true
			pending_runs = 0
			scoring_order.clear()
			retire_runner(batter_run, true)
			if not done:
				for run in game.runners:
					if run != batter_run and not run.retired:
						run.return_to_start()
				_choose_throw()
		else:
			_choose_throw()
		return


func _out_base(run: BaseballBaseRunning) -> int:
	return run.start_base if run.returning else run.target_base


func _base_out_available(run: BaseballBaseRunning) -> bool:
	return is_forced(run) or run.returning


func _safe_on_base(run: BaseballBaseRunning) -> bool:
	if run.reached == 0 or _base_out_available(run):
		return false
	return (
		run.runner.position.distance_to(game.base_positions[run.reached - 1] + Vector2(10, 9))
		<= 5.0
	)


func _try_immediate_out(candidates: Array[BaseballBaseRunning]) -> bool:
	for run in candidates:
		var destination: Vector2 = game.base_positions[_out_base(run) - 1]
		var base_out := (
			_base_out_available(run) and holder.position.distance_to(destination) <= 16.0
		)
		var tag_out := (
			not _safe_on_base(run) and holder.position.distance_to(run.runner.position) <= 21.0
		)
		if not base_out and not tag_out:
			continue
		target_runner = run
		_limit_hit_on_choice(run)
		throw_base = _out_base(run)
		holder.brake("Recorded out")
		retire_runner(run, is_forced(run))
		return true
	return false


func _choose_throw() -> void:
	var candidates := _active_runners()
	if _try_immediate_out(candidates):
		if not done:
			_choose_throw()
		return
	if candidates.is_empty():
		if outs_made > 0:
			_end("%d out(s) on the play" % outs_made)
		else:
			_end("Caught: runners retouched" if fly_caught else "Play complete: runners safe")
		return
	var best_score := -INF
	var carry := false
	for run in candidates:
		var destination: Vector2 = game.base_positions[_out_base(run) - 1]
		var run_time: float = run.runner.position.distance_to(destination) / run.runner.data.speed
		var receiver := defense.nearest(destination, [holder])
		var receiver_time := (
			receiver.position.distance_to(destination) / receiver.data.speed
			+ receiver.reaction_remaining
		)
		var flight_time := holder.position.distance_to(destination) / holder.data.throwing_speed
		var throw_time := maxf(holder.data.reaction_time + 0.2 + flight_time, receiver_time)
		var carry_distance := (
			holder.position.distance_to(destination)
			if _base_out_available(run)
			else holder.position.distance_to(run.runner.position)
		)
		var carry_time := (
			maxf(0.0, carry_distance - (16.0 if _base_out_available(run) else 21.0))
			/ holder.data.speed
		)
		if not _base_out_available(run):
			carry_time = (
				maxf(0.0, carry_distance - 21.0)
				/ maxf(20.0, holder.data.speed - run.runner.data.speed * 0.7)
			)
		var use_carry := carry_time <= throw_time
		var out_time := minf(carry_time, throw_time)
		var margin := run_time - out_time
		# Favor a quick attainable out over a long trip with a large time cushion.
		var score := minf(margin, 0.75) - out_time * 0.35
		if score > best_score:
			best_score = score
			target_runner = run
			defense.receiver = receiver
			carry = use_carry
	_limit_hit_on_choice(target_runner)
	throw_base = _out_base(target_runner)
	throw_started = false
	timer = 0.0
	if carry:
		game.phase = game.Phase.TAG
		game.last_result = (
			"Taking %s out at %s"
			% [target_runner.runner.data.player_name, BaseballBaseRunning.base_name(throw_base)]
		)
		_step_tag()
	else:
		defense.receiver.move_to(
			game.base_positions[throw_base - 1] + Vector2(-10, -7),
			"Covering %s" % BaseballBaseRunning.base_name(throw_base)
		)
		game.phase = game.Phase.THROW


func _step_throw() -> void:
	if not throw_started:
		game.ball.hold_at(holder.position)
		if _try_immediate_out(_active_runners()):
			if not done:
				_choose_throw()
			return
		if timer < holder.data.reaction_time + 0.2:
			return
		var destination: Vector2 = game.base_positions[throw_base - 1]
		var travel_time := holder.position.distance_to(destination) / holder.data.throwing_speed
		game.ball.launch(
			holder.position,
			holder.position.direction_to(destination) * holder.data.throwing_speed,
			12.0,
			BaseballBall.GRAVITY * travel_time / 2.0
		)
		game.ball_thrown.emit(holder.position)
		game.last_result = "Throw to %s" % BaseballBaseRunning.base_name(throw_base)
		throw_started = true
		return
	if within_reach(defense.receiver):
		holder = defense.receiver
		game.ball.hold_at(holder.position)
		game.ball_caught.emit(holder)
		if (
			target_runner.retired
			or target_runner.scored
			or (not target_runner.returning and target_runner.reached >= throw_base)
		):
			_choose_throw()
		else:
			game.phase = game.Phase.TAG
			_step_tag()
	elif game.ball.bounced:
		holder = null
		game.phase = game.Phase.FIELDING
		defense.step(BaseballDefense.REASSESS_INTERVAL)


func _step_tag() -> void:
	game.ball.hold_at(holder.position)
	if (
		target_runner.retired
		or target_runner.scored
		or (not target_runner.returning and target_runner.reached >= throw_base)
	):
		_choose_throw()
		return
	if _try_immediate_out(_active_runners()):
		if not done:
			_choose_throw()
		return
	var forced := _base_out_available(target_runner)
	var destination: Vector2 = game.base_positions[throw_base - 1]
	holder.target = destination if forced else target_runner.runner.position
	holder.moving = true


func retire_runner(run: BaseballBaseRunning, force_out: bool) -> void:
	if run == null or run.retired:
		return
	outs_made += 1
	if holder != null:
		game.box_score.teams[holder.team_index].players[holder.roster_index].PO += 1
	if force_out and not fly_caught:
		force_outs += 1
	ground_double_play = not fly_caught and outs_made >= 2 and force_outs > 0
	run.retired = true
	run.active = false
	run.runner.brake("Out")
	run.runner.set_label("%d OUT" % (run.runner.roster_index + 1))
	game.outs += 1
	game.out_recorded.emit(run.runner)
	if game.outs >= 3:
		if force_out or (run == batter_run and run.reached == 0):
			pending_runs = 0
		_end("Three outs: change sides")


func _on_base(run: BaseballBaseRunning) -> void:
	game.runner_reached_base.emit(run.runner)
	if run.reached == 4:
		run.scored = true
		run.active = false
		pending_runs += 1
		scoring_order.append(run.runner)
		game.run_scored.emit()
	_check_walk_off()


func _check_walk_off() -> void:
	if (
		is_home_run
		or not ground_released
		or fly_caught
		or game.batting_side != 1
		or game.inning < game.innings
	):
		return
	# A third force out can still cancel a run that crossed home first.
	if game.runners.any(func(run): return is_forced(run)):
		return
	var needed := game.scores[0] - game.scores[1] + 1
	if pending_runs >= needed:
		pending_runs = needed
		_end("Walk-off! %d run(s)" % pending_runs)


func _limit_hit_on_choice(run: BaseballBaseRunning) -> void:
	if run != batter_run and not fly_caught:
		hit_limit = mini(hit_limit, batter_run.reached)


func hit_bases() -> int:
	if is_home_run:
		return 4
	if batter_run == null or fly_caught:
		return 0
	return mini(batter_run.reached, hit_limit)


func award_home_run() -> void:
	is_home_run = true
	game.phase = game.Phase.HOME_RUN
	for player in game.fielders:
		player.brake("Home run")
	for run in game.runners:
		if not run.retired and not run.scored:
			run.awarded_base = 4
			if not run.active:
				run.advance()
	game.last_result = "Home run! Everyone rounds the bases"
	game.home_run.emit()


func _active_runners() -> Array[BaseballBaseRunning]:
	var active: Array[BaseballBaseRunning] = []
	for run in game.runners:
		if run.active and not run.retired and not run.scored:
			active.append(run)
	return active


func within_reach(player: BaseballPlayer) -> bool:
	var ball: BaseballBall = game.ball
	var closest := Geometry2D.get_closest_point_to_segment(
		player.position, ball.previous_position, ball.position
	)
	var length := ball.previous_position.distance_to(ball.position)
	var fraction := ball.previous_position.distance_to(closest) / maxf(length, 0.001)
	var contact_height := lerpf(ball.previous_height, ball.height, fraction)
	return player.position.distance_to(closest) <= 20 and contact_height <= 25


func _end(message: String) -> void:
	done = true
	result = message
	if holder == null:
		holder = defense.nearest(game.home.position, [])
		game.ball.hold_at(holder.position)
