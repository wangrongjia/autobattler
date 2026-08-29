# 无尽远征 · 规则常量库（docs/无尽模式-融合终稿.md v0.4）
# 仅存放静态数据与纯公式；运行状态与系统逻辑在 systems/endless_system.gd。

# ---- §2.1 数值曲线 ----
# R=回合；D=R-1；C=floor((R-1)/5)
const ENEMY_HP_BASE := 1.75
const ENEMY_HP_GROWTH := 1.065        # ^D（v0.4 放缓）
const ENEMY_HP_CHECKPOINT := 0.08     # ×(1+0.08C)
const ENEMY_HP_CAP := 200.0
const ENEMY_STRATEGY_BASE := 100.0
const ENEMY_STRATEGY_PER_ROUND := 6.0
const ENEMY_STRATEGY_PER_CHECKPOINT := 15.0
const ENEMY_STRATEGY_CAP := 2000.0
const ENEMY_ACTION_GAIN_CAP := 0.35
const ENEMY_ACTION_GAIN_PER_C := 0.02
const RULER_HP_BASE := 1.6
const RULER_HP_GROWTH := 1.095        # ^D（v0.4 加陡）
const RULER_HP_CHECKPOINT := 0.14     # ×(1+0.14C)
const RULER_HP_CAP := 400.0

# ---- §1.2 回合节奏 ----
const CHECKPOINT_INTERVAL := 5        # 每 5 回合一个据点
const FIRST_EXPEDITION_ROUND := 15    # 首次远征完成（据点 3，凯旋/继续）
const GOLD_FREEZE_ROUND := 15         # 此后基础收入冻结
const ENDLESS_RESERVE_LIMIT := 18     # 无尽备战区（普通闯关 9）
const ENDLESS_DRAFT_PICKS := 3        # 全程 3 次/回合，永不降频

# ---- §2.4 军势池（14 条）----
const MOMENTUM_POOL := [
	{"id": "swift", "name": "疾行如风", "levels": [
		{"desc": "常驻行动增速 +6%；开场行动条 +10", "gain": 0.06, "opening": 10.0},
		{"desc": "常驻行动增速 +10%；开场行动条 +20", "gain": 0.10, "opening": 20.0},
		{"desc": "常驻行动增速 +14%；开场行动条 +30", "gain": 0.14, "opening": 30.0}]},
	{"id": "ironwall", "name": "铁壁轮转", "levels": [
		{"desc": "每 10 秒依次为前/中/后排提供 8% 最大生命护盾 3 秒", "shield": 0.08},
		{"desc": "护盾提高至 12% 最大生命", "shield": 0.12},
		{"desc": "护盾提高至 16% 最大生命", "shield": 0.16}]},
	{"id": "soulflag", "name": "镇魂军旗", "levels": [
		{"desc": "开场 2 秒控制免疫；此后受控时长 -20%", "immune": 2.0, "resist": 0.20},
		{"desc": "开场 3 秒控制免疫；受控时长 -30%", "immune": 3.0, "resist": 0.30},
		{"desc": "开场 4 秒控制免疫；受控时长 -40%", "immune": 4.0, "resist": 0.40}]},
	{"id": "golden", "name": "金身战阵", "levels": [
		{"desc": "每 12 秒预警 0.8 秒后全军免伤 0.8 秒", "invuln": 0.8},
		{"desc": "免伤窗口延长至 1.1 秒", "invuln": 1.1},
		{"desc": "免伤窗口延长至 1.4 秒", "invuln": 1.4}]},
	{"id": "laststand", "name": "背水死战", "levels": [
		{"desc": "生命 <35% 后伤害与行动增速 +10%", "bonus": 0.10},
		{"desc": "加成提高至 +18%", "bonus": 0.18},
		{"desc": "加成提高至 +25%", "bonus": 0.25}]},
	{"id": "phoenix", "name": "浴火再起", "levels": [
		{"desc": "每回合前 1 名阵亡普通敌将以 20% 生命复起一次", "count": 1},
		{"desc": "复起名额提高至 2 名", "count": 2},
		{"desc": "复起名额提高至 3 名", "count": 3}]},
	{"id": "linked", "name": "连营合击", "levels": [
		{"desc": "敌将施法后同排最低条友军 +8 行动条", "action": 8.0},
		{"desc": "行动条提高至 +12", "action": 12.0},
		{"desc": "行动条提高至 +16", "action": 16.0}]},
	{"id": "guardian", "name": "玄甲护主", "levels": [
		{"desc": "敌方主公每损失 25% 生命，存活敌将各获 15% 最大生命护盾", "shield": 0.15},
		{"desc": "护盾提高至 25% 最大生命", "shield": 0.25},
		{"desc": "护盾提高至 35% 最大生命", "shield": 0.35}]},
	{"id": "breaker", "name": "破军长驱", "levels": [
		{"desc": "敌方对玩家主公伤害 +8%", "ruler": 0.08},
		{"desc": "对主公伤害提高至 +14%", "ruler": 0.14},
		{"desc": "对主公伤害提高至 +20%", "ruler": 0.20}]},
	{"id": "warmachine", "name": "以战养战", "levels": [
		{"desc": "敌将造成有效伤害获 +2 临时兵略（每人每回合上限 20）", "gain": 2.0, "cap": 20.0},
		{"desc": "临时兵略提高至 +3（上限 20）", "gain": 3.0, "cap": 20.0},
		{"desc": "临时兵略提高至 +4（上限 20）", "gain": 4.0, "cap": 20.0}]},
	{"id": "counter", "name": "反制之阵", "levels": [
		{"desc": "每名敌将首次被控结束后获 3 秒 50% 控制抗性", "time": 3.0},
		{"desc": "抗性持续 4 秒", "time": 4.0},
		{"desc": "抗性持续 5 秒", "time": 5.0}]},
	{"id": "swap", "name": "阴阳易位", "levels": [
		{"desc": "每 10 秒前后排互换一组适配武将并获 2 秒 15% 减伤", "reduce_time": 2.0},
		{"desc": "减伤持续 3 秒", "reduce_time": 3.0},
		{"desc": "减伤持续 4 秒", "reduce_time": 4.0}]},
	{"id": "antidote", "name": "百毒不侵", "levels": [
		{"desc": "受到的灼烧/中毒伤害 -35%", "reduce": 0.35},
		{"desc": "灼烧/中毒伤害 -55%", "reduce": 0.55},
		{"desc": "灼烧/中毒伤害 -75%", "reduce": 0.75}]},
	{"id": "mourning", "name": "哀兵必胜", "levels": [
		{"desc": "每名敌将阵亡使存活敌军兵略 +4%（单场上限 20%）", "pct": 0.04, "cap": 0.20},
		{"desc": "兵略 +6%（上限 30%）", "pct": 0.06, "cap": 0.30},
		{"desc": "兵略 +8%（上限 40%）", "pct": 0.08, "cap": 0.40}]}
]

# 百毒不侵自据点 5（回合 25）起才可出现
const MOMENTUM_LATE_UNLOCK := {"antidote": 5}

# ---- §2.5 统帅回合事件（每 10 回合，仅本回合）----
const COMMANDER_EVENTS := [
	{"id": "arrowrain", "name": "箭雨压阵", "desc": "每 8 秒预警两列，1 秒后每格造成 120% 敌均兵略伤害（空格伤主公）"},
	{"id": "mist", "name": "迷雾蔽日", "desc": "前 8 秒敌方后排直伤 -40%"},
	{"id": "wardrums", "name": "鼓角齐鸣", "desc": "双方首次施法各 +30 行动条"},
	{"id": "famine", "name": "粮道断绝", "desc": "本回合我方治疗 -30%，护盾不受影响"},
	{"id": "thunderpool", "name": "雷池天威", "desc": "空格每 5 秒落雷 100% 敌均兵略，对双方主公生效"},
	{"id": "duel", "name": "单骑叫阵", "desc": "一名敌将成统帅：生命 ×1.6、技能强化；击杀后全体敌军虚弱 5 秒（受伤 +20%）"}
]

# ---- §3.2 战策池（20 条，据点后免费三选一，本局生效，最高 3 级）----
const STRATEGY_POOL := [
	{"id": "vanguard", "name": "先登之志", "levels": [
		{"desc": "每场开始随机 2 名我方武将获 20 初始行动条", "count": 2, "action": 20.0},
		{"desc": "3 名武将（优先前军）获 20 初始行动条", "count": 3, "action": 20.0},
		{"desc": "4 名武将（优先前军）获 20 初始行动条", "count": 4, "action": 20.0}]},
	{"id": "rotation", "name": "轮转军阵", "levels": [
		{"desc": "同列三种射程齐全时，该列生命 +6%、行动增速 +5%", "hp": 0.06, "gain": 0.05},
		{"desc": "该列生命 +9%、行动增速 +8%", "hp": 0.09, "gain": 0.08},
		{"desc": "该列生命 +12%、行动增速 +12%", "hp": 0.12, "gain": 0.12}]},
	{"id": "desperate", "name": "背水一战", "levels": [
		{"desc": "主公低于 40% 生命时，全军增伤 +8%、减伤 +4%", "damage": 0.08, "reduce": 0.04},
		{"desc": "增伤 +14%、减伤 +7%", "damage": 0.14, "reduce": 0.07},
		{"desc": "增伤 +20%、减伤 +10%", "damage": 0.20, "reduce": 0.10}]},
	{"id": "shieldcounter", "name": "以守为攻", "levels": [
		{"desc": "护盾被打破时对攻击者反击 40% 护盾原量（同人 3 秒冷却）", "ratio": 0.40},
		{"desc": "反击提高至 70% 护盾原量", "ratio": 0.70},
		{"desc": "反击提高至 100% 护盾原量", "ratio": 1.00}]},
	{"id": "survivor", "name": "百战余生", "levels": [
		{"desc": "连续存活 3 回合的武将每回合生命 +2%、兵略 +1（阵亡失去一半层数）", "hp": 0.02, "strategy": 1.0},
		{"desc": "每回合生命 +3%、兵略 +1", "hp": 0.03, "strategy": 1.0},
		{"desc": "每回合生命 +4%、兵略 +1", "hp": 0.04, "strategy": 1.0}]},
	{"id": "windsprint", "name": "疾风连营", "levels": [
		{"desc": "同排友军施法后其他同排获 4 行动条（全队每秒上限 12）", "action": 4.0},
		{"desc": "行动条提高至 +6", "action": 6.0},
		{"desc": "行动条提高至 +8", "action": 8.0}]},
	{"id": "medic", "name": "军医随阵", "levels": [
		{"desc": "每场首次有武将低于 25% 生命时治疗 30% 兵略并清除重伤", "heal": 0.30},
		{"desc": "治疗提高至 45% 兵略", "heal": 0.45},
		{"desc": "治疗提高至 60% 兵略", "heal": 0.60}]},
	{"id": "flagcapture", "name": "破阵夺旗", "levels": [
		{"desc": "破阵后下一回合 +200 金币、全军 +20 初始行动条", "gold": 200, "action": 20.0},
		{"desc": "+350 金币、+20 初始行动条", "gold": 350, "action": 20.0},
		{"desc": "+500 金币、+20 初始行动条", "gold": 500, "action": 20.0}]},
	{"id": "fourcorners", "name": "四方来援", "levels": [
		{"desc": "每个不同阵营全军 +2% 属性；四阵营齐全时全军每场抵挡第一次控制", "pct": 0.02},
		{"desc": "每阵营 +3% 属性", "pct": 0.03},
		{"desc": "每阵营 +4% 属性", "pct": 0.04}]},
	{"id": "elite", "name": "精兵之道", "levels": [
		{"desc": "场上 ≤8 人时全军兵略与伤害 +8%", "pct": 0.08},
		{"desc": "兵略与伤害 +12%", "pct": 0.12},
		{"desc": "兵略与伤害 +16%", "pct": 0.16}]},
	{"id": "seaofmen", "name": "人海之势", "levels": [
		{"desc": "每名不同武将全军生命 +1.5%；满 15 人主公减伤 +5%", "hp": 0.015, "ruler": 0.05},
		{"desc": "满 15 人主公减伤 +8%", "hp": 0.015, "ruler": 0.08},
		{"desc": "满 15 人主公减伤 +12%", "hp": 0.015, "ruler": 0.12}]},
	{"id": "embers", "name": "余烬复燃", "levels": [
		{"desc": "灼烧/中毒/恐惧结束时 25% 概率保留一半时长", "chance": 0.25},
		{"desc": "概率提高至 40%", "chance": 0.40},
		{"desc": "概率提高至 55%", "chance": 0.55}]},
	{"id": "recovery", "name": "休养生息", "levels": [
		{"desc": "每回合整备阶段主公回复 2% 最大生命", "pct": 0.02},
		{"desc": "回复 3% 最大生命", "pct": 0.03},
		{"desc": "回复 4% 最大生命", "pct": 0.04}]},
	{"id": "brokencauldron", "name": "破釜沉舟", "levels": [
		{"desc": "获取即永久：全军兵略 +15%，主公最大生命 -8%", "pct": 0.15},
		{"desc": "全军兵略 +25%", "pct": 0.25},
		{"desc": "全军兵略 +35%", "pct": 0.35}]},
	{"id": "rearguard", "name": "以逸待劳", "levels": [
		{"desc": "我方后排受伤 -6%", "reduce": 0.06},
		{"desc": "受伤 -10%", "reduce": 0.10},
		{"desc": "受伤 -14%", "reduce": 0.14}]},
	{"id": "brainstorm", "name": "集思广略", "levels": [
		{"desc": "获取后 5 回合内每回合选将次数 +1", "rounds": 5},
		{"desc": "7 回合内选将次数 +1", "rounds": 7},
		{"desc": "9 回合内选将次数 +1", "rounds": 9}]},
	{"id": "sharedfate", "name": "同舟共济", "levels": [
		{"desc": "我方全体受伤的 8% 由全体存活武将均摊", "share": 0.08},
		{"desc": "均摊比例 12%", "share": 0.12},
		{"desc": "均摊比例 16%", "share": 0.16}]},
	{"id": "leadcharge", "name": "身先士卒", "levels": [
		{"desc": "主公最大生命 +10%，并立即回复等量", "pct": 0.10},
		{"desc": "主公最大生命 +15%", "pct": 0.15},
		{"desc": "主公最大生命 +20%", "pct": 0.20}]},
	{"id": "highrampart", "name": "深沟高垒", "levels": [
		{"desc": "每场战斗前 4 秒全军减伤 15%", "reduce": 0.15},
		{"desc": "减伤 25%", "reduce": 0.25},
		{"desc": "减伤 35%", "reduce": 0.35}]},
	{"id": "delay", "name": "缓兵之计", "levels": [
		{"desc": "敌方本回合新入场武将开局行动条 -20", "reduce": 20.0},
		{"desc": "开局行动条 -35", "reduce": 35.0},
		{"desc": "开局行动条 -50", "reduce": 50.0}]}
]

# ---- §3.3 军府整备（据点商店）----
const JUNFU_ITEMS := [
	{"id": "rest", "name": "休养主公", "base_cost": 600, "increment": 250, "per_checkpoint": -1,
		"desc": "主公回复 8% 最大生命"},
	{"id": "libing", "name": "厉兵", "base_cost": 500, "increment": 200, "per_hero_cap": 5,
		"desc": "本局该武将最大生命 +6%/层（≤5 层）"},
	{"id": "moma", "name": "秣马", "base_cost": 500, "increment": 200, "per_hero_cap": 5,
		"desc": "本局该武将兵略 +5/层（≤5 层）"},
	{"id": "jixing", "name": "急行", "base_cost": 700, "increment": 250, "per_hero_cap": 4,
		"desc": "本局该武将冷却 -0.25s/层（≤4 层，守将印通道 30% 合并下限）"},
	{"id": "reorganize", "name": "重整", "base_cost": 800, "increment": 0, "per_checkpoint": 1,
		"desc": "下回合主公首次致命伤害保留 1 点"},
	{"id": "recruit", "name": "求贤", "base_cost": 350, "increment": 0, "per_checkpoint": 3,
		"desc": "本回合额外一次三选一"},
	{"id": "revive", "name": "还魂", "base_cost": 900, "increment": 0, "per_checkpoint": 1,
		"desc": "复活一名本局阵亡武将入备战（保留军府层数）"}
]

# ---- §4.1 将印掉落 ----
# 本据点将印 = 2 + 2×floor((据点序号-3)/3)，恒偶数严格五五分（通用/专属各半）
static func checkpoint_imprint_count(checkpoint: int) -> int:
	if checkpoint < 3: return 0
	return 2 + 2 * int(floor(float(checkpoint - 3) / 3.0))

static func checkpoint_soul_reward(checkpoint: int) -> int:
	return 1000 + 500 * checkpoint

# ---- §2.1 曲线公式 ----
static func depth(round_number: int) -> int:
	return maxi(0, round_number - 1)

static func checkpoint_index_of(round_number: int) -> int:
	return int(floor(float(maxi(0, round_number - 1)) / float(CHECKPOINT_INTERVAL)))

static func enemy_hp_multiplier(round_number: int) -> float:
	var d := depth(round_number)
	var c := checkpoint_index_of(round_number)
	var result: float = ENEMY_HP_BASE * pow(ENEMY_HP_GROWTH, d) * (1.0 + ENEMY_HP_CHECKPOINT * c)
	return minf(result, ENEMY_HP_CAP)

static func enemy_strategy_bonus(round_number: int) -> float:
	var d := depth(round_number)
	var c := checkpoint_index_of(round_number)
	return minf(ENEMY_STRATEGY_BASE + ENEMY_STRATEGY_PER_ROUND * d + ENEMY_STRATEGY_PER_CHECKPOINT * c, ENEMY_STRATEGY_CAP)

static func enemy_action_gain(round_number: int) -> float:
	var c := checkpoint_index_of(round_number)
	return 1.0 + minf(ENEMY_ACTION_GAIN_CAP, ENEMY_ACTION_GAIN_PER_C * c)

static func enemy_ruler_hp_multiplier(round_number: int) -> float:
	var d := depth(round_number)
	var c := checkpoint_index_of(round_number)
	var result: float = RULER_HP_BASE * pow(RULER_HP_GROWTH, d) * (1.0 + RULER_HP_CHECKPOINT * c)
	return minf(result, RULER_HP_CAP)

# ---- §2.3 敌将评分导演：回合 → 智能权重 ----
static func enemy_director_weight(round_number: int) -> float:
	if round_number >= 30: return 0.90
	if round_number >= 20: return 0.90
	if round_number >= 10: return 0.75
	if round_number >= 5: return 0.50
	return 0.25

# ---- 敌将角色标签（评分导演的补角色/补行位用）----
const HERO_ROLES := {
	"liubei": ["heal", "support"], "guanyu": ["damage"], "zhangfei": ["support", "tank"],
	"zhaoyun": ["damage"], "huangzhong": ["damage"], "machao": ["damage"],
	"liushan": ["support"], "zhugeliang": ["damage"], "jiangwei": ["damage"],
	"menghuo": ["control", "tank"], "zhurong": ["damage", "dot"], "dailaidongzhu": ["damage"],
	"weiyan": ["damage"], "madai": ["damage"], "pangtong": ["damage"],
	"caocao": ["control", "damage"], "dianwei": ["damage"], "xuchu": ["damage", "tank"],
	"zhangliao": ["damage", "control"], "yuejin": ["damage"], "zhanghe": ["control", "damage"],
	"xuhuang": ["control", "tank"], "yujin": ["shield"], "xiahouyuan": ["damage", "control"],
	"caoren": ["control", "shield"], "xiahoudun": ["damage", "tank"], "simayi": ["damage"],
	"guojia": ["control"], "xunyu": ["support"], "jiaxu": ["dot"],
	"lvmeng": ["damage"], "sunjian": ["damage"], "sunce": ["damage"],
	"sunquan": ["support"], "sunshangxiang": ["damage"], "daqiao": ["heal"],
	"xiaoqiao": ["control"], "taishici": ["damage", "dot"], "dingfeng": ["damage", "control"],
	"xusheng": ["control", "tank"], "ganning": ["damage"], "huanggai": ["damage"],
	"lvbu": ["damage"], "dongzhuo": ["damage", "tank"], "diaochan": ["control"],
	"gaoshun": ["control", "damage"], "chengong": ["support"], "yanliang": ["damage"],
	"wenchou": ["damage"], "qunzhanghe": ["shield"], "gaolan": ["support"],
	"huatuo": ["heal"], "yuji": ["dot"], "zuoci": ["heal"],
	"zhangjiao": ["damage"], "zhangliang": ["support"], "zhangbao": ["damage"]
}

# ---- §4.2 贡献度折算 ----
const CONTROL_VALUE_PER_SECOND := 30.0   # 控制秒数 → 贡献折算
const HEAL_SHIELD_DIVISOR := 0.6         # (治疗+护盾) ÷ 0.6
const CONTRIB_BATTLE_WEIGHT := 0.75      # 最终权重 = 75%×贡献占比 + 25%×参战回合占比
const ROUND_BATTLE_WEIGHT := 0.25
const DRAW_BASE_WEIGHT := 0.85           # 抽取权重 = 85%×最终权重 + 15%÷合格武将数
const DRAW_FLOOR_WEIGHT := 0.15

# ---- §4.3/§4.4 将印树消耗 ----
const IMPRINT_NODE_COSTS := {"root": 5, "role": 10, "skill": 15, "branch": 20, "bond": 20, "evergreen": 20, "soul": 40}
const IMPRINT_ROOT_SWIFT_HASTE := 25.0     # 疾行：+25 冷却极速/级（实际冷却=原冷却×100/(100+极速)，叠加收益递减）
const IMPRINT_ROOT_SWIFT_ACTION := 0.04     # 无冷却武将恒为行动增速 +4%/级（将印面板可手动切换）
const IMPRINT_RESET_SOUL_PER_NODE := 20     # 重置：已投入节点数 × 20 将魂
const IMPRINT_RECORD_BONUS_UNIVERSAL := 1  # 破纪录额外 +2 枚（通用1+专属1）
const IMPRINT_RECORD_BONUS_HERO := 1

# 根基分档（全面加强 ×2.5）：输出 +5%生命/+7.5%兵略；坦克 +10/+5；治疗辅助 +7.5/+7.5；被动光环 +7.5/+5
const ROOT_CLASS_BONUS := {
	"output": {"hp": 0.05, "strategy": 0.075},
	"tank": {"hp": 0.10, "strategy": 0.05},
	"support": {"hp": 0.075, "strategy": 0.075},
	"aura": {"hp": 0.075, "strategy": 0.05}
}

# ---- 存档路径 ----
const ENDLESS_SAVE_PATH := "user://three_kingdoms_endless_save.json"
const ENDLESS_SAVE_VERSION := 8
