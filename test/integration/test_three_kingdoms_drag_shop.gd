extends SceneTree

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._start_new_from_menu()
	assert(game.draft_refresh_available == [true, true])
	var original_first: String = game.choices[0]
	var original_second: String = game.choices[1]
	game._refresh_draft_choice(0)
	assert(game.choices[0] != original_first)
	assert(game.choices[1] == original_second)
	assert(game.draft_refresh_available == [false, true])
	var refreshed_first: String = game.choices[0]
	game._refresh_draft_choice(0)
	assert(game.choices[0] == refreshed_first)
	game._refresh_draft_choice(1)
	assert(game.choices[1] != original_second)
	assert(game.draft_refresh_available == [false, false])
	game._choose_hero(game.choices[0])
	assert(game.draft_refresh_available == [true, true])
	game._choose_hero(game.choices[0])
	game._choose_hero(game.choices[0])
	assert(game.phase == "placement")
	assert(not game.draft_overlay.visible, "draft overlay must auto-hide so it cannot intercept reserve drag input")
	assert(game._reserve_units().size() == 3)
	var first: Dictionary = game._reserve_units()[0]
	var second: Dictionary = game._reserve_units()[1]
	var first_slot: Control = game.reserve_box.get_child(0)
	var drag_data = game._drag_unit(Vector2.ZERO, first.id, first_slot)
	assert(drag_data is Dictionary and drag_data.unit_id == first.id)
	assert(game._can_drop_board(Vector2.ZERO, drag_data, 0, 0))
	game._drop_board(Vector2.ZERO, drag_data, 0, 0)
	assert(first.row == 0 and first.col == 0)
	game._drop_board(Vector2.ZERO, {"unit_id":second.id}, 0, 0)
	assert(second.row == 0 and second.col == 0)
	assert(first.row < 0)
	game._drop_reserve(Vector2.ZERO, {"unit_id":second.id}, 1)
	assert(second.row < 0)
	game._sell_reserve_unit(first.id)
	assert(game.refresh_charges == 0)
	assert(game._find_by_id(game.player_units, first.id) == null)
	quit()
