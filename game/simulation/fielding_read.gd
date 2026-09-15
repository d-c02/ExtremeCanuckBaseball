class_name BaseballFieldingRead
extends RefCounted

var target: Vector2
var playable_in: float = 0.0
var refresh_remaining: float = 0.0
var error_direction: Vector2
var elapsed: float = 0.0
var was_bounced: bool = false

func _init(rng: RandomNumberGenerator) -> void:
	error_direction = Vector2(rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0)).limit_length(2.0)

func update(player: BaseballPlayer, game: BaseballMatch, delta: float, trajectory: Array[Dictionary]) -> void:
	elapsed += delta
	refresh_remaining -= delta
	var ball: BaseballBall = game.ball
	var nearby := ball.bounced and player.position.distance_to(ball.position) < 55.0
	if refresh_remaining > 0.0 and was_bounced == ball.bounced and not nearby:
		return
	was_bounced = ball.bounced
	refresh_remaining = lerpf(0.6, 0.12, player.data.anticipation)
	var uncertainty := lerpf(90.0, 4.0, player.data.anticipation) / (1.0 + elapsed * 0.7)
	uncertainty *= clampf(player.position.distance_to(ball.position) / 180.0, 0.0, 1.0)
	if ball.bounced:
		uncertainty *= 0.2
	for prediction in trajectory:
		var time: float = prediction.time
		target = game.outfield.clamp_inside(prediction.point + error_direction * uncertainty)
		playable_in = time
		var arrival := player.position.distance_to(target) / player.data.speed + player.reaction_remaining
		if prediction.home_run or (prediction.height <= 25.0 and arrival <= time):
			break
