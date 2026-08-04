#!/usr/bin/env python3
"""wechat-finetune 产物自检。

用法：
    python3 verify.py <原文.md> <产物.wechat.md>

检查四件事，前三件是硬性的（FAIL 就别交付），第四件只报数给人判断：

1. 代码块逐字节保真 —— 产物里的每个代码块都必须能在原文里找到一模一样的。
   精炼可以整块删代码，但块内改一个字符，读者照着敲就会失败，而这种错误
   肉眼几乎发现不了，所以交给脚本。
2. frontmatter 齐全且不超限 —— title/author/digest 三个字段，长度按微信硬限制。
3. 正文无残留 H1 —— 标题由 frontmatter 承载，正文再出现一次是重复。
4. 删减比例 —— 只统计不判定。删多删少只有作者知道该不该。

行内 code 的保真只报 WARN 不报 FAIL：改写句子时行内代码理应原样带过去，
但偶尔有合理的重组，留给人判断比一刀切拦住更合适。
"""

import re
import sys
from pathlib import Path

TITLE_MAX = 32
AUTHOR_MAX = 16
DIGEST_MAX = 128
FENCE_RE = re.compile(r"^(\s*)(```+|~~~+)(.*)$")
INLINE_CODE_RE = re.compile(r"`([^`\n]+)`")


def split_frontmatter(text):
    """返回 (frontmatter 原文, 正文)。没有 frontmatter 时前者为 ''。"""
    if not text.startswith("---"):
        return "", text
    lines = text.split("\n")
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            return "\n".join(lines[1:i]), "\n".join(lines[i + 1:])
    return "", text


def parse_fields(frontmatter):
    """够用的 key: value 解析，不引 yaml 依赖。"""
    fields = {}
    for line in frontmatter.split("\n"):
        if line.startswith((" ", "\t", "#")) or ":" not in line:
            continue
        key, _, value = line.partition(":")
        value = value.strip().strip("\"'")
        if value:
            fields[key.strip()] = value
    return fields


def extract_code_blocks(body):
    """按行扫围栏代码块，返回块内容列表（不含围栏行）。"""
    blocks, buf, fence = [], None, None
    for line in body.split("\n"):
        m = FENCE_RE.match(line)
        if fence is None:
            if m:
                fence, buf = m.group(2)[0] * 3, []
        else:
            if m and m.group(2).startswith(fence) and not m.group(3).strip():
                blocks.append("\n".join(buf))
                fence, buf = None, None
            else:
                buf.append(line)
    if buf is not None:
        blocks.append("\n".join(buf))
    return blocks


def strip_code(body):
    """去掉代码块，用于查 H1 和统计正文——代码里的 # 不是标题。"""
    out, fence = [], None
    for line in body.split("\n"):
        m = FENCE_RE.match(line)
        if fence is None:
            if m:
                fence = m.group(2)[0] * 3
            else:
                out.append(line)
        elif m and m.group(2).startswith(fence) and not m.group(3).strip():
            fence = None
    return "\n".join(out)


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2

    src_path, out_path = Path(sys.argv[1]), Path(sys.argv[2])
    for p in (src_path, out_path):
        if not p.is_file():
            print(f"FAIL  文件不存在：{p}")
            return 2

    src = src_path.read_text(encoding="utf-8")
    out = out_path.read_text(encoding="utf-8")
    src_body = split_frontmatter(src)[1]
    fm_raw, out_body = split_frontmatter(out)
    fields = parse_fields(fm_raw)

    failures = []
    warnings = []

    # 1. 代码块保真
    src_blocks = extract_code_blocks(src_body)
    out_blocks = extract_code_blocks(out_body)
    src_set = set(src_blocks)
    drifted = [b for b in out_blocks if b not in src_set]
    if drifted:
        failures.append(
            f"代码块保真：{len(drifted)}/{len(out_blocks)} 个代码块在原文里找不到逐字节相同的版本"
        )
        for b in drifted[:3]:
            head = (b.strip().split("\n") or [""])[0][:70]
            failures.append(f"        └ 首行：{head}")
    else:
        print(f"PASS  代码块保真：{len(out_blocks)}/{len(src_blocks)} 块保留，全部逐字节一致")

    # 2. frontmatter
    limits = {"title": TITLE_MAX, "author": AUTHOR_MAX, "digest": DIGEST_MAX}
    for key, limit in limits.items():
        value = fields.get(key)
        if not value:
            failures.append(f"frontmatter 缺 {key}")
        elif len(value) > limit:
            failures.append(f"frontmatter {key} 超限：{len(value)} 字符 > {limit}")
        else:
            print(f"PASS  frontmatter {key}：{len(value)}/{limit} 字符")

    # 3. 残留 H1
    h1 = [l for l in strip_code(out_body).split("\n") if re.match(r"^#\s+\S", l)]
    if h1:
        failures.append(f"正文残留 H1（应只存在于 frontmatter.title）：{h1[0][:60]}")
    else:
        print("PASS  正文无残留 H1")

    # 行内 code：WARN，不拦
    src_inline = set(INLINE_CODE_RE.findall(strip_code(src_body)))
    new_inline = [c for c in set(INLINE_CODE_RE.findall(strip_code(out_body))) if c not in src_inline]
    if new_inline:
        warnings.append(
            f"行内 code 有 {len(new_inline)} 处在原文中不存在，人工确认没改坏："
            + "、".join(f"`{c}`" for c in new_inline[:5])
        )

    # 4. 删减比例
    src_n, out_n = len(src_body.strip()), len(out_body.strip())
    kept = out_n / src_n * 100 if src_n else 0
    print(f"INFO  正文字符：{src_n} → {out_n}（保留 {kept:.0f}%）")
    if kept < 70:
        warnings.append(f"删减超过 30%（保留 {kept:.0f}%），请作者复核是否削掉了舍不得的内容")

    for w in warnings:
        print(f"WARN  {w}")
    for f in failures:
        print(f"FAIL  {f}" if not f.startswith(" ") else f)

    if failures:
        print(f"\n结果：FAIL（{len([f for f in failures if not f.startswith(' ')])} 项）——修复后重跑")
        return 1
    print("\n结果：PASS" + ("（有 WARN，人工确认后可交付）" if warnings else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
