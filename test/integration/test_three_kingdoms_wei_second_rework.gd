extends SceneTree

func _unit(game, team: String, hero_id: String, row: int, col: int) -> Dictionary:
	var unit: Dictionary = game._make_roster_unit(team, hero_id)
	unit.row = row
	unit.col = col
	unit.max_hp = 100000.0
	unit.hp = unit.max_hp
	game._ensure_unit_fields(unit)
	return unit

func _set_combat(game, players: Array, enemies: Array) -> void:
	game.player_units = players
	game.enemy_units = enemies
	game.combat_units = players + enemies
	game.battle_stats = {}
	for unit in game.combat_units:
		game.battle_stats[unit.id] = {"unit_id":unit.id, "hero_id":unit.hero_id, "team":unit.team, "level":1, "damage":0.0, "healing":0.0, "taken":0.0, "control":0.0}
	game._apply_combo_bonds(false, false)

func _enemies(game, count: int, row := -1) -> Array:
	var result: Array = []
	for index in count:
		result.append(_unit(game, "enemy", "dongzhuo", index % 3 if row < 0 else row, index))
	return result

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()

	for hero_id in ["xiahouyuan", "caoren", "xiahoudun", "simayi", "guojia", "xunyu", "jiaxu"]:
		assert(float(game.heroes[hero_id].cooldown) > 0.0)
	assert(game.heroes.has("jiaxu"))
	var expected_stats := {
		"xiahouyuan":[2740, 5.2, 3], "caoren":[5620, 5.2, 1], "xiahoudun":[5900, 5.2, 1],
		"simayi":[2740, 6.4, 3], "guojia":[2520, 6.4, 3], "xunyu":[2880, 6.4, 3], "jiaxu":[2740, 6.4, 3]
	}
	for hero_id in expected_stats:
		assert(int(game.heroes[hero_id].hp) == int(expected_stats[hero_id][0]))
		assert(is_equal_approx(float(game.heroes[hero_id].cooldown), float(expected_stats[hero_id][1])))
		assert(int(game.heroes[hero_id].range) == int(expected_stats[hero_id][2]))
		assert(is_equal_approx(float(game.heroes[hero_id].skill_value), 100.0))
	assert("220%兵略值" in game._skill_detail("xiahouyuan") and "眩晕1秒" in game._skill_detail("xiahouyuan"))
	assert("200%兵略值" in game._skill_detail("caoren") and "5秒" in game._skill_detail("caoren"))
	assert("240%兵略值" in game._skill_detail("xiahoudun") and "5秒" in game._skill_detail("xiahoudun"))
	assert("320%兵略值" in game._skill_detail("simayi"))
	assert("冻结2名敌人3秒" in game._skill_detail("guojia") and "150%兵略值" in game._skill_detail("guojia"))
	assert("0.4×兵略值%" in game._skill_detail("xunyu") and "4.4秒" in game._skill_detail("xunyu"))
	assert("0.02×兵略值%" in game._skill_detail("jiaxu") and "中毒4秒" in game._skill_detail("jiaxu"))

	# 夏侯三角与文档一致：夏侯渊220%/2秒眩晕/4.2秒冷却；曹仁和夏侯惇各4目标，
	# 分别造成200%/240%伤害、2秒/2.5秒眩晕并获得40%对应兵种减伤5秒。
	var yuan := _unit(game, "player", "xiahouyuan", 2, 0)
	var ren := _unit(game, "player", "caoren", 0, 1)
	var dun := _unit(game, "player", "xiahoudun", 0, 2)
	var mixed_targets := _enemies(game, 5)
	_set_combat(game, [yuan, ren, dun], mixed_targets)
	assert(is_equal_approx(game._unit_skill_cooldown(yuan), 4.2))
	var yuan_before := mixed_targets.map(func(target): return float(target.hp))
	game._cast_xiahouyuan_skill(yuan)
	var yuan_hits := 0
	for index in mixed_targets.size():
		if yuan_before[index] > float(mixed_targets[index].hp):
			yuan_hits += 1
			assert(is_equal_approx(yuan_before[index] - float(mixed_targets[index].hp), 220.0))
			assert(is_equal_approx(float(mixed_targets[index].stun), 2.0))
	assert(yuan_hits == 2)
	var rear_targets := _enemies(game, 4, 2)
	_set_combat(game, [yuan, ren, dun], rear_targets)
	var rear_before := rear_targets.map(func(target): return float(target.hp))
	game._cast_caoren_skill(ren)
	for index in rear_targets.size():
		assert(is_equal_approx(rear_before[index] - float(rear_targets[index].hp), 200.0))
		assert(is_equal_approx(float(rear_targets[index].stun), 2.0))
	assert(is_equal_approx(float(ren.rear_damage_reduction), 0.40))
	assert(is_equal_approx(float(ren.rear_damage_reduction_time), 5.0))
	var front_targets := _enemies(game, 4, 0)
	_set_combat(game, [yuan, ren, dun], front_targets)
	var front_before := front_targets.map(func(target): return float(target.hp))
	game._cast_xiahoudun_skill(dun)
	for index in front_targets.size():
		assert(is_equal_approx(front_before[index] - float(front_targets[index].hp), 240.0))
		assert(is_equal_approx(float(front_targets[index].stun), 2.5))
	assert(is_equal_approx(float(dun.front_damage_reduction), 0.40))
	assert(is_equal_approx(float(dun.front_damage_reduction_time), 5.0))

	# Directional guard only reduces damage from the matching enemy row.
	var rear_attacker := _unit(game, "enemy", "zhouyu", 2, 4)
	var front_attacker := _unit(game, "enemy", "dongzhuo", 0, 4)
	var ren_before := float(ren.hp)
	game._damage(rear_attacker, ren, 1000.0, "physical", "rear")
	assert(is_equal_approx(ren_before - float(ren.hp), 600.0))
	var dun_before := float(dun.hp)
	game._damage(front_attacker, dun, 1000.0, "physical", "front")
	assert(is_equal_approx(dun_before - float(dun.hp), 600.0))

	# 四谋士完全体：司马懿4目标320%；郭嘉3目标冻结3.7秒且4.8秒冷却；
	# 荀彧3目标加速47%；贾诩3目标、4秒、每秒2.5%最大生命且4.8秒冷却。
	var sima := _unit(game, "player", "simayi", 2, 0)
	var guo := _unit(game, "player", "guojia", 2, 1)
	var xun := _unit(game, "player", "xunyu", 2, 2)
	var jia := _unit(game, "player", "jiaxu", 2, 3)
	var targets := _enemies(game, 5)
	_set_combat(game, [sima, guo, xun, jia], targets)
	assert(is_equal_approx(game._unit_skill_cooldown(guo), 4.8))
	assert(is_equal_approx(game._unit_skill_cooldown(xun), 4.8))
	assert(is_equal_approx(game._unit_skill_cooldown(jia), 4.8))
	var hp_before := targets.map(func(target): return float(target.hp))
	game._cast_simayi_skill(sima)
	var sima_hits := 0
	for index in targets.size():
		if hp_before[index] > float(targets[index].hp):
			sima_hits += 1
			assert(is_equal_approx(hp_before[index] - float(targets[index].hp), 320.0))
	assert(sima_hits == 4)

	game._cast_guojia_skill(guo)
	var frozen_targets := targets.filter(func(target): return float(target.freeze) > 0.0)
	assert(frozen_targets.size() == 3)
	assert(frozen_targets.all(func(target): return is_equal_approx(float(target.freeze), 3.7)))
	var frozen: Dictionary = frozen_targets[0]
	var frozen_hp_before := float(frozen.hp)
	game._damage(sima, frozen, 100.0, "magic", "shatter")
	assert(is_equal_approx(float(frozen.freeze), 0.0))
	assert(is_equal_approx(frozen_hp_before - float(frozen.hp), 250.0))

	game._cast_xunyu_skill(xun)
	var hastened := [sima, guo, xun, jia].filter(func(ally): return float(ally.timed_action_time) > 0.0)
	assert(hastened.size() == 3)
	assert(hastened.all(func(ally): return is_equal_approx(float(ally.timed_action_bonus), 0.47) and is_equal_approx(float(ally.timed_action_time), 4.4)))

	for target in targets:
		target.freeze = 0.0
		target.freeze_shatter_damage = 0.0
		target.hp = target.max_hp
	game._cast_jiaxu_skill(jia)
	var poisoned := targets.filter(func(target): return float(target.poison) > 0.0)
	assert(poisoned.size() == 3)
	assert(poisoned.all(func(target): return is_equal_approx(float(target.poison), 4.0) and is_equal_approx(float(target.poison_ratio), 0.025)))
	var poison_before := float(poisoned[0].hp)
	game._process_statuses(1.0)
	assert(is_equal_approx(poison_before - float(poisoned[0].hp), float(poisoned[0].max_hp) * 0.025))

	var graph: Dictionary = game._bond_graph_data("wei")
	var bond_ids: Array = graph.bonds.map(func(bond): return str(bond[0]))
	for bond_id in ["swift_bulwark", "xiahou_brothers", "twin_bulwarks", "thunder_frost", "thunder_royal", "thunder_venom", "frost_royal", "frost_venom", "royal_venom"]:
		assert(bond_ids.has(bond_id))
	assert(graph.bonds.any(func(bond): return Array(bond[3]).has("jiaxu")))
	assert("伤害减少40%兵略值" in game._hero_bond_detail("simayi"))
	assert("冻结时间增加1.2秒" in game._hero_bond_detail("guojia"))
	assert("0.12×兵略值%" in game._hero_bond_detail("xunyu"))
	assert("0.005×兵略值%" in game._hero_bond_detail("jiaxu"))
	quit()
