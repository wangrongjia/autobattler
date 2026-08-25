extends "res://ThreeKingdom/systems/combat_system.gd"

const PremiumUIArt = preload("res://ThreeKingdom/ui/premium_ui_art.gd")

var _encyclopedia_touch_origins := {}
const CARD_BORDER_ROOT := "res://ThreeKingdom/animations/border/"
const UI_GOLD := Color("#b98a4f")
const UI_GOLD_LIGHT := Color("#f0c77a")
const UI_INK := Color("#090a09")
const UI_LACQUER := Color("#171411")
const UI_JADE := Color("#315d4d")
const PEACE_BGM_PATH := "res://ThreeKingdom/audio/bgm/peace.mp3" # 非战斗 BGM《雾中灯影》(Pixabay: kaazoom，截取 0:25-3:50)
const BATTLE_BGM_PATH := "res://ThreeKingdom/audio/bgm/battle.mp3" # 战斗 BGM《战斗行动循环》(Pixabay: Sonican，截取 0:00-1:55)
const BGM_VOLUME_DB := -7.0      # BGM 常规音量(低于技能台词，不抢戏)
const BGM_FADE_FLOOR_DB := -60.0 # 淡变两端的静音音量
const BGM_FADE_TIME := 1.0       # 战斗/非战斗 BGM 交叉淡变时长(秒)
const SFX_ROOT := "res://ThreeKingdom/audio/sfx/" # 战斗/界面音效目录(Kenney CC0)
const SFX_SETS := {
	"melee": ["melee_1.ogg", "melee_2.ogg"], # 挥击/斩击(普攻起手，投射物共用并加大音调抖动)
	"heavy": ["heavy_1.ogg"],                # 技能重击起手
	"hit": ["hit_1.ogg", "hit_2.ogg", "hit_3.ogg", "hit_4.ogg", "hit_5.ogg", "hit_6.ogg"], # 受击命中(随机)
	"death": ["death_1.ogg", "death_2.ogg", "death_3.ogg"], # 阵亡倒地闷响
	"coin": ["coin_1.ogg", "coin_2.ogg"],    # 获得金币(回合结算/出售)
	"tianshu": ["tianshu_pick.ogg"],         # 选定天书落卷
	"tianshu_open": ["tianshu_open.ogg"],    # 翻开天书阁
	"bell": ["bell.ogg"],                    # 战斗结算钟鸣
	"error": ["error.ogg"],                  # 操作无效提示
	"deploy": ["deploy.ogg"],                # 武将上阵拔刀
}
const SFX_POOL_SIZE := 10 # 同时可叠放的音效声道数

var home_portrait: TextureRect
var home_hero_name_label: Label
var home_resource_label: Label
var home_faction_label: Label
var home_motto_label: Label
var intro_popup: Control
var tianshu_refresh_setting_button: Button
var battle_menu_overlay: Control
var challenge_stage_grid: GridContainer
var challenge_stage_scroll: ScrollContainer
var challenge_detail_scroll: ScrollContainer
var challenge_difficulty_options: OptionButton
var challenge_stage_title: Label
var challenge_difficulty_buttons: Array[Button] = []
var challenge_detail_stage_label: Label
var challenge_detail_bonus_label: Label
var challenge_detail_star_label: Label
var challenge_start_button: Button
var challenge_restart_button: Button
var rune_overlay: Control
var rune_inventory_box: Container
var rune_inventory_scroll: ScrollContainer
var rune_resource_label: Label
var rune_hero_options: OptionButton
var rune_status_label: Label
var talent_overlay: Control
var talent_content_box: Control
var talent_resource_label: Label
var talent_tree_id := "all"
var talent_detail_label: Label
var talent_tree_canvas: Control
var talent_tree_tabs := {}
var rune_faction_options: OptionButton
var rune_tier_filter := 0
var rune_filter_buttons: Array[Button] = []
var rune_class_filter := ""
var rune_class_filter_buttons: Array[Button] = []
var rune_hero_portrait: TextureRect
var rune_batch_synthesize_button: Button
var rune_equipped_box: VBoxContainer
var rune_hero_detail_overlay: Control
var rune_hero_detail_text: RichTextLabel
var rune_hero_detail_columns: HBoxContainer
var challenge_limit_setting_button: Button
var result_overlay: Control
var result_title_label: Label
var result_detail_label: Label
var tianshu_overlay: Control
var tianshu_choice_box: HBoxContainer
var tianshu_owned_box: VBoxContainer
var tianshu_overlay_title: Label
var tianshu_overlay_close: Button
var tianshu_header_button: Button
var tianshu_gold_label: Label
var tianshu_purchase_button: Button
var tianshu_replace_confirm: ConfirmationDialog
var tianshu_replace_pending := ""
var tianshu_view_only := false
var sell_layer: CanvasLayer
var sell_zone: Control
var sell_zone_label: Label
var sell_drag_unit_id := ""
var sell_zone_grace_frames := 0

func _is_mobile_ui() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.get_environment("THREE_KINGDOM_MOBILE_UI_TEST") == "1"

func _enable_touch_scroll(scroll: ScrollContainer, horizontal := false, vertical := true) -> void:
	scroll.scroll_deadzone = 6
	if _is_mobile_ui(): scroll.set_meta("touch_scroll_enabled", true)
	scroll.gui_input.connect(_on_touch_scroll_input.bind(scroll, horizontal, vertical))

func _on_touch_scroll_input(event: InputEvent, scroll: ScrollContainer, horizontal: bool, vertical: bool) -> void:
	if event is InputEventScreenDrag:
		if horizontal: scroll.scroll_horizontal -= roundi(event.relative.x)
		if vertical: scroll.scroll_vertical -= roundi(event.relative.y)
		scroll.accept_event()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
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
	box.content_margin_left = 13
	box.content_margin_right = 13
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	box.shadow_color = Color(0, 0, 0, 0.48)
	box.shadow_size = 7
	box.shadow_offset = Vector2(0, 3)
	control.add_theme_stylebox_override("panel", box)

func _button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 42)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color("#ead9b5"))
	button.add_theme_color_override("font_hover_color", Color("#fff0c9"))
	button.add_theme_color_override("font_pressed_color", Color("#fff4cf"))
	button.add_theme_color_override("font_disabled_color", Color("#746b60"))
	button.add_theme_color_override("font_focus_color", Color("#fff0c9"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#171716")
	normal.border_color = Color("#755b38")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 15
	normal.content_margin_right = 15
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	normal.shadow_color = Color(0, 0, 0, 0.42)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 2)
	var hover := normal.duplicate()
	hover.bg_color = Color("#2b241a")
	hover.border_color = Color("#d4a85f")
	hover.set_border_width_all(2)
	var pressed := normal.duplicate()
	pressed.bg_color = Color("#3a2b18")
	pressed.border_color = Color("#f0c77a")
	pressed.set_border_width_all(2)
	var disabled := normal.duplicate()
	disabled.bg_color = Color("#111211")
	disabled.border_color = Color("#38342e")
	var focus := hover.duplicate()
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", focus)
	return button

func _accent_button(button: Button, accent: Color, filled := false) -> void:
	var normal: StyleBoxFlat = button.get_theme_stylebox("normal").duplicate()
	normal.border_color = accent.darkened(0.15)
	normal.bg_color = accent.darkened(0.66) if filled else Color("#171716")
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = accent.darkened(0.48)
	hover.border_color = accent.lightened(0.25)
	hover.set_border_width_all(2)
	button.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = hover.duplicate()
	pressed.bg_color = accent.darkened(0.35)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", accent.lightened(0.45))
	button.add_theme_color_override("font_hover_color", Color("#fff3d1"))

func _add_premium_art(parent: Control, variant: int, accent := UI_GOLD) -> Control:
	var art := PremiumUIArt.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.configure(variant, accent)
	parent.add_child(art)
	parent.move_child(art, 0)
	return art

func _section_title(value: String, subtitle := "") -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -1)
	var title := _label(value, 27, UI_GOLD_LIGHT)
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_outline_color", Color("#1b1007"))
	box.add_child(title)
	if not subtitle.is_empty():
		var hint := _label(subtitle, 11, Color("#9e8769"))
		hint.add_theme_constant_override("letter_spacing", 2)
		box.add_child(hint)
	return box

func _label(value: String, size := 16, color := Color("#e8e2cf")) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _build_ui() -> void:
	skill_voice_player = AudioStreamPlayer.new()
	skill_voice_player.name = "SkillVoicePlayer"
	skill_voice_player.volume_db = -1.5
	add_child(skill_voice_player)
	peace_bgm_player = AudioStreamPlayer.new()
	peace_bgm_player.name = "PeaceBgmPlayer"
	peace_bgm_player.volume_db = BGM_VOLUME_DB
	var peace_stream: AudioStreamMP3 = load(PEACE_BGM_PATH)
	if peace_stream != null:
		peace_stream.loop = true
		peace_bgm_player.stream = peace_stream
	add_child(peace_bgm_player)
	battle_bgm_player = AudioStreamPlayer.new()
	battle_bgm_player.name = "BattleBgmPlayer"
	battle_bgm_player.volume_db = BGM_VOLUME_DB
	var battle_stream: AudioStreamMP3 = load(BATTLE_BGM_PATH)
	if battle_stream != null:
		battle_stream.loop = true
		battle_bgm_player.stream = battle_stream
	add_child(battle_bgm_player)
	for index in range(SFX_POOL_SIZE):
		var sfx_player := AudioStreamPlayer.new()
		sfx_player.name = "SfxPlayer%d" % index
		add_child(sfx_player)
		sfx_players.append(sfx_player)
	for category in SFX_SETS:
		var streams: Array = []
		for file_name in SFX_SETS[category]:
			var path := SFX_ROOT + str(file_name)
			if ResourceLoader.exists(path):
				var stream: AudioStream = load(path)
				if stream != null: streams.append(stream)
		if not streams.is_empty(): sfx_streams[category] = streams
	_update_bgm()
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
	_add_premium_art(self, PremiumUIArt.Variant.COMBAT, Color("#85663e"))
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
	var eyebrow := _label("THREE KINGDOMS · TACTICAL AUTOBATTLER", 10, Color("#ad8355"))
	eyebrow.add_theme_constant_override("outline_size", 1)
	brand.add_child(eyebrow)
	title_label = _label("", 27, Color("#f0c77a"))
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.add_theme_color_override("font_outline_color", Color("#1a1008"))
	brand.add_child(title_label)
	header.add_child(brand)
	var round_panel := PanelContainer.new()
	_style(round_panel, Color("#13120ff0"), 5, Color("#80613b"), 1)
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
	_accent_button(speed_button, Color("#9a793f"))
	speed_button.custom_minimum_size = Vector2(72, 40)
	speed_button.pressed.connect(_cycle_speed)
	header.add_child(speed_button)
	menu_button = _button("")
	_accent_button(menu_button, Color("#866b45"))
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
	_style(arena, Color("#11110fee"), 5, Color("#725638"), 2)
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
	_style(lane, Color("#21170e"), 3, Color("#a77a3d"), 1)
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
	_style(command, Color("#10110fee"), 5, Color("#725638"), 2)
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
	_style(reserve_panel, Color("#10110fee"), 5, Color("#725638"), 2)
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
	tianshu_header_button = _button(t("天书阁", "CODEX"))
	_accent_button(tianshu_header_button, Color("#9e68bd"))
	tianshu_header_button.custom_minimum_size = Vector2(200, 96)
	tianshu_header_button.add_theme_font_size_override("font_size", 16)
	tianshu_header_button.pressed.connect(_show_tianshu_collection)
	tianshu_header_button.hide()
	reserve_row.add_child(tianshu_header_button)
	root.add_child(reserve_panel)
	tick_timer = Timer.new()
	tick_timer.wait_time = TICK
	tick_timer.timeout.connect(_battle_tick)
	add_child(tick_timer)
	_build_draft_layer()
	_build_sell_zone()
	_build_tianshu_overlay()
	_build_unit_inspector()

func _process(_delta: float) -> void:
	if not is_instance_valid(sell_zone) or not sell_zone.visible:
		return
	if sell_zone_grace_frames > 0:
		sell_zone_grace_frames -= 1
		return
	if not get_viewport().gui_is_dragging():
		_hide_sell_zone()

func _build_sell_zone() -> void:
	sell_layer = CanvasLayer.new()
	sell_layer.layer = 50
	add_child(sell_layer)
	sell_zone = Control.new()
	sell_zone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sell_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sell_layer.add_child(sell_zone)
	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.offset_bottom = 105
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sell_zone.add_child(center)
	var target := PanelContainer.new()
	target.custom_minimum_size = Vector2(360, 76)
	target.mouse_filter = Control.MOUSE_FILTER_STOP
	_style(target, Color("#33170fed"), 6, Color("#d59a45"), 3)
	center.add_child(target)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 1)
	var title := _label("金　售卖武将", 18, Color("#f0c77a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	sell_zone_label = _label("", 16, Color("#f4d69b"))
	sell_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sell_zone_label)
	target.add_child(box)
	target.set_drag_forwarding(_drag_empty, _can_drop_sell, _drop_sell)
	sell_zone.hide()

func _show_sell_zone(unit_id: String) -> void:
	var unit = _find_by_id(player_units, unit_id)
	if unit == null:
		return
	sell_drag_unit_id = unit_id
	sell_zone_label.text = "%s　+%d 金币" % [_hero_name(str(unit.hero_id)), _unit_sell_price(unit)]
	sell_zone_grace_frames = 2
	sell_zone.show()

func _hide_sell_zone() -> void:
	sell_drag_unit_id = ""
	if is_instance_valid(sell_zone):
		sell_zone.hide()

func _can_drop_sell(_at_position: Vector2, data) -> bool:
	if phase not in ["draft", "placement"] or battle_running or not (data is Dictionary) or not data.has("unit_id"):
		return false
	var unit = _find_by_id(player_units, str(data.unit_id))
	return unit != null and unit.alive

func _drop_sell(_at_position: Vector2, data) -> void:
	if not _can_drop_sell(_at_position, data):
		_hide_sell_zone()
		return
	var unit: Dictionary = _find_by_id(player_units, str(data.unit_id))
	var price := _unit_sell_price(unit)
	var hero_name := _hero_name(str(unit.hero_id))
	player_units.erase(unit)
	pending_unit_ids.erase(str(unit.id))
	selected_unit = ""
	_earn_gold(price, "出售 " + hero_name)
	_hide_sell_zone()
	_render()

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
	unit_inspector_scroll = ScrollContainer.new()
	unit_inspector_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unit_inspector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	unit_inspector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_enable_touch_scroll(unit_inspector_scroll, false, true)
	box.add_child(unit_inspector_scroll)
	unit_inspector_detail = RichTextLabel.new()
	unit_inspector_detail.bbcode_enabled = true
	unit_inspector_detail.fit_content = true
	unit_inspector_detail.scroll_active = false
	unit_inspector_detail.selection_enabled = not _is_mobile_ui()
	unit_inspector_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unit_inspector_detail.add_theme_font_size_override("normal_font_size", 17 if _is_mobile_ui() else 15)
	unit_inspector_detail.add_theme_constant_override("line_separation", 5)
	unit_inspector_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unit_inspector_scroll.add_child(unit_inspector_detail)
	unit_inspector_overlay.hide()

func _toggle_unit_inspector(unit_id: String) -> void:
	if unit_id == unit_inspector_unit_id and is_instance_valid(unit_inspector_overlay) and unit_inspector_overlay.visible:
		_hide_unit_inspector()
		return
	unit_inspector_unit_id = unit_id
	_refresh_unit_inspector()
	if is_instance_valid(unit_inspector_overlay):
		unit_inspector_overlay.show()

func _show_draft_hero_inspector(hero_id: String) -> void:
	if not heroes.has(hero_id): return
	unit_inspector_preview = _make_roster_unit("player", hero_id)
	unit_inspector_preview.id = "preview:" + hero_id
	unit_inspector_preview.row = maxi(0, int(heroes[hero_id].range) - 1)
	unit_inspector_preview.col = 1
	unit_inspector_restore_draft = phase == "draft" and is_instance_valid(draft_overlay) and draft_overlay.visible
	if unit_inspector_restore_draft: draft_overlay.hide()
	_toggle_unit_inspector(str(unit_inspector_preview.id))

func _hide_unit_inspector() -> void:
	unit_inspector_unit_id = ""
	unit_inspector_preview = {}
	if is_instance_valid(unit_inspector_overlay):
		unit_inspector_overlay.hide()
	if unit_inspector_restore_draft and phase == "draft" and is_instance_valid(draft_overlay):
		draft_overlay.show()
	unit_inspector_restore_draft = false

func _inspector_number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else ("%.1f" % value)

func _inspector_unit() -> Variant:
	if not unit_inspector_preview.is_empty() and str(unit_inspector_preview.get("id", "")) == unit_inspector_unit_id:
		return unit_inspector_preview
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
	if float(unit.get("gaolan_skill_value_bonus", 0.0)) > 0.0:
		lines.append(t("高览·列阵扬威  兵略值 +", "Gao Lan · Column Valor  Strategy +") + _inspector_number(float(unit.gaolan_skill_value_bonus)))
	if float(unit.get("timed_skill_value_bonus", 0.0)) > 0.0:
		lines.append(t("临时兵略值 +", "Temporary Strategy +") + _inspector_number(float(unit.timed_skill_value_bonus)) + " · " + _inspector_number(float(unit.get("timed_skill_value_time", 0.0))) + "s")
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
			if effect.has("stacks"):
				lines.append(t("中毒", "Poison") + " #" + str(index + 1) + "  " + t("层数 ", "stacks ") + str(int(effect.get("stacks", 0))))
			else:
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
	_style(panel, Color("#100e0df2"), 5, Color("#b68a4f" if is_player else "#9c4c48"), 2)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 5)
	var seal_panel := PanelContainer.new()
	seal_panel.custom_minimum_size = Vector2(44, 44)
	_style(seal_panel, Color("#173325") if is_player else Color("#451b18"), 24, Color("#d5ad58") if is_player else Color("#bf5b51"), 2)
	var seal := _label("主" if is_player else "敌", 19, Color("#f0c77a" if is_player else "#e89b91"))
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal_panel.add_child(seal)
	box.add_child(seal_panel)
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
	draft_overlay.color = Color("#080907")
	draft_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	draft_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	draft_layer.add_child(draft_overlay)
	_add_premium_art(draft_overlay, PremiumUIArt.Variant.BACKDROP, Color("#8f6f42"))
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
	panel.custom_minimum_size = Vector2(900, 575) if mobile else Vector2(1240, 650)
	_style(panel, Color("#12110fee"), 5, Color("#8e673d"), 2)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var header := HBoxContainer.new()
	var title := _label(t("本轮招募", "RECRUITMENT"), 20, Color("#f0c77a"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := _button(t("暂时隐藏", "HIDE"))
	_accent_button(close, Color("#607b95"))
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

func _build_tianshu_overlay() -> void:
	tianshu_overlay = ColorRect.new()
	tianshu_overlay.color = Color("#090711")
	tianshu_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tianshu_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	tianshu_overlay.z_index = 1550
	add_child(tianshu_overlay)
	_add_premium_art(tianshu_overlay, PremiumUIArt.Variant.CODEX, Color("#a66bcd"))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 14)
	tianshu_overlay.add_child(margin)
	var panel := PanelContainer.new()
	_style(panel, Color("#121018e8"), 5, Color("#b078d2"), 2)
	margin.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)
	var header := HBoxContainer.new()
	tianshu_overlay_title = _label("", 31, Color("#f0c77a"))
	tianshu_overlay_title.add_theme_constant_override("outline_size", 5)
	tianshu_overlay_title.add_theme_color_override("font_outline_color", Color("#211029"))
	tianshu_overlay_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(tianshu_overlay_title)
	var subtitle := _label(t("所有天书均为彩色品质 · 同名再次选择升至2级", "All codices share one prismatic tier · choose again to reach level II"), 14, Color("#d8b9ee"))
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(subtitle)
	tianshu_gold_label = _label("", 17, Color("#e8c96e"))
	tianshu_gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(tianshu_gold_label)
	tianshu_purchase_button = _button("购买三选一 · 500")
	tianshu_purchase_button.custom_minimum_size = Vector2(180, 46)
	_accent_button(tianshu_purchase_button, Color("#b98a4f"), true)
	tianshu_purchase_button.pressed.connect(_on_buy_tianshu_draw)
	header.add_child(tianshu_purchase_button)
	tianshu_overlay_close = _button(t("关闭", "CLOSE"))
	_accent_button(tianshu_overlay_close, Color("#8b62a1"))
	tianshu_overlay_close.custom_minimum_size = Vector2(120, 46)
	tianshu_overlay_close.pressed.connect(func(): tianshu_overlay.hide())
	header.add_child(tianshu_overlay_close)
	root.add_child(header)
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	root.add_child(content)
	var choices_scroll := ScrollContainer.new()
	choices_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_enable_touch_scroll(choices_scroll, true, true)
	content.add_child(choices_scroll)
	tianshu_choice_box = HBoxContainer.new()
	tianshu_choice_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tianshu_choice_box.add_theme_constant_override("separation", 14)
	choices_scroll.add_child(tianshu_choice_box)
	var owned_panel := PanelContainer.new()
	owned_panel.custom_minimum_size.x = 380
	_style(owned_panel, Color("#111117ed"), 5, Color("#765585"), 2)
	var owned_root := VBoxContainer.new()
	owned_root.add_theme_constant_override("separation", 8)
	owned_panel.add_child(owned_root)
	owned_root.add_child(_label(t("卷　本局已获天书", "OWNED CODICES"), 20, Color("#e5a8ff")))
	var owned_scroll := ScrollContainer.new()
	owned_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_enable_touch_scroll(owned_scroll, false, true)
	owned_root.add_child(owned_scroll)
	tianshu_owned_box = VBoxContainer.new()
	tianshu_owned_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tianshu_owned_box.add_theme_constant_override("separation", 7)
	owned_scroll.add_child(tianshu_owned_box)
	content.add_child(owned_panel)
	tianshu_overlay.hide()
	tianshu_replace_confirm = ConfirmationDialog.new()
	tianshu_replace_confirm.title = t("确认替换", "Confirm Replace")
	tianshu_replace_confirm.ok_button_text = t("确认替换", "Replace")
	tianshu_replace_confirm.cancel_button_text = t("取消", "Cancel")
	tianshu_replace_confirm.confirmed.connect(func(): _on_replace_tianshu_confirmed())
	tianshu_replace_confirm.canceled.connect(func(): tianshu_replace_pending = "")
	add_child(tianshu_replace_confirm)

func _show_tianshu_collection() -> void:
	if not _can_use_tianshu_pavilion(): return
	tianshu_view_only = true
	_play_sfx("tianshu_open", -6.0, 200, 0.0)
	_render_tianshu_overlay()
	tianshu_overlay.show()

func _on_buy_tianshu_draw() -> void:
	tianshu_view_only = false
	_buy_tianshu_draw()

func _on_replace_tianshu(book_id: String) -> void:
	if not _can_use_tianshu_pavilion() or not tianshu_levels.has(book_id): return
	if not is_instance_valid(tianshu_replace_confirm):
		_on_replace_tianshu_confirmed(book_id)
		return
	tianshu_replace_pending = book_id
	var level := _tianshu_level(book_id)
	tianshu_replace_confirm.dialog_text = "确定替换【%s %s】吗？\n将获得 %d 次天书三选一。" % [_tianshu_name(book_id), "2级" if level == 2 else "1级", level]
	tianshu_replace_confirm.popup_centered()

func _on_replace_tianshu_confirmed(book_id: String = "") -> void:
	var target := book_id if not book_id.is_empty() else tianshu_replace_pending
	tianshu_replace_pending = ""
	if target.is_empty(): return
	tianshu_view_only = false
	_replace_tianshu(target)

func _render_tianshu_overlay() -> void:
	if not is_instance_valid(tianshu_overlay): return
	_clear_dynamic_children(tianshu_choice_box)
	_clear_dynamic_children(tianshu_owned_box)
	var selecting := phase == "tianshu" and not tianshu_view_only
	var reason_names := {"free":"免费天书", "purchase":"天书阁购买", "replace":"替换回赠"}
	var reason_text := str(reason_names.get(tianshu_draw_reason, "天书三选一"))
	tianshu_overlay_title.text = ("%s · 第 %d / 15 回合" % [reason_text, round_number]) if selecting else t("天书阁", "CODEX PAVILION")
	tianshu_overlay_close.visible = not selecting
	tianshu_purchase_button.visible = not selecting
	tianshu_purchase_button.disabled = gold < TIANSHU_DRAW_COST or not _can_use_tianshu_pavilion()
	tianshu_gold_label.text = "金　%d" % gold
	if selecting:
		for index in tianshu_choices.size():
			var book_id := str(tianshu_choices[index])
			var book: Dictionary = TIANSHU_BOOKS[book_id]
			var current := _tianshu_level(book_id)
			var target_level := mini(2, current + 1)
			var option := VBoxContainer.new()
			option.custom_minimum_size = Vector2(330 if _is_mobile_ui() else 420, 520)
			option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			option.size_flags_vertical = Control.SIZE_EXPAND_FILL
			option.add_theme_constant_override("separation", 10)
			var card_accent: Color = _tianshu_group_color(book)
			var scope := _label("◆　" + str(book.group) + "天书　◆", 16, card_accent)
			scope.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			option.add_child(scope)
			var card := Button.new()
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.size_flags_vertical = Control.SIZE_EXPAND_FILL
			card.custom_minimum_size.y = 390
			card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card.add_theme_font_size_override("font_size", 20)
			card.text = ("天　书\n\n✦  %s  ✦\n\n%s\n\n%s" % [_tianshu_name(book_id), "升级至2级" if current == 1 else "获得1级", _tianshu_effect_text(book_id, target_level)])
			card.tooltip_text = t("点击下方「获取」按钮选定此天书", "Use the ACQUIRE button below to take this codex")
			var style := StyleBoxFlat.new()
			style.bg_color = card_accent.darkened(0.72)
			style.border_color = card_accent
			style.set_border_width_all(4)
			style.set_corner_radius_all(6)
			style.content_margin_left = 26
			style.content_margin_right = 26
			style.content_margin_top = 22
			style.content_margin_bottom = 22
			style.shadow_color = Color(card_accent, 0.28)
			style.shadow_size = 12
			card.add_theme_stylebox_override("normal", style)
			var hover: StyleBoxFlat = style.duplicate()
			hover.bg_color = card_accent.darkened(0.56)
			hover.border_color = Color("#f4d06f")
			hover.shadow_color = Color(card_accent, 0.58)
			card.add_theme_stylebox_override("hover", hover)
			card.add_child(_tianshu_border_overlay(book))
			option.add_child(card)
			var acquire := _button(t("获取《%s》" % _tianshu_name(book_id), "ACQUIRE %s" % _tianshu_name(book_id)))
			acquire.custom_minimum_size = Vector2(0, 62)
			acquire.add_theme_font_size_override("font_size", 19)
			_accent_button(acquire, card_accent)
			acquire.pressed.connect(_choose_tianshu.bind(book_id))
			option.add_child(acquire)
			var can_refresh := tianshu_infinite_refresh or (index < tianshu_refresh_available.size() and tianshu_refresh_available[index])
			var refresh := _button(t("↻ 单独刷新此天书", "↻ REFRESH THIS CODEX") if can_refresh else t("✓ 本回合已刷新", "✓ REFRESH USED"))
			_accent_button(refresh, card_accent)
			refresh.disabled = not can_refresh
			refresh.custom_minimum_size.y = 56
			refresh.add_theme_font_size_override("font_size", 18)
			refresh.pressed.connect(_refresh_tianshu_choice.bind(index))
			option.add_child(refresh)
			tianshu_choice_box.add_child(option)
	else:
		var replace_remaining := maxi(0, 1 - tianshu_replacements_this_round)
		var intro := _label("天书阁\n\n500 金币购买一次天书三选一\n300 金币替换一本天书（本回合剩余 %d / 1 次）\n替换2级天书可连续选择两次\n\n当前利息上限：%d　下回合基础收入：%d" % [replace_remaining, _gold_interest_cap(), _round_base_gold_income()], 18, Color("#c9c0b1"))
		intro.custom_minimum_size = Vector2(600, 120)
		intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tianshu_choice_box.add_child(intro)
	var owned_ids: Array = tianshu_levels.keys()
	owned_ids.sort_custom(func(a, b):
		var group_a := str(TIANSHU_BOOKS[a].group)
		var group_b := str(TIANSHU_BOOKS[b].group)
		return group_a + str(TIANSHU_BOOKS[a].name) < group_b + str(TIANSHU_BOOKS[b].name)
	)
	if owned_ids.is_empty():
		tianshu_owned_box.add_child(_label(t("尚未选择天书", "No codex selected"), 16, Color("#82788a")))
	for book_id_variant in owned_ids:
		var book_id := str(book_id_variant)
		var level := _tianshu_level(book_id)
		var owned_accent := _tianshu_group_color(TIANSHU_BOOKS[book_id])
		var item_panel := PanelContainer.new()
		item_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_style(item_panel, Color("#17141bee"), 4, owned_accent, 1)
		var item_box := VBoxContainer.new()
		var item_box_inner := VBoxContainer.new()
		item_box_inner.add_theme_constant_override("separation", 4)
		var title_row := _label("【%s】%s　%s" % ["2级" if level == 2 else "1级", str(TIANSHU_BOOKS[book_id].group), _tianshu_name(book_id)], 18, owned_accent.lightened(0.3))
		title_row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item_box_inner.add_child(title_row)
		var effect_line := _label(_tianshu_effect_text(book_id, level), 15, Color("#c9c0b1"))
		effect_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effect_line.tooltip_text = _tianshu_effect_text(book_id, level)
		item_box_inner.add_child(effect_line)
		item_box.add_child(item_box_inner)
		var replace := _button(("替换2级 · %d 金（可得两次三选一）" if level == 2 else "替换1级 · %d 金") % _tianshu_replace_cost())
		replace.custom_minimum_size.y = 40
		replace.add_theme_font_size_override("font_size", 15)
		_accent_button(replace, owned_accent.darkened(0.18))
		replace.disabled = not _can_use_tianshu_pavilion() or tianshu_replacements_this_round >= 1 or gold < _tianshu_replace_cost()
		replace.pressed.connect(_on_replace_tianshu.bind(book_id))
		item_box.add_child(replace)
		item_panel.add_child(item_box)
		tianshu_owned_box.add_child(item_panel)
	if not tianshu_pool_effect.is_empty() and round_number <= int(tianshu_pool_effect.get("end_round", 0)):
		var remaining := int(tianshu_pool_effect.get("remaining_picks", 0))
		tianshu_owned_box.add_child(_label(t("当前武将池限制剩余 %d 次选将" % remaining, "Pool restriction: %d picks left" % remaining), 14, Color("#f0c77a")))

func _set_stats_metric(metric: String) -> void:
	stats_metric = metric
	_render_battle_stats()

func _build_main_menu() -> void:
	var mobile := _is_mobile_ui()
	menu_overlay = ColorRect.new()
	menu_overlay.color = Color("#080907")
	menu_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_overlay.z_index = 1000
	add_child(menu_overlay)
	_add_premium_art(menu_overlay, PremiumUIArt.Variant.HOME, Color("#b98a4f"))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22 if mobile else 46)
	margin.add_theme_constant_override("margin_right", 22 if mobile else 46)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	menu_overlay.add_child(margin)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 720.0 if mobile else 0.0
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 65
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", -3)
	title_box.add_child(_label("THREE KINGDOMS · TACTICAL AUTOBATTLER", 10, Color("#9e7c50")))
	var home_title := _label("战三国 · 弈定九州", 35 if mobile else 40, Color("#edc878"))
	home_title.add_theme_constant_override("outline_size", 6)
	home_title.add_theme_color_override("font_outline_color", Color("#1b1007"))
	title_box.add_child(home_title)
	header.add_child(title_box)
	var resource_panel := PanelContainer.new()
	_style(resource_panel, Color("#11120ff0"), 5, Color("#82643e"), 1)
	home_resource_label = _label("", 18, Color("#e8c96e"))
	home_resource_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	home_resource_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home_resource_label.custom_minimum_size.x = 390
	resource_panel.add_child(home_resource_label)
	header.add_child(resource_panel)
	box.add_child(header)
	var hero_panel := PanelContainer.new()
	hero_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style(hero_panel, Color("#11110ed8"), 4, Color("#8e673d"), 2)
	var hero_frame := MarginContainer.new()
	hero_frame.add_theme_constant_override("margin_left", 18)
	hero_frame.add_theme_constant_override("margin_right", 18)
	hero_frame.add_theme_constant_override("margin_top", 10)
	hero_frame.add_theme_constant_override("margin_bottom", 8)
	hero_panel.add_child(hero_frame)
	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 16)
	hero_frame.add_child(hero_row)
	var faction_banner := PanelContainer.new()
	faction_banner.custom_minimum_size.x = 175
	_style(faction_banner, Color("#10261fdd"), 3, Color("#80693f"), 1)
	faction_banner.mouse_filter = Control.MOUSE_FILTER_STOP
	faction_banner.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	faction_banner.tooltip_text = t("点击查看游戏介绍", "Click for the game guide")
	faction_banner.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_show_intro_popup()
	)
	var banner_box := VBoxContainer.new()
	banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_box.add_theme_constant_override("separation", 10)
	var seal := _label("◆", 44, Color("#d8b96f"))
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_box.add_child(seal)
	home_faction_label = _label(t("游戏\n介绍", "GAME\nGUIDE"), 30, Color("#d5bd7e"))
	home_faction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_box.add_child(home_faction_label)
	banner_box.add_child(_label("────────", 12, Color("#6e5a37")))
	home_motto_label = _label(t("玩法·属性\n规则·胜负", "Rules &\nAttributes"), 17, Color("#b7a17a"))
	home_motto_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_box.add_child(home_motto_label)
	faction_banner.add_child(banner_box)
	hero_row.add_child(faction_banner)
	var hero_box := VBoxContainer.new()
	hero_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_row.add_child(hero_box)
	home_portrait = TextureRect.new()
	home_portrait.custom_minimum_size = Vector2(600 if mobile else 760, 505)
	home_portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home_portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	home_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	home_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero_box.add_child(home_portrait)
	var name_panel := PanelContainer.new()
	name_panel.custom_minimum_size = Vector2(430, 52)
	_style(name_panel, Color("#15130ff2"), 3, Color("#b98a4f"), 2)
	home_hero_name_label = _label("", 25, Color("#f0c77a"))
	home_hero_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_panel.add_child(home_hero_name_label)
	hero_box.add_child(name_panel)
	var feature_banner := PanelContainer.new()
	feature_banner.custom_minimum_size.x = 175
	_style(feature_banner, Color("#131613dd"), 3, Color("#80693f"), 1)
	var feature_box := VBoxContainer.new()
	feature_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var feature_title := _label("主页武将", 17, Color("#9e8769"))
	feature_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feature_box.add_child(feature_title)
	var feature_mark := _label("将", 48, Color("#e1c16e"))
	feature_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feature_box.add_child(feature_mark)
	var feature_help := _label("可在图鉴中\n设为主页", 16, Color("#b7a17a"))
	feature_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feature_box.add_child(feature_help)
	feature_banner.add_child(feature_box)
	hero_row.add_child(feature_banner)
	box.add_child(hero_panel)
	var navigation := HBoxContainer.new()
	navigation.alignment = BoxContainer.ALIGNMENT_CENTER
	navigation.add_theme_constant_override("separation", 8)
	var nav_entries := [
		["图　图鉴", Callable(self, "_show_encyclopedia")], ["符　符文", Callable(self, "_show_runes")],
		["战　战斗", Callable(self, "_show_battle_menu")], ["赋　天赋", Callable(self, "_show_talents")],
		["设　设置", Callable(self, "_show_settings")]
	]
	for index in nav_entries.size():
		var entry: Array = nav_entries[index]
		var nav := _button(str(entry[0]))
		nav.custom_minimum_size = Vector2(150 if mobile else 0, 62)
		nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav.add_theme_font_size_override("font_size", 20)
		_accent_button(nav, Color("#d3a34f") if index == 2 else Color("#7b6a4e"), index == 2)
		nav.pressed.connect(entry[1])
		navigation.add_child(nav)
	box.add_child(navigation)
	_build_encyclopedia()
	_build_settings_overlay()
	_build_balance_lab()
	_build_battle_menu()
	_build_rune_overlay()
	_build_talent_overlay()
	_build_result_overlay()
	_build_intro_popup()
	_refresh_home()
	draft_overlay.hide()

func _refresh_home() -> void:
	if not is_instance_valid(home_portrait): return
	home_portrait.texture = _portrait_source_texture(home_hero_id)
	var faction := str(heroes[home_hero_id].f)
	home_hero_name_label.text = _hero_name(home_hero_id) + " · " + _faction_name(faction)
	home_hero_name_label.add_theme_color_override("font_color", FACTION_COLORS[faction].lightened(0.32))
	home_resource_label.text = "将魂  %d　　将星  %d / 300" % [general_souls, general_stars]

func _show_intro_popup() -> void:
	if is_instance_valid(intro_popup):
		intro_popup.show()

func _intro_rich_page(tab_title: String, content: String) -> RichTextLabel:
	var page := RichTextLabel.new()
	page.name = tab_title
	page.bbcode_enabled = true
	page.scroll_active = true
	page.custom_minimum_size = Vector2(880, 520)
	page.add_theme_font_size_override("normal_font_size", 18)
	page.add_theme_font_size_override("bold_font_size", 19)
	page.text = content
	return page

func _build_intro_popup() -> void:
	intro_popup = ColorRect.new()
	intro_popup.color = Color("#050608e6")
	intro_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	intro_popup.z_index = 1200
	intro_popup.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			intro_popup.hide()
	)
	add_child(intro_popup)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_popup.add_child(center)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_style(panel, Color("#12140ff5"), 14, Color("#b98a4f"), 2)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var header := _label(t("游戏介绍（点击空白处关闭）", "GAME GUIDE (click outside to close)"), 22, Color("#f0c77a"))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(header)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 18)
	box.add_child(tabs)
	var c := "[color=#90c59e][b]"
	var e := "[/b][/color]"
	tabs.add_child(_intro_rich_page(t("基础玩法", "BASICS"),
		c + "一局游戏怎么玩" + e + "\n每关分三个阶段：[b]选将 → 布阵 → 战斗[/b]。选将阶段进行三轮三选一（候选从左到右固定为前军、中军、后军），布阵阶段把武将放上 5×3 棋盘，随后进行 [b]30 秒自动战斗[/b]——战斗中武将按行动条自动行动与施放技能，玩家不操作。\n\n共 [b]20 关[/b] × 5 难度，之后进入没有时间限制的最终决战。闯关与天书演武模式还含金币经济：卖出武将回收金币、每回合有收入与利息，详情见备战席右侧的天书阁。\n\n" + c + "武将管理" + e + "\n棋盘与备战席（9 格）内的武将可自由拖动上阵；上阵过的武将只能场上换位或拖到顶部售卖区卖出。天书通过天书阁购买与替换：3/6/9/12/15 回合各有一次免费三选一。"))
	tabs.add_child(_intro_rich_page(t("胜负与主公", "VICTORY"),
		c + "胜负条件" + e + "\n双方各有一位主公（[b]100000[/b] 生命，天赋可提高）。[b]任一方主公生命归零即落败[/b]；普通关 30 秒到时则比较双方主公剩余生命判定胜负，敌方主公会保留剩余生命进入后续关卡。\n\n" + c + "两条重要隐藏规则" + e + "\n[b]1. 攻击空格伤害主公[/b]：技能随机打到没有武将的空格时，伤害全额由敌方主公承受——留空阵是有代价的，但也可能浪费敌方技能。\n[b]2. 溢出治疗转化[/b]：治疗超出目标最大生命的部分，按 [b]30%[/b] 转化为我方主公的生命（天书·泽被苍生可提升至 50%/80%）。\n\n最终决战没有 30 秒限制，直到一方主公倒下为止。"))
	tabs.add_child(_intro_rich_page(t("属性与养成", "ATTRIBUTES"),
		c + "三大属性" + e + "\n[b]生命[/b]：武将的生存基础。\n[b]兵略值[/b]：全员基准 100，决定技能强度——\"230% 兵略值伤害\"即造成 100×2.3 = 230 点伤害。天赋、符文可提高兵略，从而放大所有技能。\n[b]技能冷却[/b]：行动条攒满一轮所需的时间，冷却越短出手越快。\n\n" + c + "冷却缩减规则（重要）" + e + "\n· 天赋与符文的冷却缩减[b]合并计算，合计最多减原始冷却的一半[/b]；\n· 天书与羁绊（如陈宫被动）的缩减不受此上限约束；\n· 所有缩减叠加后，最终冷却[b]最低 2 秒[/b]。\n\n" + c + "永久养成" + e + "\n[b]将星[/b]：通关按主公剩余血量评 1~3 星，用于点亮天赋树（5 棵：通用+四阵营，2 星=1 点）。\n[b]将魂[/b]：每次通关都给，用于抽符文（单抽 200、十连 2000）。符文分正（单属性）/ 均（双属性）/ 极（一减一增），两枚同阶可合成一枚高阶，每名武将最多装备 6 枚。"))
	tabs.add_child(_intro_rich_page(t("战场规则", "BATTLE"),
		c + "前军 / 中军 / 后军" + e + "\n前军[b]只能站前排且只打前排[/b]；中军站前排可打全场、站中排打前中排、站后排只打前排；后军[b]任意站位随机攻击全场[/b]。合理利用站位改变射程是布阵的核心。\n\n" + c + "行动条" + e + "\n武将行动条从 0 涨到 100 即行动一次并施放技能；增速受减速、沉默影响，眩晕/冻结/魅惑/恐惧期间停止。\n\n" + c + "常见战斗效果" + e + "\n眩晕（停止行动）、冻结（停止，受伤提前解冻并追加破冰伤害）、魅惑（停止）、恐惧（停止+持续伤害）、中毒（层数伤害，逐秒衰减）、灼烧（持续伤害）、减速（行动条变慢）、易碎（受到伤害提高）。\n\n" + c + "羁绊" + e + "\n[b]阵营羁绊[/b]：按场上同阵营人数 2/5/8 分三档——蜀承伤降低、魏控制时长提高、吴最大生命提高、群冷却缩短，8 人时各解锁强力终极效果。\n[b]组合羁绊[/b]：特定武将组合触发（桃园结义、五虎上将、四英杰等），完整关系见 图鉴 → 羁绊图。"))
	intro_popup.hide()

func _full_overlay(z: int = 1150, art_variant: int = PremiumUIArt.Variant.BACKDROP, accent := UI_GOLD) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.color = UI_INK
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = z
	overlay.hide()
	add_child(overlay)
	_add_premium_art(overlay, art_variant, accent)
	return overlay

func _overlay_panel(overlay: Control, title_text: String, close_action: Callable) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 24)
	overlay.add_child(margin)
	var panel := PanelContainer.new()
	_style(panel, Color("#12110fea"), 5, Color("#8e673d"), 2)
	margin.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 54
	var heading := _section_title(title_text, "THREE KINGDOMS · " + title_text)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var close := _button("返回主页")
	close.custom_minimum_size = Vector2(140, 46)
	_accent_button(close, Color("#6f8aa5"))
	close.pressed.connect(close_action)
	header.add_child(close)
	root.add_child(header)
	var line := HSeparator.new()
	line.add_theme_constant_override("separation", 4)
	root.add_child(line)
	return root

func _build_battle_menu() -> void:
	battle_menu_overlay = _full_overlay(1150, PremiumUIArt.Variant.MAP, Color("#a97c42"))
	var root := _overlay_panel(battle_menu_overlay, "战斗", func(): battle_menu_overlay.hide())
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 12)
	var quick_panel := PanelContainer.new()
	quick_panel.custom_minimum_size = Vector2(390, 142)
	quick_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style(quick_panel, Color("#151a1ce8"), 5, Color("#58758d"), 2)
	var quick_box := VBoxContainer.new()
	quick_box.add_theme_constant_override("separation", 6)
	quick_box.add_child(_label("⚔　快速战斗", 24, Color("#b8d2e8")))
	var quick_help := _label("原十五轮构筑玩法，可读取之前保存的对局。", 14, Color("#c9c0b1"))
	quick_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quick_box.add_child(quick_help)
	var quick_buttons := HBoxContainer.new()
	var quick_start := _button("开始新对局")
	_accent_button(quick_start, Color("#557d9e"), true)
	quick_start.pressed.connect(_start_new_from_menu)
	quick_buttons.add_child(quick_start)
	continue_button = _button("继续对局")
	_accent_button(continue_button, Color("#557d9e"))
	continue_button.disabled = not FileAccess.file_exists(SAVE_PATH)
	continue_button.pressed.connect(_continue_from_menu)
	quick_buttons.add_child(continue_button)
	quick_box.add_child(quick_buttons)
	quick_panel.add_child(quick_box)
	mode_row.add_child(quick_panel)
	var tianshu_panel := PanelContainer.new()
	tianshu_panel.custom_minimum_size = Vector2(390, 142)
	tianshu_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style(tianshu_panel, Color("#211628e8"), 5, Color("#9c63c3"), 2)
	var tianshu_box := VBoxContainer.new()
	tianshu_box.add_theme_constant_override("separation", 6)
	tianshu_box.add_child(_label("卷　天书演武", 24, Color("#e5a8ff")))
	var tianshu_help := _label("每回合先天书三选一，再进行三轮选将；天书仅本局生效。", 14, Color("#d6c3df"))
	tianshu_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tianshu_box.add_child(tianshu_help)
	var tianshu_start := _button("开始天书演武")
	_accent_button(tianshu_start, Color("#955cc0"), true)
	tianshu_start.pressed.connect(_start_tianshu_from_menu)
	tianshu_box.add_child(tianshu_start)
	tianshu_panel.add_child(tianshu_box)
	mode_row.add_child(tianshu_panel)
	var challenge_panel := PanelContainer.new()
	challenge_panel.custom_minimum_size = Vector2(390, 142)
	challenge_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style(challenge_panel, Color("#241b10e8"), 5, Color("#b48743"), 2)
	var challenge_header := VBoxContainer.new()
	challenge_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	challenge_header.add_theme_constant_override("separation", 6)
	challenge_header.add_child(_label("城　闯关", 24, Color("#f0c77a")))
	challenge_stage_title = _label("选择一个已解锁关卡与难度", 15, Color("#c9c0b1"))
	challenge_stage_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	challenge_header.add_child(challenge_stage_title)
	challenge_difficulty_options = OptionButton.new()
	for index in DIFFICULTIES.size():
		challenge_difficulty_options.add_item(str(DIFFICULTIES[index].name), index)
	challenge_difficulty_options.select(0)
	challenge_difficulty_options.item_selected.connect(_on_challenge_difficulty_selected)
	challenge_difficulty_options.hide()
	var challenge_note := _label("二十城池 · 五档难度 · 每关三星", 14, Color("#ad8355"))
	challenge_header.add_child(challenge_note)
	challenge_panel.add_child(challenge_header)
	mode_row.add_child(challenge_panel)
	root.add_child(mode_row)
	var difficulty_row := HBoxContainer.new()
	difficulty_row.add_theme_constant_override("separation", 8)
	var difficulty_caption := _label("难度", 16, Color("#ad8355"))
	difficulty_caption.custom_minimum_size.x = 78
	difficulty_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	difficulty_row.add_child(difficulty_caption)
	var difficulty_colors := [Color("#d5a846"), Color("#4e8063"), Color("#426c91"), Color("#8250a0"), Color("#a3483d")]
	for index in DIFFICULTIES.size():
		var difficulty_button := _button(str(DIFFICULTIES[index].name))
		difficulty_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		difficulty_button.custom_minimum_size.y = 45
		_accent_button(difficulty_button, difficulty_colors[index], index == 0)
		difficulty_button.pressed.connect(_on_challenge_difficulty_tab.bind(index))
		challenge_difficulty_buttons.append(difficulty_button)
		difficulty_row.add_child(difficulty_button)
	root.add_child(difficulty_row)
	var challenge_content := HBoxContainer.new()
	challenge_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	challenge_content.add_theme_constant_override("separation", 14)
	root.add_child(challenge_content)
	challenge_stage_scroll = ScrollContainer.new()
	challenge_stage_scroll.custom_minimum_size.x = 760
	challenge_stage_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	challenge_stage_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	challenge_stage_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_enable_touch_scroll(challenge_stage_scroll, false, true)
	challenge_content.add_child(challenge_stage_scroll)
	var stage_host := PanelContainer.new()
	stage_host.custom_minimum_size.x = 760
	stage_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_host.mouse_filter = Control.MOUSE_FILTER_PASS
	_style(stage_host, Color("#17140ed8"), 4, Color("#745a35"), 1)
	challenge_stage_scroll.add_child(stage_host)
	_add_premium_art(stage_host, PremiumUIArt.Variant.MAP, Color("#8b6a3b"))
	var stage_margin := MarginContainer.new()
	stage_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	stage_margin.add_theme_constant_override("margin_left", 5)
	stage_margin.add_theme_constant_override("margin_right", 5)
	stage_margin.add_theme_constant_override("margin_top", 5)
	stage_margin.add_theme_constant_override("margin_bottom", 5)
	stage_host.add_child(stage_margin)
	challenge_stage_grid = GridContainer.new()
	challenge_stage_grid.columns = 4
	challenge_stage_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	challenge_stage_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	challenge_stage_grid.add_theme_constant_override("h_separation", 9)
	challenge_stage_grid.add_theme_constant_override("v_separation", 10)
	challenge_stage_grid.gui_input.connect(_on_touch_scroll_input.bind(challenge_stage_scroll, false, true))
	stage_margin.add_child(challenge_stage_grid)
	var detail_panel := PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(350, 0)
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style(detail_panel, Color("#17130de8"), 5, Color("#b48743"), 2)
	challenge_content.add_child(detail_panel)
	var detail_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		detail_margin.add_theme_constant_override("margin_" + side, 18)
	detail_panel.add_child(detail_margin)
	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 10)
	detail_margin.add_child(detail_box)
	challenge_detail_scroll = ScrollContainer.new()
	challenge_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	challenge_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	challenge_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_enable_touch_scroll(challenge_detail_scroll, false, true)
	detail_box.add_child(challenge_detail_scroll)
	var detail_content := VBoxContainer.new()
	detail_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_content.add_theme_constant_override("separation", 12)
	detail_content.mouse_filter = Control.MOUSE_FILTER_PASS
	detail_content.gui_input.connect(_on_touch_scroll_input.bind(challenge_detail_scroll, false, true))
	challenge_detail_scroll.add_child(detail_content)
	detail_content.add_child(_label("关卡军情", 24, Color("#f0c77a")))
	challenge_detail_stage_label = _label("", 20, Color("#f3e3bd"))
	challenge_detail_stage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	challenge_detail_stage_label.mouse_filter = Control.MOUSE_FILTER_PASS
	detail_content.add_child(challenge_detail_stage_label)
	var bonus_panel := PanelContainer.new()
	bonus_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_style(bonus_panel, Color("#211a11e8"), 3, Color("#725b37"), 1)
	challenge_detail_bonus_label = _label("", 16, Color("#d9c7a1"))
	challenge_detail_bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	challenge_detail_bonus_label.custom_minimum_size.y = 190
	challenge_detail_bonus_label.mouse_filter = Control.MOUSE_FILTER_PASS
	bonus_panel.add_child(challenge_detail_bonus_label)
	detail_content.add_child(bonus_panel)
	var star_title := _label("将星条件", 21, Color("#e7bd66"))
	star_title.mouse_filter = Control.MOUSE_FILTER_PASS
	detail_content.add_child(star_title)
	var star_panel := PanelContainer.new()
	star_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_style(star_panel, Color("#171d18e8"), 3, Color("#57745f"), 1)
	challenge_detail_star_label = _label("", 16, Color("#d6dfd2"))
	challenge_detail_star_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	challenge_detail_star_label.custom_minimum_size.y = 175
	challenge_detail_star_label.mouse_filter = Control.MOUSE_FILTER_PASS
	star_panel.add_child(challenge_detail_star_label)
	detail_content.add_child(star_panel)
	challenge_start_button = _button("开始战斗")
	challenge_start_button.custom_minimum_size.y = 58
	challenge_start_button.add_theme_font_size_override("font_size", 20)
	_accent_button(challenge_start_button, Color("#b17b32"), true)
	challenge_start_button.pressed.connect(_confirm_challenge)
	detail_box.add_child(challenge_start_button)
	challenge_restart_button = _button("放弃进度，重新开始")
	challenge_restart_button.custom_minimum_size.y = 42
	challenge_restart_button.add_theme_font_size_override("font_size", 16)
	challenge_restart_button.pressed.connect(_on_challenge_restart)
	challenge_restart_button.hide()
	detail_box.add_child(challenge_restart_button)

func _show_battle_menu() -> void:
	var run := _challenge_run_snapshot()
	continue_button.disabled = not FileAccess.file_exists(SAVE_PATH)
	continue_button.text = "继续闯关" if not run.is_empty() else "继续对局"
	if not run.is_empty():
		# 存在未完成的闯关进度：优先定位到该关卡与难度，方便继续战斗。
		selected_stage = int(run.stage)
		selected_difficulty = int(run.difficulty)
	elif not pending_battle_result.is_empty():
		# 上一场闯关结算后：胜利定位到下一关（或下一难度第 1 关），失败留在原关重试。
		var target := _next_challenge_after(bool(pending_battle_result.get("victory", false)), int(pending_battle_result.get("stage", 1)), int(pending_battle_result.get("difficulty", 0)))
		selected_stage = clampi(target.x, 1, STAGE_NAMES.size())
		selected_difficulty = clampi(target.y, 0, DIFFICULTIES.size() - 1)
		pending_battle_result = {}
	challenge_difficulty_options.select(clampi(selected_difficulty, 0, DIFFICULTIES.size() - 1))
	if not _is_stage_unlocked(selected_stage, selected_difficulty): selected_stage = 1
	battle_menu_overlay.show()
	_render_stage_grid()

func _next_challenge_after(victory: bool, stage: int, difficulty: int) -> Vector2i:
	# 结算后的推荐定位：失败留在原关重试；胜利指向同难度下一关。
	# 解锁规则是"第 N 关高难度需先通关该关低难度"，因此下一关未解锁时，
	# 回落到该关尚未通关的最高低难度(即当前推进前沿)；最后一关胜利则进入下一难度第 1 关。
	if not victory: return Vector2i(stage, difficulty)
	if stage < STAGE_NAMES.size():
		if _is_stage_unlocked(stage + 1, difficulty): return Vector2i(stage + 1, difficulty)
		for lower in range(difficulty - 1, -1, -1):
			if _is_stage_unlocked(stage + 1, lower) and int(stage_star_records.get(_progression_key(stage + 1, lower), 0)) == 0:
				return Vector2i(stage + 1, lower)
		return Vector2i(stage, difficulty)
	if difficulty < DIFFICULTIES.size() - 1:
		if _is_stage_unlocked(1, difficulty + 1): return Vector2i(1, difficulty + 1)
		for lower in range(difficulty, -1, -1):
			if _is_stage_unlocked(1, lower) and int(stage_star_records.get(_progression_key(1, lower), 0)) == 0:
				return Vector2i(1, lower)
	return Vector2i(stage, difficulty)

func _on_challenge_difficulty_selected(index: int) -> void:
	selected_difficulty = clampi(index, 0, DIFFICULTIES.size() - 1)
	if not _is_stage_unlocked(selected_stage, selected_difficulty):
		selected_stage = 1
	_render_stage_grid()

func _on_challenge_difficulty_tab(index: int) -> void:
	challenge_difficulty_options.select(index)
	_on_challenge_difficulty_selected(index)

func _render_stage_grid() -> void:
	_clear_dynamic_children(challenge_stage_grid)
	var difficulty := challenge_difficulty_options.selected
	var run := _challenge_run_snapshot()
	challenge_stage_title.text = "选择关卡查看敌军加成，再由右侧开始战斗。15 回合 · 每回合 30 秒 · 解锁限制：%s" % ("开启" if limit_challenges else "关闭")
	if not run.is_empty() and int(run.difficulty) == difficulty:
		challenge_stage_title.text = "有进行中的关卡：第 %02d 关 · %s · 回合 %d / 15，选中后由右侧继续战斗。" % [int(run.stage), STAGE_NAMES[int(run.stage) - 1], int(run.round)]
	for stage in range(1, STAGE_NAMES.size() + 1):
		var unlocked := _is_stage_unlocked(stage, difficulty)
		var best := int(stage_star_records.get(_progression_key(stage, difficulty), 0))
		var is_running: bool = not run.is_empty() and int(run.stage) == stage and int(run.difficulty) == difficulty
		var status_line := ("▶ 续 %d/15" % int(run.round)) if is_running else (("★".repeat(best) + "☆".repeat(3 - best)) if unlocked else "锁")
		var button := _button(("%02d" % stage) + "\n" + STAGE_NAMES[stage - 1] + "\n" + status_line)
		button.custom_minimum_size = Vector2(176, 88)
		button.add_theme_font_size_override("font_size", 15)
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.gui_input.connect(_on_touch_scroll_input.bind(challenge_stage_scroll, false, true))
		button.disabled = not unlocked
		var difficulty_colors := [Color("#c8953e"), Color("#48765e"), Color("#3f688e"), Color("#774694"), Color("#963f37")]
		_accent_button(button, difficulty_colors[difficulty], stage == selected_stage and unlocked)
		button.tooltip_text = "关卡兵略 +%d；难度生命 +%d%%、兵略 +%d" % [_challenge_stage_strategy_bonus(stage), roundi((float(DIFFICULTIES[difficulty].hp) - 1.0) * 100.0), _challenge_difficulty_strategy_bonus(difficulty)]
		button.pressed.connect(_select_challenge_stage.bind(stage, difficulty))
		challenge_stage_grid.add_child(button)
	var tab_colors := [Color("#d5a846"), Color("#4e8063"), Color("#426c91"), Color("#8250a0"), Color("#a3483d")]
	for index in challenge_difficulty_buttons.size():
		var tab := challenge_difficulty_buttons[index]
		_accent_button(tab, tab_colors[index], index == difficulty)
		tab.modulate = Color.WHITE if index == difficulty else Color(0.72, 0.72, 0.72, 0.82)
	_render_challenge_detail()

func _select_challenge_stage(stage: int, difficulty: int) -> void:
	if not _is_stage_unlocked(stage, difficulty): return
	selected_stage = clampi(stage, 1, STAGE_NAMES.size())
	selected_difficulty = clampi(difficulty, 0, DIFFICULTIES.size() - 1)
	_render_stage_grid()

func _render_challenge_detail() -> void:
	if not is_instance_valid(challenge_detail_stage_label): return
	var difficulty := clampi(selected_difficulty, 0, DIFFICULTIES.size() - 1)
	var data: Dictionary = DIFFICULTIES[difficulty]
	var best := int(stage_star_records.get(_progression_key(selected_stage, difficulty), 0))
	var run := _challenge_run_snapshot()
	var run_here: bool = not run.is_empty() and int(run.stage) == selected_stage and int(run.difficulty) == difficulty
	if run_here:
		challenge_detail_stage_label.text = "第 %02d 关\n%s · %s\n进行中：回合 %d / 15\n历史最佳 %s" % [selected_stage, STAGE_NAMES[selected_stage - 1], str(data.name), int(run.round), "★".repeat(best) + "☆".repeat(3 - best)]
	else:
		challenge_detail_stage_label.text = "第 %02d 关\n%s · %s\n历史最佳 %s" % [selected_stage, STAGE_NAMES[selected_stage - 1], str(data.name), "★".repeat(best) + "☆".repeat(3 - best)]
	var total_strategy := _challenge_stage_strategy_bonus() + _challenge_difficulty_strategy_bonus()
	challenge_detail_bonus_label.text = "当前关卡敌方阵营加成\n  兵略 +%d\n\n当前难度敌方阵营加成\n  初始生命 +%d%%\n  兵略 +%d\n\n最终兵略加成：+%d" % [_challenge_stage_strategy_bonus(), roundi((float(data.hp) - 1.0) * 100.0), _challenge_difficulty_strategy_bonus(), total_strategy]
	challenge_detail_star_label.text = "★ 战斗胜利\n\n★ 主公结算生命 > 50,000\n\n★ 主公结算生命 > 80,000\n\n将星仅在刷新该难度历史星级时补发。"
	challenge_start_button.text = ("继续战斗（回合 %d / 15）" % int(run.round)) if run_here else "开始战斗"
	challenge_start_button.disabled = not _is_stage_unlocked(selected_stage, difficulty)
	challenge_restart_button.visible = run_here

func _confirm_challenge() -> void:
	var run := _challenge_run_snapshot()
	if not run.is_empty() and int(run.stage) == selected_stage and int(run.difficulty) == selected_difficulty:
		# 选中关卡与进行中的存档一致：读取存档从该回合继续，而非重新开始。
		battle_menu_overlay.hide()
		menu_overlay.hide()
		if not _load_game(): menu_overlay.show()
		return
	_launch_challenge(selected_stage, selected_difficulty)

func _on_challenge_restart() -> void:
	# 放弃当前关卡的进行中进度，从第 1 回合重新开始。
	_launch_challenge(selected_stage, selected_difficulty)

func _launch_challenge(stage: int, difficulty: int) -> void:
	battle_menu_overlay.hide()
	menu_overlay.hide()
	if not _start_challenge(stage, difficulty):
		menu_overlay.show()
		battle_menu_overlay.show()
		return
	_render()

func _start_tianshu_from_menu() -> void:
	battle_menu_overlay.hide()
	menu_overlay.hide()
	_start_tianshu_game()
	_render()

func _build_result_overlay() -> void:
	result_overlay = _full_overlay(1600, PremiumUIArt.Variant.HOME, Color("#b88a50"))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 420)
	_style(panel, Color("#15120df2"), 6, Color("#b88a50"), 3)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	panel.add_child(box)
	result_title_label = _label("", 48, Color("#f0c77a"))
	result_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result_title_label)
	result_detail_label = _label("", 20, Color("#d8cfbd"))
	result_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result_detail_label)
	var back := _button("点击返回主页")
	_accent_button(back, Color("#b98a4f"), true)
	back.custom_minimum_size = Vector2(320, 64)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(_return_home_from_result)
	box.add_child(back)

func _show_battle_result(result: Dictionary) -> void:
	var victory := bool(result.get("victory", false))
	_play_sfx("bell", -4.0, 1000, 0.0)
	result_title_label.text = "胜利" if victory else "失败"
	result_title_label.add_theme_color_override("font_color", Color("#f0c77a") if victory else Color("#e07070"))
	var difficulty := int(result.get("difficulty", -1))
	if difficulty >= 0:
		var stars := int(result.get("stars", 0))
		result_detail_label.text = "%s · %s\n%s\n将魂 +%d　将星 +%d" % [STAGE_NAMES[int(result.stage) - 1], str(DIFFICULTIES[difficulty].name), "★".repeat(stars) + "☆".repeat(3 - stars), int(result.get("souls", 0)), int(result.get("new_stars", 0))] if victory else "%s · %s\n主公阵亡，本次没有奖励" % [STAGE_NAMES[int(result.stage) - 1], str(DIFFICULTIES[difficulty].name)]
	else:
		result_detail_label.text = "天下归心" if victory else "主公阵亡"
	result_overlay.show()

func _return_home_from_result() -> void:
	result_overlay.hide()
	_show_main_menu()

func _build_rune_overlay() -> void:
	rune_overlay = _full_overlay(1150, PremiumUIArt.Variant.BACKDROP, Color("#557b61"))
	var root := _overlay_panel(rune_overlay, "符文", func(): rune_overlay.hide(); _refresh_home())
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 10)
	rune_resource_label = _label("", 18, Color("#e8c96e"))
	rune_resource_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(rune_resource_label)
	var draw := _button("抽取一次（%d）" % RUNE_DRAW_COST)
	_accent_button(draw, Color("#52755e"))
	draw.pressed.connect(_on_draw_runes.bind(1))
	toolbar.add_child(draw)
	var draw_ten := _button("十连抽（%d）" % (RUNE_DRAW_COST * 10))
	_accent_button(draw_ten, Color("#b98a4f"), true)
	draw_ten.pressed.connect(_on_draw_runes.bind(10))
	toolbar.add_child(draw_ten)
	root.add_child(toolbar)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 8)
	filters.add_child(_label("库存分阶：", 16, Color("#c9c0b1")))
	for tier in range(0, 7):
		var text_value := "全部" if tier == 0 else str(RUNE_TIERS[tier - 1].name)
		var filter_button := _button(text_value)
		filter_button.custom_minimum_size = Vector2(105, 42)
		if tier > 0:
			_accent_button(filter_button, Color(str(RUNE_TIERS[tier - 1].hex)))
		filter_button.pressed.connect(_set_rune_tier_filter.bind(tier))
		rune_filter_buttons.append(filter_button)
		filters.add_child(filter_button)
	root.add_child(filters)
	var class_filters := HBoxContainer.new()
	class_filters.add_theme_constant_override("separation", 8)
	class_filters.add_child(_label("符文类型：", 16, Color("#c9c0b1")))
	for rune_class in ["", "正", "均", "极"]:
		var class_button := _button("全部" if rune_class.is_empty() else rune_class + "符文")
		class_button.custom_minimum_size = Vector2(125, 40)
		_accent_button(class_button, Color("#71806f"))
		class_button.pressed.connect(_set_rune_class_filter.bind(rune_class))
		rune_class_filter_buttons.append(class_button)
		class_filters.add_child(class_button)
	var class_hint := _label("同类内按：生命 → 冷却 → 兵略", 14, Color("#8fa5b5"))
	class_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	class_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	class_filters.add_child(class_hint)
	root.add_child(class_filters)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	root.add_child(columns)
	var hero_panel := PanelContainer.new()
	hero_panel.custom_minimum_size = Vector2(640, 0)
	hero_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_panel.size_flags_stretch_ratio = 1.45
	_style(hero_panel, Color("#121c17ed"), 5, Color("#617c5d"), 2)
	var hero_box := VBoxContainer.new()
	hero_box.add_theme_constant_override("separation", 10)
	hero_panel.add_child(hero_box)
	var choose_title := _label("配置武将", 22, Color("#f0c77a"))
	choose_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_box.add_child(choose_title)
	rune_faction_options = OptionButton.new()
	for faction in ["shu", "wei", "wu", "qun"]:
		rune_faction_options.add_item(_faction_name(faction))
		rune_faction_options.set_item_metadata(rune_faction_options.get_item_count() - 1, faction)
	rune_faction_options.item_selected.connect(_on_rune_faction_selected)
	hero_box.add_child(rune_faction_options)
	rune_hero_options = OptionButton.new()
	rune_hero_options.custom_minimum_size = Vector2(560, 46)
	rune_hero_options.item_selected.connect(func(_index): _render_runes())
	hero_box.add_child(rune_hero_options)
	rune_hero_portrait = TextureRect.new()
	rune_hero_portrait.custom_minimum_size = Vector2(580, 130) if _is_mobile_ui() else Vector2(580, 180)
	rune_hero_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rune_hero_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rune_hero_portrait.mouse_filter = Control.MOUSE_FILTER_STOP
	rune_hero_portrait.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	rune_hero_portrait.tooltip_text = "点击查看武将属性详情"
	rune_hero_portrait.gui_input.connect(_on_rune_hero_card_input)
	hero_box.add_child(rune_hero_portrait)
	var equipped_scroll := ScrollContainer.new()
	equipped_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipped_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	equipped_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_enable_touch_scroll(equipped_scroll, false, true)
	hero_box.add_child(equipped_scroll)
	rune_equipped_box = VBoxContainer.new()
	rune_equipped_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rune_equipped_box.add_theme_constant_override("separation", 6)
	rune_equipped_box.gui_input.connect(_on_touch_scroll_input.bind(equipped_scroll, false, true))
	equipped_scroll.add_child(rune_equipped_box)
	columns.add_child(hero_panel)
	var inventory_column := VBoxContainer.new()
	inventory_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_column.size_flags_stretch_ratio = 1.0
	inventory_column.mouse_filter = Control.MOUSE_FILTER_PASS
	inventory_column.add_theme_constant_override("separation", 8)
	columns.add_child(inventory_column)
	var inventory_header := HBoxContainer.new()
	inventory_header.mouse_filter = Control.MOUSE_FILTER_PASS
	rune_status_label = _label("", 16, Color("#c9c0b1"))
	rune_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rune_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_header.add_child(rune_status_label)
	rune_batch_synthesize_button = _button("当前阶全部合成")
	rune_batch_synthesize_button.mouse_filter = Control.MOUSE_FILTER_PASS
	rune_batch_synthesize_button.pressed.connect(_on_synthesize_current_tier)
	inventory_header.add_child(rune_batch_synthesize_button)
	inventory_column.add_child(inventory_header)
	rune_inventory_scroll = ScrollContainer.new()
	rune_inventory_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rune_inventory_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rune_inventory_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_enable_touch_scroll(rune_inventory_scroll, false, true)
	if _is_mobile_ui(): inventory_column.gui_input.connect(_on_touch_scroll_input.bind(rune_inventory_scroll, false, true))
	inventory_column.add_child(rune_inventory_scroll)
	rune_inventory_box = GridContainer.new()
	(rune_inventory_box as GridContainer).columns = 1
	rune_inventory_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rune_inventory_box.mouse_filter = Control.MOUSE_FILTER_PASS
	rune_inventory_box.add_theme_constant_override("h_separation", 8)
	rune_inventory_box.add_theme_constant_override("v_separation", 8)
	rune_inventory_scroll.add_child(rune_inventory_box)
	var home_faction := str(heroes[home_hero_id].f)
	for index in rune_faction_options.item_count:
		if str(rune_faction_options.get_item_metadata(index)) == home_faction: rune_faction_options.select(index)
	_populate_rune_heroes(home_faction, home_hero_id)
	_build_rune_hero_detail_overlay()

func _on_rune_hero_card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_show_rune_hero_detail()

func _build_rune_hero_detail_overlay() -> void:
	rune_hero_detail_overlay = ColorRect.new()
	rune_hero_detail_overlay.color = Color("#050608e0")
	rune_hero_detail_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rune_hero_detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	rune_hero_detail_overlay.z_index = 1200
	rune_hero_detail_overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			rune_hero_detail_overlay.hide()
	)
	add_child(rune_hero_detail_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rune_hero_detail_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(920, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_style(panel, Color("#141713f2"), 14, Color("#557b61"), 2)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var header := _label("武将属性详情（点击空白处关闭）", 20, Color("#f0c77a"))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(header)
	rune_hero_detail_columns = HBoxContainer.new()
	rune_hero_detail_columns.add_theme_constant_override("separation", 14)
	box.add_child(rune_hero_detail_columns)
	rune_hero_detail_text = RichTextLabel.new()
	rune_hero_detail_text.bbcode_enabled = true
	rune_hero_detail_text.fit_content = true
	rune_hero_detail_text.scroll_active = false
	rune_hero_detail_text.custom_minimum_size = Vector2(880, 300)
	rune_hero_detail_text.add_theme_font_size_override("normal_font_size", 17)
	rune_hero_detail_text.add_theme_font_size_override("bold_font_size", 18)
	box.add_child(rune_hero_detail_text)
	rune_hero_detail_overlay.hide()

func _rune_stat_panel(title: String, accent: Color, hp: int, strategy: int, cooldown: float, delta_hp := 0, delta_strategy := 0, delta_cooldown := 0.0) -> PanelContainer:
	var stat_panel := PanelContainer.new()
	stat_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_style(stat_panel, Color("#10140fee"), 10, accent, 2)
	var stat_box := VBoxContainer.new()
	stat_box.add_theme_constant_override("separation", 8)
	stat_panel.add_child(stat_box)
	var title_label := _label(title, 18, accent)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_box.add_child(title_label)
	var rows: Array = [
		["生命", str(hp), delta_hp],
		["兵略", str(strategy), delta_strategy],
		["冷却", "%.1f秒" % cooldown, delta_cooldown],
	]
	for row in rows:
		var row_box := HBoxContainer.new()
		row_box.add_theme_constant_override("separation", 8)
		var key := _label(str(row[0]), 17, Color("#c9c0b1"))
		key.custom_minimum_size.x = 52
		row_box.add_child(key)
		var value := _label(str(row[1]), 21, Color("#e8e2cf"))
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_box.add_child(value)
		var delta := float(row[2])
		if absf(delta) >= 0.05:
			var delta_text := ("+%.0f" % delta) if absf(delta) >= 1.0 else ("%+.1f" % delta)
			var is_cooldown := str(row[0]) == "冷却"
			var is_gain := (delta < 0.0) if is_cooldown else (delta > 0.0)
			var delta_label := _label(delta_text + ("秒" if is_cooldown else ""), 15, Color("#90c59e") if is_gain else Color("#df7878"))
			row_box.add_child(delta_label)
		stat_box.add_child(row_box)
	return stat_panel

func _hide_rune_hero_detail() -> void:
	if is_instance_valid(rune_hero_detail_overlay):
		rune_hero_detail_overlay.hide()

func _show_rune_hero_detail() -> void:
	var hero_id := _selected_rune_hero()
	if hero_id.is_empty() or not is_instance_valid(rune_hero_detail_text) or not is_instance_valid(rune_hero_detail_columns): return
	var hero: Dictionary = heroes[hero_id]
	var base_hp := float(hero.hp)
	var base_strategy := float(hero.skill_value)
	var base_cooldown := float(hero.cooldown)
	var talent := _talent_stat_bonus(hero_id)
	var runes := _rune_stat_bonus(hero_id)
	var rune_hp := maxf(float(runes.hp), -base_hp * 0.30)
	var talent_hp := base_hp + float(talent.hp)
	var talent_strategy := base_strategy + float(talent.strategy)
	var progression_cap := base_cooldown * 0.5
	var talent_cooldown := maxf(2.0, base_cooldown - minf(float(talent.cooldown), progression_cap))
	var final_hp := base_hp + float(talent.hp) + rune_hp
	var final_strategy := base_strategy + float(talent.strategy) + float(runes.strategy)
	var final_cooldown := maxf(2.0, base_cooldown - minf(float(talent.cooldown) + float(runes.cooldown), progression_cap))
	_clear_dynamic_children(rune_hero_detail_columns)
	rune_hero_detail_columns.add_child(_rune_stat_panel("初始属性", Color("#7a9b6a"), roundi(base_hp), roundi(base_strategy), base_cooldown))
	rune_hero_detail_columns.add_child(_rune_stat_panel("天赋加成", Color("#b98a4f"), roundi(talent_hp), roundi(talent_strategy), talent_cooldown, roundi(talent.hp), roundi(talent.strategy), -minf(float(talent.cooldown), progression_cap)))
	rune_hero_detail_columns.add_child(_rune_stat_panel("天赋 + 符文", Color("#c56a5a"), roundi(final_hp), roundi(final_strategy), final_cooldown, roundi(float(talent.hp) + rune_hp), roundi(float(talent.strategy) + float(runes.strategy)), -minf(float(talent.cooldown) + float(runes.cooldown), progression_cap)))
	rune_hero_detail_text.text = _rune_hero_detail_content(hero_id, final_strategy)
	rune_hero_detail_overlay.show()

func _resolve_strategy_numbers(text: String, strategy: float) -> String:
	# 把 "N%兵略值" 换算成具体点数,"N×/N*兵略值%" 换算成具体百分比。
	var percent := RegEx.new()
	percent.compile("(\\d+(?:\\.\\d+)?)%兵略值")
	var output := ""
	var last := 0
	for m in percent.search_all(text):
		var value := roundi(strategy * float(m.get_string(1)) / 100.0)
		output += text.substr(last, m.get_start() - last) + str(value) + "点"
		last = m.get_end()
	output += text.substr(last)
	var ratio := RegEx.new()
	ratio.compile("(\\d+(?:\\.\\d+)?)[×*]兵略值%")
	var output2 := ""
	last = 0
	for m in ratio.search_all(output):
		var value := roundi(float(m.get_string(1)) * strategy)
		output2 += output.substr(last, m.get_start() - last) + "+" + str(value) + "%"
		last = m.get_end()
	output2 += output.substr(last)
	return output2

func _rune_hero_detail_content(hero_id: String, final_strategy: float) -> String:
	var bb := ""
	bb += "[color=#90c59e][b]技能（按最终兵略 %d 换算）[/b][/color]\n" % roundi(final_strategy)
	bb += _resolve_strategy_numbers(_skill_detail(hero_id), final_strategy)
	var bond_text := _hero_bond_detail(hero_id)
	var bond_parts := bond_text.split("\n\n")
	if bond_parts.size() > 1 and str(bond_parts[bond_parts.size() - 1]).begins_with("阵营羁绊"):
		bond_parts.remove_at(bond_parts.size() - 1)
	if not bond_parts.is_empty():
		bb += "\n\n[color=#90c59e][b]羁绊（按最终兵略换算）[/b][/color]\n"
		bb += _resolve_strategy_numbers("\n\n".join(bond_parts), final_strategy)
	return bb

func _show_runes() -> void:
	rune_overlay.show()
	_render_runes()

func _selected_rune_hero() -> String:
	if not is_instance_valid(rune_hero_options) or rune_hero_options.item_count <= 0: return home_hero_id
	return str(rune_hero_options.get_item_metadata(rune_hero_options.selected))

func _populate_rune_heroes(faction: String, preferred := "") -> void:
	rune_hero_options.clear()
	var hero_ids: Array = heroes.keys().filter(func(hero_id): return str(heroes[hero_id].f) == faction)
	hero_ids.sort_custom(func(a, b): return _hero_name(str(a)) < _hero_name(str(b)))
	for hero_id in hero_ids:
		rune_hero_options.add_item(_hero_name(str(hero_id)))
		rune_hero_options.set_item_metadata(rune_hero_options.item_count - 1, str(hero_id))
		if str(hero_id) == preferred: rune_hero_options.select(rune_hero_options.item_count - 1)

func _on_rune_faction_selected(index: int) -> void:
	var faction := str(rune_faction_options.get_item_metadata(index))
	_populate_rune_heroes(faction)
	_render_runes()

func _set_rune_tier_filter(tier: int) -> void:
	rune_tier_filter = clampi(tier, 0, 6)
	_render_runes()

func _set_rune_class_filter(rune_class: String) -> void:
	rune_class_filter = rune_class if rune_class in ["正", "均", "极"] else ""
	_render_runes()

func _rune_equipped_hero(uid: int) -> String:
	for hero_id in rune_loadouts:
		if (rune_loadouts[hero_id] as Array).has(uid): return str(hero_id)
	return ""

func _render_runes(message := "") -> void:
	_clear_dynamic_children(rune_inventory_box)
	_clear_dynamic_children(rune_equipped_box)
	rune_resource_label.text = "将魂 %d　符文总数 %d　（每名武将最多装备 6 枚）" % [general_souls, rune_inventory.size()]
	var hero_id := _selected_rune_hero()
	if hero_id.is_empty(): return
	rune_hero_portrait.texture = _portrait_source_texture(hero_id)
	var equipped: Array = rune_loadouts.get(hero_id, [])
	rune_equipped_box.add_child(_label("已装备 %d / 6" % equipped.size(), 17, Color("#f0c77a")))
	var equipped_grid := GridContainer.new()
	equipped_grid.columns = 2
	equipped_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipped_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	equipped_grid.add_theme_constant_override("h_separation", 8)
	equipped_grid.add_theme_constant_override("v_separation", 8)
	rune_equipped_box.add_child(equipped_grid)
	for uid in equipped:
		var rune = _rune_by_uid(int(uid))
		if rune == null: continue
		var tier_data: Dictionary = RUNE_TIERS[int(rune.tier) - 1]
		var equipped_panel := PanelContainer.new()
		equipped_panel.custom_minimum_size = Vector2(0, 64)
		equipped_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		equipped_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		_style(equipped_panel, Color("#141815"), 5, Color(str(tier_data.hex)), 2)
		var equipped_row := HBoxContainer.new()
		equipped_row.add_theme_constant_override("separation", 8)
		var equipped_gem := _label("◆", 20, Color(str(tier_data.hex)))
		equipped_gem.custom_minimum_size.x = 26
		equipped_gem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		equipped_gem.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		equipped_gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		equipped_row.add_child(equipped_gem)
		var equipped_text := _label(_rune_display_name(rune), 14, Color(str(tier_data.hex)).lightened(0.22))
		equipped_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		equipped_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		equipped_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		equipped_text.tooltip_text = _rune_description(rune)
		equipped_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		equipped_row.add_child(equipped_text)
		var remove := _button("卸下")
		remove.custom_minimum_size = Vector2(60, 36)
		remove.add_theme_font_size_override("font_size", 13)
		remove.pressed.connect(_on_unequip_rune.bind(hero_id, int(uid)))
		equipped_row.add_child(remove)
		equipped_panel.add_child(equipped_row)
		equipped_grid.add_child(equipped_panel)
	if equipped.is_empty(): rune_equipped_box.add_child(_label("暂无装备符文", 15, Color("#887e70")))
	# 同类符文合并:阶级相同且种类相同为同类,只显示一张卡片并标注可用数量(佩戴后数量减少)
	var rune_groups := {}
	var available_total := 0
	for rune in rune_inventory:
		var tier_matches := rune_tier_filter == 0 or int(rune.tier) == rune_tier_filter
		var class_matches := rune_class_filter.is_empty() or str(_rune_kind(str(rune.kind)).get("class", "")) == rune_class_filter
		if not (tier_matches and class_matches): continue
		var owner := _rune_equipped_hero(int(rune.uid))
		var group_key := "%d|%s" % [int(rune.tier), str(rune.kind)]
		if not rune_groups.has(group_key):
			rune_groups[group_key] = {"tier":int(rune.tier), "kind":str(rune.kind), "available":[], "hero_uid":0, "hero_count":0}
		var group: Dictionary = rune_groups[group_key]
		if owner.is_empty():
			group.available.append(rune)
			available_total += 1
		elif owner == hero_id:
			group.hero_count = int(group.hero_count) + 1
			if int(group.hero_uid) == 0: group.hero_uid = int(rune.uid)
	var group_list: Array = rune_groups.values().filter(func(g): return not (g.available as Array).is_empty() or int(g.hero_count) > 0)
	group_list.sort_custom(func(a, b):
		if int(a.tier) != int(b.tier): return int(a.tier) > int(b.tier)
		var class_order := ["正", "均", "极"]
		var a_class := str(_rune_kind(str(a.kind)).get("class", ""))
		var b_class := str(_rune_kind(str(b.kind)).get("class", ""))
		if class_order.find(a_class) != class_order.find(b_class): return class_order.find(a_class) < class_order.find(b_class)
		return str(a.kind) < str(b.kind)
	)
	var filter_name := "全部" if rune_tier_filter == 0 else str(RUNE_TIERS[rune_tier_filter - 1].name)
	var type_filter_name := "全部类型" if rune_class_filter.is_empty() else rune_class_filter + "符文"
	rune_status_label.text = message if not message.is_empty() else "%s · %s：%d 类 · 可用 %d 枚。批量合成会包含并自动卸下已装备的同阶符文。" % [filter_name, type_filter_name, group_list.size(), available_total]
	rune_batch_synthesize_button.visible = rune_tier_filter in [1, 2, 3, 4, 5]
	if rune_batch_synthesize_button.visible:
		var tier_count := rune_inventory.filter(func(rune): return int(rune.tier) == rune_tier_filter).size()
		rune_batch_synthesize_button.text = "全部合成（%d → %d）" % [tier_count, int(tier_count / 2)]
		rune_batch_synthesize_button.disabled = tier_count < 2
	for index in rune_filter_buttons.size():
		rune_filter_buttons[index].modulate = Color("#f0c77a") if index == rune_tier_filter else Color.WHITE
	var selected_class_index := ["", "正", "均", "极"].find(rune_class_filter)
	for index in rune_class_filter_buttons.size():
		rune_class_filter_buttons[index].modulate = Color("#f0c77a") if index == selected_class_index else Color.WHITE
	for group in group_list:
		var available: Array = group.available
		var tier_data: Dictionary = RUNE_TIERS[int(group.tier) - 1]
		var sample: Dictionary = available[0] if not available.is_empty() else _rune_by_uid(int(group.hero_uid))
		if sample == null: continue
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(0, 132)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
		_style(panel, Color("#131713ee"), 6, Color(str(tier_data.hex)).darkened(0.12), 2)
		var card_box := VBoxContainer.new()
		card_box.mouse_filter = Control.MOUSE_FILTER_PASS
		card_box.add_theme_constant_override("separation", 7)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_theme_constant_override("separation", 12)
		var rune_class := str(_rune_kind(str(group.kind)).get("class", ""))
		var gem := _label("◆", 38, Color(str(tier_data.hex)))
		gem.custom_minimum_size.x = 46
		gem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gem.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(gem)
		var info := _label(_rune_display_name(sample) + "　[" + rune_class + "]", 18, Color(str(tier_data.hex)).lightened(0.22))
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		info.tooltip_text = _rune_description(sample)
		row.add_child(info)
		var count_label := _label("×%d" % available.size(), 22, Color("#f0c77a"))
		count_label.custom_minimum_size.x = 64
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_label.tooltip_text = "可用数量（未被任何武将佩戴）"
		row.add_child(count_label)
		card_box.add_child(row)
		var desc := _label(_rune_description(sample), 15, Color("#b9b2a2"))
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_box.add_child(desc)
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 8)
		if int(group.hero_count) > 0:
			var owned_tag := _label("已装备 ×%d" % int(group.hero_count), 15, Color("#90c59e"))
			owned_tag.custom_minimum_size.x = 92
			owned_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			owned_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			actions.add_child(owned_tag)
		else:
			var spacer := Control.new()
			spacer.custom_minimum_size.x = 92
			actions.add_child(spacer)
		var convert_cost := int(RUNE_TIERS[int(group.tier) - 1].convert)
		convert_cost = ceili(convert_cost * (1.0 - 0.10 * _talent_level("all", "百炼")))
		var convert := _button("转换 %d" % convert_cost)
		convert.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		convert.custom_minimum_size.y = 44
		convert.add_theme_font_size_override("font_size", 16)
		convert.mouse_filter = Control.MOUSE_FILTER_PASS
		convert.disabled = available.is_empty() or general_souls < convert_cost
		if not available.is_empty(): convert.pressed.connect(_on_convert_rune.bind(int(available[0].uid)))
		actions.add_child(convert)
		var equip := _button("装备")
		equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		equip.custom_minimum_size.y = 44
		equip.add_theme_font_size_override("font_size", 16)
		_accent_button(equip, Color(str(tier_data.hex)))
		equip.mouse_filter = Control.MOUSE_FILTER_PASS
		equip.disabled = available.is_empty() or equipped.size() >= 6
		if not available.is_empty(): equip.pressed.connect(_on_equip_rune.bind(hero_id, int(available[0].uid)))
		actions.add_child(equip)
		if int(group.hero_count) > 0:
			var remove := _button("卸下")
			remove.custom_minimum_size = Vector2(96, 44)
			remove.add_theme_font_size_override("font_size", 16)
			remove.pressed.connect(_on_unequip_rune.bind(hero_id, int(group.hero_uid)))
			actions.add_child(remove)
		card_box.add_child(actions)
		panel.add_child(card_box)
		rune_inventory_box.add_child(panel)
	if group_list.is_empty():
		var empty := _label("当前分类暂无符文。", 20, Color("#887e70"))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rune_inventory_box.add_child(empty)

func _on_draw_runes(count: int) -> void:
	var results := _draw_runes(count)
	if results.is_empty():
		_render_runes("将魂不足，%d 连抽需要 %d 将魂。" % [count, count * RUNE_DRAW_COST])
		return
	if count == 1:
		_render_runes("抽取完成：" + _rune_display_name(results[0]) + "　" + _rune_description(results[0]))
	else:
		var tier_counts := [0, 0, 0, 0, 0, 0]
		for rune in results: tier_counts[int(rune.tier) - 1] += 1
		var summary: Array[String] = []
		for tier in range(1, 7):
			if tier_counts[tier - 1] > 0: summary.append(str(RUNE_TIERS[tier - 1].name) + " ×" + str(tier_counts[tier - 1]))
		_render_runes("十连抽完成：" + "　".join(summary))

func _on_synthesize_current_tier() -> void:
	var result := _synthesize_all_runes(rune_tier_filter)
	var created: Array = result.created
	if created.is_empty():
		_render_runes("当前阶至少需要两枚符文才能合成。")
	else:
		_render_runes("批量合成完成：消耗 %d 枚，获得 %d 枚%s符文。" % [int(result.consumed), created.size(), str(RUNE_TIERS[rune_tier_filter].name)])

func _on_convert_rune(uid: int) -> void:
	var result = _convert_rune(uid)
	_render_runes("将魂不足。" if result == null else "转换完成：" + _rune_display_name(result))

func _on_equip_rune(hero_id: String, uid: int) -> void:
	_equip_rune(hero_id, uid)
	_render_runes()

func _on_unequip_rune(hero_id: String, uid: int) -> void:
	_unequip_rune(hero_id, uid)
	_render_runes()

func _build_talent_overlay() -> void:
	talent_overlay = _full_overlay(1150, PremiumUIArt.Variant.TALENT, Color("#987030"))
	var root := _overlay_panel(talent_overlay, "天赋", func(): talent_overlay.hide(); _refresh_home())
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	root.add_child(content)
	var navigation_panel := PanelContainer.new()
	navigation_panel.custom_minimum_size.x = 220
	_style(navigation_panel, Color("#111511ed"), 5, Color("#665535"), 2)
	var navigation := VBoxContainer.new()
	navigation.add_theme_constant_override("separation", 9)
	navigation_panel.add_child(navigation)
	var resource_caption := _label("天赋资源", 14, Color("#9e8769"))
	resource_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	navigation.add_child(resource_caption)
	talent_resource_label = _label("", 17, Color("#e8c96e"))
	talent_resource_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	talent_resource_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	talent_resource_label.custom_minimum_size.y = 64
	navigation.add_child(talent_resource_label)
	navigation.add_child(HSeparator.new())
	for tree_id in ["all", "shu", "wei", "wu", "qun"]:
		var tab := _button(str(TALENT_TREES[tree_id].name))
		tab.custom_minimum_size.y = 58
		tab.add_theme_font_size_override("font_size", 18)
		var faction := str(TALENT_TREES[tree_id].faction)
		var tab_color: Color = Color("#b98a4f") if faction.is_empty() else FACTION_COLORS[faction]
		_accent_button(tab, tab_color, tree_id == "all")
		tab.pressed.connect(_select_talent_tree.bind(tree_id))
		talent_tree_tabs[tree_id] = tab
		navigation.add_child(tab)
	var nav_spacer := Control.new()
	nav_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	navigation.add_child(nav_spacer)
	var reset := _button("↻　重置本树")
	_accent_button(reset, Color("#886449"))
	reset.pressed.connect(_on_reset_talent_tree)
	navigation.add_child(reset)
	content.add_child(navigation_panel)
	var tree_panel := PanelContainer.new()
	tree_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style(tree_panel, Color("#11130fe3"), 5, Color("#796137"), 2)
	var tree_host := Control.new()
	tree_host.custom_minimum_size = Vector2(850, 650)
	tree_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_panel.add_child(tree_host)
	talent_tree_canvas = PremiumUIArt.new()
	talent_tree_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	talent_tree_canvas.configure(PremiumUIArt.Variant.TALENT, Color("#c0903e"))
	tree_host.add_child(talent_tree_canvas)
	talent_content_box = Control.new()
	talent_content_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree_host.add_child(talent_content_box)
	content.add_child(tree_panel)
	var detail_panel := PanelContainer.new()
	detail_panel.custom_minimum_size.x = 330
	_style(detail_panel, Color("#211b12f2"), 5, Color("#a37a48"), 2)
	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 10)
	detail_box.add_child(_label("天赋详情", 24, Color("#d8b96f")))
	talent_detail_label = _label("点击任一天赋节点查看完整效果。", 16, Color("#ead9b5"))
	talent_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	talent_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	talent_detail_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	detail_box.add_child(talent_detail_label)
	var detail_hint := _label("选择节点查看完整效果\n满足前置后可消耗 2 将星升级", 13, Color("#8f816e"))
	detail_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(detail_hint)
	detail_panel.add_child(detail_box)
	content.add_child(detail_panel)

func _show_talents() -> void:
	talent_overlay.show()
	_render_talents()

func _select_talent_tree(tree_id: String) -> void:
	talent_tree_id = tree_id
	talent_detail_label.text = str(TALENT_TREES[tree_id].name) + "：点击节点查看完整效果与当前等级。"
	_render_talents()

func _render_talents(message := "") -> void:
	_clear_dynamic_children(talent_content_box)
	var invested := 0
	for node in TALENT_TREES[talent_tree_id].nodes: invested += _talent_level(talent_tree_id, str(node[0]))
	talent_resource_label.text = "★ 将星 %d / 300\n%s · %d 点" % [general_stars, str(TALENT_TREES[talent_tree_id].name), invested]
	if not message.is_empty(): talent_detail_label.text = message
	var layer_colors := [Color("#365d43"), Color("#3d6b5c"), Color("#41627a"), Color("#765585"), Color("#9a6b32")]
	var canvas_size := talent_content_box.size
	if canvas_size.x < 500.0 or canvas_size.y < 500.0:
		canvas_size = Vector2(850, 650)
	var tree_points := {}
	for layer in range(1, 6):
		var layer_color: Color = layer_colors[layer - 1]
		var layer_nodes: Array = TALENT_TREES[talent_tree_id].nodes.filter(func(node): return int(node[1]) == layer)
		if layer_nodes.is_empty(): continue
		var requirement := int(layer_nodes[0][6])
		var unlocked := _talent_points_before_layer(talent_tree_id, layer) >= requirement
		var y := canvas_size.y - 116.0 - float(layer - 1) * 122.0
		var node_width := minf(184.0, (canvas_size.x - 115.0) / float(layer_nodes.size()) - 8.0)
		var layer_node_size := Vector2(node_width, 102)
		var layer_caption := _label("第%d层 · %s" % [layer, "冠冕" if layer == 5 else ("枝干" if layer >= 3 else "根基")], 13, layer_color.lightened(0.38) if unlocked else Color("#746f66"))
		layer_caption.position = Vector2(14, y + 35)
		layer_caption.custom_minimum_size = Vector2(105, 26)
		talent_content_box.add_child(layer_caption)
		var points: Array = []
		for node_index in layer_nodes.size():
			var node: Array = layer_nodes[node_index]
			var x := canvas_size.x * float(node_index + 1) / float(layer_nodes.size() + 1)
			var level := _talent_level(talent_tree_id, str(node[0]))
			var node_panel := PanelContainer.new()
			node_panel.position = Vector2(x - layer_node_size.x * 0.5, y)
			node_panel.custom_minimum_size = layer_node_size
			node_panel.size = layer_node_size
			_style(node_panel, layer_color.darkened(0.50) if unlocked else Color("#1b1b19"), 50, layer_color.lightened(0.28) if unlocked else Color("#4e4b46"), 3)
			var node_box := VBoxContainer.new()
			node_box.add_theme_constant_override("separation", 2)
			var detail := Button.new()
			detail.flat = true
			detail.text = ("%s　%d / %d" % [str(node[0]), level, int(node[2])]) if unlocked else ("🔒 " + str(node[0]))
			detail.custom_minimum_size.y = 28
			detail.add_theme_font_size_override("font_size", 16)
			detail.add_theme_color_override("font_color", Color("#fff0c9") if unlocked else Color("#7b7770"))
			detail.tooltip_text = _talent_effect_description(talent_tree_id, str(node[0]))
			detail.pressed.connect(_show_talent_detail.bind(talent_tree_id, str(node[0])))
			node_box.add_child(detail)
			var effect_text := _label(_talent_effect_description(talent_tree_id, str(node[0])), 11, Color("#d9d0bf") if unlocked else Color("#6c6963"))
			effect_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			effect_text.max_lines_visible = 2
			effect_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			effect_text.custom_minimum_size.y = 31
			effect_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			node_box.add_child(effect_text)
			var upgrade := _button("升级 · 2 将星")
			upgrade.custom_minimum_size.y = 28
			upgrade.add_theme_font_size_override("font_size", 12)
			_accent_button(upgrade, layer_color)
			upgrade.disabled = not _can_upgrade_talent(talent_tree_id, str(node[0]))
			upgrade.pressed.connect(_on_upgrade_talent.bind(talent_tree_id, str(node[0])))
			node_box.add_child(upgrade)
			node_panel.add_child(node_box)
			talent_content_box.add_child(node_panel)
			points.append(Vector2(x, y + layer_node_size.y * 0.5))
		tree_points[layer] = points
	if is_instance_valid(talent_tree_canvas) and talent_tree_canvas.has_method("set_tree_points"):
		talent_tree_canvas.set_tree_points(tree_points)
	for tree_id in talent_tree_tabs:
		var tab: Button = talent_tree_tabs[tree_id]
		tab.modulate = Color.WHITE if tree_id == talent_tree_id else Color(0.68, 0.68, 0.68, 0.82)

func _show_talent_detail(tree_id: String, node_name: String) -> void:
	var node := _talent_node(tree_id, node_name)
	var level := _talent_level(tree_id, node_name)
	talent_detail_label.text = "%s · %s　当前 %d / %d 级\n%s" % [str(TALENT_TREES[tree_id].name), node_name, level, int(node[2]), _talent_effect_description(tree_id, node_name)]

func _on_upgrade_talent(tree_id: String, node_name: String) -> void:
	_upgrade_talent(tree_id, node_name)
	_render_talents()

func _on_reset_talent_tree() -> void:
	var refunded := _reset_talent_tree(talent_tree_id)
	_render_talents("已返还 %d 颗将星。" % refunded)

func _build_settings_overlay() -> void:
	settings_overlay = ColorRect.new()
	settings_overlay.color = UI_INK
	settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_overlay.z_index = 1200
	settings_overlay.hide()
	add_child(settings_overlay)
	_add_premium_art(settings_overlay, PremiumUIArt.Variant.BACKDROP, Color("#846d4a"))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 820)
	_style(panel, Color("#12120ff0"), 5, Color("#8e673d"), 2)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := _label(t("游戏设置", "SETTINGS"), 30, Color("#f0c77a"))
	title.add_theme_constant_override("outline_size", 5)
	title.add_theme_color_override("font_outline_color", Color("#1a1008"))
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
	enemy_strategy_setting_options = OptionButton.new()
	enemy_strategy_setting_options.custom_minimum_size = Vector2(360, 48)
	for i in range(21):
		enemy_strategy_setting_options.add_item(t("敌方兵略值：", "Enemy Strategy: ") + str(100 + i * 5), i)
	enemy_strategy_setting_options.item_selected.connect(_set_enemy_strategy)
	box.add_child(enemy_strategy_setting_options)
	tianshu_refresh_setting_button = _button("")
	tianshu_refresh_setting_button.custom_minimum_size = Vector2(360, 48)
	tianshu_refresh_setting_button.pressed.connect(_toggle_tianshu_refresh_setting)
	box.add_child(tianshu_refresh_setting_button)
	challenge_limit_setting_button = _button("")
	challenge_limit_setting_button.custom_minimum_size = Vector2(360, 48)
	challenge_limit_setting_button.pressed.connect(_toggle_challenge_limit_setting)
	box.add_child(challenge_limit_setting_button)
	var resource_row := HBoxContainer.new()
	resource_row.alignment = BoxContainer.ALIGNMENT_CENTER
	resource_row.add_theme_constant_override("separation", 10)
	var add_souls := _button("增加将魂 +10000")
	_accent_button(add_souls, Color("#4c8b66"))
	add_souls.pressed.connect(_on_add_debug_souls)
	resource_row.add_child(add_souls)
	var add_stars := _button("增加将星 +100")
	_accent_button(add_stars, Color("#b78a43"))
	add_stars.pressed.connect(_on_add_debug_stars)
	resource_row.add_child(add_stars)
	box.add_child(resource_row)
	var lab_button := _button("平衡实验室")
	_accent_button(lab_button, Color("#705f8f"))
	lab_button.custom_minimum_size = Vector2(360, 46)
	lab_button.pressed.connect(func(): settings_overlay.hide(); _show_balance_lab())
	box.add_child(lab_button)
	var close := _button(t("保存并返回", "SAVE & BACK"))
	_accent_button(close, Color("#b98a4f"), true)
	close.custom_minimum_size = Vector2(240, 48)
	close.pressed.connect(_close_settings)
	box.add_child(close)
	_refresh_settings_ui()

func _show_settings() -> void:
	_refresh_settings_ui()
	settings_overlay.show()

func _on_add_debug_souls() -> void:
	_add_debug_souls()
	_refresh_home()

func _on_add_debug_stars() -> void:
	_add_debug_stars()
	_refresh_home()

func _toggle_challenge_limit_setting() -> void:
	limit_challenges = not limit_challenges
	_save_settings()
	_refresh_settings_ui()
	if is_instance_valid(battle_menu_overlay) and battle_menu_overlay.visible: _render_stage_grid()

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
	if is_instance_valid(enemy_strategy_setting_options):
		for i in range(21):
			enemy_strategy_setting_options.set_item_text(i, t("敌方兵略值：", "Enemy Strategy: ") + str(100 + i * 5))
		enemy_strategy_setting_options.select(int(enemy_strategy_bonus / 5))
	if is_instance_valid(tianshu_refresh_setting_button):
		tianshu_refresh_setting_button.text = t("天书无限刷新（调试）：开启", "Infinite codex refresh (debug): ON") if tianshu_infinite_refresh else t("天书无限刷新（调试）：关闭", "Infinite codex refresh (debug): OFF")
	if is_instance_valid(challenge_limit_setting_button):
		challenge_limit_setting_button.text = "闯关解锁限制：开启" if limit_challenges else "闯关解锁限制：关闭（全部开放）"

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

func _set_enemy_strategy(index: int) -> void:
	enemy_strategy_bonus = clampi(index * 5, 0, 100)
	_save_settings()
	_refresh_settings_ui()

func _toggle_tianshu_refresh_setting() -> void:
	tianshu_infinite_refresh = not tianshu_infinite_refresh
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
		enemy_strategy_bonus = clampi(int(config.get_value("battle", "enemy_strategy_bonus", 0)), 0, 100)
		tianshu_infinite_refresh = bool(config.get_value("debug", "tianshu_infinite_refresh", false))
		limit_challenges = bool(config.get_value("battle", "limit_challenges", true))
	battle_speed = game_speed

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("battle", "pause_during_actions", pause_during_actions)
	config.set_value("battle", "speed", game_speed)
	config.set_value("battle", "draft_faction_filter", draft_faction_filter)
	config.set_value("battle", "enemy_faction_filter", enemy_faction_filter)
	config.set_value("interface", "show_hero_codex_images", show_hero_codex_images)
	config.set_value("interface", "board_side", board_side)
	config.set_value("battle", "enemy_strategy_bonus", enemy_strategy_bonus)
	config.set_value("debug", "tianshu_infinite_refresh", tianshu_infinite_refresh)
	config.set_value("battle", "limit_challenges", limit_challenges)
	config.save(SETTINGS_PATH)

func _build_encyclopedia() -> void:
	var mobile := _is_mobile_ui()
	encyclopedia_overlay = ColorRect.new()
	encyclopedia_overlay.color = UI_INK
	encyclopedia_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	encyclopedia_overlay.z_index = 1100
	encyclopedia_overlay.hide()
	add_child(encyclopedia_overlay)
	_add_premium_art(encyclopedia_overlay, PremiumUIArt.Variant.BACKDROP, Color("#8f6f42"))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12 if mobile else 34)
	margin.add_theme_constant_override("margin_right", 12 if mobile else 34)
	margin.add_theme_constant_override("margin_top", 12 if mobile else 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	encyclopedia_overlay.add_child(margin)
	var panel := PanelContainer.new()
	_style(panel, Color("#12110fed"), 5, Color("#8e673d"), 2)
	margin.add_child(panel)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 12)
	panel.add_child(root_box)
	var header := HBoxContainer.new()
	encyclopedia_title_label = _label(t("武将图鉴", "HERO CODEX"), 25 if mobile else 28, Color("#f0c77a"))
	encyclopedia_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(encyclopedia_title_label)
	encyclopedia_hero_tab_button = _button(t("武将图鉴", "HERO CODEX"))
	_accent_button(encyclopedia_hero_tab_button, Color("#b98a4f"), true)
	encyclopedia_hero_tab_button.custom_minimum_size = Vector2(150, 42)
	encyclopedia_hero_tab_button.pressed.connect(_set_encyclopedia_mode.bind("heroes"))
	header.add_child(encyclopedia_hero_tab_button)
	encyclopedia_weapon_tab_button = _button(t("武器图鉴", "WEAPON CODEX"))
	_accent_button(encyclopedia_weapon_tab_button, Color("#8d744d"))
	encyclopedia_weapon_tab_button.custom_minimum_size = Vector2(150, 42)
	encyclopedia_weapon_tab_button.pressed.connect(_set_encyclopedia_mode.bind("weapons"))
	header.add_child(encyclopedia_weapon_tab_button)
	encyclopedia_bond_tab_button = _button(t("羁绊图", "BOND GRAPH"))
	_accent_button(encyclopedia_bond_tab_button, Color("#705f8f"))
	encyclopedia_bond_tab_button.custom_minimum_size = Vector2(135, 42)
	encyclopedia_bond_tab_button.pressed.connect(_set_encyclopedia_mode.bind("bonds"))
	header.add_child(encyclopedia_bond_tab_button)
	encyclopedia_tianshu_tab_button = _button(t("天书图鉴", "TIANSHU CODEX"))
	_accent_button(encyclopedia_tianshu_tab_button, Color("#4f8f9f"))
	encyclopedia_tianshu_tab_button.custom_minimum_size = Vector2(135, 42)
	encyclopedia_tianshu_tab_button.pressed.connect(_set_encyclopedia_mode.bind("tianshu"))
	header.add_child(encyclopedia_tianshu_tab_button)
	var close_button := _button(t("返回主菜单", "BACK"))
	_accent_button(close_button, Color("#607b95"))
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
		_accent_button(faction_button, FACTION_COLORS[faction])
		faction_button.custom_minimum_size = Vector2(90, 42)
		faction_button.pressed.connect(_set_encyclopedia_faction.bind(faction))
		encyclopedia_hero_filters.add_child(faction_button)
	encyclopedia_tianshu_filters = HBoxContainer.new()
	encyclopedia_tianshu_filters.add_theme_constant_override("separation", 8)
	root_box.add_child(encyclopedia_tianshu_filters)
	var tianshu_filter_spacer := Control.new()
	tianshu_filter_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	encyclopedia_tianshu_filters.add_child(tianshu_filter_spacer)
	for faction in ["all", "shu", "wei", "wu", "qun"]:
		var filter_name := t("通用", "GENERAL") if faction == "all" else _faction_name(faction)
		var faction_color: Color = Color("#c9a24c") if faction == "all" else FACTION_COLORS[faction]
		var faction_button := _button(filter_name)
		_accent_button(faction_button, faction_color)
		faction_button.custom_minimum_size = Vector2(78 if mobile else 96, 42)
		faction_button.pressed.connect(_set_encyclopedia_tianshu_faction.bind(faction))
		encyclopedia_tianshu_filter_buttons[faction] = faction_button
		encyclopedia_tianshu_filters.add_child(faction_button)
	encyclopedia_tianshu_filters.hide()
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
	if mobile:
		encyclopedia_grid.set_meta("touch_scroll_enabled", true)
		encyclopedia_grid.gui_input.connect(_on_touch_scroll_input.bind(encyclopedia_content_scroll, false, true))
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
	if mode not in ["heroes", "weapons", "bonds", "tianshu"]: return
	_hide_encyclopedia_preview()
	encyclopedia_mode = mode
	_render_encyclopedia()

func _set_encyclopedia_faction(faction: String) -> void:
	_hide_encyclopedia_preview()
	encyclopedia_faction = faction
	_render_encyclopedia()

func _set_encyclopedia_tianshu_faction(faction: String) -> void:
	if faction not in ["all", "shu", "wei", "wu", "qun"]: return
	encyclopedia_tianshu_faction = faction
	encyclopedia_content_scroll.scroll_vertical = 0
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
	var showing_tianshu := encyclopedia_mode == "tianshu"
	if showing_weapons:
		encyclopedia_title_label.text = t("蜀国武器图鉴", "SHU WEAPON CODEX")
	elif showing_bonds:
		encyclopedia_title_label.text = _faction_name(encyclopedia_faction) + t("国武将羁绊图", " BOND GRAPH")
	elif showing_tianshu:
		encyclopedia_title_label.text = t("天书图鉴", "TIANSHU CODEX")
	else:
		encyclopedia_title_label.text = t("武将图鉴", "HERO CODEX")
	encyclopedia_hero_tab_button.modulate = Color("#f0c77a") if encyclopedia_mode == "heroes" else Color.WHITE
	encyclopedia_weapon_tab_button.modulate = Color("#f0c77a") if showing_weapons else Color.WHITE
	encyclopedia_bond_tab_button.modulate = Color("#f0c77a") if showing_bonds else Color.WHITE
	encyclopedia_tianshu_tab_button.modulate = Color("#f0c77a") if showing_tianshu else Color.WHITE
	encyclopedia_hero_filters.visible = not (showing_weapons or showing_tianshu)
	encyclopedia_tianshu_filters.visible = showing_tianshu
	for faction in encyclopedia_tianshu_filter_buttons:
		var filter_button: Button = encyclopedia_tianshu_filter_buttons[faction]
		filter_button.modulate = Color("#f0c77a") if faction == encyclopedia_tianshu_faction else Color.WHITE
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
	if showing_tianshu:
		var filtered_count := TIANSHU_BOOKS.keys().filter(func(book_id): return _tianshu_codex_faction(TIANSHU_BOOKS[book_id]) == encyclopedia_tianshu_faction).size()
		var category_name := t("通用", "General") if encyclopedia_tianshu_faction == "all" else _faction_name(encyclopedia_tianshu_faction)
		encyclopedia_bond_label.text = t("%s天书 · 当前展示 %d 本，共收录 %d 本。首次选择获得一级，再次选到同名天书升级为二级。" % [category_name, filtered_count, TIANSHU_BOOKS.size()], "%s codices · showing %d of %d. First pick grants level I; picking the same book again upgrades it to level II." % [category_name, filtered_count, TIANSHU_BOOKS.size()])
		_render_tianshu_encyclopedia()
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
		var hero_header := HBoxContainer.new()
		var hero_name := _label(_hero_name(hero_id), 24, FACTION_COLORS[hero.f].lightened(0.32))
		hero_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hero_header.add_child(hero_name)
		var home_button := _button("主页中" if hero_id == home_hero_id else "设为主页")
		home_button.custom_minimum_size = Vector2(96, 38)
		home_button.disabled = hero_id == home_hero_id
		home_button.pressed.connect(_on_set_home_hero.bind(str(hero_id)))
		hero_header.add_child(home_button)
		card_box.add_child(hero_header)
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

func _on_set_home_hero(hero_id: String) -> void:
	_set_home_hero(hero_id)
	_refresh_home()
	_render_encyclopedia()

func _bond_graph_data(faction: String) -> Dictionary:
	var data := {
		"shu":{
			"faction":["han_expedition", "蜀", "Shu", "2 / 5 / 8", "全体蜀将承伤降低2%/5%/8%。8人时，每次受伤叠加3%减伤，最多3层，每层持续3秒。", "All Shu heroes take 2%/5%/8% less damage. At 8, each hit adds 3% reduction up to 3 stacks, each lasting 3s."],
			"bonds":[
				["peach_garden", "桃园结义", "Peach Garden", ["liubei", "guanyu", "zhangfei"], "3人", "3 heroes", "刘备每秒治疗提高至200%兵略值；关羽按列斩实际伤害的30%自疗；张飞号令延长50%。", "Liu Bei heals at 200% Strategy per second; Guan Yu heals for 30% of actual cleave damage; Zhang Fei's command lasts 50% longer."],
				["five_tigers", "五虎上将", "Five Tigers", ["guanyu", "zhangfei", "zhaoyun", "huangzhong", "machao"], "5人", "5 heroes", "关羽列斩550%；张飞号令延长50%且增伤变为0.25×兵略值%；赵云增加1次连刺且每刺+100%；黄忠锁定前军造成1100%；马超施法后为同排友军提供兵略值。", "Empowers all five generals' signature skills."],
				["northern_dream", "夜梦北斗", "Northern Dream", ["liubei", "liushan"], "2人", "2 heroes", "刘备持续治疗时间延长30%；刘禅鼓舞改为同列友军获得0.18×兵略值%的增伤。", "Liu Bei's regeneration lasts 30% longer; Liu Shan empowers same-column allies at 0.18 × Strategy percent."],
				["wulong_han", "卧龙辅汉", "Wolong Aids Han", ["liubei", "zhugeliang"], "2人", "2 heroes", "刘备持续治疗目标承伤降低30%；诸葛亮每多命中一名武将，本次全部伤害提高4%。", "Liu Bei's regenerating target takes 30% less damage; Zhuge Liang gains 4% damage per additional hero hit."],
				["seven_charges", "七进七出", "Seven Charges", ["zhaoyun", "liushan"], "2人", "2 heroes", "赵云额外增加1次连刺并强攻敌方后军；刘禅赋予被鼓舞友军30%全能吸血。", "Zhao Yun gains 1 extra thrust and focuses the enemy rear; Liu Shan grants empowered allies 30% omnivamp."],
				["one_rider", "一骑当千", "One Rider", ["machao", "madai"], "2人", "2 heroes", "马超贯穿改为前军/中军/后军260%/300%/340%；马岱开场行动条充满。", "Ma Chao pierces for 260%/300%/340% by row; Ma Dai starts at full gauge."],
				["fated_enemies", "宿命之敌", "Fated Enemies", ["madai", "weiyan"], "2人", "2 heroes", "马岱命中目标在本回合额外承受0.3×兵略值%的伤害；魏延按本次伤害的6%治疗相邻及正后方友军。", "Ma Dai applies Strategy-scaled vulnerability for the round; Wei Yan heals adjacent and directly-behind allies for 6% of cast damage."],
				["flying_meteor", "飞火流星", "Flying Meteor", ["huangzhong", "weiyan"], "2人", "2 heroes", "黄忠箭击有30%概率造成2倍伤害；魏延释放技能后恢复本次实际伤害23%的生命。", "Huang Zhong has a 30% chance to deal double damage; Wei Yan heals for 23% of actual cast damage."],
				["dragon_phoenix", "卧龙凤雏", "Dragon and Phoenix", ["zhugeliang", "pangtong"], "2人", "2 heroes", "诸葛亮八阵额外影响四个斜对角；庞统目标增加至3个，连环传导提高至50%。", "Zhuge Liang adds four diagonals; Pang Tong gains a third target and 50% chain echo."],
				["expedition_legacy", "北伐传承", "Northern Expedition Legacy", ["zhugeliang", "jiangwei"], "2人", "2 heroes", "诸葛亮八阵额外影响左右同排格；姜维对主目标周围八格敌人造成100%兵略值伤害。", "Zhuge Liang adds horizontal tiles; Jiang Wei splashes all eight neighboring enemies for 100% Strategy."],
				["seven_captures", "七擒孟获", "Seven Captures", ["zhugeliang", "menghuo"], "2人", "2 heroes", "诸葛亮伤害提高20%并施加15秒火攻标记，再次命中标记者提高40%；孟获追加35%整排余震。", "Zhuge Liang gains 20%, marks for 15s, and gains 40% on marked targets; Meng Huo adds a 35% row aftershock."],
				["nanman_couple", "南蛮夫妇", "Nanman Couple", ["menghuo", "zhurong"], "2人", "2 heroes", "孟获强化对灼烧目标的震地；祝融飞刃向左右相邻格弹射50%兵略值伤害。", "Meng Huo's quake is empowered against burning targets; Zhurong bounces to horizontal neighbors for 50% Strategy."],
				["barbarian_reinforcement", "蛮王援军", "Barbarian Reinforcements", ["menghuo", "dailaidongzhu"], "2人", "2 heroes", "孟获压退整排行动条；带来洞主改为以320%兵略值攻击行动条最高目标所在整列。", "Meng Huo pushes back the row's gauges; Dailai strikes the highest-gauge target's column for 320% Strategy."],
				["sibling_bond", "姐弟同心", "Sibling Bond", ["dailaidongzhu", "zhurong"], "2人", "2 heroes", "祝融灼烧延长2秒并提高至每秒100%；带来洞主附加灼烧并对已灼烧目标追加50%兵略值伤害。", "Zhurong's burn gains 2s and rises to 100% per second; Dailai burns and adds 50% Strategy against burning targets."]
			]
		},
		"wei":{
			"faction":["wei_command", "魏", "Wei", "2 / 5 / 8", "全体魏将控制时长提高2%/5%/8%。8人时，对带有任意控制或减益的目标造成伤害提高8%。", "All Wei heroes gain 2%/5%/8% control duration. At 8, they deal 8% more damage to targets with any control or debuff."],
			"bonds":[
				["evil_of_old", "古之恶来", "Evil of Old", ["caocao", "dianwei"], "2人", "2 heroes", "曹操目标+1，命中后军时伤害增加100%兵略值、眩晕增加0.9秒；典韦目标+1、伤害减少30%兵略值。", "Cao Cao gains 1 target and, against rearguards, +100% Strategy damage and +0.9s stun; Dian Wei gains 1 target but loses 30% Strategy damage."],
				["tiger_guard", "虎卫护主", "Tiger Guard", ["caocao", "xuchu"], "2人", "2 heroes", "曹操目标+1，命中前军时伤害增加100%兵略值、眩晕增加0.9秒；许褚目标+1、伤害减少40%兵略值。", "Cao Cao gains 1 target and, against vanguards, +100% Strategy damage and +0.9s stun; Xu Chu gains 1 target but loses 40% Strategy damage."],
				["twin_wei_guards", "魏武双卫", "Twin Wei Guards", ["dianwei", "xuchu"], "2人", "2 heroes", "典韦伤害增加100%兵略值；许褚伤害增加150%兵略值。", "Dian Wei gains 100% Strategy damage; Xu Chu gains 150% Strategy damage."],
				["hefei_vanguard", "逍遥津先锋", "Hefei Vanguard", ["zhangliao", "yuejin"], "2人", "2 heroes", "张辽回旋刃每段伤害增加100%兵略值；乐进目标增加1名。", "Zhang Liao gains 100% Strategy damage per pass; Yue Jin gains 1 target."],
				["adaptive_vanguard", "巧变开山", "Adaptive Vanguard", ["zhanghe", "xuhuang"], "2人", "2 heroes", "张郃眩晕增加1.8秒；徐晃伤害增加80%兵略值。", "Zhang He gains 1.8s stun; Xu Huang gains 80% Strategy damage."],
				["five_elites", "五子良将", "Five Elite Generals", ["zhangliao", "yuejin", "zhanghe", "xuhuang", "yujin"], "5人", "5 heroes", "强化回旋刃易损、乱射重伤、连枪扩散、开山随机排控制与双目标护盾。", "Enhances Returning Blade vulnerability, Volley grievous wounds, spear chaining, random-row control, and two-target shields."],
				["swift_bulwark", "神速镇远", "Swift Bulwark", ["xiahouyuan", "caoren"], "2人", "2 heroes", "夏侯渊冷却-0.9秒、眩晕+0.9秒、伤害+50%；曹仁获得目标、眩晕与后军减伤强化。", "Xiahou Yuan gains cooldown, stun, and damage; Cao Ren gains target, stun, and rear reduction."],
				["xiahou_brothers", "夏侯同心", "Xiahou Brothers", ["xiahouyuan", "xiahoudun"], "2人", "2 heroes", "夏侯渊冷却-0.9秒、眩晕+0.9秒、伤害+50%；夏侯惇获得目标、眩晕与前军减伤强化。", "Xiahou Yuan gains cooldown, stun, and damage; Xiahou Dun gains target, stun, and vanguard reduction."],
				["twin_bulwarks", "魏武双壁", "Twin Bulwarks", ["caoren", "xiahoudun"], "2人", "2 heroes", "曹仁与夏侯惇各自目标+1、眩晕+0.9秒、对应兵种减伤+0.1*兵略值%。", "Cao Ren and Xiahou Dun each gain 1 target, +0.9s stun, and +0.1*Strategy% reduction against their guarded row."],
				["thunder_frost", "雷霆冰策", "Thunder and Frost", ["simayi", "guojia"], "2人", "2 heroes", "司马懿目标+1、伤害减少40%兵略值；郭嘉目标+1、冻结减少1.5秒。", "Sima Yi gains 1 target but loses 40% Strategy damage; Guo Jia gains 1 target but loses 1.5s freeze."],
				["thunder_royal", "鹰视王佐", "Eagle Eye and Royal Aid", ["simayi", "xunyu"], "2人", "2 heroes", "司马懿目标+1、伤害减少40%兵略值；荀彧目标+1、加速减少0.05×兵略值%。", "Sima Yi gains 1 target but loses 40% Strategy damage; Xun Yu gains 1 target but loses 0.05×Strategy% speed."],
				["thunder_venom", "鹰视毒谋", "Eagle Eye and Venom", ["simayi", "jiaxu"], "2人", "2 heroes", "司马懿伤害增加80%兵略值；贾诩中毒层数衰减改为45%。", "Sima Yi gains 80% Strategy damage; Jia Xu's poison stack decay becomes 45%."],
				["frost_royal", "遗计王佐", "Frozen Royal Plan", ["guojia", "xunyu"], "2人", "2 heroes", "郭嘉冻结增加2.1秒；荀彧加速增加0.12×兵略值%。", "Guo Jia gains 2.1s freeze; Xun Yu gains 0.12×Strategy% speed."],
				["frost_venom", "冰毒奇策", "Frost and Venom", ["guojia", "jiaxu"], "2人", "2 heroes", "郭嘉冷却减少2.8秒；贾诩目标+1、毒层数减少0.2×兵略值。", "Guo Jia loses 2.8s cooldown; Jia Xu gains 1 target but applies 0.2×Strategy fewer stacks."],
				["royal_venom", "王佐毒策", "Royal Venom", ["xunyu", "jiaxu"], "2人", "2 heroes", "荀彧与贾诩的技能冷却均减少2.8秒。", "Xun Yu and Jia Xu each lose 2.8s cooldown."]
			]
		},
		"wu":{
			"faction":["jiangdong_relay", "吴", "Wu", "2 / 5 / 8", "全体吴将最大生命提高2%/5%/8%。8人时，吴将濒死会均摊全体存活吴将的生命比例，并各自恢复5%最大生命（每30秒一次）。", "All Wu heroes gain 2%/5%/8% max HP. At 8, a lethal hit equalizes surviving Wu heroes' health ratios and restores 5% max HP to each (once per 30s)."],
			"bonds":[
				["wu_commanders", "四英杰", "Four Heroes", ["zhouyu", "luxun", "lusu", "lvmeng"], "4人", "4 heroes", "周瑜额外点燃2格且灼烧增加30%；陆逊额外弹射并灼烧；鲁肃治疗2人并各提高200%兵略值最大生命；吕蒙使命中后军恐惧9秒。", "Empowers all four heroes' signature skills."],
				["sun_legacy", "孙氏之志", "Sun Legacy", ["sunjian", "sunce", "sunquan", "sunshangxiang"], "4人", "4 heroes", "孙坚消耗80%当前生命并强化吴将；孙策追加第二段且伤害+50%；孙权生命成长强化；孙尚香连续释放两次并获得2点兵略值。", "Empowers all four Sun-family heroes."],
				["jiangdong_sisters", "江东双姝", "Jiangdong Sisters", ["daqiao", "xiaoqiao"], "2人", "2 heroes", "大乔追加1次150%兵略值治疗；小乔行动条减速增加0.12×兵略值%。", "Da Qiao adds a 150% Strategy heal; Xiao Qiao gains 0.12×Strategy% gauge slow."],
				["white_raid", "白衣奇袭", "White-Robed Ambush", ["lvmeng", "ganning"], "2人", "2 heroes", "吕蒙伤害增加150%兵略值且无视护盾；甘宁攻击生命低于50%的敌人时伤害增加180%兵略值。", "Lu Meng gains 150% Strategy damage and ignores shields; Gan Ning gains 180% Strategy damage against enemies below 50% HP."],
				["shenting_duel", "神亭酣战", "Shenting Duel", ["sunce", "taishici"], "2人", "2 heroes", "孙策伤害增加50%兵略值；太史慈目标+1但直接伤害减少30%兵略值。", "Sun Ce gains 50% Strategy damage; Taishi Ci gains 1 target but loses 30% Strategy direct damage."],
				["jiangdong_couple", "江东佳偶", "Jiangdong Couple", ["sunce", "daqiao"], "2人", "2 heroes", "孙策每损失10%生命，受到伤害减少4%；大乔治疗目标每损失10%生命，本次治疗提高4%。", "Both effects scale by 4% per 10% missing HP."],
				["harmonious_zither", "琴瑟和鸣", "Harmonious Zither", ["zhouyu", "xiaoqiao"], "2人", "2 heroes", "周瑜灼烧延长3秒且每秒伤害增加30%兵略值；小乔目标增加1名。", "Zhou Yu's burn gains 3s and 30% Strategy damage; Xiao Qiao gains 1 target."],
				["red_cliffs_ruse", "赤壁苦计", "Red Cliffs Ruse", ["zhouyu", "huanggai"], "2人", "2 heroes", "周瑜灼烧随目标每损失10%生命提高6%；黄盖附加5秒、每秒50%兵略值灼烧。", "Zhou Yu's burn gains 6% per 10% missing HP."],
				["jiangdong_pillars", "江东柱石", "Pillars of Jiangdong", ["huanggai", "sunjian"], "2人", "2 heroes", "黄盖消耗提高至15%最大生命，消耗生命伤害系数提高至50%；孙坚开局行动条充满。", "Huang Gai spends 15% max HP with a 50% spent-HP coefficient; Sun Jian starts at full gauge."],
				["jiangbiao_blades", "江表双锋", "Twin Blades of Jiangbiao", ["taishici", "ganning"], "2人", "2 heroes", "太史慈伤害增加60%兵略值；甘宁冷却减少2.1秒。", "Taishi Ci gains 60% Strategy damage; Gan Ning's cooldown is reduced by 2.1s."],
				["sovereign_minister", "君臣同心", "Sovereign and Minister", ["luxun", "sunquan"], "2人", "2 heroes", "陆逊直接伤害增加80%兵略值，对灼烧目标再增加40%兵略值；孙权伤害改为自身当前生命的11%。", "Lu Xun gains 80% Strategy damage and another 40% against burning targets; Sun Quan deals 11% of his current HP."],
				["tiger_ministers", "江表虎臣", "Tiger Ministers", ["dingfeng", "xusheng"], "2人", "2 heroes", "丁奉伤害增加100%兵略值且压退70%行动条；徐盛改为随机一排，水阵延长5.4秒。", "Ding Feng gains 100% Strategy damage and pushes back 70% gauge; Xu Sheng targets a random row and gains 5.4s duration."]
			]
		},
		"qun":{
			"faction":["chaos_struggle", "群", "Qun", "2 / 5 / 8", "全体群雄武将技能冷却缩短3.6%/9%/14.4%。8人时，每次释放技能有8%概率连续释放两次。", "All Qun heroes gain 3.6%/9%/14.4% skill cooldown reduction. At 8, every cast has an 8% chance to cast twice in succession."],
			"bonds":[
				["tyrant_peerless", "暴虐无双", "Tyrant and Peerless", ["lvbu", "dongzhuo"], "2人", "2 heroes", "吕布按横扫实际伤害的20%回血；董卓伤害提高至自身当前生命30%。", "Lu Bu heals for 20% of actual sweep damage; Dong Zhuo deals 30% of current HP."],
				["hero_beauty", "英雄美人", "Hero and Beauty", ["lvbu", "diaochan"], "2人", "2 heroes", "吕布每损失10%生命增伤4%；被貂蝉魅惑者每秒攻击相邻友军。", "Lu Bu gains 4% damage per 10% HP missing; charmed enemies attack adjacent allies each second."],
				["peerless_strategy", "谋定无双", "Peerless Strategy", ["lvbu", "chengong"], "2人", "2 heroes", "吕布横扫有30%概率再释放一次；陈宫冷却光环额外减少0.8秒。", "Lu Bu has a 30% repeat chance; Chen Gong's aura reduces another 0.8s."],
				["flying_formation", "飞将陷阵", "Flying General Formation", ["lvbu", "gaoshun"], "2人", "2 heroes", "吕布无双横扫伤害增加70%兵略值；高顺技能额外攻击1人。", "Lu Bu's sweep deals 70% more Strategy damage; Gao Shun gains 1 target."],
				["tyrant_beauty", "暴君倾城", "Tyrant and Beauty", ["dongzhuo", "diaochan"], "2人", "2 heroes", "董卓最大生命提高40%；貂蝉魅惑延长3.6秒并恢复自身300%兵略值生命。", "Dong Zhuo gains 40% max HP; Diao Chan gains 3.6s charm and heals herself for 300% Strategy."],
				["strategy_formation", "谋陷并驱", "Strategy and Formation", ["chengong", "gaoshun"], "2人", "2 heroes", "陈宫冷却光环额外减少0.8秒；高顺易碎延长6.3秒。", "Chen Gong's aura reduces another 0.8s; Gao Shun's Fragile gains 6.3s."],
				["hebei_twins", "河北双雄", "Hebei Twin Champions", ["yanliang", "wenchou"], "2人", "2 heroes", "颜良、文丑各增加1个目标，并分别减少30%/50%兵略值伤害。", "Yan Liang and Wen Chou each gain 1 target but lose 30%/50% Strategy damage."],
				["hebei_comrades", "河北同袍", "Hebei Comrades", ["gaolan", "qunzhanghe"], "2人", "2 heroes", "高览同列加成提高至0.25×兵略值；群张郃护盾增加60%兵略值。", "Gao Lan's column aura rises to 0.25×Strategy; Zhang He's shield gains 60% Strategy."],
				["hebei_pillars", "河北四庭柱", "Hebei Pillars", ["yanliang", "wenchou", "qunzhanghe", "gaolan"], "4人", "4 heroes", "颜良、文丑各增加1个目标并增加120%/150%兵略值伤害；高览扩大同排同列0.25×兵略值；群张郃目标+2、护盾增加100%兵略值。", "Yan Liang and Wen Chou gain a target and damage; Gao Lan expands his aura; Zhang He gains 2 targets and 100% Strategy shielding."],
				["medicine_immortal", "医道同源", "Medicine and Immortality", ["huatuo", "yuji"], "2人", "2 heroes", "华佗治疗增加70%兵略值；于吉中毒目标+1。", "Hua Tuo gains 70% Strategy healing; Yu Ji gains 1 poison target."],
				["immortal_healers", "济世仙缘", "Immortal Healers", ["huatuo", "zuoci"], "2人", "2 heroes", "华佗治疗增加30%兵略值并清除全部减益；左慈治疗增加100%兵略值。", "Hua Tuo gains healing and cleansing; Zuo Ci gains 100% Strategy healing."],
				["fangshi_lineage", "方仙同门", "Immortal Lineage", ["yuji", "zuoci"], "2人", "2 heroes", "敌人每损失10%生命，受到的所有中毒伤害提高5%；左慈治疗时向两个随机射程内单元格追加200%兵略值天雷，空格伤害由主公承受。", "All poison damage rises by 5% per 10% target HP missing; Zuo Ci adds 200% Strategy thunderbolts to 2 random reachable tiles, with empty-tile damage hitting the ruler."],
				["heaven_man", "天人同道", "Heaven and Man", ["zhangjiao", "zhangliang"], "2人", "2 heroes", "张角伤害增加120%兵略值；张梁虚弱目标+1。", "Zhang Jiao gains 120% Strategy damage; Zhang Liang gains 1 target."],
				["heaven_earth", "天地雷契", "Heaven and Earth", ["zhangjiao", "zhangbao"], "2人", "2 heroes", "任意友军阵亡时，张角立即对2个随机敌方单元格造成600%兵略值伤害并眩晕2秒；张宝自爆以90%兵略值波及目标周围八格。", "Whenever an ally falls, Zhang Jiao immediately strikes 2 random enemy tiles for 600% Strategy and stuns for 2s; Zhang Bao splashes nearby units for 90% Strategy."],
				["earth_man", "地人续命", "Earth and Man", ["zhangliang", "zhangbao"], "2人", "2 heroes", "张梁虚弱延长4.5秒；张宝额外复生一次。", "Zhang Liang's weaken gains 4.5s; Zhang Bao gains one additional revival."]
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

func _tianshu_group_color(book: Dictionary) -> Color:
	# 分类强调色：通用=金、阵营与单阵营武将池=对应阵营色。
	if book.has("faction"):
		return FACTION_COLORS[str(book.faction)]
	if book.has("pool"):
		var pool_factions: Array = book.pool
		if pool_factions.size() == 1:
			return FACTION_COLORS[str(pool_factions[0])]
		return Color("#8a6fb5")
	return Color("#c9a24c")

func _tianshu_codex_faction(book: Dictionary) -> String:
	if book.has("faction"):
		return str(book.faction)
	if book.has("pool"):
		var pool_factions: Array = book.pool
		if pool_factions.size() == 1:
			return str(pool_factions[0])
	return "all"

func _tianshu_border_overlay(book: Dictionary) -> TextureRect:
	# 天书卡片边框贴图：通用=common，阵营与单阵营武将池使用对应阵营边框。
	var file := "common.png"
	if book.has("faction"):
		file = str(book.faction) + "-compact.png"
	elif book.has("pool"):
		var pool_factions: Array = book.pool
		file = str(pool_factions[0]) + "-compact.png" if pool_factions.size() == 1 else "qun-compact.png"
	var border := TextureRect.new()
	border.texture = load(CARD_BORDER_ROOT + file)
	border.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	border.stretch_mode = TextureRect.STRETCH_SCALE
	border.name = "TianshuBorder"
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return border

func _render_tianshu_encyclopedia() -> void:
	var book_ids := TIANSHU_BOOKS.keys().filter(func(book_id):
		return _tianshu_codex_faction(TIANSHU_BOOKS[book_id]) == encyclopedia_tianshu_faction
	)
	book_ids.sort_custom(func(a, b):
		var group_a := str(TIANSHU_BOOKS[a].group)
		var group_b := str(TIANSHU_BOOKS[b].group)
		return group_a + str(TIANSHU_BOOKS[a].name) < group_b + str(TIANSHU_BOOKS[b].name)
	)
	for book_id in book_ids:
		var book: Dictionary = TIANSHU_BOOKS[str(book_id)]
		var accent := _tianshu_group_color(book)
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 230)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		_style(card, Color("#1a1d1f"), 12, accent, 2)
		encyclopedia_grid.add_child(card)
		var card_box := VBoxContainer.new()
		card_box.mouse_filter = Control.MOUSE_FILTER_PASS
		card_box.add_theme_constant_override("separation", 10)
		card.add_child(card_box)
		var group_label := _label("◆ " + str(book.group) + " ◆", 16, accent.lightened(0.25))
		group_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_box.add_child(group_label)
		var book_name := _label(_tianshu_name(str(book_id)), 30, accent.lightened(0.34))
		book_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		book_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_box.add_child(book_name)
		var effects: Array = book.get("effects", [])
		var level_one := _label(t("一级：", "Level I: ") + (str(effects[0]) if effects.size() > 0 else ""), 18, Color("#e8e2cf"))
		level_one.mouse_filter = Control.MOUSE_FILTER_IGNORE
		level_one.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		level_one.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_box.add_child(level_one)
		var level_two := _label(t("二级：", "Level II: ") + (str(effects[1]) if effects.size() > 1 else ""), 18, Color("#c9c0b1"))
		level_two.mouse_filter = Control.MOUSE_FILTER_IGNORE
		level_two.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		level_two.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_box.add_child(level_two)

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
	if is_instance_valid(battle_menu_overlay): battle_menu_overlay.hide()
	_start_quick_game()

func _continue_from_menu() -> void:
	menu_overlay.hide()
	if is_instance_valid(battle_menu_overlay): battle_menu_overlay.hide()
	if not _load_game(): menu_overlay.show()

func _show_main_menu() -> void:
	if battle_running: return
	continue_button.disabled = not FileAccess.file_exists(SAVE_PATH)
	continue_button.text = "继续闯关" if not _challenge_run_snapshot().is_empty() else "继续对局"
	draft_overlay.hide()
	for overlay in [battle_menu_overlay, rune_overlay, talent_overlay, settings_overlay, encyclopedia_overlay, tianshu_overlay]:
		if is_instance_valid(overlay): overlay.hide()
	_refresh_home()
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
		"zhangfei": return t("燕人号令：强化己方前军，增伤0.15×兵略值%，持续3.3秒。", "Command of Yan: Allied vanguards gain damage equal to 0.15×Strategy% for 3.3s.")
		"zhaoyun": return t("龙胆连刺：随机选择一个射程内单元格，连续攻击5次，每次造成115%兵略值伤害；若命中空格，等量伤害由敌方主公承受。当前可达排无人时，射程逐排向后延伸。", "Dragon-Gall Flurry: Strike one random reachable tile 5 times for 115% Strategy each; empty-tile damage hits the enemy ruler. Range extends by rows when all currently reachable rows are empty.")
		"liushan": return t("蜀主鼓舞（被动）：强化自己前方的友军，使其伤害提高0.27×兵略值%。", "Royal Encouragement (Passive): Empower the ally directly ahead with damage based on Strategy.")
		"huangzhong": return t("百步穿杨：射击随机可攻击格，造成420%兵略值伤害。", "Piercing Arrow: Shoot a random reachable tile for 420% Strategy damage.")
		"machao": return t("铁骑贯阵：随机选择一个射程内单元格并贯穿其整列，前军/中军/后军依次受到260%/230%/200%兵略值伤害；空格承受的等量伤害由主公承受。", "Iron Cavalry: Choose a random reachable tile and pierce its column for 260%/230%/200% Strategy; empty-tile damage hits the ruler.")
		"madai": return t("斩将突袭：随机选择敌方前军单元格；前军无人则依次顺延到中军、后军。命中武将造成50%最大生命伤害，命中空格则对主公造成20×兵略值伤害。", "General-Slaying Raid: Choose a vanguard tile, advancing by rows; deal 50% max HP to a hero or 20×Strategy to the ruler on an empty tile.")
		"weiyan": return t("狂骨横斩：攻击正前方单元格，造成180%兵略值伤害；敌方前军无人时依次顺延到中军、后军，命中空格时等量伤害由主公承受。", "Bone-Crazed Sweep: Strike the facing tile for 180% Strategy, advancing by rows when empty; empty-tile damage hits the ruler.")
		"zhugeliang": return t("八阵奇谋：随机选择敌方格子，对目标及同列相邻格造成230%兵略值法术伤害。", "Eight-Formation Stratagem: Deal 230% Strategy magic damage to a random tile and its vertical neighbors.")
		"jiangwei": return t("北伐：随机攻击一个射程内单元格，造成450%兵略值法术伤害。", "Northern Expedition: Deal 450% Strategy magic damage to a random reachable tile.")
		"pangtong": return t("连环计：随机攻击两个射程内单元格，各造成200%兵略值伤害；命中的武将链接6秒并相互传导30%伤害。", "Chain Scheme: Strike 2 random reachable tiles for 200% Strategy; hit heroes are linked for 6s and echo 30% damage.")
		"menghuo": return t("蛮王震地：攻击敌方前军整排，造成115%兵略值物理伤害并眩晕1.4秒。", "Barbarian Quake: Strike the enemy vanguard row for 115% Strategy damage and stun for 1.4s.")
		"zhurong": return t("火神飞刃：随机攻击一个射程内单元格，造成300%兵略值法术伤害并灼烧3秒，每秒造成50%兵略值伤害。", "Flame Blade: Strike a random reachable tile for 300% Strategy magic damage and burn for 3s at 50% Strategy per second.")
		"dailaidongzhu": return t("蛮骨狼袭：随机攻击一个射程内单元格，造成490%兵略值物理伤害；命中空格时等量伤害由主公承受。", "Savage-Bone Wolf Assault: Strike a random reachable tile for 490% Strategy physical damage; empty-tile damage hits the ruler.")
		"caocao": return t("魏武震慑：随机攻击两个射程内单元格，各造成150%兵略值伤害；命中武将时眩晕2.2秒。", "Dominion Stun: Strike 2 random reachable tiles for 150% Strategy; hit heroes are stunned for 2.2s.")
		"dianwei": return t("恶来袭后：随机攻击两个敌方后军单元格，各造成240%兵略值伤害；空格伤害由主公承受。", "Evil Guard Raid: Strike 2 random enemy rearguard tiles for 240% Strategy each; empty-tile damage hits the ruler.")
		"xuchu": return t("虎卫破前：随机攻击两个敌方前军单元格，各造成320%兵略值伤害；前军无人时依次顺延，空格伤害由主公承受。", "Tiger Guard Break: Strike 2 random vanguard tiles for 320% Strategy each, advancing by rows when empty; empty-tile damage hits the ruler.")
		"zhangliao": return t("威震回刃：攻击随机敌方一列，回旋刃飞出与返回各造成110%兵略值伤害。", "Returning Blade: Strike a random enemy column for 110% Strategy on both the outward and returning passes.")
		"yuejin": return t("先登乱射：随机攻击三个射程内单元格，各造成200%兵略值伤害；空格伤害由主公承受。", "Vanguard Volley: Strike 3 random reachable tiles for 200% Strategy each; empty-tile damage hits the ruler.")
		"xuhuang": return t("撼地开山：攻击敌方前军整排，造成80%兵略值伤害并眩晕2.7秒。", "Earth-Splitting Axe: Strike the enemy vanguard row for 80% Strategy damage and stun for 2.7s.")
		"zhanghe": return t("巧变连枪：随机攻击一个敌方前军单元格，造成400%兵略值伤害；前军无人时依次顺延。命中武将眩晕2.7秒，空格伤害由主公承受。", "Coiling Spear Chain: Strike a random vanguard tile for 400% Strategy, advancing by rows when empty; stun a hit hero for 2.7s or damage the ruler on an empty tile.")
		"yujin": return t("毅重护阵：为当前生命值最低的友军施加300%兵略值的护盾。", "Resolute Ward: Shield the ally with the lowest current HP for 300% Strategy.")
		"xiahouyuan": return t("神速震袭：随机攻击两个射程内单元格，造成220%兵略值伤害；命中武将眩晕1.8秒，空格伤害由主公承受。", "Swift Suppression: Strike 2 random reachable tiles for 220% Strategy; stun hit heroes for 1.8s and deal empty-tile damage to the ruler.")
		"caoren": return t("樊城镇远：随机攻击两个敌方后军单元格，造成200%兵略值伤害；命中武将眩晕1.8秒，空格伤害由主公承受。释放后获得5秒后军减伤。", "Rearward Bulwark: Strike 2 random rearguard tiles for 200% Strategy; stun hit heroes for 1.8s and damage the ruler on empty tiles, then gain rearguard damage reduction for 5s.")
		"xiahoudun": return t("刚烈镇前：随机攻击两个敌方前军单元格，前军无人时依次顺延；造成240%兵略值伤害，命中武将眩晕2.7秒，空格伤害由主公承受。", "Vanguard Bulwark: Strike 2 random vanguard tiles, advancing by rows when empty, for 240% Strategy; stun hit heroes for 2.7s and damage the ruler on empty tiles.")
		"simayi": return t("雷霆谋断：随机雷击两个射程内单元格，各造成320%兵略值伤害；空格伤害由主公承受。", "Thunder Judgment: Strike 2 random reachable tiles for 320% Strategy each; empty-tile damage hits the ruler.")
		"guojia": return t("遗计冰封：随机选择两个射程内单元格；命中武将时冻结5.4秒，空格造成280%兵略值伤害。冻结目标受伤会提前解冻，并受到剩余冻结秒数×50%兵略值伤害。", "Frozen Legacy: Freeze heroes for 5.4s or deal 280% Strategy to the ruler on empty tiles. Shattering deals 50% Strategy per remaining freeze second.")
		"xunyu": return t("王佐疾策：随机使2名友军行动条速度提高0.4×兵略值%，持续4.4秒。", "Royal Acceleration: Grant 2 random allies gauge speed equal to 0.4×Strategy% for 4.4s.")
		"jiaxu": return t("毒士奇谋：随机向两个射程内单元格施加1.6×兵略值层毒。空格毒伤直接作用于主公；后续在该格上阵的武将继承剩余毒层。每秒造成当前层数伤害，随后层数减半。", "Venomous Scheme: Apply 1.6×Strategy poison stacks to 2 random reachable tiles. Poison on empty tiles damages the ruler and transfers its remaining stacks to a hero entering the tile; stacks halve after each tick.")
		"sunjian": return t("猛虎绝命：消耗40%当前生命，攻击正前方单元格并造成等同于实际消耗生命100%的伤害；前军无人时依次顺延，空格伤害由主公承受。", "Tiger's Resolve: Spend 40% current HP and strike the facing tile for 100% of HP spent, advancing by rows when empty; empty-tile damage hits the ruler.")
		"sunce": return t("小霸王连击：攻击正前方及其左侧单元格，各造成160%兵略值伤害；前军无人时依次顺延，空格伤害由主公承受。自身每损失10%生命，伤害提高3%。", "Conqueror's Twin Assault: Strike the facing and left tiles for 160% Strategy. Gain 3% damage per 10% HP missing.")
		"sunquan": return t("江东制衡：提高100%兵略值最大生命并恢复0.1×兵略值%的已损生命，再随机攻击一个射程内单元格，造成当前生命8%的伤害；最大生命上限为初始值2倍。", "Jiangdong Balance: Gain max HP equal to Strategy, restore Strategy-scaled missing HP, then deal 8% current HP damage; max HP is capped at twice its initial value.")
		"sunshangxiang": return t("枭姬叠势：随机攻击一个射程内单元格，造成500%兵略值伤害；空格伤害由主公承受。每次释放后兵略值提高1点。", "Heroine's Growing Volley: Strike a random reachable tile for 500% Strategy; empty-tile damage hits the ruler. Gain 1 Strategy after each cast.")
		"zhouyu": return t("赤壁点火：随机选择2个敌方格，各造成200%兵略值法术伤害并灼烧4秒，每秒造成30%兵略值伤害。", "Red Cliffs: Ignite 2 random enemy tiles for 200% Strategy magic damage and burn for 4s at 30% Strategy per second.")
		"luxun": return t("火烧连营：随机选择敌方单元格发射火球，造成290%兵略值法术伤害，并继续随机弹射到未命中的相邻单元格；空格伤害由主公承受，附带灼烧时会留在格中并由后续上阵武将继承。", "Flames of Camp: Launch a fireball at a random tile for 290% Strategy magic damage, then bounce randomly to an unhit adjacent tile; empty-tile damage hits the ruler and tile burns transfer to heroes entering them.")
		"lvmeng": return t("白衣渡江：攻击敌方后军随机单元格，造成500%兵略值伤害。", "White-Robed Raid: Strike a random enemy rearguard for 500% Strategy damage.")
		"lusu": return t("连横稳阵：为当前生命值最低的友军恢复320%兵略值生命，并使其最大生命提高100%兵略值。", "Alliance: Heal the ally with the lowest current HP for 320% Strategy and grant max HP equal to Strategy.")
		"daqiao": return t("国色流离：治疗生命最低的友军380%兵略值生命。", "River Blossom: Heal the ally with the lowest current HP for 380% Strategy.")
		"xiaoqiao": return t("天香缓阵：随机选择两名敌方后军，使其减速10.8秒，期间行动条速度降低0.35×兵略值%。", "Gentle Breeze: Slow two random enemy rearguards for 10.8s by 0.35×Strategy%.")
		"taishici": return t("神亭烈戟：优先攻击射程内行动条最高的两名敌人，造成200%兵略值伤害并灼烧5秒；敌方空场时改为随机攻击两个射程内单元格，空格伤害由主公承受。", "Blazing Twin Halberds: Prioritize the 2 reachable enemies with the highest gauges for 200% Strategy and burn for 5s; if the enemy board is empty, strike 2 random reachable tiles and deal empty-tile damage to the ruler.")
		"ganning": return t("锦帆并击：自身与同排左侧友军分别攻击一个随机敌方后军单元格，各造成300%自身兵略值伤害；空格伤害由主公承受，友军协击不消耗行动条。", "Bell-Raider Twin Assault: Gan Ning and his left ally each strike a random rearguard tile for 300% of their own Strategy; empty-tile damage hits the ruler and the assist costs no gauge.")
		"huanggai": return t("苦肉焚阵：消耗10%最大生命，对随机敌方一列造成200%兵略值加实际消耗生命40%的伤害；生命不足时消耗全部生命并在攻击后阵亡。", "Bitter-Flesh Column: Spend 10% max HP to damage a random enemy column for 200% Strategy plus 40% of HP spent.")
		"dingfeng": return t("雪中奋短兵：优先攻击射程内行动条最高的敌人，造成400%兵略值伤害并压退25%行动条；敌方空场时改为随机攻击一个射程内单元格，空格伤害由主公承受。", "Snowbound Short Blades: Prioritize the reachable enemy with the highest gauge for 400% Strategy and push it back 25%; if the enemy board is empty, strike a random reachable tile and damage the ruler.")
		"xusheng": return t("宿卫水阵：冲击敌方前军整排，前军无人时依次顺延；每格造成100%兵略值伤害，空格伤害由主公承受，并使命中武将减速7.2秒，行动速度降低0.3×兵略值%。", "Guardian Water Formation: Strike the enemy vanguard row, advancing by rows when empty, for 100% Strategy per tile; empty-tile damage hits the ruler and hit heroes lose 0.3×Strategy% gauge speed for 7.2s.")
		"lvbu": return t("无双横扫：攻击正前方单元格和左右相邻单元格，各造成220%兵略值伤害；敌方前军无人时依次顺延，空格伤害由主公承受。", "Peerless Sweep: Strike the facing tile and its left and right neighbors for 220% Strategy each.")
		"diaochan": return t("美人离间：随机魅惑一名敌军7.2秒，使其行动条停止。", "Beauty's Scheme: Charm a random enemy for 7.2s, stopping its action gauge.")
		"dongzhuo": return t("暴君横征：攻击正前方单元格，造成自身当前生命值20%的伤害；敌方前军无人时依次顺延，空格伤害由主公承受。", "Tyrant's Might: Strike the facing tile for 20% of current HP, advancing by rows when empty; empty-tile damage hits the ruler.")
		"chengong": return t("智迟谋速（被动）：陈宫及其同列友军的技能冷却减少1.2秒，不受原冷却一半下限限制。", "Measured Formation (Passive): Chen Gong and allies in his column reduce cooldowns by 1.2s, bypassing the half-cooldown floor.")
		"gaoshun": return t("陷阵之志：随机攻击两个敌方前军单元格，前军无人时依次顺延；造成220%兵略值伤害，命中武将施加6.3秒易碎，空格伤害由主公承受。", "Formation Resolve: Strike 2 random vanguard tiles, advancing by rows when empty, for 220% Strategy; hit heroes become Fragile for 6.3s and empty-tile damage hits the ruler.")
		"yanliang": return t("河北猛袭：随机攻击两个敌方中军或后军单元格，各造成200%兵略值伤害；空格伤害由主公承受。", "Hebei Fierce Assault: Strike 2 random midguard or rearguard tiles for 200% Strategy each; empty-tile damage hits the ruler.")
		"wenchou": return t("河北破阵：随机攻击两个敌方前军或中军单元格，各造成300%兵略值伤害；空格伤害由主公承受。", "Hebei Breakthrough: Strike 2 random vanguard or midguard tiles for 300% Strategy each; empty-tile damage hits the ruler.")
		"gaolan": return t("列阵扬威（被动）：高览同列友军的兵略值增加0.2×兵略值。", "Column Valor (Passive): Allies in Gao Lan's column gain 0.2× his Strategy.")
		"qunzhanghe": return t("河北护阵：为当前生命值最低的两名友军施加可抵消200%兵略值伤害的护盾。", "Hebei Ward: Shield the 2 allies with the lowest current HP for 200% Strategy.")
		"huatuo": return t("青囊三济：治疗当前生命值最低的三名友军，各恢复110%兵略值生命。", "Threefold Remedy: Heal the three allies with the lowest current HP for 110% Strategy each.")
		"yuji": return t("蛊毒仙术：随机向两个射程内单元格施加1.4×兵略值层毒。空格毒伤直接作用于主公，后续在该格上阵的武将继承剩余毒层；每秒结算后层数减半。", "Venomous Immortal Art: Apply 1.4×Strategy poison stacks to 2 random reachable tiles. Empty-tile poison damages the ruler and transfers to a hero entering the tile; stacks halve after each tick.")
		"zuoci": return t("遁甲济世：治疗当前生命值最低的两名友军，各恢复170%兵略值生命。", "Immortal Aid: Heal the two allies with the lowest current HP for 170% Strategy each.")
		"zhangjiao": return t("黄天雷引：召唤雷电随机攻击两个射程内单元格，各造成300%兵略值伤害；空格伤害由主公承受。", "Yellow Sky Thunder: Call lightning on 2 random reachable tiles for 300% Strategy each; empty-tile damage hits the ruler.")
		"zhangliang": return t("人公虚弱：随机使两名敌军虚弱7.2秒，兵略值降低0.5×兵略值。", "Yellow Sky Weakening: Weaken two random enemies for 7.2s, reducing Strategy based on Zhang Liang's Strategy.")
		"zhangbao": return t("地公雷爆（被动）：阵亡时随机攻击两个射程内单元格，当前排无人时依次顺延；各造成900%兵略值伤害，空格伤害由主公承受，随后以50%最大生命值复生一次。", "Earth General Detonation (Passive): On death, strike 2 random reachable tiles, advancing by rows when empty, for 900% Strategy; empty-tile damage hits the ruler, then revive once at 50% max HP.")
	return _true_damage_text(_skill_detail_legacy(hero_id))

func _bond_entry(name_zh: String, name_en: String, member_ids: Array, effect_zh: String, effect_en: String) -> String:
	var member_names: Array[String] = []
	for id in member_ids: member_names.append(_hero_name(str(id)))
	return t(name_zh, name_en) + "（" + "、".join(member_names) + "）：" + t(effect_zh, effect_en)

func _hero_bond_detail(hero_id: String) -> String:
	var entries: Array[String] = []
	var faction: String = heroes[hero_id].f
	var faction_effects: Array = {
		"shu":["2/5/8人时，本武将承伤降低2%/5%/8%；8人时每次受伤叠加3%减伤，最多3层，每层持续3秒。", "At 2/5/8, this hero takes 2%/5%/8% less damage; at 8, each hit taken adds 3% reduction up to 3 stacks, each lasting 3s."],
		"wei":["2/5/8人时，本武将控制时长提高2%/5%/8%；8人时，对带有任意控制或减益的目标伤害提高8%。", "At 2/5/8, this hero gains 2%/5%/8% control duration; at 8, damage to any controlled or debuffed target increases by 8%."],
		"wu":["2/5/8人时，本武将最大生命提高2%/5%/8%；8人时，吴将濒死会触发全体吴将生命均摊并恢复5%最大生命（每30秒一次）。", "At 2/5/8, this hero gains 2%/5%/8% max HP; at 8, a lethal hit equalizes Wu health and restores 5% max HP (once per 30s)."],
		"qun":["2/5/8人时，本武将技能冷却缩短3.6%/9%/14.4%；8人时，每次释放技能有8%概率连续释放两次。", "At 2/5/8, this hero gains 3.6%/9%/14.4% cooldown reduction; at 8, each cast has an 8% chance to cast twice."]
	}[faction]
	var peach: Array = ["liubei", "guanyu", "zhangfei"]
	if peach.has(hero_id):
		var effects: Array = {"liubei":["持续治疗由每秒100%兵略值提高为200%兵略值。", "Regeneration rises from 100% to 200% Strategy each second."], "guanyu":["按整列斩实际造成伤害的30%恢复自身生命。", "Heal for 30% of actual column-cleave damage dealt."], "zhangfei":["燕人号令持续时间增加50%。", "Command of Yan lasts 50% longer."]}[hero_id]
		entries.append(_bond_entry("桃园结义", "Peach Garden", peach, effects[0], effects[1]))
	var five_tigers: Array = ["guanyu", "zhangfei", "zhaoyun", "huangzhong", "machao"]
	if five_tigers.has(hero_id):
		var effects: Array = {"guanyu":["整列斩伤害倍率由210%提高为550%兵略值。", "Column-cleave damage rises from 210% to 550% Strategy."], "zhangfei":["持续时间增加50%，增伤变为0.25×兵略值%。", "Duration gains 50%; damage bonus becomes 0.25 × Strategy percent."], "zhaoyun":["连刺增加1次，且每次连击伤害增加100%兵略值。", "Gain 1 thrust and 100% Strategy damage per thrust."], "huangzhong":["固定选择敌方前军并提高至1100%兵略值。", "Always target an enemy vanguard at 1100% Strategy."], "machao":["释放技能后为同排友军提供0.4×马超兵略值的兵略值，持续7.2秒。", "After casting, same-row allies gain Strategy equal to 0.4 × Ma Chao's Strategy for 7.2s."]}[hero_id]
		entries.append(_bond_entry("五虎上将", "Five Tiger Generals", five_tigers, effects[0], effects[1]))
	var personal: Dictionary = {
		"liubei":[["夜梦北斗", "Northern Dream", ["liubei", "liushan"], "持续治疗时间延长30%。", "Regeneration duration increases by 30%."], ["卧龙辅汉", "Wolong Aids Han", ["liubei", "zhugeliang"], "持续治疗中的目标受到的伤害降低30%。", "The regenerating target takes 30% less damage."]],
		"liushan":[["夜梦北斗", "Northern Dream", ["liubei", "liushan"], "鼓舞作用于同列友军，增伤变为0.18×兵略值%。", "The aura affects same-column allies at 0.18 × Strategy percent."], ["七进七出", "Seven Charges", ["zhaoyun", "liushan"], "被强化友军造成伤害的30%用于恢复自身生命。", "Empowered allies heal for 30% of damage dealt."]],
		"zhaoyun":[["七进七出", "Seven Charges", ["zhaoyun", "liushan"], "连刺增加1次，固定选择距离自己最远的敌方后军。", "Gain 1 thrust and force the farthest enemy rearguard."]],
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
			["南蛮夫妇", "Nanman Couple", ["menghuo", "zhurong"], "蛮王震地对灼烧目标伤害提高40%，并将这些目标的眩晕时间由1.4秒延长至2.1秒。", "Barbarian Quake deals +40% damage to burning targets and extends their stun from 1.4s to 2.1s."],
			["蛮王援军", "Barbarian Reinforcements", ["menghuo", "dailaidongzhu"], "蛮王震地额外使每名命中武将损失8%行动条。", "Every hero hit by Barbarian Quake also loses 8% gauge."]
		],
		"zhurong":[
			["南蛮夫妇", "Nanman Couple", ["menghuo", "zhurong"], "火神飞刃向主目标左右同排相邻格各弹射一次，造成50%兵略值伤害并施加完整灼烧。", "Flame Blade bounces to both horizontal neighbors for 50% Strategy and applies its full burn."],
			["姐弟同心", "Sibling Bond", ["dailaidongzhu", "zhurong"], "火神飞刃的灼烧时长增加2秒，灼烧伤害提高至每秒100%兵略值。", "Flame Blade's burn gains 2 seconds and rises to 100% Strategy per second."]
		],
		"dailaidongzhu":[
			["蛮王援军", "Barbarian Reinforcements", ["menghuo", "dailaidongzhu"], "蛮骨狼袭改为攻击行动条最高目标所在整列，每格造成210%兵略值伤害。", "Savage-Bone Wolf Assault strikes the highest-gauge target's entire column for 320% Strategy per tile."],
			["姐弟同心", "Sibling Bond", ["dailaidongzhu", "zhurong"], "蛮骨狼袭施加4秒、每秒50%兵略值的灼烧；若目标原本已灼烧，直接伤害额外增加50%兵略值。", "Savage-Bone Wolf Assault applies a 4s burn at 50% Strategy per second; against an already burning target, direct damage gains another 50% Strategy."]
		],
		"zhugeliang":[
			["卧龙凤雏", "Dragon and Phoenix", ["zhugeliang", "pangtong"], "八阵奇谋额外影响中心格四个斜对角相邻格。", "Eight-Formation Stratagem also affects all four diagonal neighbors."],
			["北伐传承", "Northern Expedition Legacy", ["zhugeliang", "jiangwei"], "八阵奇谋额外影响中心格左右两个同排相邻格。", "Eight-Formation Stratagem also affects the two horizontal neighbors."],
			["七擒孟获", "Seven Captures", ["zhugeliang", "menghuo"], "伤害提高20%并施加15秒火攻标记；再次命中标记者时伤害提高40%。", "Gain 20% damage and apply a 15s Fire Assault mark; hitting it again gains 40% damage."],
			["卧龙辅汉", "Wolong Aids Han", ["liubei", "zhugeliang"], "本次技能每多命中一名武将，所有受击格伤害提高4%；命中9人时提高32%。", "Each additional enemy hit grants 4% damage to all affected tiles, reaching 32% at nine enemies."]
		]
	}
	for data in personal.get(hero_id, []): entries.append(_bond_entry(data[0], data[1], data[2], data[3], data[4]))
	var combo_defs: Array = [
		[["caocao", "dianwei"], "古之恶来", "Evil of Old", {"caocao":["技能目标数增加1；命中后军时伤害增加100%兵略值，眩晕时长增加0.9秒。", "Gain 1 target; against rearguards, gain 100% Strategy damage and 0.9s stun."], "dianwei":["攻击目标增加1，造成伤害减少30%兵略值。", "Gain 1 target, but lose 30% Strategy damage."]}],
		[["caocao", "xuchu"], "虎卫护主", "Tiger Guard", {"caocao":["技能目标数增加1；命中前军时伤害增加100%兵略值，眩晕时长增加0.9秒。", "Gain 1 target; against vanguards, gain 100% Strategy damage and 0.9s stun."], "xuchu":["攻击目标增加1，造成伤害减少40%兵略值。", "Gain 1 target, but lose 40% Strategy damage."]}],
		[["dianwei", "xuchu"], "魏武双卫", "Twin Wei Guards", {"dianwei":["造成伤害增加100%兵略值。", "Gain 100% Strategy damage."], "xuchu":["造成伤害增加150%兵略值。", "Gain 150% Strategy damage."]}],
		[["zhangliao", "yuejin"], "逍遥津先锋", "Hefei Vanguard", {"zhangliao":["回旋刃的每段伤害增加100%兵略值。", "Each boomerang pass gains 100% Strategy damage."], "yuejin":["攻击目标增加1名。", "Gain 1 target."]}],
		[["zhanghe", "xuhuang"], "巧变开山", "Adaptive Vanguard", {"zhanghe":["眩晕时长增加1.8秒。", "Stun duration gains 1.8s."], "xuhuang":["伤害增加80%兵略值。", "Gain 80% Strategy damage."]}],
		[["zhouyu", "luxun", "lusu", "lvmeng"], "四英杰", "Four Heroes", {"zhouyu":["额外选择2个格子，灼烧伤害增加30%兵略值。", "Gain 2 tiles and 30% Strategy burn damage."], "luxun":["总弹射次数增加2次，并施加3秒灼烧，每秒30%兵略值伤害。", "Gain 2 bounces and inflict a 3s burn at 30% Strategy per second."], "lusu":["治疗2名最低当前生命友军，各恢复400%兵略值并提高200%兵略值最大生命。", "Heal 2 allies for 400% Strategy and grant max HP equal to 200% Strategy."], "lvmeng":["命中的后军恐惧9秒，行动条停止且每秒受到4%最大生命伤害。", "Fear the struck rearguard for 9s, stopping its gauge and dealing 4% max HP each second."]}],
		[["lvbu", "dongzhuo"], "暴虐无双", "Tyrant and Peerless", {"lvbu":["按无双横扫对武将造成的实际伤害20%恢复自身生命；护盾和空格伤害不计入。", "Heal for 20% of actual hero HP damage from Peerless Sweep; shield and empty-tile damage do not count."], "dongzhuo":["暴君横征伤害提高至自身当前生命值30%。", "Tyrant's Might rises to 30% of current HP."]}],
		[["lvbu", "diaochan"], "英雄美人", "Hero and Beauty", {"lvbu":["每损失10%生命，无双横扫伤害提高4%。", "Gain 4% Peerless Sweep damage per 10% HP missing."], "diaochan":["魅惑期间，目标每秒随机攻击一名相邻友军，造成被魅惑者100%兵略值伤害。", "Each second, the charmed target attacks a random adjacent ally for 100% of its own Strategy."]}],
		[["lvbu", "chengong"], "谋定无双", "Peerless Strategy", {"lvbu":["无双横扫有30%概率连续释放两次。", "Peerless Sweep has a 30% chance to cast twice."], "chengong":["智迟谋速的冷却减少额外增加0.8秒。", "Measured Formation reduces cooldown by another 0.8s."]}],
		[["lvbu", "gaoshun"], "飞将陷阵", "Flying General Formation", {"lvbu":["无双横扫造成的伤害增加70%兵略值。", "Peerless Sweep damage gains 70% Strategy."], "gaoshun":["陷阵之志的目标额外增加1名。", "Formation Resolve gains 1 target."]}],
		[["dongzhuo", "diaochan"], "暴君倾城", "Tyrant and Beauty", {"dongzhuo":["自身最大生命值提高40%。", "Gain 40% max HP."], "diaochan":["魅惑持续时间增加3.6秒，且貂蝉恢复300%兵略值生命。", "Charm gains 3.6s and Diao Chan heals herself for 300% Strategy."]}],
		[["chengong", "gaoshun"], "谋陷并驱", "Strategy and Formation", {"chengong":["智迟谋速的冷却减少额外增加0.8秒。", "Measured Formation reduces cooldown by another 0.8s."], "gaoshun":["陷阵之志的易碎持续时间增加6.3秒。", "Formation Resolve Fragile duration gains 6.3s."]}],
		[["yanliang", "wenchou"], "河北双雄", "Hebei Twin Champions", {"yanliang":["技能目标增加1名，伤害减少30%兵略值。", "Gain 1 target but lose 30% Strategy damage."], "wenchou":["技能目标增加1名，伤害减少50%兵略值。", "Gain 1 target but lose 50% Strategy damage."]}],
		[["gaolan", "qunzhanghe"], "河北同袍", "Hebei Comrades", {"gaolan":["同列友军的兵略值加成提高至0.25×兵略值。", "The column aura rises to 0.25×Strategy."], "qunzhanghe":["护盾值增加60%兵略值。", "Shielding gains 60% Strategy."]}],
		[["zhangliao", "yuejin", "zhanghe", "xuhuang", "yujin"], "五子良将", "Five Elite Generals", {"zhangliao":["回旋刃每段伤害增加100%兵略值；命中者受到的伤害增加0.4×兵略值%，持续9秒。", "Each pass gains 100% Strategy damage; hit enemies take 0.4×Strategy% more damage for 9s."], "yuejin":["目标增加1名，伤害增加80%兵略值，并施加9秒重伤，使治疗和自身回复降低0.5×兵略值%。", "Gain 1 target and 80% Strategy damage; inflict 9s Grievous Wounds."], "zhanghe":["攻击扩散至主目标周围相连的两名随机敌军；伤害增加200%兵略值，目标受到攻击前已眩晕时额外增加400%兵略值。", "Chain to 2 adjacent enemies; gain 200% Strategy and another 400% if the target was stunned before the hit."], "xuhuang":["改为攻击随机一整排，眩晕时长增加3.6秒。", "Strike a random entire row and gain 3.6s stun."], "yujin":["施法目标增加1名，护盾值增加200%兵略值。", "Gain 1 target and 200% Strategy shielding."]}],
		[["xiahouyuan", "caoren"], "神速镇远", "Swift Bulwark", {"xiahouyuan":["冷却缩短0.9秒，眩晕延长0.9秒，伤害增加50%兵略值。", "Cooldown -0.9s, stun +0.9s, and damage +50% Strategy."], "caoren":["目标增加1名，眩晕延长0.9秒，释放技能后受到敌方后军伤害减免提高0.1*兵略值%。", "Gain 1 target, +0.9s stun, and +0.1*Strategy% rear damage reduction."]}],
		[["xiahouyuan", "xiahoudun"], "夏侯同心", "Xiahou Brothers", {"xiahouyuan":["冷却缩短0.9秒，眩晕延长0.9秒，伤害增加50%兵略值。", "Cooldown -0.9s, stun +0.9s, and damage +50% Strategy."], "xiahoudun":["目标增加1名，眩晕延长0.9秒，释放技能后受到敌方前军伤害减免提高0.1*兵略值%。", "Gain 1 target, +0.9s stun, and +0.1*Strategy% vanguard damage reduction."]}],
		[["caoren", "xiahoudun"], "魏武双壁", "Twin Bulwarks", {"caoren":["目标增加1名，眩晕延长0.9秒，释放技能后受到敌方后军伤害减免提高0.1*兵略值%。", "Gain 1 target, +0.9s stun, and +0.1*Strategy% rear damage reduction."], "xiahoudun":["目标增加1名，眩晕延长0.9秒，释放技能后受到敌方前军伤害减免提高0.1*兵略值%。", "Gain 1 target, +0.9s stun, and +0.1*Strategy% vanguard damage reduction."]}],
		[["simayi", "guojia"], "雷霆冰策", "Thunder and Frost", {"simayi":["雷击目标增加1名，伤害减少40%兵略值。", "Gain 1 lightning target but lose 40% Strategy damage."], "guojia":["冻结目标增加1名，冻结时间减少1.5秒。", "Gain 1 freeze target but lose 1.5s freeze duration."]}],
		[["simayi", "xunyu"], "鹰视王佐", "Eagle Eye and Royal Aid", {"simayi":["雷击目标增加1名，伤害减少40%兵略值。", "Gain 1 lightning target but lose 40% Strategy damage."], "xunyu":["施法目标增加1名，行动条速度加成减少0.05×兵略值%。", "Gain 1 target but lose 0.05×Strategy% gauge speed."]}],
		[["simayi", "jiaxu"], "鹰视毒谋", "Eagle Eye and Venom", {"simayi":["伤害增加80%兵略值。", "Gain 80% Strategy damage."], "jiaxu":["中毒层数衰减由50%改为45%（每次伤害后保留55%层数，100→55→30→16…→0）。", "Poison stack decay drops from 50% to 45% (each hit keeps 55% stacks: 100→55→30→16…→0)."]}],
		[["guojia", "xunyu"], "遗计王佐", "Frozen Royal Plan", {"guojia":["冻结时间增加2.1秒。", "Freeze duration gains 2.1s."], "xunyu":["行动条速度加成增加0.12×兵略值%。", "Gauge speed bonus gains 0.12×Strategy%."]}],
		[["guojia", "jiaxu"], "冰毒奇策", "Frost and Venom", {"guojia":["技能冷却减少2.8秒。", "Cooldown is reduced by 2.8s."], "jiaxu":["施法目标增加1名，但施加的毒层数减少0.2×兵略值。", "Gain 1 poison target but apply 0.2×Strategy fewer stacks."]}],
		[["xunyu", "jiaxu"], "王佐毒策", "Royal Venom", {"xunyu":["技能冷却减少2.8秒。", "Cooldown is reduced by 2.8s."], "jiaxu":["技能冷却减少2.8秒。", "Cooldown is reduced by 2.8s."]}],
		[["sunjian", "sunce", "sunquan", "sunshangxiang"], "孙氏之志", "Sun Legacy", {"sunjian":["改为消耗80%当前生命；释放后吴将本回合伤害提高0.15×兵略值%，不可叠加。", "Spend 80% current HP; Wu allies gain 0.15×Strategy% damage for the battle, non-stacking."], "sunce":["追加第二段攻击正前方和右侧敌军，正前方承受两次攻击，且伤害增加50%兵略值。", "Add a second wave and 50% Strategy damage."], "sunquan":["最大生命提高200%兵略值，上限为初始最大生命3倍；随后恢复0.15×兵略值%的已损生命。", "Gain max HP equal to 200% Strategy up to 3x initial HP, then restore Strategy-scaled missing HP."], "sunshangxiang":["每次释放连续攻击两次，释放后兵略值提高2点。", "Each cast releases twice and grants 2 Strategy afterward."]}],
		[["daqiao", "xiaoqiao"], "江东双姝", "Jiangdong Sisters", {"daqiao":["追加1次150%兵略值的治疗。", "Add one 150% Strategy heal."], "xiaoqiao":["行动条减速增加0.12×兵略值%。", "Gauge slow gains 0.12×Strategy%."]}],
		[["lvmeng", "ganning"], "白衣奇袭", "White-Robed Ambush", {"lvmeng":["伤害增加150%兵略值，且无视目标护盾。", "Gain 150% Strategy damage and ignore the target's shield."], "ganning":["攻击生命值低于50%的敌人时，伤害增加180%兵略值。", "Gain 180% Strategy damage against targets below 50% HP."]}],
		[["sunce", "taishici"], "神亭酣战", "Shenting Duel", {"sunce":["造成的伤害增加50%兵略值。", "Gain 50% Strategy damage."], "taishici":["目标增加1名，直接伤害减少30%兵略值。", "Gain 1 target but lose 30% Strategy direct damage."]}],
		[["sunce", "daqiao"], "江东佳偶", "Jiangdong Couple", {"sunce":["自身每损失10%生命，受到伤害减少4%。", "Take 4% less damage per 10% HP missing."], "daqiao":["受治疗友军每损失10%生命，本次治疗提高4%。", "Healing gains 4% per 10% target HP missing."]}],
		[["zhouyu", "xiaoqiao"], "琴瑟和鸣", "Harmonious Zither", {"zhouyu":["灼烧持续时间增加3秒，灼烧伤害增加30%兵略值。", "Burn duration gains 3s and burn damage gains 30% Strategy."], "xiaoqiao":["施法目标增加1名。", "Gain 1 target."]}],
		[["zhouyu", "huanggai"], "赤壁苦计", "Red Cliffs Ruse", {"zhouyu":["灼烧伤害随目标已损生命提高，每损失10%生命，整体灼烧伤害提高6%。", "Burn damage gains 6% per 10% target HP missing."], "huanggai":["命中格灼烧5秒，每秒造成50%兵略值伤害；空格灼烧会伤害主公。", "Burn struck tiles for 5s at 50% Strategy per second; empty tiles damage the ruler."]}],
		[["huanggai", "sunjian"], "江东柱石", "Pillars of Jiangdong", {"huanggai":["最大生命消耗提高至15%，伤害中的实际消耗生命系数提高至50%。", "Max-HP cost rises to 15% and the spent-HP coefficient rises to 50%."], "sunjian":["开局行动条充满。", "Start with a full gauge."]}],
		[["taishici", "ganning"], "江表双锋", "Twin Blades of Jiangbiao", {"taishici":["造成的伤害增加60%兵略值。", "Gain 60% Strategy damage."], "ganning":["技能冷却减少2.1秒。", "Cooldown is reduced by 2.1s."]}],
		[["luxun", "sunquan"], "君臣同心", "Sovereign and Minister", {"luxun":["直接伤害增加80%兵略值，对已灼烧目标额外增加40%兵略值。", "Gain 80% Strategy damage and another 40% against burning targets."], "sunquan":["伤害改为孙权当前生命值的11%。", "Damage becomes 11% of Sun Quan's current HP."]}],
		[["dingfeng", "xusheng"], "江表虎臣", "Tiger Ministers", {"dingfeng":["伤害增加100%兵略值，压退改为70%行动条。", "Gain 100% Strategy damage and push back 70% gauge."], "xusheng":["改为冲击随机一排，水阵持续时间增加5.4秒。", "Strike a random row and increase water formation duration by 5.4s."]}],
		[["yanliang", "wenchou", "qunzhanghe", "gaolan"], "河北四庭柱", "Hebei Pillars", {"yanliang":["技能目标增加1名，伤害增加120%兵略值。", "Gain 1 target and 120% Strategy damage."], "wenchou":["技能目标增加1名，伤害增加150%兵略值。", "Gain 1 target and 150% Strategy damage."], "qunzhanghe":["技能目标增加2名，护盾增加100%兵略值。", "Gain 2 targets and 100% Strategy shielding."], "gaolan":["光环改为同排和同列全部友军兵略值增加0.25×兵略值。", "The aura grants 0.25×Strategy to all allies in Gao Lan's row and column."]}],
		[["huatuo", "yuji"], "医道同源", "Medicine and Immortality", {"huatuo":["青囊三济治疗增加70%兵略值。", "Threefold Remedy gains 70% Strategy healing."], "yuji":["蛊毒仙术增加1个目标。", "Venomous Immortal Art gains 1 target."]}],
		[["huatuo", "zuoci"], "济世仙缘", "Immortal Healers", {"huatuo":["治疗增加30%兵略值，并清除目标全部减益。", "Gain 30% Strategy healing and cleanse all debuffs."], "zuoci":["治疗倍率增加100%兵略值。", "Healing gains 100% Strategy."]}],
		[["yuji", "zuoci"], "方仙同门", "Immortal Lineage", {"yuji":["目标每损失10%生命，受到的所有来源毒伤提高5%。", "All poison damage taken gains 5% per 10% target HP missing."], "zuoci":["治疗时同时雷击两个随机射程内单元格，各造成200%兵略值伤害；空格伤害由主公承受。", "Each heal also strikes 2 random reachable tiles for 200% Strategy lightning damage; empty-tile damage hits the ruler."]}],
		[["zhangjiao", "zhangliang"], "天人同道", "Heaven and Man", {"zhangjiao":["黄天雷引的伤害增加120%兵略值。", "Yellow Sky Thunder gains 120% Strategy damage."], "zhangliang":["人公虚弱增加1个目标。", "Yellow Sky Weakening gains 1 target."]}],
		[["zhangjiao", "zhangbao"], "天地雷契", "Heaven and Earth", {"zhangjiao":["我方友军死亡时立即强化雷击2个单元格，各造成600%兵略值伤害并眩晕2秒。", "Whenever an ally dies, immediately strike 2 tiles for 600% Strategy and stun for 2s."], "zhangbao":["地公雷爆波及每个主目标周围八格武将，造成90%兵略值伤害。", "Earth General Detonation splashes all eight neighboring units for 90% Strategy."]}],
		[["zhangliang", "zhangbao"], "地人续命", "Earth and Man", {"zhangliang":["人公虚弱持续时间增加4.5秒。", "Yellow Sky Weakening gains 4.5s duration."], "zhangbao":["本场战斗额外复生一次。", "Gain one additional revival."]}]
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
		"shu": return t("蜀：2/5/8人时承伤降低2%/5%/8%；8人时每次受伤叠加3%减伤，最多3层，每层持续3秒。", "Shu: at 2/5/8, take 2%/5%/8% less damage; at 8, each hit adds 3% reduction up to 3 stacks, each lasting 3s.")
		"wei": return t("魏：2/5/8人时控制时长提高2%/5%/8%；8人时对受控或带减益目标伤害提高8%。", "Wei: at 2/5/8, control duration gains 2%/5%/8%; at 8, deal 8% more damage to controlled or debuffed targets.")
		"wu": return t("吴：2/5/8人时最大生命提高2%/5%/8%；8人时濒死触发生命均摊并恢复5%最大生命（每30秒一次）。", "Wu: at 2/5/8, gain 2%/5%/8% max HP; at 8, a lethal hit equalizes health and restores 5% max HP (once per 30s).")
		"qun": return t("群：2/5/8人时冷却缩短3.6%/9%/14.4%；8人时释放技能有8%概率连续释放两次。", "Qun: at 2/5/8, cooldown is reduced by 3.6%/9%/14.4%; at 8, casts have an 8% repeat chance.")
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

func _play_sfx(category: String, volume_db := -6.0, min_interval_msec := 60, pitch_jitter := 0.10) -> void:
	# 战斗/界面音效：类别内随机取一个变体，轮转音效池叠放播放；同类别节流防刷屏，随机音调防重复感。
	if sfx_players.is_empty() or not sfx_streams.has(category): return
	var now := Time.get_ticks_msec()
	if now - int(_sfx_last_msec.get(category, -100000)) < min_interval_msec: return
	_sfx_last_msec[category] = now
	var streams: Array = sfx_streams[category]
	var player := sfx_players[sfx_cursor]
	sfx_cursor = (sfx_cursor + 1) % sfx_players.size()
	player.stream = streams[rng.randi_range(0, streams.size() - 1)]
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + rng.randf_range(-pitch_jitter, pitch_jitter)
	player.play()

func _bgm_fade(player: AudioStreamPlayer, fade_in: bool) -> void:
	# fade_in=true：从静音淡入到常规音量并播放；false：淡出到静音后停止(位置归零，下次从头播放)。
	if not is_instance_valid(player) or player.stream == null: return
	var old: Tween = _bgm_tweens.get(player, null)
	if old != null: old.kill()
	var tween := player.create_tween()
	_bgm_tweens[player] = tween
	if fade_in:
		player.volume_db = BGM_FADE_FLOOR_DB
		player.play()
		tween.tween_property(player, "volume_db", BGM_VOLUME_DB, BGM_FADE_TIME)
	else:
		tween.tween_property(player, "volume_db", BGM_FADE_FLOOR_DB, BGM_FADE_TIME)
		tween.tween_callback(player.stop)

func _update_bgm() -> void:
	# 战斗期间播放战斗 BGM，非战斗场景(主菜单/三选一/备战/天书/结算)播放和平 BGM；切换时交叉淡入淡出。
	var target := "battle" if battle_running else "peace"
	if target == _bgm_target: return
	_bgm_target = target
	if target == "battle":
		_bgm_fade(battle_bgm_player, true)
		_bgm_fade(peace_bgm_player, false)
	else:
		_bgm_fade(peace_bgm_player, true)
		_bgm_fade(battle_bgm_player, false)

func _render() -> void:
	if not is_instance_valid(title_label): return
	_update_bgm()
	var campaign_title: Label = find_child("CampaignTitle", true, false)
	var bond_header: Label = find_child("BondHeader", true, false)
	campaign_title.text = t("闯关战局", "CAMPAIGN")
	bond_header.text = t("我方羁绊进度", "YOUR BOND PROGRESS")
	if is_instance_valid(battle_info_tabs):
		battle_info_tabs.set_tab_title(0, t("羁绊组成", "BONDS"))
		battle_info_tabs.set_tab_title(1, t("实时战报", "BATTLE LOG"))
		battle_info_tabs.set_tab_title(2, t("统计图表", "STATISTICS"))
	if game_mode == "challenge": title_label.text = STAGE_NAMES[selected_stage - 1] + " · " + str(DIFFICULTIES[selected_difficulty].name)
	elif game_mode == "tianshu": title_label.text = t("战三国 · 弈定九州 · 天书演武", "THREE KINGDOMS · CODEX TRIAL")
	else: title_label.text = t("战三国 · 弈定九州 · 快速战斗", "THREE KINGDOMS · QUICK BATTLE")
	if game_mode == "challenge": round_label.text = "闯关 %d / 20 · 回合 %d / 15" % [selected_stage, round_number]
	elif game_mode == "tianshu": round_label.text = t("天书演武 ", "CODEX TRIAL ") + str(round_number) + " / " + str(ROUND_LIMIT)
	else: round_label.text = t("最终决战", "FINAL BATTLE") if final_battle else t("关卡 ", "STAGE ") + str(round_number) + " / " + str(ROUND_LIMIT)
	phase_label.text = "◆ " + _phase_name()
	language_button.text = "English" if language == "zh" else "简体中文"
	save_button.text = t("保存", "SAVE")
	load_button.text = t("读取", "LOAD")
	menu_button.text = t("主菜单", "MENU")
	speed_button.text = str(int(game_speed)) + "×"
	tianshu_header_button.text = _tianshu_pavilion_button_text()
	tianshu_header_button.visible = _tianshu_enabled()
	tianshu_header_button.disabled = battle_running or phase not in ["draft", "placement"]
	save_button.disabled = battle_running
	load_button.disabled = battle_running or not FileAccess.file_exists(SAVE_PATH)
	menu_button.disabled = battle_running
	player_hp_label.get_parent().get_node("Caption").text = t("我方主公", "YOUR RULER")
	enemy_hp_label.get_parent().get_node("Caption").text = t("敌方主公", "ENEMY RULER")
	var player_ruler_max := _player_ruler_max_hp()
	player_hp_label.text = str(player_ruler_hp) + "\n/ " + str(player_ruler_max)
	enemy_hp_label.text = str(enemy_ruler_hp) + "\n/ " + str(RULER_MAX_HP)
	player_ruler_fill.anchor_top = 1.0 - clampf(float(player_ruler_hp) / player_ruler_max, 0.0, 1.0)
	enemy_ruler_fill.anchor_top = 1.0 - clampf(float(enemy_ruler_hp) / RULER_MAX_HP, 0.0, 1.0)
	player_ruler_fill.modulate = Color("#a3ffae") if float(ruler_regen.player.get("time", 0.0)) > 0.0 else Color.WHITE
	enemy_ruler_fill.modulate = Color("#a3ffae") if float(ruler_regen.enemy.get("time", 0.0)) > 0.0 else Color.WHITE
	_update_battle_time_bar()
	if is_instance_valid(unit_inspector_overlay) and unit_inspector_overlay.visible:
		_refresh_unit_inspector()
	enemy_title_label.text = t("敌方阵地  ·  后排在上 / 前排在下", "ENEMY FORMATION  ·  BACK TO FRONT")
	player_title_label.text = t("我方阵地  ·  前排在上 / 后排在下", "YOUR FORMATION  ·  FRONT TO BACK")
	if phase == "tianshu": draft_title_label.text = t("天书三选一", "CHOOSE A CODEX")
	elif phase == "draft": draft_title_label.text = t("三选一 · 第%d/3轮" % (PICKS_PER_ROUND - draft_picks_remaining + 1), "PICK 1 OF 3 · ROUND %d/3" % (PICKS_PER_ROUND - draft_picks_remaining + 1))
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
	if phase == "tianshu":
		tianshu_view_only = false
		_render_tianshu_overlay()
		tianshu_overlay.visible = not is_instance_valid(menu_overlay) or not menu_overlay.visible
	elif is_instance_valid(tianshu_overlay) and tianshu_overlay.visible and tianshu_view_only:
		_render_tianshu_overlay()
	elif is_instance_valid(tianshu_overlay) and tianshu_overlay.visible and not tianshu_view_only:
		# 选完天书后保持天书阁打开并切换到管理模式，方便继续购买/替换，由玩家手动关闭。
		tianshu_view_only = true
		_render_tianshu_overlay()
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

func _tianshu_pavilion_button_text() -> String:
	var interest := mini(floori(float(gold) / 10.0), _gold_interest_cap())
	return t("天书阁", "CODEX") + " · 金 " + str(gold) + "\n" \
		+ t("利息：", "Interest: ") + str(interest) + " / " + str(_gold_interest_cap()) + "\n" \
		+ t("收入：", "Income: +") + str(_round_base_gold_income())

func _refresh_economy_ui() -> void:
	if is_instance_valid(tianshu_header_button):
		tianshu_header_button.text = _tianshu_pavilion_button_text()
		tianshu_header_button.tooltip_text = t("回合开始时先结算利息（每 10 金币 +1，上限可被天书/天赋提高），再发放基础收入。", "Round start settles interest first (1 per 10 gold, cap raisable), then base income.")
		tianshu_header_button.disabled = battle_running or phase not in ["draft", "placement"]
	if is_instance_valid(tianshu_gold_label):
		tianshu_gold_label.text = "金　%d" % gold
	if is_instance_valid(tianshu_purchase_button):
		tianshu_purchase_button.disabled = gold < TIANSHU_DRAW_COST or not _can_use_tianshu_pavilion()

func _toggle_battle_pause() -> void:
	if phase != "combat" or not battle_running: return
	battle_paused = not battle_paused
	if battle_paused:
		tick_timer.stop()
	elif not action_in_progress:
		tick_timer.start()
	_render()

func _hint() -> void:
	if phase == "tianshu": hint_label.text = t("从三本彩色天书中点击「获取」选定一本；每张候选卡可独立免费刷新一次。", "Pick one of three prismatic codices with its ACQUIRE button; each card has its own free refresh.")
	elif phase == "draft": hint_label.text = t("拖拽武将时顶部会出现售卖区；备战武将可上阵或互换，场上武将不能退回备战席。", "Drag generals to the top sell zone; reserves can deploy or swap, while field units cannot return to reserve.")
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
			cell.tooltip_text = _hero_name(unit.hero_id) + "\n" + (hero.zh_skill if language == "zh" else hero.skill) + "\n" + _skill_detail(str(unit.hero_id))
			if is_player and selected_unit == unit.id: border = Color("#f0c77a")
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color("#101311")
		normal.border_color = Color("#453d31")
		normal.border_width_left = 1
		normal.border_width_right = 1
		normal.border_width_top = 1
		normal.border_width_bottom = 1
		normal.corner_radius_top_left = 3
		normal.corner_radius_top_right = 3
		normal.corner_radius_bottom_left = 3
		normal.corner_radius_bottom_right = 3
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
			card_layer.add_child(_faction_border_overlay(str(hero.f), true, 0.92))
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
			var row_marks := ["前", "中", "后"]
			var empty := _cell_text(row_marks[row] + "\n" + t("空位", "EMPTY"), 15, Color("#5f594e"))
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

func _faction_border_overlay(faction: String, landscape := true, opacity := 1.0) -> TextureRect:
	var safe_faction := faction if faction in ["shu", "wei", "wu", "qun"] else "qun"
	# The regenerated files are named opposite to their actual orientation:
	# "draft" is the landscape frame and "compact" is the 2:3 draft frame.
	var source: Texture2D = load(CARD_BORDER_ROOT + safe_faction + ("-draft.png" if landscape else "-compact.png"))
	var border := TextureRect.new()
	border.texture = source
	border.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	border.stretch_mode = TextureRect.STRETCH_SCALE
	border.name = "FactionBorder"
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.modulate.a = opacity
	return border

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
		option.custom_minimum_size = Vector2(245 if mobile else 360, 390 if mobile else 480)
		option.add_theme_constant_override("separation", 10)
		var rank_label := _label(t(["前军候选", "中军候选", "后军候选"][choice_index], ["VANGUARD", "MIDGUARD", "REARGUARD"][choice_index]), 18, Color("#f0c77a"))
		rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		option.add_child(rank_label)
		var card := Button.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(245 if mobile else 360, 310 if mobile else 400)
		card.text = ""
		card.tooltip_text = t("点击查看武将完整状态", "Click to inspect the hero") + "\n" + _skill_detail(id)
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
		card.add_child(_faction_border_overlay(str(hero.f), false, 0.96))
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
		skill.offset_top = -65
		skill.offset_bottom = -46
		skill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(skill)
		var detail := _outlined_label(_skill_detail(id), 11, Color("#f2eee6"))
		detail.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		detail.offset_left = 12
		detail.offset_right = -12
		detail.offset_top = -196
		detail.offset_bottom = -76
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		card.add_child(detail)
		var stats := _outlined_label("HP " + str(hero.hp) + "  ·  " + _hero_army_name(id) + "  ·  " + str(hero.cooldown) + t("秒读条", "s cast"), 10, Color("#f2eee6"))
		stats.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		stats.offset_left = 10
		stats.offset_right = -10
		stats.offset_top = -44
		stats.offset_bottom = -27
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(stats)
		card.disabled = battle_running or phase != "draft"
		card.pressed.connect(_show_draft_hero_inspector.bind(id))
		option.add_child(card)
		var recruit := _button(t("招募 " + _hero_name(id), "RECRUIT " + _hero_name(id)))
		recruit.custom_minimum_size = Vector2(0, 62)
		recruit.add_theme_font_size_override("font_size", 19)
		_accent_button(recruit, FACTION_COLORS[hero.f])
		recruit.disabled = battle_running or phase != "draft" or not _can_accept_hero(id)
		recruit.tooltip_text = t("确认招募后不能撤销", "Recruitment cannot be undone")
		recruit.pressed.connect(_choose_hero.bind(id))
		option.add_child(recruit)
		var can_refresh := _tianshu_can_refresh_draft(choice_index)
		var remaining := maxi(0, _tianshu_draft_refresh_limit() - tianshu_draft_refresh_used[choice_index])
		var reroll := _button(t("↻ 仅刷新此选项（剩余%d次）" % remaining, "↻ REFRESH THIS OPTION (%d LEFT)" % remaining)) if can_refresh else _button(t("✓ 本轮已刷新", "✓ REFRESH USED"))
		reroll.custom_minimum_size = Vector2(0, 58)
		reroll.add_theme_font_size_override("font_size", 18)
		reroll.disabled = battle_running or phase != "draft" or not can_refresh
		reroll.pressed.connect(_refresh_draft_choice.bind(choice_index))
		option.add_child(reroll)
		draft_box.add_child(option)

func _clear_dynamic_children(container: Node) -> void:
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
			slot.text = ""
			slot.tooltip_text = t("拖拽到战场上阵或在备战席内换位；拖到顶部售卖区可获得 100 金币", "Drag to deploy or reorder reserves; drop on the top sell zone for 100 gold")
			slot.modulate = Color("#f0c77a") if selected_unit == unit.id else Color.WHITE
			slot.pressed.connect(_on_reserve_pressed.bind(unit.id))
			slot.set_drag_forwarding(_drag_unit.bind(unit.id, slot), _can_drop_reserve.bind(index), _drop_reserve.bind(index))
			var hero: Dictionary = heroes[unit.hero_id]
			slot.add_child(_faction_border_overlay(str(hero.f), true, 0.92))
			var reserve_text := _outlined_label(_hero_name(unit.hero_id) + "\nHP " + str(round(unit.hp)), 11, Color("#f2eee6"))
			reserve_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			reserve_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			reserve_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			slot.add_child(reserve_text)
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
	if origin.get_viewport().gui_is_dragging():
		origin.set_drag_preview(preview)
		_show_sell_zone(unit_id)
	else: preview.queue_free()
	return {"unit_id":unit_id}

func _can_drop_board(_at_position: Vector2, data, _row: int, _col: int) -> bool:
	if phase not in ["draft", "placement"] or not (data is Dictionary) or not data.has("unit_id"): return false
	var source = _find_by_id(player_units, str(data.unit_id))
	if source == null or not _can_unit_use_row(source, _row): return false
	# 君主书限制：持书君主场上最多同时存活一个，场上那个阵亡后备战席的才能上阵。
	if int(source.row) < 0 and _is_lord_book_hero(str(source.hero_id)):
		for unit in player_units:
			if int(unit.row) >= 0 and unit.alive and str(unit.hero_id) == str(source.hero_id) and unit.id != source.id:
				return false
	var occupant = _unit_at(player_units, _row, _col)
	if occupant == null or occupant.id == source.id: return true
	if int(source.row) < 0: return true
	return _can_unit_use_row(occupant, int(source.row))

func _is_lord_book_hero(hero_id: String) -> bool:
	for raw_book_id in tianshu_levels:
		var book: Dictionary = TIANSHU_BOOKS.get(str(raw_book_id), {})
		if book.has("lord") and str(book.lord) == hero_id:
			return true
	return false

func _drop_board(_at_position: Vector2, data, row: int, col: int) -> void:
	if not _can_drop_board(_at_position, data, row, col): return
	var source: Dictionary = _find_by_id(player_units, str(data.unit_id))
	var occupant = _unit_at(player_units, row, col)
	var old_row: int = int(source.row)
	var old_col: int = int(source.col)
	if occupant != null and occupant.id != source.id:
		if old_row < 0:
			occupant.row = -1
			occupant.col = -1
		else:
			occupant.row = old_row  # 两名场上武将互换位置
			occupant.col = old_col
	source.row = row
	source.col = col
	selected_unit = ""
	_hide_sell_zone()
	_log(_hero_name(source.hero_id) + t(" 已拖拽到指定战位。", " was dragged to the selected tile."))
	if old_row < 0:
		# 从备战席首次上阵：拔刀音 + 武将台词；场上换位保持安静。
		_play_sfx("deploy", -10.0, 100, 0.08)
		_play_hero_voice(str(source.hero_id), true)
	_render()

func _can_drop_reserve(_at_position: Vector2, data, _index: int) -> bool:
	if phase not in ["draft", "placement"] or not (data is Dictionary) or not data.has("unit_id"): return false
	var source = _find_by_id(player_units, str(data.unit_id))
	return source != null and int(source.row) < 0

func _drop_reserve(_at_position: Vector2, data, index: int) -> void:
	if not _can_drop_reserve(_at_position, data, index): return
	var source: Dictionary = _find_by_id(player_units, str(data.unit_id))
	var reserves := _reserve_units()
	var target = reserves[index] if index < reserves.size() else null
	if target != null and target.id != source.id:
		var source_index := player_units.find(source)
		var target_index := player_units.find(target)
		player_units[source_index] = target
		player_units[target_index] = source
	selected_unit = ""
	_hide_sell_zone()
	_render()

func _on_reserve_input(event: InputEvent, unit_id: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_sell_reserve_unit(unit_id)

func _sell_reserve_unit(unit_id: String) -> void:
	if battle_running or phase not in ["draft", "placement"]: return
	var unit = _find_by_id(player_units, unit_id)
	if unit == null: return
	var price := _unit_sell_price(unit)
	player_units.erase(unit)
	pending_unit_ids.erase(unit_id)
	_earn_gold(price, "出售 " + _hero_name(str(unit.hero_id)))
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
