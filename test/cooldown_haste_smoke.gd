extends SceneTree

var failures: Array[String] = []

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _near(actual: float, expected: float, message: String) -> void:
	_check(is_equal_approx(actual, expected), "%s：实际 %.5f，预期 %.5f" % [message, actual, expected])

func _init() -> void:
	var packed: PackedScene = load("res://ThreeKingdom/ThreeKingdom.tscn")
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()
	game.talent_levels = {}
	game.rune_loadouts = {}

	var guojia: Dictionary = game._make_roster_unit("player", "guojia")
	var base_cooldown := float(game.heroes.guojia.cooldown)
	guojia.talent_cooldown_haste = 0.0
	guojia.rune_cooldown_haste = 0.0
	guojia.bond_haste = 0.0
	game.game_mode = "quick"
	_near(game._unit_skill_cooldown(guojia), base_cooldown, "零极速应保持基础冷却")

	guojia.talent_cooldown_haste = 100.0
	_near(game._unit_skill_cooldown(guojia), base_cooldown * 0.5, "100极速应使冷却减半")
	guojia.talent_cooldown_haste = 1000.0
	_near(game._unit_skill_cooldown(guojia), 2.0, "冷却不得低于2秒")

	guojia.talent_cooldown_haste = 0.0
	guojia.rune_cooldown_haste = -8.0
	_near(game._unit_skill_cooldown(guojia), base_cooldown * 100.0 / 92.0, "负极速应按同一公式拖慢冷却")
	guojia.rune_cooldown_haste = 0.0
	game._add_bond_cooldown_haste(guojia, 2.8)
	var bond_haste := 2.8 / base_cooldown * 100.0
	_near(float(guojia.bond_haste), bond_haste, "英雄羁绊固定减秒应换算为极速")
	_near(game._unit_skill_cooldown(guojia), base_cooldown * 100.0 / (100.0 + bond_haste), "英雄羁绊应进入统一极速公式")

	guojia.bond_haste = 0.0
	game.game_mode = "tianshu"
	game.tianshu_levels = {"fengchi":1}
	game._tianshu_recompute_unit_stats(guojia)
	_near(float(guojia.tianshu_cooldown_haste), 0.25 / base_cooldown * 100.0, "天书固定减秒应换算为极速")

	game.game_mode = "quick"
	var chengong: Dictionary = game._make_roster_unit("player", "chengong")
	chengong.row = 0
	chengong.col = 0
	chengong.skill_value_bonus = 0.0
	guojia.row = 1
	guojia.col = 0
	game.player_units = [chengong, guojia]
	game.enemy_units = []
	game.combat_units = game.player_units
	game._apply_combo_bonds(false, false)
	_near(float(guojia.bond_haste), 24.0, "陈宫应按24%兵略值提供冷却极速")

	if failures.is_empty():
		print("COOLDOWN_HASTE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
