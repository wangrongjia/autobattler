extends SceneTree

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()
	game.player_units.clear()
	game.enemy_units.clear()
	var peach_ids := ["liubei", "guanyu", "zhangfei"]
	for i in peach_ids.size():
		var unit: Dictionary = game._make_roster_unit("player", peach_ids[i])
		unit.row = i
		unit.col = 0
		game.player_units.append(unit)
	var enemy: Dictionary = game._make_roster_unit("enemy", "dongzhuo")
	enemy.row = 0
	enemy.col = 0
	game.enemy_units.append(enemy)
	game.combat_units = game.player_units + game.enemy_units
	game._apply_combo_bonds()
	var liubei: Dictionary = game.player_units[0]
	var guanyu: Dictionary = game.player_units[1]
	var zhangfei: Dictionary = game.player_units[2]
	assert(liubei.max_hp == float(game.heroes.liubei.hp))
	assert(not liubei.has("physical_immunity"))
	assert(liubei.heal_multiplier == 1.0)
	assert(liubei.heal_extra_targets == 0)
	assert(not guanyu.has("cleave_lifesteal"))
	assert(not zhangfei.has("shield_multiplier"))
	var hp_after_first_activation: float = liubei.max_hp
	game._apply_combo_bonds()
	assert(liubei.max_hp == hp_after_first_activation)
	assert(liubei.damage_reduction == 0.0)
	liubei.action = 0.0
	game.battle_running = true
	game.battle_time = 0.0
	game._battle_tick()
	assert(liubei.action > 0.0)
	var action_before_stun: float = liubei.action
	liubei.stun = 1.0
	game._battle_tick()
	assert(liubei.action == action_before_stun)
	assert(float(game.heroes.liubei.hp) >= 1000.0)
	var wei := _build_team(game, ["caocao", "dianwei", "xuchu"])
	game.combat_units = wei
	game._apply_combo_bonds()
	assert(wei[1].damage_reduction == 0.0)
	assert(not wei[0].has("counter_chance") or float(wei[0].counter_chance) == 0.0)
	assert(not wei[1].has("guard_link") or not bool(wei[1].guard_link))
	assert(not wei[2].has("guard_link") or not bool(wei[2].guard_link))
	var wu := _build_team(game, ["zhouyu", "luxun", "lusu", "lvmeng"])
	game.combat_units = wu
	game._apply_combo_bonds()
	assert(wu[0].action_gain_mult == 1.0)
	assert(wu.all(func(unit): return bool(unit.four_heroes)))
	assert(int(game.heroes.zhouyu.ability_params.tile_count) + int(game.heroes.zhouyu.ability_params.four_heroes_bonus_tiles) == 4)
	assert(int(game.heroes.luxun.ability_params.four_heroes_bounces) == 3)
	var qun := _build_team(game, ["lvbu", "diaochan", "dongzhuo"])
	game.combat_units = qun
	game._apply_combo_bonds()
	assert(not qun[0].ghost_bond)
	assert(qun[1].charm_multiplier == 1.0)
	assert(is_equal_approx(float(qun[2].max_hp), float(game.heroes.dongzhuo.hp) * 1.50))
	var dongzhuo_bond_hp := float(qun[2].max_hp)
	game._apply_combo_bonds()
	assert(is_equal_approx(float(qun[2].max_hp), dongzhuo_bond_hp))

	# Five Tigers accelerates every allied vanguard/midguard by 15%.
	var five_tigers := _build_team(game, ["guanyu", "zhangfei", "zhaoyun", "huangzhong", "machao"])
	var rear_support: Dictionary = game._make_roster_unit("player", "liubei")
	rear_support.row = 2
	rear_support.col = 3
	five_tigers.append(rear_support)
	game.combat_units = five_tigers
	game._apply_combo_bonds(true, false)
	for tiger in five_tigers:
		var expected := 1.15 if int(game.heroes[tiger.hero_id].range) <= 2 else 1.0
		assert(is_equal_approx(game._unit_action_gain_multiplier(tiger), expected))

	# Guan Yu starts at 180%; Five Tigers changes the cleave to 300%.
	var guanyu_targets: Array = []
	for row in game.BOARD_ROWS:
		for col in game.BOARD_COLUMNS:
			var guanyu_target: Dictionary = game._make_roster_unit("enemy", "caocao")
			guanyu_target.row = row
			guanyu_target.col = col
			guanyu_target.max_hp = 100000.0
			guanyu_target.hp = guanyu_target.max_hp
			guanyu_targets.append(guanyu_target)
	var base_guanyu: Dictionary = game._make_roster_unit("player", "guanyu")
	base_guanyu.row = 0
	base_guanyu.col = 0
	game.combat_units = [base_guanyu] + guanyu_targets
	game.visual_events.clear()
	game._cast_guanyu_skill(base_guanyu)
	var base_guanyu_hits: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	assert(base_guanyu_hits.size() == game.BOARD_ROWS)
	assert(base_guanyu_hits.all(func(event): return int(event.amount) == roundi(game._unit_skill_output_base(base_guanyu) * 1.80)))

	var five_only_team := _build_team(game, ["guanyu", "zhangfei", "zhaoyun", "huangzhong", "machao"])
	var five_guanyu: Dictionary = five_only_team.filter(func(unit): return unit.hero_id == "guanyu")[0]
	game.combat_units = five_only_team + guanyu_targets
	game.visual_events.clear()
	game._cast_guanyu_skill(five_guanyu)
	var five_guanyu_hits: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	assert(five_guanyu_hits.size() == game.BOARD_ROWS)
	assert(five_guanyu_hits.all(func(event): return int(event.amount) == roundi(game._unit_skill_output_base(five_guanyu) * 3.0)))

	# Peach Garden keeps the 180% cleave and heals Guan Yu for 30% of actual damage.
	var peach_only_team := _build_team(game, ["liubei", "guanyu", "zhangfei"])
	var peach_guanyu: Dictionary = peach_only_team.filter(func(unit): return unit.hero_id == "guanyu")[0]
	peach_guanyu.max_hp = 100000.0
	peach_guanyu.hp = 50000.0
	game.combat_units = peach_only_team + guanyu_targets
	game.visual_events.clear()
	var peach_guanyu_hp_before: float = peach_guanyu.hp
	var peach_targets_hp_before: float = 0.0
	for target in guanyu_targets:
		peach_targets_hp_before += float(target.hp)
	game._cast_guanyu_skill(peach_guanyu)
	var peach_guanyu_hits: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	var peach_targets_hp_after: float = 0.0
	for target in guanyu_targets:
		peach_targets_hp_after += float(target.hp)
	var peach_guanyu_damage: float = peach_targets_hp_before - peach_targets_hp_after
	assert(peach_guanyu_hits.size() == game.BOARD_ROWS)
	assert(peach_guanyu_hits.all(func(event): return int(event.amount) == roundi(game._unit_skill_output_base(peach_guanyu) * 1.80)))
	assert(is_equal_approx(peach_guanyu.hp - peach_guanyu_hp_before, peach_guanyu_damage * 0.30))

	# Zhao Yun uses one target for five rapid spear thrusts.
	var base_zhao: Dictionary = game._make_roster_unit("player", "zhaoyun")
	base_zhao.row = 1
	base_zhao.col = 0
	var base_zhao_target: Dictionary = game._make_roster_unit("enemy", "caocao")
	base_zhao_target.row = 0
	base_zhao_target.col = 0
	base_zhao_target.max_hp = 100000.0
	base_zhao_target.hp = base_zhao_target.max_hp
	game.combat_units = [base_zhao, base_zhao_target]
	game.visual_events.clear()
	game._cast_zhaoyun_empower(base_zhao)
	var base_zhao_hits: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	assert(base_zhao_hits.size() == 5)
	assert(base_zhao_hits.all(func(event): return event.target_id == base_zhao_target.id and event.group_style == "spear_rapid"))
	assert(base_zhao_hits.all(func(event): return int(event.amount) == roundi(game._unit_skill_output_base(base_zhao) * 0.50)))

	# Normal Zhao Yun randomly locks one reachable target instead of secretly prioritizing lowest HP.
	var random_targets: Array = []
	for hero_id in ["caocao", "caoren", "xiaoqiao"]:
		var random_target: Dictionary = game._make_roster_unit("enemy", hero_id)
		random_target.row = 0
		random_target.col = random_targets.size()
		random_target.max_hp = 100000.0
		random_target.hp = random_target.max_hp
		random_targets.append(random_target)
	game.rng.seed = 73125
	var expected_random_index: int = game.rng.randi_range(0, random_targets.size() - 1)
	var lowest_index: int = (expected_random_index + 1) % random_targets.size()
	random_targets[lowest_index].hp = 1.0
	game.combat_units = [base_zhao] + random_targets
	game.rng.seed = 73125
	game.visual_events.clear()
	game._cast_zhaoyun_empower(base_zhao)
	var random_zhao_hits: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	assert(random_zhao_hits.size() == 5)
	assert(random_zhao_hits.all(func(event): return event.target_id == random_targets[expected_random_index].id))
	assert(random_zhao_hits.all(func(event): return event.target_id != random_targets[lowest_index].id))

	# Five Tigers changes the five thrusts to 50/70/90/110/130%.
	var five_zhao: Dictionary = five_tigers.filter(func(unit): return unit.hero_id == "zhaoyun")[0]
	var five_zhao_target: Dictionary = game._make_roster_unit("enemy", "caocao")
	five_zhao_target.row = 0
	five_zhao_target.col = 0
	five_zhao_target.max_hp = 100000.0
	five_zhao_target.hp = five_zhao_target.max_hp
	game.combat_units = five_tigers + [five_zhao_target]
	game._apply_combo_bonds(true, false)
	game.visual_events.clear()
	game._cast_zhaoyun_empower(five_zhao)
	var five_zhao_hits: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	assert(five_zhao_hits.size() == 5)
	var five_zhao_mults := [0.50, 0.70, 0.90, 1.10, 1.30]
	for index in five_zhao_hits.size():
		assert(int(five_zhao_hits[index].amount) == roundi(game._unit_skill_output_base(five_zhao) * float(five_zhao_mults[index])))

	# Seven Charges alone overrides range, forces the rear target, and strikes 7 times at 50%.
	var seven_zhao: Dictionary = game._make_roster_unit("player", "zhaoyun")
	seven_zhao.row = 2
	seven_zhao.col = 1
	var liushan: Dictionary = game._make_roster_unit("player", "liushan")
	liushan.row = 1
	liushan.col = 1
	var tempting_front: Dictionary = game._make_roster_unit("enemy", "caocao")
	tempting_front.row = 0
	tempting_front.col = 0
	tempting_front.hp = 1.0
	var forced_rear: Dictionary = game._make_roster_unit("enemy", "caoren")
	forced_rear.row = 2
	forced_rear.col = 4
	forced_rear.max_hp = 100000.0
	forced_rear.hp = forced_rear.max_hp
	game.combat_units = [seven_zhao, liushan, tempting_front, forced_rear]
	game.visual_events.clear()
	game._cast_zhaoyun_empower(seven_zhao)
	var seven_zhao_hits: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	assert(seven_zhao_hits.size() == 7)
	assert(seven_zhao_hits.all(func(event): return event.target_id == forced_rear.id and int(event.rapid_hits) == 7))
	assert(seven_zhao_hits.all(func(event): return int(event.amount) == roundi(game._unit_skill_output_base(seven_zhao) * 0.50)))
	assert(tempting_front.hp == 1.0)

	# Liu Shan's side of Seven Charges grants the empowered ally 30% omnivamp for 4 seconds.
	var buffed_zhao: Dictionary = game._make_roster_unit("player", "zhaoyun")
	buffed_zhao.row = 0
	buffed_zhao.col = 1
	buffed_zhao.max_hp = 100000.0
	buffed_zhao.hp = 50000.0
	var liushan_target: Dictionary = game._make_roster_unit("enemy", "caocao")
	liushan_target.row = 0
	liushan_target.col = 0
	liushan_target.max_hp = 100000.0
	liushan_target.hp = liushan_target.max_hp
	game.combat_units = [liushan, buffed_zhao, liushan_target]
	game._cast_liushan_command(liushan)
	assert(is_equal_approx(buffed_zhao.timed_damage_time, 4.0))
	assert(is_equal_approx(buffed_zhao.all_lifesteal, 0.30))
	assert(is_equal_approx(buffed_zhao.all_lifesteal_time, 4.0))
	var buffed_zhao_hp_before: float = buffed_zhao.hp
	var liushan_target_hp_before: float = liushan_target.hp
	game._damage(buffed_zhao, liushan_target, 100.0, "physical", "test")
	var empowered_damage: float = liushan_target_hp_before - float(liushan_target.hp)
	assert(is_equal_approx(float(buffed_zhao.hp) - buffed_zhao_hp_before, empowered_damage * 0.30))

	# Seven Charges only escalates to 50/70/90/110/130/150/170% when Five Tigers is also active.
	var both_liushan: Dictionary = game._make_roster_unit("player", "liushan")
	both_liushan.row = 2
	both_liushan.col = 3
	var both_rear: Dictionary = game._make_roster_unit("enemy", "caoren")
	both_rear.row = 2
	both_rear.col = 4
	both_rear.max_hp = 100000.0
	both_rear.hp = both_rear.max_hp
	game.combat_units = five_tigers + [both_liushan, both_rear]
	game._apply_combo_bonds(true, false)
	game.visual_events.clear()
	game._cast_zhaoyun_empower(five_zhao)
	var both_zhao_hits: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	var both_zhao_mults := [0.50, 0.70, 0.90, 1.10, 1.30, 1.50, 1.70]
	assert(both_zhao_hits.size() == 7)
	assert(both_zhao_hits.all(func(event): return event.target_id == both_rear.id and int(event.rapid_hits) == 7))
	for index in both_zhao_hits.size():
		assert(int(both_zhao_hits[index].amount) == roundi(game._unit_skill_output_base(five_zhao) * float(both_zhao_mults[index])))

	# Ma Chao targets the lowest-current-HP enemy's column and pierces 200/170/140%.
	var machao: Dictionary = game._make_roster_unit("player", "machao")
	machao.row = 1
	machao.col = 1
	var machao_targets: Array = []
	for row in 3:
		var target: Dictionary = game._make_roster_unit("enemy", "caocao")
		target.row = row
		target.col = 2
		target.max_hp = 100000.0
		target.hp = 90000.0 - row * 10000.0
		machao_targets.append(target)
	var other_target: Dictionary = game._make_roster_unit("enemy", "caoren")
	other_target.row = 0
	other_target.col = 0
	other_target.max_hp = 100000.0
	other_target.hp = 85000.0
	game.combat_units = [machao] + machao_targets + [other_target]
	var machao_hp_before := machao_targets.map(func(target): return float(target.hp))
	game._cast_machao_pierce(machao)
	var machao_mults := [2.0, 1.7, 1.4]
	for row in 3:
		assert(is_equal_approx(float(machao_hp_before[row]) - float(machao_targets[row].hp), game._unit_skill_output_base(machao) * float(machao_mults[row])))
	assert(other_target.hp == 85000.0)
	assert(game.visual_events.filter(func(event): return str(event.get("visual_group", "")).begins_with("machao_column:")).all(func(event): return str(event.get("group_style", "")) == "spear_column"))

	# One Rider removes Ma Chao's decay and lets Ma Dai open at full gauge.
	var madai: Dictionary = game._make_roster_unit("player", "madai")
	madai.row = 2
	madai.col = 0
	game.combat_units = [machao, madai] + machao_targets
	for target in machao_targets: target.hp = 90000.0 - int(target.row) * 10000.0
	game._apply_combo_bonds(true, false)
	assert(machao.one_rider and madai.one_rider)
	assert(madai.action == game.ACTION_MAX)
	machao_hp_before = machao_targets.map(func(target): return float(target.hp))
	game._cast_machao_pierce(machao)
	for row in 3:
		assert(is_equal_approx(float(machao_hp_before[row]) - float(machao_targets[row].hp), game._unit_skill_output_base(machao) * 2.0))

	# Legacy level fields do not change Ma Dai's fixed level-1 baseline.
	for level in [1, 2, 3]:
		var star_madai: Dictionary = game._make_roster_unit("player", "madai")
		star_madai.level = level
		star_madai.stat_mult = game._star_stat_multiplier(level)
		var star_target: Dictionary = game._make_roster_unit("enemy", "caocao")
		star_target.row = 0
		star_target.col = 0
		star_target.max_hp = 100000.0
		star_target.hp = star_target.max_hp
		game.combat_units = [star_madai, star_target]
		game._cast_madai_execution(star_madai)
		assert(is_equal_approx(float(star_target.hp), 60000.0))

	# Fated Enemies still marks Ma Dai's victim for 15 seconds.
	var weiyan: Dictionary = game._make_roster_unit("player", "weiyan")
	weiyan.row = 1
	weiyan.col = 1
	var madai_target: Dictionary = game._make_roster_unit("enemy", "caocao")
	madai_target.row = 0
	madai_target.col = 2
	madai_target.max_hp = 100000.0
	madai_target.hp = 100000.0
	game.combat_units = [madai, weiyan, madai_target]
	game._apply_combo_bonds(true, false)
	game._cast_madai_execution(madai)
	assert(is_equal_approx(madai_target.hp, 60000.0))
	assert(is_equal_approx(madai_target.vulnerable, 0.40))
	assert(is_equal_approx(madai_target.vulnerable_time, 15.0))

	# Wei Yan cleaves three front tiles, heals from damage, and heals the two bond positions.
	var adjacent: Dictionary = madai
	adjacent.row = 1
	adjacent.col = 0
	adjacent.hp = adjacent.max_hp * 0.50
	var rearward_midguard: Dictionary = game._make_roster_unit("player", "zhaoyun")
	rearward_midguard.row = 2
	rearward_midguard.col = 1
	rearward_midguard.hp = rearward_midguard.max_hp * 0.50
	weiyan.hp = weiyan.max_hp * 0.50
	var cleave_targets: Array = []
	for col in [0, 1, 2]:
		var cleave_target: Dictionary = game._make_roster_unit("enemy", "caoren")
		cleave_target.row = 0
		cleave_target.col = col
		cleave_target.max_hp = 100000.0
		cleave_target.hp = 100000.0
		cleave_targets.append(cleave_target)
	game.combat_units = [weiyan, adjacent, rearward_midguard] + cleave_targets
	game._apply_combo_bonds(true, false)
	var weiyan_hp_before := float(weiyan.hp)
	var adjacent_hp_before := float(adjacent.hp)
	var rearward_hp_before := float(rearward_midguard.hp)
	game._cast_weiyan_cleave(weiyan)
	var cleave_damage: float = game._unit_skill_output_base(weiyan) * 1.8
	for target in cleave_targets:
		assert(is_equal_approx(100000.0 - float(target.hp), cleave_damage))
	assert(is_equal_approx(float(weiyan.hp) - weiyan_hp_before, cleave_damage * 3.0 * 0.40))
	assert(is_equal_approx(float(adjacent.hp) - adjacent_hp_before, float(adjacent.max_hp) * 0.15))
	assert(is_equal_approx(float(rearward_midguard.hp) - rearward_hp_before, float(rearward_midguard.max_hp) * 0.15))

	# Flying Meteor gives Huang Zhong a 50% double-damage critical chance.
	var huangzhong: Dictionary = game._make_roster_unit("player", "huangzhong")
	huangzhong.row = 2
	huangzhong.col = 2
	var huangzhong_targets: Array = []
	for row in game.BOARD_ROWS:
		for col in game.BOARD_COLUMNS:
			var huangzhong_target: Dictionary = game._make_roster_unit("enemy", "caocao")
			huangzhong_target.row = row
			huangzhong_target.col = col
			huangzhong_target.max_hp = 100000.0
			huangzhong_target.hp = huangzhong_target.max_hp
			huangzhong_targets.append(huangzhong_target)
	game.combat_units = [weiyan, huangzhong] + huangzhong_targets
	game._apply_combo_bonds(true, false)
	var critical_seed := 1
	while true:
		game.rng.seed = critical_seed
		if game.rng.randf() < 0.50: break
		critical_seed += 1
	game.rng.seed = critical_seed
	game.visual_events.clear()
	game._cast_huangzhong_skill(huangzhong)
	var huangzhong_critical_hits: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	assert(huangzhong_critical_hits.size() == 1)
	assert(int(huangzhong_critical_hits[0].amount) == roundi(game._unit_skill_output_base(huangzhong) * 2.0 * 2.0))

	# Flying Meteor separately heals Wei Yan when an enemy frontliner dies.
	var doomed_front: Dictionary = game._make_roster_unit("enemy", "caocao")
	doomed_front.row = 0
	doomed_front.col = 3
	doomed_front.hp = 1.0
	weiyan.hp = weiyan.max_hp * 0.25
	game.combat_units = [weiyan, huangzhong, doomed_front]
	game._apply_combo_bonds(true, false)
	var flying_hp_before := float(weiyan.hp)
	game._damage(huangzhong, doomed_front, 10.0, "physical", "test")
	assert(not doomed_front.alive)
	assert(is_equal_approx(float(weiyan.hp) - flying_hp_before, float(weiyan.max_hp) * 0.50))

	var copies: Array = []
	for _i in 4:
		copies.append(game._make_roster_unit("player", "guanyu"))
		game._try_upgrade(copies, "guanyu")
	assert(copies.size() == 4)
	assert(copies.all(func(unit): return int(unit.level) == 1 and float(unit.stat_mult) == 1.0))
	var healer: Dictionary = game._make_roster_unit("player", "liubei")
	game.combat_units = [healer]
	game.player_ruler_hp = 4000
	game._heal_weakest_fixed(healer, game._unit_skill_output_base(healer) * 1.8, 0.20)
	assert(game.player_ruler_hp > 4000)
	game.tick_timer.stop()
	quit()

func _build_team(game, hero_ids: Array) -> Array:
	var result: Array = []
	for i in hero_ids.size():
		var unit: Dictionary = game._make_roster_unit("player", hero_ids[i])
		unit.row = i % 3
		unit.col = int(i / 3)
		result.append(unit)
	return result
