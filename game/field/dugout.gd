extends Node2D


func seat_position(index: int) -> Vector2:
	return to_global(Vector2((index - 4) * 34, 0))


func on_deck_position() -> Vector2:
	return $OnDeck.global_position
