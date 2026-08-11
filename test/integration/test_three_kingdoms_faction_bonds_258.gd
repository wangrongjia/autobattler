extends SceneTree

const SHU_IDS := ["liubei", "guanyu", "zhangfei", "zhaoyun", "huangzhong", "machao", "liushan", "zhugeliang"]
const WEI_IDS := ["caocao", "dianwei", "xuchu", "zhangliao", "yuejin", "zhanghe", "xuhuang", "yujin"]
const WU_IDS := ["zhouyu", "luxun", "lusu", "lvmeng", "sunjian", "sunce", "sunquan", "sunshangxiang"]
const QUN_IDS := ["lvbu", "diaochan", "dongzhuo", "gaoshun", "chengong", "yanliang", "wenchou", "qunzhanghe"]

func _team(game, ids: Array, team: String) -> Array:
	var result: Array = []
	for index in ids.size():
		var unit: Dictionary = game._make_roster_unit(team, str(ids[index]))
		unit.row = index % game.BOARD_ROWS
		unit.col = index % game.BOARD_COLUMNS
		result.append(unit)
	return result

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()

	# Legacy level fields no longer change Ma Dai's empty-tile ruler damage.
	for level in [1, 2, 3]:
		var madai: Dictionary = game._make_roster_unit("player", "madai")
		madai.row = 2
		madai.col = 0
		madai.level = level
		madai.stat_mult = game._star_stat_multiplier(level)
		var rear_enemy: Dictionary = game._make_roster_unit("enemy", "caocao")
		rear_enemy.row = 2
		rear_enemy.col = 0
		game.combat_units = [madai, rear_enemy]
		game.enemy_ruler_hp = game.RULER_MAX_HP
		game.visual_events.clear()
		game._cast_madai_execution(madai)
		assert(game.RULER_MAX_HP - game.enemy_ruler_hp == 1000)
		assert(game.visual_events.any(func(event): return event.kind == "empty" and int(event.row) == 0))

	# Shu: 8% base reduction, then +2% per damage instance up to 14%;
	# burn ticks count, and casting clears only the extra stacks.
	var shu_team := _team(game, SHU_IDS, "player")
	var shu_enemy: Dictionary = game._make_roster_unit("enemy", "caocao")
	shu_enemy.row = 0
	shu_enemy.col = 4
	game.combat_units = shu_team + [shu_enemy]
	game._reset_faction_battle_state()
	game._apply_faction_bonuses(false)
	var shu_target: Dictionary = shu_team[0]
	shu_target.max_hp = 100000.0
	shu_target.hp = 100000.0
	for index in 4:
		var before := float(shu_target.hp)
		game._damage(null, shu_target, 1000.0, "magic", "faction test")
		assert(is_equal_approx(before - float(shu_target.hp), [920.0, 900.0, 880.0, 860.0][index]))
		assert(int(shu_target.shu_damage_stacks) == mini(3, index + 1))
	shu_target.shu_damage_stacks = 0
	shu_target.burn = 2.0
	shu_target.burn_damage = 100.0
	shu_target.burn_clock = 0.0
	game._process_statuses(1.0)
	assert(int(shu_target.shu_damage_stacks) == 1)
	shu_target.shu_damage_stacks = 3
	game._perform_action(shu_target)
	assert(int(shu_target.shu_damage_stacks) == 0)

	# Wu: max HP increases by 8%. The first lethal hit equalizes current
	# health ratios and heals 10%; the second lethal hit is not prevented.
	var wu_team := _team(game, WU_IDS, "player")
	var wu_enemy: Dictionary = game._make_roster_unit("enemy", "caocao")
	wu_enemy.row = 0
	wu_enemy.col = 4
	game.combat_units = wu_team + [wu_enemy]
	game._reset_faction_battle_state()
	var wu_base_max := float(wu_team[0].max_hp)
	game._apply_faction_bonuses(false)
	assert(is_equal_approx(float(wu_team[0].max_hp), wu_base_max * 1.08))
	for ally in wu_team:
		ally.hp = float(ally.max_hp) * 0.50
	var wu_target: Dictionary = wu_team[0]
	wu_target.hp = 1.0
	game._damage(wu_enemy, wu_target, 1000000.0, "physical", "first lethal")
	assert(wu_target.alive)
	assert(float(wu_target.hp) > 0.0)
	assert(bool(game.faction_battle_state.player.wu_equalize_used))
	wu_target.hp = 1.0
	game._damage(wu_enemy, wu_target, 1000000.0, "physical", "second lethal")
	assert(not wu_target.alive)

	# Wei: control duration gains 15%, and all debuffs qualify the target for
	# the 15% damage bonus at eight members.
	var wei_team := _team(game, WEI_IDS, "player")
	var wei_target: Dictionary = game._make_roster_unit("enemy", "liubei")
	wei_target.row = 0
	wei_target.col = 4
	wei_target.max_hp = 100000.0
	wei_target.hp = 100000.0
	game.combat_units = wei_team + [wei_target]
	game._reset_faction_battle_state()
	game._apply_faction_bonuses(false)
	var wei_source: Dictionary = wei_team[0]
	assert(is_equal_approx(game._control_duration_multiplier(wei_source), 1.15))
	wei_target.slow = 0.20
	wei_target.slow_time = 3.0
	var wei_before := float(wei_target.hp)
	game._damage(wei_source, wei_target, 100.0 / float(wei_source.stat_mult), "physical", "debuff bonus")
	assert(is_equal_approx(wei_before - float(wei_target.hp), 115.0))

	# Qun: the action gain multiplier makes the actual cooldown 15% shorter.
	var qun_team := _team(game, QUN_IDS, "player")
	var qun_enemy: Dictionary = game._make_roster_unit("enemy", "liubei")
	qun_enemy.row = 0
	qun_enemy.col = 4
	game.combat_units = qun_team + [qun_enemy]
	game._reset_faction_battle_state()
	game._apply_faction_bonuses(false)
	assert(is_equal_approx(game._unit_action_gain_multiplier(qun_team[0]), 1.0 / 0.85))
	var double_cast_triggered := false
	for _attempt in 100:
		game.visual_events.clear()
		game._perform_action(qun_team[4])
		var charge_events: Array = game.visual_events.filter(func(event): return event.kind == "charge")
		if charge_events.size() >= 2:
			double_cast_triggered = true
			break
	assert(double_cast_triggered)

	quit()
