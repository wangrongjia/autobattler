# 无尽远征·重铸版：只保存静态规则和纯公式。
# 设计目标：我方靠可选择的线性养成与机制构筑变强；敌方靠指数数值曲线最终压垮玩家。

const SAVE_PATH := "user://three_kingdoms_endless_rework_save.json"
const SAVE_VERSION := 9
const CHECKPOINT_INTERVAL := 5
const RESERVE_LIMIT := 18
const DRAFT_PICKS := 3

# 我方无条件获得的线性底成长。保证正常构筑能进入 30 回合区间，同时不会形成百分比复利。
const PLAYER_HP_PER_ROUND := 1500.0
const PLAYER_STRATEGY_PER_ROUND := 5.0

# 敌方曲线。生命和兵略均为指数成长；行动/冷却只小幅增长并封顶。
const ENEMY_HP_BASE := 1.45
const ENEMY_HP_GROWTH := 1.10
const ENEMY_HP_CHECKPOINT_GROWTH := 1.07
const ENEMY_STRATEGY_BASE := 100.0
const ENEMY_STRATEGY_GROWTH := 1.045
const ENEMY_STRATEGY_CHECKPOINT_GROWTH := 1.06
const ENEMY_RULER_BASE := 1.70
const ENEMY_RULER_GROWTH := 1.105
const ENEMY_RULER_CHECKPOINT_GROWTH := 1.08
const ENEMY_ACTION_PER_CHECKPOINT := 0.012
const ENEMY_ACTION_CAP := 0.10
const ENEMY_HASTE_PER_TEN_ROUNDS := 2.0
const ENEMY_HASTE_CAP := 12.0

# 军府不是固定清单，而是每个据点随机出现 4 项、最多购买 2 项。数值成长保持线性，
# 重点提供选将、经济、站位与核心武将培养方向，让同一阵容也能走出不同构筑。
const ARMORY_PURCHASE_LIMIT := 2
const ARMORY_REFRESH_COST := 150
const ARMORY_ITEMS := [
	{"id":"scout_maps", "name":"游骑舆图", "tag":"选将", "max":2, "base_cost":650, "increment":350,
		"levels":["每个选将候选位每轮额外刷新 1 次", "每个候选位每轮累计额外刷新 2 次"],
		"values":{"refresh_bonus":[1.0,2.0]}},
	{"id":"veteran_roll", "name":"百战名册", "tag":"线性成长", "max":3, "base_cost":700, "increment":300,
		"levels":["每经过 1 回合，全阵容额外生命 +220、兵略 +2", "每回合累计生命 +440、兵略 +4", "每回合累计生命 +660、兵略 +6"],
		"values":{"hp_per_round":[220.0,440.0,660.0], "strategy_per_round":[2.0,4.0,6.0]}},
	{"id":"supply_route", "name":"辎重商路", "tag":"经济", "max":3, "base_cost":550, "increment":300,
		"levels":["每回合基础收入 +80（第 15 回合后仍生效）", "每回合累计 +160", "每回合累计 +240"],
		"values":{"income":[80.0,160.0,240.0]}},
	{"id":"front_oath", "name":"先登血誓", "tag":"前军构筑", "max":3, "base_cost":650, "increment":300,
		"levels":["前排武将最大生命 +5%、伤害 +4%", "累计生命 +10%、伤害 +8%", "累计生命 +15%、伤害 +12%"],
		"values":{"hp_pct":[0.05,0.10,0.15], "damage_pct":[0.04,0.08,0.12]}},
	{"id":"middle_banner", "name":"中军令旗", "tag":"中军构筑", "max":3, "base_cost":650, "increment":300,
		"levels":["中排武将兵略 +12、受控时间 -8%", "累计兵略 +24、受控 -16%", "累计兵略 +36、受控 -24%"],
		"values":{"strategy":[12.0,24.0,36.0], "control_reduction":[0.08,0.16,0.24]}},
	{"id":"rear_quiver", "name":"神机箭匣", "tag":"后军构筑", "max":3, "base_cost":650, "increment":300,
		"levels":["后排武将伤害 +4%、开场行动条 +4", "累计伤害 +8%、行动条 +8", "累计伤害 +12%、行动条 +12"],
		"values":{"damage_pct":[0.04,0.08,0.12], "opening_action":[4.0,8.0,12.0]}},
	{"id":"extra_recruit", "name":"求贤加试", "tag":"一次性", "max":99, "base_cost":400, "increment":0, "consumable":true,
		"levels":["下一回合额外进行 1 次武将三选一"]}
]

# 将印树保持七层深度，但成本压在可持续养成范围内。专属节点效果来自每名武将自己的数据树。
const IMPRINT_NODE_COSTS := {"root":3, "role":5, "skill":7, "branch":9, "bond":8, "evergreen":10, "soul":16}
const IMPRINT_ROOT_SWIFT_HASTE := 8.0
const IMPRINT_ROOT_SWIFT_ACTION := 0.035
const ROOT_CLASS_BONUS := {
	"output":{"hp":0.025, "strategy":0.04},
	"tank":{"hp":0.05, "strategy":0.02},
	"support":{"hp":0.035, "strategy":0.03},
	"aura":{"hp":0.035, "strategy":0.025}
}

# 战策刻意控制在低斜率。数值项使用加法，不创建新的乘算膨胀区。
const STRATEGIES := [
	{"id":"provisions", "name":"军粮增配", "tag":"全军成长", "max":4,
		"levels":["全军最大生命 +700", "全军最大生命累计 +1400", "全军最大生命累计 +2100", "全军最大生命累计 +2800"],
		"per_level":{"hp_flat":700.0}},
	{"id":"drill", "name":"精兵操练", "tag":"全军成长", "max":4,
		"levels":["全军兵略 +10", "全军兵略累计 +20", "全军兵略累计 +30", "全军兵略累计 +40"],
		"per_level":{"strategy_flat":10.0}},
	{"id":"march", "name":"疾行军令", "tag":"节奏", "max":4,
		"levels":["全军冷却极速 +5", "全军冷却极速累计 +10", "全军冷却极速累计 +15", "全军冷却极速累计 +20"],
		"per_level":{"cooldown_haste":5.0}},
	{"id":"assault", "name":"先登之志", "tag":"开场机制", "max":3,
		"levels":["全军开场行动条 +8", "全军开场行动条 +13", "全军开场行动条 +18"],
		"values":{"opening_action":[8.0,13.0,18.0]}},
	{"id":"bulwark", "name":"结阵持守", "tag":"开场机制", "max":3,
		"levels":["开场获得 5% 最大生命护盾", "开场护盾提高至 8%", "开场护盾提高至 11%"],
		"values":{"opening_shield":[0.05,0.08,0.11]}},
	{"id":"golden", "name":"金身一瞬", "tag":"特殊机制", "max":3,
		"levels":["开场无敌 0.5 秒", "开场无敌 0.8 秒", "开场无敌 1.1 秒"],
		"values":{"opening_invulnerable":[0.5,0.8,1.1]}},
	{"id":"laststand", "name":"背水列阵", "tag":"特殊机制", "max":3,
		"levels":["生命低于 35% 时增伤 6%", "低生命增伤提高至 10%", "低生命增伤提高至 14%"],
		"values":{"low_hp_damage":[0.06,0.10,0.14]}},
	{"id":"medic", "name":"随军医官", "tag":"续航机制", "max":3,
		"levels":["每名武将每场首次低于 25% 生命时回复 8% 最大生命", "回复提高至 12%", "回复提高至 16%"],
		"values":{"emergency_heal":[0.08,0.12,0.16]}},
	{"id":"revive", "name":"整军再起", "tag":"容错机制", "max":3,
		"levels":["每场首名阵亡武将以 12% 生命复起", "复起生命提高至 18%", "复起生命提高至 24%"],
		"values":{"revive_ratio":[0.12,0.18,0.24]}},
	{"id":"four_factions", "name":"四方协力", "tag":"阵容机制", "max":3,
		"levels":["每个上阵阵营使全军增伤 1%", "每阵营增伤提高至 1.5%", "每阵营增伤提高至 2%"],
		"values":{"damage_per_faction":[0.01,0.015,0.02]}},
	{"id":"reserve_training", "name":"全军轮训", "tag":"全军成长", "max":3,
		"levels":["每到据点，全阵容生命 +180、兵略 +2", "每据点生命 +260、兵略 +3", "每据点生命 +340、兵略 +4"],
		"values":{"checkpoint_hp":[180.0,260.0,340.0], "checkpoint_strategy":[2.0,3.0,4.0]}},
	{"id":"ruler_guard", "name":"护主军阵", "tag":"主公机制", "max":3,
		"levels":["主公受到伤害降低 5%", "主公减伤提高至 8%", "主公减伤提高至 11%"],
		"values":{"ruler_reduction":[0.05,0.08,0.11]}}
]

# 敌军每个据点获得一项公开军势。它们以机制为主，避免把冷却堆到无法观察。
const ENEMY_DOCTRINES := [
	{"id":"iron", "name":"玄甲军阵", "max":3, "levels":["敌军开场获得 6% 最大生命护盾", "开场护盾提高至 9%", "开场护盾提高至 12%"], "values":{"shield":[0.06,0.09,0.12]}},
	{"id":"unyielding", "name":"不动如山", "max":3, "levels":["敌军受到伤害降低 3%", "减伤提高至 5%", "减伤提高至 7%"], "values":{"reduction":[0.03,0.05,0.07]}},
	{"id":"fury", "name":"哀兵之势", "max":3, "levels":["敌军生命低于 35% 时增伤 8%", "增伤提高至 13%", "增伤提高至 18%"], "values":{"low_hp_damage":[0.08,0.13,0.18]}},
	{"id":"ward", "name":"镇魂军旗", "max":3, "levels":["敌军开场无敌 0.35 秒", "开场无敌提高至 0.55 秒", "开场无敌提高至 0.75 秒"], "values":{"invulnerable":[0.35,0.55,0.75]}},
	{"id":"siege", "name":"破军长驱", "max":3, "levels":["敌军对主公伤害 +6%", "对主公伤害 +10%", "对主公伤害 +14%"], "values":{"ruler_damage":[0.06,0.10,0.14]}},
	{"id":"veterans", "name":"百战精锐", "max":3, "levels":["敌军兵略额外提高 4%", "额外提高 7%", "额外提高 10%"], "values":{"strategy_pct":[0.04,0.07,0.10]}}
]

static func depth(round_number: int) -> int:
	return maxi(0, round_number - 1)

static func checkpoint_index(round_number: int) -> int:
	return int(floor(float(maxi(0, round_number - 1)) / float(CHECKPOINT_INTERVAL)))

static func completed_checkpoints(round_number: int) -> int:
	return maxi(0, int(floor(float(round_number) / float(CHECKPOINT_INTERVAL))))

static func enemy_hp_multiplier(round_number: int) -> float:
	return ENEMY_HP_BASE * pow(ENEMY_HP_GROWTH, depth(round_number)) * pow(ENEMY_HP_CHECKPOINT_GROWTH, checkpoint_index(round_number))

static func enemy_strategy(round_number: int) -> float:
	return ENEMY_STRATEGY_BASE * pow(ENEMY_STRATEGY_GROWTH, depth(round_number)) * pow(ENEMY_STRATEGY_CHECKPOINT_GROWTH, checkpoint_index(round_number))

static func enemy_ruler_multiplier(round_number: int) -> float:
	return ENEMY_RULER_BASE * pow(ENEMY_RULER_GROWTH, depth(round_number)) * pow(ENEMY_RULER_CHECKPOINT_GROWTH, checkpoint_index(round_number))

static func enemy_action_multiplier(round_number: int) -> float:
	return 1.0 + minf(ENEMY_ACTION_CAP, checkpoint_index(round_number) * ENEMY_ACTION_PER_CHECKPOINT)

static func enemy_cooldown_haste(round_number: int) -> float:
	return minf(ENEMY_HASTE_CAP, floorf(float(maxi(0, round_number - 1)) / 10.0) * ENEMY_HASTE_PER_TEN_ROUNDS)

static func strategy_entry(id: String) -> Dictionary:
	for entry in STRATEGIES:
		if str(entry.id) == id: return entry
	return {}

static func doctrine_entry(id: String) -> Dictionary:
	for entry in ENEMY_DOCTRINES:
		if str(entry.id) == id: return entry
	return {}

static func armory_entry(id: String) -> Dictionary:
	for entry in ARMORY_ITEMS:
		if str(entry.id) == id: return entry
	return {}

static func leveled_value(entry: Dictionary, key: String, level: int) -> float:
	if level <= 0: return 0.0
	var values: Dictionary = entry.get("values", {})
	if values.has(key):
		var options: Array = values[key]
		return float(options[clampi(level - 1, 0, options.size() - 1)])
	return float(entry.get("per_level", {}).get(key, 0.0)) * level
