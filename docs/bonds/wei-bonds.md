# 魏国武将羁绊关系图

全体魏国武将默认属于阵营羁绊“魏武中枢（2/5/8）”。夏侯渊、曹仁、夏侯惇、荀彧当前只有阵营羁绊，没有独立组合羁绊。

```mermaid
flowchart TB
    CC["曹操<br/>caocao"]
    DW["典韦<br/>dianwei"]
    XC["许褚<br/>xuchu"]
    ZL["张辽<br/>zhangliao"]
    YJ["乐进<br/>yuejin"]
    ZH["张郃<br/>zhanghe"]
    XH["徐晃<br/>xuhuang"]
    YJIN["于禁<br/>yujin"]
    SMY["司马懿<br/>simayi"]
    GJ["郭嘉<br/>guojia"]

    GUARDS(("护主双壁<br/>3人"))
    ELITES(("五子良将<br/>至少3人"))
    STRATEGISTS(("魏谋双星"))

    CC --- GUARDS
    DW --- GUARDS
    XC --- GUARDS

    ZL --- ELITES
    YJ --- ELITES
    ZH --- ELITES
    XH --- ELITES
    YJIN --- ELITES

    SMY --- STRATEGISTS
    GJ --- STRATEGISTS
```

## 羁绊效果速查

| 羁绊 | 成员 | 当前效果 |
|---|---|---|
| 魏武中枢 | 任意2/5/8名魏将 | 全体魏将控制时长提高3%/8%/15%；8人时，所有魏将对带有眩晕、减速、灼烧或其他任意减益的目标伤害提高15%。 |
| 护主双壁 | 曹操、典韦、许褚 | 曹操受到超过8%最大生命的单次伤害时，护卫承担25%伤害并获得20%行动条。 |
| 五子良将 | 张辽、乐进、张郃、徐晃、于禁，至少3人 | 张辽参与控制接力；乐进获得额外裂箭；张郃建立受控集火；徐晃强化控制时长；于禁使被保护后军参与接力。 |
| 魏谋双星 | 司马懿、郭嘉 | 司马懿主动额外增加1道雷击；郭嘉控制持续时间提高45%。 |

## 仅有阵营羁绊的武将

夏侯渊（`xiahouyuan`）、曹仁（`caoren`）、夏侯惇（`xiahoudun`）、荀彧（`xunyu`）。
