class_name BaseballBoxScore
extends RefCounted

var teams: Array[Dictionary] = []
var plays: Array[Dictionary] = []


func _init(rosters: Array[BaseballTeamData]) -> void:
	for roster in rosters:
		# One row per present player, in lineup order; open roster slots have none.
		var players: Array[Dictionary] = []
		for player in roster.players:
			if player == null:
				continue
			players.append(
				{
					"name": player.player_name,
					"PA": 0,
					"AB": 0,
					"R": 0,
					"H": 0,
					"2B": 0,
					"3B": 0,
					"HR": 0,
					"RBI": 0,
					"K": 0,
					"PO": 0,
					"bobbles": 0
				}
			)
		teams.append(
			{
				"name": roster.team_name,
				"R": 0,
				"H": 0,
				"LOB": 0,
				"innings": [],
				"players": players,
				"pitching": {"P": 0, "BF": 0, "outs": 0, "H": 0, "R": 0, "K": 0}
			}
		)


func begin_half(side: int, inning: int) -> void:
	while teams[side].innings.size() < inning:
		teams[side].innings.append(0)


func record_play(game: BaseballMatch) -> void:
	var play := game.play
	var offense: Dictionary = teams[game.batting_side]
	var defense: Dictionary = teams[1 - game.batting_side]
	var batter: Dictionary = offense.players[game.batter.lineup_index]
	var pitching: Dictionary = defense.pitching
	begin_half(game.batting_side, game.inning)
	pitching.P += 1
	pitching.outs += play.outs_made
	# One pitch settles a plate appearance, so every play is a completed at-bat.
	batter.PA += 1
	batter.AB += 1
	pitching.BF += 1
	if play.strikeout:
		batter.K += 1
		pitching.K += 1
	var hit := play.hit_bases()
	if hit > 0:
		batter.H += 1
		offense.H += 1
		pitching.H += 1
		if hit >= 2:
			batter[{2: "2B", 3: "3B", 4: "HR"}[hit]] += 1
	var rbi := 0 if play.ground_double_play else play.pending_runs
	batter.RBI += rbi
	for index in play.pending_runs:
		var runner: BaseballPlayer = play.scoring_order[index]
		offense.players[runner.lineup_index].R += 1
	offense.R += play.pending_runs
	pitching.R += play.pending_runs
	offense.innings[game.inning - 1] += play.pending_runs
	plays.append(
		{
			"inning": game.inning,
			"side": game.batting_side,
			"batter": game.batter.lineup_index,
			"result": play.result,
			"outs": play.outs_made,
			"runs": play.pending_runs,
			"hit_bases": hit,
			"RBI": rbi
		}
	)


func to_dict() -> Dictionary:
	return {"teams": teams.duplicate(true), "plays": plays.duplicate(true)}
