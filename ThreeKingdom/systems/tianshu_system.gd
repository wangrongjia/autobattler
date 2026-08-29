extends "res://ThreeKingdom/systems/progression_system.gd"

# 天书只在本局有效。独立的天书演武，以及所有难度的闯关均会启用本系统。
const TIANSHU_BOOKS := {
	"pojun":{"name":"破军天章", "en":"Army-Breaking Canon", "group":"通用·进攻", "effects":["所有我方武将兵略值 +16。", "所有我方武将兵略值 +32。"]},
	"fengchi":{"name":"风驰电掣", "en":"Lightning March", "group":"通用·进攻", "effects":["所有我方武将获得相当于原冷却减少 0.25 秒的冷却极速。", "等值提高至原冷却减少 0.5 秒的冷却极速。"]},
	"xianfa":{"name":"先发制人", "en":"First Strike", "group":"通用·进攻", "effects":["每场战斗开始时，所有我方武将行动条 +10。", "开场行动条加成提高至 +20。"]},
	"chengxu":{"name":"乘虚而入", "en":"Exploit Weakness", "group":"通用·进攻", "effects":["对带有任意减益或控制的敌人伤害提高 10%。", "伤害提高至 20%。"]},
	"canyang":{"name":"残阳血战", "en":"Last-Light Bloodbath", "group":"通用·进攻", "effects":["生命低于 50%时造成伤害提高 12%。", "增伤提高至 24%，并获得 10%全能吸血。"]},
	"zhanjiang":{"name":"斩将夺势", "en":"Slay and Seize", "group":"通用·进攻", "effects":["击杀后行动条 +15，每场最多 3 次。", "行动条 +25、击杀者本回合兵略 +30，每场最多 5 次。"]},
	"tianbing":{"name":"天兵赐力", "en":"Celestial Vigor", "group":"通用·生存", "effects":["所有我方武将最大生命提高 6%。", "最大生命提高至 12%。"]},
	"tiebi":{"name":"铁壁金书", "en":"Golden Bulwark", "group":"通用·生存", "effects":["所有我方武将受到伤害降低 5%。", "减伤提高至 10%。"]},
	"huichun":{"name":"回春真诀", "en":"Rejuvenation Art", "group":"通用·生存", "effects":["我方武将每 2 秒恢复 0.8%最大生命。", "每 2 秒恢复 1.6%最大生命。"]},
	"jinchan":{"name":"金蝉脱壳", "en":"Golden Cicada", "group":"通用·生存", "effects":["每场第一名受到致命伤害的友军免死并恢复 15%最大生命。", "恢复提高至 30%，同时清除全部减益。"]},
	"zebe":{"name":"泽被苍生", "en":"Grace to All", "group":"通用·生存", "effects":["溢出治疗按 50%治疗我方主公。", "转化比例提高至 80%。"]},
	"shoutu":{"name":"守土有责", "en":"Defend the Realm", "group":"通用·生存", "effects":["敌军攻击空格时，对我方主公伤害降低 15%。", "降低 30%，且主公每回合开始恢复 3%最大生命。"]},
	"yuzhan":{"name":"愈战愈勇", "en":"Battle-Hardened", "group":"通用·成长", "effects":["武将每存活通过一回合，生命 +200、兵略 +8，最多 2 层。", "每层提高至生命 +400、兵略 +16，最多 3 层。"]},
	"fengshi":{"name":"锋矢兵书", "en":"Arrowhead Manual", "group":"通用·阵型", "effects":["前军最大生命 +10%，造成伤害 +8%。", "提高至生命 +20%、伤害 +16%。"]},
	"zhongliu":{"name":"中流砥柱", "en":"Pillar of the Line", "group":"通用·阵型", "effects":["中军兵略 +16，受到控制时间降低 15%。", "兵略 +32，控制时间降低 30%。"]},
	"yanxing":{"name":"雁行秘卷", "en":"Wild-Goose Scroll", "group":"通用·阵型", "effects":["后军兵略 +20，受到直接伤害降低 8%。", "兵略 +40，直接减伤 16%。"]},
	"tonglie":{"name":"同列并进", "en":"Advance in Columns", "group":"通用·阵型", "effects":["同列至少 2 名友军时，该列生命和兵略提高 6%。", "提高至 12%，且开场行动条 +10。"]},
	"qunce":{"name":"群策群力", "en":"United Counsel", "group":"通用·阵型", "effects":["每个不同阵营使全体兵略 +8、最大生命 +2%。", "每阵营提高至兵略 +16、最大生命 +4%。"]},
	"taozhu_yice":{"name":"陶朱遗策", "en":"Legacy of Tao Zhu", "group":"通用·经济", "effects":["立即获得 300 金币。", "立即获得 600 金币。"]},
	"tuntian_kaifu":{"name":"屯田开府", "en":"Agrarian Treasury", "group":"通用·经济", "effects":["每回合基础收入 +50。", "每回合基础收入 +100。"]},
	"fujia_tianxia":{"name":"富甲天下", "en":"Wealth Under Heaven", "group":"通用·经济", "effects":["利息上限 +20。", "利息上限 +40，且每回合基础收入 +20。"]},
	"huozhi_milu":{"name":"货殖秘录", "en":"Merchant's Ledger", "group":"通用·经济", "effects":["卖出任意武将时，额外获得 30 金币。", "卖出任意武将时，额外获得 80 金币。"]},
	"jungong_juezhi":{"name":"军功爵制", "en":"Military Merit", "group":"通用·经济", "effects":["我方每击杀一名敌将，立即获得 40 金币。", "每次击杀获得 80 金币，且击杀者本回合兵略 +20。"]},
	"mage_guoshi":{"name":"马革裹尸", "en":"Shrouded in Horsehide", "group":"通用·经济", "effects":["我方武将每阵亡一名，立即获得 40 金币。", "每次阵亡获得 90 金币。"]},
	"maidu_huanzhu":{"name":"买椟还珠", "en":"Keep the Casket", "group":"通用·经济", "effects":["天书替换费用降低 80（降至 220）。", "天书替换费用降低 200（降至 100）。"]},
	"shu_talents":{"name":"西川英杰录", "en":"Shu Talents", "group":"蜀", "faction":"shu", "effects":["立即随机获得 2 名蜀阵营武将加入备战席。", "立即随机获得 3 名蜀阵营武将加入备战席。"]},
	"wei_talents":{"name":"中原英才志", "en":"Wei Talents", "group":"魏", "faction":"wei", "effects":["立即随机获得 2 名魏阵营武将加入备战席。", "立即随机获得 3 名魏阵营武将加入备战席。"]},
	"wu_talents":{"name":"江东英杰传", "en":"Wu Talents", "group":"吴", "faction":"wu", "effects":["立即随机获得 2 名吴阵营武将加入备战席。", "立即随机获得 3 名吴阵营武将加入备战席。"]},
	"qun_talents":{"name":"乱世豪杰谱", "en":"Qun Talents", "group":"群", "faction":"qun", "effects":["立即随机获得 2 名群阵营武将加入备战席。", "立即随机获得 3 名群阵营武将加入备战席。"]},
	"shu_lord":{"name":"汉昭烈帝", "en":"Emperor Zhaolie", "group":"蜀", "faction":"shu", "lord":"liubei", "effects":["仁德回春的治疗目标数 +1；刘备最大生命 +2000。", "治疗目标数 +1；被治疗的蜀国武将在治疗期间免疫所有伤害；刘备最大生命再 +5000。"]},
	"wei_lord":{"name":"魏武挥鞭", "en":"Wei Whip", "group":"魏", "faction":"wei", "lord":"caocao", "effects":["曹操施放技能后，全体魏将伤害提高 15%，持续 5 秒；曹操最大生命 +2000。", "增伤提高至 25% 持续 6 秒，且施放时全体魏将行动条 +10；曹操最大生命再 +5000。"]},
	"wu_lord":{"name":"坐断东南", "en":"Throne of the Southeast", "group":"吴", "faction":"wu", "lord":"sunquan", "effects":["任意武将阵亡时，孙权吸取其 8% 最大生命转化为自身最大生命（无上限）；孙权最大生命 +2000。", "吸取提高至 15%，且当前生命同步增加吸收值；孙权最大生命再 +5000。"]},
	"qun_lord":{"name":"金吾飞将", "en":"Golden Wings", "group":"群", "faction":"qun", "lord":"lvbu", "effects":["无双横扫改为攻击正前方及其左右各 2 格（最多前排 5 格）；吕布最大生命 +2000。", "额外覆盖正前方整列与中排左右格（站前排正中共 9 格）；吕布最大生命再 +5000。"]},
	"shu_jianbi":{"name":"汉室坚壁", "en":"Han Bulwark", "group":"蜀", "faction":"shu", "effects":["蜀将受到伤害降低 5%。", "减伤提高至 10%。"]},
	"shu_rende":{"name":"仁德遗泽", "en":"Legacy of Benevolence", "group":"蜀", "faction":"shu", "effects":["蜀将治疗提高 20%；溢出治疗的 30%转化为护盾。", "治疗提高 40%，护盾转化提高至 60%。"]},
	"shu_beifa":{"name":"北伐不息", "en":"Endless Northern March", "group":"蜀", "faction":"shu", "effects":["蜀将每次施法，本回合兵略 +10，最多 3 层。", "每次 +20，最多 5 层。"]},
	"shu_shudao":{"name":"蜀道天险", "en":"Perilous Shu Roads", "group":"蜀", "faction":"shu", "effects":["蜀国前军最大生命 +15%，受控时间降低 20%。", "生命 +30%，受控时间降低 40%。"]},
	"shu_wuhu":{"name":"五虎余烈", "en":"Five Tigers' Legacy", "group":"蜀", "faction":"shu", "effects":["蜀将首次伤害技能额外造成 100%兵略值伤害。", "额外伤害提高至 200%，命中后行动条 +10。"]},
	"wei_haoling":{"name":"魏武号令", "en":"Wei Command", "group":"魏", "faction":"wei", "effects":["魏将首次施法使命中目标兵略降低 10%，持续 5 秒。", "降低 20%，持续 8 秒。"]},
	"wei_faling":{"name":"法令森严", "en":"Strict Decree", "group":"魏", "faction":"wei", "effects":["魏将施加的眩晕、冻结、恐惧、魅惑延长 15%。", "延长 30%。"]},
	"wei_chengsheng":{"name":"乘胜穷追", "en":"Relentless Pursuit", "group":"魏", "faction":"wei", "effects":["魏将对带减益敌人伤害提高 12%。", "提高 24%，命中时额外压退 5 点行动条。"]},
	"wei_hubao":{"name":"虎豹争先", "en":"Tiger-Leopard Vanguard", "group":"魏", "faction":"wei", "effects":["开战时魏将行动条 +15。", "行动条 +30，前 5 秒造成伤害提高 10%。"]},
	"wei_tuntian":{"name":"屯田固本", "en":"Agrarian Foundation", "group":"魏", "faction":"wei", "effects":["回合结束每名存活魏将为主公恢复 0.4%最大生命，最多 8 名。", "每名恢复 0.8%，并使存活魏将恢复 5%最大生命。"]},
	"wu_wotu":{"name":"江东沃土", "en":"Jiangdong Heartland", "group":"吴", "faction":"wu", "effects":["吴将最大生命提高 6%。", "提高至 12%。"]},
	"wu_huoshao":{"name":"火烧连营", "en":"Burning Camps", "group":"吴", "faction":"wu", "effects":["吴将直接技能伤害附加 3 秒灼烧，每秒 20%兵略值，不叠加。", "每秒 40%兵略值，持续 4 秒。"]},
	"wu_tongzhou":{"name":"同舟共命", "en":"Shared Fate", "group":"吴", "faction":"wu", "effects":["吴 8 人羁绊的生命均摊改为任一吴将低于 10%生命时触发。", "触发阈值提高至低于 30%生命。"]},
	"wu_zhiheng":{"name":"制衡之术", "en":"Art of Balance", "group":"吴", "faction":"wu", "effects":["每 5 秒，行动条最高和最低的吴将归于平均后都增加 15。", "归于平均后都增加 30，且二者获得 5 秒 10%增伤。"]},
	"wu_yinghao":{"name":"江表英豪", "en":"Heroes of Jiangbiao", "group":"吴", "faction":"wu", "effects":["每名吴将首次施法获得 6%最大生命护盾。", "护盾提高至 12%，护盾存在时兵略 +50。"]},
	"qun_jishu":{"name":"乱世疾书", "en":"Chaotic Age Codex", "group":"群", "faction":"qun", "effects":["群将获得相当于原冷却减少 0.35 秒的冷却极速。", "等值提高至原冷却减少 0.7 秒的冷却极速。"]},
	"qun_wushuang":{"name":"无双战意", "en":"Peerless Will", "group":"群", "faction":"qun", "effects":["群将每损失 10%生命，兵略 +6。", "每层兵略 +12，并获得 1%减伤。"]},
	"qun_huangtian":{"name":"黄天雷契", "en":"Yellow Heaven Pact", "group":"群", "faction":"qun", "effects":["群将累计施法 5 次后，雷击 2 个随机敌方格，造成 200%平均兵略伤害。", "每 4 次触发，雷击 3 格造成 200%平均兵略伤害，并有 20%概率眩晕 1 秒。"]},
	"qun_xiaoxiong":{"name":"枭雄并起", "en":"Rival Warlords", "group":"群", "faction":"qun", "effects":["每名上阵群将使全体群将兵略 +4，最多计入 8 名。", "每名群将提高至兵略 +8，最多计入 8 名。"]},
	"qun_yujin":{"name":"余烬燎原", "en":"Embers Rekindled", "group":"群", "faction":"qun", "effects":["我方群将阵亡时，存活群将行动条 +10、本场兵略 +6，最多触发 3 次。", "行动条提高至 +20、本场兵略 +12，最多触发 5 次。"]},
	"pool_shu":{"name":"蜀汉求贤令", "en":"Shu Recruitment Edict", "group":"武将池", "pool":["shu"], "effects":["下两次选将只出现蜀将。", "下四次选将只出现蜀将；每个候选位额外刷新1次。"]},
	"pool_wei":{"name":"魏庭求贤令", "en":"Wei Recruitment Edict", "group":"武将池", "pool":["wei"], "effects":["下两次选将只出现魏将。", "下四次选将只出现魏将；每个候选位额外刷新1次。"]},
	"pool_wu":{"name":"江东求贤令", "en":"Wu Recruitment Edict", "group":"武将池", "pool":["wu"], "effects":["下两次选将只出现吴将。", "下四次选将只出现吴将；每个候选位额外刷新1次。"]},
	"pool_qun":{"name":"群雄求贤令", "en":"Qun Recruitment Edict", "group":"武将池", "pool":["qun"], "effects":["下两次选将只出现群将。", "下四次选将只出现群将；每个候选位额外刷新1次。"]}
}

var tianshu_levels := {}
var tianshu_choices: Array[String] = []
var tianshu_refresh_available: Array[bool] = [true, true, true]
var tianshu_pool_effect := {}
var tianshu_battle_state := {}
var tianshu_draft_refresh_used: Array[int] = [0, 0, 0]
var tianshu_draws_remaining := 0
var tianshu_return_phase := "draft"
var tianshu_draw_reason := ""
var tianshu_generate_draft_on_finish := false

func _tianshu_enabled() -> bool:
	# 新手引导也启用天书：演练关第 1 回合免费三选一，现场教学选书。
	return game_mode == "tianshu" or game_mode == "challenge" or game_mode == "tutorial"

func _reset_tianshu_run() -> void:
	tianshu_levels.clear()
	tianshu_choices.clear()
	tianshu_pool_effect.clear()
	tianshu_battle_state.clear()
	tianshu_refresh_available = [true, true, true]
	tianshu_draft_refresh_used = [0, 0, 0]
	tianshu_draws_remaining = 0
	tianshu_return_phase = "draft"
	tianshu_draw_reason = ""
	tianshu_generate_draft_on_finish = false

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

func _tianshu_book_faction(book: Dictionary) -> String:
	if book.has("faction"): return str(book.faction)
	if book.has("pool") and not Array(book.pool).is_empty(): return str(Array(book.pool)[0])
	return ""

func _tianshu_lord_requirement_met(book_id: String, book: Dictionary) -> bool:
	# 君主书出现前提：一级需≥2本本阵营天书；升级二级需≥2本二级本阵营天书。
	# 君主书互斥：已持有任意君主书时，其他君主书不再出现。
	if not book.has("lord"): return true
	for raw_book_id in tianshu_levels:
		var other: Dictionary = TIANSHU_BOOKS.get(str(raw_book_id), {})
		if other.has("lord") and str(raw_book_id) != book_id:
			return false
	var faction := str(book.faction)
	var owned := 0
	var owned_max := 0
	for raw_book_id in tianshu_levels:
		var other: Dictionary = TIANSHU_BOOKS.get(str(raw_book_id), {})
		if str(other.get("faction", "")) != faction or other.has("lord"): continue
		owned += 1
		if _tianshu_level(str(raw_book_id)) >= 2: owned_max += 1
	return owned_max >= 2 if _tianshu_level(book_id) >= 1 else owned >= 2

func _tianshu_group_tag(book: Dictionary) -> String:
	# 天书抬头：阵营书 / 君主书在阵营名后追加类型标识；通用与武将池沿用原分组名。
	var group := str(book.get("group", ""))
	if book.has("lord"): return group + " · 君主"
	if book.has("faction"): return group + " · 阵营"
	return group

func _tianshu_lord_requirement_note(book: Dictionary) -> String:
	# 君主天书限制说明：图鉴、选书三选一与持有列表共用（非君主书返回空）。
	if not book.has("lord"): return ""
	var faction := str(book.get("group", ""))
	var lord_name := _hero_name(str(book.lord))
	var lines := [
		"⚠ 君主天书 · 限制条件",
		"· 需已选 2 本%s阵营天书，才会在三选一出现" % faction,
		"· 需已选 2 本 2级%s阵营天书，才会出现升至 2 级" % faction,
		"· 每局仅可持有 1 本君主天书：选定后不再刷出其他阵营的君主天书",
		"· %s 上场后场上仅保留一名（生命最高），备战席可存多名" % lord_name,
	]
	return "\n".join(lines)

func _tianshu_candidates_for_slot(index: int, excluded: Array) -> Array:
	return TIANSHU_BOOKS.keys().filter(func(raw_book_id):
		var book_id := str(raw_book_id)
		if _tianshu_level(book_id) >= 2 or excluded.has(book_id): return false
		var book: Dictionary = TIANSHU_BOOKS[book_id]
		if not _tianshu_lord_requirement_met(book_id, book): return false
		# 出战阵营限定:限定时阵营书(含求贤令/君主书)只刷所选阵营,通用书不受影响。
		var book_faction := _tianshu_book_faction(book)
		if not player_factions.is_empty() and not book_faction.is_empty() and not player_factions.has(book_faction): return false
		var is_common := book_faction.is_empty()
		return is_common if index == 0 else not is_common
	)

func _generate_tianshu_choices() -> void:
	tianshu_choices.clear()
	for index in 3:
		var pool := _tianshu_candidates_for_slot(index, tianshu_choices)
		if pool.is_empty(): break
		pool.shuffle()
		tianshu_choices.append(str(pool[0]))
	tianshu_refresh_available = [true, true, true]

func _begin_tianshu_draw(count: int, reason: String, return_phase: String, generate_draft_on_finish: bool) -> void:
	tianshu_draws_remaining = maxi(1, count)
	tianshu_draw_reason = reason
	tianshu_return_phase = return_phase if return_phase in ["draft", "placement"] else "draft"
	tianshu_generate_draft_on_finish = generate_draft_on_finish
	phase = "tianshu"
	draft_user_hidden = true
	_generate_tianshu_choices()

func _refresh_tianshu_choice(index: int) -> void:
	if phase != "tianshu" or index < 0 or index >= tianshu_choices.size(): return
	if not tianshu_infinite_refresh:
		if index >= tianshu_refresh_available.size() or not tianshu_refresh_available[index]: return
	var previous := str(tianshu_choices[index])
	var excluded := tianshu_choices.duplicate()
	var pool := _tianshu_candidates_for_slot(index, excluded)
	pool = pool.filter(func(book_id): return str(book_id) != previous)
	if pool.is_empty(): return
	pool.shuffle()
	tianshu_choices[index] = str(pool[0])
	if not tianshu_infinite_refresh:
		tianshu_refresh_available[index] = false
	_render()

func _choose_tianshu(book_id: String) -> void:
	if phase != "tianshu" or not tianshu_choices.has(book_id): return
	var old_level := _tianshu_level(book_id)
	var new_level := mini(2, _tianshu_level(book_id) + 1)
	tianshu_levels[book_id] = new_level
	var book: Dictionary = TIANSHU_BOOKS[book_id]
	if book.has("pool"):
		# 单阵营求贤令：不限定回合，纯按次数生效（一级 2 次、二级 4 次）。
		# 双阵营盟书：维持回合内次数制（一级本回合 2 次、二级跨下一回合 3 次）。
		var single_pool := Array(book.pool).size() == 1
		var pool_end := 9999 if single_pool else round_number + (1 if new_level >= 2 else 0)
		var pool_picks := (4 if new_level >= 2 else 2) if single_pool else (3 if new_level >= 2 else 2)
		tianshu_pool_effect = {"book_id":book_id, "factions":Array(book.pool).duplicate(), "end_round":pool_end, "remaining_picks":pool_picks, "level":new_level}
	_log("[color=#e5a8ff]【天书·%s %s】%s[/color]" % [_tianshu_name(book_id), "2级" if new_level == 2 else "1级", _tianshu_effect_text(book_id, new_level)])
	_play_sfx("tianshu", -5.0, 100, 0.0) # 选定天书:落卷声
	_apply_tianshu_acquisition_effect(book_id, old_level, new_level)
	tianshu_draws_remaining = maxi(0, tianshu_draws_remaining - 1)
	if tianshu_draws_remaining > 0:
		_generate_tianshu_choices()
		_render()
		return
	phase = tianshu_return_phase
	draft_user_hidden = false
	if phase == "draft" and (tianshu_generate_draft_on_finish or choices.size() != DRAFT_SIZE or book.has("pool")):
		call("_generate_choices")
	tianshu_draw_reason = ""
	tianshu_generate_draft_on_finish = false
	_render()

func _apply_tianshu_acquisition_effect(book_id: String, old_level: int, new_level: int) -> void:
	if book_id == "taozhu_yice" and new_level > old_level and has_method("_earn_gold"):
		call("_earn_gold", 300 if new_level == 1 else 600, "天书·陶朱遗策")
	var talent_books := {"shu_talents":"shu", "wei_talents":"wei", "wu_talents":"wu", "qun_talents":"qun"}
	if talent_books.has(book_id) and new_level > old_level:
		_recruit_faction_heroes(str(talent_books[book_id]), 2 if new_level == 1 else 3)
	var lord_book: Dictionary = TIANSHU_BOOKS.get(book_id, {})
	if lord_book.has("lord") and new_level > old_level:
		var lord_hp := 2000.0 if new_level == 1 else 5000.0
		_apply_lord_book_bonus(str(lord_book.lord), lord_hp)

func _apply_lord_book_bonus(lord_id: String, hp_bonus: float) -> void:
	# 君主书保底：场上同名君主去重（保留血量最高的一个），备战席可存多个，全部提升生命。
	var hero_template: Dictionary = heroes.get(lord_id, {})
	if hero_template.is_empty(): return
	hero_template.hp = int(float(hero_template.hp) + hp_bonus)
	# 场上去重：只保留血量最高的一个，移除多余的
	var keep = null
	for unit in player_units:
		if str(unit.hero_id) != lord_id or int(unit.row) < 0: continue
		if keep == null or float(unit.hp) > float(keep.hp):
			keep = unit
	if keep != null:
		for unit in player_units.duplicate():
			if str(unit.hero_id) == lord_id and int(unit.row) >= 0 and unit != keep:
				player_units.erase(unit)
				_log("[color=#e5a8ff]【君主天书】移除了场上多余的%s。[/color]" % _hero_name(lord_id))
	# 所有该君主（含备战席）生命提升
	for unit in player_units:
		if str(unit.hero_id) != lord_id: continue
		unit.max_hp = float(unit.max_hp) + hp_bonus
		unit.hp = minf(float(unit.max_hp), float(unit.hp) + hp_bonus)
	_log("[color=#e5a8ff]【君主天书】%s 最大生命 +%.0f。[/color]" % [_hero_name(lord_id), hp_bonus])

func _recruit_faction_heroes(faction: String, count: int) -> void:
	var pool: Array = heroes.keys().filter(func(id): return str(heroes[id].f) == faction)
	pool.shuffle()
	var picked: Array = pool.slice(0, mini(count, pool.size()))
	for hero_id in picked:
		player_units.append(_make_roster_unit("player", str(hero_id)))
	if not picked.is_empty():
		_log("[color=#e5a8ff]【天书】随机获得 %d 名%s阵营武将加入备战席。[/color]" % [picked.size(), _faction_name(faction)])

func _active_tianshu_pool_factions() -> Array:
	if tianshu_pool_effect.is_empty() or int(tianshu_pool_effect.get("remaining_picks", 0)) <= 0 or round_number > int(tianshu_pool_effect.get("end_round", 0)):
		return []
	var factions := Array(tianshu_pool_effect.get("factions", []))
	# 出战阵营限定:求贤令阵营需在所选阵营内(防御旧存档,正常情况下非所选阵营求贤令不会出现)。
	if not player_factions.is_empty():
		factions = factions.filter(func(faction): return player_factions.has(str(faction)))
	return factions

func _tianshu_consume_pool_pick() -> void:
	if _active_tianshu_pool_factions().is_empty(): return
	tianshu_pool_effect.remaining_picks = maxi(0, int(tianshu_pool_effect.get("remaining_picks", 0)) - 1)
	if int(tianshu_pool_effect.remaining_picks) <= 0: tianshu_pool_effect.clear()

func _tianshu_draft_refresh_limit() -> int:
	if tianshu_pool_effect.is_empty(): return 1
	var factions := _active_tianshu_pool_factions()
	return 2 if factions.size() == 1 and int(tianshu_pool_effect.get("level", 0)) >= 2 else 1

func _tianshu_can_refresh_draft(index: int) -> bool:
	return index >= 0 and index < tianshu_draft_refresh_used.size() and tianshu_draft_refresh_used[index] < _tianshu_draft_refresh_limit()

func _tianshu_save_state() -> Dictionary:
	return {
		"levels":tianshu_levels, "choices":tianshu_choices, "refresh":tianshu_refresh_available,
		"pool":tianshu_pool_effect, "battle":tianshu_battle_state,
		"draft_refresh_used":tianshu_draft_refresh_used,
		"draws_remaining":tianshu_draws_remaining, "return_phase":tianshu_return_phase,
		"draw_reason":tianshu_draw_reason, "generate_draft_on_finish":tianshu_generate_draft_on_finish
	}

func _load_tianshu_state(value) -> void:
	_reset_tianshu_run()
	if not value is Dictionary: return
	var loaded_levels: Dictionary = Dictionary(value.get("levels", {}))
	for raw_book_id in loaded_levels:
		var book_id := str(raw_book_id)
		if TIANSHU_BOOKS.has(book_id):
			tianshu_levels[book_id] = clampi(int(loaded_levels[raw_book_id]), 1, 2)
	tianshu_choices.clear()
	for book_id in value.get("choices", []):
		if TIANSHU_BOOKS.has(str(book_id)): tianshu_choices.append(str(book_id))
	tianshu_refresh_available.assign(value.get("refresh", [true, true, true]))
	var loaded_pool := Dictionary(value.get("pool", {})).duplicate(true)
	var loaded_pool_id := str(loaded_pool.get("book_id", ""))
	if TIANSHU_BOOKS.has(loaded_pool_id) and TIANSHU_BOOKS[loaded_pool_id].has("pool"):
		if not loaded_pool.has("remaining_picks"): loaded_pool.remaining_picks = 3 if int(loaded_pool.get("level", 1)) >= 2 else 2
		tianshu_pool_effect = loaded_pool
	tianshu_battle_state = Dictionary(value.get("battle", {})).duplicate(true)
	tianshu_draft_refresh_used.assign(value.get("draft_refresh_used", [0, 0, 0]))
	tianshu_draws_remaining = maxi(0, int(value.get("draws_remaining", 1 if not tianshu_choices.is_empty() else 0)))
	tianshu_return_phase = str(value.get("return_phase", "draft"))
	if tianshu_return_phase not in ["draft", "placement"]: tianshu_return_phase = "draft"
	tianshu_draw_reason = str(value.get("draw_reason", "free"))
	tianshu_generate_draft_on_finish = bool(value.get("generate_draft_on_finish", phase == "tianshu"))

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
	if _tianshu_level("tianbing") > 0: hp_multiplier += 0.06 * _tianshu_level("tianbing")
	if _tianshu_level("pojun") > 0: strategy_flat += 16.0 * _tianshu_level("pojun")
	if _tianshu_level("fengshi") > 0 and int(hero.range) == 1: hp_multiplier += 0.10 * _tianshu_level("fengshi")
	if _tianshu_level("zhongliu") > 0 and int(hero.range) == 2: strategy_flat += 16.0 * _tianshu_level("zhongliu")
	if _tianshu_level("yanxing") > 0 and int(hero.range) >= 3: strategy_flat += 20.0 * _tianshu_level("yanxing")
	if _tianshu_level("tonglie") > 0 and _tianshu_column_has_pair(unit):
		hp_multiplier += 0.06 * _tianshu_level("tonglie")
		strategy_multiplier += 0.06 * _tianshu_level("tonglie")
	var faction_count := _tianshu_deployed_faction_count()
	if _tianshu_level("qunce") > 0:
		hp_multiplier += 0.02 * _tianshu_level("qunce") * faction_count
		strategy_flat += 8.0 * _tianshu_level("qunce") * faction_count
	if faction == "shu" and _tianshu_level("shu_shudao") > 0 and int(hero.range) == 1: hp_multiplier += 0.15 * _tianshu_level("shu_shudao")
	if faction == "wu" and _tianshu_level("wu_wotu") > 0: hp_multiplier += 0.06 * _tianshu_level("wu_wotu")
	if faction == "qun" and _tianshu_level("qun_xiaoxiong") > 0:
		var qun_count := mini(8, Array(combat_units).filter(func(ally): return ally.team == "player" and ally.alive and str(heroes[ally.hero_id].f) == "qun").size())
		strategy_flat += 4.0 * _tianshu_level("qun_xiaoxiong") * qun_count
	var growth_cap := 3 if _tianshu_level("yuzhan") >= 2 else 2
	var growth_stacks := mini(growth_cap, int(unit.get("tianshu_growth_stacks", 0)))
	if _tianshu_level("yuzhan") > 0 and growth_stacks > 0:
		hp_flat += 200.0 * _tianshu_level("yuzhan") * growth_stacks
		strategy_flat += 8.0 * _tianshu_level("yuzhan") * growth_stacks
	var old_bonus := float(unit.get("tianshu_max_hp_bonus", 0.0))
	var base_max := maxf(1.0, float(unit.max_hp) - old_bonus)
	var hp_ratio := float(unit.hp) / maxf(1.0, float(unit.max_hp))
	var new_max := base_max * hp_multiplier + hp_flat
	unit.tianshu_max_hp_bonus = new_max - base_max
	unit.max_hp = new_max
	unit.hp = clampf(new_max * hp_ratio, 0.0, new_max)
	unit.tianshu_strategy_bonus = strategy_flat
	unit.tianshu_strategy_multiplier = strategy_multiplier
	var equivalent_seconds := 0.25 * _tianshu_level("fengchi")
	if faction == "qun": equivalent_seconds += 0.35 * _tianshu_level("qun_jishu")
	var base_cooldown := float(heroes[unit.hero_id].cooldown)
	unit.tianshu_cooldown_haste = equivalent_seconds / base_cooldown * 100.0 if base_cooldown > 0.05 else 0.0

func _apply_tianshu_battle_start() -> void:
	if not _tianshu_enabled(): return
	tianshu_battle_state = {"jinchan_used":false, "wu_balance_clock":0.0, "qun_casts":0, "qun_fallen_triggers":0}
	for unit in combat_units:
		if unit.team != "player": continue
		unit.tianshu_kills = 0
		unit.tianshu_kill_strategy_bonus = 0.0
		unit.tianshu_qun_fallen_strategy_bonus = 0.0
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
	var result := float(unit.get("tianshu_strategy_bonus", 0.0)) + float(unit.get("tianshu_kill_strategy_bonus", 0.0)) + float(unit.get("tianshu_qun_fallen_strategy_bonus", 0.0))
	var faction := str(heroes[unit.hero_id].f)
	if faction == "shu" and _tianshu_level("shu_beifa") > 0:
		result += float(unit.get("tianshu_shu_cast_stacks", 0)) * 10.0 * float(_tianshu_level("shu_beifa"))
	if faction == "qun" and _tianshu_level("qun_wushuang") > 0:
		var missing_steps := floori((1.0 - float(unit.hp) / maxf(1.0, float(unit.max_hp))) / 0.10 + 0.0001)
		result += missing_steps * 6.0 * _tianshu_level("qun_wushuang")
	if faction == "wu" and _tianshu_level("wu_yinghao") >= 2 and float(unit.get("shield", 0.0)) > 0.0: result += 50.0
	return result

func _tianshu_strategy_multiplier(unit: Dictionary) -> float:
	return float(unit.get("tianshu_strategy_multiplier", 1.0)) if unit.team == "player" and _tianshu_enabled() else 1.0

func _tianshu_cooldown_haste(unit: Dictionary) -> float:
	return float(unit.get("tianshu_cooldown_haste", 0.0)) if unit.team == "player" and _tianshu_enabled() else 0.0

func _tianshu_control_source_multiplier(unit: Dictionary) -> float:
	if not _tianshu_enabled() or unit.team != "player": return 1.0
	var result := 1.0
	if _tianshu_has_faction(unit, "wei") and _tianshu_level("wei_faling") > 0: result *= 1.0 + 0.15 * _tianshu_level("wei_faling")
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

func _tianshu_on_overflow(source: Dictionary, target, overflow: float, visual_kind := "heal", nonblocking := true) -> float:
	if overflow <= 0.0 or source == null: return 0.0
	var conversion_ratio := 0.30
	if source.team == "player" and _tianshu_enabled() and _tianshu_level("zebe") > 0:
		conversion_ratio = 0.50 if _tianshu_level("zebe") == 1 else 0.80
	var ruler_max := _player_ruler_max_hp() if source.team == "player" else RULER_MAX_HP
	var ruler_hp := player_ruler_hp if source.team == "player" else enemy_ruler_hp
	var restored := minf(overflow * conversion_ratio, float(ruler_max - ruler_hp))
	if source.team == "player": player_ruler_hp += roundi(restored)
	else: enemy_ruler_hp += roundi(restored)
	if restored > 0.0:
		visual_events.append({"kind":visual_kind, "source_id":source.id, "target_id":"", "team":source.team, "row":-1, "col":-1, "amount":round(restored), "ruler":true, "style":"heal", "nonblocking":nonblocking})
	if target != null and _tianshu_enabled() and _tianshu_has_faction(source, "shu") and _tianshu_level("shu_rende") > 0:
		call("_grant_shield", target, overflow * 0.30 * _tianshu_level("shu_rende"))
	return restored

func _tianshu_try_prevent_death(target: Dictionary) -> bool:
	if target.team != "player" or not _tianshu_enabled(): return false
	if _tianshu_level("jinchan") > 0 and not bool(tianshu_battle_state.get("jinchan_used", false)):
		tianshu_battle_state.jinchan_used = true
		target.hp = float(target.max_hp) * (0.15 if _tianshu_level("jinchan") == 1 else 0.30)
		if _tianshu_level("jinchan") >= 2: call("_clear_all_debuffs", target)
		_log("[color=#e5a8ff]【天书·金蝉脱壳】触发免死！[/color]")
		return true
	return false

func _tianshu_wu_equalize_threshold(target: Dictionary) -> float:
	if not _tianshu_enabled() or not _tianshu_has_faction(target, "wu") or _tianshu_level("wu_tongzhou") <= 0: return 0.0
	return 0.10 if _tianshu_level("wu_tongzhou") == 1 else 0.30

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
		var bonus: float = float(call("_unit_skill_stat_value", source)) * float(_tianshu_level("shu_wuhu"))
		call("_damage", source, target, bonus, "physical", t("天书·五虎余烈", "Five Tigers' Legacy"), "tianshu_wuhu", "effect", false, true, false)
		if _tianshu_level("shu_wuhu") >= 2: source.action = minf(ACTION_MAX, float(source.action) + 10.0)

func _tianshu_on_ruler_hit(source: Dictionary, tile: Dictionary) -> void:
	if source.team != "player" or not _tianshu_enabled(): return
	if _tianshu_has_faction(source, "shu") and bool(source.get("tianshu_first_shu_damage", false)) and _tianshu_level("shu_wuhu") > 0:
		source.tianshu_first_shu_damage = false
		var bonus: float = float(call("_unit_skill_stat_value", source)) * float(_tianshu_level("shu_wuhu"))
		call("_hit_ruler", source, bonus, tile, t("天书·五虎余烈", "Five Tigers' Legacy"), "tianshu_wuhu", "effect")
		if _tianshu_level("shu_wuhu") >= 2: source.action = minf(ACTION_MAX, float(source.action) + 10.0)

func _tianshu_on_kill(killer, fallen: Dictionary) -> void:
	if not _tianshu_enabled(): return
	if fallen.team == "player" and _tianshu_level("mage_guoshi") > 0 and has_method("_earn_gold"):
		call("_earn_gold", 40 if _tianshu_level("mage_guoshi") == 1 else 90, "天书·马革裹尸")
	if fallen.team == "player" and str(heroes[fallen.hero_id].f) == "qun" and _tianshu_level("qun_yujin") > 0:
		var level := _tianshu_level("qun_yujin")
		var limit := 3 if level == 1 else 5
		if int(tianshu_battle_state.get("qun_fallen_triggers", 0)) < limit:
			tianshu_battle_state.qun_fallen_triggers = int(tianshu_battle_state.get("qun_fallen_triggers", 0)) + 1
			for ally in Array(call("_team_units", "player")).filter(func(unit): return unit.alive and str(heroes[unit.hero_id].f) == "qun"):
				ally.action = minf(ACTION_MAX, float(ally.action) + (10.0 if level == 1 else 20.0))
				ally.tianshu_qun_fallen_strategy_bonus = float(ally.get("tianshu_qun_fallen_strategy_bonus", 0.0)) + (6.0 if level == 1 else 12.0)
	if killer == null or killer.team != "player" or fallen.team != "enemy":
		return
	if _tianshu_level("jungong_juezhi") > 0 and has_method("_earn_gold"):
		var merit_level := _tianshu_level("jungong_juezhi")
		call("_earn_gold", 40 if merit_level == 1 else 80, "天书·军功爵制")
		if merit_level >= 2:
			killer.tianshu_kill_strategy_bonus = float(killer.get("tianshu_kill_strategy_bonus", 0.0)) + 20.0
	if _tianshu_level("zhanjiang") <= 0: return
	var limit := 3 if _tianshu_level("zhanjiang") == 1 else 5
	if int(killer.get("tianshu_kills", 0)) >= limit: return
	killer.tianshu_kills = int(killer.get("tianshu_kills", 0)) + 1
	killer.action = minf(ACTION_MAX, float(killer.action) + (15.0 if _tianshu_level("zhanjiang") == 1 else 25.0))
	if _tianshu_level("zhanjiang") >= 2: killer.tianshu_kill_strategy_bonus = float(killer.get("tianshu_kill_strategy_bonus", 0.0)) + 30.0

func _tianshu_on_cast(unit: Dictionary) -> void:
	if unit.team != "player" or not _tianshu_enabled(): return
	var faction := str(heroes[unit.hero_id].f)
	if faction == "shu" and _tianshu_level("shu_beifa") > 0:
		unit.tianshu_shu_cast_stacks = mini(3 if _tianshu_level("shu_beifa") == 1 else 5, int(unit.get("tianshu_shu_cast_stacks", 0)) + 1)
	if faction == "wu" and bool(unit.get("tianshu_wu_first_cast", false)) and _tianshu_level("wu_yinghao") > 0:
		unit.tianshu_wu_first_cast = false
		call("_grant_shield", unit, float(unit.max_hp) * 0.06 * _tianshu_level("wu_yinghao"))
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
		if tile.target == null: call("_hit_ruler", source, average * 2.0, tile, t("天书·黄天雷契", "Yellow Heaven Pact"), "tianshu_thunder", "magic")
		else:
			call("_damage", source, tile.target, average * 2.0, "magic", t("天书·黄天雷契", "Yellow Heaven Pact"), "tianshu_thunder", "magic")
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
				var action_gain := 15.0 if _tianshu_level("wu_zhiheng") == 1 else 30.0
				low.action = minf(ACTION_MAX, average + action_gain)
				high.action = minf(ACTION_MAX, average + action_gain)
				if _tianshu_level("wu_zhiheng") >= 2:
					for unit in [low, high]: unit.timed_damage_buff = maxf(float(unit.get("timed_damage_buff", 0.0)), 0.10); unit.timed_damage_time = maxf(float(unit.get("timed_damage_time", 0.0)), 5.0)

func _tianshu_on_round_end() -> void:
	if not _tianshu_enabled(): return
	if _tianshu_level("yuzhan") > 0:
		for unit in player_units:
			if unit.alive:
				var growth_cap := 3 if _tianshu_level("yuzhan") >= 2 else 2
				unit.tianshu_growth_stacks = mini(growth_cap, int(unit.get("tianshu_growth_stacks", 0)) + 1)
	if _tianshu_level("wei_tuntian") > 0:
		var survivors := player_units.filter(func(unit): return unit.alive and int(unit.row) >= 0 and str(heroes[unit.hero_id].f) == "wei")
		var count := mini(8, survivors.size())
		player_ruler_hp = mini(_player_ruler_max_hp(), player_ruler_hp + roundi(_player_ruler_max_hp() * 0.004 * _tianshu_level("wei_tuntian") * count))
		if _tianshu_level("wei_tuntian") >= 2:
			for unit in survivors: call("_heal_with_overflow", unit, unit, float(unit.max_hp) * 0.05, "heal", true)

func _tianshu_dot_duration_multiplier(source) -> float:
	return 1.0

func _tianshu_dot_damage_multiplier(source) -> float:
	return 1.0
