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

# ---- prose_landings：剥掉代码面（<pre> 块 + 行内 code），别的一律不动
#
# 行内 code 在产物里是 `<span style="{inline_code}">`（md2html.py:193），
# 与任何别的 span 在标签层面无法区分——只能靠样式串逐字相等来认。
# 这一条是整个函数的承重点：认不出来它，代码面就只剥掉了一半。

ICS = "background-color: #eeeeee; color: #8f3f28"
HTML2 = ('<p style="color: #111111">散文</p>'
         f'<span style="{ICS}">inline</span>'
         '<pre style="background-color: #eeeeee">'
         '<span style="color: #8f3f28">tok</span></pre>'
         '<strong style="color: #8f3f28">散文里的强调</strong>')
full = T.landings(HTML2)
pro = T.prose_landings(HTML2, ICS)
eq("landings 全量口径把三处 #8f3f28 都算上",
   sum(v for (_, b), v in full["#8f3f28"].items() if b == "text"), 3)
eq("prose_landings 只留散文面那一处",
   sum(v for (_, b), v in pro["#8f3f28"].items() if b == "text"), 1)
eq("prose_landings 剥掉行内 code（靠样式串认，不靠标签）",
   pro["#8f3f28"].get(("span", "text"), 0), 0)
eq("prose_landings 剥掉 <pre> 块内的语法高亮",
   pro["#eeeeee"].get(("pre", "fill"), 0), 0)
eq("prose_landings 不动散文面的普通落点",
   pro["#111111"][("p", "text")], 1)
eq("prose_landings 传空样式串时只剥 <pre>，不误剥全部 span",
   sum(v for (_, b), v in T.prose_landings(HTML2, "")["#8f3f28"].items()
       if b == "text"), 2)

print(f"\n{len(got) and ''}{'FAIL' if fails else 'ok'}：{len(fails)} 条失败")
sys.exit(1 if fails else 0)
