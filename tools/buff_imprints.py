# -*- coding: utf-8 -*-
# 将印树全面加强：百分比 ×2.5，平值（极速/减伤值/行动条/时长等）×2，次数/目标/上限关键字不动。
# 同步重写节点描述里的数字（%/秒/s/行动条/极速/减伤值），保持描述与数值一致。
import re, sys

PATH = r"D:\github\autobattler\ThreeKingdom\data\hero_imprint_trees.gd"
PCT, FLAT = 2.5, 2.0
KEEP_SUFFIX = ("_times", "_targets", "_cap")
KEEP_EXACT = {"third_cast_burn_settle"}

def fmt(x: float) -> str:
    r = round(x, 3)
    return ("%g" % r)

def factor_of(key: str) -> float:
    if key.endswith(KEEP_SUFFIX) or key in KEEP_EXACT:
        return 1.0
    if key.endswith("_pct"):
        return PCT
    return FLAT

def scale_val(v, f):
    if isinstance(v, list):
        return [round(x * f, 3) for x in v]
    return round(v * f, 3)

def json_compact(d: dict) -> str:
    parts = []
    for k, v in d.items():
        if isinstance(v, list):
            parts.append('"%s": [%s]' % (k, ", ".join(fmt(x) for x in v)))
        else:
            parts.append('"%s": %s' % (k, fmt(v)))
    return "{" + ", ".join(parts) + "}"

def scale_desc(desc: str) -> str:
    def rp(m):
        return fmt(float(m.group(1)) * PCT) + "%"
    desc = re.sub(r'(\d+(?:\.\d+)?)%', rp, desc)
    def rh(m):
        return "极速 +" + fmt(float(m.group(1)) * FLAT)
    desc = re.sub(r'极速\s*\+(\d+(?:\.\d+)?)', rh, desc)
    def ra(m):
        return "减伤值 +" + fmt(float(m.group(1)) * FLAT)
    desc = re.sub(r'减伤值\s*\+(\d+(?:\.\d+)?)', ra, desc)
    def rs(m):
        return fmt(float(m.group(1)) * FLAT) + "秒"
    desc = re.sub(r'(\d+(?:\.\d+)?)\s*秒', rs, desc)
    def rs2(m):
        return fmt(float(m.group(1)) * FLAT) + "s"
    desc = re.sub(r'(\d+(?:\.\d+)?)s(?![a-zA-Z])', rs2, desc)
    def rac(m):
        return m.group(1) + fmt(float(m.group(2)) * FLAT) + " 行动条"
    desc = re.sub(r'([+-])(\d+(?:\.\d+)?)\s*行动条', rac, desc)
    return desc

lines = open(PATH, encoding="utf-8").read().split("\n")
eff_re = re.compile(r'"effects": (\{[^{}]*\})')
changed = 0
for i, line in enumerate(lines):
    if '"effects"' not in line:
        continue
    m = eff_re.search(line)
    if not m:
        continue
    try:
        import json
        eff = json.loads(m.group(1))
    except Exception as e:
        print("LINE %d JSON FAIL: %s" % (i + 1, e)); sys.exit(1)
    new_eff = {k: scale_val(v, factor_of(k)) for k, v in eff.items()}
    # 描述同步缩放
    dm = re.search(r'"desc": "([^"]*)"', line)
    new_desc = scale_desc(dm.group(1)) if dm else None
    new_line = line
    new_line = new_line.replace(m.group(0), '"effects": ' + json_compact(new_eff))
    if new_desc is not None:
        new_line = new_line.replace('"desc": "%s"' % dm.group(1), '"desc": "%s"' % new_desc)
    if new_line != line:
        lines[i] = new_line
        changed += 1

open(PATH, "w", encoding="utf-8", newline="\n").write("\n".join(lines))
print("nodes changed:", changed)
