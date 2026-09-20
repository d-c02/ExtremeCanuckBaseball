extends CanvasLayer

@export var enabled: bool = true
@export_range(0.0, 1.0) var strength: float = 0.65

@onready var game: BaseballMatch = $"../Simulation"


func _process(_delta: float) -> void:
	visible = (
		enabled and not game.paused and game.transition_speed > 1 and game.is_fast_forwarding()
	)
	if visible:
		$Tracking.material.set_shader_parameter("strength", strength)
		$Indicator.text = ">> FF  %dx" % game.transition_speed
