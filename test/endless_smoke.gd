extends SceneTree

# 无尽远征冒烟测试：规则曲线 / 60 棵将印树完整性 / 据点与战策军府 / 将印点亮与重置 / 存档回读 / 凯旋终局 / UI 面板。
# 运行：godot --headless --script test/endless_smoke.gd

func _init() -> void:
	var rules = load("res://ThreeKingdom/data/endless_rules.gd")
	var trees = load("res://ThreeKingdom/data/hero_imprint_trees.gd")

	# ---- §2.1 敌方曲线 ----
	assert(is_equal_approx(rules.enemy_hp_multiplier(1), 1.75))
	assert(is_equal_approx(rules.enemy_hp_multiplier(6), 1.75 * pow(1.065, 5) * 1.08))
	assert(rules.enemy_hp_multiplier(400) == 200.0)
	assert(rules.enemy_strategy_bonus(1) == 100.0)
	assert(rules.enemy_strategy_bonus(6) == 145.0)
	assert(rules.enemy_strategy_bonus(400) == 2000.0)
	assert(is_equal_approx(rules.enemy_action_gain(1), 1.0))
	assert(is_equal_approx(rules.enemy_action_gain(51), 1.2))
	assert(is_equal_approx(rules.enemy_action_gain(91), 1.35))
	assert(is_equal_approx(rules.enemy_ruler_hp_multiplier(1), 1.6))
	assert(is_equal_approx(rules.enemy_ruler_hp_multiplier(6), 1.6 * pow(1.095, 5) * 1.14))
	assert(rules.enemy_ruler_hp_multiplier(400) == 400.0)
	assert(rules.checkpoint_index_of(1) == 0 and rules.checkpoint_index_of(6) == 1 and rules.checkpoint_index_of(11) == 2)
	# ---- §2.3 导演权重 / §4.2 掉落 ----
	assert(rules.enemy_director_weight(4) == 0.25)
	assert(rules.enemy_director_weight(5) == 0.50)
	assert(rules.enemy_director_weight(10) == 0.75)
	assert(rules.enemy_director_weight(30) == 0.90)
	assert(rules.checkpoint_imprint_count(2) == 0)
	assert(rules.checkpoint_imprint_count(3) == 2)
	assert(rules.checkpoint_imprint_count(6) == 4)
	assert(rules.checkpoint_imprint_count(9) == 6)
	assert(rules.checkpoint_soul_reward(3) == 2500)
	# ---- 池规模 ----
	assert(rules.MOMENTUM_POOL.size() == 14)
	assert(rules.COMMANDER_EVENTS.size() == 6)
	assert(rules.STRATEGY_POOL.size() == 20)
	assert(rules.JUNFU_ITEMS.size() == 7)
	assert(int(rules.MOMENTUM_LATE_UNLOCK.get("antidote", 0)) == 5)

	# ---- 60 棵七层将印树完整性 ----
	assert(trees.TREES.size() == 60)
	var packed: PackedScene = load("res://ThreeKingdom/ThreeKingdom.tscn")
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	assert(game.heroes.size() == 60)
	for hero_id in game.heroes.keys():
		assert(trees.TREES.has(str(hero_id)), "missing tree: " + str(hero_id))
	for hero_id in trees.TREES:
		var tree: Dictionary = trees.TREES[hero_id]
		assert(_root_class_ok(tree))
		assert((tree.root as Array).size() == 3)
		assert((tree.role as Array).size() == 3)
		assert((tree.skill as Array).size() == 3)
		assert((tree.branch as Array).size() == 2)
		for node in (tree.role as Array) + (tree.skill as Array) + (tree.branch as Array):
			assert(not str(node.get("name", "")).is_empty())
			assert(not (node.get("effects", {}) as Dictionary).is_empty())
		for layer_key in ["bond", "evergreen", "soul"]:
			var layer: Dictionary = tree.get(layer_key, {})
			assert(not layer.is_empty())
			assert(not (layer.get("effects", {}) as Dictionary).is_empty())

	# ---- 解锁门槛 ----
	game.stage_star_records = {}
	assert(not game._endless_unlocked())
	game.stage_star_records = {game._progression_key(20, 0): 3}
	assert(game._endless_unlocked())

	# ---- 开局 ----
	var runs_before: int = game.endless_total_runs
	game.game_mode = "endless"
	game._new_game()
	assert(game.phase == "draft" and game.round_number == 1)
	assert(game._run_is_endless())
	assert(game._run_draft_pick_count() == 3)
	assert(game._run_reserve_limit() == 18)
	assert(game._run_save_path() == rules.ENDLESS_SAVE_PATH)
	assert(game.endless_total_runs == runs_before + 1)
	assert(int(game.endless_state.run_seed) != 0)
	assert(game._run_enemy_ruler_max_hp() == int(round(game.RULER_MAX_HP * 1.6)))
	assert(game._endless_checkpoint_of_round(5) == 1)
	assert(game._endless_checkpoint_of_round(15) == 3)
	assert(game._endless_checkpoint_of_round(14) == 0)

	# ---- 曲线经模式覆盖生效 ----
	game.round_number = 6
	assert(is_equal_approx(game._challenge_enemy_hp_multiplier(), 1.75 * pow(1.065, 5) * 1.08))
	assert(game._challenge_strategy_bonus() == 145.0)
	game.round_number = 15
	var income_at_15: int = game._round_base_gold_income()
	game.round_number = 16
	assert(game._round_base_gold_income() == 0)   # 第 15 回合后基础收入冻结
	game.round_number = 1
	assert(game._round_base_gold_income() > 0)
	assert(income_at_15 > 0)

	# ---- 据点 1（第 5 回合）：将魂奖励 / 战策三选一 / 军府 / 继续 ----
	game.round_number = 5
	game.phase = "combat"
	game.battle_running = true
	game.player_ruler_hp = game._player_ruler_max_hp()
	game.enemy_ruler_hp = game._run_enemy_ruler_max_hp() - 1
	var souls_before: int = game.general_souls
	game._finish_battle()
	assert(game.phase == "checkpoint")
	assert(int(game.endless_state.checkpoint_index) == 1)
	assert(game.general_souls == souls_before + 1500)
	var payload: Dictionary = game._endless_checkpoint_payload()
	assert((payload.candidates as Array).size() == 3)
	assert(not bool(payload.can_triumph))
	assert((payload.junfu as Array).size() == 7)
	# 刷新候选：每据点一次
	assert(game._endless_refresh_strategy_candidate())
	assert(not game._endless_refresh_strategy_candidate())
	payload = game._endless_checkpoint_payload()
	assert((payload.candidates as Array).size() == 3)
	var pick_id := str((payload.candidates as Array)[0].id)
	assert(game._endless_pick_strategy(pick_id))
	assert(game._endless_strategy_level(pick_id) == 1)
	assert(not game.endless_state.strategy_pending_pick)
	assert(not game._endless_pick_strategy("nonexistent"))
	# 军府：需选武将的道具在无武将时不可购买；休养主公扣金币回血
	assert(not game._endless_buy_junfu("libing"))
	var rest_price: int = game._endless_junfu_price("rest")
	game.gold = rest_price - 1
	assert(not game._endless_buy_junfu("rest"))
	game.gold = rest_price
	game.player_ruler_hp = 10
	assert(game._endless_buy_junfu("rest"))
	assert(game.player_ruler_hp > 10)
	# 继续远征 → 第 6 回合，敌方主公按曲线成长
	game._endless_after_checkpoint()
	assert(game.phase in ["draft", "tianshu"] and game.round_number == 6)   # 第 6 回合为免费天书回合
	assert(game._run_enemy_ruler_max_hp() == int(round(game.RULER_MAX_HP * 1.6 * pow(1.095, 5) * 1.14)))

	# ---- 将印养成：层级门槛 / 专属优先 / 聚合效果 / 疾行通道 / 重置返还 ----
	game.universal_imprints = 0
	game.hero_imprints["guanyu"] = 200   # 消耗 ×5 后树价抬高，测试发足专属
	game.general_souls = 99999
	assert(not game._imprint_can_upgrade("guanyu", "role:0"))    # 根基不足 3 级
	assert(game._imprint_node_max_level("guanyu", "root:hp") == 3)
	assert(game._imprint_node_max_level("guanyu", "role:0") == 2)
	assert(game._imprint_node_max_level("guanyu", "skill:0") == 1)
	assert(game._imprint_upgrade("guanyu", "root:hp"))
	assert(game._imprint_upgrade("guanyu", "root:hp"))
	assert(game._imprint_upgrade("guanyu", "root:hp"))
	assert(game._imprint_level("guanyu", "root:hp") == 3)
	assert(not game._imprint_can_upgrade("guanyu", "root:hp"))   # 已满级
	assert(game._imprint_can_upgrade("guanyu", "role:0"))
	assert(game._imprint_upgrade("guanyu", "role:0"))
	assert(game._imprint_upgrade("guanyu", "role:0"))
	assert(not game._imprint_can_upgrade("guanyu", "role:0"))   # 定位节点满 2 级
	assert(game._imprint_upgrade("guanyu", "role:1"))
	assert(not game._imprint_can_upgrade("guanyu", "role:2"))   # 定位 3 选 2
	assert(game._imprint_can_upgrade("guanyu", "skill:0"))
	assert(not game._imprint_can_upgrade("guanyu", "branch:0"))  # 绝技未点亮 2 个
	assert(int(game.hero_imprints["guanyu"]) == 200 - 45)  # 专属优先：root 3×5 + role:0 2×10 + role:1 1×10（消耗×5 后）
	assert(game.universal_imprints == 0)
	var mod: Dictionary = game._imprint_mod("guanyu")
	assert(is_equal_approx(float(mod.hp_pct), 0.15))            # output 档生命 5%/级 ×3（加强后）
	assert(is_equal_approx(float(mod.get("damage_per_extra_hit_pct", 0.0)), 0.2))
	assert(game._imprint_upgrade("guanyu", "root:swift"))
	var mod2: Dictionary = game._imprint_mod("guanyu")
	assert(is_equal_approx(float(mod2.get("cooldown_haste_add", 0.0)), 25.0))   # 疾行：+25 冷却极速/级（极速→缩减=极速/(极速+100)，递减）
	game._imprint_toggle_swift("guanyu")
	assert(game._imprint_swift_mode("guanyu") == "cooldown")
	# 冷却极速制：极速 → 实际冷却 = 原冷却×100/(100+极速)，100 极速即减半
	var guanyu_cd_base: float = float(game.heroes.guanyu.cooldown)
	var waterfall: Array = game._endless_stat_waterfall("guanyu")
	assert(waterfall.size() == 4)
	assert(bool((waterfall[0] as Dictionary).applies))
	var haste_row: Dictionary = (waterfall[2] as Dictionary)
	assert(is_equal_approx(float(haste_row.get("haste", 0.0)), 25.0))
	assert(is_equal_approx(float(haste_row.get("final", 0.0)), guanyu_cd_base * 100.0 / 125.0))
	# 减伤值护甲：曹仁天生远程减伤值 = 兵略×0.5，结算 = 值/(值+100)；近战池为 0
	var caoren_unit: Dictionary = game._make_roster_unit("player", "caoren")
	var ranged_attacker: Dictionary = game._make_roster_unit("enemy", "sunshangxiang")
	var melee_attacker: Dictionary = game._make_roster_unit("enemy", "guanyu")
	var caoren_armor: float = game._unit_skill_stat_value(caoren_unit) * 0.5
	assert(game._unit_armor_value(caoren_unit, "ranged") == caoren_armor)
	assert(game._unit_armor_value(caoren_unit, "melee") == 0.0)
	assert(is_equal_approx(game._unit_armor_reduction(caoren_unit, ranged_attacker), caoren_armor / (caoren_armor + 100.0)))
	assert(game._unit_armor_reduction(caoren_unit, melee_attacker) == 0.0)
	# 重置：消耗 7×20 将魂，全额返还专属
	var souls_at_reset: int = game.general_souls
	assert(game._imprint_reset_cost("guanyu") == 7 * 20)
	assert(game._imprint_reset_tree("guanyu"))
	assert(game.general_souls == souls_at_reset - 140)
	assert(int(game.hero_imprints["guanyu"]) == 200)
	assert(game._imprint_level("guanyu", "root:hp") == 0)

	# ---- 存档回读（独立无尽存档 + run_seed 游标重放）----
	assert(game._save_game(true))
	var cursor_before := int(game.endless_state.rng_cursor)
	assert(game._load_game(rules.ENDLESS_SAVE_PATH))
	assert(game.game_mode == "endless" and game.phase in ["draft", "tianshu"] and game.round_number == 6)
	assert(game._endless_strategy_level(pick_id) == 1)
	assert(int(game.endless_state.rng_cursor) == cursor_before)

	# ---- 敌方评分导演 ----
	var wave: Array = game._endless_draft_enemy_wave(3)
	assert(wave.size() == 3)
	for hero_id in wave: assert(game.heroes.has(str(hero_id)))

	# ---- 据点 3（第 15 回合）：将印开始掉落 + 凯旋纪录奖励 + 存档清除 ----
	var universal_before_final: int = game.universal_imprints
	game.round_number = 15
	game.phase = "combat"
	game.battle_running = true
	game.player_ruler_hp = game._player_ruler_max_hp()
	game.enemy_ruler_hp = 1
	game._finish_battle()
	assert(game.phase == "checkpoint" and int(game.endless_state.checkpoint_index) == 3)
	assert(game.universal_imprints == universal_before_final + 1)   # 据点 3 掉落：通用 +1
	payload = game._endless_checkpoint_payload()
	assert(bool(payload.can_triumph))
	game._endless_checkpoint_triumph()
	assert(game.phase == "finished")
	assert(game.endless_best_round == 15)
	assert(game.universal_imprints == universal_before_final + 2)   # 破纪录额外 +1
	assert(not FileAccess.file_exists(rules.ENDLESS_SAVE_PATH))     # 远征结束即删档
	assert(game.endless_state.triumphed)

	# ---- UI 面板 ----
	await process_frame
	await process_frame
	assert(game.result_overlay.visible)
	assert(game.result_title_label.text == "凯旋结算")
	game._refresh_endless_banner()
	assert(game.endless_best_label.text.contains("15"))
	assert(game.endless_continue_button.disabled)   # 无进行中存档
	assert(is_instance_valid(game.checkpoint_overlay))
	game._show_imprint_panel()
	assert(game.imprint_overlay.visible)
	game.imprint_overlay.hide()
	print("ENDLESS_SMOKE_OK")
	quit()

func _root_class_ok(tree: Dictionary) -> bool:
	# 根基分档必须是四档之一
	return ["output", "tank", "support", "aura"].has(str(tree.get("root_class", "")))
