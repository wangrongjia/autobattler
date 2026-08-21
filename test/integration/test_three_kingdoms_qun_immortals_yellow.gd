extends SceneTree

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()

	var huatuo := _unit(game, "player", "huatuo", 2, 0)
	var yuji := _unit(game, "player", "yuji", 1, 1)
	var zuoci := _unit(game, "player", "zuoci", 2, 2)
	var heal_target := _unit(game, "player", "lvbu", 0, 0)
	for ally in [huatuo, yuji, zuoci, heal_target]:
		ally.max_hp = 10000.0
		ally.hp = 9000.0
	heal_target.hp = 100.0
	heal_target.stun = 2.0
	heal_target.burn = 3.0
	heal_target.poison = 4.0
	game.combat_units = [huatuo, yuji, zuoci, heal_target]
	var before := float(heal_target.hp)
	game._cast_huatuo_skill(huatuo)
	assert(is_equal_approx(float(heal_target.hp) - before, 210.0))
	assert(is_zero_approx(float(heal_target.stun)))
	assert(is_zero_approx(float(heal_target.burn)))
	assert(is_zero_approx(float(heal_target.poison)))
	print("qun_immortals:huatuo_ok")

	var enemies: Array = []
	for row in game.BOARD_ROWS:
		for col in game.BOARD_COLUMNS:
			var enemy := _unit(game, "enemy", "caocao", row, col)
			enemy.max_hp = 10000.0
			enemy.hp = enemy.max_hp
			enemies.append(enemy)
	game.combat_units = [yuji, huatuo, zuoci] + enemies
	game._cast_yuji_skill(yuji)
	var poisoned: Array = enemies.filter(func(enemy): return not (enemy.poison_effects as Array).is_empty())
	assert(poisoned.size() == 3)
	assert(poisoned.all(func(enemy): return int(enemy.poison_effects[0].stacks) == 140))
	var poison_hp := float(poisoned[0].hp)
	game._process_statuses(1.0)
	assert(is_equal_approx(poison_hp - float(poisoned[0].hp), 140.0))
	assert(int(poisoned[0].poison_effects[0].stacks) == 70)
	game._process_statuses(1.0)
	assert(int(poisoned[0].poison_effects[0].stacks) == 35)
	print("qun_immortals:yuji_decay_ok")

	huatuo.hp = 100.0
	yuji.hp = 200.0
	zuoci.hp = 300.0
	for enemy in enemies: enemy.hp = enemy.max_hp
	game.combat_units = [zuoci, huatuo, yuji] + enemies
	game.visual_events.clear()
	before = float(huatuo.hp)
	game._cast_zuoci_skill(zuoci)
	assert(is_equal_approx(float(huatuo.hp) - before, 270.0))
	var thunder: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	assert(thunder.size() == 2 and thunder.all(func(event): return int(event.amount) == 200))
	print("qun_immortals:zuoci_ok")

	var zhangjiao := _unit(game, "player", "zhangjiao", 2, 0)
	var zhangliang := _unit(game, "player", "zhangliang", 1, 1)
	var zhangbao := _unit(game, "player", "zhangbao", 0, 2)
	for enemy in enemies: enemy.hp = enemy.max_hp; enemy.stun = 0.0
	game.combat_units = [zhangjiao, zhangliang, zhangbao] + enemies
	game.visual_events.clear()
	game.rng.seed = 17
	game._cast_zhangjiao_skill(zhangjiao)
	var lightning: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage")
	assert(lightning.size() == 2 and lightning.all(func(event): return int(event.amount) == 420))
	print("qun_yellow:zhangjiao_ok")

	for enemy in enemies: enemy.skill_debuff = 0.0; enemy.skill_debuff_time = 0.0
	game._cast_zhangliang_skill(zhangliang)
	var weakened: Array = enemies.filter(func(enemy): return float(enemy.skill_debuff_time) > 0.0)
	assert(weakened.size() == 3)
	assert(weakened.all(func(enemy): return is_equal_approx(float(enemy.skill_debuff), 0.5)))
	assert(weakened.all(func(enemy): return is_equal_approx(float(enemy.skill_debuff_time), 11.7)))
	print("qun_yellow:zhangliang_ok")

	var killer := _unit(game, "enemy", "caocao", 0, 0)
	killer.max_hp = 100000.0
	killer.hp = killer.max_hp
	game.combat_units = [zhangbao, zhangliang, zhangjiao, killer] + enemies
	game.visual_events.clear()
	game._damage(killer, zhangbao, 100000.0, "physical", "revive test")
	assert(zhangbao.alive and int(zhangbao.zhangbao_revives_used) == 1)
	assert(is_equal_approx(float(zhangbao.hp), float(zhangbao.max_hp) * 0.50))
	var explosions: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage" and str(event.get("source_id", "")) == str(zhangbao.id))
	assert(explosions.any(func(event): return int(event.amount) == 900))
	game._damage(killer, zhangbao, 100000.0, "physical", "revive test")
	assert(zhangbao.alive and int(zhangbao.zhangbao_revives_used) == 2)
	game._damage(killer, zhangbao, 100000.0, "physical", "revive test")
	assert(not zhangbao.alive)
	var death_thunder: Array = game.visual_events.filter(func(event): return event.get("kind", "") == "damage" and str(event.get("source_id", "")) == str(zhangjiao.id) and int(event.get("amount", 0)) == 600)
	assert(death_thunder.size() == 2)
	print("qun_yellow:zhangbao_ok")

	game.tick_timer.stop()
	quit()

func _unit(game, team: String, hero_id: String, row: int, col: int) -> Dictionary:
	var unit: Dictionary = game._make_roster_unit(team, hero_id)
	unit.row = row
	unit.col = col
	return unit
