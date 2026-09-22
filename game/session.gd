class_name BaseballSession

## Carries what the buy screen built into the match: the team the player signed and
## the one rolled to play against it. It is static rather than an autoload so a
## match run on its own still compiles and falls back to the sample teams in its own
## scene.

static var roster: BaseballTeamData
static var opponent: BaseballTeamData


static func carry(signed: BaseballTeamData, enemy: BaseballTeamData) -> void:
	roster = signed
	opponent = enemy


static func ready_to_play() -> bool:
	return roster != null and opponent != null


## Forget the carried teams, so the next match falls back to its own scene again.
static func clear() -> void:
	roster = null
	opponent = null
