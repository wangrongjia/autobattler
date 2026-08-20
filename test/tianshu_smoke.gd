extends SceneTree

func _init() -> void:
	var packed: PackedScene = load("res://ThreeKingdom/ThreeKingdom.tscn")
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	assert(game.TIANSHU_BOOKS.size() == 48)
	game._start_quick_game()
	assert(not game._tianshu_enabled() and game.phase == "draft")
	game._start_tianshu_game()
	assert(game._tianshu_enabled() and game.phase == "tianshu")
	assert(game.tianshu_choices.size() == 3)
	assert(game.tianshu_choices.duplicate().all(func(book_id): return game.TIANSHU_BOOKS.has(book_id)))
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
	game.tianshu_choices.assign([selected, "pojun", "fengchi"])
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
	assert(is_equal_approx(game._tianshu_strategy_bonus(unit), 16.0))
	assert(is_equal_approx(float(unit.max_hp), unit_base_hp * 1.16))
	assert(is_equal_approx(game._tianshu_cooldown_reduction(unit), 0.5))
	game._apply_tianshu_battle_start()
	assert(is_equal_approx(float(unit.max_hp), unit_base_hp * 1.16))
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
	game._reset_tianshu_run()
	game.limit_challenges = false
	assert(game._start_challenge(1, 2) and game.phase == "draft")
	assert(game._start_challenge(1, 3) and game.phase == "tianshu")
	assert(is_instance_valid(game.tianshu_overlay))
	assert(is_instance_valid(game.tianshu_header_button))
	print("TIANSHU_SMOKE_OK")
	quit()
