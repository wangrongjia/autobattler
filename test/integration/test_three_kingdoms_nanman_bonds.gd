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

func _seed_for_tile(game, source: Dictionary, wanted_row: int, wanted_col: int) -> int:
	for seed in range(10000):
		game.rng.seed = seed
		var tile: Dictionary = game._random_enemy_tile(source)
		if int(tile.row) == wanted_row and int(tile.col) == wanted_col:
			return seed
	assert(false, "Could not find deterministic RNG seed for requested tile")
	return -1

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()

	# 北伐传承：姜维获得30%减伤，并向主目标两个斜角各补一次80%伤害。
	var jiangwei := _place(game, "player", "jiangwei", 0, 0)
	var zhugeliang_for_jiang := _place(game, "player", "zhugeliang", 2, 4)
	var jiang_main := _place(game, "enemy", "zhouyu", 0, 2)
	var jiang_diagonal_left := _place(game, "enemy", "zhouyu", 1, 1)
	var jiang_diagonal_right := _place(game, "enemy", "zhouyu", 1, 3)
	var jiang_enemies: Array = [jiang_main, jiang_diagonal_left, jiang_diagonal_right]
	for target in jiang_enemies:
		target.max_hp = 1000000.0
		target.hp = target.max_hp
	_set_combat(game, [jiangwei, zhugeliang_for_jiang], jiang_enemies)
	var seed := _seed_for_tile(game, jiangwei, 0, 2)
	game.rng.seed = seed
	game._cast_jiangwei_skill(jiangwei)
	var jiang_params: Dictionary = game.heroes.jiangwei.ability_params
	assert(is_equal_approx(float(jiangwei.timed_reduction), 0.0))
	assert(is_equal_approx(float(jiangwei.timed_reduction_time), 0.0))
	assert(is_equal_approx(1000000.0 - float(jiang_main.hp), float(game.heroes.jiangwei.skill_value) * float(jiang_params.mult)))
	var expected_diagonal := float(game.heroes.jiangwei.skill_value) * float(jiang_params.bond_splash_mult)
	assert(is_equal_approx(1000000.0 - float(jiang_diagonal_left.hp), expected_diagonal))
	assert(is_equal_approx(1000000.0 - float(jiang_diagonal_right.hp), expected_diagonal))

	# 卧龙凤雏：庞统的连环计同时命中横向三格，均为100%伤害和2.5秒锁条。
	var pangtong := _place(game, "player", "pangtong", 2, 0)
	var zhugeliang_for_pang := _place(game, "player", "zhugeliang", 2, 4)
	var pang_targets: Array = []
	for col in range(1, 4):
		var target := _place(game, "enemy", "zhouyu", 1, col)
		target.max_hp = 1000000.0
		target.hp = target.max_hp
		pang_targets.append(target)
	_set_combat(game, [pangtong, zhugeliang_for_pang], pang_targets)
	seed = _seed_for_tile(game, pangtong, 1, 2)
	game.rng.seed = seed
	game._cast_pangtong_skill(pangtong)
	var pang_params: Dictionary = game.heroes.pangtong.ability_params
	for target in pang_targets:
		assert(is_equal_approx(1000000.0 - float(target.hp), float(game.heroes.pangtong.skill_value) * float(pang_params.mult)))
		assert(is_equal_approx(float(target.stun), 0.0))
		assert(target.chain_effects.size() == 1)
		assert(is_equal_approx(float(target.chain_effects[0].ratio), float(pang_params.bond_link_ratio)))
	var pang_damage_events: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	assert(pang_damage_events.size() == 3)
	assert(pang_damage_events.all(func(event): return event.get("group_style", "") == "area_impact"))

	# 孟获完全羁绊：灼烧目标增伤和延长眩晕，追加整排余震，并压退行动条。
	var menghuo := _place(game, "player", "menghuo", 0, 0)
	var meng_allies: Array = [
		menghuo,
		_place(game, "player", "zhugeliang", 2, 1),
		_place(game, "player", "zhurong", 2, 2),
		_place(game, "player", "dailaidongzhu", 1, 3),
	]
	var meng_targets: Array = []
	for col in game.BOARD_COLUMNS:
		var target := _place(game, "enemy", "zhouyu", 0, col)
		target.max_hp = 1000000.0
		target.hp = target.max_hp
		target.burn = 10.0
		target.action = 80.0
		meng_targets.append(target)
	_set_combat(game, meng_allies, meng_targets)
	game._cast_menghuo_skill(menghuo)
	var meng_params: Dictionary = game.heroes.menghuo.ability_params
	var expected_meng_damage := float(game.heroes.menghuo.skill_value) * float(meng_params.mult) * float(meng_params.burning_damage_mult)
	expected_meng_damage += float(game.heroes.menghuo.skill_value) * float(meng_params.aftershock_mult)
	for target in meng_targets:
		assert(is_equal_approx(1000000.0 - float(target.hp), expected_meng_damage))
		assert(is_equal_approx(float(target.stun), game._scaled_control_duration(menghuo, float(meng_params.burning_stun), true)))
		assert(is_equal_approx(float(target.action), 80.0 - float(meng_params.bond_action_reduction)))
	var meng_damage_events: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	assert(meng_damage_events.size() == 10)
	var meng_visual_groups := {}
	for event in meng_damage_events:
		meng_visual_groups[str(event.visual_group)] = true
	assert(meng_visual_groups.size() == 2)

	# 南蛮夫妇 + 姐弟同心：祝融主目标300%，左右各50%，三格获得5秒、每秒100%的强化灼烧。
	var zhurong := _place(game, "player", "zhurong", 2, 0)
	var zhurong_allies: Array = [
		zhurong,
		_place(game, "player", "menghuo", 0, 1),
		_place(game, "player", "dailaidongzhu", 1, 2),
	]
	var zhurong_targets: Array = []
	for col in range(1, 4):
		var target := _place(game, "enemy", "zhouyu", 1, col)
		target.max_hp = 1000000.0
		target.hp = target.max_hp
		zhurong_targets.append(target)
	_set_combat(game, zhurong_allies, zhurong_targets)
	# 三个候选按列顺序排列，选择索引1作为主目标。
	for target_seed in range(10000):
		game.rng.seed = target_seed
		if game.rng.randi_range(0, 2) == 1:
			seed = target_seed
			break
	game.rng.seed = seed
	game._cast_zhurong_skill(zhurong)
	var zhurong_params: Dictionary = game.heroes.zhurong.ability_params
	assert(is_equal_approx(1000000.0 - float(zhurong_targets[1].hp), float(game.heroes.zhurong.skill_value) * float(zhurong_params.mult)))
	for index in [0, 2]:
		assert(is_equal_approx(1000000.0 - float(zhurong_targets[index].hp), float(game.heroes.zhurong.skill_value) * float(zhurong_params.bounce_mult)))
	for target in zhurong_targets:
		assert(is_equal_approx(float(target.burn), float(zhurong_params.burn) + float(zhurong_params.sibling_burn_bonus)))
		assert(is_equal_approx(float(target.burn_damage), float(game.heroes.zhurong.skill_value) * float(zhurong_params.sibling_burn_ratio)))

	# 蛮王援军 + 姐弟同心：带来洞主以320%攻击整列，已灼烧目标额外增加50%兵略值。
	var dailai := _place(game, "player", "dailaidongzhu", 0, 0)
	var dailai_allies: Array = [
		dailai,
		_place(game, "player", "menghuo", 0, 1),
		_place(game, "player", "zhurong", 2, 2),
	]
	var dailai_targets: Array = []
	for row in game.BOARD_ROWS:
		var target := _place(game, "enemy", "zhouyu", row, 2)
		target.max_hp = 1000000.0
		target.hp = target.max_hp
		target.burn = 2.0
		target.action = 90.0 if row == 1 else 50.0
		dailai_targets.append(target)
	_set_combat(game, dailai_allies, dailai_targets)
	game._cast_dailai_skill(dailai)
	var dailai_params: Dictionary = game.heroes.dailaidongzhu.ability_params
	var expected_column := float(game.heroes.dailaidongzhu.skill_value) * (float(dailai_params.column_mult) + float(dailai_params.burning_bonus_mult))
	for target in dailai_targets:
		assert(is_equal_approx(1000000.0 - float(target.hp), expected_column))
	assert(is_equal_approx(float(dailai_targets[1].action), 90.0))
	assert(is_equal_approx(float(dailai_targets[0].action), 50.0))
	assert(is_equal_approx(float(dailai_targets[2].action), 50.0))
	for target in dailai_targets:
		assert(is_equal_approx(float(target.burn), float(dailai_params.bond_burn)))
		assert(is_equal_approx(float(target.burn_damage), float(game.heroes.dailaidongzhu.skill_value) * float(dailai_params.bond_burn_ratio)))

	quit()
