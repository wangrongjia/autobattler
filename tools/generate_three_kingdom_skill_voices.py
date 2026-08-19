#!/usr/bin/env python3
"""Generate the Three Kingdoms skill voice pack from the Markdown guide.

Requires ``edge-tts``. Output is deterministic in naming and can be safely
re-run: existing non-empty files are kept unless ``--force`` is supplied.
"""

from __future__ import annotations

import argparse
import asyncio
import re
from dataclasses import dataclass
from pathlib import Path

import edge_tts


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_GUIDE = ROOT / "docs" / "武将技能台词配音指引.md"
DEFAULT_OUTPUT = ROOT / "ThreeKingdom" / "audio" / "voices" / "skills"

HERO_IDS = {
    "刘备": "liubei", "关羽": "guanyu", "张飞": "zhangfei", "赵云": "zhaoyun",
    "刘禅": "liushan", "黄忠": "huangzhong", "马超": "machao", "马岱": "madai",
    "魏延": "weiyan", "诸葛亮": "zhugeliang", "姜维": "jiangwei", "庞统": "pangtong",
    "孟获": "menghuo", "祝融": "zhurong", "带来洞主": "dailaidongzhu",
    "曹操": "caocao", "典韦": "dianwei", "许褚": "xuchu", "张辽": "zhangliao",
    "乐进": "yuejin", "徐晃": "xuhuang", "张郃": "zhanghe", "于禁": "yujin",
    "夏侯渊": "xiahouyuan", "曹仁": "caoren", "夏侯惇": "xiahoudun", "司马懿": "simayi",
    "郭嘉": "guojia", "荀彧": "xunyu", "贾诩": "jiaxu",
    "周瑜": "zhouyu", "陆逊": "luxun", "吕蒙": "lvmeng", "鲁肃": "lusu",
    "大乔": "daqiao", "小乔": "xiaoqiao", "太史慈": "taishici", "甘宁": "ganning",
    "黄盖": "huanggai", "孙坚": "sunjian", "孙策": "sunce", "孙权": "sunquan",
    "孙尚香": "sunshangxiang", "丁奉": "dingfeng", "徐盛": "xusheng",
    "吕布": "lvbu", "董卓": "dongzhuo", "貂蝉": "diaochan", "陈宫": "chengong",
    "高顺": "gaoshun", "颜良": "yanliang", "文丑": "wenchou", "高览": "gaolan",
    "群张郃": "qunzhanghe", "华佗": "huatuo", "于吉": "yuji", "左慈": "zuoci",
    "张角": "zhangjiao", "张梁": "zhangliang", "张宝": "zhangbao",
}


@dataclass(frozen=True)
class VoiceLine:
    hero_name: str
    hero_id: str
    index: int
    text: str
    direction: str


def parse_guide(path: Path) -> list[VoiceLine]:
    lines: list[VoiceLine] = []
    current_name = ""
    for raw in path.read_text(encoding="utf-8").splitlines():
        if raw.startswith("### "):
            current_name = re.split(r"[（(]", raw[4:].strip(), maxsplit=1)[0].strip()
            continue
        match = re.match(r"^\s*([1-3])\.\s+\*\*(.*?)\*\*\s*(?:——\s*)?(.*)$", raw)
        if not match or not current_name:
            continue
        if current_name not in HERO_IDS:
            raise ValueError(f"Guide hero has no game id: {current_name}")
        spoken = match.group(2).removesuffix("——").strip()
        lines.append(VoiceLine(current_name, HERO_IDS[current_name], int(match.group(1)), spoken, match.group(3).strip()))
    expected = len(HERO_IDS) * 3
    if len(lines) != expected:
        raise ValueError(f"Expected {expected} voice lines, parsed {len(lines)}")
    return lines


def voice_settings(line: VoiceLine) -> tuple[str, str, str, str]:
    cue = line.direction
    if "女声" in cue:
        voice = "zh-CN-XiaoyiNeural" if any(word in cue for word in ("娇", "野性", "活泼", "英气")) else "zh-CN-XiaoxiaoNeural"
    elif any(word in cue for word in ("青年", "清亮", "清朗", "儒雅", "书生", "稚嫩")):
        voice = "zh-CN-YunxiNeural"
    elif any(word in cue for word in ("军师", "沉稳", "从容", "温厚", "温和", "平静", "冷静")):
        voice = "zh-CN-YunyangNeural"
    else:
        voice = "zh-CN-YunjianNeural"

    if any(word in cue for word in ("极快", "爆发", "咆哮", "怒吼", "急促", "迅疾", "高亢", "激昂", "炸裂")):
        rate = "+16%"
    elif any(word in cue for word in ("快", "明快", "有力", "豪迈", "坚定", "凌厉")):
        rate = "+9%"
    elif any(word in cue for word in ("极慢", "缓", "平缓", "迟疑", "低语", "从容")):
        rate = "-10%"
    else:
        rate = "+2%"

    if any(word in cue for word in ("高亢", "高扬", "拔高", "清亮", "清脆", "上扬")):
        pitch = "+7Hz"
    elif any(word in cue for word in ("低沉", "低吼", "低平", "下沉", "下压", "苍老")):
        pitch = "-8Hz"
    else:
        pitch = "+2Hz"
    return voice, rate, pitch, "+8%"


async def generate_one(line: VoiceLine, output: Path, force: bool, semaphore: asyncio.Semaphore) -> str:
    destination = output / f"{line.hero_id}_skills_{line.index}.mp3"
    if destination.exists() and destination.stat().st_size > 0 and not force:
        return f"keep {destination.name}"
    voice, rate, pitch, volume = voice_settings(line)
    async with semaphore:
        last_error: Exception | None = None
        for attempt in range(3):
            try:
                await edge_tts.Communicate(line.text, voice, rate=rate, pitch=pitch, volume=volume).save(str(destination))
                if destination.stat().st_size <= 0:
                    raise RuntimeError("empty audio output")
                return f"made {destination.name}  {voice} {rate} {pitch}"
            except Exception as error:  # transient service failures are common in large batches
                last_error = error
                destination.unlink(missing_ok=True)
                await asyncio.sleep(1.5 * (attempt + 1))
        raise RuntimeError(f"Failed {destination.name}: {last_error}")


async def run(args: argparse.Namespace) -> None:
    guide = Path(args.guide).resolve()
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    voice_lines = parse_guide(guide)
    semaphore = asyncio.Semaphore(args.jobs)
    results = await asyncio.gather(*(generate_one(line, output, args.force, semaphore) for line in voice_lines))
    for result in results:
        print(result)
    print(f"Generated/validated {len(results)} files in {output}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--guide", default=str(DEFAULT_GUIDE))
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--jobs", type=int, default=6)
    parser.add_argument("--force", action="store_true")
    asyncio.run(run(parser.parse_args()))


if __name__ == "__main__":
    main()
