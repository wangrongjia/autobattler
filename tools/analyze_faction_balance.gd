extends SceneTree

var runs_per_side := 30
var factions: Array[String] = ["shu", "wei", "wu"]

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--runs="): runs_per_side = maxi(1, int(argument.trim_prefix("--runs=")))
		if argument.begins_with("--factions="):
			factions.clear()
			for faction in argument.trim_prefix("--factions=").split(","):
				if faction in ["shu", "wei", "wu", "qun"]: factions.append(faction)
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()
	var report := {"runs_per_side":runs_per_side, "matchups":[], "factions":{}, "heroes":{}}
	for faction in factions: report.factions[faction] = {"wins":0, "losses":0, "draws":0, "games":0}
	for left_index in factions.size():
		for right_index in range(left_index + 1, factions.size()):
			var left := factions[left_index]
			var right := factions[right_index]
			var matchup := {"left":left, "right":right, "left_wins":0, "right_wins":0, "draws":0, "games":runs_per_side * 2, "average_duration":0.0, "orientations":[], "faction_stats":{left:{"damage":0.0,"taken":0.0,"healing":0.0,"control":0.0}, right:{"damage":0.0,"taken":0.0,"healing":0.0,"control":0.0}}}
			for orientation in 2:
				var player_faction := left if orientation == 0 else right
				var enemy_faction := right if orientation == 0 else left
				var orientation_row := {"player":player_faction, "enemy":enemy_faction, "player_wins":0, "enemy_wins":0, "draws":0}
				var player_lineup: Array = game._default_faction_lineup(player_faction)
				var enemy_lineup: Array = game._default_faction_lineup(enemy_faction)
				for run_index in runs_per_side:
					var seed := 20260808 + left_index * 1000003 + right_index * 10007 + orientation * 7919 + run_index * 104729
					var result: Dictionary = game._simulate_fast_battle(player_lineup, enemy_lineup, seed)
					matchup.average_duration = float(matchup.average_duration) + float(result.duration)
					var winning_faction := ""
					if result.winner == "player": winning_faction = player_faction
					elif result.winner == "enemy": winning_faction = enemy_faction
					if winning_faction.is_empty():
						matchup.draws = int(matchup.draws) + 1
						orientation_row.draws = int(orientation_row.draws) + 1
						report.factions[left].draws = int(report.factions[left].draws) + 1
						report.factions[right].draws = int(report.factions[right].draws) + 1
					else:
						if result.winner == "player": orientation_row.player_wins = int(orientation_row.player_wins) + 1
						else: orientation_row.enemy_wins = int(orientation_row.enemy_wins) + 1
						if winning_faction == left: matchup.left_wins = int(matchup.left_wins) + 1
						else: matchup.right_wins = int(matchup.right_wins) + 1
						report.factions[winning_faction].wins = int(report.factions[winning_faction].wins) + 1
						var losing_faction := right if winning_faction == left else left
						report.factions[losing_faction].losses = int(report.factions[losing_faction].losses) + 1
					for entry in result.stats:
						var hero_id := str(entry.hero_id)
						var entry_faction := str(game.heroes[hero_id].f)
						var faction_stats: Dictionary = matchup.faction_stats[entry_faction]
						for metric in ["damage", "taken", "healing", "control"]: faction_stats[metric] = float(faction_stats[metric]) + float(entry.get(metric, 0.0))
						matchup.faction_stats[entry_faction] = faction_stats
						if not report.heroes.has(hero_id): report.heroes[hero_id] = {"faction":str(game.heroes[hero_id].f), "games":0, "damage":0.0, "taken":0.0, "healing":0.0, "control":0.0}
						var row: Dictionary = report.heroes[hero_id]
						row.games = int(row.games) + 1
						for metric in ["damage", "taken", "healing", "control"]: row[metric] = float(row[metric]) + float(entry.get(metric, 0.0))
						report.heroes[hero_id] = row
				matchup.orientations.append(orientation_row)
			matchup.average_duration = float(matchup.average_duration) / float(matchup.games)
			for faction in [left, right]:
				var faction_stats: Dictionary = matchup.faction_stats[faction]
				for metric in ["damage", "taken", "healing", "control"]: faction_stats[metric] = float(faction_stats[metric]) / float(matchup.games)
				matchup.faction_stats[faction] = faction_stats
			report.matchups.append(matchup)
	for faction in factions:
		var faction_row: Dictionary = report.factions[faction]
		faction_row.games = int(faction_row.wins) + int(faction_row.losses) + int(faction_row.draws)
		faction_row.win_rate = (float(faction_row.wins) + float(faction_row.draws) * 0.5) / maxf(1.0, float(faction_row.games))
		report.factions[faction] = faction_row
	for hero_id in report.heroes:
		var row: Dictionary = report.heroes[hero_id]
		for metric in ["damage", "taken", "healing", "control"]: row[metric] = float(row[metric]) / maxf(1.0, float(row.games))
		report.heroes[hero_id] = row
	print("BALANCE_REPORT=" + JSON.stringify(report))
	game.free()
	quit()
