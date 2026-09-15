class_name BaseballTeamData
extends Resource

@export var team_name: String = "Team"
@export var color: Color = Color.WHITE
## Roster order is the batting order. Field positions use matching indices.
@export var players: Array[BaseballPlayerData] = []
@export var field_positions: PackedVector2Array = PackedVector2Array()
@export var field_roles: PackedStringArray = PackedStringArray()
