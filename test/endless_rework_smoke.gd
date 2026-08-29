extends SceneTree

var failures: Array[String] = []
var progression_backup := {}

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _near(actual: float, expected: float, message: String) -> void:
	_check(absf(actual - expected) < 0.01, "%s：实际 %.3f，预期 %.3f" % [message, actual, expected])

func _has_option_button(node: Node) -> bool:
	if node is OptionButton: return true
	for child in node.get_children():
		if _has_option_button(child): return true
	return false

func _restore_progression(game) -> void:
	if progression_backup.is_empty(): return
	for key in progression_backup: game.set(key, progression_backup[key].duplicate(true) if progression_backup[key] is Dictionary or progression_backup[key] is Array else progression_backup[key])
	game._save_progression()

func _init() -> void:
	var packed: PackedScene = load("res://ThreeKingdom/ThreeKingdom.tscn")
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()
	for key in ["general_souls", "general_stars", "stage_star_records", "rune_inventory", "rune_loadouts", "talent_levels", "home_hero_id", "next_rune_id", "endless_imprints", "endless_imprint_nodes", "endless_best_round", "endless_total_runs"]:
		var value = game.get(key)
		progression_backup[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	game.talent_levels = {}
	game.rune_loadouts = {}
	game.game_mode = "endless"
	game._endless_new_run()

	# 60 名武将必须各有一棵七层专属树，且 UI 采用阵营→武将卡片，不再使用下拉框。
	_check(game.ImprintTrees.TREES.size() == game.heroes.size(), "所有武将都应拥有专属将印树")
	for faction in ["shu", "wei", "wu", "qun"]:
		_check(game._imprint_faction_heroes(faction).size() == 15, "%s 阵营应显示 15 张武将卡" % faction)
	_check(game._endless_imprint_node_name("guanyu", "soul") != game._endless_imprint_node_name("huanggai", "soul"), "关羽与黄盖应拥有不同将魂")
	_check(game._endless_imprint_node_name("huanggai", "skill:0") == "火船", "黄盖应拥有专属火船绝技")
	game._show_imprint_overlay()
	_check(not _has_option_button(game.imprint_overlay), "将印面板内不应再出现武将下拉框")
	_check(game.imprint_faction_grid.get_child_count() == 4, "将印面板应显示四个阵营入口")
	_check(game.imprint_hero_grid.get_child_count() == 15, "蜀阵营应渲染 15 张武将卡")
	_check(game.imprint_tree_box.get_child_count() >= 20, "专属将印树应完整渲染七层节点")
	game.ui_theme = "light"
	var paper: Color = game._imprint_ui_color("#171612", "#f7efdb")
	var ink: Color = game._imprint_ui_color("#ddd2bb", "#493b29")
	_check(paper.get_luminance() - ink.get_luminance() > 0.45, "亮色将印卡片应保持足够的明暗对比")
	game.ui_theme = "dark"
	game.imprint_overlay.hide()

	# 七层解锁顺序与分支约束必须真实生效。
	game.endless_imprint_nodes = {}
	game.endless_imprints = 100
	for ignored in 3: _check(game._endless_imprint_upgrade("guanyu", "root:hp"), "关羽根基应可升级")
	_check(game._endless_imprint_layer_unlocked("guanyu", "role"), "根基投入 3 级后应解锁定位层")
	_check(game._endless_imprint_upgrade("guanyu", "role:0"), "第一项定位应可点亮")
	_check(game._endless_imprint_upgrade("guanyu", "role:1"), "第二项定位应可点亮")
	_check(not game._endless_imprint_upgrade("guanyu", "role:2"), "定位层必须严格三选二")

	# 三个测试包批量养成工具应一次完成，并为每名武将生成独立符文实例。
	game.talent_levels = {}
	_check(game._debug_max_all_talents() > 0, "一键点满全部天赋应补齐等级")
	for tree_id in game.TALENT_TREES:
		for node in game.TALENT_TREES[tree_id].nodes:
			_check(game._talent_level(str(tree_id), str(node[0])) == int(node[2]), "全部天赋节点都应达到满级")
	var rune_count_before: int = game.rune_inventory.size()
	_check(game._debug_equip_tier6_rune_all("ZS") == game.heroes.size(), "应为全部武将生成六阶指定符文")
	_check(game.rune_inventory.size() == rune_count_before + game.heroes.size(), "每名武将都应获得独立符文实例")
	var equipped_ids := {}
	for hero_id in game.heroes:
		var slots: Array = game.rune_loadouts.get(str(hero_id), [])
		_check(not slots.is_empty(), "每名武将都应装备生成的符文")
		var rune = game._rune_by_uid(int(slots[-1]))
		_check(rune != null and int(rune.tier) == 6 and str(rune.kind) == "ZS", "批量装备应使用所选六阶符文")
		equipped_ids[str(slots[-1])] = true
	_check(equipped_ids.size() == game.heroes.size(), "批量符文实例不得被多名武将共用")
	_check(game._debug_light_all_imprint_trees() == game.heroes.size(), "应点亮全部武将将印树")
	for hero_id in game.heroes:
		_check(game._endless_imprint_level(str(hero_id), "soul") == 1, "每名武将的将魂层都应点亮")
	game.endless_imprint_nodes = {}

	# 敌方主轴必须是指数膨胀，频率成长则保持低且封顶。
	_check(game.EndlessRules.enemy_hp_multiplier(35) > 50.0, "第35回合敌军生命倍率应超过50倍")
	_check(game.EndlessRules.enemy_strategy(35) > 600.0, "第35回合敌军兵略应超过600")
	_check(game.EndlessRules.enemy_action_multiplier(200) <= 1.1001, "敌军行动增速必须封顶10%")
	_check(game.EndlessRules.enemy_cooldown_haste(200) <= 12.001, "敌军冷却极速必须封顶12")

	# 同一战策只能从三选一中锁定一项，锁定后其他候选立即失效。
	game.phase = "checkpoint"
	game.endless_state.candidates = ["provisions", "drill", "march"]
	game.endless_state.strategy_pending = true
	var before: Dictionary = game._make_roster_unit("player", "huanggai")
	game.player_units = [before]
	var base_hp := float(before.max_hp)
	_check(game._endless_pick_strategy("provisions"), "第一项战策应可锁定")
	_check(not game._endless_pick_strategy("drill"), "锁定后不得再选择第二项")
	_near(float(before.max_hp), base_hp + 700.0, "已有武将应获得共享固定生命成长")

	# 后续才招募与备战席武将必须读取相同共享快照。
	var later: Dictionary = game._make_roster_unit("player", "huanggai")
	_near(float(later.max_hp), float(before.max_hp), "后续招募武将应继承全军共享成长")
	later.row = -1
	game.player_units.append(later)
	game._endless_sync_player_roster()
	_near(float(later.max_hp), float(before.max_hp), "备战席武将应持续获得同一份成长")

	# 生命战策为固定值加法，不能因为重复同步而乘算膨胀。
	game._endless_sync_player_roster()
	game._endless_sync_player_roster()
	_near(float(before.max_hp), base_hp + 700.0, "共享成长重复同步必须幂等")
	game.round_number = 35
	game._endless_sync_player_roster()
	var round_35_expected: float = base_hp + 700.0 + 34.0 * float(game.EndlessRules.PLAYER_HP_PER_ROUND)
	_near(float(before.max_hp), round_35_expected, "第35回合应按固定值获得线性生命底成长")
	var round_35_recruit: Dictionary = game._make_roster_unit("player", "huanggai")
	_near(float(round_35_recruit.max_hp), round_35_expected, "第35回合新招募武将应继承完整线性成长")

	# 完整入口与据点 UI 必须能实际打开，而不只是公式单测。
	game.menu_overlay.hide()
	game._endless_start_game()
	game.tick_timer.stop()
	_check(game.game_mode == "endless" and game.round_number == 1, "主菜单入口应启动无尽第1回合")
	_check(game.enemy_units.size() == 3, "第1回合应生成一波智能敌军")
	game.round_number = 5
	game._endless_open_checkpoint()
	game._render()
	_check(game.phase == "checkpoint", "第5回合应进入据点阶段")
	_check(game.endless_state.candidates.size() == 3, "据点应生成三个不同战策候选")
	_check(game.checkpoint_overlay.visible, "据点汇总与三选一 UI 应显示")
	_check(game.checkpoint_strategy_box.get_child_count() == 3, "据点 UI 应渲染三张战策卡")
	_check(game.endless_state.armory_offers.size() == 4, "据点军府应随机给出四项不同军备")
	_check(game.checkpoint_armory_box.get_child_count() == 4, "军府页应渲染四张可购买军备卡")
	game.gold = 10000
	game.endless_state.armory_offers = ["scout_maps", "hero_legacy:huanggai"]
	_check(game._endless_buy_armory("scout_maps"), "军府应允许用金币购买选将刷新构筑")
	_check(game._tianshu_draft_refresh_limit() == 2, "游骑舆图一级应让每个候选位额外刷新一次")
	_check(game._endless_buy_armory("hero_legacy:huanggai"), "军府应允许围绕当前阵容核心武将购买传世兵符")
	var huanggai_growth: Dictionary = game._endless_shared_growth("huanggai")
	var guanyu_growth: Dictionary = game._endless_shared_growth("guanyu")
	_check(float(huanggai_growth.hp_flat) > float(guanyu_growth.hp_flat), "传世兵符应让指定武将随回合获得额外线性生命成长")
	_check(float(huanggai_growth.strategy_flat) > float(guanyu_growth.strategy_flat), "传世兵符应让指定武将随回合获得额外线性兵略成长")
	game.endless_state.armory.supply_route = 1
	game.round_number = 20
	_check(game._round_base_gold_income() == 80, "辎重商路应在第15回合后继续提供军府经济")
	var sell_probe: Dictionary = game._make_roster_unit("player", "guanyu")
	sell_probe.row = -1
	game.tianshu_levels.huozhi_milu = 1
	_check(game._unit_sell_price(sell_probe) == game.RESERVE_SELL_PRICE + 30, "货殖秘录一级卖将应额外获得30金币")
	game.tianshu_levels.huozhi_milu = 2
	_check(game._unit_sell_price(sell_probe) == game.RESERVE_SELL_PRICE + 80, "货殖秘录二级卖将应额外获得80金币")
	game.tianshu_levels.erase("huozhi_milu")

	# 战斗循环必须按真实时间推进：动画期间时钟、状态和行动条继续走；仅掉帧欠步按单帧6步偿还。
	var passive_player: Dictionary = game._make_roster_unit("player", "lvbu")
	var passive_enemy: Dictionary = game._make_roster_unit("enemy", "chengong")
	passive_player.row = 0
	passive_enemy.row = 0
	game.combat_units = [passive_player, passive_enemy]
	game.phase = "combat"
	game.battle_running = true
	game.battle_paused = false
	game.battle_speed = 1.0
	game.battle_time = 0.0
	game.battle_accum = 0.0
	game.action_in_progress = true
	game._process(8.0)
	_near(game.battle_time, 1.2, "技能动画期间也应推进6个固定模拟步")
	_near(game.battle_accum, 3.8, "超出单帧上限的掉帧欠步应留待后续偿还")
	_check(float(passive_player.action) > 0.0, "技能动画期间我方行动条仍应正常增长")
	game._process(0.0)
	_near(game.battle_time, 2.4, "后续帧应继续偿还至多6个固定步")
	_near(game.battle_accum, 2.6, "仍未偿还的时间应继续保留")

	# 貂蝉+吕布的魅惑倒戈必须是环境动画，不能饿死我方已经推进的行动条。
	var charmed_enemy: Dictionary = game._make_roster_unit("enemy", "chengong")
	var betrayal_victim: Dictionary = game._make_roster_unit("enemy", "dongzhuo")
	charmed_enemy.row = 0
	charmed_enemy.col = 0
	charmed_enemy.charm = 2.0
	charmed_enemy.charm_forced_attack = true
	charmed_enemy.charm_attack_clock = float(game.heroes.diaochan.ability_params.forced_attack_interval) - 0.1
	betrayal_victim.row = 0
	betrayal_victim.col = 1
	passive_player.action = 0.0
	game.combat_units = [passive_player, charmed_enemy, betrayal_victim]
	game.visual_events.clear()
	game._reset_ambient_visual_queue()
	game.battle_accum = 0.0
	game._battle_tick()
	_check(float(passive_player.action) > 0.0, "魅惑倒戈发生的同一模拟步仍应推进我方行动条")
	_check(game.ambient_visual_queue.any(func(event): return str(event.get("group_style", "")) == "charm_forced" and bool(event.get("nonblocking", false))), "魅惑倒戈伤害应进入非阻塞环境动画队列")
	game.battle_running = false
	game._reset_ambient_visual_queue()
	game.unit_cell_refs = {"probe":null}
	game.boards_dirty = false
	game._render_combat_boards()
	_check(game.boards_dirty, "高频棋盘刷新应只设置脏标记")
	game.boards_dirty = false
	game.log_box.clear()
	for index in 305: game.log_box.append_text("性能日志 %d\n" % index)
	game._log("裁剪触发")
	_check(game.log_box.get_line_count() <= 201, "战斗日志超过 300 行后应裁回最近约 200 行")

	if failures.is_empty():
		print("ENDLESS_REWORK_SMOKE_OK")
		_restore_progression(game)
		quit(0)
		return
	for failure in failures: push_error(failure)
	_restore_progression(game)
	quit(1)
