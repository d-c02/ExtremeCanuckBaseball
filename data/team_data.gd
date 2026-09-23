class_name BaseballTeamData
extends Resource

@export var team_name: String = "Team"
@export var color: Color = Color.WHITE
## Roster order is the batting order. Field positions use matching indices.
## A null or missing player leaves that slot open; the match skips it.
@export var players: Array[BaseballPlayerData] = []
@export var field_positions: PackedVector2Array = PackedVector2Array()
@export var field_roles: PackedStringArray = PackedStringArray()


func validation_error() -> String:
	if players.size() > 9 or field_positions.size() != 9 or field_roles.size() != 9:
		return "Each team needs nine field positions and roles, and at most nine players"
	for role in ["P", "C", "1B", "2B", "3B", "SS", "LF", "CF", "RF"]:
		if field_roles.count(role) != 1:
			return "Each team needs exactly one %s role" % role
	return ""


func player_at(index: int) -> BaseballPlayerData:
	return players[index] if index < players.size() else null


## Whether a player fills the slot for [param role].
func has_role(role: String) -> bool:
	var index := field_roles.find(role)
	return index >= 0 and player_at(index) != null


## Everything that happens as a team leaves the shop: every coach on it takes their
## teammates through a session, handing each of them their own level in both stats.
## A coach does not coach themselves, and two of them both put their work in.
func finish_shopping() -> void:
	var coaches: Array[BaseballPlayerData] = []
	for index in players.size():
		var player := player_at(index)
		if player != null and player.coaching_gain() > 0:
			coaches.append(player)
	for coach in coaches:
		var gain := coach.coaching_gain()
		for index in players.size():
			var player := player_at(index)
			if player == null or player == coach:
				continue
			player.strength = mini(player.strength + gain, BaseballPlayerData.MAX_STAT)
			player.dexterity = mini(player.dexterity + gain, BaseballPlayerData.MAX_STAT)
