extends SceneTree

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()

	var expected_cooldowns := {
		"lvbu":13.0, "diaochan":13.0, "dongzhuo":11.0, "gaoshun":13.0,
		"chengong":0.0, "yanliang":11.0, "wenchou":11.0, "qunzhanghe":12.0,
		"gaolan":0.0, "huatuo":11.0, "yuji":11.0, "zuoci":11.0,
		"zhangjiao":12.0, "zhangliang":12.0, "zhangbao":0.0
	}
	for hero_id in expected_cooldowns:
		assert(is_equal_approx(float(game.heroes[hero_id].cooldown), float(expected_cooldowns[hero_id])))
		assert(is_equal_approx(float(game.heroes[hero_id].skill_value), 100.0))
	print("qun_rework:data_ok")

	var lvbu := _unit(game, "player", "lvbu", 0, 2)
	var front_targets: Array = []
	for col in [1, 2, 3]:
		var target := _durable_enemy(game, 0, col)
		front_targets.append(target)
	game.combat_units = [lvbu] + front_targets
	game.visual_events.clear()
	game._cast_lvbu_skill(lvbu)
	var hits: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	assert(hits.size() == 3)
	assert(hits.all(func(event): return int(event.amount) == 220))

	var gaoshun := _unit(game, "player", "gaoshun", 0, 4)
	var middle := _durable_enemy(game, 1, 2)
	for target in front_targets: target.hp = target.max_hp
	game.combat_units = [lvbu, gaoshun, middle] + front_targets
	game.visual_events.clear()
	game._cast_lvbu_skill(lvbu)
	hits = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	assert(hits.size() == 4)
	assert(hits.filter(func(event): return int(event.row) == 1 and int(event.col) == 2).size() == 1)
	print("qun_rework:lvbu_shape_ok")

	var dongzhuo := _unit(game, "player", "dongzhuo", 1, 0)
	lvbu.hp = lvbu.max_hp * 0.25
	var normal_target := _durable_enemy(game, 0, 2)
	var shielded_target := _durable_enemy(game, 0, 1)
	shielded_target.shield = 100000.0
	game.combat_units = [lvbu, dongzhuo, normal_target, shielded_target]
	var hp_before := float(lvbu.hp)
	game._cast_lvbu_skill(lvbu)
	var actual_damage := 100000.0 - float(normal_target.hp)
	assert(is_equal_approx(float(lvbu.hp) - hp_before, actual_damage * 0.20))
	print("qun_rework:lvbu_heal_ok")

	var chengong := _unit(game, "player", "chengong", 1, 0)
	lvbu.col = 0
	gaoshun.col = 0
	game.combat_units = [chengong, lvbu, gaoshun]
	game._apply_combo_bonds(false, false)
	assert(is_equal_approx(float(lvbu.bond_cooldown), 9.6))
	assert(is_equal_approx(float(gaoshun.bond_cooldown), 9.6))
	print("qun_rework:chengong_ok")

	var diaochan := _unit(game, "player", "diaochan", 2, 4)
	diaochan.hp = 100.0
	var charmed_a := _durable_enemy(game, 1, 1)
	var charmed_b := _durable_enemy(game, 1, 2)
	game.combat_units = [diaochan, dongzhuo, lvbu, charmed_a, charmed_b]
	game._cast_diaochan(diaochan)
	var charmed := charmed_a if float(charmed_a.charm) > 0.0 else charmed_b
	assert(is_equal_approx(float(charmed.charm), 10.8))
	assert(is_equal_approx(float(diaochan.hp), 300.0))
	print("qun_rework:diaochan_ok")

	var fragile_targets: Array = []
	for index in 3:
		fragile_targets.append(_durable_enemy(game, index, index))
	game.combat_units = [gaoshun, lvbu, chengong] + fragile_targets
	game._cast_gaoshun_skill(gaoshun)
	assert(fragile_targets.all(func(target): return is_equal_approx(float(target.vulnerable), 0.40)))
	assert(fragile_targets.all(func(target): return is_equal_approx(float(target.vulnerable_time), 12.6)))
	print("qun_rework:gaoshun_ok")

	var yanliang := _unit(game, "player", "yanliang", 0, 0)
	var wenchou := _unit(game, "player", "wenchou", 0, 1)
	var qunzhanghe := _unit(game, "player", "qunzhanghe", 1, 2)
	var gaolan := _unit(game, "player", "gaolan", 2, 2)
	var aura_row := _unit(game, "player", "diaochan", 2, 4)
	var aura_col := _unit(game, "player", "lvbu", 0, 2)
	game.combat_units = [yanliang, wenchou, qunzhanghe, gaolan, aura_row, aura_col]
	game._apply_combo_bonds(false, false)
	assert(is_equal_approx(float(aura_row.skill_value_bonus), 25.0))
	assert(is_equal_approx(float(aura_col.skill_value_bonus), 25.0))
	for ally in game.combat_units:
		ally.hp = float(100 + int(ally.col) * 10 + int(ally.row))
	game._cast_qun_zhanghe_skill(qunzhanghe)
	var shielded: Array = game.combat_units.filter(func(unit): return float(unit.shield) > 0.0)
	assert(shielded.size() == 3)
	assert(shielded.all(func(unit): return is_equal_approx(float(unit.shield), 450.0)))
	print("qun_rework:hebei_aura_shield_ok")

	var enemy_targets: Array = []
	for index in 4:
		var enemy := _durable_enemy(game, 1 if index < 2 else 2, index)
		enemy_targets.append(enemy)
	game.combat_units = [yanliang, wenchou, qunzhanghe, gaolan] + enemy_targets
	game._apply_combo_bonds(false, false)
	game.visual_events.clear()
	game._cast_yanliang_skill(yanliang)
	hits = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	assert(hits.size() == 4 and hits.all(func(event): return int(event.amount) == 290))
	for enemy in enemy_targets: enemy.hp = enemy.max_hp; enemy.row = 0 if int(enemy.col) < 2 else 1
	game.visual_events.clear()
	game._cast_wenchou_skill(wenchou)
	hits = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	assert(hits.size() == 4 and hits.all(func(event): return int(event.amount) == 400))
	print("qun_rework:hebei_attack_ok")

	game.tick_timer.stop()
	quit()

func _unit(game, team: String, hero_id: String, row: int, col: int) -> Dictionary:
	var unit: Dictionary = game._make_roster_unit(team, hero_id)
	unit.row = row
	unit.col = col
	return unit

func _durable_enemy(game, row: int, col: int) -> Dictionary:
	var unit := _unit(game, "enemy", "caocao", row, col)
	unit.max_hp = 100000.0
	unit.hp = unit.max_hp
	return unit
