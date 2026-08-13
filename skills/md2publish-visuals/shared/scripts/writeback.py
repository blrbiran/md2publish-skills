#!/usr/bin/env python3
"""把生成好的图片引用回写进 Markdown，另存为新文件。

**原文永不修改**（spec §9，与 wechat-finetune「原文不动、另存」一致）：本脚本
只读 --source，产物写到 --out。

**为什么是脚本而不是让 agent 手抄正文**：回写门要给用户看 diff，diff 必须是
确定性的；而让模型重打一遍整篇正文，漏字改字既无法断言也无法回滚。语义判断
（插哪、alt 写什么）仍然全在 agent 手里，它们由 --insertions 传进来。

**insertions 里的 image 必须抄自 sidecar 的 `image` 字段。** 压缩是新增不是
替换：超限时 NN-x.png 与 NN-x.jpg 并存，硬编 .png 会让正文引用到一个超限的
文件——这正是二期 A 把压缩塞进流程要消灭的失败模式，换个位置又活了。
"""

from __future__ import annotations

import argparse
import difflib
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import artifacts  # noqa: E402
import asset_lib as a  # noqa: E402

REQUIRED_KEYS = {"anchor", "position", "image", "alt"}
POSITIONS = ("after", "before")


def load_insertions(path: Path) -> list[dict]:
    if not path.exists():
        raise a.AssetError(f"insertions 文件不存在: {path}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        raise a.AssetError(f"insertions 不是合法 JSON: {e}")
    if not isinstance(data, list) or not data:
        raise a.AssetError("insertions 必须是非空数组")
    for i, item in enumerate(data):
        if not isinstance(item, dict):
            raise a.AssetError(f"insertions[{i}] 不是对象")
        keys = set(item)
        unknown = sorted(keys - REQUIRED_KEYS)
        if unknown:
            raise a.AssetError(
                f"insertions[{i}] 有未知字段 {unknown}；只接受 {sorted(REQUIRED_KEYS)}。"
                "拼错的键如果被静默忽略，图就会插到默认位置而没人发现"
            )
        missing = sorted(REQUIRED_KEYS - keys)
        if missing:
            raise a.AssetError(f"insertions[{i}] 缺字段 {missing}")
        if item["position"] not in POSITIONS:
            raise a.AssetError(
                f"insertions[{i}].position 必须是 {POSITIONS} 之一，实为 {item['position']!r}"
            )
        if os.sep in item["image"] or "/" in item["image"]:
            raise a.AssetError(
                f"insertions[{i}].image 只写文件名，实为 {item['image']!r}。"
                "目录由 --assets-dir 决定；两处各写一遍必然打架"
            )
    return data


def locate(lines: list[str], anchor: str, index: int) -> int:
    """锚点按整行匹配（忽略前后空白）。

    不用子串匹配：Markdown 里 "## 取舍" 这样的短串很容易在正文段落里再次出现，
    而插错位置比没插更难发现——产物看起来是成功的。
    """
    want = anchor.strip()
    hits = [i for i, line in enumerate(lines) if line.strip() == want]
    if len(hits) != 1:
        raise a.AssetError(
            f"insertions[{index}] 的锚点在原文里命中 {len(hits)} 次，必须恰好 1 次：\n"
            f"  {anchor!r}\n"
            "锚点要写成原文里的一整行（前后空白会被忽略）。命中 0 次多半是抄错了，"
            "命中多次要换一个更长、更独特的行"
        )
    return hits[0]


def build(source: Path, insertions: list[dict], assets_dir: Path, out: Path) -> list[str]:
    lines = source.read_text(encoding="utf-8").splitlines()
    rel = os.path.relpath(assets_dir.resolve(), out.resolve().parent)
    plan = []
    for i, item in enumerate(insertions):
        image_path = assets_dir / item["image"]
        if not image_path.exists():
            raise a.AssetError(
                f"insertions[{i}] 引用的图不存在: {image_path}\n"
                "image 要抄 sidecar 里的 image 字段——压缩过的图是 .jpg 不是 .png"
            )
        plan.append((locate(lines, item["anchor"], i), item))

    # 从后往前插，前面的行号才不会被前一次插入顶偏
    result = list(lines)
    for at, item in sorted(plan, key=lambda p: p[0], reverse=True):
        ref = f"![{item['alt']}]({rel}/{item['image']})".replace(os.sep, "/")
        block = ["", ref, ""]
        pos = at + 1 if item["position"] == "after" else at
        result[pos:pos] = block
    return result


def main() -> int:
    ap = argparse.ArgumentParser(description="把图片引用回写进 Markdown，另存为新文件")
    ap.add_argument("--source", required=True, help="原文，只读，永不修改")
    ap.add_argument("--insertions", required=True, help="agent 写的插入计划 JSON")
    ap.add_argument("--assets-dir", required=True, help="图片所在目录")
    ap.add_argument("--out", required=True, help="输出路径，通常是 <文章目录>/article.illustrated.md")
    ap.add_argument("--force", action="store_true", help="覆盖已存在的 --out")
    ap.add_argument("--dry-run", action="store_true", help="只打印 diff，不写文件")
    args = ap.parse_args()

    source, out = Path(args.source), Path(args.out)
    try:
        if not source.exists():
            raise a.AssetError(f"源文件不存在: {source}")
        if not args.dry_run:
            artifacts.guard(out, args.force)
        insertions = load_insertions(Path(args.insertions))
        new_lines = build(source, insertions, Path(args.assets_dir), out)
    except a.AssetError as e:
        print(str(e), file=sys.stderr)
        return 1

    old_lines = source.read_text(encoding="utf-8").splitlines()
    diff = difflib.unified_diff(old_lines, new_lines,
                                fromfile=str(source), tofile=str(out), lineterm="")
    print("\n".join(diff))

    if args.dry_run:
        print(f"\n（--dry-run：未写入 {out}）")
        return 0
    out.write_text("\n".join(new_lines) + "\n", encoding="utf-8")
    print(f"\n已写入 {out}（源文件 {source} 未改动）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
