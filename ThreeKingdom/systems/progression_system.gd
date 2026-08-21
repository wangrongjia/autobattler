extends "res://ThreeKingdom/systems/game_state.gd"

# 独立于单局快速战斗存档的永久养成数据。
const PROGRESSION_SAVE_PATH := "user://three_kingdoms_progression.json"
const STAGE_NAMES := [
	"涿郡之战", "广宗之战", "下曲阳之战", "陈留之战", "虎牢关之战",
	"洛阳之战", "荥阳之战", "长安之战", "濮阳之战", "徐州之战",
	"兖州之战", "寿春之战", "宛城之战", "下邳之战", "许昌之战",
	"官渡之战", "白马之战", "延津之战", "邺城之战", "黎阳之战",
	"新野之战", "博望坡之战", "襄阳之战", "江夏之战", "夏口之战",
	"赤壁之战", "南郡之战", "江陵之战", "长沙之战", "桂阳之战",
	"零陵之战", "武陵之战", "合肥之战", "潼关之战", "汉中之战",
	"定军山之战", "樊城之战", "麦城之战", "夷陵之战", "白帝城之战",
	"街亭之战", "陈仓之战", "祁山之战", "武都之战", "五丈原之战",
	"上方谷之战", "剑阁之战", "成都之战", "建业之战", "洛阳终章之战"
]
const DIFFICULTIES := [
	{"name":"简单", "en":"EASY", "hp":1.0, "strategy":0},
	{"name":"一般", "en":"NORMAL", "hp":1.2, "strategy":10},
	{"name":"困难", "en":"HARD", "hp":1.5, "strategy":20},
	{"name":"王者", "en":"KING", "hp":1.7, "strategy":30},
	{"name":"地狱", "en":"HELL", "hp":2.2, "strategy":50}
]
const RUNE_TIERS := [
	{"name":"一阶", "color":"白", "hex":"#dedede", "chance":0.50, "power":4.0, "balanced":2.5, "extreme":5.0, "penalty":1.0, "convert":100},
	{"name":"二阶", "color":"绿", "hex":"#68bf72", "chance":0.30, "power":6.0, "balanced":3.5, "extreme":7.5, "penalty":1.5, "convert":200},
	{"name":"三阶", "color":"蓝", "hex":"#5c9ee8", "chance":0.10, "power":9.0, "balanced":5.0, "extreme":11.0, "penalty":2.0, "convert":300},
	{"name":"四阶", "color":"紫", "hex":"#ae72df", "chance":0.05, "power":14.0, "balanced":7.5, "extreme":17.5, "penalty":3.5, "convert":500},
	{"name":"五阶", "color":"橙", "hex":"#e69b45", "chance":0.04, "power":21.0, "balanced":11.5, "extreme":26.0, "penalty":5.0, "convert":800},
	{"name":"六阶", "color":"红", "hex":"#e45d5d", "chance":0.01, "power":32.0, "balanced":17.5, "extreme":40.0, "penalty":8.0, "convert":1300}
]
const RUNE_DRAW_COST := 200       # 单次符文抽取消耗将魂;十连 = 10 次,无折扣
const RUNE_KINDS := [
	{"id":"ZS", "name":"磐石", "class":"正", "positive":"hp", "negative":""},
	{"id":"ZL", "name":"韬略", "class":"正", "positive":"strategy", "negative":""},
	{"id":"ZJ", "name":"疾风", "class":"正", "positive":"cooldown", "negative":""},
	{"id":"JS", "name":"文武", "class":"均", "positive":"hp,strategy", "negative":""},
	{"id":"JH", "name":"恒毅", "class":"均", "positive":"hp,cooldown", "negative":""},
	{"id":"JM", "name":"静谋", "class":"均", "positive":"strategy,cooldown", "negative":""},
	{"id":"Q1", "name":"舍身", "class":"极", "positive":"strategy", "negative":"hp"},
	{"id":"Q2", "name":"燃血", "class":"极", "positive":"cooldown", "negative":"hp"},
	{"id":"Q3", "name":"藏锋", "class":"极", "positive":"hp", "negative":"strategy"},
	{"id":"Q4", "name":"凝神", "class":"极", "positive":"cooldown", "negative":"strategy"},
	{"id":"Q5", "name":"笃重", "class":"极", "positive":"hp", "negative":"cooldown"},
	{"id":"Q6", "name":"深谋", "class":"极", "positive":"strategy", "negative":"cooldown"}
]

# [节点名, 层数, 最大等级, 每级生命, 每级兵略, 每级冷却缩减, 上层累计解锁门槛]
const TALENT_TREES := {
	"all":{"name":"通用·天下大势", "faction":"", "nodes":[
		["厚德",1,5,40.0,0.0,0.0,0], ["修文",1,5,0.0,1.0,0.0,0], ["敏行",1,5,0.0,0.0,0.05,0],
		["强魄",2,5,60.0,0.0,0.0,8], ["韬晦",2,5,0.0,1.5,0.0,8], ["迅捷",2,5,0.0,0.0,0.075,8],
		["金坚",3,4,80.0,0.0,0.0,20], ["睿略",3,4,0.0,2.0,0.0,20], ["疾驰",3,4,0.0,0.0,0.1,20],
		["明君",4,2,0.0,0.0,0.0,34], ["神算",4,1,0.0,0.0,0.0,34], ["百炼",4,2,0.0,0.0,0.0,34],
		["天命",5,1,0.0,0.0,0.0,40], ["群英",5,1,400.0,10.0,0.5,40], ["长治",5,1,0.0,0.0,0.0,40]
	]},
	"shu":{"name":"蜀·汉室中兴", "faction":"shu", "nodes":[
		["仁厚",1,2,60.0,0.0,0.0,0], ["睿思",1,2,0.0,1.0,0.0,0], ["笃行",1,2,0.0,0.0,0.05,0],
		["坚壁",2,3,80.0,0.0,0.0,4], ["明略",2,3,0.0,1.5,0.0,4], ["疾进",2,3,0.0,0.0,0.075,4],
		["龙魂",3,2,120.0,0.0,0.0,10], ["凤雏",3,2,0.0,2.0,0.0,10], ["迅雷",3,2,0.0,0.0,0.1,10],
		["汉室坚壁",4,2,0.0,0.0,0.0,16], ["桃园同心",5,2,0.0,0.0,0.0,18]
	]},
	"wei":{"name":"魏·霸府经纬", "faction":"wei", "nodes":[
		["蓄锐",1,2,0.0,0.0,0.06,0], ["文心",1,2,0.0,1.0,0.0,0], ["固本",1,2,40.0,0.0,0.0,0],
		["疾令",2,3,0.0,0.0,0.09,4], ["武备",2,3,0.0,1.5,0.0,4], ["铁躯",2,3,60.0,0.0,0.0,4],
		["雷霆",3,2,0.0,0.0,0.12,10], ["王佐",3,2,0.0,2.0,0.0,10], ["金刚",3,2,80.0,0.0,0.0,10],
		["中枢令典",4,2,0.0,0.0,0.0,16], ["乘胜追击",5,2,0.0,0.0,0.0,18]
	]},
	"wu":{"name":"吴·江东基业", "faction":"wu", "nodes":[
		["休养",1,2,50.0,0.0,0.0,0], ["英才",1,2,0.0,1.0,0.0,0], ["顺流",1,2,0.0,0.0,0.05,0],
		["富庶",2,3,70.0,0.0,0.0,4], ["多俊",2,3,0.0,1.5,0.0,4], ["扬帆",2,3,0.0,0.0,0.075,4],
		["鼎足",3,2,110.0,0.0,0.0,10], ["擎天",3,2,0.0,2.0,0.0,10], ["破浪",3,2,0.0,0.0,0.1,10],
		["三世基业",4,2,0.0,0.0,0.0,16], ["同舟共济",5,2,0.0,0.0,0.0,18]
	]},
	"qun":{"name":"群·乱世烽火", "faction":"qun", "nodes":[
		["锋锐",1,2,0.0,1.2,0.0,0], ["亡命",1,2,40.0,0.0,0.0,0], ["果决",1,2,0.0,0.0,0.05,0],
		["霸道",2,3,0.0,1.8,0.0,4], ["狠戾",2,3,60.0,0.0,0.0,4], ["雷厉",2,3,0.0,0.0,0.075,4],
		["无双",3,2,0.0,2.4,0.0,10], ["鬼谋",3,2,90.0,0.0,0.0,10], ["迅烈",3,2,0.0,0.0,0.1,10],
		["烽火燎原",4,2,0.0,0.0,0.0,16], ["逐鹿中原",5,2,0.0,0.0,0.0,18]
	]}
}

var game_mode := "quick"
var selected_stage := 1
var selected_difficulty := 0
var limit_challenges := true
var general_souls := 0
var general_stars := 0
var stage_star_records := {}
var rune_inventory: Array = []
var rune_loadouts := {}
var talent_levels := {}
var home_hero_id := "sunshangxiang"
var next_rune_id := 1
var pending_battle_result := {}

func _progression_key(stage: int, difficulty: int) -> String:
	return str(stage) + ":" + str(difficulty)

func _load_progression() -> void:
	if not FileAccess.file_exists(PROGRESSION_SAVE_PATH): return
	var file := FileAccess.open(PROGRESSION_SAVE_PATH, FileAccess.READ)
	if file == null: return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY: return
	general_souls = maxi(0, int(data.get("general_souls", 0)))
	general_stars = maxi(0, int(data.get("general_stars", 0)))
	stage_star_records = data.get("stage_star_records", {}) if data.get("stage_star_records", {}) is Dictionary else {}
	rune_inventory = data.get("rune_inventory", []) if data.get("rune_inventory", []) is Array else []
	rune_loadouts = data.get("rune_loadouts", {}) if data.get("rune_loadouts", {}) is Dictionary else {}
	talent_levels = data.get("talent_levels", {}) if data.get("talent_levels", {}) is Dictionary else {}
	var refunded_removed_talent := 0
	for removed_name in ["开源", "生财", "重利"]:
		refunded_removed_talent += int(talent_levels.get("all:" + removed_name, 0)) * 5
		talent_levels.erase("all:" + removed_name)
	if refunded_removed_talent > 0:
		general_stars += refunded_removed_talent
	home_hero_id = str(data.get("home_hero_id", "sunshangxiang"))
	if not heroes.has(home_hero_id): home_hero_id = "sunshangxiang"
	next_rune_id = maxi(1, int(data.get("next_rune_id", 1)))
	_sanitize_progression()
	if refunded_removed_talent > 0:
		_save_progression()

func _save_progression() -> bool:
	var file := FileAccess.open(PROGRESSION_SAVE_PATH, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({
		"version":1, "general_souls":general_souls, "general_stars":general_stars,
		"stage_star_records":stage_star_records, "rune_inventory":rune_inventory,
		"rune_loadouts":rune_loadouts, "talent_levels":talent_levels,
		"home_hero_id":home_hero_id, "next_rune_id":next_rune_id
	}))
	file.close()
	return true

func _sanitize_progression() -> void:
	var valid_runes: Array = []
	var rune_ids := {}
	for raw in rune_inventory:
		if not raw is Dictionary: continue
		var tier := clampi(int(raw.get("tier", 1)), 1, 6)
		var kind := str(raw.get("kind", ""))
		if not RUNE_KINDS.any(func(entry): return str(entry.id) == kind): continue
		var id := maxi(1, int(raw.get("uid", next_rune_id)))
		next_rune_id = maxi(next_rune_id, id + 1)
		valid_runes.append({"uid":id, "tier":tier, "kind":kind})
		rune_ids[str(id)] = true
	rune_inventory = valid_runes
	for hero_id in rune_loadouts.keys():
		if not heroes.has(str(hero_id)):
			rune_loadouts.erase(hero_id)
			continue
		var cleaned: Array = []
		for uid in rune_loadouts[hero_id]:
			if rune_ids.has(str(int(uid))) and not cleaned.has(int(uid)) and cleaned.size() < 3: cleaned.append(int(uid))
		rune_loadouts[hero_id] = cleaned

func _is_stage_unlocked(stage: int, difficulty: int) -> bool:
	if stage < 1 or stage > 50 or difficulty < 0 or difficulty >= DIFFICULTIES.size(): return false
	if not limit_challenges: return true
	if difficulty == 0: return stage == 1 or int(stage_star_records.get(_progression_key(stage - 1, 0), 0)) > 0
	return _is_stage_unlocked(stage, 0) and int(stage_star_records.get(_progression_key(stage, difficulty - 1), 0)) > 0

func _challenge_strategy_bonus() -> float:
	if game_mode != "challenge": return float(enemy_strategy_bonus)
	return float(selected_stage * 5 + int(DIFFICULTIES[selected_difficulty].strategy))

func _challenge_stage_strategy_bonus(stage := selected_stage) -> int:
	return clampi(int(stage), 1, STAGE_NAMES.size()) * 5

func _challenge_difficulty_strategy_bonus(difficulty := selected_difficulty) -> int:
	return int(DIFFICULTIES[clampi(int(difficulty), 0, DIFFICULTIES.size() - 1)].strategy)

func _challenge_enemy_hp_multiplier() -> float:
	return float(DIFFICULTIES[selected_difficulty].hp) if game_mode == "challenge" else 1.0

func _challenge_stars_for_hp() -> int:
	return 3 if player_ruler_hp > 40000 else (2 if player_ruler_hp > 25000 else 1)

func _challenge_soul_reward(stars: int) -> int:
	return 300 + 50 * (selected_stage - 1) + 50 * selected_difficulty + 100 * (stars - 1)

func _complete_challenge(victory: bool) -> Dictionary:
	var result := {"victory":victory, "stage":selected_stage, "difficulty":selected_difficulty, "stars":0, "new_stars":0, "souls":0}
	if victory:
		var stars := _challenge_stars_for_hp()
		var key := _progression_key(selected_stage, selected_difficulty)
		var old_best := int(stage_star_records.get(key, 0))
		var gained := maxi(0, stars - old_best)
		stage_star_records[key] = maxi(old_best, stars)
		var souls := _challenge_soul_reward(stars)
		general_stars += gained
		general_souls += souls
		result.stars = stars
		result.new_stars = gained
		result.souls = souls
		_save_progression()
	pending_battle_result = result
	return result

func _rune_kind(kind_id: String) -> Dictionary:
	for entry in RUNE_KINDS:
		if str(entry.id) == kind_id: return entry
	return {}

func _rune_by_uid(uid: int):
	for rune in rune_inventory:
		if int(rune.uid) == uid: return rune
	return null

func _new_random_rune(tier := 0) -> Dictionary:
	var chosen_tier := tier
	if chosen_tier <= 0:
		var roll := rng.randf()
		var cumulative := 0.0
		chosen_tier = 6
		for index in RUNE_TIERS.size():
			cumulative += float(RUNE_TIERS[index].chance)
			if roll <= cumulative:
				chosen_tier = index + 1
				break
	var kind: Dictionary = RUNE_KINDS[rng.randi_range(0, RUNE_KINDS.size() - 1)]
	var rune := {"uid":next_rune_id, "tier":chosen_tier, "kind":str(kind.id)}
	next_rune_id += 1
	return rune

func _draw_rune():
	var results := _draw_runes(1)
	return null if results.is_empty() else results[0]

func _draw_runes(count: int) -> Array:
	if count <= 0 or general_souls < count * RUNE_DRAW_COST: return []
	general_souls -= count * RUNE_DRAW_COST
	var results: Array = []
	for draw_index in count:
		var rune := _new_random_rune()
		rune_inventory.append(rune)
		results.append(rune)
	_save_progression()
	return results

func _unequip_rune_everywhere(uid: int) -> void:
	for hero_id in rune_loadouts:
		var slots: Array = rune_loadouts[hero_id]
		slots.erase(uid)
		rune_loadouts[hero_id] = slots

func _synthesize_runes(first_uid: int, second_uid: int):
	if first_uid == second_uid: return null
	var first = _rune_by_uid(first_uid)
	var second = _rune_by_uid(second_uid)
	if first == null or second == null or int(first.tier) != int(second.tier) or int(first.tier) >= 6: return null
	var next_tier := int(first.tier) + 1
	_unequip_rune_everywhere(first_uid)
	_unequip_rune_everywhere(second_uid)
	rune_inventory.erase(first)
	rune_inventory.erase(second)
	var result := _new_random_rune(next_tier)
	rune_inventory.append(result)
	_save_progression()
	return result

func _synthesize_all_runes(tier: int) -> Dictionary:
	if tier < 1 or tier >= 6: return {"consumed":0, "created":[]}
	var candidates: Array = rune_inventory.filter(func(rune): return int(rune.tier) == tier)
	candidates.sort_custom(func(a, b): return int(a.uid) < int(b.uid))
	var pair_count := int(candidates.size() / 2)
	if pair_count <= 0: return {"consumed":0, "created":[]}
	var created: Array = []
	for index in pair_count:
		var first: Dictionary = candidates[index * 2]
		var second: Dictionary = candidates[index * 2 + 1]
		_unequip_rune_everywhere(int(first.uid))
		_unequip_rune_everywhere(int(second.uid))
		rune_inventory.erase(first)
		rune_inventory.erase(second)
		var result := _new_random_rune(tier + 1)
		rune_inventory.append(result)
		created.append(result)
	_save_progression()
	return {"consumed":pair_count * 2, "created":created}

func _convert_rune(uid: int):
	var old = _rune_by_uid(uid)
	if old == null: return null
	var tier := int(old.tier)
	var discount := 1.0 - 0.10 * float(_talent_level("all", "百炼"))
	var cost := ceili(float(RUNE_TIERS[tier - 1].convert) * discount)
	if general_souls < cost: return null
	general_souls -= cost
	var old_kind := str(old.kind)
	var options := RUNE_KINDS.filter(func(entry): return str(entry.id) != old_kind)
	old.kind = str(options[rng.randi_range(0, options.size() - 1)].id)
	_save_progression()
	return old

func _equip_rune(hero_id: String, uid: int) -> bool:
	if not heroes.has(hero_id) or _rune_by_uid(uid) == null: return false
	_unequip_rune_everywhere(uid)
	var slots: Array = rune_loadouts.get(hero_id, [])
	if slots.size() >= 3: return false
	slots.append(uid)
	rune_loadouts[hero_id] = slots
	_save_progression()
	return true

func _unequip_rune(hero_id: String, uid: int) -> void:
	var slots: Array = rune_loadouts.get(hero_id, [])
	slots.erase(uid)
	rune_loadouts[hero_id] = slots
	_save_progression()

func _rune_effect(rune: Dictionary) -> Dictionary:
	var tier_data: Dictionary = RUNE_TIERS[clampi(int(rune.tier), 1, 6) - 1]
	var kind := _rune_kind(str(rune.kind))
	var result := {"hp":0.0, "strategy":0.0, "cooldown":0.0}
	var amount := float(tier_data.power)
	if str(kind.get("class", "")) == "均": amount = float(tier_data.balanced)
	elif str(kind.get("class", "")) == "极": amount = float(tier_data.extreme)
	for stat in str(kind.get("positive", "")).split(",", false):
		if stat == "hp": result.hp += amount * 40.0
		elif stat == "strategy": result.strategy += amount
		elif stat == "cooldown": result.cooldown += amount * 0.05
	if not str(kind.get("negative", "")).is_empty():
		var penalty := float(tier_data.penalty)
		match str(kind.negative):
			"hp": result.hp -= penalty * 40.0
			"strategy": result.strategy -= penalty
			"cooldown": result.cooldown -= penalty * 0.05
	return result

func _rune_description(rune: Dictionary) -> String:
	var effect := _rune_effect(rune)
	var parts: Array[String] = []
	if not is_zero_approx(float(effect.hp)): parts.append("生命%+.0f" % float(effect.hp))
	if not is_zero_approx(float(effect.strategy)): parts.append("兵略%+.1f" % float(effect.strategy))
	if not is_zero_approx(float(effect.cooldown)): parts.append(("冷却缩减+%.3fs" % float(effect.cooldown)) if float(effect.cooldown) > 0 else "冷却增加%.3fs" % absf(float(effect.cooldown)))
	return " · ".join(parts)

func _rune_display_name(rune: Dictionary) -> String:
	var tier: Dictionary = RUNE_TIERS[clampi(int(rune.tier), 1, 6) - 1]
	var kind := _rune_kind(str(rune.kind))
	return str(tier.name) + "·" + str(kind.get("class", "")) + "·" + str(kind.get("name", ""))

func _talent_key(tree_id: String, node_name: String) -> String:
	return tree_id + ":" + node_name

func _talent_level(tree_id: String, node_name: String) -> int:
	return int(talent_levels.get(_talent_key(tree_id, node_name), 0))

func _talent_node(tree_id: String, node_name: String) -> Array:
	if not TALENT_TREES.has(tree_id): return []
	for node in TALENT_TREES[tree_id].nodes:
		if str(node[0]) == node_name: return node
	return []

func _talent_effect_description(tree_id: String, node_name: String) -> String:
	var specials := {
		"all:明君":"每级使我方主公最大生命值增加 2000，满级增加 4000。",
		"all:神算":"每场战斗开局随机 3 名友军行动条 +30。",
		"all:百炼":"每级使符文转换消耗降低 10%，满级降低 20%。",
		"all:天命":"所有阵营羁绊数值额外提高 20%。",
		"all:群英":"所有武将生命 +400、兵略 +10、技能冷却减少 0.5 秒。",
		"all:长治":"我方主公最大生命值增加 5000。",
		"shu:汉室坚壁":"每级使蜀阵营 2/5/8 人羁绊减伤各增加 1%，满级变为 4%/7%/10%。",
		"shu:桃园同心":"每级使蜀阵营 8 人羁绊叠层上限 +1、每层减伤 +1%、持续时间 +1 秒。",
		"wei:中枢令典":"每级使魏阵营 2/5/8 人羁绊控制强化各增加 1%，满级变为 4%/7%/10%。",
		"wei:乘胜追击":"每级使魏阵营 8 人羁绊对减益目标伤害提高 4%，满级由 8%提高到 16%。",
		"wu:三世基业":"每级使吴阵营 2/5/8 人羁绊生命加成各增加 1%，满级变为 4%/7%/10%。",
		"wu:同舟共济":"1级：8 人羁绊均摊后回复由 5%提高到 7%；2级提高到 9%。",
		"qun:烽火燎原":"每级使群阵营 2/5/8 人羁绊冷却强化各增加 1%，满级变为 4%/7%/10%。",
		"qun:逐鹿中原":"每级使群阵营 8 人羁绊的技能连发概率提高 4%，满级由 8%提高到 16%。"
	}
	var key := _talent_key(tree_id, node_name)
	if specials.has(key): return str(specials[key])
	var node := _talent_node(tree_id, node_name)
	if node.is_empty(): return ""
	var effects: Array[String] = []
	if float(node[3]) != 0.0: effects.append("每级生命 %+.0f，满级 %+.0f" % [float(node[3]), float(node[3]) * int(node[2])])
	if float(node[4]) != 0.0: effects.append("每级兵略 %+.1f，满级 %+.1f" % [float(node[4]), float(node[4]) * int(node[2])])
	if float(node[5]) != 0.0: effects.append("每级技能冷却减少 %.3f 秒，满级减少 %.3f 秒" % [float(node[5]), float(node[5]) * int(node[2])])
	return "；".join(effects) + "。"

func _talent_points_before_layer(tree_id: String, layer: int) -> int:
	var total := 0
	for node in TALENT_TREES[tree_id].nodes:
		if int(node[1]) < layer: total += _talent_level(tree_id, str(node[0]))
	return total

func _can_upgrade_talent(tree_id: String, node_name: String) -> bool:
	var node := _talent_node(tree_id, node_name)
	if node.is_empty() or general_stars < 5: return false
	if _talent_level(tree_id, node_name) >= int(node[2]): return false
	return _talent_points_before_layer(tree_id, int(node[1])) >= int(node[6])

func _upgrade_talent(tree_id: String, node_name: String) -> bool:
	if not _can_upgrade_talent(tree_id, node_name): return false
	general_stars -= 5
	var key := _talent_key(tree_id, node_name)
	talent_levels[key] = int(talent_levels.get(key, 0)) + 1
	_save_progression()
	return true

func _reset_talent_tree(tree_id: String) -> int:
	if not TALENT_TREES.has(tree_id): return 0
	var refunded := 0
	for node in TALENT_TREES[tree_id].nodes:
		var key := _talent_key(tree_id, str(node[0]))
		refunded += int(talent_levels.get(key, 0)) * 5
		talent_levels.erase(key)
	general_stars += refunded
	_save_progression()
	return refunded

func _talent_stat_bonus(hero_id: String) -> Dictionary:
	var result := {"hp":0.0, "strategy":0.0, "cooldown":0.0}
	var faction := str(heroes[hero_id].f)
	for tree_id in ["all", faction]:
		for node in TALENT_TREES[tree_id].nodes:
			var level := _talent_level(tree_id, str(node[0]))
			result.hp += float(node[3]) * level
			result.strategy += float(node[4]) * level
			result.cooldown += float(node[5]) * level
	return result

func _rune_stat_bonus(hero_id: String) -> Dictionary:
	var result := {"hp":0.0, "strategy":0.0, "cooldown":0.0}
	for uid in rune_loadouts.get(hero_id, []):
		var rune = _rune_by_uid(int(uid))
		if rune == null: continue
		var effect := _rune_effect(rune)
		result.hp += float(effect.hp)
		result.strategy += float(effect.strategy)
		result.cooldown += float(effect.cooldown)
	return result

func _apply_progression_to_new_unit(unit: Dictionary) -> void:
	var hero_id := str(unit.hero_id)
	if str(unit.team) == "enemy":
		var hp_mult := _challenge_enemy_hp_multiplier()
		unit.hp = float(unit.hp) * hp_mult
		unit.max_hp = float(unit.max_hp) * hp_mult
		unit.skill_value_bonus = _challenge_strategy_bonus()
		return
	var talent := _talent_stat_bonus(hero_id)
	var runes := _rune_stat_bonus(hero_id)
	var base_hp := float(heroes[hero_id].hp)
	var rune_hp := maxf(float(runes.hp), -base_hp * 0.30)
	unit.max_hp = maxf(1.0, base_hp + float(talent.hp) + rune_hp)
	unit.hp = unit.max_hp
	unit.skill_value_bonus = float(talent.strategy) + float(runes.strategy)
	unit.talent_cooldown_reduction = float(talent.cooldown)
	unit.rune_cooldown_reduction = float(runes.cooldown)

func _player_ruler_max_hp() -> int:
	return RULER_MAX_HP + 2000 * _talent_level("all", "明君") + 5000 * _talent_level("all", "长治")

func _talent_bond_multiplier(team: String) -> float:
	return 1.2 if team == "player" and _talent_level("all", "天命") > 0 else 1.0

func _talent_faction_tier_bonus(team: String, faction: String) -> float:
	if team != "player": return 0.0
	var node_names := {"shu":"汉室坚壁", "wei":"中枢令典", "wu":"三世基业", "qun":"烽火燎原"}
	return 0.01 * float(_talent_level(faction, str(node_names[faction])))

func _talent_opening_action_bonus() -> bool:
	return _talent_level("all", "神算") > 0

func _set_home_hero(hero_id: String) -> void:
	if not heroes.has(hero_id): return
	home_hero_id = hero_id
	_save_progression()

func _add_debug_souls() -> void:
	general_souls += 10000
	_save_progression()

func _add_debug_stars() -> void:
	general_stars += 100
	_save_progression()
