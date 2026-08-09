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

	# 曹操同时拥有两组双人羁绊：四个目标，并分别强化前军/后军。
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
		assert(is_equal_approx(cao_hp_before[index] - float(cao_targets[index].hp), float(game.heroes.caocao.skill_value) * 4.0))
		assert(is_equal_approx(float(cao_targets[index].stun), float(game.heroes.caocao.ability_params.stun) * float(game.heroes.caocao.ability_params.favored_row_stun_mult)))

	# 典韦与许褚互相把伤害提高到400%，曹操分别令其目标+1。
	var rear_targets: Array = []
	for col in 3: rear_targets.append(_unit(game, "enemy", "zhouyu", 2, col))
	_set_combat(game, [cao, dian, xu], rear_targets)
	var rear_before := rear_targets.map(func(target): return float(target.hp))
	game._cast_dianwei_skill(dian)
	for index in rear_targets.size(): assert(is_equal_approx(rear_before[index] - float(rear_targets[index].hp), float(game.heroes.dianwei.skill_value) * 4.0))
	var front_targets: Array = []
	for col in 3: front_targets.append(_unit(game, "enemy", "dongzhuo", 0, col))
	_set_combat(game, [cao, dian, xu], front_targets)
	var front_before := front_targets.map(func(target): return float(target.hp))
	game._cast_xuchu_skill(xu)
	for index in front_targets.size(): assert(is_equal_approx(front_before[index] - float(front_targets[index].hp), float(game.heroes.xuchu.skill_value) * 4.0))

	var five: Array = []
	for index in 5:
		five.append(_unit(game, "player", ["zhangliao", "yuejin", "zhanghe", "xuhuang", "yujin"][index], index / 3, index % 3))
	assert(not game._five_elites_active("player"))
	_set_combat(game, five, [])
	assert(game._five_elites_active("player"))

	# 张辽随机一列往返两段，并施加3.5秒40%易损。
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
		assert(is_equal_approx(board_before[index] - float(target.hp), float(game.heroes.zhangliao.skill_value) * 4.0))
		assert(is_equal_approx(float(target.vulnerable), 0.40))
		assert(is_equal_approx(float(target.vulnerable_time), 3.5))

	# 乐进完全体攻击7人并施加60%重伤，治疗仅剩40%。
	var yue_targets: Array = []
	for index in 7: yue_targets.append(_unit(game, "enemy", "dongzhuo", index / 5, index % 5))
	_set_combat(game, five, yue_targets)
	game._cast_yuejin_skill(five[1])
	assert(yue_targets.all(func(target): return is_equal_approx(float(target.grievous), float(game.heroes.yuejin.ability_params.five_grievous)) and is_equal_approx(float(target.grievous_time), float(game.heroes.yuejin.ability_params.five_grievous_time))))
	var heal_target: Dictionary = yue_targets[0]
	heal_target.hp -= 500.0
	var heal_before := float(heal_target.hp)
	game._heal_unit_only(five[4], heal_target, 100.0)
	assert(is_equal_approx(float(heal_target.hp) - heal_before, 100.0 * (1.0 - float(game.heroes.yuejin.ability_params.five_grievous))))

	# 徐晃完全体随机整排、300%伤害、5秒眩晕。
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
		assert(is_equal_approx(xu_huang_before[index] - float(target.hp), float(game.heroes.xuhuang.skill_value) * 3.0))
		assert(is_equal_approx(float(target.stun), float(game.heroes.xuhuang.ability_params.five_stun)))

	# 张郃完全体从前军向中军、后军连锁；预先眩晕时造成500%。
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
	assert(zhanghe_hits.size() == 4)
	for target in zhanghe_hits:
		var index := board_targets.find(target)
		assert(is_equal_approx(zhanghe_before[index] - float(target.hp), float(game.heroes.zhanghe.skill_value) * float(game.heroes.zhanghe.ability_params.five_stunned_mult)))

	# 于禁完全体保护当前生命总量最低的3人。
	_set_combat(game, five, [])
	for index in five.size():
		five[index].shield = 0.0
		five[index].hp = 100.0 + index * 100.0
	game._cast_yujin_skill(five[4])
	for index in 3: assert(is_equal_approx(float(five[index].shield), 300.0 + float(five[index].max_hp) * 0.05))
	for index in range(3, 5): assert(is_equal_approx(float(five[index].shield), 0.0))

	var wei_graph: Dictionary = game._bond_graph_data("wei")
	var bond_ids: Array = wei_graph.bonds.map(func(bond): return str(bond[0]))
	for bond_id in ["evil_of_old", "tiger_guard", "twin_wei_guards", "hefei_vanguard", "adaptive_vanguard", "five_elites"]: assert(bond_ids.has(bond_id))
	assert(game._bond_progress_tiers("five_elites", 5) == [5])
	quit()
