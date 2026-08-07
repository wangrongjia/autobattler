extends SceneTree

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	assert(game.menu_overlay.visible)
	game.menu_overlay.hide()
	game._choose_hero(game.choices[0])
	game._refresh_draft_choice(1)
	assert(game.draft_refresh_available == [true, false])
	assert(game._save_game(true))
	var saved_round: int = game.round_number
	var saved_units: int = game.player_units.size()
	game.round_number = 9
	game.player_units.clear()
	assert(game._load_game())
	assert(game.round_number == saved_round)
	assert(game.player_units.size() == saved_units)
	assert(game.draft_refresh_available == [true, false])
	game._choose_hero(game.choices[0])
	game._choose_hero(game.choices[0])
	game._auto_place_player()
	game._start_battle()
	game.tick_timer.stop()
	var source: Dictionary = game.combat_units.filter(func(unit): return unit.team == "player")[0]
	var target: Dictionary = game.combat_units.filter(func(unit): return unit.team == "enemy")[0]
	game._damage(source, target, 300.0, "physical", "test")
	assert(game.battle_stats[source.id].damage > 0.0)
	assert(game.battle_stats[target.id].taken > 0.0)
	game._finish_battle()
	assert(not game.last_battle_stats.is_empty())
	game.tick_timer.stop()
	quit()
