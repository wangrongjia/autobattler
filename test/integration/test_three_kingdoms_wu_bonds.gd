extends SceneTree

const WU_IDS := ["zhouyu", "luxun", "lvmeng", "lusu", "daqiao", "xiaoqiao", "taishici", "ganning", "huanggai", "sunjian", "sunce", "sunquan", "sunshangxiang", "dingfeng", "xusheng"]

func _place(game, team: String, hero_id: String, row: int, col: int, hp := 10000.0) -> Dictionary:
	var unit: Dictionary = game._make_roster_unit(team, hero_id)
	unit.row = row
	unit.col = col
	unit.max_hp = hp
	unit.hp = hp
	unit.skill_value = 100.0
	return unit

func _set_combat(game, allies: Array, enemies: Array, apply_bonds := true) -> void:
	game.player_units = allies
	game.enemy_units = enemies
	game.combat_units = allies + enemies
	game.visual_events.clear()
	game.ground_effects.clear()
	game.enemy_ruler_hp = game.RULER_MAX_HP
	game.player_ruler_hp = game.RULER_MAX_HP
	if apply_bonds: game._apply_combo_bonds(true, false)

func _full_enemy_board(game, hp := 10000.0) -> Array:
	var result: Array = []
	var ids := ["liubei", "guanyu", "zhangfei", "zhaoyun", "huangzhong", "machao", "weiyan", "madai", "zhugeliang", "jiangwei", "pangtong", "menghuo", "zhurong", "dailaidongzhu", "liushan"]
	for row in game.BOARD_ROWS:
		for col in game.BOARD_COLUMNS:
			result.append(_place(game, "enemy", ids[row * game.BOARD_COLUMNS + col], row, col, hp))
	return result

func _assert_close(actual: float, expected: float, tolerance := 0.01) -> void:
	assert(absf(actual - expected) <= tolerance, "expected %s, got %s" % [expected, actual])

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()

	var cooldowns := {
		"zhouyu":11.6, "luxun":11.6, "lvmeng":11.2, "lusu":11.2, "daqiao":12.4,
		"xiaoqiao":12.4, "taishici":12.0, "ganning":12.0, "huanggai":17.6,
		"sunjian":30.0, "sunce":10.4, "sunquan":10.4, "sunshangxiang":10.4,
		"dingfeng":10.8, "xusheng":11.6
	}
	for hero_id in WU_IDS:
		assert(game.heroes.has(hero_id))
		_assert_close(float(game.heroes[hero_id].cooldown), float(cooldowns[hero_id]))
		_assert_close(float(game.heroes[hero_id].skill_value), 100.0)
	assert(not game.heroes.has("jiangqin"))
	assert("200%兵略值" in game._skill_detail("zhouyu") and "灼烧4秒" in game._skill_detail("zhouyu"))
	assert("290%兵略值" in game._skill_detail("luxun"))
	assert("500%兵略值" in game._skill_detail("lvmeng"))
	assert("320%兵略值" in game._skill_detail("lusu"))
	assert("380%兵略值" in game._skill_detail("daqiao"))
	assert("0.35×兵略值%" in game._skill_detail("xiaoqiao"))
	assert("300%自身兵略值" in game._skill_detail("ganning"))
	assert("400%兵略值" in game._skill_detail("dingfeng"))
	assert("0.3×兵略值%" in game._skill_detail("xusheng"))

	# Full roster activates every Wu bond without changing the user's HP/range values.
	var full_team: Array = []
	for index in WU_IDS.size():
		full_team.append(_place(game, "player", WU_IDS[index], index % game.BOARD_ROWS, floori(float(index) / float(game.BOARD_ROWS))))
	_set_combat(game, full_team, [])
	assert(bool(game._combat_hero("player", "zhouyu").four_heroes))
	assert(bool(game._combat_hero("player", "sunce").sun_legacy))
	assert(bool(game._combat_hero("player", "lvmeng").lvmeng_ganning))
	assert(bool(game._combat_hero("player", "sunce").sunce_taishi))
	assert(bool(game._combat_hero("player", "daqiao").sunce_daqiao))
	assert(bool(game._combat_hero("player", "xusheng").dingfeng_xusheng))
	_assert_close(game._unit_skill_cooldown(game._combat_hero("player", "ganning")), 12.0 * 100.0 / 117.5)
	_assert_close(float(game._combat_hero("player", "sunjian").action), game.ACTION_MAX)

	# 太史慈：双羁绊完全体为3目标，每名230伤害，灼烧每秒20。
	var taishi := _place(game, "player", "taishici", 1, 0)
	var taishi_sunce := _place(game, "player", "sunce", 0, 1)
	var taishi_ganning := _place(game, "player", "ganning", 1, 2)
	var taishi_targets := [_place(game, "enemy", "liubei", 0, 0), _place(game, "enemy", "guanyu", 0, 1), _place(game, "enemy", "zhangfei", 0, 2)]
	for index in taishi_targets.size(): taishi_targets[index].action = 90.0 - index
	_set_combat(game, [taishi, taishi_sunce, taishi_ganning], taishi_targets)
	game._cast_taishici_skill(taishi)
	for target in taishi_targets:
		_assert_close(10000.0 - float(target.hp), 230.0)
		assert(target.burn_effects.size() == 1)
		_assert_close(float(target.burn_effects[0].damage), 20.0)

	# 丁奉羁绊只强化主目标，不再攻击相邻格。
	var ding := _place(game, "player", "dingfeng", 1, 0)
	var xu_for_ding := _place(game, "player", "xusheng", 0, 1)
	var ding_target := _place(game, "enemy", "liubei", 0, 0)
	ding_target.action = 100.0
	_set_combat(game, [ding, xu_for_ding], [ding_target])
	game._cast_dingfeng_skill(ding)
	_assert_close(10000.0 - float(ding_target.hp), 500.0)
	_assert_close(float(ding_target.action), 30.0)

	# 吕蒙与甘宁：650%伤害并无视护盾；四英杰同时施加5秒恐惧。
	var lvmeng := _place(game, "player", "lvmeng", 0, 0)
	var lm_ganning := _place(game, "player", "ganning", 1, 1)
	var lm_zhouyu := _place(game, "player", "zhouyu", 2, 0)
	var lm_luxun := _place(game, "player", "luxun", 2, 1)
	var lm_lusu := _place(game, "player", "lusu", 1, 2)
	var rear_target := _place(game, "enemy", "huangzhong", 2, 0)
	rear_target.shield = 1000.0
	_set_combat(game, [lvmeng, lm_ganning, lm_zhouyu, lm_luxun, lm_lusu], [rear_target])
	game._cast_lvmeng_skill(lvmeng)
	_assert_close(10000.0 - float(rear_target.hp), 650.0)
	_assert_close(float(rear_target.shield), 1000.0)
	_assert_close(float(rear_target.fear), 9.0)
	_assert_close(float(rear_target.fear_damage_ratio), 0.04)
	_assert_close(float(lvmeng.stealth), 0.0)

	# 大乔：基础380%，双姝追加150%；江东佳偶按目标已损生命整体放大。
	var daqiao := _place(game, "player", "daqiao", 2, 0)
	var dq_xiao := _place(game, "player", "xiaoqiao", 2, 1)
	var dq_sunce := _place(game, "player", "sunce", 0, 2)
	var heal_target := _place(game, "player", "guanyu", 0, 3, 5000.0)
	heal_target.hp = 2500.0
	_set_combat(game, [daqiao, dq_xiao, dq_sunce, heal_target], [])
	game._cast_daqiao_skill(daqiao)
	_assert_close(float(heal_target.hp), 3136.0)

	# 鲁肃四英杰：两名最低生命友军，各加500最大生命并治疗400。
	var lusu := _place(game, "player", "lusu", 1, 0)
	var low_a := _place(game, "player", "guanyu", 0, 0, 1000.0)
	var low_b := _place(game, "player", "zhangfei", 0, 1, 1000.0)
	low_a.hp = 100.0
	low_b.hp = 200.0
	var rs_zhou := _place(game, "player", "zhouyu", 2, 1)
	var rs_luxun := _place(game, "player", "luxun", 2, 2)
	var rs_lvmeng := _place(game, "player", "lvmeng", 0, 2)
	_set_combat(game, [lusu, low_a, low_b, rs_zhou, rs_luxun, rs_lvmeng], [])
	game._cast_lusu_skill(lusu)
	_assert_close(float(low_a.max_hp), 1500.0)
	_assert_close(float(low_b.max_hp), 1500.0)
	_assert_close(float(low_a.hp), 500.0)
	_assert_close(float(low_b.hp), 600.0)

	# 周瑜完全体：4格、200直接伤害、7秒且每秒110的灼烧；黄盖只放大DOT。
	var zhou := _place(game, "player", "zhouyu", 2, 0)
	var z_luxun := _place(game, "player", "luxun", 2, 1)
	var z_lusu := _place(game, "player", "lusu", 1, 1)
	var z_lvmeng := _place(game, "player", "lvmeng", 0, 1)
	var z_xiao := _place(game, "player", "xiaoqiao", 2, 2)
	var z_huang := _place(game, "player", "huanggai", 0, 2)
	var z_targets := _full_enemy_board(game)
	_set_combat(game, [zhou, z_luxun, z_lusu, z_lvmeng, z_xiao, z_huang], z_targets)
	game._cast_zhouyu(zhou)
	var ignited := z_targets.filter(func(target): return target.burn_effects.size() > 0)
	assert(ignited.size() == 4)
	for target in ignited:
		_assert_close(10000.0 - float(target.hp), 200.0)
		_assert_close(float(target.burn_effects[0].time), 7.0)
		_assert_close(float(target.burn_effects[0].damage), 110.0)
		_assert_close(float(target.burn_effects[0].missing_hp_bonus_per_step), 0.03)

	# 小乔双羁绊：3名后军、47%减速、仍固定6秒。
	var xiao := _place(game, "player", "xiaoqiao", 2, 0)
	var x_daqiao := _place(game, "player", "daqiao", 2, 1)
	var x_zhou := _place(game, "player", "zhouyu", 2, 2)
	var x_targets := [_place(game, "enemy", "huangzhong", 2, 0), _place(game, "enemy", "madai", 2, 1), _place(game, "enemy", "pangtong", 2, 2)]
	_set_combat(game, [xiao, x_daqiao, x_zhou], x_targets)
	game._cast_xiaoqiao_skill(xiao)
	for target in x_targets:
		_assert_close(float(target.slow), 0.47)
		_assert_close(float(target.slow_time), 10.8)

	# 甘宁双羁绊：低血目标时自身和左侧友军各480伤害，江表双锋提供18冷却极速。
	var gan_left := _place(game, "player", "zhouyu", 1, 0)
	var gan := _place(game, "player", "ganning", 1, 1)
	var gan_taishi := _place(game, "player", "taishici", 1, 2)
	var gan_lvmeng := _place(game, "player", "lvmeng", 0, 2)
	var gan_target := _place(game, "enemy", "huangzhong", 2, 0)
	gan_target.hp = 4000.0
	_set_combat(game, [gan_left, gan, gan_taishi, gan_lvmeng], [gan_target])
	game._cast_ganning_skill(gan)
	_assert_close(float(gan_target.hp), 3040.0)
	_assert_close(game._unit_skill_cooldown(gan), 12.0 * 100.0 / 117.5)

	# 黄盖双羁绊：15%最大生命，整列每格200兵略值+消耗生命50%，并附加5秒灼烧。
	var huang := _place(game, "player", "huanggai", 0, 0, 1000.0)
	var h_zhou := _place(game, "player", "zhouyu", 2, 1)
	var h_sunjian := _place(game, "player", "sunjian", 0, 2)
	var h_targets := _full_enemy_board(game)
	_set_combat(game, [huang, h_zhou, h_sunjian], h_targets)
	game._cast_huanggai_skill(huang)
	_assert_close(float(huang.hp), 850.0)
	var h_hit := h_targets.filter(func(target): return target.burn_effects.size() > 0)
	assert(h_hit.size() == 3)
	for target in h_hit:
		_assert_close(10000.0 - float(target.hp), 275.0)
		_assert_close(float(target.burn_effects[0].time), 5.0)
		_assert_close(float(target.burn_effects[0].damage), 50.0)

	# 孙权完全体先成长、治疗，再按自身当前生命11%造成伤害。
	var quan := _place(game, "player", "sunquan", 1, 0, 2000.0)
	quan.hp = 1000.0
	var q_jian := _place(game, "player", "sunjian", 0, 1)
	var q_ce := _place(game, "player", "sunce", 0, 2)
	var q_xiang := _place(game, "player", "sunshangxiang", 2, 2)
	var q_luxun := _place(game, "player", "luxun", 2, 1)
	var q_target := _place(game, "enemy", "liubei", 0, 0)
	_set_combat(game, [quan, q_jian, q_ce, q_xiang, q_luxun], [q_target])
	game._cast_sunquan_skill(quan)
	_assert_close(float(quan.max_hp), 2400.0)
	_assert_close(float(quan.hp), 1280.0)
	_assert_close(10000.0 - float(q_target.hp), 140.8)

	# 孙策：太史慈使基础倍率变为210%；孙氏追加第二段；大乔提供残血减伤。
	var ce := _place(game, "player", "sunce", 0, 1, 1000.0)
	ce.hp = 500.0
	var ce_taishi := _place(game, "player", "taishici", 1, 0)
	var ce_daqiao := _place(game, "player", "daqiao", 2, 0)
	var ce_jian := _place(game, "player", "sunjian", 0, 3)
	var ce_quan := _place(game, "player", "sunquan", 1, 3)
	var ce_xiang := _place(game, "player", "sunshangxiang", 2, 3)
	var ce_targets := [_place(game, "enemy", "liubei", 0, 0), _place(game, "enemy", "guanyu", 0, 1), _place(game, "enemy", "zhangfei", 0, 2)]
	_set_combat(game, [ce, ce_taishi, ce_daqiao, ce_jian, ce_quan, ce_xiang], ce_targets)
	game._cast_sunce_skill(ce)
	_assert_close(10000.0 - float(ce_targets[1].hp), 504.0)
	_assert_close(10000.0 - float(ce_targets[0].hp), 252.0)
	_assert_close(10000.0 - float(ce_targets[2].hp), 252.0)
	var ce_before := float(ce.hp)
	game._damage(ce_targets[1], ce, 100.0, "physical", "test")
	_assert_close(ce_before - float(ce.hp), 85.0)

	# 孙尚香孙氏：随机2个不同目标，各500伤害；释放后兵略值+1。
	var xiang := _place(game, "player", "sunshangxiang", 2, 0)
	var ss_jian := _place(game, "player", "sunjian", 0, 0)
	var ss_ce := _place(game, "player", "sunce", 0, 1)
	var ss_quan := _place(game, "player", "sunquan", 1, 1)
	var ss_targets := [_place(game, "enemy", "liubei", 0, 0), _place(game, "enemy", "guanyu", 0, 1)]
	_set_combat(game, [xiang, ss_jian, ss_ce, ss_quan], ss_targets)
	game._cast_sunshangxiang_skill(xiang)
	for target in ss_targets: _assert_close(10000.0 - float(target.hp), 500.0)
	_assert_close(float(xiang.sunshangxiang_skill_bonus), 1.0)

	# 徐盛羁绊：随机一整排，全部格子同步受伤100并减速30%，持续7秒。
	var xu := _place(game, "player", "xusheng", 0, 0)
	var xu_ding := _place(game, "player", "dingfeng", 1, 1)
	var xu_targets := _full_enemy_board(game)
	_set_combat(game, [xu, xu_ding], xu_targets)
	game._cast_xusheng_skill(xu)
	var water_hit := xu_targets.filter(func(target): return float(target.slow_time) > 0.0)
	assert(water_hit.size() == game.BOARD_COLUMNS)
	for target in water_hit:
		_assert_close(10000.0 - float(target.hp), 100.0)
		_assert_close(float(target.slow), 0.30)
		_assert_close(float(target.slow_time), 12.6)

	# 孙坚孙氏：消耗全部生命、按实际消耗值攻击，并给予12%不可叠加增伤。
	var jian := _place(game, "player", "sunjian", 0, 0, 1000.0)
	var j_ce := _place(game, "player", "sunce", 0, 1)
	var j_quan := _place(game, "player", "sunquan", 1, 1)
	var j_xiang := _place(game, "player", "sunshangxiang", 2, 1)
	var j_target := _place(game, "enemy", "liubei", 0, 0)
	_set_combat(game, [jian, j_ce, j_quan, j_xiang], [j_target])
	game._cast_sunjian_skill(jian)
	assert(not jian.alive)
	_assert_close(10000.0 - float(j_target.hp), 1000.0)
	_assert_close(float(j_ce.kill_buff), 0.12)

	var all_wu_bond_details := ""
	for hero_id in WU_IDS: all_wu_bond_details += game._hero_bond_detail(hero_id)
	for bond_name in ["四英杰", "孙氏之志", "江东双姝", "白衣奇袭", "神亭酣战", "江东佳偶", "琴瑟和鸣", "赤壁苦计", "江东柱石", "江表双锋", "君臣同心", "江表虎臣"]:
		assert(bond_name in all_wu_bond_details)

	game.queue_free()
	quit()
