extends SceneTree

func _place(game, team: String, hero_id: String, row: int, col: int) -> Dictionary:
	var unit: Dictionary = game._make_roster_unit(team, hero_id)
	unit.row = row
	unit.col = col
	return unit

func _set_combat(game, allies: Array, enemies: Array) -> void:
	game.player_units = allies
	game.enemy_units = enemies
	game.combat_units = allies + enemies
	game.visual_events.clear()
	game.enemy_ruler_hp = game.RULER_MAX_HP
	game.player_ruler_hp = game.RULER_MAX_HP

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()

	assert(not game.heroes.has("jiangqin"))
	assert(game.heroes.has("taishici"))
	assert(game.heroes.has("dingfeng"))

	# A full Wu roster activates both four-hero cores and every pair bond.
	var wu_ids := ["zhouyu", "luxun", "lusu", "lvmeng", "sunjian", "sunce", "sunquan", "sunshangxiang", "daqiao", "xiaoqiao", "huanggai", "taishici", "ganning", "dingfeng", "xusheng"]
	var wu_team: Array = []
	for index in wu_ids.size():
		wu_team.append(_place(game, "player", wu_ids[index], index % game.BOARD_ROWS, floori(float(index) / float(game.BOARD_ROWS))))
	_set_combat(game, wu_team, [])
	game._apply_combo_bonds(true, false)
	assert(game._combat_hero("player", "zhouyu").four_heroes)
	assert(game._combat_hero("player", "sunce").sun_legacy)
	assert(game._combat_hero("player", "sunce").sunce_taishi)
	assert(game._combat_hero("player", "daqiao").sunce_daqiao)
	assert(game._combat_hero("player", "xiaoqiao").zhouyu_xiaoqiao)
	assert(game._combat_hero("player", "huanggai").zhouyu_huanggai)
	assert(game._combat_hero("player", "sunjian").huanggai_sunjian)
	assert(game._combat_hero("player", "ganning").taishici_ganning)
	assert(game._combat_hero("player", "luxun").luxun_sunquan)
	assert(game._combat_hero("player", "dingfeng").dingfeng_xusheng)
	assert(is_equal_approx(float(game._combat_hero("player", "xusheng").control_multiplier), 1.50))

	# 神亭酣战 + 江表双锋：太史慈选择行动条最高的3人；已灼烧目标300%，其余150%。
	var taishici := _place(game, "player", "taishici", 0, 0)
	var sunce_for_taishi := _place(game, "player", "sunce", 0, 1)
	var ganning_for_taishi := _place(game, "player", "ganning", 0, 2)
	var taishi_targets: Array = []
	for index in 4:
		var target := _place(game, "enemy", "sunjian", index % game.BOARD_ROWS, index)
		target.max_hp = 1000000.0
		target.hp = target.max_hp
		target.action = 90.0 - index * 10.0
		taishi_targets.append(target)
	taishi_targets[0].burn = 1.0
	_set_combat(game, [taishici, sunce_for_taishi, ganning_for_taishi], taishi_targets)
	game._apply_combo_bonds(true, false)
	game._cast_taishici_skill(taishici)
	var taishi_params: Dictionary = game.heroes.taishici.ability_params
	assert(is_equal_approx(1000000.0 - float(taishi_targets[0].hp), float(game.heroes.taishici.skill_value) * float(taishi_params.ganning_burning_mult)))
	for index in [1, 2]:
		assert(is_equal_approx(1000000.0 - float(taishi_targets[index].hp), float(game.heroes.taishici.skill_value) * float(taishi_params.mult)))
		assert(is_equal_approx(float(taishi_targets[index].burn), 5.0))
	assert(is_equal_approx(float(taishi_targets[3].hp), 1000000.0))
	assert(game.visual_events.filter(func(event): return event.get("kind", "") == "damage").size() == 3)
	assert(is_equal_approx(float(game.heroes.taishici.cooldown), 5.0))
	var base_taishici := _place(game, "player", "taishici", 1, 0)
	var base_taishi_targets: Array = []
	for index in 3:
		var target := _place(game, "enemy", "caocao", index, index)
		target.max_hp = 10000.0
		target.hp = 10000.0
		target.action = 80.0 - index * 10.0
		base_taishi_targets.append(target)
	_set_combat(game, [base_taishici], base_taishi_targets)
	game._apply_combo_bonds(true, false)
	game._cast_taishici_skill(base_taishici)
	assert(is_equal_approx(float(base_taishi_targets[0].hp), 10000.0 - float(game.heroes.taishici.skill_value) * float(game.heroes.taishici.ability_params.mult)))
	assert(is_equal_approx(float(base_taishi_targets[1].hp), 10000.0 - float(game.heroes.taishici.skill_value) * float(game.heroes.taishici.ability_params.mult)))
	assert(is_equal_approx(float(base_taishi_targets[2].hp), 10000.0))

	# 江表虎臣：丁奉攻击中心与左右格，并分别压退行动条。
	var dingfeng := _place(game, "player", "dingfeng", 0, 0)
	var xusheng := _place(game, "player", "xusheng", 0, 1)
	var ding_targets: Array = []
	for col in range(1, 4):
		var target := _place(game, "enemy", "sunjian", 0, col)
		target.max_hp = 1000000.0
		target.hp = target.max_hp
		target.action = 90.0 if col == 2 else 50.0
		ding_targets.append(target)
	_set_combat(game, [dingfeng, xusheng], ding_targets)
	game._apply_combo_bonds(true, false)
	game._cast_dingfeng_skill(dingfeng)
	var ding_params: Dictionary = game.heroes.dingfeng.ability_params
	assert(is_equal_approx(1000000.0 - float(ding_targets[1].hp), float(game.heroes.dingfeng.skill_value) * float(ding_params.mult)))
	assert(is_equal_approx(float(ding_targets[1].action), 90.0 - float(ding_params.action_reduction)))
	for index in [0, 2]:
		assert(is_equal_approx(1000000.0 - float(ding_targets[index].hp), float(game.heroes.dingfeng.skill_value) * float(ding_params.bond_splash_mult)))
		assert(is_equal_approx(float(ding_targets[index].action), 50.0 - float(ding_params.bond_splash_action_reduction)))

	# 四英杰 + 琴瑟和鸣 + 赤壁苦计：随机4格、灼烧6秒，
	# 目标已损失50%生命时直接伤害和灼烧均提高25%。
	var zhouyu := _place(game, "player", "zhouyu", 2, 0)
	var xiaoqiao := _place(game, "player", "xiaoqiao", 2, 1)
	var huanggai_for_zhou := _place(game, "player", "huanggai", 0, 2)
	var luxun_for_zhou := _place(game, "player", "luxun", 2, 2)
	var lusu_for_zhou := _place(game, "player", "lusu", 2, 3)
	var lvmeng_for_zhou := _place(game, "player", "lvmeng", 0, 3)
	var zhou_targets: Array = []
	for row in game.BOARD_ROWS:
		for col in game.BOARD_COLUMNS:
			var target := _place(game, "enemy", "sunjian", row, col)
			target.max_hp = 1000000.0
			target.hp = target.max_hp * 0.50
			zhou_targets.append(target)
	_set_combat(game, [zhouyu, xiaoqiao, huanggai_for_zhou, luxun_for_zhou, lusu_for_zhou, lvmeng_for_zhou], zhou_targets)
	game._apply_combo_bonds(true, false)
	game._cast_zhouyu(zhouyu)
	var burned: Array = zhou_targets.filter(func(target): return float(target.burn) > 0.0)
	assert(burned.size() == 4)
	assert(burned.all(func(target): return is_equal_approx(float(target.burn), 6.0)))
	var zhou_expected := float(game.heroes.zhouyu.ability_params.base_value) * 1.25
	assert(burned.all(func(target): return is_equal_approx(500000.0 - float(target.hp), zhou_expected)))
	assert(game.visual_events.filter(func(event): return event.get("kind", "") == "row_burn").size() == 4)
	game.visual_events.clear()
	for target in burned:
		target.burn_clock = 0.0
	game._process_statuses(1.0)
	var expected_burn_tick := float(game.heroes.zhouyu.ability_params.burn_per_sec) * 1.25
	assert(burned.all(func(target): return is_equal_approx(500000.0 - zhou_expected - float(target.hp), expected_burn_tick)))
	game._render_combat_boards()
	var burning_card: Control = game.unit_cell_refs[burned[0].id]
	var burning_overlay := burning_card.get_node_or_null("BurningStateOverlay")
	assert(is_instance_valid(burning_overlay))
	assert(str(burning_overlay.texture.resource_path).ends_with("animations/onfire.png"))

	# 江东佳偶：受治疗目标每损失10%生命，本次治疗提高4%。
	var daqiao := _place(game, "player", "daqiao", 2, 0)
	var sunce_for_daqiao := _place(game, "player", "sunce", 0, 0)
	sunce_for_daqiao.max_hp = 10000.0
	sunce_for_daqiao.hp = 5000.0
	_set_combat(game, [daqiao, sunce_for_daqiao], [])
	game._apply_combo_bonds(true, false)
	var heal_base := float(game.heroes.daqiao.ability_params.base_heal)
	game._cast_generic_ability(daqiao)
	assert(is_equal_approx(float(sunce_for_daqiao.hp), 5000.0 + heal_base * 1.20))
	assert(is_equal_approx(float(game.heroes.sunce.hp), 3720.0))
	assert(is_equal_approx(float(game.heroes.daqiao.hp), 2760.0))

	# 四英杰 + 君臣同心：陆逊总共弹射3次（4次命中），相邻传递；
	# 孙权使基础增伤50%，灼烧目标再增伤50%，合计100%。
	var luxun := _place(game, "player", "luxun", 2, 0)
	var sunquan := _place(game, "player", "sunquan", 2, 1)
	var zhouyu_for_luxun := _place(game, "player", "zhouyu", 2, 2)
	var lusu_for_luxun := _place(game, "player", "lusu", 2, 3)
	var lvmeng_for_luxun := _place(game, "player", "lvmeng", 0, 3)
	var luxun_targets: Array = []
	for row in game.BOARD_ROWS:
		for col in game.BOARD_COLUMNS:
			var target := _place(game, "enemy", "sunjian", row, col)
			target.max_hp = 1000000.0
			target.hp = target.max_hp
			target.burn = 5.0
			luxun_targets.append(target)
	_set_combat(game, [luxun, sunquan, zhouyu_for_luxun, lusu_for_luxun, lvmeng_for_luxun], luxun_targets)
	game._apply_combo_bonds(true, false)
	game._cast_luxun(luxun)
	var luxun_damage: float = round(float(game.heroes.luxun.ability_params.base_value) * 2.0)
	var luxun_events: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	assert(luxun_events.size() == 4)
	assert(luxun_events.all(func(event): return is_equal_approx(float(event.amount), luxun_damage)))
	assert(luxun_events.all(func(event): return str(event.get("projectile_asset", "")).ends_with("animations/fireball.png")))
	for index in range(1, luxun_events.size()):
		var previous = game._find_by_id(luxun_targets, str(luxun_events[index - 1].target_id))
		var current = game._find_by_id(luxun_targets, str(luxun_events[index].target_id))
		assert(abs(int(previous.row) - int(current.row)) + abs(int(previous.col) - int(current.col)) == 1)

	# 鲁肃按当前生命值总量而非生命百分比选人。基础治疗1名并加200上限；
	# 四英杰治疗最低的2名，改为20%治疗和350上限。
	var base_lusu := _place(game, "player", "lusu", 2, 0)
	var low_ratio_high_total := _place(game, "player", "sunjian", 0, 0)
	low_ratio_high_total.max_hp = 10000.0
	low_ratio_high_total.hp = 900.0
	var lowest_total := _place(game, "player", "sunce", 0, 1)
	lowest_total.max_hp = 1000.0
	lowest_total.hp = 500.0
	var second_total := _place(game, "player", "sunquan", 2, 1)
	second_total.max_hp = 1000.0
	second_total.hp = 700.0
	_set_combat(game, [base_lusu, low_ratio_high_total, lowest_total, second_total], [])
	game._apply_combo_bonds(true, false)
	var lusu_params: Dictionary = game.heroes.lusu.ability_params
	game._cast_lusu_skill(base_lusu)
	var base_lusu_max := 1000.0 + float(lusu_params.max_hp_flat)
	assert(is_equal_approx(float(lowest_total.max_hp), base_lusu_max))
	assert(is_equal_approx(float(lowest_total.hp), minf(base_lusu_max, 500.0 + base_lusu_max * float(lusu_params.heal_ratio))))
	assert(is_equal_approx(float(low_ratio_high_total.max_hp), 10000.0))
	assert(is_equal_approx(float(second_total.max_hp), 1000.0))

	var four_lusu := _place(game, "player", "lusu", 2, 0)
	var lusu_lowest := _place(game, "player", "sunjian", 0, 0)
	var lusu_second := _place(game, "player", "sunce", 0, 1)
	lusu_lowest.max_hp = 1000.0
	lusu_lowest.hp = 500.0
	lusu_second.max_hp = 1000.0
	lusu_second.hp = 600.0
	var four_zhouyu := _place(game, "player", "zhouyu", 2, 1)
	var four_luxun := _place(game, "player", "luxun", 2, 2)
	var four_lvmeng := _place(game, "player", "lvmeng", 0, 2)
	_set_combat(game, [four_lusu, lusu_lowest, lusu_second, four_zhouyu, four_luxun, four_lvmeng], [])
	game._apply_combo_bonds(true, false)
	game._cast_lusu_skill(four_lusu)
	var four_lusu_max := 1000.0 + float(lusu_params.four_heroes_max_hp_flat)
	var four_lusu_heal := four_lusu_max * float(lusu_params.four_heroes_heal_ratio)
	assert(is_equal_approx(float(lusu_lowest.max_hp), four_lusu_max))
	assert(is_equal_approx(float(lusu_second.max_hp), four_lusu_max))
	assert(is_equal_approx(float(lusu_lowest.hp), 500.0 + four_lusu_heal))
	assert(is_equal_approx(float(lusu_second.hp), 600.0 + four_lusu_heal))
	game._after_active_skill(four_lusu)
	assert(is_equal_approx(float(four_zhouyu.action), 0.0))

	# 孙权基础技能：8%目标当前生命，最大生命+200（2倍封顶），再回复10%已损生命。
	var base_sunquan := _place(game, "player", "sunquan", 2, 0)
	var base_quan_target := _place(game, "enemy", "caocao", 0, 0)
	base_sunquan.max_hp = 1000.0
	base_sunquan.hp = 500.0
	base_quan_target.max_hp = 1000.0
	base_quan_target.hp = 1000.0
	_set_combat(game, [base_sunquan], [base_quan_target])
	game._apply_combo_bonds(true, false)
	game._cast_sunquan_skill(base_sunquan)
	assert(is_equal_approx(float(base_quan_target.hp), 920.0))
	assert(is_equal_approx(float(base_sunquan.max_hp), 1200.0))
	var expected_base_sunquan_hp := 500.0 + (1200.0 - 500.0) * float(game.heroes.sunquan.ability_params.missing_hp_heal_ratio)
	assert(is_equal_approx(float(base_sunquan.hp), expected_base_sunquan_hp))
	assert(is_equal_approx(game._unit_skill_cooldown(base_sunquan), float(game.heroes.sunquan.cooldown)))

	# 君臣同心：孙权改为12%当前生命伤害、8秒冷却。
	var minister_sunquan := _place(game, "player", "sunquan", 2, 0)
	var minister_luxun := _place(game, "player", "luxun", 2, 1)
	var minister_target := _place(game, "enemy", "caocao", 0, 0)
	minister_sunquan.max_hp = 1000.0
	minister_sunquan.hp = 500.0
	minister_target.max_hp = 1000.0
	minister_target.hp = 1000.0
	_set_combat(game, [minister_sunquan, minister_luxun], [minister_target])
	game._apply_combo_bonds(true, false)
	game._cast_sunquan_skill(minister_sunquan)
	assert(is_equal_approx(float(minister_target.hp), 880.0))
	assert(is_equal_approx(game._unit_skill_cooldown(minister_sunquan), float(game.heroes.sunquan.ability_params.luxun_cooldown)))

	# 四英杰 + 白衣奇袭：吕蒙后军400%，隐身3秒，恐惧4秒；
	# 恐惧每秒5%最大生命，隐身后的下一次伤害提高60%。
	var lvmeng := _place(game, "player", "lvmeng", 0, 0)
	var ganning_for_lvmeng := _place(game, "player", "ganning", 0, 1)
	var zhouyu_for_lvmeng := _place(game, "player", "zhouyu", 2, 0)
	var luxun_for_lvmeng := _place(game, "player", "luxun", 2, 1)
	var lusu_for_lvmeng := _place(game, "player", "lusu", 2, 2)
	var lvmeng_target := _place(game, "enemy", "caocao", 2, 2)
	lvmeng_target.max_hp = 10000.0
	lvmeng_target.hp = 10000.0
	_set_combat(game, [lvmeng, ganning_for_lvmeng, zhouyu_for_lvmeng, luxun_for_lvmeng, lusu_for_lvmeng], [lvmeng_target])
	game._apply_combo_bonds(true, false)
	game._cast_lvmeng_skill(lvmeng)
	assert(is_equal_approx(10000.0 - float(lvmeng_target.hp), float(game.heroes.lvmeng.ability_params.base_value)))
	assert(is_equal_approx(float(lvmeng.stealth), 3.0))
	assert(is_equal_approx(float(lvmeng_target.fear), 4.0))
	assert(bool(lvmeng.stealth_ambush_bonus_ready))
	assert(not game._targets_in_range(lvmeng_target).has(lvmeng))
	assert(game._targets_in_range(lvmeng_target).has(ganning_for_lvmeng))
	game._process_statuses(1.0)
	assert(is_equal_approx(10000.0 - float(game.heroes.lvmeng.ability_params.base_value) - float(lvmeng_target.hp), 500.0))
	var before_ambush := float(lvmeng_target.hp)
	game._damage(lvmeng, lvmeng_target, 100.0, "physical", "post stealth")
	assert(is_equal_approx(before_ambush - float(lvmeng_target.hp), 160.0))
	assert(not bool(lvmeng.stealth_ambush_bonus_ready))

	# Remaining pair effects: Sun Ce self-heal, Gan Ning assist, Huang Gai column burn/cost,
	# Sun Jian's full-gauge spent-HP strike, and Xiao Qiao's rearguard slow.
	var sunce_pair := _place(game, "player", "sunce", 0, 0)
	var daqiao_pair := _place(game, "player", "daqiao", 2, 0)
	sunce_pair.hp = float(sunce_pair.max_hp) * 0.50
	_set_combat(game, [sunce_pair, daqiao_pair], [])
	game._apply_combo_bonds(true, false)
	game._perform_action(sunce_pair)
	assert(is_equal_approx(float(sunce_pair.hp), float(sunce_pair.max_hp) * 0.62))

	var ganning_pair := _place(game, "player", "ganning", 1, 1)
	var ganning_left := _place(game, "player", "zhouyu", 1, 0)
	var taishici_pair := _place(game, "player", "taishici", 1, 2)
	var lvmeng_pair := _place(game, "player", "lvmeng", 0, 0)
	var ganning_target := _place(game, "enemy", "caocao", 2, 0)
	ganning_target.max_hp = 10000.0
	ganning_target.hp = 4000.0
	ganning_left.action = 73.0
	_set_combat(game, [ganning_pair, ganning_left, taishici_pair, lvmeng_pair], [ganning_target])
	game._apply_combo_bonds(true, false)
	game._cast_ganning_skill(ganning_pair)
	var ganning_expected := (float(game.heroes.ganning.skill_value) + float(game.heroes.zhouyu.skill_value)) * 2.5 * 1.5
	assert(is_equal_approx(4000.0 - float(ganning_target.hp), ganning_expected))
	assert(is_equal_approx(float(ganning_left.action), 73.0))
	assert(is_equal_approx(float(game.heroes.ganning.cooldown), 8.0))
	var base_ganning := _place(game, "player", "ganning", 1, 1)
	var base_ganning_left := _place(game, "player", "zhouyu", 1, 0)
	var base_ganning_target := _place(game, "enemy", "caocao", 2, 0)
	base_ganning_target.max_hp = 10000.0
	base_ganning_target.hp = 10000.0
	base_ganning_left.action = 61.0
	_set_combat(game, [base_ganning, base_ganning_left], [base_ganning_target])
	game._apply_combo_bonds(true, false)
	game._cast_ganning_skill(base_ganning)
	assert(is_equal_approx(10000.0 - float(base_ganning_target.hp), (float(game.heroes.ganning.skill_value) + float(game.heroes.zhouyu.skill_value)) * 1.5))
	assert(is_equal_approx(float(base_ganning_left.action), 61.0))

	var huanggai_pair := _place(game, "player", "huanggai", 0, 0)
	var zhouyu_pair := _place(game, "player", "zhouyu", 2, 0)
	var sunjian_pair := _place(game, "player", "sunjian", 0, 1)
	var full_enemy_board: Array = []
	for row in game.BOARD_ROWS:
		for col in game.BOARD_COLUMNS:
			var target := _place(game, "enemy", "sunjian", row, col)
			target.max_hp = 1000000.0
			target.hp = target.max_hp
			full_enemy_board.append(target)
	_set_combat(game, [huanggai_pair, zhouyu_pair, sunjian_pair], full_enemy_board)
	game._apply_combo_bonds(true, false)
	assert(is_equal_approx(float(sunjian_pair.action), game.ACTION_MAX))
	huanggai_pair.max_hp = 1000.0
	huanggai_pair.hp = 1000.0
	game._cast_huanggai_skill(huanggai_pair)
	assert(is_equal_approx(float(huanggai_pair.hp), 850.0))
	var huanggai_burned: Array = full_enemy_board.filter(func(target): return float(target.burn) > 0.0)
	assert(huanggai_burned.size() == game.BOARD_ROWS)
	assert(huanggai_burned.all(func(target): return is_equal_approx(float(target.burn), 6.0) and is_equal_approx(float(target.burn_damage), 7.5)))
	assert(huanggai_burned.all(func(target): return is_equal_approx(1000000.0 - float(target.hp), 67.5)))
	var base_huanggai := _place(game, "player", "huanggai", 0, 0)
	var base_huanggai_targets: Array = []
	for row in game.BOARD_ROWS:
		for col in game.BOARD_COLUMNS:
			var target := _place(game, "enemy", "caocao", row, col)
			target.max_hp = 10000.0
			target.hp = 10000.0
			base_huanggai_targets.append(target)
	base_huanggai.max_hp = 1000.0
	base_huanggai.hp = 1000.0
	_set_combat(game, [base_huanggai], base_huanggai_targets)
	game._apply_combo_bonds(true, false)
	game._cast_huanggai_skill(base_huanggai)
	assert(is_equal_approx(float(base_huanggai.hp), 900.0))
	var base_huanggai_damaged := base_huanggai_targets.filter(func(target): return float(target.hp) < 10000.0)
	assert(base_huanggai_damaged.size() == game.BOARD_ROWS)
	assert(base_huanggai_damaged.all(func(target): return is_equal_approx(10000.0 - float(target.hp), 33.0) and is_equal_approx(float(target.burn), 0.0)))
	var fragile_huanggai := _place(game, "player", "huanggai", 0, 0)
	var fragile_sunjian := _place(game, "player", "sunjian", 0, 1)
	var fragile_target := _place(game, "enemy", "caocao", 0, 0)
	fragile_huanggai.max_hp = 1000.0
	fragile_huanggai.hp = 100.0
	fragile_target.max_hp = 10000.0
	fragile_target.hp = 10000.0
	_set_combat(game, [fragile_huanggai, fragile_sunjian], [fragile_target])
	game._apply_combo_bonds(true, false)
	game._cast_huanggai_skill(fragile_huanggai)
	assert(not fragile_huanggai.alive)

	_set_combat(game, [huanggai_pair, zhouyu_pair, sunjian_pair], full_enemy_board)
	game._apply_combo_bonds(true, false)
	sunjian_pair.max_hp = 1000.0
	sunjian_pair.hp = 1000.0
	game.visual_events.clear()
	game._cast_sunjian_skill(sunjian_pair)
	var sunjian_events: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	var sunjian_expected := 600.0 # 首次消耗400生命，江东柱石按150%结算。
	assert(sunjian_events.size() == 1)
	assert(is_equal_approx(float(sunjian_events[0].amount), sunjian_expected))
	assert(is_equal_approx(float(sunjian_pair.hp), 600.0))
	game._cast_sunjian_skill(sunjian_pair)
	assert(is_equal_approx(float(sunjian_pair.hp), 540.0))
	var second_sunjian_events: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	assert(is_equal_approx(float(second_sunjian_events[-1].amount), 90.0))

	# 孙氏之志：孙坚首次/后续分别消耗80%/20%当前生命；死亡后存活吴将
	# 在本回合剩余时间内获得10%伤害。孙尚香从任意友军阵亡获得5点技能强度。
	var legacy_sunjian := _place(game, "player", "sunjian", 0, 0)
	var legacy_sunce := _place(game, "player", "sunce", 0, 1)
	var legacy_sunquan := _place(game, "player", "sunquan", 2, 2)
	var legacy_xiang := _place(game, "player", "sunshangxiang", 2, 3)
	var legacy_killer := _place(game, "enemy", "caocao", 0, 0)
	legacy_sunjian.max_hp = 1000.0
	legacy_sunjian.hp = 1000.0
	legacy_killer.max_hp = 1000000.0
	legacy_killer.hp = legacy_killer.max_hp
	_set_combat(game, [legacy_sunjian, legacy_sunce, legacy_sunquan, legacy_xiang], [legacy_killer])
	game._apply_combo_bonds(true, false)
	game._cast_sunjian_skill(legacy_sunjian)
	assert(is_equal_approx(float(legacy_sunjian.hp), 200.0))
	game._cast_sunjian_skill(legacy_sunjian)
	assert(is_equal_approx(float(legacy_sunjian.hp), 160.0))
	game._damage(legacy_killer, legacy_sunjian, 10000.0, "physical", "legacy test")
	assert(not legacy_sunjian.alive)
	for legacy_ally in [legacy_sunce, legacy_sunquan, legacy_xiang]:
		assert(is_equal_approx(float(legacy_ally.kill_buff), 0.10))
	assert(is_equal_approx(float(legacy_sunquan.action), 0.0))
	assert(is_equal_approx(float(legacy_xiang.action), 0.0))
	assert(is_equal_approx(float(legacy_xiang.sunshangxiang_skill_bonus), float(game.heroes.sunshangxiang.ability_params.ally_death_skill_gain)))

	# 孙氏之志强化孙权：最大生命+400+10%施法前已损生命，4倍封顶，再恢复15%已损生命。
	var legacy_quan_skill := _place(game, "player", "sunquan", 2, 0)
	var legacy_quan_jian := _place(game, "player", "sunjian", 0, 0)
	var legacy_quan_ce := _place(game, "player", "sunce", 0, 1)
	var legacy_quan_xiang := _place(game, "player", "sunshangxiang", 2, 1)
	var legacy_quan_target := _place(game, "enemy", "caocao", 0, 0)
	legacy_quan_skill.max_hp = 1000.0
	legacy_quan_skill.hp = 500.0
	legacy_quan_target.max_hp = 1000.0
	legacy_quan_target.hp = 1000.0
	_set_combat(game, [legacy_quan_skill, legacy_quan_jian, legacy_quan_ce, legacy_quan_xiang], [legacy_quan_target])
	game._apply_combo_bonds(true, false)
	game._cast_sunquan_skill(legacy_quan_skill)
	assert(is_equal_approx(float(legacy_quan_target.hp), 920.0))
	assert(is_equal_approx(float(legacy_quan_skill.max_hp), 1450.0))
	assert(is_equal_approx(float(legacy_quan_skill.hp), 642.5))
	assert(is_equal_approx(game._unit_skill_cooldown(legacy_quan_xiang), float(game.heroes.sunshangxiang.ability_params.sun_legacy_cooldown)))

	# 孙尚香基础为80强度、单击100%、施法后+1；孙氏之志改为双击150%、施法后+2。
	var base_xiang := _place(game, "player", "sunshangxiang", 2, 0)
	var base_xiang_target := _place(game, "enemy", "caocao", 0, 0)
	base_xiang_target.max_hp = 10000.0
	base_xiang_target.hp = 10000.0
	_set_combat(game, [base_xiang], [base_xiang_target])
	game._apply_combo_bonds(true, false)
	game._cast_sunshangxiang_skill(base_xiang)
	game._cast_sunshangxiang_skill(base_xiang)

	var bonded_xiang := _place(game, "player", "sunshangxiang", 2, 0)
	var bonded_xiang_jian := _place(game, "player", "sunjian", 0, 0)
	var bonded_xiang_ce := _place(game, "player", "sunce", 0, 1)
	var bonded_xiang_quan := _place(game, "player", "sunquan", 2, 1)
	var bonded_xiang_target := _place(game, "enemy", "caocao", 0, 0)
	bonded_xiang_target.max_hp = 10000.0
	bonded_xiang_target.hp = 10000.0
	_set_combat(game, [bonded_xiang, bonded_xiang_jian, bonded_xiang_ce, bonded_xiang_quan], [bonded_xiang_target])
	game._apply_combo_bonds(true, false)
	game._cast_sunshangxiang_skill(bonded_xiang)
	assert(is_equal_approx(float(bonded_xiang_target.hp), 9760.0))
	var bonded_xiang_gain := float(game.heroes.sunshangxiang.ability_params.sun_legacy_skill_gain_per_cast)
	assert(is_equal_approx(float(bonded_xiang.sunshangxiang_skill_bonus), bonded_xiang_gain))
	assert(is_equal_approx(game._unit_skill_cooldown(bonded_xiang), float(game.heroes.sunshangxiang.ability_params.sun_legacy_cooldown)))
	game._damage(bonded_xiang_target, bonded_xiang_ce, 100000.0, "physical", "ally death growth test")
	assert(is_equal_approx(float(bonded_xiang.sunshangxiang_skill_bonus), bonded_xiang_gain + float(game.heroes.sunshangxiang.ability_params.ally_death_skill_gain)))

	# 孙氏之志下，孙策以400%基础倍率攻击正前方和左侧；50%生命时再增伤10%，
	# 并获得20%伤害减免。
	var legacy_ce := _place(game, "player", "sunce", 0, 1)
	var legacy_jian := _place(game, "player", "sunjian", 0, 0)
	var legacy_quan := _place(game, "player", "sunquan", 2, 2)
	var legacy_shangxiang := _place(game, "player", "sunshangxiang", 2, 3)
	var legacy_ce_targets: Array = []
	for col in range(3):
		var target := _place(game, "enemy", "caocao", 0, col)
		target.max_hp = 1000000.0
		target.hp = target.max_hp
		legacy_ce_targets.append(target)
	_set_combat(game, [legacy_ce, legacy_jian, legacy_quan, legacy_shangxiang], legacy_ce_targets)
	game._apply_combo_bonds(true, false)
	legacy_ce.max_hp = 1000.0
	legacy_ce.hp = 500.0
	game._cast_sunce_skill(legacy_ce)
	var legacy_ce_damage := float(game.heroes.sunce.ability_params.base_value) * 4.0 * 1.10
	assert(is_equal_approx(1000000.0 - float(legacy_ce_targets[0].hp), legacy_ce_damage))
	assert(is_equal_approx(1000000.0 - float(legacy_ce_targets[1].hp), legacy_ce_damage))
	assert(is_equal_approx(float(legacy_ce_targets[2].hp), 1000000.0))
	var legacy_ce_hp_before := float(legacy_ce.hp)
	game._damage(legacy_ce_targets[1], legacy_ce, 100.0, "physical", "low hp reduction test")
	assert(is_equal_approx(legacy_ce_hp_before - float(legacy_ce.hp), 80.0))

	# 神亭酣战：第一段命中正前方+左侧，第二段命中正前方+右侧；中心两次。
	var double_ce := _place(game, "player", "sunce", 0, 1)
	var double_taishi := _place(game, "player", "taishici", 1, 2)
	var double_targets: Array = []
	for col in range(3):
		var target := _place(game, "enemy", "caocao", 0, col)
		target.max_hp = 1000000.0
		target.hp = target.max_hp
		double_targets.append(target)
	_set_combat(game, [double_ce, double_taishi], double_targets)
	game._apply_combo_bonds(true, false)
	game._cast_sunce_skill(double_ce)
	var double_ce_damage := float(game.heroes.sunce.ability_params.base_value) * 2.0
	assert(is_equal_approx(1000000.0 - float(double_targets[0].hp), double_ce_damage))
	assert(is_equal_approx(1000000.0 - float(double_targets[1].hp), double_ce_damage * 2.0))
	assert(is_equal_approx(1000000.0 - float(double_targets[2].hp), double_ce_damage))
	assert(game.visual_events.filter(func(event): return event.get("kind", "") == "damage").size() == 4)

	var xiaoqiao_pair := _place(game, "player", "xiaoqiao", 2, 0)
	var zhouyu_for_xiao := _place(game, "player", "zhouyu", 2, 1)
	var daqiao_for_xiao := _place(game, "player", "daqiao", 2, 2)
	for target in full_enemy_board:
		target.hp = target.max_hp
		target.slow = 0.0
		target.slow_time = 0.0
	_set_combat(game, [xiaoqiao_pair], full_enemy_board)
	game._apply_combo_bonds(true, false)
	game._cast_xiaoqiao_skill(xiaoqiao_pair)
	var base_slowed: Array = full_enemy_board.filter(func(target): return float(target.slow_time) > 0.0)
	assert(base_slowed.size() == 2)
	assert(base_slowed.all(func(target): return int(target.row) == game.BOARD_ROWS - 1 and is_equal_approx(float(target.slow), 0.35) and is_equal_approx(float(target.slow_time), 6.0)))
	for target in full_enemy_board:
		target.slow = 0.0
		target.slow_time = 0.0
	_set_combat(game, [xiaoqiao_pair, zhouyu_for_xiao, daqiao_for_xiao], full_enemy_board)
	game._apply_combo_bonds(true, false)
	game._cast_xiaoqiao_skill(xiaoqiao_pair)
	var bonded_slowed: Array = full_enemy_board.filter(func(target): return float(target.slow_time) > 0.0)
	assert(bonded_slowed.size() == 3)
	assert(bonded_slowed.all(func(target): return int(target.row) == game.BOARD_ROWS - 1 and is_equal_approx(float(target.slow), 0.60) and is_equal_approx(float(target.slow_time), 8.0)))

	# 图鉴为新武将显示完整小羁绊效果。
	for bond_name in ["神亭酣战", "江表双锋"]:
		assert(game._hero_bond_detail("taishici").contains(bond_name))
	assert(game._hero_bond_detail("dingfeng").contains("江表虎臣"))
	assert(game._hero_bond_detail("zhouyu").contains("琴瑟和鸣"))
	assert(game._hero_bond_detail("zhouyu").contains("赤壁苦计"))

	quit()
