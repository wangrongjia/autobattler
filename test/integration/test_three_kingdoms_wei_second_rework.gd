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

	# Full Xiahou triangle stacks each pair independently.
	var yuan := _unit(game, "player", "xiahouyuan", 2, 0)
	var ren := _unit(game, "player", "caoren", 0, 1)
	var dun := _unit(game, "player", "xiahoudun", 0, 2)
	var mixed_targets := _enemies(game, 5)
	_set_combat(game, [yuan, ren, dun], mixed_targets)
	assert(game._unit_skill_cooldown(yuan) < float(game.heroes.xiahouyuan.cooldown))
	mixed_targets[0].stun = 0.25
	var stunned_before := float(mixed_targets[0].hp)
	game._damage(yuan, mixed_targets[0], float(game.heroes.xiahouyuan.skill_value) * 2.5, "physical", "test")
	assert(is_equal_approx(stunned_before - float(mixed_targets[0].hp), float(game.heroes.xiahouyuan.skill_value) * 2.5))
	game._cast_caoren_skill(ren)
	assert(is_equal_approx(float(ren.rear_damage_reduction), 0.40))
	assert(is_equal_approx(float(ren.rear_damage_reduction_time), 6.0))
	game._cast_xiahoudun_skill(dun)
	assert(is_equal_approx(float(dun.front_damage_reduction), 0.40))
	assert(is_equal_approx(float(dun.front_damage_reduction_time), 6.5))

	# Directional guard only reduces damage from the matching enemy row.
	var rear_attacker := _unit(game, "enemy", "zhouyu", 2, 4)
	var front_attacker := _unit(game, "enemy", "dongzhuo", 0, 4)
	var ren_before := float(ren.hp)
	game._damage(rear_attacker, ren, 1000.0, "physical", "rear")
	assert(is_equal_approx(ren_before - float(ren.hp), 600.0))
	var dun_before := float(dun.hp)
	game._damage(front_attacker, dun, 1000.0, "physical", "front")
	assert(is_equal_approx(dun_before - float(dun.hp), 600.0))

	# Full four-strategist network: 5 targets at the fully stacked values.
	var sima := _unit(game, "player", "simayi", 2, 0)
	var guo := _unit(game, "player", "guojia", 2, 1)
	var xun := _unit(game, "player", "xunyu", 2, 2)
	var jia := _unit(game, "player", "jiaxu", 2, 3)
	var targets := _enemies(game, 5)
	_set_combat(game, [sima, guo, xun, jia], targets)
	assert(game._unit_skill_cooldown(guo) < float(game.heroes.guojia.cooldown))
	assert(game._unit_skill_cooldown(xun) < float(game.heroes.xunyu.cooldown))
	var hp_before := targets.map(func(target): return float(target.hp))
	game._cast_simayi_skill(sima)
	for index in targets.size():
		assert(is_equal_approx(hp_before[index] - float(targets[index].hp), float(game.heroes.simayi.skill_value) * 2.50))

	game._cast_guojia_skill(guo)
	assert(targets.all(func(target): return is_equal_approx(float(target.freeze), float(game.heroes.guojia.ability_params.freeze))))
	var frozen: Dictionary = targets[0]
	var freeze_remaining := float(frozen.freeze)
	var frozen_hp_before := float(frozen.hp)
	game._damage(sima, frozen, 100.0, "magic", "shatter")
	assert(is_equal_approx(float(frozen.freeze), 0.0))
	assert(is_equal_approx(frozen_hp_before - float(frozen.hp), 100.0 + freeze_remaining * float(game.heroes.guojia.ability_params.shatter_per_second)))

	game._cast_xunyu_skill(xun)
	assert([sima, guo, xun, jia].all(func(ally): return is_equal_approx(float(ally.timed_action_bonus), 0.20)))
	assert(is_equal_approx(game._unit_action_gain_multiplier(xun), 1.20))

	for target in targets:
		target.freeze = 0.0
		target.hp = target.max_hp
	game._cast_jiaxu_skill(jia)
	assert(targets.all(func(target): return is_equal_approx(float(target.poison), 6.5)))
	var poison_before := float(targets[0].hp)
	game._process_statuses(1.0)
	assert(is_equal_approx(poison_before - float(targets[0].hp), float(targets[0].max_hp) * float(game.heroes.jiaxu.ability_params.poison_ratio)))

	var graph: Dictionary = game._bond_graph_data("wei")
	var bond_ids: Array = graph.bonds.map(func(bond): return str(bond[0]))
	for bond_id in ["swift_bulwark", "xiahou_brothers", "twin_bulwarks", "thunder_frost", "thunder_royal", "thunder_venom", "frost_royal", "frost_venom", "royal_venom"]:
		assert(bond_ids.has(bond_id))
	assert(graph.bonds.any(func(bond): return Array(bond[3]).has("jiaxu")))
	assert(game._skill_detail("jiaxu").contains("1%"))
	quit()
