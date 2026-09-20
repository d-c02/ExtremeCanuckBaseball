extends Camera3D

@export_range(0.5, 0.95) var framing_margin: float = 0.82
@export_range(0.0, 0.1) var zoom_amount: float = 0.06
@export_range(0.2, 2.0) var zoom_speed: float = 0.9

var wide_fov: float = 45.0
var close_fov: float = 45.0

@onready var game: BaseballMatch = $"../Simulation"


func _ready() -> void:
	game.game_reset.connect(_frame_field)
	get_viewport().size_changed.connect(_frame_field)
	_frame_field()


func _frame_field() -> void:
	if game.batter == null:
		return
	var points := framing_points()
	var bounds := AABB(points[0], Vector3.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	look_at(bounds.get_center())
	near = 0.05
	wide_fov = _fitted_fov(points, framing_margin)
	close_fov = minf(wide_fov, maxf(wide_fov * (1.0 - zoom_amount), _fitted_fov(points, 0.94)))
	fov = wide_fov


func _process(delta: float) -> void:
	if game.batter == null or game.paused or game.phase == game.Phase.SETTLING:
		return
	var goal := wide_fov
	if game.phase in [game.Phase.WINDUP, game.Phase.PITCH, game.Phase.RECEIVE]:
		goal = close_fov
	elif (
		game.phase in [game.Phase.FIELDING, game.Phase.THROW, game.Phase.FOUL, game.Phase.HOME_RUN]
	):
		var ball_point := BaseballWorld.world_position(game.ball.position, game.ball.height)
		goal = clampf(
			_fitted_fov(PackedVector3Array([ball_point]), 0.88), wide_fov, wide_fov * 1.08
		)
	fov = lerpf(fov, goal, 1.0 - exp(-zoom_speed * delta))


func _fitted_fov(points: PackedVector3Array, margin: float) -> float:
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var tangent := 0.0
	for point in points:
		var local := to_local(point)
		var depth := maxf(-local.z, 0.1)
		tangent = maxf(tangent, maxf(absf(local.y), absf(local.x) / aspect) / depth)
	return clampf(rad_to_deg(2.0 * atan(tangent / margin)), 15.0, 120.0)


func framing_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	for point in game.base_positions:
		points.append(BaseballWorld.world_position(point))
		points.append(BaseballWorld.world_position(point, 75))
	for point in game.outfield.boundary:
		points.append(BaseballWorld.world_position(point))
		points.append(BaseballWorld.world_position(point, game.outfield.fence_height))
	for index in game.outfield.barrier_segments.size():
		var point: Vector2 = game.outfield.barrier_segments[index]
		points.append(BaseballWorld.world_position(point))
		points.append(BaseballWorld.world_position(point, game.outfield.barrier_heights[index / 2]))
	for dugout in game.dugouts:
		for index in [0, 8]:
			points.append(BaseballWorld.world_position(dugout.seat_position(index), 75))
	return points
