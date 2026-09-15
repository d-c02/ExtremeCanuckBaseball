extends Node2D

func _ready() -> void:
	$Order.rotation = -global_rotation
	$Order.global_position = global_position + Vector2(-160, 125)

func seat_position(index: int) -> Vector2:
	return to_global(Vector2((index - 4) * 34, 0))

func on_deck_position() -> Vector2:
	return $OnDeck.global_position

func show_order(team: BaseballTeamData, next_index: int, batting: bool) -> void:
	$Order.text = "%s: %s\nOrder: %d. %s" % [team.team_name, "BATTING" if batting else "FIELDING", next_index + 1, team.players[next_index].player_name]
	$Bench.color = team.color.darkened(0.6)
