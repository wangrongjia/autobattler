# 无尽远征 · 全部 60 棵将印树（七层数据，docs/无尽模式-融合终稿.md §5）
# 层结构：根基(3节点×3级) → 定位(3选2, 2级) → 绝技(3选2, 1~2级) → 分歧(2选1) → 羁绊(2级) → 长青(2级) → 将魂(1级)
# effects 的键为 endless_system.gd 将印效果引擎的关键字；数组值 = 每级增量（总值 = 前 N 级求和）。
# 根基层由 root_class 分档统一计算（生命%/兵略%/疾行），不入 effects。

const ROOT_SWIFT_NOTE := "疾行：+25 冷却极速/级。实际冷却 = 原冷却 × 100/(100+极速)——极速 100 即减半、200 减 2/3，叠加收益递减无上限。无冷却武将自动转为行动增速 +4%/级（可在将印面板手动切换）"

const TREES := {
	# ============ 蜀 · 15 ============
	"liubei": {
		"root_class": "support", "root": ["仁德之君", "桃园遗泽", "德政"],
		"role": [
			{"name": "仁心仁术", "desc": "治疗目标 +1（2 级至 3 名；引擎以治疗扩散表达）", "effects": {"heal_spread_count": [2, 4]}},
			{"name": "汉室宗亲", "desc": "溢出治疗转等量护盾", "effects": {"heal_overflow_shield_pct": [2.5, 2.5]}},
			{"name": "帷幄之仁", "desc": "治疗与护盾效果 +20%/级", "effects": {"heal_pct": [0.2, 0.2], "shield_pct": [0.2, 0.2]}}],
		"skill": [
			{"name": "泽被苍生", "desc": "治疗附带驱散 1 个减益", "max": 1, "effects": {"heal_cleanse": 2}},
			{"name": "濒危之救", "desc": "目标低于 125% 生命时治疗 +100%", "max": 1, "effects": {"heal_low_pct": 1}},
			{"name": "仁德广布", "desc": "治疗持续时长 +3秒（引擎按总治疗量折算 +87.5%）", "max": 1, "effects": {"heal_pct": 0.875}}],
		"branch": [
			{"name": "弘毅宽厚", "desc": "治疗量 +62.5%", "effects": {"heal_pct": 0.625}},
			{"name": "枭雄之姿", "desc": "自身减伤 +37.5%", "effects": {"taken_reduction_pct": 0.375}}],
		"bond": {"name": "桃园之义", "desc": "桃园结义（刘关张）效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "愈战愈仁", "desc": "战斗内每 10 秒治疗量 +10%（2 级 +15%），上限 +50%/100%", "effects": {"growth_heal_pct": [0.1, 0.15]}},
		"soul": {"name": "三顾茅庐", "desc": "每回合首次有友军生命跌破 37.5% 时，立即拉回 75% 并使刘备本次冷却减半（每回合 1 次）", "effects": {"ally_save_threshold": 0.3, "ally_save_heal_pct": 0.75, "ally_save_cooldown_halve": 2}}
	},
	"guanyu": {
		"root_class": "output", "root": ["武圣体魄", "青龙兵略", "偃月疾势"],
		"role": [
			{"name": "列阵破军", "desc": "每多命中一人本次伤害 +10%/级", "effects": {"damage_per_extra_hit_pct": [0.1, 0.1]}},
			{"name": "义绝", "desc": "造成伤害回复自身生命（有桃园时减半）", "effects": {"lifesteal_pct": [0.2, 0.2]}},
			{"name": "武圣威压", "desc": "对前排目标伤害 +20%/级", "effects": {"damage_front_pct": [0.2, 0.2]}}],
		"skill": [
			{"name": "拖刀", "desc": "只命中一人时追加 150% 伤害（引擎以目标排孤立判定）", "max": 1, "effects": {"damage_lone_target_pct": 1.5}},
			{"name": "破空", "desc": "命中空列时对敌方主公 125% 补偿伤害", "max": 1, "effects": {"damage_empty_pct": 1.25}},
			{"name": "春秋大义", "desc": "每击杀一人下次青龙偃月 +37.5%（可叠 3 层）", "max": 1, "effects": {"kill_damage_stack_pct": 0.375}}],
		"branch": [
			{"name": "万人敌", "desc": "多目标 +75%", "effects": {"damage_per_extra_hit_pct": 0.75}},
			{"name": "斩将", "desc": "对残血目标斩杀 +87.5%", "effects": {"damage_low_pct": 0.875}}],
		"bond": {"name": "五虎之威", "desc": "五虎上将（关张赵马黄）效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "威震荆襄", "desc": "战斗内每 10 秒兵略 +7.5%（2 级 +12.5%），上限 +37.5%/75%", "effects": {"growth_strategy_pct": [0.075, 0.125]}},
		"soul": {"name": "威震华夏", "desc": "每回合首次击杀后获 50 行动条，并获得 3秒控制免疫（每回合 1 次）", "effects": {"kill_action_burst": 100}}
	},
	"zhangfei": {
		"root_class": "support", "root": ["燕人体魄", "桓侯兵略", "豹头疾势"],
		"role": [
			{"name": "声如巨雷", "desc": "号令范围扩展至中军（引擎折算技能效果 +25%/级）", "effects": {"skill_effect_pct": [0.25, 0.25]}},
			{"name": "据水断桥", "desc": "被强化前军减伤 +20%/级", "effects": {"grant_front_taken_reduction_pct": [0.2, 0.2]}},
			{"name": "燕人威慑", "desc": "强化量 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}}],
		"skill": [
			{"name": "燕人咆哮", "desc": "前军行动增速 +37.5%（光环表达）", "max": 1, "effects": {"grant_front_action_pct": 0.375}},
			{"name": "长坂之怒", "desc": "释放时压退正前敌 37.5% 行动条", "max": 1, "effects": {"action_push_on_hit_pct": 0.375}},
			{"name": "怒目圆睁", "desc": "前军被控时长 -50%（光环表达）", "max": 1, "effects": {"grant_front_control_reduction_pct": 0.5}}],
		"branch": [
			{"name": "万人之敌", "desc": "强化幅度 +125%", "effects": {"skill_effect_pct": 1.25}},
			{"name": "义释严颜", "desc": "强化时长 +125%，期间前军回血", "effects": {"skill_effect_pct": 0.625, "grant_front_regen_pct": 0.025}}],
		"bond": {"name": "桃园之义", "desc": "桃园结义效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "熊虎之将", "desc": "整局每存活 1 回合，燕人号令强化量 +5%（2 级 +7.5%），上限 +50%/87.5%", "effects": {"round_aura_pct": [0.05, 0.075]}},
		"soul": {"name": "当阳桥断", "desc": "每回合首次有前军友军阵亡时，张飞获 100 行动条且全军伤害 +25% 至战斗结束（每回合 1 次）", "effects": {"front_death_action": 200, "front_death_army_damage_pct": 0.25}}
	},
	"zhaoyun": {
		"root_class": "output", "root": ["龙胆之躯", "常山兵略", "白马疾行"],
		"role": [
			{"name": "一身是胆", "desc": "攻击段数 +1（2 级共 +2）", "effects": {"damage_pct": [0.5, 0.5]}},
			{"name": "七进七出", "desc": "每段命中叠 +10% 伤害", "effects": {"damage_per_extra_hit_pct": [0.1, 0.1]}},
			{"name": "白马义从", "desc": "对前军目标 +20%/级", "effects": {"damage_front_pct": [0.2, 0.2]}}],
		"skill": [
			{"name": "单骑救主", "desc": "对攻击我方后排的目标（后军）伤害 +75%", "max": 1, "effects": {"damage_back_pct": 0.75}},
			{"name": "龙威", "desc": "击杀后返还 50 行动条", "max": 1, "effects": {"action_on_kill_add": 100}},
			{"name": "空城计", "desc": "受击后受伤 -30%（引擎常驻表达）", "max": 1, "effects": {"taken_reduction_pct": 0.3}}],
		"branch": [
			{"name": "冲阵", "desc": "段数强化 +37.5%/段", "effects": {"damage_pct": 0.75}},
			{"name": "护主", "desc": "对前军 +62.5%，且每次施放获 20% 最大生命护盾", "effects": {"damage_front_pct": 0.625, "post_cast_shield_pct": 0.2}}],
		"bond": {"name": "五虎之威", "desc": "五虎上将效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "子龙不老", "desc": "战斗内每 10 秒兵略 +7.5%，上限 +37.5%/75%", "effects": {"growth_strategy_pct": [0.075, 0.075]}},
		"soul": {"name": "浑身是胆", "desc": "生命低于 100% 时伤害 +100% 并免疫控制 6秒（每场 1 次）", "effects": {"low_hp_frenzy_threshold": 0.8, "low_hp_frenzy_damage_pct": 1}}
	},
	"huangzhong": {
		"root_class": "output", "root": ["老当益壮", "定军兵略", "宝雕疾弦"],
		"role": [
			{"name": "百发百中", "desc": "暴击率 +20%/级", "effects": {"crit_chance_pct": [0.2, 0.2]}},
			{"name": "流星火雨", "desc": "暴击伤害 +75%/级", "effects": {"crit_damage_pct": [0.75, 0.75]}},
			{"name": "老将之稳", "desc": "稳定层：技能期望伤害下限 225%（引擎折算稳定增伤）", "effects": {"damage_pct": [0.15, 0.15]}}],
		"skill": [
			{"name": "烈弓", "desc": "优先射击生命最低格（对 <112.5% 目标 +37.5%）", "max": 1, "effects": {"damage_low_pct": 0.375}},
			{"name": "穿杨", "desc": "对满血目标 +75%", "max": 1, "effects": {"damage_full_hp_pct": 0.75}},
			{"name": "连珠", "desc": "每次施放后下次 +20%（战斗内可叠 5）", "max": 1, "effects": {"per_cast_damage_pct": 0.2}}],
		"branch": [
			{"name": "老骥伏枥", "desc": "稳定 +50%", "effects": {"damage_pct": 0.5}},
			{"name": "宝刀未老", "desc": "暴击流 +50% 暴伤", "effects": {"crit_damage_pct": 0.5}}],
		"bond": {"name": "五虎之威", "desc": "五虎上将效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "定军山魂", "desc": "战斗内每 10 秒暴击率 +5%（2 级 +7.5%），上限 +25%/50%", "effects": {"growth_crit_pct": [0.05, 0.075]}},
		"soul": {"name": "定军斩将", "desc": "暴击时额外造成目标 30% 最大生命伤害（对主公无效）", "effects": {"crit_max_hp_damage_pct": 0.3}}
	},
	"machao": {
		"root_class": "output", "root": ["西凉铁骑体", "锦马兵略", "飞骑疾进"],
		"role": [
			{"name": "一骑当千", "desc": "相邻无友军时 +25%/级", "effects": {"damage_lone_pct": [0.25, 0.25]}},
			{"name": "铁蹄", "desc": "对前军 +20%/级", "effects": {"damage_front_pct": [0.2, 0.2]}},
			{"name": "西凉之血", "desc": "生命低于 125% 时伤害 +20%/级", "effects": {"damage_self_low_pct": [0.2, 0.2]}}],
		"skill": [
			{"name": "潼关遁走", "desc": "释放后 6秒减伤 50%", "max": 1, "effects": {"post_cast_reduction_pct": 0.5}},
			{"name": "神威", "desc": "锁定最低比例列时 +62.5%", "max": 1, "effects": {"damage_low_pct": 0.625}},
			{"name": "突骑", "desc": "释放后 +30 行动条", "max": 1, "effects": {"action_on_cast_add": 30}}],
		"branch": [
			{"name": "铁骑贯阵·极", "desc": "三排拉平最高档（中后军伤害提升）", "effects": {"damage_mid_pct": 0.75, "damage_back_pct": 0.75}},
			{"name": "独往独来", "desc": "锁定目标伤害 +125%", "effects": {"damage_pct": 0.875}}],
		"bond": {"name": "西凉铁骑", "desc": "马超+马岱组合效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "神威天将", "desc": "战斗内每 10 秒兵略 +7.5%，上限 +37.5%/75%", "effects": {"growth_strategy_pct": [0.075, 0.075]}},
		"soul": {"name": "神威天将军", "desc": "命中整列 3 人时下次冷却减半（每场 2 次）", "effects": {"full_column_cooldown_halve_times": 2}}
	},
	"liushan": {
		"root_class": "aura", "root": ["天命所归", "蜀宫养士", "无忧疾诏"],
		"role": [
			{"name": "舐犊之情", "desc": "光环目标扩为前方两格（引擎折算 +25%/级）", "effects": {"skill_effect_pct": [0.25, 0.25]}},
			{"name": "大智若愚", "desc": "自身受伤 -20%/级", "effects": {"taken_reduction_pct": [0.2, 0.2]}},
			{"name": "乐不思蜀", "desc": "被强化者同时 +12.5% 兵略（光环表达）", "effects": {"grant_ally_strategy_pct": [0.125, 0.125]}}],
		"skill": [
			{"name": "相父辅佐", "desc": "诸葛亮在场时效果 +125%（引擎折算 +62.5%）", "max": 1, "effects": {"bond_ally_damage_pct": 0.625}},
			{"name": "富贵无忧", "desc": "被强化者被控时长 -37.5%（光环表达）", "max": 1, "effects": {"grant_ally_control_reduction_pct": 0.375}},
			{"name": "安乐公", "desc": "被强化者阵亡时刘禅获 30 行动条", "max": 1, "effects": {"on_ally_death_action": 60}}],
		"branch": [
			{"name": "继汉兴室", "desc": "强化效果 +62.5%", "effects": {"skill_effect_pct": 0.625}},
			{"name": "富贵闲人", "desc": "自身减伤 +25%", "effects": {"taken_reduction_pct": 0.25}}],
		"bond": {"name": "汉室北伐", "desc": "蜀阵营羁绊效果 +25%/级", "effects": {"skill_effect_pct": [0.25, 0.25]}},
		"evergreen": {"name": "天命渐归", "desc": "整局每回合光环强化量 +5%（2 级 +7.5%），上限 +50%/87.5%", "effects": {"round_aura_pct": [0.05, 0.075]}},
		"soul": {"name": "汉室正统", "desc": "被强化友军每次击杀，刘禅 +2 兵略（整场上限 +20）", "effects": {"aura_kill_strategy_add": 4}}
	},
	"zhugeliang": {
		"root_class": "output", "root": ["卧龙之姿", "八阵兵略", "羽扇纶巾"],
		"role": [
			{"name": "神机妙算", "desc": "命中多人时 +20%/级（引擎折算范围增伤）", "effects": {"damage_per_extra_hit_pct": [0.2, 0.2]}},
			{"name": "观星", "desc": "火计标记时长 +4s/级（折算灼烧增伤）、冷却极速 +12/级", "effects": {"burn_damage_pct": [0.25, 0.25], "cooldown_haste_add": [12, 12]}},
			{"name": "隆中对", "desc": "对灼烧目标 +20%/级", "effects": {"damage_burning_pct": [0.2, 0.2]}}],
		"skill": [
			{"name": "火烧博望", "desc": "被标记目标下次受伤 +50%（引擎折算）", "max": 1, "effects": {"damage_burning_pct": 0.5}},
			{"name": "锦囊", "desc": "命中带减益者 +37.5%", "max": 1, "effects": {"damage_debuff_pct": 0.375}},
			{"name": "八阵图", "desc": "命中格 +1（伤害 -37.5%；引擎以多目标增伤折算）", "max": 1, "effects": {"damage_per_extra_hit_pct": 0.375}}],
		"branch": [
			{"name": "八阵图·范围", "desc": "范围向 +50%", "effects": {"damage_per_extra_hit_pct": 0.5}},
			{"name": "神算", "desc": "单体 +100%", "effects": {"damage_pct": 1}}],
		"bond": {"name": "汉室北伐", "desc": "蜀阵营羁绊效果 +25%/级", "effects": {"skill_effect_pct": [0.25, 0.25]}},
		"evergreen": {"name": "鞠躬尽瘁", "desc": "战斗内每 10 秒兵略 +7.5%，上限 +37.5%/75%", "effects": {"growth_strategy_pct": [0.075, 0.075]}},
		"soul": {"name": "星落五丈原", "desc": "阵亡时对全场敌人 750% 伤害并留 10秒灼烧（每场 1 次）", "effects": {"death_explode_pct": 7.5, "death_burn_time": 10}}
	},
	"jiangwei": {
		"root_class": "output", "root": ["麒麟儿体", "天水兵略", "承志疾行"],
		"role": [
			{"name": "九伐中原", "desc": "战斗内每次施法 +10%（2 级 +15%，上限 +75%/120%）", "effects": {"per_cast_damage_pct": [0.1, 0.15]}},
			{"name": "文武双全", "desc": "同时生命 +7.5%/级", "effects": {"max_hp_pct": [0.075, 0.075]}},
			{"name": "幼麟之锐", "desc": "对满血目标 +25%/级", "effects": {"damage_full_hp_pct": [0.25, 0.25]}}],
		"skill": [
			{"name": "继承遗志", "desc": "诸葛亮阵亡后 +75%（引擎以友军阵亡激怒表达）", "max": 1, "effects": {"on_ally_death_damage_pct": 0.75}},
			{"name": "剑阁守卫", "desc": "受前军伤害 -37.5%", "max": 1, "effects": {"taken_from_front_pct": 0.375}},
			{"name": "洮西大捷", "desc": "击杀后下次必暴击（每场 3 次）", "max": 1, "effects": {"kill_next_crit_times": 3}}],
		"branch": [
			{"name": "攻", "desc": "伤害 +62.5%", "effects": {"damage_pct": 0.625}},
			{"name": "守", "desc": "全队后排减伤 +20%", "effects": {"grant_rear_taken_reduction_pct": 0.2}}],
		"bond": {"name": "汉室北伐", "desc": "蜀阵营羁绊效果 +25%/级", "effects": {"skill_effect_pct": [0.25, 0.25]}},
		"evergreen": {"name": "麒麟成长", "desc": "战斗内每次施法兵略 +2.5%（2 级 +3.75%），无上限（适配无尽）", "effects": {"per_cast_strategy_pct": [0.025, 0.037]}},
		"soul": {"name": "一计害三贤", "desc": "击杀后下次北伐冷却 -125%（每场 3 次）", "effects": {"kill_cooldown_halve_times": 3}}
	},
	"menghuo": {
		"root_class": "tank", "root": ["蛮王体魄", "南中兵略", "象兵疾踏"],
		"role": [
			{"name": "蛮王震慑", "desc": "眩晕 +0.8s/级（引擎折算控制强度 +70%/级）", "effects": {"control_power_pct": [0.7, 0.7]}},
			{"name": "藤甲南兵", "desc": "物理受伤 -20%/级、灼烧受伤 +37.5%/级", "effects": {"taken_physical_reduction_pct": [0.2, 0.2], "taken_burn_increase_pct": [0.375, 0.375]}},
			{"name": "蛮力", "desc": "整排每多命中一人 +20%", "effects": {"damage_per_extra_hit_pct": [0.2, 0.2]}}],
		"skill": [
			{"name": "兽群冲锋", "desc": "对前军伤害 +37.5%", "max": 1, "effects": {"damage_front_pct": 0.375}},
			{"name": "洞主同盟", "desc": "祝融/带来洞主在场 +37.5%", "max": 1, "effects": {"bond_ally_damage_pct": 0.375}},
			{"name": "七擒之悟", "desc": "被同一目标击中 3 次后对其 +50%（引擎折算 +25%）", "max": 1, "effects": {"damage_pct": 0.25}}],
		"branch": [
			{"name": "七擒不屈", "desc": "首死以 75% 生命复起（每场 1 次）", "effects": {"death_prevent_times": 1, "death_prevent_heal_pct": 0.75}},
			{"name": "蛮王威压", "desc": "眩晕 +2s、伤害 -25%", "effects": {"control_power_pct": 1.75, "damage_pct": -0.25}}],
		"bond": {"name": "南中归心", "desc": "蜀阵营羁绊效果 +25%/级", "effects": {"skill_effect_pct": [0.25, 0.25]}},
		"evergreen": {"name": "蛮王之力", "desc": "整局每回合生命 +5%（2 级 +7.5%），上限 +50%/87.5%", "effects": {"round_hp_pct": [0.05, 0.075]}},
		"soul": {"name": "南中盟主", "desc": "每次施放获 1 层〔蛮〕：伤害 +12.5%、减伤 +7.5%（上限 5 层→2 级 8 层）", "effects": {"per_cast_self_stack_damage_pct": 0.125, "per_cast_self_stack_reduction_pct": 0.075}}
	},
	"zhurong": {
		"root_class": "output", "root": ["火神之体", "南蛮兵略", "飞刃疾旋"],
		"role": [
			{"name": "烈火", "desc": "灼烧时长 +2s/级", "effects": {"burn_duration_add": [2, 2]}},
			{"name": "火神祝福", "desc": "自身免疫灼烧", "effects": {"burn_immune": [2, 2]}},
			{"name": "刃舞", "desc": "对灼烧目标 +25%/级", "effects": {"damage_burning_pct": [0.25, 0.25]}}],
		"skill": [
			{"name": "夫妻同心", "desc": "孟获在场灼烧伤害 +62.5%", "max": 1, "effects": {"bond_ally_burn_pct": 0.625}},
			{"name": "火神之怒", "desc": "直伤段 +50%", "max": 1, "effects": {"damage_pct": 0.5}},
			{"name": "燎原", "desc": "灼烧目标阵亡时火焰扩散至相邻格", "max": 1, "effects": {"burn_spread_on_death": 2}}],
		"branch": [
			{"name": "焚天", "desc": "DoT +100%", "effects": {"burn_damage_pct": 1}},
			{"name": "飞刃", "desc": "直伤 +62.5%", "effects": {"damage_pct": 0.625}}],
		"bond": {"name": "南中归心", "desc": "蜀阵营羁绊效果 +25%/级", "effects": {"skill_effect_pct": [0.25, 0.25]}},
		"evergreen": {"name": "圣火不熄", "desc": "战斗内每 10 秒灼烧伤害 +10%（2 级 +15%），上限 +50%/100%", "effects": {"growth_burn_pct": [0.1, 0.15]}},
		"soul": {"name": "火神降临", "desc": "场上每有一名灼烧敌人，祝融伤害 +15%（动态）", "effects": {"burning_enemy_damage_pct": 0.15}}
	},
	"dailaidongzhu": {
		"root_class": "output", "root": ["蛮骨之躯", "洞主兵略", "狼袭疾步"],
		"role": [
			{"name": "狼性", "desc": "对行动条 ≥80 目标 +25%/级", "effects": {"damage_high_action_pct": [0.25, 0.25]}},
			{"name": "蛮域猎手", "desc": "对后排 +20%/级", "effects": {"damage_back_pct": [0.2, 0.2]}},
			{"name": "蓄势", "desc": "未攻击时每秒 +5% 下次伤害（战斗内上限 +50%）", "effects": {"idle_charge_pct": [0.05, 0.05]}}],
		"skill": [
			{"name": "突袭", "desc": "开局行动条 +30", "max": 1, "effects": {"action_start_add": 60}},
			{"name": "猎首", "desc": "击杀后 +3 兵略（上限 +15）", "max": 1, "effects": {"strategy_on_kill_add": 6}},
			{"name": "断喉", "desc": "对残血（<75%）+62.5%", "max": 1, "effects": {"damage_low_pct": 0.625}}],
		"branch": [
			{"name": "狼吞", "desc": "斩杀 +100%", "effects": {"damage_low_pct": 1}},
			{"name": "噬骨", "desc": "命中压退 50% 行动条", "effects": {"action_push_on_hit_pct": 0.5}}],
		"bond": {"name": "南中归心", "desc": "蜀阵营羁绊效果 +25%/级", "effects": {"skill_effect_pct": [0.25, 0.25]}},
		"evergreen": {"name": "狼群壮大", "desc": "战斗内每 10 秒兵略 +7.5%，上限 +37.5%/75%", "effects": {"growth_strategy_pct": [0.075, 0.075]}},
		"soul": {"name": "蛮域猎首", "desc": "击杀后使目标同排敌人恐惧 3秒（每场 2 次）", "effects": {"kill_fear_time": 3, "kill_fear_times": 2}}
	},
	"weiyan": {
		"root_class": "output", "root": ["反骨之躯", "汉中兵略", "疾进军略"],
		"role": [
			{"name": "子午谷", "desc": "伤害 +30%/级、受伤 +12.5%/级", "effects": {"damage_pct": [0.3, 0.3], "taken_mod_pct": [0.125, 0.125]}},
			{"name": "傲上而不忍下", "desc": "对满血目标 +25%/级", "effects": {"damage_full_hp_pct": [0.25, 0.25]}},
			{"name": "先登", "desc": "开局行动条 +30", "effects": {"action_start_add": [60, 60]}}],
		"skill": [
			{"name": "谁敢杀我", "desc": "首次致命保留 1 点（每场 1 次）", "max": 1, "effects": {"death_prevent_times": 1}},
			{"name": "郪县断后", "desc": "命中正前第二格 150%（引擎折算范围增伤）", "max": 1, "effects": {"damage_per_extra_hit_pct": 0.5}},
			{"name": "狂骨", "desc": "击杀后伤害 +37.5%（8秒）", "max": 1, "effects": {"kill_damage_stack_pct": 0.375}}],
		"branch": [
			{"name": "奇谋子午", "desc": "风险收益翻倍：伤害 +60%、受伤 +25%", "effects": {"damage_pct": 0.6, "taken_mod_pct": 0.25}},
			{"name": "汉中太守", "desc": "移除风险并获 20% 减伤", "effects": {"taken_reduction_pct": 0.2}}],
		"bond": {"name": "汉中同守", "desc": "魏延+黄忠组合效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "养寇自重", "desc": "整局每回合生命 +5%，上限 +50%/87.5%", "effects": {"round_hp_pct": [0.05, 0.05]}},
		"soul": {"name": "子午奇谋", "desc": "每回合首次施放狂骨横斩追加穿透（引擎折算首次施放 +150%）", "effects": {"first_cast_bonus_pct": 1.5}}
	},
	"madai": {
		"root_class": "output", "root": ["西凉之躯", "斩将兵略", "追风疾骑"],
		"role": [
			{"name": "空城威慑", "desc": "对主公空格伤害 +37.5%/级", "effects": {"damage_empty_pct": [0.375, 0.375]}},
			{"name": "断后", "desc": "生命 +10%/级", "effects": {"max_hp_pct": [0.1, 0.1]}},
			{"name": "袭粮", "desc": "对主公总伤害 +25%/级", "effects": {"damage_ruler_pct": [0.25, 0.25]}}],
		"skill": [
			{"name": "斩将", "desc": "击杀敌将返还 30 行动条", "max": 1, "effects": {"action_on_kill_add": 60}},
			{"name": "先锋", "desc": "对前军 +50%", "max": 1, "effects": {"damage_front_pct": 0.5}},
			{"name": "掎角", "desc": "与魏延同排时双方 +25%（引擎以固定搭档加成表达）", "max": 1, "effects": {"bond_ally_damage_pct": 0.25}}],
		"branch": [
			{"name": "诱敌深入", "desc": "空格 +75%", "effects": {"damage_empty_pct": 0.75}},
			{"name": "冲锋陷阵", "desc": "直击伤害 +62.5%", "effects": {"damage_pct": 0.625}}],
		"bond": {"name": "西凉之谊", "desc": "马超+马岱组合效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "凉州铁骑", "desc": "战斗内每 10 秒兵略 +7.5%，上限 +37.5%/75%", "effects": {"growth_strategy_pct": [0.075, 0.075]}},
		"soul": {"name": "遗计斩龙", "desc": "每次命中空格，我方全体 +20 行动条", "effects": {"empty_hit_team_action": 20}}
	},
	"pangtong": {
		"root_class": "output", "root": ["凤雏之躯", "连环兵略", "的卢疾谋"],
		"role": [
			{"name": "连环", "desc": "链接时长 +3s/级（引擎折算控制强度 +25%/级）", "effects": {"control_power_pct": [0.25, 0.25]}},
			{"name": "铁索", "desc": "传导比例 +20%/级（引擎折算传导增伤）", "effects": {"damage_per_extra_hit_pct": [0.2, 0.2]}},
			{"name": "凤雏之智", "desc": "直伤段 +25%/级", "effects": {"damage_pct": [0.25, 0.25]}}],
		"skill": [
			{"name": "凤雏连横", "desc": "链接目标 +1（2 级 +2；引擎折算）", "max": 2, "effects": {"damage_per_extra_hit_pct": [0.25, 0.25]}},
			{"name": "落凤坡", "desc": "阵亡引爆所有链接（每条 375%）", "max": 1, "effects": {"death_explode_pct": 3.75}},
			{"name": "连环火", "desc": "链接者受灼烧 +50%", "max": 1, "effects": {"burn_damage_pct": 0.5}}],
		"branch": [
			{"name": "火烧连营式", "desc": "传导 +125%", "effects": {"damage_per_extra_hit_pct": 1.25}},
			{"name": "凤鸣", "desc": "直伤 +75%", "effects": {"damage_pct": 0.75}}],
		"bond": {"name": "凤栖蜀中", "desc": "蜀阵营羁绊效果 +25%/级", "effects": {"skill_effect_pct": [0.25, 0.25]}},
		"evergreen": {"name": "连环渐紧", "desc": "战斗内每 10 秒传导比例 +7.5%（2 级 +10%），上限 +37.5%/75%", "effects": {"growth_damage_pct": [0.075, 0.1]}},
		"soul": {"name": "铁索连环", "desc": "链接目标的灼烧伤害同步传导（引擎折算灼烧 +62.5%）", "effects": {"burn_damage_pct": 0.625}}
	},

	# ============ 魏 · 15 ============
	"caocao": {
		"root_class": "output", "root": ["霸府根基", "乱世枭雄", "号令如山"],
		"role": [
			{"name": "唯才是举", "desc": "每个不同魏将提供 +2 兵略/级", "effects": {"per_faction_ally_strategy": [4, 4]}},
			{"name": "挟天子", "desc": "最低生命魏将减伤 15%/级（引擎全军折半表达）", "effects": {"grant_ally_taken_reduction_pct": [0.075, 0.075]}},
			{"name": "枭雄之略", "desc": "眩晕时长 +0.6s/级（折算控制强度 +50%/级）", "effects": {"control_power_pct": [0.5, 0.5]}}],
		"skill": [
			{"name": "震慑扩军", "desc": "对带减益目标伤害 +37.5%（引擎折算候选扩展）", "max": 1, "effects": {"damage_debuff_pct": 0.375}},
			{"name": "军令追击", "desc": "眩晕结束压退 50% 行动条", "max": 1, "effects": {"stun_end_push_pct": 0.5}},
			{"name": "挟奇用兵", "desc": "对被控目标 +50%", "max": 1, "effects": {"damage_stunned_pct": 0.5}}],
		"branch": [
			{"name": "霸道", "desc": "伤害 +62.5%", "effects": {"damage_pct": 0.625}},
			{"name": "王道", "desc": "伤害 -25%、全队增益 +37.5%", "effects": {"damage_pct": -0.25, "grant_team_damage_pct": 0.375}}],
		"bond": {"name": "魏武亲卫", "desc": "曹操+典韦 与 曹操+许褚组合效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "横槊赋诗", "desc": "战斗内每 10 秒兵略 +7.5%，上限 +37.5%/75%", "effects": {"growth_strategy_pct": [0.075, 0.075]}},
		"soul": {"name": "魏武挥鞭", "desc": "每回合首次施法后全体魏将获 8秒兵略与行动增速 +25%", "effects": {"first_cast_faction_rally_pct": 0.25}}
	},
	"dianwei": {
		"root_class": "output", "root": ["古之恶来体", "宿卫兵略", "恶来疾步"],
		"role": [
			{"name": "护主", "desc": "曹操受击时典韦伤害 +20%（可叠 3 层；引擎折算常驻）", "effects": {"bond_ally_damage_pct": [0.2, 0.2]}},
			{"name": "飞戟", "desc": "对后排 +20%/级", "effects": {"damage_back_pct": [0.2, 0.2]}},
			{"name": "恶来凶悍", "desc": "生命每低 50% 伤害 +10%", "effects": {"damage_missing_20_pct": [0.1, 0.1]}}],
		"skill": [
			{"name": "宿卫双戟", "desc": "伤害 +50%、冷却 +1s", "max": 1, "effects": {"damage_pct": 0.5, "cooldown_flat_add": 1}},
			{"name": "飞戟夺营", "desc": "目标 +1（引擎折算范围增伤 +25%/级）", "max": 2, "effects": {"damage_per_extra_hit_pct": [0.25, 0.25]}},
			{"name": "双铁戟", "desc": "击杀后下次 +37.5%", "max": 1, "effects": {"kill_damage_stack_pct": 0.375}}],
		"branch": [
			{"name": "恶来咆哮", "desc": "爆发 +75%", "effects": {"damage_pct": 0.75}},
			{"name": "忠卫", "desc": "曹操在场减伤 +37.5%，并获通用减伤值 +50", "effects": {"taken_reduction_pct": 0.375, "armor_add": 50}}],
		"bond": {"name": "霸之亲卫", "desc": "曹操+典韦组合效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "古之恶来", "desc": "战斗内每 10 秒兵略 +7.5%，上限 +37.5%/75%", "effects": {"growth_strategy_pct": [0.075, 0.075]}},
		"soul": {"name": "濮阳死战", "desc": "首次阵亡时对全体敌人 500% 伤害并保留 1 点生命（每场 1 次）", "effects": {"death_prevent_times": 1, "death_explode_pct": 5}}
	},
	"xuchu": {
		"root_class": "tank", "root": ["虎痴之躯", "虎卫兵略", "裸衣疾斗"],
		"role": [
			{"name": "裸衣阵", "desc": "伤害 +25%/级、受伤 +12.5%/级", "effects": {"damage_pct": [0.25, 0.25], "taken_mod_pct": [0.125, 0.125]}},
			{"name": "虎侯", "desc": "对前军 +20%/级", "effects": {"damage_front_pct": [0.2, 0.2]}},
			{"name": "痴壮", "desc": "生命 +10%/级（坦克向）", "effects": {"max_hp_pct": [0.1, 0.1]}}],
		"skill": [
			{"name": "裂帛", "desc": "对护盾单位 +125%", "max": 1, "effects": {"damage_shielded_pct": 1.25}},
			{"name": "恶斗", "desc": "击杀前军后下次 +50%", "max": 1, "effects": {"kill_damage_stack_pct": 0.5}},
			{"name": "倒拖牛尾", "desc": "释放后 6秒减伤 50%", "max": 1, "effects": {"post_cast_reduction_pct": 0.5}}],
		"branch": [
			{"name": "虎痴", "desc": "风险收益翻倍：伤害 +50%、受伤 +25%", "effects": {"damage_pct": 0.5, "taken_mod_pct": 0.25}},
			{"name": "中坚", "desc": "移除风险、减伤 25%，并获通用减伤值 +40", "effects": {"taken_reduction_pct": 0.25, "armor_add": 40}}],
		"bond": {"name": "恶来同袍", "desc": "典韦+许褚组合效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "虎痴之勇", "desc": "整局每回合生命 +5%，上限 +50%/87.5%", "effects": {"round_hp_pct": [0.05, 0.05]}},
		"soul": {"name": "虎痴当关", "desc": "每回合首次致命保留 1 点并获 6秒 100% 减伤（每场 2 次）", "effects": {"death_prevent_times": 2, "death_prevent_reduction_pct": 1}}
	},
	"zhangliao": {
		"root_class": "output", "root": ["前将军体", "合肥兵略", "辽来疾驰"],
		"role": [
			{"name": "威震逍遥津", "desc": "命中压退目标 20%/级行动条", "effects": {"action_push_pct": [0.2, 0.2]}},
			{"name": "止啼", "desc": "释放后敌方全体伤害 -10%（6秒，叠 2 层）", "effects": {"post_cast_enemy_damage_reduction": [0.08, 0.08]}},
			{"name": "破锋", "desc": "对前军 +20%/级", "effects": {"damage_front_pct": [0.2, 0.2]}}],
		"skill": [
			{"name": "八百破十万", "desc": "开局行动条 +50", "max": 1, "effects": {"action_start_add": 100}},
			{"name": "回刃", "desc": "第二段 +75%", "max": 1, "effects": {"damage_per_extra_hit_pct": 0.75}},
			{"name": "冲阵", "desc": "击杀后 +40 行动条", "max": 1, "effects": {"action_on_kill_add": 40}}],
		"branch": [
			{"name": "突袭", "desc": "两段各 +62.5%", "effects": {"damage_per_extra_hit_pct": 0.625}},
			{"name": "守城", "desc": "释放后获 25% maxHP 护盾", "effects": {"post_cast_shield_pct": 0.25}}],
		"bond": {"name": "五子之首", "desc": "五子良将组合效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "辽来不止", "desc": "战斗内每 10 秒兵略 +7.5%，上限 +37.5%/75%", "effects": {"growth_strategy_pct": [0.075, 0.075]}},
		"soul": {"name": "辽来来", "desc": "命中整列 3 人时立即获 50 行动条（每场 5 次）", "effects": {"full_column_action": 100, "full_column_times": 5}}
	},
	"yuejin": {
		"root_class": "output", "root": ["先登之躯", "骁锐兵略", "疾风先登"],
		"role": [
			{"name": "每战先登", "desc": "每 10 秒伤害 +15%（上限 +12/45%）", "effects": {"growth_damage_pct": [0.15, 0.15]}},
			{"name": "骁果", "desc": "命中多目标时 +20%/级（引擎折算）", "effects": {"damage_per_extra_hit_pct": [0.2, 0.2]}},
			{"name": "锐不可当", "desc": "对满血目标 +25%/级", "effects": {"damage_full_hp_pct": [0.25, 0.25]}}],
		"skill": [
			{"name": "乱射", "desc": "目标 +1、单发 -62.5%（2 级 -37.5%；引擎折算）", "max": 2, "effects": {"damage_per_extra_hit_pct": [0.25, 0.5]}},
			{"name": "锋锐", "desc": "对 <100% 目标 +62.5%", "max": 1, "effects": {"damage_low_pct": 0.625}},
			{"name": "每战先登·绝技", "desc": "开局行动条 +40", "max": 1, "effects": {"action_start_add": 80}}],
		"branch": [
			{"name": "五子良将", "desc": "多目标向：范围增伤 +62.5%", "effects": {"damage_per_extra_hit_pct": 0.625}},
			{"name": "骁锐突袭", "desc": "单发 +62.5%", "effects": {"damage_pct": 0.625}}],
		"bond": {"name": "先登同袍", "desc": "张辽+乐进组合效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "骁锐渐锐", "desc": "战斗内每 10 秒兵略 +7.5%，上限 +37.5%/75%", "effects": {"growth_strategy_pct": [0.075, 0.075]}},
		"soul": {"name": "先登陷阵", "desc": "每回合首次施放必中最虚弱 3 名敌人（引擎折算 +75%）", "effects": {"first_cast_bonus_pct": 0.75}}
	},
	"zhanghe": {
		"root_class": "output", "root": ["巧变之躯", "街亭兵略", "巧变疾机"],
		"role": [
			{"name": "巧变", "desc": "冷却极速 +16/级", "effects": {"cooldown_haste_add": [16, 16]}},
			{"name": "识阵", "desc": "眩晕 +0.6s/级（折算控制强度 +50%/级）", "effects": {"control_power_pct": [0.5, 0.5]}},
			{"name": "临机应变", "desc": "伤害 +20%/级", "effects": {"damage_pct": [0.2, 0.2]}}],
		"skill": [
			{"name": "壁断", "desc": "对护盾单位 +100%", "max": 1, "effects": {"damage_shielded_pct": 1}},
			{"name": "临阵", "desc": "受创后下次伤害 +37.5%", "max": 1, "effects": {"on_taken_damage_buff_pct": 0.375}},
			{"name": "破军", "desc": "击杀后 +40 行动条", "max": 1, "effects": {"action_on_kill_add": 40}}],
		"branch": [
			{"name": "巧变千军", "desc": "眩晕 +1.2s（折算控制强度 +100%）", "effects": {"control_power_pct": 1}},
			{"name": "猛将", "desc": "伤害 +62.5%", "effects": {"damage_pct": 0.625}}],
		"bond": {"name": "五子之变", "desc": "五子良将组合效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "巧变百出", "desc": "战斗内每 10 秒兵略 +7.5%，上限 +37.5%/75%", "effects": {"growth_strategy_pct": [0.075, 0.075]}},
		"soul": {"name": "街亭之鉴", "desc": "被张郃眩晕的敌人眩晕期间受伤 +50%", "effects": {"damage_stunned_pct": 0.5}}
	},
	"xuhuang": {
		"root_class": "tank", "root": ["周亚夫体", "治军兵略", "长驱疾进"],
		"role": [
			{"name": "治军严整", "desc": "整排每多命中一人 +20%/级", "effects": {"damage_per_extra_hit_pct": [0.2, 0.2]}},
			{"name": "长驱直入", "desc": "眩晕 +0.8s/级（折算控制强度 +70%/级）", "effects": {"control_power_pct": [0.7, 0.7]}},
			{"name": "军令如山", "desc": "释放后 6秒减伤 30%", "effects": {"post_cast_reduction_pct": [0.3, 0.3]}}],
		"skill": [
			{"name": "破关", "desc": "对前军 +50%", "max": 1, "effects": {"damage_front_pct": 0.5}},
			{"name": "周亚夫之风", "desc": "释放后获 20% maxHP 护盾", "max": 1, "effects": {"post_cast_shield_pct": 0.2}},
			{"name": "治军", "desc": "命中每人压退 20% 行动条", "max": 1, "effects": {"action_push_on_hit_pct": 0.2}}],
		"branch": [
			{"name": "破阵", "desc": "伤害 +62.5%", "effects": {"damage_pct": 0.625}},
			{"name": "军律", "desc": "眩晕 +1.6s（折算控制强度 +132.5%）", "effects": {"control_power_pct": 1.325}}],
		"bond": {"name": "巧变联动", "desc": "张郃+徐晃组合效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "治军日严", "desc": "整局每回合生命 +5%，上限 +50%/87.5%", "effects": {"round_hp_pct": [0.05, 0.05]}},
		"soul": {"name": "长驱直入·魂", "desc": "被眩晕敌人眩晕结束后行动条速度减半 6秒", "effects": {"stun_end_slow_pct": 1.25}}
	},
	"yujin": {
		"root_class": "support", "root": ["假节钺体", "毅重兵略", "持军疾令"],
		"role": [
			{"name": "毅重", "desc": "护盾量 +25%/级", "effects": {"shield_pct": [0.25, 0.25]}},
			{"name": "持军", "desc": "被护者减伤 12.5%/级", "effects": {"shielded_ally_reduction_pct": [0.125, 0.125]}},
			{"name": "军纪", "desc": "护盾目标 +1/级（引擎折算护盾量）", "effects": {"shield_pct": [0.375, 0.375]}}],
		"skill": [
			{"name": "晚节", "desc": "护盾被打破时反伤 125% 护盾量", "max": 1, "effects": {"shield_break_reflect_pct": 1.25}},
			{"name": "三军整", "desc": "护盾同时清除 1 个减益", "max": 1, "effects": {"heal_cleanse": 2}},
			{"name": "坚壁", "desc": "护盾存续时目标行动增速 +20%", "max": 1, "effects": {"shielded_ally_action_pct": 0.2}}],
		"branch": [
			{"name": "铁壁", "desc": "护盾量 +75%", "effects": {"shield_pct": 0.75}},
			{"name": "凛然", "desc": "被护者受控 -50%", "effects": {"shielded_ally_control_reduction_pct": 0.5}}],
		"bond": {"name": "五子之毅", "desc": "五子良将组合效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "军魂愈坚", "desc": "战斗内每 10 秒护盾量 +10%（2 级 +15%），上限 +50%/100%", "effects": {"growth_shield_pct": [0.1, 0.15]}},
		"soul": {"name": "假节钺", "desc": "护盾存续期间目标免疫第一次控制（每盾一次）", "effects": {"shield_control_block": 2}}
	},
	"xiahouyuan": {
		"root_class": "output", "root": ["疾驰之躯", "虎步兵略", "三日五百"],
		"role": [
			{"name": "神速", "desc": "冷却极速 +16/级", "effects": {"cooldown_haste_add": [16, 16]}},
			{"name": "虎步关右", "desc": "行动增速 +12.5%/级", "effects": {"action_gain_pct": [0.125, 0.125]}},
			{"name": "疾风迅雷", "desc": "开局行动条 +20/级", "effects": {"action_start_add": [40, 40]}}],
		"skill": [
			{"name": "妙才", "desc": "对 <125% 目标 +62.5%", "max": 1, "effects": {"damage_low_pct": 0.625}},
			{"name": "奔袭", "desc": "开局行动条 +40", "max": 1, "effects": {"action_start_add": 80}},
			{"name": "连击", "desc": "击杀后下次 +37.5%", "max": 1, "effects": {"kill_damage_stack_pct": 0.375}}],
		"branch": [
			{"name": "神速·极", "desc": "冷却再 -0.6秒", "effects": {"cooldown_flat_add": -0.6}},
			{"name": "虎步", "desc": "伤害 +62.5%", "effects": {"damage_pct": 0.625}}],
		"bond": {"name": "夏侯连璧", "desc": "夏侯渊+曹仁 与 夏侯渊+夏侯惇组合效果 +30%/级", "effects": {"skill_effect_pct": [0.3, 0.3]}},
		"evergreen": {"name": "疾行千里", "desc": "战斗内每 10 秒行动增速 +5%（2 级 +7.5%），上限 +25%/50%", "effects": {"growth_action_pct": [0.05, 0.075]}},
		"soul": {"name": "虎步关右", "desc": "眩晕命中同时压退 50% 行动条", "effects": {"action_push_on_hit_pct": 0.5}}
	},
	"caoren": {
		"root_class": "tank", "root": ["天人之际体", "守城兵略", "坚壁疾守"],
		"role": [
			{"name": "铁壁", "desc": "远程减伤值 +24/级（值/(值+100) 结算），并常驻减伤窗口", "effects": {"armor_ranged_add": [24, 24], "taken_reduction_pct": [0.1, 0.1]}},
			{"name": "守城大师", "desc": "对后军 +20%/级", "effects": {"damage_back_pct": [0.2, 0.2]}},
			{"name": "坚壁", "desc": "自身生命 +10%/级", "effects": {"max_hp_pct": [0.1, 0.1]}}],
		"skill": [
			{"name": "樊城之围", "desc": "减伤范围全队（引擎折算）", "max": 1, "effects": {"grant_ally_taken_reduction_pct": 0.15}},
			{"name": "不动如山", "desc": "释放后获 20% maxHP 护盾", "max": 1, "effects": {"post_cast_shield_pct": 0.2}},
			{"name": "婴城固守", "desc": "被保护者反伤 +25%", "max": 1, "effects": {"shield_reflect_pct": 0.25}}],
		"branch": [
			{"name": "守城", "desc": "守护向 +125%", "effects": {"skill_effect_pct": 1.25}},
			{"name": "突围", "desc": "伤害 +62.5%", "effects": {"damage_pct": 0.625}}],
		"bond": {"name": "樊城之守", "desc": "夏侯渊+曹仁组合效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "城高池深", "desc": "整局每回合生命 +5%，上限 +50%/87.5%", "effects": {"round_hp_pct": [0.05, 0.05]}},
		"soul": {"name": "天人合一", "desc": "减伤窗口期间被保护友军反伤 +25%", "effects": {"shield_reflect_pct": 0.25}}
	},
	"xiahoudun": {
		"root_class": "tank", "root": ["盲夏侯体", "独眼兵略", "疾风冲阵"],
		"role": [
			{"name": "拔矢啖睛", "desc": "每次受创 +6 行动条", "effects": {"action_on_taken_add": [6, 6]}},
			{"name": "刚烈", "desc": "近战减伤值 +24/级（值/(值+100) 结算），并常驻减伤窗口", "effects": {"armor_melee_add": [24, 24], "taken_reduction_pct": [0.125, 0.125]}},
			{"name": "独目之威", "desc": "对前军 +20%/级", "effects": {"damage_front_pct": [0.2, 0.2]}}],
		"skill": [
			{"name": "镇前", "desc": "对前军 +50%", "max": 1, "effects": {"damage_front_pct": 0.5}},
			{"name": "怒目", "desc": "开局行动条 +30", "max": 1, "effects": {"action_start_add": 60}},
			{"name": "刚烈反噬", "desc": "受创时对攻击者反伤 20% maxHP（引擎按反伤比例）", "max": 1, "effects": {"thorns_pct": 0.2}}],
		"branch": [
			{"name": "刚烈·倍", "desc": "受创成长翻倍：受创 +6 行动条、反伤强化、近战减伤值 +20", "effects": {"action_on_taken_add": 6, "thorns_pct": 0.1, "armor_melee_add": 20}},
			{"name": "强攻", "desc": "伤害 +62.5%", "effects": {"damage_pct": 0.625}}],
		"bond": {"name": "独目之义", "desc": "夏侯渊+夏侯惇组合效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "独目愈勇", "desc": "整局每回合生命 +5%，上限 +50%/87.5%", "effects": {"round_hp_pct": [0.05, 0.05]}},
		"soul": {"name": "独目苍狼", "desc": "每次受击 +4 行动条（每场累计上限 200）", "effects": {"action_on_taken_add": 4, "action_on_taken_cap": 200}}},
	"simayi": {
		"root_class": "output", "root": ["冢虎之躯", "鹰视兵略", "狼顾疾谋"],
		"role": [
			{"name": "深谋", "desc": "战斗 30秒后伤害 +25%/级", "effects": {"late_damage_pct": [0.25, 0.25]}},
			{"name": "鹰视狼顾", "desc": "伤害 +30%/级、冷却极速 +16/级", "effects": {"damage_pct": [0.3, 0.3], "cooldown_haste_add": [16, 16]}},
			{"name": "隐忍", "desc": "前 30秒受伤 -20%/级", "effects": {"early_taken_reduction_pct": [0.2, 0.2]}}],
		"skill": [
			{"name": "冢虎", "desc": "对 <87.5% 目标 +75%", "max": 1, "effects": {"damage_low_pct": 0.75}},
			{"name": "疾雷", "desc": "雷击附带 0.8秒眩晕（折算控制强度 +25%）", "max": 1, "effects": {"control_power_pct": 0.25}},
			{"name": "熬史", "desc": "每次受创下次伤害 +12.5%（战斗内叠 5）", "max": 1, "effects": {"on_taken_damage_buff_pct": 0.125}}],
		"branch": [
			{"name": "韬光养晦", "desc": "前 30秒受伤 -25%、之后伤害 +87.5%", "effects": {"early_taken_reduction_pct": 0.25, "late_damage_pct": 0.875}},
			{"name": "雷霆", "desc": "直伤 +62.5%", "effects": {"damage_pct": 0.625}}],
		"bond": {"name": "冢虎踞魏", "desc": "魏阵营羁绊效果 +25%/级", "effects": {"skill_effect_pct": [0.25, 0.25]}},
		"evergreen": {"name": "鹰视渐明", "desc": "战斗内每 10 秒伤害 +5%（2 级 +7.5%），上限 +25%/50%（与 30秒机制联动）", "effects": {"growth_damage_pct": [0.05, 0.075]}},
		"soul": {"name": "鹰视狼顾", "desc": "战斗 30秒后所有伤害 +62.5%", "effects": {"late_damage_pct": 0.625}}
	},
	"guojia": {
		"root_class": "output", "root": ["鬼才之躯", "奉孝兵略", "冰策疾谋"],
		"role": [
			{"name": "冰封千里", "desc": "冻结时长 +1s/级（折算控制强度 +37.5%/级）", "effects": {"control_power_pct": [0.375, 0.375]}},
			{"name": "遗计", "desc": "阵亡时全场敌人受破碎伤害", "effects": {"death_explode_pct": [2.5, 2.5]}},
			{"name": "鬼才", "desc": "破碎伤害 +37.5%/级（引擎折算）", "effects": {"damage_pct": [0.375, 0.375]}}],
		"skill": [
			{"name": "寒霜", "desc": "破碎伤害 +75%（引擎折算）", "max": 1, "effects": {"damage_pct": 0.75}},
			{"name": "极寒", "desc": "被冻结者受伤 +37.5%", "max": 1, "effects": {"damage_frozen_pct": 0.375}},
			{"name": "冰封三尺", "desc": "冻结目标 +1（伤害段折算）", "max": 1, "effects": {"damage_per_extra_hit_pct": 0.25}}],
		"branch": [
			{"name": "十胜十败", "desc": "冻结向：目标 +1（折算范围增伤 +62.5%）", "effects": {"damage_per_extra_hit_pct": 0.625}},
			{"name": "鬼才·极", "desc": "伤害 +62.5%", "effects": {"damage_pct": 0.625}}],
		"bond": {"name": "鬼毒相谋", "desc": "郭嘉+贾诩组合效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "冰寒彻骨", "desc": "战斗内每 10 秒冻结时长 +0.2s（2 级 +0.3s），上限 +0.5/2s（折算控制强度）", "effects": {"growth_control_pct": [0.062, 0.1]}},
		"soul": {"name": "遗计", "desc": "阵亡时冻结全场敌人 4秒（每场 1 次）", "effects": {"death_freeze_time": 4}}
	},
	"xunyu": {
		"root_class": "support", "root": ["王佐之躯", "颍川兵略", "令君疾策"],
		"role": [
			{"name": "驱虎吞狼", "desc": "加速时长 +2s/级（折算技能效果 +37.5%/级）", "effects": {"skill_effect_pct": [0.375, 0.375]}},
			{"name": "居中持重", "desc": "目标 +1/级（引擎折算）", "effects": {"skill_effect_pct": [0.25, 0.25]}},
			{"name": "明以举贤", "desc": "加速附带 +3 兵略（光环表达）", "effects": {"grant_ally_strategy_pct": [0.075, 0.075]}}],
		"skill": [
			{"name": "坚壁清野", "desc": "加速期间减伤 20%（光环表达）", "max": 1, "effects": {"grant_ally_taken_reduction_pct": 0.2}},
			{"name": "令君辅国", "desc": "加速结束保留一半 6秒（折算 +37.5%）", "max": 1, "effects": {"skill_effect_pct": 0.375}},
			{"name": "居中调停", "desc": "加速目标被控时长 -37.5%（光环表达）", "max": 1, "effects": {"grant_ally_control_reduction_pct": 0.375}}],
		"branch": [
			{"name": "王佐", "desc": "辅助 +75%", "effects": {"skill_effect_pct": 0.75}},
			{"name": "焚舟", "desc": "自身伤害 +62.5%", "effects": {"damage_pct": 0.625}}],
		"bond": {"name": "王佐毒士", "desc": "荀彧+贾诩组合效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "王佐日隆", "desc": "整局每回合加速效果 +5%（2 级 +7.5%），上限 +50%/87.5%", "effects": {"round_aura_pct": [0.05, 0.075]}},
		"soul": {"name": "令君辅国", "desc": "加速结束时目标保留一半加速效果 6秒（折算 +50%）", "effects": {"skill_effect_pct": 0.5}}
	},
	"jiaxu": {
		"root_class": "output", "root": ["毒士之躯", "凉州兵略", "乱武疾谋"],
		"role": [
			{"name": "神机", "desc": "初始毒层 +37.5%/级", "effects": {"poison_init_pct": [0.375, 0.375]}},
			{"name": "乱武", "desc": "中毒者伤害 -12.5%/级", "effects": {"poisoned_enemy_damage_reduction": [0.1, 0.1]}},
			{"name": "蛊惑", "desc": "中毒者受伤 +12.5%/级", "effects": {"damage_poisoned_pct": [0.125, 0.125]}}],
		"skill": [
			{"name": "疠疫", "desc": "目标 +1（2 级 +2；折算）", "max": 2, "effects": {"damage_per_extra_hit_pct": [0.25, 0.25]}},
			{"name": "毒士", "desc": "毒衰减减半（保留率 +62.5%）", "max": 1, "effects": {"poison_retention_add": 0.5}},
			{"name": "乱武天下", "desc": "中毒者阵亡时毒层转移", "max": 1, "effects": {"poison_transfer": 2}}],
		"branch": [
			{"name": "毒士·极", "desc": "持续：衰减减半（保留率 +62.5%）", "effects": {"poison_retention_add": 0.5}},
			{"name": "乱武·极", "desc": "爆发：层数 +75%、衰减加速", "effects": {"poison_init_pct": 0.75, "poison_retention_add": -0.3}}],
		"bond": {"name": "毒士乱谋", "desc": "郭嘉+贾诩 与 荀彧+贾诩组合效果 +30%/级", "effects": {"skill_effect_pct": [0.3, 0.3]}},
		"evergreen": {"name": "毒深难解", "desc": "战斗内每 10 秒毒伤 +10%（2 级 +15%），上限 +50%/100%", "effects": {"growth_poison_pct": [0.1, 0.15]}},
		"soul": {"name": "乱武天下", "desc": "中毒敌将阵亡时剩余毒层转移给最近敌人并刷新时长", "effects": {"poison_transfer": 2}}
	},

	# ============ 吴 · 15 ============
	"zhouyu": {
		"root_class": "output", "root": ["都督风仪", "赤焰谋略", "羽扇疾令"],
		"role": [
			{"name": "借东风", "desc": "灼烧时长 +2s/级", "effects": {"burn_duration_add": [2, 2]}},
			{"name": "连船", "desc": "地面火焰命中相邻 +25%/级（折算范围增伤）", "effects": {"damage_per_extra_hit_pct": [0.25, 0.25]}},
			{"name": "火攻", "desc": "灼烧伤害 +20%/级", "effects": {"burn_damage_pct": [0.2, 0.2]}}],
		"skill": [
			{"name": "火借风势", "desc": "燃烧格旁空格获 125% 火焰（折算）", "max": 1, "effects": {"damage_per_extra_hit_pct": 0.25}},
			{"name": "烈焰封江", "desc": "灼烧敌人行动增速 -25%", "max": 1, "effects": {"burning_enemy_slow_pct": 0.25}},
			{"name": "谈笑自若", "desc": "施放后自身 +30 行动条、冷却极速 +16", "max": 1, "effects": {"action_on_cast_add": 30, "cooldown_haste_add": 16}}],
		"branch": [
			{"name": "火烧赤壁", "desc": "大范围持续 +75%", "effects": {"burn_damage_pct": 0.75}},
			{"name": "谈笑樯橹", "desc": "范围缩小单点 +100%", "effects": {"damage_pct": 1}}],
		"bond": {"name": "四英之首", "desc": "四英杰（周鲁吕陆）效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "东风不歇", "desc": "战斗内每 10 秒灼烧伤害 +10%（2 级 +15%），上限 +50%/100%", "effects": {"growth_burn_pct": [0.1, 0.15]}},
		"soul": {"name": "东风既至", "desc": "每回合第 3 次施放时立即结算敌方所有灼烧一次伤害（不减剩余时长）", "effects": {"third_cast_burn_settle": 1}}
	},
	"luxun": {
		"root_class": "output", "root": ["儒将之躯", "社稷兵略", "书生疾剑"],
		"role": [
			{"name": "连营", "desc": "弹射次数 +1/级（折算范围增伤）", "effects": {"damage_per_extra_hit_pct": [0.3, 0.3]}},
			{"name": "火计", "desc": "弹射的灼烧伤害 +37.5%/级", "effects": {"burn_damage_pct": [0.375, 0.375]}},
			{"name": "儒将之风", "desc": "首段伤害 +25%/级", "effects": {"damage_pct": [0.25, 0.25]}}],
		"skill": [
			{"name": "声东击西", "desc": "弹射可跨排（折算）", "max": 1, "effects": {"damage_per_extra_hit_pct": 0.3}},
			{"name": "焚营", "desc": "弹射衰减 -37.5%", "max": 1, "effects": {"damage_per_extra_hit_pct": 0.375}},
			{"name": "石亭", "desc": "命中灼烧目标 +50%", "max": 1, "effects": {"damage_burning_pct": 0.5}}],
		"branch": [
			{"name": "火烧连营", "desc": "范围流：弹射强化（折算 +62.5% 并灼烧 +37.5%）", "effects": {"damage_per_extra_hit_pct": 0.625, "burn_damage_pct": 0.375}},
			{"name": "社稷之才", "desc": "单点首段 +87.5%", "effects": {"damage_pct": 0.875}}],
		"bond": {"name": "四英之谋", "desc": "四英杰 与 陆逊+孙权组合效果 +30%/级", "effects": {"skill_effect_pct": [0.3, 0.3]}},
		"evergreen": {"name": "薪火相传", "desc": "战斗内每 10 秒弹射上限成长（折算兵略 +7.5%/2 级 +10%），上限 +37.5%/75%", "effects": {"growth_strategy_pct": [0.075, 0.1]}},
		"soul": {"name": "石亭破皖", "desc": "弹射命中灼烧目标时引燃其所在格（6秒地面火焰，折算灼烧 +75%）", "effects": {"burn_damage_pct": 0.75}}
	},
	"lusu": {
		"root_class": "support", "root": ["忠厚之躯", "榻上策兵略", "指囷疾济"],
		"role": [
			{"name": "指囷相赠", "desc": "maxHP 提升量 +75%/级（折算技能效果）", "effects": {"skill_effect_pct": [0.375, 0.375]}},
			{"name": "缔盟", "desc": "治疗量 +25%/级", "effects": {"heal_pct": [0.25, 0.25]}},
			{"name": "厚德", "desc": "治疗附带 12.5% 减伤 6秒", "effects": {"heal_grant_reduction_pct": [0.125, 0.125]}}],
		"skill": [
			{"name": "缓兵之计", "desc": "治疗时目标行动增速 +25%（6秒）", "max": 1, "effects": {"heal_grant_action_pct": 0.25}},
			{"name": "同盟之义", "desc": "吴将目标附带驱散 1 减益", "max": 1, "effects": {"heal_cleanse": 2}},
			{"name": "榻上定策", "desc": "目标为生命最低者时治疗 +62.5%", "max": 1, "effects": {"heal_low_pct": 0.625}}],
		"branch": [
			{"name": "战略家", "desc": "maxHP +125%（折算技能效果 +75%）", "effects": {"skill_effect_pct": 0.75}},
			{"name": "厚德·极", "desc": "治疗 +75%", "effects": {"heal_pct": 0.75}}],
		"bond": {"name": "榻上定盟", "desc": "四英杰效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "联盟愈固", "desc": "战斗内每 10 秒治疗 +10%（2 级 +15%），上限 +50%/100%", "effects": {"growth_heal_pct": [0.1, 0.15]}},
		"soul": {"name": "榻上策", "desc": "被鲁肃治疗过的友军本场 maxHP +5%（可叠上限 +25%）", "effects": {"heal_target_maxhp_pct": 0.05}}
	},
	"lvmeng": {
		"root_class": "output", "root": ["白衣之躯", "克学兵略", "疾读疾战"],
		"role": [
			{"name": "士别三日", "desc": "战斗内每次施法 +10%（2 级 +15%，上限 +30/112.5%）", "effects": {"per_cast_damage_pct": [0.1, 0.15]}},
			{"name": "白衣", "desc": "对后军 +25%/级", "effects": {"damage_back_pct": [0.25, 0.25]}},
			{"name": "折节好学", "desc": "击杀后 +3 兵略（上限 +15）", "effects": {"strategy_on_kill_add": [6, 6]}}],
		"skill": [
			{"name": "破绽", "desc": "目标为后军时暴击率 +37.5%", "max": 1, "effects": {"crit_chance_pct": 0.375}},
			{"name": "刮目相待", "desc": "击杀后冷却 -50%", "max": 1, "effects": {"cooldown_on_kill_pct": 0.5}},
			{"name": "涌泉", "desc": "对残血（<75%）+62.5%", "max": 1, "effects": {"damage_low_pct": 0.625}}],
		"branch": [
			{"name": "白衣渡江", "desc": "刺后 +75%", "effects": {"damage_back_pct": 0.75}},
			{"name": "好学", "desc": "全队：吕蒙每次施法全队兵略 +1（上限 +15）", "effects": {"team_cast_strategy_add": 2}}],
		"bond": {"name": "白衣锦帆", "desc": "吕蒙+甘宁组合效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "士别三日·魂", "desc": "战斗 30秒后伤害 +37.5%（2 级 +62.5%）", "effects": {"late_damage_pct": [0.375, 0.625]}},
		"soul": {"name": "刮目相看", "desc": "战斗 30秒后伤害 +75%、行动增速 +50%", "effects": {"late_damage_pct": 0.75, "late_action_pct": 0.5}}
	},
	"sunjian": {
		"root_class": "output", "root": ["猛虎之躯", "乌程兵略", "虎跃疾击"],
		"role": [
			{"name": "猛虎下山", "desc": "消耗转化比率 +37.5%/级（折算技能效果）", "effects": {"skill_effect_pct": [0.375, 0.375]}},
			{"name": "玉玺护体", "desc": "首次濒死保留 1 点（2 级附 4秒 75% 减伤）", "effects": {"death_prevent_times": [1, 1]}},
			{"name": "破虏", "desc": "对前军 +25%/级", "effects": {"damage_front_pct": [0.25, 0.25]}}],
		"skill": [
			{"name": "虎父", "desc": "孙策/孙权在场 +37.5%", "max": 1, "effects": {"bond_ally_damage_pct": 0.375}},
			{"name": "猛虎撕咬", "desc": "击杀后 +40 行动条", "max": 1, "effects": {"action_on_kill_add": 40}},
			{"name": "平生之志", "desc": "生命越低伤害越高（每损失 50% +12.5%）", "max": 1, "effects": {"damage_missing_20_pct": 0.125}}],
		"branch": [
			{"name": "虎魂", "desc": "转化 +100%", "effects": {"skill_effect_pct": 1}},
			{"name": "破虏将军", "desc": "消耗减半、转化不变（折算 +37.5% 且减伤 25%）", "effects": {"skill_effect_pct": 0.375, "taken_reduction_pct": 0.25}}],
		"bond": {"name": "江东始祖", "desc": "孙氏之志（孙坚孙策孙权孙尚香）效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "猛虎之资", "desc": "整局每回合生命 +5%，上限 +50%/87.5%", "effects": {"round_hp_pct": [0.05, 0.05]}},
		"soul": {"name": "江东猛虎", "desc": "每损失 25% 生命伤害 +15%（动态）", "effects": {"damage_missing_20_pct": 0.3}}
	},
	"sunce": {
		"root_class": "output", "root": ["小霸王体", "霸王兵略", "狮儿疾袭"],
		"role": [
			{"name": "狮儿无敌", "desc": "每损失 25% 生命伤害加成 +5%", "effects": {"damage_missing_20_pct": [0.1, 0.1]}},
			{"name": "霸王枪", "desc": "攻击范围 +1 格（折算范围增伤）", "effects": {"damage_per_extra_hit_pct": [0.25, 0.25]}},
			{"name": "少年意气", "desc": "击杀后回复 10% maxHP", "effects": {"kill_heal_pct": [0.1, 0.1]}}],
		"skill": [
			{"name": "绝尘", "desc": "开局行动条 +40", "max": 1, "effects": {"action_start_add": 80}},
			{"name": "酣斗", "desc": "击杀后伤害 +37.5%（8秒）", "max": 1, "effects": {"kill_damage_stack_pct": 0.375}},
			{"name": "挟死一将", "desc": "对满血目标 +50%", "max": 1, "effects": {"damage_full_hp_pct": 0.5}}],
		"branch": [
			{"name": "小霸王", "desc": "损失转化翻倍（每损失 50% +20%）", "effects": {"damage_missing_20_pct": 0.2}},
			{"name": "孙郎", "desc": "击杀回血 20%", "effects": {"kill_heal_pct": 0.2}}],
		"bond": {"name": "小霸王", "desc": "孙氏之志 与 孙策+太史慈、孙策+大乔组合效果 +30%/级", "effects": {"skill_effect_pct": [0.3, 0.3]}},
		"evergreen": {"name": "霸王之姿", "desc": "整局每回合生命 +5%，上限 +50%/87.5%", "effects": {"round_hp_pct": [0.05, 0.05]}},
		"soul": {"name": "霸王再世", "desc": "首次致命以 75% 生命复活并获满行动条（每场 1 次）", "effects": {"death_prevent_times": 1, "death_prevent_heal_pct": 0.75, "death_prevent_full_action": 2}}
	},
	"sunquan": {
		"root_class": "support", "root": ["紫髯将军体", "守业兵略", "坐断东南疾令"],
		"role": [
			{"name": "生子当如孙仲谋", "desc": "maxHP 成长上限 2→2.5/3 倍（折算生命成长）", "effects": {"max_hp_pct": [0.25, 0.5]}},
			{"name": "守土", "desc": "反击伤害 +50%/级", "effects": {"skill_effect_pct": [0.5, 0.5]}},
			{"name": "亲贤", "desc": "每名吴将 +2 兵略/级", "effects": {"per_faction_ally_strategy": [4, 4]}}],
		"skill": [
			{"name": "坐断东南", "desc": "恢复比例 +12.5%（折算 +25%）", "max": 1, "effects": {"skill_effect_pct": 0.25}},
			{"name": "联姻", "desc": "与大乔/小乔同队时 +37.5%", "max": 1, "effects": {"bond_ally_damage_pct": 0.375}},
			{"name": "制衡", "desc": "每次施放后下次反击 +50%", "max": 1, "effects": {"per_cast_damage_pct": 0.5}}],
		"branch": [
			{"name": "守业", "desc": "maxHP 向：生命 +75%", "effects": {"max_hp_pct": 0.75}},
			{"name": "紫髯儿", "desc": "反击 +125%", "effects": {"skill_effect_pct": 1.25}}],
		"bond": {"name": "制衡江东", "desc": "孙氏之志 与 陆逊+孙权组合效果 +30%/级", "effects": {"skill_effect_pct": [0.3, 0.3]}},
		"evergreen": {"name": "基业渐固", "desc": "每次施放 maxHP 成长上限额外 +0.1 倍（折算每施放生命成长）", "effects": {"per_cast_maxhp_pct": 0.025}},
		"soul": {"name": "江东基业", "desc": "孙权 maxHP 成长以 125% 效果共享相邻友军（折算全队生命 +20%）", "effects": {"grant_ally_maxhp_pct": 0.2}}
	},
	"sunshangxiang": {
		"root_class": "output", "root": ["枭姬之躯", "弓腰姬兵略", "骏马疾驰"],
		"role": [
			{"name": "叠势", "desc": "每次施放兵略成长 +1→+2", "effects": {"per_cast_strategy_flat_add": [2, 2]}},
			{"name": "弓腰", "desc": "伤害 +20%/级", "effects": {"damage_pct": [0.2, 0.2]}},
			{"name": "才捷", "desc": "施放后 +20 行动条", "effects": {"action_on_cast_add": [20, 20]}}],
		"skill": [
			{"name": "归吴", "desc": "刘备在场伤害 +37.5%", "max": 1, "effects": {"bond_ally_damage_pct": 0.375}},
			{"name": "枭姬之勇", "desc": "战斗内每次击杀 +12.5% 兵略（上限 +25）", "max": 1, "effects": {"strategy_on_kill_add": 10}},
			{"name": "结姻", "desc": "每回合首次施放必中最低生命目标（折算 +50%）", "max": 1, "effects": {"first_cast_bonus_pct": 0.5}}],
		"branch": [
			{"name": "枭姬叠势", "desc": "成长无上限（引擎解除上限并 +2/次）", "effects": {"per_cast_strategy_flat_add": 4, "per_cast_no_cap": 1}},
			{"name": "弓腰姬", "desc": "单次 +75%", "effects": {"damage_pct": 0.75}}],
		"bond": {"name": "枭姬归吴", "desc": "孙氏之志效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "枭姬愈战", "desc": "每次施放的兵略成长额外 +1（2 级 +2）（滚雪球速率翻倍）", "effects": {"per_cast_strategy_flat_add": [2, 4]}},
		"soul": {"name": "气力过人", "desc": "每次施放 +2 兵略并使下次冷却 -0.4s（战斗内无限叠加）", "effects": {"per_cast_strategy_flat_add": 4, "per_cast_cooldown_flat_add": 0.4}}
	},
	"daqiao": {
		"root_class": "support", "root": ["国色之躯", "流离兵略", "曼舞疾吟"],
		"role": [
			{"name": "国色", "desc": "治疗量 +25%/级", "effects": {"heal_pct": [0.25, 0.25]}},
			{"name": "流离", "desc": "治疗附带驱散 1 减益", "effects": {"heal_cleanse": [2, 2]}},
			{"name": "静好", "desc": "治疗溢出转护盾 125%", "effects": {"heal_overflow_shield_pct": [1.25, 1.25]}}],
		"skill": [
			{"name": "花容", "desc": "溢出治疗转护盾", "max": 1, "effects": {"heal_overflow_shield_pct": 1.25}},
			{"name": "姊妹同心", "desc": "小乔在场治疗 +50%", "max": 1, "effects": {"bond_ally_heal_pct": 0.5}},
			{"name": "国色天香", "desc": "治疗目标 6秒受伤 -25%", "max": 1, "effects": {"heal_grant_reduction_pct": 0.25}}],
		"branch": [
			{"name": "国色天香·极", "desc": "治疗 +75%", "effects": {"heal_pct": 0.75}},
			{"name": "乱世佳人", "desc": "自身减伤 +30%", "effects": {"taken_reduction_pct": 0.3}}],
		"bond": {"name": "江东二乔", "desc": "孙策+大乔组合效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "芳华愈盛", "desc": "战斗内每 10 秒治疗 +10%（2 级 +15%），上限 +50%/100%", "effects": {"growth_heal_pct": [0.1, 0.15]}},
		"soul": {"name": "流离之芳", "desc": "被治疗友军 6秒内受伤 -37.5%", "effects": {"heal_grant_reduction_pct": 0.375}}
	},
	"xiaoqiao": {
		"root_class": "support", "root": ["天香之躯", "缓阵兵略", "轻歌疾舞"],
		"role": [
			{"name": "天香", "desc": "减速强度 +25%/级（折算控制强度）", "effects": {"control_power_pct": [0.25, 0.25]}},
			{"name": "周郎顾曲", "desc": "周瑜在场减速时长 +4s（折算 +50%）", "effects": {"bond_ally_control_pct": [0.5, 0.5]}},
			{"name": "香风", "desc": "作用排扩展至中军（折算技能效果）", "effects": {"skill_effect_pct": [0.25, 0.25]}}],
		"skill": [
			{"name": "玉容", "desc": "被减速目标受伤 +20%", "max": 1, "effects": {"damage_slowed_pct": 0.2}},
			{"name": "天香护体", "desc": "施放后自身减伤 25%（6秒）", "max": 1, "effects": {"post_cast_reduction_pct": 0.25}},
			{"name": "缓兵", "desc": "被减速目标伤害 -20%", "max": 1, "effects": {"slowed_enemy_damage_reduction": 0.16}}],
		"branch": [
			{"name": "缓阵", "desc": "控制向 +75%", "effects": {"control_power_pct": 0.75}},
			{"name": "天香·极", "desc": "辅助向 +62.5%", "effects": {"skill_effect_pct": 0.625}}],
		"bond": {"name": "曲误周郎", "desc": "周瑜+小乔组合效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "香风渐烈", "desc": "战斗内每 10 秒减速强度 +7.5%（2 级 +10%），上限 +37.5%/75%（折算控制强度）", "effects": {"growth_control_pct": [0.075, 0.1]}},
		"soul": {"name": "曲有误，周郎顾", "desc": "施放后周瑜（在场）+60 行动条；不在场全队 +10", "effects": {"cast_ally_action": 60, "cast_team_action": 20}}
	},
	"taishici": {
		"root_class": "output", "root": ["箭手之躯", "酣战兵略", "双戟疾弓"],
		"role": [
			{"name": "大丈夫", "desc": "对行动条 ≥80 目标 +25%/级", "effects": {"damage_high_action_pct": [0.25, 0.25]}},
			{"name": "信义", "desc": "灼烧伤害 +37.5%/级", "effects": {"burn_damage_pct": [0.375, 0.375]}},
			{"name": "猿臂", "desc": "可选任意排的高条目标（折算）", "effects": {"skill_effect_pct": [0.25, 0.25]}}],
		"skill": [
			{"name": "神亭鏖战", "desc": "命中高条目标压退 37.5% 行动条", "max": 1, "effects": {"action_push_on_hit_pct": 0.375}},
			{"name": "酣斗神亭", "desc": "击杀后 +40 行动条", "max": 1, "effects": {"action_on_kill_add": 40}},
			{"name": "信义灼灼", "desc": "灼烧目标 +50%", "max": 1, "effects": {"damage_burning_pct": 0.5}}],
		"branch": [
			{"name": "酣斗", "desc": "伤害 +62.5%", "effects": {"damage_pct": 0.625}},
			{"name": "义士", "desc": "灼烧 +100%", "effects": {"burn_damage_pct": 1}}],
		"bond": {"name": "神亭之义", "desc": "孙策+太史慈 与 太史慈+甘宁组合效果 +30%/级", "effects": {"skill_effect_pct": [0.3, 0.3]}},
		"evergreen": {"name": "烈戟愈酣", "desc": "战斗内每 10 秒兵略 +7.5%，上限 +37.5%/75%", "effects": {"growth_strategy_pct": [0.075, 0.075]}},
		"soul": {"name": "三尺剑立功名", "desc": "击杀后下一次技能必定暴击", "effects": {"kill_next_crit_times": 99}}
	},
	"dingfeng": {
		"root_class": "output", "root": ["雪中之躯", "短兵兵略", "雪夜疾袭"],
		"role": [
			{"name": "雪中奋短兵", "desc": "压退幅度 +20%/级", "effects": {"action_push_pct": [0.2, 0.2]}},
			{"name": "果断", "desc": "冷却极速 +16/级", "effects": {"cooldown_haste_add": [16, 16]}},
			{"name": "冬雪", "desc": "对被减速目标 +25%/级", "effects": {"damage_slowed_pct": [0.25, 0.25]}}],
		"skill": [
			{"name": "冬战", "desc": "对被减速目标 +62.5%", "max": 1, "effects": {"damage_slowed_pct": 0.625}},
			{"name": "挽狂澜", "desc": "开局行动条 +35", "max": 1, "effects": {"action_start_add": 70}},
			{"name": "雪夜追击", "desc": "击杀后 +40 行动条", "max": 1, "effects": {"action_on_kill_add": 40}}],
		"branch": [
			{"name": "短兵相接", "desc": "压条 +100%", "effects": {"action_push_pct": 1}},
			{"name": "雪夜", "desc": "伤害 +62.5%", "effects": {"damage_pct": 0.625}}],
		"bond": {"name": "雪卫同袍", "desc": "丁奉+徐盛组合效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "雪势愈急", "desc": "战斗内每 10 秒压退幅度 +5%（2 级 +7.5%），上限 +25%/50%", "effects": {"growth_push_pct": [0.05, 0.075]}},
		"soul": {"name": "雪中奋短兵·极", "desc": "被压退目标 6秒内行动增速 -75%", "effects": {"push_slow_pct": 0.75}}
	},
	"xusheng": {
		"root_class": "tank", "root": ["宿卫之躯", "疑城兵略", "水军疾阵"],
		"role": [
			{"name": "疑城", "desc": "水阵时长 +3s/级（折算控制强度）", "effects": {"control_power_pct": [0.5, 0.5]}},
			{"name": "破朔", "desc": "水阵内敌人受伤 +20%/级（折算）", "effects": {"damage_pct": [0.2, 0.2]}},
			{"name": "水操", "desc": "水阵减速强度 +20%/级（折算控制强度）", "effects": {"control_power_pct": [0.2, 0.2]}}],
		"skill": [
			{"name": "水阵连横", "desc": "水阵扩展同排相邻格（折算）", "max": 1, "effects": {"damage_per_extra_hit_pct": 0.375}},
			{"name": "百里疑城", "desc": "释放后获 20% maxHP 护盾", "max": 1, "effects": {"post_cast_shield_pct": 0.2}},
			{"name": "水淹", "desc": "水阵结束时对阵内敌人 250% 伤害（折算）", "max": 1, "effects": {"damage_pct": 0.5}}],
		"branch": [
			{"name": "水阵·极", "desc": "领域强化 +100%", "effects": {"skill_effect_pct": 1}},
			{"name": "敢死", "desc": "直伤 +75%", "effects": {"damage_pct": 0.75}}],
		"bond": {"name": "水雪之阵", "desc": "丁奉+徐盛组合效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "疑城百里", "desc": "战斗内每 10 秒水阵时长成长（折算控制强度 +25%/40%），上限对应 +3/10s", "effects": {"growth_control_pct": [0.25, 0.4]}},
		"soul": {"name": "滨江疑城", "desc": "水阵中敌人受灼烧伤害 +75%", "effects": {"burn_damage_pct": 0.75}}
	},
	"ganning": {
		"root_class": "output", "root": ["锦帆之躯", "百翎兵略", "铃震疾驰"],
		"role": [
			{"name": "锦帆百翎", "desc": "协击伤害 +25%/级", "effects": {"damage_pct": [0.25, 0.25]}},
			{"name": "铃声震江", "desc": "协击友军 +1（折算技能效果）", "effects": {"skill_effect_pct": [0.375, 0.375]}},
			{"name": "锦帆贼", "desc": "击杀后 +5 兵略（上限 +25）", "effects": {"strategy_on_kill_add": [10, 10]}}],
		"skill": [
			{"name": "劫营", "desc": "开局行动条 +40", "max": 1, "effects": {"action_start_add": 80}},
			{"name": "百骑劫营", "desc": "击杀后全队 +16 行动条", "max": 1, "effects": {"kill_team_action": 16}},
			{"name": "锦帆夜袭", "desc": "战斗 30秒后协击伤害 +50%", "max": 1, "effects": {"late_damage_pct": 0.5}}],
		"branch": [
			{"name": "百翎", "desc": "协击 +75%", "effects": {"damage_pct": 0.75}},
			{"name": "单骑", "desc": "自身 +62.5% 且暴击 +12.5%", "effects": {"damage_pct": 0.625, "crit_chance_pct": 0.125}}],
		"bond": {"name": "锦帆游侠", "desc": "太史慈+甘宁 与 吕蒙+甘宁组合效果 +30%/级", "effects": {"skill_effect_pct": [0.3, 0.3]}},
		"evergreen": {"name": "铃声愈厉", "desc": "战斗内每 10 秒兵略 +7.5%，上限 +37.5%/75%", "effects": {"growth_strategy_pct": [0.075, 0.075]}},
		"soul": {"name": "百骑劫魏营", "desc": "每场首次释放锦帆并击时，甘宁与协击友军额外 +100 行动条", "effects": {"first_cast_team_action": 100}}
	},
	"huanggai": {
		"root_class": "output", "root": ["苦肉之躯", "老将兵略", "诈降疾舟"],
		"role": [
			{"name": "苦肉", "desc": "消耗转伤害比率 +37.5%/级（折算技能效果）", "effects": {"skill_effect_pct": [0.375, 0.375]}},
			{"name": "老当益壮", "desc": "maxHP +12.5%/级", "effects": {"max_hp_pct": [0.125, 0.125]}},
			{"name": "诈降", "desc": "开局 10秒敌方不优先攻击黄盖（引擎隐身表达）", "effects": {"stealth_time": [10, 10]}}],
		"skill": [
			{"name": "火船", "desc": "列伤害附带 6秒灼烧", "max": 1, "effects": {"burn_duration_add": 6}},
			{"name": "赤壁旧功", "desc": "周瑜在场伤害 +37.5%", "max": 1, "effects": {"bond_ally_damage_pct": 0.375}},
			{"name": "三朝元老", "desc": "孤注一掷不再触发阵亡", "max": 1, "effects": {"no_self_death": 2}}],
		"branch": [
			{"name": "苦肉计", "desc": "转化 +100%", "effects": {"skill_effect_pct": 1}},
			{"name": "老将稳重", "desc": "消耗减半、转化不变（折算 +37.5% 且减伤 25%）", "effects": {"skill_effect_pct": 0.375, "taken_reduction_pct": 0.25}}],
		"bond": {"name": "老臣之心", "desc": "周瑜+黄盖 与 黄盖+孙坚组合效果 +30%/级", "effects": {"skill_effect_pct": [0.3, 0.3]}},
		"evergreen": {"name": "老当益壮·魂", "desc": "整局每回合生命 +5%，上限 +50%/87.5%", "effects": {"round_hp_pct": [0.05, 0.05]}},
		"soul": {"name": "赤壁火船", "desc": "技能命中时点燃该列地面（10秒灼烧）", "effects": {"burn_ground_on_hit": 10}}
	},

	# ============ 群 · 15 ============
	"lvbu": {
		"root_class": "output", "root": ["飞将之躯", "无双兵威", "赤兔疾驰"],
		"role": [
			{"name": "辕门射戟", "desc": "目标每少 1 人 +20%/级（引擎以目标排孤立折算）", "effects": {"damage_lone_target_pct": [0.2, 0.2]}},
			{"name": "人中吕布", "desc": "击杀获 +15% 伤害（本回合叠）", "effects": {"kill_damage_stack_pct": [0.15, 0.15]}},
			{"name": "飞将", "desc": "开局行动条 +20/级", "effects": {"action_start_add": [40, 40]}}],
		"skill": [
			{"name": "方天画戟", "desc": "命中 ≥3 人获 25% maxHP 护盾（折算）", "max": 1, "effects": {"post_cast_shield_pct": 0.25}},
			{"name": "三英之敌", "desc": "同时被 3 名敌人攻击时受伤 -37.5%（折算常驻）", "max": 1, "effects": {"taken_reduction_pct": 0.2}},
			{"name": "枭勇", "desc": "击杀后 +50 行动条", "max": 1, "effects": {"action_on_kill_add": 50}}],
		"branch": [
			{"name": "天下无双", "desc": "击杀滚雪球：+30%/层（上限 2 层）", "effects": {"kill_damage_stack_pct": 0.3}},
			{"name": "独战群雄", "desc": "无友军相邻时伤害与减伤 +37.5%", "effects": {"damage_lone_pct": 0.375, "taken_reduction_pct": 0.375}}],
		"bond": {"name": "温侯陈宫", "desc": "陈宫+吕布组合效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "无双愈战", "desc": "战斗内每 10 秒兵略 +7.5%，上限 +37.5%/75%", "effects": {"growth_strategy_pct": [0.075, 0.075]}},
		"soul": {"name": "鬼神降世", "desc": "每回合首次生命低于 75% 时清除控制并获 4秒伤害免疫（每回合 1 次）", "effects": {"low_hp_cleanse_threshold": 0.6, "low_hp_cleanse_immune_time": 4}}
	},
	"dongzhuo": {
		"root_class": "tank", "root": ["暴君之躯", "郿坞兵略", "相国疾令"],
		"role": [
			{"name": "横征", "desc": "转化比率 +25%/级（折算技能效果）", "effects": {"skill_effect_pct": [0.25, 0.25]}},
			{"name": "暴虐", "desc": "受创反伤 12.5%/级", "effects": {"thorns_pct": [0.125, 0.125]}},
			{"name": "郿坞积粮", "desc": "maxHP +12.5%/级", "effects": {"max_hp_pct": [0.125, 0.125]}}],
		"skill": [
			{"name": "郿坞", "desc": "命中后回复 12.5% maxHP（折算吸血）", "max": 1, "effects": {"lifesteal_pct": 0.375}},
			{"name": "焚城", "desc": "对前军 +50%", "max": 1, "effects": {"damage_front_pct": 0.5}},
			{"name": "暴敛", "desc": "对后排 +37.5%", "max": 1, "effects": {"damage_back_pct": 0.375}}],
		"branch": [
			{"name": "暴君", "desc": "伤害 +62.5%", "effects": {"damage_pct": 0.625}},
			{"name": "酒池肉林", "desc": "maxHP +37.5%", "effects": {"max_hp_pct": 0.375}}],
		"bond": {"name": "暴君倾城", "desc": "董卓+貂蝉组合效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "郿坞愈深", "desc": "整局每回合生命 +5%，上限 +50%/87.5%", "effects": {"round_hp_pct": [0.05, 0.05]}},
		"soul": {"name": "暴君横征·虐", "desc": "生命高于 125% 时伤害额外 +62.5%", "effects": {"high_hp_damage_pct": 0.625}}
	},
	"diaochan": {
		"root_class": "support", "root": ["倾城之躯", "离间兵略", "莲步疾舞"],
		"role": [
			{"name": "闭月", "desc": "魅惑时长 +1s/级（折算控制强度 +30%/级）", "effects": {"control_power_pct": [0.3, 0.3]}},
			{"name": "离间", "desc": "被迫攻击优先其队友（折算）", "effects": {"skill_effect_pct": [0.25, 0.25]}},
			{"name": "红颜", "desc": "自身受伤 -12.5%/级", "effects": {"taken_reduction_pct": [0.125, 0.125]}}],
		"skill": [
			{"name": "连环计", "desc": "吕布在场魅惑 +3s（折算 +50%）", "max": 1, "effects": {"bond_ally_control_pct": 0.5}},
			{"name": "拜月", "desc": "魅惑解除留 6秒减速", "max": 1, "effects": {"charm_end_slow_time": 6}},
			{"name": "倾国", "desc": "魅惑目标受伤 +25%", "max": 1, "effects": {"damage_charmed_pct": 0.25}}],
		"branch": [
			{"name": "倾国", "desc": "控制向 +75%", "effects": {"control_power_pct": 0.75}},
			{"name": "红颜·极", "desc": "自保 +30%", "effects": {"taken_reduction_pct": 0.3}}],
		"bond": {"name": "倾城离间", "desc": "董卓+貂蝉组合效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "舞袖不休", "desc": "战斗内每 10 秒魅惑时长 +0.2s（2 级 +0.3s），上限 +0.5/2s（折算控制强度）", "effects": {"growth_control_pct": [0.062, 0.1]}},
		"soul": {"name": "闭月羞花", "desc": "魅惑结束时目标对相邻同伴造成 200% 兵略伤害", "effects": {"charm_end_betrayal_pct": 2}}
	},
	"gaoshun": {
		"root_class": "tank", "root": ["陷阵之躯", "陷阵营兵略", "严训疾攻"],
		"role": [
			{"name": "陷阵营", "desc": "易碎时长 +2s/级（折算控制强度 +37.5%/级）", "effects": {"control_power_pct": [0.375, 0.375]}},
			{"name": "严整", "desc": "伤害 +20%/级", "effects": {"damage_pct": [0.2, 0.2]}},
			{"name": "死战", "desc": "生命每低 50% 伤害 +12.5%", "effects": {"damage_missing_20_pct": [0.125, 0.125]}}],
		"skill": [
			{"name": "破甲", "desc": "易碎目标受伤 +37.5%（折算对减益目标）", "max": 1, "effects": {"damage_debuff_pct": 0.375}},
			{"name": "营规", "desc": "自身受伤 -25%", "max": 1, "effects": {"taken_reduction_pct": 0.25}},
			{"name": "陷阵突袭", "desc": "击杀后 +40 行动条", "max": 1, "effects": {"action_on_kill_add": 40}}],
		"branch": [
			{"name": "陷阵", "desc": "控制增伤：对减益目标 +75%", "effects": {"damage_debuff_pct": 0.75}},
			{"name": "营督", "desc": "减伤 +30%", "effects": {"taken_reduction_pct": 0.3}}],
		"bond": {"name": "陷阵辅主", "desc": "陈宫+高顺组合效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "陷阵愈坚", "desc": "整局每回合生命 +5%，上限 +50%/87.5%", "effects": {"round_hp_pct": [0.05, 0.05]}},
		"soul": {"name": "有死无生", "desc": "首次致命保留 1 点并立即爆发一次范围伤害（每场 1 次）", "effects": {"death_prevent_times": 1, "death_explode_pct": 2.5}}
	},
	"chengong": {
		"root_class": "aura", "root": ["谋士之躯", "智迟兵略", "缓策疾谋"],
		"role": [
			{"name": "智迟", "desc": "光环冷却减免 +0.6s/级", "effects": {"aura_cooldown_add": [0.6, 0.6]}},
			{"name": "辅翼", "desc": "同列友军 +2 兵略/级（光环表达）", "effects": {"grant_column_strategy_add": [4, 4]}},
			{"name": "缓策", "desc": "自身受伤 -12.5%/级", "effects": {"taken_reduction_pct": [0.125, 0.125]}}],
		"skill": [
			{"name": "明达", "desc": "光环扩展至相邻列（折算冷却减免）", "max": 1, "effects": {"aura_cooldown_add": 0.4}},
			{"name": "逆谋", "desc": "受创时同列伤害 +20%（折算受创增伤）", "max": 1, "effects": {"on_taken_damage_buff_pct": 0.2}},
			{"name": "谋定", "desc": "同列友军施法后 +10 行动条", "max": 1, "effects": {"column_cast_action": 10}}],
		"branch": [
			{"name": "王佐之才", "desc": "团队 +125%（冷却减免 +1s）", "effects": {"aura_cooldown_add": 1}},
			{"name": "宁死不降", "desc": "自保 +30%", "effects": {"taken_reduction_pct": 0.3}}],
		"bond": {"name": "谋定辅弼", "desc": "陈宫+吕布 与 陈宫+高顺组合效果 +30%/级", "effects": {"skill_effect_pct": [0.3, 0.3]}},
		"evergreen": {"name": "智迟谋愈速", "desc": "整局每回合光环冷却减免 +0.2s（2 级 +0.3s），上限 +0.5/2s", "effects": {"round_aura_cooldown_add": [0.2, 0.3]}},
		"soul": {"name": "智迟谋速", "desc": "同列友军每次施法后获 5 行动条", "effects": {"column_cast_action": 10}}
	},
	"yanliang": {
		"root_class": "output", "root": ["河北之躯", "先锋兵略", "疾冲陷阵"],
		"role": [
			{"name": "河北名将", "desc": "对后排 +25%/级", "effects": {"damage_back_pct": [0.25, 0.25]}},
			{"name": "骄兵", "desc": "伤害 +30%/级、受伤 +12.5%/级", "effects": {"damage_pct": [0.3, 0.3], "taken_mod_pct": [0.125, 0.125]}},
			{"name": "猛鸷", "desc": "对满血目标 +25%/级", "effects": {"damage_full_hp_pct": [0.25, 0.25]}}],
		"skill": [
			{"name": "斩将", "desc": "对 <100% 目标 +62.5%", "max": 1, "effects": {"damage_low_pct": 0.625}},
			{"name": "白马之约", "desc": "阵亡时文丑获满行动条", "max": 1, "effects": {"death_ally_action": 200}},
			{"name": "猛袭", "desc": "击杀后 +40 行动条", "max": 1, "effects": {"action_on_kill_add": 40}}],
		"branch": [
			{"name": "猛袭·极", "desc": "输出 +62.5%", "effects": {"damage_pct": 0.625}},
			{"name": "庭柱", "desc": "移除骄兵惩罚并减伤 30%", "effects": {"taken_reduction_pct": 0.3}}],
		"bond": {"name": "河北之矛", "desc": "河北四庭柱效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "河北雄烈", "desc": "战斗内每 10 秒兵略 +7.5%，上限 +37.5%/75%", "effects": {"growth_strategy_pct": [0.075, 0.075]}},
		"soul": {"name": "河北双璧", "desc": "文丑在场时颜良伤害 +50%", "effects": {"bond_ally_damage_pct": 0.5}}
	},
	"wenchou": {
		"root_class": "output", "root": ["河北之躯", "延津兵略", "铁蹄疾冲"],
		"role": [
			{"name": "延津之战", "desc": "对中军 +25%/级", "effects": {"damage_mid_pct": [0.25, 0.25]}},
			{"name": "双璧", "desc": "颜良在场受伤 -25%", "effects": {"bond_ally_taken_reduction": [0.2, 0.2]}},
			{"name": "燃怒", "desc": "受创 +10% 伤害（8秒叠 5）", "effects": {"on_taken_damage_buff_pct": [0.1, 0.1]}}],
		"skill": [
			{"name": "破军", "desc": "对前军 +50%", "max": 1, "effects": {"damage_front_pct": 0.5}},
			{"name": "颜良之哀", "desc": "颜良阵亡时狂暴 +75% 至战斗结束", "max": 1, "effects": {"on_ally_death_damage_pct": 0.75}},
			{"name": "破阵", "desc": "击杀后 +40 行动条", "max": 1, "effects": {"action_on_kill_add": 40}}],
		"branch": [
			{"name": "破阵·极", "desc": "输出 +62.5%", "effects": {"damage_pct": 0.625}},
			{"name": "庭柱之勇", "desc": "承伤向 +37.5% 减伤", "effects": {"taken_reduction_pct": 0.375}}],
		"bond": {"name": "河北之盾", "desc": "河北四庭柱效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "河北虎狼", "desc": "整局每回合生命 +5%，上限 +50%/87.5%", "effects": {"round_hp_pct": [0.05, 0.05]}},
		"soul": {"name": "河北双璧·武", "desc": "颜良阵亡时文丑狂暴：伤害 +75% 至战斗结束", "effects": {"on_ally_death_damage_pct": 0.75}}
	},
	"qunzhanghe": {
		"root_class": "support", "root": ["护阵之躯", "军镇兵略", "坚阵疾守"],
		"role": [
			{"name": "军镇", "desc": "护盾量 +25%/级", "effects": {"shield_pct": [0.25, 0.25]}},
			{"name": "护阵", "desc": "目标 +1/级（折算护盾量）", "effects": {"shield_pct": [0.375, 0.375]}},
			{"name": "河北遗风", "desc": "颜良/文丑/高览在场护盾 +25%/级", "effects": {"bond_ally_shield_pct": [0.25, 0.25]}}],
		"skill": [
			{"name": "稳如磐石", "desc": "被护者减伤 12.5%", "max": 1, "effects": {"shielded_ally_reduction_pct": 0.125}},
			{"name": "坚阵", "desc": "护盾被打破时回复 12.5% maxHP", "max": 1, "effects": {"shield_break_heal_pct": 0.125}},
			{"name": "反守", "desc": "被护者反伤 25%", "max": 1, "effects": {"shield_reflect_pct": 0.25}}],
		"branch": [
			{"name": "固守", "desc": "护盾 +75%", "effects": {"shield_pct": 0.75}},
			{"name": "反击", "desc": "反伤向 +50%", "effects": {"shield_reflect_pct": 0.5}}],
		"bond": {"name": "列阵之约", "desc": "高览+群张郃组合效果 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
		"evergreen": {"name": "军镇愈固", "desc": "战斗内每 10 秒护盾量 +10%（2 级 +15%），上限 +50%/100%", "effects": {"growth_shield_pct": [0.1, 0.15]}},
		"soul": {"name": "河北护阵·坚", "desc": "护盾被打破时目标回复 12.5% 最大生命", "effects": {"shield_break_heal_pct": 0.125}}
	},
	"gaolan": {
		"root_class": "aura", "root": ["扬威之躯", "列阵兵略", "齐整疾列"],
		"role": [
			{"name": "列阵", "desc": "光环兵略 +50%/级（折算自身兵略 +20%/级）", "effects": {"strategy_pct_extra": [0.16, 0.16]}},
			{"name": "威仪", "desc": "自身兵略 +20%/级", "effects": {"strategy_pct_extra": [0.16, 0.16]}},
			{"name": "稳固", "desc": "自身受伤 -12.5%/级", "effects": {"taken_reduction_pct": [0.125, 0.125]}}],
		"skill": [
			{"name": "军威", "desc": "光环扩展至所在排（折算自身兵略）", "max": 1, "effects": {"strategy_pct_extra": 0.2}},
			{"name": "互为犄角", "desc": "同列相互减伤 15%（光环表达）", "max": 1, "effects": {"grant_ally_taken_reduction_pct": 0.15}},
			{"name": "扬威", "desc": "同列友军击杀时高览 +3 兵略（上限 +15）", "max": 1, "effects": {"column_kill_strategy_add": 6}}],
		"branch": [
			{"name": "扬威·极", "desc": "光环 +100%（折算自身兵略 +50%）", "effects": {"strategy_pct_extra": 0.4}},
			{"name": "战将", "desc": "自身 +62.5%", "effects": {"damage_pct": 0.625}}],
		"bond": {"name": "扬威之列", "desc": "高览+群张郃 与 河北四庭柱效果 +30%/级", "effects": {"skill_effect_pct": [0.3, 0.3]}},
		"evergreen": {"name": "列阵渐齐", "desc": "同列友军每次施法高览 +3.75% 光环效果（战斗内无上限，折算兵略成长）", "effects": {"column_cast_strategy_pct": 0.037}},
		"soul": {"name": "列阵扬威·齐", "desc": "同列友军每次施法高览获 +2 兵略（战斗内无限，光环随之成长）", "effects": {"column_cast_strategy_add": 4}}
	},
	"huatuo": {
		"root_class": "support", "root": ["神医之躯", "青囊兵略", "悬壶疾济"],
		"role": [
			{"name": "青囊", "desc": "治疗量 +25%/级", "effects": {"heal_pct": [0.25, 0.25]}},
			{"name": "五禽戏", "desc": "自身行动增速 +12.5%/级", "effects": {"action_gain_pct": [0.125, 0.125]}},
			{"name": "妙手", "desc": "对 <75% 目标治疗 +37.5%/级", "effects": {"heal_low_pct": [0.375, 0.375]}}],
		"skill": [
			{"name": "刮骨疗毒", "desc": "治疗附带清除重伤", "max": 1, "effects": {"heal_cleanse": 2}},
			{"name": "延年", "desc": "治疗同时 +7.5% maxHP（本场，上限 +25%）", "max": 1, "effects": {"heal_target_maxhp_pct": 0.075}},
			{"name": "良医", "desc": "治疗目标被控时长 -25%（光环表达）", "max": 1, "effects": {"grant_ally_control_reduction_pct": 0.25}}],
		"branch": [
			{"name": "神医", "desc": "群疗 +75%", "effects": {"heal_pct": 0.75}},
			{"name": "五禽戏·极", "desc": "自保 +37.5%", "effects": {"taken_reduction_pct": 0.375}}],
		"bond": {"name": "悬壶济世", "desc": "群阵营羁绊效果 +25%/级", "effects": {"skill_effect_pct": [0.25, 0.25]}},
		"evergreen": {"name": "医术愈精", "desc": "战斗内每 10 秒治疗 +10%（2 级 +15%），上限 +50%/100%", "effects": {"growth_heal_pct": [0.1, 0.15]}},
		"soul": {"name": "青囊遗世", "desc": "阵亡时全场友军获 10秒持续回复（每秒 75% 兵略，每场 1 次）", "effects": {"death_team_regen_pct": 0.75, "death_team_regen_time": 10}}
	},
	"yuji": {
		"root_class": "output", "root": ["仙师之躯", "蛊惑兵略", "符水疾咒"],
		"role": [
			{"name": "蛊毒", "desc": "初始毒层 +37.5%/级", "effects": {"poison_init_pct": [0.375, 0.375]}},
			{"name": "符水", "desc": "毒每秒伤害 +25%/级", "effects": {"poison_tick_pct": [0.25, 0.25]}},
			{"name": "妖言", "desc": "中毒者伤害 -10%/级", "effects": {"poisoned_enemy_damage_reduction": [0.08, 0.08]}}],
		"skill": [
			{"name": "咒术", "desc": "目标 +1（2 级 +2；折算）", "max": 2, "effects": {"damage_per_extra_hit_pct": [0.25, 0.25]}},
			{"name": "蛊惑", "desc": "中毒者受伤 +20%", "max": 1, "effects": {"damage_poisoned_pct": 0.2}},
			{"name": "仙术", "desc": "毒衰减速度 -37.5%（保留率 +18.75%）", "max": 1, "effects": {"poison_retention_add": 0.15}}],
		"branch": [
			{"name": "蛊毒仙术", "desc": "毒向：每秒毒伤 +50%", "effects": {"poison_tick_pct": 0.5}},
			{"name": "太平道", "desc": "直伤 +62.5%", "effects": {"damage_pct": 0.625}}],
		"bond": {"name": "符水济世", "desc": "群阵营羁绊效果 +25%/级", "effects": {"skill_effect_pct": [0.25, 0.25]}},
		"evergreen": {"name": "蛊毒愈深", "desc": "战斗内每 10 秒毒伤 +10%（2 级 +15%），上限 +50%/100%", "effects": {"growth_poison_pct": [0.1, 0.15]}},
		"soul": {"name": "蛊惑人心", "desc": "中毒敌将阵亡时于吉回复 12.5% 最大生命", "effects": {"poison_kill_heal_pct": 0.125}}
	},
	"zuoci": {
		"root_class": "support", "root": ["遁甲之躯", "仙丹兵略", "幻化疾步"],
		"role": [
			{"name": "遁甲", "desc": "治疗量 +25%/级", "effects": {"heal_pct": [0.25, 0.25]}},
			{"name": "幻", "desc": "自身受伤 -12.5%/级", "effects": {"taken_reduction_pct": [0.125, 0.125]}},
			{"name": "仙丹", "desc": "治疗附带 +7.5% maxHP（本场，上限 +25%）", "effects": {"heal_target_maxhp_pct": [0.075, 0.075]}}],
		"skill": [
			{"name": "济世", "desc": "治疗附带驱散 1 减益", "max": 1, "effects": {"heal_cleanse": 2}},
			{"name": "仙遁", "desc": "首次濒死保留 1 点（每场 1 次）", "max": 1, "effects": {"death_prevent_times": 1}},
			{"name": "幻化", "desc": "阵亡留幻影继续治疗 6秒（125%）", "max": 1, "effects": {"death_team_regen_pct": 1.25, "death_team_regen_time": 6}}],
		"branch": [
			{"name": "济世·极", "desc": "治疗 +75%", "effects": {"heal_pct": 0.75}},
			{"name": "戏曹", "desc": "幻影治疗 250% 且持续 10秒（折算 +4秒）", "effects": {"death_team_regen_pct": 1.25, "death_team_regen_time": 4}}],
		"bond": {"name": "仙术济世", "desc": "群阵营羁绊效果 +25%/级", "effects": {"skill_effect_pct": [0.25, 0.25]}},
		"evergreen": {"name": "道行渐深", "desc": "战斗内每 10 秒治疗 +10%（2 级 +15%），上限 +50%/100%", "effects": {"growth_heal_pct": [0.1, 0.15]}},
		"soul": {"name": "遁甲天书", "desc": "每累计治疗 2500% 兵略，下次治疗变为全体（每场 2 次）", "effects": {"heal_aoe_threshold_pct": 25, "heal_aoe_times": 2}}
	},
	"zhangjiao": {
		"root_class": "output", "root": ["天公之躯", "黄天兵略", "雷令疾咒"],
		"role": [
			{"name": "苍天已死", "desc": "对满血目标 +25%/级", "effects": {"damage_full_hp_pct": [0.25, 0.25]}},
			{"name": "黄天当立", "desc": "雷击伤害 +20%/级", "effects": {"damage_pct": [0.2, 0.2]}},
			{"name": "岁在甲子", "desc": "行动增速 +10%/级", "effects": {"action_gain_pct": [0.1, 0.1]}}],
		"skill": [
			{"name": "呼风唤雨", "desc": "雷击附带 0.8秒眩晕（折算控制强度 +25%）", "max": 1, "effects": {"control_power_pct": 0.25}},
			{"name": "符水治病", "desc": "击杀后治疗最低友军 50% 兵略", "max": 1, "effects": {"kill_team_heal_pct": 0.5}},
			{"name": "天公", "desc": "施放次数越多伤害越高（每次 +15%，上限 +75%）", "max": 1, "effects": {"per_cast_damage_pct": 0.15}}],
		"branch": [
			{"name": "大贤良师", "desc": "目标 +1（折算范围增伤 +62.5%）", "effects": {"damage_per_extra_hit_pct": 0.625}},
			{"name": "天公将军", "desc": "威力 +75%", "effects": {"damage_pct": 0.75}}],
		"bond": {"name": "黄天当立", "desc": "群阵营羁绊效果 +25%/级", "effects": {"skill_effect_pct": [0.25, 0.25]}},
		"evergreen": {"name": "苍天已死·雷", "desc": "战斗内每 10 秒雷击伤害 +7.5%（2 级 +10%），上限 +37.5%/75%", "effects": {"growth_damage_pct": [0.075, 0.1]}},
		"soul": {"name": "黄天当立·雷", "desc": "每场第 4 次施放时雷电全体轰击（每人递减 50%，折算 +100%）", "effects": {"fourth_cast_damage_pct": 1}}
	},
	"zhangliang": {
		"root_class": "support", "root": ["人公之躯", "虚弱兵略", "地阵疾咒"],
		"role": [
			{"name": "人公", "desc": "虚弱强度 +37.5%/级", "effects": {"skill_effect_pct": [0.375, 0.375]}},
			{"name": "乱军", "desc": "虚弱时长 +2s/级（折算控制强度 +35%/级）", "effects": {"control_power_pct": [0.35, 0.35]}},
			{"name": "地阵", "desc": "目标 +1/级（折算）", "effects": {"skill_effect_pct": [0.2, 0.2]}}],
		"skill": [
			{"name": "乘虚", "desc": "虚弱目标受伤 +30%", "max": 1, "effects": {"damage_debuff_pct": 0.3}},
			{"name": "黄天", "desc": "张角/张宝在场效果 +50%", "max": 1, "effects": {"bond_ally_damage_pct": 0.5}},
			{"name": "溃乱", "desc": "虚弱目标行动增速 -20%", "max": 1, "effects": {"debuff_enemy_action_reduction": 0.16}}],
		"branch": [
			{"name": "削弱", "desc": "辅助向 +75%", "effects": {"skill_effect_pct": 0.75}},
			{"name": "武卒", "desc": "自战 +62.5%", "effects": {"damage_pct": 0.625}}],
		"bond": {"name": "黄天之地", "desc": "群阵营羁绊效果 +25%/级", "effects": {"skill_effect_pct": [0.25, 0.25]}},
		"evergreen": {"name": "乱军渐盛", "desc": "整局每回合虚弱强度 +5%（2 级 +7.5%），上限 +50%/87.5%", "effects": {"round_aura_pct": [0.05, 0.075]}},
		"soul": {"name": "人公虚弱·溃", "desc": "虚弱敌人造成的伤害额外 -25%", "effects": {"debuff_enemy_damage_reduction": 0.2}}
	},
	"zhangbao": {
		"root_class": "aura", "root": ["地公之躯", "雷法兵略", "妖术疾躯"],
		"role": [
			{"name": "雷爆", "desc": "阵亡爆发伤害 +50%/级", "effects": {"death_explode_pct": [0.5, 0.5]}},
			{"name": "复生", "desc": "复生生命 +37.5%/级", "effects": {"revive_hp_pct": [0.375, 0.375]}},
			{"name": "妖兵", "desc": "复生后伤害 +25%/级", "effects": {"post_revive_damage_pct": [0.25, 0.25]}}],
		"skill": [
			{"name": "地公咒", "desc": "爆发目标 +1（折算）", "max": 1, "effects": {"death_explode_pct": 0.75}},
			{"name": "黄天加持", "desc": "复生后伤害 +100%", "max": 1, "effects": {"post_revive_damage_pct": 1}},
			{"name": "妖术", "desc": "爆发附带 2秒眩晕（折算控制强度 +30%）", "max": 1, "effects": {"control_power_pct": 0.3}}],
		"branch": [
			{"name": "地公雷爆", "desc": "亡语 +100%", "effects": {"death_explode_pct": 1}},
			{"name": "复生·极", "desc": "复生生命 +75%", "effects": {"revive_hp_pct": 0.75}}],
		"bond": {"name": "黄天之雷", "desc": "群阵营羁绊效果 +25%/级", "effects": {"skill_effect_pct": [0.25, 0.25]}},
		"evergreen": {"name": "妖力愈盛", "desc": "整局每回合爆发伤害 +7.5%（2 级 +10%），上限 +75%/125%", "effects": {"round_damage_pct": [0.075, 0.1]}},
		"soul": {"name": "黄天加持·魂", "desc": "复生后伤害 +100%，再次阵亡时雷爆仍触发（折算爆发 +125%）", "effects": {"post_revive_damage_pct": 1, "death_explode_pct": 1.25}}
	}
}
