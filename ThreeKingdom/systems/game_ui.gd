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
	battle_workspace = HBoxContainer.new()
	battle_workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_workspace.add_theme_constant_override("separation", 6 if compact_mobile else 12)
	root.add_child(battle_workspace)
	var arena := PanelContainer.new()
	battle_arena_panel = arena
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
	battle_workspace.add_child(arena)
	var command := PanelContainer.new()
	battle_info_panel = command
	command.custom_minimum_size.x = 330 if compact_mobile else 430
	_style(command, Color("#151719ee"), 14, Color("#594532"), 1)
	var command_box := VBoxContainer.new()
	command_box.add_theme_constant_override("separation", 8)
	battle_info_host = Control.new()
	battle_info_host.custom_minimum_size.y = 190 if compact_mobile else 430
	battle_info_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_info_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	command_box.add_child(battle_info_host)
	battle_info_tabs = TabContainer.new()
	battle_info_tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle_info_tabs.add_theme_font_size_override("font_size", 18 if compact_mobile else 17)
	battle_info_tabs.add_theme_constant_override("outline_size", 1)
	battle_info_tabs.get_tab_bar().custom_minimum_size.y = 58 if compact_mobile else 48
	battle_info_tabs.get_tab_bar().add_theme_font_size_override("font_size", 18 if compact_mobile else 17)
	battle_info_host.add_child(battle_info_tabs)
	var bonds_page := VBoxContainer.new()
	bonds_page.name = "Bonds"
	bonds_page.add_theme_constant_override("separation", 8)
	battle_info_tabs.add_child(bonds_page)
	var campaign_title := _label(t("闯关战局", "CAMPAIGN"), 18, Color("#f0c77a"))
	campaign_title.name = "CampaignTitle"
	bonds_page.add_child(campaign_title)
	var bond_header := _label(t("我方羁绊进度", "YOUR BOND PROGRESS"), 13, Color("#ad8355"))
	bond_header.name = "BondHeader"
	bonds_page.add_child(bond_header)
	bonds_label = RichTextLabel.new()
	bonds_label.bbcode_enabled = true
	bonds_label.scroll_active = true
	bonds_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bonds_label.add_theme_font_size_override("normal_font_size", 14 if compact_mobile else 13)
	bonds_label.add_theme_color_override("default_color", Color("#d8cfbd"))
	_enable_touch_value_scroll(bonds_label)
	bonds_page.add_child(bonds_label)
	var log_page := VBoxContainer.new()
	log_page.name = "Log"
	log_page.add_theme_constant_override("separation", 8)
	battle_info_tabs.add_child(log_page)
	log_title_label = _label("", 16, Color("#ad8355"))
	log_page.add_child(log_title_label)
	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.scroll_active = true
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.add_theme_font_size_override("normal_font_size", 14 if compact_mobile else 12)
	log_box.add_theme_color_override("default_color", Color("#bcb5a9"))
	_enable_touch_value_scroll(log_box)
	log_page.add_child(log_box)
	var stats_page := VBoxContainer.new()
	stats_page.name = "Stats"
	stats_page.add_theme_constant_override("separation", 8)
	battle_info_tabs.add_child(stats_page)
	stats_title_label = _label("", 16, Color("#ad8355"))
	stats_page.add_child(stats_title_label)
	var stats_tabs := HBoxContainer.new()
	stats_tabs.add_theme_constant_override("separation", 4)
	for metric in ["damage", "healing", "control", "taken"]:
		var tab := _button("")
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", 13 if compact_mobile else 11)
		tab.pressed.connect(_set_stats_metric.bind(metric))
		stats_tab_buttons[metric] = tab
		stats_tabs.add_child(tab)
	stats_page.add_child(stats_tabs)
	var stats_scroll := ScrollContainer.new()
	stats_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_enable_touch_scroll(stats_scroll, false, true)
	stats_page.add_child(stats_scroll)
	stats_chart = VBoxContainer.new()
	stats_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_chart.add_theme_constant_override("separation", 7)
	stats_scroll.add_child(stats_chart)
	battle_info_tabs.current_tab = 0
	draft_title_label = _label("", 18, Color("#f0c77a"))
	command_box.add_child(draft_title_label)
	hint_label = _label("", 12, Color("#aaa294"))
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size.y = 36
	hint_label.visible = not compact_mobile
	command_box.add_child(hint_label)
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
	battle_workspace.add_child(command)
	_apply_board_side_layout()
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
	_build_unit_inspector()

func _build_unit_inspector() -> void:
	unit_inspector_overlay = ColorRect.new()
	unit_inspector_overlay.color = Color(0.015, 0.02, 0.025, 0.86)
	unit_inspector_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	unit_inspector_overlay.z_index = 1400
	unit_inspector_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle_info_host.add_child(unit_inspector_overlay)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var side_margin := 4 if _is_mobile_ui() else 8
	margin.add_theme_constant_override("margin_left", side_margin)
	margin.add_theme_constant_override("margin_right", side_margin)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	unit_inspector_overlay.add_child(margin)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style(panel, Color("#15191df8"), 16, Color("#b98a4f"), 2)
	margin.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	unit_inspector_title = _button("")
	unit_inspector_title.custom_minimum_size.y = 56
	unit_inspector_title.add_theme_font_size_override("font_size", 23 if _is_mobile_ui() else 20)
	unit_inspector_title.tooltip_text = t("点击顶部关闭状态栏", "Tap the header to close")
	unit_inspector_title.pressed.connect(_hide_unit_inspector)
	box.add_child(unit_inspector_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_enable_touch_scroll(scroll, false, true)
	box.add_child(scroll)
	unit_inspector_detail = RichTextLabel.new()
	unit_inspector_detail.bbcode_enabled = true
	unit_inspector_detail.fit_content = true
	unit_inspector_detail.scroll_active = false
	unit_inspector_detail.selection_enabled = true
	unit_inspector_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unit_inspector_detail.add_theme_font_size_override("normal_font_size", 17 if _is_mobile_ui() else 15)
	unit_inspector_detail.add_theme_constant_override("line_separation", 5)
	unit_inspector_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(unit_inspector_detail)
	unit_inspector_overlay.hide()

func _toggle_unit_inspector(unit_id: String) -> void:
	unit_inspector_unit_id = unit_id
	_refresh_unit_inspector()
	if is_instance_valid(unit_inspector_overlay):
		unit_inspector_overlay.show()

func _hide_unit_inspector() -> void:
	unit_inspector_unit_id = ""
	if is_instance_valid(unit_inspector_overlay):
		unit_inspector_overlay.hide()

func _inspector_number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else ("%.1f" % value)

func _inspector_unit() -> Variant:
	var rosters: Array = [combat_units] if phase == "combat" else [player_units, enemy_units]
	if phase == "combat": rosters.append_array([player_units, enemy_units])
	for roster in rosters:
		for unit in roster:
			if str(unit.get("id", "")) == unit_inspector_unit_id:
				return unit
	return null

func _inspector_bond_state(unit: Dictionary) -> String:
	var status_roster: Array = combat_units
	if status_roster.is_empty() or phase != "combat":
		status_roster = player_units if str(unit.team) == "player" else enemy_units
	var allies: Array = status_roster.filter(func(other): return other.team == unit.team and other.alive and int(other.row) >= 0)
	var hero_id := str(unit.hero_id)
	var faction := str(heroes[hero_id].f)
	var faction_hero_ids := {}
	for other in allies:
		if str(heroes[other.hero_id].f) == faction: faction_hero_ids[str(other.hero_id)] = true
	var faction_count := faction_hero_ids.size()
	var tier := 0
	for threshold in [2, 5, 8]:
		if faction_count >= threshold: tier = threshold
	var graph := _bond_graph_data(faction)
	var lines: Array[String] = []
	var faction_name := t(str(graph.faction[1]), str(graph.faction[2]))
	lines.append(("[color=#f3d27a]✓ " if tier > 0 else "[color=#777b80]○ ") + faction_name + "  " + str(faction_count) + "/8[/color]")
	for bond in graph.bonds:
		var members: Array = bond[3]
		if not members.has(hero_id): continue
		var current := 0
		for member in members:
			if allies.any(func(other): return str(other.hero_id) == str(member)):
				current += 1
		var active := current == members.size()
		var bond_name := t(str(bond[1]), str(bond[2]))
		lines.append(("[color=#8fe39b]✓ " if active else "[color=#777b80]○ ") + bond_name + "  " + str(current) + "/" + str(members.size()) + "[/color]")
	return "\n".join(lines)

func _inspector_buffs(unit: Dictionary) -> String:
	var lines: Array[String] = []
	if float(unit.get("shield", 0.0)) > 0.0: lines.append(t("护盾 ", "Shield ") + _inspector_number(float(unit.shield)))
	if float(unit.get("damage_buff", 0.0)) > 0.0: lines.append(t("永久增伤 ", "Damage bonus ") + _inspector_number(float(unit.damage_buff) * 100.0) + "%")
	if float(unit.get("timed_damage_buff", 0.0)) > 0.0: lines.append(t("临时增伤 ", "Timed damage ") + _inspector_number(float(unit.timed_damage_buff) * 100.0) + "% · " + _inspector_number(float(unit.get("timed_damage_time", 0.0))) + "s")
	if float(unit.get("damage_reduction", 0.0)) > 0.0: lines.append(t("伤害减免 ", "Damage reduction ") + _inspector_number(float(unit.damage_reduction) * 100.0) + "%")
	if float(unit.get("faction_damage_reduction", 0.0)) > 0.0: lines.append(t("阵营减伤 ", "Faction reduction ") + _inspector_number(float(unit.faction_damage_reduction) * 100.0) + "%")
	if float(unit.get("timed_reduction", 0.0)) > 0.0: lines.append(t("临时减伤 ", "Timed reduction ") + _inspector_number(float(unit.timed_reduction) * 100.0) + "% · " + _inspector_number(float(unit.get("timed_reduction_time", 0.0))) + "s")
	if float(unit.get("timed_action_bonus", 0.0)) > 0.0: lines.append(t("行动条加速 ", "Gauge haste ") + _inspector_number(float(unit.timed_action_bonus) * 100.0) + "% · " + _inspector_number(float(unit.get("timed_action_time", 0.0))) + "s")
	if float(unit.get("skill_value_bonus", 0.0)) != 0.0: lines.append(t("兵略值加成 ", "Strategy bonus ") + _inspector_number(float(unit.skill_value_bonus)))
	if float(unit.get("all_lifesteal", 0.0)) > 0.0: lines.append(t("全能吸血 ", "Omnivamp ") + _inspector_number(float(unit.all_lifesteal) * 100.0) + "% · " + _inspector_number(float(unit.get("all_lifesteal_time", 0.0))) + "s")
	if float(unit.get("regen_time", 0.0)) > 0.0: lines.append(t("回春 ", "Regeneration ") + _inspector_number(float(unit.regen_time)) + "s")
	if float(unit.get("stealth", 0.0)) > 0.0: lines.append(t("隐身 ", "Stealth ") + _inspector_number(float(unit.stealth)) + "s")
	if int(unit.get("zhangbao_revives_used", 0)) >= 0 and str(unit.hero_id) == "zhangbao":
		var total_revives := 1 + (1 if _pair_active(str(unit.team), "zhangliang", "zhangbao") else 0)
		lines.append(t("剩余复生 ", "Revives left ") + str(maxi(0, total_revives - int(unit.zhangbao_revives_used))))
	return t("无", "None") if lines.is_empty() else "\n".join(lines)

func _inspector_debuffs(unit: Dictionary) -> String:
	var lines: Array[String] = []
	var burns: Array = unit.get("burn_effects", [])
	if not burns.is_empty():
		for index in burns.size():
			var effect: Dictionary = burns[index]
			lines.append(t("灼烧", "Burn") + " #" + str(index + 1) + "  " + _inspector_number(float(effect.get("time", 0.0))) + "s · " + t("每秒 ", "per second ") + _inspector_number(float(effect.get("damage", 0.0))))
	elif float(unit.get("burn", 0.0)) > 0.0:
		lines.append(t("灼烧 ", "Burn ") + _inspector_number(float(unit.burn)) + "s · " + t("每秒 ", "per second ") + _inspector_number(float(unit.get("burn_damage", 0.0))))
	var poisons: Array = unit.get("poison_effects", [])
	if not poisons.is_empty():
		for index in poisons.size():
			var effect: Dictionary = poisons[index]
			lines.append(t("中毒", "Poison") + " #" + str(index + 1) + "  " + _inspector_number(float(effect.get("time", 0.0))) + "s · " + _inspector_number(float(effect.get("ratio", 0.0)) * 100.0) + "% Max HP/s")
	elif float(unit.get("poison", 0.0)) > 0.0:
		lines.append(t("中毒 ", "Poison ") + _inspector_number(float(unit.poison)) + "s · " + _inspector_number(float(unit.get("poison_ratio", 0.0)) * 100.0) + "% Max HP/s")
	if float(unit.get("stun", 0.0)) > 0.0: lines.append(t("眩晕 ", "Stun ") + _inspector_number(float(unit.stun)) + "s")
	if float(unit.get("charm", 0.0)) > 0.0: lines.append(t("魅惑 ", "Charm ") + _inspector_number(float(unit.charm)) + "s")
	if float(unit.get("fear", 0.0)) > 0.0: lines.append(t("恐惧 ", "Fear ") + _inspector_number(float(unit.fear)) + "s")
	if float(unit.get("freeze", 0.0)) > 0.0: lines.append(t("冻结 ", "Freeze ") + _inspector_number(float(unit.freeze)) + "s")
	if float(unit.get("silence", 0.0)) > 0.0: lines.append(t("沉默 ", "Silence ") + _inspector_number(float(unit.silence)) + "s")
	if float(unit.get("slow_time", 0.0)) > 0.0: lines.append(t("减速 ", "Slow ") + _inspector_number(float(unit.get("slow_amount", 0.0)) * 100.0) + "% · " + _inspector_number(float(unit.slow_time)) + "s")
	if float(unit.get("vulnerable_time", 0.0)) > 0.0: lines.append(t("易损 ", "Vulnerable ") + _inspector_number(float(unit.get("vulnerable", 0.0)) * 100.0) + "% · " + _inspector_number(float(unit.vulnerable_time)) + "s")
	if float(unit.get("grievous_time", 0.0)) > 0.0: lines.append(t("重伤 ", "Grievous ") + _inspector_number(float(unit.get("grievous", 0.0)) * 100.0) + "% · " + _inspector_number(float(unit.grievous_time)) + "s")
	if float(unit.get("skill_debuff_time", 0.0)) > 0.0: lines.append(t("虚弱：兵略值降低 ", "Weakened: Strategy -") + _inspector_number(float(unit.get("skill_debuff", 0.0)) * 100.0) + "% · " + _inspector_number(float(unit.skill_debuff_time)) + "s")
	if bool(unit.get("zhuge_fire_mark", false)): lines.append(t("火攻标记", "Fire Assault mark"))
	if float(unit.get("strategy_mark", 0.0)) > 0.0: lines.append(t("谋略标记 ", "Strategy mark ") + _inspector_number(float(unit.strategy_mark)) + "s")
	return t("无", "None") if lines.is_empty() else "\n".join(lines)

func _refresh_unit_inspector() -> void:
	if unit_inspector_unit_id.is_empty() or not is_instance_valid(unit_inspector_detail): return
	var unit = _inspector_unit()
	if unit == null:
		_hide_unit_inspector()
		return
	var hero: Dictionary = heroes[unit.hero_id]
	var cooldown_text := t("被动技能", "Passive") if not _unit_has_active_skill(unit) else _inspector_number(_unit_skill_cooldown(unit)) + "s"
	unit_inspector_title.text = _hero_name(unit.hero_id) + t("  · 关闭状态栏 ×", "  · CLOSE ×")
	var state_text := t("存活", "Alive") if bool(unit.alive) else t("已阵亡", "Fallen")
	var body := "[color=#f0c77a][font_size=22][b]" + t("战斗状态", "COMBAT STATUS") + "[/b][/font_size][/color]\n"
	body += t("阵营：", "Faction: ") + _faction_name(hero.f) + "  ·  " + _hero_army_name(unit.hero_id) + "  ·  " + state_text + "\n"
	body += "[b]HP[/b]  " + _inspector_number(maxf(0.0, float(unit.hp))) + " / " + _inspector_number(float(unit.max_hp)) + "\n"
	body += "[b]" + t("兵略值", "Strategy") + "[/b]  " + _inspector_number(_unit_skill_stat_value(unit) * maxf(0.0, 1.0 - float(unit.get("skill_debuff", 0.0)))) + t("（面板基础 ", " (base ") + _inspector_number(float(hero.skill_value)) + t("）", ")") + "\n"
	body += t("冷却：", "Cooldown: ") + cooldown_text + t("  ·  行动条：", "  ·  Gauge: ") + _inspector_number(float(unit.get("action", 0.0))) + "/100\n\n"
	body += "[color=#f0c77a][font_size=20][b]" + str(hero.zh_skill if language == "zh" else hero.skill) + "[/b][/font_size][/color]\n" + _skill_detail(str(unit.hero_id)) + "\n\n"
	body += "[color=#8fe39b][font_size=20][b]" + t("当前增益", "CURRENT BUFFS") + "[/b][/font_size][/color]\n" + _inspector_buffs(unit) + "\n\n"
	body += "[color=#ef8a79][font_size=20][b]" + t("当前减益", "CURRENT DEBUFFS") + "[/b][/font_size][/color]\n" + _inspector_debuffs(unit)
	body += "\n\n[color=#f0c77a][font_size=20][b]" + t("羁绊状态", "BOND STATUS") + "[/b][/font_size][/color]\n" + _inspector_bond_state(unit) + "\n\n"
	body += "[b]" + t("本武将羁绊具体效果", "Hero-specific bond effects") + "[/b]\n" + _hero_bond_detail(str(unit.hero_id))
	unit_inspector_detail.text = body

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
	draft_overlay.color = Color("#080a0df2")
	draft_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	draft_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	draft_layer.add_child(draft_overlay)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mobile := _is_mobile_ui()
	margin.add_theme_constant_override("margin_left", 18 if mobile else 28)
	margin.add_theme_constant_override("margin_right", 18 if mobile else 28)
	margin.add_theme_constant_override("margin_top", 14 if mobile else 24)
	margin.add_theme_constant_override("margin_bottom", 22 if mobile else 24)
	draft_overlay.add_child(margin)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 640) if mobile else Vector2(1240, 700)
	_style(panel, Color("#171513"), 18, Color("#8e673d"), 2)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var header := HBoxContainer.new()
	var title := _label(t("本轮招募", "RECRUITMENT"), 20, Color("#f0c77a"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := _button(t("暂时隐藏", "HIDE"))
	close.custom_minimum_size = Vector2(105, 48)
	close.pressed.connect(_hide_draft_layer)
	header.add_child(close)
	box.add_child(header)
	var draft_scroll := ScrollContainer.new()
	draft_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	draft_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	draft_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	draft_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_enable_touch_scroll(draft_scroll, true, true)
	box.add_child(draft_scroll)
	draft_box = HBoxContainer.new()
	draft_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	draft_box.add_theme_constant_override("separation", 12)
	draft_scroll.add_child(draft_box)

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
	panel.custom_minimum_size = Vector2(560, 700)
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
	enemy_faction_setting_options = OptionButton.new()
	enemy_faction_setting_options.custom_minimum_size = Vector2(360, 48)
	enemy_faction_setting_options.add_item(t("敌方阵营：全部", "Enemy faction: All"), 0)
	for faction in ["shu", "wei", "wu", "qun"]:
		enemy_faction_setting_options.add_item(_faction_name(faction), enemy_faction_setting_options.get_item_count())
	enemy_faction_setting_options.item_selected.connect(_set_enemy_faction_filter)
	box.add_child(enemy_faction_setting_options)
	board_side_setting_options = OptionButton.new()
	board_side_setting_options.custom_minimum_size = Vector2(360, 48)
	board_side_setting_options.add_item(t("棋盘居左", "Board on left"), 0)
	board_side_setting_options.add_item(t("棋盘居右", "Board on right"), 1)
	board_side_setting_options.item_selected.connect(_set_board_side)
	box.add_child(board_side_setting_options)
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
	if is_instance_valid(enemy_faction_setting_options):
		var factions := ["", "shu", "wei", "wu", "qun"]
		enemy_faction_setting_options.select(factions.find(enemy_faction_filter))
	if is_instance_valid(board_side_setting_options):
		board_side_setting_options.set_item_text(0, t("棋盘居左", "Board on left"))
		board_side_setting_options.set_item_text(1, t("棋盘居右", "Board on right"))
		board_side_setting_options.select(0 if board_side == "left" else 1)

func _set_draft_faction_filter(index: int) -> void:
	var factions := ["", "shu", "wei", "wu", "qun"]
	draft_faction_filter = factions[clampi(index, 0, factions.size() - 1)]
	_save_settings()
	if phase == "draft": _generate_choices()
	_refresh_settings_ui()
	_render()

func _set_enemy_faction_filter(index: int) -> void:
	var factions := ["", "shu", "wei", "wu", "qun"]
	enemy_faction_filter = factions[clampi(index, 0, factions.size() - 1)]
	_save_settings()
	_refresh_settings_ui()

func _set_board_side(index: int) -> void:
	board_side = "left" if index == 0 else "right"
	_apply_board_side_layout()
	_save_settings()
	_refresh_settings_ui()

func _apply_board_side_layout() -> void:
	if not is_instance_valid(battle_workspace) or not is_instance_valid(battle_arena_panel) or not is_instance_valid(battle_info_panel): return
	battle_workspace.move_child(battle_arena_panel, 0 if board_side == "left" else 1)
	battle_workspace.move_child(battle_info_panel, 1 if board_side == "left" else 0)

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		pause_during_actions = bool(config.get_value("battle", "pause_during_actions", true))
		game_speed = float(config.get_value("battle", "speed", 1.0))
		draft_faction_filter = str(config.get_value("battle", "draft_faction_filter", ""))
		enemy_faction_filter = str(config.get_value("battle", "enemy_faction_filter", ""))
		show_hero_codex_images = bool(config.get_value("interface", "show_hero_codex_images", false))
		board_side = str(config.get_value("interface", "board_side", "left"))
		if game_speed not in [1.0, 2.0, 4.0]: game_speed = 1.0
		if draft_faction_filter not in ["", "shu", "wei", "wu", "qun"]: draft_faction_filter = ""
		if enemy_faction_filter not in ["", "shu", "wei", "wu", "qun"]: enemy_faction_filter = ""
		if board_side not in ["left", "right"]: board_side = "left"
	battle_speed = game_speed

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("battle", "pause_during_actions", pause_during_actions)
	config.set_value("battle", "speed", game_speed)
	config.set_value("battle", "draft_faction_filter", draft_faction_filter)
	config.set_value("battle", "enemy_faction_filter", enemy_faction_filter)
	config.set_value("interface", "show_hero_codex_images", show_hero_codex_images)
	config.set_value("interface", "board_side", board_side)
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
	encyclopedia_star_level = 1
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
	encyclopedia_preview_name.text = _hero_name(hero_id)
	encyclopedia_preview_name.add_theme_color_override("font_color", FACTION_COLORS[hero.f].lightened(0.32))
	var stat_mult := _star_stat_multiplier(encyclopedia_star_level)
	encyclopedia_preview_detail.text = (
		t("阵营：", "Faction: ") + _faction_name(hero.f) + "\n"
		+ t("生命：", "HP: ") + str(round(float(hero.hp) * stat_mult)) + "\n"
		+ t("兵略值：", "Strategy: ") + str(round(float(hero.skill_value))) + "\n"
		+ t("军种：", "Rank: ") + _hero_army_name(hero_id) + (t("（任意布阵）", " (any formation row)") if bool(hero.get("all_rows", false)) else "（" + str(hero.range) + "）") + "\n"
		+ t("技能冷却：", "Skill cooldown: ") + str(hero.cooldown) + t(" 秒", "s") + "\n\n"
		+ t("技能：", "Skill: ") + (str(hero.zh_skill) if language == "zh" else str(hero.skill)) + "\n"
		+ _skill_detail(hero_id) + "\n\n"
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
		var hero_name := _label(_hero_name(hero_id), 24, FACTION_COLORS[hero.f].lightened(0.32))
		hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_box.add_child(hero_name)
		var cooldown_text := t("被动", "Passive") if float(hero.cooldown) <= 0.0 else t("冷却 ", "Cooldown ") + str(hero.cooldown) + t("秒", "s")
		var stats := _label(
			t("生命 ", "HP ") + str(round(float(hero.hp) * stat_mult))
			+ "  ·  " + t("兵略值 ", "Strategy ") + str(round(float(hero.skill_value)))
			+ "\n" + _hero_army_name(hero_id) + "  ·  " + cooldown_text,
			13,
			Color("#e8e2cf")
		)
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_box.add_child(stats)
		var detail := _label("", 13, Color("#c9c0b1"))
		detail.text = _skill_detail(hero_id) + "\n\n" + _hero_bond_detail(hero_id)
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
			"faction":["han_expedition", "蜀", "Shu", "2 / 5 / 8", "全体蜀将承伤降低2%/5%/8%。8人时，每次受伤后额外获得2%减伤，最多3层；自身释放技能后清空额外层数。", "All Shu heroes take 2%/5%/8% less damage. At 8, each damage instance adds another 2% reduction, up to 3 stacks; casting clears the extra stacks."],
			"bonds":[
				["peach_garden", "桃园结义", "Peach Garden", ["liubei", "guanyu", "zhangfei"], "3人", "3 heroes", "刘备每秒治疗提高至150%兵略值；关羽按列斩实际伤害的30%自疗；张飞号令延长50%。", "Liu Bei heals at 150% Strategy per second; Guan Yu heals for 30% of actual cleave damage; Zhang Fei's command lasts 50% longer."],
				["five_tigers", "五虎上将", "Five Tigers", ["guanyu", "zhangfei", "zhaoyun", "huangzhong", "machao"], "5人", "5 heroes", "关羽列斩460%；张飞号令延长50%且增伤变为0.3×兵略值%；赵云每刺+100%；黄忠锁定前军造成900%；马超施法后为同排友军提供0.4×自身兵略值，持续7.2秒。", "Guan Yu 460%; Zhang Fei gains duration and Strategy-scaled damage; Zhao Yun +100% each thrust; Huang Zhong 900% to vanguards; Ma Chao grants same-row Strategy for 7.2s."],
				["northern_dream", "夜梦北斗", "Northern Dream", ["liubei", "liushan"], "2人", "2 heroes", "刘备持续治疗时间延长30%；刘禅鼓舞改为同列友军获得0.18×兵略值%的增伤。", "Liu Bei's regeneration lasts 30% longer; Liu Shan empowers same-column allies at 0.18 × Strategy percent."],
				["wulong_han", "卧龙辅汉", "Wolong Aids Han", ["liubei", "zhugeliang"], "2人", "2 heroes", "刘备持续治疗目标承伤降低30%；诸葛亮每多命中一名武将，本次全部伤害提高4%。", "Liu Bei's regenerating target takes 30% less damage; Zhuge Liang gains 4% damage per additional hero hit."],
				["seven_charges", "七进七出", "Seven Charges", ["zhaoyun", "liushan"], "2人", "2 heroes", "赵云改为7次连刺并强攻后军；刘禅赋予被鼓舞友军30%全能吸血。", "Zhao Yun gains seven thrusts against the rear; Liu Shan grants empowered allies 30% omnivamp."],
				["one_rider", "一骑当千", "One Rider", ["machao", "madai"], "2人", "2 heroes", "马超贯穿改为前军/中军/后军260%/300%/340%；马岱开场行动条充满。", "Ma Chao pierces for 260%/300%/340% by row; Ma Dai starts at full gauge."],
				["fated_enemies", "宿命之敌", "Fated Enemies", ["madai", "weiyan"], "2人", "2 heroes", "马岱命中目标在本回合额外承受0.3×兵略值%的伤害；魏延按本次伤害的6%治疗相邻及正后方友军。", "Ma Dai applies Strategy-scaled vulnerability for the round; Wei Yan heals adjacent and directly-behind allies for 6% of cast damage."],
				["flying_meteor", "飞火流星", "Flying Meteor", ["huangzhong", "weiyan"], "2人", "2 heroes", "黄忠箭击有30%概率造成2倍伤害；魏延释放技能后恢复本次实际伤害23%的生命。", "Huang Zhong has a 30% chance to deal double damage; Wei Yan heals for 23% of actual cast damage."],
				["dragon_phoenix", "卧龙凤雏", "Dragon and Phoenix", ["zhugeliang", "pangtong"], "2人", "2 heroes", "诸葛亮八阵额外影响四个斜对角；庞统目标增加至3个，连环传导提高至50%。", "Zhuge Liang adds four diagonals; Pang Tong gains a third target and 50% chain echo."],
				["expedition_legacy", "北伐传承", "Northern Expedition Legacy", ["zhugeliang", "jiangwei"], "2人", "2 heroes", "诸葛亮八阵额外影响左右同排格；姜维对主目标周围八格敌人造成100%兵略值伤害。", "Zhuge Liang adds horizontal tiles; Jiang Wei splashes all eight neighboring enemies for 100% Strategy."],
				["seven_captures", "七擒孟获", "Seven Captures", ["zhugeliang", "menghuo"], "2人", "2 heroes", "诸葛亮伤害提高20%并施加10秒火攻标记，再次命中标记者提高40%；孟获追加35%整排余震。", "Zhuge Liang gains 20%, marks for 10s, and gains 40% on marked targets; Meng Huo adds a 35% row aftershock."],
				["nanman_couple", "南蛮夫妇", "Nanman Couple", ["menghuo", "zhurong"], "2人", "2 heroes", "孟获强化对灼烧目标的震地；祝融飞刃向左右相邻格弹射50%兵略值伤害。", "Meng Huo's quake is empowered against burning targets; Zhurong bounces to horizontal neighbors for 50% Strategy."],
				["barbarian_reinforcement", "蛮王援军", "Barbarian Reinforcements", ["menghuo", "dailaidongzhu"], "2人", "2 heroes", "孟获压退整排行动条；带来洞主改为以320%兵略值攻击行动条最高目标所在整列。", "Meng Huo pushes back the row's gauges; Dailai strikes the highest-gauge target's column for 320% Strategy."],
				["sibling_bond", "姐弟同心", "Sibling Bond", ["dailaidongzhu", "zhurong"], "2人", "2 heroes", "祝融灼烧延长2秒并提高至每秒100%；带来洞主附加灼烧并对已灼烧目标追加50%兵略值伤害。", "Zhurong's burn gains 2s and rises to 100% per second; Dailai burns and adds 50% Strategy against burning targets."]
			]
		},
		"wei":{
			"faction":["wei_command", "魏", "Wei", "2 / 5 / 8", "全体魏将控制时长提高3%/8%/15%。8人时，对带有任意控制或减益的目标造成伤害提高15%。", "All Wei heroes gain 3%/8%/15% control duration. At 8, they deal 15% more damage to targets with any control or debuff."],
			"bonds":[
				["evil_of_old", "古之恶来", "Evil of Old", ["caocao", "dianwei"], "2人", "2 heroes", "曹操目标+1，命中后军时伤害增加100%兵略值、眩晕增加0.5秒；典韦目标+1、伤害减少30%兵略值。", "Cao Cao gains 1 target and, against rearguards, +100% Strategy damage and +0.5s stun; Dian Wei gains 1 target but loses 30% Strategy damage."],
				["tiger_guard", "虎卫护主", "Tiger Guard", ["caocao", "xuchu"], "2人", "2 heroes", "曹操目标+1，命中前军时伤害增加100%兵略值、眩晕增加0.5秒；许褚目标+1、伤害减少40%兵略值。", "Cao Cao gains 1 target and, against vanguards, +100% Strategy damage and +0.5s stun; Xu Chu gains 1 target but loses 40% Strategy damage."],
				["twin_wei_guards", "魏武双卫", "Twin Wei Guards", ["dianwei", "xuchu"], "2人", "2 heroes", "典韦伤害增加80%兵略值；许褚伤害增加100%兵略值。", "Dian Wei gains 80% Strategy damage; Xu Chu gains 100% Strategy damage."],
				["hefei_vanguard", "逍遥津先锋", "Hefei Vanguard", ["zhangliao", "yuejin"], "2人", "2 heroes", "张辽回旋刃每段伤害增加40%兵略值；乐进目标增加1名。", "Zhang Liao gains 40% Strategy damage per pass; Yue Jin gains 1 target."],
				["adaptive_vanguard", "巧变开山", "Adaptive Vanguard", ["zhanghe", "xuhuang"], "2人", "2 heroes", "张郃眩晕增加1秒；徐晃伤害增加80%兵略值。", "Zhang He gains 1s stun; Xu Huang gains 80% Strategy damage."],
				["five_elites", "五子良将", "Five Elite Generals", ["zhangliao", "yuejin", "zhanghe", "xuhuang", "yujin"], "5人", "5 heroes", "强化回旋刃易损、乱射重伤、连枪扩散、开山随机排控制与双目标护盾。", "Enhances Returning Blade vulnerability, Volley grievous wounds, spear chaining, random-row control, and two-target shields."],
				["swift_bulwark", "神速镇远", "Swift Bulwark", ["xiahouyuan", "caoren"], "2人", "2 heroes", "夏侯渊冷却-0.5秒、眩晕+0.5秒；曹仁目标+1、眩晕+0.5秒、后军减伤+0.1*兵略值%。", "Xiahou Yuan gains -0.5s cooldown and +0.5s stun; Cao Ren gains 1 target, +0.5s stun, and +0.1*Strategy% rear damage reduction."],
				["xiahou_brothers", "夏侯同心", "Xiahou Brothers", ["xiahouyuan", "xiahoudun"], "2人", "2 heroes", "夏侯渊冷却-0.5秒、眩晕+0.5秒；夏侯惇目标+1、眩晕+0.5秒、前军减伤+0.1*兵略值%。", "Xiahou Yuan gains -0.5s cooldown and +0.5s stun; Xiahou Dun gains 1 target, +0.5s stun, and +0.1*Strategy% vanguard damage reduction."],
				["twin_bulwarks", "魏武双壁", "Twin Bulwarks", ["caoren", "xiahoudun"], "2人", "2 heroes", "曹仁与夏侯惇各自目标+1、眩晕+0.5秒、对应兵种减伤+0.1*兵略值%。", "Cao Ren and Xiahou Dun each gain 1 target, +0.5s stun, and +0.1*Strategy% reduction against their guarded row."],
				["thunder_frost", "雷霆冰策", "Thunder and Frost", ["simayi", "guojia"], "2人", "2 heroes", "司马懿目标+1、伤害倍率+25%；郭嘉目标+1、冷却-0.5秒。", "Sima Yi gains 1 target and +25% Strategy ratio; Guo Jia gains 1 target and -0.5s cooldown."],
				["thunder_royal", "鹰视王佐", "Eagle Eye and Royal Aid", ["simayi", "xunyu"], "2人", "2 heroes", "司马懿目标+1、伤害倍率+25%；荀彧目标+1、冷却-0.4秒。", "Sima Yi gains 1 target and +25% Strategy ratio; Xun Yu gains 1 target and -0.4s cooldown."],
				["thunder_venom", "鹰视毒谋", "Eagle Eye and Venom", ["simayi", "jiaxu"], "2人", "2 heroes", "司马懿目标+1、伤害倍率+25%；贾诩目标+1、中毒+0.5秒。", "Sima Yi gains 1 target and +25% Strategy ratio; Jia Xu gains 1 target and +0.5s poison."],
				["frost_royal", "遗计王佐", "Frozen Royal Plan", ["guojia", "xunyu"], "2人", "2 heroes", "郭嘉目标+1、冷却-0.5秒；荀彧目标+1、冷却-0.4秒。", "Guo Jia gains 1 target and -0.5s cooldown; Xun Yu gains 1 target and -0.4s cooldown."],
				["frost_venom", "冰毒奇策", "Frost and Venom", ["guojia", "jiaxu"], "2人", "2 heroes", "郭嘉目标+1、冷却-0.5秒；贾诩目标+1、中毒+0.5秒。", "Guo Jia gains 1 target and -0.5s cooldown; Jia Xu gains 1 target and +0.5s poison."],
				["royal_venom", "王佐毒策", "Royal Venom", ["xunyu", "jiaxu"], "2人", "2 heroes", "荀彧目标+1、冷却-0.4秒；贾诩目标+1、中毒+0.5秒。", "Xun Yu gains 1 target and -0.4s cooldown; Jia Xu gains 1 target and +0.5s poison."]
			]
		},
		"wu":{
			"faction":["jiangdong_relay", "吴", "Wu", "2 / 5 / 8", "全体吴将最大生命提高2%/5%/8%。8人时，每场战斗首次有吴将即将阵亡，会均摊全体存活吴将的生命比例，并各自恢复10%最大生命。", "All Wu heroes gain 2%/5%/8% max HP. At 8, the first lethal hit each battle equalizes surviving Wu heroes' health ratios, then restores 10% max HP to each."],
			"bonds":[
				["wu_commanders", "四英杰", "Four Heroes", ["zhouyu", "luxun", "lusu", "lvmeng"], "4人", "4 heroes", "周瑜额外点燃2格；陆逊火球总共弹射3次；吕蒙使命中后军恐惧4秒；鲁肃改为治疗两名最低当前生命友军，各恢复20%最大生命并提高350最大生命。", "Zhou Yu ignites 2 extra tiles; Lu Xun's fireball bounces 3 times; Lu Meng fears the struck rearguard for 4s; Lu Su treats the two lowest-current-HP allies, restoring 20% max HP and granting 350 max HP to each for the battle."],
				["sun_legacy", "孙氏之志", "Sun Legacy", ["sunjian", "sunce", "sunquan", "sunshangxiang"], "4人", "4 heroes", "孙坚自损与阵亡传承强化；孙策基础倍率提高至400%并获得残血减伤；孙权每次提高400+10%已损生命的最大生命、上限4倍并恢复15%已损生命；孙尚香改为6秒冷却、连射2次150%伤害且施法后兵略值+2。", "Empowers Sun Jian's sacrifice and Sun Ce's assault; Sun Quan gains 400 plus 10% missing HP as max HP up to 4x and restores 15% missing HP; Sun Shangxiang has a 6s cooldown, fires twice at 150%, and gains 2 Strategy per cast."],
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
			"faction":["chaos_struggle", "群", "Qun", "2 / 5 / 8", "全体群雄武将技能冷却缩短3%/8%/15%。8人时，每次释放技能有20%概率连续释放两次。", "All Qun heroes gain 3%/8%/15% skill cooldown reduction. At 8, every cast has a 20% chance to cast twice in succession."],
			"bonds":[
				["tyrant_peerless", "暴虐无双", "Tyrant and Peerless", ["lvbu", "dongzhuo"], "2人", "2 heroes", "吕布按实际伤害的40%回血；董卓伤害提高至自身当前生命15%。", "Lu Bu heals for 40% of actual damage; Dong Zhuo rises to 15% of his current HP."],
				["hero_beauty", "英雄美人", "Hero and Beauty", ["lvbu", "diaochan"], "2人", "2 heroes", "吕布每损失10%生命增伤4%；被貂蝉魅惑者每秒攻击相邻友军。", "Lu Bu gains 4% damage per 10% HP missing; charmed enemies attack adjacent allies each second."],
				["peerless_strategy", "谋定无双", "Peerless Strategy", ["lvbu", "chengong"], "2人", "2 heroes", "吕布横扫有50%概率再释放一次；陈宫冷却光环额外减少1秒。", "Lu Bu has 50% chance to sweep twice; Chen Gong's aura reduces another 1s."],
				["flying_formation", "飞将陷阵", "Flying General Formation", ["lvbu", "gaoshun"], "2人", "2 heroes", "吕布横扫追加中军三格；高顺技能额外攻击2人。", "Lu Bu also sweeps 3 midguard tiles; Gao Shun gains 2 targets."],
				["tyrant_beauty", "暴君倾城", "Tyrant and Beauty", ["dongzhuo", "diaochan"], "2人", "2 heroes", "董卓最大生命提高50%；貂蝉魅惑延长至6秒。", "Dong Zhuo gains 50% max HP; Diao Chan's charm lasts 6s."],
				["strategy_formation", "谋陷并驱", "Strategy and Formation", ["chengong", "gaoshun"], "2人", "2 heroes", "陈宫冷却光环额外减少1秒；高顺易碎延长至6秒。", "Chen Gong's aura reduces another 1s; Gao Shun's Fragile lasts 6s."],
				["hebei_twins", "河北双雄", "Hebei Twin Champions", ["yanliang", "wenchou"], "2人", "2 heroes", "颜良、文丑的技能目标各增加2名。", "Yan Liang and Wen Chou each gain 2 targets."],
				["hebei_comrades", "河北同袍", "Hebei Comrades", ["gaolan", "qunzhanghe"], "2人", "2 heroes", "高览同列兵略值加成提高至40；群张郃护盾目标增加2名。", "Gao Lan's column aura rises to +40 Strategy; Zhang He gains 2 shield targets."],
				["hebei_pillars", "河北四庭柱", "Hebei Pillars", ["yanliang", "wenchou", "qunzhanghe", "gaolan"], "4人", "4 heroes", "颜良、文丑受击为下次技能叠加15%伤害，最高300%；高览扩大同排同列40兵略值；群张郃再加2目标且护盾提高至400%。", "Yan Liang and Wen Chou gain 15% next-cast damage per hit up to 300%; Gao Lan grants +40 Strategy across his row and column; Zhang He gains 2 more targets and 400% shields."],
				["medicine_immortal", "医道同源", "Medicine and Immortality", ["huatuo", "yuji"], "2人", "2 heroes", "华佗治疗同时清除全部减益；于吉中毒目标+1且持续时间+1秒。", "Hua Tuo's healing cleanses all debuffs; Yu Ji gains 1 poison target and +1s duration."],
				["immortal_healers", "济世仙缘", "Immortal Healers", ["huatuo", "zuoci"], "2人", "2 heroes", "华佗和左慈的治疗倍率各提高50%兵略值。", "Hua Tuo and Zuo Ci each gain +50% Strategy healing ratio."],
				["fangshi_lineage", "方仙同门", "Immortal Lineage", ["yuji", "zuoci"], "2人", "2 heroes", "于吉中毒目标+1且持续时间+1秒；左慈治疗时追加两道150%天雷。", "Yu Ji gains 1 poison target and +1s duration; Zuo Ci adds two 150% Strategy thunderbolts."],
				["heaven_man", "天人同道", "Heaven and Man", ["zhangjiao", "zhangliang"], "2人", "2 heroes", "张角雷击倍率提高50%；张梁虚弱目标+1。", "Zhang Jiao gains +50% Strategy ratio; Zhang Liang gains 1 weaken target."],
				["heaven_earth", "天地雷契", "Heaven and Earth", ["zhangjiao", "zhangbao"], "2人", "2 heroes", "张角雷击目标+1且有50%概率眩晕1秒；张宝自爆波及目标周围八格。", "Zhang Jiao gains 1 target and 50% chance to stun for 1s; Zhang Bao's detonation splashes all eight neighboring tiles."],
				["earth_man", "地人续命", "Earth and Man", ["zhangliang", "zhangbao"], "2人", "2 heroes", "张梁虚弱目标+1；张宝额外复生一次。", "Zhang Liang gains 1 weaken target; Zhang Bao gains one additional revival."]
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
		"qun":["lvbu", "diaochan", "dongzhuo", "yanliang", "wenchou", "qunzhanghe", "gaolan", "gaoshun", "chengong", "huatuo", "yuji", "zuoci", "zhangjiao", "zhangliang", "zhangbao"]
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
			_hero_army_name(hero_id),
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
		"liubei": return t("仁德回春：为当前生命比例最低的友军施加持续4秒、每秒100%兵略值的治疗。", "Benevolent Renewal: Regenerate the ally with the lowest HP ratio for 4s at 100% Strategy per second.")
		"guanyu": return t("青龙偃月：劈砍目标整列，每名敌人受到210%兵略值伤害。", "Green Dragon Crescent: Cleave a target column for 210% Strategy damage to each enemy.")
		"zhangfei": return t("燕人号令：强化己方前军，增伤20%，持续3.3秒。", "Command of Yan: Allied vanguards deal 20% more damage for 3.3s.")
		"zhaoyun": return t("龙胆连刺：随机选择一名射程内敌人，快速攻击同一目标5次，每次造成115%兵略值伤害。", "Dragon-Gall Flurry: Strike one random reachable enemy 5 times for 115% Strategy damage each.")
		"liushan": return t("蜀主鼓舞（被动）：强化自己前方的友军，使其伤害提高0.27×兵略值%。", "Royal Encouragement (Passive): Empower the ally directly ahead with damage based on Strategy.")
		"huangzhong": return t("百步穿杨：射击随机可攻击格，造成420%兵略值伤害。", "Piercing Arrow: Shoot a random reachable tile for 420% Strategy damage.")
		"machao": return t("铁骑贯阵：锁定当前血量最低敌人所在列，前军/中军/后军依次受到260%/230%/200%兵略值贯穿伤害。", "Iron Cavalry: Pierce the lowest-current-HP enemy's column for 260%/230%/200% Strategy damage.")
		"madai": return t("斩将突袭：随机攻击敌方前军，造成50%最大生命伤害；无前军时攻击空格，对主公造成2000点伤害。", "General-Slaying Raid: Strike a random enemy vanguard for 50% max HP; if none exists, deal 2000 ruler damage.")
		"weiyan": return t("狂骨横斩：攻击正前方及其同排相邻格，造成180%兵略值伤害。", "Bone-Crazed Sweep: Strike the facing tile and its horizontal neighbors for 180% Strategy damage.")
		"zhugeliang": return t("八阵奇谋：随机选择敌方格子，对目标及同列相邻格造成230%兵略值法术伤害。", "Eight-Formation Stratagem: Deal 230% Strategy magic damage to a random tile and its vertical neighbors.")
		"jiangwei": return t("北伐：对随机可攻击目标造成450%兵略值法术伤害。", "Northern Expedition: Deal 450% Strategy magic damage to a random reachable target.")
		"pangtong": return t("连环计：对随机两个目标造成200%兵略值伤害并链接4秒；其中一个目标受到伤害时，其他目标受到30%同等伤害。", "Chain Scheme: Strike 2 targets for 200% Strategy and link them for 4s; damage echoes at 30%.")
		"menghuo": return t("蛮王震地：攻击敌方前军整排，造成115%兵略值物理伤害并眩晕0.8秒。", "Barbarian Quake: Strike the enemy vanguard row for 115% Strategy damage and stun for 0.8s.")
		"zhurong": return t("火神飞刃：对随机敌方单位造成300%兵略值法术伤害并灼烧3秒，每秒70%兵略值伤害。", "Flame Blade: Deal 300% Strategy magic damage to a random enemy and burn for 3s at 70% Strategy per second.")
		"dailaidongzhu": return t("蛮骨狼袭：锁定行动条最高的可攻击敌人，造成490%兵略值物理伤害。", "Savage-Bone Wolf Assault: Strike the reachable enemy with the highest gauge for 490% Strategy physical damage.")
		"caocao": return t("魏武震慑：随机攻击两名敌军，造成150%兵略值伤害并眩晕1.25秒。", "Dominion Stun: Strike two random enemies for 150% Strategy damage and stun for 1.25s.")
		"dianwei": return t("恶来袭后：随机攻击两名敌方后军，各造成240%兵略值伤害。", "Evil Guard Raid: Strike two random enemy rearguards for 240% Strategy damage each.")
		"xuchu": return t("虎卫破前：随机攻击两名敌方前军，各造成320%兵略值伤害。", "Tiger Guard Break: Strike two random enemy vanguards for 320% Strategy damage each.")
		"zhangliao": return t("威震回刃：攻击随机敌方一列，回旋刃飞出与返回各造成110%兵略值伤害。", "Returning Blade: Strike a random enemy column for 110% Strategy on both the outward and returning passes.")
		"yuejin": return t("先登乱射：随机攻击三名敌军，各造成200%兵略值伤害。", "Vanguard Volley: Strike three random enemies for 200% Strategy damage each.")
		"xuhuang": return t("撼地开山：攻击敌方前军整排，造成80%兵略值伤害并眩晕1.5秒。", "Earth-Splitting Axe: Strike the enemy vanguard row for 80% Strategy damage and stun for 1.5s.")
		"zhanghe": return t("巧变连枪：随机攻击一名敌方前军，造成400%兵略值伤害并眩晕1.5秒。", "Coiling Spear Chain: Strike a random enemy vanguard for 400% Strategy damage and stun for 1.5s.")
		"yujin": return t("毅重护阵：为当前生命值最低的友军施加300%兵略值的护盾。", "Resolute Ward: Shield the ally with the lowest current HP for 300% Strategy.")
		"xiahouyuan": return t("神速震袭：随机攻击2名敌军，造成220%兵略值伤害并眩晕1秒。", "Swift Suppression: Strike 2 random enemies for 220% Strategy and stun for 1s.")
		"caoren": return t("樊城镇远：随机攻击2名敌方后军，造成200%兵略值伤害并眩晕1秒；释放后5秒内受到敌方后军的伤害减少0.2*兵略值%。", "Rearward Bulwark: Strike 2 enemy rearguards for 200% Strategy and stun for 1s; for 5s, take 0.2*Strategy% less damage from rearguards.")
		"xiahoudun": return t("刚烈镇前：随机攻击2名敌方前军，造成240%兵略值伤害并眩晕1.5秒；释放后5秒内受到敌方前军的伤害减少0.2*兵略值%。", "Vanguard Bulwark: Strike 2 enemy vanguards for 240% Strategy and stun for 1.5s; for 5s, take 0.2*Strategy% less damage from vanguards.")
		"simayi": return t("雷霆谋断：对随机2名敌人释放雷击，造成175%兵略值伤害。", "Thunder Judgment: Strike 2 random enemies with lightning for 175% Strategy damage.")
		"guojia": return t("遗计冰封：随机冻结2名敌人4秒，期间行动条停止；冻结期间受到伤害会提前解冻，并额外受到剩余秒数×400点伤害。", "Frozen Legacy: Freeze 2 random enemies for 4s, stopping their gauges; damage shatters the freeze for 400 extra damage per remaining second.")
		"xunyu": return t("王佐疾策：随机使2名友军行动条速度提高20%，持续6秒。", "Royal Acceleration: Grant 2 random allies 20% gauge speed for 6s.")
		"jiaxu": return t("毒士奇谋：使随机2名敌军中毒5秒，每秒损失1%最大生命值。", "Venomous Scheme: Poison 2 random enemies for 5s, dealing 1% max HP per second.")
		"sunjian": return t("猛虎绝命：每回合首次消耗40%当前生命，之后每次消耗10%，攻击正前方敌军并造成等同于实际消耗生命100%的伤害。", "Tiger's Resolve: Spend 40% current HP on the first cast each round and 10% thereafter, dealing 100% of HP spent to the facing enemy.")
		"sunce": return t("小霸王连击：攻击正前方及其左侧敌军，各造成200%兵略值伤害；自身每损失10%生命，伤害提高2%。", "Conqueror's Twin Assault: Hit the facing enemy and its left neighbor for 200% Strategy each; gain 2% damage per 10% HP missing.")
		"sunquan": return t("江东制衡：随机对一名敌军造成其当前生命8%的伤害；自身最大生命提高200（最多为初始最大生命2倍），随后恢复10%已损失生命。", "Jiangdong Balance: Deal 8% of a random enemy's current HP; gain 200 max HP up to 2x initial max HP, then restore 10% missing HP.")
		"sunshangxiang": return t("枭姬叠势：随机攻击一名敌军，造成100%兵略值伤害，每次释放后兵略值提高1点；任意友军阵亡时兵略值提高5点。", "Heroine's Growing Volley: Strike a random enemy for 100% Strategy and gain 1 Strategy after each cast; gain 5 Strategy whenever an ally falls.")
		"zhouyu": return t("赤壁点火：随机选择2个敌方格，各造成100%兵略值法术伤害并灼烧3秒，每秒造成50%兵略值伤害。", "Red Cliffs: Ignite 2 random enemy tiles for 100% Strategy magic damage and burn for 3s at 50% Strategy per second.")
		"luxun": return t("火烧连营：发射火球造成200%兵略值法术伤害，并向相邻敌方单元格弹射1次。", "Flames of Camp: Launch a fireball for 200% Strategy magic damage and bounce once to an adjacent enemy tile.")
		"lvmeng": return t("白衣渡江：攻击敌方后军，造成400%兵略值物理伤害，随后隐身3秒，期间不会被选为攻击目标。", "White-Robed Raid: Strike an enemy rearguard for 400% Strategy physical damage, then enter stealth for 3s and cannot be selected.")
		"lusu": return t("连横稳阵：选择当前生命值总量最低的友军，恢复15%最大生命并使本场战斗最大生命提高200。", "Alliance: Restore 15% max HP to the ally with the lowest current HP total and grant 200 max HP for this battle.")
		"daqiao": return t("国色流离：治疗当前生命比例最低的友军。", "River Blossom: Heal the ally with the lowest HP ratio.")
		"xiaoqiao": return t("天香缓阵：随机选择两名敌方后军，使其减速6秒，期间行动条速度降低35%。", "Gentle Breeze: Slow two random enemy rearguards by 35% for 6s.")
		"taishici": return t("神亭烈戟：攻击射程内行动条最高的两名敌人，造成150%兵略值伤害，并灼烧5秒，每秒造成20%兵略值伤害。", "Blazing Twin Halberds: Strike the two reachable enemies with the highest gauges for 150% Strategy and burn for 5s at 20% Strategy per second.")
		"ganning": return t("锦帆并击：自身与同排左侧友军分别攻击一名随机敌方后军，各造成150%自身兵略值的伤害；友军协击不消耗行动条。", "Bell-Raider Twin Assault: Gan Ning and the ally directly to his left each strike a random enemy rearguard for 150% of their own Strategy; the assist costs no gauge.")
		"huanggai": return t("苦肉焚阵：消耗10%最大生命，对随机敌方一列造成等同于实际消耗生命33%的伤害；生命不足时消耗全部生命并在攻击后阵亡。", "Bitter-Flesh Column: Spend 10% max HP to damage a random enemy column for 33% of HP spent; if HP is insufficient, spend it all and fall after attacking.")
		"lvbu": return t("无双横扫：对正前方敌方前军及其左右相邻格造成175%兵略值伤害。", "Peerless Sweep: Strike the facing enemy vanguard and its left/right neighbors for 175% Strategy damage.")
		"diaochan": return t("美人离间：随机魅惑一名敌军3秒，使其行动条停止。", "Beauty's Scheme: Charm a random enemy for 3s, stopping its action gauge.")
		"dongzhuo": return t("暴君横征：对正前方敌军造成自身当前生命值7%的伤害。", "Tyrant's Might: Deal damage equal to 7% of Dong Zhuo's current HP to the facing enemy.")
		"chengong": return t("智迟谋速（被动）：陈宫及其同列友军的技能冷却减少1秒。", "Measured Formation (Passive): Chen Gong and allies in his column reduce skill cooldowns by 1s.")
		"gaoshun": return t("陷阵之志：随机攻击两名敌军，造成150%兵略值伤害并施加3秒易碎，期间受到伤害提高40%。", "Formation Resolve: Strike 2 random enemies for 150% Strategy and inflict 3s Fragile, increasing damage taken by 40%.")
		"yanliang": return t("河北猛袭：随机攻击两名敌方中军或后军，造成175%兵略值伤害。", "Hebei Fierce Assault: Strike 2 random enemy midguards or rearguards for 175% Strategy damage.")
		"wenchou": return t("河北破阵：随机攻击两名敌方前军或中军，造成目标最大生命值2%的伤害。", "Hebei Breakthrough: Strike 2 random enemy vanguards or midguards for 2% of each target's max HP.")
		"gaolan": return t("列阵扬威（被动）：高览同列友军的兵略值增加20点。", "Column Valor (Passive): Allies in Gao Lan's column gain 20 Strategy.")
		"qunzhanghe": return t("河北护阵：为当前生命值最低的两名友军施加可抵消200%兵略值伤害的护盾。", "Hebei Ward: Shield the 2 allies with the lowest current HP for 200% Strategy.")
		"huatuo": return t("青囊三济：治疗当前生命值最低的三名友军，各恢复100%兵略值生命。", "Threefold Remedy: Heal the three allies with the lowest current HP for 100% Strategy each.")
		"yuji": return t("蛊毒仙术：随机使两名敌军中毒4秒，每秒损失0.5%最大生命。", "Venomous Immortal Art: Poison two random enemies for 4s, dealing 0.5% max HP each second.")
		"zuoci": return t("遁甲济世：治疗当前生命值最低的两名友军，各恢复150%兵略值生命。", "Immortal Aid: Heal the two allies with the lowest current HP for 150% Strategy each.")
		"zhangjiao": return t("黄天雷引：召唤雷电随机攻击两名敌军，各造成200%兵略值伤害。", "Yellow Sky Thunder: Call lightning on two random enemies for 200% Strategy damage each.")
		"zhangliang": return t("人公虚弱：随机使两名敌军虚弱5秒，兵略值降低50%。", "Yellow Sky Weakening: Weaken two random enemies for 5s, reducing Strategy by 50%.")
		"zhangbao": return t("地公雷爆（被动）：阵亡时随机攻击两名敌军，各造成200%兵略值伤害，随后可满血复生一次。", "Earth General Detonation (Passive): On death, strike two random enemies for 200% Strategy, then revive once at full HP.")
	return _true_damage_text(_skill_detail_legacy(hero_id))

func _bond_entry(name_zh: String, name_en: String, member_ids: Array, effect_zh: String, effect_en: String) -> String:
	var member_names: Array[String] = []
	for id in member_ids: member_names.append(_hero_name(str(id)))
	return t(name_zh, name_en) + "（" + "、".join(member_names) + "）：" + t(effect_zh, effect_en)

func _hero_bond_detail(hero_id: String) -> String:
	var entries: Array[String] = []
	var faction: String = heroes[hero_id].f
	var faction_effects: Array = {
		"shu":["2/5/8人时，本武将承伤降低2%/5%/8%；8人时受伤叠加2%额外减伤，最多3层，释放技能后清空。", "At 2/5/8, this hero takes 2%/5%/8% less damage; at 8, damage taken adds 2% reduction up to 3 stacks, cleared after casting."],
		"wei":["2/5/8人时，本武将控制时长提高3%/8%/15%；8人时，对带有任意控制或减益的目标伤害提高15%。", "At 2/5/8, this hero gains 3%/8%/15% control duration; at 8, damage to any controlled or debuffed target increases by 15%."],
		"wu":["2/5/8人时，本武将最大生命提高2%/5%/8%；8人时，每场战斗首次吴将濒死会触发全体吴将生命均摊并恢复10%最大生命。", "At 2/5/8, this hero gains 2%/5%/8% max HP; at 8, the first lethal hit each battle equalizes Wu health and restores 10% max HP."],
		"qun":["2/5/8人时，本武将技能冷却缩短3%/8%/15%；8人时，每次释放技能有20%概率连续释放两次。", "At 2/5/8, this hero gains 3%/8%/15% cooldown reduction; at 8, each cast has a 20% chance to cast twice."]
	}[faction]
	var peach: Array = ["liubei", "guanyu", "zhangfei"]
	if peach.has(hero_id):
		var effects: Array = {"liubei":["持续治疗由每秒100%兵略值提高为150%兵略值。", "Regeneration rises from 100% to 150% Strategy each second."], "guanyu":["按整列斩实际造成伤害的30%恢复自身生命。", "Heal for 30% of actual column-cleave damage dealt."], "zhangfei":["燕人号令持续时间增加50%。", "Command of Yan lasts 50% longer."]}[hero_id]
		entries.append(_bond_entry("桃园结义", "Peach Garden", peach, effects[0], effects[1]))
	var five_tigers: Array = ["guanyu", "zhangfei", "zhaoyun", "huangzhong", "machao"]
	if five_tigers.has(hero_id):
		var effects: Array = {"guanyu":["整列斩伤害倍率由210%提高为460%兵略值。", "Column-cleave damage rises from 210% to 460% Strategy."], "zhangfei":["持续时间增加50%，增伤变为0.3×兵略值%。", "Duration gains 50%; damage bonus becomes 0.3 × Strategy percent."], "zhaoyun":["每次连击伤害增加100%兵略值。", "Each thrust gains 100% Strategy damage."], "huangzhong":["固定选择敌方前军并提高至900%兵略值。", "Always target an enemy vanguard at 900% Strategy."], "machao":["释放技能后为同排友军提供0.4×马超兵略值的兵略值，持续7.2秒。", "After casting, same-row allies gain Strategy equal to 0.4 × Ma Chao's Strategy for 7.2s."]}[hero_id]
		entries.append(_bond_entry("五虎上将", "Five Tiger Generals", five_tigers, effects[0], effects[1]))
	var personal: Dictionary = {
		"liubei":[["夜梦北斗", "Northern Dream", ["liubei", "liushan"], "持续治疗时间延长30%。", "Regeneration duration increases by 30%."], ["卧龙辅汉", "Wolong Aids Han", ["liubei", "zhugeliang"], "持续治疗中的目标受到的伤害降低30%。", "The regenerating target takes 30% less damage."]],
		"liushan":[["夜梦北斗", "Northern Dream", ["liubei", "liushan"], "鼓舞作用于同列友军，增伤变为0.18×兵略值%。", "The aura affects same-column allies at 0.18 × Strategy percent."], ["七进七出", "Seven Charges", ["zhaoyun", "liushan"], "被强化友军造成伤害的30%用于恢复自身生命。", "Empowered allies heal for 30% of damage dealt."]],
		"zhaoyun":[["七进七出", "Seven Charges", ["zhaoyun", "liushan"], "连刺变为7次，固定选择距离自己最远的敌方后军，技能冷却增加0.5秒。", "Gain 7 thrusts, force the farthest enemy rearguard, and add 0.5s cooldown."]],
		"machao":[["一骑当千", "One Rider", ["machao", "madai"], "铁骑贯阵改为递增伤害：前军/中军/后军受到260%/300%/340%兵略值伤害。", "Iron Cavalry becomes 260%/300%/340% Strategy by row."]],
		"madai":[["一骑当千", "One Rider", ["machao", "madai"], "每场战斗开局行动条充满，可立即释放技能。", "Start every battle with a full gauge."], ["宿命之敌", "Fated Enemies", ["madai", "weiyan"], "命中目标在本回合剩余时间额外承受0.3×兵略值%的伤害。", "The target takes extra damage equal to 0.3 × Strategy percent for the rest of the round."]],
		"huangzhong":[["飞火流星", "Flying Meteor", ["huangzhong", "weiyan"], "箭击有30%概率暴击，暴击伤害变为2倍。", "The shot has a 30% chance to critically strike for double damage."]],
		"weiyan":[["飞火流星", "Flying Meteor", ["huangzhong", "weiyan"], "释放技能后恢复本次实际伤害23%的生命。", "After casting, heal for 23% of actual damage dealt."], ["宿命之敌", "Fated Enemies", ["madai", "weiyan"], "释放技能后，为同排相邻友军及正后方友军恢复本次伤害6%的生命。", "After casting, heal adjacent and directly-behind allies for 6% of cast damage."]],
		"jiangwei":[
			["北伐传承", "Northern Expedition Legacy", ["zhugeliang", "jiangwei"], "对主目标周围八格内的敌人造成100%兵略值伤害。", "Deal 100% Strategy damage to enemies in all eight adjacent tiles."]
		],
		"pangtong":[
			["卧龙凤雏", "Dragon and Phoenix", ["zhugeliang", "pangtong"], "释放目标增加1个，连环传导伤害由30%提高至50%。", "Gain 1 target and raise chain echo damage from 30% to 50%."]
		],
		"menghuo":[
			["七擒孟获", "Seven Captures", ["zhugeliang", "menghuo"], "蛮王震地结束后追加一次35%兵略值的整排余震，余震不重复眩晕。", "Barbarian Quake adds a 35% Strategy row-wide aftershock without a second stun."],
			["南蛮夫妇", "Nanman Couple", ["menghuo", "zhurong"], "蛮王震地对灼烧目标伤害提高40%，并将这些目标的眩晕时间由0.8秒延长至1.2秒。", "Barbarian Quake deals +40% damage to burning targets and extends their stun from 0.8s to 1.2s."],
			["蛮王援军", "Barbarian Reinforcements", ["menghuo", "dailaidongzhu"], "蛮王震地额外使每名命中武将损失8%行动条。", "Every hero hit by Barbarian Quake also loses 8% gauge."]
		],
		"zhurong":[
			["南蛮夫妇", "Nanman Couple", ["menghuo", "zhurong"], "火神飞刃向主目标左右同排相邻格各弹射一次，造成50%兵略值伤害并施加完整灼烧。", "Flame Blade bounces to both horizontal neighbors for 50% Strategy and applies its full burn."],
			["姐弟同心", "Sibling Bond", ["dailaidongzhu", "zhurong"], "火神飞刃的灼烧时长增加2秒，灼烧伤害提高至每秒100%兵略值。", "Flame Blade's burn gains 2 seconds and rises to 100% Strategy per second."]
		],
		"dailaidongzhu":[
			["蛮王援军", "Barbarian Reinforcements", ["menghuo", "dailaidongzhu"], "蛮骨狼袭改为攻击行动条最高目标所在整列，每格造成320%兵略值伤害。", "Savage-Bone Wolf Assault strikes the highest-gauge target's entire column for 320% Strategy per tile."],
			["姐弟同心", "Sibling Bond", ["dailaidongzhu", "zhurong"], "蛮骨狼袭施加4秒、每秒50%兵略值的灼烧；若目标原本已灼烧，直接伤害额外增加50%兵略值。", "Savage-Bone Wolf Assault applies a 4s burn at 50% Strategy per second; against an already burning target, direct damage gains another 50% Strategy."]
		],
		"zhugeliang":[
			["卧龙凤雏", "Dragon and Phoenix", ["zhugeliang", "pangtong"], "八阵奇谋额外影响中心格四个斜对角相邻格。", "Eight-Formation Stratagem also affects all four diagonal neighbors."],
			["北伐传承", "Northern Expedition Legacy", ["zhugeliang", "jiangwei"], "八阵奇谋额外影响中心格左右两个同排相邻格。", "Eight-Formation Stratagem also affects the two horizontal neighbors."],
			["七擒孟获", "Seven Captures", ["zhugeliang", "menghuo"], "伤害提高20%并施加10秒火攻标记；再次命中标记者时伤害提高40%。", "Gain 20% damage and apply a 10s Fire Assault mark; hitting it again gains 40% damage."],
			["卧龙辅汉", "Wolong Aids Han", ["liubei", "zhugeliang"], "本次技能每多命中一名武将，所有受击格伤害提高4%；命中9人时提高32%。", "Each additional enemy hit grants 4% damage to all affected tiles, reaching 32% at nine enemies."]
		]
	}
	for data in personal.get(hero_id, []): entries.append(_bond_entry(data[0], data[1], data[2], data[3], data[4]))
	var combo_defs: Array = [
		[["caocao", "dianwei"], "古之恶来", "Evil of Old", {"caocao":["技能目标数增加1；命中后军时伤害增加100%兵略值，眩晕时长增加0.5秒。", "Gain 1 target; against rearguards, gain 100% Strategy damage and 0.5s stun."], "dianwei":["攻击目标增加1，造成伤害减少30%兵略值。", "Gain 1 target, but lose 30% Strategy damage."]}],
		[["caocao", "xuchu"], "虎卫护主", "Tiger Guard", {"caocao":["技能目标数增加1；命中前军时伤害增加100%兵略值，眩晕时长增加0.5秒。", "Gain 1 target; against vanguards, gain 100% Strategy damage and 0.5s stun."], "xuchu":["攻击目标增加1，造成伤害减少40%兵略值。", "Gain 1 target, but lose 40% Strategy damage."]}],
		[["dianwei", "xuchu"], "魏武双卫", "Twin Wei Guards", {"dianwei":["造成伤害增加80%兵略值。", "Gain 80% Strategy damage."], "xuchu":["造成伤害增加100%兵略值。", "Gain 100% Strategy damage."]}],
		[["zhangliao", "yuejin"], "逍遥津先锋", "Hefei Vanguard", {"zhangliao":["回旋刃的每段伤害增加40%兵略值。", "Each boomerang pass gains 40% Strategy damage."], "yuejin":["攻击目标增加1名。", "Gain 1 target."]}],
		[["zhanghe", "xuhuang"], "巧变开山", "Adaptive Vanguard", {"zhanghe":["眩晕时长增加1秒。", "Stun duration gains 1s."], "xuhuang":["伤害增加80%兵略值。", "Gain 80% Strategy damage."]}],
		[["zhouyu", "luxun", "lusu", "lvmeng"], "四英杰", "Four Heroes", {"zhouyu":["赤壁点火额外选择2个格子，总共点燃4格。", "Red Cliffs selects 2 extra tiles, igniting 4 in total."], "luxun":["火球的总弹射次数由1次提高至3次。", "Fireball total bounces increase from 1 to 3."], "lusu":["改为治疗当前生命值总量最低的两名友军，各恢复20%最大生命并使本场战斗最大生命提高350。", "Treat the two allies with the lowest current HP totals, restoring 20% max HP and granting 350 max HP to each for this battle."], "lvmeng":["白衣渡江命中的后军恐惧4秒，行动条停止且每秒受到5%最大生命伤害。", "White-Robed Raid fears the struck rearguard for 4s, freezing its gauge and dealing 5% max HP each second."]}],
		[["lvbu", "dongzhuo"], "暴虐无双", "Tyrant and Peerless", {"lvbu":["按无双横扫对武将造成的实际伤害40%恢复自身生命；护盾和空格伤害不计入。", "Heal for 40% of actual hero HP damage from Peerless Sweep; shield and empty-tile damage do not count."], "dongzhuo":["暴君横征伤害由自身当前生命7%提高至15%。", "Tyrant's Might rises from 7% to 15% of current HP."]}],
		[["lvbu", "diaochan"], "英雄美人", "Hero and Beauty", {"lvbu":["每损失10%生命，无双横扫伤害提高4%。", "Gain 4% Peerless Sweep damage per 10% HP missing."], "diaochan":["魅惑期间，目标每秒随机攻击一名相邻友军，造成被魅惑者100%兵略值伤害。", "Each second, the charmed target attacks a random adjacent ally for 100% of its own Strategy."]}],
		[["lvbu", "chengong"], "谋定无双", "Peerless Strategy", {"lvbu":["无双横扫有50%概率连续释放两次。", "Peerless Sweep has a 50% chance to cast twice."], "chengong":["智迟谋速的冷却减少额外增加1秒。", "Measured Formation reduces cooldown by another 1s."]}],
		[["lvbu", "gaoshun"], "飞将陷阵", "Flying General Formation", {"lvbu":["无双横扫追加攻击正前方敌军对应的中军及其左右相邻格。", "Peerless Sweep also hits the corresponding 3 midguard tiles."], "gaoshun":["陷阵之志的目标额外增加2名。", "Formation Resolve gains 2 targets."]}],
		[["dongzhuo", "diaochan"], "暴君倾城", "Tyrant and Beauty", {"dongzhuo":["自身最大生命值提高50%。", "Gain 50% max HP."], "diaochan":["美人离间的魅惑持续时间由3秒延长至6秒。", "Beauty's Scheme charm increases from 3s to 6s."]}],
		[["chengong", "gaoshun"], "谋陷并驱", "Strategy and Formation", {"chengong":["智迟谋速的冷却减少额外增加1秒。", "Measured Formation reduces cooldown by another 1s."], "gaoshun":["陷阵之志的易碎持续时间由3秒延长至6秒。", "Formation Resolve Fragile duration increases from 3s to 6s."]}],
		[["yanliang", "wenchou"], "河北双雄", "Hebei Twin Champions", {"yanliang":["河北猛袭的技能目标额外增加2名。", "Hebei Fierce Assault gains 2 targets."], "wenchou":["河北破阵的技能目标额外增加2名。", "Hebei Breakthrough gains 2 targets."]}],
		[["gaolan", "qunzhanghe"], "河北同袍", "Hebei Comrades", {"gaolan":["同列友军的兵略值加成由20点提高至40点。", "The column aura rises from +20 to +40 Strategy."], "qunzhanghe":["河北护阵的目标额外增加2名。", "Hebei Ward gains 2 targets."]}],
		[["zhangliao", "yuejin", "zhanghe", "xuhuang", "yujin"], "五子良将", "Five Elite Generals", {"zhangliao":["回旋刃每段伤害增加80%兵略值；命中者受到的伤害增加0.4×兵略值%，持续5秒。", "Each pass gains 80% Strategy damage; hit enemies take 0.4×Strategy% more damage for 5s."], "yuejin":["目标增加1名，伤害增加50%兵略值，并施加5秒重伤，使治疗和自身回复降低0.5×兵略值%。", "Gain 1 target and 50% Strategy damage; inflict 5s Grievous Wounds reducing healing and self-recovery by 0.5×Strategy%."], "zhanghe":["攻击扩散至主目标周围相连的两名随机敌军；伤害增加200%兵略值，目标攻击前已眩晕时额外增加400%兵略值。", "Chain to 2 random enemies adjacent to the primary; gain 200% Strategy damage and another 400% if a target was already stunned."], "xuhuang":["改为攻击随机一整排，眩晕时长增加2秒。", "Strike a random entire row and gain 2s stun."], "yujin":["施法目标增加1名，护盾值增加100%兵略值。", "Gain 1 target and 100% Strategy shielding."]}],
		[["xiahouyuan", "caoren"], "神速镇远", "Swift Bulwark", {"xiahouyuan":["冷却缩短0.5秒，眩晕延长0.5秒。", "Cooldown -0.5s and stun +0.5s."], "caoren":["目标增加1名，眩晕延长0.5秒，释放技能后受到敌方后军伤害减免提高0.1*兵略值%。", "Gain 1 target, +0.5s stun, and +0.1*Strategy% rear damage reduction."]}],
		[["xiahouyuan", "xiahoudun"], "夏侯同心", "Xiahou Brothers", {"xiahouyuan":["冷却缩短0.5秒，眩晕延长0.5秒。", "Cooldown -0.5s and stun +0.5s."], "xiahoudun":["目标增加1名，眩晕延长0.5秒，释放技能后受到敌方前军伤害减免提高0.1*兵略值%。", "Gain 1 target, +0.5s stun, and +0.1*Strategy% vanguard damage reduction."]}],
		[["caoren", "xiahoudun"], "魏武双壁", "Twin Bulwarks", {"caoren":["目标增加1名，眩晕延长0.5秒，释放技能后受到敌方后军伤害减免提高0.1*兵略值%。", "Gain 1 target, +0.5s stun, and +0.1*Strategy% rear damage reduction."], "xiahoudun":["目标增加1名，眩晕延长0.5秒，释放技能后受到敌方前军伤害减免提高0.1*兵略值%。", "Gain 1 target, +0.5s stun, and +0.1*Strategy% vanguard damage reduction."]}],
		[["simayi", "guojia"], "雷霆冰策", "Thunder and Frost", {"simayi":["雷击目标增加1名，伤害倍率提高25%兵略值。", "Gain 1 lightning target and +25% Strategy ratio."], "guojia":["冻结目标增加1名，冷却缩短0.5秒。", "Gain 1 freeze target and -0.5s cooldown."]}],
		[["simayi", "xunyu"], "鹰视王佐", "Eagle Eye and Royal Aid", {"simayi":["雷击目标增加1名，伤害倍率提高25%兵略值。", "Gain 1 lightning target and +25% Strategy ratio."], "xunyu":["加速目标增加1名，冷却缩短0.4秒。", "Gain 1 acceleration target and -0.4s cooldown."]}],
		[["simayi", "jiaxu"], "鹰视毒谋", "Eagle Eye and Venom", {"simayi":["雷击目标增加1名，伤害倍率提高25%兵略值。", "Gain 1 lightning target and +25% Strategy ratio."], "jiaxu":["中毒目标增加1名，持续时间延长0.5秒。", "Gain 1 poison target and +0.5s duration."]}],
		[["guojia", "xunyu"], "遗计王佐", "Frozen Royal Plan", {"guojia":["冻结目标增加1名，冷却缩短0.5秒。", "Gain 1 freeze target and -0.5s cooldown."], "xunyu":["加速目标增加1名，冷却缩短0.4秒。", "Gain 1 acceleration target and -0.4s cooldown."]}],
		[["guojia", "jiaxu"], "冰毒奇策", "Frost and Venom", {"guojia":["冻结目标增加1名，冷却缩短0.5秒。", "Gain 1 freeze target and -0.5s cooldown."], "jiaxu":["中毒目标增加1名，持续时间延长0.5秒。", "Gain 1 poison target and +0.5s duration."]}],
		[["xunyu", "jiaxu"], "王佐毒策", "Royal Venom", {"xunyu":["加速目标增加1名，冷却缩短0.4秒。", "Gain 1 acceleration target and -0.4s cooldown."], "jiaxu":["中毒目标增加1名，持续时间延长0.5秒。", "Gain 1 poison target and +0.5s duration."]}],
		[["sunjian", "sunce", "sunquan", "sunshangxiang"], "孙氏之志", "Sun Legacy", {"sunjian":["技能当前生命消耗由首次40%/后续10%提高至80%/20%；阵亡后使存活吴将本回合伤害提高10%。", "Current-HP costs rise from 40%/10% to 80%/20%; on death, surviving Wu allies gain +10% damage for the round."], "sunce":["技能基础倍率由200%提高至400%；每损失10%生命获得4%伤害减免。", "Base skill damage rises from 200% to 400%; gain 4% damage reduction per 10% HP missing."], "sunquan":["每次最大生命提高400并额外提高等同于已损失生命10%的上限，最多达到初始最大生命4倍；随后恢复15%已损失生命。", "Each cast grants 400 plus 10% missing HP as max HP up to 4x initial max HP, then restores 15% missing HP."], "sunshangxiang":["冷却缩短至6秒；每次连射2击，每击150%兵略值；释放后兵略值提高2点。", "Cooldown becomes 6s; fire twice at 150% Strategy each and gain 2 Strategy after casting."]}],
		[["daqiao", "xiaoqiao"], "江东双姝", "Jiangdong Sisters", {"daqiao":["治疗量提高50%，并追加1次65%效果的治疗。", "Healing +50% and add one heal at 65% effect."], "xiaoqiao":["天香缓阵的行动条减速由35%提高至60%。", "Gentle Breeze's gauge slow rises from 35% to 60%."]}],
		[["lvmeng", "ganning"], "白衣奇袭", "White-Robed Ambush", {"lvmeng":["每次进入隐身后，下一次造成的伤害提高60%。", "After entering stealth, the next damage dealt gains +60%."], "ganning":["攻击生命值低于50%的敌人时，本次伤害提高50%。", "Deal 50% more damage when the target is below 50% HP."]}],
		[["sunce", "taishici"], "神亭酣战", "Shenting Duel", {"sunce":["追加第二段攻击正前方和右侧敌军；正前方会连续承受两次伤害。", "Add a second strike against the facing and right enemies; the facing enemy is hit twice."], "taishici":["技能目标数由行动条最高的2人提高至3人。", "Target the 3 highest-gauge enemies instead of 2."]}],
		[["sunce", "daqiao"], "江东佳偶", "Jiangdong Couple", {"sunce":["每次释放主动技能后恢复12%最大生命。", "Heal 12% max HP after each active."], "daqiao":["受治疗友军每损失10%生命，本次受到的治疗提高4%。", "The healed ally gains +4% healing received per 10% HP missing."]}],
		[["zhouyu", "xiaoqiao"], "琴瑟和鸣", "Harmonious Zither", {"zhouyu":["赤壁点火的灼烧持续时间由3秒延长至6秒。", "Red Cliffs burn duration rises from 3s to 6s."], "xiaoqiao":["天香缓阵的目标数由2名提高至3名，持续时间由6秒延长至8秒。", "Gentle Breeze rises from 2 to 3 targets and from 6s to 8s."]}],
		[["zhouyu", "huanggai"], "赤壁苦计", "Red Cliffs Ruse", {"zhouyu":["直接伤害与每次灼烧伤害按目标已损失生命提高，每损失10%生命增伤5%。", "Direct and burn damage gain +5% per 10% target HP missing."], "huanggai":["整列命中格灼烧6秒，每秒造成等同于本次实际消耗生命5%的伤害；空格灼烧会伤害主公。", "Burn struck column tiles for 6s at 5% of HP spent per second; burning empty tiles damages the ruler."]}],
		[["huanggai", "sunjian"], "江东柱石", "Pillars of Jiangdong", {"huanggai":["最大生命消耗由10%提高至15%，整列伤害由实际消耗生命33%提高至45%。", "Max-HP cost rises from 10% to 15%; column damage rises from 33% to 45% of HP spent."], "sunjian":["开局行动条充满；伤害由实际消耗生命100%提高至150%。", "Start with a full gauge; damage rises from 100% to 150% of HP spent."]}],
		[["taishici", "ganning"], "江表双锋", "Twin Blades of Jiangbiao", {"taishici":["目标已处于灼烧状态时，本次直接伤害由150%提高至300%兵略值。", "Direct damage rises from 150% to 300% Strategy against burning targets."], "ganning":["自身与左侧友军的本次协击倍率由150%提高至250%兵略值。", "Both Gan Ning and his left ally rise from 150% to 250% Strategy for the assist."]}],
		[["luxun", "sunquan"], "君臣同心", "Sovereign and Minister", {"luxun":["火球伤害提高50%，命中灼烧目标时再提高50%，合计提高100%。", "Fireball gains +50% damage and another +50% against burning targets, for +100% total."], "sunquan":["技能伤害由目标当前生命8%提高至12%，冷却由10秒缩短至8秒。", "Skill damage rises from 8% to 12% of target current HP and cooldown drops from 10s to 8s."]}],
		[["dingfeng", "xusheng"], "江表虎臣", "Tiger Ministers", {"dingfeng":["雪中奋短兵追加攻击目标左右相邻格，造成70%兵略值伤害并压退15%行动条。", "Snowbound Blades also hits horizontal neighbors for 70% Strategy and pushes their gauges back 15%."], "xusheng":["宿卫水阵的控制持续时间提高50%。", "Guardian Water Formation's control duration increases by 50%."]}],
		[["yanliang", "wenchou", "qunzhanghe", "gaolan"], "河北四庭柱", "Hebei Pillars", {"yanliang":["技能间隔内每次实际受伤使下次技能伤害提高15%，最高提高300%，释放后清空。", "Each actual hit between casts grants +15% next-cast damage up to +300%, cleared after casting."], "wenchou":["技能间隔内每次实际受伤使下次技能伤害提高15%，最高提高300%，释放后清空。", "Each actual hit between casts grants +15% next-cast damage up to +300%, cleared after casting."], "qunzhanghe":["技能目标再增加2名，护盾由200%提高至400%兵略值。", "Gain 2 more targets and raise shields from 200% to 400% Strategy."], "gaolan":["光环改为同排和同列全部友军兵略值增加40点。", "The aura grants +40 Strategy to all allies in Gao Lan's row and column."]}],
		[["huatuo", "yuji"], "医道同源", "Medicine and Immortality", {"huatuo":["青囊三济会清除被治疗者身上的全部减益。", "Threefold Remedy cleanses every debuff from each healed ally."], "yuji":["蛊毒仙术增加1个目标，中毒持续时间由4秒延长至5秒。", "Venomous Immortal Art gains 1 target and lasts 5s instead of 4s."]}],
		[["huatuo", "zuoci"], "济世仙缘", "Immortal Healers", {"huatuo":["青囊三济的治疗倍率由100%提高至150%兵略值。", "Threefold Remedy healing rises from 100% to 150% Strategy."], "zuoci":["遁甲济世的治疗倍率由150%提高至200%兵略值。", "Immortal Aid healing rises from 150% to 200% Strategy."]}],
		[["yuji", "zuoci"], "方仙同门", "Immortal Lineage", {"yuji":["蛊毒仙术增加1个目标，中毒持续时间增加1秒。", "Venomous Immortal Art gains 1 target and +1s duration."], "zuoci":["治疗时同时随机雷击两名敌军，各造成150%兵略值伤害。", "Each heal also strikes 2 random enemies for 150% Strategy lightning damage."]}],
		[["zhangjiao", "zhangliang"], "天人同道", "Heaven and Man", {"zhangjiao":["黄天雷引的伤害倍率由200%提高至250%兵略值。", "Yellow Sky Thunder rises from 200% to 250% Strategy."], "zhangliang":["人公虚弱增加1个目标。", "Yellow Sky Weakening gains 1 target."]}],
		[["zhangjiao", "zhangbao"], "天地雷契", "Heaven and Earth", {"zhangjiao":["黄天雷引增加1个目标，每名受击者有50%概率眩晕1秒。", "Yellow Sky Thunder gains 1 target; each victim has a 50% chance to be stunned for 1s."], "zhangbao":["地公雷爆会波及每个主目标周围上下、左右与斜对角相邻的武将，造成50%兵略值伤害。", "Earth General Detonation splashes all eight neighboring units around each primary target for 50% Strategy."]}],
		[["zhangliang", "zhangbao"], "地人续命", "Earth and Man", {"zhangliang":["人公虚弱增加1个目标。", "Yellow Sky Weakening gains 1 target."], "zhangbao":["本场战斗额外复生一次，总共可复生两次。", "Gain one additional revival, for two revivals per battle."]}]
	]
	for definition in combo_defs:
		var members: Array = definition[0]
		if members.has(hero_id):
			var effects: Dictionary = definition[3]
			var effect: Array = effects[hero_id]
			entries.append(_bond_entry(definition[1], definition[2], members, effect[0], effect[1]))
	entries.append(t("阵营羁绊\n", "Faction Bond\n") + _faction_name(faction) + t("：2/5/8 · ", ": 2/5/8 · ") + t(faction_effects[0], faction_effects[1]))
	return "\n\n".join(entries)

func _bond_detail(faction: String) -> String:
	match faction:
		"shu": return t("蜀：2/5/8人时承伤降低2%/5%/8%；8人时受击额外叠加2%减伤，最多3层，释放技能后清空。", "Shu: at 2/5/8, take 2%/5%/8% less damage; at 8, hits stack another 2% up to 3 times, cleared on cast.")
		"wei": return t("魏：2/5/8人时控制时长提高3%/8%/15%；8人时对受控或带减益目标伤害提高15%。", "Wei: at 2/5/8, control duration gains 3%/8%/15%; at 8, deal 15% more damage to controlled or debuffed targets.")
		"wu": return t("吴：2/5/8人时最大生命提高2%/5%/8%；8人时首次濒死触发生命均摊并恢复10%最大生命。", "Wu: at 2/5/8, gain 2%/5%/8% max HP; at 8, the first lethal hit equalizes health and restores 10% max HP.")
		"qun": return t("群：2/5/8人时冷却缩短3%/8%/15%；8人时释放技能有20%概率连续释放两次。", "Qun: at 2/5/8, cooldown is reduced by 3%/8%/15%; at 8, casts have a 20% repeat chance.")
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
	if is_instance_valid(battle_info_tabs):
		battle_info_tabs.set_tab_title(0, t("羁绊组成", "BONDS"))
		battle_info_tabs.set_tab_title(1, t("实时战报", "BATTLE LOG"))
		battle_info_tabs.set_tab_title(2, t("统计图表", "STATISTICS"))
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
	if is_instance_valid(unit_inspector_overlay) and unit_inspector_overlay.visible:
		_refresh_unit_inspector()
	enemy_title_label.text = t("敌方阵地  ·  后排在上 / 前排在下", "ENEMY FORMATION  ·  BACK TO FRONT")
	player_title_label.text = t("我方阵地  ·  前排在上 / 后排在下", "YOUR FORMATION  ·  FRONT TO BACK")
	if phase == "draft": draft_title_label.text = t("三选一 · 第%d/3轮" % (PICKS_PER_ROUND - draft_picks_remaining + 1), "PICK 1 OF 3 · ROUND %d/3" % (PICKS_PER_ROUND - draft_picks_remaining + 1))
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
	if phase == "draft": hint_label.text = t("选将时仍可拖拽调整阵型、从备战席上阵或将场上武将拖回备战席；点击场上武将可查看实时状态。", "During recruitment you may still drag to rearrange, deploy from reserve, return units to reserve, or tap a unit to inspect it.")
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
			var status_icons := _unit_status_icon_row(unit)
			status_icons.set_anchors_preset(Control.PRESET_TOP_WIDE)
			status_icons.offset_left = 7
			status_icons.offset_right = -7
			status_icons.offset_top = 24
			status_icons.offset_bottom = 43
			card_layer.add_child(status_icons)
			var name_label := _outlined_label(_hero_name(unit.hero_id), 22, faction_color.lightened(0.34))
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
		if is_player and phase in ["draft", "placement"] and not battle_running:
			if unit != null and phase == "draft":
				cell.pressed.connect(_toggle_unit_inspector.bind(str(unit.id)))
			else:
				cell.pressed.connect(_on_player_cell.bind(row, col))
			if unit != null: cell.set_drag_forwarding(_drag_unit.bind(unit.id, cell), _can_drop_board.bind(row, col), _drop_board.bind(row, col))
			else: cell.set_drag_forwarding(_drag_empty, _can_drop_board.bind(row, col), _drop_board.bind(row, col))
		elif unit != null and phase in ["draft", "combat"]:
			cell.disabled = false
			cell.pressed.connect(_toggle_unit_inspector.bind(str(unit.id)))
		else:
			cell.disabled = true
		board.add_child(cell)

func _unit_status_icon_row(unit: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 2)
	var entries: Array = []
	if float(unit.get("burn", 0.0)) > 0.0: entries.append(["fire.png", t("灼烧", "Burn")])
	if float(unit.get("poison", 0.0)) > 0.0: entries.append(["poisoning.png", t("中毒", "Poison")])
	if float(unit.get("skill_debuff_time", 0.0)) > 0.0: entries.append(["weak.png", t("虚弱", "Weak")])
	if float(unit.get("stun", 0.0)) > 0.0 or float(unit.get("freeze", 0.0)) > 0.0: entries.append(["dizzy.png", t("眩晕/冻结", "Stun/Freeze")])
	if float(unit.get("slow_time", 0.0)) > 0.0: entries.append(["slow.png", t("减速", "Slow")])
	if float(unit.get("damage_buff", 0.0)) > 0.0 or float(unit.get("timed_damage_buff", 0.0)) > 0.0 or float(unit.get("kill_buff", 0.0)) > 0.0 or float(unit.get("vulnerable", 0.0)) > 0.0: entries.append(["boost.png", t("增伤/易伤", "Damage boost/Vulnerable")])
	if float(unit.get("timed_action_bonus", 0.0)) > 0.0: entries.append(["speed.png", t("加速", "Haste")])
	for entry in entries.slice(0, 7):
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = load("res://ThreeKingdom/animations/" + str(entry[0]))
		icon.tooltip_text = str(entry[1])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(18, 18)
		row.add_child(icon)
	return row

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
	var mobile := _is_mobile_ui()
	for choice_index in choices.size():
		var id: String = str(choices[choice_index])
		var hero: Dictionary = heroes[id]
		var option := VBoxContainer.new()
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.size_flags_vertical = Control.SIZE_EXPAND_FILL
		option.custom_minimum_size = Vector2(245 if mobile else 360, 430 if mobile else 540)
		option.add_theme_constant_override("separation", 10)
		var rank_label := _label(t(["前军候选", "中军候选", "后军候选"][choice_index], ["VANGUARD", "MIDGUARD", "REARGUARD"][choice_index]), 18, Color("#f0c77a"))
		rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		option.add_child(rank_label)
		var card := Button.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(245 if mobile else 360, 360 if mobile else 475)
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
		var faction := _outlined_label("【" + _faction_name(hero.f) + "】", 11, Color("#eee5d5"))
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
		var hero_label := _label(side + " · " + _hero_name(row.hero_id), 11, Color("#90c59e") if row.team == "player" else Color("#d89a8f"))
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
			slot.text = _hero_name(unit.hero_id) + "\nHP " + str(round(unit.hp))
			slot.tooltip_text = t("拖拽到战场上阵；场上武将拖回此处可下阵；右键备战武将可出售", "Drag to deploy; drag a field unit here to return it; right-click a reserve unit to sell")
			slot.modulate = Color("#f0c77a") if selected_unit == unit.id else Color.WHITE
			slot.pressed.connect(_on_reserve_pressed.bind(unit.id))
			slot.gui_input.connect(_on_reserve_input.bind(unit.id))
			slot.set_drag_forwarding(_drag_unit.bind(unit.id, slot), _can_drop_reserve.bind(index), _drop_reserve.bind(index))
		else:
			slot.text = "+"
			slot.set_drag_forwarding(_drag_empty, _can_drop_reserve.bind(index), _drop_reserve.bind(index))
		reserve_box.add_child(slot)

func _on_reserve_pressed(unit_id: String) -> void:
	if phase not in ["draft", "placement"] or battle_running: return
	selected_unit = unit_id
	_render()

func _drag_empty(_at_position: Vector2):
	return null

func _drag_unit(_at_position: Vector2, unit_id: String, origin: Control):
	if phase not in ["draft", "placement"] or battle_running: return null
	var unit = _find_by_id(player_units, unit_id)
	if unit == null or not unit.alive: return null
	var preview := _outlined_label(_hero_name(unit.hero_id), 16, FACTION_COLORS[heroes[unit.hero_id].f].lightened(0.3))
	preview.custom_minimum_size = Vector2(150, 48)
	preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if origin.get_viewport().gui_is_dragging(): origin.set_drag_preview(preview)
	else: preview.queue_free()
	return {"unit_id":unit_id}

func _can_drop_board(_at_position: Vector2, data, _row: int, _col: int) -> bool:
	if phase not in ["draft", "placement"] or not (data is Dictionary) or not data.has("unit_id"): return false
	var source = _find_by_id(player_units, str(data.unit_id))
	if source == null or not _can_unit_use_row(source, _row): return false
	var occupant = _unit_at(player_units, _row, _col)
	if occupant == null or occupant.id == source.id: return true
	if int(source.row) < 0: return false
	return _can_unit_use_row(occupant, int(source.row))

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
	if phase not in ["draft", "placement"] or not (data is Dictionary) or not data.has("unit_id"): return false
	var source = _find_by_id(player_units, str(data.unit_id))
	if source == null: return false
	return int(source.row) < 0 or _reserve_units().size() < RESERVE_LIMIT

func _drop_reserve(_at_position: Vector2, data, index: int) -> void:
	if not _can_drop_reserve(_at_position, data, index): return
	var source: Dictionary = _find_by_id(player_units, str(data.unit_id))
	if int(source.row) >= 0:
		source.row = -1
		source.col = -1
		selected_unit = ""
		_log(_hero_name(source.hero_id) + t(" 已从战场下阵到备战席。", " returned from the battlefield to reserve."))
		_render()
		return
	var reserves := _reserve_units()
	var target = reserves[index] if index < reserves.size() else null
	if target != null and target.id != source.id:
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
	if unit == null: return
	player_units.erase(unit)
	pending_unit_ids.erase(unit_id)
	_log(_hero_name(unit.hero_id) + t(" 已出售。", " was sold."))
	_render()

func _bond_progress_tiers(bond_id: String, member_count: int) -> Array[int]:
	match bond_id:
		"five_elites":
			return [5]
		"hebei_pillars":
			return [4]
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
		if alive_hero_ids.has(hero_id):
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
			"name":_faction_name(faction),
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
	var hero_active: Array[String] = []
	var hero_pending: Array[String] = []
	var faction_active: Array[String] = []
	var faction_pending: Array[String] = []
	for entry in entries:
		var destination: Array[String]
		if bool(entry.get("is_faction", false)):
			destination = faction_active if bool(entry.active) else faction_pending
		else:
			destination = hero_active if bool(entry.active) else hero_pending
		destination.append(_bond_progress_line(entry))
	var sections: Array[String] = []
	sections.append(t("[color=#d4a85d][b]武将羁绊[/b][/color]", "[color=#d4a85d][b]HERO BONDS[/b][/color]"))
	if not hero_active.is_empty(): sections.append(t("[b]已激活[/b]", "[b]ACTIVE[/b]") + "\n" + "\n".join(hero_active))
	if not hero_pending.is_empty(): sections.append(t("[color=#666a70][b]待激活[/b][/color]", "[color=#666a70][b]PENDING[/b][/color]") + "\n" + "\n".join(hero_pending))
	if hero_active.is_empty() and hero_pending.is_empty(): sections.append(t("[color=#686c70]暂无[/color]", "[color=#686c70]None[/color]"))
	sections.append(t("[color=#8fc7a0][b]阵营羁绊（2/5/8）[/b][/color]", "[color=#8fc7a0][b]FACTION BONDS (2/5/8)[/b][/color]"))
	if not faction_active.is_empty(): sections.append("\n".join(faction_active))
	if not faction_pending.is_empty(): sections.append("\n".join(faction_pending))
	return "\n\n".join(sections)

func _refresh_bond_progress(units: Array) -> void:
	if is_instance_valid(bonds_label):
		bonds_label.text = _bond_text(units)

func _roster_text(units: Array) -> String:
	if units.is_empty(): return t("暂无武将", "No generals yet")
	var entries: Array[String] = []
	for unit in units:
		entries.append(("† " if not unit.alive else "") + _hero_name(unit.hero_id) + " · " + _faction_name(heroes[unit.hero_id].f))
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
	if is_instance_valid(unit_inspector_overlay) and unit_inspector_overlay.visible:
		_refresh_unit_inspector()

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
	if unit.has("burn") and unit.burn > 0:
		var burn_count := (unit.get("burn_effects", []) as Array).size()
		statuses.append(t("灼烧", "Burn") + ("×" + str(burn_count) if burn_count > 1 else ""))
	if float(unit.get("fear", 0.0)) > 0.0: statuses.append(t("恐惧", "Fear"))
	if float(unit.get("freeze", 0.0)) > 0.0: statuses.append(t("冻结", "Frozen"))
	if float(unit.get("poison", 0.0)) > 0.0:
		var poison_count := (unit.get("poison_effects", []) as Array).size()
		statuses.append(t("中毒", "Poison") + ("×" + str(poison_count) if poison_count > 1 else ""))
	if float(unit.get("skill_debuff_time", 0.0)) > 0.0: statuses.append(t("虚弱", "Weakened"))
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
