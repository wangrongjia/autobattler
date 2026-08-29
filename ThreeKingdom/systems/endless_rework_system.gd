extends "res://ThreeKingdom/systems/economy_system.gd"

const EndlessRules = preload("res://ThreeKingdom/data/endless_rework_rules.gd")

# 永久将印数据。将印只在无尽模式生效，避免污染已上架的普通/闯关平衡。
var endless_imprints := 0
var endless_imprint_nodes := {} # hero_id -> {node_id: level}
var endless_best_round := 0
var endless_total_runs := 0

# 单局数据。player_growth 是全阵容共享快照，场上、备战和以后招募的武将读取同一份值。
var endless_state := {}
var endless_battle := {}

func _endless_default_state() -> Dictionary:
	return {
		"strategies": {},
		"strategy_history": [],
		"candidates": [],
		"strategy_pending": false,
		"selected_candidate": "",
		"doctrines": {},
		"doctrine_history": [],
		"checkpoint": 0,
		"checkpoint_reward": 0,
		"checkpoint_imprints": 0,
		"player_growth": {"hp_flat":0.0, "strategy_flat":0.0, "cooldown_haste":0.0},
		"run_over": false
	}

func _run_is_endless() -> bool:
	return game_mode == "endless"

func _run_save_path() -> String:
	return EndlessRules.SAVE_PATH if _run_is_endless() else SAVE_PATH

func _run_reserve_limit() -> int:
	return EndlessRules.RESERVE_LIMIT if _run_is_endless() else RESERVE_LIMIT

func _run_draft_pick_count() -> int:
	return EndlessRules.DRAFT_PICKS if _run_is_endless() else PICKS_PER_ROUND

func _run_enemy_ruler_max_hp() -> int:
	if not _run_is_endless(): return RULER_MAX_HP
	return maxi(1, roundi(float(RULER_MAX_HP) * EndlessRules.enemy_ruler_multiplier(round_number)))

func _challenge_enemy_hp_multiplier() -> float:
	if not _run_is_endless(): return super._challenge_enemy_hp_multiplier()
	return EndlessRules.enemy_hp_multiplier(round_number)

func _challenge_strategy_bonus() -> float:
	if not _run_is_endless(): return super._challenge_strategy_bonus()
	var strategy := EndlessRules.enemy_strategy(round_number)
	strategy *= 1.0 + _endless_doctrine_value("veterans", "strategy_pct")
	return maxf(0.0, strategy - 100.0)

func _tianshu_enabled() -> bool:
	return super._tianshu_enabled() or _run_is_endless()

func _is_free_tianshu_round() -> bool:
	if not _run_is_endless(): return super._is_free_tianshu_round()
	return round_number in FREE_TIANSHU_ROUNDS

func _round_base_gold_income() -> int:
	if _run_is_endless() and round_number > 15: return 0
	return super._round_base_gold_income()

func _endless_new_run() -> void:
	endless_state = _endless_default_state()
	endless_battle = {}
	endless_total_runs += 1
	_save_progression()

func _endless_start_game() -> void:
	game_mode = "endless"
	call("_new_game")

func _endless_save_state() -> Dictionary:
	return endless_state.duplicate(true)

func _load_endless_state(value) -> void:
	endless_state = _endless_default_state()
	if value is Dictionary:
		for key in endless_state.keys():
			if value.has(key): endless_state[key] = value[key]
	_endless_sanitize_state()

func _endless_sanitize_state() -> void:
	if not endless_state.get("strategies", {}) is Dictionary: endless_state.strategies = {}
	if not endless_state.get("doctrines", {}) is Dictionary: endless_state.doctrines = {}
	if not endless_state.get("candidates", []) is Array: endless_state.candidates = []
	if not endless_state.get("strategy_history", []) is Array: endless_state.strategy_history = []
	if not endless_state.get("doctrine_history", []) is Array: endless_state.doctrine_history = []
	if not endless_state.get("player_growth", {}) is Dictionary:
		endless_state.player_growth = {"hp_flat":0.0, "strategy_flat":0.0, "cooldown_haste":0.0}
	for key in ["hp_flat", "strategy_flat", "cooldown_haste"]:
		endless_state.player_growth[key] = maxf(0.0, float(endless_state.player_growth.get(key, 0.0)))

func _endless_run_snapshot() -> Dictionary:
	if not FileAccess.file_exists(EndlessRules.SAVE_PATH): return {}
	var file := FileAccess.open(EndlessRules.SAVE_PATH, FileAccess.READ)
	if file == null: return {}
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary or str(data.get("game_mode", "")) != "endless" or str(data.get("phase", "")) == "finished": return {}
	return {"round":maxi(1, int(data.get("round_number", 1))), "checkpoint":maxi(0, int(data.get("endless", {}).get("checkpoint", 0)))}

func _endless_prepare_round() -> void:
	if not _run_is_endless(): return
	enemy_ruler_hp = _run_enemy_ruler_max_hp()
	_endless_recalculate_existing_enemies()
	_endless_sync_player_roster()
	_log("[color=#d9c08a]【军情】第 %d 回合：敌将生命 ×%.2f，兵略 %.0f，行动速度 +%.0f%%，冷却极速 +%.0f；敌主 %s。[/color]" % [
		round_number, EndlessRules.enemy_hp_multiplier(round_number), EndlessRules.enemy_strategy(round_number) * (1.0 + _endless_doctrine_value("veterans", "strategy_pct")),
		(EndlessRules.enemy_action_multiplier(round_number) - 1.0) * 100.0, EndlessRules.enemy_cooldown_haste(round_number), _endless_format_number(float(enemy_ruler_hp))])

func _endless_recalculate_existing_enemies() -> void:
	var hp_mult := EndlessRules.enemy_hp_multiplier(round_number)
	for unit in enemy_units:
		if not unit.alive: continue
		var ratio := clampf(float(unit.hp) / maxf(1.0, float(unit.max_hp)), 0.0, 1.0)
		unit.max_hp = float(heroes[unit.hero_id].hp) * hp_mult
		unit.hp = maxf(1.0, float(unit.max_hp) * ratio)
		unit.skill_value_bonus = _challenge_strategy_bonus()

func _endless_finish_battle() -> String:
	if not _run_is_endless(): return ""
	for index in range(enemy_units.size() - 1, -1, -1):
		if not enemy_units[index].alive: enemy_units.remove_at(index)
	if player_ruler_hp <= 0:
		_endless_end_run()
		return "over"
	if round_number % EndlessRules.CHECKPOINT_INTERVAL == 0:
		_endless_open_checkpoint()
		return "checkpoint"
	return "advance"

func _endless_open_checkpoint() -> void:
	var checkpoint := int(round_number / EndlessRules.CHECKPOINT_INTERVAL)
	endless_state.checkpoint = checkpoint
	endless_state.selected_candidate = ""
	endless_state.checkpoint_reward = 250 + checkpoint * 100
	general_souls += int(endless_state.checkpoint_reward)
	var imprint_gain := 0
	if checkpoint >= 3:
		imprint_gain = 2 + int(floor(float(checkpoint - 3) / 3.0))
		endless_imprints += imprint_gain
	endless_state.checkpoint_imprints = imprint_gain
	_endless_apply_checkpoint_training(checkpoint)
	var doctrine := _endless_draw_doctrine()
	_endless_roll_strategy_candidates()
	phase = "checkpoint"
	_save_progression()
	_log("[color=#f0c77a]【据点 %d】将魂 +%d%s；敌军获得【%s】。请选择且只能选择一项战策。[/color]" % [
		checkpoint, int(endless_state.checkpoint_reward), "，将印 +%d" % imprint_gain if imprint_gain > 0 else "", _endless_doctrine_name(doctrine)])

func _endless_apply_checkpoint_training(checkpoint: int) -> void:
	var level := _endless_strategy_level("reserve_training")
	if level <= 0: return
	var entry := EndlessRules.strategy_entry("reserve_training")
	endless_state.player_growth.hp_flat = float(endless_state.player_growth.hp_flat) + EndlessRules.leveled_value(entry, "checkpoint_hp", level)
	endless_state.player_growth.strategy_flat = float(endless_state.player_growth.strategy_flat) + EndlessRules.leveled_value(entry, "checkpoint_strategy", level)
	endless_state.strategy_history.append({"round":round_number, "name":"全军轮训结算", "desc":"据点 %d：全阵容获得线性成长" % checkpoint})
	_endless_sync_player_roster()

func _endless_after_checkpoint() -> bool:
	if phase != "checkpoint" or bool(endless_state.get("strategy_pending", false)): return false
	endless_state.candidates = []
	endless_state.selected_candidate = ""
	round_number += 1
	call("_prepare_round")
	call("_save_game", true)
	return true

func _endless_end_run() -> void:
	endless_state.run_over = true
	endless_best_round = maxi(endless_best_round, round_number)
	phase = "finished"
	_save_progression()
	var dir := DirAccess.open("user://")
	if dir != null and FileAccess.file_exists(EndlessRules.SAVE_PATH): dir.remove(EndlessRules.SAVE_PATH.get_file())
	pending_battle_result = {"endless":true, "victory":false, "round":round_number, "checkpoint":int(endless_state.checkpoint), "souls":0}
	if has_method("_show_battle_result"): call_deferred("_show_battle_result", pending_battle_result.duplicate(true))

# ---------------- 战策：三选一且单次锁定 ----------------

func _endless_strategy_level(id: String) -> int:
	return int(endless_state.get("strategies", {}).get(id, 0))

func _endless_strategy_value(id: String, key: String) -> float:
	var level := _endless_strategy_level(id)
	if level <= 0: return 0.0
	return EndlessRules.leveled_value(EndlessRules.strategy_entry(id), key, level)

func _endless_roll_strategy_candidates() -> void:
	var pool: Array = []
	for entry in EndlessRules.STRATEGIES:
		if _endless_strategy_level(str(entry.id)) < int(entry.max): pool.append(str(entry.id))
	pool.shuffle()
	endless_state.candidates = pool.slice(0, mini(3, pool.size()))
	endless_state.strategy_pending = not endless_state.candidates.is_empty()

func _endless_strategy_candidates() -> Array:
	var result: Array = []
	for raw_id in endless_state.get("candidates", []):
		var id := str(raw_id)
		var entry := EndlessRules.strategy_entry(id)
		var current := _endless_strategy_level(id)
		var next := mini(current + 1, int(entry.get("max", 1)))
		var descs: Array = entry.get("levels", [])
		result.append({"id":id, "name":str(entry.get("name", id)), "tag":str(entry.get("tag", "战策")), "current":current, "next":next, "max":int(entry.get("max", 1)), "desc":str(descs[next - 1])})
	return result

func _endless_pick_strategy(id: String) -> bool:
	if phase != "checkpoint" or not bool(endless_state.get("strategy_pending", false)): return false
	if not endless_state.candidates.has(id): return false
	var entry := EndlessRules.strategy_entry(id)
	if entry.is_empty(): return false
	var level := _endless_strategy_level(id)
	if level >= int(entry.max): return false
	level += 1
	endless_state.strategies[id] = level
	endless_state.strategy_pending = false
	endless_state.selected_candidate = id
	var desc := str((entry.levels as Array)[level - 1])
	endless_state.strategy_history.append({"round":round_number, "name":str(entry.name), "level":level, "desc":desc})
	for key in entry.get("per_level", {}).keys():
		endless_state.player_growth[key] = float(endless_state.player_growth.get(key, 0.0)) + float(entry.per_level[key])
	_endless_sync_player_roster()
	call("_save_game", true)
	_log("[color=#8fd4a0]【战策锁定】%s Lv%d：%s[/color]" % [str(entry.name), level, desc])
	return true

# ---------------- 敌军公开军势 ----------------

func _endless_doctrine_level(id: String) -> int:
	return int(endless_state.get("doctrines", {}).get(id, 0))

func _endless_doctrine_value(id: String, key: String) -> float:
	var level := _endless_doctrine_level(id)
	if level <= 0: return 0.0
	return EndlessRules.leveled_value(EndlessRules.doctrine_entry(id), key, level)

func _endless_doctrine_name(id: String) -> String:
	return str(EndlessRules.doctrine_entry(id).get("name", "无"))

func _endless_draw_doctrine() -> String:
	var pool: Array = []
	for entry in EndlessRules.ENEMY_DOCTRINES:
		if _endless_doctrine_level(str(entry.id)) < int(entry.max): pool.append(str(entry.id))
	if pool.is_empty(): return ""
	var id := str(pool[rng.randi_range(0, pool.size() - 1)])
	var level := _endless_doctrine_level(id) + 1
	endless_state.doctrines[id] = level
	endless_state.doctrine_history.append({"round":round_number, "id":id, "level":level})
	return id

# ---------------- 全阵容共享成长 ----------------

func _endless_imprint_mod(hero_id: String) -> Dictionary:
	var result := {"hp_pct":0.0, "strategy_pct":0.0, "cooldown_haste":0.0, "reduction":0.0, "damage":0.0, "opening_action":0.0}
	var levels: Dictionary = endless_imprint_nodes.get(hero_id, {})
	for node_id in levels:
		var level := int(levels[node_id])
		var node := EndlessRules.imprint_entry(str(node_id))
		for key in node.get("effects", {}): result[key] = float(result.get(key, 0.0)) + float(node.effects[key]) * level
	return result

func _endless_shared_growth(hero_id: String) -> Dictionary:
	var imprint := _endless_imprint_mod(hero_id)
	var linear_depth := maxi(0, round_number - 1)
	return {
		"hp_flat":float(endless_state.player_growth.get("hp_flat", 0.0)) + EndlessRules.PLAYER_HP_PER_ROUND * linear_depth,
		"strategy_flat":float(endless_state.player_growth.get("strategy_flat", 0.0)) + EndlessRules.PLAYER_STRATEGY_PER_ROUND * linear_depth,
		"cooldown_haste":float(endless_state.player_growth.get("cooldown_haste", 0.0)) + float(imprint.cooldown_haste),
		"hp_pct":float(imprint.hp_pct), "strategy_pct":float(imprint.strategy_pct),
		"damage":float(imprint.damage), "reduction":float(imprint.reduction), "opening_action":float(imprint.opening_action)
	}

func _endless_sync_player_roster() -> void:
	if not _run_is_endless(): return
	for unit in player_units:
		if str(unit.team) == "player": _endless_sync_player_unit(unit)

func _endless_sync_player_unit(unit: Dictionary, combat_reset := false) -> void:
	if not _run_is_endless() or str(unit.team) != "player": return
	var hero_id := str(unit.hero_id)
	var growth := _endless_shared_growth(hero_id)
	if not unit.has("endless_base_max_hp"):
		unit.endless_base_max_hp = float(unit.max_hp)
	var old_max := maxf(1.0, float(unit.max_hp))
	var ratio := clampf(float(unit.hp) / old_max, 0.0, 1.0)
	var target_max := float(unit.endless_base_max_hp) * (1.0 + float(growth.hp_pct)) + float(growth.hp_flat)
	unit.max_hp = maxf(1.0, target_max)
	unit.hp = maxf(1.0, float(unit.max_hp) * ratio) if unit.alive else 0.0
	var talent := _talent_stat_bonus(hero_id)
	var runes := _rune_stat_bonus(hero_id)
	var progression_strategy := float(talent.strategy) + float(runes.strategy)
	var strategy_base := float(heroes[hero_id].skill_value) + progression_strategy
	unit.skill_value_bonus = progression_strategy + float(growth.strategy_flat) + strategy_base * float(growth.strategy_pct)
	unit.endless_cooldown_haste = float(growth.cooldown_haste)
	unit.endless_damage_pct = float(growth.damage)
	unit.endless_damage_reduction = float(growth.reduction)
	unit.endless_opening_action = float(growth.opening_action)
	unit.endless_low_hp_damage = _endless_strategy_value("laststand", "low_hp_damage")
	unit.endless_emergency_heal = _endless_strategy_value("medic", "emergency_heal")
	unit.endless_emergency_used = false if combat_reset else bool(unit.get("endless_emergency_used", false))

func _apply_progression_to_new_unit(unit: Dictionary) -> void:
	super._apply_progression_to_new_unit(unit)
	if _run_is_endless() and str(unit.team) == "player": _endless_sync_player_unit(unit)

func _endless_on_battle_start() -> void:
	if not _run_is_endless(): return
	endless_battle = {"revive_used":false}
	var factions := {}
	for unit in combat_units:
		if unit.team == "player": factions[str(heroes[unit.hero_id].f)] = true
	var faction_damage := _endless_strategy_value("four_factions", "damage_per_faction") * factions.size()
	for unit in combat_units:
		if unit.team == "player":
			_endless_sync_player_unit(unit, true)
			unit.endless_damage_pct = float(unit.endless_damage_pct) + faction_damage
			unit.action = minf(ACTION_MAX, float(unit.action) + float(unit.endless_opening_action) + _endless_strategy_value("assault", "opening_action"))
			unit.invulnerable_time = maxf(float(unit.get("invulnerable_time", 0.0)), _endless_strategy_value("golden", "opening_invulnerable"))
			var shield := float(unit.max_hp) * _endless_strategy_value("bulwark", "opening_shield")
			unit.shield = float(unit.shield) + shield
			if shield > 0.0 and has_method("_add_stat"): call("_add_stat", unit, "shield", shield)
		else:
			unit.endless_enemy_action_gain = EndlessRules.enemy_action_multiplier(round_number)
			unit.endless_cooldown_haste = EndlessRules.enemy_cooldown_haste(round_number)
			unit.endless_damage_reduction = _endless_doctrine_value("unyielding", "reduction")
			unit.endless_low_hp_damage = _endless_doctrine_value("fury", "low_hp_damage")
			unit.invulnerable_time = maxf(float(unit.get("invulnerable_time", 0.0)), _endless_doctrine_value("ward", "invulnerable"))
			var enemy_shield := float(unit.max_hp) * _endless_doctrine_value("iron", "shield")
			unit.shield = float(unit.shield) + enemy_shield
	_log("[color=#9fc6df]【全军共享】本场所有已上阵武将已读取同一份远征成长；备战与后续招募也会同步。[/color]")

func _endless_try_emergency_heal(target: Dictionary) -> void:
	if not _run_is_endless() or target.team != "player" or bool(target.get("endless_emergency_used", false)): return
	var ratio := float(target.get("endless_emergency_heal", 0.0))
	if ratio <= 0.0 or float(target.hp) <= 0.0 or float(target.hp) / maxf(1.0, float(target.max_hp)) >= 0.25: return
	target.endless_emergency_used = true
	var heal := float(target.max_hp) * ratio
	if has_method("_heal_unit_only"): call("_heal_unit_only", target, target, heal)
	_log("[color=#8fd4a0]【随军医官】%s 回复 %d 生命。[/color]" % [_hero_name(str(target.hero_id)), roundi(heal)])

func _endless_try_revive(target: Dictionary) -> bool:
	if not _run_is_endless() or target.team != "player" or bool(endless_battle.get("revive_used", false)): return false
	var ratio := _endless_strategy_value("revive", "revive_ratio")
	if ratio <= 0.0: return false
	endless_battle.revive_used = true
	target.hp = maxf(1.0, float(target.max_hp) * ratio)
	target.action = 0.0
	target.invulnerable_time = 0.8
	_log("[color=#f0c77a]【整军再起】%s 以 %d%% 生命复起。[/color]" % [_hero_name(str(target.hero_id)), roundi(ratio * 100.0)])
	return true

func _endless_player_ruler_reduction() -> float:
	return _endless_strategy_value("ruler_guard", "ruler_reduction") if _run_is_endless() else 0.0

func _endless_enemy_ruler_damage_bonus() -> float:
	return _endless_doctrine_value("siege", "ruler_damage") if _run_is_endless() else 0.0

# ---------------- 汇总/可视化数据 ----------------

func _endless_player_summary() -> String:
	var growth: Dictionary = endless_state.get("player_growth", {})
	var linear_depth := maxi(0, round_number - 1)
	var linear_hp := EndlessRules.PLAYER_HP_PER_ROUND * linear_depth
	var linear_strategy := EndlessRules.PLAYER_STRATEGY_PER_ROUND * linear_depth
	var lines := PackedStringArray([
		"【全军共享线性成长】",
		"回合底成长：最大生命 +%s、兵略 +%.0f" % [_endless_format_number(linear_hp), linear_strategy],
		"战策额外成长：最大生命 +%s、兵略 +%.0f" % [_endless_format_number(float(growth.get("hp_flat", 0.0))), float(growth.get("strategy_flat", 0.0))],
		"当前合计：最大生命 +%s、兵略 +%.0f" % [_endless_format_number(linear_hp + float(growth.get("hp_flat", 0.0))), linear_strategy + float(growth.get("strategy_flat", 0.0))],
		"冷却极速 +%.0f" % float(growth.get("cooldown_haste", 0.0)),
		"说明：场上、备战席和后续招募武将全部生效。",
		"",
		"【已获战策】"
	])
	var any := false
	for entry in EndlessRules.STRATEGIES:
		var level := _endless_strategy_level(str(entry.id))
		if level <= 0: continue
		any = true
		lines.append("%s Lv%d/%d：%s" % [str(entry.name), level, int(entry.max), str((entry.levels as Array)[level - 1])])
	if not any: lines.append("尚无战策")
	return "\n".join(lines)

func _endless_enemy_summary(at_round := round_number) -> String:
	var strategy := EndlessRules.enemy_strategy(at_round) * (1.0 + _endless_doctrine_value("veterans", "strategy_pct"))
	var lines := PackedStringArray([
		"【敌军指数成长 · 第 %d 回合】" % at_round,
		"武将生命 ×%.2f" % EndlessRules.enemy_hp_multiplier(at_round),
		"武将兵略 %.0f" % strategy,
		"行动速度 +%.0f%%（封顶 +10%%）" % ((EndlessRules.enemy_action_multiplier(at_round) - 1.0) * 100.0),
		"冷却极速 +%.0f（缓慢增长，封顶 +12）" % EndlessRules.enemy_cooldown_haste(at_round),
		"敌方主公生命 %s" % _endless_format_number(float(RULER_MAX_HP) * EndlessRules.enemy_ruler_multiplier(at_round)),
		"",
		"【已公开军势】"
	])
	var any := false
	for entry in EndlessRules.ENEMY_DOCTRINES:
		var level := _endless_doctrine_level(str(entry.id))
		if level <= 0: continue
		any = true
		lines.append("%s Lv%d/%d：%s" % [str(entry.name), level, int(entry.max), str((entry.levels as Array)[level - 1])])
	if not any: lines.append("尚无军势")
	var next_checkpoint_round := (int(floor(float(maxi(1, at_round) - 1) / EndlessRules.CHECKPOINT_INTERVAL)) + 1) * EndlessRules.CHECKPOINT_INTERVAL + 1
	lines.append("")
	lines.append("下一阶段（第 %d 回合）：生命 ×%.2f，兵略 %.0f" % [next_checkpoint_round, EndlessRules.enemy_hp_multiplier(next_checkpoint_round), EndlessRules.enemy_strategy(next_checkpoint_round) * (1.0 + _endless_doctrine_value("veterans", "strategy_pct"))])
	return "\n".join(lines)

func _endless_checkpoint_payload() -> Dictionary:
	return {
		"checkpoint":int(endless_state.get("checkpoint", 0)), "round":round_number,
		"souls":int(endless_state.get("checkpoint_reward", 0)), "imprints":int(endless_state.get("checkpoint_imprints", 0)),
		"candidates":_endless_strategy_candidates(), "pending":bool(endless_state.get("strategy_pending", false)),
		"selected":str(endless_state.get("selected_candidate", "")),
		"player_summary":_endless_player_summary(), "enemy_summary":_endless_enemy_summary()
	}

func _endless_format_number(value: float) -> String:
	if value >= 100000000.0: return "%.2f亿" % (value / 100000000.0)
	if value >= 10000.0: return "%.1f万" % (value / 10000.0)
	return str(roundi(value))

# ---------------- 将印树 ----------------

func _endless_imprint_level(hero_id: String, node_id: String) -> int:
	return int(endless_imprint_nodes.get(hero_id, {}).get(node_id, 0))

func _endless_imprint_can_upgrade(hero_id: String, node_id: String) -> bool:
	if not heroes.has(hero_id): return false
	var node := EndlessRules.imprint_entry(node_id)
	if node.is_empty() or _endless_imprint_level(hero_id, node_id) >= int(node.max): return false
	for required in node.get("requires", []):
		if _endless_imprint_level(hero_id, str(required)) <= 0: return false
	return endless_imprints >= int(node.cost)

func _endless_imprint_upgrade(hero_id: String, node_id: String) -> bool:
	if not _endless_imprint_can_upgrade(hero_id, node_id): return false
	var node := EndlessRules.imprint_entry(node_id)
	endless_imprints -= int(node.cost)
	var levels: Dictionary = endless_imprint_nodes.get(hero_id, {})
	levels[node_id] = int(levels.get(node_id, 0)) + 1
	endless_imprint_nodes[hero_id] = levels
	_endless_sync_player_roster()
	_save_progression()
	return true

func _endless_imprint_refund(hero_id: String) -> bool:
	var levels: Dictionary = endless_imprint_nodes.get(hero_id, {})
	if levels.is_empty(): return false
	var refund := 0
	for node_id in levels:
		refund += int(EndlessRules.imprint_entry(str(node_id)).get("cost", 0)) * int(levels[node_id])
	endless_imprints += refund
	endless_imprint_nodes.erase(hero_id)
	_endless_sync_player_roster()
	_save_progression()
	return true

func _add_debug_imprints() -> void:
	if not _debug_tools_enabled(): return
	endless_imprints += 100
	_save_progression()

# 在原进度存档中附加字段，保持向前兼容。
func _load_progression() -> void:
	super._load_progression()
	if not FileAccess.file_exists(PROGRESSION_SAVE_PATH): return
	var file := FileAccess.open(PROGRESSION_SAVE_PATH, FileAccess.READ)
	if file == null: return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary: return
	endless_imprints = maxi(0, int(data.get("endless_imprints", 0)))
	endless_imprint_nodes = data.get("endless_imprint_nodes", {}) if data.get("endless_imprint_nodes", {}) is Dictionary else {}
	endless_best_round = maxi(0, int(data.get("endless_best_round", 0)))
	endless_total_runs = maxi(0, int(data.get("endless_total_runs", 0)))

func _save_progression() -> bool:
	if not super._save_progression(): return false
	var file := FileAccess.open(PROGRESSION_SAVE_PATH, FileAccess.READ)
	if file == null: return false
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary: data = {}
	data.endless_imprints = endless_imprints
	data.endless_imprint_nodes = endless_imprint_nodes
	data.endless_best_round = endless_best_round
	data.endless_total_runs = endless_total_runs
	file = FileAccess.open(PROGRESSION_SAVE_PATH, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true
