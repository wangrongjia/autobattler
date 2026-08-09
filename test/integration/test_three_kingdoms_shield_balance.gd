extends SceneTree

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()

	# No hero may retain the old max-HP team shield implementation.
	for hero in game.heroes.values():
		assert(hero.get("ability", "") != "shield_team")
		if str(hero.get("ability", "")).begins_with("shield_"):
			assert(not hero.get("ability_params", {}).has("ratio"))

	var yujin: Dictionary = game._make_roster_unit("player", "yujin")
	var caoren: Dictionary = game._make_roster_unit("player", "caoren")
	var ally: Dictionary = game._make_roster_unit("player", "xunyu")
	yujin.row = 0; yujin.col = 0
	caoren.row = 1; caoren.col = 0
	ally.row = 2; ally.col = 1
	ally.hp *= 0.25
	game.player_units = [yujin, caoren, ally]
	game.enemy_units = []
	game.combat_units = game.player_units
	game._apply_combo_bonds()
	game._cast_active_skill(yujin)
	for _i in 10: game._cast_generic_ability(caoren)
	assert(yujin.shield == 0.0)
	assert(caoren.shield == 0.0)
	assert(ally.shield > 0.0)
	assert(is_equal_approx(float(ally.shield), 200.0 + float(ally.max_hp) * 0.03))
	assert(ally.shield < ally.max_hp * 0.30)

	# Sun Quan's reworked signature no longer leaves any team/column damage buff.
	var sunquan: Dictionary = game._make_roster_unit("player", "sunquan")
	var same_column: Dictionary = game._make_roster_unit("player", "sunce")
	var other_column: Dictionary = game._make_roster_unit("player", "zhouyu")
	var enemy: Dictionary = game._make_roster_unit("enemy", "caocao")
	sunquan.row = 0; sunquan.col = 0
	same_column.row = 1; same_column.col = 0
	other_column.row = 1; other_column.col = 1
	enemy.row = 0; enemy.col = 0
	game.player_units = [sunquan, same_column, other_column]
	game.enemy_units = [enemy]
	game.combat_units = game.player_units + game.enemy_units
	game._apply_combo_bonds()
	var old_max_hp := float(sunquan.max_hp)
	game._cast_active_skill(sunquan)
	assert(sunquan.damage_buff == 0.0)
	assert(same_column.damage_buff == 0.0)
	assert(other_column.damage_buff == 0.0)
	assert(is_equal_approx(float(sunquan.max_hp), old_max_hp + 200.0))

	quit()
