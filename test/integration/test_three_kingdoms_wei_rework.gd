extends SceneTree

func _unit(game, team: String, hero_id: String, row: int, col: int) -> Dictionary:
	var unit: Dictionary = game._make_roster_unit(team, hero_id)
	unit.row = row
	unit.col = col
	game._ensure_unit_fields(unit)
	return unit

func _set_combat(game, players: Array, enemies: Array) -> void:
	game.player_units = players
	game.enemy_units = enemies
	game.combat_units = players + enemies
	game._apply_combo_bonds(false, false)

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()

	for hero_id in ["caocao", "dianwei", "xuchu", "zhangliao", "yuejin", "xuhuang", "zhanghe", "yujin"]:
		assert(float(game.heroes[hero_id].cooldown) > 0.0)
	assert(int(game.heroes.caocao.hp) == 5470)
	assert(is_equal_approx(float(game.heroes.caocao.cooldown), 5.6))
	assert(is_equal_approx(float(game.heroes.caocao.ability_params.mult), 1.5))
	assert(is_equal_approx(float(game.heroes.caocao.ability_params.stun), 1.25))
	assert(int(game.heroes.dianwei.hp) == 5260)
	assert(is_equal_approx(float(game.heroes.dianwei.cooldown), 5.2))
	assert(is_equal_approx(float(game.heroes.dianwei.ability_params.mult), 2.4))
	assert(int(game.heroes.xuchu.hp) == 5040)
	assert(is_equal_approx(float(game.heroes.xuchu.cooldown), 6.4))
	assert(is_equal_approx(float(game.heroes.xuchu.ability_params.mult), 3.2))
	assert("150%兵略值" in game._skill_detail("caocao") and "1.25秒" in game._skill_detail("caocao"))
	assert("240%兵略值" in game._skill_detail("dianwei"))
	assert("320%兵略值" in game._skill_detail("xuchu"))
	assert("伤害减少30%兵略值" in game._hero_bond_detail("dianwei"))
	assert("伤害减少40%兵略值" in game._hero_bond_detail("xuchu"))
	assert("伤害增加100%兵略值" in game._hero_bond_detail("xuchu"))
	var five_expected := {
		"zhangliao":[4180, 6.8, 2], "yuejin":[2660, 6.0, 3], "xuhuang":[5040, 5.6, 1],
		"zhanghe":[4540, 5.2, 1], "yujin":[4970, 4.8, 1]
	}
	for hero_id in five_expected:
		assert(int(game.heroes[hero_id].hp) == int(five_expected[hero_id][0]))
		assert(is_equal_approx(float(game.heroes[hero_id].cooldown), float(five_expected[hero_id][1])))
		assert(int(game.heroes[hero_id].range) == int(five_expected[hero_id][2]))
	assert("110%兵略值" in game._skill_detail("zhangliao"))
	assert("200%兵略值" in game._skill_detail("yuejin"))
	assert("80%兵略值" in game._skill_detail("xuhuang") and "1.5秒" in game._skill_detail("xuhuang"))
	assert("400%兵略值" in game._skill_detail("zhanghe"))
	assert("300%兵略值" in game._skill_detail("yujin"))
	assert("增加40%兵略值" in game._hero_bond_detail("zhangliao"))
	assert("目标增加1名" in game._hero_bond_detail("yuejin"))
	assert("眩晕时长增加1秒" in game._hero_bond_detail("zhanghe"))
	assert("护盾值增加100%兵略值" in game._hero_bond_detail("yujin"))

	# 未激活羁绊时，三人的伤害、目标数和曹操眩晕均严格采用图鉴基础值。
	var base_cao := _unit(game, "player", "caocao", 0, 0)
	var base_cao_targets := [_unit(game, "enemy", "dongzhuo", 0, 0), _unit(game, "enemy", "zhouyu", 2, 0)]
	_set_combat(game, [base_cao], base_cao_targets)
	var base_cao_before := base_cao_targets.map(func(target): return float(target.hp))
	game._cast_caocao_command(base_cao)
	for index in base_cao_targets.size():
		assert(is_equal_approx(base_cao_before[index] - float(base_cao_targets[index].hp), 150.0))
		assert(is_equal_approx(float(base_cao_targets[index].stun), 1.25))
	var base_dian := _unit(game, "player", "dianwei", 0, 0)
	var base_dian_targets := [_unit(game, "enemy", "zhouyu", 2, 0), _unit(game, "enemy", "luxun", 2, 1)]
	_set_combat(game, [base_dian], base_dian_targets)
	var base_dian_before := base_dian_targets.map(func(target): return float(target.hp))
	game._cast_dianwei_skill(base_dian)
	for index in base_dian_targets.size(): assert(is_equal_approx(base_dian_before[index] - float(base_dian_targets[index].hp), 240.0))
	var base_xu := _unit(game, "player", "xuchu", 0, 0)
	var base_xu_targets := [_unit(game, "enemy", "dongzhuo", 0, 0), _unit(game, "enemy", "lvbu", 0, 1)]
	_set_combat(game, [base_xu], base_xu_targets)
	var base_xu_before := base_xu_targets.map(func(target): return float(target.hp))
	game._cast_xuchu_skill(base_xu)
	for index in base_xu_targets.size(): assert(is_equal_approx(base_xu_before[index] - float(base_xu_targets[index].hp), 320.0))

	# 曹操同时拥有两组双人羁绊：四个目标；前后军均为250%伤害、1.75秒眩晕。
	var cao := _unit(game, "player", "caocao", 0, 0)
	var dian := _unit(game, "player", "dianwei", 0, 1)
	var xu := _unit(game, "player", "xuchu", 0, 2)
	var cao_targets: Array = []
	for data in [["dongzhuo", 0, 0], ["lvbu", 0, 1], ["zhouyu", 2, 0], ["luxun", 2, 1]]:
		cao_targets.append(_unit(game, "enemy", data[0], data[1], data[2]))
	_set_combat(game, [cao, dian, xu], cao_targets)
	var cao_hp_before := cao_targets.map(func(target): return float(target.hp))
	game._cast_caocao_command(cao)
	for index in cao_targets.size():
		assert(is_equal_approx(cao_hp_before[index] - float(cao_targets[index].hp), 250.0))
		assert(is_equal_approx(float(cao_targets[index].stun), 1.75))

	# 典韦完全体为240%-30%+80%=290%；许褚为320%-40%+100%=380%。
	var rear_targets: Array = []
	for col in 3: rear_targets.append(_unit(game, "enemy", "zhouyu", 2, col))
	_set_combat(game, [cao, dian, xu], rear_targets)
	var rear_before := rear_targets.map(func(target): return float(target.hp))
	game._cast_dianwei_skill(dian)
	for index in rear_targets.size(): assert(is_equal_approx(rear_before[index] - float(rear_targets[index].hp), 290.0))
	var front_targets: Array = []
	for col in 3: front_targets.append(_unit(game, "enemy", "dongzhuo", 0, col))
	_set_combat(game, [cao, dian, xu], front_targets)
	var front_before := front_targets.map(func(target): return float(target.hp))
	game._cast_xuchu_skill(xu)
	for index in front_targets.size(): assert(is_equal_approx(front_before[index] - float(front_targets[index].hp), 380.0))

	# 五子良将裸技能：张辽每段110%，乐进3人200%，徐晃前排80%+1.5秒控制，
	# 张郃单体400%+1.5秒控制，于禁为生命总量最低者提供300%护盾。
	var base_liao := _unit(game, "player", "zhangliao", 1, 0)
	var base_liao_targets: Array = []
	for row in 3:
		for col in 5: base_liao_targets.append(_unit(game, "enemy", "dongzhuo", row, col))
	_set_combat(game, [base_liao], base_liao_targets)
	var base_liao_before := base_liao_targets.map(func(target): return float(target.hp))
	game.rng.seed = 1
	game._cast_zhangliao_skill(base_liao)
	var base_liao_damaged := []
	for index in base_liao_targets.size():
		if base_liao_before[index] > float(base_liao_targets[index].hp): base_liao_damaged.append(base_liao_targets[index])
	assert(base_liao_damaged.size() == 3)
	assert(base_liao_damaged.all(func(target): return is_equal_approx(float(target.max_hp) - float(target.hp), 220.0)))
	assert(base_liao_damaged.all(func(target): return is_equal_approx(float(target.vulnerable_time), 0.0)))

	var base_yue := _unit(game, "player", "yuejin", 2, 0)
	var base_yue_targets: Array = []
	for col in 4: base_yue_targets.append(_unit(game, "enemy", "dongzhuo", 0, col))
	_set_combat(game, [base_yue], base_yue_targets)
	var base_yue_before := base_yue_targets.map(func(target): return float(target.hp))
	game._cast_yuejin_skill(base_yue)
	var base_yue_hit_count := 0
	for index in base_yue_targets.size():
		if base_yue_before[index] > float(base_yue_targets[index].hp):
			base_yue_hit_count += 1
			assert(is_equal_approx(base_yue_before[index] - float(base_yue_targets[index].hp), 200.0))
	assert(base_yue_hit_count == 3)

	var base_huang := _unit(game, "player", "xuhuang", 0, 0)
	var base_huang_targets: Array = []
	for col in 5: base_huang_targets.append(_unit(game, "enemy", "dongzhuo", 0, col))
	_set_combat(game, [base_huang], base_huang_targets)
	game._cast_xuhuang_skill(base_huang)
	assert(base_huang_targets.all(func(target): return is_equal_approx(float(target.max_hp) - float(target.hp), 80.0) and is_equal_approx(float(target.stun), 1.5)))

	var base_he := _unit(game, "player", "zhanghe", 0, 0)
	var base_he_target := _unit(game, "enemy", "dongzhuo", 0, 0)
	_set_combat(game, [base_he], [base_he_target])
	game._cast_zhanghe_skill(base_he)
	assert(is_equal_approx(float(base_he_target.max_hp) - float(base_he_target.hp), 400.0))
	assert(is_equal_approx(float(base_he_target.stun), 1.5))

	var base_yujin := _unit(game, "player", "yujin", 0, 0)
	var shield_ally := _unit(game, "player", "caocao", 0, 1)
	base_yujin.hp = 500.0
	shield_ally.hp = 100.0
	_set_combat(game, [base_yujin, shield_ally], [])
	game._cast_yujin_skill(base_yujin)
	assert(is_equal_approx(float(shield_ally.shield), 300.0))
	assert(is_equal_approx(float(base_yujin.shield), 0.0))

	var five: Array = []
	for index in 5:
		five.append(_unit(game, "player", ["zhangliao", "yuejin", "zhanghe", "xuhuang", "yujin"][index], index / 3, index % 3))
	assert(not game._five_elites_active("player"))
	_set_combat(game, five, [])
	assert(game._five_elites_active("player"))

	# 张辽完全体每段110%+40%+80%=230%，两段合计460%，并施加5秒40%易损。
	var board_targets: Array = []
	for row in 3:
		for col in 5: board_targets.append(_unit(game, "enemy", "dongzhuo", row, col))
	_set_combat(game, five, board_targets)
	var board_before := board_targets.map(func(target): return float(target.hp))
	game._cast_zhangliao_skill(five[0])
	var liao_hits := board_targets.filter(func(target): return float(target.get("vulnerable_time", 0.0)) > 0.0)
	assert(liao_hits.size() == 3)
	for target in liao_hits:
		var index := board_targets.find(target)
		assert(is_equal_approx(board_before[index] - float(target.hp), 460.0))
		assert(is_equal_approx(float(target.vulnerable), 0.40))
		assert(is_equal_approx(float(target.vulnerable_time), 5.0))

	# 乐进完全体攻击5人、造成250%，并施加5秒50%重伤。
	var yue_targets: Array = []
	for index in 7: yue_targets.append(_unit(game, "enemy", "dongzhuo", index / 5, index % 5))
	_set_combat(game, five, yue_targets)
	var yue_before := yue_targets.map(func(target): return float(target.hp))
	game._cast_yuejin_skill(five[1])
	var grievous_targets := yue_targets.filter(func(target): return float(target.grievous_time) > 0.0)
	assert(grievous_targets.size() == 5)
	for target in grievous_targets:
		var index := yue_targets.find(target)
		assert(is_equal_approx(yue_before[index] - float(target.hp), 250.0))
		assert(is_equal_approx(float(target.grievous), 0.50))
		assert(is_equal_approx(float(target.grievous_time), 5.0))
	var heal_target: Dictionary = grievous_targets[0]
	heal_target.hp -= 500.0
	var heal_before := float(heal_target.hp)
	game._heal_unit_only(five[4], heal_target, 100.0)
	assert(is_equal_approx(float(heal_target.hp) - heal_before, 50.0))

	# 徐晃完全体随机整排、160%伤害、3.5秒眩晕。
	_set_combat(game, five, board_targets)
	for target in board_targets:
		target.hp = target.max_hp
		target.stun = 0.0
		target.vulnerable = 0.0
		target.vulnerable_time = 0.0
	var xu_huang_before := board_targets.map(func(target): return float(target.hp))
	game._cast_xuhuang_skill(five[3])
	var huang_hits := board_targets.filter(func(target): return float(target.stun) > 0.0)
	assert(huang_hits.size() == 5)
	for target in huang_hits:
		var index := board_targets.find(target)
		assert(is_equal_approx(xu_huang_before[index] - float(target.hp), 160.0))
		assert(is_equal_approx(float(target.stun), 3.5))

	# 张郃完全体命中主目标及其周围两个随机相邻敌人；预先眩晕时造成1000%并眩晕2.5秒。
	_set_combat(game, five, board_targets)
	for target in board_targets:
		target.hp = target.max_hp
		target.stun = 0.5
		target.vulnerable = 0.0
		target.vulnerable_time = 0.0
	var zhanghe_before := board_targets.map(func(target): return float(target.hp))
	game._cast_zhanghe_skill(five[2])
	var zhanghe_hits: Array = []
	for index in board_targets.size():
		if zhanghe_before[index] > float(board_targets[index].hp): zhanghe_hits.append(board_targets[index])
	assert(zhanghe_hits.size() == 3)
	for target in zhanghe_hits:
		var index := board_targets.find(target)
		assert(is_equal_approx(zhanghe_before[index] - float(target.hp), 1000.0))
		assert(is_equal_approx(float(target.stun), 2.5))

	# 于禁完全体保护当前生命总量最低的2人，每人获得400%兵略值护盾。
	_set_combat(game, five, [])
	for index in five.size():
		five[index].shield = 0.0
		five[index].hp = 100.0 + index * 100.0
	game._cast_yujin_skill(five[4])
	for index in 2: assert(is_equal_approx(float(five[index].shield), 400.0))
	for index in range(2, 5): assert(is_equal_approx(float(five[index].shield), 0.0))

	var wei_graph: Dictionary = game._bond_graph_data("wei")
	var bond_ids: Array = wei_graph.bonds.map(func(bond): return str(bond[0]))
	for bond_id in ["evil_of_old", "tiger_guard", "twin_wei_guards", "hefei_vanguard", "adaptive_vanguard", "five_elites"]: assert(bond_ids.has(bond_id))
	assert(game._bond_progress_tiers("five_elites", 5) == [5])
	quit()
