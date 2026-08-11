extends SceneTree

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()

	# Star selectors are retired; compatibility helpers always return one-star values.
	assert(game._star_stat_multiplier(1) == 1.0)
	assert(game._star_stat_multiplier(2) == 1.0)
	assert(game._star_stat_multiplier(3) == 1.0)
	assert(game._star_skill_values("huangzhong", 1) == game._star_skill_values("huangzhong", 2))
	assert(game._star_skill_values("caoren", 2) == game._star_skill_values("caoren", 3))
	for hero_id in game.heroes:
		assert(game._star_skill_values(hero_id, 1) == game._star_skill_values(hero_id, 3))

	# Every hero keeps a positive skill budget after loading balance overrides.
	for hero_id in game.heroes:
		var hero: Dictionary = game.heroes[hero_id]
		assert(float(hero.skill_value) > 0.0)
	assert(game.heroes.sunshangxiang.skill_value == 100)
	assert(game.heroes.huangzhong.skill_value == game.heroes.guanyu.skill_value)
	assert(game.heroes.huangzhong.ability_params.mult == 1.45)
	assert(game.heroes.lvmeng.roles.has("刺客"))
	assert(game.heroes.ganning.roles.has("刺客"))
	assert(game.heroes.lvmeng.skill_value > 0 and game.heroes.ganning.skill_value > 0)
	assert(game._hero_bond_detail("machao").contains("行动条速度提高15%"))
	assert(game._hero_bond_detail("liushan").contains("30%全能吸血"))
	assert(game._hero_bond_detail("huangzhong").contains("50%概率暴击"))
	assert(not game._hero_bond_detail("huangzhong").contains("魏延恢复50%最大生命"))
	assert(game._hero_bond_detail("weiyan").contains("魏延恢复50%最大生命"))
	for tiger_id in ["guanyu", "zhangfei", "zhaoyun", "huangzhong"]:
		assert(not game._hero_bond_detail(tiger_id).contains("行动条速度提高15%"))
	assert(game._hero_bond_detail("jiangwei").contains("北伐传承"))
	assert(game._hero_bond_detail("jiangwei").contains("减伤由15%提高至30%"))
	assert(game._hero_bond_detail("pangtong").contains("卧龙凤雏"))
	assert(game._hero_bond_detail("pangtong").contains("两条普通羁绊"))
	for bond_name in ["七擒孟获", "南蛮夫妇", "蛮王援军"]:
		assert(game._hero_bond_detail("menghuo").contains(bond_name))
	for bond_name in ["南蛮夫妇", "姐弟同心"]:
		assert(game._hero_bond_detail("zhurong").contains(bond_name))
	for bond_name in ["蛮王援军", "姐弟同心"]:
		assert(game._hero_bond_detail("dailaidongzhu").contains(bond_name))

	# Enlarged codex uses a full-art left pane and a complete, synchronized detail pane.
	game.language = "zh"
	game.show_hero_codex_images = true
	game._show_encyclopedia()
	game._show_encyclopedia_preview("liubei")
	assert(game.encyclopedia_preview_overlay.visible)
	assert(game.encyclopedia_preview_portrait.texture != null)
	assert(game.encyclopedia_preview_detail.text.contains("技能"))
	assert(game.encyclopedia_preview_detail.text.contains("生命"))
	var preview_before: int = game.encyclopedia_preview_index
	game._step_encyclopedia_preview(1)
	assert(game.encyclopedia_preview_index != preview_before)
	assert(not game.encyclopedia_preview_detail.text.is_empty())
	game._hide_encyclopedia_preview()

	# Each pick locks immediately, replaces the pair, and cannot be undone.
	assert(game.choices.size() == 3)
	var first: String = game.choices[0]
	game._choose_hero(first)
	assert(game.chosen_this_round.has(first))
	assert(game.player_units.size() == 1)
	assert(game.draft_picks_remaining == 2)
	assert(game.choices.size() == 3)
	game._choose_hero("not_a_current_choice")
	assert(game.chosen_this_round.has(first))
	assert(game.player_units.size() == 1)
	game._choose_hero(game.choices[0])
	game._choose_hero(game.choices[0])
	assert(game.phase == "placement")
	assert(not game.draft_overlay.visible)
	assert(not game.draft_toggle_button.visible)
	assert(game.chosen_this_round.size() == 3)
	assert(game.player_units.size() >= 1 and game.player_units.size() <= 3)
	var locked: Array[String] = game.chosen_this_round.duplicate()
	game._choose_hero(first)
	assert(game.phase == "placement")
	assert(game.chosen_this_round == locked)

	# Range-1 melee can deploy and target only the front row (row 0).
	var guanyu: Dictionary = game._make_roster_unit("player", "guanyu")
	game.player_units = [guanyu]
	assert(game._can_unit_use_row(guanyu, 0))
	assert(not game._can_unit_use_row(guanyu, 1))
	assert(not game._can_drop_board(Vector2.ZERO, {"unit_id":guanyu.id}, 1, 0))
	var front: Dictionary = game._make_roster_unit("enemy", "caocao")
	var back: Dictionary = game._make_roster_unit("enemy", "zhouyu")
	guanyu.row = 0; guanyu.col = 0
	front.row = 0; front.col = 0
	back.row = 1; back.col = 0
	game.player_units = [guanyu]
	game.enemy_units = [front, back]
	game.combat_units = [guanyu, front, back]
	for _i in 30: assert(game._random_enemy_tile(guanyu).row == 0)
	assert(game._targets_in_range(guanyu) == [front])

	quit()
