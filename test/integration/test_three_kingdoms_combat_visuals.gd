extends SceneTree

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()
	game.game_speed = 4.0

	var guanyu: Dictionary = game._make_roster_unit("player", "guanyu")
	guanyu.row = 0
	guanyu.col = 0
	var enemies: Array = []
	for row in game.BOARD_ROWS:
		for col in game.BOARD_COLUMNS:
			var enemy: Dictionary = game._make_roster_unit("enemy", "caocao")
			enemy.row = row
			enemy.col = col
			if row == 0: enemy.hp = 1.0
			enemies.append(enemy)
	game.player_units = [guanyu]
	game.enemy_units = enemies
	game.combat_units = [guanyu] + enemies
	game.battle_running = true
	game.phase = "combat"
	game._render_combat_boards()
	await process_frame

	var tile: Control = game.tile_cell_refs["player:0:0"]
	var card: Control = game.unit_cell_refs[guanyu.id]
	assert(game.player_board.get_child(0) == game.tile_cell_refs["player:0:0"])
	assert(game.enemy_board.get_child(0) == game.tile_cell_refs["enemy:2:0"])
	assert(game.enemy_board.get_child(game.BOARD_COLUMNS * (game.BOARD_ROWS - 1)) == game.tile_cell_refs["enemy:0:0"])
	assert(card != tile)
	assert(card.get_parent() == tile)
	assert(card.name == "AnimatedUnitCard")
	assert(game._hero_fx("guanyu").weapon == "青龙偃月刀")
	assert(game._hero_fx("guanyu").weapon_path == "res://ThreeKingdom/weapon/qinglongyanyuedao.png")
	assert(ResourceLoader.exists(game._hero_fx("guanyu").weapon_path))

	game.visual_events.clear()
	game._perform_action(guanyu)
	var damage_events: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	assert(damage_events.size() == game.BOARD_ROWS)
	var visual_group := str(damage_events[0].get("visual_group", ""))
	assert(not visual_group.is_empty())
	assert(damage_events.all(func(event): return str(event.get("visual_group", "")) == visual_group))
	var death_events: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "death")
	assert(death_events.size() == 1)
	assert(str(death_events[0].get("visual_group", "")) == visual_group)

	var events: Array = game.visual_events.duplicate(true)
	game.visual_events.clear()
	await game._play_visual_events(events)
	var dead_card: Control = game.unit_cell_refs.get(str(death_events[0].target_id))
	assert(is_instance_valid(dead_card))
	assert(not dead_card.visible)

	# A column skill resolves all three cells together. Empty cells deal their
	# damage to the enemy ruler instead of being skipped.
	var sparse_guanyu: Dictionary = game._make_roster_unit("player", "guanyu")
	sparse_guanyu.row = 0
	sparse_guanyu.col = 0
	var sparse_column_targets: Array = []
	for col in game.BOARD_COLUMNS:
		var sparse_target: Dictionary = game._make_roster_unit("enemy", "caocao")
		sparse_target.row = 0
		sparse_target.col = col
		sparse_target.max_hp = 100000.0
		sparse_target.hp = sparse_target.max_hp
		sparse_column_targets.append(sparse_target)
	game.player_units = [sparse_guanyu]
	game.enemy_units = sparse_column_targets
	game.combat_units = [sparse_guanyu] + sparse_column_targets
	game.enemy_ruler_hp = game.RULER_MAX_HP
	game.visual_events.clear()
	game._cast_guanyu_skill(sparse_guanyu)
	var sparse_column_damage: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	var sparse_column_empty: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "empty")
	assert(sparse_column_damage.size() == 1)
	assert(sparse_column_empty.size() == 2)
	var sparse_column_group := str(sparse_column_damage[0].visual_group)
	assert(sparse_column_empty.all(func(event): return str(event.visual_group) == sparse_column_group))
	assert(game.RULER_MAX_HP - game.enemy_ruler_hp == int(sparse_column_empty.reduce(func(total, event): return total + int(event.amount), 0)))

	# Zhou Yu picks two distinct tiles in one visual group. Occupied tiles take
	# the direct hit and later burn ticks simultaneously.
	var zhouyu: Dictionary = game._make_roster_unit("player", "zhouyu")
	zhouyu.row = 2
	zhouyu.col = 2
	var fire_targets: Array = []
	for row in game.BOARD_ROWS:
		for col in game.BOARD_COLUMNS:
			var fire_target: Dictionary = game._make_roster_unit("enemy", "dongzhuo")
			fire_target.row = row
			fire_target.col = col
			fire_target.max_hp = 100000.0
			fire_target.hp = fire_target.max_hp
			fire_targets.append(fire_target)
	game.player_units = [zhouyu]
	game.enemy_units = fire_targets
	game.combat_units = [zhouyu] + fire_targets
	game.visual_events.clear()
	game._cast_zhouyu(zhouyu)
	var row_burn_events: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "row_burn")
	assert(row_burn_events.size() == 2)
	var row_group := str(row_burn_events[0].visual_group)
	assert(row_burn_events.all(func(event): return str(event.visual_group) == row_group and str(event.group_style) == "tile_burn"))
	var initial_fire_damage: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	assert(initial_fire_damage.size() == 2)
	assert(initial_fire_damage.all(func(event): return str(event.visual_group) == row_group and str(event.group_style) == "tile_burn"))
	game.visual_events.clear()
	for target in fire_targets:
		if str(target.get("burn_visual_group", "")) == row_group: target.burn_clock = 0.9
	game._process_statuses(0.2)
	var burn_tick_damage: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	assert(burn_tick_damage.size() == 2)
	assert(burn_tick_damage.all(func(event): return str(event.visual_group) == row_group and str(event.group_style) == "burn_tick"))

	# Sparse boards still animate both randomly chosen cells. Empty selected
	# cells burn the ground and route direct and periodic damage to the ruler.
	var sparse_zhouyu: Dictionary = game._make_roster_unit("player", "zhouyu")
	sparse_zhouyu.row = 2
	sparse_zhouyu.col = 2
	var sparse_fire_targets: Array = []
	for row in game.BOARD_ROWS:
		var sparse_fire_target: Dictionary = game._make_roster_unit("enemy", "dongzhuo")
		sparse_fire_target.row = row
		sparse_fire_target.col = 2
		sparse_fire_target.max_hp = 100000.0
		sparse_fire_target.hp = sparse_fire_target.max_hp
		sparse_fire_targets.append(sparse_fire_target)
	game.player_units = [sparse_zhouyu]
	game.enemy_units = sparse_fire_targets
	game.combat_units = [sparse_zhouyu] + sparse_fire_targets
	game.enemy_ruler_hp = game.RULER_MAX_HP
	game.ground_effects.clear()
	game.visual_events.clear()
	game._cast_zhouyu(sparse_zhouyu)
	var sparse_row_fire: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "row_burn")
	var sparse_row_damage: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	var sparse_row_empty: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "empty")
	assert(sparse_row_fire.size() == 2)
	assert(sparse_row_damage.size() + sparse_row_empty.size() == 2)
	assert(sparse_fire_targets.filter(func(target): return float(target.burn) > 0.0).size() == sparse_row_damage.size())
	assert(game.ground_effects.size() == sparse_row_empty.size())
	assert(game.RULER_MAX_HP - game.enemy_ruler_hp == int(sparse_row_empty.reduce(func(total, event): return total + int(event.amount), 0)))
	for target in sparse_fire_targets:
		if float(target.burn) > 0.0: target.burn_clock = 0.9
	for effect in game.ground_effects: effect.clock = 0.9
	game.visual_events.clear()
	game._process_statuses(0.2)
	var sparse_burn_ticks: Array = game.visual_events.filter(func(event): return str(event.get("group_style", "")) == "burn_tick")
	assert(sparse_burn_ticks.size() == 2)
	assert(sparse_burn_ticks.filter(func(event): return event.get("kind", "") == "empty").size() == sparse_row_empty.size())

	# Generic row skills (including Meng Huo) share the same grouped rule;
	# empty cells do not receive stun, but their damage reaches the ruler.
	var menghuo: Dictionary = game._make_roster_unit("player", "menghuo")
	menghuo.row = 0
	menghuo.col = 2
	var menghuo_target: Dictionary = game._make_roster_unit("enemy", "caocao")
	menghuo_target.row = 0
	menghuo_target.col = 2
	menghuo_target.max_hp = 100000.0
	menghuo_target.hp = menghuo_target.max_hp
	game.player_units = [menghuo]
	game.enemy_units = [menghuo_target]
	game.combat_units = [menghuo, menghuo_target]
	game.ground_effects.clear()
	game.enemy_ruler_hp = game.RULER_MAX_HP
	game.visual_events.clear()
	game._cast_generic_ability(menghuo)
	var row_impacts: Array = game.visual_events.filter(func(event): return str(event.get("kind", "")) in ["damage", "empty"])
	assert(row_impacts.size() == game.BOARD_COLUMNS)
	assert(row_impacts.filter(func(event): return event.get("kind", "") == "empty").size() == game.BOARD_COLUMNS - 1)
	assert(row_impacts.all(func(event): return str(event.visual_group) == str(row_impacts[0].visual_group)))
	assert(menghuo_target.stun > 0.0)
	game._render_combat_boards()
	await process_frame
	var grouped_row_events: Array = game.visual_events.duplicate(true)
	game.visual_events.clear()
	await game._play_visual_events(grouped_row_events)

	# Zhao Yun's single-target sequence uses one rapid spear animation group.
	var visual_zhao: Dictionary = game._make_roster_unit("player", "zhaoyun")
	visual_zhao.row = 1
	visual_zhao.col = 2
	var visual_zhao_target: Dictionary = game._make_roster_unit("enemy", "caocao")
	visual_zhao_target.row = 0
	visual_zhao_target.col = 2
	visual_zhao_target.max_hp = 100000.0
	visual_zhao_target.hp = visual_zhao_target.max_hp
	game.player_units = [visual_zhao]
	game.enemy_units = [visual_zhao_target]
	game.combat_units = [visual_zhao, visual_zhao_target]
	game._render_combat_boards()
	await process_frame
	game.visual_events.clear()
	game._cast_zhaoyun_empower(visual_zhao)
	var zhao_visual_events: Array = game.visual_events.duplicate(true)
	assert(zhao_visual_events.filter(func(event): return event.get("kind", "") == "damage").size() == 5)
	assert(zhao_visual_events.all(func(event): return str(event.get("group_style", "")) == "spear_rapid"))
	game.visual_events.clear()
	await game._play_visual_events(zhao_visual_events)

	# Ma Chao's entire selected column uses the dedicated long-spear thrust.
	var visual_machao: Dictionary = game._make_roster_unit("player", "machao")
	visual_machao.row = 1
	visual_machao.col = 2
	var visual_machao_targets: Array = []
	for row in game.BOARD_ROWS:
		var visual_machao_target: Dictionary = game._make_roster_unit("enemy", "caocao")
		visual_machao_target.row = row
		visual_machao_target.col = 2
		visual_machao_target.max_hp = 100000.0
		visual_machao_target.hp = visual_machao_target.max_hp - row * 1000.0
		visual_machao_targets.append(visual_machao_target)
	game.player_units = [visual_machao]
	game.enemy_units = visual_machao_targets
	game.combat_units = [visual_machao] + visual_machao_targets
	game._render_combat_boards()
	await process_frame
	game.visual_events.clear()
	game._cast_machao_pierce(visual_machao)
	var machao_visual_events: Array = game.visual_events.duplicate(true)
	assert(machao_visual_events.filter(func(event): return event.get("kind", "") == "damage").size() == game.BOARD_ROWS)
	assert(machao_visual_events.all(func(event): return str(event.get("group_style", "")) == "spear_column"))
	game.visual_events.clear()
	await game._play_visual_events(machao_visual_events)

	# Benevolence regeneration is a target-only green glow and is explicitly
	# nonblocking, so the battle loop does not enter an effect pause.
	var liubei: Dictionary = game._make_roster_unit("player", "liubei")
	var regen_target: Dictionary = game._make_roster_unit("player", "guanyu")
	liubei.row = 2
	liubei.col = 0
	regen_target.row = 0
	regen_target.col = 0
	regen_target.hp = regen_target.max_hp * 0.5
	game.player_units = [liubei, regen_target]
	game.enemy_units = []
	game.combat_units = [liubei, regen_target]
	game.visual_events.clear()
	game._cast_liubei_regen(liubei)
	game.visual_events.clear()
	regen_target.regen_clock = 0.9
	game._process_statuses(0.2)
	var regen_events: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "regen")
	assert(regen_events.size() == 1)
	assert(regen_events[0].target_id == regen_target.id)
	assert(regen_events[0].nonblocking)

	quit()
