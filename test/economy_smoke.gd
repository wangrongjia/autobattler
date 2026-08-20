extends SceneTree

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame

	game.talent_levels = {}
	game._start_tianshu_game()
	assert(game.round_number == 1 and game.phase == "draft")
	assert(game.gold == 320, "首回合应为初始 200 + 利息 20 + 收入 100")

	game.gold = 500
	game.round_number = 2
	game.economy_income_round = 1
	var settlement: Dictionary = game._settle_round_economy()
	assert(settlement.interest == 50 and settlement.income == 150)
	assert(game.gold == 700)

	game.talent_levels = {"all:开源":1, "all:生财":2, "all:重利":2}
	assert(game._gold_interest_cap() == 80)
	assert(game._round_base_gold_income() == 190)

	game.talent_levels = {}
	game.round_number = 3
	game.economy_income_round = 2
	game.phase = "combat"
	game.battle_running = false
	game._prepare_round()
	assert(game.phase == "tianshu" and game.tianshu_draw_reason == "free")
	assert(game.tianshu_choices.size() == 3)
	game._choose_tianshu(game.tianshu_choices[0])
	assert(game.phase == "draft")

	game.phase = "draft"
	game.gold = 500
	assert(game._buy_tianshu_draw())
	assert(game.gold == 0 and game.phase == "tianshu")
	game._choose_tianshu(game.tianshu_choices[0])
	assert(game.phase == "draft")

	game.phase = "placement"
	game.gold = 1000
	game.tianshu_levels = {"pojun":2}
	game.tianshu_replacements_this_round = 0
	assert(game._replace_tianshu("pojun"))
	assert(game.gold == 700 and game.phase == "tianshu")
	assert(game.tianshu_draws_remaining == 2 and not game.tianshu_levels.has("pojun"))
	game._choose_tianshu(game.tianshu_choices[0])
	assert(game.phase == "tianshu" and game.tianshu_draws_remaining == 1)
	game._choose_tianshu(game.tianshu_choices[0])
	assert(game.phase == "placement")

	var reserve = game._make_roster_unit("player", "sunshangxiang")
	var deployed = game._make_roster_unit("player", "guanyu")
	deployed.row = 0
	deployed.col = 0
	game.player_units = [reserve, deployed]
	game.phase = "placement"
	game.gold = 0
	assert(game._can_drop_board(Vector2.ZERO, {"unit_id":reserve.id}, 0, 0))
	game._drop_board(Vector2.ZERO, {"unit_id":reserve.id}, 0, 0)
	assert(reserve.row == 0 and reserve.col == 0)
	assert(deployed.row == -1 and deployed.col == -1)
	assert(not game._can_drop_reserve(Vector2.ZERO, {"unit_id":reserve.id}, 0))
	game._drop_sell(Vector2.ZERO, {"unit_id":reserve.id})
	assert(game.gold == 70 and game._find_by_id(game.player_units, reserve.id) == null)
	game._drop_sell(Vector2.ZERO, {"unit_id":deployed.id})
	assert(game.gold == 170 and game._find_by_id(game.player_units, deployed.id) == null)

	game.game_mode = "tianshu"
	game.tianshu_levels = {"jungong_juezhi":2, "mage_guoshi":2}
	game.gold = 0
	var killer = game._make_roster_unit("player", "zhaoyun")
	var enemy = game._make_roster_unit("enemy", "caocao")
	game._tianshu_on_kill(killer, enemy)
	assert(game.gold == 70 and float(killer.get("tianshu_kill_strategy_bonus", 0.0)) == 5.0)
	var ally = game._make_roster_unit("player", "zhangfei")
	game._tianshu_on_kill(enemy, ally)
	assert(game.gold == 160)

	game.gold = 987
	game.economy_income_round = 7
	game.tianshu_replacements_this_round = 1
	var economy_state: Dictionary = game._economy_save_state().duplicate(true)
	game.gold = 0
	game.economy_income_round = 0
	game.tianshu_replacements_this_round = 0
	game._load_economy_state(economy_state)
	assert(game.gold == 987 and game.economy_income_round == 7)
	assert(game.tianshu_replacements_this_round == 1)
	game.game_mode = "challenge"
	game.selected_stage = 23
	game.selected_difficulty = 4
	game.phase = "placement"
	var save_existed := FileAccess.file_exists(game.SAVE_PATH)
	var original_save := ""
	if save_existed:
		var original_file := FileAccess.open(game.SAVE_PATH, FileAccess.READ)
		original_save = original_file.get_as_text()
		original_file.close()
	assert(game._save_game(true), "闯关的非战斗阶段应允许中途存档")
	game.selected_stage = 1
	game.selected_difficulty = 0
	game.gold = 0
	assert(game._load_game())
	assert(game.selected_stage == 23 and game.selected_difficulty == 4)
	assert(game.gold == 987 and game.tianshu_replacements_this_round == 1)
	if save_existed:
		var restore_file := FileAccess.open(game.SAVE_PATH, FileAccess.WRITE)
		restore_file.store_string(original_save)
		restore_file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SAVE_PATH))
	game._end_economy_run()
	assert(game.gold == 0)

	print("ECONOMY_SMOKE_OK")
	quit()
