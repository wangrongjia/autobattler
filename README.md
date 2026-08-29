# 三国·羁绊战棋

使用 Godot 4.7 开发的三国主题战棋原型。玩家在 20 关（每关 15 回合）流程中招募武将、调整阵型，并利用阵营和人物羁绊挑战持续增援的敌军。

## 已实现

- 魏、蜀、吴、群四大阵营，共 60 名武将
- 5 × 3 棋盘、9 格备战区、拖拽布阵与出售
- 每关三轮三选一、候选位独立刷新、同名武将各自独立上阵（已移除合并升星）
- 行动条驱动的主动技能战斗
- 护盾、治疗、眩晕、魅惑、灼烧、范围与弹射伤害
- 阵营羁绊、人物组合羁绊、战斗统计、存档与读档
- 中文 / English 切换与武将图鉴

## 运行

用 Godot 4.7 导入 `project.godot`，按 F5 运行；也可以执行：

```bash
godot --path .
```

## 项目结构

```text
ThreeKingdom/
├── ThreeKingdom.tscn              主场景
├── three_kingdom_game.gd          极薄启动入口
├── systems/
│   ├── game_state.gd              常量、运行状态、武将数据与基础工具
│   ├── game_flow.gd               招募、布阵、回合、存档
│   ├── combat_system.gd           战斗、技能、状态与羁绊执行
│   ├── game_ui.gd                 界面构建、渲染、图鉴与交互
│   └── visual_effects.gd          投射物、近战、命中特效与飘字
└── Portraits/                     武将立绘与来源说明
tools/export_balance_snapshot.gd   从实际运行时导出武将平衡快照
test/integration/                  Godot SceneTree 集成测试
```

模块边界、依赖方向和本轮清理记录见 `ARCHITECTURE.md`。

## 测试

每个集成测试都可独立运行，例如：

```bash
godot --headless --path . --script test/integration/test_three_kingdoms_smoke.gd
```

`tools/export_balance_snapshot.gd` 会加载真实场景和全部数据预处理逻辑，再输出报告用快照，避免静态脚本与游戏内数值不一致。
