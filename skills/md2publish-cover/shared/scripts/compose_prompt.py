#!/usr/bin/env python3
"""把 platform profile + preset + 维度覆盖 + brief 渲染成最终 prompt。

纯模板渲染器：不读文章原文、不做内容抽取、不调模型。
文章的语义部分由 agent 事先写成 brief 文件传入。
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import asset_lib as a

PLACEHOLDER_RE = re.compile(r"\{\{([A-Z_]+)\}\}")
OVERRIDABLE = {"palette": "palettes", "rendering": "renderings", "layout": "layouts"}


def render_platform_frame(slot: dict, platform: dict) -> str:
    aspect = slot["aspect"]
    aspect_text = " 或 ".join(aspect) if isinstance(aspect, list) else aspect
    lines = [f"目标平台：{platform['display_name']}。画幅 {aspect_text}。"]

    text = slot["text_on_image"]
    wants = [n for n, k in (("标题", "title"), ("副标题", "subtitle")) if text[k]]
    if wants:
        lines.append(f"图上必须包含{'与'.join(wants)}，文字要大且清晰可读。")
    else:
        lines.append("图上不要出现标题文字。")
    if text.get("notes"):
        lines.append(text["notes"] + "。")

    for key, label in (("safe_area", "安全区"), ("crop_warning", "裁切"), ("count_range", "张数")):
        if slot.get(key):
            val = slot[key]
            if key == "count_range":
                lines.append(f"{label}：{val[0]}–{val[1]} 张。")
            else:
                lines.append(f"{label}：{val}。")
    if slot.get("first_is_cover"):
        lines.append("第 1 张同时充当封面，需独立成立。")
    return "\n".join(lines)


def compose(platform_name: str, preset_name: str, brief: str, overrides: dict) -> str:
    platform = a.load_platform(platform_name)
    preset = a.load_preset(preset_name)
    archetype = preset["archetype"]

    slot = a.archetype_slot(platform, archetype)
    if slot is None:
        raise a.AssetError(
            f"{platform_name} 不支持 archetype '{archetype}'（槽值为 unsupported），"
            f"因此无法使用 preset '{preset_name}'"
        )
    if not a.preset_supports(preset, platform_name):
        raise a.AssetError(f"preset '{preset_name}' 在 incompatible_platforms 中排除了 {platform_name}")

    values = {"PLATFORM_FRAME": render_platform_frame(slot, platform), "CONTENT": brief}
    for field, kind in OVERRIDABLE.items():
        chosen = overrides.get(field) or preset.get(field)
        if chosen:
            values[field.upper()] = a.load_dimension(kind, chosen)

    template = preset["template"]
    used = set(PLACEHOLDER_RE.findall(template))
    unknown = used - a.PLACEHOLDERS
    if unknown:
        raise a.AssetError(
            f"preset '{preset_name}' 的模板含未知占位符 {sorted(unknown)}；"
            f"合法集合为 {sorted(a.PLACEHOLDERS)}"
        )
    missing = used - set(values)
    if missing:
        raise a.AssetError(
            f"preset '{preset_name}' 的模板用了 {sorted(missing)}，"
            "但该维度在 preset 里为空且未通过命令行覆盖"
        )

    return PLACEHOLDER_RE.sub(lambda m: values[m.group(1)], template).strip() + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(description="渲染图片 prompt（纯模板渲染，不调模型）")
    ap.add_argument("--platform", required=True)
    ap.add_argument("--preset", required=True)
    ap.add_argument("--brief-file", required=True, help="agent 写的 brief，不是文章原文")
    ap.add_argument("--out", required=True)
    for field in OVERRIDABLE:
        ap.add_argument(f"--{field}", default=None)
    args = ap.parse_args()

    try:
        brief = open(args.brief_file, encoding="utf-8").read().strip()
    except OSError as e:
        print(f"读不了 brief 文件: {e}", file=sys.stderr)
        return 1

    overrides = {f: getattr(args, f) for f in OVERRIDABLE if getattr(args, f)}
    try:
        text = compose(args.platform, args.preset, brief, overrides)
    except a.AssetError as e:
        print(str(e), file=sys.stderr)
        return 1

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text, encoding="utf-8")
    print(str(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
