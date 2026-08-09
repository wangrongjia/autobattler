extends "res://ThreeKingdom/systems/combat_system.gd"

var _encyclopedia_touch_origins := {}

func _is_mobile_ui() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.get_environment("THREE_KINGDOM_MOBILE_UI_TEST") == "1"

func _enable_touch_scroll(scroll: ScrollContainer, horizontal := false, vertical := true) -> void:
	scroll.scroll_deadzone = 6
	if not _is_mobile_ui(): return
	scroll.set_meta("touch_scroll_enabled", true)
	scroll.gui_input.connect(_on_touch_scroll_input.bind(scroll, horizontal, vertical))

func _on_touch_scroll_input(event: InputEvent, scroll: ScrollContainer, horizontal: bool, vertical: bool) -> void:
	if event is InputEventScreenDrag:
		if horizontal: scroll.scroll_horizontal -= roundi(event.relative.x)
		if vertical: scroll.scroll_vertical -= roundi(event.relative.y)
		scroll.accept_event()

func _enable_touch_value_scroll(control: Control) -> void:
	if not _is_mobile_ui(): return
	control.set_meta("touch_scroll_enabled", true)
	control.gui_input.connect(_on_touch_value_scroll_input.bind(control))

func _on_touch_value_scroll_input(event: InputEvent, control: Control) -> void:
	if event is InputEventScreenDrag and control.has_method("get_v_scroll_bar"):
		var bar: VScrollBar = control.get_v_scroll_bar()
		bar.value -= event.relative.y
		control.accept_event()

func _on_bond_graph_touch(event: InputEvent) -> void:
	if not _is_mobile_ui(): return
	if event is InputEventScreenDrag:
		encyclopedia_bond_graph.scroll_offset -= event.relative / maxf(encyclopedia_bond_graph.zoom, 0.01)
		encyclopedia_bond_graph.accept_event()
	elif event is InputEventMagnifyGesture:
		encyclopedia_bond_graph.zoom = clampf(encyclopedia_bond_graph.zoom * event.factor, 0.25, 2.0)
		encyclopedia_bond_graph.accept_event()

func _style(control: Control, color: Color, radius := 10, border := Color.TRANSPARENT, width := 0) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.border_color = border
	box.border_width_left = width
	box.border_width_right = width
	box.border_width_top = width
	box.border_width_bottom = width
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	control.add_theme_stylebox_override("panel", box)

func _button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 42)
	button.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#2a4762")
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	var hover := normal.duplicate()
	hover.bg_color = Color("#3d6788")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	return button

func _label(value: String, size := 16, color := Color("#e8e2cf")) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _build_ui() -> void:
	var bg := TextureRect.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("#090b0f"), Color("#20130f"), Color("#080b10")])
	gradient.offsets = PackedFloat32Array([0.0, 0.48, 1.0])
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 1920
	gradient_texture.height = 1080
	gradient_texture.fill_from = Vector2(0.0, 0.0)
	gradient_texture.fill_to = Vector2(1.0, 1.0)
	bg.texture = gradient_texture
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var glow := ColorRect.new()
	glow.color = Color(0.55, 0.16, 0.08, 0.08)
	glow.position = Vector2(-160, -220)
	glow.size = Vector2(960, 580)
	glow.rotation = -0.14
	add_child(glow)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var compact_mobile := _is_mobile_ui()
	margin.add_theme_constant_override("margin_left", 10 if compact_mobile else 22)
	margin.add_theme_constant_override("margin_right", 10 if compact_mobile else 22)
	margin.add_theme_constant_override("margin_top", 8 if compact_mobile else 16)
	margin.add_theme_constant_override("margin_bottom", 28 if compact_mobile else 16)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6 if compact_mobile else 10)
	margin.add_child(root)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 44 if compact_mobile else 54
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var brand := VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.add_theme_constant_override("separation", -2)
	var eyebrow := _label("A TACTICAL AUTOBATTLER", 10, Color("#ad8355"))
	eyebrow.add_theme_constant_override("outline_size", 1)
	brand.add_child(eyebrow)
	title_label = _label("", 27, Color("#f0c77a"))
	brand.add_child(title_label)
	header.add_child(brand)
	var round_panel := PanelContainer.new()
	_style(round_panel, Color("#1a1715"), 10, Color("#5f4931"), 1)
	var round_box := HBoxContainer.new()
	round_box.add_theme_constant_override("separation", 12)
	round_label = _label("", 16)
	phase_label = _label("", 15, Color("#f0c77a"))
	round_box.add_child(round_label)
	round_box.add_child(phase_label)
	round_panel.add_child(round_box)
	header.add_child(round_panel)
	language_button = _button("")
	language_button.custom_minimum_size = Vector2(100, 40)
	language_button.pressed.connect(_toggle_language)
	header.add_child(language_button)
	save_button = _button("")
	save_button.custom_minimum_size = Vector2(82, 40)
	save_button.pressed.connect(_save_game)
	header.add_child(save_button)
	load_button = _button("")
	load_button.custom_minimum_size = Vector2(82, 40)
	load_button.pressed.connect(_load_game)
	header.add_child(load_button)
	speed_button = _button("")
	speed_button.custom_minimum_size = Vector2(72, 40)
	speed_button.pressed.connect(_cycle_speed)
	header.add_child(speed_button)
	menu_button = _button("")
	menu_button.custom_minimum_size = Vector2(92, 40)
	menu_button.pressed.connect(_show_main_menu)
	header.add_child(menu_button)
	var workspace := HBoxContainer.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 6 if compact_mobile else 12)
	root.add_child(workspace)
	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size.x = 190 if compact_mobile else 252
	_style(sidebar, Color("#151719e8"), 14, Color("#594532"), 1)
	var sidebar_box := VBoxContainer.new()
	sidebar_box.add_theme_constant_override("separation", 10)
	var campaign_title := _label(t("战局总览", "MATCH OVERVIEW"), 18, Color("#f0c77a"))
	campaign_title.name = "CampaignTitle"
	sidebar_box.add_child(campaign_title)
	var bond_header := _label(t("我方羁绊进度", "YOUR BOND PROGRESS"), 13, Color("#ad8355"))
	bond_header.name = "BondHeader"
	sidebar_box.add_child(bond_header)
	bonds_label = RichTextLabel.new()
	bonds_label.bbcode_enabled = true
	bonds_label.scroll_active = true
	bonds_label.custom_minimum_size.y = 120 if compact_mobile else 210
	bonds_label.add_theme_font_size_override("normal_font_size", 13)
	bonds_label.add_theme_color_override("default_color", Color("#d8cfbd"))
	_enable_touch_value_scroll(bonds_label)
	sidebar_box.add_child(bonds_label)
	log_title_label = _label("", 13, Color("#ad8355"))
	sidebar_box.add_child(log_title_label)
	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.scroll_active = true
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.add_theme_font_size_override("normal_font_size", 12)
	log_box.add_theme_color_override("default_color", Color("#bcb5a9"))
	_enable_touch_value_scroll(log_box)
	sidebar_box.add_child(log_box)
	sidebar.add_child(sidebar_box)
	workspace.add_child(sidebar)
	var arena := PanelContainer.new()
	arena.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style(arena, Color("#1a1815ef"), 14, Color("#68513a"), 1)
	var arena_box := VBoxContainer.new()
	arena_box.add_theme_constant_override("separation", 2 if compact_mobile else 6)
	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 10)
	time_row.alignment = BoxContainer.ALIGNMENT_CENTER
	battle_time_label = _label("", 15, Color("#f0c77a"))
	battle_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_time_label.custom_minimum_size = Vector2(80, 0)
	time_row.add_child(battle_time_label)
	battle_time_bar = ProgressBar.new()
	battle_time_bar.show_percentage = false
	battle_time_bar.custom_minimum_size = Vector2(0, 16)
	battle_time_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_time_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var time_bg := StyleBoxFlat.new()
	time_bg.bg_color = Color("#0d1115")
	time_bg.corner_radius_top_left = 4
	time_bg.corner_radius_top_right = 4
	time_bg.corner_radius_bottom_left = 4
	time_bg.corner_radius_bottom_right = 4
	var time_fill := StyleBoxFlat.new()
	time_fill.bg_color = Color("#e8a04f")
	time_fill.corner_radius_top_left = 4
	time_fill.corner_radius_top_right = 4
	time_fill.corner_radius_bottom_left = 4
	time_fill.corner_radius_bottom_right = 4
	battle_time_bar.add_theme_stylebox_override("background", time_bg)
	battle_time_bar.add_theme_stylebox_override("fill", time_fill)
	time_row.add_child(battle_time_bar)
	arena_box.add_child(time_row)
	enemy_title_label = _label("", 14, Color("#d89a8f"))
	enemy_title_label.visible = not compact_mobile
	arena_box.add_child(enemy_title_label)
	enemy_board = _board_grid()
	var enemy_formation := HBoxContainer.new()
	enemy_formation.add_theme_constant_override("separation", 8)
	enemy_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_formation.add_child(enemy_board)
	enemy_formation.add_child(_ruler_rail(false))
	arena_box.add_child(enemy_formation)
	enemy_roster_label = _label("", 11, Color("#887e70"))
	enemy_roster_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	enemy_roster_label.visible = not compact_mobile
	arena_box.add_child(enemy_roster_label)
	var lane := PanelContainer.new()
	lane.custom_minimum_size.y = 18 if compact_mobile else 42
	_style(lane, Color("#241c16"), 8, Color("#8e673d"), 1)
	var lane_box := HBoxContainer.new()
	lane_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var lane_line_left := HSeparator.new()
	lane_line_left.custom_minimum_size.x = 70
	lane_box.add_child(lane_line_left)
	phase_caption_label = _label("", 13, Color("#f0c77a"))
	phase_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_caption_label.custom_minimum_size.x = 260
	phase_caption_label.visible = not compact_mobile
	lane_box.add_child(phase_caption_label)
	var lane_line_right := HSeparator.new()
	lane_line_right.custom_minimum_size.x = 70
	lane_box.add_child(lane_line_right)
	lane.add_child(lane_box)
	arena_box.add_child(lane)
	player_title_label = _label("", 14, Color("#90c59e"))
	player_title_label.visible = not compact_mobile
	arena_box.add_child(player_title_label)
	player_board = _board_grid()
	var player_formation := HBoxContainer.new()
	player_formation.add_theme_constant_override("separation", 8)
	player_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_formation.add_child(player_board)
	player_formation.add_child(_ruler_rail(true))
	arena_box.add_child(player_formation)
	roster_label = _label("", 11, Color("#887e70"))
	roster_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	roster_label.visible = not compact_mobile
	arena_box.add_child(roster_label)
	arena.add_child(arena_box)
	workspace.add_child(arena)
	var command := PanelContainer.new()
	command.custom_minimum_size.x = 285 if compact_mobile else 380
	_style(command, Color("#151719ee"), 14, Color("#594532"), 1)
	var command_box := VBoxContainer.new()
	command_box.add_theme_constant_override("separation", 8)
	draft_title_label = _label("", 18, Color("#f0c77a"))
	command_box.add_child(draft_title_label)
	hint_label = _label("", 12, Color("#aaa294"))
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size.y = 36
	hint_label.visible = not compact_mobile
	command_box.add_child(hint_label)
	stats_title_label = _label("", 13, Color("#ad8355"))
	command_box.add_child(stats_title_label)
	var stats_tabs := HBoxContainer.new()
	stats_tabs.add_theme_constant_override("separation", 4)
	for metric in ["damage", "healing", "control", "taken"]:
		var tab := _button("")
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", 11)
		tab.pressed.connect(_set_stats_metric.bind(metric))
		stats_tab_buttons[metric] = tab
		stats_tabs.add_child(tab)
	command_box.add_child(stats_tabs)
	var stats_scroll := ScrollContainer.new()
	stats_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_scroll.custom_minimum_size.y = 96 if compact_mobile else 420
	_enable_touch_scroll(stats_scroll, false, true)
	command_box.add_child(stats_scroll)
	stats_chart = VBoxContainer.new()
	stats_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_chart.add_theme_constant_override("separation", 7)
	stats_scroll.add_child(stats_chart)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	draft_toggle_button = _button("")
	draft_toggle_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	draft_toggle_button.pressed.connect(_toggle_draft_layer)
	actions.add_child(draft_toggle_button)
	auto_button = _button("")
	auto_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_button.pressed.connect(_auto_place_player)
	actions.add_child(auto_button)
	battle_button = _button("")
	battle_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_button.pressed.connect(_start_battle)
	actions.add_child(battle_button)
	battle_pause_button = _button("")
	battle_pause_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_pause_button.pressed.connect(_toggle_battle_pause)
	battle_pause_button.hide()
	actions.add_child(battle_pause_button)
	command_box.add_child(actions)
	command.add_child(command_box)
	workspace.add_child(command)
	var reserve_panel := PanelContainer.new()
	reserve_panel.custom_minimum_size.y = 142 if compact_mobile else 108
	_style(reserve_panel, Color("#151719ee"), 12, Color("#594532"), 1)
	var reserve_row := HBoxContainer.new()
	reserve_row.add_theme_constant_override("separation", 10)
	reserve_panel.add_child(reserve_row)
	reserve_title_label = _label("", 14, Color("#f0c77a"))
	reserve_title_label.custom_minimum_size.x = 96 if compact_mobile else 115
	reserve_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reserve_row.add_child(reserve_title_label)
	var reserve_scroll := ScrollContainer.new()
	reserve_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	reserve_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	reserve_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enable_touch_scroll(reserve_scroll, true, false)
	reserve_row.add_child(reserve_scroll)
	reserve_box = HBoxContainer.new()
	reserve_box.add_theme_constant_override("separation", 6)
	reserve_scroll.add_child(reserve_box)
	root.add_child(reserve_panel)
	tick_timer = Timer.new()
	tick_timer.wait_time = TICK
	tick_timer.timeout.connect(_battle_tick)
	add_child(tick_timer)
	_build_draft_layer()

func _ruler_card(is_player: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	_style(panel, Color("#20201d"), 9, Color("#4c463c"), 1)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var caption := _label("", 11, Color("#9c9180"))
	caption.name = "Caption"
	box.add_child(caption)
	var hp := _label("", 21, Color("#f4dfad"))
	box.add_child(hp)
	panel.add_child(box)
	if is_player: player_hp_label = hp
	else: enemy_hp_label = hp
	return panel

func _ruler_rail(is_player: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(58 if _is_mobile_ui() else 76, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style(panel, Color("#100e0de8"), 10, Color("#b68a4f" if is_player else "#9c4c48"), 2)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 5)
	var seal := _label("主\n公" if is_player else "敌\n将", 17, Color("#f0c77a" if is_player else "#e89b91"))
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(seal)
	var gauge := Control.new()
	gauge.custom_minimum_size = Vector2(42, 150)
	gauge.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var well := ColorRect.new()
	well.color = Color("#211a17")
	well.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gauge.add_child(well)
	var fill := ColorRect.new()
	fill.color = Color("#4fc77a") if is_player else Color("#d9534f")
	fill.anchor_left = 0.14
	fill.anchor_right = 0.86
	fill.anchor_top = 0.0
	fill.anchor_bottom = 1.0
	fill.offset_left = 0
	fill.offset_right = 0
	fill.offset_top = 0
	fill.offset_bottom = 0
	gauge.add_child(fill)
	var shine := ColorRect.new()
	shine.color = Color(1, 0.86, 0.56, 0.20)
	shine.anchor_left = 0.18
	shine.anchor_right = 0.36
	shine.anchor_top = 0.03
	shine.anchor_bottom = 0.97
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge.add_child(shine)
	box.add_child(gauge)
	var caption := _label("", 10, Color("#b9aa94"))
	caption.name = "Caption"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(caption)
	var hp := _label("", 12, Color("#f4dfad"))
	hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hp)
	panel.add_child(box)
	if is_player:
		player_hp_label = hp
		player_ruler_fill = fill
	else:
		enemy_hp_label = hp
		enemy_ruler_fill = fill
	return panel

func _board_grid() -> GridContainer:
	var board := GridContainer.new()
	board.columns = BOARD_COLUMNS
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.add_theme_constant_override("h_separation", 6)
	board.add_theme_constant_override("v_separation", 6)
	return board

func _build_draft_layer() -> void:
	draft_layer = CanvasLayer.new()
	draft_layer.layer = 20
	add_child(draft_layer)
	draft_overlay = ColorRect.new()
	draft_overlay.color = Color("#080a0dcc")
	draft_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	draft_layer.add_child(draft_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	draft_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1500, 650)
	_style(panel, Color("#171513"), 18, Color("#8e673d"), 2)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var header := HBoxContainer.new()
	var title := _label(t("本轮招募 · 三轮二选一", "ROUND RECRUITMENT · THREE PICK-ONE-OF-TWO ROUNDS"), 25, Color("#f0c77a"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := _button(t("暂时隐藏", "HIDE"))
	close.custom_minimum_size = Vector2(120, 42)
	close.pressed.connect(_hide_draft_layer)
	header.add_child(close)
	box.add_child(header)
	draft_box = HBoxContainer.new()
	draft_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	draft_box.add_theme_constant_override("separation", 12)
	box.add_child(draft_box)

func _hide_draft_layer() -> void:
	draft_user_hidden = true
	draft_overlay.hide()

func _toggle_draft_layer() -> void:
	if phase != "draft": return
	draft_user_hidden = not draft_user_hidden
	draft_overlay.visible = not draft_user_hidden

func _set_stats_metric(metric: String) -> void:
	stats_metric = metric
	_render_battle_stats()

func _build_main_menu() -> void:
	var mobile := _is_mobile_ui()
	menu_overlay = ColorRect.new()
	menu_overlay.color = Color("#090b0ff5")
	menu_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_overlay.z_index = 1000
	add_child(menu_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 680) if mobile else Vector2(520, 520)
	_style(panel, Color("#171412"), 18, Color("#8e673d"), 2)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20 if mobile else 18)
	panel.add_child(box)
	var eyebrow := _label("A THREE KINGDOMS AUTOBATTLER", 12, Color("#ad8355"))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(eyebrow)
	var menu_title := _label("三国 · 羁绊战棋", 48 if mobile else 38, Color("#f0c77a"))
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(menu_title)
	var subtitle := _label("征战十五轮 · 构筑阵容 · 最终决战\n15 rounds of preparation, then the final battle", 15, Color("#c9c0b1"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	var new_button := _button("开始游戏  /  NEW GAME")
	new_button.custom_minimum_size = Vector2(500, 68) if mobile else Vector2(320, 56)
	new_button.add_theme_font_size_override("font_size", 20 if mobile else 16)
	new_button.pressed.connect(_start_new_from_menu)
	box.add_child(new_button)
	continue_button = _button("继续游戏  /  CONTINUE")
	continue_button.custom_minimum_size = Vector2(500, 68) if mobile else Vector2(320, 56)
	continue_button.add_theme_font_size_override("font_size", 20 if mobile else 16)
	continue_button.disabled = not FileAccess.file_exists(SAVE_PATH)
	continue_button.pressed.connect(_continue_from_menu)
	box.add_child(continue_button)
	var codex_button := _button("图鉴  /  CODEX")
	codex_button.custom_minimum_size = Vector2(500, 68) if mobile else Vector2(320, 56)
	codex_button.add_theme_font_size_override("font_size", 20 if mobile else 16)
	codex_button.pressed.connect(_show_encyclopedia)
	box.add_child(codex_button)
	var lab_button := _button("平衡实验室  /  BALANCE LAB")
	lab_button.custom_minimum_size = Vector2(500, 68) if mobile else Vector2(320, 56)
	lab_button.add_theme_font_size_override("font_size", 20 if mobile else 16)
	lab_button.pressed.connect(_show_balance_lab)
	box.add_child(lab_button)
	var settings_button := _button("游戏设置  /  SETTINGS")
	settings_button.custom_minimum_size = Vector2(500, 68) if mobile else Vector2(320, 56)
	settings_button.add_theme_font_size_override("font_size", 20 if mobile else 16)
	settings_button.pressed.connect(_show_settings)
	box.add_child(settings_button)
	var note := _label("准备阶段可随时保存或读取进度", 12, Color("#887e70"))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	_build_encyclopedia()
	_build_settings_overlay()
	_build_balance_lab()
	draft_overlay.hide()

func _build_settings_overlay() -> void:
	settings_overlay = ColorRect.new()
	settings_overlay.color = Color("#090b0ffa")
	settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_overlay.z_index = 1200
	settings_overlay.hide()
	add_child(settings_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 640)
	_style(panel, Color("#171513"), 18, Color("#8e673d"), 2)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	panel.add_child(box)
	var title := _label(t("游戏设置", "SETTINGS"), 30, Color("#f0c77a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var pause_help := _label(t("行动演出期间是否冻结其他武将的行动条和状态计时", "Freeze all gauges and status timers during action animations"), 14, Color("#c9c0b1"))
	pause_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(pause_help)
	pause_setting_button = _button("")
	pause_setting_button.custom_minimum_size = Vector2(360, 54)
	pause_setting_button.pressed.connect(_toggle_pause_setting)
	box.add_child(pause_setting_button)
	speed_setting_button = _button("")
	speed_setting_button.custom_minimum_size = Vector2(360, 54)
	speed_setting_button.pressed.connect(_cycle_speed)
	box.add_child(speed_setting_button)
	var codex_image_help := _label(t("控制武将图鉴卡片和放大介绍中是否显示武将立绘；武器图鉴不受影响。", "Show or hide hero artwork on hero-codex cards and enlarged entries; the weapon codex is unaffected."), 14, Color("#c9c0b1"))
	codex_image_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	codex_image_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(codex_image_help)
	hero_codex_images_setting_button = _button("")
	hero_codex_images_setting_button.custom_minimum_size = Vector2(360, 54)
	hero_codex_images_setting_button.pressed.connect(_toggle_hero_codex_images_setting)
	box.add_child(hero_codex_images_setting_button)
	var faction_help := _label(t("测试招募阵营：关闭时可刷出全部阵营；开启后商店只会出现指定阵营武将。", "Test draft faction: Off allows all factions; a selected faction restricts shop rolls."), 14, Color("#c9c0b1"))
	faction_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	faction_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(faction_help)
	faction_setting_options = OptionButton.new()
	faction_setting_options.custom_minimum_size = Vector2(360, 48)
	faction_setting_options.add_item(t("指定阵营：关闭", "Draft faction: Off"), 0)
	for faction in ["shu", "wei", "wu", "qun"]:
		faction_setting_options.add_item(_faction_name(faction), faction_setting_options.get_item_count())
	faction_setting_options.item_selected.connect(_set_draft_faction_filter)
	box.add_child(faction_setting_options)
	var close := _button(t("保存并返回", "SAVE & BACK"))
	close.custom_minimum_size = Vector2(240, 48)
	close.pressed.connect(_close_settings)
	box.add_child(close)
	_refresh_settings_ui()

func _show_settings() -> void:
	_refresh_settings_ui()
	settings_overlay.show()

func _close_settings() -> void:
	_save_settings()
	settings_overlay.hide()

func _toggle_pause_setting() -> void:
	pause_during_actions = not pause_during_actions
	_refresh_settings_ui()

func _cycle_speed() -> void:
	game_speed = 2.0 if game_speed == 1.0 else (4.0 if game_speed == 2.0 else 1.0)
	battle_speed = game_speed
	_save_settings()
	_refresh_settings_ui()
	if is_instance_valid(speed_button): speed_button.text = str(int(game_speed)) + "×"

func _toggle_hero_codex_images_setting() -> void:
	show_hero_codex_images = not show_hero_codex_images
	_save_settings()
	_refresh_settings_ui()
	if is_instance_valid(encyclopedia_overlay) and encyclopedia_overlay.visible and encyclopedia_mode == "heroes":
		_render_encyclopedia()
		if is_instance_valid(encyclopedia_preview_overlay) and encyclopedia_preview_overlay.visible:
			_refresh_encyclopedia_preview()

func _refresh_settings_ui() -> void:
	if is_instance_valid(pause_setting_button): pause_setting_button.text = t("行动期间全场暂停：", "Pause during actions: ") + t("开启", "ON") if pause_during_actions else t("行动期间全场暂停：关闭", "Pause during actions: OFF")
	if is_instance_valid(speed_setting_button): speed_setting_button.text = t("游戏速度：", "Game speed: ") + str(int(game_speed)) + "×"
	if is_instance_valid(hero_codex_images_setting_button):
		hero_codex_images_setting_button.text = t("武将图鉴显示图片：开启", "Hero codex artwork: ON") if show_hero_codex_images else t("武将图鉴显示图片：关闭", "Hero codex artwork: OFF")
	if is_instance_valid(faction_setting_options):
		var factions := ["", "shu", "wei", "wu", "qun"]
		faction_setting_options.select(factions.find(draft_faction_filter))

func _set_draft_faction_filter(index: int) -> void:
	var factions := ["", "shu", "wei", "wu", "qun"]
	draft_faction_filter = factions[clampi(index, 0, factions.size() - 1)]
	_save_settings()
	if phase == "draft": _generate_choices()
	_refresh_settings_ui()
	_render()

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		pause_during_actions = bool(config.get_value("battle", "pause_during_actions", true))
		game_speed = float(config.get_value("battle", "speed", 1.0))
		draft_faction_filter = str(config.get_value("battle", "draft_faction_filter", ""))
		show_hero_codex_images = bool(config.get_value("interface", "show_hero_codex_images", false))
		if game_speed not in [1.0, 2.0, 4.0]: game_speed = 1.0
		if draft_faction_filter not in ["", "shu", "wei", "wu", "qun"]: draft_faction_filter = ""
	battle_speed = game_speed

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("battle", "pause_during_actions", pause_during_actions)
	config.set_value("battle", "speed", game_speed)
	config.set_value("battle", "draft_faction_filter", draft_faction_filter)
	config.set_value("interface", "show_hero_codex_images", show_hero_codex_images)
	config.save(SETTINGS_PATH)

func _build_encyclopedia() -> void:
	var mobile := _is_mobile_ui()
	encyclopedia_overlay = ColorRect.new()
	encyclopedia_overlay.color = Color("#090b0ffa")
	encyclopedia_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	encyclopedia_overlay.z_index = 1100
	encyclopedia_overlay.hide()
	add_child(encyclopedia_overlay)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12 if mobile else 90)
	margin.add_theme_constant_override("margin_right", 12 if mobile else 90)
	margin.add_theme_constant_override("margin_top", 12 if mobile else 50)
	margin.add_theme_constant_override("margin_bottom", 24 if mobile else 50)
	encyclopedia_overlay.add_child(margin)
	var panel := PanelContainer.new()
	_style(panel, Color("#171513"), 18, Color("#8e673d"), 2)
	margin.add_child(panel)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 12)
	panel.add_child(root_box)
	var header := HBoxContainer.new()
	encyclopedia_title_label = _label(t("武将图鉴", "HERO CODEX"), 25 if mobile else 28, Color("#f0c77a"))
	encyclopedia_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(encyclopedia_title_label)
	encyclopedia_hero_tab_button = _button(t("武将图鉴", "HERO CODEX"))
	encyclopedia_hero_tab_button.custom_minimum_size = Vector2(150, 42)
	encyclopedia_hero_tab_button.pressed.connect(_set_encyclopedia_mode.bind("heroes"))
	header.add_child(encyclopedia_hero_tab_button)
	encyclopedia_weapon_tab_button = _button(t("武器图鉴", "WEAPON CODEX"))
	encyclopedia_weapon_tab_button.custom_minimum_size = Vector2(150, 42)
	encyclopedia_weapon_tab_button.pressed.connect(_set_encyclopedia_mode.bind("weapons"))
	header.add_child(encyclopedia_weapon_tab_button)
	encyclopedia_bond_tab_button = _button(t("羁绊图", "BOND GRAPH"))
	encyclopedia_bond_tab_button.custom_minimum_size = Vector2(135, 42)
	encyclopedia_bond_tab_button.pressed.connect(_set_encyclopedia_mode.bind("bonds"))
	header.add_child(encyclopedia_bond_tab_button)
	var close_button := _button(t("返回主菜单", "BACK"))
	close_button.custom_minimum_size = Vector2(130, 42)
	close_button.pressed.connect(func(): encyclopedia_overlay.hide())
	header.add_child(close_button)
	root_box.add_child(header)
	encyclopedia_hero_filters = HBoxContainer.new()
	encyclopedia_hero_filters.add_theme_constant_override("separation", 8)
	root_box.add_child(encyclopedia_hero_filters)
	var filter_spacer := Control.new()
	filter_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	encyclopedia_hero_filters.add_child(filter_spacer)
	for level in [1, 2, 3]:
		var star_button := _button("★".repeat(level))
		star_button.custom_minimum_size = Vector2(70, 42)
		star_button.tooltip_text = t("查看%d星属性与技能数值" % level, "View %d-star stats and skill values" % level)
		star_button.pressed.connect(_set_encyclopedia_star.bind(level))
		encyclopedia_hero_filters.add_child(star_button)
		encyclopedia_star_filter_buttons.append(star_button)
	encyclopedia_bond_reset_button = _button(t("重置布局", "RESET LAYOUT"))
	encyclopedia_bond_reset_button.custom_minimum_size = Vector2(120, 42)
	encyclopedia_bond_reset_button.pressed.connect(_render_encyclopedia_bond_graph)
	encyclopedia_bond_reset_button.hide()
	encyclopedia_hero_filters.add_child(encyclopedia_bond_reset_button)
	for faction in ["shu", "wei", "wu", "qun"]:
		var faction_button := _button(_faction_name(faction))
		faction_button.custom_minimum_size = Vector2(90, 42)
		faction_button.pressed.connect(_set_encyclopedia_faction.bind(faction))
		encyclopedia_hero_filters.add_child(faction_button)
	encyclopedia_bond_label = _label("", 14, Color("#e3c58c"))
	encyclopedia_bond_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	encyclopedia_bond_label.custom_minimum_size.y = 88
	root_box.add_child(encyclopedia_bond_label)
	encyclopedia_content_scroll = ScrollContainer.new()
	encyclopedia_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_enable_touch_scroll(encyclopedia_content_scroll, false, true)
	root_box.add_child(encyclopedia_content_scroll)
	encyclopedia_grid = GridContainer.new()
	encyclopedia_grid.columns = 2 if mobile else 3
	encyclopedia_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	encyclopedia_grid.add_theme_constant_override("h_separation", 12)
	encyclopedia_content_scroll.add_child(encyclopedia_grid)
	encyclopedia_bond_graph = GraphEdit.new()
	encyclopedia_bond_graph.name = "EncyclopediaBondGraph"
	encyclopedia_bond_graph.custom_minimum_size = Vector2(0, 560)
	encyclopedia_bond_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	encyclopedia_bond_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	encyclopedia_bond_graph.show_grid = true
	encyclopedia_bond_graph.minimap_enabled = true
	encyclopedia_bond_graph.show_zoom_label = true
	encyclopedia_bond_graph.show_arrange_button = false
	encyclopedia_bond_graph.connection_lines_curvature = 0.42
	encyclopedia_bond_graph.connection_lines_thickness = 2.0
	encyclopedia_bond_graph.gui_input.connect(_on_bond_graph_touch)
	if mobile: encyclopedia_bond_graph.set_meta("touch_pan_enabled", true)
	encyclopedia_bond_graph.node_selected.connect(_on_encyclopedia_bond_node_selected)
	encyclopedia_bond_graph.node_deselected.connect(_on_encyclopedia_bond_node_deselected)
	encyclopedia_bond_graph.hide()
	root_box.add_child(encyclopedia_bond_graph)
	_build_encyclopedia_preview()

func _show_encyclopedia() -> void:
	encyclopedia_overlay.show()
	_render_encyclopedia()

func _set_encyclopedia_mode(mode: String) -> void:
	if mode not in ["heroes", "weapons", "bonds"]: return
	_hide_encyclopedia_preview()
	encyclopedia_mode = mode
	_render_encyclopedia()

func _set_encyclopedia_faction(faction: String) -> void:
	_hide_encyclopedia_preview()
	encyclopedia_faction = faction
	_render_encyclopedia()

func _set_encyclopedia_star(level: int) -> void:
	encyclopedia_star_level = clampi(level, 1, 3)
	_render_encyclopedia()

func _build_encyclopedia_preview() -> void:
	var mobile := _is_mobile_ui()
	encyclopedia_preview_overlay = ColorRect.new()
	encyclopedia_preview_overlay.color = Color("#020304e8")
	encyclopedia_preview_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	encyclopedia_preview_overlay.z_index = 20
	encyclopedia_preview_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	encyclopedia_preview_overlay.focus_mode = Control.FOCUS_ALL
	encyclopedia_preview_overlay.gui_input.connect(_on_encyclopedia_preview_backdrop_input)
	encyclopedia_preview_overlay.hide()
	encyclopedia_overlay.add_child(encyclopedia_preview_overlay)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12 if mobile else 150)
	margin.add_theme_constant_override("margin_right", 12 if mobile else 150)
	margin.add_theme_constant_override("margin_top", 16 if mobile else 32)
	margin.add_theme_constant_override("margin_bottom", 28 if mobile else 32)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	encyclopedia_preview_overlay.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var previous_button := _button("<")
	previous_button.custom_minimum_size = Vector2(70, 120) if mobile else Vector2(88, 110)
	previous_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	previous_button.tooltip_text = t("上一项", "Previous entry")
	previous_button.pressed.connect(_step_encyclopedia_preview.bind(-1))
	row.add_child(previous_button)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_style(panel, Color("#171513"), 18, Color("#b88a50"), 2)
	row.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	encyclopedia_preview_name = _label("", 30, Color("#f0c77a"))
	encyclopedia_preview_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	encyclopedia_preview_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(encyclopedia_preview_name)
	var close_button := _button("×")
	close_button.custom_minimum_size = Vector2(54, 48)
	close_button.tooltip_text = t("关闭放大预览", "Close enlarged preview")
	close_button.pressed.connect(_hide_encyclopedia_preview)
	header.add_child(close_button)

	var preview_columns := HBoxContainer.new()
	preview_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_columns.add_theme_constant_override("separation", 24)
	content.add_child(preview_columns)

	encyclopedia_preview_portrait = TextureRect.new()
	encyclopedia_preview_portrait.custom_minimum_size = Vector2(500, 620) if mobile else Vector2(430, 620)
	encyclopedia_preview_portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	encyclopedia_preview_portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	encyclopedia_preview_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	encyclopedia_preview_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	encyclopedia_preview_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_columns.add_child(encyclopedia_preview_portrait)

	encyclopedia_preview_separator = VSeparator.new()
	encyclopedia_preview_separator.add_theme_constant_override("separation", 2)
	preview_columns.add_child(encyclopedia_preview_separator)

	var detail_scroll := ScrollContainer.new()
	detail_scroll.custom_minimum_size = Vector2(500, 620) if mobile else Vector2(430, 620)
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.tooltip_text = t("滚动查看完整武将介绍", "Scroll to read the complete hero entry")
	_enable_touch_scroll(detail_scroll, false, true)
	preview_columns.add_child(detail_scroll)
	encyclopedia_preview_detail = _label("", 16, Color("#ddd5c5"))
	encyclopedia_preview_detail.custom_minimum_size.x = 400
	encyclopedia_preview_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	encyclopedia_preview_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	encyclopedia_preview_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	encyclopedia_preview_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_scroll.add_child(encyclopedia_preview_detail)

	encyclopedia_preview_counter = _label("", 15, Color("#c9c0b1"))
	encyclopedia_preview_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(encyclopedia_preview_counter)

	var next_button := _button(">")
	next_button.custom_minimum_size = Vector2(70, 120) if mobile else Vector2(88, 110)
	next_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next_button.tooltip_text = t("下一项", "Next entry")
	next_button.pressed.connect(_step_encyclopedia_preview.bind(1))
	row.add_child(next_button)

func _on_encyclopedia_card_input(event: InputEvent, hero_id: String) -> void:
	if event is InputEventMouseButton and not _is_mobile_ui() and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_show_encyclopedia_preview(hero_id)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_encyclopedia_touch_origins[event.index] = {"position":event.position, "hero_id":hero_id, "dragged":false}
		else:
			var touch: Dictionary = _encyclopedia_touch_origins.get(event.index, {})
			_encyclopedia_touch_origins.erase(event.index)
			if not touch.is_empty() and str(touch.get("hero_id", "")) == hero_id and not bool(touch.get("dragged", false)) and Vector2(touch.position).distance_to(event.position) < 18.0:
				_show_encyclopedia_preview(hero_id)
	elif event is InputEventScreenDrag and _encyclopedia_touch_origins.has(event.index):
		var touch: Dictionary = _encyclopedia_touch_origins[event.index]
		if Vector2(touch.position).distance_to(event.position) >= 18.0:
			touch.dragged = true
			_encyclopedia_touch_origins[event.index] = touch

func _show_encyclopedia_preview(hero_id: String) -> void:
	if not encyclopedia_preview_hero_ids.has(hero_id):
		return
	encyclopedia_preview_index = encyclopedia_preview_hero_ids.find(hero_id)
	_refresh_encyclopedia_preview()
	encyclopedia_preview_overlay.show()
	encyclopedia_preview_overlay.grab_focus()

func _hide_encyclopedia_preview() -> void:
	if is_instance_valid(encyclopedia_preview_overlay):
		encyclopedia_preview_overlay.hide()

func _step_encyclopedia_preview(direction: int) -> void:
	if encyclopedia_preview_hero_ids.is_empty():
		return
	encyclopedia_preview_index = posmod(encyclopedia_preview_index + direction, encyclopedia_preview_hero_ids.size())
	_refresh_encyclopedia_preview()
	encyclopedia_preview_overlay.grab_focus()

func _weapon_codex_entry(owner_id: String) -> Dictionary:
	for entry in SHU_WEAPON_CODEX:
		if str(entry.id) == owner_id: return entry
	return {}

func _weapon_codex_name(entry: Dictionary) -> String:
	return str(entry.get("name_zh", "")) if language == "zh" else str(entry.get("name_en", entry.get("name_zh", "")))

func _weapon_codex_owner(entry: Dictionary) -> String:
	return str(entry.get("owner_zh", "")) if language == "zh" else str(entry.get("owner_en", entry.get("owner_zh", "")))

func _refresh_encyclopedia_preview() -> void:
	if encyclopedia_preview_hero_ids.is_empty():
		return
	var hero_id := encyclopedia_preview_hero_ids[encyclopedia_preview_index]
	if encyclopedia_mode == "weapons":
		var weapon := _weapon_codex_entry(hero_id)
		if weapon.is_empty(): return
		encyclopedia_preview_portrait.show()
		encyclopedia_preview_separator.show()
		encyclopedia_preview_portrait.texture = load(str(weapon.path))
		encyclopedia_preview_portrait.material = _weapon_cutout_material()
		encyclopedia_preview_name.text = _weapon_codex_name(weapon)
		encyclopedia_preview_name.add_theme_color_override("font_color", FACTION_COLORS.shu.lightened(0.32))
		encyclopedia_preview_detail.text = (
			t("武器名称：", "Weapon: ") + _weapon_codex_name(weapon) + "\n\n"
			+ t("归属武将：", "Owner: ") + _weapon_codex_owner(weapon) + "\n\n"
			+ t("所属阵营：蜀", "Faction: Shu") + "\n\n"
			+ t("类型：专属武器", "Type: Signature weapon")
		)
		encyclopedia_preview_counter.text = str(encyclopedia_preview_index + 1) + " / " + str(encyclopedia_preview_hero_ids.size()) + t("　点击 < > 切换武器", "　Use < > to browse weapons")
		return
	var hero: Dictionary = heroes[hero_id]
	encyclopedia_preview_portrait.visible = show_hero_codex_images
	encyclopedia_preview_separator.visible = show_hero_codex_images
	encyclopedia_preview_portrait.texture = _portrait_source_texture(hero_id) if show_hero_codex_images else null
	encyclopedia_preview_portrait.material = null
	encyclopedia_preview_name.text = _hero_name(hero_id) + "  " + "★".repeat(encyclopedia_star_level)
	encyclopedia_preview_name.add_theme_color_override("font_color", FACTION_COLORS[hero.f].lightened(0.32))
	var stat_mult := _star_stat_multiplier(encyclopedia_star_level)
	encyclopedia_preview_detail.text = (
		t("阵营：", "Faction: ") + _faction_name(hero.f) + "\n"
		+ t("定位：", "Roles: ") + _roles_text(hero.roles) + "\n"
		+ t("生命：", "HP: ") + str(round(float(hero.hp) * stat_mult)) + "\n"
		+ t("军种：", "Rank: ") + _hero_army_name(hero_id) + (t("（任意布阵）", " (any formation row)") if bool(hero.get("all_rows", false)) else "（" + str(hero.range) + "）") + "\n"
		+ t("技能冷却：", "Skill cooldown: ") + str(hero.cooldown) + t(" 秒", "s") + "\n\n"
		+ t("技能：", "Skill: ") + (str(hero.zh_skill) if language == "zh" else str(hero.skill)) + "\n"
		+ _skill_detail(hero_id) + "\n\n"
		+ _star_skill_values(hero_id, encyclopedia_star_level) + "\n\n"
		+ _hero_bond_detail(hero_id)
	)
	encyclopedia_preview_counter.text = str(encyclopedia_preview_index + 1) + " / " + str(encyclopedia_preview_hero_ids.size()) + t("　点击 < > 切换武将", "　Use < > to browse heroes")

func _on_encyclopedia_preview_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_hide_encyclopedia_preview()

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_instance_valid(encyclopedia_preview_overlay) or not encyclopedia_preview_overlay.visible:
		return
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE:
			_hide_encyclopedia_preview()
			get_viewport().set_input_as_handled()
		KEY_LEFT:
			_step_encyclopedia_preview(-1)
			get_viewport().set_input_as_handled()
		KEY_RIGHT:
			_step_encyclopedia_preview(1)
			get_viewport().set_input_as_handled()

func _star_skill_values(hero_id: String, level: int) -> String:
	var hero: Dictionary = heroes[hero_id]
	var params: Dictionary = hero.get("ability_params", {})
	var ability: String = hero.get("ability", "")
	var stat_mult := _star_stat_multiplier(level)
	var effect_mult := _star_effect_multiplier(level)
	var skill_base := float(hero.skill_value) * stat_mult
	var values: Array[String] = []
	if hero_id == "liubei":
		var heal_ratio := float(params.get("heal_ratio", 2.0))
		var duration := float(params.get("duration", 4.0))
		values.append(t("每秒治疗%d，持续%.1f秒，总计%d" % [round(skill_base * heal_ratio), duration, round(skill_base * heal_ratio * duration)], "Heal %d each second for %.1fs, total %d" % [round(skill_base * heal_ratio), duration, round(skill_base * heal_ratio * duration)]))
	elif hero_id == "zhangfei":
		var damage_by_star: Array = params.get("damage_by_star", [0.15, 0.20, 0.30])
		if damage_by_star.is_empty(): damage_by_star = [0.15, 0.20, 0.30]
		var damage_bonus := float(damage_by_star[clampi(level, 1, mini(3, damage_by_star.size())) - 1]) * 100.0
		values.append(t("前排增伤%.0f%%，持续%.1f秒" % [damage_bonus, float(params.get("duration", 3.0))], "Front row +%.0f%% damage for %.1fs" % [damage_bonus, float(params.get("duration", 3.0))]))
	elif hero_id == "guanyu": values.append(t("整列每名敌人受到%d真实伤害" % round(skill_base * float(params.get("mult", 1.8))), "Each enemy in the column takes %d true damage" % round(skill_base * float(params.get("mult", 1.8)))))
	elif hero_id == "zhaoyun":
		var hit_damage: int = roundi(skill_base * 0.50)
		values.append(t("基础连刺5次，每次%d伤害，总计%d" % [hit_damage, hit_damage * 5], "5 base thrusts for %d each, %d total" % [hit_damage, hit_damage * 5]))
	elif hero_id == "liushan":
		var damage_by_star: Array = params.get("damage_by_star", [0.25, 0.35, 0.55])
		values.append(t("同列前军增伤%.0f%%，持续4秒" % (float(damage_by_star[clampi(level, 1, damage_by_star.size()) - 1]) * 100.0), "Same-column vanguard gains %.0f%% damage for 4s" % (float(damage_by_star[clampi(level, 1, damage_by_star.size()) - 1]) * 100.0)))
	elif hero_id == "huangzhong": values.append(t("大招造成%d真实伤害" % round(skill_base * float(params.get("active_mult", 2.0))), "Active deals %d true damage" % round(skill_base * float(params.get("active_mult", 2.0)))))
	elif hero_id == "machao":
		values.append(t("贯穿同列：前军%d / 中军%d / 后军%d伤害" % [round(skill_base * float(params.get("front_mult", 2.0))), round(skill_base * float(params.get("middle_mult", 1.7))), round(skill_base * float(params.get("back_mult", 1.4)))], "Column pierce: front %d / middle %d / rear %d damage" % [round(skill_base * float(params.get("front_mult", 2.0))), round(skill_base * float(params.get("middle_mult", 1.7))), round(skill_base * float(params.get("back_mult", 1.4)))]))
	elif hero_id == "madai":
		var ratios: Array = params.get("max_hp_ratios", [0.60, 0.70, 0.85])
		values.append(t("随机前军受到其最大生命%.0f%%伤害" % (float(ratios[clampi(level, 1, ratios.size()) - 1]) * 100.0), "A random frontliner takes %.0f%% of its max HP" % (float(ratios[clampi(level, 1, ratios.size()) - 1]) * 100.0)))
	elif hero_id == "weiyan":
		values.append(t("每个目标%d伤害；自身回复实际伤害40%%" % round(skill_base * float(params.get("mult", 1.8))), "%d damage per target; self-heal 40%% of actual damage" % round(skill_base * float(params.get("mult", 1.8)))))
	elif hero_id == "caocao": values.append(t("随机2人各%d伤害；眩晕%.2f秒" % [round(skill_base * float(params.get("mult", 2.0))), float(params.get("stun", 2.5)) * effect_mult], "2 random enemies take %d each; %.2fs stun" % [round(skill_base * float(params.get("mult", 2.0))), float(params.get("stun", 2.5)) * effect_mult]))
	elif hero_id == "dianwei": values.append(t("随机2名后军各%d物理伤害" % round(skill_base * float(params.get("mult", 2.0))), "2 random rearguards take %d physical damage each" % round(skill_base * float(params.get("mult", 2.0)))))
	elif hero_id == "xuchu": values.append(t("随机2名前军各%d物理伤害" % round(skill_base * float(params.get("mult", 2.0))), "2 random vanguards take %d physical damage each" % round(skill_base * float(params.get("mult", 2.0)))))
	elif hero_id == "zhangliao": values.append(t("同列每个格子往返各%d伤害" % round(skill_base * float(params.get("mult", 1.0))), "Each tile in the column takes %d on both passes" % round(skill_base * float(params.get("mult", 1.0)))))
	elif hero_id == "yuejin": values.append(t("随机3人各%d物理伤害" % round(skill_base * float(params.get("mult", 1.0))), "3 random enemies take %d physical damage each" % round(skill_base * float(params.get("mult", 1.0)))))
	elif hero_id == "xuhuang": values.append(t("前军整排每格%d伤害；眩晕%.2f秒" % [round(skill_base * float(params.get("mult", 1.25))), float(params.get("stun", 2.0)) * effect_mult], "Enemy vanguard row takes %d per tile; %.2fs stun" % [round(skill_base * float(params.get("mult", 1.25))), float(params.get("stun", 2.0)) * effect_mult]))
	elif hero_id == "zhanghe": values.append(t("前军目标%d伤害；眩晕%.2f秒" % [round(skill_base * float(params.get("mult", 2.0))), float(params.get("stun", 1.5)) * effect_mult], "Vanguard target takes %d; %.2fs stun" % [round(skill_base * float(params.get("mult", 2.0))), float(params.get("stun", 1.5)) * effect_mult]))
	elif hero_id == "yujin": values.append(t("最低当前生命友军获得200+3%%最大生命护盾", "Lowest-current-HP ally gains 200 + 3%% max-HP shield"))
	elif hero_id == "xiahouyuan": values.append(t("随机2人各%d伤害；已眩晕目标%d伤害；眩晕%.2f秒" % [round(skill_base * 1.75), round(skill_base * 2.50), 1.5 * effect_mult], "2 random enemies take %d each, or %d if stunned; %.2fs stun" % [round(skill_base * 1.75), round(skill_base * 2.50), 1.5 * effect_mult]))
	elif hero_id == "caoren": values.append(t("随机2名后军各%d伤害；眩晕%.2f秒；后军减伤20%%持续6秒" % [round(skill_base * 1.50), 1.5 * effect_mult], "2 rearguards take %d each; %.2fs stun; 20%% rear reduction for 6s" % [round(skill_base * 1.50), 1.5 * effect_mult]))
	elif hero_id == "xiahoudun": values.append(t("随机2名前军各%d伤害；眩晕%.2f秒；前军减伤20%%持续6.5秒" % [round(skill_base * 1.50), 1.5 * effect_mult], "2 vanguards take %d each; %.2fs stun; 20%% front reduction for 6.5s" % [round(skill_base * 1.50), 1.5 * effect_mult]))
	elif hero_id == "simayi": values.append(t("随机2人各%d雷击伤害" % round(skill_base * 1.75), "2 random enemies take %d lightning damage each" % round(skill_base * 1.75)))
	elif hero_id == "guojia": values.append(t("随机冻结2人%.2f秒；破冰伤害=剩余秒数×400" % (4.0 * effect_mult), "Freeze 2 enemies for %.2fs; shatter = remaining seconds × 400" % (4.0 * effect_mult)))
	elif hero_id == "xunyu": values.append(t("随机2名友军行动条速度+20%%，持续6秒", "2 random allies gain +20%% gauge speed for 6s"))
	elif hero_id == "jiaxu": values.append(t("随机2人中毒5秒，每秒损失1%%最大生命", "Poison 2 enemies for 5s at 1%% max HP per second"))
	elif hero_id == "sunjian": values.append(t("伤害等于实际消耗生命的100%%；通常消耗当前生命10%%，首次40%%", "Damage equals 100%% of HP spent; normally costs 10%% current HP, 40%% on the first cast"))
	elif hero_id == "sunce": values.append(t("正前方及左侧每格%d伤害；每损失10%%生命再增伤2%%" % round(skill_base * float(params.get("mult", 2.0))), "%d damage to the facing and left tiles; +2%% per 10%% HP missing" % round(skill_base * float(params.get("mult", 2.0)))))
	elif hero_id == "sunquan": values.append(t("随机敌军受到其当前生命8%%伤害；自身最大生命+200并恢复10%%已损生命；基础封顶%d" % round(float(hero.hp) * stat_mult * float(params.get("max_hp_cap_mult", 2.0))), "A random enemy takes 8%% current HP; gain 200 max HP and restore 10%% missing HP; base cap %d" % round(float(hero.hp) * stat_mult * float(params.get("max_hp_cap_mult", 2.0)))))
	elif hero_id == "sunshangxiang": values.append(t("随机敌军受到%d伤害；施法后技能强度+1" % round(skill_base * float(params.get("mult", 1.0))), "Deal %d to a random enemy; gain 1 SKILL after casting" % round(skill_base * float(params.get("mult", 1.0)))))
	elif hero_id == "taishici": values.append(t("行动条最高的2名敌人各受到%d伤害，并每秒灼烧%d，持续5秒" % [round(skill_base * float(params.get("mult", 1.5))), round(skill_base * float(params.get("burn_ratio", 0.20)))], "Top 2 gauge enemies each take %d damage and %d burn per second for 5s" % [round(skill_base * float(params.get("mult", 1.5))), round(skill_base * float(params.get("burn_ratio", 0.20)))]))
	elif hero_id == "ganning": values.append(t("甘宁与左侧友军各以自身技能强度造成150%%伤害", "Gan Ning and his left ally each deal 150%% of their own SKILL"))
	elif hero_id == "huanggai": values.append(t("消耗10%%最大生命；整列每格受到消耗生命33%%的伤害", "Spend 10%% max HP; each column tile takes 33%% of HP spent"))
	elif hero_id == "zhouyu": values.append(t("每格%d魔法伤害；每秒灼烧%d" % [round(float(params.get("base_value", hero.skill_value)) * stat_mult), round(float(params.get("burn_per_sec", 0.0)) * stat_mult)], "%d magic per tile; %d burn per second" % [round(float(params.get("base_value", hero.skill_value)) * stat_mult), round(float(params.get("burn_per_sec", 0.0)) * stat_mult)]))
	elif hero_id == "luxun": values.append(t("每次命中%d；基础弹射%d次" % [round(float(params.get("base_value", skill_base * 2.0)) * stat_mult), int(params.get("bounces", 1))], "%d per hit; %d base bounce(s)" % [round(float(params.get("base_value", skill_base * 2.0)) * stat_mult), int(params.get("bounces", 1))]))
	elif hero_id == "lvmeng": values.append(t("后军目标%d物理伤害；隐身%.1f秒" % [round(float(params.get("base_value", skill_base * 4.0)) * stat_mult), float(params.get("stealth", 3.0))], "%d physical damage to rearguard; %.1fs stealth" % [round(float(params.get("base_value", skill_base * 4.0)) * stat_mult), float(params.get("stealth", 3.0))]))
	elif hero_id == "lusu": values.append(t("最低当前生命友军：恢复%.0f%%最大生命，最大生命+%d" % [float(params.get("heal_ratio", 0.15)) * 100.0, round(float(params.get("max_hp_flat", 200.0)))], "Lowest-current-HP ally: restore %.0f%% max HP, max HP +%d" % [float(params.get("heal_ratio", 0.15)) * 100.0, round(float(params.get("max_hp_flat", 200.0)))]))
	elif hero_id == "xiaoqiao": values.append(t("随机%d名后军：减速%.0f%%，持续%.1f秒" % [int(params.get("target_count", 2)), float(params.get("slow", 0.35)) * 100.0, float(params.get("slow_time", 6.0))], "Random %d rearguards: %.0f%% slow for %.1fs" % [int(params.get("target_count", 2)), float(params.get("slow", 0.35)) * 100.0, float(params.get("slow_time", 6.0))]))
	elif hero_id == "lvbu": values.append(t("目标排每人约%d物理伤害" % round(skill_base * float(params.get("mult", 1.6))), "About %d physical damage to each unit in the row" % round(skill_base * float(params.get("mult", 1.6)))))
	elif hero_id == "diaochan": values.append(t("魅惑%.2f秒" % (float(params.get("duration", 1.5)) * effect_mult), "Charm for %.2fs" % (float(params.get("duration", 1.5)) * effect_mult)))
	elif hero_id == "dongzhuo": values.append(t("技能造成%d伤害，追加当前生命比例伤害" % round(skill_base * float(params.get("mult", 1.0))), "Skill deals %d damage plus current-HP damage" % round(skill_base * float(params.get("mult", 1.0)))))
	elif ability in ["strike", "strike_magic", "drain", "control", "row", "row_magic"]:
		values.append(t("每个命中目标约%d伤害" % round(skill_base * float(params.get("mult", 1.0))), "About %d damage per hit target" % round(skill_base * float(params.get("mult", 1.0)))))
	elif ability in ["multi", "multi_magic"]:
		values.append(t("技能命中%d次，每次约%d伤害" % [int(params.get("count", 2)), round(skill_base * float(params.get("mult", 0.8)))], "%d skill hits, about %d damage each" % [int(params.get("count", 2)), round(skill_base * float(params.get("mult", 0.8)))]))
	elif ability == "heal":
		values.append(t("单次治疗约%d" % round(skill_base * float(params.get("mult", 1.5)) + float(params.get("flat", 80.0)) * HEALTH_SCALE * 0.65 * effect_mult), "Heal about %d" % round(skill_base * float(params.get("mult", 1.5)) + float(params.get("flat", 80.0)) * HEALTH_SCALE * 0.65 * effect_mult)))
	elif ability == "heal_team": values.append(t("全体恢复%.1f%%最大生命" % (float(params.get("ratio", 0.10)) * effect_mult * 100.0), "Team restores %.1f%% max HP" % (float(params.get("ratio", 0.10)) * effect_mult * 100.0)))
	elif ability.begins_with("shield_"):
		values.append(t("每个目标获得约%d护盾" % round(skill_base * float(params.get("mult", 1.5)) + float(params.get("flat", 40.0)) * effect_mult), "Each target gains about %d shield" % round(skill_base * float(params.get("mult", 1.5)) + float(params.get("flat", 40.0)) * effect_mult)))
	elif ability.begins_with("buff_"):
		values.append(t("增伤%.1f%%；行动加速%.1f%%" % [float(params.get("damage", 0.0)) * effect_mult * 100.0, float(params.get("action", 0.0)) * effect_mult * 100.0], "+%.1f%% damage; +%.1f%% gauge speed" % [float(params.get("damage", 0.0)) * effect_mult * 100.0, float(params.get("action", 0.0)) * effect_mult * 100.0]))
	if float(params.get("stun", 0.0)) > 0.0: values.append(t("控制%.2f秒" % (float(params.stun) * effect_mult), "Control %.2fs" % (float(params.stun) * effect_mult)))
	if float(params.get("burn", 0.0)) > 0.0: values.append(t("灼烧%.1f秒" % (float(params.burn) * effect_mult), "Burn %.1fs" % (float(params.burn) * effect_mult)))
	return t("★%d 实战数值：" % level, "★%d combat values: " % level) + "；".join(values)

func _render_encyclopedia() -> void:
	_clear_dynamic_children(encyclopedia_grid)
	encyclopedia_preview_hero_ids.clear()
	var showing_weapons := encyclopedia_mode == "weapons"
	var showing_bonds := encyclopedia_mode == "bonds"
	if showing_weapons:
		encyclopedia_title_label.text = t("蜀国武器图鉴", "SHU WEAPON CODEX")
	elif showing_bonds:
		encyclopedia_title_label.text = _faction_name(encyclopedia_faction) + t("国武将羁绊图", " BOND GRAPH")
	else:
		encyclopedia_title_label.text = t("武将图鉴", "HERO CODEX")
	encyclopedia_hero_tab_button.modulate = Color("#f0c77a") if encyclopedia_mode == "heroes" else Color.WHITE
	encyclopedia_weapon_tab_button.modulate = Color("#f0c77a") if showing_weapons else Color.WHITE
	encyclopedia_bond_tab_button.modulate = Color("#f0c77a") if showing_bonds else Color.WHITE
	encyclopedia_hero_filters.visible = not showing_weapons
	for star_button in encyclopedia_star_filter_buttons:
		star_button.visible = not showing_bonds
	encyclopedia_bond_reset_button.visible = showing_bonds
	encyclopedia_content_scroll.visible = not showing_bonds
	encyclopedia_bond_graph.visible = showing_bonds
	if showing_weapons:
		encyclopedia_bond_label.text = t("蜀国专属武器 · 当前收录 15 件。点击武器图片可放大查看，并使用左右箭头切换。", "Shu signature weapons · 15 entries. Click an image to enlarge it and use the arrows to browse.")
		_render_weapon_encyclopedia()
		return
	if showing_bonds:
		encyclopedia_bond_label.text = _bond_graph_help_text()
		_render_encyclopedia_bond_graph()
		return
	encyclopedia_bond_label.text = _bond_detail(encyclopedia_faction)
	for hero_id in heroes:
		var hero: Dictionary = heroes[hero_id]
		if hero.f != encyclopedia_faction: continue
		encyclopedia_preview_hero_ids.append(hero_id)
		var stat_mult := _star_stat_multiplier(encyclopedia_star_level)
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 545 if show_hero_codex_images else 335)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.tooltip_text = t("点击查看完整武将介绍", "Click to view the complete hero entry")
		card.gui_input.connect(_on_encyclopedia_card_input.bind(hero_id))
		if _is_mobile_ui(): card.mouse_filter = Control.MOUSE_FILTER_PASS
		_style(card, Color("#20201d"), 12, FACTION_COLORS[hero.f], 2)
		var card_box := VBoxContainer.new()
		card_box.add_theme_constant_override("separation", 7)
		card.add_child(card_box)
		if show_hero_codex_images:
			var portrait := _portrait_rect(hero_id)
			portrait.name = "HeroPortrait"
			portrait.custom_minimum_size.y = 205
			portrait.mouse_filter = Control.MOUSE_FILTER_PASS if _is_mobile_ui() else Control.MOUSE_FILTER_STOP
			portrait.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			portrait.tooltip_text = t("点击放大武将立绘", "Click to enlarge hero artwork")
			portrait.gui_input.connect(_on_encyclopedia_card_input.bind(hero_id))
			card_box.add_child(portrait)
		var hero_name := _label(_hero_name(hero_id) + "  " + "★".repeat(encyclopedia_star_level), 24, FACTION_COLORS[hero.f].lightened(0.32))
		hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_box.add_child(hero_name)
		var stats := _label(t("生命", "HP") + " " + str(round(float(hero.hp) * stat_mult)) + "\n" + _hero_army_name(hero_id) + "  ·  " + t("每", "Every ") + str(hero.cooldown) + t("秒读条", "s gauge"), 13, Color("#e8e2cf"))
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_box.add_child(stats)
		var detail := _label("", 13, Color("#c9c0b1"))
		detail.text = _skill_detail(hero_id) + "\n" + _star_skill_values(hero_id, encyclopedia_star_level) + "\n" + _hero_bond_detail(hero_id)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var detail_scroll := ScrollContainer.new()
		detail_scroll.custom_minimum_size.y = 190
		detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		detail_scroll.tooltip_text = t("鼠标滚轮或拖动滚动条查看完整技能与羁绊说明", "Scroll or drag the bar to read all skill and bond details")
		_enable_touch_scroll(detail_scroll, false, true)
		detail_scroll.add_child(detail)
		card_box.add_child(detail_scroll)
		encyclopedia_grid.add_child(card)

func _bond_graph_data(faction: String) -> Dictionary:
	var data := {
		"shu":{
			"faction":["han_expedition", "汉室北伐", "Han Expedition", "2 / 5 / 8", "全体蜀将承伤降低2%/5%/8%。8人时，每次受伤后额外获得2%减伤，最多3层；自身释放技能后清空额外层数。", "All Shu heroes take 2%/5%/8% less damage. At 8, each damage instance adds another 2% reduction, up to 3 stacks; casting clears the extra stacks."],
			"bonds":[
				["peach_garden", "桃园结义", "Peach Garden", ["liubei", "guanyu", "zhangfei"], "3人", "3 heroes", "强化刘备持续治疗、关羽列斩自疗与张飞号令减伤。", "Empowers Liu Bei's regeneration, Guan Yu's cleave healing, and Zhang Fei's command reduction."],
				["five_tigers", "五虎上将", "Five Tigers", ["guanyu", "zhangfei", "zhaoyun", "huangzhong", "machao"], "5人", "5 heroes", "五虎绝技强化；马超使全体前军、中军行动条速度提高15%。", "Empowers all five signatures; Ma Chao grants vanguards and midguards +15% gauge speed."],
				["northern_dream", "夜梦北斗", "Northern Dream", ["liubei", "liushan"], "2人", "2 heroes", "刘备仁德延长至6秒；刘禅鼓舞额外覆盖同列后军。", "Liu Bei's regeneration lasts 6s; Liu Shan's encouragement also covers the rearguard."],
				["wulong_han", "卧龙辅汉", "Wolong Aids Han", ["liubei", "zhugeliang"], "2人", "2 heroes", "仁德目标获得法术减伤；八阵按额外命中人数整体增伤。", "Benevolence grants magic reduction; Eight-Formation scales with additional enemies hit."],
				["seven_charges", "七进七出", "Seven Charges", ["zhaoyun", "liushan"], "2人", "2 heroes", "赵云改为7次连刺并强攻后军；刘禅赋予被鼓舞友军30%全能吸血。", "Zhao Yun gains seven thrusts against the rear; Liu Shan grants empowered allies 30% omnivamp."],
				["one_rider", "一骑当千", "One Rider", ["machao", "madai"], "2人", "2 heroes", "马超全列均为200%贯穿；马岱开场行动条充满。", "Ma Chao pierces every row at 200%; Ma Dai starts at full gauge."],
				["fated_enemies", "宿命之敌", "Fated Enemies", ["madai", "weiyan"], "2人", "2 heroes", "马岱施加40%易伤；魏延为相邻和后方中军友军治疗。", "Ma Dai applies 40% vulnerability; Wei Yan heals adjacent and rearward midguard allies."],
				["flying_meteor", "飞火流星", "Flying Meteor", ["huangzhong", "weiyan"], "2人", "2 heroes", "黄忠获得双倍暴击；敌方前军阵亡时魏延恢复50%最大生命。", "Huang Zhong gains double-damage crits; enemy vanguard deaths heal Wei Yan for 50% max HP."],
				["dragon_phoenix", "卧龙凤雏", "Dragon and Phoenix", ["zhugeliang", "pangtong"], "2人", "2 heroes", "八阵扩展左右格；连环计升级为横向三格100%伤害和2.5秒锁条。", "Eight-Formation expands horizontally; Chain Scheme becomes three-tile 100% damage and 2.5s control."],
				["expedition_legacy", "北伐传承", "Northern Expedition Legacy", ["zhugeliang", "jiangwei"], "2人", "2 heroes", "八阵扩展斜角格；姜维追加斜击并获得30%减伤5秒。", "Eight-Formation adds diagonals; Jiang Wei gains diagonal strikes and 30% reduction for 5s."],
				["seven_captures", "七擒孟获", "Seven Captures", ["zhugeliang", "menghuo"], "2人", "2 heroes", "诸葛亮获得火攻强化；孟获震地追加60%整排余震。", "Zhuge Liang gains Fire Assault; Meng Huo adds a 60% row aftershock."],
				["nanman_couple", "南蛮夫妇", "Nanman Couple", ["menghuo", "zhurong"], "2人", "2 heroes", "孟获强化对灼烧目标的震地；祝融飞刃向左右相邻格弹射。", "Meng Huo's quake is empowered against burning targets; Zhurong bounces to horizontal neighbors."],
				["barbarian_reinforcement", "蛮王援军", "Barbarian Reinforcements", ["menghuo", "dailaidongzhu"], "2人", "2 heroes", "孟获压退整排行动条；带来洞主追加同列上下格攻击。", "Meng Huo pushes back the row's gauges; Dailai adds vertical splash attacks."],
				["sibling_bond", "姐弟同心", "Sibling Bond", ["dailaidongzhu", "zhurong"], "2人", "2 heroes", "祝融灼烧提高至6秒、每秒40%；带来洞主附加灼烧并对已灼烧目标增伤。", "Zhurong's burn rises to 6s at 40%; Dailai ignites and gains damage against burning targets."]
			]
		},
		"wei":{
			"faction":["wei_command", "魏武中枢", "Wei Command", "2 / 5 / 8", "全体魏将控制时长提高3%/8%/15%。8人时，对带有任意控制或减益的目标造成伤害提高15%。", "All Wei heroes gain 3%/8%/15% control duration. At 8, they deal 15% more damage to targets with any control or debuff."],
			"bonds":[
				["evil_of_old", "古之恶来", "Evil of Old", ["caocao", "dianwei"], "2人", "2 heroes", "曹操目标+1，后军目标伤害与眩晕翻倍；典韦目标+1。", "Cao Cao gains 1 target and doubles damage/stun against rearguards; Dian Wei gains 1 target."],
				["tiger_guard", "虎卫护主", "Tiger Guard", ["caocao", "xuchu"], "2人", "2 heroes", "曹操目标+1，前军目标伤害与眩晕翻倍；许褚目标+1。", "Cao Cao gains 1 target and doubles damage/stun against vanguards; Xu Chu gains 1 target."],
				["twin_wei_guards", "魏武双卫", "Twin Wei Guards", ["dianwei", "xuchu"], "2人", "2 heroes", "典韦与许褚的技能伤害均由200%提高至400%。", "Dian Wei and Xu Chu both rise from 200% to 400% SKILL damage."],
				["hefei_vanguard", "逍遥津先锋", "Hefei Vanguard", ["zhangliao", "yuejin"], "2人", "2 heroes", "张辽往返伤害提高至200%；乐进改为攻击5人并造成150%伤害。", "Zhang Liao's two passes rise to 200%; Yue Jin targets 5 enemies at 150%."],
				["adaptive_vanguard", "巧变开山", "Adaptive Vanguard", ["zhanghe", "xuhuang"], "2人", "2 heroes", "张郃连锁至相邻前军；徐晃整排伤害提高至200%。", "Zhang He chains to an adjacent vanguard; Xu Huang's row damage rises to 200%."],
				["five_elites", "五子良将", "Five Elite Generals", ["zhangliao", "yuejin", "zhanghe", "xuhuang", "yujin"], "5人", "5 heroes", "五人齐聚后分别获得易损、重伤、连锁扩散、随机整排强控和三人护盾强化。", "At five, gain vulnerability, grievous wounds, chain spread, random-row control, and triple shielding."],
				["swift_bulwark", "神速镇远", "Swift Bulwark", ["xiahouyuan", "caoren"], "2人", "2 heroes", "夏侯渊冷却-0.5秒、眩晕+0.5秒；曹仁目标+1、眩晕+0.5秒、后军减伤+10%。", "Xiahou Yuan gains -0.5s cooldown and +0.5s stun; Cao Ren gains 1 target, +0.5s stun, and +10% rear damage reduction."],
				["xiahou_brothers", "夏侯同心", "Xiahou Brothers", ["xiahouyuan", "xiahoudun"], "2人", "2 heroes", "夏侯渊冷却-0.5秒、眩晕+0.5秒；夏侯惇目标+1、眩晕+0.5秒、前军减伤+10%。", "Xiahou Yuan gains -0.5s cooldown and +0.5s stun; Xiahou Dun gains 1 target, +0.5s stun, and +10% vanguard damage reduction."],
				["twin_bulwarks", "魏武双壁", "Twin Bulwarks", ["caoren", "xiahoudun"], "2人", "2 heroes", "曹仁与夏侯惇各自目标+1、眩晕+0.5秒、对应兵种减伤+10%。", "Cao Ren and Xiahou Dun each gain 1 target, +0.5s stun, and +10% reduction against their guarded row."],
				["thunder_frost", "雷霆冰策", "Thunder and Frost", ["simayi", "guojia"], "2人", "2 heroes", "司马懿目标+1、伤害倍率+25%；郭嘉目标+1、冷却-0.5秒。", "Sima Yi gains 1 target and +25% SKILL ratio; Guo Jia gains 1 target and -0.5s cooldown."],
				["thunder_royal", "鹰视王佐", "Eagle Eye and Royal Aid", ["simayi", "xunyu"], "2人", "2 heroes", "司马懿目标+1、伤害倍率+25%；荀彧目标+1、冷却-0.4秒。", "Sima Yi gains 1 target and +25% SKILL ratio; Xun Yu gains 1 target and -0.4s cooldown."],
				["thunder_venom", "鹰视毒谋", "Eagle Eye and Venom", ["simayi", "jiaxu"], "2人", "2 heroes", "司马懿目标+1、伤害倍率+25%；贾诩目标+1、中毒+0.5秒。", "Sima Yi gains 1 target and +25% SKILL ratio; Jia Xu gains 1 target and +0.5s poison."],
				["frost_royal", "遗计王佐", "Frozen Royal Plan", ["guojia", "xunyu"], "2人", "2 heroes", "郭嘉目标+1、冷却-0.5秒；荀彧目标+1、冷却-0.4秒。", "Guo Jia gains 1 target and -0.5s cooldown; Xun Yu gains 1 target and -0.4s cooldown."],
				["frost_venom", "冰毒奇策", "Frost and Venom", ["guojia", "jiaxu"], "2人", "2 heroes", "郭嘉目标+1、冷却-0.5秒；贾诩目标+1、中毒+0.5秒。", "Guo Jia gains 1 target and -0.5s cooldown; Jia Xu gains 1 target and +0.5s poison."],
				["royal_venom", "王佐毒策", "Royal Venom", ["xunyu", "jiaxu"], "2人", "2 heroes", "荀彧目标+1、冷却-0.4秒；贾诩目标+1、中毒+0.5秒。", "Xun Yu gains 1 target and -0.4s cooldown; Jia Xu gains 1 target and +0.5s poison."]
			]
		},
		"wu":{
			"faction":["jiangdong_relay", "江东联动", "Jiangdong Relay", "2 / 5 / 8", "全体吴将最大生命提高2%/5%/8%。8人时，每场战斗首次有吴将即将阵亡，会均摊全体存活吴将的生命比例，并各自恢复10%最大生命。", "All Wu heroes gain 2%/5%/8% max HP. At 8, the first lethal hit each battle equalizes surviving Wu heroes' health ratios, then restores 10% max HP to each."],
			"bonds":[
				["wu_commanders", "四英杰", "Four Heroes", ["zhouyu", "luxun", "lusu", "lvmeng"], "4人", "4 heroes", "周瑜额外点燃2格；陆逊火球总共弹射3次；吕蒙使命中后军恐惧4秒；鲁肃改为治疗两名最低当前生命友军，各恢复20%最大生命并提高350最大生命。", "Zhou Yu ignites 2 extra tiles; Lu Xun's fireball bounces 3 times; Lu Meng fears the struck rearguard for 4s; Lu Su treats the two lowest-current-HP allies, restoring 20% max HP and granting 350 max HP to each for the battle."],
				["sun_legacy", "孙氏之志", "Sun Legacy", ["sunjian", "sunce", "sunquan", "sunshangxiang"], "4人", "4 heroes", "孙坚自损与阵亡传承强化；孙策基础倍率提高至400%并获得残血减伤；孙权每次提高400+10%已损生命的最大生命、上限4倍并恢复15%已损生命；孙尚香改为6秒冷却、连射2次150%伤害且施法后技能强度+2。", "Empowers Sun Jian's sacrifice and Sun Ce's assault; Sun Quan gains 400 plus 10% missing HP as max HP up to 4x and restores 15% missing HP; Sun Shangxiang has a 6s cooldown, fires twice at 150%, and gains 2 SKILL per cast."],
				["jiangdong_sisters", "江东双姝", "Jiangdong Sisters", ["daqiao", "xiaoqiao"], "2人", "2 heroes", "大乔治疗量+50%并追加治疗；小乔使天香缓阵的行动条减速由35%提高至60%。", "Da Qiao gains +50% healing and an extra heal; Xiao Qiao's Gentle Breeze gauge slow rises from 35% to 60%."],
				["white_raid", "白衣奇袭", "White-Robed Ambush", ["lvmeng", "ganning"], "2人", "2 heroes", "吕蒙每次进入隐身后下一次伤害提高60%；甘宁攻击生命低于50%的目标时伤害提高50%。", "Lu Meng's next post-stealth damage gains 60%; Gan Ning deals 50% more damage to targets below 50% HP."],
				["shenting_duel", "神亭酣战", "Shenting Duel", ["sunce", "taishici"], "2人", "2 heroes", "孙策追加第二段右侧横扫，正前方承受两次伤害；太史慈的目标数由2人提高至3人。", "Sun Ce adds a second sweep to the right; Taishi Ci's target count rises from 2 to 3."],
				["jiangdong_couple", "江东佳偶", "Jiangdong Couple", ["sunce", "daqiao"], "2人", "2 heroes", "孙策每次释放技能恢复12%最大生命；大乔治疗友军时，目标每损失10%生命，本次受到的治疗提高4%。", "Sun Ce heals 12% max HP after each cast; when Da Qiao heals an ally, that target gains +4% healing per 10% HP missing."],
				["harmonious_zither", "琴瑟和鸣", "Harmonious Zither", ["zhouyu", "xiaoqiao"], "2人", "2 heroes", "周瑜赤壁点火的灼烧时间由3秒延长至6秒；小乔的减速目标由2名提高至3名，持续时间由6秒延长至8秒。", "Zhou Yu's Red Cliffs burn rises from 3s to 6s; Xiao Qiao's slow rises from 2 to 3 targets and from 6s to 8s."],
				["red_cliffs_ruse", "赤壁苦计", "Red Cliffs Ruse", ["zhouyu", "huanggai"], "2人", "2 heroes", "周瑜按目标已损生命提高点火伤害；黄盖列攻附加6秒灼烧，每秒造成实际消耗生命5%的伤害。", "Zhou Yu scales ignition with missing HP; Huang Gai burns the struck column for 6s at 5% of HP spent per second."],
				["jiangdong_pillars", "江东柱石", "Pillars of Jiangdong", ["huanggai", "sunjian"], "2人", "2 heroes", "黄盖改为消耗15%最大生命并造成实际消耗生命45%的伤害；孙坚开局满行动条，伤害提高至实际消耗生命150%。", "Huang Gai spends 15% max HP and deals 45% of HP spent; Sun Jian starts at full gauge and deals 150% of HP spent."],
				["jiangbiao_blades", "江表双锋", "Twin Blades of Jiangbiao", ["taishici", "ganning"], "2人", "2 heroes", "太史慈攻击已灼烧目标时直接伤害由150%提高至300%；甘宁与友军协击倍率由150%提高至250%。", "Taishi Ci deals 300% instead of 150% to burning targets; Gan Ning's twin assault rises from 150% to 250%."],
				["sovereign_minister", "君臣同心", "Sovereign and Minister", ["luxun", "sunquan"], "2人", "2 heroes", "陆逊火球伤害提高50%，命中灼烧目标时再提高50%，合计提高100%；孙权伤害提高至目标当前生命12%，冷却缩短至8秒。", "Lu Xun's fireball gains +50% damage and another +50% against burning targets; Sun Quan deals 12% current HP and has an 8s cooldown."],
				["tiger_ministers", "江表虎臣", "Tiger Ministers", ["dingfeng", "xusheng"], "2人", "2 heroes", "丁奉追加攻击目标左右相邻格并压退15%行动条；徐盛水阵控制延长50%。", "Ding Feng also strikes horizontal neighbors and pushes their gauge back 15%; Xu Sheng's water control lasts 50% longer."]
			]
		},
		"qun":{
			"faction":["chaos_struggle", "乱世争衡", "Chaos Struggle", "2 / 5 / 8", "全体群雄武将技能冷却缩短3%/8%/15%。8人时，每次释放技能有20%概率连续释放两次。", "All Qun heroes gain 3%/8%/15% skill cooldown reduction. At 8, every cast has a 20% chance to cast twice in succession."],
			"bonds":[
				["tyrant_court", "鬼神权倾", "Tyrant's Court", ["lvbu", "diaochan", "dongzhuo"], "3人", "3 heroes", "吕布获得致死保护，貂蝉延长魅惑，董卓强化当前生命追加伤害。", "Lu Bu gains a death ward, Diao Chan extends charm, and Dong Zhuo gains stronger current-HP damage."],
				["hebei_pillars", "河北四庭柱", "Hebei Pillars", ["yanliang", "wenchou", "qunzhanghe", "gaolan"], "至少3人", "3+ heroes", "成员开场获得紫幕；文丑反弹指向技能，群张郃可补充紫幕。", "Members open with Purple Ward; Wen Chou reflects targeted skills and Qun Zhang He restores wards."],
				["way_of_heaven", "天道", "Way of Heaven", ["yuji", "zhangjiao"], "2人", "2 heroes", "友军阵亡时有65%概率对随机敌人降下60%技能强度天雷。", "Allied deaths have a 65% chance to strike a random enemy for 60% SKILL thunder."]
			]
		}
	}
	return data.get(faction, data.shu)

func _bond_graph_help_text() -> String:
	return t(
		"网状图会把相互关联的武将和羁绊聚在一起。点击任意节点可聚焦一层关系；中键拖动画布、滚轮缩放、左键拖动节点，右下角小地图可快速定位。",
		"The network groups related heroes and bonds. Select any node to focus its direct links; middle-drag to pan, use the wheel to zoom, left-drag nodes, and use the minimap to navigate."
	)

func _bond_connection_names(connection: Dictionary) -> Array[String]:
	return [
		str(connection.get("from_node", connection.get("from", ""))),
		str(connection.get("to_node", connection.get("to", "")))
	]

func _set_bond_connection_activity(connection: Dictionary, amount: float) -> void:
	var names := _bond_connection_names(connection)
	encyclopedia_bond_graph.set_connection_activity(
		names[0],
		int(connection.get("from_port", 0)),
		names[1],
		int(connection.get("to_port", 0)),
		amount
	)

func _on_encyclopedia_bond_node_selected(node: Node) -> void:
	if encyclopedia_mode != "bonds" or not node is GraphNode:
		return
	var selected_name := str(node.name)
	var related := {selected_name:true}
	for connection in encyclopedia_bond_graph.get_connection_list():
		var names := _bond_connection_names(connection)
		if selected_name in names:
			related[names[0]] = true
			related[names[1]] = true
			_set_bond_connection_activity(connection, 1.0)
		else:
			_set_bond_connection_activity(connection, 0.0)
	if bool(node.get_meta("focus_all", false)):
		for child in encyclopedia_bond_graph.get_children():
			if child is GraphNode:
				related[str(child.name)] = true
	for child in encyclopedia_bond_graph.get_children():
		if child is GraphNode:
			child.modulate = Color.WHITE if related.has(str(child.name)) else Color(0.42, 0.42, 0.42, 0.28)
	encyclopedia_bond_label.text = str(node.get_meta("focus_text", node.title))

func _on_encyclopedia_bond_node_deselected(_node: Node) -> void:
	if encyclopedia_mode != "bonds":
		return
	for child in encyclopedia_bond_graph.get_children():
		if child is GraphNode:
			child.modulate = Color.WHITE
	for connection in encyclopedia_bond_graph.get_connection_list():
		_set_bond_connection_activity(connection, 0.0)
	encyclopedia_bond_label.text = _bond_graph_help_text()

func _bond_graph_node_style(node: GraphNode, color: Color, border: Color) -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = color
	panel.border_color = border
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(10)
	panel.content_margin_left = 10
	panel.content_margin_right = 10
	panel.content_margin_top = 8
	panel.content_margin_bottom = 8
	node.add_theme_stylebox_override("panel", panel)
	var selected := panel.duplicate()
	selected.border_color = border.lightened(0.35)
	selected.set_border_width_all(3)
	node.add_theme_stylebox_override("panel_selected", selected)

func _add_bond_graph_node(node_name: String, title: String, body: String, position: Vector2, is_bond: bool) -> GraphNode:
	var node := GraphNode.new()
	node.name = node_name
	node.title = title
	node.position_offset = position
	node.custom_minimum_size = Vector2(220, 62) if is_bond else Vector2(150, 48)
	node.resizable = false
	var color: Color = Color("#3b2d18") if is_bond else Color("#18232b")
	var border: Color = Color("#d3a850") if is_bond else FACTION_COLORS[encyclopedia_faction]
	_bond_graph_node_style(node, color, border)
	var label := _label(body, 14, Color("#f2ddaf") if is_bond else Color("#dce5e9"))
	label.custom_minimum_size.x = 190 if is_bond else 120
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(label)
	var port_color: Color = Color("#d3a850", 0.38) if is_bond else Color(FACTION_COLORS[encyclopedia_faction], 0.38)
	node.set_slot(0, true, 0, port_color, true, 0, port_color)
	node.set_meta("focus_text", title + "\n" + body)
	node.set_meta("is_bond", is_bond)
	if _is_mobile_ui(): node.mouse_filter = Control.MOUSE_FILTER_PASS
	encyclopedia_bond_graph.add_child(node)
	return node

func _bond_network_layout(hero_ids: Array, graph_data: Dictionary) -> Dictionary:
	var node_ids: Array[String] = []
	var node_kinds := {}
	var edges: Array = []
	var degree := {}
	for hero_id in hero_ids:
		var node_id := "hero_" + str(hero_id)
		node_ids.append(node_id)
		node_kinds[node_id] = "hero"
		degree[node_id] = 0
	var faction_id := "bond_" + str(graph_data.faction[0])
	node_ids.append(faction_id)
	node_kinds[faction_id] = "bond"
	degree[faction_id] = 0
	var special_members := {}
	for bond in graph_data.bonds:
		var bond_id := "bond_" + str(bond[0])
		node_ids.append(bond_id)
		node_kinds[bond_id] = "bond"
		degree[bond_id] = 0
		for member_id in bond[3]:
			var hero_node_id := "hero_" + str(member_id)
			edges.append([hero_node_id, bond_id])
			special_members[str(member_id)] = true
			degree[hero_node_id] = int(degree.get(hero_node_id, 0)) + 1
			degree[bond_id] = int(degree[bond_id]) + 1
	for hero_id in hero_ids:
		if special_members.has(str(hero_id)):
			continue
		var hero_node_id := "hero_" + str(hero_id)
		edges.append([hero_node_id, faction_id])
		degree[hero_node_id] = 1
		degree[faction_id] = int(degree[faction_id]) + 1

	var center := Vector2(920, 500)
	var positions := {faction_id:center}
	var bond_count: int = graph_data.bonds.size()
	for index in bond_count:
		var bond = graph_data.bonds[index]
		var angle := -PI * 0.92 + TAU * float(index) / maxf(1.0, float(bond_count))
		positions["bond_" + str(bond[0])] = center + Vector2(cos(angle) * 500.0, sin(angle) * 270.0)
	var isolated_index := 0
	for hero_index in hero_ids.size():
		var hero_id := str(hero_ids[hero_index])
		var hero_node_id := "hero_" + hero_id
		var linked_positions: Array[Vector2] = []
		for edge in edges:
			if str(edge[0]) == hero_node_id and str(edge[1]) != faction_id:
				linked_positions.append(positions[str(edge[1])])
		if linked_positions.is_empty():
			var isolated_angle := TAU * float(isolated_index) / maxf(1.0, float(hero_ids.size() - special_members.size()))
			positions[hero_node_id] = center + Vector2(cos(isolated_angle) * 220.0, sin(isolated_angle) * 145.0)
			isolated_index += 1
			continue
		var average := Vector2.ZERO
		for linked_position in linked_positions:
			average += linked_position
		average /= float(linked_positions.size())
		var outward := (average - center).normalized()
		if outward.length_squared() < 0.01:
			var fallback_angle := TAU * float(hero_index) / maxf(1.0, float(hero_ids.size()))
			outward = Vector2(cos(fallback_angle), sin(fallback_angle))
		var perpendicular := Vector2(-outward.y, outward.x)
		var jitter := float((hero_index % 3) - 1) * 48.0
		positions[hero_node_id] = average + outward * 145.0 + perpendicular * jitter

	var half_sizes := {}
	for node_id in node_ids:
		half_sizes[node_id] = Vector2(110, 38) if node_kinds[node_id] == "bond" else Vector2(75, 29)
	var temperature := 0.68
	for _iteration in 460:
		var forces := {}
		for node_id in node_ids:
			forces[node_id] = Vector2.ZERO
		for left_index in node_ids.size():
			var left_id := node_ids[left_index]
			for right_index in range(left_index + 1, node_ids.size()):
				var right_id := node_ids[right_index]
				var delta: Vector2 = positions[right_id] - positions[left_id]
				var distance := maxf(1.0, delta.length())
				var direction := delta / distance
				var both_bonds: bool = str(node_kinds[left_id]) == "bond" and str(node_kinds[right_id]) == "bond"
				var both_heroes: bool = str(node_kinds[left_id]) == "hero" and str(node_kinds[right_id]) == "hero"
				var minimum_distance := 215.0 if both_bonds else (165.0 if both_heroes else 190.0)
				var repel := 70000.0 / (distance * distance)
				if distance < minimum_distance:
					repel += (minimum_distance - distance) * 1.05
				forces[left_id] -= direction * repel
				forces[right_id] += direction * repel
		for edge in edges:
			var from_id := str(edge[0])
			var to_id := str(edge[1])
			var delta: Vector2 = positions[to_id] - positions[from_id]
			var distance := maxf(1.0, delta.length())
			var spring := (distance - 190.0) * 0.036
			var spring_force := delta / distance * spring
			forces[from_id] += spring_force
			forces[to_id] -= spring_force
		for node_id in node_ids:
			var gravity: Vector2 = (center - positions[node_id]) * 0.0055
			var degree_anchor := 1.0 + minf(3.0, float(degree.get(node_id, 0))) * 0.08
			positions[node_id] += (forces[node_id] + gravity) * temperature / degree_anchor
		temperature = maxf(0.12, temperature * 0.993)

	# The codex viewport is deliberately wide. Compress the free-form simulation
	# vertically before resolving label rectangles so the whole web opens legibly.
	var average_y := 0.0
	for node_id in node_ids:
		average_y += float(positions[node_id].y)
	average_y /= maxf(1.0, float(node_ids.size()))
	for node_id in node_ids:
		positions[node_id].y = average_y + (float(positions[node_id].y) - average_y) * 0.46

	for _pass in 90:
		var moved := false
		for left_index in node_ids.size():
			var left_id := node_ids[left_index]
			for right_index in range(left_index + 1, node_ids.size()):
				var right_id := node_ids[right_index]
				var delta: Vector2 = positions[right_id] - positions[left_id]
				var required_x: float = float(half_sizes[left_id].x + half_sizes[right_id].x) + 14.0
				var required_y: float = float(half_sizes[left_id].y + half_sizes[right_id].y) + 12.0
				var overlap_x := required_x - absf(delta.x)
				var overlap_y := required_y - absf(delta.y)
				if overlap_x <= 0.0 or overlap_y <= 0.0:
					continue
				moved = true
				if overlap_x < overlap_y:
					var push_x := overlap_x * 0.51 * (1.0 if delta.x >= 0.0 else -1.0)
					positions[left_id].x -= push_x
					positions[right_id].x += push_x
				else:
					var push_y := overlap_y * 0.51 * (1.0 if delta.y >= 0.0 else -1.0)
					positions[left_id].y -= push_y
					positions[right_id].y += push_y
		if not moved:
			break

	var min_corner := Vector2(INF, INF)
	var max_corner := Vector2(-INF, -INF)
	for node_id in node_ids:
		min_corner = min_corner.min(positions[node_id] - half_sizes[node_id])
		max_corner = max_corner.max(positions[node_id] + half_sizes[node_id])
	var offset := Vector2(48, 48) - min_corner
	for node_id in node_ids:
		positions[node_id] += offset
	return {"positions":positions, "edges":edges, "size":max_corner - min_corner + Vector2(96, 96)}

func _render_encyclopedia_bond_graph() -> void:
	encyclopedia_bond_graph.clear_connections()
	for child in encyclopedia_bond_graph.get_children():
		if child is GraphNode:
			encyclopedia_bond_graph.remove_child(child)
			child.queue_free()
	var graph_data := _bond_graph_data(encyclopedia_faction)
	var preferred_order := {
		"shu":["liubei", "guanyu", "zhangfei", "zhaoyun", "liushan", "zhugeliang", "huangzhong", "weiyan", "madai", "machao", "jiangwei", "pangtong", "menghuo", "zhurong", "dailaidongzhu"],
		"wei":["caocao", "dianwei", "xuchu", "zhangliao", "yuejin", "zhanghe", "xuhuang", "yujin", "simayi", "guojia", "xiahouyuan", "caoren", "xiahoudun", "xunyu", "jiaxu"],
		"wu":["zhouyu", "luxun", "lusu", "lvmeng", "sunjian", "sunce", "sunquan", "sunshangxiang", "daqiao", "xiaoqiao", "huanggai", "taishici", "ganning", "dingfeng", "xusheng"],
		"qun":["lvbu", "diaochan", "dongzhuo", "yanliang", "wenchou", "qunzhanghe", "gaolan", "yuji", "zhangjiao", "gaoshun", "chengong", "huatuo", "yuanshao", "yuanshu"]
	}
	var hero_ids: Array = preferred_order[encyclopedia_faction].duplicate()
	var layout := _bond_network_layout(hero_ids, graph_data)
	encyclopedia_bond_graph.set_meta("layout_size", layout.size)
	var graph_nodes := {}
	for hero_id_value in hero_ids:
		var hero_id := str(hero_id_value)
		var hero: Dictionary = heroes[hero_id]
		var node := _add_bond_graph_node(
			"hero_" + hero_id,
			_hero_name(hero_id),
			_hero_army_name(hero_id) + " · " + _roles_text(hero.roles),
			layout.positions["hero_" + hero_id],
			false
		)
		graph_nodes[str(node.name)] = node
	var faction_data: Array = graph_data.faction
	var faction_node := _add_bond_graph_node(
		"bond_" + str(faction_data[0]),
		t(str(faction_data[1]), str(faction_data[2])),
		t("全体本阵营武将 · " + str(faction_data[3]), "All faction heroes · " + str(faction_data[3])),
		layout.positions["bond_" + str(faction_data[0])],
		true
	)
	faction_node.set_meta("focus_all", true)
	faction_node.set_meta("focus_text", t(
		str(faction_data[1]) + " · 全体本阵营武将 · " + str(faction_data[3]) + "\n" + str(faction_data[4]),
		str(faction_data[2]) + " · All faction heroes · " + str(faction_data[3]) + "\n" + str(faction_data[5])
	))
	faction_node.tooltip_text = str(faction_node.get_meta("focus_text"))
	graph_nodes[str(faction_node.name)] = faction_node
	for bond in graph_data.bonds:
		var member_names: Array[String] = []
		for member_id in bond[3]:
			member_names.append(_hero_name(str(member_id)))
		var bond_body := t(str(bond[4]) + " · " + "、".join(member_names), str(bond[5]) + " · " + ", ".join(member_names))
		var bond_node := _add_bond_graph_node(
			"bond_" + str(bond[0]),
			t(str(bond[1]), str(bond[2])),
			bond_body,
			layout.positions["bond_" + str(bond[0])],
			true
		)
		bond_node.set_meta("focus_text", t(
			str(bond[1]) + " · " + str(bond[4]) + " · " + "、".join(member_names) + "\n" + str(bond[6]),
			str(bond[2]) + " · " + str(bond[5]) + " · " + ", ".join(member_names) + "\n" + str(bond[7])
		))
		bond_node.tooltip_text = str(bond_node.get_meta("focus_text"))
		graph_nodes[str(bond_node.name)] = bond_node
	for edge in layout.edges:
		var first_name := str(edge[0])
		var second_name := str(edge[1])
		if not graph_nodes.has(first_name) or not graph_nodes.has(second_name):
			continue
		var from_name := first_name
		var to_name := second_name
		if float(graph_nodes[from_name].position_offset.x) > float(graph_nodes[to_name].position_offset.x):
			from_name = second_name
			to_name = first_name
		encyclopedia_bond_graph.connect_node(from_name, 0, to_name, 0)
	call_deferred("_arrange_encyclopedia_bond_graph")

func _arrange_encyclopedia_bond_graph() -> void:
	if encyclopedia_mode != "bonds" or not is_instance_valid(encyclopedia_bond_graph):
		return
	await get_tree().process_frame
	if encyclopedia_mode != "bonds" or not is_instance_valid(encyclopedia_bond_graph):
		return
	var layout_size: Vector2 = encyclopedia_bond_graph.get_meta("layout_size", Vector2(1800, 900))
	var available_size := encyclopedia_bond_graph.size - Vector2(36, 36)
	var fit_zoom := minf(available_size.x / maxf(1.0, layout_size.x), available_size.y / maxf(1.0, layout_size.y))
	encyclopedia_bond_graph.zoom = clampf(fit_zoom, 0.48, 0.88)
	await get_tree().process_frame
	if encyclopedia_mode != "bonds" or not is_instance_valid(encyclopedia_bond_graph):
		return
	encyclopedia_bond_graph.scroll_offset = Vector2.ZERO

func _render_weapon_encyclopedia() -> void:
	for weapon in SHU_WEAPON_CODEX:
		var owner_id := str(weapon.id)
		encyclopedia_preview_hero_ids.append(owner_id)
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 410)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.tooltip_text = t("点击放大武器图片", "Click to enlarge weapon artwork")
		card.gui_input.connect(_on_encyclopedia_card_input.bind(owner_id))
		if _is_mobile_ui(): card.mouse_filter = Control.MOUSE_FILTER_PASS
		_style(card, Color("#191d19"), 12, FACTION_COLORS.shu, 2)
		var card_box := VBoxContainer.new()
		card_box.add_theme_constant_override("separation", 8)
		card.add_child(card_box)
		var weapon_image := TextureRect.new()
		weapon_image.texture = load(str(weapon.path))
		weapon_image.material = _weapon_cutout_material()
		weapon_image.custom_minimum_size.y = 310
		weapon_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		weapon_image.size_flags_vertical = Control.SIZE_EXPAND_FILL
		weapon_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		weapon_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		weapon_image.mouse_filter = Control.MOUSE_FILTER_PASS if _is_mobile_ui() else Control.MOUSE_FILTER_STOP
		weapon_image.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		weapon_image.tooltip_text = t("点击放大武器图片", "Click to enlarge weapon artwork")
		weapon_image.gui_input.connect(_on_encyclopedia_card_input.bind(owner_id))
		card_box.add_child(weapon_image)
		var weapon_name := _label(_weapon_codex_name(weapon), 24, FACTION_COLORS.shu.lightened(0.34))
		weapon_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_box.add_child(weapon_name)
		var owner := _label(t("归属：", "Owner: ") + _weapon_codex_owner(weapon), 16, Color("#e8e2cf"))
		owner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_box.add_child(owner)
		encyclopedia_grid.add_child(card)

func _start_new_from_menu() -> void:
	menu_overlay.hide()
	_new_game()

func _continue_from_menu() -> void:
	menu_overlay.hide()
	if not _load_game(): menu_overlay.show()

func _show_main_menu() -> void:
	if battle_running: return
	continue_button.disabled = not FileAccess.file_exists(SAVE_PATH)
	draft_overlay.hide()
	menu_overlay.show()

func _toggle_language() -> void:
	language = "en" if language == "zh" else "zh"
	_render()

func _skill_detail_legacy(hero_id: String) -> String:
	var hero: Dictionary = heroes.get(hero_id, {})
	var value := str(hero.get("detail_zh", "")) if language == "zh" else str(hero.get("detail_en", ""))
	var bond_markers := ["羁绊", "组成", "桃园结义", "五虎上将", "七进七出", "一骑当千", "宿命之敌", "飞火流星", "四英杰", "孙氏之志", "神亭酣战", "江表双锋", "江东柱石", "赤壁苦计", "君臣同心", "With ", " with ", " bond", "Bond"]
	var kept: Array[String] = []
	for clause in value.replace("。", "；").split("；", false):
		var is_bond_clause := false
		for marker in bond_markers:
			if clause.contains(marker):
				is_bond_clause = true
				break
		if not is_bond_clause:
			kept.append(clause.strip_edges())
	return ("；".join(kept) + ("。" if language == "zh" and not kept.is_empty() else "")).strip_edges()

func _skill_detail(hero_id: String) -> String:
	match hero_id:
		"liubei": return t("仁德回春：为当前生命比例最低的友军施加持续4秒、每秒200%技能强度的治疗；溢出治疗转为主公回血。", "Benevolent Renewal: Heal the lowest-HP-ratio ally for 200% SKILL each second for 4s; overflow restores the ruler.")
		"guanyu": return t("青龙偃月：劈砍目标整列，每名敌人受到180%技能强度伤害。", "Green Dragon: Cleave the target column for 180% SKILL damage per enemy.")
		"zhangfei": return t("燕人号令：强化己方前排，1/2/3星分别增伤15%/20%/30%，持续3秒。", "Roar Command: Empower the allied front row for 3s; stars grant 15%/20%/30% damage.")
		"zhaoyun": return t("龙胆连刺：随机选择一名射程内敌人，快速攻击同一目标5次，每次造成50%技能强度伤害。", "Dragon Spear: Randomly select an enemy in range and strike it 5 times for 50% SKILL each.")
		"liushan": return t("蜀主鼓舞：强化同列前军4秒，1/2/3星分别增伤25%/35%/55%。", "Royal Encouragement: Empower the allied vanguard in the same column for 4s; stars grant 25%/35%/55% damage.")
		"huangzhong": return t("百步穿杨：射击随机可攻击格，造成200%技能强度伤害。", "Piercing Arrow: Shoot a random reachable tile for 200% SKILL damage.")
		"machao": return t("铁骑贯阵：锁定当前血量最低敌人所在列，前军/中军/后军依次受到200%/170%/140%技能强度贯穿伤害。", "Iron Cavalry: Pierce the column containing the lowest-current-HP enemy for 200%/170%/140% SKILL damage by row.")
		"madai": return t("斩将突袭：随机攻击敌方前军，1/2/3星分别造成目标最大生命60%/70%/85%的伤害；没有敌方前军时攻击空格，对主公造成1000/1500/2000点伤害。", "Execution Raid: Hit a random enemy frontliner for 60%/70%/85% max HP by star; if none remains, strike an empty tile for 1000/1500/2000 ruler damage.")
		"weiyan": return t("狂骨横斩：攻击正前方及其同排相邻格，造成180%技能强度伤害，并回复实际伤害40%的生命。", "Rebel Fang: Hit the facing tile and adjacent tiles for 180% SKILL, healing 40% of actual damage.")
		"zhugeliang": return t("八阵奇谋：随机选择敌方格子，对目标及同列相邻格造成200%技能强度法术伤害。", "Eight-Formation Stratagem: Deal 200% SKILL magic damage to a random enemy tile and its vertical neighbors.")
		"jiangwei": return t("北伐：对随机可攻击目标造成160%技能强度法术伤害，并获得15%减伤5秒。", "Northern Expedition: Deal 160% SKILL magic damage to a random reachable target and gain 15% reduction for 5s.")
		"pangtong": return t("连环计：造成80%技能强度法术伤害并锁住目标行动条2秒。", "Chain Scheme: Deal 80% SKILL magic damage and freeze one target's gauge for 2s.")
		"menghuo": return t("蛮王震地：对可攻击的一整排造成105%技能强度物理伤害并眩晕0.8秒。", "Barbarian Quake: Deal 105% SKILL physical damage to a reachable row and stun for 0.8s.")
		"zhurong": return t("火神飞刃：造成145%技能强度法术伤害并灼烧4秒，每秒30%技能强度。", "Flame Blade: Deal 145% SKILL magic damage and burn for 4s at 30% SKILL per second.")
		"dailaidongzhu": return t("蛮骨狼袭：锁定行动条最高的可攻击敌人，造成180%技能强度物理伤害，并按1/2/3星压退25%/35%/50%行动条。", "Savage-Bone Wolf Assault: Strike the reachable enemy with the highest gauge for 180% SKILL and push it back 25%/35%/50% by star.")
		"caocao": return t("魏武震慑：随机攻击两名敌军，造成200%技能强度伤害并眩晕2.5秒。", "Dominion Stun: Strike two random enemies for 200% SKILL damage and stun for 2.5s.")
		"dianwei": return t("恶来袭后：随机攻击两名敌方后军，各造成200%技能强度伤害。", "Evil Guard Raid: Strike two random enemy rearguards for 200% SKILL damage each.")
		"xuchu": return t("虎卫破前：随机攻击两名敌方前军，各造成200%技能强度伤害。", "Tiger Guard Break: Strike two random enemy vanguards for 200% SKILL damage each.")
		"zhangliao": return t("威震回刃：攻击随机敌方一列，回旋刃飞出与返回各造成100%技能强度伤害。", "Returning Blade: Strike a random enemy column for 100% SKILL on both the outward and returning passes.")
		"yuejin": return t("先登乱射：随机攻击三名敌军，各造成100%技能强度伤害。", "Vanguard Volley: Strike three random enemies for 100% SKILL damage each.")
		"xuhuang": return t("撼地开山：攻击敌方前军整排，造成125%技能强度伤害并眩晕2秒。", "Earth-Splitting Axe: Strike the enemy vanguard row for 125% SKILL damage and stun for 2s.")
		"zhanghe": return t("巧变连枪：随机攻击一名敌方前军，造成200%技能强度伤害并眩晕1.5秒。", "Coiling Spear Chain: Strike a random enemy vanguard for 200% SKILL damage and stun for 1.5s.")
		"yujin": return t("毅重护阵：为当前生命值最低的友军施加200点加其3%最大生命的护盾。", "Resolute Ward: Shield the ally with the lowest current HP for 200 plus 3% max HP.")
		"xiahouyuan": return t("神速震袭：随机攻击2名敌军，造成175%技能强度伤害并眩晕1.5秒；目标已经眩晕时伤害提高至250%。", "Swift Suppression: Strike 2 random enemies for 175% SKILL and stun for 1.5s; deal 250% to already-stunned targets.")
		"caoren": return t("樊城镇远：随机攻击2名敌方后军，造成150%技能强度伤害并眩晕1.5秒；释放后6秒内受到敌方后军的伤害减少20%。", "Rearward Bulwark: Strike 2 enemy rearguards for 150% SKILL and stun for 1.5s; take 20% less damage from rearguards for 6s.")
		"xiahoudun": return t("刚烈镇前：随机攻击2名敌方前军，造成150%技能强度伤害并眩晕1.5秒；释放后6.5秒内受到敌方前军的伤害减少20%。", "Vanguard Bulwark: Strike 2 enemy vanguards for 150% SKILL and stun for 1.5s; take 20% less damage from vanguards for 6.5s.")
		"simayi": return t("雷霆谋断：对随机2名敌人释放雷击，造成175%技能强度伤害。", "Thunder Judgment: Strike 2 random enemies with lightning for 175% SKILL damage.")
		"guojia": return t("遗计冰封：随机冻结2名敌人4秒，期间行动条停止；冻结期间受到伤害会提前解冻，并额外受到剩余秒数×400点伤害。", "Frozen Legacy: Freeze 2 random enemies for 4s, stopping their gauges; damage shatters the freeze for 400 extra damage per remaining second.")
		"xunyu": return t("王佐疾策：随机使2名友军行动条速度提高20%，持续6秒。", "Royal Acceleration: Grant 2 random allies 20% gauge speed for 6s.")
		"jiaxu": return t("毒士奇谋：使随机2名敌军中毒5秒，每秒损失1%最大生命值。", "Venomous Scheme: Poison 2 random enemies for 5s, dealing 1% max HP per second.")
		"sunjian": return t("猛虎绝命：每回合首次消耗40%当前生命，之后每次消耗10%，攻击正前方敌军并造成等同于实际消耗生命100%的伤害。", "Tiger's Resolve: Spend 40% current HP on the first cast each round and 10% thereafter, dealing 100% of HP spent to the facing enemy.")
		"sunce": return t("小霸王连击：攻击正前方及其左侧敌军，各造成200%技能强度伤害；自身每损失10%生命，伤害提高2%。", "Conqueror's Twin Assault: Hit the facing enemy and its left neighbor for 200% SKILL each; gain 2% damage per 10% HP missing.")
		"sunquan": return t("江东制衡：随机对一名敌军造成其当前生命8%的伤害；自身最大生命提高200（最多为初始最大生命2倍），随后恢复10%已损失生命。", "Jiangdong Balance: Deal 8% of a random enemy's current HP; gain 200 max HP up to 2x initial max HP, then restore 10% missing HP.")
		"sunshangxiang": return t("枭姬叠势：随机攻击一名敌军，造成100%技能强度伤害，每次释放后技能强度提高1点；任意友军阵亡时技能强度提高5点。", "Heroine's Growing Volley: Strike a random enemy for 100% SKILL and gain 1 SKILL after each cast; gain 5 SKILL whenever an ally falls.")
		"zhouyu": return t("赤壁点火：随机选择2个敌方格，各造成100%技能强度法术伤害并灼烧3秒，每秒造成50%技能强度伤害。", "Red Cliffs: Ignite 2 random enemy tiles for 100% SKILL magic damage and burn for 3s at 50% SKILL per second.")
		"luxun": return t("火烧连营：发射火球造成200%技能强度法术伤害，并向相邻敌方单元格弹射1次。", "Flames of Camp: Launch a fireball for 200% SKILL magic damage and bounce once to an adjacent enemy tile.")
		"lvmeng": return t("白衣渡江：攻击敌方后军，造成400%技能强度物理伤害，随后隐身3秒，期间不会被选为攻击目标。", "White-Robed Raid: Strike an enemy rearguard for 400% SKILL physical damage, then enter stealth for 3s and cannot be selected.")
		"lusu": return t("连横稳阵：选择当前生命值总量最低的友军，恢复15%最大生命并使本场战斗最大生命提高200。", "Alliance: Restore 15% max HP to the ally with the lowest current HP total and grant 200 max HP for this battle.")
		"daqiao": return t("国色流离：治疗当前生命比例最低的友军。", "River Blossom: Heal the ally with the lowest HP ratio.")
		"xiaoqiao": return t("天香缓阵：随机选择两名敌方后军，使其减速6秒，期间行动条速度降低35%。", "Gentle Breeze: Slow two random enemy rearguards by 35% for 6s.")
		"taishici": return t("神亭烈戟：攻击射程内行动条最高的两名敌人，造成150%技能强度伤害，并灼烧5秒，每秒造成20%技能强度伤害。", "Blazing Twin Halberds: Strike the two reachable enemies with the highest gauges for 150% SKILL and burn for 5s at 20% SKILL per second.")
		"ganning": return t("锦帆并击：自身与同排左侧友军分别攻击一名随机敌方后军，各造成150%自身技能强度的伤害；友军协击不消耗行动条。", "Bell-Raider Twin Assault: Gan Ning and the ally directly to his left each strike a random enemy rearguard for 150% of their own SKILL; the assist costs no gauge.")
		"huanggai": return t("苦肉焚阵：消耗10%最大生命，对随机敌方一列造成等同于实际消耗生命33%的伤害；生命不足时消耗全部生命并在攻击后阵亡。", "Bitter-Flesh Column: Spend 10% max HP to damage a random enemy column for 33% of HP spent; if HP is insufficient, spend it all and fall after attacking.")
		"lvbu": return t("无双横扫：随机选择可攻击排，对整排造成160%技能强度伤害；空排则穿透主公。", "Peerless Sweep: Deal 160% SKILL to a random reachable row; an empty row pierces the ruler.")
		"diaochan": return t("美人离间：魅惑技能数值最高的敌人1.5秒，使其行动条停止。", "Beauty's Scheme: Charm the highest-SKILL enemy for 1.5s, freezing its gauge.")
		"dongzhuo": return t("暴君横征：造成100%技能强度+min(800%技能强度，当前生命6%)伤害。", "Tyrant's Levy: Deal 100% SKILL + min(800% SKILL, 6% current HP).")
	return _true_damage_text(_skill_detail_legacy(hero_id))

func _bond_entry(name_zh: String, name_en: String, member_ids: Array, effect_zh: String, effect_en: String) -> String:
	var member_names: Array[String] = []
	for id in member_ids: member_names.append(_hero_name(str(id)))
	return t(name_zh, name_en) + "（" + "、".join(member_names) + "）：" + t(effect_zh, effect_en)

func _hero_bond_detail(hero_id: String) -> String:
	var entries: Array[String] = []
	var faction: String = heroes[hero_id].f
	var faction_ids: Array = heroes.keys().filter(func(id): return heroes[id].f == faction)
	var faction_names: Array = {"shu":["汉室北伐", "Han Expedition"], "wei":["魏武中枢", "Wei Command"], "wu":["江东联动", "Jiangdong Relay"], "qun":["乱世争衡", "Chaos Struggle"]}[faction]
	var faction_effects: Array = {
		"shu":["2/5/8人时，本武将承伤降低2%/5%/8%；8人时受伤叠加2%额外减伤，最多3层，释放技能后清空。", "At 2/5/8, this hero takes 2%/5%/8% less damage; at 8, damage taken adds 2% reduction up to 3 stacks, cleared after casting."],
		"wei":["2/5/8人时，本武将控制时长提高3%/8%/15%；8人时，对带有任意控制或减益的目标伤害提高15%。", "At 2/5/8, this hero gains 3%/8%/15% control duration; at 8, damage to any controlled or debuffed target increases by 15%."],
		"wu":["2/5/8人时，本武将最大生命提高2%/5%/8%；8人时，每场战斗首次吴将濒死会触发全体吴将生命均摊并恢复10%最大生命。", "At 2/5/8, this hero gains 2%/5%/8% max HP; at 8, the first lethal hit each battle equalizes Wu health and restores 10% max HP."],
		"qun":["2/5/8人时，本武将技能冷却缩短3%/8%/15%；8人时，每次释放技能有20%概率连续释放两次。", "At 2/5/8, this hero gains 3%/8%/15% cooldown reduction; at 8, each cast has a 20% chance to cast twice."]
	}[faction]
	entries.append(_bond_entry(faction_names[0], faction_names[1], faction_ids, faction_effects[0], faction_effects[1]))
	var peach: Array = ["liubei", "guanyu", "zhangfei"]
	if peach.has(hero_id):
		var effects: Array = {"liubei":["持续治疗由每秒200%技能强度提高为300%技能强度。", "Regeneration rises from 200% to 300% SKILL each second."], "guanyu":["按整列斩实际造成伤害的30%恢复自身生命。", "Heal for 30% of actual column-cleave damage dealt."], "zhangfei":["前排增伤期间额外获得20%减伤。", "The front row also gains 20% damage reduction during the command."]}[hero_id]
		entries.append(_bond_entry("桃园结义", "Peach Garden", peach, effects[0], effects[1]))
	var five_tigers: Array = ["guanyu", "zhangfei", "zhaoyun", "huangzhong", "machao"]
	if five_tigers.has(hero_id):
		var effects: Array = {"guanyu":["整列斩伤害倍率由180%提高为300%技能强度。", "Column-cleave damage rises from 180% to 300% SKILL."], "zhangfei":["前军号令由3秒延长至6秒。", "Front-row Command lasts 6s instead of 3s."], "zhaoyun":["五次连刺伤害依次提高为50%/70%/90%/110%/130%技能强度。", "The five thrusts escalate to 50%/70%/90%/110%/130% SKILL."], "huangzhong":["大招固定选择敌方前军格并提高至500%技能强度。", "The active targets an enemy front tile at 500% SKILL."], "machao":["马超带来全军增益：我方所有前军与中军行动条速度提高15%。", "Ma Chao grants the army-wide effect: all allied vanguards and midguards gain 15% gauge speed."]}[hero_id]
		entries.append(_bond_entry("五虎上将", "Five Tiger Generals", five_tigers, effects[0], effects[1]))
	var personal: Dictionary = {
		"liubei":[["夜梦北斗", "Northern Dream", ["liubei", "liushan"], "持续治疗由4秒延长50%至6秒。", "Regeneration duration increases 50%, from 4s to 6s."], ["卧龙辅汉", "Wolong Aids Han", ["liubei", "zhugeliang"], "持续治疗中的目标受到的法术伤害降低20%。", "The regenerating target takes 20% less magic damage."]],
		"liushan":[["夜梦北斗", "Northern Dream", ["liubei", "liushan"], "蜀主鼓舞额外作用于同列后排友军。", "Royal Encouragement also affects the allied backliner in the same column."], ["七进七出", "Seven Charges", ["zhaoyun", "liushan"], "蜀主鼓舞额外使被强化友军获得30%全能吸血：其造成伤害的30%用于恢复自身生命，持续4秒。", "Royal Encouragement also grants the empowered ally 30% omnivamp for 4s, healing for 30% of damage dealt."]],
		"zhaoyun":[["七进七出", "Seven Charges", ["zhaoyun", "liushan"], "连刺变为7次，每次造成50%技能强度伤害，并无视射程强制攻击敌方后军；若同时激活五虎上将，七次伤害才递增至170%。", "Gain 7 thrusts at 50% SKILL each and ignore range to force an enemy rearguard. Only with Five Tigers also active do the 7 hits escalate to 170%."]],
		"machao":[["一骑当千", "One Rider", ["machao", "madai"], "铁骑贯阵不再递减，前军、中军、后军均受到200%技能强度伤害。", "Iron Cavalry no longer decays; front, middle, and rear all take 200% SKILL."]],
		"madai":[["一骑当千", "One Rider", ["machao", "madai"], "每场战斗开局行动条充满，可立即释放技能。", "Start every battle with a full gauge, ready to cast immediately."], ["宿命之敌", "Fated Enemies", ["madai", "weiyan"], "技能命中的武将被标记，额外承受40%伤害，持续15秒。", "The active marks its victim to take 40% more damage for 15s."]],
		"huangzhong":[["飞火流星", "Flying Meteor", ["huangzhong", "weiyan"], "自身箭击有50%概率暴击，暴击伤害变为原来的2倍。", "Huang Zhong's own shot has a 50% chance to critically strike for double damage."]],
		"weiyan":[["飞火流星", "Flying Meteor", ["huangzhong", "weiyan"], "敌方任一前军阵亡时，魏延恢复50%最大生命。", "Whenever an enemy frontliner falls, Wei Yan restores 50% max HP."], ["宿命之敌", "Fated Enemies", ["madai", "weiyan"], "释放技能后，为同排相邻友军及正后方的中军友军恢复15%最大生命。", "After casting, heal adjacent same-row allies and the midguard directly behind for 15% max HP."]],
		"jiangwei":[
			["北伐传承", "Northern Expedition Legacy", ["zhugeliang", "jiangwei"], "北伐追加攻击主目标斜对角最多两名敌人，各造成80%技能强度伤害；释放后的自身减伤由15%提高至30%，持续5秒。", "Northern Expedition adds up to two diagonal enemies at 80% SKILL each; post-cast damage reduction rises from 15% to 30% for 5s."]
		],
		"pangtong":[
			["卧龙凤雏", "Dragon and Phoenix", ["zhugeliang", "pangtong"], "连环计由单体扩展为中心及左右相邻三格；每格伤害由80%提高至100%技能强度，行动条锁定由2秒提高至2.5秒。该效果按两条普通羁绊的强度设计。", "Chain Scheme expands from one target to the center and horizontal neighbors; each tile rises from 80% to 100% SKILL and the gauge freeze rises from 2s to 2.5s. This is intentionally worth two standard bonds."]
		],
		"menghuo":[
			["七擒孟获", "Seven Captures", ["zhugeliang", "menghuo"], "蛮王震地结束后追加一次60%技能强度的整排余震，余震不重复眩晕。", "Barbarian Quake adds a 60% SKILL row-wide aftershock without a second stun."],
			["南蛮夫妇", "Nanman Couple", ["menghuo", "zhurong"], "蛮王震地对灼烧目标伤害提高40%，并将这些目标的眩晕时间由0.8秒延长至1.2秒。", "Barbarian Quake deals +40% damage to burning targets and extends their stun from 0.8s to 1.2s."],
			["蛮王援军", "Barbarian Reinforcements", ["menghuo", "dailaidongzhu"], "蛮王震地额外使每名命中武将损失20%行动条。", "Every hero hit by Barbarian Quake also loses 20% gauge."]
		],
		"zhurong":[
			["南蛮夫妇", "Nanman Couple", ["menghuo", "zhurong"], "火神飞刃向主目标左右同排相邻格各弹射一次，造成70%技能强度伤害并施加完整灼烧。", "Flame Blade bounces to both horizontal neighbors for 70% SKILL and applies its full burn."],
			["姐弟同心", "Sibling Bond", ["dailaidongzhu", "zhurong"], "火神飞刃的灼烧由4秒、每秒30%提高至6秒、每秒40%技能强度。", "Flame Blade's burn rises from 4s at 30% SKILL per second to 6s at 40%."]
		],
		"dailaidongzhu":[
			["蛮王援军", "Barbarian Reinforcements", ["menghuo", "dailaidongzhu"], "蛮骨狼袭追加攻击主目标同列上下相邻格，造成90%技能强度伤害并压退15%行动条。", "Savage-Bone Wolf Assault adds vertical neighbors at 90% SKILL and pushes their gauges back by 15%."],
			["姐弟同心", "Sibling Bond", ["dailaidongzhu", "zhurong"], "蛮骨狼袭施加4秒、每秒30%技能强度的灼烧；若目标原本已灼烧，本次直接伤害提高20%。", "Savage-Bone Wolf Assault applies a 4s burn at 30% SKILL per second; direct damage gains +20% against already burning targets."]
		],
		"zhugeliang":[
			["卧龙凤雏", "Dragon and Phoenix", ["zhugeliang", "pangtong"], "八阵奇谋额外影响中心格左右两个同排相邻格。", "Eight-Formation Stratagem also affects the two horizontal neighbors."],
			["北伐传承", "Northern Expedition Legacy", ["zhugeliang", "jiangwei"], "八阵奇谋额外影响中心格四个斜对角相邻格。", "Eight-Formation Stratagem also affects all four diagonal neighbors."],
			["七擒孟获", "Seven Captures", ["zhugeliang", "menghuo"], "八阵奇谋伤害提高20%并施加火攻标记；诸葛亮再次命中标记者时伤害再提高30%。", "Eight-Formation Stratagem gains +20% damage and applies Fire Assault; Zhuge Liang's next hit against a marked target gains another +30%."],
			["卧龙辅汉", "Wolong Aids Han", ["liubei", "zhugeliang"], "本次技能每多命中一名武将，所有受击格伤害提高10%；命中9人时提高80%。", "Each additional enemy hit grants +10% damage to every affected tile, reaching +80% at nine enemies."]
		]
	}
	for data in personal.get(hero_id, []): entries.append(_bond_entry(data[0], data[1], data[2], data[3], data[4]))
	var combo_defs: Array = [
		[["caocao", "dianwei"], "古之恶来", "Evil of Old", {"caocao":["技能目标数增加1；命中后军时伤害提高100%，眩晕由2.5秒延长至5秒。", "Gain 1 target; against rearguards, damage gains +100% and stun rises from 2.5s to 5s."], "dianwei":["恶来袭后的目标数由2名提高至3名。", "Evil Guard Raid targets 3 rearguards instead of 2."]}],
		[["caocao", "xuchu"], "虎卫护主", "Tiger Guard", {"caocao":["技能目标数增加1；命中前军时伤害提高100%，眩晕由2.5秒延长至5秒。", "Gain 1 target; against vanguards, damage gains +100% and stun rises from 2.5s to 5s."], "xuchu":["虎卫破前的目标数由2名提高至3名。", "Tiger Guard Break targets 3 vanguards instead of 2."]}],
		[["dianwei", "xuchu"], "魏武双卫", "Twin Wei Guards", {"dianwei":["恶来袭后伤害由200%技能强度提高至400%。", "Evil Guard Raid rises from 200% to 400% SKILL."], "xuchu":["虎卫破前伤害由200%技能强度提高至400%。", "Tiger Guard Break rises from 200% to 400% SKILL."]}],
		[["zhangliao", "yuejin"], "逍遥津先锋", "Hefei Vanguard", {"zhangliao":["回旋刃飞出与返回的每段伤害由100%提高至200%技能强度。", "Both boomerang passes rise from 100% to 200% SKILL."], "yuejin":["目标数由3名提高至5名，伤害由100%提高至150%技能强度。", "Targets rise from 3 to 5 and damage rises from 100% to 150% SKILL."]}],
		[["zhanghe", "xuhuang"], "巧变开山", "Adaptive Vanguard", {"zhanghe":["巧变连枪命中前军后，再随机攻击一名与其相邻的前军。", "After hitting the vanguard, chain to one random adjacent vanguard."], "xuhuang":["撼地开山的整排伤害由125%提高至200%技能强度。", "Earth-Splitting Axe row damage rises from 125% to 200% SKILL."]}],
		[["zhouyu", "luxun", "lusu", "lvmeng"], "四英杰", "Four Heroes", {"zhouyu":["赤壁点火额外选择2个格子，总共点燃4格。", "Red Cliffs selects 2 extra tiles, igniting 4 in total."], "luxun":["火球的总弹射次数由1次提高至3次。", "Fireball total bounces increase from 1 to 3."], "lusu":["改为治疗当前生命值总量最低的两名友军，各恢复20%最大生命并使本场战斗最大生命提高350。", "Treat the two allies with the lowest current HP totals, restoring 20% max HP and granting 350 max HP to each for this battle."], "lvmeng":["白衣渡江命中的后军恐惧4秒，行动条停止且每秒受到5%最大生命伤害。", "White-Robed Raid fears the struck rearguard for 4s, freezing its gauge and dealing 5% max HP each second."]}],
		[["lvbu", "diaochan", "dongzhuo"], "鬼神权倾", "Tyrant's Court", {"lvbu":["释放无双横扫后获得4秒致死保护。", "Gain a 4s death ward after Peerless Sweep."], "diaochan":["魅惑持续时间提高50%，由1.5秒变为2.25秒。", "Charm duration rises 50%, from 1.5s to 2.25s."], "dongzhuo":["当前生命追加比例由6%提高至12%，并在开场获得2秒致死保护。", "Current-HP ratio rises from 6% to 12% and gain a 2s opening death ward."]}],
		[["zhangliao", "yuejin", "zhanghe", "xuhuang", "yujin"], "五子良将", "Five Elite Generals", {"zhangliao":["两段回旋刃命中的敌人获得40%易损，持续3.5秒。", "Enemies hit by the two passes take 40% more damage for 3.5s."], "yuejin":["改为攻击7名敌人，造成200%技能强度伤害，并施加4秒重伤，使治疗和自身回复降低60%。", "Target 7 enemies at 200% SKILL and inflict 4s Grievous Wounds, reducing healing and self-recovery by 60%."], "zhanghe":["连锁从两名前军继续扩散至相邻中军和后军；伤害提高至300%，攻击前已眩晕的目标时提高至500%。", "The two-vanguard chain spreads to adjacent midguard and rearguard; damage rises to 300%, or 500% if the target was already stunned."], "xuhuang":["改为攻击随机一整排，伤害提高至300%技能强度，眩晕由2秒延长至5秒。", "Strike a random entire row at 300% SKILL and extend stun from 2s to 5s."], "yujin":["改为保护当前生命最低的3名友军，护盾提高至300点加目标5%最大生命。", "Protect the 3 lowest-current-HP allies for 300 plus 5% of each target's max HP."]}],
		[["xiahouyuan", "caoren"], "神速镇远", "Swift Bulwark", {"xiahouyuan":["冷却缩短0.5秒，眩晕延长0.5秒。", "Cooldown -0.5s and stun +0.5s."], "caoren":["目标增加1名，眩晕延长0.5秒，后军伤害减免提高10%。", "Gain 1 target, +0.5s stun, and +10% rear damage reduction."]}],
		[["xiahouyuan", "xiahoudun"], "夏侯同心", "Xiahou Brothers", {"xiahouyuan":["冷却缩短0.5秒，眩晕延长0.5秒。", "Cooldown -0.5s and stun +0.5s."], "xiahoudun":["目标增加1名，眩晕延长0.5秒，前军伤害减免提高10%。", "Gain 1 target, +0.5s stun, and +10% vanguard damage reduction."]}],
		[["caoren", "xiahoudun"], "魏武双壁", "Twin Bulwarks", {"caoren":["目标增加1名，眩晕延长0.5秒，后军伤害减免提高10%。", "Gain 1 target, +0.5s stun, and +10% rear damage reduction."], "xiahoudun":["目标增加1名，眩晕延长0.5秒，前军伤害减免提高10%。", "Gain 1 target, +0.5s stun, and +10% vanguard damage reduction."]}],
		[["simayi", "guojia"], "雷霆冰策", "Thunder and Frost", {"simayi":["雷击目标增加1名，伤害倍率提高25%技能强度。", "Gain 1 lightning target and +25% SKILL ratio."], "guojia":["冻结目标增加1名，冷却缩短0.5秒。", "Gain 1 freeze target and -0.5s cooldown."]}],
		[["simayi", "xunyu"], "鹰视王佐", "Eagle Eye and Royal Aid", {"simayi":["雷击目标增加1名，伤害倍率提高25%技能强度。", "Gain 1 lightning target and +25% SKILL ratio."], "xunyu":["加速目标增加1名，冷却缩短0.4秒。", "Gain 1 acceleration target and -0.4s cooldown."]}],
		[["simayi", "jiaxu"], "鹰视毒谋", "Eagle Eye and Venom", {"simayi":["雷击目标增加1名，伤害倍率提高25%技能强度。", "Gain 1 lightning target and +25% SKILL ratio."], "jiaxu":["中毒目标增加1名，持续时间延长0.5秒。", "Gain 1 poison target and +0.5s duration."]}],
		[["guojia", "xunyu"], "遗计王佐", "Frozen Royal Plan", {"guojia":["冻结目标增加1名，冷却缩短0.5秒。", "Gain 1 freeze target and -0.5s cooldown."], "xunyu":["加速目标增加1名，冷却缩短0.4秒。", "Gain 1 acceleration target and -0.4s cooldown."]}],
		[["guojia", "jiaxu"], "冰毒奇策", "Frost and Venom", {"guojia":["冻结目标增加1名，冷却缩短0.5秒。", "Gain 1 freeze target and -0.5s cooldown."], "jiaxu":["中毒目标增加1名，持续时间延长0.5秒。", "Gain 1 poison target and +0.5s duration."]}],
		[["xunyu", "jiaxu"], "王佐毒策", "Royal Venom", {"xunyu":["加速目标增加1名，冷却缩短0.4秒。", "Gain 1 acceleration target and -0.4s cooldown."], "jiaxu":["中毒目标增加1名，持续时间延长0.5秒。", "Gain 1 poison target and +0.5s duration."]}],
		[["sunjian", "sunce", "sunquan", "sunshangxiang"], "孙氏之志", "Sun Legacy", {"sunjian":["技能当前生命消耗由首次40%/后续10%提高至80%/20%；阵亡后使存活吴将本回合伤害提高10%。", "Current-HP costs rise from 40%/10% to 80%/20%; on death, surviving Wu allies gain +10% damage for the round."], "sunce":["技能基础倍率由200%提高至400%；每损失10%生命获得4%伤害减免。", "Base skill damage rises from 200% to 400%; gain 4% damage reduction per 10% HP missing."], "sunquan":["每次最大生命提高400并额外提高等同于已损失生命10%的上限，最多达到初始最大生命4倍；随后恢复15%已损失生命。", "Each cast grants 400 plus 10% missing HP as max HP up to 4x initial max HP, then restores 15% missing HP."], "sunshangxiang":["冷却缩短至6秒；每次连射2击，每击150%技能强度；释放后技能强度提高2点。", "Cooldown becomes 6s; fire twice at 150% SKILL each and gain 2 SKILL after casting."]}],
		[["daqiao", "xiaoqiao"], "江东双姝", "Jiangdong Sisters", {"daqiao":["治疗量提高50%，并追加1次65%效果的治疗。", "Healing +50% and add one heal at 65% effect."], "xiaoqiao":["天香缓阵的行动条减速由35%提高至60%。", "Gentle Breeze's gauge slow rises from 35% to 60%."]}],
		[["lvmeng", "ganning"], "白衣奇袭", "White-Robed Ambush", {"lvmeng":["每次进入隐身后，下一次造成的伤害提高60%。", "After entering stealth, the next damage dealt gains +60%."], "ganning":["攻击生命值低于50%的敌人时，本次伤害提高50%。", "Deal 50% more damage when the target is below 50% HP."]}],
		[["sunce", "taishici"], "神亭酣战", "Shenting Duel", {"sunce":["追加第二段攻击正前方和右侧敌军；正前方会连续承受两次伤害。", "Add a second strike against the facing and right enemies; the facing enemy is hit twice."], "taishici":["技能目标数由行动条最高的2人提高至3人。", "Target the 3 highest-gauge enemies instead of 2."]}],
		[["sunce", "daqiao"], "江东佳偶", "Jiangdong Couple", {"sunce":["每次释放主动技能后恢复12%最大生命。", "Heal 12% max HP after each active."], "daqiao":["受治疗友军每损失10%生命，本次受到的治疗提高4%。", "The healed ally gains +4% healing received per 10% HP missing."]}],
		[["zhouyu", "xiaoqiao"], "琴瑟和鸣", "Harmonious Zither", {"zhouyu":["赤壁点火的灼烧持续时间由3秒延长至6秒。", "Red Cliffs burn duration rises from 3s to 6s."], "xiaoqiao":["天香缓阵的目标数由2名提高至3名，持续时间由6秒延长至8秒。", "Gentle Breeze rises from 2 to 3 targets and from 6s to 8s."]}],
		[["zhouyu", "huanggai"], "赤壁苦计", "Red Cliffs Ruse", {"zhouyu":["直接伤害与每次灼烧伤害按目标已损失生命提高，每损失10%生命增伤5%。", "Direct and burn damage gain +5% per 10% target HP missing."], "huanggai":["整列命中格灼烧6秒，每秒造成等同于本次实际消耗生命5%的伤害；空格灼烧会伤害主公。", "Burn struck column tiles for 6s at 5% of HP spent per second; burning empty tiles damages the ruler."]}],
		[["huanggai", "sunjian"], "江东柱石", "Pillars of Jiangdong", {"huanggai":["最大生命消耗由10%提高至15%，整列伤害由实际消耗生命33%提高至45%。", "Max-HP cost rises from 10% to 15%; column damage rises from 33% to 45% of HP spent."], "sunjian":["开局行动条充满；伤害由实际消耗生命100%提高至150%。", "Start with a full gauge; damage rises from 100% to 150% of HP spent."]}],
		[["taishici", "ganning"], "江表双锋", "Twin Blades of Jiangbiao", {"taishici":["目标已处于灼烧状态时，本次直接伤害由150%提高至300%技能强度。", "Direct damage rises from 150% to 300% SKILL against burning targets."], "ganning":["自身与左侧友军的本次协击倍率由150%提高至250%技能强度。", "Both Gan Ning and his left ally rise from 150% to 250% SKILL for the assist."]}],
		[["luxun", "sunquan"], "君臣同心", "Sovereign and Minister", {"luxun":["火球伤害提高50%，命中灼烧目标时再提高50%，合计提高100%。", "Fireball gains +50% damage and another +50% against burning targets, for +100% total."], "sunquan":["技能伤害由目标当前生命8%提高至12%，冷却由10秒缩短至8秒。", "Skill damage rises from 8% to 12% of target current HP and cooldown drops from 10s to 8s."]}],
		[["dingfeng", "xusheng"], "江表虎臣", "Tiger Ministers", {"dingfeng":["雪中奋短兵追加攻击目标左右相邻格，造成70%技能强度伤害并压退15%行动条。", "Snowbound Blades also hits horizontal neighbors for 70% SKILL and pushes their gauges back 15%."], "xusheng":["宿卫水阵的控制持续时间提高50%。", "Guardian Water Formation's control duration increases by 50%."]}],
		[["yanliang", "wenchou", "qunzhanghe", "gaolan"], "河北四庭柱", "Hebei Pillars", {"yanliang":["开场获得1层紫幕，抵挡下一次主动技能。", "Start with 1 Purple Ward blocking the next active."], "wenchou":["开场获得1层紫幕，且指向技能有35%概率反弹60%伤害。", "Start with 1 ward; targeted skills have 35% chance to reflect 60% damage."], "qunzhanghe":["开场获得1层紫幕；主动还能为同列友军补充1层。", "Start with 1 ward; the active gives the column another ward."], "gaolan":["开场获得1层紫幕，抵挡下一次主动技能。", "Start with 1 ward blocking the next active."]}],
		[["yuji", "zhangjiao"], "天道", "Way of Heaven", {"yuji":["友军阵亡时有65%概率对随机敌人降下60%技能强度天雷。", "Allied deaths have 65% chance to strike a random enemy for 60% SKILL thunder."], "zhangjiao":["友军阵亡时有65%概率对随机敌人降下60%技能强度天雷。", "Allied deaths have 65% chance to strike a random enemy for 60% SKILL thunder."]}]
	]
	for definition in combo_defs:
		var members: Array = definition[0]
		if members.has(hero_id):
			var effects: Dictionary = definition[3]
			var effect: Array = effects[hero_id]
			entries.append(_bond_entry(definition[1], definition[2], members, effect[0], effect[1]))
	return "\n\n".join(entries)

func _bond_detail(faction: String) -> String:
	match faction:
		"shu": return t("汉室北伐（2/5/8）：全体蜀将承伤降低2%/5%/8%；8人时，每次受伤叠加2%额外减伤，最多3层达到14%，释放技能后清空额外层数。　桃园结义：刘备每秒治疗200%→300%技能强度；关羽按列斩实际伤害的30%自疗；张飞号令追加20%减伤。　五虎上将（5）：马超使全体前军和中军行动条速度提高15%；关羽列斩180%→300%；赵云五次连刺递增为50%/70%/90%/110%/130%。　七进七出：赵云变为7次连刺并强制攻击敌方后军；刘禅使被鼓舞友军获得4秒30%全能吸血。　一骑当千：马超贯穿全列均为200%，马岱开场立即行动。　宿命之敌：马岱施加40%易伤15秒，魏延为指定友军恢复15%最大生命。　飞火流星：黄忠有50%概率造成双倍伤害；敌方前军阵亡时魏延恢复50%最大生命。", "Han Expedition (2/5/8) grants 2%/5%/8% damage reduction. At 8, damage taken stacks another 2% up to three times (14% total), cleared after casting. Other listed Shu bonds retain their individual effects.")
		"wei": return t("魏武中枢（2/5/8）：全体魏将控制时长提高3%/8%/15%；8人时，对眩晕、冻结、减速、中毒及其他任意减益目标造成的伤害提高15%。　曹操双卫、夏侯三将、五子良将与司马懿、郭嘉、荀彧、贾诩的两两羁绊分别强化成员技能。", "Wei Command (2/5/8) grants 3%/8%/15% control duration. At 8, Wei heroes deal 15% more damage to targets with any control or debuff. The Cao guards, Xiahou trio, Five Elites, and six strategist pair bonds each empower their members.")
		"wu": return t("江东联动（2/5/8）：全体吴将最大生命提高2%/5%/8%；8人时，每场战斗首次有吴将即将阵亡，会按生命比例均摊全体存活吴将的生命，并各自恢复10%最大生命。　四英杰：周瑜额外点燃2格；陆逊火球总共弹射3次；鲁肃治疗两名最低当前生命友军并强化治疗与生命上限；吕蒙施加4秒恐惧。　琴瑟和鸣使周瑜灼烧延长至6秒，并使小乔减速3名后军8秒；江东双姝使小乔减速提高至60%；赤壁苦计强化周瑜点火；君臣同心强化陆逊火球；白衣奇袭强化吕蒙隐身后的下一次伤害。", "Jiangdong Relay (2/5/8) grants 2%/5%/8% max HP and its 8-unit survival effect. Four Heroes empowers Zhou Yu's tile count, Lu Xun's bounces, Lu Su's two-target treatment, and Lu Meng's fear. Harmonious Zither also empowers Xiao Qiao's target count and duration, while Jiangdong Sisters raises her slow to 60%. Other listed Wu bonds retain their individual effects.")
		"qun": return t("乱世争衡（2/5/8）：全体群雄武将技能冷却缩短3%/8%/15%；8人时，每次释放技能有20%概率连续释放两次。鬼神权倾、河北四庭柱和天道继续强化各自成员技能。", "Chaos Struggle (2/5/8) grants 3%/8%/15% skill cooldown reduction. At 8, every cast has a 20% chance to cast twice. Other Qun bonds retain their individual effects.")
	return ""

func _portrait_texture(hero_id: String) -> Texture2D:
	if portrait_cache.has(hero_id): return portrait_cache[hero_id]
	var source := _portrait_source_texture(hero_id)
	if source == null: return null
	var portrait := AtlasTexture.new()
	portrait.atlas = source
	portrait.region = Rect2(0, 0, source.get_width(), source.get_height() * 0.58)
	portrait_cache[hero_id] = portrait
	return portrait

func _portrait_source_texture(hero_id: String) -> Texture2D:
	if portrait_source_cache.has(hero_id):
		return portrait_source_cache[hero_id]
	var portrait_path := "res://ThreeKingdom/Portraits/pic/" + hero_id + ".png"
	if not ResourceLoader.exists(portrait_path):
		portrait_path = "res://ThreeKingdom/Portraits/" + hero_id + ".jpg"
	if not ResourceLoader.exists(portrait_path):
		var fallback := {"shu":"guanyu", "wei":"caocao", "wu":"zhouyu", "qun":"lvbu"}
		portrait_path = "res://ThreeKingdom/Portraits/" + fallback[heroes[hero_id].f] + ".jpg"
	var source: Texture2D = load(portrait_path)
	portrait_source_cache[hero_id] = source
	return source

func _portrait_rect(hero_id: String) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.texture = _portrait_texture(hero_id)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return portrait

func _render() -> void:
	if not is_instance_valid(title_label): return
	var campaign_title: Label = find_child("CampaignTitle", true, false)
	var bond_header: Label = find_child("BondHeader", true, false)
	campaign_title.text = t("闯关战局", "CAMPAIGN")
	bond_header.text = t("我方羁绊进度", "YOUR BOND PROGRESS")
	title_label.text = t("三国 · 羁绊战棋 · 征战", "THREE KINGDOMS · CAMPAIGN")
	round_label.text = t("最终决战", "FINAL BATTLE") if final_battle else t("关卡 ", "STAGE ") + str(round_number) + " / " + str(ROUND_LIMIT)
	phase_label.text = "◆ " + _phase_name()
	language_button.text = "English" if language == "zh" else "简体中文"
	save_button.text = t("保存", "SAVE")
	load_button.text = t("读取", "LOAD")
	menu_button.text = t("主菜单", "MENU")
	speed_button.text = str(int(game_speed)) + "×"
	save_button.disabled = battle_running
	load_button.disabled = battle_running or not FileAccess.file_exists(SAVE_PATH)
	menu_button.disabled = battle_running
	player_hp_label.get_parent().get_node("Caption").text = t("我方主公", "YOUR RULER")
	enemy_hp_label.get_parent().get_node("Caption").text = t("敌方主公", "ENEMY RULER")
	player_hp_label.text = str(player_ruler_hp) + "\n/ " + str(RULER_MAX_HP)
	enemy_hp_label.text = str(enemy_ruler_hp) + "\n/ " + str(RULER_MAX_HP)
	player_ruler_fill.anchor_top = 1.0 - clampf(float(player_ruler_hp) / RULER_MAX_HP, 0.0, 1.0)
	enemy_ruler_fill.anchor_top = 1.0 - clampf(float(enemy_ruler_hp) / RULER_MAX_HP, 0.0, 1.0)
	player_ruler_fill.modulate = Color("#a3ffae") if float(ruler_regen.player.get("time", 0.0)) > 0.0 else Color.WHITE
	enemy_ruler_fill.modulate = Color("#a3ffae") if float(ruler_regen.enemy.get("time", 0.0)) > 0.0 else Color.WHITE
	_update_battle_time_bar()
	enemy_title_label.text = t("敌方阵地  ·  后排在上 / 前排在下", "ENEMY FORMATION  ·  BACK TO FRONT")
	player_title_label.text = t("我方阵地  ·  前排在上 / 后排在下", "YOUR FORMATION  ·  FRONT TO BACK")
	if phase == "draft": draft_title_label.text = t("二选一 · 第%d/3轮" % (PICKS_PER_ROUND - draft_picks_remaining + 1), "PICK 1 OF 2 · ROUND %d/3" % (PICKS_PER_ROUND - draft_picks_remaining + 1))
	elif phase == "placement": draft_title_label.text = t("布置新武将 · 待放 ", "DEPLOY RECRUITS · LEFT ") + str(pending_unit_ids.size())
	elif phase == "combat": draft_title_label.text = t("最终无限战斗", "FINAL UNLIMITED BATTLE") if final_battle else t("本关战斗中 · 30 秒", "STAGE BATTLE · 30 SEC")
	else: draft_title_label.text = t("征战结果", "CAMPAIGN RESULT")
	log_title_label.text = t("实时战报", "BATTLE LOG")
	stats_title_label.text = t("本局实时统计", "LIVE BATTLE STATS") if phase == "combat" else t("上一局英雄统计", "PREVIOUS BATTLE STATS")
	var metric_names := {"damage":t("伤害", "DMG"), "healing":t("治疗", "HEAL"), "control":t("控制", "CC"), "taken":t("承伤", "TAKEN")}
	for metric in stats_tab_buttons:
		stats_tab_buttons[metric].text = metric_names[metric]
		stats_tab_buttons[metric].modulate = Color("#f0c77a") if metric == stats_metric else Color.WHITE
	_render_battle_stats()
	phase_caption_label.text = t("两军对垒  ·  ", "BATTLE LINE  ·  ") + _phase_name()
	bonds_label.text = _bond_text(player_units.filter(func(unit): return unit.alive and unit.row >= 0))
	reserve_title_label.text = t("备战区 ", "RESERVE ") + str(_reserve_units().size()) + " / " + str(RESERVE_LIMIT)
	_hint()
	unit_cell_refs.clear()
	tile_cell_refs.clear()
	action_bar_refs.clear()
	health_bar_refs.clear()
	_render_board(enemy_board, enemy_units, false)
	_render_board(player_board, player_units, true)
	_render_draft()
	_render_rosters()
	_render_reserve()
	draft_toggle_button.text = t("隐藏选将", "HIDE DRAFT") if not draft_user_hidden else t("显示选将", "SHOW DRAFT")
	draft_toggle_button.visible = phase == "draft"
	draft_toggle_button.disabled = phase != "draft" or battle_running
	if is_instance_valid(draft_overlay):
		draft_overlay.visible = phase == "draft" and not draft_user_hidden and (not is_instance_valid(menu_overlay) or not menu_overlay.visible)
	auto_button.text = t("自动布阵", "AUTO PLACE")
	auto_button.visible = false
	battle_button.text = t("开始战斗", "START BATTLE")
	battle_button.visible = phase != "combat"
	auto_button.disabled = phase != "placement" or pending_unit_ids.is_empty() or battle_running
	battle_button.disabled = not _can_start_battle() or battle_running
	battle_pause_button.text = t("继续", "RESUME") if battle_paused else t("暂停", "PAUSE")
	battle_pause_button.visible = phase == "combat" and battle_running

func _toggle_battle_pause() -> void:
	if phase != "combat" or not battle_running: return
	battle_paused = not battle_paused
	if battle_paused:
		tick_timer.stop()
	elif not action_in_progress:
		tick_timer.start()
	_render()

func _hint() -> void:
	if phase == "draft": hint_label.text = t("每轮从两名候选中锁定一名；每个位置本轮只能独立刷新一次，锁定后不能撤销。", "Lock one of two each round. Each slot can be refreshed once that round, and locked picks cannot be undone.")
	elif phase == "placement": hint_label.text = t("前军强制前排且只打前排；中军站前排可随机打全场、站中排随机打前中排、站后排只打前排；后军任意站位随机攻击全场。", "Vanguard is front-only; Midguard in front randomly reaches all rows, in middle reaches front/middle, and in back reaches front only; Rearguard randomly reaches all rows.")
	elif phase == "combat": hint_label.text = t("最终决战没有时间限制，直到一方主公倒下。", "The final battle has no time limit and ends only when a ruler falls.") if final_battle else t("行动期间全场暂停；本关持续 30 秒。", "All gauges pause during actions. This stage lasts 30 seconds.")
	else: hint_label.text = t("对局结束，可重新开局再次挑战。", "Match complete. Start a new game to play again.")

func _render_board(board: GridContainer, units: Array, is_player: bool) -> void:
	_clear_dynamic_children(board)
	var compact_mobile := _is_mobile_ui()
	for index in BOARD_ROWS * BOARD_COLUMNS:
		var display_row: int = index / BOARD_COLUMNS
		var row: int = display_row if is_player else BOARD_ROWS - 1 - display_row
		var col: int = index % BOARD_COLUMNS
		var unit: Variant = _unit_at(units, row, col)
		var cell := Button.new()
		cell.custom_minimum_size = Vector2(106 if compact_mobile else 112, 70 if compact_mobile else 82)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cell.tooltip_text = ""
		var color := Color("#15191c")
		var border := Color("#393733")
		var faction_color := Color("#5a554c")
		var health := 0
		var maximum := 1
		if unit:
			var hero: Dictionary = heroes[unit.hero_id]
			faction_color = FACTION_COLORS[hero.f]
			color = faction_color.darkened(0.76) if unit.alive else Color("#171717")
			border = faction_color.darkened(0.12)
			health = int(max(0.0, unit.hp)) if unit.has("hp") else int(hero.hp)
			maximum = int(unit.max_hp) if unit.has("max_hp") else int(hero.hp)
			cell.tooltip_text = _hero_name(unit.hero_id) + "\n" + (hero.zh_skill if language == "zh" else hero.skill) + "\n" + (hero.summary if language == "zh" else hero.en_summary)
			if is_player and selected_unit == unit.id: border = Color("#f0c77a")
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color("#101417")
		normal.border_color = Color("#393733")
		normal.border_width_left = 1
		normal.border_width_right = 1
		normal.border_width_top = 1
		normal.border_width_bottom = 1
		normal.corner_radius_top_left = 7
		normal.corner_radius_top_right = 7
		normal.corner_radius_bottom_left = 7
		normal.corner_radius_bottom_right = 7
		cell.add_theme_stylebox_override("normal", normal)
		cell.add_theme_stylebox_override("disabled", normal)
		var hover: StyleBoxFlat = normal.duplicate()
		hover.bg_color = Color("#171d21")
		hover.border_color = Color("#f0c77a")
		cell.add_theme_stylebox_override("hover", hover)
		cell.add_theme_color_override("font_disabled_color", Color("#e7ddca"))
		var team_key := "player" if is_player else "enemy"
		tile_cell_refs[team_key + ":" + str(row) + ":" + str(col)] = cell
		if unit:
			var hero: Dictionary = heroes[unit.hero_id]
			var card_layer := Panel.new()
			card_layer.name = "AnimatedUnitCard"
			card_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			card_layer.offset_left = 3
			card_layer.offset_top = 3
			card_layer.offset_right = -3
			card_layer.offset_bottom = -3
			card_layer.clip_contents = false
			_style(card_layer, color, 7, border, 2 if is_player and selected_unit == unit.id else 1)
			cell.add_child(card_layer)
			unit_cell_refs[unit.id] = card_layer
			var portrait := _portrait_rect(unit.hero_id)
			portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			card_layer.add_child(portrait)
			var shade := ColorRect.new()
			shade.color = Color(0.02, 0.02, 0.02, 0.38)
			shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
			shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			card_layer.add_child(shade)
			if float(unit.get("burn", 0.0)) > 0.0:
				card_layer.add_child(_burning_state_overlay(0.46))
			var badge := _cell_text(_faction_name(hero.f), 11, faction_color.lightened(0.25))
			badge.position = Vector2(8, 6)
			badge.size = Vector2(45, 17)
			badge.add_theme_constant_override("outline_size", 4)
			badge.add_theme_color_override("font_outline_color", Color.BLACK)
			card_layer.add_child(badge)
			var state := _cell_text(_status_text(unit), 10, Color("#f0c77a"))
			state.set_anchors_preset(Control.PRESET_TOP_WIDE)
			state.offset_left = 54
			state.offset_right = -8
			state.offset_top = 6
			state.offset_bottom = 23
			state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			state.add_theme_constant_override("outline_size", 4)
			state.add_theme_color_override("font_outline_color", Color.BLACK)
			card_layer.add_child(state)
			var name_label := _outlined_label(_hero_name(unit.hero_id) + "  " + "★".repeat(int(unit.get("level", 1))), 22, faction_color.lightened(0.34))
			name_label.anchor_left = 0.0
			name_label.anchor_right = 1.0
			name_label.anchor_top = 0.5
			name_label.anchor_bottom = 0.5
			name_label.offset_top = -16
			name_label.offset_bottom = 16
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			card_layer.add_child(name_label)
			var meta := _outlined_label("HP " + str(health) + "  ·  R" + str(hero.range), 10, Color("#eee5d5"))
			meta.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			meta.offset_left = 8
			meta.offset_right = -8
			meta.offset_top = -42
			meta.offset_bottom = -27
			meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card_layer.add_child(meta)
			var hp_bar := ProgressBar.new()
			hp_bar.show_percentage = false
			hp_bar.max_value = maximum
			hp_bar.value = health
			hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hp_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			hp_bar.offset_left = 8
			hp_bar.offset_right = -8
			hp_bar.offset_top = -13
			hp_bar.offset_bottom = -6
			var bar_bg := StyleBoxFlat.new()
			bar_bg.bg_color = Color("#090b0c")
			bar_bg.corner_radius_top_left = 3
			bar_bg.corner_radius_top_right = 3
			bar_bg.corner_radius_bottom_left = 3
			bar_bg.corner_radius_bottom_right = 3
			var bar_fill := StyleBoxFlat.new()
			bar_fill.bg_color = Color("#45ef73") if float(unit.get("regen_time", 0.0)) > 0.0 else (Color("#6dae78") if health > maximum * 0.35 else Color("#bd5e4b"))
			bar_fill.corner_radius_top_left = 3
			bar_fill.corner_radius_top_right = 3
			bar_fill.corner_radius_bottom_left = 3
			bar_fill.corner_radius_bottom_right = 3
			hp_bar.add_theme_stylebox_override("background", bar_bg)
			hp_bar.add_theme_stylebox_override("fill", bar_fill)
			card_layer.add_child(hp_bar)
			health_bar_refs[unit.id] = hp_bar
			var skill_bar := ProgressBar.new()
			skill_bar.show_percentage = false
			skill_bar.max_value = ACTION_MAX
			skill_bar.value = float(unit.get("action", 0.0))
			skill_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			skill_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			skill_bar.offset_left = 8
			skill_bar.offset_right = -8
			skill_bar.offset_top = -24
			skill_bar.offset_bottom = -15
			var action_bg := StyleBoxFlat.new()
			action_bg.bg_color = Color("#10141b")
			action_bg.corner_radius_top_left = 3
			action_bg.corner_radius_top_right = 3
			action_bg.corner_radius_bottom_left = 3
			action_bg.corner_radius_bottom_right = 3
			var action_fill := StyleBoxFlat.new()
			action_fill.bg_color = Color("#efb84f")
			action_fill.corner_radius_top_left = 3
			action_fill.corner_radius_top_right = 3
			action_fill.corner_radius_bottom_left = 3
			action_fill.corner_radius_bottom_right = 3
			skill_bar.add_theme_stylebox_override("background", action_bg)
			skill_bar.add_theme_stylebox_override("fill", action_fill)
			card_layer.add_child(skill_bar)
			action_bar_refs[unit.id] = skill_bar
		else:
			var empty := _cell_text("＋\n" + t("空位", "EMPTY"), 13, Color("#55534e"))
			empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cell.add_child(empty)
			var empty_team := "player" if is_player else "enemy"
			var ground_burning := ground_effects.any(func(effect):
				return str(effect.get("team", "")) == empty_team and int(effect.get("row", -1)) == row and int(effect.get("col", -1)) == col and float(effect.get("time", 0.0)) > 0.0
			)
			if ground_burning:
				cell.add_child(_burning_state_overlay(0.38))
		if is_player and phase == "placement" and not battle_running:
			cell.pressed.connect(_on_player_cell.bind(row, col))
			if unit != null: cell.set_drag_forwarding(_drag_unit.bind(unit.id, cell), _can_drop_board.bind(row, col), _drop_board.bind(row, col))
			else: cell.set_drag_forwarding(_drag_empty, _can_drop_board.bind(row, col), _drop_board.bind(row, col))
		else:
			cell.disabled = true
		board.add_child(cell)

func _burning_state_overlay(alpha: float) -> TextureRect:
	var overlay := TextureRect.new()
	overlay.name = "BurningStateOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 18
	overlay.texture = load("res://ThreeKingdom/animations/onfire.png")
	overlay.material = _fire_effect_material()
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.modulate = Color(1.0, 0.86, 0.62, alpha)
	return overlay

func _cell_text(value: String, size: int, color: Color) -> Label:
	var label := _label(value, size, color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	return label

func _outlined_label(value: String, size: int, color: Color) -> Label:
	var label := _cell_text(value, size, color)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	return label

func _render_draft() -> void:
	_clear_dynamic_children(draft_box)
	draft_box.alignment = BoxContainer.ALIGNMENT_CENTER
	for choice_index in choices.size():
		var id: String = str(choices[choice_index])
		var hero: Dictionary = heroes[id]
		var option := VBoxContainer.new()
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.size_flags_vertical = Control.SIZE_EXPAND_FILL
		option.custom_minimum_size = Vector2(500, 560)
		option.add_theme_constant_override("separation", 10)
		var card := Button.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(500, 505)
		var roles := _roles_text(hero.roles)
		card.text = ""
		card.tooltip_text = t("点击后立即锁定，不能撤销", "Click to lock this pick; it cannot be undone") + "\n" + _skill_detail(id)
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var style := StyleBoxFlat.new()
		style.bg_color = FACTION_COLORS[hero.f].darkened(0.78)
		style.border_color = FACTION_COLORS[hero.f].darkened(0.14)
		style.border_width_left = 4
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.corner_radius_top_left = 9
		style.corner_radius_top_right = 9
		style.corner_radius_bottom_left = 9
		style.corner_radius_bottom_right = 9
		style.content_margin_left = 0
		style.content_margin_right = 0
		card.add_theme_stylebox_override("normal", style)
		card.add_theme_stylebox_override("disabled", style)
		var hover: StyleBoxFlat = style.duplicate()
		hover.bg_color = FACTION_COLORS[hero.f].darkened(0.68)
		hover.border_color = Color("#f0c77a")
		card.add_theme_stylebox_override("hover", hover)
		var portrait := _portrait_rect(id)
		portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card.add_child(portrait)
		var shade := ColorRect.new()
		shade.color = Color(0.02, 0.02, 0.02, 0.40)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card.add_child(shade)
		var faction := _outlined_label("【" + _faction_name(hero.f) + "】  " + roles, 11, Color("#eee5d5"))
		faction.set_anchors_preset(Control.PRESET_TOP_WIDE)
		faction.offset_left = 10
		faction.offset_right = -10
		faction.offset_top = 8
		faction.offset_bottom = 26
		card.add_child(faction)
		var name_label := _outlined_label(_hero_name(id), 27, FACTION_COLORS[hero.f].lightened(0.32))
		name_label.anchor_left = 0.0
		name_label.anchor_right = 1.0
		name_label.anchor_top = 0.5
		name_label.anchor_bottom = 0.5
		name_label.offset_top = -24
		name_label.offset_bottom = 14
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card.add_child(name_label)
		var skill := _outlined_label("◆ " + (hero.zh_skill if language == "zh" else hero.skill), 12, Color("#f4d991"))
		skill.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		skill.offset_left = 10
		skill.offset_right = -10
		skill.offset_top = -45
		skill.offset_bottom = -26
		skill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(skill)
		var detail := _outlined_label(_skill_detail(id), 11, Color("#f2eee6"))
		detail.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		detail.offset_left = 12
		detail.offset_right = -12
		detail.offset_top = -172
		detail.offset_bottom = -52
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		card.add_child(detail)
		var stats := _outlined_label("HP " + str(hero.hp) + "  ·  " + _hero_army_name(id) + "  ·  " + str(hero.cooldown) + t("秒读条", "s cast"), 10, Color("#f2eee6"))
		stats.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		stats.offset_left = 10
		stats.offset_right = -10
		stats.offset_top = -24
		stats.offset_bottom = -6
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(stats)
		card.disabled = battle_running or phase != "draft" or not _can_accept_hero(id)
		card.pressed.connect(_choose_hero.bind(id))
		option.add_child(card)
		var can_refresh := choice_index < draft_refresh_available.size() and draft_refresh_available[choice_index]
		var reroll := _button(t("↻ 仅刷新此选项（本轮1次）", "↻ REFRESH THIS OPTION (ONCE)")) if can_refresh else _button(t("✓ 本轮已刷新", "✓ REFRESH USED"))
		reroll.custom_minimum_size = Vector2(0, 44)
		reroll.disabled = battle_running or phase != "draft" or not can_refresh
		reroll.pressed.connect(_refresh_draft_choice.bind(choice_index))
		option.add_child(reroll)
		draft_box.add_child(option)

func _clear_dynamic_children(container: Container) -> void:
	for child in container.get_children():
		child.hide()
		child.queue_free()

func _render_rosters() -> void:
	if _is_mobile_ui():
		roster_label.text = ""
		enemy_roster_label.text = ""
		return
	roster_label.text = _roster_text(player_units)
	enemy_roster_label.text = _roster_text(enemy_units)

func _render_battle_stats() -> void:
	if not is_instance_valid(stats_chart): return
	_clear_dynamic_children(stats_chart)
	var source_rows: Array = []
	if phase == "combat":
		for entry in battle_stats.values(): source_rows.append(entry.duplicate(true))
	else:
		source_rows = last_battle_stats.duplicate(true)
	if source_rows.is_empty():
		var empty := _label(t("完成第一场战斗后显示图表。", "Complete the first battle to show charts."), 12, Color("#887e70"))
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats_chart.add_child(empty)
		return
	source_rows.sort_custom(func(a, b): return float(a.get(stats_metric, 0.0)) > float(b.get(stats_metric, 0.0)))
	var chart_max := 1.0
	for row in source_rows: chart_max = max(chart_max, float(row.get(stats_metric, 0.0)))
	for row in source_rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		var side := t("我", "P") if row.team == "player" else t("敌", "E")
		var hero_label := _label(side + " · " + _hero_name(row.hero_id) + " " + "★".repeat(int(row.level)), 11, Color("#90c59e") if row.team == "player" else Color("#d89a8f"))
		hero_label.custom_minimum_size.x = 112
		hero_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.add_child(hero_label)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.max_value = chart_max
		bar.value = float(row.get(stats_metric, 0.0))
		bar.custom_minimum_size.y = 18
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color("#090b0f")
		bg.corner_radius_top_left = 4
		bg.corner_radius_top_right = 4
		bg.corner_radius_bottom_left = 4
		bg.corner_radius_bottom_right = 4
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("#5ca873") if row.team == "player" else Color("#c16458")
		fill.corner_radius_top_left = 4
		fill.corner_radius_top_right = 4
		fill.corner_radius_bottom_left = 4
		fill.corner_radius_bottom_right = 4
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fill)
		line.add_child(bar)
		var raw_value: float = float(row.get(stats_metric, 0.0))
		var value_text := "%.1fs" % raw_value if stats_metric == "control" else str(round(raw_value))
		var value_label := _label(value_text, 11, Color("#e8e2cf"))
		value_label.custom_minimum_size.x = 48
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(value_label)
		stats_chart.add_child(line)

func _render_reserve() -> void:
	_clear_dynamic_children(reserve_box)
	var reserves := _reserve_units()
	for index in RESERVE_LIMIT:
		var slot := Button.new()
		var compact_mobile := _is_mobile_ui()
		slot.custom_minimum_size = Vector2(116 if compact_mobile else 106, 100 if compact_mobile else 72)
		slot.add_theme_font_size_override("font_size", 11)
		if index < reserves.size():
			var unit: Dictionary = reserves[index]
			slot.text = _hero_name(unit.hero_id) + "\n" + "★".repeat(int(unit.level)) + "  HP " + str(round(unit.hp))
			slot.tooltip_text = t("拖拽到战场上阵；拖到其他武将可交换；右键可出售", "Drag to deploy or swap; right-click to sell")
			slot.modulate = Color("#f0c77a") if selected_unit == unit.id else Color.WHITE
			slot.pressed.connect(_on_reserve_pressed.bind(unit.id))
			slot.gui_input.connect(_on_reserve_input.bind(unit.id))
			slot.set_drag_forwarding(_drag_unit.bind(unit.id, slot), _can_drop_reserve.bind(index), _drop_reserve.bind(index))
		else:
			slot.text = "+"
			slot.set_drag_forwarding(_drag_empty, _can_drop_reserve.bind(index), _drop_reserve.bind(index))
		reserve_box.add_child(slot)

func _on_reserve_pressed(unit_id: String) -> void:
	if phase != "placement" or battle_running: return
	selected_unit = unit_id
	_render()

func _drag_empty(_at_position: Vector2):
	return null

func _drag_unit(_at_position: Vector2, unit_id: String, origin: Control):
	if phase != "placement" or battle_running: return null
	var unit = _find_by_id(player_units, unit_id)
	if unit == null or not unit.alive: return null
	var preview := _outlined_label(_hero_name(unit.hero_id) + " " + "★".repeat(int(unit.level)), 16, FACTION_COLORS[heroes[unit.hero_id].f].lightened(0.3))
	preview.custom_minimum_size = Vector2(150, 48)
	preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if origin.get_viewport().gui_is_dragging(): origin.set_drag_preview(preview)
	else: preview.queue_free()
	return {"unit_id":unit_id}

func _can_drop_board(_at_position: Vector2, data, _row: int, _col: int) -> bool:
	if phase != "placement" or not (data is Dictionary) or not data.has("unit_id"): return false
	var source = _find_by_id(player_units, str(data.unit_id))
	if source == null or not _can_unit_use_row(source, _row): return false
	var occupant = _unit_at(player_units, _row, _col)
	return occupant == null or source.row < 0 or _can_unit_use_row(occupant, int(source.row))

func _drop_board(_at_position: Vector2, data, row: int, col: int) -> void:
	if not _can_drop_board(_at_position, data, row, col): return
	var source: Dictionary = _find_by_id(player_units, str(data.unit_id))
	var occupant = _unit_at(player_units, row, col)
	var old_row: int = int(source.row)
	var old_col: int = int(source.col)
	if occupant != null and occupant.id != source.id:
		occupant.row = old_row  # 目标格的原武将换到源位置
		occupant.col = old_col
	source.row = row
	source.col = col
	selected_unit = ""
	_log(_hero_name(source.hero_id) + t(" 已拖拽到指定战位。", " was dragged to the selected tile."))
	_render()

func _can_drop_reserve(_at_position: Vector2, data, _index: int) -> bool:
	return phase == "placement" and data is Dictionary and data.has("unit_id") and _find_by_id(player_units, str(data.unit_id)) != null

func _drop_reserve(_at_position: Vector2, data, index: int) -> void:
	if not _can_drop_reserve(_at_position, data, index): return
	var source: Dictionary = _find_by_id(player_units, str(data.unit_id))
	var reserves := _reserve_units()
	var target = reserves[index] if index < reserves.size() else null
	if source.row >= 0:
		var old_row: int = int(source.row)
		var old_col: int = int(source.col)
		if target != null and target.id != source.id:
			target.row = old_row
			target.col = old_col
		source.row = -1
		source.col = -1
	elif target != null and target.id != source.id:
		var source_index := player_units.find(source)
		var target_index := player_units.find(target)
		player_units[source_index] = target
		player_units[target_index] = source
	selected_unit = ""
	_render()

func _on_reserve_input(event: InputEvent, unit_id: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_sell_reserve_unit(unit_id)

func _sell_reserve_unit(unit_id: String) -> void:
	if battle_running or phase not in ["draft", "placement"]: return
	var unit = _find_by_id(player_units, unit_id)
	if unit == null or unit.row >= 0: return
	player_units.erase(unit)
	pending_unit_ids.erase(unit_id)
	_log(_hero_name(unit.hero_id) + t(" 已出售。", " was sold."))
	_render()

func _bond_progress_tiers(bond_id: String, member_count: int) -> Array[int]:
	match bond_id:
		"five_elites":
			return [5]
		"hebei_pillars":
			return [3, 4]
	return [member_count]

func _bond_progress_target(count: int, tiers: Array[int]) -> int:
	for tier in tiers:
		if count < tier:
			return tier
	return tiers[-1]

func _bond_progress_current_tier(count: int, tiers: Array[int]) -> int:
	var current := 0
	for tier in tiers:
		if count >= tier:
			current = tier
	return current

func _bond_progress_entries(units: Array) -> Array:
	var alive_hero_ids := {}
	var faction_counts := {"shu":0, "wei":0, "wu":0, "qun":0}
	for unit in units:
		if not bool(unit.get("alive", false)) or int(unit.get("row", -1)) < 0:
			continue
		var hero_id := str(unit.get("hero_id", ""))
		if not heroes.has(hero_id):
			continue
		alive_hero_ids[hero_id] = true
		var faction := str(heroes[hero_id].f)
		faction_counts[faction] = int(faction_counts.get(faction, 0)) + 1
	var entries: Array = []
	for faction in ["shu", "wei", "wu", "qun"]:
		var faction_count := int(faction_counts[faction])
		if faction_count <= 0:
			continue
		var graph_data := _bond_graph_data(faction)
		var faction_data: Array = graph_data.faction
		var faction_tiers: Array[int] = FACTION_BOND_TIERS
		var faction_target := _bond_progress_target(faction_count, faction_tiers)
		var faction_current := _bond_progress_current_tier(faction_count, faction_tiers)
		entries.append({
			"id":str(faction_data[0]),
			"name":t(str(faction_data[1]), str(faction_data[2])),
			"count":faction_count,
			"target":faction_target,
			"current_tier":faction_current,
			"active":faction_current > 0,
			"ratio":minf(1.0, float(faction_count) / maxf(1.0, float(faction_target))),
			"is_faction":true,
		})
		for bond in graph_data.bonds:
			var members: Array = bond[3]
			var member_count := 0
			for member_id in members:
				if alive_hero_ids.has(str(member_id)):
					member_count += 1
			if member_count <= 0:
				continue
			var tiers := _bond_progress_tiers(str(bond[0]), members.size())
			var target := _bond_progress_target(member_count, tiers)
			var current := _bond_progress_current_tier(member_count, tiers)
			entries.append({
				"id":str(bond[0]),
				"name":t(str(bond[1]), str(bond[2])),
				"count":member_count,
				"target":target,
				"current_tier":current,
				"active":current > 0,
				"ratio":minf(1.0, float(member_count) / maxf(1.0, float(target))),
				"is_faction":false,
			})
	entries.sort_custom(func(a, b):
		if bool(a.active) != bool(b.active):
			return bool(a.active)
		if not is_equal_approx(float(a.ratio), float(b.ratio)):
			return float(a.ratio) > float(b.ratio)
		return str(a.name) < str(b.name)
	)
	return entries

func _bond_progress_line(entry: Dictionary) -> String:
	var progress := str(entry.count) + "/" + str(entry.target)
	if bool(entry.active) and int(entry.current_tier) < int(entry.target):
		progress += t("（已激活" + str(entry.current_tier) + "）", " (active " + str(entry.current_tier) + ")")
	if bool(entry.active):
		return "[color=#f3d27a][b]◆ " + str(entry.name) + "[/b]  " + progress + "[/color]"
	return "[color=#74787d]◇ " + str(entry.name) + "  " + progress + "[/color]"

func _bond_text(units: Array) -> String:
	var entries := _bond_progress_entries(units)
	if entries.is_empty():
		return t("[color=#686c70]暂无上阵武将[/color]", "[color=#686c70]No deployed heroes[/color]")
	var active_lines: Array[String] = []
	var pending_lines: Array[String] = []
	for entry in entries:
		if bool(entry.active):
			active_lines.append(_bond_progress_line(entry))
		else:
			pending_lines.append(_bond_progress_line(entry))
	var sections: Array[String] = []
	if active_lines.is_empty():
		sections.append(t("[color=#8e704d][b]已激活[/b]　无[/color]", "[color=#8e704d][b]ACTIVE[/b]  None[/color]"))
	else:
		sections.append(t("[color=#d4a85d][b]已激活[/b][/color]", "[color=#d4a85d][b]ACTIVE[/b][/color]") + "\n" + "\n".join(active_lines))
	if not pending_lines.is_empty():
		sections.append(t("[color=#666a70][b]待激活[/b][/color]", "[color=#666a70][b]PENDING[/b][/color]") + "\n" + "\n".join(pending_lines))
	return "\n\n".join(sections)

func _refresh_bond_progress(units: Array) -> void:
	if is_instance_valid(bonds_label):
		bonds_label.text = _bond_text(units)

func _combo_bond_text(units: Array) -> String:
	var active: Array[String] = []
	if _roster_has_all(units, ["liubei", "guanyu", "zhangfei"]): active.append(t("◆ 桃园结义：追加治疗 · 满额列斩 · 同排护盾", "◆ Peach Garden: extra heal · full cleave · row shield"))
	if _roster_has_all(units, ["caocao", "dianwei"]): active.append(t("◆ 古之恶来：曹操强化后军震慑 · 典韦目标+1", "◆ Evil of Old: Cao Cao anti-rearguard boost · Dian Wei +1 target"))
	if _roster_has_all(units, ["caocao", "xuchu"]): active.append(t("◆ 虎卫护主：曹操强化前军震慑 · 许褚目标+1", "◆ Tiger Guard: Cao Cao anti-vanguard boost · Xu Chu +1 target"))
	if _roster_has_all(units, ["dianwei", "xuchu"]): active.append(t("◆ 魏武双卫：典韦与许褚技能伤害提高至400%", "◆ Twin Wei Guards: Dian Wei and Xu Chu rise to 400%"))
	if _roster_has_all(units, ["zhouyu", "luxun", "lusu", "lvmeng"]): active.append(t("◆ 四英杰：周瑜4格点火 · 陆逊3次弹射 · 鲁肃双人强化治疗 · 吕蒙恐惧", "◆ Four Heroes: Zhou Yu 4 tiles · Lu Xun 3 bounces · Lu Su treats two · Lu Meng fear"))
	if _roster_has_all(units, ["lvbu", "diaochan", "dongzhuo"]): active.append(t("◆ 鬼神权倾：鬼神免死 · 魅惑增伤 · 暴君重击", "◆ Tyrant's Court: death ward · charm burst · tyrant strike"))
	if _roster_has_all(units, ["guanyu", "zhangfei", "zhaoyun", "huangzhong", "machao"]): active.append(t("◆ 五虎上将：前军与中军行动条速度+15% · 五虎绝技强化", "◆ Five Tigers: vanguard/midguard gauge speed +15% · signature skills empowered"))
	if _roster_has_all(units, ["machao", "madai"]): active.append(t("◆ 一骑当千：马超全列200%贯穿 · 马岱开场满行动条", "◆ One Rider: Ma Chao 200% all-row pierce · Ma Dai opens ready"))
	if _roster_has_all(units, ["weiyan", "madai"]): active.append(t("◆ 宿命之敌：马岱易伤标记 · 魏延邻位治疗", "◆ Fated Enemies: Ma Dai vulnerability · Wei Yan ally healing"))
	if _roster_has_all(units, ["weiyan", "huangzhong"]): active.append(t("◆ 飞火流星：黄忠50%概率双倍暴击 · 敌方前军阵亡时魏延恢复50%最大生命", "◆ Flying Meteor: Huang Zhong has 50% double-damage crit · enemy frontliner deaths heal Wei Yan"))
	if _roster_has_all(units, ["zhugeliang", "pangtong"]): active.append(t("◆ 卧龙凤雏：八阵扩展左右格 · 连环计升级为三格强控", "◆ Dragon and Phoenix: Eight-Formation expands horizontally · Chain Scheme becomes three-tile control"))
	if _roster_has_all(units, ["zhugeliang", "jiangwei"]): active.append(t("◆ 北伐传承：八阵扩展四斜角 · 北伐追加斜击与30%减伤", "◆ Northern Expedition Legacy: Eight-Formation adds diagonals · Northern Expedition gains diagonal strikes and 30% reduction"))
	if _roster_has_all(units, ["zhugeliang", "menghuo"]): active.append(t("◆ 七擒孟获：八阵强化并施加火攻 · 蛮王震地追加整排余震", "◆ Seven Captures: Eight-Formation gains Fire Assault · Barbarian Quake gains a row aftershock"))
	if _roster_has_all(units, ["zhugeliang", "liubei"]): active.append(t("◆ 卧龙辅汉：八阵按额外命中人数提高全体伤害", "◆ Wolong Aids Han: Eight-Formation scales with additional enemies hit"))
	if _roster_has_all(units, ["menghuo", "zhurong"]): active.append(t("◆ 南蛮夫妇：孟获强化灼烧震地 · 祝融飞刃左右弹射", "◆ Nanman Couple: burning quake · Flame Blade bounces"))
	if _roster_has_all(units, ["menghuo", "dailaidongzhu"]): active.append(t("◆ 蛮王援军：孟获整排压行动条 · 带来洞主追加同列攻击", "◆ Barbarian Reinforcements: row gauge pushback · Dailai vertical splash"))
	if _roster_has_all(units, ["dailaidongzhu", "zhurong"]): active.append(t("◆ 姐弟同心：带来洞主附加灼烧 · 祝融强化灼烧", "◆ Sibling Bond: Dailai ignites · Zhurong burn empowered"))
	if _roster_has_all(units, ["zhangliao", "yuejin"]): active.append(t("◆ 逍遥津先锋：张辽双段200% · 乐进5人150%", "◆ Hefei Vanguard: Zhang Liao 200% passes · Yue Jin 5 targets at 150%"))
	if _roster_has_all(units, ["zhanghe", "xuhuang"]): active.append(t("◆ 巧变开山：张郃相邻连枪 · 徐晃整排200%", "◆ Adaptive Vanguard: Zhang He chain · Xu Huang 200% row"))
	if _roster_has_all(units, ["zhangliao", "yuejin", "zhanghe", "xuhuang", "yujin"]): active.append(t("◆ 五子良将：易损 · 重伤 · 连锁扩散 · 随机整排强控 · 三人护盾", "◆ Five Elite Generals: vulnerability · grievous · chain · row control · triple shields"))
	if _roster_has_all(units, ["xiahouyuan", "caoren"]): active.append(t("◆ 神速镇远：夏侯渊减冷却增眩晕 · 曹仁强化后军镇守", "◆ Swift Bulwark: Xiahou Yuan cooldown/stun · Cao Ren rear guard"))
	if _roster_has_all(units, ["xiahouyuan", "xiahoudun"]): active.append(t("◆ 夏侯同心：夏侯渊减冷却增眩晕 · 夏侯惇强化前军镇守", "◆ Xiahou Brothers: Xiahou Yuan cooldown/stun · Xiahou Dun front guard"))
	if _roster_has_all(units, ["caoren", "xiahoudun"]): active.append(t("◆ 魏武双壁：曹仁、夏侯惇目标与定向减伤强化", "◆ Twin Bulwarks: Cao Ren and Xiahou Dun targeting/reduction"))
	if _roster_has_all(units, ["simayi", "guojia"]): active.append(t("◆ 雷霆冰策：司马懿雷击强化 · 郭嘉冻结加速", "◆ Thunder and Frost: stronger lightning · faster freezing"))
	if _roster_has_all(units, ["simayi", "xunyu"]): active.append(t("◆ 鹰视王佐：司马懿雷击强化 · 荀彧加速强化", "◆ Eagle Eye and Royal Aid"))
	if _roster_has_all(units, ["simayi", "jiaxu"]): active.append(t("◆ 鹰视毒谋：司马懿雷击强化 · 贾诩中毒强化", "◆ Eagle Eye and Venom"))
	if _roster_has_all(units, ["guojia", "xunyu"]): active.append(t("◆ 遗计王佐：冻结与行动加速目标增加", "◆ Frozen Royal Plan"))
	if _roster_has_all(units, ["guojia", "jiaxu"]): active.append(t("◆ 冰毒奇策：冻结与中毒目标增加", "◆ Frost and Venom"))
	if _roster_has_all(units, ["xunyu", "jiaxu"]): active.append(t("◆ 王佐毒策：行动加速与中毒目标增加", "◆ Royal Venom"))
	if _roster_has_all(units, ["sunjian", "sunce", "sunquan", "sunshangxiang"]): active.append(t("◆ 孙氏之志：孙坚绝命传承 · 孙策400%连击减伤 · 孙权4倍生命成长 · 孙尚香双射成长", "◆ Sun Legacy: Sun Jian sacrifice · Sun Ce 400% assault · Sun Quan 4x HP growth · Sun Shangxiang twin-shot growth"))
	if _roster_has_all(units, ["daqiao", "xiaoqiao"]): active.append(t("◆ 江东双姝：大乔强化治疗 · 小乔减速提高至60%", "◆ Jiangdong Sisters: Da Qiao healing · Xiao Qiao 60% slow"))
	if _roster_has_all(units, ["lvmeng", "ganning"]): active.append(t("◆ 白衣奇袭：吕蒙隐身增伤 · 甘宁对半血以下目标增伤50%", "◆ White-Robed Ambush: Lu Meng post-stealth damage · Gan Ning +50% below half HP"))
	if _roster_has_all(units, ["sunce", "taishici"]): active.append(t("◆ 神亭酣战：孙策左右双段连击 · 太史慈目标数提高至3人", "◆ Shenting Duel: Sun Ce two-wave sweep · Taishi Ci targets 3"))
	if _roster_has_all(units, ["sunce", "daqiao"]): active.append(t("◆ 江东佳偶：孙策出手自疗 · 大乔按目标已损生命提高治疗", "◆ Jiangdong Couple: Sun Ce self-heal · Da Qiao scales healing with missing HP"))
	if _roster_has_all(units, ["zhouyu", "xiaoqiao"]): active.append(t("◆ 琴瑟和鸣：周瑜灼烧延长至6秒 · 小乔减速3名后军8秒", "◆ Harmonious Zither: Zhou Yu burn to 6s · Xiao Qiao slows 3 rearguards for 8s"))
	if _roster_has_all(units, ["zhouyu", "huanggai"]): active.append(t("◆ 赤壁苦计：周瑜按已损生命强化点火 · 黄盖整列灼烧6秒", "◆ Red Cliffs Ruse: Zhou Yu missing-HP scaling · Huang Gai 6s column burn"))
	if _roster_has_all(units, ["huanggai", "sunjian"]): active.append(t("◆ 江东柱石：黄盖15%消耗/45%伤害 · 孙坚开场满行动条/150%消耗伤害", "◆ Pillars: Huang Gai 15% cost/45% damage · Sun Jian ready/150% spent-HP damage"))
	if _roster_has_all(units, ["taishici", "ganning"]): active.append(t("◆ 江表双锋：太史慈对灼烧目标300% · 甘宁协击250%", "◆ Twin Blades: Taishi Ci 300% vs burning · Gan Ning assist 250%"))
	if _roster_has_all(units, ["luxun", "sunquan"]): active.append(t("◆ 君臣同心：陆逊火球增伤 · 孙权12%当前生命伤害与8秒冷却", "◆ Sovereign and Minister: Lu Xun fireball damage · Sun Quan 12% current HP and 8s cooldown"))
	if _roster_has_all(units, ["dingfeng", "xusheng"]): active.append(t("◆ 江表虎臣：丁奉横向追击 · 徐盛延长控制", "◆ Tiger Ministers: Ding Feng splash · Xu Sheng control"))
	if _roster_has_count(units, ["yanliang", "wenchou", "qunzhanghe", "gaolan"], 3): active.append(t("◆ 河北四庭柱：开场紫幕挡技能 · 文丑反弹", "◆ Hebei Pillars: opening wards and reflection"))
	if _roster_has_all(units, ["yuji", "zhangjiao"]): active.append(t("◆ 天道：亡魂雷爆", "◆ Way of Heaven"))
	if active.is_empty(): return t("尚未激活\n集齐指定的三名武将可获得足以改变战局的羁绊", "None active\nCollect a specific trio for a battle-changing bond")
	return "\n".join(active)

func _roster_text(units: Array) -> String:
	if units.is_empty(): return t("暂无武将", "No generals yet")
	var entries: Array[String] = []
	for unit in units:
		entries.append(("† " if not unit.alive else "") + _hero_name(unit.hero_id) + " " + "★".repeat(int(unit.get("level", 1))) + " · " + _faction_name(heroes[unit.hero_id].f))
	return "  |  ".join(entries)

func _render_combat_boards() -> void:
	var p_preview: Array = []
	var e_preview: Array = []
	for unit in combat_units:
		(p_preview if unit.team == "player" else e_preview).append(unit)
	unit_cell_refs.clear()
	tile_cell_refs.clear()
	action_bar_refs.clear()
	health_bar_refs.clear()
	_render_board(player_board, p_preview, true)
	_render_board(enemy_board, e_preview, false)
	bonds_label.text = _bond_text(combat_units.filter(func(unit): return unit.team == "player" and unit.alive and unit.row >= 0))
	_render_battle_stats()
	player_hp_label.text = str(player_ruler_hp) + "\n/ " + str(RULER_MAX_HP)
	enemy_hp_label.text = str(enemy_ruler_hp) + "\n/ " + str(RULER_MAX_HP)
	player_ruler_fill.anchor_top = 1.0 - clampf(float(player_ruler_hp) / RULER_MAX_HP, 0.0, 1.0)
	enemy_ruler_fill.anchor_top = 1.0 - clampf(float(enemy_ruler_hp) / RULER_MAX_HP, 0.0, 1.0)
	player_ruler_fill.modulate = Color("#a3ffae") if float(ruler_regen.player.get("time", 0.0)) > 0.0 else Color.WHITE
	enemy_ruler_fill.modulate = Color("#a3ffae") if float(ruler_regen.enemy.get("time", 0.0)) > 0.0 else Color.WHITE
	_update_battle_time_bar()

func _update_action_bars() -> void:
	for unit in combat_units:
		var bar = action_bar_refs.get(unit.id, null)
		if not is_instance_valid(bar): continue
		bar.value = float(unit.get("action", 0.0))

func _update_battle_time_bar() -> void:
	if not is_instance_valid(battle_time_bar): return
	if final_battle:
		battle_time_bar.visible = false
		battle_time_label.text = t("∞ 最终决战", "∞ FINAL")
		return
	battle_time_bar.visible = true
	battle_time_bar.max_value = BATTLE_LIMIT
	battle_time_bar.value = battle_time
	var remaining: int = maxi(0, int(BATTLE_LIMIT - battle_time))
	battle_time_label.text = t("剩余 ", "TIME ") + str(remaining) + "s"
	if remaining <= 10:
		battle_time_label.add_theme_color_override("font_color", Color("#e85a4f"))
	else:
		battle_time_label.add_theme_color_override("font_color", Color("#f0c77a"))

func _status_text(unit: Dictionary) -> String:
	var statuses: Array[String] = []
	if unit.has("shield") and unit.shield > 0: statuses.append(t("护盾", "Shield"))
	if unit.has("burn") and unit.burn > 0: statuses.append(t("灼烧", "Burn"))
	if float(unit.get("fear", 0.0)) > 0.0: statuses.append(t("恐惧", "Fear"))
	if float(unit.get("freeze", 0.0)) > 0.0: statuses.append(t("冻结", "Frozen"))
	if float(unit.get("poison", 0.0)) > 0.0: statuses.append(t("中毒", "Poison"))
	if float(unit.get("stealth", 0.0)) > 0: statuses.append(t("潜行", "Stealth"))
	if float(unit.get("silence", 0.0)) > 0: statuses.append(t("沉默", "Silence"))
	if float(unit.get("strategy_mark", 0.0)) > 0: statuses.append(t("谋略", "Strategy"))
	if bool(unit.get("zhuge_fire_mark", false)): statuses.append(t("火攻标记", "Fire Assault"))
	if int(unit.get("spell_ward", 0)) > 0: statuses.append(t("紫幕", "Ward"))
	if float(unit.get("regen_time", 0.0)) > 0: statuses.append(t("仁德回春", "Benevolence"))
	if float(unit.get("timed_action_time", 0.0)) > 0: statuses.append(t("行动加速", "Gauge Haste"))
	if float(unit.get("rear_damage_reduction_time", 0.0)) > 0: statuses.append(t("后军减伤", "Rear Guard"))
	if float(unit.get("front_damage_reduction_time", 0.0)) > 0: statuses.append(t("前军减伤", "Front Guard"))
	if unit.has("stun") and unit.stun > 0: statuses.append(t("眩晕", "Stun"))
	if float(unit.get("grievous_time", 0.0)) > 0.0: statuses.append(t("重伤", "Grievous"))
	if unit.has("charm") and unit.charm > 0: statuses.append(t("魅惑", "Charm"))
	return " · ".join(statuses)

func _log(text_value: String) -> void:
	if not is_instance_valid(log_box): return
	if phase == "combat":
		for unit in combat_units:
			text_value = text_value.replace(_hero_name(unit.hero_id), _combat_name(unit))
	log_box.append_text(text_value + "\n")
	log_box.scroll_to_line(log_box.get_line_count())
