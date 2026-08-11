extends Button

var lab_owner: Node
var is_player_side := true
var board_row := 0
var board_col := 0
var touch_drag_started := false

func _drag_payload():
	if not is_instance_valid(lab_owner): return null
	var entry = lab_owner._lab_unit_at(is_player_side, board_row, board_col)
	if entry == null: return null
	return {
		"kind":"balance_lab_unit",
		"is_player":is_player_side,
		"row":board_row,
		"col":board_col
	}

func _drag_preview() -> Control:
	var entry = lab_owner._lab_unit_at(is_player_side, board_row, board_col)
	var preview := Label.new()
	preview.text = lab_owner._hero_name(str(entry.hero_id))
	preview.add_theme_font_size_override("font_size", 15)
	preview.add_theme_color_override("font_color", Color("#f0c77a"))
	var background := StyleBoxFlat.new()
	background.bg_color = Color("#20201dee")
	background.border_color = Color("#b88a50")
	background.set_border_width_all(2)
	background.set_corner_radius_all(8)
	background.set_content_margin_all(10)
	preview.add_theme_stylebox_override("normal", background)
	return preview

func _get_drag_data(_at_position: Vector2):
	var payload = _drag_payload()
	if payload == null: return null
	set_drag_preview(_drag_preview())
	return payload

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		touch_drag_started = false
	elif event is InputEventScreenDrag and not touch_drag_started:
		var payload = _drag_payload()
		if payload == null: return
		touch_drag_started = true
		force_drag(payload, _drag_preview())
		accept_event()

func _can_drop_data(_at_position: Vector2, data) -> bool:
	return data is Dictionary \
		and str(data.get("kind", "")) == "balance_lab_unit" \
		and bool(data.get("is_player", not is_player_side)) == is_player_side \
		and is_instance_valid(lab_owner) \
		and lab_owner._can_move_lab_unit(is_player_side, int(data.get("row", -1)), int(data.get("col", -1)), board_row, board_col)

func _drop_data(_at_position: Vector2, data) -> void:
	lab_owner._move_lab_unit(is_player_side, int(data.row), int(data.col), board_row, board_col)
