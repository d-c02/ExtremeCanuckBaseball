class_name BaseballRunEnd
extends CanvasLayer

## Banks a finished match into the run and offers the way back. The purse and the
## life are settled once, the moment the match calls it, so a replay of the same
## scene cannot bank it twice.

const SHOP_SCENE := "res://game/buy_screen.tscn"

var banked: bool = false

@onready var game: BaseballMatch = get_node_or_null("../Simulation")
@onready var label: Label = $Result
@onready var button: Button = $Continue


func _ready() -> void:
	visible = false
	button.pressed.connect(_leave)
	if game != null:
		game.game_finished.connect(_on_game_finished)


## The player bats second, so the home score is theirs.
func _on_game_finished(scores: Array[int]) -> void:
	if banked or not BaseballSession.ready_to_play():
		return
	banked = true
	var won := scores[1] > scores[0]
	BaseballSession.finish_match(won)
	visible = true
	var purse := "+$%d" % BaseballSession.MATCH_PURSE
	if BaseballSession.over():
		label.text = "Beaten, and out of lives"
		button.text = "New run"
		return
	label.text = "%s  %s%s" % [
		"Won" if won else "Lost",
		purse,
		"" if won else ", and a life with it"
	]
	button.text = "Round %d" % BaseballSession.round_number


func _leave() -> void:
	if BaseballSession.over():
		BaseballSession.begin()
	get_tree().change_scene_to_file(SHOP_SCENE)
