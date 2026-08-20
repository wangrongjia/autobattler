extends "res://ThreeKingdom/systems/progression_system.gd"

# 天书只在本局有效。独立的天书演武，以及王者/地狱闯关会启用本系统。
const TIANSHU_BOOKS := {
	"pojun":{"name":"破军天章", "en":"Army-Breaking Canon", "group":"通用·进攻", "effects":["所有我方武将兵略值 +8。", "所有我方武将兵略值 +16。"]},
	"fengchi":{"name":"风驰电掣", "en":"Lightning March", "group":"通用·进攻", "effects":["所有我方武将技能冷却减少 0.25 秒。", "所有我方武将技能冷却减少 0.5 秒。"]},
	"xianfa":{"name":"先发制人", "en":"First Strike", "group":"通用·进攻", "effects":["每场战斗开始时，所有我方武将行动条 +10。", "开场行动条加成提高至 +20。"]},
	"chengxu":{"name":"乘虚而入", "en":"Exploit Weakness", "group":"通用·进攻", "effects":["对带有任意减益或控制的敌人伤害提高 10%。", "伤害提高至 20%。"]},
	"canyang":{"name":"残阳血战", "en":"Last-Light Bloodbath", "group":"通用·进攻", "effects":["生命低于 50%时造成伤害提高 12%。", "增伤提高至 24%，并获得 10%全能吸血。"]},
	"zhanjiang":{"name":"斩将夺势", "en":"Slay and Seize", "group":"通用·进攻", "effects":["击杀后行动条 +15，每场最多 3 次。", "行动条 +25、本回合兵略 +5，每场最多 5 次。"]},
	"tianbing":{"name":"天兵赐力", "en":"Celestial Vigor", "group":"通用·生存", "effects":["所有我方武将最大生命提高 8%。", "最大生命提高至 16%。"]},
	"tiebi":{"name":"铁壁金书", "en":"Golden Bulwark", "group":"通用·生存", "effects":["所有我方武将受到伤害降低 5%。", "减伤提高至 10%。"]},
	"huichun":{"name":"回春真诀", "en":"Rejuvenation Art", "group":"通用·生存", "effects":["我方武将每 2 秒恢复 0.8%最大生命。", "每 2 秒恢复 1.6%最大生命。"]},
	"jinchan":{"name":"金蝉脱壳", "en":"Golden Cicada", "group":"通用·生存", "effects":["每场第一名受到致命伤害的友军免死并恢复 15%最大生命。", "恢复提高至 30%，同时清除全部减益。"]},
	"zebe":{"name":"泽被苍生", "en":"Grace to All", "group":"通用·生存", "effects":["溢出治疗额外按 30%治疗我方主公。", "额外转化比例提高至 60%。"]},
	"shoutu":{"name":"守土有责", "en":"Defend the Realm", "group":"通用·生存", "effects":["敌军攻击空格时，对我方主公伤害降低 15%。", "降低 30%，且主公每回合开始恢复 3%最大生命。"]},
	"yuzhan":{"name":"愈战愈勇", "en":"Battle-Hardened", "group":"通用·成长", "effects":["武将每存活通过一回合，生命 +80、兵略 +2，最多 5 层。", "每层提高至生命 +160、兵略 +4。"]},
	"fengshi":{"name":"锋矢兵书", "en":"Arrowhead Manual", "group":"通用·阵型", "effects":["前军最大生命 +10%，造成伤害 +8%。", "提高至生命 +20%、伤害 +16%。"]},
	"zhongliu":{"name":"中流砥柱", "en":"Pillar of the Line", "group":"通用·阵型", "effects":["中军兵略 +8，受到控制时间降低 15%。", "兵略 +16，控制时间降低 30%。"]},
	"yanxing":{"name":"雁行秘卷", "en":"Wild-Goose Scroll", "group":"通用·阵型", "effects":["后军兵略 +10，受到直接伤害降低 8%。", "兵略 +20，直接减伤 16%。"]},
	"tonglie":{"name":"同列并进", "en":"Advance in Columns", "group":"通用·阵型", "effects":["同列至少 2 名友军时，该列生命和兵略提高 6%。", "提高至 12%，且开场行动条 +10。"]},
	"qunce":{"name":"群策群力", "en":"United Counsel", "group":"通用·阵型", "effects":["每个不同阵营使全体兵略 +2、最大生命 +2%。", "每阵营提高至兵略 +4、最大生命 +4%。"]},
	"shu_jianbi":{"name":"汉室坚壁", "en":"Han Bulwark", "group":"蜀", "faction":"shu", "effects":["蜀将受到伤害降低 5%。", "减伤提高至 10%。"]},
	"shu_rende":{"name":"仁德遗泽", "en":"Legacy of Benevolence", "group":"蜀", "faction":"shu", "effects":["蜀将治疗提高 20%；溢出治疗的 30%转化为护盾。", "治疗提高 40%，护盾转化提高至 60%。"]},
	"shu_beifa":{"name":"北伐不息", "en":"Endless Northern March", "group":"蜀", "faction":"shu", "effects":["蜀将每次施法，本回合兵略 +1，最多 5 层。", "每次 +2，最多 8 层。"]},
	"shu_shudao":{"name":"蜀道天险", "en":"Perilous Shu Roads", "group":"蜀", "faction":"shu", "effects":["蜀国前军最大生命 +15%，受控时间降低 20%。", "生命 +30%，受控时间降低 40%。"]},
	"shu_wuhu":{"name":"五虎余烈", "en":"Five Tigers' Legacy", "group":"蜀", "faction":"shu", "effects":["蜀将首次伤害技能额外造成 80%兵略值伤害。", "额外伤害 160%，命中后行动条 +10。"]},
	"wei_haoling":{"name":"魏武号令", "en":"Wei Command", "group":"魏", "faction":"wei", "effects":["魏将首次施法使命中目标兵略降低 10%，持续 5 秒。", "降低 20%，持续 8 秒。"]},
	"wei_faling":{"name":"法令森严", "en":"Strict Decree", "group":"魏", "faction":"wei", "effects":["魏将施加的眩晕、冻结、恐惧、魅惑延长 15%。", "延长 30%。"]},
	"wei_chengsheng":{"name":"乘胜穷追", "en":"Relentless Pursuit", "group":"魏", "faction":"wei", "effects":["魏将对带减益敌人伤害提高 12%。", "提高 24%，命中时额外压退 5 点行动条。"]},
	"wei_hubao":{"name":"虎豹争先", "en":"Tiger-Leopard Vanguard", "group":"魏", "faction":"wei", "effects":["开战时魏将行动条 +15。", "行动条 +30，前 5 秒造成伤害提高 10%。"]},
	"wei_tuntian":{"name":"屯田固本", "en":"Agrarian Foundation", "group":"魏", "faction":"wei", "effects":["回合结束每名存活魏将为主公恢复 0.4%最大生命，最多 8 名。", "每名恢复 0.8%，并使存活魏将恢复 5%最大生命。"]},
	"wu_wotu":{"name":"江东沃土", "en":"Jiangdong Heartland", "group":"吴", "faction":"wu", "effects":["吴将最大生命提高 10%。", "提高至 20%。"]},
	"wu_huoshao":{"name":"火烧连营", "en":"Burning Camps", "group":"吴", "faction":"wu", "effects":["吴将直接技能伤害附加 3 秒灼烧，每秒 20%兵略值，不叠加。", "每秒 40%兵略值，持续 4 秒。"]},
	"wu_tongzhou":{"name":"同舟共命", "en":"Shared Fate", "group":"吴", "faction":"wu", "effects":["每场首次吴将受到致命伤害时，存活吴将均摊生命比例。", "均摊后额外恢复 8%最大生命。"]},
	"wu_zhiheng":{"name":"制衡之术", "en":"Art of Balance", "group":"吴", "faction":"wu", "effects":["每 5 秒，行动条最高和最低的吴将向平均值靠拢 30%。", "靠拢 60%，且二者获得 5 秒 10%增伤。"]},
	"wu_yinghao":{"name":"江表英豪", "en":"Heroes of Jiangbiao", "group":"吴", "faction":"wu", "effects":["每名吴将首次施法获得 8%最大生命护盾。", "护盾提高至 16%，护盾存在时兵略 +8。"]},
	"qun_jishu":{"name":"乱世疾书", "en":"Chaotic Age Codex", "group":"群", "faction":"qun", "effects":["群将技能冷却减少 0.35 秒。", "减少 0.7 秒。"]},
	"qun_wushuang":{"name":"无双战意", "en":"Peerless Will", "group":"群", "faction":"qun", "effects":["群将每损失 10%生命，兵略 +2。", "每层兵略 +4，并获得 1%减伤。"]},
	"qun_huangtian":{"name":"黄天雷契", "en":"Yellow Heaven Pact", "group":"群", "faction":"qun", "effects":["群将累计施法 5 次后，雷击 2 个随机敌方格，造成 100%平均兵略伤害。", "每 4 次触发，雷击 3 格并有 20%概率眩晕 1 秒。"]},
	"qun_qimen":{"name":"奇门毒典", "en":"Toxic Esoterica", "group":"群", "faction":"qun", "effects":["群将施加的灼烧、中毒和减益持续时间提高 20%。", "提高 40%，持续伤害提高 15%。"]},
	"qun_baijia":{"name":"百家争鸣", "en":"Hundred Schools", "group":"群", "faction":"qun", "effects":["每个非群阵营使群将兵略 +4、最大生命 +3%。", "每个提高至兵略 +8、最大生命 +6%。"]},
	"pool_shu":{"name":"蜀汉求贤令", "en":"Shu Recruitment Edict", "group":"武将池", "pool":["shu"], "effects":["当前及下一回合只出现蜀将。", "持续当前及之后 2 回合；每个候选位额外刷新 1 次。"]},
	"pool_wei":{"name":"魏庭求贤令", "en":"Wei Recruitment Edict", "group":"武将池", "pool":["wei"], "effects":["当前及下一回合只出现魏将。", "持续当前及之后 2 回合；每个候选位额外刷新 1 次。"]},
	"pool_wu":{"name":"江东求贤令", "en":"Wu Recruitment Edict", "group":"武将池", "pool":["wu"], "effects":["当前及下一回合只出现吴将。", "持续当前及之后 2 回合；每个候选位额外刷新 1 次。"]},
	"pool_qun":{"name":"群雄求贤令", "en":"Qun Recruitment Edict", "group":"武将池", "pool":["qun"], "effects":["当前及下一回合只出现群将。", "持续当前及之后 2 回合；每个候选位额外刷新 1 次。"]},
	"pool_shu_wu":{"name":"汉江盟书", "en":"Han-Jiang Pact", "group":"武将池", "pool":["shu","wu"], "effects":["当前及下一回合只出现蜀、吴武将。", "持续当前及之后 2 回合；两个阵营尽量均衡。"]},
	"pool_shu_wei":{"name":"汉魏争锋", "en":"Han-Wei Contest", "group":"武将池", "pool":["shu","wei"], "effects":["当前及下一回合只出现蜀、魏武将。", "持续当前及之后 2 回合；两个阵营尽量均衡。"]},
	"pool_shu_qun":{"name":"汉末逐鹿", "en":"Late-Han Strife", "group":"武将池", "pool":["shu","qun"], "effects":["当前及下一回合只出现蜀、群武将。", "持续当前及之后 2 回合；两个阵营尽量均衡。"]},
	"pool_wei_wu":{"name":"曹孙对峙", "en":"Cao-Sun Standoff", "group":"武将池", "pool":["wei","wu"], "effects":["当前及下一回合只出现魏、吴武将。", "持续当前及之后 2 回合；两个阵营尽量均衡。"]},
	"pool_wei_qun":{"name":"魏群会猎", "en":"Wei-Qun Hunt", "group":"武将池", "pool":["wei","qun"], "effects":["当前及下一回合只出现魏、群武将。", "持续当前及之后 2 回合；两个阵营尽量均衡。"]},
	"pool_wu_qun":{"name":"江表纳贤", "en":"Jiangbiao Recruitment", "group":"武将池", "pool":["wu","qun"], "effects":["当前及下一回合只出现吴、群武将。", "持续当前及之后 2 回合；两个阵营尽量均衡。"]}
}

var tianshu_levels := {}
var tianshu_choices: Array[String] = []
var tianshu_refresh_available: Array[bool] = [true, true, true]
var tianshu_pool_effect := {}
var tianshu_battle_state := {}
var tianshu_draft_refresh_used: Array[int] = [0, 0, 0]

func _tianshu_enabled() -> bool:
	return game_mode == "tianshu" or (game_mode == "challenge" and selected_difficulty >= 3)

func _reset_tianshu_run() -> void:
	tianshu_levels.clear()
	tianshu_choices.clear()
	tianshu_pool_effect.clear()
	tianshu_battle_state.clear()
	tianshu_refresh_available = [true, true, true]
	tianshu_draft_refresh_used = [0, 0, 0]

func _tianshu_level(book_id: String) -> int:
	return int(tianshu_levels.get(book_id, 0))

func _tianshu_name(book_id: String) -> String:
	var book: Dictionary = TIANSHU_BOOKS.get(book_id, {})
	return str(book.get("name", book_id)) if language == "zh" else str(book.get("en", book_id))

func _tianshu_effect_text(book_id: String, level := 0) -> String:
	var book: Dictionary = TIANSHU_BOOKS.get(book_id, {})
	var target_level := clampi(level if level > 0 else _tianshu_level(book_id) + 1, 1, 2)
	var effects: Array = book.get("effects", [])
	return str(effects[target_level - 1]) if effects.size() >= target_level else ""

func _generate_tianshu_choices() -> void:
	tianshu_choices.clear()
	var available: Array = TIANSHU_BOOKS.keys().filter(func(book_id): return _tianshu_level(str(book_id)) < 2)
	var upgrades: Array = available.filter(func(book_id): return _tianshu_level(str(book_id)) == 1)
	var upgrade_chance := 0.25 if round_number <= 3 else (0.50 if round_number <= 9 else 0.70)
	if not upgrades.is_empty() and rng.randf() < upgrade_chance:
		upgrades.shuffle()
		tianshu_choices.append(str(upgrades[0]))
	while tianshu_choices.size() < 3:
		var fresh: Array = available.filter(func(book_id): return not tianshu_choices.has(str(book_id)) and _tianshu_level(str(book_id)) == 0)
		var pool := fresh if not fresh.is_empty() else available.filter(func(book_id): return not tianshu_choices.has(str(book_id)))
		if pool.is_empty(): break
		pool.shuffle()
		tianshu_choices.append(str(pool[0]))
	tianshu_refresh_available = [true, true, true]

func _refresh_tianshu_choice(index: int) -> void:
	if phase != "tianshu" or index < 0 or index >= tianshu_choices.size(): return
	if index >= tianshu_refresh_available.size() or not tianshu_refresh_available[index]: return
	var previous := tianshu_choices[index]
	var excluded := tianshu_choices.duplicate()
	var pool: Array = TIANSHU_BOOKS.keys().filter(func(book_id):
		return _tianshu_level(str(book_id)) < 2 and str(book_id) != previous and not excluded.has(str(book_id))
	)
	if pool.is_empty(): return
	pool.shuffle()
	tianshu_choices[index] = str(pool[0])
	tianshu_refresh_available[index] = false
	_render()

func _choose_tianshu(book_id: String) -> void:
	if phase != "tianshu" or not tianshu_choices.has(book_id): return
	var new_level := mini(2, _tianshu_level(book_id) + 1)
	tianshu_levels[book_id] = new_level
	var book: Dictionary = TIANSHU_BOOKS[book_id]
	if book.has("pool"):
		tianshu_pool_effect = {"book_id":book_id, "factions":Array(book.pool).duplicate(), "end_round":round_number + (2 if new_level >= 2 else 1), "level":new_level}
	_log("[color=#e5a8ff]【天书·%s %s】%s[/color]" % [_tianshu_name(book_id), "Ⅱ" if new_level == 2 else "Ⅰ", _tianshu_effect_text(book_id, new_level)])
	phase = "draft"
	draft_user_hidden = false
	call("_generate_choices")
	_render()

func _active_tianshu_pool_factions() -> Array:
	if tianshu_pool_effect.is_empty() or round_number > int(tianshu_pool_effect.get("end_round", 0)):
		return []
	return Array(tianshu_pool_effect.get("factions", []))

func _tianshu_draft_refresh_limit() -> int:
	if tianshu_pool_effect.is_empty(): return 1
	var factions := _active_tianshu_pool_factions()
	return 2 if factions.size() == 1 and int(tianshu_pool_effect.get("level", 0)) >= 2 else 1

func _tianshu_can_refresh_draft(index: int) -> bool:
	return index >= 0 and index < tianshu_draft_refresh_used.size() and tianshu_draft_refresh_used[index] < _tianshu_draft_refresh_limit()

func _tianshu_save_state() -> Dictionary:
	return {"levels":tianshu_levels, "choices":tianshu_choices, "refresh":tianshu_refresh_available, "pool":tianshu_pool_effect, "battle":tianshu_battle_state, "draft_refresh_used":tianshu_draft_refresh_used}

func _load_tianshu_state(value) -> void:
	_reset_tianshu_run()
	if not value is Dictionary: return
	tianshu_levels = Dictionary(value.get("levels", {})).duplicate(true)
	tianshu_choices.clear()
	for book_id in value.get("choices", []):
		if TIANSHU_BOOKS.has(str(book_id)): tianshu_choices.append(str(book_id))
	tianshu_refresh_available.assign(value.get("refresh", [true, true, true]))
	tianshu_pool_effect = Dictionary(value.get("pool", {})).duplicate(true)
	tianshu_battle_state = Dictionary(value.get("battle", {})).duplicate(true)
	tianshu_draft_refresh_used.assign(value.get("draft_refresh_used", [0, 0, 0]))

func _tianshu_has_faction(unit: Dictionary, faction: String) -> bool:
	return unit.team == "player" and str(heroes[unit.hero_id].f) == faction

func _tianshu_deployed_faction_count() -> int:
	var found := {}
	for unit in combat_units:
		if unit.team == "player" and unit.alive: found[str(heroes[unit.hero_id].f)] = true
	return found.size()

func _tianshu_non_qun_faction_count() -> int:
	var found := {}
	for unit in combat_units:
		if unit.team == "player" and unit.alive and str(heroes[unit.hero_id].f) != "qun": found[str(heroes[unit.hero_id].f)] = true
	return found.size()

func _tianshu_column_has_pair(unit: Dictionary) -> bool:
	return combat_units.filter(func(other): return other.team == unit.team and other.alive and int(other.col) == int(unit.col)).size() >= 2

func _tianshu_recompute_unit_stats(unit: Dictionary) -> void:
	if unit.team != "player": return
	var hero: Dictionary = heroes[unit.hero_id]
	var faction := str(hero.f)
	var hp_multiplier := 1.0
	var hp_flat := 0.0
	var strategy_flat := 0.0
	var strategy_multiplier := 1.0
	if _tianshu_level("tianbing") > 0: hp_multiplier += 0.08 * _tianshu_level("tianbing")
	if _tianshu_level("pojun") > 0: strategy_flat += 8.0 * _tianshu_level("pojun")
	if _tianshu_level("fengshi") > 0 and int(hero.range) == 1: hp_multiplier += 0.10 * _tianshu_level("fengshi")
	if _tianshu_level("zhongliu") > 0 and int(hero.range) == 2: strategy_flat += 8.0 * _tianshu_level("zhongliu")
	if _tianshu_level("yanxing") > 0 and int(hero.range) >= 3: strategy_flat += 10.0 * _tianshu_level("yanxing")
	if _tianshu_level("tonglie") > 0 and _tianshu_column_has_pair(unit):
		hp_multiplier += 0.06 * _tianshu_level("tonglie")
		strategy_multiplier += 0.06 * _tianshu_level("tonglie")
	var faction_count := _tianshu_deployed_faction_count()
	if _tianshu_level("qunce") > 0:
		hp_multiplier += 0.02 * _tianshu_level("qunce") * faction_count
		strategy_flat += 2.0 * _tianshu_level("qunce") * faction_count
	if faction == "shu" and _tianshu_level("shu_shudao") > 0 and int(hero.range) == 1: hp_multiplier += 0.15 * _tianshu_level("shu_shudao")
	if faction == "wu" and _tianshu_level("wu_wotu") > 0: hp_multiplier += 0.10 * _tianshu_level("wu_wotu")
	if faction == "qun" and _tianshu_level("qun_baijia") > 0:
		var non_qun := _tianshu_non_qun_faction_count()
		hp_multiplier += 0.03 * _tianshu_level("qun_baijia") * non_qun
		strategy_flat += 4.0 * _tianshu_level("qun_baijia") * non_qun
	var growth_stacks := mini(5, int(unit.get("tianshu_growth_stacks", 0)))
	if _tianshu_level("yuzhan") > 0 and growth_stacks > 0:
		hp_flat += 80.0 * _tianshu_level("yuzhan") * growth_stacks
		strategy_flat += 2.0 * _tianshu_level("yuzhan") * growth_stacks
	var old_bonus := float(unit.get("tianshu_max_hp_bonus", 0.0))
	var base_max := maxf(1.0, float(unit.max_hp) - old_bonus)
	var hp_ratio := float(unit.hp) / maxf(1.0, float(unit.max_hp))
	var new_max := base_max * hp_multiplier + hp_flat
	unit.tianshu_max_hp_bonus = new_max - base_max
	unit.max_hp = new_max
	unit.hp = clampf(new_max * hp_ratio, 0.0, new_max)
	unit.tianshu_strategy_bonus = strategy_flat
	unit.tianshu_strategy_multiplier = strategy_multiplier
	unit.tianshu_cooldown_reduction = 0.0
	if _tianshu_level("fengchi") > 0: unit.tianshu_cooldown_reduction += 0.25 * _tianshu_level("fengchi")
	if faction == "qun" and _tianshu_level("qun_jishu") > 0: unit.tianshu_cooldown_reduction += 0.35 * _tianshu_level("qun_jishu")

func _apply_tianshu_battle_start() -> void:
	if not _tianshu_enabled(): return
	tianshu_battle_state = {"jinchan_used":false, "wu_tongzhou_used":false, "wu_balance_clock":0.0, "qun_casts":0}
	for unit in combat_units:
		if unit.team != "player": continue
		unit.tianshu_kills = 0
		unit.tianshu_kill_strategy_bonus = 0.0
		unit.tianshu_regen_clock = 0.0
		unit.tianshu_first_shu_damage = true
		unit.tianshu_wei_command_ready = true
		unit.tianshu_wu_first_cast = true
		unit.tianshu_shu_cast_stacks = 0
		_tianshu_recompute_unit_stats(unit)
		var faction := str(heroes[unit.hero_id].f)
		unit.action += 10.0 * _tianshu_level("xianfa")
		if faction == "wei": unit.action += 15.0 * _tianshu_level("wei_hubao")
		if _tianshu_level("tonglie") >= 2 and _tianshu_column_has_pair(unit): unit.action += 10.0
		unit.action = minf(ACTION_MAX, float(unit.action))
	if _tianshu_level("shoutu") >= 2:
		player_ruler_hp = mini(_player_ruler_max_hp(), player_ruler_hp + roundi(_player_ruler_max_hp() * 0.03))

func _tianshu_strategy_bonus(unit: Dictionary) -> float:
	if unit.team != "player" or not _tianshu_enabled(): return 0.0
	var result := float(unit.get("tianshu_strategy_bonus", 0.0)) + float(unit.get("tianshu_kill_strategy_bonus", 0.0))
	var faction := str(heroes[unit.hero_id].f)
	if faction == "shu" and _tianshu_level("shu_beifa") > 0:
		result += float(unit.get("tianshu_shu_cast_stacks", 0)) * float(_tianshu_level("shu_beifa"))
	if faction == "qun" and _tianshu_level("qun_wushuang") > 0:
		var missing_steps := floori((1.0 - float(unit.hp) / maxf(1.0, float(unit.max_hp))) / 0.10 + 0.0001)
		result += missing_steps * 2.0 * _tianshu_level("qun_wushuang")
	if faction == "wu" and _tianshu_level("wu_yinghao") >= 2 and float(unit.get("shield", 0.0)) > 0.0: result += 8.0
	return result

func _tianshu_strategy_multiplier(unit: Dictionary) -> float:
	return float(unit.get("tianshu_strategy_multiplier", 1.0)) if unit.team == "player" and _tianshu_enabled() else 1.0

func _tianshu_cooldown_reduction(unit: Dictionary) -> float:
	return float(unit.get("tianshu_cooldown_reduction", 0.0)) if unit.team == "player" and _tianshu_enabled() else 0.0

func _tianshu_control_source_multiplier(unit: Dictionary) -> float:
	if not _tianshu_enabled() or unit.team != "player": return 1.0
	var result := 1.0
	if _tianshu_has_faction(unit, "wei") and _tianshu_level("wei_faling") > 0: result *= 1.0 + 0.15 * _tianshu_level("wei_faling")
	if _tianshu_has_faction(unit, "qun") and _tianshu_level("qun_qimen") > 0: result *= 1.0 + 0.20 * _tianshu_level("qun_qimen")
	return result

func _tianshu_control_decay_multiplier(unit: Dictionary) -> float:
	if unit.team != "player" or not _tianshu_enabled(): return 1.0
	var resist := 0.0
	if int(heroes[unit.hero_id].range) == 2 and _tianshu_level("zhongliu") > 0: resist = maxf(resist, 0.15 * _tianshu_level("zhongliu"))
	if _tianshu_has_faction(unit, "shu") and int(heroes[unit.hero_id].range) == 1 and _tianshu_level("shu_shudao") > 0: resist = maxf(resist, 0.20 * _tianshu_level("shu_shudao"))
	return 1.0 / maxf(0.05, 1.0 - resist)

func _tianshu_damage_multiplier(source, target: Dictionary, direct := true) -> float:
	if source == null or source.team != "player" or not _tianshu_enabled(): return 1.0
	var result := 1.0
	var faction := str(heroes[source.hero_id].f)
	if _tianshu_level("chengxu") > 0 and bool(call("_has_any_debuff", target)): result *= 1.0 + 0.10 * _tianshu_level("chengxu")
	if _tianshu_level("canyang") > 0 and float(source.hp) < float(source.max_hp) * 0.5: result *= 1.0 + 0.12 * _tianshu_level("canyang")
	if _tianshu_level("fengshi") > 0 and int(heroes[source.hero_id].range) == 1: result *= 1.0 + 0.08 * _tianshu_level("fengshi")
	if faction == "wei" and _tianshu_level("wei_chengsheng") > 0 and bool(call("_has_any_debuff", target)): result *= 1.0 + 0.12 * _tianshu_level("wei_chengsheng")
	if faction == "wei" and _tianshu_level("wei_hubao") >= 2 and battle_time <= 5.0: result *= 1.10
	return result

func _tianshu_ruler_damage_multiplier(source: Dictionary) -> float:
	if source.team == "enemy" and _tianshu_enabled() and _tianshu_level("shoutu") > 0: return 1.0 - 0.15 * _tianshu_level("shoutu")
	var dummy := {"stun":0.0,"charm":0.0,"burn":0.0,"silence":0.0,"slow_time":0.0,"vulnerable_time":0.0,"grievous_time":0.0,"strategy_mark":0.0,"skill_debuff":0.0,"fear":0.0,"freeze":0.0,"poison":0.0,"zhuge_fire_mark":0.0}
	return _tianshu_damage_multiplier(source, dummy, true)

func _tianshu_damage_reduction(target: Dictionary, source, direct := true) -> float:
	if target.team != "player" or not _tianshu_enabled(): return 0.0
	var reduction := 0.05 * _tianshu_level("tiebi")
	var faction := str(heroes[target.hero_id].f)
	if faction == "shu": reduction += 0.05 * _tianshu_level("shu_jianbi")
	if direct and int(heroes[target.hero_id].range) >= 3: reduction += 0.08 * _tianshu_level("yanxing")
	if faction == "qun" and _tianshu_level("qun_wushuang") >= 2:
		var steps := floori((1.0 - float(target.hp) / maxf(1.0, float(target.max_hp))) / 0.10 + 0.0001)
		reduction += 0.01 * steps
	return reduction

func _tianshu_heal_multiplier(source: Dictionary) -> float:
	if not _tianshu_enabled() or not _tianshu_has_faction(source, "shu") or _tianshu_level("shu_rende") <= 0: return 1.0
	return 1.0 + 0.20 * _tianshu_level("shu_rende")

func _tianshu_on_overflow(source: Dictionary, target, overflow: float) -> void:
	if overflow <= 0.0 or source.team != "player" or not _tianshu_enabled(): return
	if _tianshu_level("zebe") > 0:
		var bonus := overflow * 0.30 * _tianshu_level("zebe")
		var restored := minf(bonus, float(_player_ruler_max_hp() - player_ruler_hp))
		player_ruler_hp += roundi(restored)
		if restored > 0.0: call("_add_stat", source, "healing", restored)
	if target != null and _tianshu_has_faction(source, "shu") and _tianshu_level("shu_rende") > 0:
		call("_grant_shield", target, overflow * 0.30 * _tianshu_level("shu_rende"))

func _tianshu_try_prevent_death(target: Dictionary) -> bool:
	if target.team != "player" or not _tianshu_enabled(): return false
	if _tianshu_level("jinchan") > 0 and not bool(tianshu_battle_state.get("jinchan_used", false)):
		tianshu_battle_state.jinchan_used = true
		target.hp = float(target.max_hp) * (0.15 if _tianshu_level("jinchan") == 1 else 0.30)
		if _tianshu_level("jinchan") >= 2: call("_clear_all_debuffs", target)
		_log("[color=#e5a8ff]【天书·金蝉脱壳】触发免死！[/color]")
		return true
	if _tianshu_has_faction(target, "wu") and _tianshu_level("wu_tongzhou") > 0 and not bool(tianshu_battle_state.get("wu_tongzhou_used", false)):
		tianshu_battle_state.wu_tongzhou_used = true
		var allies: Array = Array(call("_team_units", "player")).filter(func(ally): return ally.alive and str(heroes[ally.hero_id].f) == "wu")
		var ratio_sum := 0.0
		for ally in allies: ratio_sum += maxf(0.0, float(ally.hp)) / maxf(1.0, float(ally.max_hp))
		var shared := ratio_sum / maxf(1.0, allies.size())
		for ally in allies: ally.hp = minf(float(ally.max_hp), float(ally.max_hp) * shared + (float(ally.max_hp) * 0.08 if _tianshu_level("wu_tongzhou") >= 2 else 0.0))
		_log("[color=#e5a8ff]【天书·同舟共命】吴将均摊生命！[/color]")
		return target.hp > 0.0
	return false

func _tianshu_on_damage(source, target: Dictionary, actual_damage: float, direct := true) -> void:
	if source == null or actual_damage <= 0.0 or source.team != "player" or not _tianshu_enabled(): return
	var faction := str(heroes[source.hero_id].f)
	if faction == "wei" and _tianshu_level("wei_chengsheng") >= 2 and bool(call("_has_any_debuff", target)): target.action = maxf(0.0, float(target.action) - 5.0)
	if faction == "wei" and bool(source.get("tianshu_wei_command_ready", false)) and _tianshu_level("wei_haoling") > 0:
		source.tianshu_wei_command_ready = false
		target.skill_debuff = maxf(float(target.get("skill_debuff", 0.0)), 0.10 * _tianshu_level("wei_haoling"))
		target.skill_debuff_time = maxf(float(target.get("skill_debuff_time", 0.0)), 5.0 if _tianshu_level("wei_haoling") == 1 else 8.0)
	if faction == "wu" and direct and _tianshu_level("wu_huoshao") > 0:
		var has_fire := (target.get("burn_effects", []) as Array).any(func(effect): return str(effect.get("visual_group", "")) == "tianshu_fire")
		if not has_fire:
			call("_add_burn_effect", source, target, 3.0 if _tianshu_level("wu_huoshao") == 1 else 4.0, float(call("_unit_skill_stat_value", source)) * 0.20 * _tianshu_level("wu_huoshao"), false, "tianshu_fire")
	if faction == "shu" and direct and bool(source.get("tianshu_first_shu_damage", false)) and _tianshu_level("shu_wuhu") > 0:
		source.tianshu_first_shu_damage = false
		var bonus: float = float(call("_unit_skill_stat_value", source)) * 0.80 * _tianshu_level("shu_wuhu")
		call("_damage", source, target, bonus, "physical", t("天书·五虎余烈", "Five Tigers' Legacy"), "tianshu_wuhu", "effect", false, true, false)
		if _tianshu_level("shu_wuhu") >= 2: source.action = minf(ACTION_MAX, float(source.action) + 10.0)

func _tianshu_on_ruler_hit(source: Dictionary, tile: Dictionary) -> void:
	if source.team != "player" or not _tianshu_enabled(): return
	if _tianshu_has_faction(source, "shu") and bool(source.get("tianshu_first_shu_damage", false)) and _tianshu_level("shu_wuhu") > 0:
		source.tianshu_first_shu_damage = false
		var bonus: float = float(call("_unit_skill_stat_value", source)) * 0.80 * _tianshu_level("shu_wuhu")
		call("_hit_ruler", source, bonus, tile, t("天书·五虎余烈", "Five Tigers' Legacy"), "tianshu_wuhu", "effect")
		if _tianshu_level("shu_wuhu") >= 2: source.action = minf(ACTION_MAX, float(source.action) + 10.0)

func _tianshu_on_kill(killer, fallen: Dictionary) -> void:
	if killer == null or killer.team != "player" or not _tianshu_enabled() or _tianshu_level("zhanjiang") <= 0: return
	var limit := 3 if _tianshu_level("zhanjiang") == 1 else 5
	if int(killer.get("tianshu_kills", 0)) >= limit: return
	killer.tianshu_kills = int(killer.get("tianshu_kills", 0)) + 1
	killer.action = minf(ACTION_MAX, float(killer.action) + (15.0 if _tianshu_level("zhanjiang") == 1 else 25.0))
	if _tianshu_level("zhanjiang") >= 2: killer.tianshu_kill_strategy_bonus = float(killer.get("tianshu_kill_strategy_bonus", 0.0)) + 5.0

func _tianshu_on_cast(unit: Dictionary) -> void:
	if unit.team != "player" or not _tianshu_enabled(): return
	var faction := str(heroes[unit.hero_id].f)
	if faction == "shu" and _tianshu_level("shu_beifa") > 0:
		unit.tianshu_shu_cast_stacks = mini(5 if _tianshu_level("shu_beifa") == 1 else 8, int(unit.get("tianshu_shu_cast_stacks", 0)) + 1)
	if faction == "wu" and bool(unit.get("tianshu_wu_first_cast", false)) and _tianshu_level("wu_yinghao") > 0:
		unit.tianshu_wu_first_cast = false
		call("_grant_shield", unit, float(unit.max_hp) * 0.08 * _tianshu_level("wu_yinghao"))
	if faction == "qun" and _tianshu_level("qun_huangtian") > 0:
		tianshu_battle_state.qun_casts = int(tianshu_battle_state.get("qun_casts", 0)) + 1
		var threshold := 5 if _tianshu_level("qun_huangtian") == 1 else 4
		if int(tianshu_battle_state.qun_casts) >= threshold:
			tianshu_battle_state.qun_casts = 0
			_tianshu_trigger_yellow_heaven(unit)

func _tianshu_trigger_yellow_heaven(source: Dictionary) -> void:
	var allies: Array = Array(call("_team_units", "player")).filter(func(unit): return unit.alive and str(heroes[unit.hero_id].f) == "qun")
	if allies.is_empty(): return
	var average := 0.0
	for ally in allies: average += float(call("_unit_skill_stat_value", ally))
	average /= allies.size()
	var count := 2 if _tianshu_level("qun_huangtian") == 1 else 3
	for tile in Array(call("_random_unique_enemy_tiles", source, count)):
		if tile.target == null: call("_hit_ruler", source, average, tile, t("天书·黄天雷契", "Yellow Heaven Pact"), "tianshu_thunder", "magic")
		else:
			call("_damage", source, tile.target, average, "magic", t("天书·黄天雷契", "Yellow Heaven Pact"), "tianshu_thunder", "magic")
			if _tianshu_level("qun_huangtian") >= 2 and rng.randf() < 0.20: call("_apply_skill_stun", source, tile.target, 1.0)

func _tianshu_process_tick(delta: float) -> void:
	if not _tianshu_enabled(): return
	for unit in combat_units:
		if not unit.alive or unit.team != "player": continue
		if _tianshu_level("huichun") > 0:
			unit.tianshu_regen_clock = float(unit.get("tianshu_regen_clock", 0.0)) + delta
			while float(unit.tianshu_regen_clock) >= 2.0:
				unit.tianshu_regen_clock -= 2.0
				call("_heal_unit_only", unit, unit, float(unit.max_hp) * 0.008 * _tianshu_level("huichun"), "tianshu_huichun", "heal")
	if _tianshu_level("wu_zhiheng") > 0:
		tianshu_battle_state.wu_balance_clock = float(tianshu_battle_state.get("wu_balance_clock", 0.0)) + delta
		if float(tianshu_battle_state.wu_balance_clock) >= 5.0:
			tianshu_battle_state.wu_balance_clock -= 5.0
			var wu_units: Array = Array(call("_team_units", "player")).filter(func(unit): return unit.alive and str(heroes[unit.hero_id].f) == "wu")
			if wu_units.size() >= 2:
				wu_units.sort_custom(func(a, b): return float(a.action) < float(b.action))
				var low: Dictionary = wu_units.front()
				var high: Dictionary = wu_units.back()
				var average := (float(low.action) + float(high.action)) * 0.5
				var ratio := 0.30 * _tianshu_level("wu_zhiheng")
				low.action = lerpf(float(low.action), average, ratio)
				high.action = lerpf(float(high.action), average, ratio)
				if _tianshu_level("wu_zhiheng") >= 2:
					for unit in [low, high]: unit.timed_damage_buff = maxf(float(unit.get("timed_damage_buff", 0.0)), 0.10); unit.timed_damage_time = maxf(float(unit.get("timed_damage_time", 0.0)), 5.0)

func _tianshu_on_round_end() -> void:
	if not _tianshu_enabled(): return
	if _tianshu_level("yuzhan") > 0:
		for unit in player_units:
			if unit.alive: unit.tianshu_growth_stacks = mini(5, int(unit.get("tianshu_growth_stacks", 0)) + 1)
	if _tianshu_level("wei_tuntian") > 0:
		var survivors := player_units.filter(func(unit): return unit.alive and int(unit.row) >= 0 and str(heroes[unit.hero_id].f) == "wei")
		var count := mini(8, survivors.size())
		player_ruler_hp = mini(_player_ruler_max_hp(), player_ruler_hp + roundi(_player_ruler_max_hp() * 0.004 * _tianshu_level("wei_tuntian") * count))
		if _tianshu_level("wei_tuntian") >= 2:
			for unit in survivors: unit.hp = minf(float(unit.max_hp), float(unit.hp) + float(unit.max_hp) * 0.05)

func _tianshu_dot_duration_multiplier(source) -> float:
	return 1.0 + 0.20 * _tianshu_level("qun_qimen") if source != null and _tianshu_has_faction(source, "qun") and _tianshu_enabled() else 1.0

func _tianshu_dot_damage_multiplier(source) -> float:
	return 1.15 if source != null and _tianshu_has_faction(source, "qun") and _tianshu_enabled() and _tianshu_level("qun_qimen") >= 2 else 1.0
