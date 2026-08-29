extends SceneTree

func _init() -> void:
	var packed: PackedScene = load("res://ThreeKingdom/ThreeKingdom.tscn")
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	assert(game.STAGE_NAMES.size() == 20)
	assert(game.DIFFICULTIES.size() == 5)
	assert(game.RUNE_KINDS.size() == 12)
	assert(game.RUNE_TIERS.size() == 6)
	assert(game._challenge_soul_reward(1) == 1200)
	game.game_mode = "challenge"
	game.selected_stage = 1
	game.selected_difficulty = 0
	game.general_souls = 0
	game.general_stars = 0
	game.stage_star_records = {}
	game.player_ruler_hp = 80001
	var first_clear: Dictionary = game._complete_challenge(true)
	assert(first_clear.stars == 3)
	assert(first_clear.new_stars == 3)
	assert(first_clear.souls == 2000)
	assert(game.general_stars == 3 and game.general_souls == 2000)
	game.player_ruler_hp = 80000
	assert(game._challenge_stars_for_hp() == 2)
	game.player_ruler_hp = 50000
	assert(game._challenge_stars_for_hp() == 1)
	game._show_battle_result(first_clear)
	assert(game.result_detail_label.text.contains("将魂 +2000"))
	game.result_overlay.hide()
	game.player_ruler_hp = 60001
	var repeat_clear: Dictionary = game._complete_challenge(true)
	assert(repeat_clear.stars == 2 and repeat_clear.new_stars == 0)
	assert(repeat_clear.souls == 1600)
	game.enemy_ruler_hp = 40000
	var partial_loss: Dictionary = game._complete_challenge(false)
	assert(is_equal_approx(float(partial_loss.damage_ratio), 0.6))
	assert(partial_loss.souls == 720)
	assert(game.general_souls == 2000 + 1600 + 720)
	game._show_battle_result(partial_loss)
	assert(game.result_detail_label.text.contains("敌方主公战损 60%"))
	assert(game.result_detail_label.text.contains("将魂 +720"))
	game.result_overlay.hide()
	game.enemy_ruler_hp = game.RULER_MAX_HP
	var no_damage_loss: Dictionary = game._complete_challenge(false)
	assert(no_damage_loss.souls == 0)
	assert(game.general_souls == 2000 + 1600 + 720)
	game.selected_stage = 20
	game.selected_difficulty = 4
	game.game_mode = "challenge"
	assert(game._challenge_strategy_bonus() == 320.0)   # 20关×10 + 地狱难度100 + 全局平值20（上游数值调整后）
	assert(game._challenge_soul_reward(3) == 6600)
	var enemy = game._make_roster_unit("enemy", "guanyu")
	assert(is_equal_approx(float(enemy.max_hp), float(game.heroes.guanyu.hp) * 2.0))
	assert(is_equal_approx(float(enemy.skill_value_bonus), 320.0))
	game.talent_levels = {"all:明君":2, "all:神算":1, "all:天命":1, "all:群英":1, "all:长治":1, "shu:汉室坚壁":2}
	assert(game._player_ruler_max_hp() == game.RULER_MAX_HP + 18000)
	assert(is_equal_approx(game._talent_bond_multiplier("player"), 1.2))
	assert(game._talent_faction_recruit_rounds("shu") == 2)
	assert(game._talent_opening_action_bonus())
	var opening_units: Array = []
	for hero_id in ["sunshangxiang", "guanyu", "caocao", "lvbu"]:
		opening_units.append(game._make_roster_unit("player", hero_id))
	game.combat_units = opening_units
	game._apply_opening_skills()
	assert(opening_units.filter(func(opening_unit): return is_equal_approx(float(opening_unit.action), 30.0)).size() == 3)
	game.talent_levels = {}
	var extreme_rune := {"uid":1, "tier":6, "kind":"Q2"}
	var extreme_effect: Dictionary = game._rune_effect(extreme_rune)
	assert(is_equal_approx(float(extreme_effect.hp), -320.0))
	assert(is_equal_approx(float(extreme_effect.cooldown), 40.0))   # Q2 六级：旧 2.0s → 极速 40（1 秒 = 20 极速）
	game.rune_inventory = [extreme_rune, {"uid":2, "tier":6, "kind":"Q2"}, {"uid":3, "tier":6, "kind":"Q2"}]
	game.rune_loadouts = {"sunshangxiang":[1, 2, 3]}
	var player = game._make_roster_unit("player", "sunshangxiang")
	# 冷却极速制：3×Q2 六级 = 3×40 极速 → 实际冷却 = 原冷却×100/(100+120)（收益递减，无 50% 上限）
	var sss_cd: float = float(game.heroes.sunshangxiang.cooldown)
	assert(is_equal_approx(game._unit_skill_cooldown(player), sss_cd * 100.0 / (100.0 + 120.0)))
	game.general_souls = game.RUNE_DRAW_COST * 10
	game.rune_inventory = []
	var ten_draws: Array = game._draw_runes(10)
	assert(ten_draws.size() == 10 and game.general_souls == 0)
	game.rune_inventory = [
		{"uid":101, "tier":1, "kind":"ZS"}, {"uid":102, "tier":1, "kind":"ZL"},
		{"uid":103, "tier":1, "kind":"ZJ"}, {"uid":104, "tier":1, "kind":"JS"},
		{"uid":105, "tier":1, "kind":"JH"}
	]
	game.rune_loadouts = {"sunshangxiang":[101, 105]}
	var batch_result: Dictionary = game._synthesize_all_runes(1)
	assert(batch_result.consumed == 2 and (batch_result.created as Array).size() == 1)   # 一键合成只消耗未装备符文（102/103 配对）
	assert(game.rune_inventory.filter(func(rune): return int(rune.tier) == 1).size() == 3)   # 装备中的 101/105 与未配对的 104 保留
	assert(game.rune_loadouts.sunshangxiang == [101, 105])   # 装备中的符文不自动拆下
	game.stage_star_records = {}
	game.limit_challenges = true
	assert(game._is_stage_unlocked(1, 0))
	assert(not game._is_stage_unlocked(2, 0))
	assert(not game._is_stage_unlocked(1, 1))
	game.stage_star_records[game._progression_key(1, 0)] = 1
	assert(game._is_stage_unlocked(2, 0))
	assert(game._is_stage_unlocked(1, 1))
	game.limit_challenges = false
	assert(game._is_stage_unlocked(20, 4))
	game._save_settings()
	game.limit_challenges = true
	game._load_settings()
	assert(not game.limit_challenges)
	assert(is_instance_valid(game.menu_overlay))
	assert(is_instance_valid(game.battle_menu_overlay))
	assert(is_instance_valid(game.rune_overlay))
	assert(is_instance_valid(game.talent_overlay))
	assert(is_instance_valid(game.result_overlay))
	game.rune_inventory = [
		{"uid":201, "tier":3, "kind":"ZL"}, {"uid":202, "tier":3, "kind":"ZJ"},
		{"uid":203, "tier":3, "kind":"ZS"}, {"uid":204, "tier":3, "kind":"JS"},
		{"uid":205, "tier":3, "kind":"Q6"}
	]
	game.rune_loadouts = {"sunshangxiang":[203, 202, 201]}
	game.home_hero_id = "sunshangxiang"
	game._populate_rune_heroes("wu", "sunshangxiang")
	game._show_runes()
	assert(game.rune_faction_options.item_count == 4)
	assert(is_instance_valid(game.rune_hero_portrait.texture))
	assert(game.rune_hero_portrait.custom_minimum_size.y <= 260.0)
	assert((game.rune_equipped_box.get_child(1) as GridContainer).get_child_count() == 3)
	game._set_rune_tier_filter(3)
	game._set_rune_class_filter("正")
	assert(game.rune_batch_synthesize_button.visible)
	var first_rune_panel: Control = game.rune_inventory_box.get_child(0)
	assert(first_rune_panel.mouse_filter == Control.MOUSE_FILTER_PASS)
	var first_rune_row: Control = first_rune_panel.get_child(0).get_child(0)
	assert(first_rune_row.mouse_filter == Control.MOUSE_FILTER_PASS)
	assert((first_rune_row.get_child(1) as Label).text.contains("疾风"))
	assert(((game.rune_inventory_box.get_child(1) as Control).get_child(0).get_child(0).get_child(1) as Label).text.contains("韬略"))
	assert(((game.rune_inventory_box.get_child(2) as Control).get_child(0).get_child(0).get_child(1) as Label).text.contains("磐石"))
	for child in first_rune_row.get_children():
		if child is Button: assert(child.mouse_filter == Control.MOUSE_FILTER_PASS)
	game.rune_overlay.hide()
	game._show_talents()
	assert(game.talent_upgrade_button.disabled)
	assert(game.talent_node_panels.has("厚德"))
	game._select_talent_node("all", "厚德")
	assert(game.talent_detail_name_label.text == "厚德")
	assert(game.talent_detail_label.text.contains("生命"))
	assert(not game.talent_upgrade_button.disabled)
	game._show_talent_detail("all", "天命")
	assert(game.talent_detail_label.text.contains("20%"))
	game.talent_overlay.hide()
	game.menu_overlay.show()
	game.game_mode = "quick"
	game._show_battle_menu()
	game._select_challenge_stage(20, 4)
	assert(game.game_mode == "quick" and game.battle_menu_overlay.visible)
	assert(game.challenge_detail_bonus_label.text.contains("最终兵略加成：+320"))
	assert(game.challenge_detail_star_label.text.contains("50,000"))
	game._confirm_challenge()
	assert(game.phase == "draft" and game.round_number == 1)
	assert(game.draft_overlay.visible)
	game.phase = "combat"
	game.battle_running = true
	game.player_ruler_hp = game._player_ruler_max_hp()
	game.enemy_ruler_hp = game.RULER_MAX_HP
	game._finish_battle()
	assert(game.phase == "draft" and game.round_number == 2)
	game.round_number = 15
	game.phase = "combat"
	game.battle_running = true
	game.player_ruler_hp = game._player_ruler_max_hp()
	game.enemy_ruler_hp = game.RULER_MAX_HP - 1
	game._finish_battle()
	assert(game.phase == "finished")
	game.game_mode = "quick"
	game.phase = "combat"
	game.battle_running = true
	game.player_ruler_hp = 100
	game.enemy_ruler_hp = 0
	game._finish_battle()
	await process_frame
	await process_frame
	assert(game.result_overlay.visible)
	assert(game.result_title_label.text == "胜利")
	print("PROGRESSION_SMOKE_OK")
	quit()
