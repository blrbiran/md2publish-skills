#!/usr/bin/env python3
"""产物落盘规则：重跑保护（spec §7.3）与 sidecar 元数据（spec §5.3）。

两件事都是确定性动作，因此写成脚本而不是交给 agent 判断——被覆盖的是花钱
生成的东西，"永不静默覆盖"这条不该依赖模型记性；sidecar 的 preset_version
也必须从 YAML 读，手填迟早填错，而它存在的意义正是事后查得出版本。
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import asset_lib as a  # noqa: E402


def guard(path: Path, force: bool) -> None:
    if path.exists() and not force:
        raise a.AssetError(
            f"目标已存在，跳过：{path}\n"
            "它是花钱生成的产物，不会被静默覆盖。确实要重生成就加 --force。"
        )


def parse_overrides(pairs: list[str]) -> dict:
    out = {}
    for pair in pairs:
        if "=" not in pair:
            raise a.AssetError(f"--override 要写成 key=value，实为 {pair!r}")
        key, value = pair.split("=", 1)
        out[key.strip()] = value.strip()
    return out


# 零成本、确定性产出的 archetype：不调 AI，因此没有 preset / prompt / brief / model。
# 它们的 provider 字段记的是**光栅化后端**（rsvg-convert / magick / chrome）——
# 同一份 SVG 在不同机器上会被不同后端渲染成不同的位图，不记就无从追溯。
DETERMINISTIC_ARCHETYPES = {"diagram"}


def sidecar(image: Path, meta: dict) -> Path:
    if not image.exists():
        raise a.AssetError(f"图片不存在，无法写 sidecar: {image}")
    if meta["archetype"] in DETERMINISTIC_ARCHETYPES:
        preset_name = None
        preset_version = None
    else:
        preset = a.load_preset(meta["preset"])   # preset 不存在时在这里硬失败
        preset_name = meta["preset"]
        preset_version = preset["version"]
    record = {
        "platform": meta["platform"],
        "archetype": meta["archetype"],
        "preset": preset_name,
        "preset_version": preset_version,
        "overrides": meta["overrides"],
        "provider": meta["provider"],
        "model": meta["model"],
        "prompt_file": meta["prompt_file"],
        "brief_file": meta["brief_file"],
        "source_file": meta["source_file"],
        "alt_text": meta["alt_text"],
        "image": image.name,
        "bytes": image.stat().st_size,
        "generated_at": datetime.now().astimezone().isoformat(timespec="seconds"),
    }
    out = image.with_suffix(".json")
    out.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return out


def check_sidecar_args(args) -> None:
    """按 archetype 分支校验必填项。

    argparse 的 required=True 做不到这件事：cover 必须有 preset，diagram 必须没有。
    放任 diagram 传 preset 不报错的话，照抄 cover 命令的人会得到一份声称走过
    preset 链路、实际根本没有的 sidecar。

    另外两件 argparse 也拦不住的事，一并在这里挡掉：
    - `--image ""`：argparse 认为它"给了"，而 Path("") 是当前目录、exists() 为真，
      于是 sidecar() 里"图片不存在"那道提示放它过去，最后炸在 with_suffix() 上。
    - 拼错的 archetype：分支逻辑只认 diagram，其余一律当 AI 支路放行，于是
      `--archetype covr` 会写出一份 archetype 是乱码的 sidecar，rc=0。
    """
    if not args.image:
        raise a.AssetError(
            "--image 不能为空：空串会被解析成当前目录，"
            "既绕过'图片不存在'的检查，也算不出 sidecar 该叫什么名字"
        )
    if args.archetype not in a.ARCHETYPES:
        raise a.AssetError(
            f"未知 archetype: {args.archetype}；可选 {a.ARCHETYPES}"
        )
    ai_only = (
        ("--preset", args.preset),
        ("--model", args.model),
        ("--prompt-file", args.prompt_file),
        ("--brief-file", args.brief_file),
    )
    if args.archetype in DETERMINISTIC_ARCHETYPES:
        if not args.source_file:
            raise a.AssetError(
                f"--archetype {args.archetype} 必须给 --source-file"
                "（SVG 的文件名，不是路径）：它是这张图唯一的复现记录"
            )
        given = [flag for flag, value in ai_only if value]
        if given:
            raise a.AssetError(
                f"--archetype {args.archetype} 不接受 {given}："
                "它不调 AI、不走 preset / prompt 链路，这些字段一律记 null"
            )
        return
    missing = [flag for flag, value in ai_only if not value]
    if missing:
        raise a.AssetError(f"--archetype {args.archetype} 缺必填参数: {missing}")
    if args.source_file:
        raise a.AssetError("--source-file 只用于确定性 archetype（当前：diagram）")


def main() -> int:
    ap = argparse.ArgumentParser(description="产物落盘规则：重跑保护与 sidecar 元数据")
    sub = ap.add_subparsers(dest="cmd", required=True)

    g = sub.add_parser("guard", help="目标已存在则拦住，除非 --force")
    g.add_argument("--path", required=True)
    g.add_argument("--force", action="store_true")

    s = sub.add_parser("sidecar", help="写 <image 同名>.json，记录生成它的全部输入")
    s.add_argument("--image", required=True)
    # 所有 archetype 都必须有的
    for field in ("platform", "archetype", "provider", "alt-text"):
        s.add_argument(f"--{field}", required=True)
    # 按 archetype 分支必填，由 check_sidecar_args 校验（argparse 表达不了这种条件必填）
    for field in ("preset", "model", "prompt-file", "brief-file", "source-file"):
        s.add_argument(f"--{field}", default=None)
    s.add_argument("--override", action="append", default=[], metavar="KEY=VALUE")

    args = ap.parse_args()
    try:
        if args.cmd == "guard":
            guard(Path(args.path), args.force)
            return 0
        check_sidecar_args(args)
        out = sidecar(Path(args.image), {
            "platform": args.platform,
            "archetype": args.archetype,
            "preset": args.preset,
            "provider": args.provider,
            "model": args.model,
            "prompt_file": args.prompt_file,
            "brief_file": args.brief_file,
            "source_file": args.source_file,
            "alt_text": args.alt_text,
            "overrides": parse_overrides(args.override),
        })
    except a.AssetError as e:
        print(str(e), file=sys.stderr)
        return 1
    print(str(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
