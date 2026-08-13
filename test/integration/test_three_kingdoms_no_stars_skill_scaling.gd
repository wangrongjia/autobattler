extends SceneTree

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	print("CHECKPOINT scene_ready")
	game.tick_timer.stop()

	# Every hero is registered directly with 100 Strategy; no hidden output baseline exists.
	for hero in game.heroes.values():
		assert(float(hero.skill_value) == 100.0)
		assert(not hero.has("skill_output_base"))
	assert(game._star_stat_multiplier(3) == 1.0)
	assert(game._star_effect_multiplier(3) == 1.0)
	print("CHECKPOINT normalized")

	# Duplicates stay independent and never merge.
	game.player_units.clear()
	var first: Dictionary = game._make_roster_unit("player", "guanyu")
	var second: Dictionary = game._make_roster_unit("player", "guanyu")
	game.player_units.append_array([first, second])
	assert(game._try_upgrade(game.player_units, "guanyu") == null)
	assert(game.player_units.size() == 2)
	for unit in game.player_units:
		assert(int(unit.level) == 1)
		assert(float(unit.stat_mult) == 1.0)
	print("CHECKPOINT duplicates")

	# Ma Dai's percent-HP effect scales linearly with current SKILL.
	var madai: Dictionary = game._make_roster_unit("player", "madai")
	var target: Dictionary = game._make_roster_unit("enemy", "caocao")
	madai.row = 2
	madai.col = 0
	target.row = 0
	target.col = 0
	target.max_hp = 10000.0
	target.hp = 10000.0
	game.combat_units = [madai, target]
	game.battle_stats[madai.id] = {"damage":0.0, "healing":0.0, "taken":0.0, "control":0.0}
	game.battle_stats[target.id] = {"damage":0.0, "healing":0.0, "taken":0.0, "control":0.0}
	game.heroes.madai.skill_value = 100
	print("CHECKPOINT madai")
	game._cast_madai_execution(madai)
	assert(is_equal_approx(float(target.hp), 5000.0))
	target.hp = 10000.0
	game.heroes.madai.skill_value = 50
	game._cast_madai_execution(madai)
	assert(is_equal_approx(float(target.hp), 7500.0))
	game.heroes.madai.skill_value = 100

	# Recruitment always exposes Vanguard / Midguard / Rearguard slots.
	game.draft_faction_filter = "shu"
	game._generate_choices()
	assert(game.choices.size() == 3)
	for index in 3:
		assert(int(game.heroes[game.choices[index]].range) == index + 1)
		assert(str(game.heroes[game.choices[index]].f) == "shu")
	assert(game.draft_refresh_available == [true, true, true])
	print("CHECKPOINT draft")

	# Enemy waves are newly randomized but obey their own faction restriction.
	game.enemy_faction_filter = "wei"
	game.enemy_units.clear()
	game._add_enemy_wave()
	assert(game.enemy_units.size() == 3)
	for unit in game.enemy_units:
		assert(str(game.heroes[unit.hero_id].f) == "wei")
		assert(int(unit.level) == 1)
	print("CHECKPOINT enemy")

	# Poison application and periodic ticks are grouped, simultaneous events.
	var yuji: Dictionary = game._make_roster_unit("player", "yuji")
	yuji.row = 2; yuji.col = 0
	var poison_a: Dictionary = game._make_roster_unit("enemy", "caocao")
	var poison_b: Dictionary = game._make_roster_unit("enemy", "dianwei")
	poison_a.row = 0; poison_a.col = 0
	poison_b.row = 0; poison_b.col = 1
	game.combat_units = [yuji, poison_a, poison_b]
	game.visual_events.clear()
	game._cast_yuji_skill(yuji)
	var apply_events: Array = game.visual_events.filter(func(event): return str(event.get("group_style", "")) == "poison_apply")
	assert(apply_events.size() == 2)
	assert(apply_events.all(func(event): return str(event.visual_group).begins_with("yuji_poison:")))
	game.visual_events.clear()
	for effect in poison_a.get("poison_effects", []): effect.clock = 0.9
	for effect in poison_b.get("poison_effects", []): effect.clock = 0.9
	game.battle_time = 1.0
	game._process_statuses(0.2)
	var poison_ticks: Array = game.visual_events.filter(func(event): return str(event.get("group_style", "")) == "poison_tick")
	assert(poison_ticks.size() == 2)
	assert(poison_ticks[0].visual_group == poison_ticks[1].visual_group)

	# Balance editing separates hero values and GitHub sync into child tabs.
	var editor_page = game.balance_editor_scroll.get_parent()
	var sub_tabs = editor_page.get_parent()
	assert(sub_tabs is TabContainer)
	assert(sub_tabs.get_tab_count() == 2)
	assert(is_instance_valid(game.enemy_faction_setting_options))
	target.poison = 2.0
	target.burn = 2.0
	target.stun = 1.0
	target.slow_time = 1.0
	target.skill_debuff_time = 1.0
	target.timed_damage_buff = 0.1
	target.timed_action_bonus = 0.1
	var icon_row = game._unit_status_icon_row(target)
	assert(icon_row.get_child_count() == 7)
	icon_row.queue_free()
	print("CHECKPOINT complete")
	quit()
