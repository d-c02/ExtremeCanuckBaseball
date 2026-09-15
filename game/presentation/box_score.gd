extends PanelContainer

@onready var game: BaseballMatch = get_parent().get_parent()
@onready var text: RichTextLabel = $Text


func _ready() -> void:
	hide()
	game.game_reset.connect(hide)
	game.play_finished.connect(func(_result): refresh())
	game.game_finished.connect(
		func(_scores):
			refresh()
			show()
	)


func _unhandled_key_input(event: InputEvent) -> void:
	if game.box_score == null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		visible = not visible
		if visible:
			refresh()


func refresh() -> void:
	var lines: Array[String] = [
		"FINAL BOX SCORE" if game.phase == game.Phase.FINISHED else "BOX SCORE",
		"B: close | Scroll for both teams",
		""
	]
	var heading := "Team             "
	for inning in game.inning:
		heading += "%3d" % (inning + 1)
	lines.append(heading + "    R   H  LOB")
	for team in game.box_score.teams:
		var row := "%-17s" % team.name.left(16)
		for inning in game.inning:
			row += "%3s" % (str(int(team.innings[inning])) if inning < team.innings.size() else "-")
		lines.append(row + "  %3d %3d %3d" % [team.R, team.H, team.LOB])
	for team in game.box_score.teams:
		lines.append("\n%s" % team.name)
		lines.append("Player          PA  AB   R   H  2B  3B  HR RBI   K  PO Bob")
		for player in team.players:
			var row := "%-15s" % player.name.left(14)
			for stat in ["PA", "AB", "R", "H", "2B", "3B", "HR", "RBI", "K", "PO", "bobbles"]:
				row += "%4d" % player[stat]
			lines.append(row)
		var p: Dictionary = team.pitching
		var pitching_outs: int = p.outs
		lines.append(
			(
				"Pitching: IP %d.%d | P %d | BF %d | H %d | R %d | K %d"
				% [int(pitching_outs / 3.0), pitching_outs % 3, p.P, p.BF, p.H, p.R, p.K]
			)
		)
	lines.append("\nPA: plate appearances | AB: at-bats | R: runs | H: hits")
	lines.append("RBI: runs batted in | K: strikeouts | PO: putouts | Bob: bobbles")
	lines.append("LOB: team runners left on base | IP: innings.outs | BF: batters faced")
	lines.append("Hits use simplified fielder's-choice scoring. Bobbles are not official errors.")
	text.text = "\n".join(lines)
