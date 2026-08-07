extends SceneTree

func _place(game, team: String, hero_id: String, row: int, col: int) -> Dictionary:
	var unit: Dictionary = game._make_roster_unit(team, hero_id)
	unit.row = row
	unit.col = col
	return unit

func _progress(entries: Array, bond_id: String) -> Dictionary:
	for entry in entries:
		if str(entry.id) == bond_id:
			return entry
	return {}

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()

	var guanyu := _place(game, "player", "guanyu", 0, 0)
	var zhangfei := _place(game, "player", "zhangfei", 1, 0)
	var zhaoyun := _place(game, "player", "zhaoyun", 1, 1)
	var huangzhong := _place(game, "player", "huangzhong", 2, 1)
	var machao := _place(game, "player", "machao", 1, 2)
	var player_team: Array = [guanyu, zhangfei, zhaoyun, huangzhong, machao]
	var enemy := _place(game, "enemy", "caocao", 0, 0)
	game.player_units = player_team
	game.enemy_units = [enemy]
	game.combat_units = player_team + [enemy]
	game._apply_combo_bonds(true, false)

	var entries: Array = game._bond_progress_entries(player_team)
	var five_tigers := _progress(entries, "five_tigers")
	assert(not five_tigers.is_empty())
	assert(bool(five_tigers.active))
	assert(int(five_tigers.count) == 5)
	assert(int(five_tigers.target) == 5)
	var shu_faction := _progress(entries, "han_expedition")
	assert(bool(shu_faction.active))
	assert(int(shu_faction.count) == 5)
	assert(int(shu_faction.target) == 8)
	assert(int(shu_faction.current_tier) == 5)

	var full_text: String = game._bond_text(player_team)
	assert(full_text.contains("已激活") or full_text.contains("ACTIVE"))
	assert(full_text.contains("五虎上将"))
	assert(full_text.contains("5/5"))
	assert(full_text.contains("待激活") or full_text.contains("PENDING"))
	assert(full_text.find("五虎上将") < full_text.find("桃园结义"))
	assert(full_text.contains("[color=#f3d27a]"))
	assert(full_text.contains("[color=#74787d]"))

	# A death immediately removes the fallen hero from every progress counter.
	machao.hp = 1.0
	game._damage(enemy, machao, 100000.0, "physical", "bond progress test")
	assert(not machao.alive)
	var after_death_entries: Array = game._bond_progress_entries(player_team)
	five_tigers = _progress(after_death_entries, "five_tigers")
	assert(not bool(five_tigers.active))
	assert(int(five_tigers.count) == 4)
	assert(int(five_tigers.target) == 5)
	assert(game.bonds_label.text.contains("4/5"))
	assert(not game.bonds_label.text.contains("五虎上将[/b]  5/5"))

	quit()
