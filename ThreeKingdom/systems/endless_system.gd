extends "res://ThreeKingdom/systems/economy_system.gd"

# 无尽远征 · 数据与规则引擎（docs/无尽模式-融合终稿.md v0.4）。
# 继承链插入：economy_system → endless_system → game_flow（仅改一行 extends）。
# 本文件只使用上层（game_state/progression/tianshu/economy）成员，负责：
#   模式接口、敌方曲线、据点/掉落/贡献、军势·统帅事件·战策·军府的数据引擎、
#   将印永久养成（七层树 + 三通道冷却 + 数值瀑布）与进度存档 v2、无尽单局存档。
# 战斗内效果引擎在 combat_system.gd 末尾（_endless_* 系列覆盖 _endless_on_battle_start）。
# 敌方评分导演在 game_flow.gd（需要 ENEMY_SQUADS）。

const EndlessRules = preload("res://ThreeKingdom/data/endless_rules.gd")
const ImprintTrees = preload("res://ThreeKingdom/data/hero_imprint_trees.gd")

# ---- 永久养成（progression 存档 v2 追加字段）----
var universal_imprints := 0                 # 通用将印
var hero_imprints := {}                     # 专属将印 hero_id -> 数量
var hero_imprint_nodes := {}                # 已点亮节点 hero_id -> {node_key: level}
var hero_imprint_swift := {}                # 疾行模式 hero_id -> "auto"/"cooldown"/"action"
var hero_imprint_spent := {}                # 重置返还基数 hero_id -> {"exclusive":n,"universal":n}
var imprint_exclusive_only := false         # 点亮是否「仅专属」
var endless_best_round := 0                 # 历史最高回合
var endless_best_lineup := []               # 最高回合阵容快照
var endless_total_runs := 0                 # 总远征次数
var endless_total_checkpoints := 0          # 累计据点数

# ---- 单局无尽运行状态（随无尽存档持久化，run_seed 驱动确定性随机流）----
var endless_state := {
	"run_seed": 0, "rng_cursor": 0,
	"momentum": {},                # 军势 id -> level
	"event_history": [],           # 统帅事件历史（同类两次内不重复）
	"current_event": "",           # 本回合统帅事件 id
	"strategies": {},              # 战策 id -> level
	"checkpoint_index": 0,         # 已到达的最高据点序号（1=回合5）
	"checkpoint_strategy_ids": [], # 据点页当前战策候选
	"checkpoint_refreshed": false, # 本据点是否已刷新候选
	"checkpoint_round": 0,         # 本据点对应回合
	"strategy_pending_pick": false,
	"pick_total": 3,               # 本回合选将总次数快照（求贤/集思广略）
	"coupon": false,               # 军府 8 折券
	"junfu_global": {},            # item_id -> 本据点已购次数（限次类）
	"junfu_hero": {},              # item_id -> {hero_id: 层数}
	"rearguard_ready": false,      # 重整：主公首次致命伤害保留 1 点
	"recruit_extra": 0,            # 求贤：下一回合整备额外一次三选一
	"brainstorm_left": 0,          # 集思广略剩余回合（每回合选将 +1）
	"breakthrough_action": false,  # 破阵奖励：下一场全军 +20 初始行动条
	"contribution": {},            # hero_id -> {"contrib": float, "rounds": int}
	"survival_streak": {},         # hero_id -> 连续存活回合（百战余生）
	"record_bonus_given": false,
	"run_over": false,
	"triumphed": false
}
var endless_rng := RandomNumberGenerator.new()
var endless_battle := {}                    # 每场战斗的运行时状态（不存档；含 im_cache）
var endless_last_summary := {}              # 最近一次据点/终局摘要（UI 用）

func _reset_endless_defaults() -> void:
	endless_state = {
		"run_seed": int(rng.randi()), "rng_cursor": 0,
		"momentum": {}, "event_history": [], "current_event": "",
		"strategies": {}, "checkpoint_index": 0, "checkpoint_strategy_ids": [],
		"checkpoint_refreshed": false, "checkpoint_round": 0, "strategy_pending_pick": false,
		"pick_total": 3, "coupon": false, "junfu_global": {}, "junfu_hero": {},
		"rearguard_ready": false, "recruit_extra": 0, "brainstorm_left": 0,
		"breakthrough_action": false, "contribution": {}, "survival_streak": {},
		"record_bonus_given": false, "run_over": false, "triumphed": false
	}

# ==================== 模式接口 ====================

func _run_is_endless() -> bool:
	return game_mode == "endless"

func _run_save_path() -> String:
	return EndlessRules.ENDLESS_SAVE_PATH if _run_is_endless() else SAVE_PATH

func _run_draft_pick_count() -> int:
	if not _run_is_endless(): return PICKS_PER_ROUND
	var extra := 0
	if int(endless_state.get("brainstorm_left", 0)) > 0: extra += 1
	if int(endless_state.get("recruit_extra", 0)) > 0: extra += 1
	return EndlessRules.ENDLESS_DRAFT_PICKS + extra

func _run_reserve_limit() -> int:
	return EndlessRules.ENDLESS_RESERVE_LIMIT if _run_is_endless() else RESERVE_LIMIT

func _endless_unlocked() -> bool:
	# 任意难度通关第 20 关后解锁。
	for difficulty in DIFFICULTIES.size():
		if int(stage_star_records.get(_progression_key(STAGE_NAMES.size(), difficulty), 0)) > 0:
			return true
	return false

func _endless_checkpoint_of_round(round_number_value: int) -> int:
	return int(round_number_value / EndlessRules.CHECKPOINT_INTERVAL) if round_number_value % EndlessRules.CHECKPOINT_INTERVAL == 0 else 0

func _endless_rearguard_ready() -> bool:
	if not _run_is_endless() or not bool(endless_state.get("rearguard_ready", false)): return false
	endless_state.rearguard_ready = false
	_log("[color=#8fd4a0]【重整】主公在致命一击下保留 1 点生命！[/color]")
	return true

# ==================== 曲线与日程覆盖（§2.1/§1.2）====================

func _challenge_enemy_hp_multiplier() -> float:
	if not _run_is_endless(): return super._challenge_enemy_hp_multiplier()
	return EndlessRules.enemy_hp_multiplier(round_number)

func _challenge_strategy_bonus() -> float:
	if not _run_is_endless(): return super._challenge_strategy_bonus()
	return EndlessRules.enemy_strategy_bonus(round_number)

func _run_enemy_ruler_max_hp() -> int:
	if not _run_is_endless(): return RULER_MAX_HP
	return maxi(1, int(round(float(RULER_MAX_HP) * EndlessRules.enemy_ruler_hp_multiplier(round_number))))

func _player_ruler_max_hp() -> int:
	var result: int = super._player_ruler_max_hp()
	if _run_is_endless():
		result = int(round(float(result) * (1.0 - 0.08 * float(_endless_has_strategy("brokencauldron")))))
		result = int(round(float(result) * (1.0 + _endless_strategy_param("leadcharge", "pct"))))
	return result

func _round_base_gold_income() -> int:
	var result: int = super._round_base_gold_income()
	if _run_is_endless() and round_number > EndlessRules.GOLD_FREEZE_ROUND:
		result = 0   # 冻结基础收入；利息与卖将收入保留
	return result

func _tianshu_enabled() -> bool:
	return super._tianshu_enabled() or _run_is_endless()

func _is_free_tianshu_round() -> bool:
	if not _run_is_endless(): return super._is_free_tianshu_round()
	if round_number in FREE_TIANSHU_ROUNDS: return true
	if round_number > EndlessRules.FIRST_EXPEDITION_ROUND and round_number % EndlessRules.CHECKPOINT_INTERVAL == 0:
		return _endless_upgradable_tianshu_books() >= 3
	return false

func _endless_upgradable_tianshu_books() -> int:
	var count := 0
	for book_id in TIANSHU_BOOKS.keys():
		if _tianshu_level(str(book_id)) < 2: count += 1
	return count

func _endless_convert_leftover_tianshu() -> bool:
	# 残卷转化：可选天书不足 3 本时，500 金换一张军府 8 折券。
	if not _run_is_endless() or bool(endless_state.get("coupon", false)): return false
	if _endless_upgradable_tianshu_books() >= 3: return false
	if not _spend_gold(500, "残卷转化"): return false
	endless_state.coupon = true
	_log("[color=#e5a8ff]【残卷转化】天书残卷折价换得军府八折券一张。[/color]")
	return true

# ==================== 单局生命周期 ====================

func _endless_new_run() -> void:
	_reset_endless_defaults()
	_endless_reseed()
	endless_battle = {}
	endless_last_summary = {}
	endless_total_runs += 1
	_save_progression()

func _endless_reseed() -> void:
	endless_rng.seed = int(endless_state.get("run_seed", 0))
	for index in int(endless_state.get("rng_cursor", 0)):
		endless_rng.randi()

func _endless_randf() -> float:
	var value := endless_rng.randf()
	endless_state.rng_cursor = int(endless_state.get("rng_cursor", 0)) + 1
	return value

func _endless_randi_range(from: int, to: int) -> int:
	var value := endless_rng.randi_range(from, to)
	endless_state.rng_cursor = int(endless_state.get("rng_cursor", 0)) + 1
	return value

func _endless_pick(keys: Array) -> String:
	if keys.is_empty(): return ""
	return str(keys[_endless_randi_range(0, keys.size() - 1)])

# ---- 回合整备（由 game_flow._prepare_round 在结算经济后调用）----

func _endless_prepare_round() -> void:
	# 统帅回合事件：每 10 回合一场，同类事件两次内不重复
	endless_state.current_event = ""
	if round_number % 10 == 0:
		var recent: Array = (endless_state.event_history as Array).slice(maxi(0, (endless_state.event_history as Array).size() - 2))
		var candidates: Array = EndlessRules.COMMANDER_EVENTS.filter(func(entry): return not recent.has(str(entry.id)))
		if candidates.is_empty(): candidates = EndlessRules.COMMANDER_EVENTS.duplicate()
		endless_state.current_event = _endless_pick(candidates.map(func(entry): return str(entry.id)))
		endless_state.event_history.append(endless_state.current_event)
		_log("[color=#e8916d]【统帅回合·%s】%s[/color]" % [_endless_event_name(str(endless_state.current_event)), _endless_event_desc(str(endless_state.current_event))])
	# 敌方主公按主公式成长满血重入
	enemy_ruler_hp = _run_enemy_ruler_max_hp()
	# 存量敌军重算：保留生命比例，按新倍率重设最大生命（§2.2）
	_endless_recalc_enemy_units()
	# 战策·休养生息：整备阶段主公回复
	var recovery := _endless_strategy_param("recovery", "pct")
	if recovery > 0.0:
		var ruler_max := float(_player_ruler_max_hp())
		var healed := minf(ruler_max - float(player_ruler_hp), ruler_max * recovery)
		player_ruler_hp = int(minf(ruler_max, float(player_ruler_hp) + healed))
		if healed >= 1.0: _log("[color=#8fd4a0]【休养生息】主公回复 %d 生命。[/color]" % int(healed))
	_endless_announce_intel()
	if int(endless_state.get("recruit_extra", 0)) > 0:
		_log("[color=#e5c97a]【军府·求贤】本回合选将次数 +1。[/color]")

func _endless_recalc_enemy_units() -> void:
	var multiplier := _challenge_enemy_hp_multiplier()
	for unit in enemy_units:
		if not unit.alive: continue
		var base_hp := float(heroes[unit.hero_id].hp)
		var ratio := clampf(float(unit.hp) / maxf(1.0, float(unit.max_hp)), 0.0, 1.0)
		unit.max_hp = base_hp * multiplier
		unit.hp = unit.max_hp * ratio

func _endless_announce_intel() -> void:
	var momentum_names: Array[String] = []
	for id in endless_state.momentum:
		var entry := _endless_momentum_entry(str(id))
		momentum_names.append("%s Lv%d" % [str(entry.get("name", id)), int(endless_state.momentum[id])])
	if not momentum_names.is_empty():
		_log("[color=#e8916d]【军势】敌军：%s[/color]" % "、".join(momentum_names))
	var event_note := "" if str(endless_state.current_event).is_empty() else " · 统帅事件：" + _endless_event_name(str(endless_state.current_event))
	_log("[color=#c9b98a]【军情】第 %d 回合 · 敌将生命 ×%.2f · 兵略 +%d · 行动增速 %.0f%% · 敌方主公生命 %s%s[/color]" % [
		round_number, _challenge_enemy_hp_multiplier(), int(_challenge_strategy_bonus()),
		(EndlessRules.enemy_action_gain(round_number) - 1.0) * 100.0, _format_big_number(float(_run_enemy_ruler_max_hp())), event_note])
	if int(endless_state.get("checkpoint_index", 0)) == 0:
		var next_checkpoint := (int(round_number / EndlessRules.CHECKPOINT_INTERVAL) + 1) * EndlessRules.CHECKPOINT_INTERVAL
		_log("[color=#c9b98a]【军情】下一个据点：第 %d 回合。[/color]" % next_checkpoint)

func _format_big_number(value: float) -> String:
	if value >= 100000000.0: return "%.1f亿" % (value / 100000000.0)
	if value >= 10000.0: return "%.1f万" % (value / 10000.0)
	return str(int(value))

func _endless_consume_prep_flags() -> void:
	# 在选将次数快照之后消耗一次性整备标记
	if int(endless_state.get("brainstorm_left", 0)) > 0:
		endless_state.brainstorm_left = int(endless_state.brainstorm_left) - 1
	endless_state.recruit_extra = 0

# ==================== 回合结算 / 据点（§4.1/§4.2）====================
# 返回 "advance"（进入下一回合）/ "checkpoint"（打开据点页）/ "over"（远征结束）。
# 回合推进与自动存档由 game_flow._finish_battle 的 endless 分支执行。

func _endless_finish_battle() -> String:
	# 贡献度聚合：输出+承伤+(治疗+护盾)/0.6+控制秒×折算+增益
	var contribution: Dictionary = endless_state.contribution
	for entry in battle_stats.values():
		if str(entry.get("team", "")) != "player": continue
		var hero_id := str(entry.get("hero_id", ""))
		if hero_id.is_empty() or not heroes.has(hero_id): continue
		if not contribution.has(hero_id): contribution[hero_id] = {"contrib": 0.0, "rounds": 0}
		var record: Dictionary = contribution[hero_id]
		record.contrib = float(record.contrib) + float(entry.get("damage", 0.0)) + float(entry.get("taken", 0.0)) \
			+ (float(entry.get("healing", 0.0)) + float(entry.get("shield", 0.0))) / EndlessRules.HEAL_SHIELD_DIVISOR \
			+ float(entry.get("control", 0.0)) * EndlessRules.CONTROL_VALUE_PER_SECOND + float(entry.get("buff", 0.0))
		record.rounds = int(record.rounds) + 1
	endless_state.contribution = contribution
	# 连续存活层数（百战余生；阵亡失去一半）
	var streaks: Dictionary = endless_state.survival_streak
	for unit in player_units:
		var hero_id := str(unit.hero_id)
		if unit.alive and int(unit.row) >= 0:
			streaks[hero_id] = int(streaks.get(hero_id, 0)) + 1
		elif streaks.has(hero_id) and not unit.alive:
			streaks[hero_id] = int(streaks[hero_id]) / 2
	endless_state.survival_streak = streaks
	# 破阵（斩首）：敌主归零即本回合胜利
	if enemy_ruler_hp <= 0 and player_ruler_hp > 0:
		var bonus := 100 + 20 * EndlessRules.checkpoint_index_of(round_number)
		general_souls += bonus
		endless_state.breakthrough_action = true
		endless_state.coupon = true
		var flag_gold := int(_endless_strategy_param("flagcapture", "gold"))
		if flag_gold > 0: _earn_gold(flag_gold, "破阵夺旗")
		_save_progression()
		_log("[color=#f6c860]【破阵】敌军主公授首！将魂 +%d；下回合全军 +20 初始行动条；获得军府八折券一张。[/color]" % bonus)
	# 阵亡敌将清理（下一回合由导演补员）
	for index in range(enemy_units.size() - 1, -1, -1):
		if not enemy_units[index].alive: enemy_units.erase(index)
	if player_ruler_hp <= 0:
		_endless_end_run(false)
		return "over"
	var checkpoint := _endless_checkpoint_of_round(round_number)
	if checkpoint > 0:
		_endless_open_checkpoint(checkpoint)
		return "checkpoint"
	return "advance"

func _endless_open_checkpoint(checkpoint: int) -> void:
	endless_state.checkpoint_index = maxi(int(endless_state.checkpoint_index), checkpoint)
	endless_state.checkpoint_round = round_number
	endless_state.checkpoint_refreshed = false
	endless_state.strategy_pending_pick = false
	endless_total_checkpoints += 1
	var souls := EndlessRules.checkpoint_soul_reward(checkpoint)
	general_souls += souls
	# 将印掉落（据点 3 起；恒偶数严格五五分）
	var drop_line := ""
	if checkpoint >= 3:
		var total := EndlessRules.checkpoint_imprint_count(checkpoint)
		var universal_count := total / 2
		var hero_count := total / 2
		universal_imprints += universal_count
		var attributed: Array[String] = []
		for index in hero_count:
			var hero_id := _endless_draw_contribution_hero()
			hero_imprints[hero_id] = int(hero_imprints.get(hero_id, 0)) + 1
			attributed.append(_hero_name(hero_id))
		drop_line = "；将印 +%d（通用 %d、专属 %d → %s）" % [total, universal_count, hero_count, "、".join(attributed) if not attributed.is_empty() else "—"]
	_save_progression()
	# 军势抽取（据点 6 起每次 2 条）
	var draws := 2 if checkpoint >= 6 else 1
	var momentum_names: Array[String] = []
	for index in draws:
		var drawn := _endless_draw_momentum()
		if drawn.is_empty(): break
		var entry := _endless_momentum_entry(drawn)
		momentum_names.append("%s Lv%d" % [str(entry.get("name", drawn)), int(endless_state.momentum[drawn])])
	# 战策候选（免费三选一）
	_endless_roll_strategy_candidates()
	phase = "checkpoint"
	endless_last_summary = {
		"checkpoint": checkpoint, "round": round_number, "souls": souls,
		"momentum": momentum_names, "can_triumph": checkpoint >= 3
	}
	_log("[color=#f6c860]【据点 %d · 第 %d 回合】奖励已锁定：将魂 +%d%s[/color]" % [checkpoint, round_number, souls, drop_line])
	if not momentum_names.is_empty():
		_log("[color=#e8916d]【军势公示】敌军获得：%s[/color]" % "、".join(momentum_names))
	if checkpoint == 3:
		_log("[color=#f6c860]【首次远征完成】将印开始掉落。可以凯旋结算，或继续远征！[/color]")

func _endless_checkpoint_payload() -> Dictionary:
	return {
		"checkpoint": int(endless_state.checkpoint_index),
		"round": int(round_number),
		"souls": int(endless_last_summary.get("souls", 0)),
		"momentum": endless_last_summary.get("momentum", []),
		"can_triumph": int(endless_state.checkpoint_index) >= 3,
		"candidates": _endless_candidate_entries(),
		"refreshed": bool(endless_state.checkpoint_refreshed),
		"contribution": _endless_contribution_ranking(),
		"junfu": _endless_junfu_entries()
	}

func _endless_draw_contribution_hero() -> String:
	# 抽取权重 = 85%×最终权重 + 15%÷合格武将数；最终权重 = 75%×贡献占比 + 25%×参战回合占比
	var contribution: Dictionary = endless_state.contribution
	var qualified: Array = (contribution as Dictionary).keys().filter(func(hero_id): return heroes.has(str(hero_id)))
	if qualified.is_empty():
		var pool: Array = heroes.keys().filter(func(hero_id): return not _imprint_fully_lit(str(hero_id)))
		if pool.is_empty(): pool = heroes.keys()
		return _endless_pick(pool)
	var total_contrib := 0.0
	var total_rounds := 0
	for hero_id in qualified:
		total_contrib += float(contribution[hero_id].contrib)
		total_rounds += int(contribution[hero_id].rounds)
	if total_contrib <= 0.0 or total_rounds <= 0:
		return str(qualified[_endless_randi_range(0, qualified.size() - 1)])
	var weights: Array = []
	var weight_sum := 0.0
	for hero_id in qualified:
		var record: Dictionary = contribution[hero_id]
		var final_weight := EndlessRules.CONTRIB_BATTLE_WEIGHT * (float(record.contrib) / total_contrib) \
			+ EndlessRules.ROUND_BATTLE_WEIGHT * (float(record.rounds) / float(total_rounds))
		var weight := EndlessRules.DRAW_BASE_WEIGHT * final_weight + EndlessRules.DRAW_FLOOR_WEIGHT / float(qualified.size())
		weights.append(weight)
		weight_sum += weight
	var roll := _endless_randf() * weight_sum
	var accumulated := 0.0
	for index in weights.size():
		accumulated += float(weights[index])
		if roll <= accumulated: return str(qualified[index])
	return str(qualified.back())

func _endless_contribution_ranking() -> Array:
	var ranking: Array = []
	for hero_id in endless_state.contribution:
		var record: Dictionary = endless_state.contribution[hero_id]
		ranking.append({"hero_id": str(hero_id), "name": _hero_name(str(hero_id)), "contrib": float(record.contrib), "rounds": int(record.rounds)})
	ranking.sort_custom(func(a, b): return float(a.contrib) > float(b.contrib))
	return ranking.slice(0, 8)

# ---- 军势（§2.4）----

func _endless_momentum_entry(id: String) -> Dictionary:
	for entry in EndlessRules.MOMENTUM_POOL:
		if str(entry.id) == id: return entry
	return {}

func _endless_momentum_level(id: String) -> int:
	return int(endless_state.momentum.get(id, 0))

func _endless_momentum_param(id: String, key: String) -> float:
	var level := _endless_momentum_level(id)
	if level <= 0: return 0.0
	var levels: Array = _endless_momentum_entry(id).get("levels", [])
	if levels.size() < level: return 0.0
	return float(levels[level - 1].get(key, 0.0))

func _endless_draw_momentum() -> String:
	var pool: Array = []
	for entry in EndlessRules.MOMENTUM_POOL:
		var id := str(entry.id)
		var level := _endless_momentum_level(id)
		if level >= 3: continue
		if int(endless_state.checkpoint_index) < int(EndlessRules.MOMENTUM_LATE_UNLOCK.get(id, 0)): continue
		pool.append(id)
	if pool.is_empty(): return ""
	var chosen := _endless_pick(pool)
	endless_state.momentum[chosen] = _endless_momentum_level(chosen) + 1
	return chosen

# ---- 统帅事件（§2.5）----

func _endless_event_entry(id: String) -> Dictionary:
	for entry in EndlessRules.COMMANDER_EVENTS:
		if str(entry.id) == id: return entry
	return {}

func _endless_event_name(id: String) -> String:
	return str(_endless_event_entry(id).get("name", id))

func _endless_event_desc(id: String) -> String:
	return str(_endless_event_entry(id).get("desc", ""))

# ---- 战策（§3.2）----

func _endless_strategy_entry(id: String) -> Dictionary:
	for entry in EndlessRules.STRATEGY_POOL:
		if str(entry.id) == id: return entry
	return {}

func _endless_strategy_name(id: String) -> String:
	return str(_endless_strategy_entry(id).get("name", id))

func _endless_strategy_level(id: String) -> int:
	return int(endless_state.strategies.get(id, 0))

func _endless_has_strategy(id: String) -> bool:
	return _endless_strategy_level(id) > 0

func _endless_strategy_param(id: String, key: String) -> float:
	var level := _endless_strategy_level(id)
	if level <= 0: return 0.0
	var levels: Array = _endless_strategy_entry(id).get("levels", [])
	if levels.size() < level: return 0.0
	return float(levels[level - 1].get(key, 0.0))

func _endless_roll_strategy_candidates() -> void:
	var pool: Array = []
	for entry in EndlessRules.STRATEGY_POOL:
		var id := str(entry.id)
		if _endless_strategy_level(id) >= 3: continue
		pool.append(id)
	var candidates: Array = []
	while candidates.size() < 3 and not pool.is_empty():
		var chosen := _endless_pick(pool)
		pool.erase(chosen)
		candidates.append(chosen)
	endless_state.checkpoint_strategy_ids = candidates
	endless_state.strategy_pending_pick = not candidates.is_empty()

func _endless_candidate_entries() -> Array:
	var result: Array = []
	for id in endless_state.checkpoint_strategy_ids:
		var entry := _endless_strategy_entry(str(id))
		var level := _endless_strategy_level(str(id))
		var levels: Array = entry.get("levels", [])
		var next_level := clampi(level + 1, 1, 3)
		var desc := ""
		if not levels.is_empty(): desc = str(levels[mini(next_level - 1, levels.size() - 1)].get("desc", ""))
		result.append({"id": str(id), "name": str(entry.get("name", id)), "level": level, "desc": desc, "maxed": level >= 3})
	return result

func _endless_pick_strategy(id: String) -> bool:
	if not endless_state.checkpoint_strategy_ids.has(id): return false
	var level := _endless_strategy_level(id)
	if level >= 3: return false
	endless_state.strategies[id] = level + 1
	endless_state.strategy_pending_pick = false
	_log("[color=#8fd4a0]【战策】获得【%s】%d 级。[/color]" % [_endless_strategy_name(id), level + 1])
	match id:
		"brainstorm":
			endless_state.brainstorm_left = int(_endless_strategy_param("brainstorm", "rounds"))
		"leadcharge":
			var gain := int(round(float(_player_ruler_max_hp()) * _endless_strategy_param("leadcharge", "pct")))
			player_ruler_hp = int(minf(float(_player_ruler_max_hp()), float(player_ruler_hp) + gain))
			_log("[color=#8fd4a0]【身先士卒】主公生命上限提高并立即回复 %d。[/color]" % gain)
	return true

func _endless_refresh_strategy_candidate() -> bool:
	if bool(endless_state.checkpoint_refreshed): return false
	var current: Array = endless_state.checkpoint_strategy_ids
	if current.is_empty(): return false
	var pool: Array = []
	for entry in EndlessRules.STRATEGY_POOL:
		var id := str(entry.id)
		if _endless_strategy_level(id) >= 3: continue
		if current.has(id): continue
		pool.append(id)
	if pool.is_empty(): return false
	endless_state.checkpoint_refreshed = true
	var chosen := _endless_pick(pool)
	if current.size() >= 3:
		current[0] = chosen
	else:
		current.append(chosen)
	endless_state.checkpoint_strategy_ids = current
	endless_state.strategy_pending_pick = true
	return true

# ---- 军府整备（§3.3）----

func _endless_junfu_entry(id: String) -> Dictionary:
	for entry in EndlessRules.JUNFU_ITEMS:
		if str(entry.id) == id: return entry
	return {}

func _endless_junfu_price(id: String, hero_id := "") -> int:
	var entry := _endless_junfu_entry(id)
	if entry.is_empty(): return 0
	var cost := int(entry.base_cost)
	if entry.has("increment"):
		if entry.has("per_hero_cap"):
			cost += int(entry.increment) * _endless_junfu_hero_stacks(id, hero_id)
		else:
			cost += int(entry.increment) * int(endless_state.junfu_global.get(id, 0))
	return cost

func _endless_junfu_hero_stacks(id: String, hero_id: String) -> int:
	return int(endless_state.junfu_hero.get(id, {}).get(hero_id, 0))

func _endless_junfu_uses_left(id: String) -> int:
	var entry := _endless_junfu_entry(id)
	var per := int(entry.get("per_checkpoint", -1))
	if per < 0: return 999
	return per - int(endless_state.junfu_global.get(id, 0))

func _endless_junfu_entries() -> Array:
	var result: Array = []
	for entry in EndlessRules.JUNFU_ITEMS:
		var id := str(entry.id)
		result.append({
			"id": id, "name": str(entry.name), "desc": str(entry.desc),
			"price": _endless_junfu_price(id), "uses_left": _endless_junfu_uses_left(id),
			"needs_hero": entry.has("per_hero_cap")
		})
	return result

func _endless_buy_junfu(id: String, hero_id := "") -> bool:
	if not _run_is_endless() or phase != "checkpoint": return false
	var entry := _endless_junfu_entry(id)
	if entry.is_empty(): return false
	if entry.has("per_hero_cap") and (hero_id.is_empty() or not heroes.has(hero_id)): return false
	if _endless_junfu_uses_left(id) <= 0: return false
	if entry.has("per_hero_cap") and _endless_junfu_hero_stacks(id, hero_id) >= int(entry.per_hero_cap):
		_log("[color=#e07070]该武将的军府强化已达层数上限。[/color]")
		return false
	endless_battle.erase("im_cache")   # 军府层数改写聚合结果，先失效缓存
	var price := _endless_junfu_price(id, hero_id)
	var paid := price
	if bool(endless_state.coupon):
		paid = int(round(float(price) * 0.8))
	if not _spend_gold(paid, "军府·%s" % str(entry.name)): return false
	if bool(endless_state.coupon):
		endless_state.coupon = false
		_log("[color=#e5a8ff]已使用军府八折券。[/color]")
	endless_state.junfu_global[id] = int(endless_state.junfu_global.get(id, 0)) + 1
	match id:
		"rest":
			var ruler_max := float(_player_ruler_max_hp())
			var healed := int(round(ruler_max * 0.08))
			player_ruler_hp = int(minf(ruler_max, float(player_ruler_hp) + healed))
			_log("[color=#8fd4a0]【休养主公】主公回复 %d 生命。[/color]" % healed)
		"libing", "moma", "jixing":
			var hero_stacks: Dictionary = endless_state.junfu_hero.get(id, {})
			hero_stacks[hero_id] = _endless_junfu_hero_stacks(id, hero_id) + 1
			endless_state.junfu_hero[id] = hero_stacks
			for unit in player_units:
				if str(unit.hero_id) == hero_id and str(unit.team) == "player":
					_endless_apply_junfu_to_unit(unit)
		"reorganize":
			endless_state.rearguard_ready = true
			_log("[color=#8fd4a0]【重整】下一回合主公首次致命伤害将保留 1 点。[/color]")
		"recruit":
			endless_state.recruit_extra = 1
			_log("[color=#8fd4a0]【求贤】下一回合整备额外一次三选一。[/color]")
		"revive":
			if not _endless_revive_hero():
				endless_state.junfu_global[id] = int(endless_state.junfu_global.get(id, 0)) - 1
				gold += paid
				_log("[color=#e07070]没有可复活的阵亡武将。[/color]")
				return false
	return true

func _endless_apply_junfu_to_unit(unit: Dictionary) -> void:
	# 军府层数与将印同源注入 im；成长折算有幂等护栏，生命按增量标量重放
	unit.im = _imprint_mod(str(unit.hero_id))
	_endless_apply_round_growth(unit)

func _endless_revive_hero() -> bool:
	for index in range(player_units.size() - 1, -1, -1):
		var unit: Dictionary = player_units[index]
		if unit.alive: continue
		unit.alive = true
		unit.hp = float(unit.max_hp) * 0.5
		unit.row = -1
		unit.col = -1
		_log("[color=#8fd4a0]【还魂】%s 以 50%% 生命重返备战席。[/color]" % _hero_name(str(unit.hero_id)))
		return true
	return false

func _endless_checkpoint_continue() -> bool:
	if phase != "checkpoint": return false
	if bool(endless_state.strategy_pending_pick) and not (endless_state.checkpoint_strategy_ids as Array).is_empty():
		_log("[color=#e07070]请先选择一条战策（或刷新后再选）。[/color]")
		return false
	endless_state.junfu_global = {}
	endless_state.checkpoint_strategy_ids = []
	_endless_convert_leftover_tianshu()
	return true

func _endless_checkpoint_triumph() -> void:
	if phase != "checkpoint": return
	_endless_end_run(true)

# ---- 终局结算 ----

func _endless_end_run(triumph: bool) -> void:
	endless_state.run_over = true
	endless_state.triumphed = triumph
	var record_broken := round_number > endless_best_round
	var record_imprints := 0
	if record_broken:
		endless_best_round = round_number
		endless_best_lineup = []
		for unit in player_units:
			if unit.alive and int(unit.row) >= 0:
				endless_best_lineup.append({"hero_id": str(unit.hero_id)})
		if not bool(endless_state.record_bonus_given):
			endless_state.record_bonus_given = true
			universal_imprints += EndlessRules.IMPRINT_RECORD_BONUS_UNIVERSAL
			var record_hero := _endless_draw_contribution_hero()
			hero_imprints[record_hero] = int(hero_imprints.get(record_hero, 0)) + EndlessRules.IMPRINT_RECORD_BONUS_HERO
			record_imprints = 2
	_save_progression()
	phase = "finished"
	_log("[color=#f6c860]【远征结束】%s结算至据点 %d；存活 %d 回合%s。[/color]" % [
		"凯旋" if triumph else "战败", int(endless_state.checkpoint_index), round_number,
		"；刷新最高纪录！" if record_broken else ""])
	var endless_dir := DirAccess.open("user://")
	if endless_dir != null and FileAccess.file_exists(EndlessRules.ENDLESS_SAVE_PATH):
		endless_dir.remove(EndlessRules.ENDLESS_SAVE_PATH.get_file())
	pending_battle_result = {
		"endless": true, "victory": triumph, "triumph": triumph, "round": round_number,
		"checkpoint": int(endless_state.checkpoint_index), "record_broken": record_broken,
		"record_imprints": record_imprints, "contribution": _endless_contribution_ranking()
	}
	call_deferred("_show_battle_result", (pending_battle_result as Dictionary).duplicate(true))

# ---- 无尽单局存档 ----

func _endless_save_state() -> Dictionary:
	return (endless_state as Dictionary).duplicate(true)

func _load_endless_state(value) -> void:
	if not (value is Dictionary): return
	var loaded: Dictionary = value
	_reset_endless_defaults()
	for key in (endless_state as Dictionary).keys():
		if loaded.has(key): endless_state[key] = loaded[key]
	_endless_reseed()

func _endless_run_snapshot() -> Dictionary:
	if not FileAccess.file_exists(EndlessRules.ENDLESS_SAVE_PATH): return {}
	var file := FileAccess.open(EndlessRules.ENDLESS_SAVE_PATH, FileAccess.READ)
	if file == null: return {}
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY: return {}
	if str(data.get("game_mode", "")) != "endless": return {}
	if str(data.get("phase", "")) == "finished": return {}
	var endless_data: Dictionary = data.get("endless", {})
	return {"round": clampi(int(data.get("round_number", 1)), 1, 999999),
		"checkpoint": clampi(int(endless_data.get("checkpoint_index", 0)), 0, 999999)}

# ==================== 将印养成（§4.3/§4.4）====================

func _imprint_tree(hero_id: String) -> Dictionary:
	return ImprintTrees.TREES.get(hero_id, {})

func _imprint_levels(hero_id: String) -> Dictionary:
	return hero_imprint_nodes.get(hero_id, {})

func _imprint_level(hero_id: String, node_key: String) -> int:
	return int(_imprint_levels(hero_id).get(node_key, 0))

func _im_level_total(value, level: int) -> float:
	# 数组值 = 每级增量（总值 = 前 N 级求和）；标量值 = 数值 × 等级
	if value is Array:
		var total := 0.0
		for index in mini(maxi(0, level), (value as Array).size()):
			total += float((value as Array)[index])
		return total
	return float(value) * float(maxi(0, level))

func _imprint_node_max_level(hero_id: String, node_key: String) -> int:
	var tree := _imprint_tree(hero_id)
	if tree.is_empty(): return 0
	match node_key.split(":")[0]:
		"root": return 3
		"role": return 2
		"skill":
			var nodes: Array = tree.get("skill", [])
			var index := int(node_key.split(":")[1])
			if index < 0 or index >= nodes.size(): return 0
			return int(nodes[index].get("max", 1))
		"branch": return 1
		"bond": return 2
		"evergreen": return 2
		"soul": return 1
	return 0

func _imprint_node_name(hero_id: String, node_key: String) -> String:
	var tree := _imprint_tree(hero_id)
	if tree.is_empty(): return node_key
	match node_key.split(":")[0]:
		"root":
			var names: Array = tree.get("root", [])
			var slot := ["hp", "strategy", "swift"].find(node_key.split(":")[1])
			if slot >= 0 and slot < names.size(): return str(names[slot])
		"role", "skill", "branch":
			var nodes: Array = tree.get(str(node_key.split(":")[0]), [])
			var index := int(node_key.split(":")[1])
			if index >= 0 and index < nodes.size(): return str(nodes[index].get("name", node_key))
		"bond": return str(tree.get("bond", {}).get("name", node_key))
		"evergreen": return str(tree.get("evergreen", {}).get("name", node_key))
		"soul": return str(tree.get("soul", {}).get("name", node_key))
	return node_key

func _imprint_node_desc(hero_id: String, node_key: String) -> String:
	var tree := _imprint_tree(hero_id)
	if tree.is_empty(): return ""
	match node_key.split(":")[0]:
		"root":
			var root_class := str(tree.get("root_class", "output"))
			var bonus: Dictionary = EndlessRules.ROOT_CLASS_BONUS.get(root_class, EndlessRules.ROOT_CLASS_BONUS.output)
			match node_key:
				"root:hp": return "生命 +%d%%/级（乘区：天赋符文之后）" % int(round(float(bonus.hp) * 100.0))
				"root:strategy": return "兵略 +%d%%/级（乘区：天赋符文之后）" % int(round(float(bonus.strategy) * 100.0))
				"root:swift": return ImprintTrees.ROOT_SWIFT_NOTE
		"role", "skill", "branch":
			var nodes: Array = tree.get(str(node_key.split(":")[0]), [])
			var index := int(node_key.split(":")[1])
			if index >= 0 and index < nodes.size(): return str(nodes[index].get("desc", ""))
		"bond": return str(tree.get("bond", {}).get("desc", ""))
		"evergreen": return str(tree.get("evergreen", {}).get("desc", ""))
		"soul": return str(tree.get("soul", {}).get("desc", ""))
	return ""

func _imprint_node_effects(hero_id: String, node_key: String) -> Dictionary:
	var tree := _imprint_tree(hero_id)
	if tree.is_empty(): return {}
	match node_key.split(":")[0]:
		"role", "skill", "branch":
			var nodes: Array = tree.get(str(node_key.split(":")[0]), [])
			var index := int(node_key.split(":")[1])
			if index >= 0 and index < nodes.size(): return nodes[index].get("effects", {})
		"bond": return tree.get("bond", {}).get("effects", {})
		"evergreen": return tree.get("evergreen", {}).get("effects", {})
		"soul": return tree.get("soul", {}).get("effects", {})
	return {}

func _imprint_node_cost(node_key: String) -> int:
	return int(EndlessRules.IMPRINT_NODE_COSTS.get(node_key.split(":")[0], 1))

func _imprint_invested_levels(hero_id: String) -> int:
	var total := 0
	for node_key in _imprint_levels(hero_id):
		total += _imprint_level(hero_id, str(node_key))
	return total

func _imprint_distinct_layer_count(hero_id: String, layer: String) -> int:
	var count := 0
	for index in 3:
		if _imprint_level(hero_id, "%s:%d" % [layer, index]) > 0: count += 1
	return count

func _imprint_distinct_branch(hero_id: String) -> String:
	for index in 2:
		if _imprint_level(hero_id, "branch:%d" % index) > 0: return "branch:%d" % index
	return ""

func _imprint_can_unlock_layer(hero_id: String, layer: String) -> bool:
	match layer:
		"root": return true
		"role":
			var root_points := 0
			for key in ["root:hp", "root:strategy", "root:swift"]:
				root_points += _imprint_level(hero_id, key)
			return root_points >= 3
		"skill": return _imprint_distinct_layer_count(hero_id, "role") >= 1
		"branch": return _imprint_distinct_layer_count(hero_id, "skill") >= 2
		"bond": return _imprint_distinct_branch(hero_id) != ""
		"evergreen": return _imprint_level(hero_id, "bond") >= 1
		"soul": return _imprint_level(hero_id, "evergreen") >= 1
	return false

func _imprint_layer_locked_hint(hero_id: String, layer: String) -> String:
	if _imprint_can_unlock_layer(hero_id, layer): return ""
	match layer:
		"role": return "需根基投入 ≥3 级"
		"skill": return "需点亮任一定位节点"
		"branch": return "需点亮两个绝技节点"
		"bond": return "需完成分歧二选一"
		"evergreen": return "需羁绊 ≥1 级"
		"soul": return "需长青 ≥1 级"
	return ""

func _imprint_can_upgrade(hero_id: String, node_key: String) -> bool:
	if not heroes.has(hero_id) or _imprint_tree(hero_id).is_empty(): return false
	var layer := node_key.split(":")[0]
	var level := _imprint_level(hero_id, node_key)
	if layer != "root" and not _imprint_can_unlock_layer(hero_id, layer): return false
	if level >= _imprint_node_max_level(hero_id, node_key): return false
	# 定位/绝技 3 选 2；分歧 2 选 1
	if (layer == "role" or layer == "skill") and level == 0 and _imprint_distinct_layer_count(hero_id, layer) >= 2: return false
	if layer == "branch" and level == 0 and _imprint_distinct_branch(hero_id) != "": return false
	var cost := _imprint_node_cost(node_key)
	var exclusive := int(hero_imprints.get(hero_id, 0))
	if imprint_exclusive_only and exclusive < cost: return false
	return exclusive + universal_imprints >= cost

func _imprint_upgrade(hero_id: String, node_key: String) -> bool:
	if not _imprint_can_upgrade(hero_id, node_key): return false
	endless_battle.erase("im_cache")   # 点亮即失效聚合缓存，随后的 unit.im 注入拿到新值
	var cost := _imprint_node_cost(node_key)
	var exclusive := int(hero_imprints.get(hero_id, 0))
	var from_exclusive := mini(exclusive, cost)
	var from_universal := cost - from_exclusive
	if imprint_exclusive_only and from_universal > 0: return false
	hero_imprints[hero_id] = exclusive - from_exclusive
	universal_imprints -= from_universal
	if not hero_imprint_nodes.has(hero_id): hero_imprint_nodes[hero_id] = {}
	var nodes: Dictionary = hero_imprint_nodes[hero_id]
	nodes[node_key] = _imprint_level(hero_id, node_key) + 1
	if not hero_imprint_spent.has(hero_id): hero_imprint_spent[hero_id] = {"exclusive": 0, "universal": 0}
	var spent: Dictionary = hero_imprint_spent[hero_id]
	spent.exclusive = int(spent.exclusive) + from_exclusive
	spent.universal = int(spent.universal) + from_universal
	_save_progression()
	for unit in player_units:
		if str(unit.hero_id) == hero_id and str(unit.team) == "player":
			_endless_apply_junfu_to_unit(unit)
	return true

func _imprint_reset_cost(hero_id: String) -> int:
	return _imprint_invested_levels(hero_id) * EndlessRules.IMPRINT_RESET_SOUL_PER_NODE

func _imprint_reset_tree(hero_id: String) -> bool:
	var cost := _imprint_reset_cost(hero_id)
	if cost <= 0: return false
	if general_souls < cost: return false
	endless_battle.erase("im_cache")
	general_souls -= cost
	var spent: Dictionary = hero_imprint_spent.get(hero_id, {"exclusive": 0, "universal": 0})
	hero_imprints[hero_id] = int(hero_imprints.get(hero_id, 0)) + int(spent.get("exclusive", 0))
	universal_imprints += int(spent.get("universal", 0))
	hero_imprint_nodes.erase(hero_id)
	hero_imprint_spent[hero_id] = {"exclusive": 0, "universal": 0}
	_save_progression()
	for unit in player_units:
		if str(unit.hero_id) == hero_id and str(unit.team) == "player":
			unit.im = _imprint_mod(hero_id)
			_endless_apply_junfu_to_unit(unit)
	_log("[color=#e5c97a]将印树已重置：消耗将魂 %d，返还专属 %d、通用 %d。[/color]" % [cost, int(spent.get("exclusive", 0)), int(spent.get("universal", 0))])
	return true

func _imprint_swift_mode(hero_id: String) -> String:
	return str(hero_imprint_swift.get(hero_id, "auto"))

func _imprint_toggle_swift(hero_id: String) -> void:
	endless_battle.erase("im_cache")
	var order := ["auto", "cooldown", "action"]
	var current := order.find(_imprint_swift_mode(hero_id))
	hero_imprint_swift[hero_id] = order[(current + 1) % order.size()]
	_save_progression()

func _add_debug_imprints() -> void:
	# 调试工具：将印不足时快速补充通用将印（仅调试包/编辑器可见入口）
	universal_imprints += 1000
	_save_progression()

func _imprint_fully_lit(hero_id: String) -> bool:
	if _imprint_tree(hero_id).is_empty(): return false
	for key in ["root:hp", "root:strategy", "root:swift"]:
		if _imprint_level(hero_id, key) < 3: return false
	if _imprint_distinct_layer_count(hero_id, "role") < 2: return false
	for index in 3:
		if _imprint_level(hero_id, "role:%d" % index) > 0 and _imprint_level(hero_id, "role:%d" % index) < 2: return false
	if _imprint_distinct_layer_count(hero_id, "skill") < 2: return false
	for index in 3:
		if _imprint_level(hero_id, "skill:%d" % index) > 0 and _imprint_level(hero_id, "skill:%d" % index) < _imprint_node_max_level(hero_id, "skill:%d" % index): return false
	if _imprint_distinct_branch(hero_id) == "": return false
	if _imprint_level(hero_id, "bond") < 2: return false
	if _imprint_level(hero_id, "evergreen") < 2: return false
	if _imprint_level(hero_id, "soul") < 1: return false
	return true

# ---- 将印效果聚合（战斗开局注入 unit.im；菜单预览也用）----

func _imprint_mod(hero_id: String) -> Dictionary:
	var cache: Dictionary = endless_battle.get("im_cache", {})
	if cache.has(hero_id): return (cache[hero_id] as Dictionary).duplicate(true)
	var mod := {}
	var tree := _imprint_tree(hero_id)
	if not tree.is_empty():
		var levels := _imprint_levels(hero_id)
		var root_class := str(tree.get("root_class", "output"))
		var root_bonus: Dictionary = EndlessRules.ROOT_CLASS_BONUS.get(root_class, EndlessRules.ROOT_CLASS_BONUS.output)
		mod.hp_pct = float(root_bonus.hp) * float(levels.get("root:hp", 0))
		mod.strategy_pct = float(root_bonus.strategy) * float(levels.get("root:strategy", 0))
		# 疾行：+冷却极速/级（实际冷却=原冷却×100/(100+极速)，收益递减无上限）；
		# 无冷却武将恒为行动增速，有冷却武将也可在将印面板手动切为行动增速。
		var swift_level := int(levels.get("root:swift", 0))
		var original_cooldown := float(heroes[hero_id].cooldown)
		var mode := _imprint_swift_mode(hero_id)
		var swift_as_action := original_cooldown <= 0.05 or mode == "action"
		if swift_level > 0:
			if swift_as_action:
				mod.action_gain_pct = float(EndlessRules.IMPRINT_ROOT_SWIFT_ACTION) * swift_level
			else:
				mod.cooldown_haste_add = float(EndlessRules.IMPRINT_ROOT_SWIFT_HASTE) * swift_level
		for node_key in levels:
			var level := int(levels[node_key])
			if level <= 0: continue
			var effects := _imprint_node_effects(hero_id, str(node_key))
			for keyword in effects:
				if str(keyword).begins_with("_"): continue
				mod[keyword] = float(mod.get(keyword, 0.0)) + _im_level_total(effects[keyword], level)
		_endless_mark_evergreen_caps(mod)
		# 军府层数（本局）
		mod.max_hp_pct = float(mod.get("max_hp_pct", 0.0)) + 0.06 * _endless_junfu_hero_stacks("libing", hero_id)
		mod.strategy_flat_add = float(mod.get("strategy_flat_add", 0.0)) + 5.0 * _endless_junfu_hero_stacks("moma", hero_id)
		mod.cooldown_flat_add = float(mod.get("cooldown_flat_add", 0.0)) - 0.25 * _endless_junfu_hero_stacks("jixing", hero_id)
	cache[hero_id] = mod.duplicate(true)
	endless_battle.im_cache = cache
	return mod

func _endless_mark_evergreen_caps(mod: Dictionary) -> void:
	# 整局长青（round_*）搬入 _round_* 通道，由 _endless_apply_round_growth 按回合折算（上限 10 倍）
	if float(mod.get("round_hp_pct", 0.0)) > 0.0:
		mod._round_hp_pct = mod.round_hp_pct
		mod._round_hp_cap = float(mod.round_hp_pct) * 10.0
		mod.erase("round_hp_pct")
	if float(mod.get("round_damage_pct", 0.0)) > 0.0:
		mod._round_damage_pct = mod.round_damage_pct
		mod._round_damage_cap = float(mod.round_damage_pct) * 10.0
		mod.erase("round_damage_pct")
	if float(mod.get("round_heal_pct", 0.0)) > 0.0:
		mod._round_heal_pct = mod.round_heal_pct
		mod._round_heal_cap = float(mod.round_heal_pct) * 10.0
		mod.erase("round_heal_pct")
	if float(mod.get("round_aura_pct", 0.0)) > 0.0:
		mod._round_aura_pct = mod.round_aura_pct
		mod._round_aura_cap = float(mod.round_aura_pct) * 10.0
		mod.erase("round_aura_pct")
	if float(mod.get("round_aura_cooldown_add", 0.0)) > 0.0:
		mod._round_aura_cd = mod.round_aura_cooldown_add
		mod._round_aura_cd_cap = float(mod.round_aura_cooldown_add) * 10.0
		mod.erase("round_aura_cooldown_add")
	# 成长上限扩展与成长共享（近似映射）
	if float(mod.get("max_hp_growth_cap_add", 0.0)) > 0.0 and float(mod.get("_round_hp_cap", 0.0)) > 0.0:
		mod._round_hp_cap = float(mod._round_hp_cap) + float(mod.max_hp_growth_cap_add)
	if float(mod.get("maxhp_growth_share", 0.0)) > 0.0:
		mod.max_hp_pct = float(mod.get("max_hp_pct", 0.0)) + float(mod.maxhp_growth_share)

func _im(unit: Dictionary) -> Dictionary:
	return unit.get("im", {})

func _imget(unit: Dictionary, key: String, default := 0.0) -> float:
	return float(_im(unit).get(key, default))

# 生命第二乘区：以 endless_base_max_hp 为基线累加无尽加成比例，等比保留当前生命
func _endless_hp_scalar(unit: Dictionary, add_pct: float) -> void:
	if add_pct <= 0.0: return
	var old_total := float(unit.get("endless_hp_scalar", 0.0))
	var base := float(unit.get("endless_base_max_hp", 0.0))
	if base <= 0.0:
		base = float(unit.max_hp) / (1.0 + old_total)
		unit.endless_base_max_hp = base
	var new_total := old_total + add_pct
	unit.max_hp = base * (1.0 + new_total)
	unit.hp = clampf(float(unit.hp) * (1.0 + new_total) / (1.0 + old_total), 1.0, float(unit.max_hp))
	unit.endless_hp_scalar = new_total

func _endless_apply_round_growth(unit: Dictionary) -> void:
	# 长青整局成长按已存活回合折算入静态聚合（幂等：_growth_folded 护栏）
	var im: Dictionary = unit.get("im", {})
	if im.is_empty() or int(im.get("_growth_folded", 0)) > 0: return
	im._growth_folded = 1
	var survived := maxi(0, round_number - 1)
	im.max_hp_pct = float(im.get("max_hp_pct", 0.0)) + minf(float(im.get("_round_hp_pct", 0.0)) * survived, float(im.get("_round_hp_cap", 0.0)))
	im.damage_pct = float(im.get("damage_pct", 0.0)) + minf(float(im.get("_round_damage_pct", 0.0)) * survived, float(im.get("_round_damage_cap", 0.0)))
	im.heal_pct = float(im.get("heal_pct", 0.0)) + minf(float(im.get("_round_heal_pct", 0.0)) * survived, float(im.get("_round_heal_cap", 0.0)))
	im.skill_effect_pct = float(im.get("skill_effect_pct", 0.0)) + minf(float(im.get("_round_aura_pct", 0.0)) * survived, float(im.get("_round_aura_cap", 0.0)))
	if float(im.get("_round_aura_cd", 0.0)) > 0.0:
		im.aura_cooldown_add = float(im.get("aura_cooldown_add", 0.0)) + minf(float(im._round_aura_cd) * survived, float(im.get("_round_aura_cd_cap", 0.0)))
	var hp_delta := float(im.max_hp_pct) - float(unit.get("endless_hp_im_applied", 0.0))
	if hp_delta > 0.0:
		_endless_hp_scalar(unit, hp_delta)
		unit.endless_hp_im_applied = float(im.max_hp_pct)

# ---- 属性瀑布对比（§4.5 UI 硬需求：基础→+天赋→+符文→×将印→最终）----

func _endless_stat_waterfall(hero_id: String) -> Array:
	var talent := _talent_stat_bonus(hero_id)
	var runes := _rune_stat_bonus(hero_id)
	var im := _imprint_mod(hero_id)
	var applies := _run_is_endless()
	# 预览即所得：无论当前是否在无尽对局，最终值都按将印完整结算（applies 仅用于界面横幅提示）。
	var base_hp := float(heroes[hero_id].hp)
	var talent_hp := float(talent.hp)
	var rune_hp := maxf(float(runes.hp), -base_hp * 0.30)
	var mid_hp := maxf(1.0, base_hp + talent_hp + rune_hp)
	var final_hp := mid_hp * (1.0 + float(im.get("hp_pct", 0.0)))
	var base_strategy := float(heroes[hero_id].skill_value)
	var mid_strategy := base_strategy + float(talent.strategy) + float(runes.strategy)
	var final_strategy := mid_strategy * (1.0 + float(im.get("strategy_pct", 0.0))) + float(im.get("strategy_flat_add", 0.0))
	var original_cooldown := float(heroes[hero_id].cooldown)
	# 冷却极速制：天赋/符文秒数与将印极速统一折入极速池，实际冷却 = 原冷却 × 100/(100+极速)。
	var total_haste := 0.0
	var final_cooldown := 0.0
	if original_cooldown > 0.05:
		# 天赋/符文聚合值已是极速点，直接入池
		var progression_haste := float(talent.cooldown) + float(runes.cooldown)
		var imprint_haste := float(im.get("cooldown_haste_add", 0.0)) + float(im.get("cooldown_channel_pct", 0.0)) * 100.0 + float(im.get("cooldown_flat_add", 0.0)) / original_cooldown * 100.0
		total_haste = progression_haste + imprint_haste
		final_cooldown = maxf(2.0, original_cooldown * 100.0 / (100.0 + total_haste))
	var final_action := 1.0 + float(im.get("action_gain_pct", 0.0))
	return [
		{"key": "hp", "label": "最大生命", "base": base_hp, "talent": talent_hp, "rune": rune_hp, "pct": float(im.get("hp_pct", 0.0)), "final": final_hp, "applies": applies},
		{"key": "strategy", "label": "兵略值", "base": base_strategy, "talent": float(talent.strategy), "rune": float(runes.strategy), "pct": float(im.get("strategy_pct", 0.0)), "flat": float(im.get("strategy_flat_add", 0.0)), "final": final_strategy, "applies": applies},
		{"key": "cooldown", "label": "技能冷却", "base": original_cooldown, "talent": float(talent.cooldown), "rune": float(runes.cooldown), "pct": 0.0, "haste": total_haste, "final": final_cooldown, "applies": applies},
		{"key": "action", "label": "行动增速", "base": 1.0, "talent": 0.0, "rune": 0.0, "pct": float(im.get("action_gain_pct", 0.0)), "final": final_action, "applies": applies}
	]

# ---- 生效路径：单位创建（§4.5，将印生命乘区在创建时即生效）----

func _apply_progression_to_new_unit(unit: Dictionary) -> void:
	super._apply_progression_to_new_unit(unit)
	if str(unit.team) != "player" or not _run_is_endless(): return
	var im := _imprint_mod(str(unit.hero_id))
	unit.endless_base_max_hp = float(unit.max_hp)
	var hp_pct := float(im.get("hp_pct", 0.0))
	if hp_pct > 0.0:
		unit.max_hp = maxf(1.0, float(unit.max_hp) * (1.0 + hp_pct))
		unit.hp = float(unit.max_hp)
	unit.endless_hp_scalar = hp_pct
	unit.endless_hp_im_applied = hp_pct

# ---- 战斗开局钩子（真实实现见 combat_system.gd 末尾；此存根保证 game_flow 可调用）----

func _endless_on_battle_start() -> void:
	pass

# ==================== 进度存档 v2（在 progression 存档上追加将印字段）====================

func _save_progression() -> bool:
	var success: bool = super._save_progression()
	if not success: return false
	var file := FileAccess.open(PROGRESSION_SAVE_PATH, FileAccess.READ)
	if file == null: return true
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY: return true
	var payload: Dictionary = data
	payload.version = 2
	payload.universal_imprints = universal_imprints
	payload.hero_imprints = hero_imprints
	payload.hero_imprint_nodes = hero_imprint_nodes
	payload.hero_imprint_swift = hero_imprint_swift
	payload.hero_imprint_spent = hero_imprint_spent
	payload.endless_best_round = endless_best_round
	payload.endless_best_lineup = endless_best_lineup
	payload.endless_total_runs = endless_total_runs
	payload.endless_total_checkpoints = endless_total_checkpoints
	var write := FileAccess.open(PROGRESSION_SAVE_PATH, FileAccess.WRITE)
	if write == null: return false
	write.store_string(JSON.stringify(payload))
	write.close()
	return true

func _load_progression() -> void:
	super._load_progression()
	if not FileAccess.file_exists(PROGRESSION_SAVE_PATH): return
	var file := FileAccess.open(PROGRESSION_SAVE_PATH, FileAccess.READ)
	if file == null: return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY: return
	var payload: Dictionary = data
	universal_imprints = maxi(0, int(payload.get("universal_imprints", 0)))
	hero_imprints = payload.get("hero_imprints", {}) if payload.get("hero_imprints", {}) is Dictionary else {}
	hero_imprint_nodes = payload.get("hero_imprint_nodes", {}) if payload.get("hero_imprint_nodes", {}) is Dictionary else {}
	hero_imprint_swift = payload.get("hero_imprint_swift", {}) if payload.get("hero_imprint_swift", {}) is Dictionary else {}
	hero_imprint_spent = payload.get("hero_imprint_spent", {}) if payload.get("hero_imprint_spent", {}) is Dictionary else {}
	endless_best_round = maxi(0, int(payload.get("endless_best_round", 0)))
	endless_best_lineup = payload.get("endless_best_lineup", []) if payload.get("endless_best_lineup", []) is Array else []
	endless_total_runs = maxi(0, int(payload.get("endless_total_runs", 0)))
	endless_total_checkpoints = maxi(0, int(payload.get("endless_total_checkpoints", 0)))
	# 清洗非法节点键（版本升级/数据修订后的兜底）
	for hero_id in (hero_imprint_nodes as Dictionary).keys().duplicate():
		if not heroes.has(str(hero_id)) or _imprint_tree(str(hero_id)).is_empty():
			hero_imprint_nodes.erase(hero_id)
			continue
		var nodes: Dictionary = hero_imprint_nodes[hero_id]
		for node_key in (nodes as Dictionary).keys().duplicate():
			var level := int(nodes[node_key])
			if level <= 0 or level > _imprint_node_max_level(str(hero_id), str(node_key)):
				nodes.erase(node_key)
