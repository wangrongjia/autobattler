extends SceneTree

const SHU_SCOPE := {
	"liubei":{"hp":3740, "cooldown":12.0, "range":3, "params":{"duration":4.0, "heal_ratio":1.0}},
	"guanyu":{"hp":5180, "cooldown":12.6, "range":1, "params":{"mult":2.10, "five_mult":4.60, "peach_heal":0.30}},
	"zhangfei":{"hp":5620, "cooldown":13.2, "range":2, "params":{"damage_ratio":0.20, "duration":3.3}},
	"zhaoyun":{"hp":3840, "cooldown":11.4, "range":2, "params":{"hit_count":5, "hit_mult":1.15, "seven_hit_count":7}},
	"liushan":{"hp":3460, "cooldown":0.0, "range":2, "params":{"damage_ratio":0.27, "liubei_damage_ratio":0.18}},
	"huangzhong":{"hp":3550, "cooldown":8.4, "range":3, "params":{"mult":4.20, "five_mult":9.0}},
	"machao":{"hp":3600, "cooldown":14.4, "range":2, "params":{"front_mult":2.60, "middle_mult":2.30, "back_mult":2.0}},
	"madai":{"hp":3580, "cooldown":42.0, "range":3, "params":{"max_hp_ratio":0.50, "empty_ruler_damage":2000.0}},
	"weiyan":{"hp":4540, "cooldown":10.8, "range":1, "params":{"mult":1.80, "meteor_heal":0.23, "fated_ally_heal":0.06}},
	"zhugeliang":{"hp":3460, "cooldown":13.8, "range":3, "params":{"mult":2.30, "fire_mark_duration":10.0, "fire_mark_bonus":0.40}},
	"jiangwei":{"hp":4320, "cooldown":9.0, "range":1, "params":{"mult":4.50, "bond_splash_mult":1.0}},
	"pangtong":{"hp":3550, "cooldown":10.8, "range":3, "params":{"target_count":2, "mult":2.0, "link_duration":4.0, "link_ratio":0.30}},
	"menghuo":{"hp":5180, "cooldown":11.4, "range":1, "params":{"mult":1.15, "stun":0.8, "aftershock_mult":0.35, "bond_action_reduction":8.0}},
}

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()
	game.language = "zh"
	print("shu_contract:scene")

	for hero in game.heroes.values():
		assert(float(hero.skill_value) == 100.0)
		assert(not hero.has("skill_output_base"))
		assert(not hero.has("roles"))
	print("shu_contract:registration")

	for hero_id in SHU_SCOPE:
		var expected: Dictionary = SHU_SCOPE[hero_id]
		var hero: Dictionary = game.heroes[hero_id]
		assert(int(hero.hp) == int(expected.hp))
		assert(is_equal_approx(float(hero.cooldown), float(expected.cooldown)))
		assert(int(hero.range) == int(expected.range))
		for key in expected.params:
			assert(hero.ability_params.has(key))
			assert(is_equal_approx(float(hero.ability_params[key]), float(expected.params[key])))
		var skill_text: String = game._skill_detail(hero_id)
		var bond_text: String = game._hero_bond_detail(hero_id)
		assert(skill_text.contains("兵略值") or hero_id in ["zhangfei", "madai"])
		assert(not skill_text.contains("技能强度"))
		assert(not skill_text.contains("实战数值"))
		assert(not skill_text.contains("当前技能数值"))
		assert(not skill_text.contains("定位"))
		assert(bond_text.rfind("阵营羁绊") >= 0)
		assert(bond_text.ends_with("释放技能后清空。"))
		assert(not bond_text.contains("汉室北伐"))
	print("shu_contract:data_codex")

	# The combat panel keeps hero bonds above the compact faction bond section.
	var bond_units: Array = []
	for index in 3:
		var unit: Dictionary = game._make_roster_unit("player", ["liubei", "guanyu", "zhangfei"][index])
		unit.row = index
		unit.col = 0
		bond_units.append(unit)
	var combat_bonds: String = game._bond_text(bond_units)
	assert(combat_bonds.find("武将羁绊") >= 0)
	assert(combat_bonds.find("阵营羁绊") > combat_bonds.find("武将羁绊"))
	assert(combat_bonds.contains("蜀"))
	print("shu_contract:bonds")

	# Guan Yu is the direct contract example: 210% × 100 per occupied tile,
	# with no hidden output base and no second Strategy multiplication.
	var guanyu: Dictionary = game._make_roster_unit("player", "guanyu")
	guanyu.row = 0
	guanyu.col = 2
	var targets: Array = []
	for row in game.BOARD_ROWS:
		for col in game.BOARD_COLUMNS:
			var target: Dictionary = game._make_roster_unit("enemy", "caocao")
			target.row = row
			target.col = col
			target.max_hp = 10000.0
			target.hp = 10000.0
			targets.append(target)
	game.combat_units = [guanyu] + targets
	game.visual_events.clear()
	game._cast_guanyu_skill(guanyu)
	var hits_100 := targets.filter(func(target): return float(target.hp) < 10000.0)
	assert(hits_100.size() == 3)
	for target in hits_100: assert(is_equal_approx(10000.0 - float(target.hp), 210.0))
	print("shu_contract:guan100")

	game.heroes.guanyu.skill_value = 50
	for target in targets: target.hp = 10000.0
	game.visual_events.clear()
	game._cast_guanyu_skill(guanyu)
	var hits_50 := targets.filter(func(target): return float(target.hp) < 10000.0)
	assert(hits_50.size() == 3)
	for target in hits_50: assert(is_equal_approx(10000.0 - float(target.hp), 105.0))
	game.heroes.guanyu.skill_value = 100
	print("shu_contract:guan50")

	# Liu Bei likewise reads the registered Strategy value directly.
	var liubei: Dictionary = game._make_roster_unit("player", "liubei")
	var wounded: Dictionary = game._make_roster_unit("player", "zhangfei")
	liubei.row = 2
	liubei.col = 0
	wounded.row = 0
	wounded.col = 0
	wounded.hp = float(wounded.max_hp) * 0.5
	game.combat_units = [liubei, wounded]
	game._cast_liubei_regen(liubei)
	assert(is_equal_approx(float(wounded.regen_per_second), 100.0))
	assert(is_equal_approx(float(wounded.regen_time), 4.0))

	print("shu_codex_contract:ok")
	quit()
