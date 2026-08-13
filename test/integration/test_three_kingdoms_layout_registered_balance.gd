extends SceneTree

func _initialize() -> void:
	OS.set_environment("THREE_KINGDOM_MOBILE_UI_TEST", "1")
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()

	assert(game.BATTLE_LIMIT == 30.0)
	assert(not game.has_method("_rebalance_role_stats"))
	assert(not game.has_method("_scale_hero_health"))
	assert(game.REGISTERED_HERO_BALANCE.BASE_STATS.size() == game.heroes.size())
	assert(int(game.heroes.guanyu.hp) == 5180)
	assert(float(game.heroes.guanyu.skill_value) == 100.0)
	assert(float(game.heroes.caocao.cooldown) == 5.6)
	assert(int(game.heroes.zhouyu.range) == 3)
	assert(not game.heroes.daqiao.ability_params.has("base_heal"))
	var supported_abilities := ["signature", "strike", "strike_magic", "drain", "control", "row", "row_magic", "multi", "multi_magic", "heal", "heal_team", "shield_single", "shield_row", "shield_column", "buff_single", "buff_two", "buff_column", "buff_row_ranged", "buff_row_melee", "buff_self", "passive"]
	for hero in game.heroes.values():
		assert(str(hero.get("ability", "")) in supported_abilities)
	var project_overrides = game._read_json_file(game.BALANCE_PROJECT_PATH, {"invalid":true})
	assert(project_overrides is Dictionary and project_overrides.is_empty())

	assert(game.battle_info_tabs.get_tab_count() == 3)
	assert(game.battle_info_tabs.current_tab == 0)
	assert(game.battle_info_tabs.get_tab_title(0) in ["羁绊组成", "BONDS"])
	game.board_side = "left"
	game._apply_board_side_layout()
	assert(game.battle_workspace.get_child(0) == game.battle_arena_panel)
	game.board_side = "right"
	game._apply_board_side_layout()
	assert(game.battle_workspace.get_child(0) == game.battle_info_panel)

	var unit: Dictionary = game._make_roster_unit("player", "guanyu")
	game.language = "en"
	unit.row = 0
	unit.col = 0
	game.combat_units = [unit]
	game._toggle_unit_inspector(str(unit.id))
	assert(game.unit_inspector_overlay.visible)
	assert(game.unit_inspector_overlay.get_parent() == game.battle_info_host)
	assert(game.unit_inspector_detail.get_parent().get_meta("touch_scroll_enabled", false))
	game._toggle_unit_inspector(str(unit.id))
	assert(game.unit_inspector_overlay.visible)
	game._hide_unit_inspector()
	assert(not game.unit_inspector_overlay.visible)

	OS.unset_environment("THREE_KINGDOM_MOBILE_UI_TEST")
	quit()



