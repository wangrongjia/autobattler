extends Control

const BOARD_COLUMNS := 5           # 棋盘列数(横向 5 格)
const BOARD_ROWS := 3              # 棋盘行数(纵向 3 行:前排 row0/中排 row1/后排 row2)
const RULER_MAX_HP := 50000        # 主公最大血量(主公血量归零则游戏结束)
const ROUND_LIMIT := 15            # 总关卡数(15 关备战 + 1 场最终决战)
const BATTLE_LIMIT := 30.0         # 每关战斗时长(秒),最终决战无此限制
const TICK := 0.2                  # 战斗循环间隔:每 0.2 秒"走一步"(推进行动条)
const ACTION_MAX := 100.0          # 行动条上限:从 0 涨到 100 时武将行动一次
const FACTION_BOND_TIERS: Array[int] = [2, 5, 8] # 四阵营统一羁绊档位
const DEFAULT_SKILL_COOLDOWN := 8.5 # 未单独配置武将的初始冷却；不是均衡实验室的调整下限
const COOLDOWN_INPUT_MIN := 0.0     # 均衡实验室允许设置为 0，战斗计算处另行防止除零
const HERO_COOLDOWN_DEFAULTS := {"liubei":4.0, "liushan":4.0, "zhangfei":6.5, "zhaoyun":4.5, "huangzhong":4.0, "machao":6.0, "zhugeliang":4.0, "dailaidongzhu":8.0, "weiyan":5.0, "madai":20.0, "sunquan":10.0, "sunshangxiang":8.0, "taishici":4.0, "ganning":8.0, "huanggai":10.0}
const HEALTH_SCALE := 12.0         # 全体基础血量由原来的 ×6 提高到 ×12，最终获得双倍血量
const RESERVE_LIMIT := 9           # 备战区(棋盘下方的替补区)最多放 9 名武将
const BOARD_LIMIT := BOARD_COLUMNS * BOARD_ROWS  # 棋盘总格数 = 15
const SAVE_PATH := "user://three_kingdoms_save.json"        # 存档文件路径(user:// 是玩家存档目录)
const SETTINGS_PATH := "user://three_kingdoms_settings.cfg" # 设置文件路径
const DRAFT_SIZE := 2              # 每次选将显示 2 名候选
const PICKS_PER_ROUND := 3         # 每关连续进行 3 轮二选一
const ENEMY_WAVES := [             # 15 关每关固定出现的敌方武将(每关 2 名)
	["zhaoyun", "huangzhong"], ["zhangliao", "yuejin"], ["lvmeng", "ganning"],
	["gaoshun", "chengong"], ["guanyu", "zhangfei"], ["simayi", "guojia"],
	["daqiao", "xiaoqiao"], ["yanliang", "wenchou"], ["menghuo", "zhurong"],
	["sunjian", "sunce"], ["zhanghe", "xuhuang"], ["yuji", "zhangjiao"],
	["zhugeliang", "pangtong"], ["sunquan", "sunshangxiang"], ["lvbu", "dongzhuo"]
]
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
var choices: Array = []            # 当前一轮二选一的候选武将 ID
var pending_unit_ids: Array[String] = []  # 待上阵的单位 ID(选完后需要玩家拖到棋盘上)
var chosen_this_round: Array[String] = [] # 本关三轮已经锁定的武将 ID
var draft_roster_baseline: Array = []     # 保留用于兼容旧存档
var draft_picks_remaining := PICKS_PER_ROUND  # 本关还能选几次(初始 3)
var refresh_charges := 0           # 保留用于兼容旧存档；二选一候选现在可独立免费刷新
var draft_refresh_available: Array[bool] = [true, true] # 当前二选一的每个位置各可刷新一次
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
var encyclopedia_star_level := 1   # 图鉴当前查看的星级(1/2/3 星)
var encyclopedia_bond_label: Label # 图鉴顶部的阵营羁绊说明
var encyclopedia_preview_overlay: Control # 图鉴武将放大预览层
var encyclopedia_preview_portrait: TextureRect # 放大预览中的完整武将立绘
var encyclopedia_preview_separator: Control # 放大预览中立绘与介绍之间的分隔线
var encyclopedia_preview_detail: Label # 放大预览右侧的完整图鉴介绍
var encyclopedia_preview_name: Label # 放大预览中的武将名
var encyclopedia_preview_counter: Label # 放大预览中的当前位置
var encyclopedia_preview_hero_ids: Array[String] = [] # 当前阵营可左右切换的武将
var encyclopedia_preview_index := 0 # 当前放大预览索引

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
var faction_setting_options: OptionButton  # 测试阵营过滤下拉框
var draft_faction_filter := ""     # 选将阵营过滤(空=全部, 或 shu/wei/wu/qun)

var heroes := {
	"liubei": {"zh":"刘备", "en":"Liu Bei", "f":"shu", "roles":["治疗", "辅助"], "hp":260, "skill_value":32, "cooldown":4.0, "range":4, "skill":"Benevolent Rule", "zh_skill":"仁德", "summary":"治疗生命最低的友军，并赋予减伤。", "en_summary":"Heals the weakest ally and grants damage reduction."},
	"guanyu": {"zh":"关羽", "en":"Guan Yu", "f":"shu", "roles":["战士", "爆发"], "hp":360, "skill_value":58, "cooldown":3.0, "range":1, "skill":"Green Dragon Cleave", "zh_skill":"青龙断阵", "summary":"斩击同列敌人；击杀后追击。", "en_summary":"Cleave enemies in a column; pursue after a kill."},
	"zhangfei": {"zh":"张飞", "en":"Zhang Fei", "f":"shu", "roles":["坦克", "辅助"], "hp":390, "skill_value":44, "cooldown":4.0, "range":1, "skill":"Roar of Yan", "zh_skill":"燕人怒吼", "summary":"开场为同排友军施加护盾。", "en_summary":"Grants shields to allies in his row at battle start."},
	"caocao": {"zh":"曹操", "en":"Cao Cao", "f":"wei", "roles":["坦克", "控制"], "hp":380, "skill_value":46, "cooldown":3.0, "range":1, "skill":"Cunning Counter", "zh_skill":"奸雄反制", "summary":"释放技能时有概率眩晕目标。", "en_summary":"His skill has a chance to stun the target."},
	"dianwei": {"zh":"典韦", "en":"Dian Wei", "f":"wei", "roles":["坦克", "战士"], "hp":365, "skill_value":52, "cooldown":3.0, "range":1, "skill":"Evil's Capture", "zh_skill":"恶来擒杀号", "summary":"重创最远的敌军并降低其技能伤害。", "en_summary":"Strikes the farthest enemy and reduces its skill damage."},
	"xuchu": {"zh":"许褚", "en":"Xu Chu", "f":"wei", "roles":["战士"], "hp":350, "skill_value":60, "cooldown":3.0, "range":1, "skill":"Tiger Hammer", "zh_skill":"虎痴重锤", "summary":"当前生命越高，技能追加伤害越高。", "en_summary":"His skill deals bonus damage based on current health."},
	"zhouyu": {"zh":"周瑜", "en":"Zhou Yu", "f":"wu", "roles":["法师", "灼烧"], "hp":225, "skill_value":72, "cooldown":4.0, "range":4, "skill":"Red Cliffs", "zh_skill":"赤壁点火", "summary":"点燃敌方一整排。", "en_summary":"Ignites an entire enemy row."},
	"luxun": {"zh":"陆逊", "en":"Lu Xun", "f":"wu", "roles":["法师", "爆发"], "hp":235, "skill_value":68, "cooldown":4.0, "range":4, "skill":"Flames of Camp", "zh_skill":"火烧连营", "summary":"火球命中目标并弹射邻格。", "en_summary":"A fireball hits a target and bounces nearby."},
	"lusu": {"zh":"鲁肃", "en":"Lu Su", "f":"wu", "roles":["辅助", "治疗"], "hp":260, "skill_value":36, "cooldown":4.0, "range":4, "skill":"Alliance", "zh_skill":"连横稳阵", "summary":"治疗当前生命总量最低的友军并提高其最大生命。", "en_summary":"Treats the ally with the lowest current HP total and raises max HP."},
	"lvbu": {"zh":"吕布", "en":"Lu Bu", "f":"qun", "roles":["战士", "收割"], "hp":390, "skill_value":70, "cooldown":3.0, "range":2, "skill":"Peerless", "zh_skill":"无双横扫", "summary":"有概率横扫敌方前排。", "en_summary":"May sweep the entire enemy front row."},
	"diaochan": {"zh":"貂蝉", "en":"Diao Chan", "f":"qun", "roles":["控制", "辅助"], "hp":210, "skill_value":32, "cooldown":4.0, "range":4, "skill":"Beauty's Scheme", "zh_skill":"美人离间", "summary":"魅惑敌方技能数值最高单位。", "en_summary":"Charms the enemy with the highest skill value."},
	"dongzhuo": {"zh":"董卓", "en":"Dong Zhuo", "f":"qun", "roles":["战士", "坦克"], "hp":390, "skill_value":52, "cooldown":3.0, "range":2, "skill":"Tyrant's Levy", "zh_skill":"暴君横征", "summary":"按当前生命追加物理伤害。", "en_summary":"Deals bonus physical damage based on current health."}
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
	_register_hero("zhaoyun", "赵云", "Zhao Yun", "shu", ["战士", "爆发"], 245, 54, 2.8, 1, "Seven Charges", "七进七出", "strike", {"mult":1.65}, "突击后排目标并获得短时减伤。", "Strike a backline target and gain brief damage reduction.")
	_register_hero("huangzhong", "黄忠", "Huang Zhong", "shu", ["战士", "爆发"], 180, 61, 2.7, 4, "Piercing Arrow", "百步穿杨", "strike", {"mult":2.0}, "造成200%技能强度物理伤害。与魏延组成飞火流星后，对近战目标额外提高50%伤害。", "Deal 200% SKILL physical damage. Flying Meteor with Wei Yan grants +50% damage against melee.")
	_register_hero("machao", "马超", "Ma Chao", "shu", ["战士", "爆发"], 250, 55, 2.9, 2, "Iron Cavalry", "西凉铁骑", "row", {"mult":1.25}, "冲击随机敌排，对整排造成125%技能强度物理伤害。", "Charge a random enemy row for 125% SKILL physical damage.")
	_register_hero("liushan", "刘禅", "Liu Shan", "shu", ["辅助"], 195, 31, 4.0, 2, "Royal Encouragement", "蜀主鼓舞", "buff_column", {"damage_by_star":[0.25, 0.35, 0.55], "duration":4.0, "seven_lifesteal":0.30}, "读条完成后，使同列前军伤害提高25%/35%/55%，持续4秒。与刘备羁绊时同时强化同列后军；与赵云组成七进七出时，被强化友军额外获得30%全能吸血。冷却4秒。", "On gauge completion, grant the allied vanguard in this column +25%/35%/55% damage for 4s. Liu Bei also includes the rearguard; Seven Charges with Zhao Yun additionally grants empowered allies 30% omnivamp. 4s cooldown.")
	_register_hero("zhugeliang", "诸葛亮", "Zhuge Liang", "shu", ["法师", "爆发"], 190, 66, 4.0, 4, "Eight-Formation Stratagem", "八阵奇谋", "row_magic", {"mult":2.0}, "随机选择敌方格子，对目标及同列相邻格造成200%技能强度法术伤害。冷却4秒。", "Choose a random enemy tile and deal 200% SKILL magic damage to it and its vertical neighbors. 4s cooldown.")
	_register_hero("jiangwei", "姜维", "Jiang Wei", "shu", ["坦克", "法师"], 300, 48, 3.0, 1, "Northern Expedition", "北伐", "strike_magic", {"mult":1.60, "reduction":0.15, "bond_reduction":0.30, "reduction_duration":5.0, "diagonal_mult":0.80, "diagonal_count":2}, "造成160%技能强度魔法伤害，并获得15%减伤，持续5秒。", "Deal 160% SKILL magic damage and gain 15% damage reduction for 5s.")
	_register_hero("menghuo", "孟获", "Meng Huo", "shu", ["坦克"], 360, 43, 3.6, 1, "Barbarian King", "蛮王震地", "row", {"mult":1.05, "stun":0.8, "aftershock_mult":0.60, "burning_damage_mult":1.40, "burning_stun":1.20, "bond_action_reduction":20.0}, "震击随机敌排，造成105%技能强度物理伤害并眩晕0.8秒。", "Strike a random row for 105% SKILL physical damage and stun for 0.8s.")
	_register_hero("zhurong", "祝融", "Zhurong", "shu", ["战士", "灼烧"], 215, 51, 3.2, 4, "Flame Blade", "火神飞刃", "strike_magic", {"mult":1.45, "burn":4.0, "burn_ratio":0.30, "bounce_mult":0.70, "bond_burn":6.0, "bond_burn_ratio":0.40}, "造成145%技能强度魔法伤害并灼烧4秒，每秒造成30%技能强度伤害。", "Deal 145% SKILL magic damage and burn for 4s at 30% SKILL per second.")
	_register_hero("dailaidongzhu", "带来洞主", "Dailai Dongzhu", "shu", ["坦克", "控制"], 320, 48, 8.0, 2, "Savage-Bone Wolf Assault", "蛮骨狼袭", "signature", {"mult":1.8, "action_reduction_by_star":[25.0, 35.0, 50.0], "target_mode":"highest_action", "column_splash_mult":0.90, "splash_action_reduction":15.0, "burning_damage_mult":1.20, "bond_burn":4.0, "bond_burn_ratio":0.30}, "锁定可攻击范围内行动条最高的敌人，造成180%技能强度物理伤害，并按1/2/3星使其行动条降低25%/35%/50%。冷却8秒。", "Lock the reachable enemy with the highest gauge, deal 180% SKILL physical damage, and reduce its gauge by 25%/35%/50% at stars 1/2/3. 8s cooldown.")
	_register_hero("weiyan", "魏延", "Wei Yan", "shu", ["坦克", "收割"], 315, 50, 2.9, 1, "Rebel Fang", "狂骨", "drain", {"mult":1.5, "heal":0.35}, "造成150%技能强度物理伤害，并回复实际伤害的35%。", "Deal 150% SKILL physical damage and heal for 35% of actual damage.")
	_register_hero("madai", "马岱", "Ma Dai", "shu", ["战士", "爆发"], 215, 55, 3.0, 4, "Hidden Arrow", "潜袭冷箭", "strike", {"mult":1.75}, "造成175%技能强度物理伤害；对已受伤目标提高至225%。", "Deal 175% SKILL physical damage, increased to 225% against wounded targets.")
	_register_hero("pangtong", "庞统", "Pang Tong", "shu", ["法师", "控制"], 185, 62, 3.8, 4, "Chain Scheme", "连环计", "control", {"stun":2.0, "mult":0.8, "bond_mult":1.0, "bond_stun":2.5}, "造成80%技能强度魔法伤害并锁住目标行动条2秒。", "Deal 80% SKILL magic damage and freeze the target's gauge for 2s.")

	_register_hero("zhangliao", "张辽", "Zhang Liao", "wei", ["战士", "爆发"], 290, 53, 3.3, 2, "Charging Wheel", "逍遥津突袭", "row", {"mult":1.35}, "贯穿随机敌排，造成135%技能强度物理伤害。", "Pierce a random enemy row for 135% SKILL physical damage.")
	_register_hero("yuejin", "乐进", "Yue Jin", "wei", ["战士", "爆发"], 185, 45, 3.0, 4, "Five Arrows", "五矢齐发", "multi", {"count":3, "mult":0.75}, "连续射出3箭，每箭造成75%技能强度物理伤害并独立选择格子。", "Fire 3 arrows, each targeting independently for 75% SKILL physical damage.")
	_register_hero("zhanghe", "张郃", "Zhang He", "wei", ["控制", "战士"], 315, 47, 2.7, 1, "Stunning Spear", "破阵枪", "control", {"stun":1.5, "mult":1.0}, "造成100%技能强度物理伤害并眩晕1.5秒。", "Deal 100% SKILL physical damage and stun for 1.5s.")
	_register_hero("xuhuang", "徐晃", "Xu Huang", "wei", ["控制", "坦克"], 350, 42, 3.5, 1, "Heaven Lifter", "撼地飞斧", "row_magic", {"mult":0.9, "stun":1.5}, "对随机敌排造成90%技能强度魔法伤害并眩晕1.5秒。", "Deal 90% SKILL magic damage to a row and stun for 1.5s.")
	_register_hero("yujin", "于禁", "Yu Jin", "wei", ["坦克"], 345, 40, 3.5, 1, "Steadfast Formation", "毅重军阵", "shield_single", {"mult":1.20, "flat":35.0}, "为当前生命比例最低的友军提供120%技能强度+35点护盾。", "Shield the lowest-HP ally for 120% SKILL + 35.")
	_register_hero("xiahouyuan", "夏侯渊", "Xiahou Yuan", "wei", ["控制", "战士"], 190, 57, 2.7, 4, "Swift Arrow", "神速箭", "strike", {"mult":1.4, "stun":1.0}, "造成140%技能强度物理伤害并眩晕1秒。", "Deal 140% SKILL physical damage and stun for 1s.")
	_register_hero("caoren", "曹仁", "Cao Ren", "wei", ["坦克", "辅助"], 390, 39, 3.7, 1, "Iron Wall", "据守樊城", "shield_single", {"mult":1.60, "flat":50.0}, "为当前生命比例最低的友军提供160%技能强度+50点护盾；曹仁自身获得10%减伤。", "Shield the lowest-HP ally for 160% SKILL + 50; Cao Ren gains 10% damage reduction.")
	_register_hero("xiahoudun", "夏侯惇", "Xiahou Dun", "wei", ["坦克", "反击"], 410, 46, 3.4, 1, "One-Eyed Retaliation", "刚烈反击", "drain", {"mult":1.35, "heal":0.25}, "造成135%技能强度物理伤害，并回复实际伤害25%。", "Deal 135% SKILL physical damage and heal for 25% of actual damage.")
	_register_hero("guojia", "郭嘉", "Guo Jia", "wei", ["控制", "法师"], 175, 58, 4.1, 4, "Frozen Plan", "遗计冰封", "control", {"stun":2.5, "mult":0.6}, "造成60%技能强度魔法伤害并冻结目标2.5秒。", "Deal 60% SKILL magic damage and freeze the target for 2.5s.")
	_register_hero("simayi", "司马懿", "Sima Yi", "wei", ["法师", "爆发"], 190, 69, 4.0, 4, "Thunder Scheme", "雷霆谋断", "multi_magic", {"count":2, "mult":1.45}, "召唤2道雷击，每道造成145%技能强度魔法伤害并随机选格。", "Call 2 lightning strikes, each choosing a random tile for 145% SKILL magic damage.")
	_register_hero("xunyu", "荀彧", "Xun Yu", "wei", ["辅助", "控制"], 200, 34, 3.8, 4, "Royal Recommendation", "王佐举荐", "buff_two", {"damage":0.18, "action":0.12}, "举荐两名当前生命比例最低的友军，使其伤害提高18%、行动条速度提高12%。", "Empower the two lowest-HP allies with +18% damage and +12% gauge speed.")

	_register_hero("lvmeng", "吕蒙", "Lu Meng", "wu", ["战士", "爆发"], 205, 61, 2.8, 1, "White-Robed Raid", "白衣渡江", "strike", {"mult":2.1}, "突袭造成210%技能强度物理伤害；对远程目标额外提高30%。", "Ambush for 210% SKILL physical damage, +30% against ranged targets.")
	_register_hero("sunjian", "孙坚", "Sun Jian", "wu", ["战士", "爆发"], 275, 52, 3.0, 1, "Tiger's First Strike", "江东猛虎", "strike", {"mult":1.9}, "造成190%技能强度物理伤害；本场第一次释放提高至260%。", "Deal 190% SKILL physical damage; the first cast is increased to 260%.")
	_register_hero("sunce", "孙策", "Sun Ce", "wu", ["战士", "收割"], 310, 59, 2.9, 1, "Little Conqueror", "小霸王", "drain", {"mult":1.55, "heal":0.40}, "造成155%技能强度物理伤害并回复实际伤害40%。生命越低，羁绊强化越高。", "Deal 155% SKILL physical damage and heal for 40%. Bonds scale as HP falls.")
	_register_hero("sunquan", "孙权", "Sun Quan", "wu", ["辅助", "战士"], 285, 44, 10.0, 3, "Jiangdong Balance", "江东制衡", "signature", {"current_hp_damage_ratio":0.08, "max_hp_gain":200.0, "max_hp_cap_mult":2.0, "missing_hp_heal_ratio":0.10}, "随机对一名敌军造成其当前生命8%的伤害，提高自身最大生命并恢复已损生命。", "Damage a random enemy based on current HP, then grow max HP and restore missing HP.")
	_register_hero("sunshangxiang", "孙尚香", "Sun Shangxiang", "wu", ["战士", "爆发"], 180, 80, 8.0, 4, "Heroine's Growing Volley", "枭姬叠势", "signature", {"hit_count":1, "mult":1.0, "skill_gain_per_cast":1.0, "ally_death_skill_gain":5.0}, "随机攻击一名敌军；每次施法和友军阵亡都会永久提高自身技能强度。", "Strike a random enemy; casts and allied deaths permanently increase SKILL.")
	_register_hero("daqiao", "大乔", "Da Qiao", "wu", ["治疗", "辅助"], 175, 33, 3.7, 4, "River Blossom", "国色流离", "heal", {"mult":1.5, "flat":95.0, "bond_missing_hp_step":0.10, "bond_heal_bonus_per_step":0.04}, "治疗当前生命比例最低的友军。与孙策组成江东佳偶后，目标每损失10%生命，本次受到的治疗提高4%。", "Heal the lowest-HP-ratio ally. With Sun Ce, the target gains 4% healing received per 10% HP missing.")
	_register_hero("xiaoqiao", "小乔", "Xiao Qiao", "wu", ["辅助", "控制"], 165, 35, 3.5, 4, "Gentle Breeze", "天香缓阵", "signature", {"target_count":2, "slow":0.35, "slow_time":6.0}, "随机选择两名敌方后军，使其行动条速度降低35%，持续6秒。", "Slow two random enemy rearguards by 35% for 6s.")
	_register_hero("taishici", "太史慈", "Taishi Ci", "wu", ["战士", "爆发"], 250, 52, 4.0, 2, "Blazing Twin Halberds", "神亭烈戟", "signature", {"target_count":2, "mult":1.50, "burn":5.0, "burn_ratio":0.20, "sunce_target_count":3, "ganning_burning_mult":3.0}, "攻击射程内行动条最高的两名敌人，造成150%技能强度伤害并施加5秒灼烧。", "Strike the two reachable enemies with the highest gauges for 150% SKILL and burn them for 5s.")
	_register_hero("dingfeng", "丁奉", "Ding Feng", "wu", ["坦克", "控制"], 335, 46, 8.5, 1, "Snowbound Short Blades", "雪中奋短兵", "signature", {"mult":1.30, "action_reduction":25.0, "bond_splash_mult":0.70, "bond_splash_action_reduction":15.0}, "攻击射程内行动条最高的敌人，造成130%技能强度物理伤害并压退25%行动条。", "Strike the reachable enemy with the highest gauge for 130% SKILL physical damage and push its gauge back by 25%.")
	_register_hero("xusheng", "徐盛", "Xu Sheng", "wu", ["坦克", "控制"], 330, 43, 3.2, 1, "Breaking Waves", "疑城水阵", "row_magic", {"mult":0.85, "stun":1.2}, "对随机敌排造成85%技能强度魔法伤害并减速1.2秒。", "Deal 85% SKILL magic damage to a row and disable it for 1.2s.")
	_register_hero("ganning", "甘宁", "Gan Ning", "wu", ["战士", "爆发"], 225, 63, 8.0, 2, "Bell-Raider Twin Assault", "锦帆并击", "signature", {"mult":1.50, "taishici_mult":2.50, "lvmeng_low_hp_bonus":0.50}, "自身与左侧友军分别攻击随机敌方后军，友军协击不消耗行动条。", "Gan Ning and his left ally each strike a random enemy rearguard; the ally assist costs no gauge.")
	_register_hero("huanggai", "黄盖", "Huang Gai", "wu", ["坦克", "爆发"], 350, 48, 10.0, 1, "Bitter-Flesh Column", "苦肉焚阵", "signature", {"max_hp_cost":0.10, "damage_cost_ratio":0.33, "zhouyu_burn":6.0, "zhouyu_burn_cost_ratio":0.05, "sunjian_max_hp_cost":0.15, "sunjian_damage_cost_ratio":0.45}, "消耗10%最大生命，对随机敌方一列造成消耗生命33%的伤害。", "Spend 10% max HP to damage a random enemy column for 33% of HP spent.")

	_register_hero("gaoshun", "高顺", "Gao Shun", "qun", ["坦克", "辅助"], 365, 44, 3.4, 1, "Camp Crusher", "陷阵营", "shield_row", {"mult":1.00, "flat":25.0}, "为自身同排友军提供100%技能强度+25点护盾。", "Shield allies in his row for 100% SKILL + 25.")
	_register_hero("chengong", "陈宫", "Chen Gong", "qun", ["辅助", "战士"], 190, 49, 3.0, 4, "Measured Assault", "智迟谋速", "buff_two", {"damage":0.15, "action":0.15}, "强化两名当前生命比例最低的友军，使其伤害与行动条速度提高15%。", "Empower the two lowest-HP allies with +15% damage and gauge speed.")
	_register_hero("yanliang", "颜良", "Yan Liang", "qun", ["坦克", "法师"], 350, 47, 3.1, 1, "Hebei Retaliation", "河北反击", "multi_magic", {"count":2, "mult":0.9}, "反击2个随机格，每次造成90%技能强度魔法伤害。", "Counter 2 random tiles for 90% SKILL magic damage each.")
	_register_hero("wenchou", "文丑", "Wen Chou", "qun", ["坦克", "反击"], 325, 49, 3.1, 1, "Reflected Edge", "返锋", "shield_single", {"mult":1.30, "flat":35.0}, "为当前生命比例最低的友军提供130%技能强度+35点护盾。", "Shield the lowest-HP ally for 130% SKILL + 35.")
	_register_hero("qunzhanghe", "群张郃", "Zhang He (Qun)", "qun", ["辅助", "坦克"], 300, 41, 3.2, 1, "Purple Ward", "紫盾", "shield_column", {"mult":1.20, "flat":30.0}, "为自身同列友军提供120%技能强度+30点护盾。", "Shield allies in his column for 120% SKILL + 30.")
	_register_hero("gaolan", "高览", "Gao Lan", "qun", ["辅助", "法师"], 245, 50, 3.0, 3, "Arcane Blades", "法刃加持", "buff_row_melee", {"damage":0.20}, "使自身同排的近战友军伤害提高20%。", "Increase damage of melee allies in his row by 20%.")
	_register_hero("huatuo", "华佗", "Hua Tuo", "qun", ["治疗", "辅助"], 190, 32, 3.8, 4, "Green Remedy", "青囊济世", "heal_team", {"ratio":0.10}, "治疗全体友军各自最大生命10%，并清除技能伤害降低效果。", "Heal all allies for 10% max HP and remove skill-damage reduction.")
	_register_hero("yuji", "于吉", "Yu Ji", "qun", ["法师", "收割"], 215, 59, 3.7, 4, "Fallen Detonation", "亡魂爆破", "row_magic", {"mult":1.35}, "对随机敌排造成135%技能强度魔法伤害；每名已阵亡友军使伤害+15%。", "Deal 135% SKILL magic damage to a row; +15% per fallen ally.")
	_register_hero("zhangjiao", "张角", "Zhang Jiao", "qun", ["法师", "辅助"], 230, 62, 4.0, 4, "Yellow Heaven", "苍天已死", "multi_magic", {"count":3, "mult":0.75}, "召唤3道雷击，每道造成75%技能强度魔法伤害。", "Call 3 lightning strikes for 75% SKILL magic damage each.")
	_register_hero("yuanshao", "袁绍", "Yuan Shao", "qun", ["战士", "辅助"], 210, 54, 3.0, 4, "Coalition Banner", "诸侯盟主", "buff_self", {"damage":0.10, "faction_scale":true}, "每存在一个至少2人的阵营，自身伤害提高10%，最多40%。", "For each faction with at least 2 units, increase his own damage by 10%, up to 40%.")
	_register_hero("yuanshu", "袁术", "Yuan Shu", "qun", ["法师", "爆发"], 205, 57, 3.6, 4, "Imperial Volley", "伪帝连珠", "multi_magic", {"count":4, "mult":0.65}, "发射4枚法术弹，每枚造成65%技能强度魔法伤害并随机选格。", "Fire 4 magic bolts, each targeting a random tile for 65% SKILL magic damage.")

func _register_hero(id: String, zh: String, en: String, faction: String, roles: Array, hp: int, skill_value: int, cooldown: float, range_tier: int, skill: String, zh_skill: String, ability: String, params: Dictionary, detail_zh: String, detail_en: String) -> void:
	heroes[id] = {"zh":zh, "en":en, "f":faction, "roles":roles, "hp":hp, "skill_value":skill_value, "cooldown":maxf(COOLDOWN_INPUT_MIN, cooldown), "range":range_tier, "skill":skill, "zh_skill":zh_skill, "summary":detail_zh, "en_summary":detail_en, "ability":ability, "ability_params":params, "detail_zh":detail_zh, "detail_en":detail_en}

const FACTION_COLORS := {"shu": Color("#4ca968"), "wei": Color("#4f79c5"), "wu": Color("#d2644f"), "qun": Color("#a66dc4")}

func _rebalance_role_stats() -> void:
	for hero_id in heroes:
		var hero: Dictionary = heroes[hero_id]
		if not hero.has("ability_params"): hero.ability_params = {}
		if not hero.has("ability"): hero.ability = "signature"
		hero.range = clampi(int(hero.range), 1, 3)
		if int(hero.range) >= 3:
			var ranged_cap := 38 if hero.roles.any(func(role): return role in ["辅助", "治疗", "控制"]) else 46
			if hero.roles.has("法师"): ranged_cap = min(ranged_cap, 44)
			hero.skill_value = min(int(hero.skill_value), ranged_cap)
	heroes.huangzhong.skill_value = 46
	heroes.huangzhong.ability_params.mult = 1.55
	heroes.huangzhong.detail_zh = "造成155%技能强度物理伤害。与魏延组成飞火流星后，箭击有50%概率造成双倍伤害。"
	heroes.huangzhong.detail_en = "Deal 155% SKILL physical damage. Flying Meteor with Wei Yan gives each shot a 50% chance to deal double damage."
	heroes.huangzhong.summary = heroes.huangzhong.detail_zh
	heroes.huangzhong.en_summary = heroes.huangzhong.detail_en
	for id in ["lvmeng", "ganning"]: heroes[id].roles = ["刺客", "爆发"]
	heroes.lvmeng.skill_value = 50
	heroes.lvmeng.cooldown = 3.20
	heroes.lvmeng.ability_params.mult = 1.55
	heroes.lvmeng.detail_zh = "突袭造成155%技能强度物理伤害；对远程目标额外提高20%。"
	heroes.lvmeng.detail_en = "Ambush for 155% SKILL physical damage, +20% against ranged targets."
	heroes.lvmeng.summary = heroes.lvmeng.detail_zh
	heroes.lvmeng.en_summary = heroes.lvmeng.detail_en
	heroes.ganning.skill_value = 52
	heroes.ganning.cooldown = 3.10
	heroes.ganning.ability_params.mult = 1.65
	heroes.ganning.detail_zh = "奇袭造成165%技能强度物理伤害；奇袭羁绊只强化技能机制，不再提供超高持续输出。"
	heroes.ganning.detail_en = "Raid for 165% SKILL physical damage; Ambush improves skill mechanics instead of sustained DPS."
	heroes.ganning.summary = heroes.ganning.detail_zh
	heroes.ganning.en_summary = heroes.ganning.detail_en
	_configure_signature_skill_params()

func _configure_signature_skill_params() -> void:
	var signature_params := {
		"liubei":{"duration":4.0, "heal_ratio":2.0},
		"guanyu":{"mult":1.8},
		"zhangfei":{"damage_by_star":[0.15, 0.20, 0.30], "duration":3.0},
		"caocao":{"mult":1.0, "stun_chance":0.35, "stun":1.0, "counter_chance":0.45, "reduction":0.15, "duration":4.0},
		"dianwei":{"mult":1.8, "skill_damage_reduction":0.25, "target_mode":"farthest"},
		"xuchu":{"mult":1.0, "current_hp_ratio":0.08, "extra_cap":1.4},
		"luxun":{"mult":2.2, "bounce_mult":1.0, "bounce_falloff":0.12},
		"lusu":{"heal_ratio":0.15, "max_hp_flat":200.0, "target_count":1, "four_heroes_heal_ratio":0.20, "four_heroes_max_hp_flat":350.0, "four_heroes_target_count":2},
		"lvbu":{"mult":1.6},
		"diaochan":{"duration":1.5, "target_mode":"highest_skill_value"},
		"dongzhuo":{"mult":1.0, "current_hp_ratio":0.06, "extra_cap":8.0}
	}
	for hero_id in signature_params:
		heroes[hero_id].ability = "signature"
		heroes[hero_id].ability_params = signature_params[hero_id].duplicate(true)

func _set_skill(hero_id: String, ability: String, params: Dictionary, zh_detail: String, en_detail: String) -> void:
	heroes[hero_id].ability = ability
	heroes[hero_id].ability_params = params
	heroes[hero_id].detail_zh = zh_detail
	heroes[hero_id].detail_en = en_detail
	heroes[hero_id].summary = zh_detail
	heroes[hero_id].en_summary = en_detail

func _apply_document_skill_rework() -> void:
	heroes.sunjian.skill = "Tiger's Resolve"
	heroes.sunjian.zh_skill = "猛虎绝命"
	_set_skill("sunjian", "signature", {"damage_cost_ratio":1.0, "pillars_damage_cost_ratio":1.5, "self_cost":0.10, "first_self_cost":0.40, "sun_legacy_self_cost":0.20, "sun_legacy_first_self_cost":0.80, "death_wu_damage_bonus":0.10}, "猛虎绝命：消耗当前生命攻击正前方敌军；通常消耗10%，每回合首次消耗40%，造成等同于实际消耗生命100%的伤害。", "Tiger's Resolve: Spend 10% current HP, or 40% on the first cast each round, to strike the facing enemy for 100% of HP actually spent.")
	heroes.sunce.skill = "Conqueror's Twin Assault"
	heroes.sunce.zh_skill = "小霸王连击"
	_set_skill("sunce", "signature", {"mult":2.0, "sun_legacy_mult":4.0, "missing_hp_step":0.10, "missing_hp_damage_bonus_per_step":0.02, "missing_hp_reduction_per_step":0.04}, "小霸王连击：攻击正前方及其左侧敌军，造成200%技能强度伤害；自身每损失10%生命，伤害提高2%。孙氏之志使基础倍率提高至400%，且每损失10%生命获得4%伤害减免；神亭酣战追加第二次攻击，命中正前方及其右侧，使正前方承受两次伤害。", "Conqueror's Twin Assault: Strike the facing enemy and its left neighbor for 200% SKILL damage; gain +2% damage per 10% HP missing. Sun Legacy raises the base ratio to 400% and grants 4% damage reduction per 10% HP missing. Shenting Duel adds a second strike against the facing enemy and its right neighbor, hitting the center twice.")
	heroes.sunquan.skill = "Jiangdong Balance"
	heroes.sunquan.zh_skill = "江东制衡"
	_set_skill("sunquan", "signature", {"current_hp_damage_ratio":0.08, "max_hp_gain":200.0, "max_hp_cap_mult":2.0, "missing_hp_heal_ratio":0.10, "sun_legacy_max_hp_gain":400.0, "sun_legacy_missing_hp_cap_gain_ratio":0.10, "sun_legacy_max_hp_cap_mult":4.0, "sun_legacy_missing_hp_heal_ratio":0.15, "luxun_damage_ratio":0.12, "luxun_cooldown":8.0}, "江东制衡：随机对一名敌军造成其当前生命8%的伤害；自身最大生命提高200（不超过初始最大生命的2倍），再恢复10%已损失生命。孙氏之志使最大生命提高400并额外提高等同于当前已损失生命10%的上限（总上限改为初始最大生命4倍），再恢复15%已损失生命；君臣同心使伤害提高至目标当前生命12%，冷却缩短至8秒。基础冷却10秒。", "Jiangdong Balance: Deal 8% of a random enemy's current HP, gain 200 max HP up to 2x initial max HP, then restore 10% missing HP. Sun Legacy grants 400 plus 10% missing HP as max HP, raises the cap to 4x, and restores 15% missing HP. Sovereign and Minister raises damage to 12% current HP and shortens cooldown to 8s. Base cooldown 10s.")
	_set_skill("zhaoyun", "signature", {"hit_mults":[0.50, 0.50, 0.50, 0.50, 0.50], "five_tiger_mults":[0.50, 0.70, 0.90, 1.10, 1.30], "seven_base_mults":[0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50], "seven_charge_mults":[0.50, 0.70, 0.90, 1.10, 1.30, 1.50, 1.70]}, "龙胆连刺：随机选择一名射程内敌人并快速攻击同一目标5次，每次造成50%技能强度伤害。五虎上将使五次伤害递增为50%/70%/90%/110%/130%；单独七进七出改为随机锁定一名敌方后军并进行7次50%连刺，同时激活五虎时七次伤害递增至170%。", "Dragon Spear: Randomly select an enemy in range and rapidly strike that target 5 times for 50% SKILL each. Five Tigers changes the hits to 50%/70%/90%/110%/130%. Seven Charges alone randomly locks an enemy rearguard for 7 hits at 50%; with Five Tigers also active, the 7 hits escalate to 170%.")
	_set_skill("liushan", "buff_column", {"damage_by_star":[0.25, 0.35, 0.55], "duration":4.0, "seven_lifesteal":0.30}, "蜀主鼓舞：强化同列前军4秒；1/2/3星增伤25%/35%/55%。七进七出额外使被强化友军获得30%全能吸血。冷却4秒。", "Royal Encouragement: Empower the allied vanguard in the same column for 4s; stars grant 25%/35%/55% damage. Seven Charges also grants the empowered ally 30% omnivamp. 4s cooldown.")
	_set_skill("huangzhong", "strike", {"mult":1.45, "active_mult":2.0, "target_mode":"back_low", "focus":true}, "百步穿杨：优先后排低血目标，连续锁定同一目标会逐步提高暴击率，换目标后清空。", "Piercing Arrow: Prefer a low-HP backliner. Repeated shots build critical chance, reset on target change.")
	_set_skill("zhugeliang", "row_magic", {"mult":2.0, "menghuo_damage_bonus":0.20, "fire_mark_bonus":0.30, "liubei_extra_target_bonus":0.10}, "八阵奇谋：随机选择敌方格子，对目标及同列相邻格造成200%技能强度法术伤害，冷却4秒。庞统使同排相邻格也受击；姜维使四个斜对角相邻格也受击；孟获使伤害提高20%并施加火攻标记，已标记者再次受到诸葛亮伤害时额外提高30%；刘备使本次每多命中一名武将，所有受击格伤害提高10%。", "Eight-Formation Stratagem: Choose a random enemy tile and deal 200% SKILL magic damage to it and its vertical neighbors. 4s cooldown. Pang Tong adds horizontal neighbors; Jiang Wei adds all four diagonals; Meng Huo grants +20% damage and applies Fire Assault, causing Zhuge Liang's later hits to deal +30%; Liu Bei grants +10% damage to every affected tile per additional enemy hit.")
	_set_skill("machao", "signature", {"front_mult":2.0, "middle_mult":1.7, "back_mult":1.4}, "铁骑贯阵：锁定当前血量最低敌人的整列，前军/中军/后军依次受到200%/170%/140%技能强度伤害；与马岱组成一骑当千后全列均为200%。", "Iron Cavalry: Pierce the column containing the lowest-current-HP enemy for 200%/170%/140% SKILL by row; One Rider with Ma Dai makes every row 200%.")
	_set_skill("madai", "signature", {"max_hp_ratios":[0.60, 0.70, 0.85], "empty_ruler_damage_by_star":[1000.0, 1500.0, 2000.0], "vulnerable":0.40, "vulnerable_time":15.0}, "斩将突袭：随机攻击敌方前排，1/2/3星分别造成其最大生命60%/70%/85%的伤害；敌方没有前军时攻击前军空格，并对主公造成1000/1500/2000点伤害。一骑当千使每场开局行动条充满；宿命之敌使命中目标额外承伤40%持续15秒。", "Execution Raid: Hit a random frontliner for 60%/70%/85% max HP at stars 1/2/3. If no enemy vanguard remains, strike an empty front tile and deal 1000/1500/2000 ruler damage. One Rider starts each battle at full gauge; Fated Enemies marks the victim to take 40% more damage for 15s.")
	_set_skill("weiyan", "signature", {"mult":1.8, "self_heal":0.40, "ally_heal":0.15}, "狂骨横斩：攻击正前方及同排相邻格，造成180%技能强度伤害并回复实际伤害40%。飞火流星在敌方前军阵亡时回复50%最大生命；宿命之敌为相邻友军和后方中军回复15%最大生命。", "Rebel Fang: Hit the facing tile and adjacent tiles for 180% SKILL, healing 40% of damage. Flying Meteor heals 50% max HP when an enemy frontliner falls; Fated Enemies heals adjacent allies and rearward midguards for 15% max HP.")
	_set_skill("yuejin", "multi", {"count":3, "mult":0.55, "target_mode":"front", "shield_break":0.45}, "裂箭急袭：向前排分裂3箭，每箭55%技能强度；命中护盾时额外提高45%伤害。", "Split Volley: Fire 3 front-row arrows for 55% SKILL each; +45% damage into shields.")
	_set_skill("xiahouyuan", "strike", {"mult":1.40, "target_mode":"back_low", "silence":1.5, "first_mult":1.30}, "神速点杀：首次出手强化，优先后排并沉默1.5秒。", "Swift Execution: The first cast is empowered, prefers the backline and silences for 1.5s.")
	_set_skill("guojia", "control", {"mult":0.45, "stun":1.5, "target_mode":"highest_skill_value", "vulnerable":0.18, "vulnerable_time":4.0}, "鬼才冰策：冻结技能数值最高敌人1.5秒，并使其受到伤害提高18%持续4秒。", "Frozen Scheme: Freeze the highest-SKILL enemy for 1.5s and make it take 18% more damage for 4s.")
	_set_skill("simayi", "multi_magic", {"count":2, "mult":1.05, "target_mode":"debuffed"}, "鹰视雷击：优先雷击带减益目标2次；若没有减益则仍随机落雷。", "Eagle-Gaze Thunder: Prefer debuffed targets for 2 strikes; otherwise lightning remains random.")
	_set_skill("zhouyu", "strike_magic", {"mult":1.0, "tile_count":2, "four_heroes_bonus_tiles":2, "burn":3.0, "burn_ratio":0.50, "xiaoqiao_burn":6.0, "missing_hp_step":0.10, "missing_hp_bonus_per_step":0.05}, "赤壁点火：随机点燃2个敌方格，各造成100%技能强度法术伤害并灼烧3秒，每秒造成50%技能强度伤害。四英杰额外点燃2格；琴瑟和鸣使灼烧延长至6秒；赤壁苦计使直接伤害与每次灼烧伤害按目标已损失生命提高，每损失10%生命增伤5%。", "Red Cliffs: Ignite 2 random enemy tiles for 100% SKILL magic damage and burn for 3s at 50% SKILL per second. Four Heroes adds 2 tiles; Harmonious Zither extends burn to 6s; Red Cliffs Ruse grants +5% direct and burn damage per 10% target HP missing.")
	_set_skill("luxun", "strike_magic", {"mult":2.0, "bounces":1, "four_heroes_bounces":3, "sunquan_damage_bonus":0.50, "sunquan_burning_bonus":0.50}, "火烧连营：发射火球造成200%技能强度法术伤害，并向相邻敌方格弹射1次。四英杰使总弹射次数提高至3次；君臣同心使伤害提高50%，命中灼烧目标时再提高50%，合计提高100%。", "Flames of Camp: Launch a fireball for 200% SKILL magic damage and bounce once to an adjacent enemy tile. Four Heroes raises total bounces to 3; Sovereign and Minister grants +50% damage and another +50% against burning targets, for +100% total.")
	_set_skill("lvmeng", "strike", {"mult":4.0, "target_mode":"back", "stealth":3.0, "fear":4.0, "fear_max_hp_ratio":0.05, "ambush_next_damage_bonus":0.60}, "白衣渡江：攻击敌方后军，造成400%技能强度物理伤害，随后隐身3秒，隐身期间不会被选为攻击目标。四英杰使命中目标恐惧4秒，行动条停止且每秒受到5%最大生命伤害；白衣奇袭使吕蒙每次进入隐身后，下一次造成的伤害提高60%。", "White-Robed Raid: Strike an enemy rearguard for 400% SKILL physical damage, then enter stealth for 3s and cannot be selected. Four Heroes fears the victim for 4s, freezing its gauge and dealing 5% max HP each second; White-Robed Ambush grants Lu Meng's next damage after entering stealth +60%.")
	_set_skill("lusu", "signature", {"heal_ratio":0.15, "max_hp_flat":200.0, "target_count":1, "four_heroes_heal_ratio":0.20, "four_heroes_max_hp_flat":350.0, "four_heroes_target_count":2}, "连横稳阵：选择当前生命值总量最低的友军，为其恢复15%最大生命并使本场战斗最大生命提高200。四英杰使技能改为选择两名当前生命值总量最低的友军，各恢复20%最大生命并使本场战斗最大生命提高350。", "Alliance: Select the ally with the lowest current HP total, restore 15% max HP, and raise max HP by 200 for this battle. Four Heroes selects the two lowest-current-HP allies, restores 20% max HP to each, and raises each max HP by 350 for this battle.")
	_set_skill("xiaoqiao", "signature", {"target_count":2, "slow":0.35, "slow_time":6.0, "zhouyu_target_count":3, "zhouyu_slow_time":8.0, "daqiao_slow":0.60}, "天香缓阵：随机选择两名敌方后军，使其减速6秒，减速期间行动条速度降低35%。琴瑟和鸣使目标数提高至3名且持续时间延长至8秒；江东双姝使行动条速度降低60%。", "Gentle Breeze: Select two random enemy rearguards and slow them for 6s, reducing gauge speed by 35%. Harmonious Zither raises the target count to 3 and duration to 8s; Jiangdong Sisters increases the gauge slow to 60%.")
	heroes.taishici.skill = "Blazing Twin Halberds"
	heroes.taishici.zh_skill = "神亭烈戟"
	_set_skill("taishici", "signature", {"target_count":2, "mult":1.50, "burn":5.0, "burn_ratio":0.20, "sunce_target_count":3, "ganning_burning_mult":3.0}, "神亭烈戟：攻击射程内行动条最高的两名敌人，造成150%技能强度物理伤害，并施加5秒灼烧，每秒造成20%技能强度伤害。", "Blazing Twin Halberds: Strike the two reachable enemies with the highest gauges for 150% SKILL physical damage and burn for 5s at 20% SKILL per second.")
	heroes.ganning.skill = "Bell-Raider Twin Assault"
	heroes.ganning.zh_skill = "锦帆并击"
	_set_skill("ganning", "signature", {"mult":1.50, "taishici_mult":2.50, "lvmeng_low_hp_bonus":0.50}, "锦帆并击：自身与同排左侧友军分别攻击一名随机敌方后军，各造成150%自身技能强度的物理伤害；友军协击不消耗行动条。", "Bell-Raider Twin Assault: Gan Ning and the ally directly to his left each strike a random enemy rearguard for 150% of their own SKILL; the assist costs no gauge.")
	heroes.huanggai.skill = "Bitter-Flesh Column"
	heroes.huanggai.zh_skill = "苦肉焚阵"
	_set_skill("huanggai", "signature", {"max_hp_cost":0.10, "damage_cost_ratio":0.33, "zhouyu_burn":6.0, "zhouyu_burn_cost_ratio":0.05, "sunjian_max_hp_cost":0.15, "sunjian_damage_cost_ratio":0.45}, "苦肉焚阵：消耗自身10%最大生命，对随机敌方一列造成等同于实际消耗生命33%的物理伤害；生命不足时消耗全部生命并在攻击后阵亡。", "Bitter-Flesh Column: Spend 10% max HP to damage a random enemy column for 33% of HP actually spent; if HP is insufficient, spend it all and fall after the attack.")
	heroes.sunshangxiang.skill = "Heroine's Growing Volley"
	heroes.sunshangxiang.zh_skill = "枭姬叠势"
	heroes.sunshangxiang.skill_value = 80
	_set_skill("sunshangxiang", "signature", {"mult":1.0, "hit_count":1, "skill_gain_per_cast":1.0, "ally_death_skill_gain":5.0, "sun_legacy_mult":1.5, "sun_legacy_hit_count":2, "sun_legacy_skill_gain_per_cast":2.0, "sun_legacy_cooldown":6.0}, "枭姬叠势：随机攻击一名敌军，造成100%技能强度伤害；每次释放后自身技能强度永久提高1点。孙氏之志使冷却缩短至6秒，每次连续释放2击，每击造成150%技能强度伤害，且每次释放后技能强度提高2点。任意友军阵亡时，孙尚香技能强度提高5点。基础技能强度80，冷却8秒。", "Heroine's Growing Volley: Strike a random enemy for 100% SKILL, then permanently gain 1 SKILL. Sun Legacy shortens cooldown to 6s, fires twice for 150% SKILL each, and grants 2 SKILL after each cast. Whenever an ally falls, gain 5 SKILL. Base SKILL 80; cooldown 8s.")
	_set_skill("xusheng", "row_magic", {"mult":0.65, "stun":0.8, "slow":0.20, "slow_time":4.0}, "宿卫水阵：冲击一排并留下4秒水阵，使该排行动速度降低20%。", "Guardian Water Formation: Strike a row and leave a 4s water field that slows gauge gain by 20%.")
	_set_skill("wenchou", "shield_single", {"mult":1.0, "flat":28.0, "spell_reflect":0.35}, "反弹恶斗：为最低生命友军施加小型护盾；自身有35%概率反弹指向性技能。", "Reflected Duel: Give a small shield to the weakest ally; Wen Chou has 35% chance to reflect targeted skills.")
	_set_skill("qunzhanghe", "shield_column", {"mult":0.75, "flat":20.0, "spell_ward":1}, "紫幕护法：为同列友军施加小型护盾，并各抵挡下一次主动技能伤害。", "Purple Ward: Give column allies a small shield and block their next active-skill hit.")
	_set_skill("yuji", "row_magic", {"mult":0.95, "fallen_scale":0.18, "target_mode":"back_low"}, "妖术祭雷：轰击后排；每名阵亡友军使本次雷击强化18%。", "Sacrificial Thunder: Strike the backline; each fallen ally empowers the cast by 18%.")
	_set_skill("zhangjiao", "multi_magic", {"count":2, "mult":0.60, "summon_on_death":0.45}, "黄天起义：降下2道雷击；友军阵亡时有45%概率触发一次小型天雷。", "Yellow Heaven: Call 2 lightning strikes; allied deaths have 45% chance to trigger a minor thunderbolt.")

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
			heroes[hero_id].cooldown = maxf(DEFAULT_SKILL_COOLDOWN, float(heroes[hero_id].cooldown))

func _minimum_skill_cooldown(_hero_id: String) -> float:
	return COOLDOWN_INPUT_MIN

func _scale_hero_health() -> void:
	for hero_id in heroes:
		heroes[hero_id].hp = int(float(heroes[hero_id].hp) * HEALTH_SCALE)

func _finalize_skill_values() -> void:
	for hero_id in heroes:
		_finalize_hero_skill_values(hero_id)

func _finalize_hero_skill_values(hero_id: String) -> void:
	if not heroes.has(hero_id): return
	var hero: Dictionary = heroes[hero_id]
	var params: Dictionary = hero.get("ability_params", {})
	var skill_value: float = float(hero.skill_value)
	var mult: float = float(params.get("mult", 1.0))
	var ability: String = hero.get("ability", "")
	for derived_key in ["base_value", "base_heal", "base_shield", "burn_per_sec"]:
		params.erase(derived_key)
	if ability in ["strike", "strike_magic", "drain", "control", "row", "row_magic", "multi", "multi_magic"]:
		params["base_value"] = round(skill_value * mult)
	elif ability == "heal":
		params["base_heal"] = round(skill_value * mult + float(params.get("flat", 80.0)) * HEALTH_SCALE * 0.65)
	elif ability == "heal_team":
		params["base_heal"] = round(skill_value * mult)  # ratio 已在 params 里,治疗时用 base_heal × ratio
	elif ability.begins_with("shield_"):
		params["base_shield"] = round(skill_value * mult + float(params.get("flat", 40.0)))
	if float(params.get("burn", 0.0)) > 0.0:
		params["burn_per_sec"] = round(skill_value * float(params.get("burn_ratio", 0.30)))
	if ability == "signature" and not params.has("base_value"):
		params["base_value"] = round(skill_value)
	hero.ability_params = params

func t(zh: String, en: String) -> String:
	return zh if language == "zh" else en

func _star_stat_multiplier(level: int) -> float:
	return [1.0, 1.5, 2.25][clampi(level, 1, 3) - 1]

func _star_effect_multiplier(level: int) -> float:
	return [1.0, 1.25, 1.50][clampi(level, 1, 3) - 1]

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

func _roles_text(roles: Array) -> String:
	if language == "zh": return " / ".join(roles)
	var translations := {"治疗":"Healer", "辅助":"Support", "战士":"Warrior", "刺客":"Assassin", "爆发":"Burst", "坦克":"Tank", "控制":"Control", "法师":"Mage", "灼烧":"Burn", "收割":"Execution"}
	var localized: Array[String] = []
	for role in roles: localized.append(translations.get(role, role))
	return " / ".join(localized)

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
	var count := 0
	for unit in units:
		if unit.alive and unit.row >= 0 and ids.has(unit.hero_id): count += 1
	return count >= required

func _make_roster_unit(team: String, hero_id: String) -> Dictionary:
	var hero: Dictionary = heroes[hero_id]
	return {
		"id":team + ":" + hero_id + ":" + str(rng.randi()), "hero_id":hero_id, "team":team, "level":1, "stat_mult":1.0,
		"row":-1, "col":-1, "hp":float(hero.hp), "max_hp":float(hero.hp), "alive":true,
		"action":0.0, "action_gain_mult":1.0, "shield":0.0, "burn":0.0, "burn_damage":0.0, "burn_clock":0.0,
		"burn_missing_hp_scale":false, "fear":0.0, "fear_damage_ratio":0.0, "fear_clock":0.0,
		"stun":0.0, "charm":0.0, "damage_reduction":0.0, "damage_buff":0.0,
		"silence":0.0, "stealth":0.0, "slow":0.0, "slow_time":0.0,
		"vulnerable":0.0, "vulnerable_time":0.0, "strategy_mark":0.0, "zhuge_fire_mark":false, "spell_ward":0,
		"cast_count":0, "focus_target":"", "focus_stacks":0, "faction_tier":0,
		"bond_cooldown":0.0, "sunquan_initial_max_hp":0.0, "sunshangxiang_skill_bonus":0.0,
		"faction_damage_reduction":0.0, "faction_hp_bonus":0.0, "faction_control_bonus":0.0,
		"faction_cooldown_reduction":0.0, "shu_damage_stacks":0,
		"four_heroes":false, "lvmeng_ganning":false, "stealth_ambush_bonus_ready":false,
		"regen_per_second":0.0, "regen_time":0.0, "regen_clock":0.0, "regen_magic_reduction":0.0, "regen_source":"",
		"timed_damage_buff":0.0, "timed_damage_time":0.0, "timed_reduction":0.0, "timed_reduction_time":0.0,
		"all_lifesteal":0.0, "all_lifesteal_time":0.0,
		"skill_debuff":0.0, "kill_buff":0.0, "death_prevention":0.0,
		"heal_multiplier":1.0, "charm_multiplier":1.0, "current_hp_ratio":0.06
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
