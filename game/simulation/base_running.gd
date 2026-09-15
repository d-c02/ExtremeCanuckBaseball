class_name BaseballBaseRunning
extends RefCounted

var runner: BaseballPlayer
var bases: PackedVector2Array
var reached: int = 0
var target_base: int = 1
var active: bool = false
var awarded_base: int = 0
var start_base: int = 0
var retired: bool = false
var scored: bool = false
var returning: bool = false
var contact_judgement: float = 0.0

func reset(player: BaseballPlayer, positions: PackedVector2Array) -> void:
	runner = player
	bases = positions
	reached = 0
	target_base = 1
	active = false
	awarded_base = 0
	start_base = 0
	retired = false
	scored = false
	returning = false

func advance(delay: float = 0.0) -> void:
	if reached >= 4:
		return
	target_base = reached + 1
	active = true
	runner.move_to(target_position(), "Running to %s" % base_name(target_base), delay)

func target_position() -> Vector2:
	return bases[target_base - 1] + Vector2(10, 9)

func step() -> void:
	if not active or runner.position.distance_to(target_position()) > 5.0:
		return
	reached = target_base
	active = false
	runner.stop("At %s" % base_name(reached))
	if returning:
		if reached > start_base:
			target_base -= 1
			active = true
			runner.move_to(target_position(), "Retouching base")
		else:
			returning = false
		return
	if reached < awarded_base:
		advance()

func return_to_start() -> void:
	scored = false
	awarded_base = 0
	returning = true
	target_base = maxi(start_base, reached)
	if reached > start_base and runner.position.distance_to(bases[reached - 1] + Vector2(10, 9)) < 5.0:
		target_base -= 1
	active = true
	runner.move_to(target_position(), "Retouching base")

static func base_name(index: int) -> String:
	return ["home", "first", "second", "third", "home"][index]
