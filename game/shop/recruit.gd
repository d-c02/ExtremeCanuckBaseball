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


## Roll a player worth [param price], splitting that worth between strength and
## dexterity at random so two players of a price still play differently.
static func roll(
	rng: RandomNumberGenerator, price: int, taken: PackedStringArray
) -> BaseballPlayerData:
	var player := BaseballPlayerData.new()
	player.player_name = roll_name(rng, taken)
	var average := inverse_lerp(
		float(BaseballPlayerData.MIN_VALUE), float(BaseballPlayerData.MAX_VALUE), float(price)
	)
	# Keep the tilt inside the range where the other stat can still balance it, so
	# the pair always averages out to the price that was asked for.
	var lowest := maxf(0.0, average * 2.0 - 1.0)
	var highest := minf(1.0, average * 2.0)
	var strength := clampf(average + rng.randf_range(-0.22, 0.22), lowest, highest)
	player.strength = roundi(strength * BaseballPlayerData.MAX_STAT)
	player.dexterity = roundi((average * 2.0 - strength) * BaseballPlayerData.MAX_STAT)
	return player


static func roll_name(rng: RandomNumberGenerator, taken: PackedStringArray) -> String:
	for attempt in NAMES.size():
		var pick := NAMES[rng.randi() % NAMES.size()]
		if not taken.has(pick):
			return pick
	return NAMES[rng.randi() % NAMES.size()]


## Roll a team worth about as much as [param roster] and laid out on the same spots.
## A pitcher and a catcher are always signed; the rest of the money is spread over
## as many other spots as the roster it will face has filled.
static func roll_opponent(rng: RandomNumberGenerator, roster: BaseballTeamData) -> BaseballTeamData:
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
	var prices := _prices(rng, budget, spots.size())
	var taken := PackedStringArray()
	team.players.resize(team.field_roles.size())
	for spot in spots.size():
		var player := roll(rng, prices[spot], taken)
		taken.append(player.player_name)
		team.players[spots[spot]] = player
	return team


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


## Split [param budget] over [param count] players a dollar at a time, so the spread
## is uneven but nobody breaks the price range.
static func _prices(rng: RandomNumberGenerator, budget: int, count: int) -> Array[int]:
	var prices: Array[int] = []
	for spot in count:
		prices.append(BaseballPlayerData.MIN_VALUE)
	var room := count * (BaseballPlayerData.MAX_VALUE - BaseballPlayerData.MIN_VALUE)
	var left := mini(maxi(budget - count * BaseballPlayerData.MIN_VALUE, 0), room)
	while left > 0:
		var pick := rng.randi() % count
		if prices[pick] < BaseballPlayerData.MAX_VALUE:
			prices[pick] += 1
			left -= 1
	return prices
