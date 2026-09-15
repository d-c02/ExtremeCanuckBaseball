extends Node

@export var enabled: bool = true
@export_group("Clips")
@export var footstep_dirt: AudioStream
@export var footstep_grass: AudioStream
@export var throw_ball: AudioStream
@export var flight: AudioStream
@export var hit: AudioStream
@export var catch_ball: AudioStream
@export var out: AudioStream
@export var strike: AudioStream
@export var strikeout: AudioStream
@export var foul: AudioStream
@export var change_sides: AudioStream
@export var home_run: AudioStream
@export_group("Mix")
@export_range(-50, 0) var footsteps_db: float = -24.0
@export_range(-50, 0) var actions_db: float = -14.0
@export_range(-50, 0) var calls_db: float = -14.0
@export_range(-50, 0) var flight_db: float = -32.0

var voices: Array[AudioStreamPlayer2D] = []
var voice_index: int = 0
var step_cursor: int = 0
var step_cooldown: float = 0.0
var last_positions: Dictionary = {}
var walked: Dictionary = {}

@onready var game: BaseballMatch = get_parent()
@onready var calls: AudioStreamPlayer = $Calls
@onready var airborne: AudioStreamPlayer2D = $Flight

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		enabled = false
	for index in 8:
		var voice := AudioStreamPlayer2D.new()
		voice.max_distance = 1800.0
		add_child(voice)
		voices.append(voice)
	game.ball_thrown.connect(func(point): _at(throw_ball, point))
	game.ball_hit.connect(func(_quality): _at(hit, game.ball.position))
	game.ball_caught.connect(func(player): _at(catch_ball, player.position))
	game.out_recorded.connect(_on_out)
	game.strike_called.connect(func(is_strikeout): _call(strikeout if is_strikeout else strike))
	game.foul_called.connect(func(): _at(hit, game.home.position); _call(foul))
	game.sides_changed.connect(func(): _call(change_sides))
	game.home_run.connect(func(): _call(home_run))

func _at(clip: AudioStream, point: Vector2, volume: float = actions_db, pitch: float = 1.0) -> void:
	if not enabled or clip == null or game.paused:
		return
	var voice := voices[voice_index]
	voice_index = (voice_index + 1) % voices.size()
	voice.stop()
	voice.stream = clip
	voice.global_position = point
	voice.volume_db = volume
	voice.pitch_scale = pitch
	voice.play()

func _call(clip: AudioStream) -> void:
	if not enabled or clip == null or game.paused:
		return
	calls.stream = clip
	calls.volume_db = calls_db
	calls.play()

func _on_out(_player: BaseballPlayer) -> void:
	if game.phase != game.Phase.PITCH:
		_call(out)

func _process(delta: float) -> void:
	if not enabled or game.paused or game.phase == game.Phase.READY or not game.error_message.is_empty():
		airborne.stop()
		calls.stop()
		for voice in voices:
			voice.stop()
		last_positions.clear()
		walked.clear()
		return
	_update_flight(delta)
	_step_sounds(delta)

func _update_flight(delta: float) -> void:
	var ball := game.ball
	var audible := game.phase in [game.Phase.PITCH, game.Phase.FIELDING, game.Phase.THROW, game.Phase.FOUL]
	if not audible or ball.held or ball.height <= 1.0 or flight == null:
		airborne.stop()
		return
	airborne.global_position = ball.position
	airborne.volume_db = flight_db
	airborne.pitch_scale = lerpf(airborne.pitch_scale, lerpf(0.7, 1.8, clampf(ball.height / 200.0, 0, 1)), 1.0 - exp(-8.0 * delta))
	if not airborne.playing:
		airborne.stream = flight
		airborne.play()

func _step_sounds(delta: float) -> void:
	step_cooldown = maxf(0.0, step_cooldown - delta)
	var players := game.get_node("Players").get_children()
	for player in players:
		var previous: Vector2 = last_positions.get(player, player.position)
		var distance: float = previous.distance_to(player.position)
		last_positions[player] = player.position
		walked[player] = float(walked.get(player, 0.0)) + (distance if distance < 100.0 else 0.0)
	if step_cooldown > 0.0:
		return
	for offset in players.size():
		var index := (step_cursor + offset) % players.size()
		var player: BaseballPlayer = players[index]
		if not player.moving or player.velocity.length() < 25.0 or walked[player] < 28.0:
			continue
		walked[player] = 0.0
		step_cursor = (index + 1) % players.size()
		step_cooldown = 0.09
		var clip := footstep_grass if player.position.y < -250.0 else footstep_dirt
		_at(clip, player.position, footsteps_db, 0.95 + (index % 3) * 0.05)
		break
