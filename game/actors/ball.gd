class_name BaseballBall
extends Node2D

const GRAVITY: float = 420.0
var velocity: Vector2 = Vector2.ZERO
var height: float = 0.0
var vertical_velocity: float = 0.0
var previous_position: Vector2
var previous_height: float = 0.0
var held: bool = true
var bounced: bool = false
var gravity_enabled: bool = true


func launch(
	origin: Vector2, horizontal_velocity: Vector2, launch_height: float, upward_velocity: float
) -> void:
	position = origin
	previous_position = origin
	height = launch_height
	previous_height = height
	velocity = horizontal_velocity
	vertical_velocity = upward_velocity
	held = false
	bounced = false
	gravity_enabled = true


func step(delta: float) -> void:
	previous_position = position
	previous_height = height
	if held:
		return
	position += velocity * delta
	if not gravity_enabled:
		return
	if height > 0.0 or vertical_velocity > 0.0:
		vertical_velocity -= GRAVITY * delta
		height += vertical_velocity * delta
		if height <= 0.0:
			height = 0.0
			vertical_velocity = 0.0
			bounced = true
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 85.0 * delta)


func hold_at(point: Vector2) -> void:
	held = true
	position = point
	height = 25.0
	velocity = Vector2.ZERO
	vertical_velocity = 0.0
	previous_position = point
	previous_height = height
