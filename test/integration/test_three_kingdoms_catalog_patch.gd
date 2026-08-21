extends SceneTree

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()

	assert(is_equal_approx(float(game.heroes.liubei.ability_params.peach_heal_ratio), 2.0))
	assert(is_equal_approx(float(game.heroes.guanyu.ability_params.five_mult), 5.5))
	assert(is_equal_approx(float(game.heroes.zhangfei.ability_params.damage_skill_ratio), 0.15))
	assert(int(game.heroes.zhaoyun.ability_params.five_bonus_hits) == 1)
	assert(int(game.heroes.zhaoyun.ability_params.seven_bonus_hits) == 1)
	assert(is_equal_approx(float(game.heroes.huangzhong.ability_params.five_mult), 11.0))
	assert(is_equal_approx(float(game.heroes.zhugeliang.ability_params.fire_mark_duration), 15.0))
	assert(is_equal_approx(float(game.heroes.pangtong.ability_params.link_duration), 6.0))
	assert(is_equal_approx(float(game.heroes.zhurong.ability_params.burn_ratio), 0.5))
	assert(is_equal_approx(float(game.heroes.dianwei.ability_params.xuchu_damage_bonus_mult), 1.0))
	assert(is_equal_approx(float(game.heroes.xuchu.ability_params.dianwei_damage_bonus_mult), 1.5))
	assert(is_equal_approx(float(game.heroes.zhangliao.ability_params.five_damage_bonus_mult), 1.0))
	assert(is_equal_approx(float(game.heroes.yuejin.ability_params.five_damage_bonus_mult), 0.8))
	assert(is_equal_approx(float(game.heroes.yujin.ability_params.five_shield_bonus_mult), 2.0))
	assert(is_equal_approx(float(game.heroes.xiahouyuan.ability_params.bond_damage_bonus_mult), 0.5))
	assert(is_equal_approx(float(game.heroes.guojia.ability_params.empty_damage_mult), 2.8))
	assert(is_equal_approx(float(game.heroes.zhouyu.ability_params.missing_hp_bonus_per_step), 0.06))
	assert(is_equal_approx(float(game.heroes.chengong.ability_params.cooldown_reduction), 1.2))
	assert(int(game.heroes.qunzhanghe.ability_params.four_pillars_bonus_targets) == 2)
	assert(is_equal_approx(float(game.heroes.zuoci.ability_params.thunder_mult), 2.0))
	print("catalog_patch:parameters_ok")

	var ruler_before := int(game.enemy_ruler_hp)
	for hero_id in ["caocao", "jiangwei", "pangtong", "zhurong"]:
		var caster := _unit(game, "player", hero_id, 0, 2)
		game.combat_units = [caster]
		game._cast_active_skill(caster)
		assert(int(game.enemy_ruler_hp) == ruler_before)
	var madai := _unit(game, "player", "madai", 0, 2)
	game.combat_units = [madai]
	game._cast_madai_execution(madai)
	assert(ruler_before - int(game.enemy_ruler_hp) == 2000)
	print("catalog_patch:empty_tile_rules_ok")

	var sunjian := _unit(game, "player", "sunjian", 0, 2)
	var sunce := _unit(game, "player", "sunce", 0, 1)
	var sunquan := _unit(game, "player", "sunquan", 1, 1)
	var sunshangxiang := _unit(game, "player", "sunshangxiang", 2, 1)
	var wu_target := _unit(game, "enemy", "dongzhuo", 0, 2)
	sunjian.max_hp = 1000.0
	sunjian.hp = 1000.0
	game.combat_units = [sunjian, sunce, sunquan, sunshangxiang, wu_target]
	game._apply_combo_bonds(false, false)
	game._cast_sunjian_skill(sunjian)
	assert(is_equal_approx(float(sunjian.hp), 200.0))
	assert([sunjian, sunce, sunquan, sunshangxiang].all(func(unit): return is_equal_approx(float(unit.kill_buff), 0.15)))
	game._apply_combo_bonds(false, false)
	assert([sunjian, sunce, sunquan, sunshangxiang].all(func(unit): return is_equal_approx(float(unit.kill_buff), 0.15)))
	print("catalog_patch:sun_legacy_ok")

	var guojia := _unit(game, "player", "guojia", 2, 0)
	var attacker := _unit(game, "player", "caocao", 0, 0)
	var frozen := _unit(game, "enemy", "dongzhuo", 0, 0)
	frozen.max_hp = 10000.0
	frozen.hp = frozen.max_hp
	frozen.freeze = 5.4
	frozen.freeze_shatter_per_second = 50.0
	frozen.freeze_source_id = str(guojia.id)
	game.combat_units = [guojia, attacker, frozen]
	var frozen_before := float(frozen.hp)
	game._damage(attacker, frozen, 100.0, "magic", "test")
	assert(is_equal_approx(frozen_before - float(frozen.hp), 370.0))
	print("catalog_patch:freeze_shatter_ok")

	var yuji := _unit(game, "player", "yuji", 1, 0)
	var zuoci := _unit(game, "player", "zuoci", 2, 0)
	var poisoned := _unit(game, "enemy", "dongzhuo", 0, 0)
	poisoned.max_hp = 10000.0
	poisoned.hp = 5000.0
	game.combat_units = [yuji, zuoci, poisoned]
	game._add_decay_poison_effect(yuji, poisoned, 100)
	game._process_statuses(1.0)
	assert(is_equal_approx(float(poisoned.hp), 4875.0))
	assert(int(poisoned.poison_effects[0].stacks) == 50)
	print("catalog_patch:poison_scaling_ok")

	game.tick_timer.stop()
	quit()

func _unit(game, team: String, hero_id: String, row: int, col: int) -> Dictionary:
	var unit: Dictionary = game._make_roster_unit(team, hero_id)
	unit.row = row
	unit.col = col
	return unit
