#!/usr/bin/env python3
"""主题文件的解析纪律——audit-themes.py 与 census-themes.py 共用的唯一一份。

这些函数每一个都对应一次踩过的坑，改动前先读它们自己的 docstring：

- strip_comments：豁免注记里的色值会变成假落点，必须先剥
- palette：一行只声明一个色，取第一个；后面解释里引用的其它色值不算声明
- element_of：按元素名判定，不拿关键词在整行里搜

搬进本模块时一字未改。若要改判据，先跑 test-audit-themes.sh 与 test-census-themes.sh。
"""

import collections
import os
import re

# ↓ 以下三个函数从 audit-themes.py 原样搬入，实现不变


def strip_comments(text):
    """剥掉全部 HTML 注释。查落点前必须先做这一步——豁免注记
    （`<!-- audit-ok: LEVEL #色值 理由 -->`）里本身带着色值，不剥的话它会被当成
    一次真实落点，把 DEAD 检查骗过去。
    """
    return re.sub(r"<!--.*?-->", "", text, flags=re.S)


def element_of(line):
    """从「- h3：`font-size...`」里取出元素名 h3。取不到就返回整行。

    按元素名判定，而不是拿关键词在整行里搜——否则规范里一句
    「别只挂在 em 上」这样的说明文字，会把该行误判成 em 落点。
    """
    m = re.match(r"^[-*]\s*\*{0,2}([^：:`]{1,24})", line.strip())
    return (m.group(1) if m else line).strip().rstrip("*")


def palette(md_text):
    """调色板里真正被「声明」的颜色 → 它那行的角色描述。

    一行只声明一个色，取该行的第一个色值。后面解释里引用的其它色值
    （「`#2a3550` 在新底色上只有 1.27:1」这种）不算声明——否则一句解释
    就会凭空造出一个零落点的死色。
    """
    out = {}
    for line in md_text.splitlines():
        if not line.strip().startswith(("-", "*")):
            continue
        m = re.search(r"#[0-9a-fA-F]{6}", line)
        if m and m.group() not in out:
            out[m.group()] = line
    return out


# ↓ 以下四个函数为 Task 2 新增的原语，供 census-themes.py 使用


# 可机械化实体：色值、内联样式串、CSS 声明。带其一即为规范行。
_ENTITY = re.compile(r"#[0-9a-fA-F]{6}|style\s*=|[a-z-]+\s*:\s*[^\s;]")


def spec_lines(md_text):
    """规范行 = 行里含可机械化实体的行。返回 [(行号, 行文)]。

    **判定不看行首符号。**第一版按 bullet/表格行判，两头都错：
    漏掉 ink-wash.md:47 那种散文体带完整 style 串的规范（全库 15 行，
    「## 收尾」节的通用写法），也漏掉 cyber-neon.md:36 那种缩进有序项。
    而纯比喻句（「像印章落在水墨画上」）不带实体，自然落选。
    """
    out = []
    for i, line in enumerate(strip_comments(md_text).splitlines(), 1):
        if _ENTITY.search(line):
            out.append((i, line))
    return out


# 推不出来的映射写死在这里。新增带后缀的主题要在这里加一行。
_MD_NAME = {"13-cyber-neon-v7-edge": "cyber-neon"}


def theme_pairs(ref_dir):
    """主题名 → (md 路径, theme.json 路径)。**显式对照表，不用正则从文件名推。**

    13-cyber-neon-v7-edge.theme.json ↔ cyber-neon.md 推不出来，而兜底 regex
    会在下一个带后缀的主题上静默失配。双向完整性在调用处断言。
    """
    md_dir = os.path.join(ref_dir, "theme-prompts")
    js_dir = os.path.join(ref_dir, "theme-json")
    pairs = []
    for js in sorted(os.listdir(js_dir)):
        if not js.endswith(".theme.json"):
            continue
        base = js[: -len(".theme.json")]
        name = re.sub(r"^\d+-", "", base)
        md = os.path.join(md_dir, _MD_NAME.get(base, name) + ".md")
        pairs.append((base, md, os.path.join(js_dir, js)))
    return pairs


def exemptions(md_text, prefix):
    """解析豁免注记。prefix 是 'census-ok' 或 'audit-ok'，**不能省**。

    两套注记共存于同一批主题文件，各认各的前缀，互不干扰。这一步只挑**能解析成功**的
    注记；解析不出来的（缺键、理由留空）不在这里报错——那是 malformed_exemptions 的活，
    调用方（现在只有 census-themes.py）拿它去大声 FAIL，不能让残缺注记悄悄自称已生效。
    """
    pat = re.compile(r"<!--\s*" + re.escape(prefix) + r":\s*(\S+)\s+(\S+)\s+(.*?)\s*-->", re.S)
    return [(m.group(1), m.group(2), m.group(3)) for m in pat.finditer(md_text)]


_COMMENT = re.compile(r"<!--(.*?)-->", re.S)


def malformed_exemptions(md_text, prefix):
    """凡以字面前缀 `<prefix>:` 开头的 HTML 注释，只要解析不出「档名 键 非空理由」
    三元组，原样返回该注释全文，供调用方大声 FAIL——不许悄悄丢掉或悄悄接受零理由。

    只认字面前缀，不做「像不像」的模糊匹配：`audit-ok:` 不是 `census-ok:` 的近似写法，
    是另一套注记自己完整合法的语法（`audit-themes.py:86-89` 有它自己的硬编码正则），
    这里按 prefix 参数只挑以这个字面串开头的注释，两套前缀不会互相牵连——写错前缀不算
    「census-ok 写残了」，是完全没在跟这个检查器说话。
    """
    strict = re.compile(r"^\s*" + re.escape(prefix) + r":\s*(\S+)\s+(\S+)\s+(\S.*?)\s*$", re.S)
    out = []
    for m in _COMMENT.finditer(md_text):
        body = m.group(1)
        if body.strip().startswith(prefix + ":") and not strict.match(body):
            out.append(m.group(0))
    return out


_TAG_STYLE = re.compile(r'<([a-zA-Z][a-zA-Z0-9]*)\b[^>]*?style="([^"]*)"')
_COLOR_PROP = re.compile(r"(?<![-\w])color\s*$")
_PRE_BLOCK = re.compile(r"<pre\b.*?</pre>", re.S)


def _scan(html, skip_ranges=(), skip_style=None):
    """landings / prose_landings 共用的唯一一遍扫描。

    桶按 **CSS 属性名**分，不按视觉直觉分：
      text = color；fill = background 开头的任何属性；line = 其余
    取属性名必须带 (?<![-\\w]) 守卫——background-color: 含子串 color:，
    不挡就永远取到底色（audit-themes.py:103 踩过一次，配了变异用例）。

    skip_ranges / skip_style 只由 prose_landings 传，landings 一律不传——
    两者必须走同一份桶定义，不能各写一遍（Trap 3：不许有第二个真相源）。
    """
    res = collections.defaultdict(collections.Counter)
    for m in _TAG_STYLE.finditer(html):
        tag, style = m.group(1), m.group(2)
        if any(a <= m.start() < b for a, b in skip_ranges):
            continue
        if skip_style and style.strip() == skip_style:
            continue
        for decl in style.split(";"):
            if ":" not in decl:
                continue
            prop, val = decl.split(":", 1)
            prop = prop.strip().lower()
            if _COLOR_PROP.search(prop):
                bucket = "text"
            elif prop.startswith("background"):
                bucket = "fill"
            else:
                bucket = "line"
            for c in re.findall(r"#[0-9a-fA-F]{6}", val):
                res[c.lower()][(tag.lower(), bucket)] += 1
    return res


def landings(html):
    """色值 → Counter[(标签, 桶)]，桶 ∈ text / fill / line。全量口径。"""
    return _scan(html)


def prose_landings(html, inline_code_style):
    """散文面落点 = landings() 减去**代码面**：`<pre>` 块内的一切 + 行内 code。

    只有 census_themes.check_l2 的 `INVERT` 用它。别的档（ZERO / NEAR-ZERO /
    DECOR）一律仍用 landings()——「这个色在产物里出现了几次」和「它在阅读面上
    占多大分量」是两个问题，只有 INVERT 问的是后者。

    **行内 code 认不出来的话，这个函数就是假的。**`md2html.py:193` 发的行内
    code 是 `<span style="{inline_code}">`，**不是 `<code>`**——按 `<pre>`/
    `<code>` 标签切区域会把它整个漏掉（实测语料里 193 处，占某些主题参照色
    落点的七成）。产物里没有任何别的标记能区分它，唯一可靠的把手是「样式串
    与 theme.json 的 `inline_code` 逐字相同」：那个键在 md2html.py 里是原样
    拼进去的、不加定宽后缀，且全库 26 份 theme.json 已核过没有第二个键与它
    重样式串。inline_code_style 为空（主题没配这个键）时只剥 `<pre>`。
    """
    ranges = [(m.start(), m.end()) for m in _PRE_BLOCK.finditer(html)]
    return _scan(html, ranges, (inline_code_style or "").strip() or None)
