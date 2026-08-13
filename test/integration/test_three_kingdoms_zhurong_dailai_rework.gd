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
	game.ground_effects.clear()
	game.enemy_ruler_hp = game.RULER_MAX_HP
	game.player_ruler_hp = game.RULER_MAX_HP

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()

	# 注册值和图鉴文本完全采用最新文档。
	assert(int(game.heroes.zhurong.hp) == 3580)
	assert(is_equal_approx(float(game.heroes.zhurong.cooldown), 5.1))
	assert(int(game.heroes.zhurong.range) == 3)
	assert(int(game.heroes.zhurong.skill_value) == 100)
	assert(int(game.heroes.dailaidongzhu.hp) == 4610)
	assert(is_equal_approx(float(game.heroes.dailaidongzhu.cooldown), 4.9))
	assert(int(game.heroes.dailaidongzhu.range) == 2)
	assert(int(game.heroes.dailaidongzhu.skill_value) == 100)
	assert(game._skill_detail("zhurong").contains("300%兵略值"))
	assert(game._skill_detail("zhurong").contains("每秒70%兵略值"))
	assert(game._skill_detail("dailaidongzhu").contains("490%兵略值"))
	assert(not game._skill_detail("dailaidongzhu").contains("压退"))
	assert(game._hero_bond_detail("zhurong").contains("50%兵略值"))
	assert(game._hero_bond_detail("zhurong").contains("每秒100%兵略值"))
	assert(game._hero_bond_detail("dailaidongzhu").contains("320%兵略值"))
	assert(game._hero_bond_detail("dailaidongzhu").contains("额外增加50%兵略值"))

	# 祝融无羁绊：随机敌军受到300点直接伤害，附加3秒、每秒70点灼烧。
	var zhurong := _place(game, "player", "zhurong", 2, 0)
	var zhurong_target := _place(game, "enemy", "zhouyu", 2, 2)
	zhurong_target.max_hp = 1000000.0
	zhurong_target.hp = zhurong_target.max_hp
	_set_combat(game, [zhurong], [zhurong_target])
	game._cast_zhurong_skill(zhurong)
	assert(is_equal_approx(1000000.0 - float(zhurong_target.hp), 300.0))
	assert(is_equal_approx(float(zhurong_target.burn), 3.0))
	assert(is_equal_approx(float(zhurong_target.burn_damage), 70.0))

	# 带来洞主无羁绊：只攻击行动条最高者490点，不再压退行动条。
	var dailai := _place(game, "player", "dailaidongzhu", 1, 0)
	var low_action := _place(game, "enemy", "zhouyu", 0, 1)
	var high_action := _place(game, "enemy", "luxun", 1, 3)
	for target in [low_action, high_action]:
		target.max_hp = 1000000.0
		target.hp = target.max_hp
	low_action.action = 30.0
	high_action.action = 90.0
	_set_combat(game, [dailai], [low_action, high_action])
	game._cast_dailai_skill(dailai)
	assert(is_equal_approx(float(low_action.hp), 1000000.0))
	assert(is_equal_approx(1000000.0 - float(high_action.hp), 490.0))
	assert(is_equal_approx(float(high_action.action), 90.0))

	# 孟获+祝融：攻击最高行动条目标所在整列，每格320；已灼烧目标额外50。
	dailai = _place(game, "player", "dailaidongzhu", 1, 0)
	var allies: Array = [dailai, _place(game, "player", "menghuo", 0, 1), _place(game, "player", "zhurong", 2, 1)]
	var column_targets: Array = []
	for row in game.BOARD_ROWS:
		var target := _place(game, "enemy", "zhouyu", row, 2)
		target.max_hp = 1000000.0
		target.hp = target.max_hp
		target.action = 95.0 if row == 1 else 20.0
		column_targets.append(target)
	column_targets[0].burn = 2.0
	_set_combat(game, allies, column_targets)
	game._cast_dailai_skill(dailai)
	assert(is_equal_approx(1000000.0 - float(column_targets[0].hp), 370.0))
	assert(is_equal_approx(1000000.0 - float(column_targets[1].hp), 320.0))
	assert(is_equal_approx(1000000.0 - float(column_targets[2].hp), 320.0))
	for target in column_targets:
		assert(is_equal_approx(float(target.burn), 4.0))
		assert(is_equal_approx(float(target.burn_damage), 50.0))

	print("zhurong_dailai_rework:ok")
	quit()
