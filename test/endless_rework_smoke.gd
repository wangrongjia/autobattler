extends SceneTree

var failures: Array[String] = []

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _near(actual: float, expected: float, message: String) -> void:
	_check(absf(actual - expected) < 0.01, "%s：实际 %.3f，预期 %.3f" % [message, actual, expected])

func _init() -> void:
	var packed: PackedScene = load("res://ThreeKingdom/ThreeKingdom.tscn")
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()
	game.talent_levels = {}
	game.rune_loadouts = {}
	game.game_mode = "endless"
	game._endless_new_run()

	# 敌方主轴必须是指数膨胀，频率成长则保持低且封顶。
	_check(game.EndlessRules.enemy_hp_multiplier(35) > 50.0, "第35回合敌军生命倍率应超过50倍")
	_check(game.EndlessRules.enemy_strategy(35) > 600.0, "第35回合敌军兵略应超过600")
	_check(game.EndlessRules.enemy_action_multiplier(200) <= 1.1001, "敌军行动增速必须封顶10%")
	_check(game.EndlessRules.enemy_cooldown_haste(200) <= 12.001, "敌军冷却极速必须封顶12")

	# 同一战策只能从三选一中锁定一项，锁定后其他候选立即失效。
	game.phase = "checkpoint"
	game.endless_state.candidates = ["provisions", "drill", "march"]
	game.endless_state.strategy_pending = true
	var before: Dictionary = game._make_roster_unit("player", "huanggai")
	game.player_units = [before]
	var base_hp := float(before.max_hp)
	_check(game._endless_pick_strategy("provisions"), "第一项战策应可锁定")
	_check(not game._endless_pick_strategy("drill"), "锁定后不得再选择第二项")
	_near(float(before.max_hp), base_hp + 700.0, "已有武将应获得共享固定生命成长")

	# 后续才招募与备战席武将必须读取相同共享快照。
	var later: Dictionary = game._make_roster_unit("player", "huanggai")
	_near(float(later.max_hp), float(before.max_hp), "后续招募武将应继承全军共享成长")
	later.row = -1
	game.player_units.append(later)
	game._endless_sync_player_roster()
	_near(float(later.max_hp), float(before.max_hp), "备战席武将应持续获得同一份成长")

	# 生命战策为固定值加法，不能因为重复同步而乘算膨胀。
	game._endless_sync_player_roster()
	game._endless_sync_player_roster()
	_near(float(before.max_hp), base_hp + 700.0, "共享成长重复同步必须幂等")
	game.round_number = 35
	game._endless_sync_player_roster()
	var round_35_expected: float = base_hp + 700.0 + 34.0 * float(game.EndlessRules.PLAYER_HP_PER_ROUND)
	_near(float(before.max_hp), round_35_expected, "第35回合应按固定值获得线性生命底成长")
	var round_35_recruit: Dictionary = game._make_roster_unit("player", "huanggai")
	_near(float(round_35_recruit.max_hp), round_35_expected, "第35回合新招募武将应继承完整线性成长")

	# 完整入口与据点 UI 必须能实际打开，而不只是公式单测。
	game.menu_overlay.hide()
	game._endless_start_game()
	game.tick_timer.stop()
	_check(game.game_mode == "endless" and game.round_number == 1, "主菜单入口应启动无尽第1回合")
	_check(game.enemy_units.size() == 3, "第1回合应生成一波智能敌军")
	game.round_number = 5
	game._endless_open_checkpoint()
	game._render()
	_check(game.phase == "checkpoint", "第5回合应进入据点阶段")
	_check(game.endless_state.candidates.size() == 3, "据点应生成三个不同战策候选")
	_check(game.checkpoint_overlay.visible, "据点汇总与三选一 UI 应显示")
	_check(game.checkpoint_strategy_box.get_child_count() == 3, "据点 UI 应渲染三张战策卡")

	if failures.is_empty():
		print("ENDLESS_REWORK_SMOKE_OK")
		quit(0)
		return
	for failure in failures: push_error(failure)
	quit(1)
