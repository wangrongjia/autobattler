extends SceneTree

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()
	game.menu_overlay.hide()

	var field_unit: Dictionary = game._make_roster_unit("player", "guanyu")
	field_unit.row = 0
	field_unit.col = 0
	var reserve_unit: Dictionary = game._make_roster_unit("player", "caocao")
	game.player_units = [field_unit, reserve_unit]
	game.choices = ["guanyu", "caocao", "sunquan"]
	game._render()
	await process_frame

	var board_borders: Array[Node] = game.player_board.find_children("FactionBorder", "", true, false)
	assert(board_borders.size() == 1)
	assert(board_borders[0] is TextureRect)
	assert(board_borders[0].texture.resource_path.ends_with("shu-draft.png"))

	var reserve_borders: Array[Node] = game.reserve_box.find_children("FactionBorder", "", true, false)
	assert(reserve_borders.size() == 1)
	assert(reserve_borders[0] is TextureRect)
	assert(reserve_borders[0].texture.resource_path.ends_with("wei-draft.png"))

	var draft_borders: Array[Node] = game.draft_box.find_children("FactionBorder", "", true, false)
	assert(draft_borders.size() == 3)
	assert(draft_borders[0] is TextureRect)
	assert(draft_borders[0].texture.resource_path.ends_with("shu-compact.png"))
	assert(draft_borders[1].texture.resource_path.ends_with("wei-compact.png"))
	assert(draft_borders[2].texture.resource_path.ends_with("wu-compact.png"))
	for border in board_borders + reserve_borders + draft_borders:
		assert(border.mouse_filter == Control.MOUSE_FILTER_IGNORE)

	quit()
