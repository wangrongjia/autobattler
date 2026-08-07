extends SceneTree

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()
	assert(game.RESERVE_LIMIT == 9)
	assert(game.PICKS_PER_ROUND == 3)
	assert(game.DRAFT_SIZE == 2)
	for hero_id in game.heroes:
		var hero: Dictionary = game.heroes[hero_id]
		assert(int(hero.range) in [1, 2, 3])
		assert(float(hero.cooldown) >= game._minimum_skill_cooldown(hero_id))
		assert(hero.has("skill_value"))
	assert(game.heroes.liubei.cooldown == 4.0)
	assert(game.heroes.liushan.cooldown == 4.0)
	assert(game.heroes.zhangfei.cooldown == 6.5)
	assert(game.heroes.huangzhong.cooldown == 4.0)
	assert(game.heroes.zhaoyun.cooldown == float(game.balance_overrides.get("zhaoyun", {}).get("cooldown", 4.5)))
	assert(game.heroes.machao.cooldown == float(game.balance_overrides.get("machao", {}).get("cooldown", 6.0)))
	assert(game.heroes.weiyan.cooldown == float(game.balance_overrides.get("weiyan", {}).get("cooldown", 5.0)))
	assert(game.heroes.madai.cooldown == 20.0)
	assert(game.heroes.guanyu.cooldown == game.DEFAULT_SKILL_COOLDOWN)

	# Midguard targeting mirrors formation row; rearguard reaches all rows.
	var zhangfei: Dictionary = game._make_roster_unit("player", "zhangfei")
	zhangfei.row = 0
	assert(game._attackable_rows(zhangfei) == [0, 1, 2])
	zhangfei.row = 1
	assert(game._attackable_rows(zhangfei) == [0, 1])
	zhangfei.row = 2
	assert(game._attackable_rows(zhangfei) == [0])
	var liubei: Dictionary = game._make_roster_unit("player", "liubei")
	for row in 3:
		liubei.row = row
		assert(game._attackable_rows(liubei) == [0, 1, 2])
	var guanyu: Dictionary = game._make_roster_unit("player", "guanyu")
	assert(game._can_unit_use_row(guanyu, 0))
	assert(not game._can_unit_use_row(guanyu, 1))
	var weiyan: Dictionary = game._make_roster_unit("player", "weiyan")
	assert(game._can_unit_use_row(weiyan, 0))
	assert(not game._can_unit_use_row(weiyan, 1))
	assert(not game._can_unit_use_row(weiyan, 2))

	# A completed gauge directly casts the hero's active.
	guanyu.row = 0; guanyu.col = 0
	var enemies: Array = []
	for row in 3:
		for col in 4:
			var enemy: Dictionary = game._make_roster_unit("enemy", "caocao")
			enemy.row = row; enemy.col = col
			enemies.append(enemy)
	game.combat_units = [guanyu] + enemies
	game.visual_events.clear()
	game._perform_action(guanyu)
	assert(game.visual_events.any(func(event): return event.kind == "charge"))

	# Liu Bei's three specified bonds modify duration, coefficient and magic reduction.
	var bond_ids := ["liubei", "guanyu", "zhangfei", "liushan", "zhugeliang", "machao", "huangzhong", "zhaoyun", "weiyan", "madai", "pangtong", "menghuo"]
	var bond_team: Array = []
	for i in bond_ids.size():
		var ally: Dictionary = game._make_roster_unit("player", bond_ids[i])
		ally.row = int(i / 4); ally.col = i % 4
		bond_team.append(ally)
	game.combat_units = bond_team
	game._cast_liubei_regen(bond_team[0])
	var regenerating := bond_team.filter(func(ally): return float(ally.regen_time) > 0.0)
	assert(regenerating.size() == 1)
	assert(regenerating[0].regen_time == float(game.heroes.liubei.ability_params.get("duration", 4.0)) * 1.5)
	assert(regenerating[0].regen_per_second == float(game.heroes.liubei.ability_params.get("base_value", game.heroes.liubei.skill_value)) * 3.0)
	assert(regenerating[0].regen_magic_reduction == 0.20)

	# Five Tigers and Peach Garden alter the exact supplied hero actives.
	var zhang: Dictionary = bond_team[2]
	game._cast_zhangfei_command(zhang)
	for ally in bond_team.filter(func(member): return member.row == 0):
		assert(ally.timed_damage_buff == 0.15)
		assert(ally.timed_damage_time == 6.0)
		assert(ally.timed_reduction == 0.20)
	var zhao: Dictionary = bond_team[7]
	var zhao_target: Dictionary = game._make_roster_unit("enemy", "caocao")
	zhao_target.row = 2
	zhao_target.col = 0
	zhao_target.max_hp = 100000.0
	zhao_target.hp = zhao_target.max_hp
	game.combat_units = bond_team + [zhao_target]
	var zhao_target_hp: float = zhao_target.hp
	game.visual_events.clear()
	game._cast_zhaoyun_empower(zhao)
	var zhao_hits: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage" and event.get("target_id", "") == zhao_target.id)
	assert(zhao_hits.size() == 7)
	var zhao_both_bond_mults := [0.50, 0.70, 0.90, 1.10, 1.30, 1.50, 1.70]
	for index in zhao_hits.size():
		assert(int(zhao_hits[index].amount) == roundi(float(game.heroes.zhaoyun.skill_value) * float(zhao_both_bond_mults[index])))
	assert(zhao_target.hp < zhao_target_hp)
	assert(zhao.timed_reduction == 0.0)

	# Defense stats no longer alter damage.
	var tank: Dictionary = game._make_roster_unit("enemy", "caoren")
	var mage: Dictionary = game._make_roster_unit("enemy", "xiaoqiao")
	var tank_before: float = tank.hp
	var mage_before: float = mage.hp
	game._damage(null, tank, 100.0, "physical", "test")
	game._damage(null, mage, 100.0, "magic", "test")
	assert(is_equal_approx(tank_before - tank.hp, 100.0))
	assert(is_equal_approx(mage_before - mage.hp, 100.0))

	# Enemy ruler HP persists into the next recruitment wave.
	game.combat_units = []
	game.round_number = 1
	game.final_battle = false
	game.player_ruler_hp = 4200
	game.enemy_ruler_hp = 3210
	game.phase = "combat"
	game.battle_running = true
	game._finish_battle()
	assert(game.enemy_ruler_hp == 3210)
	assert(game.draft_picks_remaining == 3)
	quit()
