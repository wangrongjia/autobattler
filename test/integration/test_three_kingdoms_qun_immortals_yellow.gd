extends SceneTree

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()

	for removed_id in ["yuanshao", "yuanshu"]:
		assert(not game.heroes.has(removed_id))
	for hero_id in ["huatuo", "yuji", "zuoci", "zhangjiao", "zhangliang", "zhangbao"]:
		assert(game.heroes.has(hero_id))
	assert(is_equal_approx(float(game.heroes.huatuo.cooldown), 6.0))
	assert(is_equal_approx(float(game.heroes.yuji.cooldown), 6.6))
	assert(is_equal_approx(float(game.heroes.zuoci.cooldown), 6.0))
	assert(is_equal_approx(float(game.heroes.zhangjiao.cooldown), 6.0))
	assert(is_equal_approx(float(game.heroes.zhangliang.cooldown), 5.0))
	assert(not game._unit_has_active_skill(_unit(game, "player", "zhangbao", 0, 0)))
	print("qun_new:data_ok")

	# Hua Tuo heals the three lowest-current-HP allies. The full immortal triangle
	# increases healing to 150% and cleanses every healed target.
	var huatuo := _unit(game, "player", "huatuo", 2, 0)
	var yuji := _unit(game, "player", "yuji", 2, 1)
	var zuoci := _unit(game, "player", "zuoci", 2, 2)
	var heal_target := _unit(game, "player", "lvbu", 0, 0)
	for ally in [huatuo, yuji, zuoci, heal_target]:
		ally.max_hp = 10000.0
		ally.hp = 9000.0
	heal_target.hp = 100.0
	heal_target.stun = 2.0
	heal_target.burn = 3.0
	heal_target.poison = 4.0
	heal_target.skill_debuff = 0.5
	heal_target.skill_debuff_time = 5.0
	game.combat_units = [huatuo, yuji, zuoci, heal_target]
	var heal_before := float(heal_target.hp)
	game._cast_huatuo_skill(huatuo)
	assert(is_equal_approx(float(heal_target.hp) - heal_before, game._unit_scaled_skill_value(huatuo) * 1.5))
	assert(is_zero_approx(float(heal_target.stun)))
	assert(is_zero_approx(float(heal_target.burn)))
	assert(is_zero_approx(float(heal_target.poison)))
	assert(is_zero_approx(float(heal_target.skill_debuff)))
	print("qun_new:huatuo_ok")

	# Both Yu Ji bonds stack independently: four targets and six seconds.
	var enemies: Array = []
	for index in 4:
		var enemy := _unit(game, "enemy", "caocao", index % 3, index)
		enemy.max_hp = 10000.0
		enemy.hp = enemy.max_hp
		enemies.append(enemy)
	game.combat_units = [yuji, huatuo, zuoci] + enemies
	game._cast_yuji_skill(yuji)
	assert(enemies.all(func(enemy): return is_equal_approx(float(enemy.poison), 6.0)))
	assert(enemies.all(func(enemy): return is_equal_approx(float(enemy.poison_ratio), 0.005)))
	var poison_hp := float(enemies[0].hp)
	game._process_statuses(1.0)
	assert(is_equal_approx(poison_hp - float(enemies[0].hp), 50.0))
	print("qun_new:yuji_ok")

	# Zuo Ci gains stronger healing from Hua Tuo and twin lightning from Yu Ji.
	huatuo.hp = 200.0
	yuji.hp = 300.0
	zuoci.hp = 100.0
	for enemy in enemies: enemy.hp = enemy.max_hp
	game.combat_units = [zuoci, huatuo, yuji] + enemies
	game.visual_events.clear()
	var zuoci_hp := float(zuoci.hp)
	game._cast_zuoci_skill(zuoci)
	assert(is_equal_approx(float(zuoci.hp) - zuoci_hp, game._unit_scaled_skill_value(zuoci) * 2.0))
	var thunder_hits: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	assert(thunder_hits.size() == 2)
	print("qun_new:zuoci_ok")

	# Zhang Jiao: 250% with Zhang Liang, three targets and probabilistic stun with Zhang Bao.
	var zhangjiao := _unit(game, "player", "zhangjiao", 2, 0)
	var zhangliang := _unit(game, "player", "zhangliang", 2, 1)
	var zhangbao := _unit(game, "player", "zhangbao", 0, 2)
	for enemy in enemies: enemy.hp = enemy.max_hp; enemy.stun = 0.0
	game.combat_units = [zhangjiao, zhangliang, zhangbao] + enemies
	game.visual_events.clear()
	game.rng.seed = 17
	game._cast_zhangjiao_skill(zhangjiao)
	var lightning_hits: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	assert(lightning_hits.size() == 3)
	assert(lightning_hits.all(func(event): return int(event.amount) == roundi(game._unit_skill_output_base(zhangjiao) * game._unit_skill_power_multiplier(zhangjiao) * 2.5)))
	print("qun_new:zhangjiao_ok")

	# Zhang Liang reaches four targets when both bonds are active and expiry restores SKILL.
	for enemy in enemies: enemy.skill_debuff = 0.0; enemy.skill_debuff_time = 0.0
	game._cast_zhangliang_skill(zhangliang)
	assert(enemies.all(func(enemy): return is_equal_approx(float(enemy.skill_debuff), 0.5)))
	assert(enemies.all(func(enemy): return is_equal_approx(float(enemy.skill_debuff_time), 5.0)))
	game._process_statuses(5.0)
	assert(enemies.all(func(enemy): return is_zero_approx(float(enemy.skill_debuff))))
	print("qun_new:zhangliang_ok")

	# Zhang Bao explodes on every death and gains a second full-HP revival with Zhang Liang.
	var killer := _unit(game, "enemy", "caocao", 0, 0)
	killer.max_hp = 100000.0
	killer.hp = killer.max_hp
	for enemy in enemies: enemy.team = "enemy"; enemy.hp = enemy.max_hp
	game.combat_units = [zhangbao, zhangliang, zhangjiao, killer] + enemies
	game.visual_events.clear()
	game._damage(killer, zhangbao, 100000.0, "physical", "revive test")
	assert(zhangbao.alive and int(zhangbao.zhangbao_revives_used) == 1)
	assert(is_equal_approx(float(zhangbao.hp), float(zhangbao.max_hp)))
	game._damage(killer, zhangbao, 100000.0, "physical", "revive test")
	assert(zhangbao.alive and int(zhangbao.zhangbao_revives_used) == 2)
	game._damage(killer, zhangbao, 100000.0, "physical", "revive test")
	assert(not zhangbao.alive)
	assert(game.visual_events.filter(func(event): return event.get("kind", "") == "damage" and str(event.get("source_id", "")) == str(zhangbao.id)).size() >= 6)
	print("qun_new:zhangbao_ok")

	# Combat board click opens a realtime inspector and the same toggle closes it.
	zhangjiao.alive = true
	zhangjiao.hp = zhangjiao.max_hp - 100.0
	zhangjiao.skill_debuff = 0.5
	zhangjiao.skill_debuff_time = 3.0
	game.combat_units = [zhangjiao, zhangliang]
	game.phase = "combat"
	game._render_combat_boards()
	game._toggle_unit_inspector(str(zhangjiao.id))
	assert(game.unit_inspector_overlay.visible)
	assert(game.unit_inspector_detail.text.contains("HP"))
	assert(game.unit_inspector_detail.text.contains("技能强度"))
	assert(game.unit_inspector_detail.text.contains("天人同道"))
	assert(game.unit_inspector_detail.text.contains("虚弱"))
	game._toggle_unit_inspector(str(zhangjiao.id))
	assert(not game.unit_inspector_overlay.visible)
	print("qun_new:inspector_ok")

	game.tick_timer.stop()
	quit()

func _unit(game, team: String, hero_id: String, row: int, col: int) -> Dictionary:
	var unit: Dictionary = game._make_roster_unit(team, hero_id)
	unit.row = row
	unit.col = col
	return unit
