extends CanvasLayer

@export var enabled: bool = true
@export_range(0.0, 1.0) var strength: float = 0.65

var previous_positions: Dictionary[BaseballPlayer, Vector2] = {}
var accelerated_views: Array[BaseballPlayerView] = []
var presented: bool = true

@onready var game: BaseballMatch = $"../Simulation"
@onready var camera: Camera3D = $"../Camera"


func _ready() -> void:
	_reset()
	game.game_reset.connect(_reset)
	game.simulation_stepped.connect(_on_simulation_stepped)


func _reset() -> void:
	visible = false
	presented = true
	accelerated_views.clear()
	previous_positions.clear()
	for view in get_parent().actor_views:
		previous_positions[view.player] = view.player.position


func _on_simulation_stepped(steps: int) -> void:
	if presented:
		accelerated_views.clear()
	presented = false
	for view in get_parent().actor_views:
		var player: BaseballPlayer = view.player
		var previous: Vector2 = previous_positions.get(player, player.position)
		if (
			steps > 1
			and not player.position.is_equal_approx(previous)
			and view not in accelerated_views
		):
			accelerated_views.append(view)
		previous_positions[player] = player.position


func _process(_delta: float) -> void:
	presented = true
	visible = false
	if not enabled or game.paused:
		return
	for view in accelerated_views:
		if (
			view.is_visible_in_tree()
			and camera.is_position_in_frustum(
				BaseballWorld.world_position(view.player.position, 35)
			)
		):
			visible = true
			break
	if visible:
		$Tracking.material.set_shader_parameter("strength", strength)
