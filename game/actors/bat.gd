class_name BaseballBat
extends Node2D

var owner_player: BaseballPlayer
var carrier: BaseballPlayer
var rack: Vector2
var height: float = 3.0
var dropping: bool = false
var follow_through: float = 0.0
var angle: float = -1.8


func reset() -> void:
	position = rack
	carrier = null
	height = 3.0
	dropping = false
	follow_through = 0.0


func step(delta: float) -> void:
	if carrier != null:
		position = carrier.position + Vector2(-10, 0)
		height = 25.0
		angle = PI + lerpf(-1.8, 1.8, carrier.swing_progress) if carrier.swing_visible else -1.8
		if follow_through > 0.0:
			follow_through -= delta
			carrier.show_swing(minf(1.0, carrier.swing_progress + delta / 0.24))
			if follow_through <= 0.0:
				carrier.swing_visible = false
				carrier = null
				dropping = true
	elif dropping:
		height = maxf(3.0, height - 100.0 * delta)
		dropping = height > 3.0
