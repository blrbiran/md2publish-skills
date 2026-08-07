#!/usr/bin/env python3
"""产物落点普查：把「声明了什么」「兑现了什么」「实际出现几次」三侧对起来。

用法：
    python3 census-themes.py                      # 扫真实主题库
    python3 census-themes.py --fixture-dir DIR    # 变异测试用，DIR/<n>.md + DIR/<n>.theme.json
    python3 census-themes.py --counts <主题名>     # 输出该主题每个调色板色的落点分解

背景见 docs/superpowers/specs/2026-08-07-product-landing-census-design.md。
核心认知：audit-themes.py 报 0 条不等于主题成立——它查主题文件里有没有**声明**落点，
不查产物里这个色出现几次。本仓库已知四次「规范白纸黑字写着、产物里 0 处」全部逃过了
现有的每一条检查。

判定分九档，严重度三级（ERROR / WARN / INFO），三级都可用注记豁免：

    <!-- census-ok: <档名> <键> <一句话理由> -->

**基线是「未销掉的 = 0 条」**，与 audit-themes.py 同一套约定。

本文件（L1）只实现 UNCARRIED / INVENTED / INLINE-BLOCK 三档——主题 .md ↔
theme.json 的比对，不需要语料。UNMOUNTED / ZERO / NEAR-ZERO / DECOR / INVERT /
STALE-NOTE 六档接产物语料（L2/L3），由后续任务补上；豁免机制同样留给后续任务。
配套的变异测试见 test-census-themes.sh。
"""

import argparse
import collections
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from theme_lib import strip_comments, spec_lines, theme_pairs

SEVERITY = {
    "UNCARRIED": "ERROR", "INVENTED": "ERROR", "INLINE-BLOCK": "ERROR",
    "UNMOUNTED": "ERROR", "ZERO": "ERROR", "NEAR-ZERO": "WARN",
    "DECOR": "WARN", "INVERT": "INFO", "STALE-NOTE": "ERROR",
}

# 承担定宽的键，照 md2html.py 里 boxed=True 的实际集合定，不用「主题有没有卡片」近似。
#   card   md2html.py:324  恒 True
#   顶层块  md2html.py:356 起  boxed = not card_open，即仅无卡片主题
#   footer md2html.py:434  恒 True，与有无卡片无关
TOP_BLOCK = ("p", "p_first", "h2", "h2_first", "h3", "blockquote",
             "pre", "table", "list_item", "hr")


def json_colors(theme):
    """theme.json 里出现的全部色值 → 出现在哪些键上。"""
    out = collections.defaultdict(set)

    def walk(key, val):
        if isinstance(val, dict):
            for v in val.values():
                walk(key, v)
        elif isinstance(val, list):
            for v in val:
                walk(key, v)
        else:
            for c in re.findall(r"#[0-9a-fA-F]{6}", str(val)):
                out[c.lower()].add(key)

    for k, v in theme.items():
        walk(k, v)
    return out


def boxed_keys(theme):
    """这份 theme.json 里，哪些键会被 md2html.py 拼上定宽串。"""
    keys = ["footer"]
    if theme.get("card"):
        keys.append("card")
    else:
        keys.extend(TOP_BLOCK)
    return keys


def check_l1(name, md_text, theme):
    """L1：主题 .md ↔ theme.json。不需要语料，任何时候都能跑完。"""
    found = []
    clean = strip_comments(md_text)
    jc = json_colors(theme)

    # UNCARRIED：规范行里声明的色，theme.json 一次都不出现
    declared = set()
    for _, line in spec_lines(clean):
        declared.update(c.lower() for c in re.findall(r"#[0-9a-fA-F]{6}", line))
    for c in sorted(declared - set(jc)):
        found.append(("UNCARRIED", name, c, "主题文件声明了，theme.json 没兑现"))

    # INVENTED：theme.json 里的色，主题文件任何位置都没有（规则 9：不许自己造色）
    all_md = set(c.lower() for c in re.findall(r"#[0-9a-fA-F]{6}", clean))
    for c in sorted(set(jc) - all_md):
        found.append(("INVENTED", name, c,
                      f"theme.json 现造的色，主题文件里没有（落在 {sorted(jc[c])}）"))

    # INLINE-BLOCK：承担定宽的键不能是 inline-block（判例）
    for k in boxed_keys(theme):
        v = theme.get(k)
        if isinstance(v, str) and "inline-block" in v:
            found.append(("INLINE-BLOCK", name, k,
                          "承担定宽的元素用 inline-block，auto 外边距会算成 0"))
    return found


def report(found):
    for tier, theme, key, why in found:
        print(f"{tier:<13}{theme:<24}{key:<12}{why}")
    print(f"\n普查完毕，{len(found)} 条未销")
    return 1 if found else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fixture-dir")
    args = ap.parse_args()

    found = []
    if args.fixture_dir:
        d = args.fixture_dir
        for f in sorted(os.listdir(d)):
            if not f.endswith(".md"):
                continue
            name = f[:-3]
            jp = os.path.join(d, name + ".theme.json")
            if not os.path.exists(jp):
                continue
            found += check_l1(name, open(os.path.join(d, f)).read(),
                              json.load(open(jp)))
    else:
        ref = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "references")
        for base, md, js in theme_pairs(ref):
            if not os.path.exists(md):
                print(f"FAIL 对照表不完整：{base} 找不到 {md}")
                return 1
            found += check_l1(base, open(md).read(), json.load(open(js)))
    return report(found)


if __name__ == "__main__":
    sys.exit(main())
