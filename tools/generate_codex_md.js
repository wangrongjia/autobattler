// Generates a markdown codex file matching the in-game encyclopedia display.
// Simulates: normalization (skill_value→100, skill_output_base preserved),
// _star_skill_values (1-star), and _hero_bond_detail.
const fs = require("fs");

// ── Hero names (zh) ──
const names = {
	liubei:"刘备", guanyu:"关羽", zhangfei:"张飞", zhaoyun:"赵云", liushan:"刘禅",
	huangzhong:"黄忠", machao:"马超", madai:"马岱", weiyan:"魏延", zhugeliang:"诸葛亮",
	jiangwei:"姜维", pangtong:"庞统", menghuo:"孟获", zhurong:"祝融", dailaidongzhu:"带来洞主",
	caocao:"曹操", dianwei:"典韦", xuchu:"许褚", zhangliao:"张辽", yuejin:"乐进",
	xuhuang:"徐晃", zhanghe:"张郃", yujin:"于禁", xiahouyuan:"夏侯渊", caoren:"曹仁",
	xiahoudun:"夏侯惇", simayi:"司马懿", guojia:"郭嘉", xunyu:"荀彧", jiaxu:"贾诩",
	zhouyu:"周瑜", luxun:"陆逊", lvmeng:"吕蒙", lusu:"鲁肃", daqiao:"大乔",
	xiaoqiao:"小乔", taishici:"太史慈", ganning:"甘宁", huanggai:"黄盖", sunjian:"孙坚",
	sunce:"孙策", sunquan:"孙权", sunshangxiang:"孙尚香", dingfeng:"丁奉", xusheng:"徐盛",
	lvbu:"吕布", diaochan:"貂蝉", dongzhuo:"董卓", gaoshun:"高顺", chengong:"陈宫",
	yanliang:"颜良", wenchou:"文丑", qunzhanghe:"群张郃", gaolan:"高览", huatuo:"华佗",
	yuji:"于吉", zhangjiao:"张角", zhangliang:"张梁", zhangbao:"张宝", zuoci:"左慈"
};

// ── Faction membership ──
const factionOf = {
	liubei:"shu",guanyu:"shu",zhangfei:"shu",zhaoyun:"shu",liushan:"shu",huangzhong:"shu",machao:"shu",madai:"shu",weiyan:"shu",zhugeliang:"shu",jiangwei:"shu",pangtong:"shu",menghuo:"shu",zhurong:"shu",dailaidongzhu:"shu",
	caocao:"wei",dianwei:"wei",xuchu:"wei",zhangliao:"wei",yuejin:"wei",xuhuang:"wei",zhanghe:"wei",yujin:"wei",xiahouyuan:"wei",caoren:"wei",xiahoudun:"wei",simayi:"wei",guojia:"wei",xunyu:"wei",jiaxu:"wei",
	zhouyu:"wu",luxun:"wu",lvmeng:"wu",lusu:"wu",daqiao:"wu",xiaoqiao:"wu",taishici:"wu",ganning:"wu",huanggai:"wu",sunjian:"wu",sunce:"wu",sunquan:"wu",sunshangxiang:"wu",dingfeng:"wu",xusheng:"wu",
	lvbu:"qun",diaochan:"qun",dongzhuo:"qun",gaoshun:"qun",chengong:"qun",yanliang:"qun",wenchou:"qun",qunzhanghe:"qun",gaolan:"qun",huatuo:"qun",yuji:"qun",zhangjiao:"qun",zhangliang:"qun",zhangbao:"qun",zuoci:"qun"
};
const factionName = {shu:"蜀",wei:"魏",wu:"吴",qun:"群"};
const factionBondName = {shu:"汉室北伐",wei:"魏武中枢",wu:"江东联动",qun:"乱世争衡"};
const factionBondEffect = {
	shu:"2/5/8人时，本武将承伤降低2%/5%/8%；8人时受伤叠加2%额外减伤，最多3层，释放技能后清空。",
	wei:"2/5/8人时，本武将控制时长提高3%/8%/15%；8人时，对带有任意控制或减益的目标伤害提高15%。",
	wu:"2/5/8人时，本武将最大生命提高2%/5%/8%；8人时，每场战斗首次吴将濒死会触发全体吴将生命均摊并恢复10%最大生命。",
	qun:"2/5/8人时，本武将技能冷却缩短3%/8%/15%；8人时，每次释放技能有20%概率连续释放两次。"
};

// ── BASE_STATS from registered_hero_balance.gd ──
const baseStats = {
	caocao:{hp:5470,skill:100.0,cooldown:5.6,range:1}, caoren:{hp:5620,skill:100.0,cooldown:5.2,range:1},
	chengong:{hp:2280,skill:100.0,cooldown:0.0,range:3}, dailaidongzhu:{hp:4610,skill:100.0,cooldown:4.9,range:2},
	daqiao:{hp:2760,skill:100.0,cooldown:6.2,range:3}, dianwei:{hp:5260,skill:100.0,cooldown:5.2,range:1},
	diaochan:{hp:2520,skill:100.0,cooldown:6.5,range:3}, dingfeng:{hp:4020,skill:100.0,cooldown:5.4,range:1},
	dongzhuo:{hp:4680,skill:100.0,cooldown:5.5,range:2}, ganning:{hp:2960,skill:100.0,cooldown:6.0,range:2},
	gaolan:{hp:2940,skill:100.0,cooldown:0.0,range:3}, gaoshun:{hp:4380,skill:100.0,cooldown:6.5,range:1},
	guanyu:{hp:4320,skill:64.0,cooldown:8.5,range:1}, guojia:{hp:2520,skill:100.0,cooldown:6.4,range:3},
	huanggai:{hp:4200,skill:100.0,cooldown:8.8,range:1}, huangzhong:{hp:2960,skill:51.0,cooldown:4.0,range:3},
	huatuo:{hp:2280,skill:100.0,cooldown:5.5,range:3}, jiangwei:{hp:3600,skill:53.0,cooldown:6.5,range:1},
	jiaxu:{hp:2740,skill:100.0,cooldown:6.4,range:3}, liubei:{hp:3120,skill:40.0,cooldown:4.0,range:3},
	liushan:{hp:2880,skill:31.0,cooldown:4.0,range:2}, lusu:{hp:3120,skill:100.0,cooldown:5.6,range:3},
	luxun:{hp:2820,skill:100.0,cooldown:5.8,range:3}, lvbu:{hp:4680,skill:100.0,cooldown:6.5,range:2},
	lvmeng:{hp:3200,skill:100.0,cooldown:5.6,range:2}, machao:{hp:3000,skill:61.0,cooldown:7.5,range:2},
	madai:{hp:2980,skill:40.0,cooldown:20.0,range:3}, menghuo:{hp:4320,skill:47.0,cooldown:6.6,range:1},
	pangtong:{hp:2960,skill:42.0,cooldown:7.0,range:3}, qunzhanghe:{hp:3600,skill:100.0,cooldown:6.0,range:1},
	simayi:{hp:2740,skill:100.0,cooldown:6.4,range:3}, sunce:{hp:3720,skill:100.0,cooldown:5.2,range:1},
	sunjian:{hp:3300,skill:100.0,cooldown:15.0,range:1}, sunquan:{hp:3420,skill:100.0,cooldown:5.2,range:3},
	sunshangxiang:{hp:2760,skill:100.0,cooldown:5.2,range:3}, taishici:{hp:3200,skill:100.0,cooldown:6.0,range:2},
	weiyan:{hp:3780,skill:55.0,cooldown:5.0,range:1}, wenchou:{hp:3900,skill:100.0,cooldown:5.5,range:1},
	xiahoudun:{hp:5900,skill:100.0,cooldown:5.2,range:1}, xiahouyuan:{hp:2740,skill:100.0,cooldown:5.2,range:3},
	xiaoqiao:{hp:2760,skill:100.0,cooldown:6.2,range:3}, xuchu:{hp:5040,skill:100.0,cooldown:6.4,range:1},
	xuhuang:{hp:5040,skill:100.0,cooldown:5.6,range:1}, xunyu:{hp:2880,skill:100.0,cooldown:6.4,range:3},
	xusheng:{hp:3960,skill:100.0,cooldown:5.8,range:1}, yanliang:{hp:4200,skill:100.0,cooldown:5.5,range:1},
	yuejin:{hp:2660,skill:100.0,cooldown:6.0,range:3}, yuji:{hp:2580,skill:100.0,cooldown:5.5,range:3},
	yujin:{hp:4970,skill:100.0,cooldown:4.8,range:1}, zhangbao:{hp:1560,skill:100.0,cooldown:0.0,range:1},
	zhangfei:{hp:4680,skill:44.0,cooldown:6.5,range:2}, zhanghe:{hp:4540,skill:100.0,cooldown:5.2,range:1},
	zhangjiao:{hp:2760,skill:100.0,cooldown:6.0,range:3}, zhangliang:{hp:2520,skill:100.0,cooldown:6.0,range:3},
	zhangliao:{hp:4180,skill:100.0,cooldown:6.8,range:2}, zhaoyun:{hp:3200,skill:59.0,cooldown:6.0,range:2},
	zhouyu:{hp:2700,skill:100.0,cooldown:5.8,range:3}, zhugeliang:{hp:2880,skill:27.0,cooldown:6.0,range:3},
	zhurong:{hp:3580,skill:100.0,cooldown:5.1,range:3}, zuoci:{hp:2400,skill:100.0,cooldown:5.5,range:3}
};

// ── PARAM_OVERRIDES from registered_hero_balance.gd ──
const paramOverrides = {
	lvbu:{mult:2.2,dongzhuo_heal:0.2,missing_hp_step:0.1,diaochan_bonus_per_step:0.03,chengong_repeat_chance:0.3},
	dongzhuo:{current_hp_ratio:0.2,lvbu_current_hp_ratio:0.3,diaochan_max_hp_bonus:0.4},
	diaochan:{duration:4.0,dongzhuo_duration_bonus:2.0,dongzhuo_self_heal_mult:2.0,forced_attack_interval:1.0,forced_attack_mult:1.0},
	chengong:{cooldown_reduction:1.0,lvbu_bonus_reduction:0.7,gaoshun_bonus_reduction:0.7},
	gaoshun:{target_count:2,mult:2.2,vulnerable:0.4,vulnerable_time:3.5,lvbu_bonus_targets:1,chengong_bonus_duration:3.5},
	yanliang:{target_count:2,wenchou_bonus_targets:1,mult:2.0,wenchou_damage_penalty_mult:0.3,four_pillars_bonus_targets:1,four_pillars_damage_bonus_mult:1.2},
	wenchou:{target_count:2,yanliang_bonus_targets:1,mult:3.0,yanliang_damage_penalty_mult:0.5,four_pillars_bonus_targets:1,four_pillars_damage_bonus_mult:1.5},
	gaolan:{skill_bonus_ratio:0.2,zhanghe_skill_bonus_ratio:0.25,four_pillars_skill_bonus_ratio:0.25},
	qunzhanghe:{target_count:2,shield_mult:2.0,gaolan_shield_bonus_mult:0.6,four_pillars_bonus_targets:1,four_pillars_shield_bonus_mult:1.0},
	huatuo:{target_count:3,heal_mult:1.1,yuji_bonus_mult:0.7,zuoci_bonus_mult:0.3},
	yuji:{target_count:2,poison_stack_mult:1.4,huatuo_bonus_targets:1,zuoci_stack_bonus_mult:0.4},
	zuoci:{target_count:2,heal_mult:1.7,huatuo_bonus_mult:0.5,thunder_mult:1.0},
	zhangjiao:{target_count:2,mult:3.0,zhangliang_bonus_mult:1.2,zhangbao_bonus_targets:1,zhangbao_stun_chance:0.3,zhangbao_stun:1.5},
	zhangliang:{target_count:2,duration:4.0,skill_reduction:0.5,zhangjiao_bonus_targets:1,zhangbao_duration_bonus:2.5},
	zhangbao:{target_count:2,death_mult:9.0,base_revives:1,revive_hp_ratio:0.5,zhangjiao_splash_mult:0.9,zhangliang_bonus_revives:1},
	caocao:{bond_bonus_targets:1.0,favored_damage_bonus_mult:1.0,favored_stun_bonus:0.5,mult:1.5,stun:1.25,target_count:2.0},
	caoren:{bond_bonus_targets:1,bond_reduction_skill_ratio:0.1,bond_stun_bonus:0.5,guard_time:5.0,mult:2.0,rear_reduction_skill_ratio:0.2,stun:1.0,target_count:2},
	dailaidongzhu:{mult:4.9,column_mult:3.2,burning_bonus_mult:0.5,bond_burn:4.0,bond_burn_ratio:0.5,target_mode:"highest_action"},
	daqiao:{bond_heal_bonus_per_step:0.04,bond_missing_hp_step:0.1,heal_mult:3.8,xiaoqiao_extra_heal_mult:1.5},
	dingfeng:{mult:4.0,action_reduction:25.0,bond_damage_bonus_mult:1.0,bond_action_reduction:70.0},
	dianwei:{caocao_bonus_targets:1.0,caocao_damage_penalty_mult:0.3,mult:2.4,target_count:2.0,xuchu_damage_bonus_mult:0.8},
	ganning:{lvmeng_low_hp_bonus_mult:1.8,mult:3.0,taishici_cooldown_reduction:1.2},
	guojia:{freeze:3.0,jiaxu_cooldown_reduction:1.6,shatter_mult:1.5,simayi_bonus_targets:1,simayi_duration_penalty:0.5,target_count:2,xunyu_duration_bonus:1.2},
	huangzhong:{active_mult:2.0,focus:true,mult:1.45,target_mode:"back_low"},
	jiaxu:{duration:4.0,guojia_duration_bonus:1.0,guojia_poison_bonus_skill_ratio:0.005,poison_skill_ratio:0.02,simayi_bonus_targets:1,simayi_duration_penalty:1.0,target_count:2,xunyu_cooldown_reduction:1.6},
	liubei:{duration:6.0,heal_ratio:2.0},
	liushan:{damage_by_star:[0.25,0.35,0.55],duration:4.0,seven_lifesteal:0.3},
	huanggai:{max_hp_cost:0.1,mult:2.0,damage_cost_ratio:0.4,zhouyu_burn:5.0,zhouyu_burn_ratio:0.5,sunjian_max_hp_cost:0.15,sunjian_damage_cost_ratio:0.5},
	lusu:{four_heroes_heal_mult:4.0,four_heroes_max_hp_flat:500.0,four_heroes_target_count:2.0,heal_mult:3.2,max_hp_flat:200.0,target_count:1.0},
	luxun:{bounces:1.0,four_heroes_bonus_bounces:2.0,four_heroes_burn:3.0,four_heroes_burn_ratio:0.3,mult:2.9,sunquan_burning_bonus_mult:0.4,sunquan_damage_bonus_mult:0.8},
	lvmeng:{fear:5.0,fear_max_hp_ratio:0.04,ganning_bonus_mult:1.5,mult:5.0},
	machao:{back_mult:1.4,front_mult:2.0,middle_mult:1.7},
	madai:{empty_ruler_damage_by_star:[1000.0],max_hp_ratios:[0.4],vulnerable:0.4,vulnerable_time:15.0},
	menghuo:{mult:1.05,stun:0.8},
	pangtong:{bond_mult:1.25,bond_stun:2.5,mult:1.0,stun:2.0},
	simayi:{guojia_bonus_targets:1,guojia_damage_penalty_mult:0.4,jiaxu_damage_bonus_mult:0.8,mult:3.2,target_count:2,xunyu_bonus_targets:1,xunyu_damage_penalty_mult:0.4},
	sunjian:{max_hp_cost:0.4,damage_cost_ratio:1.0,sun_legacy_self_cost:1.0,death_wu_damage_bonus:0.12},
	sunce:{mult:1.6,missing_hp_step:0.1,missing_hp_damage_bonus_per_step:0.04,taishici_bonus_mult:0.5,missing_hp_reduction_per_step:0.03},
	sunquan:{current_hp_damage_ratio:0.08,luxun_damage_ratio:0.11,max_hp_cap_mult:2.0,max_hp_gain:200.0,missing_hp_heal_ratio:0.15,sun_legacy_max_hp_cap_mult:3.0,sun_legacy_max_hp_gain:400.0,sun_legacy_missing_hp_heal_ratio:0.20},
	sunshangxiang:{target_count:1.0,mult:5.0,skill_gain_per_cast:1.0,sun_legacy_bonus_targets:1.0},
	taishici:{burn:5.0,burn_ratio:0.20,ganning_damage_bonus_mult:0.60,mult:2.0,sunce_bonus_targets:1.0,sunce_damage_penalty_mult:0.30,target_count:2.0},
	weiyan:{ally_heal:0.15,mult:1.8,self_heal:0.4},
	xiahoudun:{bond_bonus_targets:1,bond_reduction_skill_ratio:0.1,bond_stun_bonus:0.5,front_reduction_skill_ratio:0.2,guard_time:5.0,mult:2.4,stun:1.5,target_count:2},
	xiahouyuan:{bond_cooldown_reduction:0.5,bond_stun_bonus:0.5,mult:2.2,stun:1.0,target_count:2},
	xiaoqiao:{daqiao_slow_bonus_skill_ratio:0.12,slow_skill_ratio:0.35,slow_time:6.0,target_count:2.0,zhouyu_bonus_targets:1.0},
	xusheng:{mult:1.0,slow_skill_ratio:0.30,slow_time:4.0,bond_slow_time_bonus:3.0},
	xuchu:{caocao_bonus_targets:1.0,caocao_damage_penalty_mult:0.4,dianwei_damage_bonus_mult:1.0,mult:3.2,target_count:2.0},
	xuhuang:{five_stun_bonus:2.0,mult:0.8,stun:1.5,zhanghe_damage_bonus_mult:0.8},
	yuejin:{five_bonus_targets:1.0,five_damage_bonus_mult:0.5,five_grievous_skill_ratio:0.5,five_grievous_time:5.0,mult:2.0,target_count:3.0,zhangliao_bonus_targets:1.0},
	zhangfei:{damage_by_star:[0.15,0.2,0.3],duration:3.0},
	zhanghe:{five_chain_targets:2.0,five_damage_bonus_mult:2.0,five_stunned_damage_bonus_mult:4.0,mult:4.0,stun:1.5,xuhuang_stun_bonus:1.0},
	zhangliao:{five_damage_bonus_mult:0.8,five_vulnerable_skill_ratio:0.4,five_vulnerable_time:5.0,hit_count:2.0,mult:1.1,yuejin_damage_bonus_mult:0.4},
	yujin:{five_bonus_targets:1.0,five_shield_bonus_mult:1.0,shield_mult:3.0,target_count:1.0},
	xunyu:{action_bonus_skill_ratio:0.4,duration:4.4,guojia_action_bonus_skill_ratio:0.12,jiaxu_cooldown_reduction:1.6,simayi_action_penalty_skill_ratio:0.05,simayi_bonus_targets:1,target_count:2},
	zhaoyun:{five_tiger_mults:[0.5,0.7,0.9,1.1,1.3],hit_mults:[0.5,0.5,0.5,0.5,0.5],seven_base_mults:[0.5,0.5,0.5,0.5,0.5,0.5,0.5],seven_charge_mults:[0.5,0.7,0.9,1.1,1.3,1.5,1.7]},
	zhouyu:{burn:4.0,burn_ratio:0.30,four_heroes_bonus_tiles:2.0,four_heroes_burn_bonus_mult:0.50,xiaoqiao_burn_duration_bonus:3.0,xiaoqiao_burn_bonus_mult:0.30,missing_hp_bonus_per_step:0.03,missing_hp_step:0.1,mult:2.0,tile_count:2.0},
	zhugeliang:{fire_mark_bonus:0.3,liubei_extra_target_bonus:0.1,menghuo_damage_bonus:0.2,mult:2.0},
	zhurong:{mult:3.0,burn:3.0,burn_ratio:0.7,bounce_mult:0.5,sibling_burn_bonus:2.0,sibling_burn_ratio:1.0}
};

// ── Registration ability + detail_zh (for heroes NOT in _skill_detail match) ──
const regAbility = {
	// 12 signature → "signature" via _configure_signature_skill_params
	liubei:"signature",guanyu:"signature",zhangfei:"signature",caocao:"signature",dianwei:"signature",xuchu:"signature",
	zhouyu:"signature",luxun:"signature",lusu:"signature",lvbu:"signature",diaochan:"signature",dongzhuo:"signature",
	// extended registration values
	zhaoyun:"strike",huangzhong:"strike",machao:"row",liushan:"buff_column",zhugeliang:"row_magic",
	jiangwei:"strike_magic",pangtong:"control",menghuo:"row",zhurong:"signature",dailaidongzhu:"signature",
	weiyan:"drain",madai:"strike",
	zhangliao:"signature",yuejin:"signature",zhanghe:"signature",xuhuang:"signature",yujin:"signature",
	xiahouyuan:"signature",caoren:"signature",xiahoudun:"signature",simayi:"signature",guojia:"signature",xunyu:"signature",jiaxu:"signature",
	sunjian:"signature",sunce:"drain",sunquan:"signature",sunshangxiang:"signature",daqiao:"heal",xiaoqiao:"signature",
	taishici:"signature",ganning:"signature",huanggai:"signature",dingfeng:"signature",xusheng:"row_magic",
	gaoshun:"signature",chengong:"passive",yanliang:"signature",wenchou:"signature",qunzhanghe:"signature",
	gaolan:"passive",huatuo:"signature",yuji:"signature",zhangjiao:"signature",zhangliang:"signature",zhangbao:"passive",zuoci:"signature"
};
// detail_zh from registration (used by _skill_detail_legacy for heroes not in _skill_detail match)
const regDetailZh = {
	dingfeng:"攻击射程内行动条最高的敌人，造成130%技能强度物理伤害并压退25%行动条。",
	// xusheng is overridden by _set_skill in _apply_document_skill_rework:
	xusheng:"宿卫水阵：冲击一排并留下4秒水阵，使该排行动速度降低20%。"
};

// ── _skill_detail hardcoded text (zh only) ──
const skillDetail = {
	liubei:"仁德回春：为当前生命比例最低的友军施加持续4秒、每秒200%技能强度的治疗；溢出治疗转为主公回血。",
	guanyu:"青龙偃月：劈砍目标整列，每名敌人受到180%技能强度伤害。",
	zhangfei:"燕人号令：强化己方前军，增伤15%，持续3秒。",
	zhaoyun:"龙胆连刺：随机选择一名射程内敌人，快速攻击同一目标5次，每次造成50%技能强度伤害。",
	liushan:"蜀主鼓舞：强化同列前军4秒，使其伤害提高25%。",
	huangzhong:"百步穿杨：射击随机可攻击格，造成200%技能强度伤害。",
	machao:"铁骑贯阵：锁定当前血量最低敌人所在列，前军/中军/后军依次受到200%/170%/140%技能强度贯穿伤害。",
	madai:"斩将突袭：随机攻击敌方前军，造成40%最大生命伤害；无前军时攻击空格，对主公造成1000点伤害。",
	weiyan:"狂骨横斩：攻击正前方及其同排相邻格，造成180%技能强度伤害，并回复实际伤害40%的生命。",
	zhugeliang:"八阵奇谋：随机选择敌方格子，对目标及同列相邻格造成200%技能强度法术伤害。",
	jiangwei:"北伐：对随机可攻击目标造成160%技能强度法术伤害，并获得15%减伤5秒。",
	pangtong:"连环计：造成80%技能强度法术伤害并锁住目标行动条2秒。",
	menghuo:"蛮王震地：对可攻击的一整排造成105%技能强度物理伤害并眩晕0.8秒。",
	zhurong:"火神飞刃：对随机敌方单位造成300%兵略值法术伤害并灼烧3秒，每秒70%兵略值伤害。",
	dailaidongzhu:"蛮骨狼袭：锁定行动条最高的可攻击敌人，造成490%兵略值物理伤害。",
	caocao:"魏武震慑：随机攻击两名敌军，造成150%兵略值伤害并眩晕1.25秒。",
	dianwei:"恶来袭后：随机攻击两名敌方后军，各造成240%兵略值伤害。",
	xuchu:"虎卫破前：随机攻击两名敌方前军，各造成320%兵略值伤害。",
	zhangliao:"威震回刃：攻击随机敌方一列，回旋刃飞出与返回各造成110%兵略值伤害。",
	yuejin:"先登乱射：随机攻击三名敌军，各造成200%兵略值伤害。",
	xuhuang:"撼地开山：攻击敌方前军整排，造成80%兵略值伤害并眩晕1.5秒。",
	zhanghe:"巧变连枪：随机攻击一名敌方前军，造成400%兵略值伤害并眩晕1.5秒。",
	yujin:"毅重护阵：为当前生命值最低的友军施加300%兵略值的护盾。",
	xiahouyuan:"神速震袭：随机攻击2名敌军，造成220%兵略值伤害并眩晕1秒。",
	caoren:"樊城镇远：随机攻击2名敌方后军，造成200%兵略值伤害并眩晕1秒；释放后5秒内受到敌方后军的伤害减少0.2×兵略值%。",
	xiahoudun:"刚烈镇前：随机攻击2名敌方前军，造成240%兵略值伤害并眩晕1.5秒；释放后5秒内受到敌方前军的伤害减少0.2×兵略值%。",
	simayi:"雷霆谋断：对随机2名敌人释放雷击，造成320%兵略值伤害。",
	guojia:"遗计冰封：随机冻结2名敌人3秒，期间行动条停止；冻结期间受到伤害会提前解冻，并受到郭嘉150%兵略值伤害。",
	xunyu:"王佐疾策：随机使2名友军行动条速度提高0.4×兵略值%，持续4.4秒。",
	jiaxu:"毒士奇谋：使随机2名敌军中毒4秒，每秒损失0.02×兵略值%最大生命值。",
	sunjian:"猛虎绝命：消耗40%最大生命，攻击正前方敌军并造成等同于实际消耗生命100%的伤害。",
	sunce:"小霸王连击：攻击正前方及其左侧敌军，各造成160%兵略值伤害；自身每损失10%生命，伤害提高4%。",
	sunquan:"江东制衡：自身最大生命提高200（最多为初始最大生命2倍），随后恢复15%已损失生命，再随机对一名敌军造成孙权当前生命8%的伤害。",
	sunshangxiang:"枭姬叠势：随机攻击一名敌军，造成500%兵略值伤害，每次释放后兵略值提高1点。",
	zhouyu:"赤壁点火：随机选择2个敌方格，各造成200%兵略值法术伤害并灼烧4秒，每秒造成30%兵略值伤害。",
	luxun:"火烧连营：发射火球造成290%兵略值法术伤害，并向相邻敌方单元格弹射1次造成同等伤害。",
	lvmeng:"白衣渡江：攻击敌方后军随机单元格，造成500%兵略值伤害。",
	lusu:"连横稳阵：为当前生命值最低的友军恢复320%兵略值生命，并使其最大生命提高200。",
	daqiao:"国色流离：治疗生命最低的友军380%兵略值生命。",
	xiaoqiao:"天香缓阵：随机选择两名敌方后军，使其减速6秒，期间行动条速度降低0.35×兵略值%。",
	taishici:"神亭烈戟：攻击射程内行动条最高的两名敌人，造成200%兵略值伤害，并灼烧5秒，每秒造成20%兵略值伤害。",
	ganning:"锦帆并击：自身与同排左侧友军分别攻击一名随机敌方后军，各造成300%自身兵略值的伤害；友军协击不消耗行动条。",
	huanggai:"苦肉焚阵：消耗10%最大生命，对随机敌方一列造成200%兵略值加实际消耗生命40%的伤害；生命不足时消耗全部生命并在攻击后阵亡。",
	dingfeng:"雪中奋短兵：攻击射程内行动条最高的敌人，造成400%兵略值伤害并压退25%行动条。",
	xusheng:"宿卫水阵：冲击敌方前军整排，造成100%兵略值伤害，并留下4秒水阵，使该排行动速度降低0.3×兵略值%。",
	lvbu:"无双横扫：对正前方敌方前军及其左右相邻格造成220%兵略值伤害。",
	diaochan:"美人离间：随机魅惑一名敌军4秒，使其行动条停止。",
	dongzhuo:"暴君横征：对正前方敌军造成自身当前生命值20%的伤害。",
	chengong:"智迟谋速（被动）：陈宫及其同列友军的技能冷却减少1秒。",
	gaoshun:"陷阵之志：随机攻击两名敌军，造成220%兵略值伤害并施加3.5秒易碎，易碎目标受到伤害提高0.4×兵略值%。",
	yanliang:"河北猛袭：随机攻击两名敌方中军或后军，造成200%兵略值伤害。",
	wenchou:"河北破阵：随机攻击两名敌方前军或中军，造成300%兵略值伤害。",
	gaolan:"列阵扬威（被动）：高览同列友军的兵略值增加0.2×兵略值。",
	qunzhanghe:"河北护阵：为当前生命值最低的两名友军施加可抵消200%兵略值伤害的护盾。",
	huatuo:"青囊三济：治疗当前生命值最低的三名友军，各恢复110%兵略值生命。",
	yuji:"蛊毒仙术：对随机两名敌军施加1.4×兵略值的中毒层数，每秒受到层数等量伤害，随后层数向下取整减半，降至0时清除。",
	zuoci:"遁甲济世：治疗当前生命值最低的两名友军，各恢复170%兵略值生命。",
	zhangjiao:"黄天雷引：召唤雷电随机攻击两名敌军，各造成300%兵略值伤害。",
	zhangliang:"人公虚弱：随机使两名敌军虚弱4秒，兵略值降低0.5×兵略值。",
	zhangbao:"地公雷爆（被动）：阵亡时随机攻击两名敌军，各造成900%兵略值伤害，随后以50%最大生命值复生一次。"
};

// ── Bond data (from _hero_bond_detail) ──
const peachGarden = ["liubei","guanyu","zhangfei"];
const peachEffects = {
	liubei:"持续治疗由每秒200%技能强度提高为300%技能强度。",
	guanyu:"按整列斩实际造成伤害的30%恢复自身生命。",
	zhangfei:"前排增伤期间额外获得20%减伤。"
};
const fiveTigers = ["guanyu","zhangfei","zhaoyun","huangzhong","machao"];
const fiveTigerEffects = {
	guanyu:"整列斩伤害倍率由180%提高为300%技能强度。",
	zhangfei:"前军号令由3秒延长至6秒。",
	zhaoyun:"五次连刺伤害依次提高为50%/70%/90%/110%/130%技能强度。",
	huangzhong:"大招固定选择敌方前军格并提高至500%技能强度。",
	machao:"马超带来全军增益：我方所有前军与中军行动条速度提高15%。"
};
const personalBonds = {
	liubei:[["夜梦北斗",["liubei","liushan"],"持续治疗由4秒延长50%至6秒。"],["卧龙辅汉",["liubei","zhugeliang"],"持续治疗中的目标受到的法术伤害降低20%。"]],
	liushan:[["夜梦北斗",["liubei","liushan"],"蜀主鼓舞额外作用于同列后排友军。"],["七进七出",["zhaoyun","liushan"],"蜀主鼓舞额外使被强化友军获得30%全能吸血：其造成伤害的30%用于恢复自身生命，持续4秒。"]],
	zhaoyun:[["七进七出",["zhaoyun","liushan"],"连刺变为7次，每次造成50%技能强度伤害，并无视射程强制攻击敌方后军；若同时激活五虎上将，七次伤害才递增至170%。"]],
	machao:[["一骑当千",["machao","madai"],"铁骑贯阵不再递减，前军、中军、后军均受到200%技能强度伤害。"]],
	madai:[["一骑当千",["machao","madai"],"每场战斗开局行动条充满，可立即释放技能。"],["宿命之敌",["madai","weiyan"],"技能命中的武将被标记，额外承受40%伤害，持续15秒。"]],
	huangzhong:[["飞火流星",["huangzhong","weiyan"],"自身箭击有50%概率暴击，暴击伤害变为原来的2倍。"]],
	weiyan:[["飞火流星",["huangzhong","weiyan"],"敌方任一前军阵亡时，魏延恢复50%最大生命。"],["宿命之敌",["madai","weiyan"],"释放技能后，为同排相邻友军及正后方的中军友军恢复15%最大生命。"]],
	jiangwei:[["北伐传承",["zhugeliang","jiangwei"],"北伐追加攻击主目标斜对角最多两名敌人，各造成80%技能强度伤害；释放后的自身减伤由15%提高至30%，持续5秒。"]],
	pangtong:[["卧龙凤雏",["zhugeliang","pangtong"],"连环计由单体扩展为中心及左右相邻三格；每格伤害由80%提高至100%技能强度，行动条锁定由2秒提高至2.5秒。该效果按两条普通羁绊的强度设计。"]],
	menghuo:[["七擒孟获",["zhugeliang","menghuo"],"蛮王震地结束后追加一次60%技能强度的整排余震，余震不重复眩晕。"],["南蛮夫妇",["menghuo","zhurong"],"蛮王震地对灼烧目标伤害提高40%，并将这些目标的眩晕时间由0.8秒延长至1.2秒。"],["蛮王援军",["menghuo","dailaidongzhu"],"蛮王震地额外使每名命中武将损失20%行动条。"]],
	zhurong:[["南蛮夫妇",["menghuo","zhurong"],"火神飞刃向主目标左右同排相邻格各弹射一次，造成50%兵略值伤害并施加完整灼烧。"],["姐弟同心",["dailaidongzhu","zhurong"],"火神飞刃的灼烧时长增加2秒，灼烧伤害提高至每秒100%兵略值。"]],
	dailaidongzhu:[["蛮王援军",["menghuo","dailaidongzhu"],"蛮骨狼袭改为攻击行动条最高目标所在整列，每格造成320%兵略值伤害。"],["姐弟同心",["dailaidongzhu","zhurong"],"蛮骨狼袭施加4秒、每秒50%兵略值的灼烧；若目标原本已灼烧，直接伤害额外增加50%兵略值。"]],
	zhugeliang:[["卧龙凤雏",["zhugeliang","pangtong"],"八阵奇谋额外影响中心格左右两个同排相邻格。"],["北伐传承",["zhugeliang","jiangwei"],"八阵奇谋额外影响中心格四个斜对角相邻格。"],["七擒孟获",["zhugeliang","menghuo"],"八阵奇谋伤害提高20%并施加火攻标记；诸葛亮再次命中标记者时伤害再提高30%。"],["卧龙辅汉",["liubei","zhugeliang"],"本次技能每多命中一名武将，所有受击格伤害提高10%；命中9人时提高80%。"]]
};
const comboDefs = [
	[["caocao","dianwei"],"古之恶来",{caocao:"技能目标数增加1；命中后军时伤害增加100%兵略值，眩晕时长增加0.5秒。",dianwei:"攻击目标增加1，造成伤害减少30%兵略值。"}],
	[["caocao","xuchu"],"虎卫护主",{caocao:"技能目标数增加1；命中前军时伤害增加100%兵略值，眩晕时长增加0.5秒。",xuchu:"攻击目标增加1，造成伤害减少40%兵略值。"}],
	[["dianwei","xuchu"],"魏武双卫",{dianwei:"造成伤害增加80%兵略值。",xuchu:"造成伤害增加100%兵略值。"}],
	[["zhangliao","yuejin"],"逍遥津先锋",{zhangliao:"回旋刃的每段伤害增加40%兵略值。",yuejin:"攻击目标增加1名。"}],
	[["zhanghe","xuhuang"],"巧变开山",{zhanghe:"眩晕时长增加1秒。",xuhuang:"伤害增加80%兵略值。"}],
	[["zhouyu","luxun","lusu","lvmeng"],"四英杰",{zhouyu:"赤壁点火额外选择2个格子，灼烧伤害增加50%兵略值。",luxun:"火球总弹射次数增加2次，并施加3秒、每秒30%兵略值的灼烧。",lusu:"治疗最低当前生命的2名友军，各恢复400%兵略值并提高500最大生命。",lvmeng:"命中的后军恐惧5秒，行动条停止且每秒受到4%最大生命伤害。"}],
	[["lvbu","dongzhuo"],"暴虐无双",{lvbu:"按无双横扫对武将造成的实际伤害20%恢复自身生命；护盾和空格伤害不计入。",dongzhuo:"暴君横征伤害提高至自身当前生命值30%。"}],
	[["lvbu","diaochan"],"英雄美人",{lvbu:"每损失10%生命，无双横扫伤害提高3%。",diaochan:"魅惑期间，目标每秒随机攻击一名相邻友军，造成被魅惑者100%兵略值伤害。"}],
	[["lvbu","chengong"],"谋定无双",{lvbu:"无双横扫有30%概率连续释放两次。",chengong:"智迟谋速的冷却减少额外增加0.7秒。"}],
	[["lvbu","gaoshun"],"飞将陷阵",{lvbu:"无双横扫追加攻击正前方敌军对应的中军。",gaoshun:"陷阵之志的目标额外增加1名。"}],
	[["dongzhuo","diaochan"],"暴君倾城",{dongzhuo:"自身最大生命值提高40%。",diaochan:"魅惑持续时间增加2秒，且貂蝉为自己恢复200%兵略值生命。"}],
	[["chengong","gaoshun"],"谋陷并驱",{chengong:"智迟谋速的冷却减少额外增加0.7秒。",gaoshun:"陷阵之志的易碎持续时间增加3.5秒。"}],
	[["yanliang","wenchou"],"河北双雄",{yanliang:"技能目标增加1名，伤害减少30%兵略值。",wenchou:"技能目标增加1名，伤害减少50%兵略值。"}],
	[["gaolan","qunzhanghe"],"河北同袍",{gaolan:"同列友军的兵略值加成提高至0.25×兵略值。",qunzhanghe:"护盾值增加60%兵略值。"}],
	[["zhangliao","yuejin","zhanghe","xuhuang","yujin"],"五子良将",{zhangliao:"回旋刃每段伤害增加80%兵略值；命中者受到的伤害增加0.4×兵略值%，持续5秒。",yuejin:"目标增加1名，伤害增加50%兵略值，并施加5秒重伤，使治疗和自身回复降低0.5×兵略值%。",zhanghe:"攻击扩散至主目标周围相连的两名随机敌军；伤害增加200%兵略值，目标攻击前已眩晕时额外增加400%兵略值。",xuhuang:"改为攻击随机一整排，眩晕时长增加2秒。",yujin:"施法目标增加1名，护盾值增加100%兵略值。"}],
	[["xiahouyuan","caoren"],"神速镇远",{xiahouyuan:"冷却缩短0.5秒，眩晕延长0.5秒。",caoren:"目标增加1名，眩晕延长0.5秒，后军伤害减免提高0.1×兵略值%。"}],
	[["xiahouyuan","xiahoudun"],"夏侯同心",{xiahouyuan:"冷却缩短0.5秒，眩晕延长0.5秒。",xiahoudun:"目标增加1名，眩晕延长0.5秒，前军伤害减免提高0.1×兵略值%。"}],
	[["caoren","xiahoudun"],"魏武双壁",{caoren:"目标增加1名，眩晕延长0.5秒，后军伤害减免提高0.1×兵略值%。",xiahoudun:"目标增加1名，眩晕延长0.5秒，前军伤害减免提高0.1×兵略值%。"}],
	[["simayi","guojia"],"雷霆冰策",{simayi:"雷击目标增加1名，伤害减少40%兵略值。",guojia:"冻结目标增加1名，冻结时间减少0.5秒。"}],
	[["simayi","xunyu"],"鹰视王佐",{simayi:"雷击目标增加1名，伤害减少40%兵略值。",xunyu:"施法目标增加1名，行动条速度加成减少0.05×兵略值%。"}],
	[["simayi","jiaxu"],"鹰视毒谋",{simayi:"伤害增加80%兵略值。",jiaxu:"施法目标增加1名，中毒持续时间减少1秒。"}],
	[["guojia","xunyu"],"遗计王佐",{guojia:"冻结时间增加1.2秒。",xunyu:"行动条速度加成增加0.12×兵略值%。"}],
	[["guojia","jiaxu"],"冰毒奇策",{guojia:"技能冷却减少1.6秒。",jiaxu:"中毒持续时间增加1秒，每秒伤害增加0.005×兵略值%最大生命。"}],
	[["xunyu","jiaxu"],"王佐毒策",{xunyu:"技能冷却减少1.6秒。",jiaxu:"技能冷却减少1.6秒。"}],
	[["sunjian","sunce","sunquan","sunshangxiang"],"孙氏之志",{sunjian:"改为消耗全部生命；阵亡后存活吴将本回合伤害提高12%，不可叠加。",sunce:"追加第二段攻击正前方和右侧敌军，正前方承受两次攻击。",sunquan:"最大生命提高400，上限为初始最大生命3倍；随后恢复20%已损失生命。",sunshangxiang:"施法目标增加1名。"}],
	[["daqiao","xiaoqiao"],"江东双姝",{daqiao:"追加1次150%兵略值的治疗。",xiaoqiao:"行动条减速增加0.12×兵略值%。"}],
	[["lvmeng","ganning"],"白衣奇袭",{lvmeng:"伤害增加150%兵略值，且无视目标护盾。",ganning:"攻击生命值低于50%的敌人时，伤害增加180%兵略值。"}],
	[["sunce","taishici"],"神亭酣战",{sunce:"造成的伤害增加50%兵略值。",taishici:"目标增加1名，直接伤害减少30%兵略值。"}],
	[["sunce","daqiao"],"江东佳偶",{sunce:"自身每损失10%生命，受到伤害减少3%。",daqiao:"受治疗友军每损失10%生命，本次治疗提高4%。"}],
	[["zhouyu","xiaoqiao"],"琴瑟和鸣",{zhouyu:"灼烧持续时间增加3秒，灼烧伤害增加30%兵略值。",xiaoqiao:"施法目标增加1名。"}],
	[["zhouyu","huanggai"],"赤壁苦计",{zhouyu:"灼烧伤害随目标已损生命提高，每损失10%生命，整体灼烧伤害提高3%。",huanggai:"命中格灼烧5秒，每秒造成50%兵略值伤害；空格灼烧会伤害主公。"}],
	[["huanggai","sunjian"],"江东柱石",{huanggai:"最大生命消耗提高至15%，伤害中的实际消耗生命系数提高至50%。",sunjian:"开局行动条充满。"}],
	[["taishici","ganning"],"江表双锋",{taishici:"造成的伤害增加60%兵略值。",ganning:"技能冷却减少1.2秒。"}],
	[["luxun","sunquan"],"君臣同心",{luxun:"直接伤害增加80%兵略值，对已灼烧目标额外增加40%兵略值。",sunquan:"伤害改为孙权当前生命值的11%。"}],
	[["dingfeng","xusheng"],"江表虎臣",{dingfeng:"伤害增加100%兵略值，压退改为70%行动条。",xusheng:"改为冲击随机一排，水阵持续时间增加3秒。"}],
	[["yanliang","wenchou","qunzhanghe","gaolan"],"河北四庭柱",{yanliang:"技能目标增加1名，伤害增加120%兵略值。",wenchou:"技能目标增加1名，伤害增加150%兵略值。",qunzhanghe:"技能目标增加1名，护盾增加100%兵略值。",gaolan:"光环改为同排和同列全部友军兵略值增加0.25×兵略值。"}],
	[["huatuo","yuji"],"医道同源",{huatuo:"青囊三济治疗增加70%兵略值。",yuji:"蛊毒仙术增加1个目标。"}],
	[["huatuo","zuoci"],"济世仙缘",{huatuo:"青囊三济增加30%兵略值，且清除目标全部减益。",zuoci:"遁甲济世的治疗倍率增加50%兵略值。"}],
	[["yuji","zuoci"],"方仙同门",{yuji:"施加的中毒层数增加0.4×兵略值。",zuoci:"治疗时同时随机雷击两名敌军，各造成100%兵略值伤害。"}],
	[["zhangjiao","zhangliang"],"天人同道",{zhangjiao:"黄天雷引的伤害增加120%兵略值。",zhangliang:"人公虚弱增加1个目标。"}],
	[["zhangjiao","zhangbao"],"天地雷契",{zhangjiao:"黄天雷引增加1个目标，每名受击者有30%概率眩晕1.5秒。",zhangbao:"地公雷爆波及主目标周围八格武将，造成90%兵略值伤害。"}],
	[["zhangliang","zhangbao"],"地人续命",{zhangliang:"人公虚弱持续时间增加2.5秒。",zhangbao:"可以额外复生1次。"}]
];

// ── Computation helpers (mirroring GDScript logic) ──
function round(x) { return Math.round(x); }
// 生命值 ÷2 后四舍五入到最近的 10 的倍数
function displayHp(hp) { return Math.round(hp / 2 / 10) * 10; }
function getParams(id) {
	return paramOverrides[id] ? {...paramOverrides[id]} : {};
}
function getDetail(id) {
	if (skillDetail[id]) return skillDetail[id];
	// legacy fallback: strip bond clauses from detail_zh
	let text = regDetailZh[id] || "";
	return text;
}
function getArmyName(range) {
	return [, "前军", "中军", "后军"][range] || "前军";
}

// Simulates _star_skill_values(hero_id, 1)
function starSkillValues(id) {
	const bs = baseStats[id];
	const skillOutputBase = bs.skill;
	const effectMult = 1.0; // skill_value normalized to 100
	const skillBase = skillOutputBase * effectMult;
	const params = getParams(id);
	const ability = regAbility[id];
	const statMult = 1.0;
	const hp = displayHp(bs.hp);
	const v = [];

	function fmt(s) { return s.replace(/%%/g, "%"); }

	switch (id) {
		case "liubei": v.push(fmt(`每秒治疗${round(skillBase*params.heal_ratio ?? 2.0)}，持续${(params.duration ?? 4.0).toFixed(1)}秒，总计${round(skillBase*(params.heal_ratio ?? 2.0)*(params.duration ?? 4.0))}`)); break;
		case "zhangfei": { const dbs = params.damage_by_star ?? [0.15,0.2,0.3]; v.push(fmt(`前排增伤${round(dbs[0]*effectMult*100)}%，持续${(params.duration ?? 3.0).toFixed(1)}秒`)); break; }
		case "guanyu": v.push(fmt(`整列每名敌人受到${round(skillBase*(params.mult ?? 1.8))}真实伤害`)); break;
		case "zhaoyun": { const hd = round(skillBase*0.50); v.push(fmt(`基础连刺5次，每次${hd}伤害，总计${hd*5}`)); break; }
		case "liushan": { const dbs = params.damage_by_star ?? [0.25]; v.push(fmt(`同列前军增伤${round(dbs[0]*effectMult*100)}%，持续4秒`)); break; }
		case "huangzhong": v.push(fmt(`大招造成${round(skillBase*(params.active_mult ?? 2.0))}真实伤害`)); break;
		case "machao": v.push(fmt(`贯穿同列：前军${round(skillBase*(params.front_mult ?? 2.0))} / 中军${round(skillBase*(params.middle_mult ?? 1.7))} / 后军${round(skillBase*(params.back_mult ?? 1.4))}伤害`)); break;
		case "madai": { const r = params.max_hp_ratios ?? [0.4]; v.push(fmt(`随机前军受到其最大生命${round(r[0]*effectMult*100)}%伤害`)); break; }
		case "weiyan": v.push(fmt(`每个目标${round(skillBase*(params.mult ?? 1.8))}伤害；自身回复实际伤害40%`)); break;
		case "caocao": v.push(fmt(`随机2人各${round(skillBase*(params.mult ?? 1.5))}伤害；眩晕${(params.stun ?? 1.25).toFixed(2)}秒`)); break;
		case "dianwei": v.push(fmt(`随机2名后军各${round(skillBase*(params.mult ?? 2.4))}物理伤害`)); break;
		case "xuchu": v.push(fmt(`随机2名前军各${round(skillBase*(params.mult ?? 3.2))}物理伤害`)); break;
		case "zhangliao": v.push(fmt(`同列每个格子往返各${round(skillBase*(params.mult ?? 1.1))}伤害`)); break;
		case "yuejin": v.push(fmt(`随机3人各${round(skillBase*(params.mult ?? 2.0))}物理伤害`)); break;
		case "xuhuang": v.push(fmt(`前军整排每格${round(skillBase*(params.mult ?? 0.8))}伤害；眩晕${(params.stun ?? 1.5).toFixed(2)}秒`)); break;
		case "zhanghe": v.push(fmt(`前军目标${round(skillBase*(params.mult ?? 4.0))}伤害；眩晕${(params.stun ?? 1.5).toFixed(2)}秒`)); break;
		case "yujin": v.push(fmt(`最低当前生命友军获得${round(skillBase*(params.shield_mult ?? 3.0))}护盾`)); break;
		case "xiahouyuan": v.push(fmt(`随机2人各${round(skillBase*2.2)}伤害；眩晕1秒`)); break;
		case "caoren": v.push(fmt(`随机2名后军各${round(skillBase*2.0)}伤害；眩晕1秒；后军减伤${round(20.0*effectMult)}%持续5秒`)); break;
		case "xiahoudun": v.push(fmt(`随机2名前军各${round(skillBase*2.4)}伤害；眩晕1.5秒；前军减伤${round(20.0*effectMult)}%持续5秒`)); break;
		case "simayi": v.push(fmt(`随机2人各${round(skillBase*3.2)}雷击伤害`)); break;
		case "guojia": v.push(fmt(`随机冻结2人3秒；受击破冰并追加${round(skillBase*1.5)}伤害`)); break;
		case "xunyu": v.push(`随机2名友军行动条速度+40%，持续4.4秒`); break;
		case "jiaxu": v.push(`随机2人中毒4秒，每秒损失2%最大生命`); break;
		case "sunjian": v.push(`消耗40%最大生命，造成实际消耗生命100%的伤害`); break;
		case "sunce": v.push(fmt(`正前方及左侧每格${round(skillBase*(params.mult ?? 1.6))}伤害；每损失10%生命再增伤4%`)); break;
		case "sunquan": v.push(fmt(`自身最大生命+200并恢复15%已损生命，随后造成自身当前生命8%的伤害；基础封顶${round(hp*statMult*(params.max_hp_cap_mult ?? 2.0))}`)); break;
		case "sunshangxiang": v.push(fmt(`随机敌军受到${round(skillBase*(params.mult ?? 5.0))}伤害；施法后兵略值+1`)); break;
		case "taishici": v.push(fmt(`行动条最高的2名敌人各受到${round(skillBase*(params.mult ?? 2.0))}伤害，并每秒灼烧${round(skillBase*(params.burn_ratio ?? 0.20))}，持续5秒`)); break;
		case "ganning": v.push(`甘宁与左侧友军各以自身兵略值造成300%伤害`); break;
		case "huanggai": v.push(fmt(`消耗10%最大生命；整列每格受到${round(skillBase*2.0)}加消耗生命40%的伤害`)); break;
		case "zhouyu": v.push(fmt(`每格${round(skillBase*(params.mult ?? 2.0))}魔法伤害；每秒灼烧${round(skillBase*(params.burn_ratio ?? 0.30))}`)); break;
		case "luxun": v.push(fmt(`每次命中${round(skillBase*(params.mult ?? 2.9))}；基础弹射${params.bounces ?? 1}次`)); break;
		case "lvmeng": v.push(fmt(`随机后军受到${round(skillBase*(params.mult ?? 5.0))}伤害`)); break;
		case "lusu": v.push(fmt(`最低当前生命友军恢复${round(skillBase*(params.heal_mult ?? 3.2))}生命，最大生命+${round(params.max_hp_flat ?? 200)}`)); break;
		case "daqiao": v.push(fmt(`最低当前生命友军恢复${round(skillBase*(params.heal_mult ?? 3.8))}生命`)); break;
		case "xiaoqiao": v.push(fmt(`随机${params.target_count ?? 2}名后军：减速${(params.slow_skill_ratio ?? 0.35)*100}%，持续${(params.slow_time ?? 6.0).toFixed(1)}秒`)); break;
		case "dingfeng": v.push(fmt(`行动条最高敌人受到${round(skillBase*(params.mult ?? 4.0))}伤害并压退${params.action_reduction ?? 25}%行动条`)); break;
		case "xusheng": v.push(fmt(`前军整排每格${round(skillBase*(params.mult ?? 1.0))}伤害并减速${(params.slow_skill_ratio ?? 0.30)*100}%，持续${params.slow_time ?? 4}秒`)); break;
		case "lvbu": v.push(fmt(`正面三格每格约${round(skillBase*(params.mult ?? 2.2))}伤害`)); break;
		case "diaochan": v.push(fmt(`随机魅惑${(params.duration ?? 4.0).toFixed(2)}秒`)); break;
		case "dongzhuo": v.push(fmt(`正前方受到董卓当前生命${(params.current_hp_ratio ?? 0.2)*100}%伤害`)); break;
		case "chengong": v.push(fmt(`同列友军技能冷却减少${(params.cooldown_reduction ?? 1.0).toFixed(1)}秒`)); break;
		case "gaoshun": v.push(fmt(`随机${params.target_count ?? 2}人各受到${round(skillBase*(params.mult ?? 2.2))}伤害并易碎${(params.vulnerable_time ?? 3.5).toFixed(1)}秒`)); break;
		case "yanliang": v.push(fmt(`随机${params.target_count ?? 2}名中/后军各受到${round(skillBase*(params.mult ?? 2.0))}伤害`)); break;
		case "wenchou": v.push(fmt(`随机${params.target_count ?? 2}名前/中军各受到${round(skillBase*(params.mult ?? 3.0))}伤害`)); break;
		case "gaolan": v.push(fmt(`同列友军兵略值+${round(skillBase*(params.skill_bonus_ratio ?? 0.2))}`)); break;
		case "qunzhanghe": v.push(fmt(`生命最低${params.target_count ?? 2}名友军各获得${round(skillBase*(params.shield_mult ?? 2.0))}护盾`)); break;
		case "huatuo": v.push(fmt(`生命最低3名友军各恢复${round(skillBase*(params.heal_mult ?? 1.1))}生命`)); break;
		case "yuji": v.push(fmt(`随机2人获得${round(skillBase*(params.poison_stack_mult ?? 1.4))}层递减中毒`)); break;
		case "zuoci": v.push(fmt(`生命最低2名友军各恢复${round(skillBase*(params.heal_mult ?? 1.7))}生命`)); break;
		case "zhangjiao": v.push(fmt(`随机2人各受到${round(skillBase*(params.mult ?? 3.0))}雷击伤害`)); break;
		case "zhangliang": v.push(`随机2人兵略值降低50%，持续4秒`); break;
		case "zhangbao": v.push(fmt(`每次阵亡随机2人各受到${round(skillBase*(params.death_mult ?? 9.0))}伤害；以50%生命复生1次`)); break;
		default:
			if (["strike","strike_magic","drain","control","row","row_magic"].includes(ability))
				v.push(fmt(`每个命中目标约${round(skillBase*(params.mult ?? 1.0))}伤害`));
			else if (["multi","multi_magic"].includes(ability))
				v.push(fmt(`技能命中${params.count ?? 2}次，每次约${round(skillBase*(params.mult ?? 0.8))}伤害`));
			else if (ability === "heal")
				v.push(fmt(`单次治疗约${round(skillBase*(params.mult ?? 1.5)+(params.flat ?? 0)*effectMult)}`));
			else if (ability === "heal_team")
				v.push(fmt(`全体恢复${(params.ratio ?? 0.10)*effectMult*100}%最大生命`));
			else if (ability.startsWith("shield_"))
				v.push(fmt(`每个目标获得约${round(skillBase*(params.mult ?? 1.5)+(params.flat ?? 40)*effectMult)}护盾`));
			else if (ability.startsWith("buff_"))
				v.push(fmt(`增伤${(params.damage ?? 0)*effectMult*100}%；行动加速${(params.action ?? 0)*effectMult*100}%`));
			break;
	}
	// Append stun / burn suffixes
	if ((params.stun ?? 0) > 0) v.push(`控制${params.stun.toFixed(2)}秒`);
	if ((params.burn ?? 0) > 0) v.push(`灼烧${params.burn.toFixed(1)}秒`);

	return v.length > 0 ? "当前技能数值：" + v.join("；") : "当前技能数值：（无）";
}

// Simulates _hero_bond_detail(hero_id)
function heroBondDetail(id) {
	const entries = [];
	const faction = factionOf[id];
	const factionIds = Object.keys(factionOf).filter(k => factionOf[k] === faction);
	entries.push(`${factionBondName[faction]}（${factionIds.map(k=>names[k]).join("、")}）：${factionBondEffect[faction]}`);
	if (peachGarden.includes(id))
		entries.push(`桃园结义（${peachGarden.map(k=>names[k]).join("、")}）：${peachEffects[id]}`);
	if (fiveTigers.includes(id))
		entries.push(`五虎上将（${fiveTigers.map(k=>names[k]).join("、")}）：${fiveTigerEffects[id]}`);
	for (const b of (personalBonds[id] || []))
		entries.push(`${b[0]}（${b[1].map(k=>names[k]).join("、")}）：${b[2]}`);
	for (const def of comboDefs) {
		if (def[0].includes(id))
			entries.push(`${def[1]}（${def[0].map(k=>names[k]).join("、")}）：${def[2][id]}`);
	}
	return entries.join("\n\n");
}

// ── Generate markdown ──
const factionOrder = ["shu","wei","wu","qun"];
const factionTitle = {shu:"蜀国",wei:"魏国",wu:"吴国",qun:"群雄"};
const factionHeroOrder = {
	shu:["liubei","guanyu","zhangfei","zhaoyun","liushan","huangzhong","machao","madai","weiyan","zhugeliang","jiangwei","pangtong","menghuo","zhurong","dailaidongzhu"],
	wei:["caocao","dianwei","xuchu","zhangliao","yuejin","xuhuang","zhanghe","yujin","xiahouyuan","caoren","xiahoudun","simayi","guojia","xunyu","jiaxu"],
	wu:["zhouyu","luxun","lvmeng","lusu","daqiao","xiaoqiao","taishici","ganning","huanggai","sunjian","sunce","sunquan","sunshangxiang","dingfeng","xusheng"],
	qun:["lvbu","diaochan","dongzhuo","gaoshun","chengong","yanliang","wenchou","qunzhanghe","gaolan","huatuo","yuji","zhangjiao","zhangliang","zhangbao","zuoci"]
};

let md = `# 三国·羁绊战棋 · 武将图鉴\n\n`;
md += `> 自动生成，数据源：\`registered_hero_balance.gd\` + \`game_ui.gd\`（_skill_detail / _star_skill_values / _hero_bond_detail）\n`;
md += `> 数值为 1 星、无羁绊加成的裸机状态。技能强度已归一为 100，实战输出基准保留。\n`;
md += `> 技能描述为文案文本（可能与实际数值有出入，以「当前技能数值」行为准）。\n\n`;
md += `---\n\n`;

for (const fac of factionOrder) {
	md += `## ${factionTitle[fac]}（${factionName[fac]}）· 15 名武将\n\n`;
	for (const id of factionHeroOrder[fac]) {
		const bs = baseStats[id];
		md += `### ${names[id]}（${id}）\n\n`;
		md += `| 生命 | 兵种 | 冷却 |\n`;
		md += `|------|------|------|\n`;
		md += `| ${displayHp(bs.hp)} | ${getArmyName(bs.range)} | ${bs.cooldown}秒读条 |\n\n`;
		md += `**技能描述**\n\n`;
		md += `${getDetail(id)}\n\n`;
		md += `**当前技能数值（1星）**\n\n`;
		md += `${starSkillValues(id)}\n\n`;
		md += `**羁绊**\n\n`;
		md += `${heroBondDetail(id).replace(/\n\n/g, "\n\n")}\n\n`;
		md += `---\n\n`;
	}
}

fs.writeFileSync("docs/武将图鉴导出.md", md, "utf-8");
console.log("Generated docs/武将图鉴导出.md");
console.log("Heroes:", Object.keys(names).length, "Factions:", factionOrder.length);
