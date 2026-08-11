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


def sidecar(image: Path, meta: dict) -> Path:
    if not image.exists():
        raise a.AssetError(f"图片不存在，无法写 sidecar: {image}")
    preset = a.load_preset(meta["preset"])     # preset 不存在时在这里硬失败
    record = {
        "platform": meta["platform"],
        "archetype": meta["archetype"],
        "preset": meta["preset"],
        "preset_version": preset["version"],
        "overrides": meta["overrides"],
        "provider": meta["provider"],
        "model": meta["model"],
        "prompt_file": meta["prompt_file"],
        "brief_file": meta["brief_file"],
        "alt_text": meta["alt_text"],
        "image": image.name,
        "bytes": image.stat().st_size,
        "generated_at": datetime.now().astimezone().isoformat(timespec="seconds"),
    }
    out = image.with_suffix(".json")
    out.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="产物落盘规则：重跑保护与 sidecar 元数据")
    sub = ap.add_subparsers(dest="cmd", required=True)

    g = sub.add_parser("guard", help="目标已存在则拦住，除非 --force")
    g.add_argument("--path", required=True)
    g.add_argument("--force", action="store_true")

    s = sub.add_parser("sidecar", help="写 <image 同名>.json，记录生成它的全部输入")
    s.add_argument("--image", required=True)
    for field in ("platform", "archetype", "preset", "provider", "model",
                  "prompt-file", "brief-file", "alt-text"):
        s.add_argument(f"--{field}", required=True)
    s.add_argument("--override", action="append", default=[], metavar="KEY=VALUE")

    args = ap.parse_args()
    try:
        if args.cmd == "guard":
            guard(Path(args.path), args.force)
            return 0
        out = sidecar(Path(args.image), {
            "platform": args.platform,
            "archetype": args.archetype,
            "preset": args.preset,
            "provider": args.provider,
            "model": args.model,
            "prompt_file": args.prompt_file,
            "brief_file": args.brief_file,
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
