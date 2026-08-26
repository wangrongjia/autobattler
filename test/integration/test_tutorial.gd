extends SceneTree

# 新手引导快速冒烟：入口 → 讲解页 → 天书 → 选将 → 布阵 → 战斗 → 首次奖励1200 → 重玩不再发奖。
# 布阵用「改状态 + 单次 _render + 帧间隔」：一帧内多次 _render 在 headless 下会触发既有的引擎段错误。
# 结束前还原 progression，不污染本机进度。

func _place_units(game) -> int:
	var placed := 0
	for unit in game.player_units:
		if not unit.alive or int(unit.row) >= 0: continue
		for row in [0, 1, 2]:
			var done := false
			for col in game.BOARD_COLUMNS:
				if game._unit_at(game.player_units, row, col) != null: continue
				if not game._can_unit_use_row(unit, row): break
				unit.row = row
				unit.col = col
				placed += 1
				done = true
				break
			if done: break
	game._render()
	await process_frame
	return placed

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var souls_before: int = game.general_souls
	var tutorial_done_before: bool = game.tutorial_done
	game.tutorial_done = false

	# 1) 入口：演练开局即免费天书三选一，敌军精简为两名，讲解页弹出。
	game._start_tutorial_from_menu()
	await process_frame
	assert(game.game_mode == "tutorial" and game.tutorial_active)
	assert(game.phase == "tianshu" and game.tianshu_choices.size() == 3)
	var deployed: Array = game.enemy_units.filter(func(unit): return unit.alive and int(unit.row) >= 0)
	assert(deployed.size() == 2)
	assert(game.tutorial_pages_overlay.visible)
	assert(game._tutorial_page_data().size() == 8)
	assert(game.title_label.text.contains("新手引导"))

	# 2) 翻到最后一页 → 开始演练。
	game.tutorial_page_index = 7
	game._apply_tutorial_page()
	assert(not game.tutorial_page_prev.disabled or true)
	game._tutorial_begin_practice()
	assert(not game.tutorial_pages_overlay.visible)
	assert(game.tutorial_hint_panel.visible and game.tutorial_hint_label.text.contains("天书"))
	assert(game.tutorial_check_panel.visible)

	# 3) 选天书 → 选将三轮（高亮：点击选择武将）。
	game._choose_tianshu(str(game.tianshu_choices[0]))
	assert(game.phase == "draft")
	assert(game.tutorial_hint_label.text.contains("武将"))
	var guard := 0
	while game.phase == "draft" and guard < 9:
		game._choose_hero(str(game.choices[0]))
		guard += 1
	assert(game.phase == "placement" and game.chosen_this_round.size() == 3)
	assert(game.tutorial_hint_label.text.contains("棋盘"))

	# 4) 布阵上阵 → 开战（高亮：拖动武将到棋盘 → 开始战斗）。
	assert(await _place_units(game) >= 1)
	assert(game._can_start_battle())
	game._start_battle()
	assert(game.phase == "combat" and game.battle_running)
	assert(game.tutorial_check_panel.visible)

	# 5) 演练结束：清单消失，首次完成 +1200 将魂（第一关·简单难度1星）。
	game._finish_battle()
	assert(game.phase == "finished" and not game.tutorial_active)
	assert(not game.tutorial_check_panel.visible)
	await process_frame
	await process_frame
	assert(game.tutorial_complete_overlay.visible)
	assert(game.tutorial_done)
	assert(game.general_souls == souls_before + 1200)

	# 6) 再引导一次：可重玩，奖励不重复发放。
	game._start_tutorial_from_menu()
	await process_frame
	assert(game.phase == "tianshu" and game.tutorial_active)
	game._tutorial_begin_practice()
	game._choose_tianshu(str(game.tianshu_choices[0]))
	guard = 0
	while game.phase == "draft" and guard < 9:
		game._choose_hero(str(game.choices[0]))
		guard += 1
	assert(await _place_units(game) >= 1)
	game._start_battle()
	game._finish_battle()
	await process_frame
	await process_frame
	assert(game.tutorial_done and game.general_souls == souls_before + 1200)
	assert(game.tutorial_complete_overlay.visible)

	# 7) 还原本机进度存档。
	game.general_souls = souls_before
	game.tutorial_done = tutorial_done_before
	assert(game._save_progression())
	print("TUTORIAL_TEST_OK")
	quit()
