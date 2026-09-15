class_name BaseballPlayer
extends CharacterBody2D

var data: BaseballPlayerData
var target: Vector2
var intention: String = "Waiting"
var reaction_remaining: float = 0.0
var moving: bool = false
var role: String = ""
var team_index: int = 0
var roster_index: int = 0

@onready var body: Polygon2D = $Visuals/Body
@onready var bat: Polygon2D = $Visuals/Bat

func configure(player_data: BaseballPlayerData, team_color: Color) -> void:
	data = player_data
	body.color = team_color
	$Visuals/Name.text = role if not role.is_empty() else data.player_name
	target = position

func move_to(destination: Vector2, action: String, delay: float = 0.0) -> void:
	target = destination
	intention = action
	reaction_remaining = delay
	moving = true

func stop(action: String = "Waiting") -> void:
	moving = false
	reaction_remaining = 0.0
	velocity = Vector2.ZERO
	intention = action

func brake(action: String = "Settling") -> void:
	var stopping_distance := velocity.length_squared() / (2.0 * data.acceleration)
	move_to(position + velocity.normalized() * stopping_distance, action)

func set_label(label: String) -> void:
	$Visuals/Name.text = label

func step(delta: float) -> void:
	if not moving:
		return
	reaction_remaining = maxf(0.0, reaction_remaining - delta)
	if reaction_remaining > 0.0:
		return
	var offset := target - position
	var arrival_speed := minf(data.speed, sqrt(2.0 * data.acceleration * offset.length()))
	if offset.length() < 2.0:
		arrival_speed = 0.0
	velocity = velocity.move_toward(offset.normalized() * arrival_speed, data.acceleration * delta)
	move_and_slide()
	if position.distance_to(target) < 3.0 and velocity.length() < 25.0:
		stop("In position")

func show_swing(progress: float) -> void:
	bat.visible = true
	bat.rotation = lerpf(-1.8, 1.8, clampf(progress, 0.0, 1.0))
