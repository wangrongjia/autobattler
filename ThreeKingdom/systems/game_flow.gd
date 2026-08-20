extends "res://ThreeKingdom/systems/economy_system.gd"

func _new_game() -> void:
	round_number = 1
	phase = "draft"
	_reset_tianshu_run()
	_reset_economy_run()
	player_ruler_hp = _player_ruler_max_hp()
	enemy_ruler_hp = RULER_MAX_HP
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
	ground_effects.clear()
	refresh_charges = 0
	if tick_timer: tick_timer.stop()
	if is_instance_valid(log_box): log_box.clear()
	_prepare_round()
	if game_mode == "challenge":
		_log("%s · %s：完成三轮选将后迎战守军。" % [STAGE_NAMES[selected_stage - 1], str(DIFFICULTIES[selected_difficulty].name)])
	elif game_mode == "tianshu":
		_log("[color=#e5a8ff]天书演武开始：第 3/6/9/12/15 回合免费选天书，其他抽取可在天书阁购买。[/color]")
	else:
		_log(t("征战开始：每关进行三轮三选一，选项从左到右固定为前军、中军、后军。", "Campaign begins with three pick-one-of-three rounds; slots are fixed to Vanguard, Midguard, and Rearguard."))
	_render()

func _start_quick_game() -> void:
	game_mode = "quick"
	_new_game()

func _start_tianshu_game() -> void:
	game_mode = "tianshu"
	_new_game()

func _start_challenge(stage: int, difficulty: int) -> bool:
	if not _is_stage_unlocked(stage, difficulty): return false
	game_mode = "challenge"
	selected_stage = clampi(stage, 1, 50)
	selected_difficulty = clampi(difficulty, 0, DIFFICULTIES.size() - 1)
	_new_game()
	return true

func _save_game(silent := false) -> bool:
	if battle_running:
		if not silent: _log(t("战斗过程中不能保存，请在选人或布阵阶段保存。", "Save during draft or formation, not combat."))
		return false
	var data := {
		"version":7, "round_number":round_number, "phase":phase, "game_mode":game_mode,
		"selected_stage":selected_stage, "selected_difficulty":selected_difficulty,
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
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data))
	file.close()
	if is_instance_valid(continue_button): continue_button.disabled = false
	if not silent: _log(t("游戏进度已保存。", "Game saved."))
	_render()
	return true

func _load_game() -> bool:
	if battle_running or not FileAccess.file_exists(SAVE_PATH): return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null: return false
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) not in [3, 4, 5, 6, 7]:
		_log(t("存档版本不兼容。", "The save version is incompatible."))
		return false
	tick_timer.stop()
	game_mode = str(data.get("game_mode", "quick"))
	selected_stage = clampi(int(data.get("selected_stage", selected_stage)), 1, STAGE_NAMES.size())
	selected_difficulty = clampi(int(data.get("selected_difficulty", selected_difficulty)), 0, DIFFICULTIES.size() - 1)
	round_number = int(data.round_number)
	phase = str(data.phase)
	player_ruler_hp = int(data.player_ruler_hp)
	enemy_ruler_hp = int(data.enemy_ruler_hp)
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
	while loaded_reserves.size() > RESERVE_LIMIT:
		player_units.erase(loaded_reserves.pop_back())
		refresh_charges += 1
	selected_unit = str(data.selected_unit)
	final_battle = bool(data.get("final_battle", false))
	ruler_regen = data.get("ruler_regen", {"player":{"amount":0.0, "time":0.0, "clock":0.0}, "enemy":{"amount":0.0, "time":0.0, "clock":0.0}})
	last_battle_stats = data.get("last_battle_stats", [])
	_load_tianshu_state(data.get("tianshu", {}))
	_load_economy_state(data.get("economy", {}))
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

func _prepare_round() -> void:
	phase = "draft"
	draft_user_hidden = false
	draft_picks_remaining = PICKS_PER_ROUND
	pending_unit_ids = []
	chosen_this_round = []
	draft_roster_baseline = player_units.duplicate(true)
	selected_unit = ""
	_settle_round_economy()
	_add_enemy_wave()    # 每关从指定阵营（或全阵营）随机加入3名敌将
	if _tianshu_enabled() and _is_free_tianshu_round():
		_begin_tianshu_draw(1, "free", "draft", true)
	else:
		_generate_choices()

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

func _add_enemy_wave() -> void:
	var pool: Array = heroes.keys().filter(func(hero_id): return enemy_faction_filter.is_empty() or str(heroes[hero_id].f) == enemy_faction_filter)
	pool.shuffle()
	var wave: Array = pool.slice(0, mini(3, pool.size()))
	for hero_id in wave:
		var unit := _make_roster_unit("enemy", hero_id)
		enemy_units.append(unit)
		_auto_place_enemy(unit)
	var wave_names: Array[String] = []
	for hero_id in wave: wave_names.append(_hero_name(str(hero_id)))
	_log(t("第 %d 关敌军随机选择：" % round_number, "Stage %d enemy random picks: " % round_number) + "、".join(wave_names))

func _choose_hero(id: String) -> void:
	if battle_running or phase != "draft" or not choices.has(id): return
	if not _can_accept_hero(id):
		_log(t("场上和备战区均已满。", "The field and reserve are both full."))
		return
	var unit := _make_roster_unit("player", id)
	player_units.append(unit)
	chosen_this_round.append(id)
	draft_picks_remaining -= 1
	var locked_count := PICKS_PER_ROUND - draft_picks_remaining
	_log(t("第%d/3轮锁定：" % locked_count, "Pick %d/3 locked: " % locked_count) + _hero_name(id))
	if draft_picks_remaining <= 0:
		phase = "placement"
		draft_user_hidden = true
	else:
		_generate_choices()
		draft_user_hidden = false
	_render()

func _can_accept_hero(hero_id: String) -> bool:
	return _reserve_units().size() < RESERVE_LIMIT

func _try_upgrade(roster: Array, hero_id: String):
	# Compatibility shim for old callers/saves. Duplicate heroes remain separate.
	return null

func _auto_place_enemy(unit: Dictionary) -> void:
	var hero: Dictionary = heroes[unit.hero_id]
	var rows := [0, 1, 2] if bool(hero.get("all_rows", false)) else ([0] if int(hero.range) == 1 else ([0, 1, 2] if hero.range <= 2 else [2, 1, 0]))
	for row in rows:
		for col in BOARD_COLUMNS:
			if _unit_at(enemy_units, row, col) == null:
				unit.row = row
				unit.col = col
				return
	var deployed := enemy_units.filter(func(existing): return existing.alive and existing.row >= 0 and existing.id != unit.id and _can_unit_use_row(unit, int(existing.row)))
	if not deployed.is_empty():
		var replaced: Dictionary = deployed[0]
		unit.row = replaced.row
		unit.col = replaced.col
		replaced.row = -1
		replaced.col = -1

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
		if placed: _log(_hero_name(unit.hero_id) + t(" 已自动布阵。", " was placed automatically."))
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
			selected.row = row
			selected.col = col
			_log(_hero_name(selected.hero_id) + t(" 已调整站位。", " repositioned."))
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
			unit.current_hp_ratio = 0.06
			combat_units.append(unit)
	battle_stats = {}
	for unit in combat_units:
		battle_stats[unit.id] = {"unit_id":unit.id, "hero_id":unit.hero_id, "team":unit.team, "level":int(unit.get("level", 1)), "damage":0.0, "healing":0.0, "taken":0.0, "control":0.0}
	_apply_combo_bonds()
	_apply_tianshu_battle_start()
	_apply_faction_bonuses()
	_apply_opening_skills()
	_log("[color=#f6c860]" + t("第 ", "Round ") + str(round_number) + t(" 回合战斗开始（30 秒）！", " battle begins (30 seconds)!") + "[/color]")
	tick_timer.start()
	_render()

func _finish_battle() -> void:
	if not battle_running and phase != "combat": return
	tick_timer.stop()
	battle_running = false
	battle_paused = false
	action_in_progress = false
	_capture_battle_stats()
	_tianshu_on_round_end()
	var result: String
	if player_ruler_hp == enemy_ruler_hp: result = t("本关战斗结束，平局。", "Stage complete — draw.")
	elif player_ruler_hp > enemy_ruler_hp: result = t("本关战斗胜利！", "Stage won!")
	else: result = t("本关战斗失利。", "Stage lost.")
	_log("[color=#f6c860]" + result + "[/color]")
	var decisive := player_ruler_hp <= 0 or enemy_ruler_hp <= 0
	var player_won := enemy_ruler_hp <= 0 and player_ruler_hp > 0
	if game_mode == "challenge":
		if decisive or round_number >= ROUND_LIMIT:
			phase = "finished"
			var challenge_result := _complete_challenge(player_won if decisive else player_ruler_hp > enemy_ruler_hp)
			if has_method("_show_battle_result"):
				call_deferred("_show_battle_result", challenge_result)
		if not decisive and round_number < ROUND_LIMIT:
			round_number += 1
			_prepare_round()
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
