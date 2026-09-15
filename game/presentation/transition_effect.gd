extends CanvasLayer

@export_range(0.0, 1.0) var strength: float = 0.6
var amount: float = 0.0


func _process(delta: float) -> void:
	var game: BaseballMatch = get_parent()
	var active: bool = game.is_fast_forwarding() and game.transition_speed > 1 and not game.paused
	amount = move_toward(amount, strength if active else 0.0, delta * 4.0)
	$Glitch.visible = amount > 0.001
	$Glitch.material.set_shader_parameter("amount", amount)
