extends SceneTree

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._choose_hero(game.choices[0])
	game._choose_hero(game.choices[0])
	game._choose_hero(game.choices[0])
	game._auto_place_player()
	game._start_battle()
	game.tick_timer.stop()
	game.rng.seed = 7
	var saw_empty := false
	var saw_unit := false
	for _roll in 100:
		var tile: Dictionary = game._random_enemy_tile(game.player_units[0])
		if tile.target == null: saw_empty = true
		else: saw_unit = true
	assert(saw_empty and saw_unit)
	var survivor: Dictionary = game.player_units[0]
	var fallen: Dictionary = game.enemy_units[0]
	survivor.hp = 123.0
	survivor.shield = 42.0
	survivor.burn = 2.5
	survivor.burn_damage = 7.0
	survivor.damage_reduction = 0.33
	fallen.hp = 0.0
	fallen.alive = false
	game._finish_battle()
	assert(game.round_number == 2)
	assert(survivor.hp == 123.0)
	assert(survivor.shield == 42.0)
	assert(survivor.burn == 2.5)
	assert(survivor.damage_reduction == 0.33)
	assert(not fallen.alive)
	assert(game.enemy_units.size() == 4)
	assert(game._unit_at(game.enemy_units, fallen.row, fallen.col) != fallen)
	quit()
