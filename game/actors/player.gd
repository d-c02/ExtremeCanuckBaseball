class_name BaseballPlayer
extends CharacterBody2D

var data: BaseballPlayerData
var target: Vector2
var waypoints: PackedVector2Array
var intention: String = "Waiting"
var reaction_remaining: float = 0.0
var moving: bool = false
var role: String = ""
var team_index: int = 0
var roster_index: int = 0
## Place among the team's present players; open roster slots are skipped.
var lineup_index: int = 0

var display_label: String = ""
var swing_visible: bool = false
var swing_progress: float = 0.0


func configure(player_data: BaseballPlayerData) -> void:
	data = player_data
	display_label = data.player_name
	target = position


func move_to(destination: Vector2, action: String, delay: float = 0.0) -> void:
	waypoints.clear()
	target = destination
	intention = action
	reaction_remaining = delay
	moving = true


func move_via(points: PackedVector2Array, action: String) -> void:
	move_to(points[0], action)
	waypoints = points.slice(1)


func stop(action: String = "Waiting") -> void:
	waypoints.clear()
	moving = false
	reaction_remaining = 0.0
	velocity = Vector2.ZERO
	intention = action


func brake(action: String = "Settling") -> void:
	var stopping_distance := velocity.length_squared() / (2.0 * data.acceleration)
	move_to(position + velocity.normalized() * stopping_distance, action)


func set_label(label: String) -> void:
	display_label = label


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
		if waypoints.is_empty():
			stop("In position")
		else:
			target = waypoints[0]
			waypoints.remove_at(0)


func show_swing(progress: float) -> void:
	swing_visible = true
	swing_progress = clampf(progress, 0.0, 1.0)
