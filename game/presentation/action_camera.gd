extends Camera3D

@export_range(25, 75) var elevation: float = 48.0
@export var azimuth: float = -15.0
@export_range(35, 110) var viewing_distance: float = 62.0
@export var follow_speed: float = 4.0

var focus := Vector3(0, 0, -7)

@onready var game: BaseballMatch = $"../Simulation"


func _process(delta: float) -> void:
	if game.batter == null:
		return
	var orbit := (
		float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	)
	azimuth += orbit * delta * 50.0
	var desired_focus := Vector3(0, 0, -7)
	var points := framing_points()
	if game.dugout_view:
		desired_focus = (points[0] + points[1]) / 2
	elif game.phase in [game.Phase.FIELDING, game.Phase.THROW, game.Phase.TAG, game.Phase.FOUL]:
		desired_focus = desired_focus.lerp(BaseballWorld.world_position(game.ball.position), 0.4)
	focus = focus.lerp(desired_focus, 1.0 - exp(-follow_speed * delta))
	var yaw := deg_to_rad(azimuth)
	var pitch := deg_to_rad(elevation)
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
	position = focus + direction * distance


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
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			viewing_distance = maxf(35.0, viewing_distance - 4.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			viewing_distance = minf(110.0, viewing_distance + 4.0)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		azimuth -= event.relative.x * 0.25
		elevation = clampf(elevation + event.relative.y * 0.2, 25, 75)
