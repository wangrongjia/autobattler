extends SceneTree

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()

	assert(game.heroes.zhugeliang.zh_skill == "八阵奇谋")
	assert(game.heroes.zhugeliang.cooldown == float(game.balance_overrides.get("zhugeliang", {}).get("cooldown", 4.0)))
	assert(game.heroes.zhugeliang.ability_params.mult == 2.0)
	assert(game._zhugeliang_affected_tiles(1, 2, false, false).size() == 3)
	assert(game._zhugeliang_affected_tiles(1, 2, true, false).size() == 5)
	assert(game._zhugeliang_affected_tiles(1, 2, true, true).size() == 9)
	assert(game._zhugeliang_affected_tiles(0, 0, true, true).size() == 4)

	var player_ids := ["zhugeliang", "pangtong", "jiangwei", "menghuo", "liubei"]
	var player_team: Array = []
	for index in player_ids.size():
		var ally: Dictionary = game._make_roster_unit("player", player_ids[index])
		ally.row = index % game.BOARD_ROWS
		ally.col = index
		player_team.append(ally)
	var zhuge: Dictionary = player_team[0]
	var enemy_team: Array = []
	for row in game.BOARD_ROWS:
		for col in range(1, 4):
			var target: Dictionary = game._make_roster_unit("enemy", "caocao")
			target.row = row
			target.col = col
			target.max_hp = 1000000.0
			target.hp = target.max_hp
			enemy_team.append(target)
	game.player_units = player_team
	game.enemy_units = enemy_team
	game.combat_units = player_team + enemy_team
	game.visual_events.clear()

	var base_damage := float(game.heroes.zhugeliang.ability_params.base_value)
	var complete_first_hit := base_damage * 1.20 * 1.80
	game._cast_zhugeliang_area_at(zhuge, 1, 2)
	for target in enemy_team:
		assert(is_equal_approx(float(target.hp), float(target.max_hp) - complete_first_hit))
		assert(bool(target.zhuge_fire_mark))
	var first_damage_events: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	assert(first_damage_events.size() == 9)
	assert(first_damage_events.all(func(event): return event.get("group_style", "") == "area_impact"))
	var visual_groups := {}
	for event in first_damage_events:
		visual_groups[str(event.visual_group)] = true
	assert(visual_groups.size() == 1)

	game.visual_events.clear()
	var hp_before_second: Array = enemy_team.map(func(target): return float(target.hp))
	game._cast_zhugeliang_area_at(zhuge, 1, 2)
	var complete_marked_hit := complete_first_hit * 1.30
	for index in enemy_team.size():
		assert(is_equal_approx(hp_before_second[index] - float(enemy_team[index].hp), complete_marked_hit))
		assert(bool(enemy_team[index].zhuge_fire_mark))

	var pangtong: Dictionary = player_team[1]
	var marked_target: Dictionary = enemy_team[0]
	var hp_before_other_magic := float(marked_target.hp)
	game._damage(pangtong, marked_target, 100.0, "magic", "test")
	assert(is_equal_approx(hp_before_other_magic - float(marked_target.hp), 100.0))
	assert(bool(marked_target.zhuge_fire_mark))

	var sparse_target: Dictionary = game._make_roster_unit("enemy", "caocao")
	sparse_target.row = 1
	sparse_target.col = 2
	sparse_target.max_hp = 1000000.0
	sparse_target.hp = sparse_target.max_hp
	game.enemy_units = [sparse_target]
	game.combat_units = player_team + [sparse_target]
	game.enemy_ruler_hp = game.RULER_MAX_HP
	game.visual_events.clear()
	var sparse_damage := base_damage * 1.20
	game._cast_zhugeliang_area_at(zhuge, 1, 2)
	assert(is_equal_approx(float(sparse_target.hp), float(sparse_target.max_hp) - sparse_damage))
	assert(game.RULER_MAX_HP - game.enemy_ruler_hp == round(sparse_damage) * 8)
	assert(game.visual_events.filter(func(event): return event.get("kind", "") == "damage").size() == 1)
	assert(game.visual_events.filter(func(event): return event.get("kind", "") == "empty").size() == 8)

	game.language = "zh"
	var skill_detail: String = game._skill_detail("zhugeliang")
	var bond_detail: String = game._hero_bond_detail("zhugeliang")
	assert(skill_detail.contains("八阵奇谋"))
	assert(not skill_detail.contains("命中9人"))
	assert(bond_detail.contains("卧龙凤雏"))
	assert(bond_detail.contains("北伐传承"))
	assert(bond_detail.contains("七擒孟获"))
	assert(bond_detail.contains("命中9人时提高80%"))
	quit()
