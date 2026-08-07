#!/usr/bin/env python3
"""theme_lib 新原语的单元测试。跑法：python3 test-theme-lib.py"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import theme_lib as T

fails = []
def eq(name, actual, expected):
    if actual == expected:
        print(f"ok   {name}")
    else:
        print(f"FAIL {name}\n     期望: {expected!r}\n     实得: {actual!r}")
        fails.append(name)

# ---- spec_lines：判「是不是规范」看有没有可机械化实体，不看行首符号

MD = """# t

## 色彩系统

- 主强调：`#cc3366`

## 收尾

文末居中放一个印章：`<p style="text-align: center; color: #cc3366;">□</p>` 可换为「完」字。

朱砂红是唯一的颜色，出现频率要低——像印章落在水墨画上，多了就俗。

  1. 原文里带「注意 / 警告 / 不要 / 会导致」这类警示语义的 `strong`，改用 `color: #ff4ba3`

| 函数名 | `#d2a8ff` | 定义或调用处 |
"""
got = [t for _, t in T.spec_lines(MD)]
eq("spec_lines 收散文体带 style 的规范",
   any("印章" in l and "style=" in l for l in got), True)
eq("spec_lines 不收纯比喻句",
   any("多了就俗" in l for l in got), False)
eq("spec_lines 收缩进有序条款行",
   any("警示语义" in l for l in got), True)
eq("spec_lines 收表格行",
   any("#d2a8ff" in l for l in got), True)

# ---- exemptions：按前缀分流，键是不透明 token

EX = """<!-- census-ok: INVERT #f28ba8 待真机定夺 -->
<!-- census-ok: UNMOUNTED p_first 本主题刻意不做导语 -->
<!-- audit-ok: OVER #3d6a8a 别的脚本的注记 -->
"""
eq("exemptions 只认自己的前缀",
   T.exemptions(EX, "census-ok"),
   [("INVERT", "#f28ba8", "待真机定夺"),
    ("UNMOUNTED", "p_first", "本主题刻意不做导语")])
eq("exemptions 认得 audit-ok",
   T.exemptions(EX, "audit-ok"),
   [("OVER", "#3d6a8a", "别的脚本的注记")])

# ---- landings：三个桶按属性名分，background-color 不许被当成 color

HTML = ('<p style="color: #111111; background-color: #eeeeee">x</p>'
        '<h3 style="border-left: 3px solid #cc3366">y</h3>'
        '<span style="color: #cc3366">z</span>')
land = T.landings(HTML)
eq("landings text 桶", land["#111111"][("p", "text")], 1)
eq("landings fill 桶", land["#eeeeee"][("p", "fill")], 1)
eq("landings 不把 background-color 记成 text",
   land["#eeeeee"].get(("p", "text"), 0), 0)
eq("landings line 桶", land["#cc3366"][("h3", "line")], 1)
eq("landings 同色跨桶分开记", land["#cc3366"][("span", "text")], 1)

print(f"\n{len(got) and ''}{'FAIL' if fails else 'ok'}：{len(fails)} 条失败")
sys.exit(1 if fails else 0)
