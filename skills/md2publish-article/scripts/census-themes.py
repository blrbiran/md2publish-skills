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

`census-ok` 与 audit-themes.py 的 `audit-ok` 前缀故意不同——两套注记共存于
同一批主题文件，各认各的前缀。注记若销不到任何发现，报第十档 STALE-NOTE；
档名打错（SEVERITY 里没有的档）直接 FAIL，不许静默地什么都不销。
**基线是「未销掉的 = 0 条」**，与 audit-themes.py 同一套约定。

本文件目前实现 UNCARRIED / INVENTED / INLINE-BLOCK（L1，主题 .md ↔ theme.json
色值/键位比对）、UNMOUNTED（L3，散文语义条款 ↔ theme.json 机械字段），以及
ZERO / NEAR-ZERO / DECOR / INVERT（L2，theme.json ↔ 产物 HTML，需要
`--article`/`MD2HTML_CORPUS` 指到的语料；语料缺失时 L2 整体 SKIP 并把退出码
标红，不静默跳过），加上豁免注记与 STALE-NOTE（按层设门：L2 SKIP 的一轮里，
L2 档的注记不判 stale）。
配套的变异测试见 test-census-themes.sh。
"""

import argparse
import collections
import json
import os
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from theme_lib import (strip_comments, spec_lines, theme_pairs, palette, landings,
                        exemptions, malformed_exemptions)

SEVERITY = {
    "UNCARRIED": "ERROR", "INVENTED": "ERROR", "INLINE-BLOCK": "ERROR",
    "UNMOUNTED": "ERROR", "ZERO": "ERROR", "ZERO-DUP": "INFO", "NEAR-ZERO": "WARN",
    "DECOR": "WARN", "INVERT": "INFO", "STALE-NOTE": "ERROR",
}

# 注记档名的合法集合，**不含** STALE-NOTE：它是 apply_exemptions 自己算出来的产物，
# 不走 rows 匹配那条路（stale 行由 apply_exemptions 直接 append，从不进 kept 再被销），
# 一条 `census-ok: STALE-NOTE ...` 注记永远销不到任何东西——写它只可能是打错档名，
# 不该被 `tier not in SEVERITY` 那条防线放过。
LEGAL_NOTE_TIERS = set(SEVERITY) - {"STALE-NOTE"}

# 承担定宽的键，照 md2html.py 里 boxed=True 的实际集合定，不用「主题有没有卡片」近似。
#   card   md2html.py:324  恒 True
#   顶层块  md2html.py:356 起  boxed = not card_open，即仅无卡片主题
#   footer md2html.py:434  恒 True，与有无卡片无关
TOP_BLOCK = ("p", "p_first", "h2", "h2_first", "h3", "blockquote",
             "pre", "table", "list_item", "hr")

# NEAR-ZERO 的 container 锚点判据：色值挂在 `container` 上、且没有挂到任何别的
# 会随文章内容重复的键上时，落点 ≤2 **不构成「几乎没出现」**，不报 NEAR-ZERO。
#
#     "container" in mounts and mounts <= NEAR_ZERO_OK_KEYS
#
# **锚点是 `container`，判据不是「build() 只发射一次」。**这个区别是实打实的，
# 第一版正是栽在这里：`md2html.py:426-434` 里 `footer` 与 `footer_html` 由同一个
# `if T.get("footer_html")` 守着、同属文末那一个 `<p>`，**次数**跟 `container`
# 一样固定 ≤1。按「只发一次」推导，三个键平级——那样一个「唯一强调色只落在文末
# 落款上」的主题会被静默，而那恰恰是 apple-air 立项缺陷的形状。
#
# **区分性质是面积/角色，不是次数**：`container`（md2html.py:439，整篇唯一的最外层
# `<div>`）是铺满整页的底，落 1 次等于全覆盖；文末那个 `<p>` 是个落款，落 1 次就是
# 真的几乎没有。所以只有 `container` 能提供豁免的正当性，它是**必要条件**。
#
# `footer` / `footer_html` 进 NEAR_ZERO_OK_KEYS 不是因为它们自己够格，而是因为
# 它们是额外的一次性挂载点、不破坏 `container` 已经给出的正当性——27-retro-phosphor
# 就是把容器底色 `#0d120d` 又用在了文末终端行上。**没有 `container` 在场时，
# 它们一个都不豁免**（test-census-themes.sh 的 l2-nearzero-footer-html-only
# 与既有的 l2-nearzero 一起钉着这条）。
#
# 判定用**子集**而不是「沾一个就算」：挂载键里只要有一个在集合之外（哪怕
# `container` 也在），这个色的落点就依赖文章内容，必须按真实计数判。
# **别往这个集合里加键**——真正危险的是「在某篇文章里可以落 0 次」的那一类
# （`hr`、`list_prefix_ol_html`、`td_alt`、`blockquote`、`pre`、`table`）：它们看着
# 也「不随长度变化」，其实是随内容有无而变，加进来就能让总数落进 ≤2 却完全依赖内容。
# 单键扩大由 l2-nearzero-allowset-hr / -ol（`hr`、`list_prefix_ol_html`）与
# l2-nearzero-structural-plus（`td_alt`）钉着。
#
# 判定依据只能是挂载键，**绝不能是调色板标签**：19-candy-pop 的 `#e8f2f9` 标签正是
# 「浅蓝底」，任何「标签含底/背景就豁免」的写法（以及 REF_EXCLUDE 那类词表）都会
# 连带灭掉那条真死色——它只挂在 `em` 上，中文文章里 em 可能整篇为零（规则 1）。
NEAR_ZERO_ANCHOR = "container"
NEAR_ZERO_OK_KEYS = frozenset({"container", "footer", "footer_html"})


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
    # 集合）在当前 _ENTITY 下恒等——已对全库 26 对主题验证，0 处不同，
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
    # L3 只看 spec_lines 挑出来的、带可机械化实体的行（#hex / style= / 属性: 值，
    # 见 theme_lib.py:59 的 _ENTITY）。一句只用中文名字指色、不带 hex/style= 的
    # 散文条款，对这一层是不可见的——已知现存实例：
    # references/theme-prompts/cyber-neon.md:37「提示卡里属于警示性质的那种，
    # 标题和左边框用品红」，`13-cyber-neon-v7-edge` 的 theme.json 没有 `alert`
    # 键，字面上完全满足 UNMOUNTED 的定义，但因为这行没有 hex/style=/属性:值，
    # 进不了 spec_lines，眼下报的是 0。人已经在 2026-08-07 裁定接受这个已知
    # 局限、不为了扩大这里的口径去动 _ENTITY——量过替代方案的代价：把这里的
    # 过滤条件去掉、对全部行（而不只是 spec_lines 挑出的行）跑同一套关键词表，
    # 全库只多出 2 条：上面这条真阳性，外加 `06-editor-slate:82`「比 strong
    # 高一档」这一条假阳性（那行的「注意」说的是提示卡触发语法，「strong」只是
    # 拿来类比优先级，不是警示性 strong 的规范条款）。这个已知空洞记在
    # task-4-report.md 的「留给 Task 7」一节，由人工兜底，不在这一层扩口径去追。
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


ACCENT_ROLE = ("强调", "点睛", "accent", "主色")
# 参照色的排除项：装饰面计数天然高或天然低；正文色必然压倒一切强调色，拿它作参照会
# 多报——实测清空 REF_EXCLUDE 后真实库是 44 条而不是 43，多出 1 条 INVERT（不是「全库
# 都报了」这么夸张，改动前先核过数字，别凭直觉写）。ZERO/NEAR-ZERO 那个循环从不套用
# REF_EXCLUDE，这条警告仍然成立、不因为上面这句更正而减弱：「次级灰」含「次级」，
# 若误把 REF_EXCLUDE 也接到那个循环上，会连 aurora-flow 的立身缺陷一起豁免掉。
REF_EXCLUDE = ("底", "背景", "线", "边", "卡片", "面板", "纸面", "块",
               "正文", "主文字", "默认文字", "次级")


def _label(line):
    """只取冒号前的角色标签，不看破折号后的解释文字。

    这是 audit-themes.py:113-115 已有的纪律。washi-spring 的
    「灰樱粉（线色，不作文字色）：#d98e9f——……不能算主强调」整行搜「强调」
    会把它误判成强调色，而它恰恰声明了自己不是。
    """
    return re.split(r"[：:]", line.lstrip("-* "), 1)[0]


def render(article, theme_path, workdir, name):
    """现场用 md2html.py 生成产物。不读 out/ 定稿——那套 -v1/-v5 命名混乱，
    且「定稿与 theme.json 同步」这个假设失效恰恰是本脚本要报的毛病之一。"""
    out = os.path.join(workdir, name + ".html")
    md2html = os.path.join(os.path.dirname(os.path.abspath(__file__)), "md2html.py")
    r = subprocess.run([sys.executable, md2html, article, theme_path, "-o", out],
                       capture_output=True)
    if r.returncode != 0:
        return None, r.stderr.decode()[:200]
    return open(out).read(), None


def bucket_sum(landing, bucket):
    """某个色的落点计数器（landings() 返回值里某个色对应的 Counter[(标签, 桶)]）
    里，某一个桶（text/fill/line）的落点总数。

    check_l2 的 text_count 与 --counts 的 print_counts 共用这一个函数——两处
    「文字」的口径必须是同一份代码，不能各自重新写一遍 sum(...)。否则谁改了
    DECOR/INVERT 用的桶定义，--counts 会悄悄跟丢，人类拿着 --counts 印出来的
    旧数字写豁免注记，注记从写下来那一刻就是错的（Trap 3）。
    """
    return sum(v for (_, b), v in landing.items() if b == bucket)


def check_l2(name, md_text, html, already, theme):
    """L2：theme.json ↔ 产物。already 是 L1 已报过 UNCARRIED 的色值集合。"""
    found = []
    land = landings(html)
    mounts = json_colors(theme)
    # 小写化只做在这个调用点，不做进 palette() 本身——palette() 也喂给
    # audit-themes.py，在那边小写化会改动它的输入（复审测过对本库是 no-op，
    # 43→43，但「测过是 no-op」不等于「安全去改共享原语」）。landings() 的键
    # 恒为小写（theme_lib.py:135 的 c.lower()），主题 .md 若写 `#FFFFFF`，
    # pal 的键不转小写就永远查不到 land 里的落点，凭空报一条 ZERO。
    pal = {c.lower(): line for c, line in palette(strip_comments(md_text)).items()}

    def text_count(c):
        return bucket_sum(land.get(c, {}), "text")

    for color, line in pal.items():
        total = sum(land.get(color, {}).values())
        label = _label(line)
        is_accent = any(k in label for k in ACCENT_ROLE)

        if total == 0:
            if color in already:
                # 去重只降级不消失：若直接删掉，一旦给 UNCARRIED 写了豁免注记，
                # 「这个色在产物里 0 处」这个事实就从报告里彻底消失了。
                found.append(("ZERO-DUP", name, color, "产物 0 处（已由 UNCARRIED 报过）"))
            else:
                found.append(("ZERO", name, color, "调色板声明了，产物里 0 处"))
            continue
        if total <= 2:
            # 铺满整页的容器底色，落点 ≤2 不是「几乎没出现」，见 NEAR_ZERO_OK_KEYS
            # 的说明。锚点 `container` 是必要条件，所以这里不需要再管空集——
            # 「theme.json 里根本没有这个色」时锚点判定直接为假。
            #
            # 「ZERO 一律不动」这条约束**由锚点本身保证，不是靠这道门放在哪**：
            # `container` 的样式串必然渲染进最外层 `<div>`，所以带锚点的色落点恒 ≥1，
            # 永远走不到上面 `total == 0` 那条分支。实测把这道门上移到循环开头，
            # 62 条用例全绿、真实库输出逐字节不变——**它是行为等价的**。
            # 门留在这个分支里只是为了读起来清楚，别在注释里把它说成判据的一部分：
            # 没有任何用例能证死那个改法，声称钉住了就是假覆盖。
            keys = mounts.get(color, set())
            if NEAR_ZERO_ANCHOR in keys and keys <= NEAR_ZERO_OK_KEYS:
                continue
            # continue 在这里：落点≤2 时不再往下判 DECOR，即便这 ≤2 处全是边框/
            # 底色——NEAR-ZERO 已经把这个色标出来了，不需要 DECOR 再报一遍同一个
            # 「几乎没有」的事实。属于故意，不是漏判（review 2026-08-08 确认）。
            found.append(("NEAR-ZERO", name, color, f"产物里只有 {total} 处"))
            continue
        if is_accent and text_count(color) == 0:
            found.append(("DECOR", name, color,
                          f"标为强调却没有文字色落点（{total} 处全是边框/底色）"))

    # INVERT：主强调的文字落点少于副/辅强调，或不足参照色的三分之一
    mains = [(c, l) for c, l in pal.items()
             if "主强调" in _label(l) or "唯一强调" in _label(l)]
    subs = [(c, l) for c, l in pal.items()
            if "副强调" in _label(l) or "辅强调" in _label(l)]
    refs = [(c, l) for c, l in pal.items()
            if not any(k in _label(l) for k in ACCENT_ROLE)
            and not any(k in _label(l) for k in REF_EXCLUDE)]
    for c, _ in mains:
        n = text_count(c)
        why = None
        for sc, sl in subs:
            if text_count(sc) > n:
                why = f"主强调文字落点 {n}，少于副/辅强调 {_label(sl)} 的 {text_count(sc)}"
                break
        if not why:
            for rc, rl in refs:
                if text_count(rc) > 3 * max(n, 1):
                    why = f"主强调文字落点 {n}，不足参照色 {_label(rl)}（{text_count(rc)}）的三分之一"
                    break
        if why:
            found.append(("INVERT", name, c, why))
    return found


L2_TIERS = {"ZERO", "ZERO-DUP", "NEAR-ZERO", "DECOR", "INVERT"}


def apply_exemptions(name, md_text, rows, l2_active):
    """豁免在去重之后、输出之前。返回 (剩余发现, stale 注记)。

    注记读的是原始 md_text（未剥注释）——注记本身就活在 HTML 注释里，
    strip_comments 会把它连同其它注释一起剥掉，那样就永远解析不到任何注记。
    """
    # 三种最可能的手误——缺键、写成 audit-ok 前缀（那是另一套注记的合法语法，
    # 不该在这里报错，也不该在这里生效）、理由留空——前两种会被 exemptions() 悄悄
    # 漏掉（不解析成三元组），第三种会被悄悄接受（理由是空字符串，照样能销掉一条
    # ERROR）。malformed_exemptions 只挑「像 census-ok 却解析不出来」的那些，
    # 跟 tier 打错字用同一套「大声 FAIL，不许静默」的纪律。
    bad = malformed_exemptions(md_text, "census-ok")
    if bad:
        print(f"FAIL {name}：豁免注记写残了（缺键，或理由留空）——")
        for b in bad:
            print(f"     {b}")
        print("     合法格式：<!-- census-ok: <档名> <键> <一句话理由> -->")
        raise SystemExit(1)
    notes = exemptions(md_text, "census-ok")
    for tier, key, _ in notes:
        if tier not in LEGAL_NOTE_TIERS:
            print(f"FAIL {name}：豁免注记档名不认识 —— {tier}")
            print(f"     合法档名：{sorted(LEGAL_NOTE_TIERS)}")
            raise SystemExit(1)
    used = set()
    kept = []
    for row in rows:
        tier, _, key, _ = row
        idx = next((i for i, (t, k, _) in enumerate(notes)
                    if t == tier and k == key and i not in used), None)
        if idx is None:
            kept.append(row)
        else:
            used.add(idx)
    stale = []
    for i, (tier, key, _) in enumerate(notes):
        if i in used:
            continue
        # 按层设门：某层 SKIP 时该层的注记一律不判 stale，否则语料缺失
        # 会把所有 L2 注记变成凭空的 ERROR——而它们恰恰是要求写下来留档的。
        if tier in L2_TIERS and not l2_active:
            continue
        stale.append(("STALE-NOTE", name, key, f"这条 {tier} 注记销不到任何发现"))
    return kept, stale


def print_counts(name, md_text, html):
    """--counts：每个调色板色的落点分解。把「改完必须去数产物」变成一条命令。

    数的口径与三档判据同源：都是先 landings(html) 拿 Counter[(标签, 桶)]，
    再调 bucket_sum ——跟 check_l2.text_count 完全同一个函数、同一处定义，
    不是「凑巧写得一样」的两份 sum(...)。谁改了 DECOR/INVERT 用的桶定义，
    这里必然跟着变（Trap 3：不许有第二个真相源）。
    """
    land = landings(html)
    # 同 check_l2：小写化只做在这个调用点，理由见那边的注释。
    pal = {c.lower(): line for c, line in palette(strip_comments(md_text)).items()}
    print(f"{'色值':<10}{'角色':<24}{'总':>5}{'文字':>6}{'面':>5}{'线':>5}")
    for color, line in pal.items():
        c = land.get(color, {})
        tot = sum(c.values())
        tx = bucket_sum(c, "text")
        fl = bucket_sum(c, "fill")
        ln = bucket_sum(c, "line")
        print(f"{color:<10}{_label(line)[:22]:<24}{tot:>5}{tx:>6}{fl:>5}{ln:>5}")


def report(found, silenced):
    # 每列后补一个空格再垫宽，保证列之间至少有一个分隔符——不然像
    # list_prefix_ol_html（20 字符）这种超过 12 宽的键会跟 why 文本连写，
    # 靠空白分列的 awk（test-census-themes.sh 的 check()）就取不出正确的列。
    for tier, theme, key, why in found:
        print(f"{tier + ' ':<13}{theme + ' ':<24}{key + ' ':<12}{why}")
    print(f"\n普查完毕，{len(found)} 条未销")
    # 「43 → 0」是修好了缺陷，还是被注记盖住了——不把这两件事分开报，本项目就是在
    # 为防这个立项失败模式而造的工具里，把它原样复制了一遍。销掉的和没销掉的都要
    # 露面，缺一半读者就看不出「变干净了」到底是哪种变法。
    print(f"{silenced} 条已由注记豁免")
    return 1 if found else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fixture-dir")
    ap.add_argument("--article", help="语料文章；不给则从 MD2HTML_CORPUS 推")
    ap.add_argument("--counts", metavar="<主题名>",
                     help="输出该主题每个调色板色的落点分解，不跑普查。真实库模式按名字"
                          "匹配 references/；配合 --fixture-dir 时改从该目录取，供变异"
                          "测试用一份本地小语料把这条模式钉死，不必依赖真实语料库。")
    args = ap.parse_args()

    corpus = os.environ.get(
        "MD2HTML_CORPUS",
        os.path.expanduser("~/code/skills/writing/wechat_test/litellm-multi-provider-gateway"))
    article = args.article or os.path.join(corpus, "litellm-multi-provider-gateway.md")
    has_corpus = os.path.exists(article)

    if args.counts:
        if args.fixture_dir:
            d = args.fixture_dir
            md = os.path.join(d, args.counts + ".md")
            js = os.path.join(d, args.counts + ".theme.json")
            if not (os.path.exists(md) and os.path.exists(js)):
                print(f"FAIL --counts：{d} 里没有 {args.counts}")
                return 1
            base = args.counts
        else:
            ref = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "references")
            match = next((p for p in theme_pairs(ref) if p[0] == args.counts), None)
            if not match:
                print(f"FAIL --counts：主题库里没有 {args.counts}")
                return 1
            base, md, js = match
        if not has_corpus:
            print(f"FAIL --counts：语料不在 {article}，无法渲染产物")
            return 1
        with tempfile.TemporaryDirectory() as workdir:
            html, err = render(article, js, workdir, base)
        if err:
            print(f"FAIL --counts：渲染失败 —— {err}")
            return 1
        print_counts(base, open(md).read(), html)
        return 0

    if not has_corpus:
        print(f"SKIP L2：语料不在 {article}")
        print("     这不是通过。设 MD2HTML_CORPUS 或 --article 再跑，否则产物侧没有护栏。")

    found = []
    silenced = 0
    if not assert_keyword_table_complete():
        return 1
    with tempfile.TemporaryDirectory() as workdir:
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
                l1 = check_l1(name, md_text, theme)
                rows = l1 + check_l3(name, md_text, theme)
                if has_corpus:
                    html, err = render(article, jp, workdir, name)
                    if err:
                        rows.append(("RENDER-FAIL", name, "-", err))
                    else:
                        already = {c for t, _, c, _ in l1 if t == "UNCARRIED"}
                        rows += check_l2(name, md_text, html, already, theme)
                pre_exempt = len(rows)
                rows, stale = apply_exemptions(name, md_text, rows, has_corpus)
                silenced += pre_exempt - len(rows)
                found += rows + stale
        else:
            ref = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "references")
            for base, md, js in theme_pairs(ref):
                if not os.path.exists(md):
                    print(f"FAIL 对照表不完整：{base} 找不到 {md}")
                    return 1
                md_text, theme = open(md).read(), json.load(open(js))
                l1 = check_l1(base, md_text, theme)
                rows = l1 + check_l3(base, md_text, theme)
                if has_corpus:
                    html, err = render(article, js, workdir, base)
                    if err:
                        rows.append(("RENDER-FAIL", base, "-", err))
                    else:
                        already = {c for t, _, c, _ in l1 if t == "UNCARRIED"}
                        rows += check_l2(base, md_text, html, already, theme)
                pre_exempt = len(rows)
                rows, stale = apply_exemptions(base, md_text, rows, has_corpus)
                silenced += pre_exempt - len(rows)
                found += rows + stale
    code = report(found, silenced)
    return code or (0 if has_corpus else 1)   # 语料缺失也要标红


if __name__ == "__main__":
    sys.exit(main())
