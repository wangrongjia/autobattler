extends "res://ThreeKingdom/systems/game_flow.gd"

const SKILL_VOICE_ROOT := "res://ThreeKingdom/audio/voices/skills/"
const SKILL_VOICE_VARIANTS := 3

func _skill_voice_paths(hero_id: String) -> Array[String]:
	var paths: Array[String] = []
	for index in range(1, SKILL_VOICE_VARIANTS + 1):
		var path := SKILL_VOICE_ROOT + hero_id + "_skills_" + str(index) + ".mp3"
		if ResourceLoader.exists(path):
			paths.append(path)
	return paths

func _play_hero_voice(hero_id: String, force := false) -> void:
	# 武将台词：选将锁定/上阵时喊话(force=true 立即重播)；技能释放不再播台词，交由击打音效表现。
	if not is_instance_valid(skill_voice_player): return
	if not force and skill_voice_player.playing: return
	var paths := _skill_voice_paths(hero_id)
	if paths.is_empty():
		return
	var selected_path := paths[rng.randi_range(0, paths.size() - 1)]
	var stream = load(selected_path)
	if stream == null:
		return
	skill_voice_player.stream = stream
	skill_voice_player.play()

func _ensure_unit_fields(unit: Dictionary) -> void:
	var defaults := {"silence":0.0, "stealth":0.0, "slow":0.0, "slow_time":0.0, "vulnerable":0.0, "vulnerable_time":0.0, "grievous":0.0, "grievous_time":0.0, "strategy_mark":0.0, "zhuge_fire_mark":0.0, "spell_ward":0, "cast_count":0, "focus_target":"", "focus_stacks":0, "faction_tier":0, "faction_damage_reduction":0.0, "faction_hp_bonus":0.0, "faction_control_bonus":0.0, "faction_cooldown_reduction":0.0, "shu_damage_stacks":0, "shu_damage_decay_time":0.0,"four_heroes":false, "lvmeng_ganning":false, "stealth_ambush_bonus_ready":false, "burn_missing_hp_scale":false, "burn_effects":[], "fear":0.0, "fear_damage_ratio":0.0, "fear_clock":0.0, "freeze":0.0, "freeze_shatter_damage":0.0, "freeze_shatter_per_second":0.0, "freeze_source_id":"", "poison":0.0, "poison_ratio":0.0, "poison_stacks":0, "poison_clock":0.0, "poison_source":"", "poison_effects":[], "regen_per_second":0.0, "regen_time":0.0, "regen_clock":0.0, "regen_damage_reduction":0.0, "regen_source":"", "timed_damage_buff":0.0, "timed_damage_time":0.0, "timed_damage_buff_source":"", "timed_reduction":0.0, "timed_reduction_time":0.0, "timed_action_bonus":0.0, "timed_action_time":0.0, "rear_damage_reduction":0.0, "rear_damage_reduction_time":0.0, "front_damage_reduction":0.0, "front_damage_reduction_time":0.0, "all_lifesteal":0.0, "all_lifesteal_time":0.0, "invulnerable_time":0.0, "bond_haste":0.0, "sunquan_initial_max_hp":0.0, "sunshangxiang_skill_bonus":0.0, "skill_value_bonus":0.0, "gaolan_skill_value_bonus":0.0, "gaolan_aura_source":"", "timed_skill_value_bonus":0.0, "timed_skill_value_time":0.0, "liushan_aura_damage_bonus":0.0, "liushan_aura_lifesteal":0.0, "chain_effects":[], "four_pillars":false, "charm_forced_attack":false, "charm_attack_clock":0.0, "dongzhuo_diaochan_hp_bonus":0.0, "skill_debuff_time":0.0, "zhangbao_revives_used":0}
	for key in defaults:
		if not unit.has(key): unit[key] = defaults[key]

func _sync_dot_summaries(unit: Dictionary) -> void:
	var burn_time := 0.0
	var burn_damage := 0.0
	for effect in unit.get("burn_effects", []):
		burn_time = maxf(burn_time, float(effect.get("time", 0.0)))
		burn_damage += float(effect.get("damage", 0.0))
	unit.burn = burn_time
	unit.burn_damage = burn_damage
	var poison_stacks := 0
	for effect in unit.get("poison_effects", []):
		poison_stacks += int(effect.get("stacks", 0))
	unit.poison = 1.0 if poison_stacks > 0 else 0.0
	unit.poison_stacks = poison_stacks

func _migrate_legacy_dots(unit: Dictionary) -> void:
	_ensure_unit_fields(unit)
	if (unit.get("burn_effects", []) as Array).is_empty() and float(unit.get("burn", 0.0)) > 0.0:
		unit.burn_effects = [{"source_id":"", "time":float(unit.burn), "clock":float(unit.get("burn_clock", 0.0)), "damage":float(unit.get("burn_damage", 0.0)), "missing_hp_scale":bool(unit.get("burn_missing_hp_scale", false)), "visual_group":str(unit.get("burn_visual_group", ""))}]

func _add_burn_effect(source: Variant, target: Dictionary, duration: float, damage_per_second: float, missing_hp_scale := false, visual_group := "", missing_hp_step := 0.10, missing_hp_bonus_per_step := 0.05) -> void:
	if target == null or not target.alive or duration <= 0.0 or damage_per_second <= 0.0: return
	duration *= _tianshu_dot_duration_multiplier(source)
	damage_per_second *= _tianshu_dot_damage_multiplier(source)
	_migrate_legacy_dots(target)
	var effects: Array = target.get("burn_effects", [])
	effects.append({"source_id":str(source.get("id", "")) if source != null else "", "time":duration, "clock":0.0, "damage":damage_per_second, "missing_hp_scale":missing_hp_scale, "visual_group":visual_group, "missing_hp_step":missing_hp_step, "missing_hp_bonus_per_step":missing_hp_bonus_per_step})
	target.burn_effects = effects
	_sync_dot_summaries(target)

func _add_decay_poison_effect(source: Variant, target: Dictionary, stacks: int, retention := 0.5) -> void:
	if target == null or not target.alive or stacks <= 0: return
	stacks = roundi(float(stacks) * _tianshu_dot_damage_multiplier(source))
	retention = clampf(retention + (1.0 - retention) * (_tianshu_dot_duration_multiplier(source) - 1.0), 0.0, 0.95)
	_migrate_legacy_dots(target)
	var effects: Array = target.get("poison_effects", [])
	var merged := false
	for effect in effects:
		if effect.has("stacks"):
			# 毒统一合并累加：已有 N 层再施加 M 层 = N+M 层；衰减率与伤害归属以后施加者为准。
			effect.stacks = int(effect.get("stacks", 0)) + stacks
			effect.retention = retention
			effect.source_id = str(source.get("id", "")) if source != null else ""
			merged = true
			break
	if not merged:
		effects.append({"source_id":str(source.get("id", "")) if source != null else "", "clock":0.0, "stacks":stacks, "retention":retention})
	target.poison_effects = effects
	_sync_dot_summaries(target)

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
			var destiny_mult := _talent_bond_multiplier(team)
			var tier_value := _faction_tier_value(tier, [0.02, 0.05, 0.08]) * destiny_mult
			unit.faction_tier = tier
			unit.faction_damage_reduction = tier_value if faction == "shu" else 0.0
			unit.faction_control_bonus = tier_value if faction == "wei" else 0.0
			unit.faction_cooldown_reduction = tier_value * BOND_COOLDOWN_REDUCTION_MULTIPLIER if faction == "qun" else 0.0
			_set_wu_hp_bonus(unit, tier_value if faction == "wu" else 0.0)
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
	if _talent_opening_action_bonus():
		var allies := combat_units.filter(func(unit): return unit.team == "player" and unit.alive)
		allies.shuffle()
		for index in mini(3, allies.size()): allies[index].action = minf(ACTION_MAX, float(allies[index].action) + 30.0)

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
		unit.bond_haste = 0.0
		unit.dingfeng_xusheng = false
		unit.heaven_death = false
		unit.one_rider = false
		unit.fated_enemies = false
		unit.flying_meteor = false
		if unit.team == "enemy":
			unit.skill_value_bonus = _challenge_strategy_bonus()
		else:
			var progression_bonus := _talent_stat_bonus(str(unit.hero_id))
			var rune_bonus := _rune_stat_bonus(str(unit.hero_id))
			unit.skill_value_bonus = float(progression_bonus.strategy) + float(rune_bonus.strategy)
		unit.gaolan_skill_value_bonus = 0.0
		unit.gaolan_aura_source = ""
		unit.liushan_aura_damage_bonus = 0.0
		unit.liushan_aura_lifesteal = 0.0
		unit.four_pillars = false
		if unit.hero_id == "dongzhuo":
			_set_runtime_max_hp_bonus(unit, "dongzhuo_diaochan_hp_bonus", 0.0)
	for team in ["player", "enemy"]:
		var active := _team_units(team)
		if _roster_has_all(active, ["liubei", "guanyu", "zhangfei"]):
			if announce: _log(t("【桃园结义】刘备每秒治疗提高至200%兵略值，关羽恢复30%实际伤害，张飞号令持续时间增加50%。", "[Peach Garden] Liu Bei heals at 200% Strategy, Guan Yu heals for 30% actual damage, and Zhang Fei's command lasts 50% longer."))
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
			_set_runtime_max_hp_bonus(bonded_dongzhuo, "dongzhuo_diaochan_hp_bonus", float(heroes.dongzhuo.ability_params.get("diaochan_max_hp_bonus", 0.40)))
			if announce: _log(t("【暴君倾城】董卓最大生命值提高40%；貂蝉魅惑延长3.6秒并在施法时治疗自身。", "[Tyrant and Beauty] Dong Zhuo gains 40% max HP; Diao Chan gains 3.6s charm and self-healing."))
		if _roster_has_all(active, ["guanyu", "zhangfei", "zhaoyun", "huangzhong", "machao"]):
			if announce: _log(t("【五虎上将】五虎技能获得各自强化。", "[Five Tigers] The five generals empower their own skills."))
		if _roster_has_all(active, ["machao", "madai"]):
			var machao = _combat_hero(team, "machao")
			var madai = _combat_hero(team, "madai")
			machao.one_rider = true
			madai.one_rider = true
			if opening: madai.action = ACTION_MAX
			if announce: _log(t("【一骑当千】马超贯穿改为260%/300%/340%兵略值；马岱开场立即释放技能。", "[One Rider] Ma Chao pierces for 260%/300%/340% Strategy; Ma Dai starts ready."))
		if _roster_has_all(active, ["weiyan", "madai"]):
			_combat_hero(team, "weiyan").fated_enemies = true
			_combat_hero(team, "madai").fated_enemies = true
			if announce: _log(t("【宿命之敌】马岱施加本回合30%易损；魏延按本次伤害的6%治疗相邻与正后方友军。", "[Fated Enemies] Ma Dai applies 30% vulnerability for the round; Wei Yan shares 6% of cast damage as healing."))
		if _roster_has_all(active, ["weiyan", "huangzhong"]):
			_combat_hero(team, "weiyan").flying_meteor = true
			_combat_hero(team, "huangzhong").flying_meteor = true
			if announce: _log(t("【飞火流星】黄忠有30%概率造成双倍伤害；魏延恢复本次技能实际伤害的23%。", "[Flying Meteor] Huang Zhong has a 30% double-damage chance; Wei Yan heals for 23% of cast damage."))
		var liushan = _combat_hero(team, "liushan")
		if liushan != null and liushan.alive:
			var same_column := _pair_active(team, "liushan", "liubei")
			var aura_bonus := float(heroes.liushan.ability_params.get("liubei_damage_ratio", 0.18) if same_column else heroes.liushan.ability_params.get("damage_ratio", 0.27)) * _unit_skill_effect_multiplier(liushan)
			for ally in active:
				if not ally.alive or ally.id == liushan.id: continue
				var affected := int(ally.col) == int(liushan.col) if same_column else (int(ally.col) == int(liushan.col) and int(ally.row) == int(liushan.row) - 1)
				if affected:
					ally.liushan_aura_damage_bonus = aura_bonus
					if _pair_active(team, "liushan", "zhaoyun"): ally.liushan_aura_lifesteal = float(heroes.liushan.ability_params.get("seven_lifesteal", 0.30)) * _unit_skill_effect_multiplier(liushan)
		if _roster_has_all(active, ["zhangliao", "yuejin"]):
			if announce: _log(t("【逍遥津先锋】张辽与乐进互相强化技能。", "[Hefei Vanguard] Zhang Liao and Yue Jin empower each other's skills."))
		if _roster_has_all(active, ["zhanghe", "xuhuang"]):
			if announce: _log(t("【巧变开山】张郃与徐晃互相强化技能。", "[Adaptive Vanguard] Zhang He and Xu Huang empower each other's skills."))
		if _roster_has_all(active, ["zhangliao", "yuejin", "zhanghe", "xuhuang", "yujin"]):
			if announce: _log(t("【五子良将】五人绝技全部获得完全体强化。", "[Five Elite Generals] All five signature skills reach their complete form."))
		var xiahouyuan = _combat_hero(team, "xiahouyuan")
		if xiahouyuan != null:
			var cd_reduction := _scaled_cooldown_reduction(float(heroes.xiahouyuan.ability_params.get("bond_cooldown_reduction", 0.5)))
			if _roster_has_all(active, ["xiahouyuan", "caoren"]): _add_bond_cooldown_haste(xiahouyuan, cd_reduction)
			if _roster_has_all(active, ["xiahouyuan", "xiahoudun"]): _add_bond_cooldown_haste(xiahouyuan, cd_reduction)
		var guojia = _combat_hero(team, "guojia")
		if guojia != null:
			if _roster_has_all(active, ["guojia", "jiaxu"]): _add_bond_cooldown_haste(guojia, _scaled_cooldown_reduction(float(heroes.guojia.ability_params.get("jiaxu_cooldown_reduction", 1.6))))
		var xunyu = _combat_hero(team, "xunyu")
		if xunyu != null:
			if _roster_has_all(active, ["xunyu", "jiaxu"]): _add_bond_cooldown_haste(xunyu, _scaled_cooldown_reduction(float(heroes.xunyu.ability_params.get("jiaxu_cooldown_reduction", 1.6))))
		var jiaxu = _combat_hero(team, "jiaxu")
		if jiaxu != null:
			if _roster_has_all(active, ["jiaxu", "xunyu"]): _add_bond_cooldown_haste(jiaxu, _scaled_cooldown_reduction(float(heroes.jiaxu.ability_params.get("xunyu_cooldown_reduction", 1.6))))
		if _roster_has_all(active, ["sunjian", "sunce", "sunquan", "sunshangxiang"]):
			for id in ["sunjian", "sunce", "sunquan", "sunshangxiang"]: _combat_hero(team, id).sun_legacy = true
			if announce: _log(t("【孙氏之志】强化孙坚、孙策、孙权与孙尚香的专属技能。", "[Sun Legacy] Empowers the signature skills of Sun Jian, Sun Ce, Sun Quan, and Sun Shangxiang."))
		if _roster_has_all(active, ["lvmeng", "ganning"]):
			_combat_hero(team, "lvmeng").lvmeng_ganning = true
			_combat_hero(team, "ganning").lvmeng_ganning = true
		if _roster_has_all(active, ["sunce", "taishici"]):
			_combat_hero(team, "sunce").sunce_taishi = true
			_combat_hero(team, "taishici").sunce_taishi = true
			if announce: _log(t("【神亭酣战】孙策伤害增加50%兵略值；太史慈目标+1、直接伤害减少30%兵略值。", "[Shenting Duel] Sun Ce gains 50% Strategy damage; Taishi Ci gains 1 target but loses 30% Strategy direct damage."))
		if _roster_has_all(active, ["sunce", "daqiao"]):
			_combat_hero(team, "sunce").sunce_daqiao = true
			_combat_hero(team, "daqiao").sunce_daqiao = true
			if announce: _log(t("【江东佳偶】孙策残血时获得减伤；大乔根据目标已损失生命提高治疗。", "[Jiangdong Couple] Sun Ce gains damage reduction at low HP; Da Qiao scales healing with the target's missing HP."))
		if _roster_has_all(active, ["zhouyu", "xiaoqiao"]):
			_combat_hero(team, "zhouyu").zhouyu_xiaoqiao = true
			_combat_hero(team, "xiaoqiao").zhouyu_xiaoqiao = true
			if announce: _log(t("【琴瑟和鸣】周瑜灼烧延长3秒并增加30%兵略值伤害；小乔目标增加1名。", "[Harmonious Zither] Zhou Yu's burn gains 3s and 30% Strategy damage; Xiao Qiao gains 1 target."))
		if _roster_has_all(active, ["zhouyu", "huanggai"]):
			_combat_hero(team, "zhouyu").zhouyu_huanggai = true
			_combat_hero(team, "huanggai").zhouyu_huanggai = true
			if announce: _log(t("【赤壁苦计】周瑜灼烧随目标已损生命增强；黄盖列攻附加5秒、每秒50%兵略值灼烧。", "[Red Cliffs Ruse] Zhou Yu's burn scales with missing HP; Huang Gai's column strike burns for 5s at 50% Strategy per second."))
		if _roster_has_all(active, ["huanggai", "sunjian"]):
			_combat_hero(team, "huanggai").huanggai_sunjian = true
			_combat_hero(team, "sunjian").huanggai_sunjian = true
			if opening: _combat_hero(team, "sunjian").action = ACTION_MAX
			if announce: _log(t("【江东柱石】黄盖消耗15%最大生命且消耗生命伤害系数提高至50%；孙坚开局满行动条。", "[Pillars of Jiangdong] Huang Gai spends 15% max HP with a 50% spent-HP coefficient; Sun Jian starts ready."))
		if _roster_has_all(active, ["taishici", "ganning"]):
			_combat_hero(team, "taishici").taishici_ganning = true
			_combat_hero(team, "ganning").taishici_ganning = true
			var bonded_ganning = _combat_hero(team, "ganning")
			_add_bond_cooldown_haste(bonded_ganning, _scaled_cooldown_reduction(float(heroes.ganning.ability_params.get("taishici_cooldown_reduction", 1.2))))
			if announce: _log(t("【江表双锋】太史慈伤害增加60%兵略值；甘宁获得18冷却极速。", "[Twin Blades of Jiangbiao] Taishi Ci gains 60% Strategy damage; Gan Ning gains 18 cooldown haste."))
		if _roster_has_all(active, ["luxun", "sunquan"]):
			_combat_hero(team, "luxun").luxun_sunquan = true
			_combat_hero(team, "sunquan").luxun_sunquan = true
			if announce: _log(t("【君臣同心】陆逊火球增加80%兵略值伤害，灼烧目标再增加40%；孙权伤害改为自身当前生命的11%。", "[Sovereign and Minister] Lu Xun gains 80% Strategy damage plus 40% against burning targets; Sun Quan deals 11% of his current HP."))
		if _roster_has_all(active, ["dingfeng", "xusheng"]):
			_combat_hero(team, "dingfeng").dingfeng_xusheng = true
			_combat_hero(team, "xusheng").dingfeng_xusheng = true
			if announce: _log(t("【江表虎臣】丁奉伤害增加100%兵略值并压退70%行动条；徐盛改为随机一排且水阵延长3秒。", "[Tiger Ministers] Ding Feng gains 100% Strategy damage and pushes back 70% gauge; Xu Sheng targets a random row and the water formation gains 3s."))
		var four_pillars := _roster_has_all(active, ["yanliang", "wenchou", "qunzhanghe", "gaolan"])
		if four_pillars:
			for id in ["yanliang", "wenchou", "qunzhanghe", "gaolan"]:
				var pillar = _combat_hero(team, id)
				if pillar != null: pillar.four_pillars = true
			if announce: _log(t("【河北四庭柱】颜良、文丑增加目标与伤害，高览扩大兵略值光环，群张郃强化护盾。", "[Hebei Pillars] Yan Liang and Wen Chou gain targets and damage, Gao Lan expands his Strategy aura, and Zhang He empowers his wards."))
		var chengong = _combat_hero(team, "chengong")
		if chengong != null and chengong.alive:
			var haste_ratio := float(heroes.chengong.ability_params.get("haste_ratio", 0.24))
			if _roster_has_all(active, ["chengong", "lvbu"]): haste_ratio += float(heroes.chengong.ability_params.get("lvbu_haste_ratio", 0.16))
			if _roster_has_all(active, ["chengong", "gaoshun"]): haste_ratio += float(heroes.chengong.ability_params.get("gaoshun_haste_ratio", 0.16))
			var bond_haste := _unit_skill_stat_value(chengong) * haste_ratio * _unit_skill_effect_multiplier(chengong)
			for ally in active:
				if not ally.alive or int(ally.col) != int(chengong.col): continue
				ally.bond_haste = float(ally.get("bond_haste", 0.0)) + bond_haste
				# 增益估算（冷却类，仅开场记一次）：出手频率增幅≈极速/(100+极速)。
				if opening and ally.id != chengong.id:
					_add_stat(chengong, "buff", _unit_live_dps(ally) * (bond_haste / (100.0 + bond_haste)) * SUPPORT_AURA_HORIZON)
		var gaolan = _combat_hero(team, "gaolan")
		if gaolan != null and gaolan.alive:
			var skill_bonus_ratio := float(heroes.gaolan.ability_params.get("skill_bonus_ratio", 0.20))
			if _roster_has_all(active, ["gaolan", "qunzhanghe"]): skill_bonus_ratio = float(heroes.gaolan.ability_params.get("zhanghe_skill_bonus_ratio", 0.25))
			if four_pillars: skill_bonus_ratio = float(heroes.gaolan.ability_params.get("four_pillars_skill_bonus_ratio", 0.25))
			var skill_bonus := _unit_skill_stat_value(gaolan) * skill_bonus_ratio
			for ally in active:
				if not ally.alive: continue
				var affected := int(ally.col) == int(gaolan.col)
				if four_pillars: affected = affected or int(ally.row) == int(gaolan.row)
				if affected:
					ally.gaolan_skill_value_bonus = skill_bonus
					ally.gaolan_aura_source = str(gaolan.id)
					# 增益估算（兵略光环类，仅开场记一次）：加成占比×dps×预期剩余时长。
					if opening and ally.id != gaolan.id:
						var ally_skill := _unit_skill_stat_value(ally)
						if ally_skill > 0.0:
							_add_stat(gaolan, "buff", _unit_live_dps(ally) * (skill_bonus / ally_skill) * SUPPORT_AURA_HORIZON)
		_sync_duplicate_bond_benefits(team, opening)

func _sync_duplicate_bond_benefits(team: String, opening: bool) -> void:
	var templates := {}
	var fields := ["heal_multiplier", "charm_multiplier", "control_multiplier", "current_hp_ratio", "ghost_bond", "multi_bonus", "burn_multiplier", "heal_extra_targets", "four_heroes", "lvmeng_ganning", "sun_legacy", "ambush_link", "sunce_taishi", "sunce_daqiao", "zhouyu_xiaoqiao", "zhouyu_huanggai", "huanggai_sunjian", "taishici_ganning", "luxun_sunquan", "bond_haste", "dingfeng_xusheng", "heaven_death", "one_rider", "fated_enemies", "flying_meteor", "skill_value_bonus", "liushan_aura_damage_bonus", "liushan_aura_lifesteal", "four_pillars"]
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

func _grant_shield(target: Dictionary, amount: float, source = null) -> void:
	if not target.alive or amount <= 0.0: return
	if source != null:
		amount *= 1.0 + _endless_imprint_value(source, "shield_pct")
	var cap: float = max(float(target.shield), amount * 2.0)
	var applied: float = min(float(target.shield) + amount, cap) - float(target.shield)
	target.shield += applied
	# 护盾量计入统计（只记实际生效增量，受2倍上限约束的部分不算），供 MVP 评分使用。
	if applied > 0.0: _add_stat(source, "shield", applied)

func _combat_hero(team: String, hero_id: String):
	for unit in _team_units(team):
		if unit.hero_id == hero_id and unit.alive and int(unit.row) >= 0: return unit
	for unit in _team_units(team):
		if unit.hero_id == hero_id: return unit
	return null

func _add_stat(unit, key: String, amount: float) -> void:
	if unit == null or not battle_stats.has(unit.id): return
	battle_stats[unit.id][key] = float(battle_stats[unit.id].get(key, 0.0)) + amount

const SUPPORT_AURA_HORIZON := 15.0   # 被动增益折算的预期生效秒数（战斗上限30秒，取一半作均值）

func _credit_damage_buff_sources(source: Dictionary, actual_damage: float) -> void:
	# 增益归因（伤害加成类）：从实际伤害反推"队友增益带来的反事实增量"，按比例记到来源名下。
	# timed_damage_buff=主动/天书增伤（刘禅、张飞、曹操军令等），liushan_aura=刘禅被动光环；自身加成不重复记。
	var timed := float(source.get("timed_damage_buff", 0.0))
	var aura := float(source.get("liushan_aura_damage_bonus", 0.0))
	var ally_buff := timed + aura
	if ally_buff <= 0.0 or actual_damage <= 0.0: return
	var others := float(source.damage_buff) + float(source.get("kill_buff", 0.0))
	var amplified: float = actual_damage * ally_buff / (1.0 + others + ally_buff)
	if timed > 0.0:
		var timed_src = _find_by_id(combat_units, str(source.get("timed_damage_buff_source", "")))
		if timed_src != null and str(timed_src.id) != str(source.id):
			_add_stat(timed_src, "buff", amplified * timed / ally_buff)
	if aura > 0.0:
		var aura_src = _find_by_id(combat_units, str(source.get("liushan_aura_source", "")))
		if aura_src != null and str(aura_src.id) != str(source.id):
			_add_stat(aura_src, "buff", amplified * aura / ally_buff)

func _unit_live_dps(unit: Dictionary) -> float:
	# 实时估算单位每秒输出：已有战斗数据用累计输出/时长，开场无数据时用兵略值×1.6粗估（普攻+绝技折合）。
	var entry: Dictionary = battle_stats.get(unit.id, {})
	var dealt := float(entry.get("damage", 0.0))
	if battle_time > 1.0 and dealt > 0.0: return dealt / battle_time
	return _unit_skill_stat_value(unit) * 1.6

func _capture_battle_stats() -> void:
	last_battle_stats = []
	for entry in battle_stats.values(): last_battle_stats.append(entry.duplicate(true))

func _round_damage_totals() -> Vector2:
	# 本回合内两队的伤害小计(battle_stats 每场战斗开始时会重建，只有本回合数据)。
	var player_damage := 0.0
	var enemy_damage := 0.0
	for entry in battle_stats.values():
		if str(entry.get("team", "")) == "player": player_damage += float(entry.get("damage", 0.0))
		else: enemy_damage += float(entry.get("damage", 0.0))
	return Vector2(player_damage, enemy_damage)

func _record_replay_sample() -> void:
	# 回放曲线采样：每 ≥0.5 秒战斗时间记一次双方主公生命与两队整关累计伤害，供结算画面绘制曲线。
	if battle_time - replay_last_sample_t < 0.5: return
	replay_last_sample_t = battle_time
	var totals := _round_damage_totals()
	stage_replay_curve.append({"t": stage_time_offset + battle_time, "pr":player_ruler_hp, "er":enemy_ruler_hp, "pd":stage_damage_player + totals.x, "ed":stage_damage_enemy + totals.y})

func _push_final_replay_sample() -> void:
	# 回合结束的精确终点采样 + 回合分隔标记，保证曲线收尾与判定瞬间一致。
	replay_last_sample_t = -1.0
	var totals := _round_damage_totals()
	stage_replay_curve.append({"t": stage_time_offset + battle_time, "pr":player_ruler_hp, "er":enemy_ruler_hp, "pd":stage_damage_player + totals.x, "ed":stage_damage_enemy + totals.y})
	stage_time_offset += battle_time
	stage_damage_player += totals.x
	stage_damage_enemy += totals.y
	stage_replay_round_marks.append(stage_time_offset)

func _accumulate_stage_stats() -> void:
	# 把本场 battle_stats 累加进整关统计，供结算画面评选整关 MVP 与数据王。
	for entry in battle_stats.values():
		var uid := str(entry.get("unit_id", ""))
		if uid == "": continue
		if not stage_stats_totals.has(uid):
			stage_stats_totals[uid] = {"unit_id":uid, "hero_id":str(entry.get("hero_id", "")), "team":str(entry.get("team", "")), "level":int(entry.get("level", 1)), "damage":0.0, "healing":0.0, "taken":0.0, "control":0.0, "shield":0.0, "buff":0.0}
		var total: Dictionary = stage_stats_totals[uid]
		for key in ["damage", "healing", "taken", "control", "shield", "buff"]:
			total[key] = float(total.get(key, 0.0)) + float(entry.get(key, 0.0))

func _snapshot_battle_lineup() -> void:
	# 最终一场双方阵容快照：结算画面延迟显示，避免依赖战斗对象存活。
	last_battle_lineup = []
	for unit in combat_units:
		if int(unit.row) < 0: continue
		last_battle_lineup.append({"hero_id":str(unit.hero_id), "team":str(unit.team), "level":int(unit.get("level", 1)), "hp":float(unit.hp), "max_hp":float(unit.max_hp), "alive":bool(unit.alive)})

func _unit_action_gain_multiplier(unit: Dictionary) -> float:
	var result := float(unit.get("action_gain_mult", 1.0))
	result *= 1.0 + float(unit.get("timed_action_bonus", 0.0))
	result *= 1.0 + float(unit.get("endless_action_gain_pct", 0.0))
	result *= float(unit.get("endless_enemy_action_gain", 1.0))
	var cooldown_reduction := clampf(float(unit.get("faction_cooldown_reduction", 0.0)), 0.0, 0.95)
	if cooldown_reduction > 0.0:
		result /= 1.0 - cooldown_reduction
	return result

func _unit_skill_cooldown(unit: Dictionary) -> float:
	# 所有来源汇入同一冷却极速池：实际冷却 = 基础冷却 × 100 / (100 + 极速)。
	# 极速越高收益越递减；最终冷却最低 2 秒。负极速会按同一公式拖慢冷却。
	var base := float(heroes[unit.hero_id].cooldown)
	if base <= 0.05: return 0.0
	var haste := maxf(-90.0, _unit_cooldown_haste(unit))
	return maxf(2.0, base * 100.0 / (100.0 + haste))

func _unit_cooldown_haste(unit: Dictionary) -> float:
	return float(unit.get("talent_cooldown_haste", 0.0)) \
		+ float(unit.get("rune_cooldown_haste", 0.0)) \
		+ float(unit.get("bond_haste", 0.0)) \
		+ float(unit.get("endless_cooldown_haste", 0.0)) \
		+ _tianshu_cooldown_haste(unit)

func _add_bond_cooldown_haste(unit: Dictionary, equivalent_seconds: float) -> void:
	var base := float(heroes[unit.hero_id].cooldown)
	if base <= 0.05 or equivalent_seconds <= 0.0: return
	unit.bond_haste = float(unit.get("bond_haste", 0.0)) + equivalent_seconds / base * 100.0

func _unit_has_active_skill(unit: Dictionary) -> bool:
	return str(heroes[unit.hero_id].get("ability", "")) != "passive"

func _unit_skill_power_multiplier(unit: Dictionary) -> float:
	return maxf(0.0, _unit_skill_stat_value(unit) / 100.0)

func _unit_skill_stat_value(unit: Dictionary) -> float:
	var value := float(heroes[unit.hero_id].skill_value) + float(unit.get("skill_value_bonus", 0.0)) + float(unit.get("gaolan_skill_value_bonus", 0.0)) + float(unit.get("timed_skill_value_bonus", 0.0)) + float(unit.get("sunshangxiang_skill_bonus", 0.0)) + _tianshu_strategy_bonus(unit)
	return value * _tianshu_strategy_multiplier(unit)

func _unit_scaled_skill_value(unit: Dictionary) -> float:
	return _unit_skill_stat_value(unit) * maxf(0.0, 1.0 - float(unit.get("skill_debuff", 0.0)))

func _unit_skill_effect_multiplier(unit: Dictionary) -> float:
	return _unit_skill_power_multiplier(unit) * maxf(0.0, 1.0 - float(unit.get("skill_debuff", 0.0))) * (1.0 + _endless_imprint_value(unit, "skill_effect_pct"))

func _endless_imprint_value(unit, key: String, fallback := 0.0) -> float:
	if unit == null: return fallback
	var imprint = unit.get("endless_imprint_mod", {})
	return float(imprint.get(key, fallback)) if imprint is Dictionary else fallback

func _endless_imprint_damage_multiplier(source: Dictionary, target: Dictionary, group_style: String) -> float:
	var result := 1.0
	var target_ratio := float(target.hp) / maxf(1.0, float(target.max_hp))
	var source_ratio := float(source.hp) / maxf(1.0, float(source.max_hp))
	if int(target.row) == 0: result += _endless_imprint_value(source, "damage_front_pct")
	elif int(target.row) == 1: result += _endless_imprint_value(source, "damage_mid_pct")
	else: result += _endless_imprint_value(source, "damage_back_pct")
	if target_ratio <= 0.50: result += _endless_imprint_value(source, "damage_low_pct")
	if target_ratio >= 0.95: result += _endless_imprint_value(source, "damage_full_hp_pct")
	if source_ratio <= 0.50: result += _endless_imprint_value(source, "damage_self_low_pct")
	if source_ratio >= 0.80: result += _endless_imprint_value(source, "high_hp_damage_pct")
	if _has_any_debuff(target): result += _endless_imprint_value(source, "damage_debuff_pct")
	if float(target.get("burn", 0.0)) > 0.0: result += _endless_imprint_value(source, "damage_burning_pct")
	if float(target.get("poison", 0.0)) > 0.0: result += _endless_imprint_value(source, "damage_poisoned_pct")
	if float(target.get("charm", 0.0)) > 0.0: result += _endless_imprint_value(source, "damage_charmed_pct")
	if float(target.get("action", 0.0)) >= ACTION_MAX * 0.80: result += _endless_imprint_value(source, "damage_high_action_pct")
	if group_style == "burn_tick": result += _endless_imprint_value(source, "burn_damage_pct")
	if group_style == "poison_tick": result += _endless_imprint_value(source, "poison_damage_pct")
	return maxf(0.0, result)

func _control_duration_multiplier(unit: Dictionary) -> float:
	return float(unit.get("control_multiplier", 1.0)) * (1.0 + float(unit.get("faction_control_bonus", 0.0))) * _tianshu_control_source_multiplier(unit)

func _scaled_control_duration(unit: Dictionary, duration: float, include_effect_multiplier := false) -> float:
	var multiplier := CONTROL_DURATION_MULTIPLIER * _control_duration_multiplier(unit)
	if include_effect_multiplier:
		multiplier *= _unit_effect_multiplier(unit)
	return floorf(maxf(0.0, duration) * multiplier * 10.0 + 0.0001) / 10.0

func _scaled_cooldown_reduction(reduction: float) -> float:
	return floorf(maxf(0.0, reduction) * BOND_COOLDOWN_REDUCTION_MULTIPLIER * 10.0 + 0.0001) / 10.0

func _battle_tick() -> void:
	if not battle_running or battle_paused: return
	if _has_winner():
		if not action_in_progress: _finish_battle()
		return
	if battle_time >= BATTLE_LIMIT and not final_battle:
		if not action_in_progress: _finish_battle()
		return
	if not action_in_progress and not visual_events.is_empty():
		_begin_effect_pause()
		return
	if not action_in_progress:
		var already_ready := combat_units.filter(func(unit): return unit.alive and _unit_has_active_skill(unit) and unit.stun <= 0 and unit.charm <= 0 and float(unit.get("fear", 0.0)) <= 0.0 and float(unit.get("freeze", 0.0)) <= 0.0 and float(unit.action) >= ACTION_MAX)
		if not already_ready.is_empty():
			_begin_action(already_ready[0])
			return
	var delta := TICK * battle_speed
	battle_time += delta
	_record_replay_sample()
	_process_statuses(delta)
	var ambient_events: Array = visual_events.filter(func(event): return bool(event.get("nonblocking", false)))
	if not ambient_events.is_empty():
		visual_events = visual_events.filter(func(event): return not bool(event.get("nonblocking", false)))
		_queue_ambient_visual_events(ambient_events)
	# 行动条与战斗时钟不再受状态动画或主动技能动画阻塞。动画期间只禁止开始下一次技能结算。
	for unit in combat_units:
		if not unit.alive or not _unit_has_active_skill(unit) or unit.stun > 0 or unit.charm > 0 or float(unit.get("fear", 0.0)) > 0.0 or float(unit.get("freeze", 0.0)) > 0.0: continue
		var gain_per_second: float = ACTION_MAX / maxf(0.001, _unit_skill_cooldown(unit))
		var silence_slow := 0.5 if float(unit.get("silence", 0.0)) > 0.0 else 0.0
		unit.action = min(ACTION_MAX, float(unit.action) + gain_per_second * delta * _unit_action_gain_multiplier(unit) * (1.0 - float(unit.get("slow", 0.0)) - silence_slow))
	_update_action_bars()
	_update_battle_time_bar()
	if _has_winner():
		if not action_in_progress: _finish_battle()
		return
	if not visual_events.is_empty():
		if not action_in_progress: _begin_effect_pause()
		return
	if not action_in_progress:
		var ready := combat_units.filter(func(unit): return unit.alive and _unit_has_active_skill(unit) and unit.stun <= 0 and unit.charm <= 0 and float(unit.get("fear", 0.0)) <= 0.0 and float(unit.get("freeze", 0.0)) <= 0.0 and float(unit.action) >= ACTION_MAX)
		if not ready.is_empty(): _begin_action(ready[0])
		elif battle_time >= BATTLE_LIMIT and not final_battle: _finish_battle()

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
		_ensure_unit_fields(unit)
		var control_decay := _tianshu_control_decay_multiplier(unit)
		# Compatibility for a battle loaded from an older save that only has the legacy single DOT fields.
		_migrate_legacy_dots(unit)
		var active_burns: Array = []
		for raw_effect in unit.get("burn_effects", []):
			var effect: Dictionary = raw_effect
			effect.clock = float(effect.get("clock", 0.0)) + delta
			while float(effect.clock) >= 1.0 and float(effect.get("time", 0.0)) > 0.0 and unit.alive:
				effect.clock = float(effect.clock) - 1.0
				var burn_tick_damage := float(effect.get("damage", 0.0))
				if bool(effect.get("missing_hp_scale", false)):
					burn_tick_damage *= _missing_hp_damage_multiplier(unit, float(effect.get("missing_hp_step", 0.10)), float(effect.get("missing_hp_bonus_per_step", 0.05)))
				var burn_source = _find_by_id(combat_units, str(effect.get("source_id", "")))
				_damage(burn_source, unit, burn_tick_damage, "magic", t("灼烧", "Burn"), "status_burn:" + status_tick_id, "burn_tick", false)
			effect.time = maxf(0.0, float(effect.get("time", 0.0)) - delta)
			if float(effect.time) > 0.0: active_burns.append(effect)
		unit.burn_effects = active_burns
		_sync_dot_summaries(unit)
		if not unit.alive:
			continue
		if float(unit.get("fear", 0.0)) > 0.0:
			unit.fear_clock = float(unit.get("fear_clock", 0.0)) + delta
			if unit.fear_clock >= 1.0:
				unit.fear_clock -= 1.0
				_damage(null, unit, float(unit.max_hp) * float(unit.get("fear_damage_ratio", 0.05)), "magic", t("恐惧", "Fear"), "status_fear:" + status_tick_id, "fear_tick", false)
			unit.fear = maxf(0.0, float(unit.fear) - delta * control_decay)
			if unit.fear <= 0.0:
				unit.fear_damage_ratio = 0.0
				unit.fear_clock = 0.0
		var active_poisons: Array = []
		for raw_effect in unit.get("poison_effects", []):
			var effect: Dictionary = raw_effect
			effect.clock = float(effect.get("clock", 0.0)) + delta
			var poison_source = _find_by_id(combat_units, str(effect.get("source_id", "")))
			while float(effect.clock) >= 1.0 and int(effect.get("stacks", 0)) > 0 and unit.alive:
				effect.clock = float(effect.clock) - 1.0
				var poison_damage := float(effect.stacks)
				if _pair_active(_enemy_team_id(str(unit.team)), "yuji", "zuoci"):
					var yuji_params: Dictionary = heroes.yuji.ability_params
					poison_damage *= _missing_hp_damage_multiplier(unit, float(yuji_params.get("fangshi_missing_hp_step", 0.10)), float(yuji_params.get("fangshi_damage_bonus_per_step", 0.05)))
				_damage(poison_source, unit, poison_damage, "magic", t("中毒", "Poison"), "status_poison:" + status_tick_id, "poison_tick", false)
				effect.stacks = floori(float(effect.stacks) * float(effect.get("retention", 0.5)))
			if int(effect.get("stacks", 0)) > 0: active_poisons.append(effect)
		unit.poison_effects = active_poisons
		_sync_dot_summaries(unit)
		unit.freeze = maxf(0.0, float(unit.get("freeze", 0.0)) - delta * control_decay)
		unit.stun = max(0.0, unit.stun - delta * control_decay)
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
				var forced_amount := _unit_skill_stat_value(unit) * float(heroes.diaochan.ability_params.get("forced_attack_mult", 1.0))
				_damage(unit, victim, forced_amount, "physical", t("魅惑倒戈", "Charmed betrayal"), "charm_attack:" + str(unit.id), "charm_forced")
		unit.charm = max(0.0, unit.charm - delta * control_decay)
		if unit.charm <= 0.0:
			unit.charm_forced_attack = false
			unit.charm_attack_clock = 0.0
		unit.silence = max(0.0, float(unit.get("silence", 0.0)) - delta)
		unit.skill_debuff_time = maxf(0.0, float(unit.get("skill_debuff_time", 0.0)) - delta)
		if unit.skill_debuff_time <= 0.0: unit.skill_debuff = 0.0
		unit.stealth = max(0.0, float(unit.get("stealth", 0.0)) - delta)
		unit.slow_time = max(0.0, float(unit.get("slow_time", 0.0)) - delta * control_decay)
		if unit.slow_time <= 0.0: unit.slow = 0.0
		unit.vulnerable_time = max(0.0, float(unit.get("vulnerable_time", 0.0)) - delta)
		if unit.vulnerable_time <= 0.0: unit.vulnerable = 0.0
		unit.grievous_time = max(0.0, float(unit.get("grievous_time", 0.0)) - delta)
		if unit.grievous_time <= 0.0: unit.grievous = 0.0
		unit.timed_damage_time = max(0.0, float(unit.get("timed_damage_time", 0.0)) - delta)
		if unit.timed_damage_time <= 0.0:
			unit.timed_damage_buff = 0.0
			unit.timed_damage_buff_source = ""
		unit.all_lifesteal_time = max(0.0, float(unit.get("all_lifesteal_time", 0.0)) - delta)
		if unit.all_lifesteal_time <= 0.0: unit.all_lifesteal = 0.0
		unit.timed_reduction_time = max(0.0, float(unit.get("timed_reduction_time", 0.0)) - delta)
		if unit.timed_reduction_time <= 0.0: unit.timed_reduction = 0.0
		unit.timed_action_time = maxf(0.0, float(unit.get("timed_action_time", 0.0)) - delta)
		if unit.timed_action_time <= 0.0: unit.timed_action_bonus = 0.0
		unit.timed_skill_value_time = maxf(0.0, float(unit.get("timed_skill_value_time", 0.0)) - delta)
		if unit.timed_skill_value_time <= 0.0: unit.timed_skill_value_bonus = 0.0
		unit.rear_damage_reduction_time = maxf(0.0, float(unit.get("rear_damage_reduction_time", 0.0)) - delta)
		if unit.rear_damage_reduction_time <= 0.0: unit.rear_damage_reduction = 0.0
		unit.front_damage_reduction_time = maxf(0.0, float(unit.get("front_damage_reduction_time", 0.0)) - delta)
		if unit.front_damage_reduction_time <= 0.0: unit.front_damage_reduction = 0.0
		unit.invulnerable_time = maxf(0.0, float(unit.get("invulnerable_time", 0.0)) - delta)
		if int(unit.get("shu_damage_stacks", 0)) > 0:
			var decay := float(unit.get("shu_damage_decay_time", 0.0)) - delta
			if decay <= 0.0:
				unit.shu_damage_stacks = int(unit.get("shu_damage_stacks", 0)) - 1
				var shu_talent_duration := _talent_level("shu", "桃园同心") if unit.team == "player" else 0
				unit.shu_damage_decay_time = 3.0 + shu_talent_duration if int(unit.shu_damage_stacks) > 0 else 0.0
			else:
				unit.shu_damage_decay_time = decay
		if float(unit.get("regen_time", 0.0)) > 0.0:
			unit.regen_clock = float(unit.get("regen_clock", 0.0)) + delta
			unit.regen_time = max(0.0, float(unit.regen_time) - delta)
			if unit.regen_clock >= 1.0:
				unit.regen_clock -= 1.0
				var regen_source = _find_by_id(combat_units, str(unit.get("regen_source", "")))
				if regen_source != null: _heal_with_overflow(regen_source, unit, float(unit.regen_per_second), "regen", true)
			if unit.regen_time <= 0.0:
				unit.regen_per_second = 0.0
				unit.regen_damage_reduction = 0.0
				unit.regen_source = ""
		unit.strategy_mark = max(0.0, float(unit.get("strategy_mark", 0.0)) - delta)
		unit.zhuge_fire_mark = maxf(0.0, float(unit.get("zhuge_fire_mark", 0.0)) - delta)
		var active_chains: Array = []
		for raw_chain in unit.get("chain_effects", []):
			var chain: Dictionary = raw_chain
			chain.time = maxf(0.0, float(chain.get("time", 0.0)) - delta)
			if float(chain.time) > 0.0: active_chains.append(chain)
		unit.chain_effects = active_chains
		unit.death_prevention = max(0.0, float(unit.get("death_prevention", 0.0)) - delta)
	for index in range(ground_effects.size() - 1, -1, -1):
		var effect: Dictionary = ground_effects[index]
		var occupant = _unit_at(_team_units(str(effect.team)), int(effect.row), int(effect.col))
		if occupant != null:
			var effect_source = _find_by_id(combat_units, str(effect.get("source_id", "")))
			if str(effect.get("type", "burn")) == "poison":
				_add_decay_poison_effect(effect_source, occupant, int(effect.get("stacks", 0)), float(effect.get("retention", 0.5)))
			else:
				_add_burn_effect(
					effect_source,
					occupant,
					float(effect.get("time", 0.0)),
					float(effect.get("damage", 0.0)),
					bool(effect.get("missing_hp_scale", false)),
					str(effect.get("visual_group", "")),
					float(effect.get("missing_hp_step", 0.10)),
					float(effect.get("missing_hp_bonus_per_step", 0.05))
				)
			ground_effects.remove_at(index)
			continue
		effect.clock = float(effect.get("clock", 0.0)) + delta
		var source = _find_by_id(combat_units, str(effect.get("source_id", "")))
		if str(effect.get("type", "burn")) == "poison":
			while float(effect.clock) >= 1.0 and int(effect.get("stacks", 0)) > 0:
				effect.clock = float(effect.clock) - 1.0
				if source != null:
					_hit_ruler(
						source,
						float(effect.stacks),
						{"team":str(effect.team), "row":int(effect.row), "col":int(effect.col)},
						t("地面中毒", "Ground poison"),
						str(effect.get("visual_group", "")),
						"poison_tick"
					)
				effect.stacks = floori(float(effect.stacks) * float(effect.get("retention", 0.5)))
			if int(effect.get("stacks", 0)) <= 0:
				ground_effects.remove_at(index)
			else:
				ground_effects[index] = effect
			continue
		effect.time = maxf(0.0, float(effect.get("time", 0.0)) - delta)
		while float(effect.clock) >= 1.0:
			effect.clock = float(effect.clock) - 1.0
			if source != null:
				var ground_damage := float(effect.get("damage", 0.0))
				if bool(effect.get("missing_hp_scale", false)):
					var target_ruler_hp := enemy_ruler_hp if source.team == "player" else player_ruler_hp
					var target_ruler_max := RULER_MAX_HP if source.team == "player" else _player_ruler_max_hp()
					var ruler_missing_ratio := 1.0 - float(target_ruler_hp) / maxf(1.0, float(target_ruler_max))
					ground_damage *= 1.0 + floorf(ruler_missing_ratio / maxf(0.001, float(effect.get("missing_hp_step", 0.10))) + 0.0001) * float(effect.get("missing_hp_bonus_per_step", 0.05))
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
	_tianshu_process_tick(delta)

func _perform_action(unit: Dictionary) -> void:
	visual_events.append({"kind":"charge", "source_id":unit.id, "target_id":unit.id, "amount":0, "style":"magic"})
	_cast_active_skill(unit)
	_after_active_skill(unit)
	var qun_repeat_chance := 0.08 + (0.04 * _talent_level("qun", "逐鹿中原") if unit.team == "player" else 0.0)
	if heroes[unit.hero_id].f == "qun" and int(unit.get("faction_tier", 0)) >= 3 and not _has_winner() and rng.randf() < qun_repeat_chance:
		_log("[color=#d59af0]" + t("【乱世争衡】%s 触发羁绊二连：以下为第 2 次技能，不消耗行动条。" % _hero_name(str(unit.hero_id)), "[Chaos Struggle] %s triggers the second bond cast without consuming action." % _hero_name(str(unit.hero_id))) + "[/color]")
		visual_events.append({"kind":"repeat_cast", "source_id":unit.id, "target_id":unit.id, "amount":2, "style":"magic"})
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
		"daqiao": _cast_daqiao_skill(unit)
		"xiaoqiao": _cast_xiaoqiao_skill(unit)
		"sunjian": _cast_sunjian_skill(unit)
		"sunce": _cast_sunce_skill(unit)
		"sunquan": _cast_sunquan_skill(unit)
		"sunshangxiang": _cast_sunshangxiang_skill(unit)
		"ganning": _cast_ganning_skill(unit)
		"huanggai": _cast_huanggai_skill(unit)
		"xusheng": _cast_xusheng_skill(unit)
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
	var hp_before := float(unit.hp)
	var requested_cost := hp_before * (float(params.get("sun_legacy_current_hp_cost", 0.80)) if bool(unit.get("sun_legacy", false)) else float(params.get("current_hp_cost", 0.40)))
	unit.hp = maxf(0.0, hp_before - minf(hp_before, requested_cost))
	var hp_spent := hp_before - float(unit.hp)
	var amount := hp_spent * float(params.get("damage_cost_ratio", 1.0))
	var tile := _fixed_advancing_enemy_tile(unit, int(unit.col))
	var target = tile.target
	var visual_group := "sunjian_sacrifice:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	if target == null:
		_hit_ruler(unit, amount, tile, t("猛虎绝命空击", "Tiger's Resolve missed"), visual_group, "row_impact", false)
	else:
		_damage(unit, target, amount, "physical", t("猛虎绝命", "Tiger's Resolve"), visual_group, "row_impact", false)
	if bool(unit.get("sun_legacy", false)):
		var legacy_bonus := float(params.get("sun_legacy_damage_skill_ratio", 0.15)) * _unit_skill_effect_multiplier(unit)
		for ally in _team_units(unit.team):
			if not ally.alive or str(heroes[ally.hero_id].f) != "wu": continue
			ally.kill_buff = maxf(float(ally.get("kill_buff", 0.0)), legacy_bonus)
			visual_events.append({"kind":"skill", "source_id":unit.id, "target_id":ally.id, "amount":roundi(legacy_bonus * 100.0), "style":"magic", "nonblocking":true})
		_log("[color=#efb568]" + t("【孙氏之志】吴将本回合伤害提高 ", "[Sun Legacy] Wu allies gain ") + ("%.1f" % (legacy_bonus * 100.0)) + t("%，不可叠加。", "% damage for this battle, non-stacking.") + "[/color]")
	unit.cast_count = int(unit.get("cast_count", 0)) + 1
	_finish_sacrifice_death(unit)

func _cast_sunce_wave(unit: Dictionary, column_offsets: Array, damage: float, wave: int) -> void:
	var target_team := _enemy_team_id(unit.team)
	var target_row := _fallback_enemy_row(unit)
	var visual_group := "sunce_double:" + str(unit.id) + ":" + str(unit.get("cast_count", 0)) + ":" + str(wave)
	for offset in column_offsets:
		var col := int(unit.col) + int(offset)
		if col < 0 or col >= BOARD_COLUMNS:
			continue
		var tile := {"row":target_row, "col":col, "team":target_team}
		var target = _unit_at(_enemy_units(unit.team), int(tile.row), int(tile.col))
		if target == null:
			_hit_ruler(unit, damage, tile, t("小霸王连击空击", "Conqueror's Twin Assault missed"), visual_group, "row_impact")
		else:
			_damage(unit, target, damage, "physical", t("小霸王连击", "Conqueror's Twin Assault"), visual_group, "row_impact")

func _cast_sunce_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.sunce.ability_params
	var base_mult := float(params.get("mult", 1.60))
	if bool(unit.get("sun_legacy", false)):
		base_mult += float(params.get("sun_legacy_damage_bonus_mult", 0.50))
	if bool(unit.get("sunce_taishi", false)):
		base_mult += float(params.get("taishici_bonus_mult", 0.50))
	var missing_mult := _missing_hp_damage_multiplier(unit, float(params.get("missing_hp_step", 0.10)), float(params.get("missing_hp_damage_bonus_per_step", 0.04)))
	var damage := float(params.get("base_value", _unit_skill_stat_value(unit))) * base_mult * missing_mult
	_cast_sunce_wave(unit, [0, -1], damage, 1)
	if bool(unit.get("sun_legacy", false)) and not _has_winner():
		_cast_sunce_wave(unit, [0, 1], damage, 2)
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_sunquan_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.sunquan.ability_params
	if float(unit.get("sunquan_initial_max_hp", 0.0)) <= 0.0:
		unit.sunquan_initial_max_hp = float(unit.max_hp)
	var effect_mult := _unit_skill_effect_multiplier(unit)
	var max_hp_gain := _unit_skill_stat_value(unit) * float(params.get("max_hp_gain_skill_ratio", 1.0))
	var cap_mult := float(params.get("max_hp_cap_mult", 2.0))
	var heal_ratio := float(params.get("missing_hp_heal_skill_ratio", 0.10)) * effect_mult
	if bool(unit.get("sun_legacy", false)):
		max_hp_gain = _unit_skill_stat_value(unit) * float(params.get("sun_legacy_max_hp_gain_skill_ratio", 2.0))
		cap_mult = float(params.get("sun_legacy_max_hp_cap_mult", 3.0))
		heal_ratio = float(params.get("sun_legacy_missing_hp_heal_skill_ratio", 0.15)) * effect_mult
	var max_hp_cap := float(unit.sunquan_initial_max_hp) * cap_mult
	var actual_gain := minf(max_hp_gain, maxf(0.0, max_hp_cap - float(unit.max_hp)))
	if actual_gain > 0.0:
		unit.max_hp = float(unit.max_hp) + actual_gain
		visual_events.append({"kind":"skill", "source_id":unit.id, "target_id":unit.id, "amount":roundi(actual_gain), "style":"heal", "nonblocking":true})
	var restored := _heal_unit_only(unit, unit, maxf(0.0, float(unit.max_hp) - float(unit.hp)) * heal_ratio)
	_log(_combat_name(unit) + t(" 提高最大生命 ", " gains ") + str(roundi(actual_gain)) + t("，并恢复 ", " max HP and restores ") + str(roundi(restored)) + t(" 点生命。", " HP."))
	var tile := _random_enemy_tile(unit)
	var target = tile.target
	var ratio := (float(params.get("luxun_damage_ratio", 0.11)) if bool(unit.get("luxun_sunquan", false)) else float(params.get("current_hp_damage_ratio", 0.08))) * effect_mult
	var damage := float(unit.hp) * ratio / maxf(0.001, float(unit.get("stat_mult", 1.0)))
	if target == null:
		_hit_ruler(unit, damage, tile, t("江东制衡空击", "Jiangdong Balance missed"), "", "", false)
	else:
		_damage(unit, target, damage, "magic", t("江东制衡", "Jiangdong Balance"), "", "", false)
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_sunshangxiang_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.sunshangxiang.ability_params
	var target_count := int(params.get("target_count", 1))
	var release_count := int(params.get("sun_legacy_release_count", 2)) if bool(unit.get("sun_legacy", false)) else 1
	var mult := float(params.get("mult", 5.0))
	var current_skill := _unit_skill_stat_value(unit)
	var visual_group := "sunshangxiang_volley:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for _release in release_count:
		for tile in _random_unique_enemy_tiles(unit, target_count):
			if tile.target == null:
				_hit_ruler(unit, current_skill * mult, tile, t("枭姬叠势空击", "Heroine's Volley missed"), visual_group, "multi_target")
			else:
				_damage(unit, tile.target, current_skill * mult, "physical", t("枭姬叠势", "Heroine's Growing Volley"), visual_group, "rapid_hit")
	var skill_gain := float(params.get("sun_legacy_skill_gain", 2.0)) if bool(unit.get("sun_legacy", false)) else float(params.get("skill_gain_per_cast", 1.0))
	unit.sunshangxiang_skill_bonus = float(unit.get("sunshangxiang_skill_bonus", 0.0)) + skill_gain
	_log(_combat_name(unit) + t(" 兵略值永久提高 ", " permanently gains ") + str(skill_gain) + t(" 点。", " Strategy."))
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_taishici_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.taishici.ability_params
	var candidates := _targets_in_range(unit).filter(func(enemy): return enemy.alive and float(enemy.get("stealth", 0.0)) <= 0.0)
	candidates.sort_custom(func(a, b): return float(a.action) > float(b.action))
	var target_count := int(params.get("target_count", 2)) + (int(params.get("sunce_bonus_targets", 1)) if bool(unit.get("sunce_taishi", false)) else 0)
	var hit_mult := float(params.get("mult", 2.0))
	if bool(unit.get("sunce_taishi", false)): hit_mult -= float(params.get("sunce_damage_penalty_mult", 0.30))
	if bool(unit.get("taishici_ganning", false)): hit_mult += float(params.get("ganning_damage_bonus_mult", 0.60))
	if candidates.is_empty():
		for tile in _random_unique_enemy_tiles(unit, target_count):
			_hit_ruler(unit, _unit_skill_stat_value(unit) * hit_mult, tile, t("神亭烈戟空击", "Blazing Halberds missed"))
		return
	var visual_group := "taishici_targets:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for target in candidates.slice(0, mini(target_count, candidates.size())):
		_damage(unit, target, _unit_skill_stat_value(unit) * hit_mult, "physical", t("神亭烈戟", "Blazing Twin Halberds"), visual_group, "multi_target")
		if target.alive:
			_apply_skill_burn(unit, target, float(params.get("burn", 5.0)), _unit_skill_stat_value(unit) * float(params.get("burn_ratio", 0.20)))
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _ganning_assault_hit(caster: Dictionary, attacker: Dictionary, params: Dictionary, visual_group: String) -> void:
	var tile := _random_enemy_tile_in_rows(caster, [BOARD_ROWS - 1])
	var target = tile.target
	var mult := float(params.get("mult", 3.0))
	if target != null and bool(caster.get("lvmeng_ganning", false)) and float(target.hp) < float(target.max_hp) * 0.50:
		mult += float(params.get("lvmeng_low_hp_bonus_mult", 1.80))
	var amount := _unit_skill_stat_value(attacker) * mult
	if target == null:
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
	if _try_wu_equalize_and_recover(unit):
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
	cost_ratio *= 1.0 - clampf(_endless_imprint_value(unit, "huanggai_cost_reduction_pct"), 0.0, 0.50)
	var requested_cost := float(unit.max_hp) * cost_ratio
	var hp_spent := minf(float(unit.hp), requested_cost)
	unit.hp = maxf(0.0, float(unit.hp) - hp_spent)
	var damage_ratio := float(params.get("sunjian_damage_cost_ratio", 0.50)) if pillars else float(params.get("damage_cost_ratio", 0.40))
	# 黄盖仍围绕苦肉与生命构筑，但专属将印只强化转化效率，不再让全军生命成长直接形成无上限乘算。
	damage_ratio *= 1.0 + minf(0.40, _endless_imprint_value(unit, "skill_effect_pct") * 0.40)
	var amount := _unit_skill_stat_value(unit) * float(params.get("mult", 2.0)) + hp_spent * damage_ratio
	var col := rng.randi_range(0, BOARD_COLUMNS - 1)
	var target_team := _enemy_team_id(unit.team)
	var visual_group := "huanggai_column:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	var imprint_burn_time := maxf(_endless_imprint_value(unit, "burn_duration_add"), _endless_imprint_value(unit, "burn_ground_on_hit"))
	for row in BOARD_ROWS:
		var tile := {"row":row, "col":col, "team":target_team}
		var target = _unit_at(_enemy_units(unit.team), row, col)
		if target == null:
			_hit_ruler(unit, amount, tile, t("苦肉焚阵空击", "Bitter-Flesh Column missed"), visual_group, "column_impact", false)
			if bool(unit.get("zhouyu_huanggai", false)) or imprint_burn_time > 0.0:
				var burn_time := maxf(float(params.get("zhouyu_burn", 5.0)) if bool(unit.get("zhouyu_huanggai", false)) else 0.0, imprint_burn_time)
				_set_ground_burn(unit, target_team, row, col, burn_time, _unit_skill_stat_value(unit) * float(params.get("zhouyu_burn_ratio", 0.50)), visual_group)
		else:
			_damage(unit, target, amount, "physical", t("苦肉焚阵", "Bitter-Flesh Column"), visual_group, "column_impact", false)
			if target.alive and (bool(unit.get("zhouyu_huanggai", false)) or imprint_burn_time > 0.0):
				var burn_time := maxf(float(params.get("zhouyu_burn", 5.0)) if bool(unit.get("zhouyu_huanggai", false)) else 0.0, imprint_burn_time)
				_apply_skill_burn(unit, target, burn_time, _unit_skill_stat_value(unit) * float(params.get("zhouyu_burn_ratio", 0.50)))
	unit.cast_count = int(unit.get("cast_count", 0)) + 1
	if _endless_imprint_value(unit, "no_self_death") >= 1.0 and float(unit.hp) <= 0.0:
		unit.hp = maxf(1.0, float(unit.max_hp) * 0.08)
	else:
		_finish_sacrifice_death(unit)

func _cast_dingfeng_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.dingfeng.ability_params
	var mult := float(params.get("mult", 4.0))
	var action_reduction := float(params.get("action_reduction", 25.0))
	if bool(unit.get("dingfeng_xusheng", false)):
		mult += float(params.get("bond_damage_bonus_mult", 1.0))
		action_reduction = float(params.get("bond_action_reduction", 70.0))
	var target = _highest_action_enemy(unit)
	if target == null:
		var tile := _random_enemy_tile(unit)
		_hit_ruler(unit, _unit_skill_stat_value(unit) * mult, tile, t("雪中奋短兵空击", "Snowbound Blades missed"))
		return
	var visual_group := "dingfeng_assault:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	_damage(unit, target, _unit_skill_stat_value(unit) * mult, "physical", t("雪中奋短兵", "Snowbound Short Blades"), visual_group, "row_impact")
	if target.alive:
		_reduce_action_bar(unit, target, action_reduction)

func _apply_skill_stun(source: Dictionary, target: Dictionary, duration: float) -> void:
	if target == null or not target.alive or duration <= 0.0: return
	var actual := _scaled_control_duration(source, duration, true)
	target.stun = maxf(float(target.stun), actual)
	_add_stat(source, "control", actual)

func _cast_caocao_command(unit: Dictionary) -> void:
	var params: Dictionary = heroes.caocao.ability_params
	var has_dianwei := _pair_active(unit.team, "caocao", "dianwei")
	var has_xuchu := _pair_active(unit.team, "caocao", "xuchu")
	var target_count := int(params.get("target_count", 2))
	if has_dianwei: target_count += int(params.get("bond_bonus_targets", 1))
	if has_xuchu: target_count += int(params.get("bond_bonus_targets", 1))
	var skill_value := _unit_skill_stat_value(unit)
	var base_mult := float(params.get("mult", 1.50))
	var visual_group := "caocao_command:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for tile in _random_unique_enemy_tiles(unit, target_count):
		var target = tile.target
		var favored := (has_dianwei and int(tile.row) == BOARD_ROWS - 1) or (has_xuchu and int(tile.row) == 0)
		var damage_mult := base_mult + (float(params.get("favored_damage_bonus_mult", 1.0)) if favored else 0.0)
		var amount := skill_value * damage_mult
		if target == null:
			_miss_tile(unit, tile, t("魏武震慑", "Dominion Stun"))
			continue
		_damage(unit, target, amount, "physical", t("魏武震慑", "Dominion Stun"), visual_group, "multi_target")
		var stun_duration := float(params.get("stun", 1.25)) + (float(params.get("favored_stun_bonus", 0.5)) if favored else 0.0)
		_apply_skill_stun(unit, target, stun_duration)
		var lord_level := _tianshu_level("wei_lord") if unit.team == "player" else 0
		if lord_level >= 1:
			var army_bonus := 0.15 if lord_level == 1 else 0.25
			var army_time := 5.0 if lord_level == 1 else 6.0
			for ally in _team_units(unit.team):
				if not ally.alive or str(heroes[ally.hero_id].f) != "wei": continue
				if army_bonus >= float(ally.get("timed_damage_buff", 0.0)):
					ally.timed_damage_buff = army_bonus
					ally.timed_damage_buff_source = str(unit.id)
				ally.timed_damage_time = maxf(float(ally.get("timed_damage_time", 0.0)), army_time)
				if lord_level >= 2:
					ally.action = minf(ACTION_MAX, float(ally.get("action", 0.0)) + 10.0)
			_log("[color=#7fa8e0]【魏武挥鞭】全军魏将增伤 %.0f%%，持续 %.0f 秒。[/color]" % [army_bonus * 100.0, army_time])
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _wei_pair_count(team: String, hero_id: String, partners: Array) -> int:
	var count := 0
	for partner in partners:
		if _pair_active(team, hero_id, str(partner)): count += 1
	return count

func _cast_xiahouyuan_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.xiahouyuan.ability_params
	var bond_count := _wei_pair_count(unit.team, "xiahouyuan", ["caoren", "xiahoudun"])
	var stun_duration := float(params.get("stun", 1.0)) + float(params.get("bond_stun_bonus", 0.5)) * bond_count
	var damage_mult := float(params.get("mult", 2.2)) + float(params.get("bond_damage_bonus_mult", 0.50)) * bond_count
	var visual_group := "xiahouyuan_suppression:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for tile in _random_unique_enemy_tiles(unit, int(params.get("target_count", 2))):
		var target = tile.target
		if target == null:
			_hit_ruler(unit, _unit_skill_stat_value(unit) * damage_mult, tile, t("神速震袭空击", "Swift Suppression missed"), visual_group, "multi_target")
			continue
		_damage(unit, target, _unit_skill_stat_value(unit) * damage_mult, "physical", t("神速震袭", "Swift Suppression"), visual_group, "multi_target")
		_apply_skill_stun(unit, target, stun_duration)
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_caoren_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.caoren.ability_params
	var bond_count := _wei_pair_count(unit.team, "caoren", ["xiahouyuan", "xiahoudun"])
	var target_count := int(params.get("target_count", 2)) + int(params.get("bond_bonus_targets", 1)) * bond_count
	var stun_duration := float(params.get("stun", 1.0)) + float(params.get("bond_stun_bonus", 0.5)) * bond_count
	var visual_group := "caoren_rear_guard:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for tile in _random_unique_enemy_tiles(unit, target_count, [BOARD_ROWS - 1]):
		var target = tile.target
		if target == null:
			_hit_ruler(unit, _unit_skill_stat_value(unit) * float(params.get("mult", 1.50)), tile, t("樊城镇远空击", "Rearward Bulwark missed"), visual_group, "multi_target")
			continue
		_damage(unit, target, _unit_skill_stat_value(unit) * float(params.get("mult", 1.50)), "physical", t("樊城镇远", "Rearward Bulwark"), visual_group, "multi_target")
		_apply_skill_stun(unit, target, stun_duration)
	unit.rear_damage_reduction = (float(params.get("rear_reduction_skill_ratio", 0.20)) + float(params.get("bond_reduction_skill_ratio", 0.10)) * bond_count) * _unit_skill_effect_multiplier(unit)
	unit.rear_damage_reduction_time = float(params.get("guard_time", 5.0))
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_xiahoudun_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.xiahoudun.ability_params
	var bond_count := _wei_pair_count(unit.team, "xiahoudun", ["xiahouyuan", "caoren"])
	var target_count := int(params.get("target_count", 2)) + int(params.get("bond_bonus_targets", 1)) * bond_count
	var stun_duration := float(params.get("stun", 1.5)) + float(params.get("bond_stun_bonus", 0.5)) * bond_count
	var target_row := _fallback_enemy_row(unit)
	var visual_group := "xiahoudun_front_guard:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for tile in _random_unique_enemy_tiles(unit, target_count, [target_row]):
		var target = tile.target
		if target == null:
			_hit_ruler(unit, _unit_skill_stat_value(unit) * float(params.get("mult", 1.50)), tile, t("刚烈镇前空击", "Vanguard Bulwark missed"), visual_group, "multi_target")
			continue
		_damage(unit, target, _unit_skill_stat_value(unit) * float(params.get("mult", 1.50)), "physical", t("刚烈镇前", "Vanguard Bulwark"), visual_group, "multi_target")
		_apply_skill_stun(unit, target, stun_duration)
	unit.front_damage_reduction = (float(params.get("front_reduction_skill_ratio", 0.20)) + float(params.get("bond_reduction_skill_ratio", 0.10)) * bond_count) * _unit_skill_effect_multiplier(unit)
	unit.front_damage_reduction_time = float(params.get("guard_time", 5.0))
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_simayi_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.simayi.ability_params
	var with_guojia := _pair_active(unit.team, "simayi", "guojia")
	var with_xunyu := _pair_active(unit.team, "simayi", "xunyu")
	var with_jiaxu := _pair_active(unit.team, "simayi", "jiaxu")
	var target_count := int(params.get("target_count", 2))
	if with_guojia: target_count += int(params.get("guojia_bonus_targets", 1))
	if with_xunyu: target_count += int(params.get("xunyu_bonus_targets", 1))
	var mult := float(params.get("mult", 3.20))
	if with_guojia: mult -= float(params.get("guojia_damage_penalty_mult", 0.40))
	if with_xunyu: mult -= float(params.get("xunyu_damage_penalty_mult", 0.40))
	if with_jiaxu: mult += float(params.get("jiaxu_damage_bonus_mult", 0.80))
	mult = maxf(mult, 0.0)
	var visual_group := "simayi_thunder:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for tile in _random_unique_enemy_tiles(unit, target_count):
		if tile.target == null:
			_hit_ruler(unit, _unit_skill_stat_value(unit) * mult, tile, t("雷霆谋断空击", "Thunder Judgment missed"), visual_group, "multi_target")
		else:
			_damage(unit, tile.target, _unit_skill_stat_value(unit) * mult, "magic", t("雷霆谋断", "Thunder Judgment"), visual_group, "multi_target")
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_guojia_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.guojia.ability_params
	var with_simayi := _pair_active(unit.team, "guojia", "simayi")
	var with_xunyu := _pair_active(unit.team, "guojia", "xunyu")
	var target_count := int(params.get("target_count", 2)) + (int(params.get("simayi_bonus_targets", 1)) if with_simayi else 0)
	var base_duration := float(params.get("freeze", 3.0))
	if with_simayi: base_duration -= float(params.get("simayi_duration_penalty", 0.5))
	if with_xunyu: base_duration += float(params.get("xunyu_duration_bonus", 1.2))
	var duration := _scaled_control_duration(unit, base_duration, true)
	var shatter_per_second := _unit_scaled_skill_value(unit) * float(params.get("shatter_per_second_mult", 0.50))
	var visual_group := "guojia_freeze:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for tile in _random_unique_enemy_tiles(unit, target_count):
		var target = tile.target
		if target == null:
			_hit_ruler(unit, _unit_skill_stat_value(unit) * float(params.get("empty_damage_mult", 2.80)), tile, t("遗计冰封空击", "Frozen Legacy empty strike"), visual_group, "multi_target")
			continue
		target.freeze = maxf(float(target.get("freeze", 0.0)), duration)
		target.freeze_shatter_damage = 0.0
		target.freeze_shatter_per_second = maxf(float(target.get("freeze_shatter_per_second", 0.0)), shatter_per_second)
		target.freeze_source_id = str(unit.id)
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
	var with_simayi := _pair_active(unit.team, "xunyu", "simayi")
	var with_guojia := _pair_active(unit.team, "xunyu", "guojia")
	var target_count := int(params.get("target_count", 2)) + (int(params.get("simayi_bonus_targets", 1)) if with_simayi else 0)
	var targets := _random_unique_living_allies(unit, target_count)
	var action_bonus_ratio := float(params.get("action_bonus_skill_ratio", 0.40))
	if with_simayi: action_bonus_ratio -= float(params.get("simayi_action_penalty_skill_ratio", 0.05))
	if with_guojia: action_bonus_ratio += float(params.get("guojia_action_bonus_skill_ratio", 0.12))
	var action_bonus := maxf(0.0, action_bonus_ratio) * _unit_skill_effect_multiplier(unit)
	var haste_time := float(params.get("duration", 4.4))
	var visual_group := "xunyu_haste:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for target in targets:
		target.timed_action_bonus = maxf(float(target.get("timed_action_bonus", 0.0)), action_bonus)
		target.timed_action_time = maxf(float(target.get("timed_action_time", 0.0)), haste_time)
		# 增益估算（行动加速类）：多出手比例×目标实时dps×持续时长。
		if target.id != unit.id:
			_add_stat(unit, "buff", _unit_live_dps(target) * action_bonus * haste_time)
		visual_events.append({"kind":"skill", "source_id":unit.id, "target_id":target.id, "amount":roundi(action_bonus * 100.0), "style":"magic", "nonblocking":true, "visual_group":visual_group, "group_style":"simultaneous"})
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_jiaxu_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.jiaxu.ability_params
	var with_simayi := _pair_active(unit.team, "jiaxu", "simayi")
	var with_guojia := _pair_active(unit.team, "jiaxu", "guojia")
	var target_count := int(params.get("target_count", 2)) + (int(params.get("guojia_bonus_targets", 1)) if with_guojia else 0)
	var poison_stacks := maxi(1, roundi(_unit_skill_stat_value(unit) * float(params.get("poison_stack_mult", 1.6))))
	if with_guojia:
		poison_stacks = maxi(1, poison_stacks - roundi(_unit_skill_stat_value(unit) * float(params.get("guojia_stack_penalty_ratio", 0.2))))
	var retention := 0.55 if with_simayi else 0.5
	var visual_group := "jiaxu_poison:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for tile in _random_unique_enemy_tiles(unit, target_count):
		if tile.target == null:
			_set_ground_poison(unit, str(tile.team), int(tile.row), int(tile.col), poison_stacks, retention, visual_group)
			visual_events.append({"kind":"empty", "source_id":unit.id, "team":tile.team, "row":tile.row, "col":tile.col, "amount":0, "skill":true, "style":"magic", "visual_group":visual_group, "group_style":"poison_apply"})
		else:
			_add_decay_poison_effect(unit, tile.target, poison_stacks, retention)
			visual_events.append({"kind":"skill", "source_id":unit.id, "target_id":tile.target.id, "amount":poison_stacks, "style":"magic", "visual_group":visual_group, "group_style":"poison_apply"})
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_liubei_regen(unit: Dictionary) -> void:
	var params: Dictionary = heroes[unit.hero_id].ability_params
	var allies := _team_units(unit.team).filter(func(ally): return ally.alive)
	allies.sort_custom(func(a, b): return float(a.hp) / maxf(1.0, float(a.max_hp)) < float(b.hp) / maxf(1.0, float(b.max_hp)))
	var target_count := 1 + (1 if _tianshu_level("shu_lord") >= 1 and unit.team == "player" else 0)
	var duration := float(params.get("duration", 4.0)) * (1.0 + float(params.get("liushan_duration_bonus", 0.30)) if _pair_active(unit.team, "liubei", "liushan") else 1.0)
	var heal_ratio := float(params.get("peach_heal_ratio", 1.5)) if _roster_has_all(_team_units(unit.team), ["liubei", "guanyu", "zhangfei"]) else float(params.get("heal_ratio", 1.0))
	var heal_per_second := _unit_skill_stat_value(unit) * heal_ratio
	var damage_reduction := float(params.get("zhuge_damage_reduction", 0.30)) * _unit_skill_effect_multiplier(unit) if _pair_active(unit.team, "liubei", "zhugeliang") else 0.0
	var shu_invulnerable: bool = _tianshu_level("shu_lord") >= 2 and unit.team == "player"
	var picked_count := 0
	for target in allies:
		if picked_count >= target_count: break
		picked_count += 1
		target.regen_per_second = heal_per_second
		target.regen_time = duration
		target.regen_clock = 0.0
		target.regen_source = unit.id
		target.regen_damage_reduction = damage_reduction
		if shu_invulnerable and str(heroes[target.hero_id].f) == "shu":
			target.invulnerable_time = maxf(float(target.get("invulnerable_time", 0.0)), duration)
		visual_events.append({"kind":"regen_apply", "source_id":unit.id, "target_id":target.id, "amount":0, "style":"heal"})
	if picked_count == 0:
		var row := rng.randi_range(0, BOARD_ROWS - 1)
		var col := rng.randi_range(0, BOARD_COLUMNS - 1)
		ruler_regen[unit.team] = {"amount":heal_per_second, "time":duration, "clock":0.0, "source":unit.id, "damage_reduction":damage_reduction}
		visual_events.append({"kind":"heal", "source_id":unit.id, "target_id":"", "team":unit.team, "row":row, "col":col, "amount":round(heal_per_second), "ruler":true, "style":"heal"})

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
		if buff >= float(ally.get("timed_damage_buff", 0.0)):
			ally.timed_damage_buff = buff
			ally.timed_damage_buff_source = str(unit.id)
		ally.timed_damage_time = max(float(ally.get("timed_damage_time", 0.0)), duration)
		if seven_charges:
			ally.all_lifesteal = max(float(ally.get("all_lifesteal", 0.0)), float(params.get("seven_lifesteal", 0.30)) * _unit_skill_effect_multiplier(unit))
			ally.all_lifesteal_time = max(float(ally.get("all_lifesteal_time", 0.0)), duration)
		visual_events.append({"kind":"skill", "source_id":unit.id, "target_id":ally.id, "amount":round(buff * 100.0), "style":"magic", "visual_group":visual_group, "group_style":"simultaneous"})

func _cast_zhangfei_command(unit: Dictionary) -> void:
	var params: Dictionary = heroes[unit.hero_id].ability_params
	var five := _roster_has_count(_team_units(unit.team), ["guanyu", "zhangfei", "zhaoyun", "huangzhong", "machao"], 5)
	var peach := _roster_has_all(_team_units(unit.team), ["liubei", "guanyu", "zhangfei"])
	var damage_skill_ratio := float(params.get("five_damage_skill_ratio", 0.25)) if five else float(params.get("damage_skill_ratio", 0.15))
	var buff := damage_skill_ratio * _unit_skill_stat_value(unit) / 100.0
	var duration := float(params.get("duration", 3.3)) * (1.0 + (float(params.get("peach_duration_bonus", 0.50)) if peach else 0.0) + (float(params.get("five_duration_bonus", 0.50)) if five else 0.0))
	var visual_group := "zhangfei_buff:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for ally in _team_units(unit.team):
		if not ally.alive or ally.row != 0: continue
		if buff >= float(ally.get("timed_damage_buff", 0.0)):
			ally.timed_damage_buff = buff
			ally.timed_damage_buff_source = str(unit.id)
		ally.timed_damage_time = max(float(ally.get("timed_damage_time", 0.0)), duration)
		visual_events.append({"kind":"skill", "source_id":unit.id, "target_id":ally.id, "amount":round(buff * 100.0), "style":"magic", "visual_group":visual_group, "group_style":"simultaneous"})

func _cast_zhaoyun_empower(unit: Dictionary) -> void:
	var params: Dictionary = heroes[unit.hero_id].ability_params
	var five_tigers := _roster_has_count(_team_units(unit.team), ["guanyu", "zhangfei", "zhaoyun", "huangzhong", "machao"], 5)
	var seven_charges := _pair_active(unit.team, "zhaoyun", "liushan")
	var hit_count := int(params.get("hit_count", 5))
	if five_tigers: hit_count += int(params.get("five_bonus_hits", 1))
	if seven_charges: hit_count += int(params.get("seven_bonus_hits", 1))
	var hit_mult := float(params.get("hit_mult", 1.15)) + (float(params.get("five_bonus_mult", 1.0)) if five_tigers else 0.0)
	var tile := _random_enemy_tile_in_rows(unit, [BOARD_ROWS - 1]) if seven_charges else _random_enemy_tile(unit)
	var target = tile.target
	var visual_group := "zhaoyun_rapid:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for _hit_index in hit_count:
		var amount := _unit_skill_stat_value(unit) * hit_mult
		target = _unit_at(_enemy_units(unit.team), int(tile.row), int(tile.col))
		if target != null and float(target.get("stealth", 0.0)) > 0.0:
			target = null
		if target == null:
			_hit_ruler(unit, amount, tile, t("龙胆连刺空击", "Dragon Spear missed"), visual_group, "spear_rapid")
		else:
			_damage(unit, target, amount, "physical", t("龙胆连刺", "Dragon Spear"), visual_group, "spear_rapid")
	for event in visual_events:
		if str(event.get("visual_group", "")) == visual_group:
			event["rapid_hits"] = hit_count

func _cast_huangzhong_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes[unit.hero_id].ability_params
	var five_tigers := _roster_has_count(_team_units(unit.team), ["guanyu", "zhangfei", "zhaoyun", "huangzhong", "machao"], 5)
	var base: float = _unit_skill_stat_value(unit)
	var dmg_mult := float(params.get("five_mult", 11.0)) if five_tigers else float(params.get("mult", 4.2))
	var flying_critical := bool(unit.get("flying_meteor", false)) and rng.randf() < float(params.get("meteor_crit_chance", 0.30))
	if flying_critical: dmg_mult *= float(params.get("meteor_crit_mult", 2.0))
	var tile := _random_enemy_tile(unit)
	if tile.target == null:
		_hit_ruler(unit, base * dmg_mult, tile, t("百步穿杨暴击空击", "Piercing Arrow critical missed") if flying_critical else t("百步穿杨空击", "Piercing Arrow missed"))
	else:
		_damage(unit, tile.target, base * dmg_mult, "physical", t("百步穿杨暴击", "Piercing Arrow critical") if flying_critical else t("百步穿杨", "Piercing Arrow"))

func _cast_machao_pierce(unit: Dictionary) -> void:
	var target_col := int(_random_enemy_tile(unit).col)
	var params: Dictionary = heroes.machao.ability_params
	var row_multipliers := [
		float(params.get("front_mult", 2.0)),
		float(params.get("middle_mult", 1.7)),
		float(params.get("back_mult", 1.4))
	]
	if bool(unit.get("one_rider", false)): row_multipliers = params.get("one_rider_mults", [2.6, 3.0, 3.4])
	var visual_group := "machao_column:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	var target_team := _enemy_team_id(unit.team)
	for row in BOARD_ROWS:
		var amount := _unit_skill_stat_value(unit) * float(row_multipliers[row])
		var target = _unit_at(_enemy_units(unit.team), row, target_col)
		if target == null:
			_hit_ruler(unit, amount, {"row":row, "col":target_col, "team":target_team}, t("铁骑贯阵空击", "Iron Cavalry missed"), visual_group, "spear_column")
		else:
			_damage(unit, target, amount, "physical", t("铁骑贯阵", "Iron Cavalry"), visual_group, "spear_column")
	if _roster_has_count(_team_units(unit.team), ["guanyu", "zhangfei", "zhaoyun", "huangzhong", "machao"], 5):
		for ally in _team_units(unit.team):
			if ally.alive and ally.id != unit.id and int(ally.row) == int(unit.row):
				var five_bonus := _unit_skill_stat_value(unit) * float(params.get("five_skill_ratio", 0.40))
				ally.timed_skill_value_bonus = maxf(float(ally.get("timed_skill_value_bonus", 0.0)), five_bonus)
				ally.timed_skill_value_time = maxf(float(ally.get("timed_skill_value_time", 0.0)), float(params.get("five_duration", 7.2)))
				# 增益估算（兵略加成类）：加成占目标兵略比例×dps×持续时长。
				var ally_skill := _unit_skill_stat_value(ally)
				if ally_skill > 0.0:
					_add_stat(unit, "buff", _unit_live_dps(ally) * (five_bonus / ally_skill) * float(params.get("five_duration", 7.2)))

func _cast_madai_execution(unit: Dictionary) -> void:
	var params: Dictionary = heroes.madai.ability_params
	var target_row := _fallback_enemy_row(unit)
	var tile := _random_enemy_tile_in_rows(unit, [target_row])
	var target = tile.target
	if target == null:
		var ruler_damage := _unit_skill_stat_value(unit) * float(params.get("empty_ruler_strategy_mult", 20.0))
		_hit_ruler(unit, ruler_damage / maxf(0.01, float(unit.get("stat_mult", 1.0))), tile, t("斩将突袭空格追主", "Execution Raid ruler strike"), "", "", false)
		return
	var damage := float(target.max_hp) * float(params.get("max_hp_ratio", 0.50)) * _unit_skill_effect_multiplier(unit)
	_damage(unit, target, damage, "physical", t("斩将突袭", "Execution Raid"), "", "", false)
	if target.alive and bool(unit.get("fated_enemies", false)):
		target.vulnerable = max(float(target.get("vulnerable", 0.0)), float(params.get("vulnerable_skill_ratio", 0.30)) * _unit_skill_effect_multiplier(unit))
		target.vulnerable_time = max(float(target.get("vulnerable_time", 0.0)), maxf(0.0, BATTLE_LIMIT - battle_time))
		visual_events.append({"kind":"skill", "source_id":unit.id, "target_id":target.id, "amount":roundi(target.vulnerable * 100.0), "style":"magic"})

func _cast_weiyan_cleave(unit: Dictionary) -> void:
	var params: Dictionary = heroes.weiyan.ability_params
	var damage_dealt := 0.0
	var visual_group := "weiyan_cleave:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	var amount := _unit_skill_stat_value(unit) * float(params.get("mult", 1.8))
	var tile := _fixed_advancing_enemy_tile(unit, int(unit.col))
	if tile.target == null:
		_hit_ruler(unit, amount, tile, t("狂骨横斩空击", "Rebel Fang missed"), visual_group, "row_impact")
	else:
		damage_dealt += _damage(unit, tile.target, amount, "physical", t("狂骨横斩", "Rebel Fang"), visual_group, "row_impact")
	if damage_dealt > 0.0 and bool(unit.get("flying_meteor", false)):
		_heal_unit_only(unit, unit, damage_dealt * float(params.get("meteor_heal", 0.23)) * _unit_skill_effect_multiplier(unit))
	if bool(unit.get("fated_enemies", false)):
		for ally in _team_units(unit.team):
			if not ally.alive or ally.id == unit.id: continue
			var adjacent_same_row: bool = int(ally.row) == int(unit.row) and abs(int(ally.col) - int(unit.col)) == 1
			var directly_behind: bool = int(ally.col) == int(unit.col) and int(ally.row) == int(unit.row) + 1
			if adjacent_same_row or directly_behind:
				_heal_unit_only(unit, ally, damage_dealt * float(params.get("fated_ally_heal", 0.06)) * _unit_skill_effect_multiplier(unit))

func _after_active_skill(unit: Dictionary) -> void:
	_tianshu_on_cast(unit)
	var shield_pct := _endless_imprint_value(unit, "post_cast_shield_pct")
	if shield_pct > 0.0: _grant_shield(unit, float(unit.max_hp) * shield_pct, unit)
	var reduction := _endless_imprint_value(unit, "post_cast_reduction_pct")
	if reduction > 0.0:
		unit.timed_reduction = maxf(float(unit.get("timed_reduction", 0.0)), reduction)
		unit.timed_reduction_time = maxf(float(unit.get("timed_reduction_time", 0.0)), 3.0)
	var action_add := _endless_imprint_value(unit, "action_on_cast_add")
	if action_add > 0.0: unit.action = minf(ACTION_MAX, float(unit.action) + action_add)
	if heroes[unit.hero_id].f == "shu" and int(unit.get("faction_tier", 0)) >= 3:
		unit.shu_damage_stacks = 0
		unit.shu_damage_decay_time = 0.0

func _cast_generic_ability(unit: Dictionary) -> void:
	var hero: Dictionary = heroes[unit.hero_id]
	var ability: String = hero.get("ability", "")
	var params: Dictionary = hero.get("ability_params", {})
	var effect_mult := _unit_skill_effect_multiplier(unit)
	var base_value: float = _unit_skill_stat_value(unit) * float(params.get("mult", 1.0))
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
			target.vulnerable_time = max(float(target.vulnerable_time), _scaled_control_duration(unit, float(params.get("vulnerable_time", 4.0))))
		if float(params.get("silence", 0.0)) > 0.0: target.silence = max(float(target.silence), _scaled_control_duration(unit, float(params.silence)))
		if float(params.get("action_refund", 0.0)) > 0.0: unit.action = min(ACTION_MAX, float(unit.action) + float(params.action_refund))
		if ability == "drain" and dealt > 0:
			var drain_ratio := float(params.get("heal", 0.25))
			_heal_with_overflow(unit, unit, dealt * min(0.75, drain_ratio * effect_mult))
		if float(params.get("stun", 0.0)) > 0 and target.alive:
			var base_control_time: float = float(params.stun)
			if unit.hero_id == "xiaoqiao" and bool(unit.get("zhouyu_xiaoqiao", false)) and float(target.get("burn", 0.0)) > 0.0: base_control_time *= 1.50
			var control_time := _scaled_control_duration(unit, base_control_time)
			target.stun = max(float(target.stun), control_time)
			_add_stat(unit, "control", control_time)
		if float(params.get("burn", 0.0)) > 0 and target.alive:
			_add_burn_effect(unit, target, float(params.burn), _unit_skill_stat_value(unit) * float(params.get("burn_ratio", 0.30)) * float(unit.get("burn_multiplier", 1.0)))
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
					_add_burn_effect(unit, target, float(params.burn), float(params.get("burn_per_sec", 15.0)) * effect_mult * float(unit.get("burn_multiplier", 1.0)), false, visual_group)
				if float(params.get("slow", 0.0)) > 0.0:
					target.slow = max(float(target.slow), float(params.slow) * effect_mult)
					target.slow_time = max(float(target.slow_time), _scaled_control_duration(unit, float(params.get("slow_time", 4.0))))
				if float(params.get("stun", 0.0)) > 0 and target.alive:
					var row_control := _scaled_control_duration(unit, float(params.stun))
					target.stun = max(float(target.stun), row_control)
					_add_stat(unit, "control", row_control)
	elif ability in ["multi", "multi_magic"]:
		for _shot in int(params.get("count", 2)) + int(unit.get("multi_bonus", 0)):
			var tile := _ability_enemy_tile(unit, params)
			if tile.target == null: _hit_ruler(unit, base_value, tile, hero.zh_skill if language == "zh" else hero.skill)
			else: _damage(unit, tile.target, base_value, "magic" if ability == "multi_magic" else "physical", hero.zh_skill if language == "zh" else hero.skill)
	elif ability == "heal":
		var heal_base: float = _unit_skill_stat_value(unit) * float(params.get("mult", 1.0)) + float(params.get("flat", 0.0))
		_heal_weakest_fixed(unit, heal_base, 0.0)
		for _extra in int(unit.get("heal_extra_targets", 0)):
			_heal_weakest_fixed(unit, heal_base, 0.0)
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
		var shield_value: float = (_unit_skill_stat_value(unit) * float(params.get("mult", 1.0)) + float(params.get("flat", 40.0))) * float(unit.get("stat_mult", 1.0))
		for ally in shield_targets:
			_grant_shield(ally, shield_value, unit)
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
	var tiles := _zhugeliang_affected_tiles(center_row, center_col, has_jiangwei, has_pangtong)
	var enemies := _enemy_units(unit.team)
	var affected_unit_count := 0
	for tile in tiles:
		if _unit_at(enemies, int(tile.row), int(tile.col)) != null:
			affected_unit_count += 1
	var cast_multiplier := 1.0
	if has_menghuo:
		cast_multiplier *= 1.0 + float(params.get("menghuo_damage_bonus", 0.20))
	if has_liubei:
		cast_multiplier *= 1.0 + max(0, affected_unit_count - 1) * float(params.get("liubei_extra_target_bonus", 0.04))
	var base_damage := _unit_skill_stat_value(unit) * float(params.get("mult", 2.30)) * cast_multiplier
	var target_team := _enemy_team_id(unit.team)
	var visual_group := "zhugeliang_area:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for tile in tiles:
		var row := int(tile.row)
		var col := int(tile.col)
		var target = _unit_at(enemies, row, col)
		if target == null:
			_hit_ruler(unit, base_damage, {"row":row, "col":col, "team":target_team}, t("八阵奇谋空击", "Eight-Formation empty strike"), visual_group, "area_impact")
			continue
		var marked_before := float(target.get("zhuge_fire_mark", 0.0)) > 0.0
		var damage := base_damage * (1.0 + float(params.get("fire_mark_bonus", 0.40)) if has_menghuo and marked_before else 1.0)
		_damage(unit, target, damage, "magic", t("八阵奇谋", "Eight-Formation Stratagem"), visual_group, "area_impact")
		if has_menghuo and target.alive:
			target.zhuge_fire_mark = float(params.get("fire_mark_duration", 10.0))

func _pair_active(team: String, first: String, second: String) -> bool:
	var units := _team_units(team)
	return units.any(func(unit): return unit.alive and unit.hero_id == first) and units.any(func(unit): return unit.alive and unit.hero_id == second)

func _cast_guanyu_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes[unit.hero_id].ability_params
	var tile := _random_enemy_tile(unit)
	var base: float = _unit_skill_stat_value(unit)
	var peach := _roster_has_all(_team_units(unit.team), ["liubei", "guanyu", "zhangfei"])
	var five_tigers := _roster_has_count(_team_units(unit.team), ["guanyu", "zhangfei", "zhaoyun", "huangzhong", "machao"], 5)
	var skill_mult := float(params.get("five_mult", 5.50)) if five_tigers else float(params.get("mult", 2.10))
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
	var has_caocao := _pair_active(unit.team, "dianwei", "caocao")
	var has_xuchu := _pair_active(unit.team, "dianwei", "xuchu")
	var target_count := int(params.get("target_count", 2)) + (int(params.get("caocao_bonus_targets", 1)) if has_caocao else 0)
	var mult := float(params.get("mult", 2.40))
	if has_caocao: mult -= float(params.get("caocao_damage_penalty_mult", 0.30))
	if has_xuchu: mult += float(params.get("xuchu_damage_bonus_mult", 0.80))
	mult = maxf(mult, 0.0)
	var visual_group := "dianwei_rear:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for tile in _random_unique_enemy_tiles(unit, target_count, [BOARD_ROWS - 1]):
		if tile.target == null:
			_hit_ruler(unit, _unit_skill_stat_value(unit) * mult, tile, t("恶来袭后空击", "Evil Guard Raid missed"), visual_group, "multi_target")
		else:
			_damage(unit, tile.target, _unit_skill_stat_value(unit) * mult, "physical", t("恶来袭后", "Evil Guard Raid"), visual_group, "multi_target")
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_xuchu_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.xuchu.ability_params
	var has_caocao := _pair_active(unit.team, "xuchu", "caocao")
	var has_dianwei := _pair_active(unit.team, "xuchu", "dianwei")
	var target_count := int(params.get("target_count", 2)) + (int(params.get("caocao_bonus_targets", 1)) if has_caocao else 0)
	var mult := float(params.get("mult", 3.20))
	if has_caocao: mult -= float(params.get("caocao_damage_penalty_mult", 0.40))
	if has_dianwei: mult += float(params.get("dianwei_damage_bonus_mult", 1.0))
	mult = maxf(mult, 0.0)
	var target_row := _fallback_enemy_row(unit)
	var visual_group := "xuchu_front:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for tile in _random_unique_enemy_tiles(unit, target_count, [target_row]):
		if tile.target == null:
			_hit_ruler(unit, _unit_skill_stat_value(unit) * mult, tile, t("虎卫破前空击", "Tiger Guard Break missed"), visual_group, "multi_target")
		else:
			_damage(unit, tile.target, _unit_skill_stat_value(unit) * mult, "physical", t("虎卫破前", "Tiger Guard Break"), visual_group, "multi_target")
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _five_elites_active(team: String) -> bool:
	return _roster_has_all(_team_units(team), ["zhangliao", "yuejin", "zhanghe", "xuhuang", "yujin"])

func _cast_zhangliao_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.zhangliao.ability_params
	var five := _five_elites_active(unit.team)
	var mult := float(params.get("mult", 1.10))
	if _pair_active(unit.team, "zhangliao", "yuejin"):
		mult += float(params.get("yuejin_damage_bonus_mult", 0.40))
	if five:
		mult += float(params.get("five_damage_bonus_mult", 0.80))
	var amount := _unit_skill_stat_value(unit) * mult
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
				target.vulnerable = maxf(float(target.get("vulnerable", 0.0)), float(params.get("five_vulnerable_skill_ratio", 0.40)) * _unit_skill_effect_multiplier(unit))
				target.vulnerable_time = maxf(float(target.get("vulnerable_time", 0.0)), _scaled_control_duration(unit, float(params.get("five_vulnerable_time", 5.0))))
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_yuejin_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.yuejin.ability_params
	var five := _five_elites_active(unit.team)
	var pair := _pair_active(unit.team, "zhangliao", "yuejin")
	var target_count := int(params.get("target_count", 3))
	if pair: target_count += int(params.get("zhangliao_bonus_targets", 1))
	if five: target_count += int(params.get("five_bonus_targets", 1))
	var mult := float(params.get("mult", 2.0))
	if five: mult += float(params.get("five_damage_bonus_mult", 0.50))
	var visual_group := "yuejin_volley:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for tile in _random_unique_enemy_tiles(unit, target_count):
		if tile.target == null:
			_hit_ruler(unit, _unit_skill_stat_value(unit) * mult, tile, t("先登乱射空击", "Vanguard Volley missed"), visual_group, "multi_target")
		else:
			_damage(unit, tile.target, _unit_skill_stat_value(unit) * mult, "physical", t("先登乱射", "Vanguard Volley"), visual_group, "multi_target")
			if five and tile.target.alive:
				tile.target.grievous = maxf(float(tile.target.get("grievous", 0.0)), float(params.get("five_grievous_skill_ratio", 0.50)) * _unit_skill_effect_multiplier(unit))
				tile.target.grievous_time = maxf(float(tile.target.get("grievous_time", 0.0)), _scaled_control_duration(unit, float(params.get("five_grievous_time", 5.0))))
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_xuhuang_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.xuhuang.ability_params
	var five := _five_elites_active(unit.team)
	var pair := _pair_active(unit.team, "xuhuang", "zhanghe")
	var row := rng.randi_range(0, BOARD_ROWS - 1) if five else 0
	var mult := float(params.get("mult", 0.80))
	if pair: mult += float(params.get("zhanghe_damage_bonus_mult", 0.80))
	var stun_time := float(params.get("stun", 1.5))
	if five: stun_time += float(params.get("five_stun_bonus", 2.0))
	var visual_group := "xuhuang_row:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	var target_team := _enemy_team_id(unit.team)
	for col in BOARD_COLUMNS:
		var target = _unit_at(_enemy_units(unit.team), row, col)
		if target == null:
			_hit_ruler(unit, _unit_skill_stat_value(unit) * mult, {"row":row, "col":col, "team":target_team}, t("撼地开山空击", "Earth-Splitting Axe empty strike"), visual_group, "row_impact")
		else:
			_damage(unit, target, _unit_skill_stat_value(unit) * mult, "physical", t("撼地开山", "Earth-Splitting Axe"), visual_group, "row_impact")
			_apply_skill_stun(unit, target, stun_time)
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _random_adjacent_enemies(unit: Dictionary, center: Dictionary, count: int) -> Array:
	var candidates := _enemy_units(unit.team).filter(func(enemy):
		return enemy.alive and enemy.id != center.id and float(enemy.get("stealth", 0.0)) <= 0.0 \
			and abs(int(enemy.row) - int(center.row)) <= 1 and abs(int(enemy.col) - int(center.col)) <= 1
	)
	var result: Array = []
	for _index in mini(count, candidates.size()):
		var picked := rng.randi_range(0, candidates.size() - 1)
		result.append(candidates[picked])
		candidates.remove_at(picked)
	return result

func _cast_zhanghe_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.zhanghe.ability_params
	var five := _five_elites_active(unit.team)
	var pair := _pair_active(unit.team, "zhanghe", "xuhuang")
	var target_row := _fallback_enemy_row(unit)
	var primary_tile := _random_enemy_tile_in_rows(unit, [target_row])
	var primary = primary_tile.target
	var targets: Array = [] if primary == null else [primary]
	if five and primary != null:
		targets.append_array(_random_adjacent_enemies(unit, primary, int(params.get("five_chain_targets", 2))))
	var visual_group := "zhanghe_chain:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	var stun_time := float(params.get("stun", 1.5)) + (float(params.get("xuhuang_stun_bonus", 1.0)) if pair else 0.0)
	if primary == null:
		var empty_mult := float(params.get("mult", 4.0)) + (float(params.get("five_damage_bonus_mult", 2.0)) if five else 0.0)
		_hit_ruler(unit, _unit_skill_stat_value(unit) * empty_mult, primary_tile, t("巧变连枪空击", "Coiling Spear missed"), visual_group, "multi_target")
	for target in targets:
		var stunned_before := float(target.get("stun", 0.0)) > 0.0
		var mult := float(params.get("mult", 4.0))
		if five:
			mult += float(params.get("five_damage_bonus_mult", 2.0))
			if stunned_before: mult += float(params.get("five_stunned_damage_bonus_mult", 4.0))
		_damage(unit, target, _unit_skill_stat_value(unit) * mult, "physical", t("巧变连枪", "Coiling Spear Chain"), visual_group, "multi_target")
		_apply_skill_stun(unit, target, stun_time)
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_yujin_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.yujin.ability_params
	var five := _five_elites_active(unit.team)
	var target_count := int(params.get("target_count", 1)) + (int(params.get("five_bonus_targets", 1)) if five else 0)
	var shield_mult := float(params.get("shield_mult", 3.0)) + (float(params.get("five_shield_bonus_mult", 1.0)) if five else 0.0)
	var allies := _team_units(unit.team).filter(func(ally): return ally.alive)
	allies.sort_custom(func(a, b): return float(a.hp) < float(b.hp))
	for ally in allies.slice(0, mini(target_count, allies.size())):
		var shield_value := _unit_scaled_skill_value(unit) * shield_mult
		_grant_shield(ally, shield_value, unit)
		visual_events.append({"kind":"heal", "source_id":unit.id, "target_id":ally.id, "amount":round(shield_value), "style":"shield"})
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_dongzhuo_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes[unit.hero_id].ability_params
	var ratio := float(params.get("lvbu_current_hp_ratio", 0.30)) if _pair_active(unit.team, "dongzhuo", "lvbu") else float(params.get("current_hp_ratio", 0.20))
	var amount := float(unit.hp) * ratio * _unit_skill_effect_multiplier(unit)
	var tile := _fixed_advancing_enemy_tile(unit, int(unit.col))
	var target = tile.target
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
	_add_burn_effect(source, target, duration, damage_per_second * float(source.get("burn_multiplier", 1.0)))

func _cast_jiangwei_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.jiangwei.ability_params
	var inherited_strategy := _pair_active(unit.team, "jiangwei", "zhugeliang")
	var tile := _random_enemy_tile(unit)
	var visual_group := "jiangwei_northern:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	var main_target = tile.target
	var main_damage := _unit_skill_stat_value(unit) * float(params.get("mult", 4.50))
	if main_target == null:
		_miss_tile(unit, tile, t("北伐", "Northern Expedition"))
	else:
		_damage(unit, main_target, main_damage, "magic", t("北伐", "Northern Expedition"), visual_group, "area_impact")
	if not inherited_strategy:
		return
	var splash_targets: Array = []
	for row_offset in [-1, 0, 1]:
		for col_offset in [-1, 0, 1]:
			if row_offset == 0 and col_offset == 0: continue
			var row: int = int(tile.row) + int(row_offset)
			var col: int = int(tile.col) + int(col_offset)
			if row < 0 or row >= BOARD_ROWS or col < 0 or col >= BOARD_COLUMNS:
				continue
			var adjacent = _unit_at(_enemy_units(unit.team), row, col)
			if adjacent != null: splash_targets.append(adjacent)
	var splash_damage := _unit_skill_stat_value(unit) * float(params.get("bond_splash_mult", 1.0))
	for adjacent in splash_targets:
		_damage(unit, adjacent, splash_damage, "magic", t("北伐扩散", "Northern Expedition splash"), visual_group, "area_impact")

func _cast_pangtong_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.pangtong.ability_params
	var dragon_and_phoenix := _pair_active(unit.team, "pangtong", "zhugeliang")
	var count := int(params.get("bond_target_count", 3)) if dragon_and_phoenix else int(params.get("target_count", 2))
	var targets: Array = []
	var damage := _unit_skill_stat_value(unit) * float(params.get("mult", 2.0))
	var visual_group := "pangtong_chain:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for tile in _random_unique_enemy_tiles(unit, count):
		if tile.target == null:
			_miss_tile(unit, tile, t("连环计", "Chain Scheme"))
		else:
			targets.append(tile.target)
			_damage(unit, tile.target, damage, "magic", t("连环计", "Chain Scheme"), visual_group, "area_impact")
	_apply_pangtong_link(unit, targets, float(params.get("link_duration", 6.0)), float(params.get("bond_link_ratio", 0.50)) if dragon_and_phoenix else float(params.get("link_ratio", 0.30)))

func _apply_pangtong_link(source: Dictionary, targets: Array, duration: float, ratio: float) -> void:
	var living := targets.filter(func(target): return target.alive)
	if living.size() < 2: return
	var group_id := "pangtong:" + str(source.id) + ":" + str(source.get("cast_count", 0))
	for target in living:
		var effects: Array = target.get("chain_effects", [])
		effects.append({"group":group_id, "time":duration, "ratio":ratio, "source_id":str(source.id)})
		target.chain_effects = effects

func _propagate_pangtong_link(origin: Dictionary, actual_damage: float, visual_group: String) -> void:
	for raw_chain in origin.get("chain_effects", []).duplicate(true):
		var chain: Dictionary = raw_chain
		if float(chain.get("time", 0.0)) <= 0.0: continue
		var pangtong_source = _find_by_id(combat_units, str(chain.get("source_id", "")))
		for target in combat_units:
			if not target.alive or target.id == origin.id: continue
			var linked := false
			for other_raw in target.get("chain_effects", []):
				var other: Dictionary = other_raw
				if float(other.get("time", 0.0)) > 0.0 and str(other.get("group", "")) == str(chain.get("group", "")):
					linked = true
					break
			if linked:
				_damage(pangtong_source, target, actual_damage * float(chain.get("ratio", 0.30)), "magic", t("连环传导", "Chain Echo"), visual_group, "area_impact", false, false)

func _cast_menghuo_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.menghuo.ability_params
	var with_zhugeliang := _pair_active(unit.team, "menghuo", "zhugeliang")
	var with_zhurong := _pair_active(unit.team, "menghuo", "zhurong")
	var with_dailai := _pair_active(unit.team, "menghuo", "dailaidongzhu")
	var row := 0
	var target_team := _enemy_team_id(unit.team)
	var initial_group := "menghuo_quake:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	var base_damage := _unit_skill_stat_value(unit) * float(params.get("mult", 1.15))
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
			stun_duration = _scaled_control_duration(unit, stun_duration, true)
			target.stun = maxf(float(target.stun), stun_duration)
			_add_stat(unit, "control", stun_duration)
			if with_dailai:
				_reduce_action_bar(unit, target, float(params.get("bond_action_reduction", 20.0)))
	if not with_zhugeliang:
		return
	var aftershock_group := "menghuo_aftershock:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	var aftershock_damage := _unit_skill_stat_value(unit) * float(params.get("aftershock_mult", 0.35))
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
	var burn_duration := float(params.get("burn", 3.0)) + (float(params.get("sibling_burn_bonus", 2.0)) if sibling_bond else 0.0)
	var burn_ratio := float(params.get("sibling_burn_ratio", 1.0)) if sibling_bond else float(params.get("burn_ratio", 0.50))
	var visual_group := "zhurong_blade:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for col in cols:
		var is_center := int(col) == int(tile.col)
		var damage := _unit_skill_stat_value(unit) * (float(params.get("mult", 3.0)) if is_center else float(params.get("bounce_mult", 0.50)))
		var target = _unit_at(_enemy_units(unit.team), int(tile.row), int(col))
		var impact_tile := {"row":int(tile.row), "col":int(col), "team":str(tile.team)}
		if target == null:
			_miss_tile(unit, impact_tile, t("火神飞刃", "Flame Blade"))
			continue
		_damage(unit, target, damage, "magic", t("火神飞刃", "Flame Blade"), visual_group, "area_impact")
		if target.alive:
			_apply_skill_burn(unit, target, burn_duration, _unit_skill_stat_value(unit) * burn_ratio)

func _cast_dailai_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.dailaidongzhu.ability_params
	var with_menghuo := _pair_active(unit.team, "dailaidongzhu", "menghuo")
	var with_zhurong := _pair_active(unit.team, "dailaidongzhu", "zhurong")
	var center_tile := _random_enemy_tile(unit)
	var rows: Array = range(BOARD_ROWS) if with_menghuo else [int(center_tile.row)]
	var direct_mult := float(params.get("column_mult", 3.20)) if with_menghuo else float(params.get("mult", 4.90))
	var visual_group := "dailai_wolf:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for row in rows:
		var damage := _unit_skill_stat_value(unit) * direct_mult
		var target = _unit_at(_enemy_units(unit.team), int(row), int(center_tile.col))
		if target != null and float(target.get("stealth", 0.0)) > 0.0:
			target = null
		var impact_tile := {"row":int(row), "col":int(center_tile.col), "team":str(center_tile.team)}
		if target == null:
			_hit_ruler(unit, damage, impact_tile, t("蛮骨狼袭空击", "Savage-Bone Wolf Assault missed"), visual_group, "area_impact")
			if with_zhurong:
				_set_ground_burn(unit, str(center_tile.team), int(row), int(center_tile.col), float(params.get("bond_burn", 4.0)), _unit_skill_stat_value(unit) * float(params.get("bond_burn_ratio", 0.50)), visual_group)
			continue
		var burning_before := with_zhurong and float(target.get("burn", 0.0)) > 0.0
		if burning_before:
			damage += _unit_skill_stat_value(unit) * float(params.get("burning_bonus_mult", 0.50))
		_damage(unit, target, damage, "physical", t("蛮骨狼袭", "Savage-Bone Wolf Assault"), visual_group, "area_impact")
		if not target.alive:
			continue
		if with_zhurong:
			_apply_skill_burn(unit, target, float(params.get("bond_burn", 4.0)), _unit_skill_stat_value(unit) * float(params.get("bond_burn_ratio", 0.50)))

func _cast_lvbu_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes[unit.hero_id].ability_params
	_log(_hero_name("lvbu") + t(" 发动无双横扫！", " unleashes Peerless Sweep!"))
	var damage_dealt := _cast_lvbu_sweep_once(unit, 0)
	if _pair_active(unit.team, "lvbu", "chengong") and not _has_winner() and rng.randf() < float(params.get("chengong_repeat_chance", 0.30)):
		damage_dealt += _cast_lvbu_sweep_once(unit, 1)
		_log(t("【谋定无双】陈宫使吕布再次横扫！", "[Peerless Strategy] Chen Gong triggers a second sweep!"))
	if _pair_active(unit.team, "lvbu", "dongzhuo") and damage_dealt > 0.0:
		_heal_unit_only(unit, unit, damage_dealt * float(params.get("dongzhuo_heal", 0.20)))
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_lvbu_sweep_once(unit: Dictionary, wave: int) -> float:
	var params: Dictionary = heroes.lvbu.ability_params
	var amount := _unit_skill_stat_value(unit) * float(params.get("mult", 2.20))
	if _pair_active(unit.team, "lvbu", "gaoshun"):
		amount += _unit_skill_stat_value(unit) * float(params.get("gaoshun_damage_bonus_mult", 0.70))
	if _pair_active(unit.team, "lvbu", "diaochan"):
		amount *= _missing_hp_damage_multiplier(unit, float(params.get("missing_hp_step", 0.10)), float(params.get("diaochan_bonus_per_step", 0.03)) * _unit_skill_effect_multiplier(unit))
	var damage_dealt := 0.0
	var visual_group := "lvbu_sweep:" + str(unit.id) + ":" + str(unit.get("cast_count", 0)) + ":" + str(wave)
	var target_row := _fallback_enemy_row(unit)
	var qun_lord_level := _tianshu_level("qun_lord") if unit.team == "player" else 0
	var col_offsets: Array = [-1, 0, 1]
	if qun_lord_level >= 1:
		col_offsets = [-2, -1, 0, 1, 2]
	for col_offset in col_offsets:
		var target_col: int = int(unit.col) + int(col_offset)
		if target_col < 0 or target_col >= BOARD_COLUMNS: continue
		var tile := _enemy_tile(unit, target_row, target_col)
		var target = tile.target
		if target == null:
			_hit_ruler(unit, amount, tile, t("无双横扫空击", "Peerless Sweep missed"), visual_group, "row_impact")
		else:
			var hp_before := float(target.hp)
			_damage(unit, target, amount, "physical", t("无双横扫", "Peerless Sweep"), visual_group, "row_impact")
			damage_dealt += maxf(0.0, hp_before - float(target.hp))
	if qun_lord_level >= 2:
		for sweep_entry in [[target_row + 1, -1], [target_row + 1, 0], [target_row + 1, 1], [target_row + 2, 0]]:
			var extra_row := int(sweep_entry[0])
			var extra_col := int(unit.col) + int(sweep_entry[1])
			if extra_row >= BOARD_ROWS or extra_col < 0 or extra_col >= BOARD_COLUMNS: continue
			var extra_tile := {"row":extra_row, "col":extra_col, "team":_enemy_team_id(unit.team)}
			var extra_target = _unit_at(_enemy_units(unit.team), extra_row, extra_col)
			if extra_target == null:
				_hit_ruler(unit, amount, extra_tile, t("无双横扫空击", "Peerless Sweep missed"), visual_group, "row_impact")
			else:
				var extra_hp_before := float(extra_target.hp)
				_damage(unit, extra_target, amount, "physical", t("无双横扫", "Peerless Sweep"), visual_group, "row_impact")
				damage_dealt += maxf(0.0, extra_hp_before - float(extra_target.hp))
	return damage_dealt

func _missing_hp_damage_multiplier(target: Dictionary, step: float, bonus_per_step: float) -> float:
	var missing_ratio := 1.0 - float(target.hp) / maxf(1.0, float(target.max_hp))
	return 1.0 + floorf(clampf(missing_ratio, 0.0, 1.0) / maxf(0.001, step) + 0.0001) * bonus_per_step

func _ruler_missing_hp_damage_multiplier(team: String, step: float, bonus_per_step: float) -> float:
	var target_hp := enemy_ruler_hp if team == "player" else player_ruler_hp
	var missing_ratio := 1.0 - float(target_hp) / maxf(1.0, float(RULER_MAX_HP))
	return 1.0 + floorf(clampf(missing_ratio, 0.0, 1.0) / maxf(0.001, step) + 0.0001) * bonus_per_step

func _random_unique_enemy_tiles(unit: Dictionary, count: int, rows: Array = []) -> Array:
	var available: Array = []
	var target_team := _enemy_team_id(unit.team)
	var target_rows := _attackable_rows(unit) if rows.is_empty() else rows
	for row in target_rows:
		for col in BOARD_COLUMNS:
			available.append({"row":row, "col":col, "team":target_team})
	var result: Array = []
	for _index in mini(count, available.size()):
		var picked := rng.randi_range(0, available.size() - 1)
		var tile: Dictionary = available[picked]
		available.remove_at(picked)
		tile = _enemy_tile(unit, int(tile.row), int(tile.col))
		result.append(tile)
	return result

func _cast_zhouyu(unit: Dictionary) -> void:
	var params: Dictionary = heroes.zhouyu.ability_params
	var tile_count := int(params.get("tile_count", 2))
	if bool(unit.get("four_heroes", false)):
		tile_count += int(params.get("four_heroes_bonus_tiles", 2))
	var burn_duration := float(params.get("burn", 4.0))
	if bool(unit.get("zhouyu_xiaoqiao", false)):
		burn_duration += float(params.get("xiaoqiao_burn_duration_bonus", 3.0))
	var missing_scale := bool(unit.get("zhouyu_huanggai", false))
	var missing_step := float(params.get("missing_hp_step", 0.10))
	var missing_bonus := float(params.get("missing_hp_bonus_per_step", 0.03))
	var base := float(params.get("base_value", _unit_skill_stat_value(unit))) * float(params.get("mult", 2.0))
	var burn_mult := float(params.get("burn_ratio", 0.30))
	if bool(unit.get("four_heroes", false)): burn_mult += float(params.get("four_heroes_burn_bonus_mult", 0.50))
	if bool(unit.get("zhouyu_xiaoqiao", false)): burn_mult += float(params.get("xiaoqiao_burn_bonus_mult", 0.30))
	var burn_per_second := _unit_skill_stat_value(unit) * burn_mult * float(unit.get("burn_multiplier", 1.0))
	unit["zhouyu_casts"] = int(unit.get("zhouyu_casts", 0)) + 1
	var visual_group := "zhouyu_tiles:" + str(unit.id) + ":" + str(unit.zhouyu_casts)
	var tiles := _random_unique_enemy_tiles(unit, tile_count)
	_log(_hero_name("zhouyu") + t(" 随机点燃 ", " ignites ") + str(tile_count) + t(" 个敌方格！", " enemy tiles!"))
	for tile in tiles:
		visual_events.append({"kind":"row_burn", "source_id":unit.id, "target_id":"", "team":tile.team, "row":tile.row, "col":tile.col, "amount":0, "skill":true, "style":"magic", "visual_group":visual_group, "group_style":"tile_burn"})
		if tile.target == null:
			_hit_ruler(unit, base, tile, t("赤壁点火空击", "Red Cliffs empty strike"), visual_group, "tile_burn")
			_set_ground_burn(unit, str(tile.team), int(tile.row), int(tile.col), burn_duration, burn_per_second, visual_group, missing_scale, missing_step, missing_bonus)
		else:
			_damage(unit, tile.target, base, "magic", t("赤壁点火", "Red Cliffs"), visual_group, "tile_burn")
			if tile.target.alive:
				_add_burn_effect(unit, tile.target, burn_duration, burn_per_second, missing_scale, visual_group, missing_step, missing_bonus)

func _set_ground_burn(source: Dictionary, target_team: String, row: int, col: int, duration: float, damage: float, visual_group: String, missing_hp_scale := false, missing_hp_step := 0.10, missing_hp_bonus_per_step := 0.05) -> void:
	var effect := {
		"type":"burn",
		"source_id":str(source.id),
		"team":target_team,
		"row":row,
		"col":col,
		"time":duration,
		"clock":0.0,
		"damage":damage,
		"visual_group":visual_group,
		"missing_hp_scale":missing_hp_scale,
		"missing_hp_step":missing_hp_step,
		"missing_hp_bonus_per_step":missing_hp_bonus_per_step
	}
	ground_effects.append(effect)

func _set_ground_poison(source: Dictionary, target_team: String, row: int, col: int, stacks: int, retention: float, visual_group: String) -> void:
	if source == null or stacks <= 0:
		return
	ground_effects.append({
		"type":"poison",
		"source_id":str(source.id),
		"team":target_team,
		"row":row,
		"col":col,
		"clock":0.0,
		"stacks":stacks,
		"retention":retention,
		"visual_group":visual_group
	})

func _adjacent_luxun_tiles(unit: Dictionary, from_tile: Dictionary, hit_tiles: Dictionary) -> Array:
	var candidates: Array = []
	for offset in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
		var row := int(from_tile.row) + int(offset[0])
		var col := int(from_tile.col) + int(offset[1])
		if row < 0 or row >= BOARD_ROWS or col < 0 or col >= BOARD_COLUMNS:
			continue
		if hit_tiles.has(str(row) + ":" + str(col)):
			continue
		candidates.append(_enemy_tile(unit, row, col))
	return candidates

func _luxun_damage_multiplier(unit: Dictionary, target: Dictionary) -> float:
	var params: Dictionary = heroes.luxun.ability_params
	var result := float(params.get("mult", 2.90))
	if bool(unit.get("luxun_sunquan", false)):
		result += float(params.get("sunquan_damage_bonus_mult", 0.80))
		if float(target.get("burn", 0.0)) > 0.0:
			result += float(params.get("sunquan_burning_bonus_mult", 0.40))
	return result

func _cast_luxun(unit: Dictionary) -> void:
	var params: Dictionary = heroes.luxun.ability_params
	var skill_value := _unit_skill_stat_value(unit)
	var visual_group := "luxun_fireball:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	var current := _random_enemy_tile(unit)
	var bounce_count := int(params.get("bounces", 1)) + (int(params.get("four_heroes_bonus_bounces", 2)) if bool(unit.get("four_heroes", false)) else 0)
	var hit_tiles := {}
	_log(_hero_name("luxun") + t(" 发射火球，沿相邻格弹射！", " launches a fireball through adjacent tiles!"))
	for chain_index in bounce_count + 1:
		hit_tiles[str(current.row) + ":" + str(current.col)] = true
		var target = current.target
		var damage_mult := float(params.get("mult", 2.90))
		if target != null:
			damage_mult = _luxun_damage_multiplier(unit, target)
			_damage(unit, target, skill_value * damage_mult, "magic", t("火烧连营", "Flames of Camp"), visual_group, "fireball_chain")
			if target.alive and bool(unit.get("four_heroes", false)):
				_apply_skill_burn(unit, target, float(params.get("four_heroes_burn", 3.0)), skill_value * float(params.get("four_heroes_burn_ratio", 0.30)))
		else:
			if bool(unit.get("luxun_sunquan", false)):
				damage_mult += float(params.get("sunquan_damage_bonus_mult", 0.80))
			_hit_ruler(unit, skill_value * damage_mult, current, t("火烧连营空击", "Flames of Camp empty strike"), visual_group, "fireball_chain")
			if bool(unit.get("four_heroes", false)):
				_set_ground_burn(unit, str(current.team), int(current.row), int(current.col), float(params.get("four_heroes_burn", 3.0)), skill_value * float(params.get("four_heroes_burn_ratio", 0.30)), visual_group)
		for created_event_index in range(visual_events.size() - 1, -1, -1):
			var created_event: Dictionary = visual_events[created_event_index]
			if str(created_event.get("visual_group", "")) != visual_group:
				break
			if str(created_event.get("kind", "")) in ["damage", "empty"]:
				visual_events[created_event_index]["chain_index"] = chain_index
				visual_events[created_event_index]["projectile_asset"] = "res://ThreeKingdom/animations/fireball.png"
				break
		if chain_index >= bounce_count:
			break
		var adjacent := _adjacent_luxun_tiles(unit, current, hit_tiles)
		if adjacent.is_empty():
			break
		current = adjacent[rng.randi_range(0, adjacent.size() - 1)]

func _cast_lvmeng_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.lvmeng.ability_params
	var tile := _random_enemy_tile_in_rows(unit, [BOARD_ROWS - 1])
	var target = tile.target
	var mult := float(params.get("mult", 5.0)) + (float(params.get("ganning_bonus_mult", 1.50)) if bool(unit.get("lvmeng_ganning", false)) else 0.0)
	var amount := float(params.get("base_value", _unit_skill_stat_value(unit))) * mult
	if target == null:
		_hit_ruler(unit, amount, tile, t("白衣渡江空击", "White-Robed Raid empty strike"))
	else:
		_damage(unit, target, amount, "physical", t("白衣渡江", "White-Robed Raid"), "", "", false, true, bool(unit.get("lvmeng_ganning", false)))
		if target.alive and bool(unit.get("four_heroes", false)):
			var fear_duration := _scaled_control_duration(unit, float(params.get("fear", 5.0)))
			target.fear = maxf(float(target.get("fear", 0.0)), fear_duration)
			target.fear_damage_ratio = maxf(float(target.get("fear_damage_ratio", 0.0)), float(params.get("fear_max_hp_ratio", 0.04)) * _unit_skill_effect_multiplier(unit))
			target.fear_clock = 0.0
			_add_stat(unit, "control", fear_duration)
			visual_events.append({"kind":"skill", "source_id":unit.id, "target_id":target.id, "amount":0, "style":"magic"})

func _cast_diaochan(unit: Dictionary) -> void:
	var params: Dictionary = heroes[unit.hero_id].ability_params
	var enemies := _enemy_units(unit.team).filter(func(enemy): return enemy.alive and float(enemy.get("stealth", 0.0)) <= 0.0)
	if enemies.is_empty(): return
	var target: Dictionary = enemies[rng.randi_range(0, enemies.size() - 1)]
	var with_dongzhuo := _pair_active(unit.team, "diaochan", "dongzhuo")
	var duration := float(params.get("duration", 4.0)) + (float(params.get("dongzhuo_duration_bonus", 2.0)) if with_dongzhuo else 0.0)
	target.charm = maxf(float(target.get("charm", 0.0)), _scaled_control_duration(unit, duration))
	target.charm_forced_attack = _pair_active(unit.team, "diaochan", "lvbu")
	target.charm_attack_clock = 0.0
	_add_stat(unit, "control", float(target.charm))
	visual_events.append({"kind":"skill", "source_id":unit.id, "target_id":target.id, "amount":0, "style":"magic"})
	if with_dongzhuo:
		_heal_unit_only(unit, unit, _unit_scaled_skill_value(unit) * float(params.get("dongzhuo_self_heal_mult", 2.0)))
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
	if _pair_active(unit.team, "gaoshun", "lvbu"): target_count += int(params.get("lvbu_bonus_targets", 1))
	var duration := float(params.get("vulnerable_time", 3.5))
	if _pair_active(unit.team, "gaoshun", "chengong"): duration += float(params.get("chengong_bonus_duration", 3.5))
	var target_row := _fallback_enemy_row(unit)
	var visual_group := "gaoshun_fragile:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for tile in _random_unique_enemy_tiles(unit, target_count, [target_row]):
		var target = tile.target
		if target == null:
			_hit_ruler(unit, _unit_skill_stat_value(unit) * float(params.get("mult", 2.20)), tile, t("陷阵之志空击", "Formation Resolve missed"), visual_group, "multi_target")
			continue
		_damage(unit, target, _unit_skill_stat_value(unit) * float(params.get("mult", 2.20)), "physical", t("陷阵之志", "Formation Resolve"), visual_group, "multi_target")
		if target.alive:
			target.vulnerable = maxf(float(target.get("vulnerable", 0.0)), float(params.get("vulnerable", 0.40)) * _unit_skill_effect_multiplier(unit))
			target.vulnerable_time = maxf(float(target.get("vulnerable_time", 0.0)), _scaled_control_duration(unit, duration))
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_yanliang_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.yanliang.ability_params
	var count := int(params.get("target_count", 2))
	var mult := float(params.get("mult", 2.0))
	if _pair_active(unit.team, "yanliang", "wenchou"):
		count += int(params.get("wenchou_bonus_targets", 1))
		mult -= float(params.get("wenchou_damage_penalty_mult", 0.30))
	if bool(unit.get("four_pillars", false)):
		count += int(params.get("four_pillars_bonus_targets", 1))
		mult += float(params.get("four_pillars_damage_bonus_mult", 1.20))
	var damage := _unit_skill_stat_value(unit) * mult
	var visual_group := "yanliang_assault:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for tile in _random_unique_enemy_tiles(unit, count, [1, 2]):
		if tile.target == null:
			_hit_ruler(unit, damage, tile, t("河北猛袭空击", "Hebei Fierce Assault missed"), visual_group, "multi_target")
		else:
			_damage(unit, tile.target, damage, "physical", t("河北猛袭", "Hebei Fierce Assault"), visual_group, "multi_target")
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_wenchou_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.wenchou.ability_params
	var count := int(params.get("target_count", 2))
	var mult := float(params.get("mult", 3.0))
	if _pair_active(unit.team, "wenchou", "yanliang"):
		count += int(params.get("yanliang_bonus_targets", 1))
		mult -= float(params.get("yanliang_damage_penalty_mult", 0.50))
	if bool(unit.get("four_pillars", false)):
		count += int(params.get("four_pillars_bonus_targets", 1))
		mult += float(params.get("four_pillars_damage_bonus_mult", 1.50))
	var visual_group := "wenchou_breakthrough:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	var amount := _unit_skill_stat_value(unit) * mult
	for tile in _random_unique_enemy_tiles(unit, count, [0, 1]):
		if tile.target == null:
			_hit_ruler(unit, amount, tile, t("河北破阵空击", "Hebei Breakthrough missed"), visual_group, "multi_target")
		else:
			_damage(unit, tile.target, amount, "physical", t("河北破阵", "Hebei Breakthrough"), visual_group, "multi_target", false)
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_qun_zhanghe_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.qunzhanghe.ability_params
	var count := int(params.get("target_count", 2))
	var shield_mult := float(params.get("shield_mult", 2.0))
	if _pair_active(unit.team, "qunzhanghe", "gaolan"):
		shield_mult += float(params.get("gaolan_shield_bonus_mult", 0.60))
	if bool(unit.get("four_pillars", false)):
		count += int(params.get("four_pillars_bonus_targets", 1))
		shield_mult += float(params.get("four_pillars_shield_bonus_mult", 1.0))
	var shield_value := _unit_skill_stat_value(unit) * shield_mult * float(unit.get("stat_mult", 1.0))
	var allies := _team_units(unit.team).filter(func(ally): return ally.alive)
	allies.sort_custom(func(a, b):
		if not is_equal_approx(float(a.hp), float(b.hp)): return float(a.hp) < float(b.hp)
		return str(a.id) < str(b.id)
	)
	for target in allies.slice(0, mini(count, allies.size())):
		_grant_shield(target, shield_value, unit)
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
	target.burn_effects = []
	target.burn_missing_hp_scale = false
	target.fear = 0.0
	target.fear_damage_ratio = 0.0
	target.fear_clock = 0.0
	target.freeze = 0.0
	target.freeze_shatter_damage = 0.0
	target.freeze_shatter_per_second = 0.0
	target.freeze_source_id = ""
	target.poison = 0.0
	target.poison_ratio = 0.0
	target.poison_stacks = 0
	target.poison_clock = 0.0
	target.poison_source = ""
	target.poison_effects = []
	target.silence = 0.0
	target.slow = 0.0
	target.slow_time = 0.0
	target.vulnerable = 0.0
	target.vulnerable_time = 0.0
	target.grievous = 0.0
	target.grievous_time = 0.0
	target.strategy_mark = 0.0
	target.zhuge_fire_mark = 0.0
	target.skill_debuff = 0.0
	target.skill_debuff_time = 0.0

func _cast_huatuo_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.huatuo.ability_params
	var heal_mult := float(params.get("heal_mult", 1.10))
	if _pair_active(unit.team, "huatuo", "yuji"):
		heal_mult += float(params.get("yuji_bonus_mult", 0.70))
	if _pair_active(unit.team, "huatuo", "zuoci"):
		heal_mult += float(params.get("zuoci_bonus_mult", 0.30))
	var cleanses := _pair_active(unit.team, "huatuo", "zuoci")
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
	var target_count := int(params.get("target_count", 2))
	if _pair_active(unit.team, "yuji", "huatuo"):
		target_count += int(params.get("huatuo_bonus_targets", 1))
	var stack_mult := float(params.get("poison_stack_mult", 1.40))
	var poison_stacks := maxi(1, roundi(_unit_skill_stat_value(unit) * stack_mult))
	var visual_group := "yuji_poison:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for tile in _random_unique_enemy_tiles(unit, target_count):
		if tile.target == null:
			_set_ground_poison(unit, str(tile.team), int(tile.row), int(tile.col), poison_stacks, 0.5, visual_group)
			visual_events.append({"kind":"empty", "source_id":unit.id, "team":tile.team, "row":tile.row, "col":tile.col, "amount":0, "skill":true, "style":"magic", "visual_group":visual_group, "group_style":"poison_apply"})
		else:
			_add_decay_poison_effect(unit, tile.target, poison_stacks)
			visual_events.append({"kind":"skill", "source_id":unit.id, "target_id":tile.target.id, "amount":poison_stacks, "style":"magic", "visual_group":visual_group, "group_style":"poison_apply"})
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_zuoci_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.zuoci.ability_params
	var heal_mult := float(params.get("heal_mult", 1.70))
	if _pair_active(unit.team, "zuoci", "huatuo"):
		heal_mult += float(params.get("huatuo_bonus_mult", 0.5))
	var heal_group := "zuoci_heal:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for target in _lowest_current_hp_allies(unit, int(params.get("target_count", 2))):
		_heal_unit_only(unit, target, _unit_scaled_skill_value(unit) * heal_mult, heal_group, "simultaneous")
	if _pair_active(unit.team, "zuoci", "yuji"):
		var visual_group := "zuoci_thunder:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
		for tile in _random_unique_enemy_tiles(unit, int(params.get("target_count", 2))):
			if tile.target == null:
				_hit_ruler(unit, _unit_skill_stat_value(unit) * float(params.get("thunder_mult", 1.0)), tile, t("遁甲天雷空击", "Immortal Thunder missed"), visual_group, "multi_target")
			else:
				_damage(unit, tile.target, _unit_skill_stat_value(unit) * float(params.get("thunder_mult", 1.0)), "magic", t("遁甲天雷", "Immortal Thunder"), visual_group, "multi_target")
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_zhangjiao_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.zhangjiao.ability_params
	var target_count := int(params.get("target_count", 2))
	var mult := float(params.get("mult", 3.0))
	if _pair_active(unit.team, "zhangjiao", "zhangliang"):
		mult += float(params.get("zhangliang_bonus_mult", 1.20))
	var visual_group := "zhangjiao_thunder:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for tile in _random_unique_enemy_tiles(unit, target_count):
		if tile.target == null:
			_hit_ruler(unit, _unit_skill_stat_value(unit) * mult, tile, t("黄天雷引空击", "Yellow Sky Thunder missed"), visual_group, "multi_target")
		else:
			_damage(unit, tile.target, _unit_skill_stat_value(unit) * mult, "magic", t("黄天雷引", "Yellow Sky Thunder"), visual_group, "multi_target")
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_zhangjiao_death_thunder(zhangjiao: Dictionary, fallen: Dictionary) -> void:
	if zhangjiao == null or not zhangjiao.alive or _has_winner(): return
	var params: Dictionary = heroes.zhangjiao.ability_params
	var visual_group := "zhangjiao_death_thunder:" + str(zhangjiao.id) + ":" + str(fallen.id)
	for tile in _random_unique_enemy_tiles(zhangjiao, int(params.get("death_thunder_targets", 2))):
		var amount := _unit_skill_stat_value(zhangjiao) * float(params.get("death_thunder_mult", 6.0))
		if tile.target == null:
			_hit_ruler(zhangjiao, amount, tile, t("天地雷契空击", "Heaven-Earth Thunder missed"), visual_group, "multi_target")
		else:
			_damage(zhangjiao, tile.target, amount, "magic", t("天地雷契", "Heaven-Earth Thunder"), visual_group, "multi_target")
			if tile.target.alive:
				_apply_skill_stun(zhangjiao, tile.target, float(params.get("death_thunder_stun", 1.111111)))
	_log("[color=#e6c86f]" + t("【天地雷契】友军阵亡，张角立即释放强化雷击！", "[Heaven and Earth] An ally falls; Zhang Jiao immediately casts empowered thunder!") + "[/color]")

func _cast_zhangliang_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.zhangliang.ability_params
	var target_count := int(params.get("target_count", 2))
	if _pair_active(unit.team, "zhangliang", "zhangjiao"): target_count += int(params.get("zhangjiao_bonus_targets", 1))
	var duration := float(params.get("duration", 4.0))
	if _pair_active(unit.team, "zhangliang", "zhangbao"): duration += float(params.get("zhangbao_duration_bonus", 2.5))
	var visual_group := "zhangliang_weak:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for target in _pick_random_units(_enemy_units(unit.team).filter(func(enemy): return enemy.alive and float(enemy.get("stealth", 0.0)) <= 0.0), target_count):
		target.skill_debuff = maxf(float(target.get("skill_debuff", 0.0)), float(params.get("skill_reduction", 0.5)) * _unit_skill_effect_multiplier(unit))
		var control_duration := _scaled_control_duration(unit, duration)
		target.skill_debuff_time = maxf(float(target.get("skill_debuff_time", 0.0)), control_duration)
		_add_stat(unit, "control", control_duration)
		visual_events.append({"kind":"skill", "source_id":unit.id, "target_id":target.id, "amount":roundi(float(params.get("skill_reduction", 0.5)) * _unit_skill_effect_multiplier(unit) * 100.0), "style":"magic", "visual_group":visual_group, "group_style":"weak_apply"})
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_lusu_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes[unit.hero_id].ability_params
	var four_heroes := bool(unit.get("four_heroes", false))
	var target_count := int(params.get("four_heroes_target_count", 2)) if four_heroes else int(params.get("target_count", 1))
	var heal_mult := float(params.get("four_heroes_heal_mult", 4.0)) if four_heroes else float(params.get("heal_mult", 3.20))
	var max_hp_ratio := float(params.get("four_heroes_max_hp_skill_ratio", 2.0)) if four_heroes else float(params.get("max_hp_skill_ratio", 1.0))
	var max_hp_flat := _unit_skill_stat_value(unit) * max_hp_ratio
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
		var heal_amount := _unit_skill_stat_value(unit) * heal_mult
		_heal_unit_only(unit, target, heal_amount, visual_group, "simultaneous")
		visual_events.append({"kind":"skill", "source_id":unit.id, "target_id":target.id, "amount":round(max_hp_flat), "style":"heal"})
	_log(_hero_name("lusu") + t(" 为最低生命友军稳固阵线！", " fortifies the lowest-current-HP allies!"))

func _cast_daqiao_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.daqiao.ability_params
	var allies := _team_units(unit.team).filter(func(ally): return ally.alive)
	allies.sort_custom(func(a, b):
		if not is_equal_approx(float(a.hp), float(b.hp)): return float(a.hp) < float(b.hp)
		return str(a.id) < str(b.id)
	)
	if allies.is_empty(): return
	var target: Dictionary = allies[0]
	var healing_multiplier := 1.0
	if bool(unit.get("sunce_daqiao", false)):
		var missing_ratio := 1.0 - float(target.hp) / maxf(1.0, float(target.max_hp))
		var missing_steps := floori(clampf(missing_ratio, 0.0, 1.0) / maxf(0.001, float(params.get("bond_missing_hp_step", 0.10))) + 0.0001)
		healing_multiplier += float(missing_steps) * float(params.get("bond_heal_bonus_per_step", 0.04))
	var visual_group := "daqiao_heal:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	_heal_unit_only(unit, target, _unit_skill_stat_value(unit) * float(params.get("heal_mult", 3.80)) * healing_multiplier, visual_group, "simultaneous")
	if _pair_active(unit.team, "daqiao", "xiaoqiao"):
		_heal_unit_only(unit, target, _unit_skill_stat_value(unit) * float(params.get("xiaoqiao_extra_heal_mult", 1.50)) * healing_multiplier, visual_group, "simultaneous")
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

func _cast_xiaoqiao_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes[unit.hero_id].ability_params
	var zhouyu_bond := bool(unit.get("zhouyu_xiaoqiao", false))
	var daqiao_bond := _pair_active(unit.team, "daqiao", "xiaoqiao")
	var target_count := int(params.get("target_count", 2)) + (int(params.get("zhouyu_bonus_targets", 1)) if zhouyu_bond else 0)
	var duration := float(params.get("slow_time", 6.0))
	var slow_skill_ratio := float(params.get("slow_skill_ratio", 0.35))
	if daqiao_bond: slow_skill_ratio += float(params.get("daqiao_slow_bonus_skill_ratio", 0.12))
	var slow_ratio := slow_skill_ratio * _unit_skill_effect_multiplier(unit)
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
		var control_duration := _scaled_control_duration(unit, duration)
		target.slow_time = maxf(float(target.get("slow_time", 0.0)), control_duration)
		_add_stat(unit, "control", control_duration)
		visual_events.append({"kind":"skill", "source_id":unit.id, "target_id":target.id, "amount":round(slow_ratio * 100.0), "style":"magic", "visual_group":visual_group, "group_style":"simultaneous"})
		applied += 1
	if applied == 0:
		visual_events.append({"kind":"empty", "source_id":unit.id, "team":_enemy_team_id(unit.team), "row":BOARD_ROWS - 1, "col":rng.randi_range(0, BOARD_COLUMNS - 1), "amount":0, "skill":true, "style":"magic"})
	_log(_hero_name("xiaoqiao") + t(" 使敌方后军陷入天香缓阵！", " slows the enemy rearguard with Gentle Breeze!"))

func _cast_xusheng_skill(unit: Dictionary) -> void:
	var params: Dictionary = heroes.xusheng.ability_params
	var row := _fallback_enemy_row(unit)
	var duration := float(params.get("slow_time", 4.0)) + (float(params.get("bond_slow_time_bonus", 3.0)) if bool(unit.get("dingfeng_xusheng", false)) else 0.0)
	var slow_ratio := float(params.get("slow_skill_ratio", 0.30)) * _unit_skill_effect_multiplier(unit)
	var damage := _unit_skill_stat_value(unit) * float(params.get("mult", 1.0))
	var target_team := _enemy_team_id(unit.team)
	var visual_group := "xusheng_water:" + str(unit.id) + ":" + str(unit.get("cast_count", 0))
	for col in BOARD_COLUMNS:
		var tile := {"row":row, "col":col, "team":target_team}
		var target = _unit_at(_enemy_units(unit.team), row, col)
		if target == null:
			_hit_ruler(unit, damage, tile, t("宿卫水阵空击", "Guardian Water Formation missed"), visual_group, "row_impact")
		else:
			_damage(unit, target, damage, "magic", t("宿卫水阵", "Guardian Water Formation"), visual_group, "row_impact")
			if target.alive:
				target.slow = maxf(float(target.get("slow", 0.0)), slow_ratio)
				var control_duration := _scaled_control_duration(unit, duration)
				target.slow_time = maxf(float(target.get("slow_time", 0.0)), control_duration)
				_add_stat(unit, "control", control_duration)
	unit.cast_count = int(unit.get("cast_count", 0)) + 1

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
	amount *= 1.0 + _endless_imprint_value(source, "heal_pct")
	if target != null and float(target.hp) / maxf(1.0, float(target.max_hp)) <= 0.35:
		amount *= 1.0 + _endless_imprint_value(source, "heal_low_pct")
	amount *= _tianshu_heal_multiplier(source)
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
	var ruler_restored := _tianshu_on_overflow(source, target, overflow, visual_kind, nonblocking)
	_add_stat(source, "healing", amount - overflow + ruler_restored)

func _heal_unit_only(source: Dictionary, target: Dictionary, amount: float, visual_group := "", group_style := "") -> float:
	if source == null or target == null or not target.alive or amount <= 0.0: return 0.0
	amount *= 1.0 + _endless_imprint_value(source, "heal_pct")
	if float(target.hp) / maxf(1.0, float(target.max_hp)) <= 0.35:
		amount *= 1.0 + _endless_imprint_value(source, "heal_low_pct")
	amount *= _tianshu_heal_multiplier(source)
	amount *= 1.0 - clampf(float(target.get("grievous", 0.0)), 0.0, 0.95)
	var missing := maxf(0.0, float(target.max_hp) - float(target.hp))
	var restored := minf(missing, amount)
	if restored > 0.0:
		target.hp += restored
		visual_events.append({"kind":"heal", "source_id":source.id, "target_id":target.id, "amount":round(restored), "style":"heal", "nonblocking":true, "visual_group":visual_group, "group_style":group_style})
	var ruler_restored := _tianshu_on_overflow(source, target, amount - restored, "heal", true)
	_add_stat(source, "healing", restored + ruler_restored)
	return restored

func _ability_enemy_tile(unit: Dictionary, _params: Dictionary) -> Dictionary:
	# 通用攻击技能统一抽取射程内格子；需要直锁武将的控制/行动条技能使用各自专用施法函数。
	return _random_enemy_tile(unit)

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
		+ (1.0 if float(unit.get("zhuge_fire_mark", 0.0)) > 0.0 else 0.0)
	)

func _has_any_debuff(unit: Dictionary) -> bool:
	return _debuff_score(unit) > 0.0

func _random_enemy_tile(unit: Dictionary) -> Dictionary:
	return _random_enemy_tile_in_rows(unit, _attackable_rows(unit))

func _enemy_tile(unit: Dictionary, row: int, col: int) -> Dictionary:
	var target = _unit_at(_enemy_units(unit.team), row, col)
	if target != null and float(target.get("stealth", 0.0)) > 0.0:
		target = null
	return {"row":row, "col":col, "team":_enemy_team_id(unit.team), "target":target}

func _random_enemy_tile_in_rows(unit: Dictionary, rows: Array) -> Dictionary:
	var valid_rows: Array = rows.filter(func(row): return int(row) >= 0 and int(row) < BOARD_ROWS)
	if valid_rows.is_empty():
		valid_rows = [0]
	return _enemy_tile(unit, int(valid_rows[rng.randi_range(0, valid_rows.size() - 1)]), rng.randi_range(0, BOARD_COLUMNS - 1))

func _fallback_enemy_row(unit: Dictionary, preferred_rows := [0, 1, 2]) -> int:
	for row in preferred_rows:
		if _enemy_units(unit.team).any(func(enemy): return enemy.alive and int(enemy.row) == int(row)):
			return int(row)
	return int(preferred_rows.back()) if not preferred_rows.is_empty() else 0

func _fixed_advancing_enemy_tile(unit: Dictionary, col: int, preferred_rows := [0, 1, 2]) -> Dictionary:
	return _enemy_tile(unit, _fallback_enemy_row(unit, preferred_rows), clampi(col, 0, BOARD_COLUMNS - 1))

func _enemy_team_id(team: String) -> String:
	return "enemy" if team == "player" else "player"

func _miss_tile(unit: Dictionary, tile: Dictionary, label: String) -> void:
	visual_events.append({"kind":"empty", "source_id":unit.id, "team":tile.team, "row":tile.row, "col":tile.col, "amount":0, "skill":true, "style":"magic"})
	_log(_hero_name(unit.hero_id) + t(" 的", "'s ") + label + t("，目标格为空。", "; target tile was empty."))

func _combat_name(unit: Dictionary) -> String:
	var color := "#90c59e" if unit.team == "player" else "#d89a8f"
	return "[color=" + color + "]" + _hero_name(unit.hero_id) + "[/color]"

func _apply_all_lifesteal(unit: Dictionary, damage_dealt: float) -> void:
	var ratio := maxf(float(unit.get("all_lifesteal", 0.0)), float(unit.get("liushan_aura_lifesteal", 0.0)))
	if unit.team == "player" and _tianshu_enabled() and _tianshu_level("canyang") >= 2 and float(unit.hp) < float(unit.max_hp) * 0.5:
		ratio = maxf(ratio, 0.10)
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
	var wu_talent_level := _talent_level("wu", "同舟共济") if target.team == "player" else 0
	state.wu_equalize_used = true
	faction_battle_state[target.team] = state
	var total_hp := 0.0
	var total_max_hp := 0.0
	for ally in wu_allies:
		total_hp += maxf(0.0, float(ally.hp))
		total_max_hp += maxf(1.0, float(ally.max_hp))
	var shared_ratio := clampf(total_hp / maxf(1.0, total_max_hp), 0.0, 1.0)
	# 基础回复 3% 最大生命；天赋「同舟共济」1级 +2%、2级 +3%（满级共 6%）。
	var recovery_ratio := 0.03 + (0.02 if wu_talent_level == 1 else 0.03 if wu_talent_level >= 2 else 0.0)
	var recovery_percent := roundi(recovery_ratio * 100.0)
	var trigger_text := "生命低于 %d%%" % roundi(_tianshu_wu_equalize_threshold(target) * 100.0) if _tianshu_wu_equalize_threshold(target) > 0.0 else "濒死"
	# 8 人大羁绊发动横幅：全屏脉冲 + 中央飘字，随后全体吴将在同一时刻同时恢复。
	visual_events.append({"kind":"faction_bond", "team":target.team, "title":t("江东联动", "Jiangdong Bond"), "subtitle":t("吴国八人羁绊 · 全体回复 %d%% 最大生命" % recovery_percent, "Wu 8-Hero Bond · all recover %d%% max HP" % recovery_percent)})
	var bond_group: String = "wu_bond_" + str(target.team) + "_" + str(target.id)
	for ally in wu_allies:
		ally.hp = float(ally.max_hp) * shared_ratio
		# 羁绊回复为无归属治疗：不进入任何武将的治疗统计；重伤减疗仍按目标结算。
		var amount := float(ally.max_hp) * recovery_ratio * (1.0 - clampf(float(ally.get("grievous", 0.0)), 0.0, 0.95))
		var restored: float = minf(maxf(0.0, float(ally.max_hp) - float(ally.hp)), amount)
		ally.hp += restored
		if restored > 0.0:
			visual_events.append({"kind":"heal", "source_id":target.id, "target_id":ally.id, "amount":roundi(restored), "style":"heal", "nonblocking":true, "visual_group":bond_group, "group_style":"simultaneous"})
	_log("[color=#e58f78]【江东联动】%s触发：吴将均摊生命并各自恢复 %d%% 最大生命（每回合限一次）！[/color]" % [trigger_text, recovery_percent])
	return target.hp > 0.0

func _damage(source, target: Dictionary, amount: float, damage_type: String, label: String, visual_group := "", group_style := "", scales_with_skill := false, propagate_links := true, ignore_shield := false) -> float:
	if not target.alive: return 0.0
	if float(target.get("invulnerable_time", 0.0)) > 0.0: return 0.0
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
	var ambient_status_hit := group_style in ["burn_tick", "poison_tick", "fear_tick", "charm_forced"] or str(visual_group).begins_with("status_")
	var direct_tianshu_damage := source != null and not ambient_status_hit
	value *= 1.0 + float(target.get("vulnerable", 0.0))
	if source != null:
		value *= float(source.get("stat_mult", 1.0))
		if scales_with_skill: value *= _unit_skill_power_multiplier(source)
		value *= 1.0 + source.damage_buff + float(source.get("timed_damage_buff", 0.0)) + float(source.get("liushan_aura_damage_bonus", 0.0)) + float(source.get("kill_buff", 0.0))
		value *= 1.0 + float(source.get("endless_damage_pct", 0.0))
		value *= _endless_imprint_damage_multiplier(source, target, group_style)
		var crit_chance := clampf(_endless_imprint_value(source, "crit_chance_pct"), 0.0, 0.75)
		if crit_chance > 0.0 and rng.randf() < crit_chance:
			value *= 1.5 + _endless_imprint_value(source, "crit_damage_pct")
		if float(source.hp) / maxf(1.0, float(source.max_hp)) < 0.35:
			value *= 1.0 + float(source.get("endless_low_hp_damage", 0.0))
		value *= maxf(0.0, 1.0 - float(source.get("skill_debuff", 0.0)))
		if heroes[source.hero_id].f == "wei" and int(source.get("faction_tier", 0)) >= 3 and _has_any_debuff(target):
			value *= 1.08 + (0.04 * _talent_level("wei", "乘胜追击") if source.team == "player" else 0.0)
		value *= _tianshu_damage_multiplier(source, target, direct_tianshu_damage)
	var shatter_added := 0.0
	var freeze_shatter_source = null
	var freeze_remaining := float(target.get("freeze", 0.0))
	if freeze_remaining > 0.0:
		var shatter_damage := freeze_remaining * float(target.get("freeze_shatter_per_second", 0.0))
		if shatter_damage <= 0.0:
			shatter_damage = float(target.get("freeze_shatter_damage", 0.0))
		freeze_shatter_source = _find_by_id(combat_units, str(target.get("freeze_source_id", "")))
		target.freeze = 0.0
		target.freeze_shatter_damage = 0.0
		target.freeze_shatter_per_second = 0.0
		target.freeze_source_id = ""
		value += shatter_damage
		shatter_added = shatter_damage
		visual_events.append({"kind":"skill", "source_id":"" if freeze_shatter_source == null else freeze_shatter_source.id, "target_id":target.id, "amount":roundi(shatter_damage), "style":"magic"})
		if freeze_shatter_source != null:
			_log("[color=#7fb3ff]" + _hero_name(str(freeze_shatter_source.hero_id)) + t(" 的冰封提前破碎，追加 ", "'s freeze shatters early for ") + str(roundi(shatter_damage)) + t(" 点伤害。", " extra damage.") + "[/color]")
		else:
			_log(t("冰封提前破碎，追加 ", "Freeze shatters early for ") + str(roundi(shatter_damage)) + t(" 点伤害。", " extra damage."))
	var total_reduction: float = max(float(target.damage_reduction), float(target.get("timed_reduction", 0.0)))
	total_reduction = max(total_reduction, float(target.get("regen_damage_reduction", 0.0)))
	if source != null and int(source.row) == BOARD_ROWS - 1 and float(target.get("rear_damage_reduction_time", 0.0)) > 0.0:
		total_reduction += float(target.get("rear_damage_reduction", 0.0))
	if source != null and int(source.row) == 0 and float(target.get("front_damage_reduction_time", 0.0)) > 0.0:
		total_reduction += float(target.get("front_damage_reduction", 0.0))
	if target.hero_id == "sunce" and bool(target.get("sunce_daqiao", false)):
		var params: Dictionary = heroes.sunce.ability_params
		var missing_hp_reduction := _missing_hp_damage_multiplier(target, float(params.get("missing_hp_step", 0.10)), float(params.get("missing_hp_reduction_per_step", 0.03))) - 1.0
		total_reduction += missing_hp_reduction
	total_reduction += _tianshu_damage_reduction(target, source, direct_tianshu_damage)
	total_reduction += float(target.get("endless_damage_reduction", 0.0))
	value *= 1.0 - clampf(total_reduction, 0.0, 0.95)
	var faction_reduction := float(target.get("faction_damage_reduction", 0.0))
	if heroes[target.hero_id].f == "shu" and int(target.get("faction_tier", 0)) >= 3:
		var shu_stack_cap := 3 + (_talent_level("shu", "桃园同心") if target.team == "player" else 0)
		var shu_talent_level := _talent_level("shu", "桃园同心") if target.team == "player" else 0
		faction_reduction += (0.03 + 0.01 * shu_talent_level) * clampi(int(target.get("shu_damage_stacks", 0)), 0, shu_stack_cap)
	value *= 1.0 - clampf(faction_reduction, 0.0, 0.95)
	if damage_type == "magic" and float(target.get("strategy_mark", 0.0)) > 0.0 and source != null:
		value *= 1.30
		target.strategy_mark = 0.0
		visual_events.append({"kind":"skill", "source_id":source.id, "target_id":target.id, "amount":0, "style":"magic"})
		_log(t("谋略标记爆炸！", "Strategy mark detonates!"))
	if target.shield > 0 and not ignore_shield:
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
	if source != null: _credit_damage_buff_sources(source, actual_damage)
	if source != null and actual_damage > 0.0:
		var lifesteal := clampf(_endless_imprint_value(source, "lifesteal_pct"), 0.0, 0.75)
		if lifesteal > 0.0: _heal_unit_only(source, source, actual_damage * lifesteal)
	if shatter_added > 0.0 and actual_damage > 0.0 and freeze_shatter_source != null:
		# 破冰伤害计入冻结施放者名下,打破者只保留非破冰部分。
		var shatter_share := minf(shatter_added, actual_damage)
		if source != null: _add_stat(source, "damage", -shatter_share)
		_add_stat(freeze_shatter_source, "damage", shatter_share)
	if actual_damage > 0.0 and heroes[target.hero_id].f == "shu" and int(target.get("faction_tier", 0)) >= 3:
		var shu_stack_cap := 3 + (_talent_level("shu", "桃园同心") if target.team == "player" else 0)
		target.shu_damage_stacks = mini(shu_stack_cap, int(target.get("shu_damage_stacks", 0)) + 1)
		if float(target.get("shu_damage_decay_time", 0.0)) <= 0.0:
			target.shu_damage_decay_time = 3.0 + (_talent_level("shu", "桃园同心") if target.team == "player" else 0)
	if source != null: _apply_all_lifesteal(source, actual_damage)
	_tianshu_on_damage(source, target, actual_damage, direct_tianshu_damage)
	if propagate_links and actual_damage > 0.0: _propagate_pangtong_link(target, actual_damage, visual_group)
	var effect_style := "effect" if source == null else ("magic" if damage_type == "magic" else ("ranged" if int(heroes[source.hero_id].range) > 2 else "melee"))
	visual_events.append({"kind":"damage", "source_id":"" if source == null else source.id, "target_id":target.id, "team":target.team, "row":target.row, "col":target.col, "amount":round(value), "skill":true, "style":effect_style, "visual_group":visual_group, "group_style":group_style, "nonblocking":ambient_status_hit})
	var source_name := t("环境", "Effect") if source == null else _hero_name(source.hero_id)
	_log(source_name + t(" 对 ", " hits ") + _hero_name(target.hero_id) + t(" 造成 ", " for ") + str(round(value)) + t(" 伤害（", " damage (") + label + "）")
	var wu_equalize_threshold := _tianshu_wu_equalize_threshold(target)
	if target.hp > 0.0 and wu_equalize_threshold > 0.0 and float(target.hp) / maxf(1.0, float(target.max_hp)) < wu_equalize_threshold:
		if _try_wu_equalize_and_recover(target):
			return actual_damage
	if target.hp > 0.0:
		_endless_try_emergency_heal(target)
	if target.hp <= 0:
		if _tianshu_try_prevent_death(target):
			return actual_damage
		if float(target.get("death_prevention", 0.0)) > 0.0:
			target.hp = max(1.0, target.max_hp * 0.08)
			target.death_prevention = 0.0
			visual_events.append({"kind":"heal", "source_id":target.id, "target_id":target.id, "amount":round(target.hp)})
			_log("[color=#f6c860]" + _hero_name(target.hero_id) + t(" 触发羁绊免死！", " triggers a bond death ward!") + "[/color]")
			return actual_damage
		if _try_wu_equalize_and_recover(target):
			return actual_damage
		if target.hero_id == "zhangbao" and _resolve_zhangbao_death(target, source, visual_group, group_style):
			return actual_damage
		if _endless_try_revive(target):
			return actual_damage
		target.alive = false
		_on_unit_fallen(target, source)
		_apply_combo_bonds(false, false)
		_apply_faction_bonuses(false)
		if has_method("_refresh_bond_progress"):
			call("_refresh_bond_progress", combat_units.filter(func(unit): return unit.team == "player" and unit.alive and unit.row >= 0))
		visual_events.append({"kind":"death", "source_id":"" if source == null else source.id, "target_id":target.id, "amount":0, "visual_group":visual_group, "group_style":group_style})
		_log("[color=#df7878]" + _hero_name(target.hero_id) + t(" 阵亡！", " falls!") + "[/color]")
	return actual_damage

func _resolve_zhangbao_death(unit: Dictionary, killer, visual_group: String, group_style: String) -> bool:
	var params: Dictionary = heroes.zhangbao.ability_params
	var explosion_group := "zhangbao_death:" + str(unit.id) + ":" + str(unit.get("zhangbao_revives_used", 0))
	var targets: Array = []
	var target_row := _fallback_enemy_row(unit)
	for tile in _random_unique_enemy_tiles(unit, int(params.get("target_count", 2)), [target_row]):
		if tile.target == null:
			_hit_ruler(unit, _unit_skill_stat_value(unit) * float(params.get("death_mult", 2.0)), tile, t("地公雷爆空击", "Earth General Detonation missed"), explosion_group, "multi_target")
		else:
			targets.append(tile.target)
	var primary_ids := {}
	for target in targets: primary_ids[str(target.id)] = true
	for target in targets:
		_damage(unit, target, _unit_skill_stat_value(unit) * float(params.get("death_mult", 2.0)), "magic", t("地公雷爆", "Earth General Detonation"), explosion_group, "multi_target")
	if _pair_active(unit.team, "zhangbao", "zhangjiao"):
		var splash_targets: Array = []
		for primary in targets:
			for enemy in _enemy_units(unit.team):
				if not enemy.alive or primary_ids.has(str(enemy.id)) or splash_targets.has(enemy): continue
				if abs(int(enemy.row) - int(primary.row)) <= 1 and abs(int(enemy.col) - int(primary.col)) <= 1:
					splash_targets.append(enemy)
		for target in splash_targets:
			_damage(unit, target, _unit_skill_stat_value(unit) * float(params.get("zhangjiao_splash_mult", 0.90)), "magic", t("地公雷爆余波", "Detonation Shockwave"), explosion_group, "area_impact")
	var revive_limit := int(params.get("base_revives", 1))
	if _pair_active(unit.team, "zhangbao", "zhangliang"):
		revive_limit += int(params.get("zhangliang_bonus_revives", 1))
	if int(unit.get("zhangbao_revives_used", 0)) >= revive_limit:
		return false
	unit.zhangbao_revives_used = int(unit.get("zhangbao_revives_used", 0)) + 1
	unit.hp = float(unit.max_hp) * float(params.get("revive_hp_ratio", 0.50))
	unit.shield = 0.0
	unit.action = 0.0
	_clear_all_debuffs(unit)
	visual_events.append({"kind":"death", "source_id":"" if killer == null else killer.id, "target_id":unit.id, "amount":0, "visual_group":visual_group, "group_style":group_style})
	visual_events.append({"kind":"heal", "source_id":unit.id, "target_id":unit.id, "amount":roundi(unit.max_hp), "style":"heal", "nonblocking":true})
	_log("[color=#e8c75d]" + _hero_name("zhangbao") + t(" 引雷自爆后以50%最大生命复生！", " detonates and revives at 50% max HP!") + "[/color]")
	return true

func _on_unit_fallen(fallen: Dictionary, killer) -> void:
	_tianshu_on_kill(killer, fallen)
	var lord_level := _tianshu_level("wu_lord")
	if lord_level >= 1 and str(fallen.hero_id) != "sunquan":
		var sunquan = _combat_hero("player", "sunquan")
		if sunquan != null and sunquan.alive:
			var drain_ratio := 0.08 if lord_level == 1 else 0.15
			var drained := float(fallen.max_hp) * drain_ratio
			sunquan.max_hp = float(sunquan.max_hp) + drained
			if lord_level >= 2:
				sunquan.hp = minf(float(sunquan.max_hp), float(sunquan.hp) + drained)
			_log("[color=#e58f78]【坐断东南】%s 阵亡，孙权吸取 %.0f 最大生命。[/color]" % [_hero_name(str(fallen.hero_id)), drained])
	var zhangjiao = _combat_hero(str(fallen.team), "zhangjiao")
	var heaven_earth_active := _pair_active(str(fallen.team), "zhangjiao", "zhangbao") or str(fallen.hero_id) == "zhangbao"
	if zhangjiao != null and zhangjiao.alive and str(fallen.id) != str(zhangjiao.id) and heaven_earth_active:
		_cast_zhangjiao_death_thunder(zhangjiao, fallen)

func _hit_ruler(unit: Dictionary, amount: float, tile: Dictionary, label: String, visual_group := "", group_style := "", scales_with_skill := false) -> float:
	var value_float: float = amount * float(unit.get("stat_mult", 1.0)) * (1.0 + float(unit.damage_buff) + float(unit.get("timed_damage_buff", 0.0)) + float(unit.get("liushan_aura_damage_bonus", 0.0)) + float(unit.get("kill_buff", 0.0)))
	if scales_with_skill: value_float *= _unit_skill_power_multiplier(unit)
	value_float *= maxf(0.0, 1.0 - float(unit.get("skill_debuff", 0.0)))
	value_float *= _tianshu_ruler_damage_multiplier(unit)
	value_float *= 1.0 + float(unit.get("endless_damage_pct", 0.0))
	if float(unit.hp) / maxf(1.0, float(unit.max_hp)) < 0.35:
		value_float *= 1.0 + float(unit.get("endless_low_hp_damage", 0.0))
	if _run_is_endless():
		if unit.team == "enemy":
			value_float *= 1.0 + _endless_enemy_ruler_damage_bonus()
			value_float *= 1.0 - _endless_player_ruler_reduction()
	var target_team := _enemy_team_id(unit.team)
	var ability := str(heroes[unit.hero_id].get("ability", ""))
	if ability in ["strike_magic", "row_magic", "multi_magic", "control"]: value_float *= 1.0 - float(ruler_regen[target_team].get("magic_reduction", 0.0))
	var value: int = round(value_float)
	var before_ruler: int = enemy_ruler_hp if unit.team == "player" else player_ruler_hp
	if unit.team == "player": enemy_ruler_hp = max(0, enemy_ruler_hp - value)
	else: player_ruler_hp = max(0, player_ruler_hp - value)
	var after_ruler: int = enemy_ruler_hp if unit.team == "player" else player_ruler_hp
	if after_ruler <= 0 and battle_running:
		battle_running = false
		tick_timer.stop()
		call_deferred("_finish_battle")
	_add_stat(unit, "damage", float(before_ruler - after_ruler))
	_credit_damage_buff_sources(unit, float(before_ruler - after_ruler))
	_tianshu_on_ruler_hit(unit, tile)
	visual_events.append({"kind":"empty", "source_id":unit.id, "team":tile.team, "row":tile.row, "col":tile.col, "amount":value, "skill":true, "style":"ranged" if int(heroes[unit.hero_id].range) > 2 else "melee", "visual_group":visual_group, "group_style":group_style})
	_log(_hero_name(unit.hero_id) + t(" 攻击空格（", " targets an empty tile (") + label + t("），穿透命中主公 ", ") and hits the ruler for ") + str(value) + (t(" 点伤害。", ".") if language == "zh" else ""))
	return float(before_ruler - after_ruler)

func _targets_in_range(unit: Dictionary) -> Array:
	var rows := _attackable_rows(unit)
	return _enemy_units(unit.team).filter(func(enemy): return enemy.alive and float(enemy.get("stealth", 0.0)) <= 0.0 and rows.has(int(enemy.row)))

func _attackable_rows(unit: Dictionary) -> Array:
	var tier := int(heroes[unit.hero_id].range)
	var rows: Array = []
	if tier == 1:
		rows = [0]
	if tier == 2:
		if int(unit.row) <= 0: rows = [0, 1, 2]
		elif int(unit.row) == 1: rows = [0, 1]
		else: rows = [0]
	if tier >= 3:
		rows = [0, 1, 2]
	# 射程 1 在当前已开放排完全无人时逐排延伸；射程 2 的站位限制保持固定。
	while tier == 1 and rows.size() < BOARD_ROWS and not _enemy_units(unit.team).any(func(enemy): return enemy.alive and rows.has(int(enemy.row))):
		rows.append(int(rows.back()) + 1)
	return rows

func _team_units(team: String) -> Array:
	return combat_units.filter(func(unit): return unit.team == team)

func _enemy_units(team: String) -> Array:
	return combat_units.filter(func(unit): return unit.team != team)

func _has_winner() -> bool:
	return player_ruler_hp <= 0 or enemy_ruler_hp <= 0
