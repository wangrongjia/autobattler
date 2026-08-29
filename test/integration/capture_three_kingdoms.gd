extends SceneTree

func _initialize() -> void:
	var mode := OS.get_environment("CAPTURE_MODE")
	if mode.is_empty(): mode = "initial"
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	if mode == "english": game.language = "en"
	root.add_child(game)
	await process_frame
	if OS.get_environment("CAPTURE_THEME") == "light":
		# 绢纸亮色主题预览：重建界面层后按原流程截图。
		game.ui_theme = "light"
		game._rebuild_ui()
		await process_frame
	if mode not in ["initial", "codex", "bond_codex", "settings", "balance_lab", "quick_battle"]:
		game.menu_overlay.hide()
		game._render()
	if mode == "codex": game._show_encyclopedia()
	if mode == "settings": game._show_settings()
	if mode == "bond_codex":
		game._show_encyclopedia()
		game._set_encyclopedia_mode("bonds")
		var bond_faction := OS.get_environment("CAPTURE_FACTION")
		if bond_faction in ["shu", "wei", "wu", "qun"]:
			game._set_encyclopedia_faction(bond_faction)
	if mode in ["balance_lab", "quick_battle"]: game._show_balance_lab()
	if mode == "bond_progress":
		var player_setup := [
			["guanyu", 0, 0],
			["zhangfei", 1, 0],
			["zhaoyun", 1, 1],
			["huangzhong", 2, 1],
			["machao", 1, 2],
		]
		var enemy_setup := [["caocao", 0, 0], ["dianwei", 0, 1], ["xuchu", 0, 2]]
		game.player_units.clear()
		game.enemy_units.clear()
		for entry in player_setup:
			var unit: Dictionary = game._make_roster_unit("player", str(entry[0]))
			unit.row = int(entry[1])
			unit.col = int(entry[2])
			game.player_units.append(unit)
		for entry in enemy_setup:
			var unit: Dictionary = game._make_roster_unit("enemy", str(entry[0]))
			unit.row = int(entry[1])
			unit.col = int(entry[2])
			game.enemy_units.append(unit)
		game.combat_units = game.player_units + game.enemy_units
		game.phase = "combat"
		game.battle_running = true
		game._apply_combo_bonds(true, false)
		game._apply_faction_bonuses(false)
		game._render()
	if mode == "fire_effect":
		game.player_units.clear()
		game.enemy_units.clear()
		for entry in [["zhouyu", 2, 0], ["luxun", 2, 1], ["lusu", 2, 2], ["lvmeng", 0, 0]]:
			var unit: Dictionary = game._make_roster_unit("player", str(entry[0]))
			unit.row = int(entry[1])
			unit.col = int(entry[2])
			game.player_units.append(unit)
		for entry in [["caocao", 0, 0], ["dianwei", 0, 1], ["guojia", 2, 1], ["xuchu", 2, 2]]:
			var unit: Dictionary = game._make_roster_unit("enemy", str(entry[0]))
			unit.row = int(entry[1])
			unit.col = int(entry[2])
			unit.burn = 6.0
			unit.burn_damage = 30.0
			game.enemy_units.append(unit)
		game.combat_units = game.player_units + game.enemy_units
		game.phase = "combat"
		game.battle_running = true
		game._apply_combo_bonds(true, false)
		game._render()
	if mode == "quick_battle":
		game.balance_lab_tabs.current_tab = 1
		game.lab_player_lineup = [{"hero_id":"guanyu", "level":2, "row":0, "col":0}, {"hero_id":"liubei", "level":1, "row":2, "col":1}]
		game.lab_enemy_lineup = [{"hero_id":"caocao", "level":2, "row":0, "col":0}, {"hero_id":"guojia", "level":1, "row":2, "col":1}]
		game._refresh_lab_lineups()
		await game._run_fast_battles()
	if mode == "checkpoint":
		game._endless_start_game()
		game.menu_overlay.hide()
		var checkpoint_hero: Dictionary = game._make_roster_unit("player", "huanggai")
		checkpoint_hero.row = -1
		game.player_units.append(checkpoint_hero)
		game.round_number = 5
		game.gold = 3000
		game._endless_open_checkpoint()
		game._render()
		game.checkpoint_tabs.current_tab = 1
	if mode == "formation" or mode == "combat":
		game._choose_hero(game.choices[0])
		game._choose_hero(game.choices[0])
		game._choose_hero(game.choices[0])
		game._auto_place_player()
	if mode == "combat":
		game._start_battle()
		game.tick_timer.stop()
		for _step in 12:
			game._battle_tick()
			game.tick_timer.stop()
	await _settle()
	var filenames := {"initial":"three_kingdoms_screen.png", "draft":"three_kingdoms_draft.png", "codex":"three_kingdoms_codex.png", "bond_codex":"three_kingdoms_bond_codex.png", "settings":"three_kingdoms_settings.png", "bond_progress":"three_kingdoms_bond_progress.png", "fire_effect":"three_kingdoms_fire_effect.png", "balance_lab":"three_kingdoms_balance_lab.png", "quick_battle":"three_kingdoms_quick_battle.png", "checkpoint":"three_kingdoms_checkpoint.png", "english":"three_kingdoms_english.png", "formation":"three_kingdoms_formation.png", "combat":"three_kingdoms_combat.png"}
	_save(filenames[mode])
	quit()

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func _save(filename: String) -> void:
	var image := root.get_texture().get_image()
	var output_path := ProjectSettings.globalize_path("res://test/" + filename)
	var error := image.save_png(output_path)
	print(filename, " size=", image.get_size(), " result=", error)
	assert(error == OK)
