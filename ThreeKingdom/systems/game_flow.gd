extends "res://ThreeKingdom/systems/endless_rework_system.gd"

func _new_game() -> void:
	round_number = 1
	phase = "draft"
	if game_mode != "challenge": player_factions.clear() # 出战阵营限制仅闯关模式有效
	_reset_tianshu_run()
	_reset_economy_run()
	if game_mode == "endless": _endless_new_run()
	_roll_hell_theme()
	_roll_enemy_factions()
	player_ruler_hp = _player_ruler_max_hp()
	enemy_ruler_hp = _run_enemy_ruler_max_hp()
	ruler_regen = {"player":{"amount":0.0, "time":0.0, "clock":0.0}, "enemy":{"amount":0.0, "time":0.0, "clock":0.0}}
	player_units = []
	enemy_units = []
	pending_unit_ids = []
	chosen_this_round = []
	selected_unit = ""
	battle_running = false
	battle_paused = false
	action_in_progress = false
	final_battle = false
	battle_speed = game_speed
	battle_stats = {}
	last_battle_stats = []
	stage_replay_curve = []
	stage_replay_round_marks = []
	stage_time_offset = 0.0
	stage_stats_totals = {}
	last_battle_lineup = []
	replay_last_sample_t = -1.0
	stage_damage_player = 0.0
	stage_damage_enemy = 0.0
	ground_effects.clear()
	refresh_charges = 0
	if tick_timer: tick_timer.stop()
	if is_instance_valid(log_box): log_box.clear()
	_prepare_round()
	if game_mode == "challenge":
		_log("%s · %s：完成三轮选将后迎战守军。" % [STAGE_NAMES[selected_stage - 1], str(DIFFICULTIES[selected_difficulty].name)])
		if not player_factions.is_empty():
			var faction_names := []
			for faction in player_factions: faction_names.append(_faction_name(faction))
			_log("[color=#e5c97a]本关出战阵营限定：%s。选将与阵营天书只会出现上述阵营。[/color]" % "、".join(faction_names))
		if enemy_factions.size() > 0 and enemy_factions.size() < 4:
			var enemy_names := []
			for faction in enemy_factions: enemy_names.append(_faction_name(faction))
			_log("[color=#e8916d]本关敌军出没阵营：%s。敌方增援只会从上述阵营中刷新。[/color]" % "、".join(enemy_names))
	elif game_mode == "tianshu":
		_log("[color=#e5a8ff]天书演武开始：第 3/6/9/12/15 回合免费选天书，其他抽取可在天书阁购买。[/color]")
	elif game_mode == "endless":
		_log("[color=#f0c77a]【无尽远征·重铸】我方全军线性养成，敌方生命与兵略指数成长；每 5 回合公开敌军军势并进行一次战策三选一。[/color]")
	elif game_mode == "tutorial":
		_log("[color=#8fd4a0]新手引导：按提示完成 选天书 → 选将 → 布阵 → 战斗 一次完整流程。[/color]")
	else:
		_log(t("征战开始：每关进行三轮三选一，选项从左到右固定为前军、中军、后军。", "Campaign begins with three pick-one-of-three rounds; slots are fixed to Vanguard, Midguard, and Rearguard."))
	if game_mode == "challenge" or game_mode == "endless":
		# 闯关模式：每回合开始(选将阶段)自动保存，中途退出后可从本回合继续。
		_save_game(true)
	_render()

func _start_quick_game() -> void:
	game_mode = "quick"
	_new_game()

func _start_tianshu_game() -> void:
	game_mode = "tianshu"
	_new_game()

func _start_tutorial_game() -> void:
	# 新手引导演练：完整流程 + 两名敌军的低压力对局。
	game_mode = "tutorial"
	tutorial_active = true
	tutorial_page_index = 0
	_new_game()
	# 演练敌军精简为两名：让新手把注意力放在流程而不是胜负上。
	var deployed: Array = enemy_units.filter(func(unit): return unit.alive and int(unit.row) >= 0)
	for index in range(2, deployed.size()):
		enemy_units.erase(deployed[index])
	_log("[color=#8fd4a0]【引导】演练敌军仅有两名武将，放手体验完整流程。[/color]")
	_render()

func _challenge_faction_pick_count(difficulty: int) -> int:
	# 闯关开局需选择的出战阵营数:简单1/一般2/困难3;王者/地狱全阵营上阵(0=不选择)。
	if difficulty == 0: return 1
	if difficulty == 1: return 2
	if difficulty == 2: return 3
	return 0

func _start_challenge(stage: int, difficulty: int, factions: Array = []) -> bool:
	if not _is_stage_unlocked(stage, difficulty): return false
	game_mode = "challenge"
	selected_stage = clampi(stage, 1, 20)
	selected_difficulty = clampi(difficulty, 0, DIFFICULTIES.size() - 1)
	# 本关我方出战阵营:王者/地狱不限制;其余难度取前 N 个合法所选阵营。
	player_factions.clear()
	var need := _challenge_faction_pick_count(selected_difficulty)
	for faction in factions:
		var fid := str(faction)
		if fid in ["shu", "wei", "wu", "qun"] and not player_factions.has(fid):
			player_factions.append(fid)
	while player_factions.size() > need:
		player_factions.pop_back()
	_new_game()
	return true

func _save_game(silent := false) -> bool:
	if battle_running:
		if not silent: _log(t("战斗过程中不能保存，请在选人或布阵阶段保存。", "Save during draft or formation, not combat."))
		return false
	var data := {
		"version":EndlessRules.SAVE_VERSION if _run_is_endless() else 7, "round_number":round_number, "phase":phase, "game_mode":game_mode,
		"selected_stage":selected_stage, "selected_difficulty":selected_difficulty,
		"hell_faction":hell_faction, "hell_theme_name":hell_theme_name,
		"player_factions":player_factions, "enemy_factions":enemy_factions,
		"player_ruler_hp":player_ruler_hp, "enemy_ruler_hp":enemy_ruler_hp,
		"player_units":player_units, "enemy_units":enemy_units,
		"draft_roster_baseline":draft_roster_baseline,
		"choices":choices, "pending_unit_ids":pending_unit_ids,
		"chosen_this_round":chosen_this_round, "draft_picks_remaining":draft_picks_remaining,
		"draft_refresh_available":draft_refresh_available,
		"refresh_charges":refresh_charges,
		"selected_unit":selected_unit, "final_battle":final_battle,
		"ruler_regen":ruler_regen,
		"last_battle_stats":last_battle_stats,
		"tianshu":_tianshu_save_state(),
		"economy":_economy_save_state()
	}
	if _run_is_endless(): data.endless = _endless_save_state()
	var file := FileAccess.open(_run_save_path(), FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data))
	file.close()
	if is_instance_valid(continue_button): continue_button.disabled = false
	if not silent: _log(t("游戏进度已保存。", "Game saved."))
	_render()
	return true

func _load_game(from_path := "") -> bool:
	var target_path := str(from_path) if not str(from_path).is_empty() else _run_save_path()
	if battle_running or not FileAccess.file_exists(target_path): return false
	var file := FileAccess.open(target_path, FileAccess.READ)
	if file == null: return false
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) not in [3, 4, 5, 6, 7, EndlessRules.SAVE_VERSION]:
		_log(t("存档版本不兼容。", "The save version is incompatible."))
		return false
	tick_timer.stop()
	# 读档后回放曲线与整关累计统计从当前回合重新开始记录(存档不保存回放数据)。
	stage_replay_curve = []
	stage_replay_round_marks = []
	stage_time_offset = 0.0
	stage_stats_totals = {}
	last_battle_lineup = []
	replay_last_sample_t = -1.0
	stage_damage_player = 0.0
	stage_damage_enemy = 0.0
	game_mode = str(data.get("game_mode", "quick"))
	tutorial_active = game_mode == "tutorial"
	selected_stage = clampi(int(data.get("selected_stage", selected_stage)), 1, STAGE_NAMES.size())
	selected_difficulty = clampi(int(data.get("selected_difficulty", selected_difficulty)), 0, DIFFICULTIES.size() - 1)
	hell_faction = str(data.get("hell_faction", ""))
	hell_theme_name = str(data.get("hell_theme_name", ""))
	if hell_faction not in ["shu", "wei", "wu", "qun"]: hell_faction = ""
	# 本关出战阵营:仅闯关存档携带;王者/地狱无限制,旧存档无此字段则不限制。
	player_factions.clear()
	if game_mode == "challenge" and _challenge_faction_pick_count(selected_difficulty) > 0:
		for faction in data.get("player_factions", []):
			var fid := str(faction)
			if fid in ["shu", "wei", "wu", "qun"] and not player_factions.has(fid):
				player_factions.append(fid)
	if game_mode == "challenge" and selected_difficulty >= 4 and hell_faction.is_empty():
		_roll_hell_theme() # 旧存档没有阵营字段:读档时补随机一次
	# 敌方出没阵营:仅简单/一般/困难存档携带;旧存档无此字段则补随机一次。
	enemy_factions.clear()
	if game_mode == "challenge" and selected_difficulty < 3:
		for faction in data.get("enemy_factions", []):
			var enemy_fid := str(faction)
			if enemy_fid in ["shu", "wei", "wu", "qun"] and not enemy_factions.has(enemy_fid):
				enemy_factions.append(enemy_fid)
		if enemy_factions.is_empty():
			_roll_enemy_factions()
	round_number = int(data.round_number)
	phase = str(data.phase)
	player_ruler_hp = int(data.player_ruler_hp)
	enemy_ruler_hp = int(data.enemy_ruler_hp)
	if game_mode == "endless": _load_endless_state(data.get("endless", {}))
	player_units = _sanitize_loaded_units(data.player_units, "player")
	enemy_units = _sanitize_loaded_units(data.enemy_units, "enemy")
	draft_roster_baseline = _sanitize_loaded_units(data.get("draft_roster_baseline", player_units.duplicate(true)), "player")
	choices = Array(data.choices).filter(func(hero_id): return heroes.has(str(hero_id)))
	pending_unit_ids.clear()
	for id in data.pending_unit_ids: pending_unit_ids.append(str(id))
	chosen_this_round.clear()
	for id in data.chosen_this_round: chosen_this_round.append(str(id))
	draft_picks_remaining = int(data.draft_picks_remaining)
	draft_refresh_available = [true, true, true]
	var loaded_refresh_state: Array = data.get("draft_refresh_available", [true, true, true])
	for index in mini(DRAFT_SIZE, loaded_refresh_state.size()):
		draft_refresh_available[index] = bool(loaded_refresh_state[index])
	refresh_charges = int(data.get("refresh_charges", 0))
	var loaded_reserves := _reserve_units()
	while loaded_reserves.size() > _run_reserve_limit():
		player_units.erase(loaded_reserves.pop_back())
		refresh_charges += 1
	selected_unit = str(data.selected_unit)
	final_battle = bool(data.get("final_battle", false))
	ruler_regen = data.get("ruler_regen", {"player":{"amount":0.0, "time":0.0, "clock":0.0}, "enemy":{"amount":0.0, "time":0.0, "clock":0.0}})
	last_battle_stats = data.get("last_battle_stats", [])
	_load_tianshu_state(data.get("tianshu", {}))
	_load_economy_state(data.get("economy", {}))
	if game_mode == "endless": _endless_sync_player_roster()
	if int(data.get("version", 0)) < 6:
		for index in mini(DRAFT_SIZE, draft_refresh_available.size()):
			tianshu_draft_refresh_used[index] = 0 if draft_refresh_available[index] else 1
	battle_running = false
	battle_paused = false
	action_in_progress = false
	combat_units = []
	visual_events.clear()
	ground_effects.clear()
	if phase == "tianshu" and tianshu_choices.size() != 3:
		_generate_tianshu_choices()
	elif phase == "draft" and choices.size() != DRAFT_SIZE:
		_generate_choices()
	_log(t("存档已读取。", "Save loaded."))
	_render()
	return true

func _sanitize_loaded_units(value, expected_team: String) -> Array:
	var result: Array = []
	if not value is Array: return result
	for raw_unit in value:
		if not raw_unit is Dictionary: continue
		var hero_id := str(raw_unit.get("hero_id", ""))
		if not heroes.has(hero_id): continue
		var unit: Dictionary = raw_unit.duplicate(true)
		unit.team = expected_team
		unit.level = 1
		unit.stat_mult = 1.0
		_ensure_unit_fields(unit)
		result.append(unit)
	return result

func _challenge_run_snapshot() -> Dictionary:
	# 读取存档中"进行中"的闯关对局(未结束的挑战模式),供关卡界面定位与续战。
	if not FileAccess.file_exists(SAVE_PATH): return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null: return {}
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY: return {}
	if str(data.get("game_mode", "")) != "challenge": return {}
	if str(data.get("phase", "")) == "finished": return {}
	return {
		"stage": clampi(int(data.get("selected_stage", 1)), 1, STAGE_NAMES.size()),
		"difficulty": clampi(int(data.get("selected_difficulty", 0)), 0, DIFFICULTIES.size() - 1),
		"round": clampi(int(data.get("round_number", 1)), 1, ROUND_LIMIT)
	}

func _clear_run_save() -> void:
	# 闯关结算后清除本局自动存档,关卡界面不再把该关当成"进行中";非本局存档不动。
	var snapshot := _challenge_run_snapshot()
	if snapshot.is_empty(): return
	if int(snapshot.stage) != selected_stage or int(snapshot.difficulty) != selected_difficulty: return
	var dir := DirAccess.open("user://")
	if dir != null and FileAccess.file_exists(SAVE_PATH):
		dir.remove(SAVE_PATH.get_file())
	if is_instance_valid(continue_button): continue_button.disabled = true

func _prepare_round() -> void:
	phase = "draft"
	draft_user_hidden = false
	draft_picks_remaining = _run_draft_pick_count()
	pending_unit_ids = []
	chosen_this_round = []
	draft_roster_baseline = player_units.duplicate(true)
	selected_unit = ""
	_settle_round_economy()
	if game_mode == "endless": _endless_prepare_round()
	_add_enemy_wave()    # 每回合敌方增援:普通随机3人;王者前两关4人、其余羁绊三人组;地狱前两轮5人、其余本局随机阵营3人;满员不挤人、阵亡后补位
	_grant_faction_talent_recruits()  # 第4层阵营天赋:前N回合每回合开始时随机获得1名本阵营武将入备战席
	if _tianshu_enabled() and _is_free_tianshu_round():
		_begin_tianshu_draw(1, "free", "draft", true)
	else:
		_generate_choices()

func _grant_faction_talent_recruits() -> void:
	# 第 4 层阵营天赋(汉室坚壁/中枢令典/三世基业/烽火燎原)：
	# 等级为几，对局前几回合每回合开始时各随机获得 1 名本阵营武将，直接加入备战席(row=-1)。
	var talent_names := {"shu":"汉室坚壁", "wei":"中枢令典", "wu":"三世基业", "qun":"烽火燎原"}
	for faction in ["shu", "wei", "wu", "qun"]:
		# 出战阵营限定:未选该阵营时,该阵营天赋不发放备战武将。
		if not player_factions.is_empty() and not player_factions.has(faction): continue
		if round_number > _talent_faction_recruit_rounds(faction): continue
		var pool: Array = heroes.keys().filter(func(id): return str(heroes[id].f) == faction)
		if pool.is_empty(): continue
		pool.shuffle()
		var hero_id := str(pool[0])
		player_units.append(_make_roster_unit("player", hero_id))
		_log("[color=#e5c97a]【天赋·%s】%s 加入备战席。[/color]" % [talent_names[faction], _hero_name(hero_id)])

func _generate_choices() -> void:
	choices = []
	var pool_factions := _active_tianshu_pool_factions()
	for range_tier in [1, 2, 3]:
		var pool := _draft_pool_for_range(range_tier, draft_faction_filter)
		if pool_factions.size() == 2 and int(tianshu_pool_effect.get("level", 0)) >= 2:
			var preferred_faction := str(pool_factions[(range_tier - 1 + round_number) % 2])
			var preferred: Array = pool.filter(func(hero_id): return str(heroes[hero_id].f) == preferred_faction)
			if not preferred.is_empty(): pool = preferred
		pool.shuffle()
		if not pool.is_empty(): choices.append(pool[0])
	draft_refresh_available = [true, true, true]
	tianshu_draft_refresh_used = [0, 0, 0]

func _draft_pool_for_range(range_tier: int, faction_filter: String) -> Array:
	var pool_factions := _active_tianshu_pool_factions()
	return heroes.keys().filter(func(hero_id):
		var faction := str(heroes[hero_id].f)
		# 出战阵营限定:限定时仅所选阵营武将可进入候选/刷新池。
		if not player_factions.is_empty() and not player_factions.has(faction): return false
		return int(heroes[hero_id].range) == range_tier and (pool_factions.has(faction) if not pool_factions.is_empty() else (faction_filter.is_empty() or faction == faction_filter))
	)

func _refresh_draft_choice(choice_index: int) -> void:
	if phase != "draft" or battle_running or choice_index < 0 or choice_index >= choices.size():
		return
	if not _tianshu_can_refresh_draft(choice_index):
		return
	var old_id := str(choices[choice_index])
	var required_range := choice_index + 1
	var pool := _draft_pool_for_range(required_range, draft_faction_filter)
	pool = pool.filter(func(hero_id): return str(hero_id) != old_id)
	if pool.is_empty():
		return
	pool.shuffle()
	choices[choice_index] = pool[0]
	tianshu_draft_refresh_used[choice_index] += 1
	draft_refresh_available[choice_index] = _tianshu_can_refresh_draft(choice_index)
	_log(t("已单独刷新 ", "Refreshed ") + _hero_name(old_id) + t(" 的候选位。", " candidate slot."))
	_render()

func _refresh_shop(choice_index := 0) -> void:
	_refresh_draft_choice(int(choice_index))

# 敌方增援三人组:组内武将互相存在真实羁绊(双人/三人/四人/五人羁绊皆有,逐步凑齐即触发)
const ENEMY_SQUADS := [
	{"faction": "shu", "name": "桃园结义", "heroes": ["liubei", "guanyu", "zhangfei"]},
	{"faction": "shu", "name": "五虎·前锋", "heroes": ["guanyu", "zhangfei", "zhaoyun"]},
	{"faction": "shu", "name": "五虎·骠骑", "heroes": ["zhaoyun", "huangzhong", "machao"]},
	{"faction": "shu", "name": "西凉铁骑", "heroes": ["machao", "madai", "weiyan"]},
	{"faction": "shu", "name": "飞火流星", "heroes": ["weiyan", "huangzhong", "madai"]},
	{"faction": "wei", "name": "魏武亲卫", "heroes": ["caocao", "dianwei", "xuchu"]},
	{"faction": "wei", "name": "魏谋三杰", "heroes": ["xunyu", "guojia", "jiaxu"]},
	{"faction": "wei", "name": "夏侯宗族", "heroes": ["xiahouyuan", "xiahoudun", "caoren"]},
	{"faction": "wei", "name": "五子·先锋", "heroes": ["zhangliao", "yuejin", "zhanghe"]},
	{"faction": "wei", "name": "五子·后军", "heroes": ["zhanghe", "xuhuang", "yujin"]},
	{"faction": "wu", "name": "江东都督", "heroes": ["zhouyu", "huanggai", "xiaoqiao"]},
	{"faction": "wu", "name": "锦帆虎臣", "heroes": ["taishici", "ganning", "lvmeng"]},
	{"faction": "wu", "name": "孙氏之志", "heroes": ["sunjian", "sunce", "sunquan"]},
	{"faction": "wu", "name": "江东双璧", "heroes": ["sunce", "taishici", "daqiao"]},
	{"faction": "wu", "name": "社稷之臣", "heroes": ["luxun", "sunquan", "lusu"]},
	{"faction": "wu", "name": "四英杰", "heroes": ["zhouyu", "luxun", "lvmeng"]},
	{"faction": "qun", "name": "飞将亲随", "heroes": ["lvbu", "chengong", "gaoshun"]},
	{"faction": "qun", "name": "河北庭柱", "heroes": ["yanliang", "wenchou", "qunzhanghe"]},
	{"faction": "qun", "name": "庭柱后援", "heroes": ["qunzhanghe", "gaolan", "wenchou"]},
	{"faction": "qun", "name": "暴君倾城", "heroes": ["dongzhuo", "diaochan", "lvbu"]}
]

func _endless_enemy_wave(count: int) -> Array:
	# 敌军不是纯随机抽卡：优先补齐已有组合羁绊，其次补阵营和行位，但保留少量扰动。
	var fielded := {}
	var factions := {}
	var row_counts := [0, 0, 0]
	for unit in enemy_units:
		if not unit.alive or int(unit.row) < 0: continue
		fielded[str(unit.hero_id)] = true
		factions[str(heroes[unit.hero_id].f)] = true
		row_counts[int(unit.row)] += 1
	var result: Array = []
	for pick_index in count:
		var best_id := ""
		var best_score := -99999.0
		for raw_id in heroes.keys():
			var hero_id := str(raw_id)
			if fielded.has(hero_id) or result.has(hero_id): continue
			var hero: Dictionary = heroes[hero_id]
			var score := rng.randf_range(0.0, 8.0)
			for squad in ENEMY_SQUADS:
				var members: Array = squad.heroes
				if not members.has(hero_id): continue
				var present := 0
				for member in members:
					if fielded.has(str(member)) or result.has(str(member)): present += 1
				score += present * 18.0
				if present == members.size() - 1: score += 30.0
			if not factions.has(str(hero.f)): score += 8.0
			var legal_rows := [0] if int(hero.range) == 1 and not bool(hero.get("all_rows", false)) else [0, 1, 2]
			var emptiest := 99
			for row in legal_rows: emptiest = mini(emptiest, row_counts[row])
			score += maxf(0.0, 12.0 - emptiest * 4.0)
			if score > best_score:
				best_score = score
				best_id = hero_id
		if best_id.is_empty(): break
		result.append(best_id)
	return result

# 地狱难度:开局随机锁定一个阵营(每局不同),整局只刷该阵营的武将;此处仅作主题名库
const HELL_THEMES := [
	{"faction": "shu", "name": "蜀·王道之师"},
	{"faction": "shu", "name": "蜀·北伐雄师"},
	{"faction": "wei", "name": "魏·虎豹精锐"},
	{"faction": "wei", "name": "魏·宗室名将"},
	{"faction": "wu", "name": "吴·江东英才"},
	{"faction": "wu", "name": "吴·虎臣水军"},
	{"faction": "qun", "name": "群·飞将无双"},
	{"faction": "qun", "name": "群·乱世枭雄"}
]

func _roll_hell_theme() -> void:
	# 地狱难度:开局随机锁定一个敌方阵营,整局只刷该阵营武将;非地狱对局清空。
	hell_faction = ""
	hell_theme_name = ""
	if game_mode != "challenge" or selected_difficulty < 4: return
	var factions := ["shu", "wei", "wu", "qun"]
	hell_faction = str(factions[rng.randi_range(0, factions.size() - 1)])
	var themes: Array = HELL_THEMES.filter(func(theme): return str(theme.faction) == hell_faction)
	hell_theme_name = str(themes[rng.randi_range(0, themes.size() - 1)].name) if not themes.is_empty() else "地狱·全面压制"

func _roll_enemy_factions() -> void:
	# 简单/一般/困难:开局随机锁定敌方出没阵营,简单2个/一般3个/困难4个(全阵营)。
	# 王者走羁绊三人组、地狱另有整局阵营锁,均不在此时限制;非闯关对局清空。
	enemy_factions.clear()
	if game_mode != "challenge" or selected_difficulty >= 3: return
	var factions := ["shu", "wei", "wu", "qun"]
	factions.shuffle()
	for index in range(2 + selected_difficulty):
		enemy_factions.append(str(factions[index]))

func _add_enemy_wave() -> void:
	# 通用规则:每回合增援一批敌将;场上15格满员(全为存活敌将)时不增援,阵亡空位后继续补充。
	# 波次人数:默认3;王者第1~2关4人;地狱第1~2轮5人(压制玩家阵营天赋的开局爆兵),之后恢复3。
	# 阵亡武将可以同名重新生成(是全新单位,不是复活);不再把场上武将挤下场。
	var alive_deployed := 0
	for unit in enemy_units:
		if unit.alive and int(unit.row) >= 0: alive_deployed += 1
	var wave_size := 3
	if game_mode == "challenge" and selected_difficulty == 3 and round_number <= 2:
		wave_size = 4    # 王者:前两关每波4人
	elif game_mode == "challenge" and selected_difficulty >= 4 and round_number <= 2:
		wave_size = 5    # 地狱:前两轮每波5人,之后恢复3
	var wave_limit := mini(wave_size, BOARD_ROWS * BOARD_COLUMNS - alive_deployed)
	if wave_limit <= 0:
		_log(t("第 %d 关敌军阵容满员，暂无增援。" % round_number, "Stage %d: the enemy lineup is full. No reinforcements." % round_number))
		return
	var wave: Array = []
	var wave_title := ""
	if game_mode == "challenge" and selected_difficulty == 3:
		# 王者:全阵营随机,每回合上阵一套互相有羁绊的三人组;人数不足时从其他随机小队补齐
		var king_squad: Dictionary = ENEMY_SQUADS[rng.randi_range(0, ENEMY_SQUADS.size() - 1)]
		wave = (king_squad.heroes as Array).duplicate()
		wave_title = str(king_squad.name)
		var guard := 0
		while wave.size() < wave_limit and guard < 8:
			guard += 1
			var extra_squad: Dictionary = ENEMY_SQUADS[rng.randi_range(0, ENEMY_SQUADS.size() - 1)]
			for raw_hero_id in extra_squad.heroes:
				if wave.size() >= wave_limit: break
				if not wave.has(str(raw_hero_id)): wave.append(str(raw_hero_id))
	elif game_mode == "challenge" and selected_difficulty >= 4:
		# 地狱:本局随机阵营,每波从该阵营随机挑人(优先没上过场的),
		# 并按各排空位轮转目标行,保证前/中/后排都能补到人。
		wave_title = hell_theme_name if not hell_theme_name.is_empty() else "地狱·全面压制"
		wave = _hell_wave_picks(wave_limit)
	elif game_mode == "endless":
		wave_title = "无尽军团·智能增援"
		wave = _endless_enemy_wave(wave_limit)
	else:
		# 简单/一般/困难/其它模式:随机3名(可重复出现同名新单位)
		# 简单/一般/困难时先按本局随机锁定的敌方出没阵营过滤,再叠加手动设置的阵营过滤。
		var random_pool: Array = heroes.keys().filter(func(hero_id):
			var faction := str(heroes[hero_id].f)
			if not enemy_factions.is_empty() and not enemy_factions.has(faction): return false
			return enemy_faction_filter.is_empty() or faction == enemy_faction_filter
		)
		if random_pool.is_empty():
			# 手动阵营过滤与出没阵营无交集时,退回仅按出没阵营刷新,保证增援不缺员。
			random_pool = heroes.keys().filter(func(hero_id): return enemy_factions.is_empty() or enemy_factions.has(str(heroes[hero_id].f)))
		random_pool.shuffle()
		wave = random_pool.slice(0, wave_limit)
	var wave_names: Array[String] = []
	var misses := 0
	for entry in wave.slice(0, wave_limit):
		var hero_id := str(entry) if entry is String else str(entry.get("id", ""))
		var target_row := -1 if entry is String else int(entry.get("row", -1))
		if _spawn_enemy_unit(hero_id, target_row):
			wave_names.append(_hero_name(hero_id))
		else:
			misses += 1
	if misses > 0 and game_mode == "challenge" and selected_difficulty >= 3:
		# 王者/地狱：落位失败的名额从池中随机换人补上，保证波次人数真正上场(地狱仍限本局阵营)。
		var fallback_pool: Array = heroes.keys()
		if selected_difficulty >= 4:
			fallback_pool = fallback_pool.filter(func(id): return str(heroes[id].f) == hell_faction)
		fallback_pool.shuffle()
		for raw_id in fallback_pool:
			if misses <= 0: break
			var fallback_id := str(raw_id)
			if _spawn_enemy_unit(fallback_id):
				wave_names.append(_hero_name(fallback_id))
				misses -= 1
	if wave_names.is_empty():
		_log(t("第 %d 关敌军暂无有效增援。" % round_number, "Stage %d: no valid enemy reinforcements." % round_number))
		return
	if wave_title.is_empty():
		_log(t("第 %d 关敌军随机选择：" % round_number, "Stage %d enemy random picks: " % round_number) + "、".join(wave_names))
	else:
		_log("[color=#e8916d]" + t("【%s】第 %d 回合敌方增援：" % [wave_title, round_number], "[%s] Round %d enemy reinforcements: " % [wave_title, round_number]) + "、".join(wave_names) + "[/color]")

func _spawn_enemy_unit(hero_id: String, preferred_row := -1) -> bool:
	# 生成一名敌将并自动布阵;没有可用空位时直接放弃生成,不挤占场上现有武将。
	# preferred_row 是地狱增援的"目标行"偏好:只调整落位尝试顺序,不突破射程限制。
	if not heroes.has(hero_id): return false
	var hero: Dictionary = heroes[hero_id]
	var rows := [0, 1, 2] if bool(hero.get("all_rows", false)) else ([0] if int(hero.range) == 1 else ([0, 1, 2] if hero.range <= 2 else [2, 1, 0]))
	if preferred_row >= 0 and rows.has(preferred_row):
		rows.erase(preferred_row)
		rows.push_front(preferred_row)
	for row in rows:
		for col in BOARD_COLUMNS:
			if _unit_at(enemy_units, row, col) != null: continue
			var unit := _make_roster_unit("enemy", hero_id)
			unit.row = row
			unit.col = col
			enemy_units.append(unit)
			return true
	return false

func _hell_wave_picks(count: int) -> Array:
	# 地狱增援:本局阵营内随机个人。优先选"没上过场的"(排除场上存活同名与本波已选);
	# 每人按各排空位轮转一个目标行(后排需求只挑射程2/3,前排任何射程都能站)。
	var faction_pool: Array = heroes.keys().filter(func(id): return str(heroes[id].f) == hell_faction)
	if faction_pool.is_empty(): return []
	var picks: Array = []
	var picked := {}
	for index in count:
		var target_row := _hell_target_row(index)
		var fresh: Array = faction_pool.filter(func(id): return not picked.has(id) and not _enemy_fielded_alive(str(id)))
		var row_fit: Array = fresh.filter(func(id): return _hero_can_stand_row(str(id), target_row))
		var candidates := row_fit if not row_fit.is_empty() else fresh
		if candidates.is_empty(): break
		candidates.shuffle()
		var chosen := str(candidates[0])
		picked[chosen] = true
		picks.append({"id":chosen, "row":target_row})
	return picks

func _enemy_fielded_alive(hero_id: String) -> bool:
	for unit in enemy_units:
		if unit.alive and int(unit.row) >= 0 and str(unit.hero_id) == hero_id: return true
	return false

func _hero_can_stand_row(hero_id: String, row: int) -> bool:
	# 射程1(前军)只能站前排;射程2/3与 all_rows 武将任意排可站。
	if not heroes.has(hero_id): return false
	var hero: Dictionary = heroes[hero_id]
	if bool(hero.get("all_rows", false)): return true
	return row == 0 if int(hero.range) == 1 else true

func _hell_target_row(seed_index: int) -> int:
	# 目标行=当前空位最多的排;多排并列空位时按 seed_index 轮转,让一波内在前/中/后均衡铺开。
	var free := []
	for row in BOARD_ROWS:
		var used := 0
		for unit in enemy_units:
			if unit.alive and int(unit.row) == row: used += 1
		free.append(maxi(0, BOARD_COLUMNS - used))
	var best_free: int = free.max()
	if best_free <= 0: return 2
	var rows: Array = []
	for row in BOARD_ROWS:
		if free[row] == best_free: rows.append(row)
	return int(rows[seed_index % rows.size()])

func _choose_hero(id: String) -> void:
	if battle_running or phase != "draft" or not choices.has(id): return
	if not _can_accept_hero(id):
		_play_sfx("error", -6.0, 150, 0.0)
		_log(t("场上和备战区均已满。", "The field and reserve are both full."))
		return
	var unit := _make_roster_unit("player", id)
	player_units.append(unit)
	chosen_this_round.append(id)
	draft_picks_remaining -= 1
	_tianshu_consume_pool_pick()
	var pick_total := _run_draft_pick_count()
	var locked_count := pick_total - draft_picks_remaining
	_log(t("第%d/%d轮锁定：" % [locked_count, pick_total], "Pick %d/%d locked: " % [locked_count, pick_total]) + _hero_name(id))
	_play_hero_voice(id, true) # 选将锁定：武将喊话
	if draft_picks_remaining <= 0:
		phase = "placement"
		draft_user_hidden = true
	else:
		_generate_choices()
		draft_user_hidden = false
	_render()

func _can_accept_hero(hero_id: String) -> bool:
	return _reserve_units().size() < _run_reserve_limit()

func _try_upgrade(roster: Array, hero_id: String):
	# Compatibility shim for old callers/saves. Duplicate heroes remain separate.
	return null

func _auto_place_player() -> void:
	if phase != "placement": return
	if pending_unit_ids.is_empty():
		for reserve in _reserve_units(): pending_unit_ids.append(reserve.id)
	if pending_unit_ids.is_empty(): return
	while not pending_unit_ids.is_empty():
		var unit: Variant = _find_by_id(player_units, pending_unit_ids[0])
		if unit == null:
			pending_unit_ids.pop_front()
			continue
		var hero: Dictionary = heroes[unit.hero_id]
		var rows := [0, 1, 2] if bool(hero.get("all_rows", false)) else ([0] if int(hero.range) == 1 else ([0, 1, 2] if hero.range <= 2 else [2, 1, 0]))
		var placed := false
		for row in rows:
			for col in BOARD_COLUMNS:
				if _unit_at(player_units, row, col) == null:
					unit.row = row
					unit.col = col
					placed = true
					break
			if placed: break
		if not placed:
			unit.row = -1
			unit.col = -1
			_log(_hero_name(unit.hero_id) + t(" 已进入备战区。", " moved to the reserve."))
			pending_unit_ids.pop_front()
			if placed:
				_log(_hero_name(unit.hero_id) + t(" 已自动布阵。", " was placed automatically."))
				_play_sfx("deploy", -10.0, 100, 0.08) # 自动布阵与手动上阵同款拔刀音，台词只在第一位喊，避免连播
				if not is_instance_valid(skill_voice_player) or not skill_voice_player.playing:
					_play_hero_voice(str(unit.hero_id))
		_render()

func _on_player_cell(row: int, col: int) -> void:
	if phase not in ["draft", "placement"] or battle_running: return
	var occupant: Variant = _unit_at(player_units, row, col)
	if not pending_unit_ids.is_empty():
		if occupant != null: return
		var pending: Variant = _find_by_id(player_units, pending_unit_ids[0])
		if pending:
			if not _can_unit_use_row(pending, row):
				_log(t("射程1的近战武将只能部署在前排。", "Range-1 melee generals can only deploy in the front row."))
				return
			pending.row = row
			pending.col = col
			pending_unit_ids.pop_front()
			_log(_hero_name(pending.hero_id) + t(" 已上阵。", " deployed."))
			_play_sfx("deploy", -10.0, 100, 0.08)
			if not is_instance_valid(skill_voice_player) or not skill_voice_player.playing:
				_play_hero_voice(str(pending.hero_id))
	elif occupant != null:
		var selected: Variant = _find_by_id(player_units, selected_unit)
		if selected != null and selected.row < 0:
			_log(t("该战位已有武将；可将备战武将拖到此处互换。", "That tile is occupied; drag the reserve general here to swap."))
		else:
			selected_unit = occupant.id
	else:
		var selected: Variant = _find_by_id(player_units, selected_unit)
		if selected:
			if not _can_unit_use_row(selected, row): return
			var first_deploy := int(selected.row) < 0
			selected.row = row
			selected.col = col
			_log(_hero_name(selected.hero_id) + (t(" 已上阵。", " deployed.") if first_deploy else t(" 已调整站位。", " repositioned.")))
			if first_deploy:
				# 备战武将点选上阵：与拖拽上阵同款拔刀音 + 台词；场上换位保持安静。
				_play_sfx("deploy", -10.0, 100, 0.08)
				_play_hero_voice(str(selected.hero_id), true)
		selected_unit = ""
	_render()

func _can_start_battle() -> bool:
	return phase == "placement" and pending_unit_ids.is_empty() and player_units.any(func(unit): return unit.alive and unit.row >= 0) and enemy_units.any(func(unit): return unit.alive and unit.row >= 0)

func _start_battle() -> void:
	if not _can_start_battle(): return
	phase = "combat"
	battle_running = true
	battle_paused = false
	battle_time = 0.0
	battle_accum = 0.0
	boards_dirty = false
	action_in_progress = false
	battle_speed = game_speed
	selected_unit = ""
	combat_units = []
	ground_effects.clear()
	_reset_faction_battle_state()
	for team_units in [player_units, enemy_units]:
		for unit in team_units:
			if not unit.alive or unit.row < 0: continue
			_ensure_unit_fields(unit)
			unit.level = 1
			unit.stat_mult = 1.0
			unit.team = "player" if team_units == player_units else "enemy"
			if not unit.has("action"): unit.action = 0.0
			unit.action_gain_mult = 1.0
			unit.heal_multiplier = 1.0
			unit.charm_multiplier = 1.0
			unit.kill_buff = 0.0
			unit.current_hp_ratio = 0.06
			combat_units.append(unit)
	battle_stats = {}
	for unit in combat_units:
		battle_stats[unit.id] = {"unit_id":unit.id, "hero_id":unit.hero_id, "team":unit.team, "level":int(unit.get("level", 1)), "damage":0.0, "healing":0.0, "taken":0.0, "control":0.0, "shield":0.0, "buff":0.0}
	_apply_combo_bonds()
	_apply_tianshu_battle_start()
	_apply_faction_bonuses()
	_apply_opening_skills()
	_endless_on_battle_start()
	_log("[color=#f6c860]" + t("第 ", "Round ") + str(round_number) + t(" 回合战斗开始（30 秒）！", " battle begins (30 seconds)!") + "[/color]")
	tick_timer.start()
	_render()

func _finish_battle() -> void:
	if not battle_running and phase != "combat": return
	if has_method("_hide_unit_inspector"):
		call("_hide_unit_inspector")
	tick_timer.stop()
	battle_running = false
	battle_accum = 0.0
	battle_paused = false
	action_in_progress = false
	_capture_battle_stats()
	_push_final_replay_sample()
	_accumulate_stage_stats()
	_snapshot_battle_lineup()
	_tianshu_on_round_end()
	var result: String
	if player_ruler_hp == enemy_ruler_hp: result = t("本关战斗结束，平局。", "Stage complete — draw.")
	elif player_ruler_hp > enemy_ruler_hp: result = t("本关战斗胜利！", "Stage won!")
	else: result = t("本关战斗失利。", "Stage lost.")
	_log("[color=#f6c860]" + result + "[/color]")
	var decisive := player_ruler_hp <= 0 or enemy_ruler_hp <= 0
	var player_won := enemy_ruler_hp <= 0 and player_ruler_hp > 0
	if game_mode == "endless":
		var endless_outcome := _endless_finish_battle()
		if endless_outcome == "advance":
			round_number += 1
			_prepare_round()
			_save_game(true)
		elif endless_outcome == "checkpoint":
			_save_game(true)
	elif game_mode == "challenge":
		if decisive or round_number >= ROUND_LIMIT:
			phase = "finished"
			var challenge_result := _complete_challenge(player_won if decisive else player_ruler_hp > enemy_ruler_hp)
			_clear_run_save()
			if has_method("_show_battle_result"):
				call_deferred("_show_battle_result", challenge_result)
		if not decisive and round_number < ROUND_LIMIT:
			round_number += 1
			_prepare_round()
			_save_game(true)
			_log("进入闯关第 %d / 15 回合：主公生命与现有阵容继续保留。" % round_number)
	elif game_mode == "tianshu":
		if decisive or round_number >= ROUND_LIMIT:
			phase = "finished"
			if has_method("_show_battle_result"):
				call_deferred("_show_battle_result", {"victory":player_won if decisive else player_ruler_hp >= enemy_ruler_hp, "stage":round_number, "difficulty":-1, "stars":0, "new_stars":0, "souls":0})
		if not decisive and round_number < ROUND_LIMIT:
			round_number += 1
			_prepare_round()
			_save_game(true)
			_log("进入天书演武第 %d / 15 回合。" % round_number)
	elif game_mode == "tutorial":
		# 新手引导只打一场演练：无论胜负都算完成引导，清单消失并弹出奖励结算。
		phase = "finished"
		tutorial_active = false
		if has_method("_show_battle_result"):
			call_deferred("_show_battle_result", {"victory":player_won if decisive else player_ruler_hp >= enemy_ruler_hp, "stage":1, "difficulty":-1, "stars":0, "new_stars":0, "souls":0})
		if has_method("_tutorial_on_complete"):
			call_deferred("_tutorial_on_complete")
	elif decisive:
		phase = "finished"
		if has_method("_show_battle_result"):
			call_deferred("_show_battle_result", {"victory":player_won, "stage":round_number, "difficulty":-1, "stars":0, "new_stars":0, "souls":0})
	elif final_battle:
		phase = "finished"
		_log(t("最终决战胜利，天下归一！", "Final victory. The realm is united!"))
		if has_method("_show_battle_result"):
			call_deferred("_show_battle_result", {"victory":player_ruler_hp >= enemy_ruler_hp, "stage":round_number, "difficulty":-1, "stars":0, "new_stars":0, "souls":0})
	elif round_number >= ROUND_LIMIT:
		_start_final_battle()
	else:
		round_number += 1
		_prepare_round()
		_save_game(true)
		_log(t("进入下一关：敌方主公保留剩余生命，再进行三轮三选一。", "Next stage: the enemy ruler keeps its remaining HP; complete three pick-one-of-three rounds."))
	if phase == "finished":
		_end_economy_run()
	_render()

func _start_final_battle() -> void:
	final_battle = true
	phase = "placement"
	pending_unit_ids.clear()
	_log("[color=#f6c860]" + t("十五轮备战结束：不再选将，进入无时间限制的最终决战！", "Fifteen preparation rounds complete. The unlimited final battle begins!") + "[/color]")
	if _can_start_battle(): _start_battle()
	else:
		phase = "finished"
		_log(t("我方已无可上阵武将，征战失败。", "No allied generals remain to deploy. Campaign failed."))
