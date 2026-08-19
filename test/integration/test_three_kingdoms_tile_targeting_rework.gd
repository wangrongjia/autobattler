extends SceneTree

func _unit(game, team: String, hero_id: String, row: int, col: int) -> Dictionary:
	var unit: Dictionary = game._make_roster_unit(team, hero_id)
	unit.row = row
	unit.col = col
	unit.max_hp = 1000000.0
	unit.hp = unit.max_hp
	game._ensure_unit_fields(unit)
	return unit

func _set_combat(game, players: Array, enemies: Array) -> void:
	game.player_units = players
	game.enemy_units = enemies
	game.combat_units = players + enemies
	game.ground_effects.clear()
	game.visual_events.clear()
	game.player_ruler_hp = game.RULER_MAX_HP
	game.enemy_ruler_hp = game.RULER_MAX_HP
	game.battle_stats = {}
	for unit in game.combat_units:
		game.battle_stats[unit.id] = {"unit_id":unit.id, "hero_id":unit.hero_id, "team":unit.team, "level":1, "damage":0.0, "healing":0.0, "taken":0.0, "control":0.0}

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()

	# 通用射程：射程1在当前开放排无人时逐排扩展；射程2的站位限制固定；射程3始终全场。
	var zhaoyun := _unit(game, "player", "zhaoyun", 0, 0)
	var front := _unit(game, "enemy", "caocao", 0, 4)
	_set_combat(game, [zhaoyun], [front])
	assert(game._attackable_rows(zhaoyun) == [0])
	front.row = 1
	assert(game._attackable_rows(zhaoyun) == [0, 1])
	front.row = 2
	assert(game._attackable_rows(zhaoyun) == [0, 1, 2])

	var pangtong := _unit(game, "player", "pangtong", 0, 1)
	_set_combat(game, [pangtong], [front])
	assert(game._attackable_rows(pangtong) == [0, 1, 2])
	pangtong.row = 1
	front.row = 1
	assert(game._attackable_rows(pangtong) == [0, 1])
	front.row = 2
	assert(game._attackable_rows(pangtong) == [0, 1])
	pangtong.row = 2
	assert(game._attackable_rows(pangtong) == [0])

	var zhuge := _unit(game, "player", "zhugeliang", 0, 2)
	_set_combat(game, [zhuge], [front])
	assert(game._attackable_rows(zhuge) == [0, 1, 2])

	# 顺延与固定列是两个独立约束：先找首个有武将的排，再攻击原列，即使该格为空也不改锁敌。
	var weiyan := _unit(game, "player", "weiyan", 0, 0)
	var middle_other_col := _unit(game, "enemy", "caocao", 1, 4)
	_set_combat(game, [weiyan], [middle_other_col])
	var advancing_tile: Dictionary = game._fixed_advancing_enemy_tile(weiyan, int(weiyan.col))
	assert(int(advancing_tile.row) == 1 and int(advancing_tile.col) == 0 and advancing_tile.target == null)
	var ruler_before := int(game.enemy_ruler_hp)
	game._cast_weiyan_cleave(weiyan)
	assert(ruler_before - int(game.enemy_ruler_hp) == roundi(game._unit_skill_stat_value(weiyan) * float(game.heroes.weiyan.ability_params.mult)))

	# 多目标技能抽取不同单元格，而不是只从存活武将中抽取；空格与武将格基础伤害一致。
	var caocao := _unit(game, "player", "caocao", 1, 0)
	var durable_front := _unit(game, "enemy", "dongzhuo", 0, 0)
	_set_combat(game, [caocao], [durable_front])
	game.rng.seed = 7
	game._cast_caocao_command(caocao)
	var impacts: Array = game.visual_events.filter(func(event): return str(event.get("visual_group", "")).begins_with("caocao_command:") and str(event.get("kind", "")) in ["damage", "empty"])
	assert(impacts.size() == int(game.heroes.caocao.ability_params.target_count))
	var impact_keys: Array = impacts.map(func(event): return str(event.row) + ":" + str(event.col))
	var unique_impact_keys := {}
	for key in impact_keys: unique_impact_keys[key] = true
	assert(impact_keys.size() == unique_impact_keys.size())
	assert(impacts.all(func(event): return int(event.amount) == roundi(game._unit_skill_stat_value(caocao) * float(game.heroes.caocao.ability_params.mult))))

	# 空格毒每秒直伤主公并衰减；格上出现武将后，剩余层数转移给该武将。
	var jiaxu := _unit(game, "player", "jiaxu", 2, 0)
	_set_combat(game, [jiaxu], [])
	game.rng.seed = 11
	game._cast_jiaxu_skill(jiaxu)
	assert(game.ground_effects.size() == int(game.heroes.jiaxu.ability_params.target_count))
	assert(game.ground_effects.all(func(effect): return str(effect.type) == "poison"))
	var poison_stacks := int(game.ground_effects[0].stacks)
	ruler_before = int(game.enemy_ruler_hp)
	game._process_statuses(1.0)
	assert(ruler_before - int(game.enemy_ruler_hp) == poison_stacks * game.ground_effects.size())
	var inherited_stacks := int(game.ground_effects[0].stacks)
	var poisoned_tile: Dictionary = game.ground_effects[0]
	var entrant := _unit(game, "enemy", "caocao", int(poisoned_tile.row), int(poisoned_tile.col))
	game.enemy_units.append(entrant)
	game.combat_units.append(entrant)
	game._process_statuses(0.1)
	assert(int(entrant.poison_stacks) == inherited_stacks)
	assert(not game.ground_effects.any(func(effect): return str(effect.type) == "poison" and int(effect.row) == int(entrant.row) and int(effect.col) == int(entrant.col)))

	# 空格灼烧同样转移剩余持续时间；陆逊的每次弹射都以相邻单元格为目标，空场也会完整弹射。
	var luxun := _unit(game, "player", "luxun", 2, 0)
	_set_combat(game, [luxun], [])
	game._set_ground_burn(luxun, "enemy", 1, 1, 3.0, 40.0, "inherit_burn")
	game._process_statuses(0.5)
	var burn_entrant := _unit(game, "enemy", "caocao", 1, 1)
	game.enemy_units.append(burn_entrant)
	game.combat_units.append(burn_entrant)
	game._process_statuses(0.1)
	assert(is_equal_approx(float(burn_entrant.burn), 2.5))
	assert(not game.ground_effects.any(func(effect): return str(effect.get("type", "burn")) == "burn" and int(effect.row) == 1 and int(effect.col) == 1))

	_set_combat(game, [luxun], [])
	game.rng.seed = 19
	game._cast_luxun(luxun)
	var fireball_events: Array = game.visual_events.filter(func(event): return str(event.get("visual_group", "")).begins_with("luxun_fireball:") and str(event.get("kind", "")) == "empty")
	assert(fireball_events.size() == int(game.heroes.luxun.ability_params.bounces) + 1)
	assert(abs(int(fireball_events[0].row) - int(fireball_events[1].row)) + abs(int(fireball_events[0].col) - int(fireball_events[1].col)) == 1)

	game.tick_timer.stop()
	quit()
