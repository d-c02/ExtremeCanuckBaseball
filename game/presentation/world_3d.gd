class_name BaseballWorld
extends Node3D

# Rules keep their original units; the field's 2D Y axis becomes 3D Z.
const FIELD_SCALE: float = 0.04
const PLAYER_VIEW = preload("res://game/presentation/player_3d.tscn")

var player_views: Array[BaseballPlayerView] = []
var show_guides: bool = false
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
	field.build(game)
	for squad in game.squads:
		for player in squad:
			var view: BaseballPlayerView = PLAYER_VIEW.instantiate()
			$Players.add_child(view)
			view.configure(player, game.teams[player.team_index].color)
			player_views.append(view)
	guides.mesh = debug_mesh
	var surface := BaseballFieldView.material(Color.WHITE)
	surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	surface.vertex_color_use_as_albedo = true
	guides.material_override = surface
	sync(0.0)


func _process(delta: float) -> void:
	if game.batter != null:
		sync(delta)


func sync(delta: float) -> void:
	for view in player_views:
		view.sync(0.0 if game.paused else delta)
	ball.position = world_position(game.ball.position, game.ball.height)
	shadow.position = world_position(game.ball.position, 1.0)
	for side in field.dugout_labels.size():
		var team := game.teams[side]
		field.dugout_labels[side].text = (
			"%s · next %d" % [team.team_name, game.next_batter[side] + 1]
		)
	_update_guides()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		show_guides = not show_guides


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
