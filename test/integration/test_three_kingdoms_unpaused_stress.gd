extends SceneTree

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._start_new_from_menu()
	game._choose_hero(game.choices[0])
	game._choose_hero(game.choices[0])
	game._choose_hero(game.choices[0])
	game._auto_place_player()
	game._start_battle()
	game.pause_during_actions = false
	game.game_speed = 4.0
	game.battle_speed = 4.0
	for unit in game.combat_units: unit.action = 95.0
	await create_timer(2.5).timeout
	game.tick_timer.stop()
	# Stop scheduling new turns, then allow the last visual action to resolve.
	for _frame in 120:
		if not game.action_in_progress: break
		await process_frame
	assert(not game.action_in_progress)
	game.pause_during_actions = true
	game.game_speed = 1.0
	game._save_settings()
	quit()
