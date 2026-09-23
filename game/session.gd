class_name BaseballSession

## The run: the money and lives it is played with, how far into it we are, the team
## the buy screen has signed, and the team rolled to play against it. Static rather
## than an autoload so a scene run on its own still compiles; a match opened by
## itself finds no teams here and falls back to the sample ones in its own scene.

const STARTING_FUNDS: int = 30
const STARTING_LIVES: int = 5
## What finishing a match pays, win or lose.
const MATCH_PURSE: int = 20

static var funds: int = STARTING_FUNDS
static var lives: int = STARTING_LIVES
## Rounds count from one, and are what a spawn pool opens up against.
static var round_number: int = 1
static var roster: BaseballTeamData
static var opponent: BaseballTeamData


## Start a fresh run, throwing away the team and the money of the last one.
static func begin() -> void:
	funds = STARTING_FUNDS
	lives = STARTING_LIVES
	round_number = 1
	roster = null
	opponent = null


static func carry(signed: BaseballTeamData, enemy: BaseballTeamData) -> void:
	roster = signed
	opponent = enemy


## Everything the run has paid out by the round it is on: what it started with, plus
## a purse for every round already played. It is what a rolled opponent is given to
## spend, so the two sides have had the same money through the same shop.
static func income() -> int:
	return STARTING_FUNDS + (round_number - 1) * MATCH_PURSE


static func ready_to_play() -> bool:
	return roster != null and opponent != null


## Bank a finished match: the purse either way, a life for a loss, and on to the
## next round. The team stays signed; only the opponent is thrown away.
static func finish_match(won: bool) -> void:
	funds += MATCH_PURSE
	if not won:
		lives -= 1
	round_number += 1
	opponent = null


static func over() -> bool:
	return lives <= 0


## Forget the carried teams, so the next match falls back to its own scene again.
static func clear() -> void:
	roster = null
	opponent = null
