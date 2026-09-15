class_name BaseballTeamData
extends Resource

@export var team_name: String = "Team"
@export var color: Color = Color.WHITE
## Roster order is the batting order. Field positions use matching indices.
@export var players: Array[BaseballPlayerData] = []
@export var field_positions: PackedVector2Array = PackedVector2Array()
@export var field_roles: PackedStringArray = PackedStringArray()


func validation_error() -> String:
	if players.size() != 9 or field_positions.size() != 9 or field_roles.size() != 9:
		return "Each team needs nine players, field positions, and field roles"
	for index in players.size():
		if players[index] == null:
			return "Player %d needs a player Resource" % (index + 1)
	for role in ["P", "C", "1B", "2B", "3B", "SS", "LF", "CF", "RF"]:
		if field_roles.count(role) != 1:
			return "Each team needs exactly one %s role" % role
	return ""
