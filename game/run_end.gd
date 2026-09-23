class_name BaseballRunEnd
extends CanvasLayer

## Banks a finished match once and offers the way back to the shop.

const SHOP_SCENE := "res://game/buy_screen.tscn"

var banked: bool = false
var session_match: bool = false

@onready var game: BaseballMatch = get_node_or_null("../Simulation")
@onready var label: Label = $Result
@onready var button: Button = $Continue


func _ready() -> void:
	visible = false
	session_match = BaseballSession.ready_to_play()
	button.pressed.connect(_leave)
	if game != null:
		game.game_reset.connect(_on_game_reset)
		game.game_finished.connect(_on_game_finished)


func _on_game_finished(_scores: Array[int]) -> void:
	if not session_match:
		return
	var won := game.winner() == 1
	var replayed := banked
	if not replayed:
		banked = true
		BaseballSession.finish_match(won)
	visible = true
	if BaseballSession.over():
		label.text = "RUN OVER"
		button.text = "New run"
	elif replayed:
		label.text = "%s  REPLAY" % ("WIN" if won else "LOSS")
		button.text = "Next shop"
	else:
		label.text = (
			"%s  +$%d%s"
			% ["WIN" if won else "LOSS", BaseballSession.MATCH_PURSE, "" if won else "  -1 LIFE"]
		)
		button.text = "Next shop"
	button.grab_focus()


func _on_game_reset() -> void:
	visible = false
	button.release_focus()


func _leave() -> void:
	if BaseballSession.over():
		BaseballSession.begin()
	get_tree().change_scene_to_file(SHOP_SCENE)
