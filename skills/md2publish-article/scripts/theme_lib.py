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

    两套注记共存于同一批主题文件，各认各的前缀，互不干扰。
    """
    pat = re.compile(r"<!--\s*" + re.escape(prefix) + r":\s*(\S+)\s+(\S+)\s+(.*?)\s*-->", re.S)
    return [(m.group(1), m.group(2), m.group(3)) for m in pat.finditer(md_text)]


_TAG_STYLE = re.compile(r'<([a-zA-Z][a-zA-Z0-9]*)\b[^>]*?style="([^"]*)"')
_COLOR_PROP = re.compile(r"(?<![-\w])color\s*$")


def landings(html):
    """色值 → Counter[(标签, 桶)]，桶 ∈ text / fill / line。

    桶按 **CSS 属性名**分，不按视觉直觉分：
      text = color；fill = background 开头的任何属性；line = 其余
    取属性名必须带 (?<![-\\w]) 守卫——background-color: 含子串 color:，
    不挡就永远取到底色（audit-themes.py:103 踩过一次，配了变异用例）。
    """
    res = collections.defaultdict(collections.Counter)
    for tag, style in _TAG_STYLE.findall(html):
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
