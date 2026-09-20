extends SceneTree

const DELTA := 1.0 / 60.0
var failures := 0
var game: BaseballMatch
var world: BaseballWorld


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func tick() -> void:
	await physics_frame
	game.step(DELTA)


func finish_play() -> void:
	for frame in 4000:
		await tick()
		if game.play.done or not game.error_message.is_empty():
			break
	check(game.play.done and game.error_message.is_empty(), "Play stalled")


func run() -> void:
	world = load("res://main.tscn").instantiate()
	root.add_child(world)
	game = world.game
	game.set_physics_process(false)
	check_rosters()
	check_seed_replay()
	await check_box_score_toggle()
	var original_stats := roster_stats()
	var first_trace: Array = []
	var first_box: Dictionary = {}
	for seed_value in [42, 42, 7]:
		game.random_seed = seed_value
		game.reset_game()
		var trace: Array = []
		var record := func(_result: String):
			if game.play.strikeout or _result.begins_with("Swing and miss"):
				check(
					game.play.holder.role == "C" and game.ball.held,
					"Strike ended before catcher received the pitch"
				)
			trace.append([game.scores.duplicate(), game.outs, game.inning, game.batting_side])
			var occupied: Array[int] = []
			for runner in game.runners:
				# A third out can leave a runner between bases; reached is their last touch.
				if runner.active:
					continue
				check(not occupied.has(runner.reached), "Two runners occupy one base")
				occupied.append(runner.reached)
		game.play_finished.connect(record)
		game.start_game()
		for frame in 100000:
			await tick()
			if game.phase == game.Phase.WINDUP:
				check(
					game.equipment.bat_for(game.batter).carrier == game.batter,
					"Pitch began before hitter collected a bat"
				)
			if game.phase == game.Phase.FINISHED:
				break
		game.play_finished.disconnect(record)
		check(
			game.error_message.is_empty() and game.phase == game.Phase.FINISHED,
			"Game failed to finish"
		)
		check(
			game.inning >= game.innings and game.get_node("Players").get_child_count() == 18,
			"Game lost innings or roster players"
		)
		if first_trace.is_empty():
			first_trace = trace
			first_box = game.box_score.to_dict()
		elif seed_value == 42:
			check(
				trace == first_trace and game.box_score.to_dict() == first_box,
				"Seed replay changed the game or box score"
			)
		check(game.scores[0] != game.scores[1], "Tied game stopped without extra innings")
		var pitches := 0
		for side in 2:
			var team: Dictionary = game.box_score.teams[side]
			var runs := 0
			var hits := 0
			var putouts := 0
			for player in team.players:
				runs += player.R
				hits += player.H
				putouts += player.PO
			check(
				runs == game.scores[side] and runs == team.R and hits == team.H,
				"Player totals disagree with score"
			)
			check(putouts == team.pitching.outs, "Putouts disagree with pitching outs")
			check(
				team.innings.reduce(func(a, b): return a + b, 0) == runs,
				"Line score disagrees with runs"
			)
			pitches += team.pitching.P
		check(pitches == game.pitch_count, "Box score lost pitches")
		print(
			"Seed ",
			seed_value,
			": ",
			game.scores,
			", pitches: ",
			game.pitch_count,
			", K: ",
			game.box_score.teams[0].pitching.K + game.box_score.teams[1].pitching.K
		)
	check(roster_stats() == original_stats, "Simulation modified roster Resources")
	await check_outs()
	check_continuity()
	await check_changeover()
	check_fielders()
	await check_wall_and_home_run()
	await check_contact_and_retreat()
	await check_scoring()
	check_foul()
	await check_grounding()
	check_camera()
	await _check_transition_effect()
	print("Failures: ", failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)


func check_seed_replay() -> void:
	game.random_seed = 0
	game.reset_game()
	var seed_value := game.active_seed
	var sample := game.rng.randi()
	game.reset_game(true)
	check(
		game.active_seed == seed_value and game.rng.randi() == sample, "Replay lost the active seed"
	)
	game.random_seed = 42
	game.reset_game()


func roster_stats() -> Array:
	var stats: Array = []
	for team in game.teams:
		for player in team.players:
			for property in [
				"speed",
				"acceleration",
				"reaction_time",
				"hitting",
				"fielding",
				"throwing_speed",
				"batting_power",
				"anticipation",
				"idle_behavior"
			]:
				stats.append(player.get(property))
	return stats


func contact(base_count: int = 0) -> void:
	game.reset_game()
	game.batter.position = game.home.position
	for player in game.fielders:
		player.position = game.teams[1].field_positions[player.roster_index]
		player.role = game.teams[1].field_roles[player.roster_index]
	for index in base_count:
		var player: BaseballPlayer = game.squads[0][index + 1]
		var runner := BaseballBaseRunning.new()
		runner.reset(player, game.base_positions)
		runner.reached = index + 1
		player.position = game.base_positions[index] + Vector2(10, 9)
		game.runners.append(runner)
	game.play = BaseballLivePlay.new(game)
	game.play.swing_time = BaseballLivePlay.PITCH_DURATION
	game.play.aim_error = 0.0
	game.ball.hold_at(game.home.position)
	game.equipment.bat_for(game.batter).carrier = game.batter
	game.play._resolve_swing()
	game.pitch_count = 1


func possession(point: Vector2) -> void:
	game.play.holder = game.fielders[0]
	game.play.holder.position = point
	game.ball.hold_at(point)
	game.play._choose_throw()


func check_outs() -> void:
	contact(1)
	game.ball.bounced = true
	game.play._advance_runners()
	var lead := game.runners[0]
	lead.runner.position = game.base_positions[0].lerp(game.base_positions[1], 0.5)
	possession(game.base_positions[0])
	check(
		game.play.batter_run.retired and game.outs == 1, "First baseman ignored an immediate force"
	)
	check(not game.play.is_forced(lead), "Force survived the trailing runner's out")
	lead.runner.position = game.play.holder.position + Vector2(5, 0)
	game.play._choose_throw()
	check(lead.retired and game.outs == 2, "Defense ignored a second, unforced tag")
	contact()
	possession(game.base_positions[0] + Vector2(-45, 0))
	check(game.phase == game.Phase.TAG, "First baseman threw instead of stepping on first")
	await finish_play()
	check(game.play.batter_run.retired and game.outs == 1, "Unassisted out failed")
	contact(1)
	lead = game.runners[0]
	lead.reached = 2
	lead.active = true
	lead.target_base = 3
	lead.runner.position = game.base_positions[1] + Vector2(10, 9)
	possession(lead.runner.position)
	check(not lead.retired, "Unforced runner was tagged while touching their base")
	contact()
	game.outs = 2
	game.play.pending_runs = 1
	game.play.retire_runner(game.play.batter_run, true)
	game._complete_play()
	check(game.scores[0] == 0 and game.outs == 3, "Third force out counted a run")
	check(game.box_score.teams[0].players[0].RBI == 0, "Cancelled run earned an RBI")


func check_continuity() -> void:
	game.reset_game()
	game.start_game()
	game.step(DELTA)
	check(
		is_equal_approx(game.phase_elapsed, DELTA) and not game.is_fast_forwarding(),
		"Opening deployment was sped up"
	)
	contact()
	var runner := game.play.batter_run
	runner.reached = 1
	runner.active = false
	runner.runner.position = game.base_positions[0] + Vector2(10, 9)
	game.fielders[1].velocity = Vector2(100, 0)
	game.play._end("Safe at first")
	game._complete_play()
	check(game.fielders[1].velocity.length() > 0, "Result froze the fielders")
	check(game.squads[0][1].target != game.home.position, "Next hitter interrupted the result beat")
	game.step(DELTA)
	check(
		is_equal_approx(game.phase_elapsed, DELTA) and not game.is_fast_forwarding(),
		"Result beat was sped up"
	)
	game._prepare_pitch()
	check(
		game.runners.has(runner) and game.batter.roster_index == 1,
		"Next batter cleared the runner or reset the order"
	)
	game.phase_elapsed = 0.0
	game.step(DELTA)
	check(
		is_equal_approx(game.phase_elapsed, game.transition_speed * DELTA),
		"Transition speed failed"
	)
	game.paused = true
	var point := game.batter.position
	game.step(DELTA)
	check(game.batter.position == point, "Pause advanced the game")
	game.paused = false
	game.play = BaseballLivePlay.new(game)
	game.phase_elapsed = 0
	game.step(DELTA)
	check(is_equal_approx(game.phase_elapsed, DELTA), "Transition speed leaked into the pitch")


func check_changeover() -> void:
	contact(1)
	var incoming: BaseballPlayer = game.squads[0][7]
	var outgoing: BaseballPlayer = game.squads[1][7]
	var runner := game.runners[0].runner
	var incoming_start := incoming.position
	var outgoing_start := outgoing.position
	game.outs = 3
	game.play.holder = game.fielders[1]
	game.play.done = true
	game.ball.hold_at(game.play.holder.position)
	game._end_half()
	check(game.runners.is_empty(), "Changeover kept the previous half's runners")
	check(runner.waypoints.is_empty(), "Runner took a dugout detour before fielding")
	for frame in 20:
		await tick()
	check(
		(
			incoming.position.distance_to(incoming_start) > 5.0
			and outgoing.position.distance_to(outgoing_start) > 5.0
			and outgoing.moving
		),
		"Incoming defense waited for the outgoing team to reach its dugout"
	)
	check(game.phase == game.Phase.PREPARING, "Pitch started before changeover finished")
	for frame in 3000:
		await tick()
		if game.phase not in [game.Phase.PREPARING, game.Phase.RETURN_BALL]:
			break
	check(
		game.phase == game.Phase.WINDUP and game._everyone_arrived(),
		"Changeover stalled or pitched before everyone arrived"
	)


func check_fielders() -> void:
	contact()
	game.ball.launch(game.fielders[7].position, Vector2.ZERO, 180, 0)
	game.play.defense.assign()
	for index in [6, 8]:
		check(
			game.fielders[index].target.distance_to(game.teams[1].field_positions[index]) <= 8,
			"Routine fly pulled another outfielder off station"
		)
	game.ball.launch(Vector2(-450, -490), Vector2.ZERO, 0, 0)
	game.ball.bounced = true
	var left := game.fielders[6]
	var catcher := game.fielders[2]
	catcher.position = game.ball.position
	left.position = game.ball.position + Vector2(5, 0)
	catcher.reaction_remaining = 0
	left.reaction_remaining = 0
	game.play.defense.step(0.2)
	check(game.play.defense.chaser == catcher, "Distant chaser monopolized a nearby pickup")
	game.play.catch_retries[catcher] = 0.65
	game.rng.seed = 42
	game.play._step_fielding(DELTA)
	check(game.play.holder == left, "One player's bobble blocked their teammate")


func check_wall_and_home_run() -> void:
	game.reset_game()
	var wall := game.outfield
	var player := game.fielders[7]
	for index in [16, 8]:
		var midpoint := (wall.boundary[index] + wall.boundary[index + 1]) * 0.5
		var normal := wall.inward_normal(index)
		player.position = midpoint + normal * 50
		player.stop()
		player.move_to(midpoint - normal * 150, "Collision test")
		for frame in 120:
			await physics_frame
			player.step(DELTA)
		check((player.position - midpoint).dot(normal) >= 7.9, "Player crossed the wall")
	var top := game.home.position.y - wall.fence_distance
	game.ball.launch(Vector2(0, top + 40), Vector2(0, -300), 0, 0)
	game.ball.bounced = true
	var prediction := wall.forecast(game.ball, 0.5)
	game.ball.step(0.2)
	check(
		wall.check_crossing(game.ball) == "wall" and game.ball.velocity.y > 0,
		"Low ball did not rebound"
	)
	check(
		not prediction.home_run and prediction.point.y > top,
		"AI predicted a rebound outside the wall"
	)
	contact(3)
	game.ball.launch(game.home.position, Vector2(0, -600), 10, 410)
	game.play.defense.assign()
	await finish_play()
	check(
		game.play.is_home_run and game.scores[0] == 4 and game.runners.is_empty(),
		"Fence clearance failed to score a grand slam"
	)
	var stats: Dictionary = game.box_score.teams[0].players[0]
	check(
		stats.HR == 1 and stats.H == 1 and stats.AB == 1 and stats.R == 1 and stats.RBI == 4,
		"Grand slam box score is wrong"
	)


func check_contact_and_retreat() -> void:
	contact(3)
	game.outs = 2
	for runner in game.runners:
		if runner != game.play.batter_run:
			runner.active = false
	game.play._advance_on_contact()
	check(game.runners.all(func(r): return r.active), "Two-out runners waited for a bounce")
	contact(1)
	var runner := game.runners[0]
	runner.active = false
	game.ball.launch(game.home.position, Vector2(0, -250), 10, 25)
	game.play._advance_on_contact()
	check(runner.active, "Runner waited for a bounce on a likely ground hit")
	runner.runner.position = game.base_positions[0].lerp(game.base_positions[1], 0.3)
	var before := runner.runner.position
	game.ball.launch(game.fielders[6].position, Vector2.ZERO, 12, 0)
	for fielder in game.fielders:
		fielder.reaction_remaining = 0
	game.rng.seed = 42
	game.play._step_fielding(DELTA)
	check(
		runner.returning and runner.runner.position == before,
		"Caught fly failed to send runner back without teleporting"
	)
	await finish_play()
	check(
		game.scores[0] == 0 and (runner.retired or runner.reached == runner.start_base),
		"Caught-fly retreat or scoring failed"
	)


func check_scoring() -> void:
	contact(1)
	var lead := game.runners[0]
	game.play._limit_hit_on_choice(lead)
	game.play.batter_run.reached = 1
	game.play._end("Fielder's choice")
	game._complete_play()
	check(
		game.box_score.teams[0].H == 0 and game.box_score.teams[0].players[0].AB == 1,
		"Fielder's choice counted as a hit"
	)
	contact()
	game.runners.clear()
	game.play = BaseballLivePlay.new(game)
	game.strikes = 2
	game.ball.launch(
		game.home.position, Vector2(0, 220.0 / BaseballLivePlay.PITCH_DURATION), 12.0, 0.0
	)
	game.ball.gravity_enabled = false
	game.play.swing_time = 2.0
	game.play._resolve_swing()
	await finish_play()
	var pitcher: Dictionary = game.box_score.teams[1].pitching
	check(
		(
			pitcher.K == 1
			and pitcher.outs == 1
			and pitcher.BF == 1
			and game.box_score.teams[0].players[0].K == 1
		),
		"Strikeout accounting failed"
	)
	game.inning = game.innings
	game.batting_side = 1
	game.outs = 3
	game._end_half()
	check(
		(
			game.phase == game.Phase.PREPARING
			and game.inning == game.innings + 1
			and game.batting_side == 0
		),
		"Tie did not start an extra inning"
	)
	contact(2)
	game.batting_side = 1
	game.inning = game.innings
	game.play.batter_run.reached = 1
	lead = game.runners[1]
	lead.reached = 4
	game.play._on_base(lead)
	check(not game.play.done, "Airborne provisional run ended the game before a possible catch")
	game.play.ground_released = true
	game.play._check_walk_off()
	check(not game.play.done, "Walk-off ignored an outstanding force")
	game.runners[0].reached = 2
	game.play._check_walk_off()
	check(
		game.play.done and game.play.pending_runs == 1, "Winning run did not stop a non-HR walk-off"
	)


func check_foul() -> void:
	game.reset_game()
	game.strikes = 2
	game.play = BaseballLivePlay.new(game)
	game.play.swing_time = BaseballLivePlay.PITCH_DURATION + 0.11
	game.play.aim_error = 0.8
	game.ball.hold_at(game.home.position)
	game.play._resolve_swing()
	var origin := game.ball.position
	game.play.step(0.25)
	check(game.ball.position != origin and not game.play.done, "Foul had no visible flight")
	game.play.step(1.3)
	check(
		game.play.done and not game.play.batter_done and game.strikes == 2,
		"Two-strike foul retired the batter"
	)


func check_grounding() -> void:
	game.reset_game()
	await physics_frame
	for side in 2:
		var dugout = game.dugouts[side]
		var view: BaseballPlayerView = world.player_views[side * 9]
		var actor := view.player
		actor.stop()
		for step in range(-1, 7):
			var local_y: float = -dugout.room_width / 2 - (step + 0.5) * dugout.stair_run / 6
			actor.position = dugout.to_global(Vector2(0, local_y))
			await physics_frame
			view._physics_process(DELTA)
			view.sync(0)
			var expected := clampf(-1.2 + (step + 1) * 0.2, -1.2, 0.0)
			check(
				absf(view.position.y - expected) < 0.025,
				"Player missed a dugout floor or stair tread"
			)
		actor.position = dugout.seat_position(0)
		game._send_on_deck(actor)
		var crossed_stairs := false
		for frame in 1200:
			await tick()
			var local: Vector2 = dugout.to_local(actor.position)
			if (
				local.y < -dugout.room_width / 2
				and local.y > -dugout.room_width / 2 - dugout.stair_run
			):
				crossed_stairs = true
				check(absf(local.x) < dugout.stair_width / 2, "Player crossed a stair wall")
			if not actor.moving:
				break
		check(crossed_stairs and not actor.moving, "Player failed to use the dugout exit")


func check_camera() -> void:
	game.reset_game()
	var camera: Camera3D = world.get_node("Camera")
	check(world.player_views.size() == 18, "3D presentation lost roster actors")
	game.ball.launch(Vector2(850, -900), Vector2.ZERO, 150, 0)
	game.phase = game.Phase.FIELDING
	world.sync(0.0)
	for view in world.player_views:
		check(
			Vector2(view.position.x, view.position.z).is_equal_approx(
				view.player.position * BaseballWorld.FIELD_SCALE
			),
			"3D actor diverged from the simulation"
		)
	check(
		world.ball.position.is_equal_approx(Vector3(34, 6, -36)),
		"Ball height was not mapped into 3D"
	)
	check(is_equal_approx(world.shadow.position.y, 0.04), "Ball shadow left the ground")
	camera._process(DELTA)
	for point in camera.framing_points():
		check(camera.is_position_in_frustum(point), "Broadcast lost the live ball or bases")
	game.phase = game.Phase.SETTLING
	var held_transform: Transform3D = camera.transform
	camera._process(1.0)
	check(camera.transform == held_transform, "Broadcast moved during the result beat")
	game.phase = game.Phase.FIELDING
	camera.broadcast = false
	for angle in [-120.0, 0.0, 90.0]:
		camera.azimuth = angle
		for frame in 30:
			camera._process(DELTA)
			for point in camera.framing_points():
				check(camera.is_position_in_frustum(point), "3D camera lost bases or airborne ball")
	game.dugout_view = true
	for frame in 30:
		camera._process(DELTA)
	for point in camera.framing_points():
		check(camera.is_position_in_frustum(point), "Dugout camera lost a bench")
	game.dugout_view = false
	camera.azimuth = -15.0
	camera.broadcast = true
	game.phase = game.Phase.PITCH
	camera._process(DELTA)
	var contact_frame: Transform3D = camera.transform
	game.ball_hit.emit(0.8)
	game.phase = game.Phase.FIELDING
	camera._process(0.1)
	check(camera.transform == contact_frame, "Broadcast cut away at contact")
	camera._process(camera.contact_hold)
	check(camera.shot == &"HighHome", "Broadcast never picked up the batted ball")
	game.ball_return = BaseballBallReturn.new(game, game.fielder_for("CF"))
	game.phase = game.Phase.RETURN_BALL
	camera._process(DELTA)
	check(
		camera.shot == &"HighHome" and camera.near < 1.0,
		"Outfield return selected a clipped pitching shot"
	)
	check(camera.is_position_in_frustum(world.ball.position), "Return camera clipped out the ball")
	check(
		world.player_views.all(func(view): return view.visible),
		"Pitching shot left fielders hidden"
	)
	# Small framing changes should not make the operator hunt with the zoom.
	camera._update_lens(45.0, 35.0, 0.0, true)
	for frame in 240:
		camera._update_lens(45.0 + sin(frame * 0.2), 35.0, DELTA, false)
	check(is_equal_approx(camera.fov, 45.0), "Broadcast lens hunted over small movements")
	for frame in 50:
		camera._update_lens(35.0, 25.0, DELTA, false)
	check(camera.fov < 45.0 and camera.fov > 35.0, "Stable framing did not start an eased zoom")
	game.paused = true
	var paused_lens: float = camera.fov
	camera._process(1.0)
	check(is_equal_approx(camera.fov, paused_lens), "Lens kept zooming while paused")
	game.paused = false
	camera._update_lens(55.0, 45.0, 0.0, true)
	camera._update_lens(55.0, 45.0, DELTA, false)
	check(is_equal_approx(camera.fov, 55.0), "New shot inherited the previous zoom")
	game.reset_game()


func _check_transition_effect() -> void:
	game.reset_game()
	game.start_game()
	var camera = world.get_node("Camera")
	var tape = world.get_node("TapeTransition")
	tape.set_process(false)
	camera.set_process(false)
	camera.position = BaseballWorld.world_position(game.home.position) + Vector3(0, 25, 25)
	camera.look_at(BaseballWorld.world_position(game.home.position))
	camera.fov = 60.0
	for view in world.actor_views:
		view.player.stop()
		view.visible = true
	game.ball_return = BaseballBallReturn.new(game, game.fielder_for("P"))
	game.ball_return.ready = true
	game.pitch_count = 1
	game.batter.position = game.home.position
	game.batter.move_to(game.home.position + Vector2(20, 0), "Short adjustment")
	tape._reset()
	await tick()
	tape._process(DELTA)
	check(tape.visible, "Visible accelerated short movement had no tape effect")
	check(
		(
			is_equal_approx(
				tape.get_node("Tracking").material.get_shader_parameter("strength"), tape.strength
			)
			and tape.get_node("Indicator").modulate.a == 1.0
		),
		"Accelerated movement started before the tape effect was fully visible"
	)
	tape._process(DELTA / 2.0)
	check(tape.visible, "Tape flickered between physics ticks")
	game.batter.stop()

	var attendant: BaseballPlayer = game.equipment.attendants[0]
	attendant.position = game.home.position
	attendant.move_to(game.home.position + Vector2(20, 0), "Equipment duty")
	tape._reset()
	await tick()
	tape._process(DELTA)
	check(tape.visible, "Visible accelerated equipment attendant had no tape effect")
	attendant.position = Vector2(10000, 10000)
	attendant.move_to(Vector2(10100, 10000), "Offscreen equipment duty")
	tape._reset()
	await tick()
	tape._process(DELTA)
	check(not tape.visible, "Offscreen repositioning showed the tape effect")
	attendant.stop()

	# The catcher's arrival starts a normal-speed return on the last accelerated step.
	var catcher := game.fielder_for("C")
	catcher.position = game.home.position
	catcher.move_to(catcher.position + Vector2(1, 0), "Returning with ball")
	catcher.velocity = Vector2(24.0 + catcher.data.acceleration * DELTA * 1.5, 0)
	game.ball.hold_at(catcher.position)
	game.ball_return = BaseballBallReturn.new(game, catcher)
	tape._reset()
	await tick()
	await tick()
	tape._process(DELTA)
	check(
		game.phase == game.Phase.RETURN_BALL and not catcher.moving and tape.visible,
		"Accelerated arrival lost its effect across two physics ticks before rendering"
	)
	await tick()
	tape._process(DELTA)
	check(not tape.visible, "Tape effect leaked into normal-speed return flight")

	game.phase = game.Phase.PREPARING
	game.ball_return.ready = true
	game.batter.move_to(game.batter.position + Vector2(20, 0), "Visible repositioning")
	await tick()
	tape._process(DELTA)
	check(tape.visible, "Visible acceleration did not restore the tape effect")
	game.paused = true
	tape._process(DELTA)
	check(not tape.visible, "Tape effect kept running while paused")
	game.reset_game()
	check(not tape.visible, "Reset left the tape effect visible")
	game.start_game()
	await tick()
	tape._process(DELTA)
	check(not tape.visible, "Opening walkout showed the tape effect")
	game.reset_game()
	camera.set_process(true)
	tape.set_process(true)


func check_rosters() -> void:
	for team in game.teams:
		check(team.validation_error().is_empty(), "Sample roster was rejected")
	var roster: BaseballTeamData = game.home_team.duplicate(true)
	var catcher := roster.field_roles.find("C")
	roster.field_roles[catcher] = "RF"
	check(not roster.validation_error().is_empty(), "Roster without a catcher was accepted")
	roster.field_roles[catcher] = "C"
	roster.players[0] = null
	check(not roster.validation_error().is_empty(), "Null player Resource was accepted")


func check_box_score_toggle() -> void:
	var panel := game.get_node("HUD/BoxScore")
	var event := InputEventKey.new()
	event.keycode = KEY_B
	event.pressed = true
	game.reset_game()
	panel._unhandled_key_input(event)
	await process_frame
	await process_frame
	check(panel.visible, "Pre-game box score did not stay open")
	panel._unhandled_key_input(event)
	check(not panel.visible, "B did not close the box score")
	panel._unhandled_key_input(event)
	game.reset_game()
	check(not panel.visible, "Reset left the old box score open")
	panel._unhandled_key_input(event)
	await process_frame
	await process_frame
	check(panel.visible, "Box score could not reopen after reset")
	game.reset_game()
