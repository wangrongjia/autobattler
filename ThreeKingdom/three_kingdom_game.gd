extends "res://ThreeKingdom/systems/visual_effects.gd"

func _ready() -> void:
	rng.randomize()              # 用当前时间初始化随机数种子,保证每局随机不同
	_add_extended_roster()       # 注册 45 名扩展武将(加上 12 名招牌 = 57 名)
	_rebalance_role_stats()      # 第1步:平衡数值(远程武将技能强度封顶、特例覆盖)
	_apply_document_skill_rework()  # 第2步:按设计文档重做 18 名武将的技能
	_configure_combat_profiles()
	_scale_hero_health()         # 第4步:所有武将基础血量 ×12（相对原配置翻倍）
	_finalize_skill_values()     # 第5步:从技能基础数值预计算伤害/治疗/护盾
	_load_balance_overrides()    # 载入平衡实验室保存的项目数值覆盖
	_load_settings()             # 读取持久化设置(速度、暂停选项、阵营过滤)
	_build_ui()                  # 构建整个游戏界面(纯代码创建所有 UI 元素)
	_new_game()                  # 开始新游戏(进入第 1 关选将阶段)
	_build_main_menu()           # 构建主菜单覆盖层(盖在游戏上,等待玩家点击开始)
