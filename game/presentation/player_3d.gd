class_name BaseballPlayerView
extends Node3D

## Colour a spent arm's strength fades toward as it tires on the mound.
const SPENT_TINT := Color(0.87, 0.35, 0.29)

var player: BaseballPlayer
var game: BaseballMatch
var stride: float = 0.0
var ground_height: float = 0.0
var ground_initialized: bool = false

@onready var ground_ray: RayCast3D = $GroundRay
@onready var sprite: Sprite3D = $Sprite
@onready var strength_label: Label3D = $Strength
@onready var dexterity_label: Label3D = $Dexterity
@onready var strength_tint: Color = strength_label.modulate
@onready var standing_height: float = sprite.position.y


func configure(actor: BaseballPlayer, color: Color, match_scene: BaseballMatch) -> void:
	player = actor
	game = match_scene
	sprite.modulate = color
	# Stats stand at the player's feet, strength on the left and dexterity on the
	# right, worded by the data so the match and the buy screen always agree.
	# Dexterity never moves; strength is rewritten every frame for a tiring arm.
	var stats := player.data.stat_texts()
	strength_label.text = stats[0]
	dexterity_label.text = stats[1]


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
	_show_strength()
	# A benched squad stands shoulder to shoulder, so the stats wait outside.
	var benched: bool = game.dugouts[player.team_index].contains(player.position)
	strength_label.visible = not benched
	dexterity_label.visible = not benched


## The arm on the mound counts its strength down as it tires, fading toward the
## spent tint. Everyone else stands at what they were bought with, including that
## same pitcher once they come up to bat, because hitting spends nothing.
func _show_strength() -> void:
	if player.role != "P" or player not in game.fielders:
		strength_label.text = BaseballPlayerData.stat_text(player.data.strength)
		strength_label.modulate = strength_tint
		return
	strength_label.text = BaseballPlayerData.stat_text(player.pitch_strength)
	var spent := 1.0 - float(player.pitch_strength) / maxf(1.0, float(player.data.strength))
	strength_label.modulate = strength_tint.lerp(SPENT_TINT, clampf(spent, 0.0, 1.0))
