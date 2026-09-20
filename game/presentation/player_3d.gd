class_name BaseballPlayerView
extends Node3D

var player: BaseballPlayer
var game: BaseballMatch
var stride: float = 0.0
var ground_height: float = 0.0
var ground_initialized: bool = false

@onready var ground_ray: RayCast3D = $GroundRay
@onready var sprite: Sprite3D = $Sprite
@onready var label: Label3D = $Label
@onready var standing_height: float = sprite.position.y


func configure(actor: BaseballPlayer, color: Color, match_scene: BaseballMatch) -> void:
	player = actor
	game = match_scene
	sprite.modulate = color


func _physics_process(delta: float) -> void:
	if player == null or game.paused:
		return
	var point := BaseballWorld.world_position(player.position)
	ground_ray.global_position = point + Vector3.UP * 8.0
	ground_ray.force_raycast_update()
	var height := 0.0
	if ground_ray.is_colliding():
		height = ground_ray.get_collision_point().y
	if not ground_initialized or not player.moving:
		ground_height = height
	else:
		ground_height = lerpf(ground_height, height, 1.0 - exp(-25.0 * delta))
	ground_initialized = true


func sync(delta: float) -> void:
	position = BaseballWorld.world_position(player.position)
	position.y = ground_height
	stride += player.velocity.length() * delta * 0.12
	sprite.position.y = standing_height + (absf(sin(stride)) * 0.1 if player.moving else 0.0)
	label.text = player.display_label
