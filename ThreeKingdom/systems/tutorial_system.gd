extends "res://ThreeKingdom/systems/game_ui.gd"

# 新手引导：取代原「天书演武」入口。先分页讲解规则(棋盘/流程/选将/天书/金币/羁绊/出手)，
# 再进入一场低压力演练关(敌军仅两名)，顶部常驻「选将/布阵/战斗」步骤清单，
# 关键节点弹出高亮气泡(点击选择武将 / 拖动武将到棋盘 / 开始战斗)，全部完成后清单消失。

const TUTORIAL_SOUL_REWARD := 1200 # 等同第一关·简单难度 1 星将魂(_challenge_soul_reward(1) 同公式)

var tutorial_pages_overlay: Control
var tutorial_page_title: Label
var tutorial_page_rich: RichTextLabel
var tutorial_page_dots: Label
var tutorial_page_prev: Button
var tutorial_page_next: Button
var tutorial_complete_overlay: Control
var tutorial_complete_body: RichTextLabel
var tutorial_check_panel: PanelContainer
var tutorial_hint_panel: PanelContainer
var tutorial_hint_label: Label
var tutorial_hint_arrow: Label
var tutorial_check_key := ""
var tutorial_hint_state := ""

# ---------------------------------------------------------------- 入口

func _start_tutorial_from_menu() -> void:
	if is_instance_valid(battle_menu_overlay): battle_menu_overlay.hide()
	if is_instance_valid(menu_overlay): menu_overlay.hide()
	if is_instance_valid(tutorial_complete_overlay): tutorial_complete_overlay.hide()
	if is_instance_valid(result_overlay): result_overlay.hide()
	_start_tutorial_game()
	_render()
	_show_tutorial_pages()

# ---------------------------------------------------------------- 讲解分页

func _tutorial_page_data() -> Array:
	var c := "[color=#90c59e][b]"
	var e := "[/b][/color]"
	var g := "[color=#f0c77a][b]"
	return [
		{"title": t("欢迎与胜利条件", "WELCOME & VICTORY"),
			"body": g + "这是什么游戏" + e + "\n三国题材的[b]自动战斗[/b]棋盘对弈：你负责战前决策——选将、布阵、天书与金币运营；战斗阶段全自动进行，拼的是布阵思路。\n\n" + g + "怎么算赢" + e + "\n双方各有一位主公([b]100000[/b] 生命)。[b]任一方主公生命归零立即分出胜负[/b]；普通关 30 秒到时则比较双方主公剩余生命，多者获胜。\n\n" + c + "两条重要隐藏规则" + e + "\n· 技能打到空格：伤害[b]全额由敌方主公承受[/b]——留空阵有代价。\n· 治疗溢出：超出最大生命的部分按 [b]30%[/b] 转化为我方主公生命。"},
		{"title": t("战场棋盘 · 前中后军", "BOARD & RANKS"),
			"body": g + "5×3 棋盘" + e + "\n每方阵地 3 排 × 5 列，前排最先接敌。上阵限制由兵种决定：\n\n" + c + "前军(近战)" + e + "\n[b]只能站前排，且只攻击敌方前排[/b]。身板硬、贴脸打。\n\n" + c + "中军" + e + "\n站前排可随机打全场；站中排打前中排；站后排只打前排。站位改变射程。\n\n" + c + "后军" + e + "\n[b]任意站位，随机攻击全场[/b]，通常脆但输出高。\n\n用站位改变射程、让对面够不着你的后排，是布阵的核心。"},
		{"title": t("一关的流程 · 战报与统计", "FLOW, LOG & STATS"),
			"body": g + "每关三阶段" + e + "\n[b]选将 → 布阵 → 战斗[/b]。选将三轮三选一；布阵把武将拖上棋盘；随后 [b]30 秒自动战斗[/b]，全程无需操作。\n\n" + g + "右侧信息面板" + e + "\n战斗界面右侧有三个页签：\n· [b]羁绊组成[/b]：实时显示我方阵营/组合羁绊进度；\n· [b]实时战报[/b]：战斗中每一笔出手、伤害、控制都会滚动记录——这就是战报系统；\n· [b]统计图表[/b]：用 伤害 / 治疗 / 控制 / 承伤 四个统计按钮切换，查看每位武将本回合的数据条。\n\n结算画面还有 MVP 特写、数据王与伤害曲线，评的是整关累计表现。"},
		{"title": t("选将与备战席", "DRAFT & RESERVE"),
			"body": g + "选将阶段" + e + "\n每轮三个候选从左到右固定为[b]前军、中军、后军[/b]，点击卡片看详情、按「招募」锁定；每关共三轮。每个候选位还能免费刷新一次。\n\n" + g + "备战席(备战区 9 格)" + e + "\n招募的武将先进备战区，再拖上棋盘上阵；棋盘与备战区之间可以自由拖动换人。\n\n" + c + "限制" + e + "\n· [b]上阵过的武将不能退回备战席[/b]，只能在场上换位；\n· 想清理阵容：把武将拖到屏幕顶部出现的[b]售卖区[/b]卖出(上阵 70 金 / 备战 100 金)；\n· 备战区满 9 人且棋盘满员时无法再招募。"},
		{"title": t("天书：选书与替换", "CODEX PICK & SWAP"),
			"body": g + "天书是什么" + e + "\n只在本局生效的成长方向：武将池、经济、君主、阵营天赋等，最多升到 2 级。入口在[b]备战区右侧的天书阁[/b]。\n\n" + g + "怎么获得" + e + "\n· 第 [b]3/6/9/12/15[/b] 回合开始时免费三选一；\n· 平时可花 [b]500 金[/b]在天书阁购买一次三选一；\n· 拿错了？花 [b]300 金[/b]替换：退掉一本现有天书(每回合限 1 次)，按其等级获得对应次数的重新抽取。\n\n本次演练第 1 回合就送一次免费三选一，稍后亲自试。"},
		{"title": t("金币运营", "GOLD ECONOMY"),
			"body": g + "金币从哪来" + e + "\n开局 [b]200 金[/b]。每回合开始时先结利息再发收入：\n· [b]利息[/b]：每持有 10 金 +1，上限 50(部分天书/天赋可提高)；\n· [b]基础收入[/b]：100 金起步，每过一关 +50。\n\n" + g + "金币花在哪" + e + "\n· 购买天书三选一：500 金；\n· 替换天书：300 金；\n· 卖出武将回收：备战 100 金 / 上阵 70 金。\n\n" + c + "节奏选择" + e + "\n攒钱吃利息稳后期，还是尽早买天书滚强度——两者的平衡就是运营核心。顶部天书阁按钮上实时显示当前金币、利息与收入。"},
		{"title": t("羁绊与出手规则", "BONDS & ACTIONS"),
			"body": g + "羁绊" + e + "\n右侧「羁绊组成」页签实时显示进度：\n· [b]阵营羁绊[/b]：按场上同阵营人数 [b]2/5/8[/b] 分三档——蜀承伤降低、魏控制时长提高、吴最大生命提高、群冷却缩短，8 人解锁终极效果；\n· [b]组合羁绊[/b]：特定武将组合触发(桃园结义、五虎上将、四英杰……)，完整关系见 图鉴 → 羁绊图。\n\n" + g + "怎么出手" + e + "\n每位武将有一条[b]行动条(0→100)[/b]，攒满立即释放技能并重新读条。卡片上的秒数就是冷却：数字越小出手越快。\n\n" + c + "常见限制" + e + "\n眩晕/冻结/魅惑/恐惧期间停止行动；减速让行动条变慢；沉默禁技能。冷却统一走「冷却极速」：实际冷却 = 原冷却 × 100/(100+极速)，极速叠加收益递减、无百分比上限，最终冷却最低 2 秒。"},
		{"title": t("开始演练", "PRACTICE"),
			"body": g + "现在来一次完整演练" + e + "\n按提示走完：[b]选天书 → 三轮选将 → 布阵上阵 → 30 秒战斗[/b]。\n\n屏幕顶部会出现步骤清单：[b]选将 ✓ → 布阵 ✓ → 战斗 ✓[/b]，全部完成后清单自动消失。\n\n" + c + "演练规格" + e + "\n· 敌军仅有[b]两名[/b]武将，轻松获胜，专注体验流程；\n· 首次完成奖励 [b]将魂 +%d[/b](等同第一关·简单难度)，用于抽符文；\n· 之后随时可以从 战斗 → 新手引导 [b]再来一次[/b](重复完成不再发奖励)。"}
	]

func _show_tutorial_pages() -> void:
	if not is_instance_valid(tutorial_pages_overlay): _build_tutorial_pages()
	tutorial_page_index = clampi(tutorial_page_index, 0, _tutorial_page_data().size() - 1)
	_apply_tutorial_page()
	tutorial_pages_overlay.show()

func _build_tutorial_pages() -> void:
	tutorial_pages_overlay = ColorRect.new()
	tutorial_pages_overlay.color = _overlay_color(Color("#060908e8"))
	tutorial_pages_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutorial_pages_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_pages_overlay.z_index = 1590
	add_child(tutorial_pages_overlay)
	_add_premium_art(tutorial_pages_overlay, PremiumUIArt.Variant.BACKDROP, Color("#5f9a72"))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutorial_pages_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 0) if _is_mobile_ui() else Vector2(1040, 690)
	_style(panel, Color("#101a13f2"), 12, Color("#6fae82"), 2)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 46
	var eyebrow := _label("TUTORIAL · NEW COMMANDER", 10, Color("#8fae96"))
	eyebrow.add_theme_constant_override("letter_spacing", 2)
	var head_box := VBoxContainer.new()
	head_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_box.add_theme_constant_override("separation", -2)
	head_box.add_child(eyebrow)
	tutorial_page_title = _label("", 28, Color("#9fe0ae"))
	head_box.add_child(tutorial_page_title)
	header.add_child(head_box)
	var skip := _button(t("跳过讲解", "SKIP"))
	skip.custom_minimum_size = Vector2(130, 46)
	_accent_button(skip, Color("#607b95"))
	skip.pressed.connect(_tutorial_begin_practice)
	header.add_child(skip)
	box.add_child(header)
	var line := HSeparator.new()
	box.add_child(line)
	tutorial_page_rich = RichTextLabel.new()
	tutorial_page_rich.bbcode_enabled = true
	tutorial_page_rich.scroll_active = true
	tutorial_page_rich.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tutorial_page_rich.custom_minimum_size = Vector2(0, 470)
	tutorial_page_rich.add_theme_font_size_override("normal_font_size", 18)
	tutorial_page_rich.add_theme_font_size_override("bold_font_size", 19)
	tutorial_page_rich.add_theme_color_override("default_color", _text_color(Color("#d8cfbd")))
	box.add_child(tutorial_page_rich)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	tutorial_page_prev = _button(t("◄ 上一页", "◄ BACK"))
	tutorial_page_prev.custom_minimum_size = Vector2(150, 50)
	tutorial_page_prev.pressed.connect(func():
		tutorial_page_index = maxi(0, tutorial_page_index - 1)
		_apply_tutorial_page()
	)
	footer.add_child(tutorial_page_prev)
	tutorial_page_dots = _label("", 17, Color("#c6d6c8"))
	tutorial_page_dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tutorial_page_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_page_dots.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(tutorial_page_dots)
	tutorial_page_next = _button("")
	tutorial_page_next.custom_minimum_size = Vector2(190, 50)
	_accent_button(tutorial_page_next, Color("#5f9a72"), true)
	tutorial_page_next.pressed.connect(func():
		if tutorial_page_index >= _tutorial_page_data().size() - 1:
			_tutorial_begin_practice()
		else:
			tutorial_page_index += 1
			_apply_tutorial_page()
	)
	footer.add_child(tutorial_page_next)
	box.add_child(footer)

func _apply_tutorial_page() -> void:
	var pages := _tutorial_page_data()
	tutorial_page_index = clampi(tutorial_page_index, 0, pages.size() - 1)
	var page: Dictionary = pages[tutorial_page_index]
	var body: String = str(page.body)
	if body.contains("%d"): body = body % TUTORIAL_SOUL_REWARD
	tutorial_page_title.text = str(page.title)
	tutorial_page_rich.text = _bbc(body)
	tutorial_page_dots.text = "%d / %d" % [tutorial_page_index + 1, pages.size()]
	tutorial_page_prev.disabled = tutorial_page_index == 0
	tutorial_page_next.text = t("开始演练 ▶", "START PRACTICE ▶") if tutorial_page_index == pages.size() - 1 else t("下一页 ►", "NEXT ►")

func _tutorial_begin_practice() -> void:
	if is_instance_valid(tutorial_pages_overlay): tutorial_pages_overlay.hide()
	_render()

# ---------------------------------------------------------------- 步骤清单与高亮提示

func _tutorial_place_done() -> bool:
	return player_units.any(func(unit): return unit.alive and int(unit.row) >= 0)

func _tutorial_refresh() -> void:
	# 由 _render() 末尾调用：引导期间刷新清单与气泡，阶段结束(结算)后整体消失。
	if not tutorial_active or phase not in ["tianshu", "draft", "placement", "combat"] or is_instance_valid(menu_overlay) and menu_overlay.visible:
		_hide_tutorial_chrome()
		return
	_update_tutorial_checklist()
	_update_tutorial_hints()

func _hide_tutorial_chrome() -> void:
	if is_instance_valid(tutorial_check_panel): tutorial_check_panel.hide()
	if is_instance_valid(tutorial_hint_panel): tutorial_hint_panel.hide()
	tutorial_hint_state = ""

func _update_tutorial_checklist() -> void:
	var draft_done := not chosen_this_round.is_empty()
	var place_done := _tutorial_place_done()
	var battle_done := phase == "finished"
	var battling := phase == "combat"
	var key := "%s|%s|%s|%s" % [draft_done, place_done, battle_done, battling]
	if is_instance_valid(tutorial_check_panel) and key == tutorial_check_key:
		return
	tutorial_check_key = key
	if not is_instance_valid(tutorial_check_panel):
		tutorial_check_panel = PanelContainer.new()
		_style(tutorial_check_panel, Color("#132a1ef0"), 9, Color("#5f9a72"), 2)
		tutorial_check_panel.z_index = 1580
		tutorial_check_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tutorial_check_panel.hide()
		add_child(tutorial_check_panel)
		tutorial_check_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		tutorial_check_panel.offset_top = 84 if _is_mobile_ui() else 92
		tutorial_check_panel.grow_vertical = Control.GROW_DIRECTION_END
	_clear_dynamic_children(tutorial_check_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caption := _label(t("引导", "GUIDE"), 16, Color("#9fe0ae"))
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(caption)
	var steps := [[t("选将", "DRAFT"), draft_done], [t("布阵", "FORM"), place_done], [t("战斗", "BATTLE"), battle_done]]
	var current_seen := false
	for entry in steps:
		var done := bool(entry[1])
		var mark := "✓"
		var color := Color("#a8e6b0")
		if not done:
			if not current_seen and not battling:
				mark = "▶"
				color = Color("#f0c77a")
				current_seen = true
			elif battling and str(entry[0]) == t("战斗", "BATTLE"):
				mark = "⋯"
				color = Color("#f0c77a")
			else:
				mark = "·"
				color = Color("#9aa79b")
		var step := _outlined_label("%s %s" % [str(entry[0]), mark], 16, color)
		step.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(step)
	tutorial_check_panel.add_child(row)
	tutorial_check_panel.show()

func _update_tutorial_hints() -> void:
	var text := ""
	var at_bottom := false
	if phase == "tianshu":
		text = t("点击「获取」选定一本天书", "Click ACQUIRE to take a codex")
	elif phase == "draft" and chosen_this_round.is_empty():
		text = t("点击选择武将，按「招募」锁定", "Click a hero, then press RECRUIT")
	elif phase == "placement" and not _tutorial_place_done():
		text = t("拖动武将到棋盘上阵", "Drag a general onto the board")
		at_bottom = true
	elif phase == "placement" and _can_start_battle():
		text = t("布阵完成：点击「开始战斗」", "Ready — press START BATTLE")
		at_bottom = true
	elif phase == "combat":
		text = t("战斗自动进行：右侧可看实时战报与统计", "Battle runs itself — watch log & stats at the right")
	var state := ("bottom:" if at_bottom else "top:") + text
	if state == tutorial_hint_state and is_instance_valid(tutorial_hint_panel):
		return
	tutorial_hint_state = state
	if text.is_empty():
		if is_instance_valid(tutorial_hint_panel): tutorial_hint_panel.hide()
		return
	if not is_instance_valid(tutorial_hint_panel):
		tutorial_hint_panel = PanelContainer.new()
		_style(tutorial_hint_panel, Color("#173326f2"), 9, Color("#6fc48a"), 2)
		tutorial_hint_panel.z_index = 1580
		tutorial_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tutorial_hint_panel.hide()
		add_child(tutorial_hint_panel)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tutorial_hint_panel.add_child(v)
		tutorial_hint_label = _label("", 17, Color("#d9f3dc"))
		tutorial_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(tutorial_hint_label)
		tutorial_hint_arrow = _label("▼", 15, Color("#8fd4a0"))
		tutorial_hint_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(tutorial_hint_arrow)
		var pulse := create_tween().set_loops()
		pulse.tween_property(tutorial_hint_panel, "modulate", Color(1, 1, 1, 0.62), 0.55).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(tutorial_hint_panel, "modulate", Color(1, 1, 1, 1.0), 0.55).set_trans(Tween.TRANS_SINE)
	tutorial_hint_label.text = text
	if at_bottom:
		tutorial_hint_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		tutorial_hint_panel.offset_bottom = -128
		tutorial_hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	else:
		tutorial_hint_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		tutorial_hint_panel.offset_top = 150 if not _is_mobile_ui() else 132
		tutorial_hint_panel.grow_vertical = Control.GROW_DIRECTION_END
	tutorial_hint_panel.show()

# ---------------------------------------------------------------- 完成结算

func _tutorial_on_complete() -> void:
	# 演练结束(胜负均可)：首次完成发放将魂，之后重复引导不再发。
	tutorial_active = false
	var reward := 0
	if not tutorial_done:
		reward = TUTORIAL_SOUL_REWARD
		tutorial_done = true
		general_souls += reward
		_save_progression()
		_refresh_home()
	if reward > 0:
		_log("[color=#8fd4a0]【引导完成】奖励将魂 +%d，可在主页「符文」中抽取符文。[/color]" % reward)
	else:
		_log("[color=#8fd4a0]【引导完成】奖励已领取过，本次不再发放。[/color]")
	_show_tutorial_complete_dialog(reward)

func _show_tutorial_complete_dialog(reward: int) -> void:
	if not is_instance_valid(tutorial_complete_overlay): _build_tutorial_complete_dialog()
	tutorial_complete_body.text = _bbc("[color=#a8e6b0]选将 ✓　布阵 ✓　战斗 ✓[/color]\n\n" +
		(("首次完成新手引导，奖励 [color=#f0c77a]将魂 +%d[/color]。\n可在主页「符文」抽取符文增强武将。" % reward) if reward > 0 else "新手引导奖励此前已领取，本次演练不再发放。") +
		"\n\n想去真正的战场了？主页「战斗」里有快速战斗与二十城闯关。")
	tutorial_complete_overlay.show()

func _build_tutorial_complete_dialog() -> void:
	tutorial_complete_overlay = ColorRect.new()
	tutorial_complete_overlay.color = _overlay_color(Color("#050806d8"))
	tutorial_complete_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutorial_complete_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_complete_overlay.z_index = 1650
	tutorial_complete_overlay.hide()
	add_child(tutorial_complete_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutorial_complete_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	_style(panel, Color("#101a13f2"), 12, Color("#6fae82"), 2)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title := _label(t("◆ 新手引导完成 ◆", "◆ TUTORIAL COMPLETE ◆"), 30, Color("#9fe0ae"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_outline_color", Color("#0c1b10"))
	box.add_child(title)
	tutorial_complete_body = RichTextLabel.new()
	tutorial_complete_body.bbcode_enabled = true
	tutorial_complete_body.fit_content = true
	tutorial_complete_body.custom_minimum_size = Vector2(500, 0)
	tutorial_complete_body.add_theme_font_size_override("normal_font_size", 17)
	tutorial_complete_body.add_theme_color_override("default_color", _text_color(Color("#d8cfbd")))
	box.add_child(tutorial_complete_body)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var retry := _button(t("再引导一次", "REPLAY TUTORIAL"))
	retry.custom_minimum_size = Vector2(170, 50)
	_accent_button(retry, Color("#5f9a72"), true)
	retry.pressed.connect(func():
		tutorial_complete_overlay.hide()
		if is_instance_valid(result_overlay): result_overlay.hide()
		_start_tutorial_from_menu()
	)
	buttons.add_child(retry)
	var home := _button(t("返回主页", "HOME"))
	home.custom_minimum_size = Vector2(150, 50)
	_accent_button(home, Color("#607b95"))
	home.pressed.connect(func():
		tutorial_complete_overlay.hide()
		_return_home_from_result()
	)
	buttons.add_child(home)
	box.add_child(buttons)
