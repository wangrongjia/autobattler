# 三国代码分析与模块边界

## 结论

原先约 3,800 行的单脚本同时承担数据、存档、流程、战斗、界面和特效，修改一个机制很容易牵动无关区域。本轮将其拆为六个按职责排列的脚本，主入口只保留启动编排。当前继承方向是：

```text
game_state
  └─ game_flow
      └─ combat_system
          └─ game_ui
              └─ visual_effects
                  └─ three_kingdom_game
```

Godot 官方建议按功能分组资源、保持清晰主入口，并让场景尽量自洽；Godot Open RPG 也按 combat、overworld、GUI 等领域拆分。当前结构采用相同思路，同时保留现有场景和测试接口，降低一次性重写风险。

参考：

- https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html
- https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html
- https://docs.godotengine.org/en/stable/tutorials/best_practices/scenes_versus_scripts.html
- https://github.com/gdquest-demos/godot-open-rpg

## 模块职责

| 模块 | 主要职责 | 不应放入 |
|---|---|---|
| `game_state.gd` | 常量、全局状态、武将定义、运行时单位结构、通用查询 | UI 节点构建、具体战斗结算 |
| `game_flow.gd` | 新游戏、存读档、招募、升星、布阵、关卡开始/结束 | 技能公式、绘制逻辑 |
| `combat_system.gd` | 行动条、技能、伤害、状态、阵营与组合羁绊 | 菜单和卡片布局 |
| `game_ui.gd` | UI 构建、渲染、拖拽、图鉴、设置、双语文案 | 伤害和治疗结算 |
| `visual_effects.gd` | 投射物、近战位移、命中爆发、飘字 | 胜负与数值规则 |
| `three_kingdom_game.gd` | 调用初始化步骤 | 任何具体玩法 |

为兼容现有场景与集成测试，本轮使用分层继承完成低风险拆分。下一阶段若继续扩展，建议将武将与羁绊改为 `Resource` 数据资产，并让 UI 和战斗系统通过组合与信号通信，逐步减少深继承。

## 删除的旧模型

以下属性属于复制来源、旧普攻循环或已经没有读取方的历史实现，现已从武将定义、单位运行时结构、战斗分支、图鉴文案与测试中移除：

- 无参与公式的 `pdef`、`mdef`
- 旧“多次普攻后施法”计数：`basic_before_skill`、`basic_count`
- 赵云旧强化普攻状态：`empowered_attacks`、`empowered_mult`、`basic_shield_charges`
- 未完成的通用乘区或临时羁绊字段：`spell_amp`、`skill_damage_mult`、`damage_vs_melee`、`control_bonus`
- 已失效的护盾、免疫、破甲与标记字段：`shield_multiplier`、`physical_immunity`、`armor_break`、`bond_marks`、`hebei_ward`、`fire_mark`
- 其他没有有效读写闭环的字段：`cleave_lifesteal`、`dodge_bonus`、`tiger_echo`

保留的状态字段都至少有明确写入与消费路径。南蛮夫妇的 `burn_multiplier` 原先只写不读，本轮补入所有灼烧伤害计算。

## 同步修复

- 周瑜 `base_value` 已在数据预处理阶段计算 `ATK × mult`，旧战斗代码再次乘以 `mult`；现已去掉重复乘算。
- 图鉴不再把物理/法术文案统一替换成“真实伤害”，避免显示值与实际伤害类型不一致。
- 旧普攻循环测试改为验证行动条满后直接施放主动技能。
- 移除战场格子重绘时反复创建的无限回血脉冲 Tween，消除高速战斗下的 Tween 无限循环错误。
- 评分报告由真实场景运行后导出，而不是用正则重复解析源代码。

## 已知后续重点

`game_ui.gd` 仍是最大的单一模块，因为它同时包含主界面、战场、招募、图鉴和设置。继续迭代时可按场景拆成 `BattleHUD`、`DraftPanel`、`EncyclopediaPanel` 和 `SettingsPanel`，每个面板拥有自己的脚本与信号；这是下一步最有收益的结构优化。
