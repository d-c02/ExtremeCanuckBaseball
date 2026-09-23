class_name BaseballPlayer
extends CharacterBody2D

var data: BaseballPlayerData
var target: Vector2
var waypoints: PackedVector2Array
var intention: String = "Waiting"
var reaction_remaining: float = 0.0
## A frozen field, for the kind that skates on it: what their top speed is
## multiplied by, and how much of the freeze is left to skate through.
var speed_multiplier: float = 1.0
var skating_remaining: float = 0.0
var moving: bool = false
var role: String = ""
var team_index: int = 0
var roster_index: int = 0
## Place among the team's present players; open roster slots are skipped.
var lineup_index: int = 0

## Live pitching strength. Strikeouts drain it and contact refreshes it, while
## the Resource keeps the value the player was bought with.
var pitch_strength: int = 0

var swing_visible: bool = false
var swing_progress: float = 0.0


func configure(player_data: BaseballPlayerData) -> void:
	data = player_data
	target = position
	refresh_strength()


## What this player is covering ground at right now: what they were bought with,
## unless a frozen field is under a pair of skates.
func current_speed() -> float:
	return data.speed * speed_multiplier


## Restore the pitching strength bought in the buy phase.
func refresh_strength() -> void:
	pitch_strength = data.strength


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


## The field ices over for [param seconds]. Most players stand and stare on top of
## whatever reaction is already running, keeping their assignment but unable to act
## on it yet; a kind at home on ice skates through it instead and covers ground
## faster for as long as it lasts.
func chill(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var skating := data.skating_gain()
	if skating > 0.0:
		speed_multiplier = 1.0 + skating
		skating_remaining = maxf(skating_remaining, seconds)
		return
	reaction_remaining += seconds
	velocity = Vector2.ZERO


func brake(action: String = "Settling") -> void:
	var stopping_distance := velocity.length_squared() / (2.0 * data.acceleration)
	move_to(position + velocity.normalized() * stopping_distance, action)


func step(delta: float) -> void:
	if skating_remaining > 0.0:
		skating_remaining = maxf(0.0, skating_remaining - delta)
		if skating_remaining == 0.0:
			speed_multiplier = 1.0
	if not moving:
		return
	reaction_remaining = maxf(0.0, reaction_remaining - delta)
	if reaction_remaining > 0.0:
		return
	var offset := target - position
	var arrival_speed := minf(current_speed(), sqrt(2.0 * data.acceleration * offset.length()))
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
