extends Camera3D

@export_range(25, 75) var elevation: float = 48.0
@export var azimuth: float = -15.0
@export_range(35, 110) var viewing_distance: float = 62.0
@export var broadcast: bool = true
@export var follow_speed: float = 2.0
@export_group("Broadcast operator")
@export_range(0.0, 1.0) var contact_hold: float = 0.35
@export_range(0.5, 5.0) var minimum_shot_time: float = 2.0
@export_range(5.0, 90.0) var pan_degrees_per_second: float = 24.0
@export_range(1.0, 45.0) var zoom_degrees_per_second: float = 12.0
@export_range(0.0, 0.3) var dead_zone: float = 0.08
@export_range(0.1, 2.0) var zoom_settle_time: float = 0.6
@export_range(1.0, 6.0) var zoom_interval: float = 2.5
@export_range(1.0, 10.0) var zoom_threshold: float = 3.0

var shot: StringName = &""
var shot_elapsed: float = 0.0
var contact_remaining: float = 0.0
var requested_shot: StringName = &""
var request_elapsed: float = 0.0
var focus := Vector3(0, 0, -7)
var focus_goal := Vector3(0, 0, -7)
var orbit_yaw: float = -15.0
var orbit_pitch: float = 48.0
var orbit_distance: float = 62.0
var lens_candidate: float = 45.0
var lens_stable_time: float = 0.0
var lens_start: float = 45.0
var lens_goal: float = 45.0
var lens_elapsed: float = 0.0
var lens_duration: float = 0.0
var lens_rest: float = 0.0

@onready var game: BaseballMatch = $"../Simulation"


func _ready() -> void:
	game.ball_hit.connect(func(_quality): contact_remaining = contact_hold)
	game.foul_called.connect(func(): contact_remaining = contact_hold)
	game.game_reset.connect(_reset_shots)


func _reset_shots() -> void:
	shot = &""
	shot_elapsed = 0.0
	contact_remaining = 0.0
	requested_shot = &""
	request_elapsed = 0.0


func _process(delta: float) -> void:
	if game.batter == null:
		return
	var orbit := (
		float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	)
	if orbit != 0.0:
		broadcast = false
	if broadcast and not game.dugout_view:
		_update_broadcast(delta)
		_update_foreground()
		return
	shot = &""
	_update_foreground()
	near = 0.05
	fov = 45.0
	azimuth += orbit * delta * 50.0
	var desired_focus := Vector3(0, 0, -7)
	var points := framing_points()
	if game.dugout_view:
		desired_focus = (points[0] + points[1]) / 2
	elif game.phase in [game.Phase.FIELDING, game.Phase.THROW, game.Phase.TAG, game.Phase.FOUL]:
		desired_focus = desired_focus.lerp(BaseballWorld.world_position(game.ball.position), 0.4)
	focus = focus.lerp(desired_focus, 1.0 - exp(-follow_speed * delta))
	var damping := 1.0 - exp(-follow_speed * delta)
	orbit_yaw = rad_to_deg(lerp_angle(deg_to_rad(orbit_yaw), deg_to_rad(azimuth), damping))
	orbit_pitch = lerpf(orbit_pitch, elevation, damping)
	var yaw := deg_to_rad(orbit_yaw)
	var pitch := deg_to_rad(orbit_pitch)
	var direction := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	position = focus + direction
	look_at(focus)
	var distance := 32.0 if game.dugout_view else viewing_distance
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var vertical_tangent := tan(deg_to_rad(fov) / 2.0) * 0.72
	var horizontal_tangent := vertical_tangent * aspect
	# Fit in camera space so orbiting and tall fly balls cannot push the bases offscreen.
	for point in points:
		var offset := point - focus
		var depth := offset.dot(direction)
		distance = maxf(distance, absf(offset.dot(basis.x)) / horizontal_tangent + depth)
		distance = maxf(distance, absf(offset.dot(basis.y)) / vertical_tangent + depth)
	orbit_distance = lerpf(orbit_distance, distance, damping)
	# The fitted distance includes breathing room; only the outer edge is a hard limit.
	orbit_distance = maxf(orbit_distance, distance * 0.8)
	position = focus + direction * orbit_distance


func framing_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	if game.dugout_view:
		for dugout in game.dugouts:
			points.append(BaseballWorld.world_position(dugout.position, 30))
		for dugout in game.dugouts:
			points.append(BaseballWorld.world_position(dugout.seat_position(0), 70))
			points.append(BaseballWorld.world_position(dugout.seat_position(8), 70))
	else:
		for point in game.base_positions:
			points.append(BaseballWorld.world_position(point, 0))
			points.append(BaseballWorld.world_position(point, 75))
		if game.phase in [game.Phase.FIELDING, game.Phase.THROW, game.Phase.TAG, game.Phase.FOUL]:
			points.append(BaseballWorld.world_position(game.ball.position, game.ball.height))
			points.append(BaseballWorld.world_position(game.ball.position))
	return points


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V:
		broadcast = not broadcast
		shot = &""
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			broadcast = false
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			viewing_distance = maxf(35.0, viewing_distance - 4.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			viewing_distance = minf(110.0, viewing_distance + 4.0)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		broadcast = false
		azimuth -= event.relative.x * 0.25
		elevation = clampf(elevation + event.relative.y * 0.2, 25, 75)


func _update_broadcast(delta: float) -> void:
	if game.paused and shot != &"":
		return
	shot_elapsed += delta
	contact_remaining = maxf(0.0, contact_remaining - delta)
	if game.phase == game.Phase.SETTLING and shot != &"":
		return
	if contact_remaining > 0.0 and shot == &"CenterField":
		return
	var next_shot := _choose_shot()
	if next_shot != requested_shot:
		requested_shot = next_shot
		request_elapsed = 0.0
	request_elapsed += delta
	var pitch_sequence := next_shot == &"CenterField"
	var leaving_pitch_view := (
		shot == &"CenterField" and next_shot == &"HighHome" and contact_remaining <= 0.0
	)
	if (
		shot != &""
		and not pitch_sequence
		and not leaving_pitch_view
		and (shot_elapsed < minimum_shot_time or request_elapsed < 0.35)
	):
		next_shot = shot
	# A baseline assignment expires with its runner; stay wide if that play is gone.
	if next_shot in [&"FirstBase", &"ThirdBase"] and game.play == null:
		next_shot = &"HighHome"
	var cut := next_shot != shot
	shot = next_shot
	near = 0.05
	if cut:
		shot_elapsed = 0.0
	var points := _shot_points()
	var center := Vector3.ZERO
	for point in points:
		center += point
	center /= points.size()
	position = get_node("../BroadcastPositions/" + String(shot)).position
	if cut:
		focus = center
		focus_goal = center
		look_at(focus)
	else:
		var viewport_size := get_viewport().get_visible_rect().size
		var screen := unproject_position(center) / viewport_size
		var offset := screen - Vector2(0.5, 0.5)
		var excess := (
			offset - offset.clamp(Vector2(-dead_zone, -dead_zone), Vector2(dead_zone, dead_zone))
		)
		if excess.length_squared() > 0.0 and not is_position_behind(center):
			var depth := maxf(-to_local(center).z, 0.1)
			focus_goal = project_position((Vector2(0.5, 0.5) + excess) * viewport_size, depth)
		var damping := 1.0 - exp(-follow_speed * delta)
		focus = focus.lerp(focus_goal, damping)
		var desired := Transform3D(Basis.IDENTITY, position).looking_at(focus).basis
		var current_rotation := basis.get_rotation_quaternion()
		var target := desired.get_rotation_quaternion()
		var angle := current_rotation.angle_to(target)
		basis = Basis(
			current_rotation.slerp(
				target,
				minf(damping, deg_to_rad(pan_degrees_per_second) * delta / maxf(angle, 0.0001))
			)
		)
	_update_lens(_framed_lens(points, 0.65), _framed_lens(points, 0.92), delta, cut)


func _update_lens(desired: float, safety: float, delta: float, cut: bool) -> void:
	if cut:
		fov = desired
		lens_goal = desired
		lens_candidate = desired
		lens_duration = 0.0
		lens_rest = 0.0
		lens_stable_time = 0.0
		return
	lens_rest += delta
	if absf(desired - lens_candidate) > zoom_threshold * 0.5:
		lens_candidate = desired
		lens_stable_time = 0.0
	else:
		lens_stable_time += delta
	if safety > fov:
		# Keep fast action in frame without waiting for the operator's next zoom.
		fov = maxf(safety, lerpf(fov, desired, 1.0 - exp(-follow_speed * delta)))
		lens_duration = 0.0
		lens_rest = 0.0
		lens_stable_time = 0.0
		return
	if lens_duration > 0.0:
		lens_elapsed = minf(lens_elapsed + delta, lens_duration)
		fov = Tween.interpolate_value(
			lens_start,
			lens_goal - lens_start,
			lens_elapsed,
			lens_duration,
			Tween.TRANS_SINE,
			Tween.EASE_IN_OUT
		)
		if lens_elapsed >= lens_duration or fov < safety:
			fov = maxf(fov, safety)
			lens_duration = 0.0
			lens_rest = 0.0
	elif (
		lens_rest >= zoom_interval
		and lens_stable_time >= zoom_settle_time
		and absf(desired - fov) >= zoom_threshold
	):
		lens_start = fov
		lens_goal = desired
		lens_elapsed = 0.0
		lens_duration = maxf(1.2, absf(lens_goal - fov) * PI / (2.0 * zoom_degrees_per_second))


func _choose_shot() -> StringName:
	if game.phase in [game.Phase.WINDUP, game.Phase.PITCH, game.Phase.RECEIVE]:
		return &"CenterField"
	if game.phase in [game.Phase.PREPARING, game.Phase.RETURN_BALL]:
		var returning := game.ball_return
		if shot == &"CenterField" and returning != null:
			var catcher := game.fielder_for("C")
			if (
				returning.carrier == catcher
				and catcher.position.distance_to(game.home.position) < 100
			):
				return &"CenterField"
	if game.phase in [game.Phase.THROW, game.Phase.TAG] and game.play != null:
		return &"FirstBase" if game.play.throw_base in [1, 4] else &"ThirdBase"
	return &"HighHome"


func _update_foreground() -> void:
	var pitcher_depth := -to_local(BaseballWorld.world_position(game.mound.position)).z
	for view in get_parent().player_views:
		var player: BaseballPlayer = view.player
		var foreground := -to_local(view.position).z < pitcher_depth - 2.0
		var participant := (
			player == game.batter or player in [game.fielder_for("P"), game.fielder_for("C")]
		)
		view.visible = shot != &"CenterField" or not foreground or participant


func _shot_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	if shot == &"CenterField":
		for player in [game.batter, game.fielder_for("P"), game.fielder_for("C")]:
			points.append(BaseballWorld.world_position(player.position))
			points.append(BaseballWorld.world_position(player.position, 75))
	elif shot in [&"FirstBase", &"ThirdBase"]:
		points.append(BaseballWorld.world_position(game.base_positions[game.play.throw_base - 1]))
		if game.play.target_runner != null:
			points.append(BaseballWorld.world_position(game.play.target_runner.runner.position, 35))
	else:
		points = framing_points()
		if game.phase in [game.Phase.READY, game.Phase.PREPARING]:
			for dugout in game.dugouts:
				points.append(BaseballWorld.world_position(dugout.position))
			for fielder in game.fielders:
				points.append(BaseballWorld.world_position(fielder.position, 75))
	points.append(BaseballWorld.world_position(game.ball.position, game.ball.height))
	return points


func _framed_lens(points: PackedVector3Array, margin: float) -> float:
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var tangent := 0.0
	for point in points:
		var local := to_local(point)
		var depth := maxf(-local.z, 0.1)
		tangent = maxf(tangent, maxf(absf(local.y), absf(local.x) / aspect) / depth)
	return clampf(
		rad_to_deg(2.0 * atan(tangent / margin)), 8.0 if shot == &"CenterField" else 15.0, 100.0
	)
