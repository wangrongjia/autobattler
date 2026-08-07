extends SceneTree

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	assert(game.heroes.size() == 58)
	var faction_sizes := {"shu":15, "wei":14, "wu":15, "qun":14}
	for faction in faction_sizes:
		assert(game.heroes.values().filter(func(hero): return hero.f == faction).size() == faction_sizes[faction])
	assert(game._portrait_texture("zhaoyun") != null)
	assert(game._portrait_source_texture("dailaidongzhu").resource_path.ends_with("/pic/dailaidongzhu.png"))
	assert(game.heroes.dailaidongzhu.zh_skill == "蛮骨狼袭")
	assert(game.heroes.dailaidongzhu.cooldown == 8.0)
	game.pause_during_actions = true
	game._toggle_pause_setting()
	assert(not game.pause_during_actions)
	game.game_speed = 1.0
	game._cycle_speed()
	assert(game.game_speed == 2.0)
	game._cycle_speed()
	assert(game.game_speed == 4.0)
	game._cycle_speed()
	assert(game.game_speed == 1.0)
	var source: Dictionary = game._make_roster_unit("player", "zhaoyun")
	var target: Dictionary = game._make_roster_unit("enemy", "caocao")
	source.row = 0
	source.col = 0
	target.row = 0
	target.col = 0
	game.combat_units = [source, target]
	game.battle_stats[source.id] = {"damage":0.0, "healing":0.0, "taken":0.0, "control":0.0}
	game.battle_stats[target.id] = {"damage":0.0, "healing":0.0, "taken":0.0, "control":0.0}
	game._cast_generic_ability(source)
	assert(game.battle_stats[source.id].damage >= 0.0)
	var dailai: Dictionary = game._make_roster_unit("player", "dailaidongzhu")
	var slow_enemy: Dictionary = game._make_roster_unit("enemy", "caocao")
	var ready_enemy: Dictionary = game._make_roster_unit("enemy", "dianwei")
	dailai.row = 0
	dailai.col = 1
	dailai.level = 2
	slow_enemy.row = 0
	slow_enemy.col = 1
	slow_enemy.action = 30.0
	ready_enemy.row = 1
	ready_enemy.col = 2
	ready_enemy.action = 90.0
	ready_enemy.max_hp = 100000.0
	ready_enemy.hp = ready_enemy.max_hp
	game.combat_units = [dailai, slow_enemy, ready_enemy]
	game.battle_stats[dailai.id] = {"damage":0.0, "healing":0.0, "taken":0.0, "control":0.0}
	game._cast_dailai_skill(dailai)
	assert(ready_enemy.action == 55.0)
	assert(slow_enemy.action == 30.0)
	assert(float(ready_enemy.hp) < float(ready_enemy.max_hp))
	game.visual_events.clear()
	game.combat_units = [source, target]
	game.pause_during_actions = false
	game.battle_running = true
	source.action = 100.0
	target.action = 0.0
	game._begin_action(source)
	assert(not game.action_in_progress)
	var before_tick: float = target.action
	game._battle_tick()
	assert(target.action > before_tick)
	game.battle_running = false
	game.pause_during_actions = true
	game.game_speed = 1.0
	game.battle_speed = 1.0
	game._save_settings()
	quit()
