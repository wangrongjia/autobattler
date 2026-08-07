extends "res://ThreeKingdom/systems/game_ui.gd"

const BALANCE_PROJECT_PATH := "res://ThreeKingdom/data/hero_balance_overrides.json"
const BALANCE_USER_PATH := "user://hero_balance_overrides.json"
const LAB_LINEUPS_PATH := "user://balance_lab_lineups.json"
const FAST_BATTLE_LIMIT := 300.0
const FAST_BATTLE_MAX_ACTIONS := 12000

var balance_lab_overlay: Control
var balance_lab_tabs: TabContainer
var balance_editor_hero_list: ItemList
var balance_editor_faction: OptionButton
var balance_editor_hp: SpinBox
var balance_editor_skill_value: SpinBox
var balance_editor_cooldown: SpinBox
var balance_editor_range: SpinBox
var balance_editor_params: TextEdit
var balance_editor_status: Label
var balance_editor_selected_id := ""
var balance_default_heroes := {}
var balance_overrides := {}
var balance_project_writable := false

var lab_player_lineup: Array = []
var lab_enemy_lineup: Array = []
var lab_player_hero: OptionButton
var lab_enemy_hero: OptionButton
var lab_player_faction: OptionButton
var lab_enemy_faction: OptionButton
var lab_player_star: OptionButton
var lab_enemy_star: OptionButton
var lab_player_board: GridContainer
var lab_enemy_board: GridContainer
var lab_player_selected_pos := Vector2i(-1, -1)
var lab_enemy_selected_pos := Vector2i(-1, -1)
var lab_preset_name: LineEdit
var lab_preset_list: ItemList
var lab_runs: SpinBox
var lab_run_button: Button
var lab_live_start_button: Button
var lab_result: RichTextLabel
var lab_battle_split: VSplitContainer
var lab_setup_panel: Control
var lab_result_panel: Control
var lab_status: Label
var lab_presets: Array = []
var lab_live_battle := false
var lab_live_paused := false
var lab_live_stop_requested := false
var lab_live_snapshot := {}
var lab_live_hud: Control
var lab_live_time_label: Label
var lab_live_speed_button: Button
var lab_live_pause_button: Button
var lab_live_end_button: Button

func _load_balance_overrides() -> void:
	balance_default_heroes = heroes.duplicate(true)
	balance_project_writable = _can_write_project_balance()
	var loaded = _read_json_file(BALANCE_PROJECT_PATH, {})
	if not balance_project_writable:
		var user_loaded = _read_json_file(BALANCE_USER_PATH, {})
		if user_loaded is Dictionary and not user_loaded.is_empty():
			loaded = user_loaded
	balance_overrides = {}
	if loaded is Dictionary:
		for hero_id in loaded:
			if heroes.has(hero_id) and loaded[hero_id] is Dictionary:
				var normalized := _normalize_hero_override(loaded[hero_id], str(hero_id))
				balance_overrides[hero_id] = normalized
				_apply_hero_override(hero_id, normalized)

func _can_write_project_balance() -> bool:
	var probe_path := "res://ThreeKingdom/data/.balance_write_probe.tmp"
	var probe := FileAccess.open(probe_path, FileAccess.WRITE)
	if probe == null:
		return false
	probe.store_string("ok")
	probe.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(probe_path))
	return true

func _read_json_file(path: String, fallback):
	if not FileAccess.file_exists(path):
		return fallback
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return fallback
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed != null else fallback

func _write_json_file(path: String, value) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "\t"))
	file.close()
	return true

func _apply_hero_override(hero_id: String, data: Dictionary) -> void:
	var hero: Dictionary = heroes[hero_id]
	hero.hp = maxi(1, int(data.get("hp", hero.hp)))
	hero.skill_value = maxi(0, int(data.get("skill_value", hero.skill_value)))
	hero.cooldown = maxf(COOLDOWN_INPUT_MIN, float(data.get("cooldown", hero.cooldown)))
	hero.range = clampi(int(data.get("range", hero.range)), 1, 3)
	if data.get("ability_params", null) is Dictionary:
		# Merge saved values over the current schema so newly added skill/bond
		# parameters survive older Balance Lab save files.
		var params: Dictionary = hero.get("ability_params", {}).duplicate(true)
		for key in data.ability_params:
			params[key] = data.ability_params[key]
		for derived_key in ["base_value", "base_heal", "base_shield", "burn_per_sec"]:
			params.erase(derived_key)
		hero.ability_params = params
	heroes[hero_id] = hero
	_finalize_hero_skill_values(hero_id)

func _normalize_hero_override(data: Dictionary, hero_id := "") -> Dictionary:
	var normalized := {}
	for key in ["hp", "skill_value", "cooldown", "range"]:
		if data.has(key):
			normalized[key] = maxf(COOLDOWN_INPUT_MIN, float(data[key])) if key == "cooldown" else data[key]
	if data.get("ability_params", null) is Dictionary:
		normalized["ability_params"] = data.ability_params.duplicate(true)
	return normalized

func _editable_ability_params(hero_id: String) -> Dictionary:
	var params: Dictionary = heroes[hero_id].get("ability_params", {}).duplicate(true)
	for derived_key in ["base_value", "base_heal", "base_shield", "burn_per_sec"]:
		params.erase(derived_key)
	return params

func _save_balance_overrides() -> bool:
	var path := BALANCE_PROJECT_PATH if balance_project_writable else BALANCE_USER_PATH
	return _write_json_file(path, balance_overrides)

func _build_balance_lab() -> void:
	_load_lab_presets()
	balance_lab_overlay = ColorRect.new()
	balance_lab_overlay.color = Color("#07090cfb")
	balance_lab_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	balance_lab_overlay.z_index = 1300
	balance_lab_overlay.hide()
	add_child(balance_lab_overlay)
	_build_lab_live_hud()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	balance_lab_overlay.add_child(margin)
	var panel := PanelContainer.new()
	_style(panel, Color("#141617"), 16, Color("#8e673d"), 2)
	margin.add_child(panel)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 10)
	panel.add_child(root_box)

	var header := HBoxContainer.new()
	root_box.add_child(header)
	var title := _label(t("平衡实验室", "BALANCE LAB"), 30, Color("#f0c77a"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := _button(t("返回主菜单", "BACK"))
	close.custom_minimum_size.x = 150
	close.pressed.connect(func(): balance_lab_overlay.hide())
	header.add_child(close)

	var tabs := TabContainer.new()
	balance_lab_tabs = tabs
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 16)
	root_box.add_child(tabs)
	var editor_page := VBoxContainer.new()
	editor_page.name = "英雄数值"
	tabs.add_child(editor_page)
	var battle_page := VBoxContainer.new()
	battle_page.name = "快速战斗"
	tabs.add_child(battle_page)
	tabs.set_tab_title(0, t("英雄数值", "HERO VALUES"))
	tabs.set_tab_title(1, t("快速战斗", "QUICK BATTLE"))
	_build_balance_editor_page(editor_page)
	_build_fast_battle_page(battle_page)

func _build_lab_live_hud() -> void:
	lab_live_hud = MarginContainer.new()
	lab_live_hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lab_live_hud.offset_left = 330
	lab_live_hud.offset_right = -330
	lab_live_hud.offset_top = 74
	lab_live_hud.offset_bottom = 136
	lab_live_hud.z_index = 1200
	lab_live_hud.mouse_filter = Control.MOUSE_FILTER_STOP
	lab_live_hud.hide()
	add_child(lab_live_hud)
	var panel := PanelContainer.new()
	_style(panel, Color("#15191df2"), 12, Color("#d8a852"), 2)
	lab_live_hud.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var title := _label(t("均衡实验室 · 实战演练", "BALANCE LAB · LIVE BATTLE"), 19, Color("#f0c77a"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	lab_live_time_label = _label("", 15, Color("#d8d0c1"))
	lab_live_time_label.custom_minimum_size.x = 150
	lab_live_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(lab_live_time_label)
	lab_live_speed_button = _button("")
	lab_live_speed_button.custom_minimum_size.x = 100
	lab_live_speed_button.pressed.connect(_cycle_lab_live_speed)
	row.add_child(lab_live_speed_button)
	lab_live_pause_button = _button(t("暂停", "PAUSE"))
	lab_live_pause_button.custom_minimum_size.x = 110
	lab_live_pause_button.tooltip_text = t("暂停行动条、状态计时和战斗计时；当前动作会先播放完毕", "Pause gauges, status timers, and battle time after the current action finishes")
	lab_live_pause_button.pressed.connect(_toggle_lab_live_pause)
	row.add_child(lab_live_pause_button)
	lab_live_end_button = _button(t("手动结束", "END BATTLE"))
	lab_live_end_button.custom_minimum_size.x = 140
	lab_live_end_button.pressed.connect(_request_end_lab_live_battle)
	row.add_child(lab_live_end_button)

func _show_balance_lab() -> void:
	_refresh_balance_hero_list()
	_refresh_lab_lineups()
	_refresh_lab_presets()
	balance_lab_overlay.show()

func _build_balance_editor_page(page: VBoxContainer) -> void:
	var help := _label(t("这里只调整生命、射程、技能基础数值、技能冷却和技能机制参数。修改后立即影响后续战斗，并写入数值覆盖文件。", "Only HP, range, skill base value, skill cooldown, and skill mechanic parameters are editable. Changes affect future battles immediately and are written to the balance override file."), 13, Color("#c9c0b1"))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(help)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	page.add_child(columns)

	var picker_panel := PanelContainer.new()
	picker_panel.custom_minimum_size.x = 360
	_style(picker_panel, Color("#1d2021"), 10, Color("#4a4640"), 1)
	columns.add_child(picker_panel)
	var picker := VBoxContainer.new()
	picker_panel.add_child(picker)
	balance_editor_faction = OptionButton.new()
	balance_editor_faction.add_item(t("全部阵营", "All factions"))
	for faction in ["shu", "wei", "wu", "qun"]:
		balance_editor_faction.add_item(_faction_name(faction))
	balance_editor_faction.item_selected.connect(func(_index): _refresh_balance_hero_list())
	picker.add_child(balance_editor_faction)
	balance_editor_hero_list = ItemList.new()
	balance_editor_hero_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_enable_touch_value_scroll(balance_editor_hero_list)
	balance_editor_hero_list.item_selected.connect(_select_balance_hero)
	picker.add_child(balance_editor_hero_list)

	var values_panel := PanelContainer.new()
	values_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style(values_panel, Color("#1d2021"), 10, Color("#4a4640"), 1)
	columns.add_child(values_panel)
	var values := VBoxContainer.new()
	values.add_theme_constant_override("separation", 9)
	values_panel.add_child(values)
	values.add_child(_label(t("英雄与技能参数", "HERO & SKILL VALUES"), 22, Color("#e3c58c")))
	balance_editor_hp = _lab_spinbox(1, 200000, 1)
	balance_editor_skill_value = _lab_spinbox(0, 10000, 1)
	balance_editor_cooldown = _lab_spinbox(COOLDOWN_INPUT_MIN, 3600.0, 0.1)
	balance_editor_range = _lab_spinbox(1, 3, 1)
	values.add_child(_lab_value_row(t("生命", "HP"), balance_editor_hp))
	values.add_child(_lab_value_row(t("技能基础数值", "Skill base value"), balance_editor_skill_value))
	values.add_child(_lab_value_row(t("技能冷却（秒）", "Skill cooldown (seconds)"), balance_editor_cooldown))
	values.add_child(_lab_value_row(t("射程层级", "Range tier"), balance_editor_range))
	values.add_child(_label(t("技能参数 JSON（派生伤害值会自动重算）", "SKILL PARAMS JSON (derived values recalculate)"), 14, Color("#e3c58c")))
	balance_editor_params = TextEdit.new()
	balance_editor_params.custom_minimum_size.y = 250
	balance_editor_params.size_flags_vertical = Control.SIZE_EXPAND_FILL
	balance_editor_params.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	values.add_child(balance_editor_params)
	var actions := HBoxContainer.new()
	values.add_child(actions)
	var save := _button(t("保存此武将", "SAVE HERO"))
	save.pressed.connect(_save_selected_hero_balance)
	actions.add_child(save)
	var reset := _button(t("恢复默认", "RESET HERO"))
	reset.pressed.connect(_reset_selected_hero_balance)
	actions.add_child(reset)
	var export_all := _button(t("复制全部数值", "COPY ALL"))
	export_all.pressed.connect(_copy_balance_data)
	actions.add_child(export_all)
	var import_all := _button(t("从剪贴板导入", "IMPORT CLIPBOARD"))
	import_all.pressed.connect(_import_balance_data)
	actions.add_child(import_all)
	balance_editor_status = _label("", 13, Color("#90c59e"))
	balance_editor_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	values.add_child(balance_editor_status)
	_refresh_balance_hero_list()

func _lab_spinbox(minimum: float, maximum: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.allow_greater = true
	spin.custom_minimum_size = Vector2(230, 42)
	return spin

func _lab_value_row(caption: String, editor: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := _label(caption, 15, Color("#c9c0b1"))
	label.custom_minimum_size.x = 180
	row.add_child(label)
	row.add_child(editor)
	return row

func _refresh_balance_hero_list() -> void:
	if not is_instance_valid(balance_editor_hero_list): return
	balance_editor_hero_list.clear()
	var factions := ["", "shu", "wei", "wu", "qun"]
	var filter: String = factions[balance_editor_faction.selected] if is_instance_valid(balance_editor_faction) else ""
	for hero_id in heroes:
		if not filter.is_empty() and heroes[hero_id].f != filter: continue
		var index := balance_editor_hero_list.add_item(_hero_name(hero_id) + " · " + _faction_name(heroes[hero_id].f))
		balance_editor_hero_list.set_item_metadata(index, hero_id)
	if balance_editor_hero_list.item_count > 0:
		balance_editor_hero_list.select(0)
		_select_balance_hero(0)

func _select_balance_hero(index: int) -> void:
	balance_editor_selected_id = str(balance_editor_hero_list.get_item_metadata(index))
	var hero: Dictionary = heroes[balance_editor_selected_id]
	balance_editor_cooldown.min_value = COOLDOWN_INPUT_MIN
	balance_editor_hp.value = float(hero.hp)
	balance_editor_skill_value.value = float(hero.skill_value)
	balance_editor_cooldown.value = float(hero.cooldown)
	balance_editor_range.value = float(hero.range)
	balance_editor_params.text = JSON.stringify(_editable_ability_params(balance_editor_selected_id), "\t")
	balance_editor_status.text = _hero_name(balance_editor_selected_id) + t(" · 当前实战数据", " · current combat values")

func _save_selected_hero_balance() -> void:
	if balance_editor_selected_id.is_empty(): return
	var parsed = JSON.parse_string(balance_editor_params.text)
	if not parsed is Dictionary:
		balance_editor_status.text = t("技能参数不是有效的 JSON 对象，未保存。", "Skill params are not a valid JSON object; nothing was saved.")
		balance_editor_status.add_theme_color_override("font_color", Color("#df7878"))
		return
	var data := {
		"hp": int(balance_editor_hp.value),
		"skill_value": int(balance_editor_skill_value.value),
		"cooldown": float(balance_editor_cooldown.value),
		"range": int(balance_editor_range.value),
		"ability_params": parsed
	}
	balance_overrides[balance_editor_selected_id] = data
	_apply_hero_override(balance_editor_selected_id, data)
	_apply_balance_to_existing_units(balance_editor_selected_id)
	var saved := _save_balance_overrides()
	balance_editor_status.text = t("已保存到：", "Saved to: ") + (BALANCE_PROJECT_PATH if balance_project_writable else BALANCE_USER_PATH) if saved else t("保存失败，请检查目录写入权限。", "Save failed; check directory permissions.")
	balance_editor_status.add_theme_color_override("font_color", Color("#90c59e") if saved else Color("#df7878"))
	_select_balance_hero(balance_editor_hero_list.get_selected_items()[0])

func _reset_selected_hero_balance() -> void:
	if balance_editor_selected_id.is_empty() or not balance_default_heroes.has(balance_editor_selected_id): return
	heroes[balance_editor_selected_id] = balance_default_heroes[balance_editor_selected_id].duplicate(true)
	balance_overrides.erase(balance_editor_selected_id)
	_finalize_hero_skill_values(balance_editor_selected_id)
	_apply_balance_to_existing_units(balance_editor_selected_id)
	_save_balance_overrides()
	_select_balance_hero(balance_editor_hero_list.get_selected_items()[0])
	balance_editor_status.text = t("已恢复该武将的代码默认值。", "Hero restored to code defaults.")

func _apply_balance_to_existing_units(hero_id: String) -> void:
	for roster in [player_units, enemy_units]:
		for unit in roster:
			if unit.hero_id != hero_id: continue
			var ratio: float = float(unit.hp) / maxf(1.0, float(unit.max_hp))
			unit.max_hp = float(heroes[hero_id].hp) * float(unit.get("stat_mult", 1.0))
			unit.hp = unit.max_hp * ratio
			if hero_id == "sunquan":
				unit.sunquan_initial_max_hp = float(unit.max_hp)

func _copy_balance_data() -> void:
	DisplayServer.clipboard_set(JSON.stringify(balance_overrides, "\t"))
	balance_editor_status.text = t("全部数值覆盖已复制到剪贴板。", "All balance overrides copied to clipboard.")

func _import_balance_data() -> void:
	var parsed = JSON.parse_string(DisplayServer.clipboard_get())
	if not parsed is Dictionary:
		balance_editor_status.text = t("剪贴板不是有效的数值覆盖 JSON。", "Clipboard does not contain valid balance override JSON.")
		return
	for hero_id in parsed:
		if heroes.has(hero_id) and parsed[hero_id] is Dictionary:
			var normalized := _normalize_hero_override(parsed[hero_id], str(hero_id))
			balance_overrides[hero_id] = normalized
			_apply_hero_override(hero_id, normalized)
			_apply_balance_to_existing_units(hero_id)
	_save_balance_overrides()
	_refresh_balance_hero_list()
	balance_editor_status.text = t("已导入并应用数值覆盖。", "Balance overrides imported and applied.")

func _build_fast_battle_page(page: VBoxContainer) -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	page.add_child(top)
	lab_preset_name = LineEdit.new()
	lab_preset_name.placeholder_text = t("阵容方案名称", "Lineup preset name")
	lab_preset_name.custom_minimum_size.x = 260
	top.add_child(lab_preset_name)
	top.add_child(_label(t("演练次数", "Runs"), 14, Color("#c9c0b1")))
	lab_runs = _lab_spinbox(1, 200, 1)
	lab_runs.value = 10
	lab_runs.custom_minimum_size.x = 110
	top.add_child(lab_runs)
	lab_run_button = _button(t("立即结算", "RUN NOW"))
	lab_run_button.custom_minimum_size.x = 180
	lab_run_button.pressed.connect(_run_fast_battles)
	top.add_child(lab_run_button)
	lab_live_start_button = _button(t("开始实战", "START LIVE"))
	lab_live_start_button.custom_minimum_size.x = 180
	lab_live_start_button.tooltip_text = t("按当前双方阵容进入无回合、不可换将的可视化实战", "Start a visual battle using the current formations, with no rounds or substitutions")
	lab_live_start_button.pressed.connect(_start_lab_live_battle)
	top.add_child(lab_live_start_button)
	lab_status = _label(t("300秒真实逻辑演练；未击败主公时按剩余战力判定。", "300s real-logic simulation; remaining army strength breaks ruler ties."), 13, Color("#c9c0b1"))
	lab_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(lab_status)

	var view_actions := HBoxContainer.new()
	view_actions.add_theme_constant_override("separation", 6)
	page.add_child(view_actions)
	var formation_only := _button(t("只看选将与布阵", "FORMATION ONLY"))
	formation_only.pressed.connect(_set_lab_view_mode.bind("formation"))
	view_actions.add_child(formation_only)
	var result_only := _button(t("只看结算", "RESULT ONLY"))
	result_only.pressed.connect(_set_lab_view_mode.bind("result"))
	view_actions.add_child(result_only)
	var coexist := _button(t("同时显示", "SHOW BOTH"))
	coexist.pressed.connect(_set_lab_view_mode.bind("both"))
	view_actions.add_child(coexist)
	var resize_help := _label(t("同时显示时，可拖动中间分隔线放大或缩小两个区域。", "When both are visible, drag the divider to resize either area."), 12, Color("#887e70"))
	resize_help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resize_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	view_actions.add_child(resize_help)

	lab_battle_split = VSplitContainer.new()
	lab_battle_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lab_battle_split.split_offset = 390
	page.add_child(lab_battle_split)
	var setup := HBoxContainer.new()
	lab_setup_panel = setup
	setup.custom_minimum_size.y = 330
	setup.add_theme_constant_override("separation", 12)
	lab_battle_split.add_child(setup)
	var player_panel := _build_lineup_side(true)
	player_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup.add_child(player_panel)
	setup.add_child(_build_preset_panel())
	var enemy_panel := _build_lineup_side(false)
	enemy_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup.add_child(enemy_panel)

	var result_panel := PanelContainer.new()
	lab_result_panel = result_panel
	_style(result_panel, Color("#17191a"), 10, Color("#4a4640"), 1)
	lab_battle_split.add_child(result_panel)
	lab_result = RichTextLabel.new()
	lab_result.bbcode_enabled = true
	lab_result.fit_content = false
	lab_result.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lab_result.custom_minimum_size.y = 150
	lab_result.add_theme_font_size_override("normal_font_size", 13)
	_enable_touch_value_scroll(lab_result)
	lab_result.text = t("[color=#887e70]配置双方阵容后点击“立即结算”。结果会汇总胜率、伤害、承伤、治疗和控制。[/color]", "[color=#887e70]Configure both teams and run. Results aggregate win rate, damage, taken, healing and control.[/color]")
	result_panel.add_child(lab_result)

func _set_lab_view_mode(mode: String) -> void:
	if not is_instance_valid(lab_setup_panel) or not is_instance_valid(lab_result_panel): return
	lab_setup_panel.visible = mode != "result"
	lab_result_panel.visible = mode != "formation"
	if mode == "both":
		lab_battle_split.split_offset = 390

func _build_lineup_side(is_player: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	_style(panel, Color("#1d2021"), 10, Color("#4a664f") if is_player else Color("#704b46"), 2)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title := _label(t("我方阵容", "PLAYER TEAM") if is_player else t("敌方阵容", "ENEMY TEAM"), 20, Color("#90c59e") if is_player else Color("#d89a8f"))
	box.add_child(title)
	var pick_row := HBoxContainer.new()
	pick_row.add_theme_constant_override("separation", 5)
	box.add_child(pick_row)
	var faction_option := OptionButton.new()
	faction_option.custom_minimum_size.x = 88
	faction_option.add_item(t("全部", "ALL"))
	for faction in ["shu", "wei", "wu", "qun"]:
		faction_option.add_item(_faction_name(faction))
	faction_option.item_selected.connect(func(_index): _refresh_lab_hero_option(is_player))
	pick_row.add_child(faction_option)
	var hero_option := OptionButton.new()
	hero_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick_row.add_child(hero_option)
	var star_option := OptionButton.new()
	for level in [1, 2, 3]: star_option.add_item("★".repeat(level), level)
	pick_row.add_child(star_option)
	var add := _button(t("自动加入", "AUTO ADD"))
	add.custom_minimum_size.x = 105
	add.pressed.connect(_add_lab_unit.bind(is_player))
	pick_row.add_child(add)
	var board_help_text := t("前排 ↑　拖拽武将可移动或交换位置　↓ 后排", "FRONT ↑  Drag heroes to move or swap  ↓ BACK")
	var board_help := _label(board_help_text, 11, Color("#887e70"))
	board_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(board_help)
	var board := GridContainer.new()
	board.columns = BOARD_COLUMNS
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.add_theme_constant_override("h_separation", 4)
	board.add_theme_constant_override("v_separation", 4)
	box.add_child(board)
	var slot_script = preload("res://ThreeKingdom/systems/lab_board_slot.gd")
	for display_row in BOARD_ROWS:
		var row: int = display_row
		for col in BOARD_COLUMNS:
			var slot = slot_script.new()
			slot.lab_owner = self
			slot.is_player_side = is_player
			slot.board_row = row
			slot.board_col = col
			slot.custom_minimum_size = Vector2(88, 48)
			slot.mouse_default_cursor_shape = Control.CURSOR_DRAG
			slot.add_theme_font_size_override("font_size", 11)
			var empty_style := StyleBoxFlat.new()
			empty_style.bg_color = Color("#111416")
			empty_style.border_color = Color("#3b4143")
			empty_style.set_border_width_all(1)
			empty_style.set_corner_radius_all(6)
			var hover_style: StyleBoxFlat = empty_style.duplicate()
			hover_style.bg_color = Color("#26333a")
			slot.add_theme_stylebox_override("normal", empty_style)
			slot.add_theme_stylebox_override("hover", hover_style)
			slot.pressed.connect(_select_lab_board_unit.bind(is_player, row, col))
			board.add_child(slot)
	var selected_actions := HBoxContainer.new()
	selected_actions.add_theme_constant_override("separation", 5)
	box.add_child(selected_actions)
	var star_down := _button("－★")
	star_down.tooltip_text = t("选中武将降一星", "Decrease selected hero star")
	star_down.pressed.connect(_change_lab_unit_star.bind(-1, is_player))
	selected_actions.add_child(star_down)
	var star_up := _button("＋★")
	star_up.tooltip_text = t("选中武将升一星；双击列表也可升星", "Increase selected hero star; double-click also works")
	star_up.pressed.connect(_change_lab_unit_star.bind(1, is_player))
	selected_actions.add_child(star_up)
	var remove := _button(t("移除", "REMOVE"))
	remove.pressed.connect(_remove_lab_unit.bind(is_player))
	selected_actions.add_child(remove)
	var lineup_actions := HBoxContainer.new()
	lineup_actions.add_theme_constant_override("separation", 5)
	box.add_child(lineup_actions)
	var arrange := _button(t("自动整理站位", "AUTO ARRANGE"))
	arrange.pressed.connect(_auto_arrange_lab_lineup.bind(is_player))
	lineup_actions.add_child(arrange)
	var clear := _button(t("清空", "CLEAR"))
	clear.pressed.connect(_clear_lab_lineup.bind(is_player))
	lineup_actions.add_child(clear)
	if is_player:
		lab_player_faction = faction_option
		lab_player_hero = hero_option
		lab_player_star = star_option
		lab_player_board = board
	else:
		lab_enemy_faction = faction_option
		lab_enemy_hero = hero_option
		lab_enemy_star = star_option
		lab_enemy_board = board
	_refresh_lab_hero_option(is_player)
	return panel

func _populate_lab_hero_option(option: OptionButton, faction_filter := "") -> void:
	option.clear()
	for hero_id in heroes:
		if not faction_filter.is_empty() and str(heroes[hero_id].f) != faction_filter: continue
		var index := option.get_item_count()
		option.add_item(_hero_name(hero_id) + " · " + _faction_name(heroes[hero_id].f), index)
		option.set_item_metadata(index, hero_id)

func _refresh_lab_hero_option(is_player: bool) -> void:
	var faction_option := lab_player_faction if is_player else lab_enemy_faction
	var hero_option := lab_player_hero if is_player else lab_enemy_hero
	if not is_instance_valid(faction_option) or not is_instance_valid(hero_option): return
	var factions := ["", "shu", "wei", "wu", "qun"]
	_populate_lab_hero_option(hero_option, factions[clampi(faction_option.selected, 0, factions.size() - 1)])

func _build_preset_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 285
	_style(panel, Color("#191b1c"), 10, Color("#8e673d"), 1)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(_label(t("已保存阵容", "SAVED PRESETS"), 18, Color("#e3c58c")))
	lab_preset_list = ItemList.new()
	lab_preset_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_enable_touch_value_scroll(lab_preset_list)
	lab_preset_list.item_activated.connect(func(_index): _load_selected_lab_preset())
	box.add_child(lab_preset_list)
	var save := _button(t("保存当前", "SAVE CURRENT"))
	save.pressed.connect(_save_current_lab_preset)
	box.add_child(save)
	var load_button := _button(t("载入", "LOAD"))
	load_button.pressed.connect(_load_selected_lab_preset)
	box.add_child(load_button)
	var transfer := HBoxContainer.new()
	box.add_child(transfer)
	var export_button := _button(t("导出", "EXPORT"))
	export_button.pressed.connect(_export_selected_lab_preset)
	transfer.add_child(export_button)
	var import_button := _button(t("导入", "IMPORT"))
	import_button.pressed.connect(_import_lab_preset)
	transfer.add_child(import_button)
	var delete_button := _button(t("删除", "DELETE"))
	delete_button.pressed.connect(_delete_selected_lab_preset)
	box.add_child(delete_button)
	return panel

func _add_lab_unit(is_player: bool) -> void:
	var hero_option := lab_player_hero if is_player else lab_enemy_hero
	var star_option := lab_player_star if is_player else lab_enemy_star
	var lineup: Array = lab_player_lineup if is_player else lab_enemy_lineup
	if hero_option.item_count == 0: return
	var hero_id := str(hero_option.get_item_metadata(hero_option.selected))
	var level := star_option.selected + 1
	for entry in lineup:
		if str(entry.hero_id) != hero_id: continue
		entry.level = level
		lab_status.text = _hero_name(hero_id) + t(" 已更新为", " updated to ") + "★".repeat(level)
		_refresh_lab_lineups()
		return
	var position := _next_lab_position(lineup, hero_id)
	if position.x < 0:
		lab_status.text = t("没有适合该武将的空位；可移除武将或点击自动整理。", "No suitable slot; remove a hero or auto-arrange.")
		return
	lineup.append({"hero_id":hero_id, "level":level, "row":position.x, "col":position.y})
	if is_player: lab_player_selected_pos = position
	else: lab_enemy_selected_pos = position
	lab_status.text = _hero_name(hero_id) + t(" 已自动加入阵容。", " auto-added to the lineup.")
	_refresh_lab_lineups()

func _remove_lab_unit(is_player: bool) -> void:
	var lineup: Array = lab_player_lineup if is_player else lab_enemy_lineup
	var index := _selected_lab_entry_index(is_player)
	if index < 0: return
	lineup.remove_at(index)
	if is_player: lab_player_selected_pos = Vector2i(-1, -1)
	else: lab_enemy_selected_pos = Vector2i(-1, -1)
	_refresh_lab_lineups()

func _change_lab_unit_star(delta: int, is_player: bool) -> void:
	var lineup: Array = lab_player_lineup if is_player else lab_enemy_lineup
	var index := _selected_lab_entry_index(is_player)
	if index < 0: return
	lineup[index].level = clampi(int(lineup[index].level) + delta, 1, 3)
	_refresh_lab_lineups()

func _clear_lab_lineup(is_player: bool) -> void:
	if is_player:
		lab_player_lineup.clear()
		lab_player_selected_pos = Vector2i(-1, -1)
	else:
		lab_enemy_lineup.clear()
		lab_enemy_selected_pos = Vector2i(-1, -1)
	_refresh_lab_lineups()

func _lab_unit_at(is_player: bool, row: int, col: int):
	var lineup: Array = lab_player_lineup if is_player else lab_enemy_lineup
	for entry in lineup:
		if int(entry.row) == row and int(entry.col) == col: return entry
	return null

func _select_lab_board_unit(is_player: bool, row: int, col: int) -> void:
	var position := Vector2i(row, col) if _lab_unit_at(is_player, row, col) != null else Vector2i(-1, -1)
	if is_player: lab_player_selected_pos = position
	else: lab_enemy_selected_pos = position
	_refresh_lab_lineups()

func _selected_lab_entry_index(is_player: bool) -> int:
	var lineup: Array = lab_player_lineup if is_player else lab_enemy_lineup
	var position := lab_player_selected_pos if is_player else lab_enemy_selected_pos
	for index in lineup.size():
		if int(lineup[index].row) == position.x and int(lineup[index].col) == position.y:
			return index
	return -1

func _can_move_lab_unit(is_player: bool, from_row: int, from_col: int, to_row: int, to_col: int) -> bool:
	var source = _lab_unit_at(is_player, from_row, from_col)
	if source == null: return false
	if not bool(heroes[source.hero_id].get("all_rows", false)) and int(heroes[source.hero_id].range) == 1 and to_row != 0: return false
	var target = _lab_unit_at(is_player, to_row, to_col)
	if target != null and not bool(heroes[target.hero_id].get("all_rows", false)) and int(heroes[target.hero_id].range) == 1 and from_row != 0: return false
	return true

func _move_lab_unit(is_player: bool, from_row: int, from_col: int, to_row: int, to_col: int) -> void:
	if not _can_move_lab_unit(is_player, from_row, from_col, to_row, to_col): return
	var source = _lab_unit_at(is_player, from_row, from_col)
	var target = _lab_unit_at(is_player, to_row, to_col)
	source.row = to_row
	source.col = to_col
	if target != null:
		target.row = from_row
		target.col = from_col
	var position := Vector2i(to_row, to_col)
	if is_player: lab_player_selected_pos = position
	else: lab_enemy_selected_pos = position
	lab_status.text = t("已调整武将站位。", "Hero position updated.")
	_refresh_lab_lineups()

func _preferred_lab_rows(hero_id: String) -> Array:
	if bool(heroes[hero_id].get("all_rows", false)): return [0, 1, 2]
	var range_tier := int(heroes[hero_id].range)
	if range_tier == 1: return [0]
	if range_tier == 2: return [1, 0, 2]
	return [2, 1, 0]

func _next_lab_position(lineup: Array, hero_id: String) -> Vector2i:
	for row in _preferred_lab_rows(hero_id):
		for col in BOARD_COLUMNS:
			if not lineup.any(func(entry): return int(entry.row) == row and int(entry.col) == col):
				return Vector2i(row, col)
	return Vector2i(-1, -1)

func _auto_arrange_lab_lineup(is_player: bool) -> void:
	var lineup: Array = lab_player_lineup if is_player else lab_enemy_lineup
	var arranged: Array = []
	var ordered := lineup.duplicate(true)
	ordered.sort_custom(func(a, b): return int(heroes[a.hero_id].range) < int(heroes[b.hero_id].range))
	for entry in ordered:
		var position := _next_lab_position(arranged, str(entry.hero_id))
		if position.x < 0:
			lab_status.text = t("近战武将超过前排容量，无法全部上阵。", "Too many melee heroes for the front row.")
			return
		entry.row = position.x
		entry.col = position.y
		arranged.append(entry)
	if is_player: lab_player_lineup = arranged
	else: lab_enemy_lineup = arranged
	lab_status.text = t("已按近战前排、远程后排自动整理。", "Auto-arranged melee front and ranged back.")
	_refresh_lab_lineups()

func _refresh_lab_lineups() -> void:
	if not is_instance_valid(lab_player_board): return
	for pair in [[lab_player_board, lab_player_lineup, true], [lab_enemy_board, lab_enemy_lineup, false]]:
		var board: GridContainer = pair[0]
		var lineup: Array = pair[1]
		var is_player: bool = pair[2]
		var selected := lab_player_selected_pos if is_player else lab_enemy_selected_pos
		for slot in board.get_children():
			var entry = _lab_unit_at(is_player, int(slot.board_row), int(slot.board_col))
			if entry == null:
				slot.text = "·"
				slot.tooltip_text = t("空位：第%d排第%d列" % [int(slot.board_row) + 1, int(slot.board_col) + 1], "Empty: R%d C%d" % [int(slot.board_row) + 1, int(slot.board_col) + 1])
				slot.modulate = Color.WHITE
			else:
				slot.text = _hero_name(str(entry.hero_id)) + "\n" + "★".repeat(int(entry.level))
				slot.tooltip_text = t("拖拽换位；点击后可升降星或移除", "Drag to move; click to change stars or remove")
				var faction_color: Color = FACTION_COLORS[heroes[entry.hero_id].f].lightened(0.28)
				slot.modulate = Color("#f0c77a") if selected == Vector2i(int(slot.board_row), int(slot.board_col)) else faction_color

func _load_lab_presets() -> void:
	var loaded = _read_json_file(LAB_LINEUPS_PATH, [])
	lab_presets = []
	if loaded is Array:
		for value in loaded:
			if not value is Dictionary: continue
			var preset: Dictionary = value.duplicate(true)
			preset.player = _sanitize_lab_lineup(preset.get("player", []))
			preset.enemy = _sanitize_lab_lineup(preset.get("enemy", []))
			lab_presets.append(preset)

func _sanitize_lab_lineup(value) -> Array:
	var sanitized: Array = []
	if not value is Array:
		return sanitized
	for raw_entry in value:
		if not raw_entry is Dictionary: continue
		var hero_id := str(raw_entry.get("hero_id", ""))
		if not heroes.has(hero_id): continue
		var row := clampi(int(raw_entry.get("row", 0)), 0, BOARD_ROWS - 1)
		if not bool(heroes[hero_id].get("all_rows", false)) and int(heroes[hero_id].range) == 1: row = 0
		var col := clampi(int(raw_entry.get("col", 0)), 0, BOARD_COLUMNS - 1)
		for index in range(sanitized.size() - 1, -1, -1):
			if int(sanitized[index].row) == row and int(sanitized[index].col) == col:
				sanitized.remove_at(index)
		sanitized.append({"hero_id":hero_id, "level":clampi(int(raw_entry.get("level", 1)), 1, 3), "row":row, "col":col})
	return sanitized

func _save_lab_presets() -> void:
	_write_json_file(LAB_LINEUPS_PATH, lab_presets)

func _refresh_lab_presets() -> void:
	if not is_instance_valid(lab_preset_list): return
	lab_preset_list.clear()
	for preset in lab_presets:
		lab_preset_list.add_item(str(preset.get("name", t("未命名阵容", "Unnamed preset"))) + "  ·  " + str(preset.get("player", []).size()) + "v" + str(preset.get("enemy", []).size()))

func _save_current_lab_preset() -> void:
	if lab_player_lineup.is_empty() or lab_enemy_lineup.is_empty():
		lab_status.text = t("双方都至少需要一名武将。", "Both teams need at least one hero.")
		return
	var preset_name := lab_preset_name.text.strip_edges()
	if preset_name.is_empty():
		preset_name = t("演练方案 ", "Simulation ") + str(lab_presets.size() + 1)
	var preset := {"name":preset_name, "player":lab_player_lineup.duplicate(true), "enemy":lab_enemy_lineup.duplicate(true), "runs":int(lab_runs.value)}
	var replaced := false
	for index in lab_presets.size():
		if str(lab_presets[index].get("name", "")) == preset_name:
			lab_presets[index] = preset
			replaced = true
			break
	if not replaced: lab_presets.append(preset)
	_save_lab_presets()
	_refresh_lab_presets()
	lab_status.text = t("阵容方案已保存。", "Lineup preset saved.")

func _selected_lab_preset_index() -> int:
	var selected := lab_preset_list.get_selected_items()
	return selected[0] if not selected.is_empty() else -1

func _load_selected_lab_preset() -> void:
	var index := _selected_lab_preset_index()
	if index < 0: return
	var preset: Dictionary = lab_presets[index]
	lab_preset_name.text = str(preset.get("name", ""))
	lab_player_lineup = _sanitize_lab_lineup(preset.get("player", []))
	lab_enemy_lineup = _sanitize_lab_lineup(preset.get("enemy", []))
	lab_runs.value = int(preset.get("runs", 10))
	_refresh_lab_lineups()
	lab_status.text = t("阵容方案已载入。", "Lineup preset loaded.")

func _delete_selected_lab_preset() -> void:
	var index := _selected_lab_preset_index()
	if index < 0: return
	lab_presets.remove_at(index)
	_save_lab_presets()
	_refresh_lab_presets()
	lab_status.text = t("已删除阵容方案。", "Lineup preset deleted.")

func _export_selected_lab_preset() -> void:
	var index := _selected_lab_preset_index()
	if index < 0: return
	DisplayServer.clipboard_set(JSON.stringify(lab_presets[index], "\t"))
	lab_status.text = t("所选阵容 JSON 已复制到剪贴板。", "Selected lineup JSON copied to clipboard.")

func _import_lab_preset() -> void:
	var parsed = JSON.parse_string(DisplayServer.clipboard_get())
	if not parsed is Dictionary or not parsed.get("player", null) is Array or not parsed.get("enemy", null) is Array:
		lab_status.text = t("剪贴板里没有有效的阵容 JSON。", "Clipboard does not contain valid lineup JSON.")
		return
	var preset: Dictionary = parsed
	if str(preset.get("name", "")).is_empty(): preset.name = t("导入阵容", "Imported lineup")
	preset.player = _sanitize_lab_lineup(preset.player)
	preset.enemy = _sanitize_lab_lineup(preset.enemy)
	if preset.player.is_empty() or preset.enemy.is_empty():
		lab_status.text = t("导入阵容缺少有效武将。", "Imported preset has no valid heroes.")
		return
	lab_presets.append(preset)
	_save_lab_presets()
	_refresh_lab_presets()
	lab_status.text = t("阵容已导入列表。", "Lineup imported into the list.")

func _start_lab_live_battle() -> void:
	if lab_player_lineup.is_empty() or lab_enemy_lineup.is_empty():
		lab_status.text = t("双方都至少需要一名武将。", "Both teams need at least one hero.")
		return
	if battle_running:
		lab_status.text = t("当前已有战斗正在进行。", "A battle is already running.")
		return
	lab_live_snapshot = _capture_lab_live_snapshot()
	tick_timer.stop()
	player_units = _build_lab_live_units("player", lab_player_lineup)
	enemy_units = _build_lab_live_units("enemy", lab_enemy_lineup)
	combat_units = []
	combat_units.append_array(player_units)
	combat_units.append_array(enemy_units)
	player_ruler_hp = RULER_MAX_HP
	enemy_ruler_hp = RULER_MAX_HP
	ruler_regen = {
		"player":{"amount":0.0, "time":0.0, "clock":0.0},
		"enemy":{"amount":0.0, "time":0.0, "clock":0.0}
	}
	battle_stats = {}
	for unit in combat_units:
		battle_stats[unit.id] = {
			"unit_id":unit.id,
			"hero_id":unit.hero_id,
			"team":unit.team,
			"level":int(unit.level),
			"damage":0.0,
			"healing":0.0,
			"taken":0.0,
			"control":0.0
		}
	pending_unit_ids.clear()
	selected_unit = ""
	visual_events.clear()
	ground_effects.clear()
	_reset_faction_battle_state()
	battle_time = 0.0
	battle_speed = game_speed
	action_in_progress = false
	final_battle = true
	phase = "combat"
	battle_running = true
	lab_live_battle = true
	lab_live_paused = false
	lab_live_stop_requested = false
	# 实战演练始终等待动作演出结束，手动结束时才能安全恢复正式战局。
	pause_during_actions = true
	_apply_combo_bonds(true, false)
	_apply_faction_bonuses(false)
	_apply_opening_skills()
	visual_events.clear()
	if is_instance_valid(log_box):
		log_box.clear()
	_log("[color=#f0c77a]" + t("均衡实验室实战开始：无回合、不可换将、无时间限制。", "Balance Lab live battle started: no rounds, substitutions, or time limit.") + "[/color]")
	if is_instance_valid(menu_overlay): menu_overlay.hide()
	balance_lab_overlay.hide()
	lab_live_pause_button.disabled = false
	lab_live_end_button.disabled = false
	lab_live_hud.show()
	_update_lab_live_hud()
	tick_timer.start()
	_render()

func _build_lab_live_units(team: String, setup: Array) -> Array:
	var result: Array = []
	for entry in setup:
		var unit: Dictionary = _make_roster_unit(team, str(entry.hero_id))
		unit.level = clampi(int(entry.get("level", 1)), 1, 3)
		unit.stat_mult = _star_stat_multiplier(unit.level)
		unit.max_hp = float(heroes[unit.hero_id].hp) * float(unit.stat_mult)
		unit.hp = unit.max_hp
		unit.row = clampi(int(entry.get("row", 0)), 0, BOARD_ROWS - 1)
		unit.col = clampi(int(entry.get("col", 0)), 0, BOARD_COLUMNS - 1)
		_ensure_unit_fields(unit)
		result.append(unit)
	return result

func _capture_lab_live_snapshot() -> Dictionary:
	return {
		"player_units":player_units.duplicate(true),
		"enemy_units":enemy_units.duplicate(true),
		"combat_units":combat_units.duplicate(true),
		"player_ruler_hp":player_ruler_hp,
		"enemy_ruler_hp":enemy_ruler_hp,
		"ruler_regen":ruler_regen.duplicate(true),
		"phase":phase,
		"battle_running":battle_running,
		"battle_time":battle_time,
		"action_in_progress":action_in_progress,
		"final_battle":final_battle,
		"battle_speed":battle_speed,
		"pause_during_actions":pause_during_actions,
		"selected_unit":selected_unit,
		"visual_events":visual_events.duplicate(true),
		"ground_effects":ground_effects.duplicate(true),
		"battle_stats":battle_stats.duplicate(true),
		"last_battle_stats":last_battle_stats.duplicate(true),
		"log_text":log_box.text if is_instance_valid(log_box) else "",
		"menu_visible":menu_overlay.visible if is_instance_valid(menu_overlay) else false
	}

func _restore_lab_live_snapshot(snapshot: Dictionary) -> void:
	player_units = snapshot.get("player_units", []).duplicate(true)
	enemy_units = snapshot.get("enemy_units", []).duplicate(true)
	combat_units = snapshot.get("combat_units", []).duplicate(true)
	player_ruler_hp = int(snapshot.get("player_ruler_hp", RULER_MAX_HP))
	enemy_ruler_hp = int(snapshot.get("enemy_ruler_hp", RULER_MAX_HP))
	ruler_regen = snapshot.get("ruler_regen", {
		"player":{"amount":0.0, "time":0.0, "clock":0.0},
		"enemy":{"amount":0.0, "time":0.0, "clock":0.0}
	}).duplicate(true)
	phase = str(snapshot.get("phase", "draft"))
	battle_running = bool(snapshot.get("battle_running", false))
	battle_time = float(snapshot.get("battle_time", 0.0))
	action_in_progress = bool(snapshot.get("action_in_progress", false))
	final_battle = bool(snapshot.get("final_battle", false))
	battle_speed = float(snapshot.get("battle_speed", game_speed))
	pause_during_actions = bool(snapshot.get("pause_during_actions", true))
	selected_unit = str(snapshot.get("selected_unit", ""))
	visual_events = snapshot.get("visual_events", []).duplicate(true)
	ground_effects = snapshot.get("ground_effects", []).duplicate(true)
	battle_stats = snapshot.get("battle_stats", {}).duplicate(true)
	last_battle_stats = snapshot.get("last_battle_stats", []).duplicate(true)
	if is_instance_valid(log_box):
		log_box.text = str(snapshot.get("log_text", ""))
	if is_instance_valid(menu_overlay):
		menu_overlay.visible = bool(snapshot.get("menu_visible", false))

func _request_end_lab_live_battle() -> void:
	if not lab_live_battle or lab_live_stop_requested: return
	lab_live_stop_requested = true
	tick_timer.stop()
	lab_live_pause_button.disabled = true
	lab_live_end_button.disabled = true
	lab_live_time_label.text = t("正在结束当前动作…", "Finishing current action...")
	if not action_in_progress:
		_finish_lab_live_battle(true)

func _cycle_lab_live_speed() -> void:
	if not lab_live_battle: return
	_cycle_speed()
	_update_lab_live_hud()

func _toggle_lab_live_pause() -> void:
	if not lab_live_battle or lab_live_stop_requested: return
	lab_live_paused = not lab_live_paused
	if lab_live_paused:
		tick_timer.stop()
	else:
		if not action_in_progress:
			tick_timer.start()
	_update_lab_live_hud()
	_render()

func _update_lab_live_hud() -> void:
	if not lab_live_battle: return
	if is_instance_valid(lab_live_time_label):
		lab_live_time_label.text = (t("已暂停 · ", "PAUSED · ") if lab_live_paused else t("已战 ", "TIME ")) + "%.1fs" % battle_time
	if is_instance_valid(lab_live_speed_button):
		lab_live_speed_button.text = str(int(game_speed)) + "×"
	if is_instance_valid(lab_live_pause_button):
		lab_live_pause_button.text = t("继续", "RESUME") if lab_live_paused else t("暂停", "PAUSE")

func _finish_lab_live_battle(manual: bool) -> void:
	if not lab_live_battle: return
	tick_timer.stop()
	battle_running = false
	action_in_progress = false
	var elapsed := battle_time
	var player_hp := player_ruler_hp
	var enemy_hp := enemy_ruler_hp
	var winner := _lab_live_winner()
	var stats: Array = []
	for entry in battle_stats.values():
		stats.append(entry.duplicate(true))
	var report := _build_lab_live_report(manual, winner, elapsed, player_hp, enemy_hp, stats)
	var snapshot: Dictionary = lab_live_snapshot
	lab_live_battle = false
	lab_live_paused = false
	lab_live_stop_requested = false
	lab_live_snapshot = {}
	lab_live_hud.hide()
	_restore_lab_live_snapshot(snapshot)
	_render()
	if is_instance_valid(balance_lab_tabs): balance_lab_tabs.current_tab = 1
	_set_lab_view_mode("result")
	lab_result.text = report
	lab_status.text = t("实战已手动结束。", "Live battle ended manually.") if manual else t("实战已分出胜负。", "Live battle has a winner.")
	balance_lab_overlay.show()

func _lab_live_winner() -> String:
	if player_ruler_hp <= 0 and enemy_ruler_hp <= 0: return "draw"
	if player_ruler_hp <= 0: return "enemy"
	if enemy_ruler_hp <= 0: return "player"
	var player_score := float(player_ruler_hp) / RULER_MAX_HP
	var enemy_score := float(enemy_ruler_hp) / RULER_MAX_HP
	for unit in _team_units("player"):
		if unit.alive: player_score += float(unit.hp) / maxf(1.0, float(unit.max_hp))
	for unit in _team_units("enemy"):
		if unit.alive: enemy_score += float(unit.hp) / maxf(1.0, float(unit.max_hp))
	if absf(player_score - enemy_score) <= 0.01: return "draw"
	return "player" if player_score > enemy_score else "enemy"

func _build_lab_live_report(manual: bool, winner: String, elapsed: float, player_hp: int, enemy_hp: int, stats: Array) -> String:
	var lines: Array[String] = []
	lines.append("[font_size=20][color=#f0c77a]" + t("实战演练结果", "LIVE BATTLE RESULT") + "[/color][/font_size]")
	var finish_reason := t("手动结束", "Ended manually") if manual else t("主公倒下，战斗结束", "A ruler fell")
	lines.append(finish_reason + " · " + t("用时 ", "Duration ") + "%.1fs" % elapsed)
	var winner_text := t("平局", "Draw")
	if winner == "player": winner_text = t("我方胜利", "Player victory")
	elif winner == "enemy": winner_text = t("敌方胜利", "Enemy victory")
	var winner_color := "#c9c0b1"
	if winner == "player": winner_color = "#90c59e"
	elif winner == "enemy": winner_color = "#d89a8f"
	lines.append("[color=" + winner_color + "]" + winner_text + "[/color]   " + t("主公生命：", "Ruler HP: ") + str(player_hp) + " : " + str(enemy_hp))
	lines.append("")
	lines.append(t("[color=#e3c58c]武将统计[/color]　伤害 / 承伤 / 治疗 / 控制秒数", "[color=#e3c58c]Hero stats[/color]  Damage / Taken / Healing / Control seconds"))
	stats.sort_custom(func(a, b): return float(a.damage) > float(b.damage))
	for row in stats:
		var side := t("我", "P") if row.team == "player" else t("敌", "E")
		var color := "#90c59e" if row.team == "player" else "#d89a8f"
		lines.append("[color=" + color + "]" + side + " · " + _hero_name(row.hero_id) + " " + "★".repeat(int(row.level)) + "[/color]　" + str(round(float(row.damage))) + " / " + str(round(float(row.taken))) + " / " + str(round(float(row.healing))) + " / " + "%.2f" % float(row.control))
	return "\n".join(lines)

func _finish_battle() -> void:
	if lab_live_battle:
		_finish_lab_live_battle(false)
		return
	super._finish_battle()

func _resolve_action(unit: Dictionary) -> void:
	await super._resolve_action(unit)
	if lab_live_battle and lab_live_paused:
		tick_timer.stop()
	if lab_live_battle and lab_live_stop_requested:
		_finish_lab_live_battle(true)

func _resolve_effect_pause() -> void:
	await super._resolve_effect_pause()
	if lab_live_battle and lab_live_paused:
		tick_timer.stop()
	if lab_live_battle and lab_live_stop_requested:
		_finish_lab_live_battle(true)

func _battle_tick() -> void:
	if lab_live_battle and lab_live_paused:
		return
	super._battle_tick()

func _render() -> void:
	super._render()
	if not lab_live_battle: return
	title_label.text = t("三国 · 均衡实验室 · 实战演练", "THREE KINGDOMS · BALANCE LAB · LIVE BATTLE")
	round_label.text = t("实战演练", "LIVE BATTLE")
	phase_label.text = t("◆ 无回合战斗", "◆ ROUNDLESS COMBAT")
	draft_title_label.text = t("双方锁定阵容 · 不可换将", "LINEUPS LOCKED · NO SUBSTITUTIONS")
	phase_caption_label.text = t("均衡实验室 · 实战进行中", "BALANCE LAB · LIVE BATTLE")
	hint_label.text = t("实战已暂停；点击“继续”恢复，仍可切换倍速或手动结束。", "Live battle paused. Resume when ready; speed and manual end remain available.") if lab_live_paused else t("当前阵容已锁定；可暂停、切换 1× / 2× / 4× 倍速，或手动结束。", "Lineups are locked. Pause, change 1× / 2× / 4× speed, or end manually.")
	stats_title_label.text = t("实战演练实时统计", "LIVE PRACTICE STATS")

func _update_battle_time_bar() -> void:
	super._update_battle_time_bar()
	if not lab_live_battle: return
	battle_time_bar.visible = false
	battle_time_label.text = t("∞ 实战演练", "∞ LIVE")
	_update_lab_live_hud()

func _run_fast_battles() -> void:
	if lab_player_lineup.is_empty() or lab_enemy_lineup.is_empty():
		lab_status.text = t("双方都至少需要一名武将。", "Both teams need at least one hero.")
		return
	lab_run_button.disabled = true
	var runs := int(lab_runs.value)
	var wins := {"player":0, "enemy":0, "draw":0}
	var aggregate := {}
	var duration_total := 0.0
	var seed_base := int(Time.get_ticks_usec() & 0x7fffffff)
	for run_index in runs:
		var result := _simulate_fast_battle(lab_player_lineup, lab_enemy_lineup, seed_base + run_index * 7919)
		wins[result.winner] = int(wins[result.winner]) + 1
		duration_total += float(result.duration)
		for entry in result.stats:
			var key := str(entry.team) + ":" + str(entry.hero_id) + ":" + str(entry.level)
			if not aggregate.has(key):
				aggregate[key] = {"team":entry.team, "hero_id":entry.hero_id, "level":entry.level, "damage":0.0, "taken":0.0, "healing":0.0, "control":0.0}
			for metric in ["damage", "taken", "healing", "control"]:
				aggregate[key][metric] = float(aggregate[key][metric]) + float(entry.get(metric, 0.0))
		if run_index % 10 == 9:
			lab_status.text = t("正在演练：", "Simulating: ") + str(run_index + 1) + " / " + str(runs)
			await get_tree().process_frame
	_render_fast_battle_result(runs, wins, aggregate, duration_total / runs)
	lab_run_button.disabled = false
	lab_status.text = t("演练完成。", "Simulation complete.")

func _simulate_fast_battle(player_setup: Array, enemy_setup: Array, seed: int) -> Dictionary:
	var sandbox = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	sandbox.heroes = heroes.duplicate(true)
	sandbox.language = language
	sandbox.rng.seed = seed
	sandbox.player_ruler_hp = RULER_MAX_HP
	sandbox.enemy_ruler_hp = RULER_MAX_HP
	sandbox.ruler_regen = {"player":{"amount":0.0, "time":0.0, "clock":0.0}, "enemy":{"amount":0.0, "time":0.0, "clock":0.0}}
	sandbox.combat_units = []
	for side in [["player", player_setup], ["enemy", enemy_setup]]:
		for entry in side[1]:
			var unit: Dictionary = sandbox._make_roster_unit(side[0], str(entry.hero_id))
			unit.level = clampi(int(entry.get("level", 1)), 1, 3)
			unit.stat_mult = sandbox._star_stat_multiplier(unit.level)
			unit.max_hp = float(sandbox.heroes[unit.hero_id].hp) * unit.stat_mult
			unit.hp = unit.max_hp
			unit.row = clampi(int(entry.get("row", 0)), 0, BOARD_ROWS - 1)
			unit.col = clampi(int(entry.get("col", 0)), 0, BOARD_COLUMNS - 1)
			sandbox._ensure_unit_fields(unit)
			sandbox.combat_units.append(unit)
	sandbox.battle_stats = {}
	for unit in sandbox.combat_units:
		sandbox.battle_stats[unit.id] = {"unit_id":unit.id, "hero_id":unit.hero_id, "team":unit.team, "level":int(unit.level), "damage":0.0, "healing":0.0, "taken":0.0, "control":0.0}
	sandbox._reset_faction_battle_state()
	sandbox._apply_combo_bonds(true, false)
	sandbox._apply_faction_bonuses(false)
	sandbox._apply_opening_skills()
	sandbox.visual_events.clear()
	sandbox.ground_effects.clear()

	var elapsed := 0.0
	var actions := 0
	while elapsed < FAST_BATTLE_LIMIT and actions < FAST_BATTLE_MAX_ACTIONS:
		var player_alive: Array = sandbox._team_units("player").filter(func(unit): return unit.alive)
		var enemy_alive: Array = sandbox._team_units("enemy").filter(func(unit): return unit.alive)
		if player_alive.is_empty() or enemy_alive.is_empty() or sandbox._has_winner(): break
		var ready: Array = sandbox.combat_units.filter(func(unit): return unit.alive and unit.stun <= 0.0 and unit.charm <= 0.0 and float(unit.get("fear", 0.0)) <= 0.0 and float(unit.action) >= ACTION_MAX)
		if not ready.is_empty():
			var acting: Dictionary = ready[0]
			acting.action = maxf(0.0, float(acting.action) - ACTION_MAX)
			sandbox._perform_action(acting)
			sandbox.visual_events.clear()
			actions += 1
			continue
		elapsed += TICK
		sandbox._process_statuses(TICK)
		sandbox.visual_events.clear()
		for unit in sandbox.combat_units:
			if not unit.alive or unit.stun > 0.0 or unit.charm > 0.0 or float(unit.get("fear", 0.0)) > 0.0: continue
			var gain_per_second: float = ACTION_MAX / maxf(0.001, float(sandbox.heroes[unit.hero_id].cooldown))
			var silence_slow := 0.5 if float(unit.get("silence", 0.0)) > 0.0 else 0.0
			unit.action = minf(ACTION_MAX, float(unit.action) + gain_per_second * TICK * sandbox._unit_action_gain_multiplier(unit) * (1.0 - float(unit.get("slow", 0.0)) - silence_slow))

	var player_units_alive: Array = sandbox._team_units("player").filter(func(unit): return unit.alive)
	var enemy_units_alive: Array = sandbox._team_units("enemy").filter(func(unit): return unit.alive)
	var winner := "draw"
	if sandbox.player_ruler_hp <= 0 or player_units_alive.is_empty():
		winner = "enemy"
	elif sandbox.enemy_ruler_hp <= 0 or enemy_units_alive.is_empty():
		winner = "player"
	else:
		var player_score := float(sandbox.player_ruler_hp) / RULER_MAX_HP
		var enemy_score := float(sandbox.enemy_ruler_hp) / RULER_MAX_HP
		for unit in player_units_alive: player_score += float(unit.hp) / maxf(1.0, float(unit.max_hp))
		for unit in enemy_units_alive: enemy_score += float(unit.hp) / maxf(1.0, float(unit.max_hp))
		if absf(player_score - enemy_score) > 0.01:
			winner = "player" if player_score > enemy_score else "enemy"
	var stats: Array = []
	for entry in sandbox.battle_stats.values(): stats.append(entry.duplicate(true))
	sandbox.free()
	return {"winner":winner, "duration":minf(elapsed, FAST_BATTLE_LIMIT), "stats":stats}

func _render_fast_battle_result(runs: int, wins: Dictionary, aggregate: Dictionary, average_duration: float) -> void:
	var lines: Array[String] = []
	lines.append("[font_size=20][color=#f0c77a]" + t("快速战斗汇总", "QUICK BATTLE SUMMARY") + "[/color][/font_size]")
	lines.append(t("演练 %d 次 · 平均 %.1f 秒" % [runs, average_duration], "%d runs · %.1fs average" % [runs, average_duration]))
	lines.append("[color=#90c59e]" + t("我方胜利", "Player wins") + " " + str(wins.player) + "  (" + "%.1f%%" % (float(wins.player) / runs * 100.0) + ")[/color]   [color=#d89a8f]" + t("敌方胜利", "Enemy wins") + " " + str(wins.enemy) + "  (" + "%.1f%%" % (float(wins.enemy) / runs * 100.0) + ")[/color]   " + t("平局", "Draws") + " " + str(wins.draw))
	lines.append("")
	lines.append(t("[color=#e3c58c]武将场均统计[/color]　伤害 / 承伤 / 治疗 / 控制秒数", "[color=#e3c58c]Per-run hero averages[/color]  Damage / Taken / Healing / Control seconds"))
	var rows: Array = aggregate.values()
	rows.sort_custom(func(a, b): return float(a.damage) > float(b.damage))
	for row in rows:
		var side := t("我", "P") if row.team == "player" else t("敌", "E")
		var color := "#90c59e" if row.team == "player" else "#d89a8f"
		lines.append("[color=" + color + "]" + side + " · " + _hero_name(row.hero_id) + " " + "★".repeat(int(row.level)) + "[/color]　" + str(round(float(row.damage) / runs)) + " / " + str(round(float(row.taken) / runs)) + " / " + str(round(float(row.healing) / runs)) + " / " + "%.2f" % (float(row.control) / runs))
	lab_result.text = "\n".join(lines)
