#!/usr/bin/env python3
"""contrast_lib.py 的单元测试。锚点值全部来自项目历史上人手量过的真实主题色对。"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import contrast_lib as CL

fails = 0
def ok(name, cond):
    global fails
    if cond:
        print(f"ok   {name}")
    else:
        fails += 1
        print(f"FAIL {name}")

def near(a, b, tol=0.005):
    return abs(a - b) <= tol

# ── parse_color ────────────────────────────────────────────
ok("parse_color 认 6 位 hex",        CL.parse_color("#efe0cd") == (239, 224, 205, 1.0))
ok("parse_color 认 3 位 hex 并展开",  CL.parse_color("#fff")    == (255, 255, 255, 1.0))
ok("parse_color 认 rgba 带 alpha",   CL.parse_color("rgba(176, 142, 138, 0.35)") == (176, 142, 138, 0.35))
ok("parse_color 认 rgb 无 alpha",    CL.parse_color("rgb(0,0,0)") == (0, 0, 0, 1.0))
ok("parse_color 认 transparent",     CL.parse_color("transparent") == (0, 0, 0, 0.0))
ok("parse_color 认不出返回 None",     CL.parse_color("inherit") is None)

# ── composite ──────────────────────────────────────────────
# morandi-fog 的下划线高亮：rgba(176,142,138,0.35) 压在白上
ok("composite 0.35 alpha 压白",
   CL.composite((176, 142, 138, 0.35), (255, 255, 255)) == (227, 215, 214))
ok("composite alpha=1 直接盖住下层",
   CL.composite((17, 34, 51, 1.0), (255, 255, 255)) == (17, 34, 51))
ok("composite alpha=0 完全透明，下层原样",
   CL.composite((0, 0, 0, 0.0), (239, 224, 205)) == (239, 224, 205))

# ── contrast_ratio：锚点全是项目历史上量过的真值 ─────────────
ok("白/黑 = 21",           near(CL.contrast_ratio((255,255,255), (0,0,0)), 21.0))
ok("同色 = 1",             near(CL.contrast_ratio((120,120,120), (120,120,120)), 1.0))
ok("terracotta keyword 3.3878",
   near(CL.contrast_ratio((0xc2,0x59,0x3b), (0xef,0xe0,0xcd)), 3.3878))
ok("terracotta 旧 comment 2.5769",
   near(CL.contrast_ratio((0x9c,0x8a,0x72), (0xef,0xe0,0xcd)), 2.5769))
ok("terracotta 正文 8.3880",
   near(CL.contrast_ratio((0x4f,0x38,0x2b), (0xef,0xe0,0xcd)), 8.3880))
ok("terracotta string 5.5726",
   near(CL.contrast_ratio((0x8f,0x3f,0x28), (0xef,0xe0,0xcd)), 5.5726))
ok("terracotta 橄榄绿 3.5503",
   near(CL.contrast_ratio((0x6f,0x7a,0x4d), (0xef,0xe0,0xcd)), 3.5503))
ok("celadon 饰线 1.4492",
   near(CL.contrast_ratio((0xd8,0xcf,0xb8), (0xfb,0xf7,0xec)), 1.4492))
ok("contrast_ratio 对调前后景不变",
   near(CL.contrast_ratio((0xc2,0x59,0x3b), (0xef,0xe0,0xcd)),
        CL.contrast_ratio((0xef,0xe0,0xcd), (0xc2,0x59,0x3b))))

print(f"\nok：{fails} 条失败")
sys.exit(1 if fails else 0)
