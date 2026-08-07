extends SceneTree

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()
	assert(is_instance_valid(game.balance_lab_overlay))
	assert(game.balance_editor_hero_list.item_count == 58)
	assert(game.lab_player_board.get_child_count() == 15)
	assert(game.lab_enemy_board.get_child_count() == 15)
	assert(int(game.lab_player_board.get_child(0).board_row) == 0)
	assert(int(game.lab_enemy_board.get_child(0).board_row) == 0)
	assert(int(game.lab_enemy_board.get_child((game.BOARD_ROWS - 1) * game.BOARD_COLUMNS).board_row) == game.BOARD_ROWS - 1)
	game._set_lab_view_mode("result")
	assert(not game.lab_setup_panel.visible and game.lab_result_panel.visible)
	game._set_lab_view_mode("formation")
	assert(game.lab_setup_panel.visible and not game.lab_result_panel.visible)
	game._set_lab_view_mode("both")
	assert(game.lab_setup_panel.visible and game.lab_result_panel.visible)
	assert(game._minimum_skill_cooldown("zhangfei") == 0.0)
	assert(game._minimum_skill_cooldown("huangzhong") == 0.0)
	assert(game._minimum_skill_cooldown("guanyu") == 0.0)
	for cooldown_case in [["zhangfei", 6.5], ["huangzhong", 4.0]]:
		for hero_index in game.balance_editor_hero_list.item_count:
			if str(game.balance_editor_hero_list.get_item_metadata(hero_index)) != str(cooldown_case[0]): continue
			game._select_balance_hero(hero_index)
			assert(game.balance_editor_cooldown.min_value == 0.0)
			assert(game.balance_editor_cooldown.value == float(cooldown_case[1]))
			break

	# Quick lineup editing filters by faction, auto-places, and updates duplicates.
	game.lab_player_lineup.clear()
	game.lab_player_faction.select(1) # Shu
	game._refresh_lab_hero_option(true)
	assert(game.lab_player_hero.item_count == 15)
	game.lab_player_star.select(2)
	game._add_lab_unit(true)
	assert(game.lab_player_lineup.size() == 1)
	assert(game.lab_player_lineup[0].level == 3)
	game.lab_player_star.select(0)
	game._add_lab_unit(true)
	assert(game.lab_player_lineup.size() == 1)
	assert(game.lab_player_lineup[0].level == 1)
	assert(game.lab_player_lineup[0].row in game._preferred_lab_rows(game.lab_player_lineup[0].hero_id))
	var original_row: int = game.lab_player_lineup[0].row
	var original_col: int = game.lab_player_lineup[0].col
	assert(game._can_move_lab_unit(true, original_row, original_col, 1, 3))
	game._move_lab_unit(true, original_row, original_col, 1, 3)
	assert(game.lab_player_lineup[0].row == 1 and game.lab_player_lineup[0].col == 3)
	game.lab_player_lineup.append({"hero_id":"guanyu", "level":1, "row":0, "col":0})
	assert(not game._can_move_lab_unit(true, 0, 0, 2, 0))

	# Editing the skill base value also refreshes derived skill damage.
	var old_hero: Dictionary = game.heroes.xusheng.duplicate(true)
	var params: Dictionary = game._editable_ability_params("xusheng")
	game._apply_hero_override("xusheng", {"hp":1400, "skill_value":77, "cooldown":0.0, "range":3, "ability_params":params})
	assert(game.heroes.xusheng.hp == 1400)
	assert(game.heroes.xusheng.skill_value == 77)
	assert(game.heroes.xusheng.cooldown == 0.0)
	assert(game.balance_editor_cooldown.min_value == game._minimum_skill_cooldown(game.balance_editor_selected_id))
	assert(game.heroes.xusheng.ability_params.base_value == round(77.0 * float(params.mult)))
	game.heroes.xusheng = old_hero

	# Signature heroes expose their real multipliers and mechanics through the same JSON editor.
	var old_dianwei: Dictionary = game.heroes.dianwei.duplicate(true)
	var signature_params: Dictionary = game._editable_ability_params("dianwei")
	signature_params.mult = 2.25
	signature_params.skill_damage_reduction = 0.40
	game._apply_hero_override("dianwei", {"hp":1460, "skill_value":80, "cooldown":2.2, "range":1, "ability_params":signature_params})
	assert(game.heroes.dianwei.ability_params.mult == 2.25)
	var signature_actor: Dictionary = game._make_roster_unit("player", "dianwei")
	var signature_target: Dictionary = game._make_roster_unit("enemy", "caocao")
	signature_actor.row = 0; signature_actor.col = 0
	signature_target.row = 0; signature_target.col = 0
	signature_target.max_hp = 100000.0
	signature_target.hp = signature_target.max_hp
	game.combat_units = [signature_actor, signature_target]
	for _attempt in 12:
		game._cast_dianwei_skill(signature_actor)
		if signature_target.skill_debuff == 0.40: break
	assert(signature_target.skill_debuff == 0.40)
	game.heroes.dianwei = old_dianwei

	# Live battle uses the selected formation, locks deployment, supports speed,
	# and restores the untouched campaign after a manual ending.
	game.lab_player_lineup = [{"hero_id":"guanyu", "level":2, "row":0, "col":1}]
	game.lab_enemy_lineup = [{"hero_id":"caocao", "level":3, "row":0, "col":3}]
	var saved_phase: String = game.phase
	var saved_player_units := JSON.stringify(game.player_units)
	var saved_enemy_units := JSON.stringify(game.enemy_units)
	var original_speed: float = game.game_speed
	game._start_lab_live_battle()
	game.tick_timer.stop()
	await process_frame
	assert(game.lab_live_battle)
	assert(game.phase == "combat" and game.battle_running and game.final_battle)
	assert(not game.lab_live_paused)
	assert(is_instance_valid(game.lab_live_pause_button))
	assert(game.lab_live_pause_button.text == "暂停" or game.lab_live_pause_button.text == "PAUSE")
	assert(game.player_units.size() == 1 and game.enemy_units.size() == 1)
	assert(game.player_units[0].hero_id == "guanyu" and game.player_units[0].level == 2)
	assert(game.enemy_units[0].hero_id == "caocao" and game.enemy_units[0].level == 3)
	var enemy_front_live_cell: Control = game.tile_cell_refs["enemy:0:3"]
	assert(enemy_front_live_cell == game.enemy_board.get_child((game.BOARD_ROWS - 1) * game.BOARD_COLUMNS + 3))
	assert(game.player_board.get_child(0).disabled)
	assert(not game.balance_lab_overlay.visible and game.lab_live_hud.visible)
	game._battle_tick()
	game.tick_timer.stop()
	assert(game.battle_time > 0.0)
	var paused_battle_time: float = game.battle_time
	var paused_actions: Array = game.combat_units.map(func(unit): return float(unit.action))
	game._toggle_lab_live_pause()
	assert(game.lab_live_paused and game.tick_timer.is_stopped())
	assert(game.lab_live_pause_button.text == "继续" or game.lab_live_pause_button.text == "RESUME")
	game._battle_tick()
	assert(game.battle_time == paused_battle_time)
	for unit_index in game.combat_units.size():
		assert(float(game.combat_units[unit_index].action) == float(paused_actions[unit_index]))
	game._toggle_lab_live_pause()
	assert(not game.lab_live_paused)
	game.tick_timer.stop()
	game._cycle_lab_live_speed()
	assert(game.game_speed != original_speed)
	while game.game_speed != original_speed:
		game._cycle_lab_live_speed()
	game._toggle_lab_live_pause()
	assert(game.lab_live_paused)
	game._request_end_lab_live_battle()
	assert(not game.lab_live_battle and not game.lab_live_hud.visible)
	assert(game.balance_lab_overlay.visible and game.lab_result_panel.visible)
	assert(game.lab_result.text.contains("实战演练结果") or game.lab_result.text.contains("LIVE BATTLE RESULT"))
	assert(game.phase == saved_phase)
	assert(JSON.stringify(game.player_units) == saved_player_units)
	assert(JSON.stringify(game.enemy_units) == saved_enemy_units)
	game._start_lab_live_battle()
	game.tick_timer.stop()
	assert(not game.lab_live_paused)
	game.enemy_ruler_hp = 0
	game._finish_battle()
	assert(not game.lab_live_battle and game.phase == saved_phase)
	assert(game.lab_status.text.contains("胜负") or game.lab_status.text.contains("winner"))
	assert(JSON.stringify(game.player_units) == saved_player_units)
	assert(JSON.stringify(game.enemy_units) == saved_enemy_units)

	# Fast battle uses real combat stats and accepts explicit stars/positions.
	var player := [{"hero_id":"guanyu", "level":2, "row":0, "col":0}]
	var enemy := [{"hero_id":"caocao", "level":1, "row":0, "col":0}]
	var result: Dictionary = game._simulate_fast_battle(player, enemy, 20260723)
	assert(result.winner in ["player", "enemy", "draw"])
	assert(result.duration > 0.0 and result.duration <= game.FAST_BATTLE_LIMIT + 0.001)
	assert(result.stats.size() == 2)
	for entry in result.stats:
		assert(entry.has("damage"))
		assert(entry.has("taken"))
		assert(entry.has("healing"))
		assert(entry.has("control"))

	quit()
