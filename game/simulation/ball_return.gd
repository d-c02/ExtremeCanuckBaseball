class_name BaseballBallReturn
extends RefCounted

var game: BaseballMatch
var carrier: BaseballPlayer
var pitcher: BaseballPlayer
var flight_remaining: float = 0.0
var ready: bool = false
var throwing: bool = false
var resume_route: PackedVector2Array
var resume_action: String


func _init(match_scene: BaseballMatch, previous_holder: BaseballPlayer) -> void:
	game = match_scene
	pitcher = game.fielder_for("P")
	carrier = previous_holder
	if carrier != null and carrier not in game.fielders:
		resume_route = PackedVector2Array([carrier.target])
		resume_route.append_array(carrier.waypoints)
		resume_action = carrier.intention
		carrier.stop("Returning ball before leaving field")
	if carrier == null:
		carrier = game.fielder_for("C")
		if game.play != null and game.play.is_home_run:
			game.equipment.issue_ball()
		carrier.move_via(
			game.dugouts[carrier.team_index].route_out(carrier.position, game.ball.position),
			"Collecting ball"
		)


func step(delta: float) -> void:
	if ready:
		return
	if throwing:
		flight_remaining -= delta
		game.ball.step(delta)
		if flight_remaining <= 0.0:
			game.ball.hold_at(pitcher.position)
			game.ball_caught.emit(pitcher)
			ready = true
			game.phase = game.Phase.PREPARING
		return
	if not game.ball.held:
		game.ball.step(delta)
		if carrier.waypoints.is_empty():
			carrier.target = game.ball.position
		carrier.moving = true
		if carrier.position.distance_to(game.ball.position) > 18.0 or game.ball.height > 25.0:
			return
		game.ball.hold_at(carrier.position)
		game.ball_caught.emit(carrier)
		if carrier in game.fielders:
			carrier.move_to(game.field_position(carrier), "Returning with ball")
		else:
			game._send_to_dugout(carrier)
	game.ball.hold_at(carrier.position)
	if pitcher.moving or carrier.moving:
		return
	if carrier == pitcher:
		ready = true
		return
	game.phase = game.Phase.RETURN_BALL
	game.phase_elapsed = 0.0
	flight_remaining = maxf(0.65, carrier.position.distance_to(pitcher.position) / 240.0)
	game.ball.launch(
		game.ball.position,
		(pitcher.position - game.ball.position) / flight_remaining,
		game.ball.height,
		BaseballBall.GRAVITY * flight_remaining / 2.0
	)
	if not resume_route.is_empty():
		carrier.move_via(resume_route, resume_action)
	throwing = true
	game.ball_thrown.emit(carrier.position)
	game.last_result = "%s returns the ball to the pitcher" % carrier.data.player_name
