extends Control

const REGISTERED_HERO_BALANCE = preload("res://ThreeKingdom/data/registered_hero_balance.gd")

const BOARD_COLUMNS := 5           # 棋盘列数(横向 5 格)
const BOARD_ROWS := 3              # 棋盘行数(纵向 3 行:前排 row0/中排 row1/后排 row2)
const RULER_MAX_HP := 50000        # 主公最大血量(主公血量归零则游戏结束)
const ROUND_LIMIT := 15            # 总关卡数(15 关备战 + 1 场最终决战)
const BATTLE_LIMIT := 30.0         # 每关战斗时长(秒),最终决战无此限制
const TICK := 0.2                  # 战斗循环间隔:每 0.2 秒"走一步"(推进行动条)
const ACTION_MAX := 100.0          # 行动条上限:从 0 涨到 100 时武将行动一次
const FACTION_BOND_TIERS: Array[int] = [2, 5, 8] # 四阵营统一羁绊档位
const DEFAULT_Strategy_COOLDOWN := 8.5 # 未单独配置武将的初始冷却；不是均衡实验室的调整下限
const COOLDOWN_INPUT_MIN := 0.0     # 均衡实验室允许设置为 0，战斗计算处另行防止除零
const HERO_COOLDOWN_DEFAULTS := {"liubei":6.0, "guanyu":6.3, "liushan":0.0, "zhangfei":6.6, "zhaoyun":5.7, "huangzhong":4.2, "machao":7.2, "zhugeliang":6.9, "jiangwei":4.5, "pangtong":5.4, "menghuo":5.7, "zhurong":5.1, "dailaidongzhu":4.9, "weiyan":5.4, "madai":21.0, "sunquan":10.0, "sunshangxiang":8.0, "taishici":4.0, "ganning":8.0, "huanggai":10.0, "caocao":5.6, "dianwei":5.2, "xuchu":6.4, "zhangliao":6.8, "yuejin":6.0, "xuhuang":5.6, "zhanghe":5.2, "yujin":4.8, "xiahouyuan":5.5, "caoren":6.0, "xiahoudun":6.5, "simayi":7.5, "guojia":7.0, "xunyu":7.2, "jiaxu":6.5, "lvbu":6.4, "dongzhuo":5.5, "diaochan":7.0, "chengong":0.0, "gaoshun":6.2, "yanliang":4.0, "wenchou":4.0, "gaolan":0.0, "qunzhanghe":5.6, "huatuo":6.0, "yuji":6.6, "zuoci":6.0, "zhangjiao":6.0, "zhangliang":5.0, "zhangbao":0.0}
const RESERVE_LIMIT := 9           # 备战区(棋盘下方的替补区)最多放 9 名武将
const BOARD_LIMIT := BOARD_COLUMNS * BOARD_ROWS  # 棋盘总格数 = 15
const SAVE_PATH := "user://three_kingdoms_save.json"        # 存档文件路径(user:// 是玩家存档目录)
const SETTINGS_PATH := "user://three_kingdoms_settings.cfg" # 设置文件路径
const DRAFT_SIZE := 3              # 每次选将固定显示前军/中军/后军各 1 名
const PICKS_PER_ROUND := 3         # 每关连续进行 3 轮三选一
const SHU_WEAPON_CODEX := [
	{"id":"liubei", "owner_zh":"刘备", "owner_en":"Liu Bei", "name_zh":"双股剑", "name_en":"Twin Swords", "path":"res://ThreeKingdom/weapon/shuanggujian.png"},
	{"id":"guanyu", "owner_zh":"关羽", "owner_en":"Guan Yu", "name_zh":"青龙偃月刀", "name_en":"Green Dragon Crescent Blade", "path":"res://ThreeKingdom/weapon/qinglongyanyuedao.png"},
	{"id":"zhangfei", "owner_zh":"张飞", "owner_en":"Zhang Fei", "name_zh":"丈八蛇矛", "name_en":"Zhangba Serpent Spear", "path":"res://ThreeKingdom/weapon/zhangbashemao.png"},
	{"id":"zhaoyun", "owner_zh":"赵云", "owner_en":"Zhao Yun", "name_zh":"龙胆亮银枪", "name_en":"Dragon Gall Silver Spear", "path":"res://ThreeKingdom/weapon/longdanliangyinqiang.png"},
	{"id":"machao", "owner_zh":"马超", "owner_en":"Ma Chao", "name_zh":"虎头湛金枪", "name_en":"Tiger-Head Gilded Spear", "path":"res://ThreeKingdom/weapon/hutouzhanjinqiang.png"},
	{"id":"huangzhong", "owner_zh":"黄忠", "owner_en":"Huang Zhong", "name_zh":"落日弓", "name_en":"Setting Sun Bow", "path":"res://ThreeKingdom/weapon/luorigong.png"},
	{"id":"weiyan", "owner_zh":"魏延", "owner_en":"Wei Yan", "name_zh":"鬼头刀", "name_en":"Demon-Head Saber", "path":"res://ThreeKingdom/weapon/guitoudao.png"},
	{"id":"madai", "owner_zh":"马岱", "owner_en":"Ma Dai", "name_zh":"斩马刀", "name_en":"Horse-Cleaving Saber", "path":"res://ThreeKingdom/weapon/zhanmadao.png"},
	{"id":"liushan", "owner_zh":"刘禅", "owner_en":"Liu Shan", "name_zh":"细剑", "name_en":"Fine Sword", "path":"res://ThreeKingdom/weapon/xijian.png"},
	{"id":"zhugeliang", "owner_zh":"诸葛亮", "owner_en":"Zhuge Liang", "name_zh":"七星卧龙扇", "name_en":"Seven-Star Sleeping Dragon Fan", "path":"res://ThreeKingdom/weapon/qixingwolongshan.png"},
	{"id":"jiangwei", "owner_zh":"姜维", "owner_en":"Jiang Wei", "name_zh":"麒麟破军枪", "name_en":"Qilin Army-Breaker Spear", "path":"res://ThreeKingdom/weapon/qilinpojunqiang.png"},
	{"id":"pangtong", "owner_zh":"庞统", "owner_en":"Pang Tong", "name_zh":"黑凤涅槃扇", "name_en":"Black Phoenix Nirvana Fan", "path":"res://ThreeKingdom/weapon/heifenniepanshan.png"},
	{"id":"menghuo", "owner_zh":"孟获", "owner_en":"Meng Huo", "name_zh":"南蛮开山斧", "name_en":"Nanman Mountain-Cleaving Axe", "path":"res://ThreeKingdom/weapon/nanmakaishanfu.png"},
	{"id":"zhurong", "owner_zh":"祝融", "owner_en":"Zhurong", "name_zh":"火凤烈焰刃", "name_en":"Fire Phoenix Flame Blade", "path":"res://ThreeKingdom/weapon/huofenglieyanren.png"},
	{"id":"dailaidongzhu", "owner_zh":"带来洞主", "owner_en":"Dailai Dongzhu", "name_zh":"蛮骨狼牙棒", "name_en":"Barbarian-Bone Wolf-Fang Mace", "path":"res://ThreeKingdom/weapon/mangulangyabang.png"}
]

var language := "zh"               # 当前语言:"zh"中文 / "en"英文
var round_number := 1              # 当前关卡数(1~15)
var phase := "draft"               # 当前阶段:draft选将 / placement布阵 / combat战斗 / finished结算
var player_ruler_hp := RULER_MAX_HP  # 我方主公当前血量
var enemy_ruler_hp := RULER_MAX_HP   # 敌方主公当前血量
var player_units: Array = []       # 我方所有武将单位列表(包括棋盘上和备战区的)
var enemy_units: Array = []        # 敌方所有武将单位列表
var choices: Array = []            # 当前一轮三选一的候选武将 ID
var pending_unit_ids: Array[String] = []  # 待上阵的单位 ID(选完后需要玩家拖到棋盘上)
var chosen_this_round: Array[String] = [] # 本关三轮已经锁定的武将 ID
var draft_roster_baseline: Array = []     # 保留用于兼容旧存档
var draft_picks_remaining := PICKS_PER_ROUND  # 本关还能选几次(初始 3)
var refresh_charges := 0           # 保留用于兼容旧存档；三个候选位每轮可各自刷新一次
var draft_refresh_available: Array[bool] = [true, true, true] # 当前三选一的每个位置各可刷新一次
var selected_unit := ""            # 当前在备战区被选中(准备拖拽上阵)的单位 ID
var combat_units: Array = []       # 战斗中参与战斗的单位列表(只有上阵的,row>=0)
var battle_time := 0.0             # 当前战斗已经进行的秒数
var battle_running := false        # 战斗是否正在进行
var battle_paused := false         # 玩家手动暂停当前实战
var action_in_progress := false    # 是否有武将正在执行行动(此时全场暂停)
var final_battle := false          # 是否是最终决战(第 15 关之后)
var battle_speed := 1.0            # 战斗速度(1×/2×/4×)
var game_speed := 1.0              # 游戏速度(持久化保存的设置)
var pause_during_actions := true   # 是否在武将行动演出期间暂停全场(可设置)
var show_hero_codex_images := false # 武将图鉴是否显示武将图片(默认关闭)
var ruler_regen := {"player":{"amount":0.0, "time":0.0, "clock":0.0}, "enemy":{"amount":0.0, "time":0.0, "clock":0.0}}  # 主公持续回血状态(刘备仁德命中空格时触发)
var faction_battle_state := {
	"player":{"wu_equalize_used":false},
	"enemy":{"wu_equalize_used":false}
} # 每场战斗独立的阵营特殊效果次数
var rng := RandomNumberGenerator.new()  # 随机数生成器

var title_label: Label             # 顶部大标题
var round_label: Label             # 关卡数显示(如"关卡 3 / 15")
var phase_label: Label             # 当前阶段显示(如"◆ 选将")
var hint_label: Label              # 操作提示文字
var player_hp_label: Label         # 我方主公血量数字
var enemy_hp_label: Label          # 敌方主公血量数字
var player_ruler_fill: ColorRect   # 我方主公血条填充条
var enemy_ruler_fill: ColorRect    # 敌方主公血条填充条
var player_board: GridContainer    # 我方棋盘(5×3 格子容器)
var enemy_board: GridContainer     # 敌方棋盘(5×3 格子容器)
var draft_box: BoxContainer        # 选将弹层里的 5 张武将卡片容器
var roster_label: Label            # 我方阵容文字列表
var enemy_roster_label: Label      # 敌方阵容文字列表
var log_box: RichTextLabel         # 右侧实时战报(支持 BBCode 颜色)
var bonds_label: RichTextLabel     # 我方羁绊进度：激活项置顶，待激活项置后
var reserve_box: HBoxContainer     # 底部备战区(9 格横排)
var reserve_title_label: Label     # 备战区标题
var enemy_title_label: Label       # 敌方阵地标题
var player_title_label: Label      # 我方阵地标题
var draft_title_label: Label       # 选将/战斗阶段标题
var log_title_label: Label         # 战报标题
var phase_caption_label: Label     # 中间分隔线上的阶段说明
var auto_button: Button            # 自动布阵按钮
var battle_button: Button          # 开始战斗按钮
var battle_pause_button: Button    # 正常战斗的暂停/继续按钮
var language_button: Button        # 中英文切换按钮
var tick_timer: Timer              # 战斗循环定时器(每 TICK 秒触发一次 _battle_tick)
var battle_time_bar: ProgressBar   # 战斗时间进度条(显示剩余战斗时间)
var battle_time_label: Label       # 战斗时间数字标签(如 "18s" 或 "∞ 无时限")
var battle_workspace: HBoxContainer # 棋盘与信息侧栏的横向工作区
var battle_arena_panel: PanelContainer # 双方棋盘面板
var battle_info_panel: PanelContainer # 羁绊/战报/统计组合侧栏
var battle_info_host: Control      # 三页签及武将实时状态栏的共同显示区域
var battle_info_tabs: TabContainer # 羁绊组成/实时战报/统计图表

var portrait_cache := {}           # 武将卡片裁剪纹理缓存(避免重复加载图片)
var portrait_source_cache := {}    # 武将完整立绘缓存(图鉴放大预览使用)
var unit_cell_refs := {}           # 单位 ID → 格子内武将卡片层的映射(动画只移动卡片，不移动棋盘格)
var tile_cell_refs := {}           # "队伍:行:列" → 格子控件的映射(用于空格特效定位)
var action_bar_refs := {}          # 单位 ID → 行动条进度条数组的映射
var health_bar_refs := {}          # 单位 ID → 生命条映射(持续回血时不重建棋盘也能即时刷新)
var visual_events: Array = []      # 待播放的视觉事件队列(伤害、治疗、特效)
var ground_effects: Array = []     # 空格上的持续地面效果；伤害按格转移给对应主公
var battle_stats := {}             # 本场战斗统计:单位 ID → {damage, healing, taken, control}
var last_battle_stats: Array = []  # 上一场战斗的统计(用于战斗间隙展示)

var stats_title_label: Label       # 统计区标题
var stats_chart: VBoxContainer     # 统计柱状图容器
var stats_tab_buttons := {}        # 4 个统计指标切换按钮(伤害/治疗/控制/承伤)
var stats_metric := "damage"       # 当前显示的统计指标

var draft_layer: CanvasLayer       # 选将弹层的画布层(layer=20,在最上面)
var draft_overlay: Control         # 弹层背景半透明遮罩
var draft_user_hidden := false     # 玩家是否手动隐藏了选将弹层
var draft_toggle_button: Button    # 显示/隐藏选将弹层的按钮

var encyclopedia_overlay: Control  # 图鉴覆盖层
var encyclopedia_grid: GridContainer  # 图鉴卡片网格(3 列)
var encyclopedia_mode := "heroes"  # heroes 武将图鉴 / weapons 武器图鉴 / bonds 羁绊图
var encyclopedia_title_label: Label
var encyclopedia_hero_filters: Control
var encyclopedia_hero_tab_button: Button
var encyclopedia_weapon_tab_button: Button
var encyclopedia_bond_tab_button: Button
var encyclopedia_bond_reset_button: Button
var encyclopedia_star_filter_buttons: Array[Button] = []
var encyclopedia_content_scroll: ScrollContainer
var encyclopedia_bond_graph: GraphEdit
var encyclopedia_faction := "shu"  # 图鉴当前查看的阵营
var encyclopedia_star_level := 1   # 兼容旧界面数据；现版本只有一星
var encyclopedia_bond_label: Label # 图鉴顶部的阵营羁绊说明
var encyclopedia_preview_overlay: Control # 图鉴武将放大预览层
var encyclopedia_preview_portrait: TextureRect # 放大预览中的完整武将立绘
var encyclopedia_preview_separator: Control # 放大预览中立绘与介绍之间的分隔线
var encyclopedia_preview_detail: Label # 放大预览右侧的完整图鉴介绍
var encyclopedia_preview_name: Label # 放大预览中的武将名
var encyclopedia_preview_counter: Label # 放大预览中的当前位置
var encyclopedia_preview_hero_ids: Array[String] = [] # 当前阵营可左右切换的武将
var encyclopedia_preview_index := 0 # 当前放大预览索引

var unit_inspector_overlay: Control # 战斗武将实时状态弹层
var unit_inspector_title: Button
var unit_inspector_detail: RichTextLabel
var unit_inspector_unit_id := ""

var menu_overlay: Control          # 主菜单覆盖层(z_index=1000,盖住一切)
var continue_button: Button        # 继续游戏按钮
var save_button: Button            # 保存按钮
var load_button: Button            # 读取按钮
var menu_button: Button            # 返回主菜单按钮
var speed_button: Button           # 速度切换按钮

var settings_overlay: Control      # 设置覆盖层
var pause_setting_button: Button   # "行动期间暂停"开关按钮
var speed_setting_button: Button   # 速度设置按钮
var hero_codex_images_setting_button: Button # 武将图鉴图片显示开关
var faction_setting_options: OptionButton  # 我方选将阵营过滤
var enemy_faction_setting_options: OptionButton # 敌方随机阵营过滤
var board_side_setting_options: OptionButton # 棋盘居左/居右
var draft_faction_filter := ""     # 我方选将阵营过滤(空=全部, 或 shu/wei/wu/qun)
var enemy_faction_filter := ""     # 敌方随机武将阵营过滤
var board_side := "left"           # 棋盘位置:left=居左,right=居右

var heroes := {
	"liubei":{"zh":"刘备", "en":"Liu Bei", "f":"shu", "hp":3740, "skill_value":100, "cooldown":6.0, "range":3, "skill":"Benevolent Renewal", "zh_skill":"仁德回春", "ability":"signature", "ability_params":{"duration":4.0, "heal_ratio":1.0, "peach_heal_ratio":1.5, "liushan_duration_bonus":0.30, "zhuge_damage_reduction":0.30}, "summary":"仁德回春：为当前生命比例最低的友军施加持续4秒、每秒100%兵略值的治疗。", "en_summary":"Regenerate the ally with the lowest HP ratio for 4s at 100% Strategy per second.", "detail_zh":"仁德回春：为当前生命比例最低的友军施加持续4秒、每秒100%兵略值的治疗。", "detail_en":"Regenerate the ally with the lowest HP ratio for 4s at 100% Strategy per second."},
	"guanyu":{"zh":"关羽", "en":"Guan Yu", "f":"shu", "hp":5180, "skill_value":100, "cooldown":6.3, "range":1, "skill":"Green Dragon Crescent", "zh_skill":"青龙偃月", "ability":"signature", "ability_params":{"mult":2.10, "five_mult":4.60, "peach_heal":0.30}, "summary":"青龙偃月：劈砍目标整列，每名敌人受到210%兵略值伤害。", "en_summary":"Cleave the target column for 210% Strategy damage to each enemy.", "detail_zh":"青龙偃月：劈砍目标整列，每名敌人受到210%兵略值伤害。", "detail_en":"Cleave the target column for 210% Strategy damage to each enemy."},
	"zhangfei":{"zh":"张飞", "en":"Zhang Fei", "f":"shu", "hp":5620, "skill_value":100, "cooldown":6.6, "range":2, "skill":"Command of Yan", "zh_skill":"燕人号令", "ability":"signature", "ability_params":{"damage_ratio":0.20, "duration":3.3, "peach_duration_bonus":0.50, "five_duration_bonus":0.50, "five_damage_skill_ratio":0.30}, "summary":"燕人号令：强化己方前军，使其伤害提高20%，持续3.3秒。", "en_summary":"Empower allied vanguards with 20% damage for 3.3s.", "detail_zh":"燕人号令：强化己方前军，使其伤害提高20%，持续3.3秒。", "detail_en":"Empower allied vanguards with 20% damage for 3.3s."},
	"caocao":{"zh":"曹操", "en":"Cao Cao", "f":"wei", "hp":5470, "skill_value":100, "cooldown":5.6, "range":1, "skill":"Dominion Stun", "zh_skill":"魏武震慑", "ability":"signature", "ability_params":{"target_count":2, "mult":1.50, "stun":1.25, "bond_bonus_targets":1, "favored_damage_bonus_mult":1.0, "favored_stun_bonus":0.5}, "summary":"魏武震慑：随机攻击两名敌军，造成150%兵略值伤害并眩晕1.25秒。", "en_summary":"Dominion Stun: Strike two random enemies for 150% Strategy damage and stun for 1.25s.", "detail_zh":"魏武震慑：随机攻击两名敌军，造成150%兵略值伤害并眩晕1.25秒。", "detail_en":"Dominion Stun: Strike two random enemies for 150% Strategy damage and stun for 1.25s."},
	"dianwei":{"zh":"典韦", "en":"Dian Wei", "f":"wei", "hp":5260, "skill_value":100, "cooldown":5.2, "range":1, "skill":"Evil Guard Raid", "zh_skill":"恶来袭后", "ability":"signature", "ability_params":{"target_count":2, "mult":2.40, "caocao_bonus_targets":1, "caocao_damage_penalty_mult":0.30, "xuchu_damage_bonus_mult":0.80}, "summary":"恶来袭后：随机攻击两名敌方后军，各造成240%兵略值伤害。", "en_summary":"Evil Guard Raid: Strike two random enemy rearguards for 240% Strategy damage each.", "detail_zh":"恶来袭后：随机攻击两名敌方后军，各造成240%兵略值伤害。", "detail_en":"Evil Guard Raid: Strike two random enemy rearguards for 240% Strategy damage each."},
	"xuchu":{"zh":"许褚", "en":"Xu Chu", "f":"wei", "hp":5040, "skill_value":100, "cooldown":6.4, "range":1, "skill":"Tiger Guard Break", "zh_skill":"虎卫破前", "ability":"signature", "ability_params":{"target_count":2, "mult":3.20, "caocao_bonus_targets":1, "caocao_damage_penalty_mult":0.40, "dianwei_damage_bonus_mult":1.0}, "summary":"虎卫破前：随机攻击两名敌方前军，各造成320%兵略值伤害。", "en_summary":"Tiger Guard Break: Strike two random enemy vanguards for 320% Strategy damage each.", "detail_zh":"虎卫破前：随机攻击两名敌方前军，各造成320%兵略值伤害。", "detail_en":"Tiger Guard Break: Strike two random enemy vanguards for 320% Strategy damage each."},
	"zhouyu":{"zh":"周瑜", "en":"Zhou Yu", "f":"wu", "hp":225, "skill_value":100, "cooldown":4.0, "range":3, "skill":"Red Cliffs", "zh_skill":"赤壁点火", "ability":"signature", "summary":"点燃敌方格子。", "en_summary":"Ignites enemy tiles."},
	"luxun":{"zh":"陆逊", "en":"Lu Xun", "f":"wu", "hp":235, "skill_value":100, "cooldown":4.0, "range":3, "skill":"Flames of Camp", "zh_skill":"火烧连营", "ability":"signature", "summary":"火球命中目标并弹射邻格。", "en_summary":"A fireball hits a target and bounces nearby."},
	"lusu":{"zh":"鲁肃", "en":"Lu Su", "f":"wu", "hp":260, "skill_value":100, "cooldown":4.0, "range":3, "skill":"Alliance", "zh_skill":"连横稳阵", "ability":"signature", "summary":"治疗当前生命总量最低的友军并提高其最大生命。", "en_summary":"Treats the ally with the lowest current HP total and raises max HP."},
	"lvbu":{"zh":"吕布", "en":"Lu Bu", "f":"qun", "hp":390, "skill_value":100, "cooldown":3.0, "range":2, "skill":"Peerless", "zh_skill":"无双横扫", "ability":"signature", "summary":"横扫敌方前军。", "en_summary":"Sweeps enemy vanguards."},
	"diaochan":{"zh":"貂蝉", "en":"Diao Chan", "f":"qun", "hp":210, "skill_value":100, "cooldown":4.0, "range":3, "skill":"Beauty's Scheme", "zh_skill":"美人离间", "ability":"signature", "summary":"魅惑随机敌军。", "en_summary":"Charms a random enemy."},
	"dongzhuo":{"zh":"董卓", "en":"Dong Zhuo", "f":"qun", "hp":390, "skill_value":100, "cooldown":3.0, "range":2, "skill":"Tyrant's Levy", "zh_skill":"暴君横征", "ability":"signature", "summary":"按当前生命造成伤害。", "en_summary":"Deals damage based on current health."}
}

# UI and combat hooks are implemented by focused subclasses. Declaring the
# interface here keeps lower-level game state independent from presentation.
func _render() -> void:
	pass

func _log(_text_value: String) -> void:
	pass

func _render_combat_boards() -> void:
	pass

func _update_action_bars() -> void:
	pass

func _update_battle_time_bar() -> void:
	pass

func _play_visual_events(_events: Array) -> void:
	pass

func _hero_fx(_hero_id: String) -> Dictionary:
	return {}

func _weapon_cutout_material() -> ShaderMaterial:
	return null

func _fire_effect_material() -> ShaderMaterial:
	return null

func _apply_faction_bonuses(_announce := true) -> void:
	pass

func _apply_opening_skills() -> void:
	pass

func _apply_combo_bonds(_opening := true, _announce := true) -> void:
	pass

func _capture_battle_stats() -> void:
	pass

func _load_balance_overrides() -> void:
	pass

func _build_balance_lab() -> void:
	pass

func _show_balance_lab() -> void:
	pass

func _ensure_unit_fields(_unit: Dictionary) -> void:
	pass

func _reset_faction_battle_state() -> void:
	faction_battle_state = {
		"player":{"wu_equalize_used":false},
		"enemy":{"wu_equalize_used":false}
	}

func _add_extended_roster() -> void:
	_register_hero("zhaoyun", "赵云", "Zhao Yun", "shu", 3840, 100, 5.7, 2, "Dragon-Gall Flurry", "龙胆连刺", "signature", {"hit_count":5, "hit_mult":1.15, "five_bonus_mult":1.0, "seven_hit_count":7, "seven_cooldown_add":0.5}, "随机选择一名射程内敌人，快速攻击同一目标5次，每次造成115%兵略值伤害。", "Strike one random reachable enemy 5 times for 115% Strategy each.")
	_register_hero("huangzhong", "黄忠", "Huang Zhong", "shu", 3550, 100, 4.2, 3, "Piercing Arrow", "百步穿杨", "signature", {"mult":4.2, "five_mult":9.0, "meteor_crit_chance":0.30, "meteor_crit_mult":2.0}, "射击随机可攻击格，造成420%兵略值伤害。", "Shoot a random reachable tile for 420% Strategy damage.")
	_register_hero("machao", "马超", "Ma Chao", "shu", 3600, 100, 7.2, 2, "Iron Cavalry", "铁骑贯阵", "signature", {"front_mult":2.6, "middle_mult":2.3, "back_mult":2.0, "one_rider_mults":[2.6,3.0,3.4], "five_skill_ratio":0.4, "five_duration":7.2}, "锁定当前血量最低敌人所在列，前军/中军/后军依次受到260%/230%/200%兵略值伤害。", "Pierce the lowest-current-HP enemy's column for 260%/230%/200% Strategy damage.")
	_register_hero("liushan", "刘禅", "Liu Shan", "shu", 3460, 100, 0.0, 2, "Royal Encouragement", "蜀主鼓舞", "passive", {"damage_ratio":0.27, "liubei_damage_ratio":0.18, "seven_lifesteal":0.30}, "被动强化自己前方的友军，使其伤害提高0.27×兵略值%。", "Passively empowers the ally ahead with damage based on Strategy.")
	_register_hero("zhugeliang", "诸葛亮", "Zhuge Liang", "shu", 3460, 100, 6.9, 3, "Eight-Formation Stratagem", "八阵奇谋", "signature", {"mult":2.3, "menghuo_damage_bonus":0.20, "fire_mark_duration":10.0, "fire_mark_bonus":0.40, "liubei_extra_target_bonus":0.04}, "随机选择敌方格子，对目标及同列相邻格造成230%兵略值法术伤害。", "Deal 230% Strategy magic damage to a random tile and its vertical neighbors.")
	_register_hero("jiangwei", "姜维", "Jiang Wei", "shu", 4320, 100, 4.5, 1, "Northern Expedition", "北伐", "signature", {"mult":4.5, "bond_splash_mult":1.0}, "对随机可攻击目标造成450%兵略值法术伤害。", "Deal 450% Strategy magic damage to a random reachable target.")
	_register_hero("menghuo", "孟获", "Meng Huo", "shu", 5180, 100, 5.7, 1, "Barbarian Quake", "蛮王震地", "signature", {"mult":1.15, "stun":0.8, "aftershock_mult":0.35, "burning_damage_mult":1.40, "burning_stun":1.20, "bond_action_reduction":8.0}, "攻击敌方前军整排，造成115%兵略值物理伤害并眩晕0.8秒。", "Strike the enemy vanguard row for 115% Strategy damage and stun for 0.8s.")
	_register_hero("zhurong", "祝融", "Zhurong", "shu", 3580, 100, 5.1, 3, "Flame Blade", "火神飞刃", "signature", {"mult":3.0, "burn":3.0, "burn_ratio":0.70, "bounce_mult":0.50, "sibling_burn_bonus":2.0, "sibling_burn_ratio":1.0}, "火神飞刃：对随机敌方单位造成300%兵略值法术伤害并灼烧3秒，每秒造成70%兵略值伤害。", "Flame Blade: Deal 300% Strategy magic damage to a random enemy and burn for 3s at 70% Strategy per second.")
	_register_hero("dailaidongzhu", "带来洞主", "Dailai Dongzhu", "shu", 4610, 100, 4.9, 2, "Savage-Bone Wolf Assault", "蛮骨狼袭", "signature", {"mult":4.90, "column_mult":3.20, "burning_bonus_mult":0.50, "bond_burn":4.0, "bond_burn_ratio":0.50, "target_mode":"highest_action"}, "蛮骨狼袭：锁定行动条最高的可攻击敌人，造成490%兵略值物理伤害。", "Savage-Bone Wolf Assault: Strike the reachable enemy with the highest gauge for 490% Strategy physical damage.")
	_register_hero("weiyan", "魏延", "Wei Yan", "shu", 4540, 100, 5.4, 1, "Bone-Crazed Sweep", "狂骨横斩", "signature", {"mult":1.8, "meteor_heal":0.23, "fated_ally_heal":0.06}, "攻击正前方及其同排相邻格，造成180%兵略值伤害。", "Strike the facing tile and its horizontal neighbors for 180% Strategy damage.")
	_register_hero("madai", "马岱", "Ma Dai", "shu", 3580, 100, 21.0, 3, "General-Slaying Raid", "斩将突袭", "signature", {"max_hp_ratio":0.50, "empty_ruler_damage":2000.0, "vulnerable_skill_ratio":0.30}, "随机攻击敌方前军，造成50%最大生命伤害；无前军时对主公造成2000点伤害。", "Strike a random enemy vanguard for 50% max HP; if none exists, deal 2000 ruler damage.")
	_register_hero("pangtong", "庞统", "Pang Tong", "shu", 3550, 100, 5.4, 3, "Chain Scheme", "连环计", "signature", {"target_count":2, "mult":2.0, "link_duration":4.0, "link_ratio":0.30, "bond_target_count":3, "bond_link_ratio":0.50}, "随机攻击两个目标，各造成200%兵略值伤害并链接4秒；链接者受伤时其他目标承受30%同等伤害。", "Strike two random targets for 200% Strategy and link them for 4s; linked allies echo 30% damage.")

	_register_hero("zhangliao", "张辽", "Zhang Liao", "wei", 4180, 100, 6.8, 2, "Returning Blade", "威震回刃", "signature", {"mult":1.10, "hit_count":2, "yuejin_damage_bonus_mult":0.40, "five_damage_bonus_mult":0.80, "five_vulnerable_skill_ratio":0.40, "five_vulnerable_time":5.0}, "威震回刃：攻击随机敌方一列，回旋刃飞出与返回各造成110%兵略值伤害。", "Returning Blade: Strike a random enemy column for 110% Strategy on both the outward and returning passes.")
	_register_hero("yuejin", "乐进", "Yue Jin", "wei", 2660, 100, 6.0, 3, "Vanguard Volley", "先登乱射", "signature", {"target_count":3, "mult":2.0, "zhangliao_bonus_targets":1, "five_bonus_targets":1, "five_damage_bonus_mult":0.50, "five_grievous_skill_ratio":0.50, "five_grievous_time":5.0}, "先登乱射：随机攻击三名敌军，各造成200%兵略值伤害。", "Vanguard Volley: Strike three random enemies for 200% Strategy damage each.")
	_register_hero("zhanghe", "张郃", "Zhang He", "wei", 4540, 100, 5.2, 1, "Coiling Spear Chain", "巧变连枪", "signature", {"mult":4.0, "stun":1.5, "xuhuang_stun_bonus":1.0, "five_chain_targets":2, "five_damage_bonus_mult":2.0, "five_stunned_damage_bonus_mult":4.0}, "巧变连枪：随机攻击一名敌方前军，造成400%兵略值伤害并眩晕1.5秒。", "Coiling Spear Chain: Strike a random enemy vanguard for 400% Strategy damage and stun for 1.5s.")
	_register_hero("xuhuang", "徐晃", "Xu Huang", "wei", 5040, 100, 5.6, 1, "Earth-Splitting Axe", "撼地开山", "signature", {"mult":0.80, "stun":1.5, "zhanghe_damage_bonus_mult":0.80, "five_stun_bonus":2.0}, "撼地开山：攻击敌方前军整排，造成80%兵略值伤害并眩晕1.5秒。", "Earth-Splitting Axe: Strike the enemy vanguard row for 80% Strategy damage and stun for 1.5s.")
	_register_hero("yujin", "于禁", "Yu Jin", "wei", 4970, 100, 4.8, 1, "Resolute Ward", "毅重护阵", "signature", {"target_count":1, "shield_mult":3.0, "five_bonus_targets":1, "five_shield_bonus_mult":1.0}, "毅重护阵：为当前生命值最低的友军施加300%兵略值的护盾。", "Resolute Ward: Shield the ally with the lowest current HP for 300% Strategy.")
	_register_hero("xiahouyuan", "夏侯渊", "Xiahou Yuan", "wei", 190, 100, 5.5, 4, "Swift Suppression", "神速震袭", "signature", {"target_count":2, "mult":1.75, "stunned_mult":2.50, "stun":1.5}, "随机攻击2名敌军，造成175%兵略值伤害并眩晕1.5秒；若目标已眩晕，伤害提高至250%。", "Strike 2 random enemies for 175% Strategy and stun for 1.5s; deal 250% against already-stunned targets.")
	_register_hero("caoren", "曹仁", "Cao Ren", "wei", 390, 100, 6.0, 1, "Rearward Bulwark", "樊城镇远", "signature", {"target_count":2, "mult":1.50, "stun":1.5, "guard_time":6.0, "rear_reduction":0.20}, "随机攻击2名敌方后军，造成150%兵略值伤害并眩晕1.5秒；释放后6秒内，自身受到敌方后军的伤害减少20%。", "Strike 2 random enemy rearguards for 150% Strategy and stun for 1.5s; for 6s, take 20% less damage from enemy rearguards.")
	_register_hero("xiahoudun", "夏侯惇", "Xiahou Dun", "wei", 410, 100, 6.5, 1, "Vanguard Bulwark", "刚烈镇前", "signature", {"target_count":2, "mult":1.50, "stun":1.5, "guard_time":6.5, "front_reduction":0.20}, "随机攻击2名敌方前军，造成150%兵略值伤害并眩晕1.5秒；释放后6.5秒内，自身受到敌方前军的伤害减少20%。", "Strike 2 random enemy vanguards for 150% Strategy and stun for 1.5s; for 6.5s, take 20% less damage from enemy vanguards.")
	_register_hero("guojia", "郭嘉", "Guo Jia", "wei", 175, 100, 7.0, 4, "Frozen Legacy", "遗计冰封", "signature", {"target_count":2, "freeze":4.0, "shatter_per_second":400.0}, "随机冻结2名敌军4秒；冻结期间行动条停止，受到伤害时提前解冻，并额外受到剩余冻结秒数×400点伤害。", "Freeze 2 random enemies for 4s. Their gauges stop; taking damage breaks freeze and deals 400 extra damage per remaining second.")
	_register_hero("simayi", "司马懿", "Sima Yi", "wei", 190, 100, 7.5, 4, "Thunder Judgment", "雷霆谋断", "signature", {"target_count":2, "mult":1.75}, "随机雷击2名敌军，造成175%兵略值伤害。", "Strike 2 random enemies with lightning for 175% Strategy damage.")
	_register_hero("xunyu", "荀彧", "Xun Yu", "wei", 200, 100, 7.2, 4, "Royal Acceleration", "王佐疾策", "signature", {"target_count":2, "action_bonus":0.20, "duration":6.0}, "随机使2名友军行动条速度提高20%，持续6秒。", "Grant 2 random allies 20% gauge speed for 6s.")
	_register_hero("jiaxu", "贾诩", "Jia Xu", "wei", 190, 100, 6.5, 4, "Venomous Scheme", "毒士奇谋", "signature", {"target_count":2, "poison_ratio":0.01, "duration":5.0}, "使随机2名敌军中毒5秒，每秒损失1%最大生命值。", "Poison 2 random enemies for 5s, dealing 1% max HP each second.")

	_register_hero("lvmeng", "吕蒙", "Lu Meng", "wu", 205, 100, 2.8, 1, "White-Robed Raid", "白衣渡江", "strike", {"mult":2.1}, "突袭造成210%兵略值物理伤害；对远程目标额外提高30%。", "Ambush for 210% Strategy physical damage, +30% against ranged targets.")
	_register_hero("sunjian", "孙坚", "Sun Jian", "wu", 275, 100, 3.0, 1, "Tiger's First Strike", "江东猛虎", "strike", {"mult":1.9}, "造成190%兵略值物理伤害；本场第一次释放提高至260%。", "Deal 190% Strategy physical damage; the first cast is increased to 260%.")
	_register_hero("sunce", "孙策", "Sun Ce", "wu", 310, 100, 2.9, 1, "Little Conqueror", "小霸王", "drain", {"mult":1.55, "heal":0.40}, "造成155%兵略值物理伤害并回复实际伤害40%。生命越低，羁绊强化越高。", "Deal 155% Strategy physical damage and heal for 40%. Bonds scale as HP falls.")
	_register_hero("sunquan", "孙权", "Sun Quan", "wu", 285, 100, 10.0, 3, "Jiangdong Balance", "江东制衡", "signature", {"current_hp_damage_ratio":0.08, "max_hp_gain":200.0, "max_hp_cap_mult":2.0, "missing_hp_heal_ratio":0.10}, "随机对一名敌军造成其当前生命8%的伤害，提高自身最大生命并恢复已损生命。", "Damage a random enemy based on current HP, then grow max HP and restore missing HP.")
	_register_hero("sunshangxiang", "孙尚香", "Sun Shangxiang", "wu", 180, 100, 8.0, 4, "Heroine's Growing Volley", "枭姬叠势", "signature", {"hit_count":1, "mult":1.0, "skill_gain_per_cast":1.0, "ally_death_skill_gain":3.0}, "随机攻击一名敌军；每次施法和友军阵亡都会永久提高自身兵略值。", "Strike a random enemy; casts and allied deaths permanently increase Strategy.")
	_register_hero("daqiao", "大乔", "Da Qiao", "wu", 175, 100, 3.7, 4, "River Blossom", "国色流离", "heal", {"mult":1.5, "flat":95.0, "bond_missing_hp_step":0.10, "bond_heal_bonus_per_step":0.04}, "治疗当前生命比例最低的友军。与孙策组成江东佳偶后，目标每损失10%生命，本次受到的治疗提高4%。", "Heal the lowest-HP-ratio ally. With Sun Ce, the target gains 4% healing received per 10% HP missing.")
	_register_hero("xiaoqiao", "小乔", "Xiao Qiao", "wu", 165, 100, 3.5, 4, "Gentle Breeze", "天香缓阵", "signature", {"target_count":2, "slow":0.35, "slow_time":6.0}, "随机选择两名敌方后军，使其行动条速度降低35%，持续6秒。", "Slow two random enemy rearguards by 35% for 6s.")
	_register_hero("taishici", "太史慈", "Taishi Ci", "wu", 250, 100, 4.0, 2, "Blazing Twin Halberds", "神亭烈戟", "signature", {"target_count":2, "mult":1.50, "burn":5.0, "burn_ratio":0.20, "sunce_target_count":3, "ganning_burning_mult":3.0}, "攻击射程内行动条最高的两名敌人，造成150%兵略值伤害并施加5秒灼烧。", "Strike the two reachable enemies with the highest gauges for 150% Strategy and burn them for 5s.")
	_register_hero("dingfeng", "丁奉", "Ding Feng", "wu", 335, 100, 8.5, 1, "Snowbound Short Blades", "雪中奋短兵", "signature", {"mult":1.30, "action_reduction":25.0, "bond_splash_mult":0.70, "bond_splash_action_reduction":15.0}, "攻击射程内行动条最高的敌人，造成130%兵略值物理伤害并压退25%行动条。", "Strike the reachable enemy with the highest gauge for 130% Strategy physical damage and push its gauge back by 25%.")
	_register_hero("xusheng", "徐盛", "Xu Sheng", "wu", 330, 100, 3.2, 1, "Breaking Waves", "疑城水阵", "row_magic", {"mult":0.85, "stun":1.2}, "对随机敌排造成85%兵略值魔法伤害并减速1.2秒。", "Deal 85% Strategy magic damage to a row and disable it for 1.2s.")
	_register_hero("ganning", "甘宁", "Gan Ning", "wu", 225, 100, 8.0, 2, "Bell-Raider Twin Assault", "锦帆并击", "signature", {"mult":1.50, "taishici_mult":2.50, "lvmeng_low_hp_bonus":0.50}, "自身与左侧友军分别攻击随机敌方后军，友军协击不消耗行动条。", "Gan Ning and his left ally each strike a random enemy rearguard; the ally assist costs no gauge.")
	_register_hero("huanggai", "黄盖", "Huang Gai", "wu", 350, 100, 10.0, 1, "Bitter-Flesh Column", "苦肉焚阵", "signature", {"max_hp_cost":0.10, "damage_cost_ratio":0.33, "zhouyu_burn":6.0, "zhouyu_burn_cost_ratio":0.05, "sunjian_max_hp_cost":0.15, "sunjian_damage_cost_ratio":0.45}, "消耗10%最大生命，对随机敌方一列造成消耗生命33%的伤害。", "Spend 10% max HP to damage a random enemy column for 33% of HP spent.")

	_register_hero("gaoshun", "高顺", "Gao Shun", "qun", 365, 100, 3.4, 1, "Camp Crusher", "陷阵营", "shield_row", {"mult":1.00, "flat":25.0}, "为自身同排友军提供100%兵略值+25点护盾。", "Shield allies in his row for 100% Strategy + 25.")
	_register_hero("chengong", "陈宫", "Chen Gong", "qun", 190, 100, 3.0, 4, "Measured Assault", "智迟谋速", "buff_two", {"damage":0.15, "action":0.15}, "强化两名当前生命比例最低的友军，使其伤害与行动条速度提高15%。", "Empower the two lowest-HP allies with +15% damage and gauge speed.")
	_register_hero("yanliang", "颜良", "Yan Liang", "qun", 350, 100, 3.1, 1, "Hebei Retaliation", "河北反击", "multi_magic", {"count":2, "mult":0.9}, "反击2个随机格，每次造成90%兵略值魔法伤害。", "Counter 2 random tiles for 90% Strategy magic damage each.")
	_register_hero("wenchou", "文丑", "Wen Chou", "qun", 325, 100, 3.1, 1, "Reflected Edge", "返锋", "shield_single", {"mult":1.30, "flat":35.0}, "为当前生命比例最低的友军提供130%兵略值+35点护盾。", "Shield the lowest-HP ally for 130% Strategy + 35.")
	_register_hero("qunzhanghe", "群张郃", "Zhang He (Qun)", "qun", 300, 100, 3.2, 1, "Purple Ward", "紫盾", "shield_column", {"mult":1.20, "flat":30.0}, "为自身同列友军提供120%兵略值+30点护盾。", "Shield allies in his column for 120% Strategy + 30.")
	_register_hero("gaolan", "高览", "Gao Lan", "qun", 245, 100, 3.0, 3, "Arcane Blades", "法刃加持", "buff_row_melee", {"damage":0.20}, "使自身同排的近战友军伤害提高20%。", "Increase damage of melee allies in his row by 20%.")
	_register_hero("huatuo", "华佗", "Hua Tuo", "qun", 190, 100, 6.0, 4, "Threefold Remedy", "青囊三济", "signature", {"target_count":3, "heal_mult":1.0}, "治疗当前生命最低的三名友军，各恢复100%兵略值生命。", "Heal the three allies with the lowest current HP for 100% Strategy each.")
	_register_hero("yuji", "于吉", "Yu Ji", "qun", 215, 100, 6.6, 4, "Venomous Immortal Art", "蛊毒仙术", "signature", {"target_count":2, "poison_ratio":0.005, "duration":4.0}, "随机使两名敌军中毒4秒，每秒损失0.5%最大生命。", "Poison two random enemies for 4s, dealing 0.5% max HP each second.")
	_register_hero("zuoci", "左慈", "Zuo Ci", "qun", 200, 100, 6.0, 4, "Immortal Aid", "遁甲济世", "signature", {"target_count":2, "heal_mult":1.5, "thunder_mult":1.5}, "治疗当前生命最低的两名友军，各恢复150%兵略值生命。", "Heal the two allies with the lowest current HP for 150% Strategy each.")
	_register_hero("zhangjiao", "张角", "Zhang Jiao", "qun", 230, 100, 6.0, 4, "Yellow Sky Thunder", "黄天雷引", "signature", {"target_count":2, "mult":2.0, "zhangliang_bonus_mult":0.5, "zhangbao_bonus_targets":1, "zhangbao_stun_chance":0.5, "zhangbao_stun":1.0}, "召唤雷电随机攻击两名敌军，各造成200%兵略值伤害。", "Call lightning on two random enemies for 200% Strategy damage each.")
	_register_hero("zhangliang", "张梁", "Zhang Liang", "qun", 210, 100, 5.0, 4, "Yellow Sky Weakening", "人公虚弱", "signature", {"target_count":2, "duration":5.0, "skill_reduction":0.5, "bond_bonus_targets":1}, "随机使两名敌军虚弱5秒，兵略值降低50%。", "Weaken two random enemies for 5s, reducing Strategy by 50%.")
	_register_hero("zhangbao", "张宝", "Zhang Bao", "qun", 130, 100, 0.0, 1, "Earth General Detonation", "地公雷爆", "passive", {"target_count":2, "death_mult":2.0, "base_revives":1, "zhangjiao_splash_mult":0.5, "zhangliang_bonus_revives":1}, "阵亡时随机攻击两名敌军，各造成200%兵略值伤害，随后可满血复生一次。", "On death, strike two random enemies for 200% Strategy, then revive once at full HP.")

func _register_hero(id: String, zh: String, en: String, faction: String, hp: int, skill_value: int, cooldown: float, range_tier: int, skill: String, zh_skill: String, ability: String, params: Dictionary, detail_zh: String, detail_en: String) -> void:
	heroes[id] = {"zh":zh, "en":en, "f":faction, "hp":hp, "skill_value":skill_value, "cooldown":maxf(COOLDOWN_INPUT_MIN, cooldown), "range":range_tier, "skill":skill, "zh_skill":zh_skill, "summary":detail_zh, "en_summary":detail_en, "ability":ability, "ability_params":params, "detail_zh":detail_zh, "detail_en":detail_en}

const FACTION_COLORS := {"shu": Color("#4ca968"), "wei": Color("#4f79c5"), "wu": Color("#d2644f"), "qun": Color("#a66dc4")}

func _apply_registered_balance_baseline() -> void:
	for hero_id in REGISTERED_HERO_BALANCE.BASE_STATS:
		if not heroes.has(hero_id): continue
		var stats: Dictionary = REGISTERED_HERO_BALANCE.BASE_STATS[hero_id]
		var hero: Dictionary = heroes[hero_id]
		hero.hp = int(stats.hp)
		hero.cooldown = float(stats.cooldown)
		hero.range = int(stats.range)
		if REGISTERED_HERO_BALANCE.PARAM_OVERRIDES.has(hero_id):
			hero.ability_params = REGISTERED_HERO_BALANCE.PARAM_OVERRIDES[hero_id].duplicate(true)
		heroes[hero_id] = hero

func _set_skill(hero_id: String, params: Dictionary, zh_detail: String, en_detail: String) -> void:
	heroes[hero_id].ability_params = params
	heroes[hero_id].detail_zh = zh_detail
	heroes[hero_id].detail_en = en_detail
	heroes[hero_id].summary = zh_detail
	heroes[hero_id].en_summary = en_detail

func _apply_existing_faction_skill_reworks() -> void:
	# 蜀国刘备至孟获的数据已直接写在注册表中；这里只保留其他阵营此前已经生效的配置。
	heroes.sunjian.skill = "Tiger's Resolve"
	heroes.sunjian.zh_skill = "猛虎绝命"
	_set_skill("sunjian", {"damage_cost_ratio":1.0, "pillars_damage_cost_ratio":1.5, "self_cost":0.10, "first_self_cost":0.40, "sun_legacy_self_cost":0.20, "sun_legacy_first_self_cost":0.80, "death_wu_damage_bonus":0.10}, "猛虎绝命：消耗当前生命攻击正前方敌军；通常消耗10%，每回合首次消耗40%，造成等同于实际消耗生命100%的伤害。", "Tiger's Resolve: Spend 10% current HP, or 40% on the first cast each round, to strike the facing enemy for 100% of HP actually spent.")
	heroes.sunce.skill = "Conqueror's Twin Assault"
	heroes.sunce.zh_skill = "小霸王连击"
	_set_skill("sunce", {"mult":2.0, "sun_legacy_mult":4.0, "missing_hp_step":0.10, "missing_hp_damage_bonus_per_step":0.02, "missing_hp_reduction_per_step":0.04}, "小霸王连击：攻击正前方及其左侧敌军，造成200%兵略值伤害；自身每损失10%生命，伤害提高2%。", "Conqueror's Twin Assault: Strike the facing enemy and its left neighbor for 200% Strategy damage; gain +2% damage per 10% HP missing.")
	heroes.sunquan.skill = "Jiangdong Balance"
	heroes.sunquan.zh_skill = "江东制衡"
	_set_skill("sunquan", {"current_hp_damage_ratio":0.08, "max_hp_gain":200.0, "max_hp_cap_mult":2.0, "missing_hp_heal_ratio":0.10, "sun_legacy_max_hp_gain":400.0, "sun_legacy_missing_hp_cap_gain_ratio":0.10, "sun_legacy_max_hp_cap_mult":4.0, "sun_legacy_missing_hp_heal_ratio":0.15, "luxun_damage_ratio":0.12, "luxun_cooldown":8.0}, "江东制衡：随机对一名敌军造成其当前生命8%的伤害；自身最大生命提高200，再恢复10%已损失生命。", "Jiangdong Balance: Deal 8% of a random enemy's current HP, gain max HP, then restore missing HP.")
	_set_skill("zhouyu", {"mult":1.0, "tile_count":2, "four_heroes_bonus_tiles":2, "burn":3.0, "burn_ratio":0.50, "xiaoqiao_burn":6.0, "missing_hp_step":0.10, "missing_hp_bonus_per_step":0.05}, "赤壁点火：随机点燃2个敌方格，各造成100%兵略值法术伤害并灼烧3秒，每秒造成50%兵略值伤害。", "Red Cliffs: Ignite 2 random enemy tiles for 100% Strategy magic damage and burn for 3s at 50% Strategy per second.")
	_set_skill("luxun", {"mult":2.0, "bounces":1, "four_heroes_bounces":3, "sunquan_damage_bonus":0.50, "sunquan_burning_bonus":0.50}, "火烧连营：发射火球造成200%兵略值法术伤害，并向相邻敌方格弹射1次。", "Flames of Camp: Launch a fireball for 200% Strategy magic damage and bounce once.")
	_set_skill("lvmeng", {"mult":4.0, "target_mode":"back", "stealth":3.0, "fear":4.0, "fear_max_hp_ratio":0.05, "ambush_next_damage_bonus":0.60}, "白衣渡江：攻击敌方后军，造成400%兵略值物理伤害，随后隐身3秒。", "White-Robed Raid: Strike an enemy rearguard for 400% Strategy physical damage, then enter stealth for 3s.")
	_set_skill("lusu", {"heal_ratio":0.15, "max_hp_flat":200.0, "target_count":1, "four_heroes_heal_ratio":0.20, "four_heroes_max_hp_flat":350.0, "four_heroes_target_count":2}, "连横稳阵：治疗当前生命值总量最低的友军并提高其最大生命。", "Alliance: Heal the ally with the lowest current HP and raise max HP.")
	_set_skill("xiaoqiao", {"target_count":2, "slow":0.35, "slow_time":6.0, "zhouyu_target_count":3, "zhouyu_slow_time":8.0, "daqiao_slow":0.60}, "天香缓阵：随机选择两名敌方后军，使其行动条速度降低35%，持续6秒。", "Gentle Breeze: Slow two random enemy rearguards by 35% for 6s.")
	heroes.taishici.skill = "Blazing Twin Halberds"
	heroes.taishici.zh_skill = "神亭烈戟"
	_set_skill("taishici", {"target_count":2, "mult":1.50, "burn":5.0, "burn_ratio":0.20, "sunce_target_count":3, "ganning_burning_mult":3.0}, "神亭烈戟：攻击射程内行动条最高的两名敌人，造成150%兵略值物理伤害，并施加5秒灼烧。", "Blazing Twin Halberds: Strike two enemies for 150% Strategy and burn them.")
	heroes.ganning.skill = "Bell-Raider Twin Assault"
	heroes.ganning.zh_skill = "锦帆并击"
	_set_skill("ganning", {"mult":1.50, "taishici_mult":2.50, "lvmeng_low_hp_bonus":0.50}, "锦帆并击：自身与同排左侧友军分别攻击一名随机敌方后军。", "Bell-Raider Twin Assault: Gan Ning and his left ally strike enemy rearguards.")
	heroes.huanggai.skill = "Bitter-Flesh Column"
	heroes.huanggai.zh_skill = "苦肉焚阵"
	_set_skill("huanggai", {"max_hp_cost":0.10, "damage_cost_ratio":0.33, "zhouyu_burn":6.0, "zhouyu_burn_cost_ratio":0.05, "sunjian_max_hp_cost":0.15, "sunjian_damage_cost_ratio":0.45}, "苦肉焚阵：消耗自身10%最大生命，对随机敌方一列造成消耗生命33%的伤害。", "Bitter-Flesh Column: Spend max HP to damage an enemy column.")
	heroes.sunshangxiang.skill = "Heroine's Growing Volley"
	heroes.sunshangxiang.zh_skill = "枭姬叠势"
	_set_skill("sunshangxiang", {"mult":1.0, "hit_count":1, "skill_gain_per_cast":1.0, "ally_death_skill_gain":3.0, "sun_legacy_mult":1.5, "sun_legacy_hit_count":2, "sun_legacy_skill_gain_per_cast":1.0, "sun_legacy_cooldown":6.0}, "枭姬叠势：随机攻击一名敌军；每次释放后自身兵略值提高1点。", "Heroine's Growing Volley: Strike a random enemy and gain Strategy after casting.")
	_set_skill("xusheng", {"mult":0.65, "stun":0.8, "slow":0.20, "slow_time":4.0}, "宿卫水阵：冲击一排并留下4秒水阵，使该排行动速度降低20%。", "Guardian Water Formation: Strike a row and slow its gauge gain.")

	heroes.lvbu.skill = "Peerless Sweep"
	heroes.lvbu.zh_skill = "无双横扫"
	_set_skill("lvbu", {"mult":1.75, "dongzhuo_heal":0.40, "missing_hp_step":0.10, "diaochan_bonus_per_step":0.04, "chengong_repeat_chance":0.50}, "无双横扫：攻击正前方敌方前军及其左右相邻格，造成175%兵略值伤害。", "Peerless Sweep: Strike the facing enemy vanguard and its neighbors for 175% Strategy damage.")
	heroes.dongzhuo.skill = "Tyrant's Might"
	heroes.dongzhuo.zh_skill = "暴君横征"
	_set_skill("dongzhuo", {"current_hp_ratio":0.07, "lvbu_current_hp_ratio":0.15, "diaochan_max_hp_bonus":0.50}, "暴君横征：对正前方敌军造成自身当前生命值7%的物理伤害。", "Tyrant's Might: Deal damage equal to 7% of current HP.")
	heroes.dongzhuo.range = 2
	heroes.diaochan.skill = "Beauty's Scheme"
	heroes.diaochan.zh_skill = "美人离间"
	_set_skill("diaochan", {"duration":3.0, "dongzhuo_duration":6.0, "forced_attack_interval":1.0, "forced_attack_mult":1.0, "target_mode":"random"}, "美人离间：随机魅惑一名敌军3秒，使其行动条停止。", "Beauty's Scheme: Charm a random enemy for 3s.")
	heroes.chengong.skill = "Measured Formation"
	heroes.chengong.zh_skill = "智迟谋速"
	heroes.chengong.ability = "passive"
	_set_skill("chengong", {"cooldown_reduction":1.0, "lvbu_bonus_reduction":1.0, "gaoshun_bonus_reduction":1.0}, "智迟谋速（被动）：陈宫及其同列友军的技能冷却减少1秒。", "Measured Formation: Chen Gong and allies in his column reduce cooldowns.")
	heroes.gaoshun.skill = "Formation Resolve"
	heroes.gaoshun.zh_skill = "陷阵之志"
	_set_skill("gaoshun", {"target_count":2, "mult":1.50, "vulnerable":0.40, "vulnerable_time":3.0, "lvbu_bonus_targets":2, "chengong_bonus_duration":3.0}, "陷阵之志：随机攻击两名敌军，造成150%兵略值伤害并施加3秒易碎。", "Formation Resolve: Strike 2 enemies for 150% Strategy and make them Fragile.")
	heroes.yanliang.skill = "Hebei Fierce Assault"
	heroes.yanliang.zh_skill = "河北猛袭"
	_set_skill("yanliang", {"target_count":2, "wenchou_bonus_targets":2, "mult":1.75, "hit_bonus":0.15, "hit_bonus_cap":3.0}, "河北猛袭：随机攻击两名敌方中军或后军，造成175%兵略值伤害。", "Hebei Fierce Assault: Strike 2 enemy midguards or rearguards for 175% Strategy.")
	heroes.wenchou.skill = "Hebei Breakthrough"
	heroes.wenchou.zh_skill = "河北破阵"
	_set_skill("wenchou", {"target_count":2, "yanliang_bonus_targets":2, "max_hp_ratio":0.02, "hit_bonus":0.15, "hit_bonus_cap":3.0}, "河北破阵：随机攻击两名敌方前军或中军，造成其最大生命值2%的伤害。", "Hebei Breakthrough: Strike 2 enemies for 2% max HP.")
	heroes.gaolan.skill = "Column Valor"
	heroes.gaolan.zh_skill = "列阵扬威"
	heroes.gaolan.ability = "passive"
	_set_skill("gaolan", {"skill_bonus":20.0, "zhanghe_skill_bonus":40.0, "four_pillars_skill_bonus":40.0}, "列阵扬威（被动）：高览同列友军的兵略值增加20点。", "Column Valor: Allies in Gao Lan's column gain 20 Strategy.")
	heroes.qunzhanghe.skill = "Hebei Ward"
	heroes.qunzhanghe.zh_skill = "河北护阵"
	_set_skill("qunzhanghe", {"target_count":2, "gaolan_bonus_targets":2, "four_pillars_bonus_targets":2, "shield_mult":2.0, "four_pillars_shield_mult":4.0}, "河北护阵：为当前生命值最低的两名友军施加可抵消200%兵略值伤害的护盾。", "Hebei Ward: Shield the 2 allies with the lowest current HP for 200% Strategy.")
	heroes.huatuo.skill = "Threefold Remedy"
	heroes.huatuo.zh_skill = "青囊三济"
	_set_skill("huatuo", {"target_count":3, "heal_mult":1.0, "zuoci_bonus_mult":0.5}, "青囊三济：治疗当前生命值最低的三名友军，各恢复100%兵略值生命。", "Threefold Remedy: Heal the three allies with the lowest current HP for 100% Strategy each.")
	heroes.yuji.skill = "Venomous Immortal Art"
	heroes.yuji.zh_skill = "蛊毒仙术"
	_set_skill("yuji", {"target_count":2, "poison_ratio":0.005, "duration":4.0, "bond_bonus_targets":1, "bond_bonus_duration":1.0}, "蛊毒仙术：随机使两名敌军中毒4秒，每秒损失0.5%最大生命。", "Venomous Immortal Art: Poison two random enemies for 4s.")
	heroes.zuoci.skill = "Immortal Aid"
	heroes.zuoci.zh_skill = "遁甲济世"
	_set_skill("zuoci", {"target_count":2, "heal_mult":1.5, "huatuo_bonus_mult":0.5, "thunder_mult":1.5}, "遁甲济世：治疗当前生命值最低的两名友军，各恢复150%兵略值生命。", "Immortal Aid: Heal two allies for 150% Strategy each.")
	heroes.zhangjiao.skill = "Yellow Sky Thunder"
	heroes.zhangjiao.zh_skill = "黄天雷引"
	_set_skill("zhangjiao", {"target_count":2, "mult":2.0, "zhangliang_bonus_mult":0.5, "zhangbao_bonus_targets":1, "zhangbao_stun_chance":0.5, "zhangbao_stun":1.0}, "黄天雷引：召唤雷电随机攻击两名敌军，各造成200%兵略值伤害。", "Yellow Sky Thunder: Call lightning on two random enemies for 200% Strategy damage each.")
	heroes.zhangliang.skill = "Yellow Sky Weakening"
	heroes.zhangliang.zh_skill = "人公虚弱"
	_set_skill("zhangliang", {"target_count":2, "duration":5.0, "skill_reduction":0.5, "bond_bonus_targets":1}, "人公虚弱：随机使两名敌军虚弱5秒，兵略值降低50%。", "Yellow Sky Weakening: Weaken two random enemies for 5s, reducing Strategy by 50%.")
	heroes.zhangbao.skill = "Earth General Detonation"
	heroes.zhangbao.zh_skill = "地公雷爆"
	heroes.zhangbao.ability = "passive"
	_set_skill("zhangbao", {"target_count":2, "death_mult":2.0, "base_revives":1, "zhangjiao_splash_mult":0.5, "zhangliang_bonus_revives":1}, "地公雷爆（被动）：阵亡时随机攻击两名敌军，各造成200%兵略值伤害，随后可满血复生一次。", "Earth General Detonation: Strike two enemies for 200% Strategy on death, then revive once.")

func _configure_combat_profiles() -> void:
	for hero_id in HERO_COOLDOWN_DEFAULTS:
		heroes[hero_id].cooldown = float(HERO_COOLDOWN_DEFAULTS[hero_id])
	_apply_default_skill_cooldowns()
	heroes.liubei.range = 3
	heroes.guanyu.range = 1
	heroes.zhangfei.range = 2
	heroes.zhaoyun.range = 2
	heroes.huangzhong.range = 3
	heroes.machao.range = 2
	heroes.madai.range = 3
	heroes.weiyan.range = 1
	heroes.weiyan.erase("all_rows")

func _apply_default_skill_cooldowns() -> void:
	for hero_id in heroes:
		if not HERO_COOLDOWN_DEFAULTS.has(hero_id):
			heroes[hero_id].cooldown = maxf(DEFAULT_Strategy_COOLDOWN, float(heroes[hero_id].cooldown))

func _minimum_skill_cooldown(_hero_id: String) -> float:
	return COOLDOWN_INPUT_MIN

func t(zh: String, en: String) -> String:
	return zh if language == "zh" else en

func _star_stat_multiplier(level: int) -> float:
	return 1.0

func _star_effect_multiplier(level: int) -> float:
	return 1.0

func _unit_effect_multiplier(unit: Dictionary) -> float:
	return _star_effect_multiplier(int(unit.get("level", 1)))

func _hero_name(id: String) -> String:
	return heroes[id][language]

func _faction_name(faction: String) -> String:
	var names := {"shu":["蜀", "Shu"], "wei":["魏", "Wei"], "wu":["吴", "Wu"], "qun":["群", "Qun"]}
	return names[faction][0 if language == "zh" else 1]

func _army_name(tier: int) -> String:
	var names := {1:["前军", "Vanguard"], 2:["中军", "Midguard"], 3:["后军", "Rearguard"]}
	return names[clampi(tier, 1, 3)][0 if language == "zh" else 1]

func _hero_army_name(hero_id: String) -> String:
	if bool(heroes.get(hero_id, {}).get("all_rows", false)):
		return t("全军", "Any Rank")
	return _army_name(int(heroes[hero_id].range))

func _phase_name() -> String:
	var map := {"draft":["选将", "DRAFT"], "placement":["布阵", "FORMATION"], "combat":["战斗", "COMBAT"], "finished":["结算", "RESULT"]}
	return map[phase][0 if language == "zh" else 1]

func _action_odds(hero_id: String) -> String:
	var hero: Dictionary = heroes[hero_id]
	return t("每 %.1f 秒读条完成,释放技能" % float(hero.cooldown), "Skill cast every %.1fs when the gauge fills" % float(hero.cooldown))

func _true_damage_text(value: String) -> String:
	return value

func _reserve_units() -> Array:
	return player_units.filter(func(unit): return unit.alive and unit.row < 0)

func _roster_has_all(units: Array, ids: Array) -> bool:
	for hero_id in ids:
		if not units.any(func(unit): return unit.alive and unit.row >= 0 and unit.hero_id == hero_id): return false
	return true

func _roster_has_count(units: Array, ids: Array, required: int) -> bool:
	var present := {}
	for unit in units:
		if unit.alive and unit.row >= 0 and ids.has(unit.hero_id): present[str(unit.hero_id)] = true
	return present.size() >= required

func _make_roster_unit(team: String, hero_id: String) -> Dictionary:
	var hero: Dictionary = heroes[hero_id]
	return {
		"id":team + ":" + hero_id + ":" + str(rng.randi()), "hero_id":hero_id, "team":team, "level":1, "stat_mult":1.0,
		"row":-1, "col":-1, "hp":float(hero.hp), "max_hp":float(hero.hp), "alive":true,
		"action":0.0, "action_gain_mult":1.0, "shield":0.0, "burn":0.0, "burn_damage":0.0, "burn_clock":0.0, "burn_effects":[],
		"burn_missing_hp_scale":false, "fear":0.0, "fear_damage_ratio":0.0, "fear_clock":0.0,
		"freeze":0.0, "freeze_shatter_per_second":0.0,
		"poison":0.0, "poison_ratio":0.0, "poison_clock":0.0, "poison_source":"", "poison_effects":[],
		"stun":0.0, "charm":0.0, "damage_reduction":0.0, "damage_buff":0.0,
		"silence":0.0, "stealth":0.0, "slow":0.0, "slow_time":0.0,
		"vulnerable":0.0, "vulnerable_time":0.0, "grievous":0.0, "grievous_time":0.0, "strategy_mark":0.0, "zhuge_fire_mark":0.0, "spell_ward":0,
		"cast_count":0, "focus_target":"", "focus_stacks":0, "faction_tier":0,
		"bond_cooldown":0.0, "sunquan_initial_max_hp":0.0, "sunshangxiang_skill_bonus":0.0,
		"faction_damage_reduction":0.0, "faction_hp_bonus":0.0, "faction_control_bonus":0.0,
		"faction_cooldown_reduction":0.0, "shu_damage_stacks":0,
		"four_heroes":false, "lvmeng_ganning":false, "stealth_ambush_bonus_ready":false,
		"regen_per_second":0.0, "regen_time":0.0, "regen_clock":0.0, "regen_damage_reduction":0.0, "regen_source":"",
		"timed_damage_buff":0.0, "timed_damage_time":0.0, "timed_reduction":0.0, "timed_reduction_time":0.0,
		"timed_action_bonus":0.0, "timed_action_time":0.0,
		"rear_damage_reduction":0.0, "rear_damage_reduction_time":0.0,
		"front_damage_reduction":0.0, "front_damage_reduction_time":0.0,
		"all_lifesteal":0.0, "all_lifesteal_time":0.0,
		"skill_debuff":0.0, "kill_buff":0.0, "death_prevention":0.0,
		"heal_multiplier":1.0, "charm_multiplier":1.0, "current_hp_ratio":0.06,
		"skill_value_bonus":0.0, "timed_skill_value_bonus":0.0, "timed_skill_value_time":0.0, "liushan_aura_damage_bonus":0.0, "liushan_aura_lifesteal":0.0, "chain_effects":[], "four_pillars":false, "hebei_damage_stacks":0,
		"charm_forced_attack":false, "charm_attack_clock":0.0, "dongzhuo_diaochan_hp_bonus":0.0,
		"skill_debuff_time":0.0, "zhangbao_revives_used":0
	}

func _can_unit_use_row(unit: Dictionary, row: int) -> bool:
	if bool(heroes[unit.hero_id].get("all_rows", false)): return row >= 0 and row < BOARD_ROWS
	return int(heroes[unit.hero_id].range) != 1 or row == 0

func _unit_at(units: Array, row: int, col: int):
	for unit in units:
		if unit.alive and unit.row == row and unit.col == col: return unit
	return null

func _find_unit(units: Array, hero_id: String, unplaced := false):
	for unit in units:
		if unit.hero_id == hero_id and (not unplaced or unit.row < 0): return unit
	return null

func _find_by_id(units: Array, id: String):
	for unit in units:
		if unit.id == id: return unit
	return null
