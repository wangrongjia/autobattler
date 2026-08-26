extends SceneTree

# 主题切换冒烟测试：绢纸(亮色)重建后，遮罩/按钮/文字应当转为纸色与墨色，玄墨(暗色)恢复如初。

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	if game.ui_theme != "dark":
		# 忽略开发机设置文件里持久化的主题，统一以玄墨为基准再切换。
		game.ui_theme = "dark"
		game._rebuild_ui()
		await process_frame
	var dark_overlay: Color = game.settings_overlay.color
	game.ui_theme = "light"
	game._rebuild_ui()
	await process_frame
	var light_overlay: Color = game.settings_overlay.color
	assert(light_overlay.v > 0.8, "绢纸主题遮罩应为纸色, got %s" % [light_overlay])
	assert(light_overlay.a == dark_overlay.a, "遮罩透明度应保持不变")
	var sample: Label = game._label("测试", 16, Color("#f0c77a"))
	var ink: Color = sample.get_theme_color("font_color")
	assert(ink.v < 0.5 and ink.h > 0.05 and ink.h < 0.15, "金色标题应转深墨金色, got %s" % [ink])
	var panel := Color("#12120f")
	assert(absf(game._panel_color(panel).v - 0.955) < 0.05, "深色面板应转纸色")
	assert(game._text_color(Color("#3a3a3a")) == Color("#3a3a3a"), "深色文字应原样保留")
	assert(game._panel_color(Color("#f0c77a")) == Color("#f0c77a"), "亮色底应原样保留")
	var light_button: Button = game._button("测试按钮")
	var button_ink: Color = light_button.get_theme_color("font_color")
	assert(button_ink.v < 0.5, "绢纸主题按钮文字应为深墨色, got %s" % [button_ink])
	var light_theme: Theme = game._build_root_theme()
	assert(light_theme.get_color("font_color", "TooltipLabel").v < 0.5, "绢纸主题提示文字应为深墨色")
	assert(light_theme.get_color("font_selected_color", "TabContainer").v < 0.5, "绢纸主题页签选中文字应为深墨色")
	var bbc: String = game._bbc("[color=#f0c77a]标题[/color] 正文")
	assert(not bbc.contains("#f0c77a"), "富文本浅色应被替换, got %s" % [bbc])
	assert(game.theme != null, "根主题应存在")
	assert(game.menu_overlay.visible, "重建后主菜单应保持可见")
	game.ui_theme = "dark"
	game._rebuild_ui()
	await process_frame
	assert(game.settings_overlay.color.v < 0.1, "切回玄墨应恢复暗色遮罩, got %s" % [game.settings_overlay.color])
	print("THEME_SWITCH_TEST_OK")
	quit()
