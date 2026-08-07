extends SceneTree

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()
	game.language = "zh"

	var rows: Array[Dictionary] = []
	var hero_ids: Array = game.heroes.keys()
	hero_ids.sort()
	for hero_id in hero_ids:
		var hero: Dictionary = game.heroes[hero_id]
		rows.append({
			"id": hero_id,
			"zh": hero.get("zh", ""),
			"en": hero.get("en", ""),
			"faction": hero.get("f", ""),
			"roles": hero.get("roles", []),
			"hp": hero.get("hp", 0),
			"atk": hero.get("atk", 0),
			"spd": hero.get("spd", 0.0),
			"range": hero.get("range", 0),
			"skill": hero.get("zh_skill", ""),
			"ability": hero.get("ability", ""),
			"ability_params": hero.get("ability_params", {}),
			"skill_detail": game._skill_detail(hero_id),
			"bond_detail": game._hero_bond_detail(hero_id),
			"star_values": game._star_skill_values(hero_id, 1)
		})

	var snapshot := {
		"game_version": ProjectSettings.get_setting("application/config/version", ""),
		"ruler_max_hp": game.RULER_MAX_HP,
		"hero_count": rows.size(),
		"heroes": rows
	}
	var output_dir := ProjectSettings.globalize_path("res://outputs/three_kingdoms_balance_refactor")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var output := FileAccess.open(output_dir.path_join("runtime_balance_snapshot.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(snapshot, "\t"))
	output.close()
	print("BALANCE_SNAPSHOT_BEGIN")
	print(JSON.stringify(snapshot))
	print("BALANCE_SNAPSHOT_END")
	quit()
