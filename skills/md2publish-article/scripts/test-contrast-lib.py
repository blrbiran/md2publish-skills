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

# ── gradient_stops ─────────────────────────────────────────
ok("gradient_stops 抽出两个 hex 色标",
   CL.gradient_stops("linear-gradient(135deg, #6a5cff, #38c6d9)")
   == [(0x6a,0x5c,0xff,1.0), (0x38,0xc6,0xd9,1.0)])
ok("gradient_stops 抽出 rgba 与 transparent",
   CL.gradient_stops("linear-gradient(transparent 62%, rgba(176, 142, 138, 0.35) 62%)")
   == [(0,0,0,0.0), (176,142,138,0.35)])
ok("gradient_stops 对非渐变返回空",
   CL.gradient_stops("none") == [])

# ── backdrop_samples ───────────────────────────────────────
ok("没声明任何底 → 沿用父级候选集",
   CL.backdrop_samples(None, None, [(255,255,255)]) == [(255,255,255)])
ok("只有 background-color → 单一候选",
   CL.backdrop_samples("#efe0cd", None, [(255,255,255)]) == [(239,224,205)])
# morandi-fog 形态：半透明色带压在白卡上，两个候选（带上 / 带下）
ok("半透明渐变与下层合成，保留两个候选",
   set(CL.backdrop_samples("#ffffff",
        "linear-gradient(transparent 62%, rgba(176, 142, 138, 0.35) 62%)",
        [(255,255,255)]))
   == {(255,255,255), (227,215,214)})

# ── worst_contrast：三种情况 ────────────────────────────────
AURORA = CL.backdrop_samples(None, "linear-gradient(135deg, #6a5cff, #38c6d9)", [(255,255,255)])
ok("aurora-flow 白字压渐变，最差 2.0492",
   near(CL.worst_contrast((255,255,255), AURORA), 2.0492))

# 前景比整条渐变都暗：最小亮度在渐变内部（t≈0.70），端点法会漏判
INTERIOR = CL.backdrop_samples(None, "linear-gradient(#ff0000, #0000ff)", [(255,255,255)])
ok("前景比整条渐变都暗时最差点在内部：1.9502（端点法会给出 2.4440）",
   near(CL.worst_contrast((0,0,0), INTERIOR), 1.9502))

# 前景亮度夹在两端之间：介值定理 → 必有一点等亮 → 1.0
BETWEEN = CL.backdrop_samples(None, "linear-gradient(#000000, #ffffff)", [(255,255,255)])
ok("前景亮度夹在渐变两端之间时最差 = 1.0（端点法会给出 3.9494）",
   near(CL.worst_contrast((0x80,0x80,0x80), BETWEEN), 1.0))

# ── walk ───────────────────────────────────────────────────
DOC = ('<div style="background-color: #f8f0e7">'
       '<section style="background-color: #fdf8f1">'
       '<p style="font-size: 15.5px; color: #4f382b">正文'
       '<strong style="color: #c2593b; font-weight: 700">强调</strong></p>'
       '<h2 style="background-color: #c2593b; color: #fdf8f1; font-size: 17px; font-weight: 700">'
       '标题</h2></section></div>')
NODES = {n.text: n for n in CL.walk(DOC)}

ok("walk 只收非空文本节点", set(NODES) == {"正文", "强调", "标题"})
ok("正文落在卡片底上，不是容器底", NODES["正文"].samples == [(0xfd,0xf8,0xf1)])
ok("strong 继承父级字号", NODES["强调"].size == 15.5)
ok("strong 自己的字重覆盖继承值", NODES["强调"].weight == 700)
ok("strong 的底仍是卡片底（它自己没声明底）", NODES["强调"].samples == [(0xfd,0xf8,0xf1)])
ok("h2 文字落在 h2 自己的底上", NODES["标题"].samples == [(0xc2,0x59,0x3b)])
ok("h2 的 own_bg 记录了自己声明的底", NODES["标题"].own_bg == (0xc2,0x59,0x3b))
ok("p 没声明自己的底，own_bg 是 None", NODES["正文"].own_bg is None)
ok("没声明字号时用默认 16px",
   [n for n in CL.walk('<div style="background-color:#fff">裸</div>')][0].size == 16.0)

# 栈不闭合必须抛，不许继续算
try:
    CL.walk('<div style="background-color:#fff"><p style="color:#000">未闭合')
    ok("栈不闭合时抛 ContrastWalkError", False)
except CL.ContrastWalkError:
    ok("栈不闭合时抛 ContrastWalkError", True)

# 无底色祖先必须抛，不许默默按白算
try:
    CL.walk('<div><p style="color: #000000">没有任何底色声明</p></div>')
    ok("无底色祖先时抛 ContrastWalkError（不许兜白）", False)
except CL.ContrastWalkError:
    ok("无底色祖先时抛 ContrastWalkError（不许兜白）", True)

# ── decor_signatures / is_decor ────────────────────────────
THEME = {
    "container": "background-color: #ffffff",
    "h3_prefix_html": '<span style="color: #6f7a4d;">☘&nbsp;</span>',
    "list_prefix_html": '<span style="color: #c2593b;">●</span>&nbsp;&nbsp;',
    "list_prefix_ol_html": "{n}.",            # 没有 style，走字面文本那条路
    "strong": "color: #c2593b; font-weight: 700",   # 不是注入字段，不该进签名
}
SIGS = CL.decor_signatures(THEME)

def node(style, text, tag="span"):
    return CL.Node(tag, (0,0,0), [(255,255,255)], 13.0, 400, text, style, None)

ok("注入前缀的样式串算装饰",       CL.is_decor(node("color: #6f7a4d;", "☘"), SIGS))
ok("注入列表符的样式串算装饰",     CL.is_decor(node("color: #c2593b;", "●"), SIGS))
ok("strong 的样式串不算装饰（不是注入字段）",
   not CL.is_decor(node("color: #c2593b; font-weight: 700", "强调"), SIGS))
ok("代码块里的纯符号不算装饰——这正是字符类判据会判错的地方",
   not CL.is_decor(node("color: #4f382b", "|---|"), SIGS))
ok("代码块里的花括号不算装饰",
   not CL.is_decor(node("color: #4f382b", "{"), SIGS))
ok("内容里的引号不算装饰（探针曾把它误判成装饰）",
   not CL.is_decor(node("color: #d97758", '"', tag="em"), SIGS))
ok("没有 style 的注入字段按字面文本认",
   CL.is_decor(node("", "1."), SIGS))
ok("样式串比对忽略首尾空白与末尾分号",
   CL.is_decor(node("  color: #6f7a4d  ", "☘"), SIGS))

# ── 阈值 ───────────────────────────────────────────────────
ok("18.66px/700 是大文本",       CL.is_large_text(18.66, 700))
ok("18.2px/700 不是大文本",      not CL.is_large_text(18.2, 700))
ok("24px/400 是大文本",          CL.is_large_text(24.0, 400))
ok("23.9px/400 不是大文本",      not CL.is_large_text(23.9, 400))
ok("18.66px/400 不是大文本（字重不够）", not CL.is_large_text(18.66, 400))
ok("普通文字阈值 4.5",           CL.threshold(False, 15.5, 400) == 4.5)
ok("大文本阈值 3.0",             CL.threshold(False, 24.0, 400) == 3.0)
ok("装饰阈值 3.0",               CL.threshold(True, 13.0, 400) == 3.0)

# ── findings_for ───────────────────────────────────────────
T5 = {"container": "background-color: #ffffff",
      "h2_prefix_html": '<span style="background-color: #f0a500; color: #f0a500;">■</span>'}

# 同色块：注入装饰且前景=自己的底 → 跳过
BLOCK = ('<div style="background-color: #ffffff">'
         '<h2 style="font-size: 18px">'
         '<span style="background-color: #f0a500; color: #f0a500;">■</span>标题</h2></div>')
ok("注入装饰的同色块被跳过（bauhaus-pop 的 ■）",
   not [f for f in CL.findings_for("t", BLOCK, T5) if f.sample == "■"])

# 同色块规则不许放宽到非装饰节点：正文色等于卡片底是真缺陷，必须仍报
SAMECOLOR = ('<div style="background-color: #ffffff">'
             '<p style="background-color: #eeeeee; color: #eeeeee; font-size: 15px">正文</p></div>')
ok("非装饰节点的同色不许跳过（真缺陷）",
   [f for f in CL.findings_for("t", SAMECOLOR, T5) if f.sample == "正文"])

# 计数合并：同键的多处只出一条，count 累加
DUP = ('<div style="background-color: #ffffff">'
       '<p style="color: #bbbbbb; font-size: 15px">一</p>'
       '<p style="color: #bbbbbb; font-size: 15px">二</p></div>')
DUPF = CL.findings_for("t", DUP, T5)
ok("同键合并成一条", len(DUPF) == 1)
ok("合并后 count 累加", DUPF[0].count == 2)
ok("达标的不出现在发现里",
   CL.findings_for("t", '<div style="background-color: #ffffff">'
                        '<p style="color: #000000; font-size: 15px">黑字</p></div>', T5) == [])

print(f"\nok：{fails} 条失败")
sys.exit(1 if fails else 0)
