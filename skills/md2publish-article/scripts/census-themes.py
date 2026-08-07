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

本文件目前实现 UNCARRIED / INVENTED / INLINE-BLOCK（L1，主题 .md ↔ theme.json
色值/键位比对）与 UNMOUNTED（L3，散文语义条款 ↔ theme.json 机械字段）四档，
都不需要产物语料。ZERO / NEAR-ZERO / DECOR / INVERT / STALE-NOTE 五档接产物
语料（L2），由后续任务补上；豁免机制同样留给后续任务。
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
    #
    # 走 spec_lines 而不是直接对 clean 做 re.findall，是为了让 declared 的定义
    # 「规范行里的色」在语义上独立于 all_md 的定义「全文任意处的色」——即使两者
    # 在当前实现下取值恒等（见下）。theme_lib.py:59 的 _ENTITY 第一个分支就是
    # `#[0-9a-fA-F]{6}` 本身：任何带色值的行天然满足「含可机械化实体」，落进
    # spec_lines。因此 declared（spec_lines 各行色值的并集）与 all_md（全文色值
    # 集合）在当前 _ENTITY 下恒等——已对全库 27 对主题验证，0 处不同，
    # spec_lines 这一步在 L1 里眼下是零过滤。这不是本档的 bug，是 _ENTITY 定义
    # 的必然结果，记在这里防止以后有人「优化」成直接对 clean 取色值当作 declared。
    # 但这条恒等关系是**脆的**：_ENTITY 的色值分支若被收窄（比如为了堵 URL 假阳性
    # 把它删掉，只留 style=/CSS 声明两个分支），declared 就会立刻变窄于 all_md，
    # UNCARRIED 的判定含义随之改变——届时需要一条真正区分两者的 fixture，
    # 而不是继续依赖当前这个恒等关系。
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


# 关键词 → 必须存在的 theme.json 字段。信号写成**组合**而不是字面整串：
# 第一版写「警示性 strong」，而 cyber-neon.md:36 的原文是「这类警示语义的 `strong`」，
# 字面不匹配——靶子就是这么丢的。
# 每项：(必须全部出现的信号组, 字段名, 前缀黑名单)
KEYWORD_FIELDS = [
    ((("导语", "首段", "全文第一段"),), "p_first", ("引",)),
    ((("首个 h2", "第一个 h2", "首节标题"),), "h2_first", ()),
    ((("警示", "注意", "警告"), ("strong",)), "strong_alt", ()),
    ((("印章", "落款", "文末装饰"),), "footer_html", ()),
    ((("提示卡",),), "alert", ()),
    ((("斑马纹", "隔行"),), "td_alt", ()),
    ((("有序列表", "序号"),), "list_prefix_ol_html", ()),
    ((("语法高亮",),), "highlight", ()),
    ((("轮换", "轮转"),), "list_prefix_cycle", ()),
    ((("对称饰线", "两侧饰线"),), "h2_suffix_html", ()),
]

# md2html.py docstring 字段表里的位置性/语义性字段，每个都必须在上表里有条目。
# 这份表和 KEYWORD_FIELDS 一样是手写的、都写在本文件里——assert_keyword_table_
# complete 只核对这两份手写表彼此同步，并不读 md2html.py，所以查不出"md2html.py
# 本身新增了一个语义字段、这里两份表都忘了加"这种情况（那需要真的去解析
# md2html.py 的字段表，这份断言做不到）。它能查出的是「这两份手写表自己漏同步」，
# 比如给 KEYWORD_FIELDS 加了新字段却忘了把字段名加进 SEMANTIC_FIELDS，反过来
# 也一样——立刻 FAIL，而不是静默漏检。
SEMANTIC_FIELDS = {
    "p_first", "h2_first", "strong_alt", "footer_html", "alert", "td_alt",
    "list_prefix_ol_html", "highlight", "list_prefix_cycle", "h2_suffix_html",
}

NEGATIONS = ("不要", "别", "不用", "建议改用")
# 引号内的否定词不算——引号里是被引用的字面串，不是作者在否定什么。
_QUOTED = re.compile(r"「[^」]*」|\"[^\"]*\"|“[^”]*”|`[^`]*`")


def _negated(line, pos, word):
    """关键词命中位置附近有没有真正的否定。

    三条护栏缺一不可，第一版三条全踩了：
      1. 只在前后各 8 字的局部窗口内判，不做整行布尔判定
      2. 引号内的否定词不算（cyber-neon.md:36 的「不要」躺在被引用的枚举里，
         距关键词约 10 字，光靠窗口挡不住）
      3. 单字「无」只在「无<关键词>」这种紧邻组合里算否定
         （全库到处是「无序前缀」「无卡片」「无彩色」）
    """
    masked = _QUOTED.sub(lambda m: "　" * len(m.group()), line)
    lo, hi = max(0, pos - 8), min(len(masked), pos + len(word) + 8)
    window = masked[lo:hi]
    if any(n in window for n in NEGATIONS):
        return True
    return ("无" + word) in masked


def check_l3(name, md_text, theme):
    """L3：散文条款 ↔ 机械字段。不需要语料。"""
    found = []
    lines = spec_lines(strip_comments(md_text))
    for signals, field, blacklist in KEYWORD_FIELDS:
        if theme.get(field):
            continue
        for _, line in lines:
            hits = []
            for group in signals:
                hit = None
                for word in group:
                    for m in re.finditer(re.escape(word), line):
                        # 前缀黑名单：CJK 没有词边界，\b 在汉字之间永不成立
                        if any(line[max(0, m.start() - len(b)):m.start()] == b
                               for b in blacklist):
                            continue
                        if _negated(line, m.start(), word):
                            continue
                        hit = (m.start(), word)
                        break
                    if hit:
                        break
                if not hit:
                    hits = []
                    break
                hits.append(hit)
            if hits:
                found.append(("UNMOUNTED", name, field,
                              f"规范里写了这条，theme.json 无 {field} 字段"))
                break
    return found


def assert_keyword_table_complete():
    """语义字段必须在关键词表里有条目，缺一条 FAIL。"""
    covered = {f for _, f, _ in KEYWORD_FIELDS}
    missing = SEMANTIC_FIELDS - covered
    if missing:
        print(f"FAIL 关键词表漏了语义字段：{sorted(missing)}")
        print("     新增 md2html.py 字段时要同步 KEYWORD_FIELDS。")
        return False
    return True


def report(found):
    # 每列后补一个空格再垫宽，保证列之间至少有一个分隔符——不然像
    # list_prefix_ol_html（20 字符）这种超过 12 宽的键会跟 why 文本连写，
    # 靠空白分列的 awk（test-census-themes.sh 的 check()）就取不出正确的列。
    for tier, theme, key, why in found:
        print(f"{tier + ' ':<13}{theme + ' ':<24}{key + ' ':<12}{why}")
    print(f"\n普查完毕，{len(found)} 条未销")
    return 1 if found else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fixture-dir")
    args = ap.parse_args()

    found = []
    if not assert_keyword_table_complete():
        return 1
    if args.fixture_dir:
        d = args.fixture_dir
        for f in sorted(os.listdir(d)):
            if not f.endswith(".md"):
                continue
            name = f[:-3]
            jp = os.path.join(d, name + ".theme.json")
            if not os.path.exists(jp):
                continue
            md_text, theme = open(os.path.join(d, f)).read(), json.load(open(jp))
            found += check_l1(name, md_text, theme) + check_l3(name, md_text, theme)
    else:
        ref = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "references")
        for base, md, js in theme_pairs(ref):
            if not os.path.exists(md):
                print(f"FAIL 对照表不完整：{base} 找不到 {md}")
                return 1
            md_text, theme = open(md).read(), json.load(open(js))
            found += check_l1(base, md_text, theme) + check_l3(base, md_text, theme)
    return report(found)


if __name__ == "__main__":
    sys.exit(main())
