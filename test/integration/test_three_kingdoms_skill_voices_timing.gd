extends SceneTree

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()

	# All active baseline cooldowns are doubled; passive heroes remain at zero.
	assert(is_equal_approx(float(game.heroes.zhaoyun.cooldown), 11.4))
	assert(is_equal_approx(float(game.heroes.madai.cooldown), 42.0))
	assert(is_zero_approx(float(game.heroes.chengong.cooldown)))
	assert(is_zero_approx(float(game.heroes.gaolan.cooldown)))
	assert(is_zero_approx(float(game.heroes.zhangbao.cooldown)))

	# Cooldown-reduction bonds use 1.8x and floor to one decimal place.
	assert(is_equal_approx(game._scaled_cooldown_reduction(0.5), 0.9))
	assert(is_equal_approx(game._scaled_cooldown_reduction(0.7), 1.2))
	assert(is_equal_approx(game._scaled_cooldown_reduction(1.2), 2.1))
	assert(is_equal_approx(game._scaled_cooldown_reduction(1.6), 2.8))

	var source: Dictionary = game._make_roster_unit("player", "menghuo")
	game._ensure_unit_fields(source)
	assert(is_equal_approx(game._scaled_control_duration(source, 0.8), 1.4))
	assert(is_equal_approx(game._scaled_control_duration(source, 1.25), 2.2))
	assert(is_equal_approx(game._scaled_control_duration(source, 3.5), 6.3))
	# Damage-over-time durations are intentionally unchanged.
	assert(is_equal_approx(float(game.heroes.zhurong.ability_params.burn), 3.0))
	assert(is_equal_approx(float(game.heroes.zhouyu.ability_params.burn), 4.0))

	assert(is_instance_valid(game.skill_voice_player))
	assert(game._skill_voice_paths("zhaoyun").size() == 3)
	for hero_id in game.heroes:
		assert(game._skill_voice_paths(str(hero_id)).size() == 3)

	assert("眩晕2.2秒" in game._skill_detail("caocao"))
	assert("冻结5.4秒" in game._skill_detail("guojia"))
	assert("冷却减少1秒" in game._skill_detail("chengong"))
	assert("灼烧3秒" in game._skill_detail("zhurong"))
	quit()
