class_name BaseballPlayerPool
extends Resource

## What the shop can stock, and when. Every kind of player names the round it starts
## turning up in, so a run opens up better players the further it gets.

@export var types: Array[BaseballPlayerType] = []


## The kinds on offer in [param round_number], earliest first.
func available(round_number: int) -> Array[BaseballPlayerType]:
	var open: Array[BaseballPlayerType] = []
	for type in types:
		if type != null and type.from_round <= round_number:
			open.append(type)
	return open
