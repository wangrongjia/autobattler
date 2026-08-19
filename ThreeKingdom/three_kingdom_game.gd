extends "res://ThreeKingdom/systems/visual_effects.gd"

func _ready() -> void:
	rng.randomize()              # 用当前时间初始化随机数种子,保证每局随机不同
	_add_extended_roster()       # 注册 武将
	_apply_existing_faction_skill_reworks() # 保留尚未轮到重做阵营的既有技能配置
	_configure_combat_profiles()
	_apply_registered_balance_baseline() # 直接载入代码中的最终基础值，无职业/血量隐式修正
	_load_balance_overrides()    # 只载入此后由平衡实验室保存的新差异
	balance_default_heroes = heroes.duplicate(true)
	_load_progression()          # 读取关卡、资源、符文、天赋与主页武将
	_load_settings()             # 读取持久化设置(速度、暂停选项、阵营过滤)
	_build_ui()                  # 构建整个游戏界面(纯代码创建所有 UI 元素)
	_new_game()                  # 开始新游戏(进入第 1 关选将阶段)
	_build_main_menu()           # 构建主菜单覆盖层(盖在游戏上,等待玩家点击开始)
