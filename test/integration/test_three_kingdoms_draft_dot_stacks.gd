extends SceneTree

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._start_new_from_menu()
	game.tick_timer.stop()

	# Recruitment occupies only the information area, leaving formation and reserve interactive.
	assert(game.phase == "draft")
	assert(game.draft_overlay.get_parent() == game.draft_layer)
	assert(game.draft_layer.layer == 20)
	game._choose_hero(str(game.choices[0]))
	assert(game.phase == "draft")
	var recruited: Dictionary = game._reserve_units()[0]
	var drag_data := {"unit_id":str(recruited.id)}
	assert(game._can_drop_board(Vector2.ZERO, drag_data, 0, 0))
	game._drop_board(Vector2.ZERO, drag_data, 0, 0)
	assert(recruited.row == 0 and recruited.col == 0)
	game._toggle_unit_inspector(str(recruited.id))
	assert(game.unit_inspector_overlay.visible)
	assert(game._inspector_unit() == recruited)
	game._hide_unit_inspector()
	assert(game._can_drop_reserve(Vector2.ZERO, drag_data, 0))
	game._drop_reserve(Vector2.ZERO, drag_data, 0)
	assert(game._find_by_id(game.player_units, str(recruited.id)) == null)

	# Every burn/poison application has its own source, timer and value.
	var poison_a: Dictionary = game._make_roster_unit("player", "yuji")
	var poison_b: Dictionary = game._make_roster_unit("player", "jiaxu")
	var burn_a: Dictionary = game._make_roster_unit("player", "zhouyu")
	var burn_b: Dictionary = game._make_roster_unit("player", "taishici")
	var target: Dictionary = game._make_roster_unit("enemy", "caocao")
	target.max_hp = 10000.0
	target.hp = 10000.0
	game.combat_units = [poison_a, poison_b, burn_a, burn_b, target]
	game._add_poison_effect(poison_a, target, 3.0, 0.005)
	game._add_poison_effect(poison_b, target, 2.0, 0.010)
	game._add_burn_effect(burn_a, target, 3.0, 40.0)
	game._add_burn_effect(burn_b, target, 2.0, 60.0)
	assert((target.poison_effects as Array).size() == 2)
	assert((target.burn_effects as Array).size() == 2)
	game._process_statuses(1.0)
	assert(is_equal_approx(float(target.hp), 9750.0))
	game._process_statuses(1.0)
	assert(is_equal_approx(float(target.hp), 9500.0))
	assert((target.poison_effects as Array).size() == 1)
	assert((target.burn_effects as Array).size() == 1)

	# Reapplying control keeps the longer remaining duration; it never adds durations.
	target.stun = 2.0
	game._apply_skill_stun(poison_a, target, 1.0)
	assert(is_equal_approx(float(target.stun), 2.0))
	game._apply_skill_stun(poison_a, target, 3.0)
	assert(is_equal_approx(float(target.stun), 5.4))

	game.tick_timer.stop()
	quit()
