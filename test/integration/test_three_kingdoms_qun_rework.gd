extends SceneTree

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()

	assert(is_equal_approx(float(game.heroes.lvbu.cooldown), 6.4))
	assert(is_equal_approx(float(game.heroes.dongzhuo.cooldown), 5.5))
	assert(int(game.heroes.dongzhuo.range) == 2)
	assert(is_equal_approx(float(game.heroes.diaochan.cooldown), 7.0))
	assert(game.heroes.chengong.ability == "passive")
	assert(game.heroes.gaolan.ability == "passive")
	print("qun_rework:data_ok")

	# Lu Bu hits the facing vanguard and its two horizontal neighbors.
	var lvbu := _unit(game, "player", "lvbu", 0, 2)
	var sweep_targets: Array = []
	for row in [0, 1]:
		for col in [1, 2, 3]:
			var target := _unit(game, "enemy", "caocao", row, col)
			target.max_hp = 100000.0
			target.hp = target.max_hp
			sweep_targets.append(target)
	game.combat_units = [lvbu] + sweep_targets
	game.visual_events.clear()
	game._cast_lvbu_skill(lvbu)
	var base_hits: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	assert(base_hits.size() == 3)
	assert(base_hits.all(func(event): return int(event.row) == 0))
	assert(base_hits.all(func(event): return int(event.amount) == roundi(float(game.heroes.lvbu.skill_value) * 1.75)))
	print("qun_rework:lvbu_base_ok")

	# Gao Shun extends the same sweep to the corresponding midguard tiles.
	var gaoshun := _unit(game, "player", "gaoshun", 1, 4)
	for target in sweep_targets: target.hp = target.max_hp
	game.combat_units = [lvbu, gaoshun] + sweep_targets
	game.visual_events.clear()
	game._cast_lvbu_skill(lvbu)
	var extended_hits: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	assert(extended_hits.size() == 6)
	print("qun_rework:lvbu_gaoshun_ok")

	# Dong Zhuo's bond heals only from HP actually removed, not shields or empty tiles.
	var dongzhuo := _unit(game, "player", "dongzhuo", 1, 0)
	lvbu.hp = lvbu.max_hp * 0.25
	var normal_target := _unit(game, "enemy", "caocao", 0, 2)
	normal_target.max_hp = 100000.0
	normal_target.hp = normal_target.max_hp
	var shielded_target := _unit(game, "enemy", "caoren", 0, 1)
	shielded_target.max_hp = 100000.0
	shielded_target.hp = shielded_target.max_hp
	shielded_target.shield = 100000.0
	game.combat_units = [lvbu, dongzhuo, normal_target, shielded_target]
	var lvbu_hp_before := float(lvbu.hp)
	game._cast_lvbu_skill(lvbu)
	var actual_damage := 100000.0 - float(normal_target.hp)
	assert(is_equal_approx(float(shielded_target.hp), 100000.0))
	assert(is_equal_approx(float(lvbu.hp) - lvbu_hp_before, actual_damage * 0.40))
	print("qun_rework:lvbu_heal_ok")

	# Chen Gong's column aura stacks its Lu Bu and Gao Shun pair bonuses.
	var chengong := _unit(game, "player", "chengong", 2, 0)
	lvbu.col = 0
	gaoshun.col = 0
	game.combat_units = [chengong, lvbu, gaoshun]
	game._apply_combo_bonds(false, false)
	assert(not game._unit_has_active_skill(chengong))
	assert(is_equal_approx(float(lvbu.bond_cooldown), 3.4))
	assert(is_equal_approx(float(gaoshun.bond_cooldown), 3.2))
	print("qun_rework:chengong_ok")

	# Diao Chan charms for 6s with Dong Zhuo and forces one adjacent betrayal per second with Lu Bu.
	var diaochan := _unit(game, "player", "diaochan", 2, 4)
	var charmed_a := _unit(game, "enemy", "caocao", 1, 1)
	var charmed_b := _unit(game, "enemy", "caoren", 1, 2)
	charmed_a.max_hp = 100000.0; charmed_a.hp = charmed_a.max_hp
	charmed_b.max_hp = 100000.0; charmed_b.hp = charmed_b.max_hp
	game.combat_units = [diaochan, dongzhuo, lvbu, charmed_a, charmed_b]
	game._cast_diaochan(diaochan)
	var charmed := charmed_a if float(charmed_a.charm) > 0.0 else charmed_b
	var betrayed := charmed_b if charmed.id == charmed_a.id else charmed_a
	assert(is_equal_approx(float(charmed.charm), 6.0))
	var betrayed_hp_before := float(betrayed.hp)
	game._process_statuses(1.0)
	assert(float(betrayed.hp) < betrayed_hp_before)
	assert(is_equal_approx(float(charmed.charm), 5.0))
	print("qun_rework:diaochan_ok")

	# Gao Shun reaches 4 targets with Lu Bu and 6s Fragile with Chen Gong.
	var fragile_targets: Array = []
	for index in 4:
		var target := _unit(game, "enemy", "caocao", index % 3, index)
		target.max_hp = 100000.0; target.hp = target.max_hp
		fragile_targets.append(target)
	game.combat_units = [gaoshun, lvbu, chengong] + fragile_targets
	game._cast_gaoshun_skill(gaoshun)
	assert(fragile_targets.all(func(target): return is_equal_approx(float(target.vulnerable), 0.40)))
	assert(fragile_targets.all(func(target): return is_equal_approx(float(target.vulnerable_time), 6.0)))
	print("qun_rework:gaoshun_ok")

	# All four Hebei pillars are required for hit-stacking, the cross aura, and 6 stronger shields.
	var yanliang := _unit(game, "player", "yanliang", 1, 0)
	var wenchou := _unit(game, "player", "wenchou", 0, 2)
	var gaolan := _unit(game, "player", "gaolan", 2, 4)
	var qunzhanghe := _unit(game, "player", "qunzhanghe", 0, 3)
	lvbu.row = 2; lvbu.col = 1
	diaochan.row = 1; diaochan.col = 4
	game.combat_units = [yanliang, wenchou, gaolan, qunzhanghe, lvbu, diaochan]
	game._apply_combo_bonds(false, false)
	assert(bool(yanliang.four_pillars) and bool(wenchou.four_pillars))
	assert(is_equal_approx(float(lvbu.skill_value_bonus), 40.0))
	assert(is_equal_approx(float(diaochan.skill_value_bonus), 40.0))
	game._cast_qun_zhanghe_skill(qunzhanghe)
	var expected_shield := float(game.heroes.qunzhanghe.skill_value) * 4.0
	assert(game.combat_units.all(func(unit): return is_equal_approx(float(unit.shield), expected_shield)))
	print("qun_rework:pillars_shield_ok")

	var enemy_attacker := _unit(game, "enemy", "caocao", 0, 0)
	game.combat_units.append(enemy_attacker)
	yanliang.shield = 0.0
	for _hit in 3:
		game._damage(enemy_attacker, yanliang, 10.0, "physical", "stack test")
	assert(int(yanliang.hebei_damage_stacks) == 3)
	assert(is_equal_approx(game._hebei_stored_damage_multiplier(yanliang, game.heroes.yanliang.ability_params), 1.45))
	print("qun_rework:pillars_stack_ok")

	# Generic lifesteal also ignores fully shielded damage and ruler hits from empty tiles.
	enemy_attacker.max_hp = 10000.0
	enemy_attacker.hp = 1000.0
	enemy_attacker.all_lifesteal = 1.0
	enemy_attacker.all_lifesteal_time = 10.0
	qunzhanghe.shield = 10000.0
	var attacker_hp_before := float(enemy_attacker.hp)
	game._damage(enemy_attacker, qunzhanghe, 100.0, "physical", "shield test")
	assert(is_equal_approx(float(enemy_attacker.hp), attacker_hp_before))
	game._hit_ruler(enemy_attacker, 100.0, {"row":0, "col":0, "team":"player"}, "empty test")
	assert(is_equal_approx(float(enemy_attacker.hp), attacker_hp_before))

	game.tick_timer.stop()
	quit()

func _unit(game, team: String, hero_id: String, row: int, col: int) -> Dictionary:
	var unit: Dictionary = game._make_roster_unit(team, hero_id)
	unit.row = row
	unit.col = col
	return unit
