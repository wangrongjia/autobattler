extends SceneTree

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.pause_during_actions = true
	game._choose_hero(game.choices[0])
	game._choose_hero(game.choices[0])
	game._choose_hero(game.choices[0])
	game._auto_place_player()
	game._start_battle()
	game.tick_timer.stop()
	var actor: Dictionary = game.combat_units[0]
	var observer: Dictionary = game.combat_units[1]
	actor.action = 100.0
	observer.action = 37.0
	game._battle_tick()
	assert(game.action_in_progress)
	var frozen_action: float = observer.action
	game._battle_tick()
	assert(observer.action == frozen_action)
	var action_deadline := Time.get_ticks_msec() + 10000
	while game.action_in_progress and Time.get_ticks_msec() < action_deadline:
		await process_frame
	game.tick_timer.stop()
	assert(not game.action_in_progress)
	assert(actor.action < 100.0)
	quit()
