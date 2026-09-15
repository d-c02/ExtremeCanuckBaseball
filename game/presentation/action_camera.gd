extends Camera2D

@export var follow_speed: float = 4.0
@export var zoom_speed: float = 2.0
@export var close_zoom: float = 0.72
@export var wide_zoom: float = 0.45

var inset: SubViewportContainer
var runner_view: SubViewport
var inset_label: Label
var visible_time: float = 0.0
var initialized: bool = false

@onready var match_scene: BaseballMatch = get_parent()
@onready var zones: BaseballCameraZones = $"../Field/CameraZones"

func _ready() -> void:
	inset = $RunnerHUD/RunnerView
	runner_view = inset.get_node("World")
	inset_label = inset.get_node("Title")
	runner_view.world_2d = get_world_2d()
	inset.hide()

func _process(delta: float) -> void:
	if match_scene.batter == null:
		return
	var phase = match_scene.phase
	var ball: BaseballBall = match_scene.ball
	var active_runner: BaseballBaseRunning = match_scene.camera_runner()
	var runner: BaseballPlayer = active_runner.runner if active_runner != null else match_scene.batter
	var depth: float = match_scene.outfield.fence_distance
	var overview: Vector2 = match_scene.home.position - Vector2(0, depth * 0.5)
	var view_size := get_viewport_rect().size
	var overview_zoom := minf(close_zoom, minf(view_size.y / (depth + 240.0),
		view_size.x / (depth * sqrt(2.0) + 160.0)))
	var focus := overview
	var desired_zoom := overview_zoom
	if phase in [match_scene.Phase.FIELDING, match_scene.Phase.THROW, match_scene.Phase.TAG, match_scene.Phase.HOME_RUN, match_scene.Phase.FOUL]:
		var target := runner.position
		if phase != match_scene.Phase.HOME_RUN:
			target = ball.position + Vector2(0, -ball.height)
		var dead := zones.dead_zone()
		var nearest := target.clamp(dead.position, dead.end)
		focus += target - nearest
		if not dead.has_point(target):
			var required := zones.protected_bases().expand(target).grow(80.0)
			var fit := minf(view_size.x / required.size.x, view_size.y / required.size.y)
			desired_zoom = minf(overview_zoom, maxf(wide_zoom, fit))
	var protected := zones.protected_bases().grow(24.0)
	desired_zoom = minf(desired_zoom, minf(view_size.x / protected.size.x, view_size.y / protected.size.y))
	if match_scene.dugout_view:
		var benches := Rect2(match_scene.dugouts[0].position, Vector2.ZERO).expand(match_scene.dugouts[1].position).grow(280.0)
		focus = benches.get_center()
		desired_zoom = minf(view_size.x / benches.size.x, view_size.y / benches.size.y)
	if not initialized:
		position = focus
		zoom = Vector2.ONE * desired_zoom
		initialized = true
	position = position.lerp(focus, 1.0 - exp(-follow_speed * delta))
	zoom = zoom.lerp(Vector2.ONE * desired_zoom, 1.0 - exp(-zoom_speed * delta))
	if not match_scene.dugout_view:
		position = constrained_center(position, view_size / zoom)
	force_update_scroll()
	_update_inset(runner, delta)

func constrained_center(center: Vector2, visible_size: Vector2) -> Vector2:
	var half := visible_size * 0.5
	var protected := zones.protected_bases().grow(24.0)
	var minimum := protected.end - half
	var maximum := protected.position + half
	# If guides conflict, retaining the bases takes precedence over the lower line.
	maximum.y = maxf(minimum.y, minf(maximum.y, zones.bottom_limit() - half.y))
	return center.clamp(minimum.min(maximum), maximum.max(minimum))

func _update_inset(runner: BaseballPlayer, delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	var screen_position := get_viewport().get_canvas_transform() * runner.global_position
	var in_view := Rect2(Vector2(60, 95), viewport_size - Vector2(120, 155)).has_point(screen_position)
	var running: BaseballBaseRunning = match_scene.camera_runner()
	var active: bool = running != null and not match_scene.dugout_view
	if not active:
		inset.hide()
		visible_time = 0.0
	elif not in_view:
		inset.show()
		visible_time = 0.0
	else:
		visible_time += delta
		if visible_time > 0.35:
			inset.hide()
	runner_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if inset.visible else SubViewport.UPDATE_DISABLED
	if not inset.visible:
		return
	var destination: Vector2 = running.target_position()
	var focus := runner.position.lerp(destination, 0.5) - Vector2(0, 20)
	var size := Vector2(runner_view.size)
	var span := (runner.position - destination).abs() + Vector2(100, 100)
	var scale_factor := minf(1.1, minf(size.x / span.x, size.y / span.y))
	runner_view.canvas_transform = Transform2D(Vector2(scale_factor, 0), Vector2(0, scale_factor), size / 2.0 - focus * scale_factor)
	inset_label.text = "%s → %s" % [runner.data.player_name, BaseballBaseRunning.base_name(running.target_base)]
