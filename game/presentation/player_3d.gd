class_name BaseballPlayerView
extends Node3D

var player: BaseballPlayer
var stride: float = 0.0

@onready var sprite: Sprite3D = $Sprite
@onready var label: Label3D = $Label
@onready var bat: Node3D = $Bat
@onready var standing_height: float = sprite.position.y


func configure(actor: BaseballPlayer, color: Color) -> void:
	player = actor
	sprite.modulate = color


func sync(delta: float) -> void:
	position = BaseballWorld.world_position(player.position)
	stride += player.velocity.length() * delta * 0.12
	sprite.position.y = standing_height + (absf(sin(stride)) * 0.1 if player.moving else 0.0)
	label.text = player.display_label
	bat.visible = player.swing_visible
	bat.rotation.y = lerpf(-1.8, 1.8, player.swing_progress)
