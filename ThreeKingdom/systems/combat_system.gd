extends "res://ThreeKingdom/systems/game_flow.gd"

func _ensure_unit_fields(unit: Dictionary) -> void:
	var defaults := {"silence":0.0, "stealth":0.0, "slow":0.0, "slow_time":0.0, "vulnerable":0.0, "vulnerable_time":0.0, "grievous":0.0, "grievous_time":0.0, "strategy_mark":0.0, "zhuge_fire_mark":false, "spell_ward":0, "cast_count":0, "focus_target":"", "focus_stacks":0, "faction_tier":0, "faction_damage_reduction":0.0, "faction_hp_bonus":0.0, "faction_control_bonus":0.0, "faction_cooldown_reduction":0.0, "shu_damage_stacks":0, "four_heroes":false, "lvmeng_ganning":false, "stealth_ambush_bonus_ready":false, "burn_missing_hp_scale":false, "fear":0.0, "fear_damage_ratio":0.0, "fear_clock":0.0, "freeze":0.0, "freeze_shatter_per_second":0.0, "poison":0.0, "poison_ratio":0.0, "poison_clock":0.0, "poison_source":"", "regen_per_second":0.0, "regen_time":0.0, "regen_clock":0.0, "regen_magic_reduction":0.0, "regen_source":"", "timed_damage_buff":0.0, "timed_damage_time":0.0, "timed_reduction":0.0, "timed_reduction_time":0.0, "timed_action_bonus":0.0, "timed_action_time":0.0, "rear_damage_reduction":0.0, "rear_damage_reduction_time":0.0, "front_damage_reduction":0.0, "front_damage_reduction_time":0.0, "all_lifesteal":0.0, "all_lifesteal_time":0.0, "bond_cooldown":0.0, "sunquan_initial_max_hp":0.0, "sunshangxiang_skill_bonus":0.0, "skill_value_bonus":0.0, "four_pillars":false, "hebei_damage_stacks":0, "charm_forced_attack":false, "charm_attack_clock":0.0, "dongzhuo_diaochan_hp_bonus":0.0, "skill_debuff_time":0.0, "zhangbao_revives_used":0, "five_tigers_speed_bonus":0.0}
	for key in defaults:
		if not unit.has(key): unit[key] = defaults[key]

func _reset_faction_battle_state() -> void:
	faction_battle_state = {
		"player":{"wu_equalize_used":false},
		"enemy":{"wu_equalize_used":false}
	}
	for unit in combat_units:
		_ensure_unit_fields(unit)
		unit.shu_damage_stacks = 0

func _faction_tier_for_count(count: int) -> int:
	if count >= FACTION_BOND_TIERS[2]:
		return 3
	if count >= FACTION_BOND_TIERS[1]:
		return 2
	if count >= FACTION_BOND_TIERS[0]:
		return 1
	return 0

func _faction_tier_value(tier: int, values: Array) -> float:
	if tier <= 0:
		return 0.0
	return float(values[clampi(tier - 1, 0, values.size() - 1)])

func _set_wu_hp_bonus(unit: Dictionary, new_bonus: float) -> void:
	var old_bonus := float(unit.get("faction_hp_bonus", 0.0))
	if is_equal_approx(old_bonus, new_bonus):
		return
	var old_max := maxf(1.0, float(unit.max_hp))
	var hp_ratio := clampf(float(unit.hp) / old_max, 0.0, 1.0)
	var base_max := old_max / maxf(0.01, 1.0 + old_bonus)
	unit.max_hp = base_max * (1.0 + new_bonus)
	unit.hp = minf(float(unit.max_hp), float(unit.max_hp) * hp_ratio)
	unit.faction_hp_bonus = new_bonus

func _set_runtime_max_hp_bonus(unit: Dictionary, field: String, new_bonus: float) -> void:
	var old_bonus := float(unit.get(field, 0.0))
	if is_equal_approx(old_bonus, new_bonus): return
	var old_max := maxf(1.0, float(unit.max_hp))
	var hp_ratio := clampf(float(unit.hp) / old_max, 0.0, 1.0)
	var base_max := old_max / maxf(0.01, 1.0 + old_bonus)
	unit.max_hp = base_max * (1.0 + new_bonus)
	unit.hp = minf(float(unit.max_hp), float(unit.max_hp) * hp_ratio)
	unit[field] = new_bonus

func _apply_faction_bonuses(announce := true) -> void:
	for team in ["player", "enemy"]:
		var counts := {"shu":0, "wei":0, "wu":0, "qun":0}
		var seen_heroes := {}
		for unit in _team_units(team):
			_ensure_unit_fields(unit)
			if unit.alive and not seen_heroes.has(str(unit.hero_id)):
				seen_heroes[str(unit.hero_id)] = true
				counts[heroes[unit.hero_id].f] += 1
		for unit in _team_units(team):
			var faction: String = heroes[unit.hero_id].f
			var tier := _faction_tier_for_count(int(counts[faction])) if unit.alive else 0
			unit.faction_tier = tier
			unit.faction_damage_reduction = _faction_tier_value(tier, [0.02, 0.05, 0.08]) if faction == "shu" else 0.0
			unit.faction_control_bonus = _faction_tier_value(tier, [0.03, 0.08, 0.15]) if faction == "wei" else 0.0
			unit.faction_cooldown_reduction = _faction_tier_value(tier, [0.03, 0.08, 0.15]) if faction == "qun" else 0.0
			_set_wu_hp_bonus(unit, _faction_tier_value(tier, [0.02, 0.05, 0.08]) if faction == "wu" else 0.0)
			if faction != "shu" or tier < 3:
				unit.shu_damage_stacks = 0
			if int(unit.faction_tier) > 0 and announce:
				var mechanic: String = {
					"shu":t("全体减伤", "team damage reduction"),
					"wei":t("控制强化", "control amplification"),
					"wu":t("全体生命提高", "team max HP"),
					"qun":t("技能冷却缩短", "skill cooldown reduction")
				}[faction]
				_log(_faction_name(faction) + " " + str(FACTION_BOND_TIERS[int(unit.faction_tier) - 1]) + t("人羁绊：", "-unit bond: ") + mechanic)

func _apply_opening_skills() -> void:
	pass

func _apply_combo_bonds(opening := true, announce := true) -> void:
	for unit in combat_units:
		unit.heal_multiplier = 1.0
		unit.charm_multiplier = 1.0
		unit.control_multiplier = 1.0
		unit.current_hp_ratio = 0.06
		unit.ghost_bond = false
		unit.multi_bonus = 0
		unit.burn_multiplier = 1.0
		unit.heal_extra_targets = 0
		unit.four_heroes = false
		unit.lvmeng_ganning = false
		unit.sun_legacy = false
		unit.ambush_link = false
		unit.sunce_taishi = false
		unit.sunce_daqiao = false
		unit.zhouyu_xiaoqiao = false
		unit.zhouyu_huanggai = false
		unit.huanggai_sunjian = false
		unit.taishici_ganning = false
		unit.luxun_sunquan = false
		unit.bond_cooldown = 0.0
		unit.dingfeng_xusheng = false
		unit.heaven_death = false
		unit.five_tigers_speed = false
		unit.five_tigers_speed_bonus = 0.0
		unit.one_rider = false
		unit.fated_enemies = false
		unit.flying_meteor = false
		unit.skill_value_bonus = 0.0
		unit.four_pillars = false
		if unit.hero_id == "dongzhuo":
			_set_runtime_max_hp_bonus(unit, "dongzhuo_diaochan_hp_bonus", 0.0)
	for team in ["player", "enemy"]:
		var active := _team_units(team)
		if _roster_has_all(active, ["liubei", "guanyu", "zhangfei"]):
			if announce: _log(t("【桃园结义】刘备持续治疗升至300%技能强度，关羽按列斩实际伤害的30%恢复自身，张飞号令追加20%减伤。", "[Peach Garden] Liu Bei regenerates at 300% SKILL, Guan Yu heals for 30% of actual cleave damage, and Zhang Fei's command adds 20% reduction."))
		if _roster_has_all(active, ["caocao", "dianwei"]):
			if announce: _log(t("【古之恶来】曹操和典韦互相强化技能。", "[Evil of Old] Cao Cao and Dian Wei empower each other's skills."))
		if _roster_has_all(active, ["caocao", "xuchu"]):
			if announce: _log(t("【虎卫护主】曹操和许褚互相强化技能。", "[Tiger Guard] Cao Cao and Xu Chu empower each other's skills."))
		if _roster_has_all(active, ["dianwei", "xuchu"]):
			if announce: _log(t("【魏武双卫】典韦和许褚互相强化技能。", "[Twin Wei Guards] Dian Wei and Xu Chu empower each other's skills."))
		if _roster_has_all(active, ["zhouyu", "luxun", "lusu", "lvmeng"]):
			for id in ["zhouyu", "luxun", "lusu", "lvmeng"]:
				_combat_hero(team, id).four_heroes = true
			if announce: _log(t("【四英杰】强化周瑜点火、陆逊弹射、鲁肃双人治疗与吕蒙恐惧。", "[Four Heroes] Empowers Zhou Yu's ignition, Lu Xun's bounces, Lu Su's two-ally treatment, and Lu Meng's fear."))
		if _roster_has_all(active, ["dongzhuo", "diaochan"]):
			var bonded_dongzhuo = _combat_hero(team, "dongzhuo")
			_set_runtime_max_hp_bonus(bonded_dongzhuo, "dongzhuo_diaochan_hp_bonus", float(heroes.dongzhuo.ability_params.get("diaochan_max_hp_bonus", 0.50)))
			if announce: _log(t("【暴君倾城】董卓最大生命值提高50%，貂蝉魅惑延长至6秒。", "[Tyrant and Beauty] Dong Zhuo gains 50% max HP and Diao Chan's charm lasts 6s."))
		if _roster_has_all(active, ["guanyu", "zhangfei", "zhaoyun", "huangzhong", "machao"]):
			var speed_bonus := 0.15 * _unit_skill_effect_multiplier(_combat_hero(team, "machao"))
			for ally in active:
				if int(heroes[ally.hero_id].range) <= 2:
					ally.five_tigers_speed = true
					ally.five_tigers_speed_bonus = speed_bonus
			if announce: _log(t("【五虎上将】我方所有前军和中军行动条速度提高15%。", "[Five Tigers] All allied vanguards and midguards gain 15% gauge speed."))
		if _roster_has_all(active, ["machao", "madai"]):
			var machao = _combat_hero(team, "machao")
			var madai = _combat_hero(team, "madai")
			machao.one_rider = true
			madai.one_rider = true
			if opening: madai.action = ACTION_MAX
			if announce: _log(t("【一骑当千】马超全列贯穿均为200%；马岱每场开局立即释放技能。", "[One Rider] Ma Chao pierces every row at 200%; Ma Dai starts each battle ready to cast."))
		if _roster_has_all(active, ["weiyan", "madai"]):
			_combat_hero(team, "weiyan").fated_enemies = true
			_combat_hero(team, "madai").fated_enemies = true
			if announce: _log(t("【宿命之敌】马岱施加40%易伤15秒；魏延技能为相邻和后方中军友军回复15%最大生命。", "[Fated Enemies] Ma Dai applies 40% vulnerability for 15s; Wei Yan heals adjacent and rearward midguard allies for 15% max HP."))
		if _roster_has_all(active, ["weiyan", "huangzhong"]):
			_combat_hero(team, "weiyan").flying_meteor = true
			_combat_hero(team, "huangzhong").flying_meteor = true
			if announce: _log(t("【飞火流星】黄忠箭击有50%概率造成双倍伤害；敌方前军阵亡时，魏延回复50%最大生命。", "[Flying Meteor] Huang Zhong has a 50% chance to deal double damage; Wei Yan heals 50% max HP whenever an enemy frontliner falls."))
		if _roster_has_all(active, ["zhangliao", "yuejin"]):
			if announce: _log(t("【逍遥津先锋】张辽与乐进互相强化技能。", "[Hefei Vanguard] Zhang Liao and Yue Jin empower each other's skills."))
		if _roster_has_all(active, ["zhanghe", "xuhuang"]):
			if announce: _log(t("【巧变开山】张郃与徐晃互相强化技能。", "[Adaptive Vanguard] Zhang He and Xu Huang empower each other's skills."))
		if _roster_has_all(active, ["zhangliao", "yuejin", "zhanghe", "xuhuang", "yujin"]):
			if announce: _log(t("【五子良将】五人绝技全部获得完全体强化。", "[Five Elite Generals] All five signature skills reach their complete form."))
		var xiahouyuan = _combat_hero(team, "xiahouyuan")
		if xiahouyuan != null:
			var xhy_cd := float(heroes.xiahouyuan.cooldown)
			if _roster_has_all(active, ["xiahouyuan", "caoren"]): xhy_cd -= 0.5
			if _roster_has_all(active, ["xiahouyuan", "xiahoudun"]): xhy_cd -= 0.5
			xiahouyuan.bond_cooldown = xhy_cd
		var guojia = _combat_hero(team, "guojia")
		if guojia != null:
			var guo_cd := float(heroes.guojia.cooldown)
			for ally_id in ["simayi", "xunyu", "jiaxu"]:
				if _roster_has_all(active, ["guojia", ally_id]): guo_cd -= 0.5
			guojia.bond_cooldown = guo_cd
		var xunyu = _combat_hero(team, "xunyu")
		if xunyu != null:
			var xun_cd := float(heroes.xunyu.cooldown)
			for ally_id in ["simayi", "guojia", "jiaxu"]:
				if _roster_has_all(active, ["xunyu", ally_id]): xun_cd -= 0.4
			xunyu.bond_cooldown = xun_cd
		if _roster_has_all(active, ["sunjian", "sunce", "sunquan", "sunshangxiang"]):
			for id in ["sunjian", "sunce", "sunquan", "sunshangxiang"]: _combat_hero(team, id).sun_legacy = true
			_combat_hero(team, "sunshangxiang").bond_cooldown = float(heroes.sunshangxiang.ability_params.get("sun_legacy_cooldown", 6.0))
			if announce: _log(t("【孙氏之志】强化孙坚、孙策、孙权与孙尚香的专属技能。", "[Sun Legacy] Empowers the signature skills of Sun Jian, Sun Ce, Sun Quan, and Sun Shangxiang."))
		if _roster_has_all(active, ["daqiao", "xiaoqiao"]):
			_combat_hero(team, "daqiao").heal_multiplier = 1.50
			_combat_hero(team, "daqiao").heal_extra_targets = 1
		if _roster_has_all(active, ["lvmeng", "ganning"]):
			_combat_hero(team, "lvmeng").lvmeng_ganning = true
			_combat_hero(team, "ganning").lvmeng_ganning = true
		if _roster_has_all(active, ["sunce", "taishici"]):
			_combat_hero(team, "sunce").sunce_taishi = true
			_combat_hero(team, "taishici").sunce_taishi = true
			if announce: _log(t("【神亭酣战】孙策追加右侧第二段横扫；太史慈改为攻击行动条最高的3名敌人。", "[Shenting Duel] Sun Ce adds a right-side second sweep; Taishi Ci targets the 3 enemies with the highest gauges."))
		if _roster_has_all(active, ["sunce", "daqiao"]):
			_combat_hero(team, "sunce").sunce_daqiao = true
			_combat_hero(team, "daqiao").sunce_daqiao = true
			if announce: _log(t("【江东佳偶】孙策出手后自疗；大乔根据目标已损失生命提高治疗。", "[Jiangdong Couple] Sun Ce heals after casting; Da Qiao scales healing with the target's missing HP."))
		if _roster_has_all(active, ["zhouyu", "xiaoqiao"]):
			_combat_hero(team, "zhouyu").zhouyu_xiaoqiao = true
			_combat_hero(team, "xiaoqiao").zhouyu_xiaoqiao = true
			if announce: _log(t("【琴瑟和鸣】周瑜延长灼烧；小乔减速目标增至3名并延长至8秒。", "[Harmonious Zither] Zhou Yu extends burns; Xiao Qiao slows 3 targets for 8s."))
		if _roster_has_all(active, ["zhouyu", "huanggai"]):
			_combat_hero(team, "zhouyu").zhouyu_huanggai = true
			_combat_hero(team, "huanggai").zhouyu_huanggai = true
			if announce: _log(t("【赤壁苦计】周瑜提高点火伤害；黄盖列攻附加6秒灼烧。", "[Red Cliffs Ruse] Zhou Yu's ignition hits harder; Huang Gai's column strike burns for 6s."))
		if _roster_has_all(active, ["huanggai", "sunjian"]):
			_combat_hero(team, "huanggai").huanggai_sunjian = true
			_combat_hero(team, "sunjian").huanggai_sunjian = true
			if opening: _combat_hero(team, "sunjian").action = ACTION_MAX
			if announce: _log(t("【江东柱石】黄盖消耗15%最大生命并按消耗生命45%伤害；孙坚开局满行动条且按消耗生命150%伤害。", "[Pillars of Jiangdong] Huang Gai spends 15% max HP and deals 45% of HP spent; Sun Jian starts ready and deals 150% of HP spent."))
		if _roster_has_all(active, ["taishici", "ganning"]):
			_combat_hero(team, "taishici").taishici_ganning = true
			_combat_hero(team, "ganning").taishici_ganning = true
			if announce: _log(t("【江表双锋】太史慈对已灼烧目标提高至300%伤害；甘宁协击提高至250%技能强度。", "[Twin Blades of Jiangbiao] Taishi Ci deals 300% to burning targets; Gan Ning's twin assault rises to 250% SKILL."))
		if _roster_has_all(active, ["luxun", "sunquan"]):
			_combat_hero(team, "luxun").luxun_sunquan = true
			_combat_hero(team, "sunquan").luxun_sunquan = true
			_combat_hero(team, "sunquan").bond_cooldown = float(heroes.sunquan.ability_params.get("luxun_cooldown", 8.0))
			if announce: _log(t("【君臣同心】陆逊火球增伤；孙权改为造成12%当前生命伤害且冷却缩短至8秒。", "[Sovereign and Minister] Lu Xun's fireball gains damage; Sun Quan deals 12% current-HP damage with an 8s cooldown."))
		if _roster_has_all(active, ["dingfeng", "xusheng"]):
			_combat_hero(team, "dingfeng").dingfeng_xusheng = true
			_combat_hero(team, "xusheng").dingfeng_xusheng = true
			_combat_hero(team, "xusheng").control_multiplier = maxf(float(_combat_hero(team, "xusheng").control_multiplier), 1.50)
			if announce: _log(t("【江表虎臣】丁奉追加横向突击；徐盛水阵控制延长50%。", "[Tiger Ministers] Ding Feng gains horizontal follow-up strikes; Xu Sheng's water control lasts 50% longer."))
		var four_pillars := _roster_has_all(active, ["yanliang", "wenchou", "qunzhanghe", "gaolan"])
		if four_pillars:
			for id in ["yanliang", "wenchou", "qunzhanghe", "gaolan"]:
				var pillar = _combat_hero(team, id)
				if pillar != null: pillar.four_pillars = true
			if announce: _log(t("【河北四庭柱】颜良、文丑获得受击蓄势，高览扩大技能强度光环，群张郃强化护盾。", "[Hebei Pillars] Yan Liang and Wen Chou build damage from hits, Gao Lan expands his SKILL aura, and Zhang He empowers his wards."))
		var chengong = _combat_hero(team, "chengong")
		if chengong != null and chengong.alive:
			var cooldown_reduction := float(heroes.chengong.ability_params.get("cooldown_reduction", 1.0))
			if _roster_has_all(active, ["chengong", "lvbu"]): cooldown_reduction += float(heroes.chengong.ability_params.get("lvbu_bonus_reduction", 1.0))
			if _roster_has_all(active, ["chengong", "gaoshun"]): cooldown_reduction += float(heroes.chengong.ability_params.get("gaoshun_bonus_reduction", 1.0))
			cooldown_reduction *= _unit_skill_effect_multiplier(chengong)
			for ally in active:
				if not ally.alive or int(ally.col) != int(chengong.col): continue
				var current_cooldown := float(ally.get("bond_cooldown", 0.0))
				if current_cooldown <= 0.0: current_cooldown = float(heroes[ally.hero_id].cooldown)
				ally.bond_cooldown = maxf(0.1, current_cooldown - cooldown_reduction)
		var gaolan = _combat_hero(team, "gaolan")
		if gaolan != null and gaolan.alive:
			var skill_bonus := float(heroes.gaolan.ability_params.get("skill_bonus", 20.0))
			if _roster_has_all(active, ["gaolan", "qunzhanghe"]): skill_bonus = float(heroes.gaolan.ability_params.get("zhanghe_skill_bonus", 40.0))
			if four_pillars: skill_bonus = float(heroes.gaolan.ability_params.get("four_pillars_skill_bonus", 40.0))
			skill_bonus *= _unit_skill_effect_multiplier(gaolan)
			for ally in active:
				if not ally.alive: continue
				var affected := int(ally.col) == int(gaolan.col)
				if four_pillars: affected = affected or int(ally.row) == int(gaolan.row)
				if affected: ally.skill_value_bonus = maxf(float(ally.get("skill_value_bonus", 0.0)), skill_bonus)
		_sync_duplicate_bond_benefits(team, opening)

func _sync_duplicate_bond_benefits(team: String, opening: bool) -> void:
	var templates := {}
	var fields := ["heal_multiplier", "charm_multiplier", "control_multiplier", "current_hp_ratio", "ghost_bond", "multi_bonus", "burn_multiplier", "heal_extra_targets", "four_heroes", "lvmeng_ganning", "sun_legacy", "ambush_link", "sunce_taishi", "sunce_daqiao", "zhouyu_xiaoqiao", "zhouyu_huanggai", "huanggai_sunjian", "taishici_ganning", "luxun_sunquan", "bond_cooldown", "dingfeng_xusheng", "heaven_death", "five_tigers_speed", "five_tigers_speed_bonus", "one_rider", "fated_enemies", "flying_meteor", "skill_value_bonus", "four_pillars"]
	for unit in _team_units(team):
		if unit.alive and not templates.has(str(unit.hero_id)):
			templates[str(unit.hero_id)] = unit
	for unit in _team_units(team):
		if not unit.alive: continue
		var template: Dictionary = templates[str(unit.hero_id)]
		if unit.id == template.id: continue
		for field in fields:
			unit[field] = template.get(field, unit.get(field))
		if opening and float(template.get("action", 0.0)) >= ACTION_MAX:
			unit.action = ACTION_MAX
		if unit.hero_id == "dongzhuo":
			_set_runtime_max_hp_bonus(unit, "dongzhuo_diaochan_hp_bonus", float(template.get("dongzhuo_diaochan_hp_bonus", 0.0)))

func _grant_shield(target: Dictionary, amount: float) -> void:
	if not target.alive or amount <= 0.0: return
	var cap: float = max(float(target.shield), amount * 2.0)
	target.shield = min(float(target.shield) + amount, cap)

func _combat_hero(team: String, hero_id: String):
	for unit in _team_units(team):
		if unit.hero_id == hero_id and unit.alive and int(unit.row) >= 0: return unit
	for unit in _team_units(team):
		if unit.hero_id == hero_id: return unit
	return null

func _add_stat(unit, key: String, amount: float) -> void:
	if unit == null or not battle_stats.has(unit.id): return
	battle_stats[unit.id][key] = float(battle_stats[unit.id].get(key, 0.0)) + amount

func _capture_battle_stats() -> void:
	last_battle_stats = []
	for entry in battle_stats.values(): last_battle_stats.append(entry.duplicate(true))

func _unit_action_gain_multiplier(unit: Dictionary) -> float:
	var result := float(unit.get("action_gain_mult", 1.0))
	result *= 1.0 + float(unit.get("timed_action_bonus", 0.0))
	if bool(unit.get("five_tigers_speed", false)): result *= 1.0 + float(unit.get("five_tigers_speed_bonus", 0.15))
	var cooldown_reduction := clampf(float(unit.get("faction_cooldown_reduction", 0.0)), 0.0, 0.95)
	if cooldown_reduction > 0.0:
		result /= 1.0 - cooldown_reduction
	return result

func _unit_skill_cooldown(unit: Dictionary) -> float:
	var bond_value := float(unit.get("bond_cooldown", 0.0))
	return bond_value if bond_value > 0.0 else float(heroes[unit.hero_id].cooldown)

func _unit_has_active_skill(unit: Dictionary) -> bool:
	return str(heroes[unit.hero_id].get("ability", "")) != "passive"

func _unit_skill_power_multiplier(unit: Dictionary) -> float:
	return maxf(0.0, _unit_skill_stat_value(unit) / 100.0)

func _unit_skill_stat_value(unit: Dictionary) -> float:
	return float(heroes[unit.hero_id].skill_value) + float(unit.get("skill_value_bonus", 0.0)) + float(unit.get("sunshangxiang_skill_bonus", 0.0))

func _unit_skill_output_base(unit: Dictionary) -> float:
	var hero: Dictionary = heroes[unit.hero_id]
	return float(hero.get("skill_output_base", hero.get("skill_value", 100.0)))

func _unit_combat_skill_value(unit: Dictionary) -> float:
	return _unit_skill_output_base(unit) * _unit_skill_power_multiplier(unit)

func _unit_scaled_skill_value(unit: Dictionary) -> float:
	return _unit_combat_skill_value(unit) * maxf(0.0, 1.0 - float(unit.get("skill_debuff", 0.0)))

func _unit_skill_effect_multiplier(unit: Dictionary) -> float:
	return _unit_skill_power_multiplier(unit) * maxf(0.0, 1.0 - float(unit.get("skill_debuff", 0.0)))

func _control_duration_multiplier(unit: Dictionary) -> float:
	return float(unit.get("control_multiplier", 1.0)) * (1.0 + float(unit.get("faction_control_bonus", 0.0)))

func _battle_tick() -> void:
	if not battle_running or battle_paused or action_in_progress: return
	var already_ready := combat_units.filter(func(unit): return unit.alive and _unit_has_active_skill(unit) and unit.stun <= 0 and unit.charm <= 0 and float(unit.get("fear", 0.0)) <= 0.0 and float(unit.get("freeze", 0.0)) <= 0.0 and float(unit.action) >= ACTION_MAX)
	if not already_ready.is_empty():
		_begin_action(already_ready[0])
		return
	var delta := TICK * battle_speed
	battle_time += delta
	_process_statuses(delta)
	var ambient_events: Array = visual_events.filter(func(event): return bool(event.get("nonblocking", false)))
	if not ambient_events.is_empty():
		visual_events = visual_events.filter(func(event): return not bool(event.get("nonblocking", false)))
		call_deferred("_play_visual_events", ambient_events)
	if _has_winner():
		_finish_battle()
		return
	if not visual_events.is_empty():
		_begin_effect_pause()
		return
	for unit in combat_units:
		if not unit.alive or not _unit_has_active_skill(unit) or unit.stun > 0 or unit.charm > 0 or float(unit.get("fear", 0.0)) > 0.0 or float(unit.get("freeze", 0.0)) > 0.0: continue
		var gain_per_second: float = ACTION_MAX / maxf(0.001, _unit_skill_cooldown(unit))
		var silence_slow := 0.5 if float(unit.get("silence", 0.0)) > 0.0 else 0.0
		unit.action = min(ACTION_MAX, float(unit.action) + gain_per_second * delta * _unit_action_gain_multiplier(unit) * (1.0 - float(unit.get("slow", 0.0)) - silence_slow))
	_update_action_bars()
	_update_battle_time_bar()
	var ready := combat_units.filter(func(unit): return unit.alive and _unit_has_active_skill(unit) and unit.stun <= 0 and unit.charm <= 0 and float(unit.get("fear", 0.0)) <= 0.0 and float(unit.get("freeze", 0.0)) <= 0.0 and float(unit.action) >= ACTION_MAX)
	if not ready.is_empty(): _begin_action(ready[0])
	if battle_time >= BATTLE_LIMIT and not final_battle: _finish_battle()

func _begin_action(unit: Dictionary) -> void:
	if action_in_progress or not unit.alive: return
	if not pause_during_actions:
		unit.action = max(0.0, float(unit.action) - ACTION_MAX)
		_perform_action(unit)
		var free_events := visual_events.duplicate(true)
		visual_events.clear()
		if not free_events.is_empty(): call_deferred("_play_unpaused_events", free_events)
		if _has_winner(): _finish_battle()
		return
	action_in_progress = true
	tick_timer.stop()
	unit.action = max(0.0, float(unit.action) - ACTION_MAX)
	call_deferred("_resolve_action", unit)

func _resolve_action(unit: Dictionary) -> void:
	if unit.alive: _perform_action(unit)
	var events := visual_events.duplicate(true)
	visual_events.clear()
	if not events.is_empty(): await _play_visual_events(events)
	_render_combat_boards()
	action_in_progress = false
	if _has_winner(): _finish_battle()
	elif battle_running and not battle_paused: tick_timer.start()

func _play_unpaused_events(events: Array) -> void:
	await _play_visual_events(events)
	if battle_running: _render_combat_boards()

func _begin_effect_pause() -> void:
	if action_in_progress: return
	action_in_progress = true
	tick_timer.stop()
	call_deferred("_resolve_effect_pause")

func _resolve_effect_pause() -> void:
	var events := visual_events.duplicate(true)
	visual_events.clear()
	if not events.is_empty(): await _play_visual_events(events)
	_render_combat_boards()
	action_in_progress = false
	if _has_winner(): _finish_battle()
	elif battle_running and not battle_paused: tick_timer.start()

func _process_statuses(delta: float = TICK) -> void:
	var status_tick_id := str(floori(battle_time + 0.001))
	for unit in combat_units:
		if not unit.alive: continue
		if unit.burn > 0:
			unit.burn_clock = float(unit.get("burn_clock", 0.0)) + delta
			if unit.burn_clock >= 1.0:
				unit.burn_clock -= 1.0
				var burn_visual_group := str(unit.get("burn_visual_group", ""))
				var burn_tick_damage := float(unit.burn_damage)
				if bool(unit.get("burn_missing_hp_scale", false)):
					burn_tick_damage *= _missing_hp_damage_multiplier(unit, 0.10, 0.05)
				_damage(null, unit, burn_tick_damage, "magic", t("灼烧", "Burn"), "status_burn:" + status_tick_id, "burn_tick", false)
			unit.burn = max(0.0, unit.burn - delta)
			if unit.burn <= 0.0:
				unit["burn_visual_group"] = ""
				unit.burn_missing_hp_scale = false
		if not unit.alive:
			continue
		if float(unit.get("fear", 0.0)) > 0.0:
			unit.fear_clock = float(unit.get("fear_clock", 0.0)) + delta
			if unit.fear_clock >= 1.0:
				unit.fear_clock -= 1.0
				_damage(null, unit, float(unit.max_hp) * float(unit.get("fear_damage_ratio", 0.05)), "magic", t("恐惧", "Fear"), "status_fear:" + status_tick_id, "fear_tick", false)
			unit.fear = maxf(0.0, float(unit.fear) - delta)
			if unit.fear <= 0.0:
				unit.fear_damage_ratio = 0.0
				unit.fear_clock = 0.0
		if float(unit.get("poison", 0.0)) > 0.0:
			unit.poison_clock = float(unit.get("poison_clock", 0.0)) + delta
			while float(unit.poison_clock) >= 1.0 and unit.alive:
				unit.poison_clock = float(unit.poison_clock) - 1.0
				var poison_source = _find_by_id(combat_units, str(unit.get("poison_source", "")))
				var poison_amount := float(unit.max_hp) * float(unit.get("poison_ratio", 0.01))
				_damage(poison_source, unit, poison_amount, "magic", t("中毒", "Poison"), "status_poison:" + status_tick_id, "poison_tick", false)
			unit.poison = maxf(0.0, float(unit.poison) - delta)
			if unit.poison <= 0.0:
				unit.poison_ratio = 0.0
				unit.poison_clock = 0.0
				unit.poison_source = ""
		unit.freeze = maxf(0.0, float(unit.get("freeze", 0.0)) - delta)
		unit.stun = max(0.0, unit.stun - delta)
		if float(unit.get("charm", 0.0)) > 0.0 and bool(unit.get("charm_forced_attack", false)):
			unit.charm_attack_clock = float(unit.get("charm_attack_clock", 0.0)) + delta
			var interval := float(heroes.diaochan.ability_params.get("forced_attack_interval", 1.0))
			while float(unit.charm_attack_clock) >= interval and unit.alive:
				unit.charm_attack_clock = float(unit.charm_attack_clock) - interval
				var adjacent := _team_units(unit.team).filter(func(ally):
					return ally.alive and ally.id != unit.id and abs(int(ally.row) - int(unit.row)) + abs(int(ally.col) - int(unit.col)) == 1
				)
				if adjacent.is_empty(): continue
				var victim: Dictionary = adjacent[rng.randi_range(0, adjacent.size() - 1)]
				var forced_amount := _unit_skill_output_base(unit) * float(heroes.diaochan.ability_params.get("forced_attack_mult", 1.0))
				_damage(unit, victim, forced_amount, "physical", t("魅惑倒戈", "Charmed betrayal"), "charm_attack:" + str(unit.id), "multi_target")
		unit.charm = max(0.0, unit.charm - delta)
		if unit.charm <= 0.0:
			unit.charm_forced_attack = false
			unit.charm_attack_clock = 0.0
		unit.silence = max(0.0, float(unit.get("silence", 0.0)) - delta)
		unit.skill_debuff_time = maxf(0.0, float(unit.get("skill_debuff_time", 0.0)) - delta)
		if unit.skill_debuff_time <= 0.0: unit.skill_debuff = 0.0
		unit.stealth = max(0.0, float(unit.get("stealth", 0.0)) - delta)
		unit.slow_time = max(0.0, float(unit.get("slow_time", 0.0)) - delta)
		if unit.slow_time <= 0.0: unit.slow = 0.0
		unit.vulnerable_time = max(0.0, float(unit.get("vulnerable_time", 0.0)) - delta)
		if unit.vulnerable_time <= 0.0: unit.vulnerable = 0.0
		unit.grievous_time = max(0.0, float(unit.get("grievous_time", 0.0)) - delta)
		if unit.grievous_time <= 0.0: unit.grievous = 0.0
		unit.timed_damage_time = max(0.0, float(unit.get("timed_damage_time", 0.0)) - delta)
		if unit.timed_damage_time <= 0.0: unit.timed_damage_buff = 0.0
		unit.all_lifesteal_time = max(0.0, float(unit.get("all_lifesteal_time", 0.0)) - delta)
		if unit.all_lifesteal_time <= 0.0: unit.all_lifesteal = 0.0
		unit.timed_reduction_time = max(0.0, float(unit.get("timed_reduction_time", 0.0)) - delta)
		if unit.timed_reduction_time <= 0.0: unit.timed_reduction = 0.0
		unit.timed_action_time = maxf(0.0, float(unit.get("timed_action_time", 0.0)) - delta)
		if unit.timed_action_time <= 0.0: unit.timed_action_bonus = 0.0
		unit.rear_damage_reduction_time = maxf(0.0, float(unit.get("rear_damage_reduction_time", 0.0)) - delta)
		if unit.rear_damage_reduction_time <= 0.0: unit.rear_damage_reduction = 0.0
		unit.front_damage_reduction_time = maxf(0.0, float(unit.get("front_damage_reduction_time", 0.0)) - delta)
		if unit.front_damage_reduction_time <= 0.0: unit.front_damage_reduction = 0.0
		if float(unit.get("regen_time", 0.0)) > 0.0:
			unit.regen_clock = float(unit.get("regen_clock", 0.0)) + delta
			unit.regen_time = max(0.0, float(unit.regen_time) - delta)
			if unit.regen_clock >= 1.0:
				unit.regen_clock -= 1.0
				var regen_source = _find_by_id(combat_units, str(unit.get("regen_source", "")))
				if regen_source != null: _heal_with_overflow(regen_source, unit, float(unit.regen_per_second), "regen", true)
			if unit.regen_time <= 0.0:
				unit.regen_per_second = 0.0
				unit.regen_magic_reduction = 0.0
				unit.regen_source = ""
		unit.strategy_mark = max(0.0, float(unit.get("strategy_mark", 0.0)) - delta)
		unit.death_prevention = max(0.0, float(unit.get("death_prevention", 0.0)) - delta)
	for index in range(ground_effects.size() - 1, -1, -1):
		var effect: Dictionary = ground_effects[index]
		effect.time = maxf(0.0, float(effect.get("time", 0.0)) - delta)
		effect.clock = float(effect.get("clock", 0.0)) + delta
		if float(effect.clock) >= 1.0:
			effect.clock = float(effect.clock) - 1.0
			var source = _find_by_id(combat_units, str(effect.get("source_id", "")))
			if source != null:
				var ground_damage := float(effect.get("damage", 0.0))
				if bool(effect.get("missing_hp_scale", false)):
					var target_ruler_hp := enemy_ruler_hp if source.team == "player" else player_ruler_hp
					var ruler_missing_ratio := 1.0 - float(target_ruler_hp) / maxf(1.0, float(RULER_MAX_HP))
					ground_damage *= 1.0 + floorf(ruler_missing_ratio / 0.10 + 0.0001) * 0.05
				_hit_ruler(
					source,
					ground_damage,
					{"team":str(effect.team), "row":int(effect.row), "col":int(effect.col)},
					t("地面灼烧", "Ground burn"),
					str(effect.get("visual_group", "")),
					"burn_tick"
				)
		if float(effect.time) <= 0.0:
			ground_effects.remove_at(index)
		else:
			ground_effects[index] = effect
	for team in ["player", "enemy"]:
		var regen: Dictionary = ruler_regen[team]
		if float(regen.get("time", 0.0)) <= 0.0: continue
		regen.time = max(0.0, float(regen.time) - delta)
		regen.clock = float(regen.get("clock", 0.0)) + delta
		if regen.clock >= 1.0:
			regen.clock -= 1.0
			var regen_source = _find_by_id(combat_units, str(regen.get("source", "")))
			if regen_source != null: _heal_with_overflow(regen_source, null, float(regen.amount), "regen", true)
		if regen.time <= 0.0:
			regen.amount = 0.0
			regen.magic_reduction = 0.0
		ruler_regen[team] = regen

func _perform_action(unit: Dictionary) -> void:
	visual_events.append({"kind":"charge", "source_id":unit.id, "target_id":unit.id, "amount":0, "style":"magic"})
	_cast_active_skill(unit)
	_after_active_skill(unit)
	if heroes[unit.hero_id].f == "shu":
		unit.shu_damage_stacks = 0
	if heroes[unit.hero_id].f == "qun" and int(unit.get("faction_tier", 0)) >= 3 and not _has_winner() and rng.randf() < 0.20:
		_log("[color=#d59af0]" + t("【乱世争衡】触发连续施法！", "[Chaos Struggle] Double cast triggered!") + "[/color]")
		visual_events.append({"kind":"charge", "source_id":unit.id, "target_id":unit.id, "amount":0, "style":"magic"})
		_cast_active_skill(unit)
		_after_active_skill(unit)

func _cast_active_skill(unit: Dictionary) -> void:
	match unit.hero_id:
		"liubei": _cast_liubei_regen(unit)
		"liushan": _cast_liushan_command(unit)
		"zhangfei": _cast_zhangfei_command(unit)
		"caocao": _cast_caocao_command(unit)
		"zhaoyun": _cast_zhaoyun_empower(unit)
		"huangzhong": _cast_huangzhong_skill(unit)
		"machao": _cast_machao_pierce(unit)
		"madai": _cast_madai_execution(unit)
		"weiyan": _cast_weiyan_cleave(unit)
		"zhugeliang": _cast_zhugeliang_skill(unit)
		"jiangwei": _cast_jiangwei_skill(unit)
		"pangtong": _cast_pangtong_skill(unit)
		"menghuo": _cast_menghuo_skill(unit)
		"zhurong": _cast_zhurong_skill(unit)
		"dailaidongzhu": _cast_dailai_skill(unit)
		"taishici": _cast_taishici_skill(unit)
		"dingfeng": _cast_dingfeng_skill(unit)
		"zhouyu": _cast_zhouyu(unit)
		"luxun": _cast_luxun(unit)
		"lvmeng": _cast_lvmeng_skill(unit)
		"lusu": _cast_lusu_skill(unit)
		"xiaoqiao": _cast_xiaoqiao_skill(unit)
		"sunjian": _cast_sunjian_skill(unit)
		"sunce": _cast_sunce_skill(unit)
		"sunquan": _cast_sunquan_skill(unit)
		"sunshangxiang": _cast_sunshangxiang_skill(unit)
		"ganning": _cast_ganning_skill(unit)
		"huanggai": _cast_huanggai_skill(unit)
		"diaochan": _cast_diaochan(unit)
		"gaoshun": _cast_gaoshun_skill(unit)
		"yanliang": _cast_yanliang_skill(unit)
		"wenchou": _cast_wenchou_skill(unit)
		"qunzhanghe": _cast_qun_zhanghe_skill(unit)
		"dianwei": _cast_dianwei_skill(unit)
		"guanyu": _cast_guanyu_skill(unit)
		"lvbu": _cast_lvbu_skill(unit)
		"xuchu": _cast_xuchu_skill(unit)
		"zhangliao": _cast_zhangliao_skill(unit)
		"yuejin": _cast_yuejin_skill(unit)
		"xuhuang": _cast_xuhuang_skill(unit)
		"zhanghe": _cast_zhanghe_skill(unit)
		"yujin": _cast_yujin_skill(unit)
		"xiahouyuan": _cast_xiahouyuan_skill(unit)
		"caoren": _cast_caoren_skill(unit)
		"xiahoudun": _cast_xiahoudun_skill(unit)
		"simayi": _cast_simayi_skill(unit)
		"guojia": _cast_guojia_skill(unit)
		"xunyu": _cast_xunyu_skill(unit)
		"jiaxu": _cast_jiaxu_skill(unit)
		"huatuo": _cast_huatuo_skill(unit)
		"yuji": _cast_yuji_skill(unit)
		"zuoci": _cast_zuoci_skill(unit)
		"zhangjiao": _cast_zhangjiao_skill(unit)
		"zhangliang": _cast_zhangliang_skill(unit)
		"dongzhuo": _cast_dongzhuo_skill(unit)
		_: _cast_generic_ability(unit)

func _highest_action_enemy(unit: Dictionary):
	var candidates := _targets_in_range(unit).filter(func(enemy): return enemy.alive and float(enemy.get("stealth", 0.0)) <= 0.0)
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(a, b): return float(a.action) > float(b.action))
	return candidates[0]

func _cast_sunjian_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.sunjian.ability_params
	var first_cast := int(unit.get("cast_count", 0)) == 0
	var self_cost := float(params.get("first_self_cost", 0.40)) if first_cast else float(params.get("self_cost", 0.10))
	if bool(unit.get("sun_legacy", false)):
		self_cost = float(params.get("sun_legacy_first_self_cost", 0.80)) if first_cast else float(params.get("sun_legacy_self_cost", 0.20))
	var hp_before := float(unit.hp)
	unit.hp = maxf(1.0, hp_before * (1.0 - clampf(self_cost, 0.0, 0.99)))
	var hp_spent := hp_before - float(unit.hp)
	var damage_cost_ratio := float(params.get("pillars_damage_cost_ratio", 1.5)) if bool(unit.get("huanggai_sunjian", false)) else float(params.get("damage_cost_ratio", 1.0))
	var amount := hp_spent * damage_cost_ratio * _unit_skill_effect_multiplier(unit)
	var tile := {"row":0, "col":clampi(int(unit.col), 0, BOARD_COLUMNS - 1), "team":_enemy_team_id(unit.team)}
	var target = _unit_at(_enemy_units(unit.team), int(tile.row), int(tile.col))
	var visual_group := "sunjian_sacrifice:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	if target == null:
		_hit_ruler(unit, amount, tile, t("猛虎绝命空击", "Tiger's Resolve missed"), visual_group, "row_impact", false)
	else:
		_damage(unit, target, amount, "physical", t("猛虎绝命", "Tiger's Resolve"), visual_group, "row_impact", false)
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_sunce_wave(unit: Dictionary, column_offsets: Array, damage: float, wave: int) -> void:
	var target_team := _enemy_team_id(unit.team)
	var visual_group := "sunce_double:" + str(unit.id) + ":" + str(unit.get("cast_count", 0)) + ":" + str(wave)
	for offset in column_offsets:
		var col := int(unit.col) + int(offset)
		if col < 0 or col >= BOARD_COLUMNS:
			continue
		var tile := {"row":0, "col":col, "team":target_team}
		var target = _unit_at(_enemy_units(unit.team), int(tile.row), int(tile.col))
		if target == null:
			_hit_ruler(unit, damage, tile, t("小霸王连击空击", "Conqueror's Twin Assault missed"), visual_group, "row_impact")
		else:
			_damage(unit, target, damage, "physical", t("小霸王连击", "Conqueror's Twin Assault"), visual_group, "row_impact")

func _cast_sunce_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.sunce.ability_params
	var base_mult := float(params.get("sun_legacy_mult", 4.0)) if bool(unit.get("sun_legacy", false)) else float(params.get("mult", 2.0))
	var missing_mult := _missing_hp_damage_multiplier(unit, float(params.get("missing_hp_step", 0.10)), float(params.get("missing_hp_damage_bonus_per_step", 0.02)) * _unit_skill_effect_multiplier(unit))
	var damage := float(params.get("base_value", _unit_skill_output_base(unit))) * base_mult * missing_mult
	_cast_sunce_wave(unit, [0, -1], damage, 1)
	if bool(unit.get("sunce_taishi", false)) and not _has_winner():
		_cast_sunce_wave(unit, [0, 1], damage, 2)
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _random_living_enemy(unit: Dictionary):
	var candidates := _enemy_units(unit.team).filter(func(enemy): return enemy.alive and float(enemy.get("stealth", 0.0)) <= 0.0)
	if candidates.is_empty():
		return null
	return candidates[rng.randi_range(0, candidates.size() - 1)]

func _cast_sunquan_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.sunquan.ability_params
	var target = _random_living_enemy(unit)
	var ratio := (float(params.get("luxun_damage_ratio", 0.12)) if bool(unit.get("luxun_sunquan", false)) else float(params.get("current_hp_damage_ratio", 0.08))) * _unit_skill_effect_multiplier(unit)
	if target == null:
		var tile := _random_enemy_tile(unit)
		var ruler_hp := enemy_ruler_hp if unit.team == "player" else player_ruler_hp
		_hit_ruler(unit, float(ruler_hp) * ratio / maxf(0.001, float(unit.get("stat_mult", 1.0))), tile, t("江东制衡空击", "Jiangdong Balance missed"), "", "", false)
	else:
		_damage(unit, target, float(target.hp) * ratio / maxf(0.001, float(unit.get("stat_mult", 1.0))), "magic", t("江东制衡", "Jiangdong Balance"), "", "", false)
	if float(unit.get("sunquan_initial_max_hp", 0.0)) <= 0.0:
		unit.sunquan_initial_max_hp = float(unit.max_hp)
	var missing_before := maxf(0.0, float(unit.max_hp) - float(unit.hp))
	var effect_mult := _unit_skill_effect_multiplier(unit)
	var max_hp_gain := float(params.get("max_hp_gain", 200.0)) * effect_mult
	var cap_mult := float(params.get("max_hp_cap_mult", 2.0))
	var heal_ratio := float(params.get("missing_hp_heal_ratio", 0.10)) * effect_mult
	if bool(unit.get("sun_legacy", false)):
		max_hp_gain = (float(params.get("sun_legacy_max_hp_gain", 400.0)) + missing_before * float(params.get("sun_legacy_missing_hp_cap_gain_ratio", 0.10))) * effect_mult
		cap_mult = float(params.get("sun_legacy_max_hp_cap_mult", 4.0))
		heal_ratio = float(params.get("sun_legacy_missing_hp_heal_ratio", 0.15)) * effect_mult
	var max_hp_cap := float(unit.sunquan_initial_max_hp) * cap_mult
	var actual_gain := minf(max_hp_gain, maxf(0.0, max_hp_cap - float(unit.max_hp)))
	if actual_gain > 0.0:
		unit.max_hp = float(unit.max_hp) + actual_gain
		visual_events.append({"kind":"skill", "source_id":unit.id, "target_id":unit.id, "amount":roundi(actual_gain), "style":"heal", "nonblocking":true})
	var restored := _heal_unit_only(unit, unit, maxf(0.0, float(unit.max_hp) - float(unit.hp)) * heal_ratio)
	_log(_combat_name(unit) + t(" 提高最大生命 ", " gains ") + str(roundi(actual_gain)) + t("，并恢复 ", " max HP and restores ") + str(roundi(restored)) + t(" 点生命。", " HP."))
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_sunshangxiang_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.sunshangxiang.ability_params
	var legacy := bool(unit.get("sun_legacy", false))
	var hit_count := int(params.get("sun_legacy_hit_count", 2)) if legacy else int(params.get("hit_count", 1))
	var mult := float(params.get("sun_legacy_mult", 1.5)) if legacy else float(params.get("mult", 1.0))
	var current_skill := _unit_skill_output_base(unit)
	var visual_group := "sunshangxiang_volley:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for _hit in hit_count:
		if _has_winner():
			break
		var target = _random_living_enemy(unit)
		if target == null:
			var tile := _random_enemy_tile(unit)
			_hit_ruler(unit, current_skill * mult, tile, t("枭姬叠势空击", "Heroine's Volley missed"), visual_group, "rapid_hit")
		else:
			_damage(unit, target, current_skill * mult, "physical", t("枭姬叠势", "Heroine's Growing Volley"), visual_group, "rapid_hit")
	var skill_gain := float(params.get("sun_legacy_skill_gain_per_cast", 2.0)) if legacy else float(params.get("skill_gain_per_cast", 1.0))
	unit.sunshangxiang_skill_bonus = float(unit.get("sunshangxiang_skill_bonus", 0.0)) + skill_gain
	_log(_combat_name(unit) + t(" 技能强度永久提高 ", " permanently gains ") + str(skill_gain) + t(" 点。", " SKILL."))
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_taishici_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.taishici.ability_params
	var candidates := _targets_in_range(unit).filter(func(enemy): return enemy.alive and float(enemy.get("stealth", 0.0)) <= 0.0)
	candidates.sort_custom(func(a, b): return float(a.action) > float(b.action))
	var target_count := int(params.get("sunce_target_count", 3)) if bool(unit.get("sunce_taishi", false)) else int(params.get("target_count", 2))
	if candidates.is_empty():
		var tile := _random_enemy_tile(unit)
		_hit_ruler(unit, _unit_skill_output_base(unit) * float(params.get("mult", 1.50)), tile, t("神亭烈戟空击", "Blazing Halberds missed"))
		return
	var visual_group := "taishici_targets:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for target in candidates.slice(0, mini(target_count, candidates.size())):
		var hit_mult := float(params.get("ganning_burning_mult", 3.0)) if bool(unit.get("taishici_ganning", false)) and float(target.get("burn", 0.0)) > 0.0 else float(params.get("mult", 1.50))
		_damage(unit, target, _unit_skill_output_base(unit) * hit_mult, "physical", t("神亭烈戟", "Blazing Twin Halberds"), visual_group, "multi_target")
		if target.alive:
			_apply_skill_burn(unit, target, float(params.get("burn", 5.0)), _unit_skill_output_base(unit) * float(params.get("burn_ratio", 0.20)))
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _random_enemy_rearguard(unit: Dictionary):
	var targets := _enemy_units(unit.team).filter(func(enemy): return enemy.alive and int(enemy.row) == BOARD_ROWS - 1 and float(enemy.get("stealth", 0.0)) <= 0.0)
	return null if targets.is_empty() else targets[rng.randi_range(0, targets.size() - 1)]

func _ganning_assault_hit(caster: Dictionary, attacker: Dictionary, params: Dictionary, visual_group: String) -> void:
	var target = _random_enemy_rearguard(caster)
	var mult := float(params.get("taishici_mult", 2.50)) if bool(caster.get("taishici_ganning", false)) else float(params.get("mult", 1.50))
	if target != null and bool(caster.get("lvmeng_ganning", false)) and float(target.hp) < float(target.max_hp) * 0.50:
		mult *= 1.0 + float(params.get("lvmeng_low_hp_bonus", 0.50))
	var amount := _unit_skill_output_base(attacker) * mult
	if target == null:
		var tile := {"row":BOARD_ROWS - 1, "col":rng.randi_range(0, BOARD_COLUMNS - 1), "team":_enemy_team_id(caster.team)}
		_hit_ruler(attacker, amount, tile, t("锦帆并击空击", "Bell-Raider Twin Assault missed"), visual_group, "multi_target")
	else:
		_damage(attacker, target, amount, "physical", t("锦帆并击", "Bell-Raider Twin Assault"), visual_group, "multi_target")

func _cast_ganning_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.ganning.ability_params
	var visual_group := "ganning_twin:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	_ganning_assault_hit(unit, unit, params, visual_group)
	var left_ally = _unit_at(_team_units(unit.team), int(unit.row), int(unit.col) - 1)
	if left_ally != null and left_ally.alive and not _has_winner():
		_ganning_assault_hit(unit, left_ally, params, visual_group)
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _finish_sacrifice_death(unit: Dictionary) -> void:
	if not unit.alive or float(unit.hp) > 0.0:
		return
	unit.alive = false
	_on_unit_fallen(unit, null)
	_apply_combo_bonds(false, false)
	_apply_faction_bonuses(false)
	visual_events.append({"kind":"death", "source_id":unit.id, "target_id":unit.id, "amount":0})
	_log("[color=#df7878]" + _hero_name(unit.hero_id) + t(" 因苦肉消耗阵亡！", " falls to the Bitter-Flesh cost!") + "[/color]")

func _cast_huanggai_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.huanggai.ability_params
	var pillars := bool(unit.get("huanggai_sunjian", false))
	var cost_ratio := float(params.get("sunjian_max_hp_cost", 0.15)) if pillars else float(params.get("max_hp_cost", 0.10))
	var requested_cost := float(unit.max_hp) * cost_ratio
	var hp_spent := minf(float(unit.hp), requested_cost)
	unit.hp = maxf(0.0, float(unit.hp) - hp_spent)
	var damage_ratio := float(params.get("sunjian_damage_cost_ratio", 0.45)) if pillars else float(params.get("damage_cost_ratio", 0.33))
	var amount := hp_spent * damage_ratio * _unit_skill_effect_multiplier(unit)
	var col := rng.randi_range(0, BOARD_COLUMNS - 1)
	var target_team := _enemy_team_id(unit.team)
	var visual_group := "huanggai_column:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for row in BOARD_ROWS:
		var tile := {"row":row, "col":col, "team":target_team}
		var target = _unit_at(_enemy_units(unit.team), row, col)
		if target == null:
			_hit_ruler(unit, amount, tile, t("苦肉焚阵空击", "Bitter-Flesh Column missed"), visual_group, "column_impact", false)
			if bool(unit.get("zhouyu_huanggai", false)):
				_set_ground_burn(unit, target_team, row, col, float(params.get("zhouyu_burn", 6.0)), hp_spent * float(params.get("zhouyu_burn_cost_ratio", 0.05)) * _unit_skill_effect_multiplier(unit), visual_group)
		else:
			_damage(unit, target, amount, "physical", t("苦肉焚阵", "Bitter-Flesh Column"), visual_group, "column_impact", false)
			if target.alive and bool(unit.get("zhouyu_huanggai", false)):
				_apply_skill_burn(unit, target, float(params.get("zhouyu_burn", 6.0)), hp_spent * float(params.get("zhouyu_burn_cost_ratio", 0.05)))
	unit.cast_count = int(unit.get("cast_count", 0)) + 1
	_finish_sacrifice_death(unit)

func _cast_dingfeng_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.dingfeng.ability_params
	var target = _highest_action_enemy(unit)
	if target == null:
		var tile := _random_enemy_tile(unit)
		_hit_ruler(unit, _unit_skill_output_base(unit) * float(params.get("mult", 1.30)), tile, t("雪中奋短兵空击", "Snowbound Blades missed"))
		return
	var visual_group := "dingfeng_assault:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	_damage(unit, target, _unit_skill_output_base(unit) * float(params.get("mult", 1.30)), "physical", t("雪中奋短兵", "Snowbound Short Blades"), visual_group, "row_impact")
	if target.alive:
		_reduce_action_bar(unit, target, float(params.get("action_reduction", 25.0)))
	if not bool(unit.get("dingfeng_xusheng", false)):
		return
	var target_team := _enemy_team_id(unit.team)
	for col in [int(target.col) - 1, int(target.col) + 1]:
		if col < 0 or col >= BOARD_COLUMNS:
			continue
		var adjacent = _unit_at(_enemy_units(unit.team), int(target.row), col)
		var amount := _unit_skill_output_base(unit) * float(params.get("bond_splash_mult", 0.70))
		if adjacent == null:
			_hit_ruler(unit, amount, {"row":target.row, "col":col, "team":target_team}, t("短兵突击空击", "Short-blade follow-up missed"), visual_group, "row_impact")
		else:
			_damage(unit, adjacent, amount, "physical", t("短兵突击", "Short-blade Follow-up"), visual_group, "row_impact")
			if adjacent.alive:
				_reduce_action_bar(unit, adjacent, float(params.get("bond_splash_action_reduction", 15.0)))

func _random_unique_living_enemies(unit: Dictionary, count: int, row := -1) -> Array:
	var candidates := _enemy_units(unit.team).filter(func(enemy):
		return enemy.alive and float(enemy.get("stealth", 0.0)) <= 0.0 and (row < 0 or int(enemy.row) == row)
	)
	var result: Array = []
	for _index in mini(count, candidates.size()):
		var picked := rng.randi_range(0, candidates.size() - 1)
		result.append(candidates[picked])
		candidates.remove_at(picked)
	return result

func _apply_skill_stun(source: Dictionary, target: Dictionary, duration: float) -> void:
	if target == null or not target.alive or duration <= 0.0: return
	var actual := duration * _unit_effect_multiplier(source) * _control_duration_multiplier(source)
	target.stun = maxf(float(target.stun), actual)
	_add_stat(source, "control", actual)

func _cast_caocao_command(unit: Dictionary) -> void:
	var params: Dictionary = heroes.caocao.ability_params
	var has_dianwei := _pair_active(unit.team, "caocao", "dianwei")
	var has_xuchu := _pair_active(unit.team, "caocao", "xuchu")
	var target_count := int(params.get("target_count", 2))
	if has_dianwei: target_count += int(params.get("bond_bonus_targets", 1))
	if has_xuchu: target_count += int(params.get("bond_bonus_targets", 1))
	var targets := _random_unique_living_enemies(unit, target_count)
	var base := _unit_skill_output_base(unit) * float(params.get("mult", 2.0))
	var visual_group := "caocao_command:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	if targets.is_empty():
		_hit_ruler(unit, base, _random_enemy_tile(unit), t("魏武震慑空击", "Dominion Stun missed"), visual_group, "multi_target")
	for target in targets:
		var favored := (has_dianwei and int(target.row) == BOARD_ROWS - 1) or (has_xuchu and int(target.row) == 0)
		var amount := base * (float(params.get("favored_row_mult", 2.0)) if favored else 1.0)
		_damage(unit, target, amount, "physical", t("魏武震慑", "Dominion Stun"), visual_group, "multi_target")
		_apply_skill_stun(unit, target, float(params.get("stun", 2.5)) * (float(params.get("favored_row_stun_mult", 2.0)) if favored else 1.0))
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _wei_pair_count(team: String, hero_id: String, partners: Array) -> int:
	var count := 0
	for partner in partners:
		if _pair_active(team, hero_id, str(partner)): count += 1
	return count

func _cast_xiahouyuan_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.xiahouyuan.ability_params
	var bond_count := _wei_pair_count(unit.team, "xiahouyuan", ["caoren", "xiahoudun"])
	var stun_duration := float(params.get("stun", 1.5)) + 0.5 * bond_count
	var targets := _random_unique_living_enemies(unit, int(params.get("target_count", 2)))
	var visual_group := "xiahouyuan_suppression:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	if targets.is_empty():
		_hit_ruler(unit, _unit_skill_output_base(unit) * float(params.get("mult", 1.75)), _random_enemy_tile(unit), t("神速震袭空击", "Swift Suppression missed"), visual_group, "multi_target")
	for target in targets:
		var was_stunned := float(target.stun) > 0.0
		var mult := float(params.get("stunned_mult", 2.50)) if was_stunned else float(params.get("mult", 1.75))
		_damage(unit, target, _unit_skill_output_base(unit) * mult, "physical", t("神速震袭", "Swift Suppression"), visual_group, "multi_target")
		_apply_skill_stun(unit, target, stun_duration)
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_caoren_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.caoren.ability_params
	var bond_count := _wei_pair_count(unit.team, "caoren", ["xiahouyuan", "xiahoudun"])
	var target_count := int(params.get("target_count", 2)) + bond_count
	var stun_duration := float(params.get("stun", 1.5)) + 0.5 * bond_count
	var targets := _random_unique_living_enemies(unit, target_count, BOARD_ROWS - 1)
	var visual_group := "caoren_rear_guard:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for target in targets:
		_damage(unit, target, _unit_skill_output_base(unit) * float(params.get("mult", 1.50)), "physical", t("樊城镇远", "Rearward Bulwark"), visual_group, "multi_target")
		_apply_skill_stun(unit, target, stun_duration)
	unit.rear_damage_reduction = (float(params.get("rear_reduction", 0.20)) + 0.10 * bond_count) * _unit_skill_effect_multiplier(unit)
	unit.rear_damage_reduction_time = float(params.get("guard_time", 6.0))
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_xiahoudun_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.xiahoudun.ability_params
	var bond_count := _wei_pair_count(unit.team, "xiahoudun", ["xiahouyuan", "caoren"])
	var target_count := int(params.get("target_count", 2)) + bond_count
	var stun_duration := float(params.get("stun", 1.5)) + 0.5 * bond_count
	var targets := _random_unique_living_enemies(unit, target_count, 0)
	var visual_group := "xiahoudun_front_guard:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for target in targets:
		_damage(unit, target, _unit_skill_output_base(unit) * float(params.get("mult", 1.50)), "physical", t("刚烈镇前", "Vanguard Bulwark"), visual_group, "multi_target")
		_apply_skill_stun(unit, target, stun_duration)
	unit.front_damage_reduction = (float(params.get("front_reduction", 0.20)) + 0.10 * bond_count) * _unit_skill_effect_multiplier(unit)
	unit.front_damage_reduction_time = float(params.get("guard_time", 6.5))
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_simayi_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.simayi.ability_params
	var bond_count := _wei_pair_count(unit.team, "simayi", ["guojia", "xunyu", "jiaxu"])
	var targets := _random_unique_living_enemies(unit, int(params.get("target_count", 2)) + bond_count)
	var mult := float(params.get("mult", 1.75)) + 0.25 * bond_count
	var visual_group := "simayi_thunder:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	if targets.is_empty(): _hit_ruler(unit, _unit_skill_output_base(unit) * mult, _random_enemy_tile(unit), t("雷霆谋断空击", "Thunder Judgment missed"), visual_group, "multi_target")
	for target in targets:
		_damage(unit, target, _unit_skill_output_base(unit) * mult, "magic", t("雷霆谋断", "Thunder Judgment"), visual_group, "multi_target")
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_guojia_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.guojia.ability_params
	var bond_count := _wei_pair_count(unit.team, "guojia", ["simayi", "xunyu", "jiaxu"])
	var targets := _random_unique_living_enemies(unit, int(params.get("target_count", 2)) + bond_count)
	var duration := float(params.get("freeze", 4.0)) * _unit_effect_multiplier(unit) * _control_duration_multiplier(unit)
	var visual_group := "guojia_freeze:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for target in targets:
		target.freeze = maxf(float(target.get("freeze", 0.0)), duration)
		target.freeze_shatter_per_second = float(params.get("shatter_per_second", 400.0)) * _unit_skill_effect_multiplier(unit)
		_add_stat(unit, "control", duration)
		visual_events.append({"kind":"skill", "source_id":unit.id, "target_id":target.id, "amount":roundi(duration * 10.0), "style":"magic", "visual_group":visual_group, "group_style":"simultaneous"})
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _random_unique_living_allies(unit: Dictionary, count: int) -> Array:
	var candidates := _team_units(unit.team).filter(func(ally): return ally.alive)
	var result: Array = []
	for _index in mini(count, candidates.size()):
		var picked := rng.randi_range(0, candidates.size() - 1)
		result.append(candidates[picked])
		candidates.remove_at(picked)
	return result

func _cast_xunyu_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.xunyu.ability_params
	var bond_count := _wei_pair_count(unit.team, "xunyu", ["simayi", "guojia", "jiaxu"])
	var targets := _random_unique_living_allies(unit, int(params.get("target_count", 2)) + bond_count)
	var visual_group := "xunyu_haste:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for target in targets:
		target.timed_action_bonus = maxf(float(target.get("timed_action_bonus", 0.0)), float(params.get("action_bonus", 0.20)) * _unit_skill_effect_multiplier(unit))
		target.timed_action_time = maxf(float(target.get("timed_action_time", 0.0)), float(params.get("duration", 6.0)))
		visual_events.append({"kind":"skill", "source_id":unit.id, "target_id":target.id, "amount":20, "style":"magic", "nonblocking":true, "visual_group":visual_group, "group_style":"simultaneous"})
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_jiaxu_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.jiaxu.ability_params
	var bond_count := _wei_pair_count(unit.team, "jiaxu", ["simayi", "guojia", "xunyu"])
	var targets := _random_unique_living_enemies(unit, int(params.get("target_count", 2)) + bond_count)
	var duration := float(params.get("duration", 5.0)) + 0.5 * bond_count
	var visual_group := "jiaxu_poison:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for target in targets:
		target.poison = maxf(float(target.get("poison", 0.0)), duration)
		target.poison_ratio = float(params.get("poison_ratio", 0.01)) * _unit_skill_effect_multiplier(unit)
		target.poison_clock = 0.0
		target.poison_source = unit.id
		visual_events.append({"kind":"skill", "source_id":unit.id, "target_id":target.id, "amount":roundi(duration * 10.0), "style":"magic", "visual_group":visual_group, "group_style":"poison_apply"})
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_liubei_regen(unit: Dictionary) -> void:
	var params: Dictionary = heroes[unit.hero_id].ability_params
	var allies := _team_units(unit.team).filter(func(ally): return ally.alive)
	allies.sort_custom(func(a, b): return float(a.hp) / maxf(1.0, float(a.max_hp)) < float(b.hp) / maxf(1.0, float(b.max_hp)))
	var target = allies[0] if not allies.is_empty() else null
	var row := int(target.row) if target != null else rng.randi_range(0, BOARD_ROWS - 1)
	var col := int(target.col) if target != null else rng.randi_range(0, BOARD_COLUMNS - 1)
	var duration := float(params.get("duration", 4.0)) * (1.5 if _pair_active(unit.team, "liubei", "liushan") else 1.0)
	var heal_ratio := 3.0 if _roster_has_all(_team_units(unit.team), ["liubei", "guanyu", "zhangfei"]) else float(params.get("heal_ratio", 2.0))
	var base_heal: float = float(params.get("base_value", _unit_skill_output_base(unit)))
	var heal_per_second := base_heal * _unit_skill_effect_multiplier(unit) * heal_ratio
	var magic_reduction := 0.20 * _unit_skill_effect_multiplier(unit) if _pair_active(unit.team, "liubei", "zhugeliang") else 0.0
	if target == null:
		ruler_regen[unit.team] = {"amount":heal_per_second, "time":duration, "clock":0.0, "source":unit.id, "magic_reduction":magic_reduction}
		visual_events.append({"kind":"heal", "source_id":unit.id, "target_id":"", "team":unit.team, "row":row, "col":col, "amount":round(heal_per_second), "ruler":true, "style":"heal"})
	else:
		target.regen_per_second = heal_per_second
		target.regen_time = duration
		target.regen_clock = 0.0
		target.regen_source = unit.id
		target.regen_magic_reduction = magic_reduction
		visual_events.append({"kind":"regen_apply", "source_id":unit.id, "target_id":target.id, "amount":0, "style":"heal"})

func _cast_liushan_command(unit: Dictionary) -> void:
	var params: Dictionary = heroes.liushan.ability_params
	var damage_by_star: Array = params.get("damage_by_star", [0.25, 0.35, 0.55])
	var buff: float = float(damage_by_star[0]) * _unit_skill_effect_multiplier(unit)
	var duration := float(params.get("duration", 4.0))
	var extend_to_backline := _pair_active(unit.team, "liushan", "liubei")
	var seven_charges := _pair_active(unit.team, "liushan", "zhaoyun")
	var visual_group := "liushan_buff:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for ally in _team_units(unit.team):
		if not ally.alive or ally.col != unit.col: continue
		if ally.row != 0 and not (extend_to_backline and ally.row == BOARD_ROWS - 1): continue
		ally.timed_damage_buff = max(float(ally.get("timed_damage_buff", 0.0)), buff)
		ally.timed_damage_time = max(float(ally.get("timed_damage_time", 0.0)), duration)
		if seven_charges:
			ally.all_lifesteal = max(float(ally.get("all_lifesteal", 0.0)), float(params.get("seven_lifesteal", 0.30)) * _unit_skill_effect_multiplier(unit))
			ally.all_lifesteal_time = max(float(ally.get("all_lifesteal_time", 0.0)), duration)
		visual_events.append({"kind":"skill", "source_id":unit.id, "target_id":ally.id, "amount":round(buff * 100.0), "style":"magic", "visual_group":visual_group, "group_style":"simultaneous"})

func _cast_zhangfei_command(unit: Dictionary) -> void:
	var params: Dictionary = heroes[unit.hero_id].ability_params
	var damage_by_star: Array = params.get("damage_by_star", [0.15, 0.20, 0.30])
	if damage_by_star.is_empty(): damage_by_star = [0.15, 0.20, 0.30]
	var buff: float = float(damage_by_star[0]) * _unit_skill_effect_multiplier(unit)
	var duration := 6.0 if _roster_has_count(_team_units(unit.team), ["guanyu", "zhangfei", "zhaoyun", "huangzhong", "machao"], 5) else float(params.get("duration", 3.0))
	var peach := _roster_has_all(_team_units(unit.team), ["liubei", "guanyu", "zhangfei"])
	var visual_group := "zhangfei_buff:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for ally in _team_units(unit.team):
		if not ally.alive or ally.row != 0: continue
		ally.timed_damage_buff = max(float(ally.get("timed_damage_buff", 0.0)), buff)
		ally.timed_damage_time = max(float(ally.get("timed_damage_time", 0.0)), duration)
		if peach:
			ally.timed_reduction = max(float(ally.get("timed_reduction", 0.0)), 0.20 * _unit_skill_effect_multiplier(unit))
			ally.timed_reduction_time = max(float(ally.get("timed_reduction_time", 0.0)), duration)
		visual_events.append({"kind":"skill", "source_id":unit.id, "target_id":ally.id, "amount":round(buff * 100.0), "style":"magic", "visual_group":visual_group, "group_style":"simultaneous"})

func _cast_zhaoyun_empower(unit: Dictionary) -> void:
	var params: Dictionary = heroes[unit.hero_id].ability_params
	var five_tigers := _roster_has_count(_team_units(unit.team), ["guanyu", "zhangfei", "zhaoyun", "huangzhong", "machao"], 5)
	var seven_charges := _pair_active(unit.team, "zhaoyun", "liushan")
	var hit_mults: Array
	if seven_charges and five_tigers:
		hit_mults = params.get("seven_charge_mults", [])
	elif seven_charges:
		hit_mults = params.get("seven_base_mults", [])
	elif five_tigers:
		hit_mults = params.get("five_tiger_mults", [])
	else:
		hit_mults = params.get("hit_mults", [])
	if hit_mults.is_empty(): hit_mults = [0.50, 0.50, 0.50, 0.50, 0.50]
	var candidates: Array
	if seven_charges:
		candidates = _enemy_units(unit.team).filter(func(enemy): return enemy.alive and int(enemy.row) == BOARD_ROWS - 1 and float(enemy.get("stealth", 0.0)) <= 0.0)
	else:
		candidates = _targets_in_range(unit).filter(func(enemy): return enemy.alive)
	var target = candidates[rng.randi_range(0, candidates.size() - 1)] if not candidates.is_empty() else null
	var target_row: int = BOARD_ROWS - 1 if seven_charges else int(_attackable_rows(unit)[0] if not _attackable_rows(unit).is_empty() else 0)
	var target_col := int(target.col) if target != null else rng.randi_range(0, BOARD_COLUMNS - 1)
	if target != null: target_row = int(target.row)
	var target_team := _enemy_team_id(unit.team)
	var visual_group := "zhaoyun_rapid:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for hit_mult in hit_mults:
		var amount := _unit_skill_output_base(unit) * float(hit_mult)
		if target == null:
			_hit_ruler(unit, amount, {"row":target_row, "col":target_col, "team":target_team}, t("龙胆连刺空击", "Dragon Spear missed"), visual_group, "spear_rapid")
		elif target.alive:
			_damage(unit, target, amount, "physical", t("龙胆连刺", "Dragon Spear"), visual_group, "spear_rapid")
	for event in visual_events:
		if str(event.get("visual_group", "")) == visual_group:
			event["rapid_hits"] = hit_mults.size()

func _cast_huangzhong_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes[unit.hero_id].ability_params
	var five_tigers := _roster_has_count(_team_units(unit.team), ["guanyu", "zhangfei", "zhaoyun", "huangzhong", "machao"], 5)
	var base: float = _unit_skill_output_base(unit)
	var dmg_mult := 5.0 if five_tigers else float(params.get("active_mult", 2.0))
	var flying_critical := bool(unit.get("flying_meteor", false)) and rng.randf() < 0.50
	if flying_critical: dmg_mult *= 2.0
	var tile: Dictionary
	if five_tigers:
		var col := rng.randi_range(0, BOARD_COLUMNS - 1)
		tile = {"row":0, "col":col, "team":_enemy_team_id(unit.team), "target":_unit_at(_enemy_units(unit.team), 0, col)}
	else: tile = _random_enemy_tile(unit)
	if tile.target == null:
		_hit_ruler(unit, base * dmg_mult, tile, t("百步穿杨暴击空击", "Piercing Arrow critical missed") if flying_critical else t("百步穿杨空击", "Piercing Arrow missed"))
	else:
		_damage(unit, tile.target, base * dmg_mult, "physical", t("百步穿杨暴击", "Piercing Arrow critical") if flying_critical else t("百步穿杨", "Piercing Arrow"))

func _cast_machao_pierce(unit: Dictionary) -> void:
	var enemies := _enemy_units(unit.team).filter(func(enemy): return enemy.alive)
	var target_col := clampi(int(unit.col), 0, BOARD_COLUMNS - 1)
	if not enemies.is_empty():
		enemies.sort_custom(func(a, b): return float(a.hp) < float(b.hp))
		target_col = int(enemies[0].col)
	var params: Dictionary = heroes.machao.ability_params
	var row_multipliers := [
		float(params.get("front_mult", 2.0)),
		float(params.get("middle_mult", 1.7)),
		float(params.get("back_mult", 1.4))
	]
	if bool(unit.get("one_rider", false)): row_multipliers = [2.0, 2.0, 2.0]
	var visual_group := "machao_column:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	var target_team := _enemy_team_id(unit.team)
	for row in BOARD_ROWS:
		var amount := _unit_skill_output_base(unit) * float(row_multipliers[row])
		var target = _unit_at(_enemy_units(unit.team), row, target_col)
		if target == null:
			_hit_ruler(unit, amount, {"row":row, "col":target_col, "team":target_team}, t("铁骑贯阵空击", "Iron Cavalry missed"), visual_group, "spear_column")
		else:
			_damage(unit, target, amount, "physical", t("铁骑贯阵", "Iron Cavalry"), visual_group, "spear_column")

func _cast_madai_execution(unit: Dictionary) -> void:
	var front_targets := _enemy_units(unit.team).filter(func(enemy): return enemy.alive and int(enemy.row) == 0 and float(enemy.get("stealth", 0.0)) <= 0.0)
	var params: Dictionary = heroes.madai.ability_params
	if front_targets.is_empty():
		var ruler_damage_by_star: Array = params.get("empty_ruler_damage_by_star", [1000.0, 1500.0, 2000.0])
		var ruler_damage := float(ruler_damage_by_star[0]) * _unit_skill_effect_multiplier(unit)
		var empty_tile := {"row":0, "col":rng.randi_range(0, BOARD_COLUMNS - 1), "team":_enemy_team_id(unit.team), "target":null}
		_hit_ruler(unit, ruler_damage / maxf(0.01, float(unit.get("stat_mult", 1.0))), empty_tile, t("斩将突袭空格追主", "Execution Raid ruler strike"), "", "", false)
		return
	var target: Dictionary = front_targets[rng.randi_range(0, front_targets.size() - 1)]
	var ratios: Array = params.get("max_hp_ratios", [0.60, 0.70, 0.85])
	var damage := float(target.max_hp) * float(ratios[0]) * _unit_skill_effect_multiplier(unit)
	_damage(unit, target, damage, "physical", t("斩将突袭", "Execution Raid"), "", "", false)
	if target.alive and bool(unit.get("fated_enemies", false)):
		target.vulnerable = max(float(target.get("vulnerable", 0.0)), float(params.get("vulnerable", 0.40)) * _unit_skill_effect_multiplier(unit))
		target.vulnerable_time = max(float(target.get("vulnerable_time", 0.0)), float(params.get("vulnerable_time", 15.0)))
		visual_events.append({"kind":"skill", "source_id":unit.id, "target_id":target.id, "amount":40, "style":"magic"})

func _cast_weiyan_cleave(unit: Dictionary) -> void:
	var params: Dictionary = heroes.weiyan.ability_params
	var damage_dealt := 0.0
	var visual_group := "weiyan_cleave:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	var amount := _unit_skill_output_base(unit) * float(params.get("mult", 1.8))
	var target_team := _enemy_team_id(unit.team)
	for col in range(maxi(0, int(unit.col) - 1), mini(BOARD_COLUMNS - 1, int(unit.col) + 1) + 1):
		var target = _unit_at(_enemy_units(unit.team), 0, col)
		if target == null:
			_hit_ruler(unit, amount, {"row":0, "col":col, "team":target_team}, t("狂骨横斩空击", "Rebel Fang missed"), visual_group, "row_impact")
		else:
			damage_dealt += _damage(unit, target, amount, "physical", t("狂骨横斩", "Rebel Fang"), visual_group, "row_impact")
	if damage_dealt > 0.0:
		_heal_unit_only(unit, unit, damage_dealt * float(params.get("self_heal", 0.40)) * _unit_skill_effect_multiplier(unit))
	if bool(unit.get("fated_enemies", false)):
		for ally in _team_units(unit.team):
			if not ally.alive or ally.id == unit.id: continue
			var adjacent_same_row: bool = int(ally.row) == int(unit.row) and abs(int(ally.col) - int(unit.col)) == 1
			var rearward_midguard: bool = int(ally.col) == int(unit.col) and int(ally.row) > int(unit.row) and int(heroes[ally.hero_id].range) == 2
			if adjacent_same_row or rearward_midguard:
				_heal_unit_only(unit, ally, float(ally.max_hp) * float(params.get("ally_heal", 0.15)) * _unit_skill_effect_multiplier(unit))

func _after_active_skill(unit: Dictionary) -> void:
	if unit.hero_id == "sunce" and bool(unit.get("sunce_daqiao", false)):
		_heal_unit_only(unit, unit, float(unit.max_hp) * 0.12)

func _cast_generic_ability(unit: Dictionary) -> void:
	var hero: Dictionary = heroes[unit.hero_id]
	var ability: String = hero.get("ability", "")
	var params: Dictionary = hero.get("ability_params", {})
	var effect_mult := _unit_skill_effect_multiplier(unit)
	var base_value: float = float(params.get("base_value", 50.0))  # 预计算的固定伤害值
	if ability in ["strike", "strike_magic", "drain", "control"]:
		if float(params.get("stealth", 0.0)) > 0.0:
			unit.stealth = max(float(unit.stealth), float(params.stealth))
		var tile := _ability_enemy_tile(unit, params)
		var target = tile.target
		if target == null:
			_hit_ruler(unit, base_value, tile, hero.zh_skill if language == "zh" else hero.skill)
			return
		var mult: float = 1.0  # 固定值基础上的额外倍率(条件加成)
		if int(unit.get("cast_count", 0)) == 0: mult *= float(params.get("first_mult", 1.0))
		if unit.hero_id == "xiaoqiao" and bool(unit.get("zhouyu_xiaoqiao", false)) and float(target.get("burn", 0.0)) > 0.0: mult *= 1.30
		if (target.stun > 0 or target.charm > 0) and float(params.get("bonus_controlled", 0.0)) > 0.0: mult += float(params.bonus_controlled)
		if target.shield > 0.0: mult *= 1.0 + float(params.get("shield_break", 0.0))
		if target.burn > 0.0 and float(params.get("bonus_burning", 0.0)) > 0.0: mult += float(params.bonus_burning)
		if params.get("focus", false):
			if str(unit.get("focus_target", "")) == str(target.id): unit.focus_stacks = min(4, int(unit.get("focus_stacks", 0)) + 1)
			else:
				unit.focus_target = target.id
				unit.focus_stacks = 1
			if rng.randf() < float(unit.focus_stacks) * 0.08: mult *= 1.60
		if unit.hero_id == "madai" and target.hp < target.max_hp: mult = 2.25
		if unit.hero_id == "lvmeng" and int(heroes[target.hero_id].range) >= 3: mult *= 1.20
		var dealt := _damage(unit, target, base_value * mult, "magic" if ability == "strike_magic" or ability == "control" else "physical", hero.zh_skill if language == "zh" else hero.skill)
		if float(params.get("vulnerable", 0.0)) > 0.0:
			target.vulnerable = max(float(target.vulnerable), float(params.vulnerable) * effect_mult)
			target.vulnerable_time = max(float(target.vulnerable_time), float(params.get("vulnerable_time", 4.0)))
		if float(params.get("silence", 0.0)) > 0.0: target.silence = max(float(target.silence), float(params.silence) * _control_duration_multiplier(unit))
		if float(params.get("action_refund", 0.0)) > 0.0: unit.action = min(ACTION_MAX, float(unit.action) + float(params.action_refund))
		if ability == "drain" and dealt > 0:
			var drain_ratio := float(params.get("heal", 0.25))
			_heal_with_overflow(unit, unit, dealt * min(0.75, drain_ratio * effect_mult))
		if float(params.get("stun", 0.0)) > 0 and target.alive:
			var control_time: float = float(params.stun) * _control_duration_multiplier(unit)
			if unit.hero_id == "xiaoqiao" and bool(unit.get("zhouyu_xiaoqiao", false)) and float(target.get("burn", 0.0)) > 0.0: control_time *= 1.50
			target.stun = max(float(target.stun), control_time)
			_add_stat(unit, "control", control_time)
		if float(params.get("burn", 0.0)) > 0 and target.alive:
			target.burn = float(params.burn)
			target.burn_damage = float(params.get("burn_per_sec", 15.0)) * effect_mult * float(unit.get("burn_multiplier", 1.0))
			target.burn_missing_hp_scale = false
	elif ability in ["row", "row_magic"]:
		if float(params.get("self_cost", 0.0)) > 0:
			var self_cost := float(params.self_cost)
			unit.hp = max(1.0, unit.hp - unit.hp * self_cost)
		var skill_rows := _attackable_rows(unit)
		var row: int = skill_rows[rng.randi_range(0, skill_rows.size() - 1)]
		var target_team := _enemy_team_id(unit.team)
		var visual_group := "row:" + str(unit.hero_id) + ":" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
		var row_mult: float = 1.0
		if float(params.get("fallen_scale", 0.0)) > 0.0:
			row_mult *= 1.0 + _team_units(unit.team).filter(func(ally): return not ally.alive).size() * float(params.fallen_scale)
		for col in BOARD_COLUMNS:
			var tile := {"row":row, "col":col, "team":target_team}
			var target = _unit_at(_enemy_units(unit.team), row, col)
			if target == null:
				_hit_ruler(unit, base_value * row_mult, tile, hero.zh_skill if language == "zh" else hero.skill, visual_group, "row_impact")
			else:
				_damage(unit, target, base_value * row_mult, "magic" if ability == "row_magic" else "physical", hero.zh_skill if language == "zh" else hero.skill, visual_group, "row_impact")
				if str(params.get("mark", "")) == "strategy": target.strategy_mark = float(params.get("mark_time", 4.0))
				if float(params.get("burn", 0.0)) > 0.0:
					target.burn = max(float(target.burn), float(params.burn))
					target.burn_damage = float(params.get("burn_per_sec", 15.0)) * effect_mult * float(unit.get("burn_multiplier", 1.0))
					target.burn_missing_hp_scale = false
				if float(params.get("slow", 0.0)) > 0.0:
					target.slow = max(float(target.slow), float(params.slow) * effect_mult)
					target.slow_time = max(float(target.slow_time), float(params.get("slow_time", 4.0)) * _control_duration_multiplier(unit))
				if float(params.get("stun", 0.0)) > 0 and target.alive:
					var row_control: float = float(params.stun) * _control_duration_multiplier(unit)
					target.stun = max(float(target.stun), row_control)
					_add_stat(unit, "control", row_control)
	elif ability in ["multi", "multi_magic"]:
		for _shot in int(params.get("count", 2)) + int(unit.get("multi_bonus", 0)):
			var tile := _ability_enemy_tile(unit, params)
			if tile.target == null: _hit_ruler(unit, base_value, tile, hero.zh_skill if language == "zh" else hero.skill)
			else: _damage(unit, tile.target, base_value, "magic" if ability == "multi_magic" else "physical", hero.zh_skill if language == "zh" else hero.skill)
	elif ability == "heal":
		var heal_base: float = float(params.get("base_heal", 80.0)) * _unit_skill_power_multiplier(unit)
		_heal_weakest_fixed(unit, heal_base, 0.0)
		for _extra in int(unit.get("heal_extra_targets", 0)):
			_heal_weakest_fixed(unit, heal_base * 0.65, 0.0)
	elif ability == "heal_team":
		for ally in _team_units(unit.team):
			if not ally.alive: continue
			_heal_with_overflow(unit, ally, ally.max_hp * float(params.get("ratio", 0.10)) * effect_mult)
			ally.skill_debuff = 0.0
	elif ability in ["shield_single", "shield_row", "shield_column"]:
		var allies := _team_units(unit.team).filter(func(ally): return ally.alive)
		allies.sort_custom(func(a, b): return float(a.hp) / float(a.max_hp) < float(b.hp) / float(b.max_hp))
		var shield_targets: Array = []
		if ability == "shield_single" and not allies.is_empty(): shield_targets = [allies[0]]
		elif ability == "shield_row": shield_targets = allies.filter(func(ally): return ally.row == unit.row)
		elif ability == "shield_column": shield_targets = allies.filter(func(ally): return ally.col == unit.col)
		var shield_value: float = float(params.get("base_shield", 60.0)) * float(unit.get("stat_mult", 1.0)) * _unit_skill_power_multiplier(unit)
		for ally in shield_targets:
			_grant_shield(ally, shield_value)
			if int(params.get("spell_ward", 0)) > 0: ally.spell_ward = max(int(ally.get("spell_ward", 0)), int(params.spell_ward))
			visual_events.append({"kind":"heal", "source_id":unit.id, "target_id":ally.id, "amount":round(shield_value), "style":"shield"})
		if unit.hero_id == "caoren": unit.damage_reduction = max(float(unit.damage_reduction), 0.10 * _unit_skill_effect_multiplier(unit))
	elif ability.begins_with("buff_"):
		var faction_count := 1
		if params.get("faction_scale", false):
			var counts := {}
			for ally in _team_units(unit.team): counts[heroes[ally.hero_id].f] = int(counts.get(heroes[ally.hero_id].f, 0)) + 1
			faction_count = min(4, counts.values().filter(func(count): return count >= 2).size())
		var buff_targets := _team_units(unit.team).filter(func(ally): return ally.alive)
		buff_targets.sort_custom(func(a, b): return float(a.hp) / float(a.max_hp) < float(b.hp) / float(b.max_hp))
		if ability == "buff_single": buff_targets = buff_targets.slice(0, min(1, buff_targets.size()))
		elif ability == "buff_two": buff_targets = buff_targets.slice(0, min(2, buff_targets.size()))
		elif ability == "buff_column": buff_targets = buff_targets.filter(func(ally): return ally.col == unit.col)
		elif ability == "buff_row_ranged": buff_targets = buff_targets.filter(func(ally): return ally.row == unit.row and int(heroes[ally.hero_id].range) > 2)
		elif ability == "buff_row_melee": buff_targets = buff_targets.filter(func(ally): return ally.row == unit.row and int(heroes[ally.hero_id].range) <= 2)
		elif ability == "buff_self": buff_targets = [unit]
		for ally in buff_targets:
			var damage_bonus: float = float(params.get("damage", 0.0)) * effect_mult * faction_count
			ally.damage_buff = max(float(ally.damage_buff), damage_bonus)
			ally.action_gain_mult = max(float(ally.action_gain_mult), 1.0 + float(params.get("action", 0.0)) * effect_mult)
			if float(params.get("heal_ratio", 0.0)) > 0.0:
				var heal_ratio := float(params.heal_ratio)
				_heal_with_overflow(unit, ally, ally.max_hp * heal_ratio * effect_mult * float(unit.get("heal_multiplier", 1.0)))
	else:
		_log(_hero_name(unit.hero_id) + t(" 的技能机制尚未配置。", "'s skill mechanic is not configured."))
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _zhugeliang_affected_tiles(center_row: int, center_col: int, include_horizontal: bool, include_diagonal: bool) -> Array:
	var offsets: Array = [[0, 0], [-1, 0], [1, 0]]
	if include_horizontal:
		offsets.append_array([[0, -1], [0, 1]])
	if include_diagonal:
		offsets.append_array([[-1, -1], [-1, 1], [1, -1], [1, 1]])
	var tiles: Array = []
	var seen := {}
	for offset in offsets:
		var row := center_row + int(offset[0])
		var col := center_col + int(offset[1])
		if row < 0 or row >= BOARD_ROWS or col < 0 or col >= BOARD_COLUMNS:
			continue
		var key := str(row) + ":" + str(col)
		if seen.has(key):
			continue
		seen[key] = true
		tiles.append({"row":row, "col":col})
	return tiles

func _cast_zhugeliang_skill(unit: Dictionary) -> void:
	_cast_zhugeliang_area_at(unit, rng.randi_range(0, BOARD_ROWS - 1), rng.randi_range(0, BOARD_COLUMNS - 1))

func _cast_zhugeliang_area_at(unit: Dictionary, center_row: int, center_col: int) -> void:
	var params: Dictionary = heroes.zhugeliang.ability_params
	var has_pangtong := _pair_active(unit.team, "zhugeliang", "pangtong")
	var has_jiangwei := _pair_active(unit.team, "zhugeliang", "jiangwei")
	var has_menghuo := _pair_active(unit.team, "zhugeliang", "menghuo")
	var has_liubei := _pair_active(unit.team, "zhugeliang", "liubei")
	var tiles := _zhugeliang_affected_tiles(center_row, center_col, has_pangtong, has_jiangwei)
	var enemies := _enemy_units(unit.team)
	var affected_unit_count := 0
	for tile in tiles:
		if _unit_at(enemies, int(tile.row), int(tile.col)) != null:
			affected_unit_count += 1
	var cast_multiplier := 1.0
	if has_menghuo:
		cast_multiplier *= 1.0 + float(params.get("menghuo_damage_bonus", 0.20))
	if has_liubei:
		cast_multiplier *= 1.0 + max(0, affected_unit_count - 1) * float(params.get("liubei_extra_target_bonus", 0.10))
	var base_damage := float(params.get("base_value", _unit_skill_output_base(unit))) * cast_multiplier
	var target_team := _enemy_team_id(unit.team)
	var visual_group := "zhugeliang_area:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for tile in tiles:
		var row := int(tile.row)
		var col := int(tile.col)
		var target = _unit_at(enemies, row, col)
		if target == null:
			_hit_ruler(unit, base_damage, {"row":row, "col":col, "team":target_team}, t("八阵奇谋空击", "Eight-Formation empty strike"), visual_group, "area_impact")
			continue
		var marked_before := bool(target.get("zhuge_fire_mark", false))
		var damage := base_damage * (1.0 + float(params.get("fire_mark_bonus", 0.30)) if has_menghuo and marked_before else 1.0)
		_damage(unit, target, damage, "magic", t("八阵奇谋", "Eight-Formation Stratagem"), visual_group, "area_impact")
		if has_menghuo and target.alive:
			target.zhuge_fire_mark = true

func _pair_active(team: String, first: String, second: String) -> bool:
	var units := _team_units(team)
	return units.any(func(unit): return unit.alive and unit.hero_id == first) and units.any(func(unit): return unit.alive and unit.hero_id == second)

func _cast_guanyu_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes[unit.hero_id].ability_params
	var tile := _random_enemy_tile(unit)
	var base: float = float(params.get("base_value", _unit_skill_output_base(unit)))
	var peach := _roster_has_all(_team_units(unit.team), ["liubei", "guanyu", "zhangfei"])
	var five_tigers := _roster_has_count(_team_units(unit.team), ["guanyu", "zhangfei", "zhaoyun", "huangzhong", "machao"], 5)
	var skill_mult := 3.0 if five_tigers else float(params.get("mult", 1.8))
	var damage_dealt := 0.0
	var visual_group := "guanyu_column:" + str(unit.id)
	var target_col := int(tile.col)
	for row in BOARD_ROWS:
		var target = _unit_at(_enemy_units(unit.team), row, target_col)
		if target == null:
			_hit_ruler(unit, base * skill_mult, {"row":row, "col":target_col, "team":tile.team}, t("青龙断阵空击", "Green Dragon empty strike"), visual_group, "column_impact")
		else:
			damage_dealt += _damage(unit, target, base * skill_mult, "physical", t("青龙断阵", "Green Dragon Cleave"), visual_group, "column_impact")
	if damage_dealt > 0.0 and peach:
		_heal_with_overflow(unit, unit, damage_dealt * 0.30)

func _cast_dianwei_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.dianwei.ability_params
	var target_count := int(params.get("target_count", 2)) + (int(params.get("caocao_bonus_targets", 1)) if _pair_active(unit.team, "dianwei", "caocao") else 0)
	var mult := float(params.get("xuchu_mult", 4.0)) if _pair_active(unit.team, "dianwei", "xuchu") else float(params.get("mult", 2.0))
	var targets := _random_unique_living_enemies(unit, target_count, BOARD_ROWS - 1)
	var visual_group := "dianwei_rear:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	if targets.is_empty():
		_hit_ruler(unit, _unit_skill_output_base(unit) * mult, {"row":BOARD_ROWS - 1, "col":rng.randi_range(0, BOARD_COLUMNS - 1), "team":_enemy_team_id(unit.team)}, t("恶来袭后空击", "Evil Guard Raid missed"), visual_group, "multi_target")
	for target in targets:
		_damage(unit, target, _unit_skill_output_base(unit) * mult, "physical", t("恶来袭后", "Evil Guard Raid"), visual_group, "multi_target")
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_xuchu_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.xuchu.ability_params
	var target_count := int(params.get("target_count", 2)) + (int(params.get("caocao_bonus_targets", 1)) if _pair_active(unit.team, "xuchu", "caocao") else 0)
	var mult := float(params.get("dianwei_mult", 4.0)) if _pair_active(unit.team, "xuchu", "dianwei") else float(params.get("mult", 2.0))
	var targets := _random_unique_living_enemies(unit, target_count, 0)
	var visual_group := "xuchu_front:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	if targets.is_empty():
		_hit_ruler(unit, _unit_skill_output_base(unit) * mult, {"row":0, "col":rng.randi_range(0, BOARD_COLUMNS - 1), "team":_enemy_team_id(unit.team)}, t("虎卫破前空击", "Tiger Guard Break missed"), visual_group, "multi_target")
	for target in targets:
		_damage(unit, target, _unit_skill_output_base(unit) * mult, "physical", t("虎卫破前", "Tiger Guard Break"), visual_group, "multi_target")
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _five_elites_active(team: String) -> bool:
	return _roster_has_all(_team_units(team), ["zhangliao", "yuejin", "zhanghe", "xuhuang", "yujin"])

func _cast_zhangliao_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.zhangliao.ability_params
	var five := _five_elites_active(unit.team)
	var mult := float(params.get("yuejin_mult", 2.0)) if _pair_active(unit.team, "zhangliao", "yuejin") else float(params.get("mult", 1.0))
	var amount := _unit_skill_output_base(unit) * mult
	var col := rng.randi_range(0, BOARD_COLUMNS - 1)
	var target_team := _enemy_team_id(unit.team)
	var affected: Array = []
	for hit_index in int(params.get("hit_count", 2)):
		var visual_group := "zhangliao_boomerang:" + str(unit.id) + ":" + str(unit.get("cast_count", 0)) + ":" + str(hit_index)
		for row in BOARD_ROWS:
			var target = _unit_at(_enemy_units(unit.team), row, col)
			if target == null:
				_hit_ruler(unit, amount, {"row":row, "col":col, "team":target_team}, t("威震回刃空击", "Returning Blade empty strike"), visual_group, "column_impact")
			else:
				_damage(unit, target, amount, "physical", t("威震回刃", "Returning Blade"), visual_group, "column_impact")
				if not affected.has(target): affected.append(target)
	if five:
		for target in affected:
			if target.alive:
				target.vulnerable = maxf(float(target.get("vulnerable", 0.0)), float(params.get("five_vulnerable", 0.40)) * _unit_skill_effect_multiplier(unit))
				target.vulnerable_time = maxf(float(target.get("vulnerable_time", 0.0)), float(params.get("five_vulnerable_time", 3.5)))
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_yuejin_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.yuejin.ability_params
	var five := _five_elites_active(unit.team)
	var pair := _pair_active(unit.team, "zhangliao", "yuejin")
	var target_count := int(params.get("five_target_count", 7)) if five else (int(params.get("zhangliao_target_count", 5)) if pair else int(params.get("target_count", 3)))
	var mult := float(params.get("five_mult", 2.0)) if five else (float(params.get("zhangliao_mult", 1.5)) if pair else float(params.get("mult", 1.0)))
	var targets := _random_unique_living_enemies(unit, target_count)
	var visual_group := "yuejin_volley:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	if targets.is_empty():
		_hit_ruler(unit, _unit_skill_output_base(unit) * mult, _random_enemy_tile(unit), t("先登乱射空击", "Vanguard Volley missed"), visual_group, "multi_target")
	for target in targets:
		_damage(unit, target, _unit_skill_output_base(unit) * mult, "physical", t("先登乱射", "Vanguard Volley"), visual_group, "multi_target")
		if five and target.alive:
			target.grievous = maxf(float(target.get("grievous", 0.0)), float(params.get("five_grievous", 0.60)) * _unit_skill_effect_multiplier(unit))
			target.grievous_time = maxf(float(target.get("grievous_time", 0.0)), float(params.get("five_grievous_time", 4.0)))
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_xuhuang_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.xuhuang.ability_params
	var five := _five_elites_active(unit.team)
	var pair := _pair_active(unit.team, "xuhuang", "zhanghe")
	var row := rng.randi_range(0, BOARD_ROWS - 1) if five else 0
	var mult := float(params.get("five_mult", 3.0)) if five else (float(params.get("zhanghe_mult", 2.0)) if pair else float(params.get("mult", 1.25)))
	var stun_time := float(params.get("five_stun", 5.0)) if five else float(params.get("stun", 2.0))
	var visual_group := "xuhuang_row:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	var target_team := _enemy_team_id(unit.team)
	for col in BOARD_COLUMNS:
		var target = _unit_at(_enemy_units(unit.team), row, col)
		if target == null:
			_hit_ruler(unit, _unit_skill_output_base(unit) * mult, {"row":row, "col":col, "team":target_team}, t("撼地开山空击", "Earth-Splitting Axe empty strike"), visual_group, "row_impact")
		else:
			_damage(unit, target, _unit_skill_output_base(unit) * mult, "physical", t("撼地开山", "Earth-Splitting Axe"), visual_group, "row_impact")
			_apply_skill_stun(unit, target, stun_time)
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _random_adjacent_row_target(unit: Dictionary, row: int, col: int) -> Variant:
	var candidates := _enemy_units(unit.team).filter(func(enemy): return enemy.alive and int(enemy.row) == row and abs(int(enemy.col) - col) <= 1 and float(enemy.get("stealth", 0.0)) <= 0.0)
	return null if candidates.is_empty() else candidates[rng.randi_range(0, candidates.size() - 1)]

func _cast_zhanghe_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.zhanghe.ability_params
	var five := _five_elites_active(unit.team)
	var pair := _pair_active(unit.team, "zhanghe", "xuhuang")
	var front_targets := _random_unique_living_enemies(unit, BOARD_COLUMNS, 0)
	if front_targets.is_empty():
		_hit_ruler(unit, _unit_skill_output_base(unit) * float(params.get("mult", 2.0)), {"row":0, "col":rng.randi_range(0, BOARD_COLUMNS - 1), "team":_enemy_team_id(unit.team)}, t("巧变连枪空击", "Coiling Spear missed"))
		return
	var primary: Dictionary = front_targets[rng.randi_range(0, front_targets.size() - 1)]
	var targets: Array = [primary]
	if pair:
		var adjacent_fronts := front_targets.filter(func(enemy): return enemy.id != primary.id and abs(int(enemy.col) - int(primary.col)) == 1)
		if not adjacent_fronts.is_empty(): targets.append(adjacent_fronts[rng.randi_range(0, adjacent_fronts.size() - 1)])
	if five:
		var middle = _random_adjacent_row_target(unit, 1, int(primary.col))
		if middle != null:
			targets.append(middle)
			var rear = _random_adjacent_row_target(unit, 2, int(middle.col))
			if rear != null: targets.append(rear)
	var visual_group := "zhanghe_chain:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for target in targets:
		var stunned_before := float(target.get("stun", 0.0)) > 0.0
		var mult := float(params.get("five_stunned_mult", 5.0)) if five and stunned_before else (float(params.get("five_mult", 3.0)) if five else float(params.get("mult", 2.0)))
		_damage(unit, target, _unit_skill_output_base(unit) * mult, "physical", t("巧变连枪", "Coiling Spear Chain"), visual_group, "multi_target")
		_apply_skill_stun(unit, target, float(params.get("stun", 1.5)))
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_yujin_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.yujin.ability_params
	var five := _five_elites_active(unit.team)
	var target_count := int(params.get("five_target_count", 3)) if five else int(params.get("target_count", 1))
	var flat := float(params.get("five_flat_shield", 300.0)) if five else float(params.get("flat_shield", 200.0))
	var ratio := float(params.get("five_max_hp_shield_ratio", 0.05)) if five else float(params.get("max_hp_shield_ratio", 0.03))
	var allies := _team_units(unit.team).filter(func(ally): return ally.alive)
	allies.sort_custom(func(a, b): return float(a.hp) < float(b.hp))
	for ally in allies.slice(0, mini(target_count, allies.size())):
		var shield_value := (flat + float(ally.max_hp) * ratio) * _unit_skill_effect_multiplier(unit)
		_grant_shield(ally, shield_value)
		visual_events.append({"kind":"heal", "source_id":unit.id, "target_id":ally.id, "amount":round(shield_value), "style":"shield"})
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_dongzhuo_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes[unit.hero_id].ability_params
	var ratio := float(params.get("lvbu_current_hp_ratio", 0.15)) if _pair_active(unit.team, "dongzhuo", "lvbu") else float(params.get("current_hp_ratio", 0.07))
	var amount := float(unit.hp) * ratio * _unit_skill_effect_multiplier(unit)
	var tile := {"row":0, "col":clampi(int(unit.col), 0, BOARD_COLUMNS - 1), "team":_enemy_team_id(unit.team)}
	var target = _unit_at(_enemy_units(unit.team), int(tile.row), int(tile.col))
	if target == null:
		_hit_ruler(unit, amount, tile, t("暴君横征空击", "Tyrant's Might missed"), "", "", false)
	else:
		_damage(unit, target, amount, "physical", t("暴君横征", "Tyrant's Might"), "", "", false)
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _reduce_action_bar(source: Dictionary, target: Dictionary, amount: float) -> float:
	if source == null or target == null or not target.alive or amount <= 0.0:
		return 0.0
	var action_before := float(target.action)
	target.action = maxf(0.0, action_before - amount)
	var actual_reduction := action_before - float(target.action)
	if actual_reduction > 0.0:
		var control_seconds := actual_reduction / ACTION_MAX * float(heroes[target.hero_id].cooldown)
		_add_stat(source, "control", control_seconds)
	return actual_reduction

func _apply_skill_burn(source: Dictionary, target: Dictionary, duration: float, damage_per_second: float) -> void:
	if source == null or target == null or not target.alive or duration <= 0.0:
		return
	target.burn = maxf(float(target.burn), duration)
	target.burn_damage = maxf(float(target.get("burn_damage", 0.0)), damage_per_second * _unit_skill_effect_multiplier(source) * float(source.get("burn_multiplier", 1.0)))
	target.burn_missing_hp_scale = false

func _cast_jiangwei_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.jiangwei.ability_params
	var inherited_strategy := _pair_active(unit.team, "jiangwei", "zhugeliang")
	unit.timed_reduction = maxf(float(unit.get("timed_reduction", 0.0)), (float(params.get("bond_reduction", 0.30)) if inherited_strategy else float(params.get("reduction", 0.15))) * _unit_skill_effect_multiplier(unit))
	unit.timed_reduction_time = maxf(float(unit.get("timed_reduction_time", 0.0)), float(params.get("reduction_duration", 5.0)))
	var tile := _random_enemy_tile(unit)
	var visual_group := "jiangwei_northern:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	var main_target = tile.target
	var main_damage := float(params.get("base_value", _unit_skill_output_base(unit)))
	if main_target == null:
		_hit_ruler(unit, main_damage, tile, t("北伐空击", "Northern Expedition missed"), visual_group, "area_impact")
	else:
		_damage(unit, main_target, main_damage, "magic", t("北伐", "Northern Expedition"), visual_group, "area_impact")
	if not inherited_strategy:
		return
	var diagonal_targets: Array = []
	for row_offset in [-1, 1]:
		for col_offset in [-1, 1]:
			var row: int = int(tile.row) + int(row_offset)
			var col: int = int(tile.col) + int(col_offset)
			if row < 0 or row >= BOARD_ROWS or col < 0 or col >= BOARD_COLUMNS:
				continue
			var diagonal = _unit_at(_enemy_units(unit.team), row, col)
			if diagonal != null:
				diagonal_targets.append(diagonal)
	var count := mini(int(params.get("diagonal_count", 2)), diagonal_targets.size())
	var diagonal_damage := _unit_skill_output_base(unit) * float(params.get("diagonal_mult", 0.80))
	for index in count:
		_damage(unit, diagonal_targets[index], diagonal_damage, "magic", t("北伐斜击", "Northern Expedition diagonal strike"), visual_group, "area_impact")

func _cast_pangtong_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.pangtong.ability_params
	var dragon_and_phoenix := _pair_active(unit.team, "pangtong", "zhugeliang")
	var tile := _random_enemy_tile(unit)
	var cols: Array = [int(tile.col)]
	if dragon_and_phoenix:
		cols = range(maxi(0, int(tile.col) - 1), mini(BOARD_COLUMNS - 1, int(tile.col) + 1) + 1)
	var damage := _unit_skill_output_base(unit) * (float(params.get("bond_mult", 1.0)) if dragon_and_phoenix else float(params.get("mult", 0.80)))
	var control_duration := float(params.get("bond_stun", 2.5)) if dragon_and_phoenix else float(params.get("stun", 2.0))
	var visual_group := "pangtong_chain:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for col in cols:
		var target = _unit_at(_enemy_units(unit.team), int(tile.row), int(col))
		var impact_tile := {"row":int(tile.row), "col":int(col), "team":str(tile.team)}
		if target == null:
			_hit_ruler(unit, damage, impact_tile, t("连环计空击", "Chain Scheme missed"), visual_group, "area_impact")
			continue
		_damage(unit, target, damage, "magic", t("连环计", "Chain Scheme"), visual_group, "area_impact")
		if target.alive:
			var actual_control := control_duration * _unit_effect_multiplier(unit) * _control_duration_multiplier(unit)
			target.stun = maxf(float(target.stun), actual_control)
			_add_stat(unit, "control", actual_control)

func _cast_menghuo_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.menghuo.ability_params
	var with_zhugeliang := _pair_active(unit.team, "menghuo", "zhugeliang")
	var with_zhurong := _pair_active(unit.team, "menghuo", "zhurong")
	var with_dailai := _pair_active(unit.team, "menghuo", "dailaidongzhu")
	var rows := _attackable_rows(unit)
	var row: int = rows[rng.randi_range(0, rows.size() - 1)]
	var target_team := _enemy_team_id(unit.team)
	var initial_group := "menghuo_quake:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	var base_damage := float(params.get("base_value", _unit_skill_output_base(unit)))
	for col in BOARD_COLUMNS:
		var target = _unit_at(_enemy_units(unit.team), row, col)
		var tile := {"row":row, "col":col, "team":target_team}
		if target == null:
			_hit_ruler(unit, base_damage, tile, t("蛮王震地空击", "Barbarian Quake missed"), initial_group, "row_impact")
			continue
		var burning := with_zhurong and float(target.get("burn", 0.0)) > 0.0
		var damage := base_damage * (float(params.get("burning_damage_mult", 1.40)) if burning else 1.0)
		_damage(unit, target, damage, "physical", t("蛮王震地", "Barbarian Quake"), initial_group, "row_impact")
		if target.alive:
			var stun_duration := float(params.get("burning_stun", 1.20)) if burning else float(params.get("stun", 0.80))
			stun_duration *= _unit_effect_multiplier(unit) * _control_duration_multiplier(unit)
			target.stun = maxf(float(target.stun), stun_duration)
			_add_stat(unit, "control", stun_duration)
			if with_dailai:
				_reduce_action_bar(unit, target, float(params.get("bond_action_reduction", 20.0)))
	if not with_zhugeliang:
		return
	var aftershock_group := "menghuo_aftershock:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	var aftershock_damage := _unit_skill_output_base(unit) * float(params.get("aftershock_mult", 0.60))
	for col in BOARD_COLUMNS:
		var target = _unit_at(_enemy_units(unit.team), row, col)
		var tile := {"row":row, "col":col, "team":target_team}
		if target == null:
			_hit_ruler(unit, aftershock_damage, tile, t("蛮王余震空击", "Barbarian Aftershock missed"), aftershock_group, "row_impact")
		else:
			_damage(unit, target, aftershock_damage, "physical", t("蛮王余震", "Barbarian Aftershock"), aftershock_group, "row_impact")

func _cast_zhurong_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.zhurong.ability_params
	var nanman_couple := _pair_active(unit.team, "zhurong", "menghuo")
	var sibling_bond := _pair_active(unit.team, "zhurong", "dailaidongzhu")
	var tile := _random_enemy_tile(unit)
	var cols: Array = [int(tile.col)]
	if nanman_couple:
		cols = range(maxi(0, int(tile.col) - 1), mini(BOARD_COLUMNS - 1, int(tile.col) + 1) + 1)
	var burn_duration := float(params.get("bond_burn", 6.0)) if sibling_bond else float(params.get("burn", 4.0))
	var burn_ratio := float(params.get("bond_burn_ratio", 0.40)) if sibling_bond else float(params.get("burn_ratio", 0.30))
	var visual_group := "zhurong_blade:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for col in cols:
		var is_center := int(col) == int(tile.col)
		var damage := float(params.get("base_value", _unit_skill_output_base(unit))) if is_center else _unit_skill_output_base(unit) * float(params.get("bounce_mult", 0.70))
		var target = _unit_at(_enemy_units(unit.team), int(tile.row), int(col))
		var impact_tile := {"row":int(tile.row), "col":int(col), "team":str(tile.team)}
		if target == null:
			_hit_ruler(unit, damage, impact_tile, t("火神飞刃空击", "Flame Blade missed"), visual_group, "area_impact")
			continue
		_damage(unit, target, damage, "magic", t("火神飞刃", "Flame Blade"), visual_group, "area_impact")
		_apply_skill_burn(unit, target, burn_duration, _unit_skill_output_base(unit) * burn_ratio)

func _cast_dailai_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.dailaidongzhu.ability_params
	var with_menghuo := _pair_active(unit.team, "dailaidongzhu", "menghuo")
	var with_zhurong := _pair_active(unit.team, "dailaidongzhu", "zhurong")
	var candidates := _targets_in_range(unit).filter(func(enemy): return enemy.alive and float(enemy.get("stealth", 0.0)) <= 0.0)
	candidates.sort_custom(func(a, b): return float(a.action) > float(b.action))
	var center_tile: Dictionary
	if candidates.is_empty():
		center_tile = _random_enemy_tile(unit)
	else:
		var chosen: Dictionary = candidates[0]
		center_tile = {"row":int(chosen.row), "col":int(chosen.col), "team":str(chosen.team), "target":chosen}
	var reductions: Array = params.get("action_reduction_by_star", [25.0, 35.0, 50.0])
	var rows: Array = [int(center_tile.row)]
	if with_menghuo:
		if int(center_tile.row) > 0:
			rows.push_front(int(center_tile.row) - 1)
		if int(center_tile.row) < BOARD_ROWS - 1:
			rows.append(int(center_tile.row) + 1)
	var visual_group := "dailai_wolf:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for row in rows:
		var is_center := int(row) == int(center_tile.row)
		var damage := float(params.get("base_value", _unit_skill_output_base(unit))) * float(params.get("mult", 1.8)) if is_center else _unit_skill_output_base(unit) * float(params.get("column_splash_mult", 0.90))
		var target = _unit_at(_enemy_units(unit.team), int(row), int(center_tile.col))
		if target != null and float(target.get("stealth", 0.0)) > 0.0:
			target = null
		var impact_tile := {"row":int(row), "col":int(center_tile.col), "team":str(center_tile.team)}
		if target == null:
			_hit_ruler(unit, damage, impact_tile, t("蛮骨狼袭空击", "Savage-Bone Wolf Assault missed"), visual_group, "area_impact")
			continue
		var burning_before := with_zhurong and float(target.get("burn", 0.0)) > 0.0
		if burning_before:
			damage *= float(params.get("burning_damage_mult", 1.20))
		_damage(unit, target, damage, "physical", t("蛮骨狼袭", "Savage-Bone Wolf Assault"), visual_group, "area_impact")
		if not target.alive:
			continue
		var requested_reduction := (float(reductions[0]) if is_center else float(params.get("splash_action_reduction", 15.0))) * _unit_skill_effect_multiplier(unit)
		var actual_reduction := _reduce_action_bar(unit, target, requested_reduction)
		if actual_reduction > 0.0:
			_log(_hero_name("dailaidongzhu") + t(" 以蛮骨狼袭压退 ", " drives back ") + _hero_name(target.hero_id) + t(" 的行动条 ", "'s gauge by ") + str(round(actual_reduction)) + "%")
		if with_zhurong:
			_apply_skill_burn(unit, target, float(params.get("bond_burn", 4.0)), _unit_skill_output_base(unit) * float(params.get("bond_burn_ratio", 0.30)))

func _cast_lvbu_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes[unit.hero_id].ability_params
	_log(_hero_name("lvbu") + t(" 发动无双横扫！", " unleashes Peerless Sweep!"))
	var damage_dealt := _cast_lvbu_sweep_once(unit, 0)
	if _pair_active(unit.team, "lvbu", "chengong") and not _has_winner() and rng.randf() < float(params.get("chengong_repeat_chance", 0.50)):
		damage_dealt += _cast_lvbu_sweep_once(unit, 1)
		_log(t("【谋定无双】陈宫使吕布再次横扫！", "[Peerless Strategy] Chen Gong triggers a second sweep!"))
	if _pair_active(unit.team, "lvbu", "dongzhuo") and damage_dealt > 0.0:
		_heal_unit_only(unit, unit, damage_dealt * float(params.get("dongzhuo_heal", 0.40)))
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_lvbu_sweep_once(unit: Dictionary, wave: int) -> float:
	var params: Dictionary = heroes.lvbu.ability_params
	var amount := _unit_skill_output_base(unit) * float(params.get("mult", 1.75))
	if _pair_active(unit.team, "lvbu", "diaochan"):
		amount *= _missing_hp_damage_multiplier(unit, float(params.get("missing_hp_step", 0.10)), float(params.get("diaochan_bonus_per_step", 0.04)) * _unit_skill_effect_multiplier(unit))
	var rows := [0, 1] if _pair_active(unit.team, "lvbu", "gaoshun") else [0]
	var target_team := _enemy_team_id(unit.team)
	var damage_dealt := 0.0
	var visual_group := "lvbu_sweep:" + str(unit.id) + ":" + str(unit.get("cast_count", 0)) + ":" + str(wave)
	for row in rows:
		for col in range(maxi(0, int(unit.col) - 1), mini(BOARD_COLUMNS - 1, int(unit.col) + 1) + 1):
			var tile := {"row":int(row), "col":col, "team":target_team}
			var target = _unit_at(_enemy_units(unit.team), int(row), col)
			if target == null:
				_hit_ruler(unit, amount, tile, t("无双横扫空击", "Peerless Sweep missed"), visual_group, "row_impact")
			else:
				var hp_before := float(target.hp)
				_damage(unit, target, amount, "physical", t("无双横扫", "Peerless Sweep"), visual_group, "row_impact")
				damage_dealt += maxf(0.0, hp_before - float(target.hp))
	return damage_dealt

func _missing_hp_damage_multiplier(target: Dictionary, step: float, bonus_per_step: float) -> float:
	var missing_ratio := 1.0 - float(target.hp) / maxf(1.0, float(target.max_hp))
	return 1.0 + floorf(clampf(missing_ratio, 0.0, 1.0) / maxf(0.001, step) + 0.0001) * bonus_per_step

func _ruler_missing_hp_damage_multiplier(team: String, step: float, bonus_per_step: float) -> float:
	var target_hp := enemy_ruler_hp if team == "player" else player_ruler_hp
	var missing_ratio := 1.0 - float(target_hp) / maxf(1.0, float(RULER_MAX_HP))
	return 1.0 + floorf(clampf(missing_ratio, 0.0, 1.0) / maxf(0.001, step) + 0.0001) * bonus_per_step

func _random_unique_enemy_tiles(unit: Dictionary, count: int) -> Array:
	var available: Array = []
	var target_team := _enemy_team_id(unit.team)
	for row in BOARD_ROWS:
		for col in BOARD_COLUMNS:
			available.append({"row":row, "col":col, "team":target_team})
	var result: Array = []
	for _index in mini(count, available.size()):
		var picked := rng.randi_range(0, available.size() - 1)
		var tile: Dictionary = available[picked]
		available.remove_at(picked)
		tile.target = _unit_at(_enemy_units(unit.team), int(tile.row), int(tile.col))
		result.append(tile)
	return result

func _cast_zhouyu(unit: Dictionary) -> void:
	var params: Dictionary = heroes.zhouyu.ability_params
	var tile_count := int(params.get("tile_count", 2))
	if bool(unit.get("four_heroes", false)):
		tile_count += int(params.get("four_heroes_bonus_tiles", 2))
	var burn_duration := float(params.get("xiaoqiao_burn", 6.0)) if bool(unit.get("zhouyu_xiaoqiao", false)) else float(params.get("burn", 3.0))
	var missing_scale := bool(unit.get("zhouyu_huanggai", false))
	var missing_step := float(params.get("missing_hp_step", 0.10))
	var missing_bonus := float(params.get("missing_hp_bonus_per_step", 0.05))
	if missing_scale: missing_bonus *= _unit_skill_effect_multiplier(unit)
	var base := float(params.get("base_value", _unit_skill_output_base(unit)))
	var burn_per_second := float(params.get("burn_per_sec", _unit_skill_output_base(unit) * 0.50)) * float(unit.get("burn_multiplier", 1.0)) * _unit_skill_effect_multiplier(unit)
	unit["zhouyu_casts"] = int(unit.get("zhouyu_casts", 0)) + 1
	var visual_group := "zhouyu_tiles:" + str(unit.id) + ":" + str(unit.zhouyu_casts)
	var tiles := _random_unique_enemy_tiles(unit, tile_count)
	_log(_hero_name("zhouyu") + t(" 随机点燃 ", " ignites ") + str(tile_count) + t(" 个敌方格！", " enemy tiles!"))
	for tile in tiles:
		visual_events.append({"kind":"row_burn", "source_id":unit.id, "target_id":"", "team":tile.team, "row":tile.row, "col":tile.col, "amount":0, "skill":true, "style":"magic", "visual_group":visual_group, "group_style":"tile_burn"})
		var damage_multiplier := 1.0
		if missing_scale:
			damage_multiplier = _missing_hp_damage_multiplier(tile.target, missing_step, missing_bonus) if tile.target != null else _ruler_missing_hp_damage_multiplier(unit.team, missing_step, missing_bonus)
		if tile.target == null:
			_hit_ruler(unit, base * damage_multiplier, tile, t("赤壁点火空击", "Red Cliffs empty strike"), visual_group, "tile_burn")
			_set_ground_burn(unit, str(tile.team), int(tile.row), int(tile.col), burn_duration, burn_per_second, visual_group, missing_scale)
		else:
			_damage(unit, tile.target, base * damage_multiplier, "magic", t("赤壁点火", "Red Cliffs"), visual_group, "tile_burn")
			if tile.target.alive:
				tile.target.burn = burn_duration
				tile.target.burn_damage = burn_per_second * float(unit.get("stat_mult", 1.0))
				tile.target.burn_visual_group = visual_group
				tile.target.burn_missing_hp_scale = missing_scale

func _set_ground_burn(source: Dictionary, target_team: String, row: int, col: int, duration: float, damage: float, visual_group: String, missing_hp_scale := false) -> void:
	var effect := {
		"source_id":str(source.id),
		"team":target_team,
		"row":row,
		"col":col,
		"time":duration,
		"clock":0.0,
		"damage":damage,
		"visual_group":visual_group,
		"missing_hp_scale":missing_hp_scale
	}
	for index in ground_effects.size():
		var existing: Dictionary = ground_effects[index]
		if str(existing.team) == target_team and int(existing.row) == row and int(existing.col) == col:
			ground_effects[index] = effect
			return
	ground_effects.append(effect)

func _adjacent_luxun_targets(unit: Dictionary, from_target: Dictionary, hit_ids: Dictionary) -> Array:
	return _enemy_units(unit.team).filter(func(enemy):
		return (
			enemy.alive
			and float(enemy.get("stealth", 0.0)) <= 0.0
			and not hit_ids.has(str(enemy.id))
			and abs(int(enemy.row) - int(from_target.row)) + abs(int(enemy.col) - int(from_target.col)) == 1
		)
	)

func _luxun_damage_multiplier(unit: Dictionary, target: Dictionary) -> float:
	if not bool(unit.get("luxun_sunquan", false)):
		return 1.0
	var params: Dictionary = heroes.luxun.ability_params
	var bonus := float(params.get("sunquan_damage_bonus", 0.50))
	if float(target.get("burn", 0.0)) > 0.0:
		bonus += float(params.get("sunquan_burning_bonus", 0.50))
	return 1.0 + bonus

func _cast_luxun(unit: Dictionary) -> void:
	var params: Dictionary = heroes.luxun.ability_params
	var candidates := _enemy_units(unit.team).filter(func(enemy): return enemy.alive and float(enemy.get("stealth", 0.0)) <= 0.0)
	var base := float(params.get("base_value", _unit_skill_output_base(unit) * 2.0))
	var target_team := _enemy_team_id(unit.team)
	var visual_group := "luxun_fireball:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	if candidates.is_empty():
		var empty_tile := {"row":rng.randi_range(0, BOARD_ROWS - 1), "col":rng.randi_range(0, BOARD_COLUMNS - 1), "team":target_team}
		_hit_ruler(unit, base, empty_tile, t("火烧连营空击", "Flames of Camp empty strike"), visual_group, "fireball_chain")
		return
	var current: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
	var bounce_count := int(params.get("four_heroes_bounces", 3)) if bool(unit.get("four_heroes", false)) else int(params.get("bounces", 1))
	var hit_ids := {}
	_log(_hero_name("luxun") + t(" 发射火球，沿相邻格弹射！", " launches a fireball through adjacent tiles!"))
	for chain_index in bounce_count + 1:
		hit_ids[str(current.id)] = true
		_damage(unit, current, base * _luxun_damage_multiplier(unit, current), "magic", t("火烧连营", "Flames of Camp"), visual_group, "fireball_chain")
		for created_event_index in range(visual_events.size() - 1, -1, -1):
			var created_event: Dictionary = visual_events[created_event_index]
			if str(created_event.get("visual_group", "")) != visual_group:
				break
			if str(created_event.get("kind", "")) == "damage":
				visual_events[created_event_index]["chain_index"] = chain_index
				visual_events[created_event_index]["projectile_asset"] = "res://ThreeKingdom/animations/fireball.png"
				break
		if chain_index >= bounce_count:
			break
		var adjacent := _adjacent_luxun_targets(unit, current, hit_ids)
		if adjacent.is_empty():
			break
		current = adjacent[rng.randi_range(0, adjacent.size() - 1)]

func _cast_lvmeng_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.lvmeng.ability_params
	var targets := _enemy_units(unit.team).filter(func(enemy): return enemy.alive and int(enemy.row) == BOARD_ROWS - 1 and float(enemy.get("stealth", 0.0)) <= 0.0)
	var target = targets[rng.randi_range(0, targets.size() - 1)] if not targets.is_empty() else null
	var target_team := _enemy_team_id(unit.team)
	var target_col := int(target.col) if target != null else rng.randi_range(0, BOARD_COLUMNS - 1)
	var amount := float(params.get("base_value", _unit_skill_output_base(unit) * 4.0))
	if target == null:
		_hit_ruler(unit, amount, {"row":BOARD_ROWS - 1, "col":target_col, "team":target_team}, t("白衣渡江空击", "White-Robed Raid empty strike"))
	else:
		_damage(unit, target, amount, "physical", t("白衣渡江", "White-Robed Raid"))
		if target.alive and bool(unit.get("four_heroes", false)):
			target.fear = maxf(float(target.get("fear", 0.0)), float(params.get("fear", 4.0)))
			target.fear_damage_ratio = maxf(float(target.get("fear_damage_ratio", 0.0)), float(params.get("fear_max_hp_ratio", 0.05)) * _unit_skill_effect_multiplier(unit))
			target.fear_clock = 0.0
			_add_stat(unit, "control", float(params.get("fear", 4.0)))
			visual_events.append({"kind":"skill", "source_id":unit.id, "target_id":target.id, "amount":0, "style":"magic"})
	unit.stealth = maxf(float(unit.get("stealth", 0.0)), float(params.get("stealth", 3.0)))
	if bool(unit.get("lvmeng_ganning", false)):
		unit.stealth_ambush_bonus_ready = true

func _cast_diaochan(unit: Dictionary) -> void:
	var params: Dictionary = heroes[unit.hero_id].ability_params
	var enemies := _enemy_units(unit.team).filter(func(enemy): return enemy.alive and float(enemy.get("stealth", 0.0)) <= 0.0)
	if enemies.is_empty(): return
	var target: Dictionary = enemies[rng.randi_range(0, enemies.size() - 1)]
	var duration := float(params.get("dongzhuo_duration", 6.0)) if _pair_active(unit.team, "diaochan", "dongzhuo") else float(params.get("duration", 3.0))
	target.charm = duration * _control_duration_multiplier(unit)
	target.charm_forced_attack = _pair_active(unit.team, "diaochan", "lvbu")
	target.charm_attack_clock = 0.0
	_add_stat(unit, "control", float(target.charm))
	visual_events.append({"kind":"skill", "source_id":unit.id, "target_id":target.id, "amount":0, "style":"magic"})
	_log(_hero_name("diaochan") + t(" 魅惑了 ", " charms ") + _hero_name(target.hero_id) + "！")
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _pick_random_units(candidates: Array, count: int) -> Array:
	var pool := candidates.duplicate()
	var result: Array = []
	for _index in mini(count, pool.size()):
		var picked := rng.randi_range(0, pool.size() - 1)
		result.append(pool[picked])
		pool.remove_at(picked)
	return result

func _cast_gaoshun_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.gaoshun.ability_params
	var target_count := int(params.get("target_count", 2))
	if _pair_active(unit.team, "gaoshun", "lvbu"): target_count += int(params.get("lvbu_bonus_targets", 2))
	var duration := float(params.get("vulnerable_time", 3.0))
	if _pair_active(unit.team, "gaoshun", "chengong"): duration += float(params.get("chengong_bonus_duration", 3.0))
	var targets := _pick_random_units(_enemy_units(unit.team).filter(func(enemy): return enemy.alive and float(enemy.get("stealth", 0.0)) <= 0.0), target_count)
	var visual_group := "gaoshun_fragile:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for target in targets:
		_damage(unit, target, _unit_skill_output_base(unit) * float(params.get("mult", 1.50)), "physical", t("陷阵之志", "Formation Resolve"), visual_group, "multi_target")
		if target.alive:
			target.vulnerable = maxf(float(target.get("vulnerable", 0.0)), float(params.get("vulnerable", 0.40)) * _unit_skill_effect_multiplier(unit))
			target.vulnerable_time = maxf(float(target.get("vulnerable_time", 0.0)), duration)
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _hebei_stored_damage_multiplier(unit: Dictionary, params: Dictionary) -> float:
	if not bool(unit.get("four_pillars", false)): return 1.0
	return 1.0 + minf(float(params.get("hit_bonus_cap", 3.0)), float(unit.get("hebei_damage_stacks", 0)) * float(params.get("hit_bonus", 0.15)))

func _cast_yanliang_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.yanliang.ability_params
	var count := int(params.get("target_count", 2))
	if _pair_active(unit.team, "yanliang", "wenchou"): count += int(params.get("wenchou_bonus_targets", 2))
	var candidates := _enemy_units(unit.team).filter(func(enemy): return enemy.alive and int(enemy.row) in [1, 2] and float(enemy.get("stealth", 0.0)) <= 0.0)
	var damage := _unit_skill_output_base(unit) * float(params.get("mult", 1.75)) * _hebei_stored_damage_multiplier(unit, params)
	var visual_group := "yanliang_assault:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for target in _pick_random_units(candidates, count):
		_damage(unit, target, damage, "physical", t("河北猛袭", "Hebei Fierce Assault"), visual_group, "multi_target")
	unit.hebei_damage_stacks = 0
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_wenchou_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.wenchou.ability_params
	var count := int(params.get("target_count", 2))
	if _pair_active(unit.team, "wenchou", "yanliang"): count += int(params.get("yanliang_bonus_targets", 2))
	var candidates := _enemy_units(unit.team).filter(func(enemy): return enemy.alive and int(enemy.row) in [0, 1] and float(enemy.get("stealth", 0.0)) <= 0.0)
	var stored_mult := _hebei_stored_damage_multiplier(unit, params)
	var visual_group := "wenchou_breakthrough:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for target in _pick_random_units(candidates, count):
		var amount := float(target.max_hp) * float(params.get("max_hp_ratio", 0.02)) * stored_mult * _unit_skill_effect_multiplier(unit)
		_damage(unit, target, amount, "physical", t("河北破阵", "Hebei Breakthrough"), visual_group, "multi_target", false)
	unit.hebei_damage_stacks = 0
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_qun_zhanghe_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.qunzhanghe.ability_params
	var count := int(params.get("target_count", 2))
	if _pair_active(unit.team, "qunzhanghe", "gaolan"): count += int(params.get("gaolan_bonus_targets", 2))
	if bool(unit.get("four_pillars", false)): count += int(params.get("four_pillars_bonus_targets", 2))
	var shield_mult := float(params.get("four_pillars_shield_mult", 4.0)) if bool(unit.get("four_pillars", false)) else float(params.get("shield_mult", 2.0))
	var shield_value := _unit_combat_skill_value(unit) * shield_mult * float(unit.get("stat_mult", 1.0))
	var allies := _team_units(unit.team).filter(func(ally): return ally.alive)
	allies.sort_custom(func(a, b):
		if not is_equal_approx(float(a.hp), float(b.hp)): return float(a.hp) < float(b.hp)
		return str(a.id) < str(b.id)
	)
	for target in allies.slice(0, mini(count, allies.size())):
		_grant_shield(target, shield_value)
		visual_events.append({"kind":"heal", "source_id":unit.id, "target_id":target.id, "amount":roundi(shield_value), "style":"shield"})
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _lowest_current_hp_allies(unit: Dictionary, count: int) -> Array:
	var allies := _team_units(unit.team).filter(func(ally): return ally.alive)
	allies.sort_custom(func(a, b):
		if not is_equal_approx(float(a.hp), float(b.hp)): return float(a.hp) < float(b.hp)
		return str(a.id) < str(b.id)
	)
	return allies.slice(0, mini(count, allies.size()))

func _clear_all_debuffs(target: Dictionary) -> void:
	target.stun = 0.0
	target.charm = 0.0
	target.charm_forced_attack = false
	target.charm_attack_clock = 0.0
	target.burn = 0.0
	target.burn_damage = 0.0
	target.burn_clock = 0.0
	target.burn_missing_hp_scale = false
	target.fear = 0.0
	target.fear_damage_ratio = 0.0
	target.fear_clock = 0.0
	target.freeze = 0.0
	target.freeze_shatter_per_second = 0.0
	target.poison = 0.0
	target.poison_ratio = 0.0
	target.poison_clock = 0.0
	target.poison_source = ""
	target.silence = 0.0
	target.slow = 0.0
	target.slow_time = 0.0
	target.vulnerable = 0.0
	target.vulnerable_time = 0.0
	target.grievous = 0.0
	target.grievous_time = 0.0
	target.strategy_mark = 0.0
	target.zhuge_fire_mark = false
	target.skill_debuff = 0.0
	target.skill_debuff_time = 0.0

func _cast_huatuo_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.huatuo.ability_params
	var heal_mult := float(params.get("heal_mult", 1.0))
	if _pair_active(unit.team, "huatuo", "zuoci"):
		heal_mult += float(params.get("zuoci_bonus_mult", 0.5))
	var cleanses := _pair_active(unit.team, "huatuo", "yuji")
	var targets := _lowest_current_hp_allies(unit, int(params.get("target_count", 3)))
	var visual_group := "huatuo_heal:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for target in targets:
		if cleanses: _clear_all_debuffs(target)
		_heal_unit_only(unit, target, _unit_scaled_skill_value(unit) * heal_mult, visual_group, "simultaneous")
		if cleanses:
			visual_events.append({"kind":"skill", "source_id":unit.id, "target_id":target.id, "amount":0, "style":"heal", "nonblocking":true, "visual_group":visual_group, "group_style":"simultaneous"})
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_yuji_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.yuji.ability_params
	var bond_count := 0
	if _pair_active(unit.team, "yuji", "huatuo"): bond_count += 1
	if _pair_active(unit.team, "yuji", "zuoci"): bond_count += 1
	var target_count := int(params.get("target_count", 2)) + bond_count * int(params.get("bond_bonus_targets", 1))
	var duration := float(params.get("duration", 4.0)) + float(bond_count) * float(params.get("bond_bonus_duration", 1.0))
	var visual_group := "yuji_poison:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for target in _pick_random_units(_enemy_units(unit.team).filter(func(enemy): return enemy.alive and float(enemy.get("stealth", 0.0)) <= 0.0), target_count):
		target.poison = maxf(float(target.get("poison", 0.0)), duration)
		target.poison_ratio = maxf(float(target.get("poison_ratio", 0.0)), float(params.get("poison_ratio", 0.005)) * _unit_skill_effect_multiplier(unit))
		target.poison_clock = 0.0
		target.poison_source = unit.id
		visual_events.append({"kind":"skill", "source_id":unit.id, "target_id":target.id, "amount":roundi(duration * 10.0), "style":"magic", "visual_group":visual_group, "group_style":"poison_apply"})
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_zuoci_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.zuoci.ability_params
	var heal_mult := float(params.get("heal_mult", 1.5))
	if _pair_active(unit.team, "zuoci", "huatuo"):
		heal_mult += float(params.get("huatuo_bonus_mult", 0.5))
	var heal_group := "zuoci_heal:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for target in _lowest_current_hp_allies(unit, int(params.get("target_count", 2))):
		_heal_unit_only(unit, target, _unit_scaled_skill_value(unit) * heal_mult, heal_group, "simultaneous")
	if _pair_active(unit.team, "zuoci", "yuji"):
		var enemies := _pick_random_units(_enemy_units(unit.team).filter(func(enemy): return enemy.alive and float(enemy.get("stealth", 0.0)) <= 0.0), int(params.get("target_count", 2)))
		var visual_group := "zuoci_thunder:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
		for target in enemies:
			_damage(unit, target, _unit_skill_output_base(unit) * float(params.get("thunder_mult", 1.5)), "magic", t("遁甲天雷", "Immortal Thunder"), visual_group, "multi_target")
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_zhangjiao_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.zhangjiao.ability_params
	var target_count := int(params.get("target_count", 2))
	var mult := float(params.get("mult", 2.0))
	if _pair_active(unit.team, "zhangjiao", "zhangliang"):
		mult += float(params.get("zhangliang_bonus_mult", 0.5))
	var with_zhangbao := _pair_active(unit.team, "zhangjiao", "zhangbao")
	if with_zhangbao: target_count += int(params.get("zhangbao_bonus_targets", 1))
	var visual_group := "zhangjiao_thunder:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for target in _pick_random_units(_enemy_units(unit.team).filter(func(enemy): return enemy.alive and float(enemy.get("stealth", 0.0)) <= 0.0), target_count):
		_damage(unit, target, _unit_skill_output_base(unit) * mult, "magic", t("黄天雷引", "Yellow Sky Thunder"), visual_group, "multi_target")
		if with_zhangbao and target.alive and rng.randf() < clampf(float(params.get("zhangbao_stun_chance", 0.5)) * _unit_skill_effect_multiplier(unit), 0.0, 1.0):
			_apply_skill_stun(unit, target, float(params.get("zhangbao_stun", 1.0)))
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_zhangliang_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.zhangliang.ability_params
	var target_count := int(params.get("target_count", 2))
	if _pair_active(unit.team, "zhangliang", "zhangjiao"): target_count += int(params.get("bond_bonus_targets", 1))
	if _pair_active(unit.team, "zhangliang", "zhangbao"): target_count += int(params.get("bond_bonus_targets", 1))
	var visual_group := "zhangliang_weak:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for target in _pick_random_units(_enemy_units(unit.team).filter(func(enemy): return enemy.alive and float(enemy.get("stealth", 0.0)) <= 0.0), target_count):
		target.skill_debuff = maxf(float(target.get("skill_debuff", 0.0)), float(params.get("skill_reduction", 0.5)) * _unit_skill_effect_multiplier(unit))
		target.skill_debuff_time = maxf(float(target.get("skill_debuff_time", 0.0)), float(params.get("duration", 5.0)) * _control_duration_multiplier(unit))
		_add_stat(unit, "control", float(params.get("duration", 5.0)) * _control_duration_multiplier(unit))
		visual_events.append({"kind":"skill", "source_id":unit.id, "target_id":target.id, "amount":roundi(float(params.get("skill_reduction", 0.5)) * _unit_skill_effect_multiplier(unit) * 100.0), "style":"magic", "visual_group":visual_group, "group_style":"weak_apply"})
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_lusu_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes[unit.hero_id].ability_params
	var four_heroes := bool(unit.get("four_heroes", false))
	var target_count := int(params.get("four_heroes_target_count", 2)) if four_heroes else int(params.get("target_count", 1))
	var heal_ratio := (float(params.get("four_heroes_heal_ratio", 0.20)) if four_heroes else float(params.get("heal_ratio", 0.15))) * _unit_skill_effect_multiplier(unit)
	var max_hp_flat := (float(params.get("four_heroes_max_hp_flat", 350.0)) if four_heroes else float(params.get("max_hp_flat", 200.0))) * _unit_skill_effect_multiplier(unit)
	var allies := _team_units(unit.team).filter(func(ally): return ally.alive)
	allies.sort_custom(func(a, b):
		if not is_equal_approx(float(a.hp), float(b.hp)):
			return float(a.hp) < float(b.hp)
		return str(a.id) < str(b.id)
	)
	var visual_group := "lusu_heal:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for index in mini(target_count, allies.size()):
		var target: Dictionary = allies[index]
		target.max_hp += max_hp_flat
		var heal_amount := float(target.max_hp) * heal_ratio
		_heal_unit_only(unit, target, heal_amount, visual_group, "simultaneous")
		visual_events.append({"kind":"skill", "source_id":unit.id, "target_id":target.id, "amount":round(max_hp_flat), "style":"heal"})
	_log(_hero_name("lusu") + t(" 为最低生命友军稳固阵线！", " fortifies the lowest-current-HP allies!"))

func _cast_xiaoqiao_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes[unit.hero_id].ability_params
	var zhouyu_bond := bool(unit.get("zhouyu_xiaoqiao", false))
	var daqiao_bond := _pair_active(unit.team, "daqiao", "xiaoqiao")
	var target_count := int(params.get("zhouyu_target_count", 3)) if zhouyu_bond else int(params.get("target_count", 2))
	var duration := float(params.get("zhouyu_slow_time", 8.0)) if zhouyu_bond else float(params.get("slow_time", 6.0))
	var slow_ratio := (float(params.get("daqiao_slow", 0.60)) if daqiao_bond else float(params.get("slow", 0.35))) * _unit_skill_effect_multiplier(unit)
	var targets := _enemy_units(unit.team).filter(func(enemy):
		return enemy.alive and int(enemy.row) == BOARD_ROWS - 1 and float(enemy.get("stealth", 0.0)) <= 0.0
	)
	var applied := 0
	var visual_group := "xiaoqiao_slow:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for _index in mini(target_count, targets.size()):
		var picked := rng.randi_range(0, targets.size() - 1)
		var target: Dictionary = targets[picked]
		targets.remove_at(picked)
		target.slow = maxf(float(target.get("slow", 0.0)), slow_ratio)
		target.slow_time = maxf(float(target.get("slow_time", 0.0)), duration)
		_add_stat(unit, "control", duration)
		visual_events.append({"kind":"skill", "source_id":unit.id, "target_id":target.id, "amount":round(slow_ratio * 100.0), "style":"magic", "visual_group":visual_group, "group_style":"simultaneous"})
		applied += 1
	if applied == 0:
		visual_events.append({"kind":"empty", "source_id":unit.id, "team":_enemy_team_id(unit.team), "row":BOARD_ROWS - 1, "col":rng.randi_range(0, BOARD_COLUMNS - 1), "amount":0, "skill":true, "style":"magic"})
	_log(_hero_name("xiaoqiao") + t(" 使敌方后军陷入天香缓阵！", " slows the enemy rearguard with Gentle Breeze!"))

func _heal_weakest_fixed(unit: Dictionary, heal_amount: float, reduction: float, boost := false, boost_ratio := 0.10, boost_cap := 3) -> void:
	var allies := _team_units(unit.team).filter(func(ally): return ally.alive)
	allies.sort_custom(func(a, b): return float(a.hp) / maxf(1.0, float(a.max_hp)) < float(b.hp) / maxf(1.0, float(b.max_hp)))
	var target = allies[0] if not allies.is_empty() else null
	var value: float = heal_amount * float(unit.get("stat_mult", 1.0)) * float(unit.get("heal_multiplier", 1.0))
	if target == null:
		_heal_with_overflow(unit, null, value)
		return
	if unit.hero_id == "daqiao" and bool(unit.get("sunce_daqiao", false)):
		var params: Dictionary = heroes.daqiao.ability_params
		var missing_ratio := 1.0 - float(target.hp) / maxf(1.0, float(target.max_hp))
		var missing_steps := floori(clampf(missing_ratio, 0.0, 1.0) / maxf(0.001, float(params.get("bond_missing_hp_step", 0.10))) + 0.0001)
		value *= 1.0 + float(missing_steps) * float(params.get("bond_heal_bonus_per_step", 0.04)) * _unit_skill_effect_multiplier(unit)
	if boost and int(target.get("lusu_boosts", 0)) < boost_cap:
		var hp_gain: float = target.max_hp * boost_ratio
		target.max_hp += hp_gain
		target.hp += hp_gain
		target["lusu_boosts"] = int(target.get("lusu_boosts", 0)) + 1
	_heal_with_overflow(unit, target, value)
	target.damage_reduction = max(target.damage_reduction, reduction)
func _heal_with_overflow(source: Dictionary, target, amount: float, visual_kind := "heal", nonblocking := false) -> void:
	if source == null or amount <= 0.0: return
	if target != null and target.alive:
		amount *= 1.0 - clampf(float(target.get("grievous", 0.0)), 0.0, 0.95)
	var overflow := amount
	if target != null and target.alive:
		var missing: float = maxf(0.0, float(target.max_hp) - float(target.hp))
		var restored: float = min(missing, amount)
		target.hp += restored
		overflow -= restored
		if restored > 0.0:
			visual_events.append({"kind":visual_kind, "source_id":source.id, "target_id":target.id, "amount":round(restored), "style":"heal", "nonblocking":nonblocking})
	var ruler_restored := 0.0
	if overflow > 0.0:
		var ruler_hp: int = player_ruler_hp if source.team == "player" else enemy_ruler_hp
		ruler_restored = minf(overflow, float(RULER_MAX_HP - ruler_hp))
		if source.team == "player": player_ruler_hp += int(round(ruler_restored))
		else: enemy_ruler_hp += int(round(ruler_restored))
		if ruler_restored > 0.0:
			visual_events.append({"kind":visual_kind, "source_id":source.id, "target_id":"", "team":source.team, "row":-1, "col":-1, "amount":round(ruler_restored), "ruler":true, "style":"heal", "nonblocking":nonblocking})
	_add_stat(source, "healing", amount)

func _heal_unit_only(source: Dictionary, target: Dictionary, amount: float, visual_group := "", group_style := "") -> float:
	if source == null or target == null or not target.alive or amount <= 0.0: return 0.0
	amount *= 1.0 - clampf(float(target.get("grievous", 0.0)), 0.0, 0.95)
	var missing := maxf(0.0, float(target.max_hp) - float(target.hp))
	var restored := minf(missing, amount)
	if restored <= 0.0: return 0.0
	target.hp += restored
	visual_events.append({"kind":"heal", "source_id":source.id, "target_id":target.id, "amount":round(restored), "style":"heal", "nonblocking":true, "visual_group":visual_group, "group_style":group_style})
	_add_stat(source, "healing", restored)
	return restored

func _ability_enemy_tile(unit: Dictionary, params: Dictionary) -> Dictionary:
	if rng.randf() < 0.25 or str(params.get("target_mode", "random")) == "random": return _random_enemy_tile(unit)
	var candidates := _targets_in_range(unit).filter(func(enemy): return enemy.alive and float(enemy.get("stealth", 0.0)) <= 0.0)
	if candidates.is_empty(): return _random_enemy_tile(unit)
	var mode := str(params.get("target_mode", "random"))
	if mode == "back_low": candidates.sort_custom(func(a, b): return a.row > b.row if a.row != b.row else float(a.hp) / float(a.max_hp) < float(b.hp) / float(b.max_hp))
	elif mode == "highest_skill_value": candidates.sort_custom(func(a, b): return _unit_skill_stat_value(a) > _unit_skill_stat_value(b))
	elif mode == "farthest": candidates.sort_custom(func(a, b): return a.row > b.row)
	elif mode == "front": candidates.sort_custom(func(a, b): return a.row < b.row)
	elif mode == "debuffed": candidates.sort_custom(func(a, b): return _debuff_score(a) > _debuff_score(b))
	var target: Dictionary = candidates[0]
	return {"row":target.row, "col":target.col, "team":target.team, "target":target}

func _debuff_score(unit: Dictionary) -> float:
	return (
		float(unit.stun)
		+ float(unit.charm)
		+ float(unit.burn)
		+ float(unit.get("silence", 0.0))
		+ float(unit.get("slow_time", 0.0))
		+ float(unit.get("vulnerable_time", 0.0))
		+ float(unit.get("grievous_time", 0.0))
		+ float(unit.get("strategy_mark", 0.0))
		+ float(unit.get("skill_debuff", 0.0))
		+ float(unit.get("fear", 0.0))
		+ float(unit.get("freeze", 0.0))
		+ float(unit.get("poison", 0.0))
		+ (1.0 if bool(unit.get("zhuge_fire_mark", false)) else 0.0)
	)

func _has_any_debuff(unit: Dictionary) -> bool:
	return _debuff_score(unit) > 0.0

func _random_enemy_tile(unit: Dictionary) -> Dictionary:
	var rows := _attackable_rows(unit)
	var row: int = rows[rng.randi_range(0, rows.size() - 1)]
	var col := rng.randi_range(0, BOARD_COLUMNS - 1)
	var team := _enemy_team_id(unit.team)
	var target = _unit_at(_enemy_units(unit.team), row, col)
	if target != null and float(target.get("stealth", 0.0)) > 0.0: target = null
	return {"row":row, "col":col, "team":team, "target":target}

func _enemy_team_id(team: String) -> String:
	return "enemy" if team == "player" else "player"

func _miss_tile(unit: Dictionary, tile: Dictionary, label: String) -> void:
	visual_events.append({"kind":"empty", "source_id":unit.id, "team":tile.team, "row":tile.row, "col":tile.col, "amount":0, "skill":true, "style":"magic"})
	_log(_hero_name(unit.hero_id) + t(" 的", "'s ") + label + t("，目标格为空。", "; target tile was empty."))

func _combat_name(unit: Dictionary) -> String:
	var color := "#90c59e" if unit.team == "player" else "#d89a8f"
	return "[color=" + color + "]" + _hero_name(unit.hero_id) + "[/color]"

func _apply_all_lifesteal(unit: Dictionary, damage_dealt: float) -> void:
	var ratio := float(unit.get("all_lifesteal", 0.0))
	if ratio <= 0.0 or damage_dealt <= 0.0 or not unit.alive: return
	_heal_with_overflow(unit, unit, damage_dealt * ratio)

func _try_wu_equalize_and_recover(target: Dictionary) -> bool:
	if heroes[target.hero_id].f != "wu" or int(target.get("faction_tier", 0)) < 3:
		return false
	if not faction_battle_state.has(target.team):
		faction_battle_state[target.team] = {"wu_equalize_used":false}
	var state: Dictionary = faction_battle_state[target.team]
	if bool(state.get("wu_equalize_used", false)):
		return false
	var wu_allies := _team_units(target.team).filter(func(ally): return ally.alive and heroes[ally.hero_id].f == "wu")
	if wu_allies.size() < FACTION_BOND_TIERS[2]:
		return false
	state.wu_equalize_used = true
	faction_battle_state[target.team] = state
	var total_hp := 0.0
	var total_max_hp := 0.0
	for ally in wu_allies:
		total_hp += maxf(0.0, float(ally.hp))
		total_max_hp += maxf(1.0, float(ally.max_hp))
	var shared_ratio := clampf(total_hp / maxf(1.0, total_max_hp), 0.0, 1.0)
	for ally in wu_allies:
		var before := float(ally.hp)
		ally.hp = minf(float(ally.max_hp), float(ally.max_hp) * shared_ratio + float(ally.max_hp) * 0.10)
		var restored := maxf(0.0, float(ally.hp) - before)
		visual_events.append({"kind":"heal", "source_id":target.id, "target_id":ally.id, "amount":round(restored), "style":"heal", "nonblocking":true})
	_log("[color=#e58f78]" + t("【江东联动】首次濒死触发：吴将均摊生命并恢复10%最大生命！", "[Jiangdong Relay] First lethal hit equalizes Wu health and restores 10% max HP!") + "[/color]")
	return target.hp > 0.0

func _damage(source, target: Dictionary, amount: float, damage_type: String, label: String, visual_group := "", group_style := "", scales_with_skill := true) -> float:
	if not target.alive: return 0.0
	var target_params: Dictionary = heroes[target.hero_id].get("ability_params", {})
	var is_active_skill := source != null
	if is_active_skill and int(target.get("spell_ward", 0)) > 0:
		target.spell_ward = int(target.spell_ward) - 1
		visual_events.append({"kind":"skill", "source_id":target.id, "target_id":target.id, "amount":0, "style":"shield"})
		_log(_hero_name(target.hero_id) + t(" 的紫幕抵挡了技能。", " blocks the skill with Purple Ward."))
		return 0.0
	if is_active_skill and float(target_params.get("spell_reflect", 0.0)) > 0.0 and rng.randf() < float(target_params.spell_reflect):
		_damage(null, source, amount * 0.60, damage_type, t("技能反弹", "Skill reflection"))
		_log(_hero_name(target.hero_id) + t(" 反弹了指向性技能。", " reflects the targeted skill."))
		return 0.0
	var value: float = amount
	var consumes_lvmeng_ambush := false
	value *= 1.0 + float(target.get("vulnerable", 0.0))
	if source != null:
		value *= float(source.get("stat_mult", 1.0))
		if scales_with_skill: value *= _unit_skill_power_multiplier(source)
		value *= 1.0 + source.damage_buff + float(source.get("timed_damage_buff", 0.0)) + float(source.get("kill_buff", 0.0))
		value *= maxf(0.0, 1.0 - float(source.get("skill_debuff", 0.0)))
		if source.hero_id == "lvmeng" and bool(source.get("stealth_ambush_bonus_ready", false)):
			value *= 1.0 + float(heroes.lvmeng.ability_params.get("ambush_next_damage_bonus", 0.60))
			consumes_lvmeng_ambush = true
		if heroes[source.hero_id].f == "wei" and int(source.get("faction_tier", 0)) >= 3 and _has_any_debuff(target):
			value *= 1.15
	var freeze_remaining := float(target.get("freeze", 0.0))
	if freeze_remaining > 0.0:
		var shatter_damage := freeze_remaining * float(target.get("freeze_shatter_per_second", 400.0))
		target.freeze = 0.0
		target.freeze_shatter_per_second = 0.0
		value += shatter_damage
		visual_events.append({"kind":"skill", "source_id":"" if source == null else source.id, "target_id":target.id, "amount":roundi(shatter_damage), "style":"magic"})
		_log(t("冰封提前破碎，追加 ", "Freeze shatters early for ") + str(roundi(shatter_damage)) + t(" 点伤害。", " extra damage."))
	var total_reduction: float = max(float(target.damage_reduction), float(target.get("timed_reduction", 0.0)))
	if damage_type == "magic": total_reduction = max(total_reduction, float(target.get("regen_magic_reduction", 0.0)))
	if source != null and int(source.row) == BOARD_ROWS - 1 and float(target.get("rear_damage_reduction_time", 0.0)) > 0.0:
		total_reduction += float(target.get("rear_damage_reduction", 0.0))
	if source != null and int(source.row) == 0 and float(target.get("front_damage_reduction_time", 0.0)) > 0.0:
		total_reduction += float(target.get("front_damage_reduction", 0.0))
	if target.hero_id == "sunce" and bool(target.get("sun_legacy", false)):
		var params: Dictionary = heroes.sunce.ability_params
		var missing_hp_reduction := _missing_hp_damage_multiplier(target, float(params.get("missing_hp_step", 0.10)), float(params.get("missing_hp_reduction_per_step", 0.04)) * _unit_skill_effect_multiplier(target)) - 1.0
		total_reduction += missing_hp_reduction
	value *= 1.0 - clampf(total_reduction, 0.0, 0.95)
	var faction_reduction := float(target.get("faction_damage_reduction", 0.0))
	if heroes[target.hero_id].f == "shu" and int(target.get("faction_tier", 0)) >= 3:
		faction_reduction += 0.02 * clampi(int(target.get("shu_damage_stacks", 0)), 0, 3)
	value *= 1.0 - clampf(faction_reduction, 0.0, 0.95)
	if damage_type == "magic" and float(target.get("strategy_mark", 0.0)) > 0.0 and source != null:
		value *= 1.30
		target.strategy_mark = 0.0
		visual_events.append({"kind":"skill", "source_id":source.id, "target_id":target.id, "amount":0, "style":"magic"})
		_log(t("谋略标记爆炸！", "Strategy mark detonates!"))
	if target.shield > 0:
		var absorbed: float = min(float(target.shield), value)
		target.shield -= absorbed
		value -= absorbed
		if absorbed > 0: _log(_hero_name(target.hero_id) + t(" 的护盾吸收 ", "'s shield absorbs ") + str(round(absorbed)))
	if value <= 0: return 0.0
	var hp_before: float = target.hp
	target.hp = max(0.0, target.hp - value)
	var actual_damage: float = hp_before - target.hp
	_add_stat(source, "damage", actual_damage)
	_add_stat(target, "taken", actual_damage)
	if actual_damage > 0.0 and consumes_lvmeng_ambush and source != null:
		source.stealth_ambush_bonus_ready = false
	if actual_damage > 0.0 and heroes[target.hero_id].f == "shu" and int(target.get("faction_tier", 0)) >= 3:
		target.shu_damage_stacks = mini(3, int(target.get("shu_damage_stacks", 0)) + 1)
	if actual_damage > 0.0 and bool(target.get("four_pillars", false)) and target.hero_id in ["yanliang", "wenchou"]:
		target.hebei_damage_stacks = mini(20, int(target.get("hebei_damage_stacks", 0)) + 1)
	if source != null: _apply_all_lifesteal(source, actual_damage)
	var effect_style := "effect" if source == null else ("magic" if damage_type == "magic" else ("ranged" if int(heroes[source.hero_id].range) > 2 else "melee"))
	visual_events.append({"kind":"damage", "source_id":"" if source == null else source.id, "target_id":target.id, "team":target.team, "row":target.row, "col":target.col, "amount":round(value), "skill":true, "style":effect_style, "visual_group":visual_group, "group_style":group_style})
	var source_name := t("环境", "Effect") if source == null else _hero_name(source.hero_id)
	_log(source_name + t(" 对 ", " hits ") + _hero_name(target.hero_id) + t(" 造成 ", " for ") + str(round(value)) + t(" 伤害（", " damage (") + label + "）")
	if target.hp <= 0:
		if float(target.get("death_prevention", 0.0)) > 0.0:
			target.hp = max(1.0, target.max_hp * 0.08)
			target.death_prevention = 0.0
			visual_events.append({"kind":"heal", "source_id":target.id, "target_id":target.id, "amount":round(target.hp)})
			_log("[color=#f6c860]" + _hero_name(target.hero_id) + t(" 触发羁绊免死！", " triggers a bond death ward!") + "[/color]")
			return value
		if _try_wu_equalize_and_recover(target):
			return value
		if target.hero_id == "zhangbao" and _resolve_zhangbao_death(target, source, visual_group, group_style):
			return value
		target.alive = false
		_on_unit_fallen(target, source)
		_apply_combo_bonds(false, false)
		_apply_faction_bonuses(false)
		if has_method("_refresh_bond_progress"):
			call("_refresh_bond_progress", combat_units.filter(func(unit): return unit.team == "player" and unit.alive and unit.row >= 0))
		visual_events.append({"kind":"death", "source_id":"" if source == null else source.id, "target_id":target.id, "amount":0, "visual_group":visual_group, "group_style":group_style})
		_log("[color=#df7878]" + _hero_name(target.hero_id) + t(" 阵亡！", " falls!") + "[/color]")
	return value

func _resolve_zhangbao_death(unit: Dictionary, killer, visual_group: String, group_style: String) -> bool:
	var params: Dictionary = heroes.zhangbao.ability_params
	var explosion_group := "zhangbao_death:" + str(unit.id) + ":" + str(unit.get("zhangbao_revives_used", 0))
	var targets := _pick_random_units(_enemy_units(unit.team).filter(func(enemy): return enemy.alive and float(enemy.get("stealth", 0.0)) <= 0.0), int(params.get("target_count", 2)))
	var primary_ids := {}
	for target in targets: primary_ids[str(target.id)] = true
	for target in targets:
		_damage(unit, target, _unit_skill_output_base(unit) * float(params.get("death_mult", 2.0)), "magic", t("地公雷爆", "Earth General Detonation"), explosion_group, "multi_target")
	if _pair_active(unit.team, "zhangbao", "zhangjiao"):
		var splash_targets: Array = []
		for primary in targets:
			for enemy in _enemy_units(unit.team):
				if not enemy.alive or primary_ids.has(str(enemy.id)) or splash_targets.has(enemy): continue
				if abs(int(enemy.row) - int(primary.row)) <= 1 and abs(int(enemy.col) - int(primary.col)) <= 1:
					splash_targets.append(enemy)
		for target in splash_targets:
			_damage(unit, target, _unit_skill_output_base(unit) * float(params.get("zhangjiao_splash_mult", 0.5)), "magic", t("地公雷爆余波", "Detonation Shockwave"), explosion_group, "area_impact")
	var revive_limit := int(params.get("base_revives", 1))
	if _pair_active(unit.team, "zhangbao", "zhangliang"):
		revive_limit += int(params.get("zhangliang_bonus_revives", 1))
	if int(unit.get("zhangbao_revives_used", 0)) >= revive_limit:
		return false
	unit.zhangbao_revives_used = int(unit.get("zhangbao_revives_used", 0)) + 1
	unit.hp = float(unit.max_hp)
	unit.shield = 0.0
	unit.action = 0.0
	_clear_all_debuffs(unit)
	visual_events.append({"kind":"death", "source_id":"" if killer == null else killer.id, "target_id":unit.id, "amount":0, "visual_group":visual_group, "group_style":group_style})
	visual_events.append({"kind":"heal", "source_id":unit.id, "target_id":unit.id, "amount":roundi(unit.max_hp), "style":"heal", "nonblocking":true})
	_log("[color=#e8c75d]" + _hero_name("zhangbao") + t(" 引雷自爆后满血复生！", " detonates and revives at full HP!") + "[/color]")
	return true

func _on_unit_fallen(fallen: Dictionary, killer) -> void:
	if int(fallen.row) == 0:
		for weiyan in _team_units(_enemy_team_id(str(fallen.team))).filter(func(ally): return ally.alive and ally.hero_id == "weiyan" and bool(ally.get("flying_meteor", false))):
			var restored := _heal_unit_only(weiyan, weiyan, float(weiyan.max_hp) * 0.50 * _unit_skill_effect_multiplier(weiyan))
			if restored > 0.0:
				_log(t("【飞火流星】敌方前军阵亡，魏延恢复50%最大生命。", "[Flying Meteor] An enemy frontliner falls; Wei Yan restores 50% max HP."))
	var allies := _team_units(fallen.team).filter(func(ally): return ally.alive)
	for sunshangxiang in allies.filter(func(ally): return ally.hero_id == "sunshangxiang"):
		var death_gain := float(heroes.sunshangxiang.ability_params.get("ally_death_skill_gain", 5.0))
		sunshangxiang.sunshangxiang_skill_bonus = float(sunshangxiang.get("sunshangxiang_skill_bonus", 0.0)) + death_gain
		visual_events.append({"kind":"charge", "source_id":fallen.id, "target_id":sunshangxiang.id, "amount":roundi(death_gain), "style":"physical", "nonblocking":true})
		_log("[color=#efb568]" + t("【枭姬】友军阵亡，孙尚香技能强度提高", "[Heroine] An ally falls; Sun Shangxiang gains ") + str(roundi(death_gain)) + t("点。", " SKILL.") + "[/color]")
	if fallen.hero_id == "sunjian" and bool(fallen.get("sun_legacy", false)):
		var legacy_bonus := float(heroes.sunjian.ability_params.get("death_wu_damage_bonus", 0.10)) * _unit_skill_effect_multiplier(fallen)
		for ally in allies:
			if heroes[ally.hero_id].f != "wu":
				continue
			ally.kill_buff = float(ally.get("kill_buff", 0.0)) + legacy_bonus
			visual_events.append({"kind":"skill", "source_id":fallen.id, "target_id":ally.id, "amount":roundi(legacy_bonus * 100.0), "style":"magic", "nonblocking":true})
		_log("[color=#efb568]" + t("【猛虎遗志】孙坚阵亡，存活吴将本回合伤害提高10%。", "[Tiger's Legacy] Sun Jian falls; surviving Wu allies gain 10% damage for the rest of the round.") + "[/color]")

func _hit_ruler(unit: Dictionary, amount: float, tile: Dictionary, label: String, visual_group := "", group_style := "", scales_with_skill := true) -> float:
	var value_float: float = amount * float(unit.get("stat_mult", 1.0)) * (1.0 + float(unit.damage_buff) + float(unit.get("timed_damage_buff", 0.0)) + float(unit.get("kill_buff", 0.0)))
	if scales_with_skill: value_float *= _unit_skill_power_multiplier(unit)
	value_float *= maxf(0.0, 1.0 - float(unit.get("skill_debuff", 0.0)))
	var consumes_lvmeng_ambush: bool = str(unit.hero_id) == "lvmeng" and bool(unit.get("stealth_ambush_bonus_ready", false))
	if consumes_lvmeng_ambush:
		value_float *= 1.0 + float(heroes.lvmeng.ability_params.get("ambush_next_damage_bonus", 0.60))
	var target_team := _enemy_team_id(unit.team)
	var ability := str(heroes[unit.hero_id].get("ability", ""))
	if ability in ["strike_magic", "row_magic", "multi_magic", "control"]: value_float *= 1.0 - float(ruler_regen[target_team].get("magic_reduction", 0.0))
	var value: int = round(value_float)
	var before_ruler: int = enemy_ruler_hp if unit.team == "player" else player_ruler_hp
	if unit.team == "player": enemy_ruler_hp = max(0, enemy_ruler_hp - value)
	else: player_ruler_hp = max(0, player_ruler_hp - value)
	var after_ruler: int = enemy_ruler_hp if unit.team == "player" else player_ruler_hp
	if consumes_lvmeng_ambush and before_ruler > after_ruler:
		unit.stealth_ambush_bonus_ready = false
	_add_stat(unit, "damage", float(before_ruler - after_ruler))
	visual_events.append({"kind":"empty", "source_id":unit.id, "team":tile.team, "row":tile.row, "col":tile.col, "amount":value, "skill":true, "style":"ranged" if int(heroes[unit.hero_id].range) > 2 else "melee", "visual_group":visual_group, "group_style":group_style})
	_log(_hero_name(unit.hero_id) + t(" 攻击空格（", " targets an empty tile (") + label + t("），穿透命中主公 ", ") and hits the ruler for ") + str(value) + (t(" 点伤害。", ".") if language == "zh" else ""))
	return float(before_ruler - after_ruler)

func _targets_in_range(unit: Dictionary) -> Array:
	var rows := _attackable_rows(unit)
	return _enemy_units(unit.team).filter(func(enemy): return enemy.alive and float(enemy.get("stealth", 0.0)) <= 0.0 and rows.has(int(enemy.row)))

func _attackable_rows(unit: Dictionary) -> Array:
	var tier := int(heroes[unit.hero_id].range)
	if unit.hero_id == "zhaoyun" and _pair_active(unit.team, "zhaoyun", "liushan"): return [2]
	if tier == 1: return [0]
	if tier == 2:
		if int(unit.row) <= 0: return [0, 1, 2]
		if int(unit.row) == 1: return [0, 1]
		return [0]
	return [0, 1, 2]

func _team_units(team: String) -> Array:
	return combat_units.filter(func(unit): return unit.team == team)

func _enemy_units(team: String) -> Array:
	return combat_units.filter(func(unit): return unit.team != team)

func _has_winner() -> bool:
	return player_ruler_hp <= 0 or enemy_ruler_hp <= 0
