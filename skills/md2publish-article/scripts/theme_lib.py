#!/usr/bin/env python3
"""主题文件的解析纪律——audit-themes.py 与 census-themes.py 共用的唯一一份。

这些函数每一个都对应一次踩过的坑，改动前先读它们自己的 docstring：

- strip_comments：豁免注记里的色值会变成假落点，必须先剥
- palette：一行只声明一个色，取第一个；后面解释里引用的其它色值不算声明
- element_of：按元素名判定，不拿关键词在整行里搜

搬进本模块时一字未改。若要改判据，先跑 test-audit-themes.sh 与 test-census-themes.sh。
"""

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


def palette(palette):
    """调色板里真正被「声明」的颜色 → 它那行的角色描述。

    一行只声明一个色，取该行的第一个色值。后面解释里引用的其它色值
    （「`#2a3550` 在新底色上只有 1.27:1」这种）不算声明——否则一句解释
    就会凭空造出一个零落点的死色。
    """
    out = {}
    for line in palette.splitlines():
        if not line.strip().startswith(("-", "*")):
            continue
        m = re.search(r"#[0-9a-fA-F]{6}", line)
        if m and m.group() not in out:
            out[m.group()] = line
    return out
