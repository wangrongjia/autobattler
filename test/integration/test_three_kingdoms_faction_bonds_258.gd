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

	# Legacy level fields no longer change Ma Dai's empty-tile ruler damage:
	# with the target row kept empty every cast lands on an empty tile and
	# deals empty_ruler_strategy_mult x Strategy ruler damage at any level.
	var madai_damages: Array = []
	for level in [1, 2, 3]:
		var madai: Dictionary = game._make_roster_unit("player", "madai")
		madai.row = 2
		madai.col = 0
		madai.level = level
		madai.stat_mult = game._star_stat_multiplier(level)
		game.combat_units = [madai]
		game.enemy_ruler_hp = game.RULER_MAX_HP
		game.visual_events.clear()
		game._cast_madai_execution(madai)
		var madai_expected: int = int(round(game._unit_skill_stat_value(madai) * float(game.heroes.madai.ability_params.empty_ruler_strategy_mult)))
		assert(game.RULER_MAX_HP - game.enemy_ruler_hp == madai_expected)
		madai_damages.append(madai_expected)
		assert(game.visual_events.any(func(event): return event.kind == "empty" and int(event.row) == 2))
	assert(madai_damages.all(func(damage): return damage == madai_damages[0]))

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
		assert(is_equal_approx(before - float(shu_target.hp), [920.0, 890.0, 860.0, 830.0][index]))
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
	# health ratios and heals 3% (5%/6% with 同舟共济 talent levels); healing
	# is unattributed, all allies recover in one simultaneous visual group and
	# the trigger is limited to once per round. A second lethal hit in the
	# same round is not prevented.
	var wu_team := _team(game, WU_IDS, "player")
	var wu_enemy: Dictionary = game._make_roster_unit("enemy", "caocao")
	wu_enemy.row = 0
	wu_enemy.col = 4
	game.combat_units = wu_team + [wu_enemy]
	game.battle_stats = {}
	for unit in game.combat_units:
		game.battle_stats[unit.id] = {"unit_id":unit.id, "hero_id":unit.hero_id, "team":unit.team, "level":1, "damage":0.0, "healing":0.0, "taken":0.0, "control":0.0}
	game._reset_faction_battle_state()
	var wu_base_max := float(wu_team[0].max_hp)
	game._apply_faction_bonuses(false)
	assert(is_equal_approx(float(wu_team[0].max_hp), wu_base_max * 1.08))
	for ally in wu_team:
		ally.max_hp = 100000.0
		ally.hp = 50000.0
	var wu_target: Dictionary = wu_team[0]
	wu_target.hp = 1.0
	game.visual_events.clear()
	game._damage(wu_enemy, wu_target, 1000000.0, "physical", "first lethal")
	assert(wu_target.alive)
	assert(float(wu_target.hp) > 0.0)
	assert(bool(game.faction_battle_state.player.wu_equalize_used))
	# 均摊比例 = 7 名半血吴将 / 8 人总上限；随后每人 +3% 上限生命。
	var wu_shared := 7.0 * 50000.0 / 800000.0
	for ally in wu_team:
		assert(absf(float(ally.hp) - 100000.0 * (wu_shared + 0.03)) < 0.01)
		assert(float(game.battle_stats[ally.id].healing) == 0.0) # 羁绊回复无归属
	var wu_banner: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "faction_bond")
	assert(wu_banner.size() == 1 and str(wu_banner[0].title).contains("江东联动"))
	var wu_heal_events: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "heal")
	assert(wu_heal_events.size() == 8)
	assert(wu_heal_events.all(func(event): return str(event.visual_group) == "wu_bond_player_" + wu_target.id and str(event.group_style) == "simultaneous"))
	# 天赋「同舟共济」：1级 +2%、2级 +3%。
	for wu_talent_setup in [[1, 0.05], [2, 0.06]]:
		game.talent_levels["wu:同舟共济"] = int(wu_talent_setup[0])
		game._reset_faction_battle_state()
		for ally in wu_team:
			ally.hp = 50000.0
		wu_target.hp = 1.0
		game._damage(wu_enemy, wu_target, 1000000.0, "physical", "talent lethal")
		assert(wu_target.alive)
		for ally in wu_team:
			assert(absf(float(ally.hp) - 100000.0 * (wu_shared + float(wu_talent_setup[1]))) < 0.01)
	game.talent_levels.erase("wu:同舟共济")
	wu_target.hp = 1.0
	game._damage(wu_enemy, wu_target, 1000000.0, "physical", "second lethal")
	assert(not wu_target.alive)

	# Wei: control duration gains 8%, and all debuffs qualify the target for
	# the 8% damage bonus at eight members.
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
	assert(is_equal_approx(game._control_duration_multiplier(wei_source), 1.08))
	wei_target.slow = 0.20
	wei_target.slow_time = 3.0
	var wei_before := float(wei_target.hp)
	game._damage(wei_source, wei_target, 100.0 / float(wei_source.stat_mult), "physical", "debuff bonus")
	assert(is_equal_approx(wei_before - float(wei_target.hp), 108.0))

	# Qun: the action gain multiplier makes the actual cooldown 8% shorter.
	var qun_team := _team(game, QUN_IDS, "player")
	var qun_enemy: Dictionary = game._make_roster_unit("enemy", "liubei")
	qun_enemy.row = 0
	qun_enemy.col = 4
	game.combat_units = qun_team + [qun_enemy]
	game._reset_faction_battle_state()
	game._apply_faction_bonuses(false)
	var qun_reduction := clampf(float(qun_team[0].get("faction_cooldown_reduction", 0.0)), 0.0, 0.95)
	assert(qun_reduction > 0.0)
	assert(is_equal_approx(game._unit_action_gain_multiplier(qun_team[0]), 1.0 / (1.0 - qun_reduction)))
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
