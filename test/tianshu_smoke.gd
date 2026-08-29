extends SceneTree

func _init() -> void:
	var packed: PackedScene = load("res://ThreeKingdom/ThreeKingdom.tscn")
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	assert(game.TIANSHU_BOOKS.size() == 48)
	for removed_id in ["pool_shu_wu", "pool_shu_wei", "pool_shu_qun", "pool_wei_wu", "pool_wei_qun", "pool_wu_qun"]:
		assert(not game.TIANSHU_BOOKS.has(removed_id))
	for retained_id in ["pool_shu", "pool_wei", "pool_wu", "pool_qun"]:
		assert(game.TIANSHU_BOOKS.has(retained_id))
	for removed_id in ["qun_qimen", "qun_baijia"]:
		assert(not game.TIANSHU_BOOKS.has(removed_id))
	for added_id in ["qun_xiaoxiong", "qun_yujin"]:
		assert(game.TIANSHU_BOOKS.has(added_id))
	assert(game.TIANSHU_BOOKS.keys().filter(func(book_id): return game._tianshu_codex_faction(game.TIANSHU_BOOKS[book_id]) == "all").size() == 24)
	for faction in ["shu", "wei", "wu", "qun"]:
		assert(game.TIANSHU_BOOKS.keys().filter(func(book_id): return game._tianshu_codex_faction(game.TIANSHU_BOOKS[book_id]) == faction).size() == 6)
	game._start_quick_game()
	assert(not game._tianshu_enabled() and game.phase == "draft")
	game._start_tianshu_game()
	assert(game._tianshu_enabled() and game.phase == "draft")
	game.round_number = 3
	game.economy_income_round = 2
	game._prepare_round()
	assert(game.phase == "tianshu" and game.tianshu_draw_reason == "free")
	assert(game.tianshu_choices.size() == 3)
	assert(game.tianshu_choices.duplicate().all(func(book_id): return game.TIANSHU_BOOKS.has(book_id)))
	assert(game._tianshu_book_faction(game.TIANSHU_BOOKS[game.tianshu_choices[0]]).is_empty())
	assert(not game._tianshu_book_faction(game.TIANSHU_BOOKS[game.tianshu_choices[1]]).is_empty())
	assert(not game._tianshu_book_faction(game.TIANSHU_BOOKS[game.tianshu_choices[2]]).is_empty())
	var unique := {}
	for book_id in game.tianshu_choices: unique[book_id] = true
	assert(unique.size() == 3)
	var untouched_one: String = str(game.tianshu_choices[1])
	var untouched_two: String = str(game.tianshu_choices[2])
	game._refresh_tianshu_choice(0)
	assert(not game.tianshu_refresh_available[0])
	assert(game.tianshu_choices[1] == untouched_one and game.tianshu_choices[2] == untouched_two)
	var selected: String = str(game.tianshu_choices[0])
	game._choose_tianshu(selected)
	assert(game._tianshu_level(selected) == 1 and game.phase == "draft")
	game.phase = "tianshu"
	game.tianshu_choices.assign([selected, "pool_shu", "pool_wei"])
	game._choose_tianshu(selected)
	assert(game._tianshu_level(selected) == 2)
	game._reset_tianshu_run()
	game.game_mode = "tianshu"
	game.tianshu_levels = {"pojun":2, "tianbing":2, "fengchi":2}
	var unit = game._make_roster_unit("player", "sunshangxiang")
	var unit_base_hp := float(unit.max_hp)
	game.player_units = [unit]
	game.combat_units = [unit]
	game._apply_tianshu_battle_start()
	assert(is_equal_approx(game._tianshu_strategy_bonus(unit), 32.0))
	assert(is_equal_approx(float(unit.max_hp), unit_base_hp * 1.12))
	assert(is_equal_approx(game._tianshu_cooldown_haste(unit), 0.5 / float(game.heroes.sunshangxiang.cooldown) * 100.0))
	game._apply_tianshu_battle_start()
	assert(is_equal_approx(float(unit.max_hp), unit_base_hp * 1.12))
	game._reset_tianshu_run()
	game.game_mode = "quick"
	game.player_ruler_hp = 10000
	unit.hp = unit.max_hp
	game._heal_with_overflow(unit, unit, 1000.0)
	assert(game.player_ruler_hp == 10300)
	game.game_mode = "tianshu"
	game.tianshu_levels = {"zebe":1}
	game.player_ruler_hp = 10000
	game._heal_unit_only(unit, unit, 1000.0)
	assert(game.player_ruler_hp == 10500)
	game._reset_tianshu_run()
	game.game_mode = "tianshu"
	game.tianshu_levels = {"qun_xiaoxiong":2, "qun_yujin":1}
	var qun_survivor = game._make_roster_unit("player", "lvbu")
	var qun_fallen = game._make_roster_unit("player", "diaochan")
	game.combat_units = [qun_survivor, qun_fallen]
	game._apply_tianshu_battle_start()
	assert(is_equal_approx(game._tianshu_strategy_bonus(qun_survivor), 16.0))
	qun_fallen.alive = false
	game._tianshu_on_kill(null, qun_fallen)
	assert(is_equal_approx(float(qun_survivor.action), 10.0))
	assert(is_equal_approx(game._tianshu_strategy_bonus(qun_survivor), 22.0))
	game._reset_tianshu_run()
	game.game_mode = "tianshu"
	game.phase = "tianshu"
	game.tianshu_choices.assign(["pool_shu", "pool_wei", "pool_wu"])
	game._choose_tianshu("pool_shu")
	assert(game._active_tianshu_pool_factions() == ["shu"])
	for hero_id in game.choices: assert(game.heroes[hero_id].f == "shu")
	var saved_tianshu: Dictionary = game._tianshu_save_state().duplicate(true)
	game._reset_tianshu_run()
	game._load_tianshu_state(saved_tianshu)
	assert(game._tianshu_level("pool_shu") == 1 and game._active_tianshu_pool_factions() == ["shu"])
	game._choose_hero(str(game.choices[0]))
	assert(int(game.tianshu_pool_effect.get("remaining_picks", 0)) == 1)
	game._choose_hero(str(game.choices[0]))
	assert(game.tianshu_pool_effect.is_empty())
	game._load_tianshu_state({"levels":{"pool_shu_wu":2, "pool_shu":1}, "pool":{"book_id":"pool_shu_wu", "factions":["shu", "wu"], "end_round":9}})
	assert(not game.tianshu_levels.has("pool_shu_wu") and game._tianshu_level("pool_shu") == 1)
	assert(game.tianshu_pool_effect.is_empty())
	game._reset_tianshu_run()
	game.game_mode = "tianshu"
	game.phase = "placement"
	game.gold = 1000
	game.tianshu_levels = {"taozhu_yice":1}
	game.tianshu_replacements_this_round = 0
	assert(game._replace_tianshu("taozhu_yice"))
	assert(game._tianshu_candidates_for_slot(0, []).has("taozhu_yice"))
	game.tianshu_choices.assign(["taozhu_yice", "pool_shu", "pool_wei"])
	game._choose_tianshu("taozhu_yice")
	assert(game.gold == 1000 and game._tianshu_level("taozhu_yice") == 1)
	game.phase = "placement"
	game.gold = 1000
	game.tianshu_levels = {"pool_shu":1}
	game.tianshu_replacements_this_round = 0
	assert(game._replace_tianshu("pool_shu"))
	assert(game._tianshu_candidates_for_slot(1, []).has("pool_shu"))
	game._reset_tianshu_run()
	game.limit_challenges = false
	assert(game._start_challenge(1, 2) and game.phase == "draft")
	assert(game._start_challenge(1, 3) and game.phase == "draft")
	assert(is_instance_valid(game.tianshu_overlay))
	assert(is_instance_valid(game.tianshu_header_button))
	print("TIANSHU_SMOKE_OK")
	quit()
