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
## How many shop actions a rolled team tries before it gives up on its money.
const SPEND_ATTEMPTS: int = 400
## The battery a rolled team signs before it merges anybody, and how often it puts
## a bought player into somebody rather than an open spot.
const BATTERY: int = 2
const MERGE_CHANCE: float = 0.4
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


## Roll a team by shopping with [param budget]: the money the run has paid the
## player by now. It works its own shelf, buying whatever it can use and paying the
## rising price of a fresh one once the shelf holds nothing for it. Rerolls are what
## it takes to keep spending, not a habit copied off the player. A pitcher and a
## catcher are signed before anybody is merged, so a match always has a battery.
static func roll_opponent(
	rng: RandomNumberGenerator, roster: BaseballTeamData, shelf: BaseballShelf, budget: int
) -> BaseballTeamData:
	var team := BaseballTeamData.new()
	team.team_name = TEAM_NAMES[rng.randi() % TEAM_NAMES.size()]
	team.color = Color(TEAM_COLORS[rng.randi() % TEAM_COLORS.size()])
	team.field_positions = roster.field_positions.duplicate()
	team.field_roles = roster.field_roles.duplicate()
	team.players.resize(team.field_roles.size())
	if shelf.types.is_empty():
		return team
	var order := _spots(rng, team.field_roles, team.field_roles.size())
	var taken := PackedStringArray()
	var signed: Array[BaseballPlayerData] = []
	var left := budget
	var refreshes := 0
	shelf.restock(rng, taken)
	for attempt in SPEND_ATTEMPTS:
		var spent := _buy_from(rng, shelf, team, order, signed, left)
		if spent > 0:
			left -= spent
			continue
		refreshes += 1
		if refreshes > left:
			break
		left -= refreshes
		shelf.restock(rng, taken)
	team.finish_shopping()
	return team


## Take one thing off the shelf and put it to work. Returns what it cost, or nothing
## when the shelf holds nothing this team can use for the money it has left.
static func _buy_from(
	rng: RandomNumberGenerator,
	shelf: BaseballShelf,
	team: BaseballTeamData,
	order: Array[int],
	signed: Array[BaseballPlayerData],
	left: int
) -> int:
	var player_picks: Array[int] = []
	for index in shelf.players.size():
		var candidate := shelf.players[index]
		if candidate.value() > left:
			continue
		if signed.size() < order.size() or _host_for(rng, candidate, signed) != null:
			player_picks.append(index)
	var snack_picks: Array[int] = []
	if not signed.is_empty():
		for index in shelf.snacks.size():
			if shelf.snacks[index].price <= left:
				snack_picks.append(index)
	var choices := player_picks.size() + snack_picks.size()
	if choices == 0:
		return 0
	var choice := rng.randi() % choices
	if choice < player_picks.size():
		var player: BaseballPlayerData = shelf.players[player_picks[choice]]
		shelf.players.remove_at(player_picks[choice])
		return _take(rng, player, team, order, signed)
	var index: int = snack_picks[choice - player_picks.size()]
	var snack: BaseballFoodType = shelf.snacks[index]
	shelf.snacks.remove_at(index)
	signed[rng.randi() % signed.size()].eat(snack)
	return snack.price


## Sign a bought player, or merge them into one of their kind. The battery is signed
## first whatever else is on offer, and after that a merge is a coin toss against an
## open spot.
static func _take(
	rng: RandomNumberGenerator,
	player: BaseballPlayerData,
	team: BaseballTeamData,
	order: Array[int],
	signed: Array[BaseballPlayerData]
) -> int:
	var price := player.value()
	var open := signed.size() < order.size()
	var host := _host_for(rng, player, signed)
	if host != null and (not open or (signed.size() >= BATTERY and rng.randf() < MERGE_CHANCE)):
		host.absorb(player)
		return price
	if not open:
		return 0
	team.players[order[signed.size()]] = player
	signed.append(player)
	return price


## Somebody already signed who could take [param player] in, picked at random from
## everybody who could.
static func _host_for(
	rng: RandomNumberGenerator, player: BaseballPlayerData, signed: Array[BaseballPlayerData]
) -> BaseballPlayerData:
	var hosts: Array[BaseballPlayerData] = []
	for host in signed:
		if host.can_absorb(player):
			hosts.append(host)
	if hosts.is_empty():
		return null
	return hosts[rng.randi() % hosts.size()]


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


