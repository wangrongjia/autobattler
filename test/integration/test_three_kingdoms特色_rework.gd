extends SceneTree

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()

	# Every roster entry receives a distinct procedural visual identity.
	var visual_keys := {}
	for hero_id in game.heroes:
		var fx: Dictionary = game._hero_fx(hero_id)
		assert(not str(fx.glyph).is_empty())
		assert(str(fx.element) in ["blade", "arrow", "hammer", "spear", "fire", "lightning", "frost", "heal", "arcane"])
		visual_keys[str(fx.glyph) + fx.color.to_html()] = true
	assert(visual_keys.size() >= 50)

	# Ruler HP is represented by vertical arena-side fills.
	assert(is_instance_valid(game.player_ruler_fill))
	assert(is_instance_valid(game.enemy_ruler_fill))
	game.player_ruler_hp = int(game.RULER_MAX_HP * 0.5)
	game.enemy_ruler_hp = int(game.RULER_MAX_HP * 0.25)
	game._render()
	assert(is_equal_approx(game.player_ruler_fill.anchor_top, 0.5))
	assert(is_equal_approx(game.enemy_ruler_fill.anchor_top, 0.75))

	# Faction bonds install mechanics instead of generic stat multipliers.
	game.combat_units = _team(game, ["zhaoyun", "huangzhong", "machao"], "player")
	game._apply_combo_bonds()
	game._apply_faction_bonuses(false)
	for unit in game.combat_units:
		assert(unit.faction_tier == 1)
		assert(not unit.has("skill_damage_mult"))

	# Strategy marks detonate on a following magic hit.
	var caster: Dictionary = game._make_roster_unit("player", "simayi")
	var target: Dictionary = game._make_roster_unit("enemy", "caocao")
	caster.row = 0; caster.col = 0
	target.row = 0; target.col = 0
	target.strategy_mark = 4.0
	game.combat_units = [caster, target]
	game._damage(caster, target, 100.0, "magic", "谋略引爆")
	assert(target.strategy_mark == 0.0)

	assert(game.heroes.zhaoyun.ability == "signature")
	assert(game.heroes.zhaoyun.cooldown == float(game.balance_overrides.get("zhaoyun", {}).get("cooldown", 4.5)))
	assert(game.heroes.guanyu.ability_params.mult == 1.80)
	assert(game.heroes.liushan.cooldown == 4.0)
	assert(game.heroes.liushan.ability_params.duration == 4.0)
	assert(game.heroes.liushan.ability_params.seven_lifesteal == 0.30)
	assert(game.heroes.zhaoyun.ability_params.hit_mults == [0.50, 0.50, 0.50, 0.50, 0.50])
	assert(game.heroes.zhaoyun.ability_params.five_tiger_mults == [0.50, 0.70, 0.90, 1.10, 1.30])
	assert(game.heroes.zhaoyun.ability_params.seven_base_mults == [0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50])
	assert(game.heroes.zhaoyun.ability_params.seven_charge_mults.size() == 7)
	assert(game.heroes.madai.ability_params.max_hp_ratios == [0.60, 0.70, 0.85])
	assert(game.heroes.qunzhanghe.ability_params.spell_ward == 1)
	assert(game.heroes.ganning.cooldown == 8.0)
	assert(game.heroes.ganning.ability_params.mult == 1.50)
	assert(game.heroes.ganning.ability_params.taishici_mult == 2.50)
	assert(game.heroes.ganning.ability_params.lvmeng_low_hp_bonus == 0.50)
	# Coefficient guardrails prevent a single generic cast from combining top
	# burst, long control and oversized shielding again.
	for hero_id in game.heroes:
		var hero: Dictionary = game.heroes[hero_id]
		var params: Dictionary = hero.get("ability_params", {})
		var ability := str(hero.get("ability", ""))
		var hit_count := int(params.get("count", 1)) if ability in ["multi", "multi_magic"] else 1
		var coefficient_cap := 4.0 if hero_id == "lvmeng" else 3.20
		assert(float(params.get("mult", 0.0)) * hit_count <= coefficient_cap)
		assert(float(params.get("stun", 0.0)) <= 2.50)
		assert(float(params.get("damage", 0.0)) <= 0.30)
		if ability.begins_with("shield_"): assert(not params.has("ratio"))
	quit()

func _team(game, ids: Array, team: String) -> Array:
	var result: Array = []
	for i in ids.size():
		var unit: Dictionary = game._make_roster_unit(team, ids[i])
		unit.row = 0
		unit.col = i
		result.append(unit)
	return result
