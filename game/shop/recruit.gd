class_name BaseballRecruit

## Rolls the random players the shop sells and the teams it plays against. Every
## roll is asked for a price and builds stats worth exactly that, so what a team
## costs and what it can do never drift apart.

const NAMES: PackedStringArray = [
	"Jack",
	"Arthur",
	"Harrhy",
	"Moose",
	"Dutch",
	"Whit",
	"Ollie",
	"Red",
	"Lefty",
	"Buster",
	"Cal",
	"Mo",
	"Pinky",
	"Hoot",
	"Cyril",
	"Bug",
	"Rip",
	"Sparky",
	"Tuck",
	"Wally"
]
const TEAM_NAMES: PackedStringArray = [
	"Moose Jaw Mallets", "Red Deer Ramblers", "Sudbury Shovels", "Flin Flon Foxes"
]
## Kit colours the rolled teams wear, as hex the roll turns into a [Color].
const TEAM_COLORS: PackedStringArray = ["2f6fbb", "d9a227", "4c9a5a", "8a4fbe"]


## Roll a level one of one of [param types], with a name of their own for the box
## score. The caller picks what is on offer; the roll picks between them.
static func roll(
	rng: RandomNumberGenerator, types: Array[BaseballPlayerType], taken: PackedStringArray
) -> BaseballPlayerData:
	if types.is_empty():
		return null
	var player := types[rng.randi() % types.size()].recruit()
	player.player_name = roll_name(rng, taken)
	return player


static func roll_name(rng: RandomNumberGenerator, taken: PackedStringArray) -> String:
	for attempt in NAMES.size():
		var pick := NAMES[rng.randi() % NAMES.size()]
		if not taken.has(pick):
			return pick
	return NAMES[rng.randi() % NAMES.size()]


## Roll a team worth about as much as [param roster] and laid out on the same spots.
## A pitcher and a catcher are always signed; the rest of the spots go to as many
## other players as the roster it will face has filled. Everybody starts at level
## one, then the roll merges them up until the two teams are worth about the same.
static func roll_opponent(
	rng: RandomNumberGenerator, roster: BaseballTeamData, types: Array[BaseballPlayerType]
) -> BaseballTeamData:
	var team := BaseballTeamData.new()
	team.team_name = TEAM_NAMES[rng.randi() % TEAM_NAMES.size()]
	team.color = Color(TEAM_COLORS[rng.randi() % TEAM_COLORS.size()])
	team.field_positions = roster.field_positions.duplicate()
	team.field_roles = roster.field_roles.duplicate()
	var budget := 0
	var signed := 0
	for index in roster.field_roles.size():
		var player := roster.player_at(index)
		if player != null:
			budget += player.value()
			signed += 1
	var spots := _spots(rng, team.field_roles, maxi(signed, 2))
	var taken := PackedStringArray()
	var rolled: Array[BaseballPlayerData] = []
	team.players.resize(team.field_roles.size())
	for spot in spots:
		var player := roll(rng, types, taken)
		if player == null:
			continue
		taken.append(player.player_name)
		team.players[spot] = player
		rolled.append(player)
	_level_up_to(rng, rolled, budget)
	return team


## Level rolled players up one at a time, while doing so leaves the team nearer
## [param budget] than leaving it alone would.
static func _level_up_to(
	rng: RandomNumberGenerator, rolled: Array[BaseballPlayerData], budget: int
) -> void:
	for attempt in rolled.size() * BaseballPlayerData.MAX_LEVEL:
		var worth := 0
		var candidates: Array[BaseballPlayerData] = []
		for player in rolled:
			worth += player.value()
			if player.level < BaseballPlayerData.MAX_LEVEL:
				candidates.append(player)
		if candidates.is_empty():
			return
		var pick: BaseballPlayerData = candidates[rng.randi() % candidates.size()]
		var probe: BaseballPlayerData = pick.duplicate()
		probe.gain_level()
		var after := worth - pick.value() + probe.value()
		if absi(after - budget) >= absi(worth - budget):
			return
		pick.gain_level()


## Pick which spots to fill: the pitcher and the catcher first, then a random spread
## of the rest.
static func _spots(rng: RandomNumberGenerator, roles: PackedStringArray, count: int) -> Array[int]:
	var chosen: Array[int] = []
	for role in ["P", "C"]:
		var index := roles.find(role)
		if index >= 0:
			chosen.append(index)
	var rest: Array[int] = []
	for index in roles.size():
		if not chosen.has(index):
			rest.append(index)
	while chosen.size() < count and not rest.is_empty():
		chosen.append(rest.pop_at(rng.randi() % rest.size()))
	return chosen


