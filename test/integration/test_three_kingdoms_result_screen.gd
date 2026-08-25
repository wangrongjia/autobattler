extends SceneTree

## 战斗结算画面集成测试：回放曲线采样、整关累计统计、阵容快照、
## MVP/数据王评选、三星判定与结算界面填充/动画入口。

func _place(game, team: String, hero_id: String, row: int, col: int) -> Dictionary:
	var unit: Dictionary = game._make_roster_unit(team, hero_id)
	unit.row = row
	unit.col = col
	return unit

func _init_battle_stats(game) -> void:
	game.battle_stats = {}
	for unit in game.combat_units:
		game.battle_stats[unit.id] = {"unit_id":unit.id, "hero_id":unit.hero_id, "team":unit.team, "level":1, "damage":0.0, "healing":0.0, "taken":0.0, "control":0.0}

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()

	# 模拟一场快速模式战斗：2 我方 + 1 敌方，手动推进时间轴触发曲线采样。
	var p1 := _place(game, "player", "guanyu", 0, 0)
	var p2 := _place(game, "player", "zhangfei", 1, 1)
	var e1 := _place(game, "enemy", "caocao", 0, 0)
	game.player_units = [p1, p2]
	game.enemy_units = [e1]
	game.combat_units = [p1, p2, e1]
	_init_battle_stats(game)
	game.phase = "combat"
	game.battle_running = true
	game.battle_speed = 1.0  # 测试固定 1× 速度，避免读取到本机持久化的加速设置
	for unit in game.combat_units: unit.stun = 999.0
	game.battle_time = 0.4
	game._battle_tick()
	game.battle_time = 1.2
	game._battle_tick()
	game.battle_time = 2.0
	game._battle_tick()
	assert(game.stage_replay_curve.size() == 3)
	assert(absf(float(game.stage_replay_curve[0].t) - 0.6) < 0.01)
	assert(int(game.stage_replay_curve[0].pr) == game.player_ruler_hp)

	# 记入战斗统计后以决定性胜利收尾。
	game._add_stat(p1, "damage", 800.0)
	game._add_stat(p2, "healing", 300.0)
	game.enemy_ruler_hp = 0
	game.player_ruler_hp = int(game._player_ruler_max_hp())
	game._finish_battle()
	await process_frame
	await process_frame

	# 结算画面已展示且数据齐全。
	assert(game.result_overlay.visible)
	assert(game.result_star_labels.size() == 3)
	assert(game._display_stars_for_hp() == 3)
	assert(game.stage_replay_curve.size() == 4)  # 终点精确采样
	assert(game.stage_replay_round_marks.size() == 1)
	assert(game.stage_stats_totals.has(str(p1.id)))

	# 伤害曲线跨回合连续：battle_stats 每回合重建，但采样值 = 上回合累计 + 本回合增量。
	assert(absf(float(game.stage_replay_curve[3].pd) - 800.0) < 0.01)
	_init_battle_stats(game)  # 模拟第二回合开战时的统计表重建
	game.battle_time = 0.6
	game._add_stat(p1, "damage", 500.0)
	game._record_replay_sample()
	var mid_round_two: Dictionary = game.stage_replay_curve[game.stage_replay_curve.size() - 1]
	assert(absf(float(mid_round_two.pd) - 1300.0) < 0.01)
	game._push_final_replay_sample()
	assert(absf(game.stage_damage_player - 1300.0) < 0.01)
	assert(game.stage_replay_round_marks.size() == 2)
	assert(absf(float(game.stage_replay_curve[game.stage_replay_curve.size() - 1].t) - 2.8) < 0.01)
	assert(float(game.stage_stats_totals[str(p1.id)].damage) == 800.0)
	assert(float(game.stage_stats_totals[str(p2.id)].healing) == 300.0)
	assert(game.last_battle_lineup.size() == 3)
	assert(game.result_mvp_name_label.text != "--")
	assert(game.result_chart.is_visible_in_tree())
	assert(game.result_chart.series.size() == 4)
	assert(game.result_chart.x_max > 2.0)
	assert(game.result_lineup_player_flow.get_child_count() == 2)
	assert(game.result_lineup_enemy_flow.get_child_count() == 1)

	# MVP 评分与数据王：伤害王关羽、治疗王张飞，全零的控制不评王。
	var mvp_data: Dictionary = game._compute_battle_mvp()
	assert(str(mvp_data.mvp.hero_id) == "guanyu")
	var kings: Dictionary = mvp_data.kings
	assert(str(kings.damage.hero_id) == "guanyu")
	assert(str(kings.healing.hero_id) == "zhangfei")
	assert(not kings.has("control"))

	# 图表生长动画进度可直接驱动。
	game.result_chart.set_reveal(1.0)
	assert(absf(game.result_chart.reveal - 1.0) < 0.001)

	# 战败路径：星级保持熄灭、界面正常刷新。
	game._show_battle_result({"victory":false, "stage":1, "difficulty":-1, "stars":0, "new_stars":0, "souls":0})
	assert(game.result_overlay.visible)
	assert(game.result_title_label.text == "失败")
	assert(game.result_star_labels[0].scale == Vector2.ONE)

	print("RESULT_SCREEN_TEST_OK")
	quit()
