class_name BaseballWorld
extends Node3D

# Rules keep their original units; the field's 2D Y axis becomes 3D Z.
const FIELD_SCALE: float = 0.04
const PLAYER_VIEW = preload("res://game/presentation/player_3d.tscn")

var player_views: Array[BaseballPlayerView] = []
var actor_views: Array[BaseballPlayerView] = []
var show_guides: bool = false
var ball_ground: Dictionary[BaseballBall, float] = {}
var debug_mesh := ImmediateMesh.new()

@onready var game: BaseballMatch = $Simulation
@onready var field: BaseballFieldView = $Field
@onready var ball: MeshInstance3D = $Ball
@onready var shadow: MeshInstance3D = $BallShadow
@onready var guides: MeshInstance3D = $Guides


static func world_position(point: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(point.x, height, point.y) * FIELD_SCALE


func _ready() -> void:
	if not game.error_message.is_empty():
		return
	game.game_reset.connect(func(): ball_ground.clear())
	field.build()
	for squad in game.squads:
		for player in squad:
			var view: BaseballPlayerView = PLAYER_VIEW.instantiate()
			$Players.add_child(view)
			view.configure(player, game.teams[player.team_index].color, game)
			player_views.append(view)
			actor_views.append(view)
	var equipment_view := BaseballEquipmentView.new()
	add_child(equipment_view)
	equipment_view.configure(self)
	actor_views.append_array(equipment_view.attendants)
	guides.mesh = debug_mesh
	var surface := BaseballFieldView.material(Color.WHITE)
	surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	surface.vertex_color_use_as_albedo = true
	guides.material_override = surface
	sync(0.0)
	game.start_game()


func _process(delta: float) -> void:
	if game.batter != null:
		sync(delta)


func sync(delta: float) -> void:
	for view in player_views:
		view.sync(0.0 if game.paused else delta)
	ball.position = ball_position(game.ball)
	shadow.position = world_position(game.ball.position)
	shadow.position.y = ball_ground.get(game.ball, 0.0) + 0.002
	_update_guides()


func _physics_process(_delta: float) -> void:
	if game.batter == null or game.paused:
		return
	var balls: Array[BaseballBall] = game.equipment.used_balls.duplicate()
	balls.append(game.ball)
	for actor in balls:
		var point := world_position(actor.position)
		var ray := PhysicsRayQueryParameters3D.create(
			point + Vector3.UP * 8, point - Vector3.UP * 8, BaseballFieldView.GROUND_LAYER
		)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		ball_ground[actor] = hit.position.y if not hit.is_empty() else 0.0


func ball_position(actor: BaseballBall) -> Vector3:
	var point := world_position(actor.position, actor.height)
	point.y = maxf(point.y, ball_ground.get(actor, 0.0) + ball.mesh.radius)
	return point


func _update_guides() -> void:
	debug_mesh.clear_surfaces()
	var moving: Array[BaseballPlayer] = []
	if game.debug_visible:
		moving = game.fielders.filter(func(player): return player.moving)
	if moving.is_empty() and not show_guides:
		return
	debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	if show_guides:
		var corners := [
			Vector2(-280, -280), Vector2(280, -280), Vector2(280, 290), Vector2(-280, 290)
		]
		for index in 4:
			debug_mesh.surface_set_color(Color("f6d36a"))
			debug_mesh.surface_add_vertex(world_position(corners[index], 4))
			debug_mesh.surface_add_vertex(world_position(corners[(index + 1) % 4], 4))
	for player in moving:
		debug_mesh.surface_set_color(Color("8fe1ee"))
		debug_mesh.surface_add_vertex(world_position(player.position, 5))
		debug_mesh.surface_add_vertex(world_position(player.target, 5))
	debug_mesh.surface_end()
