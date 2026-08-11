#!/usr/bin/env python3
"""contrast_lib.py 的单元测试。锚点值全部来自项目历史上人手量过的真实主题色对。"""
import io
import sys
from contextlib import redirect_stderr
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

# ── 渐变插值顺序：alpha 也变化时必须先插值再合成，不能先合成再插值 ──
# rgba(255,0,0,0) → rgba(0,0,255,1) 压在白底上：两个色标 alpha 不同（0 与 1）。
# 正确做法——(r,g,b,alpha) 未预乘分量插值，中点 (127.5,0,127.5,0.5)，再合成到白上
# ——中点是 (191,128,191)。先各自合成再插值的错误做法会给出 (128,128,255)：
# 白底上合成 alpha=0 的红=白 (255,255,255)，合成 alpha=1 的蓝=蓝 (0,0,255)，
# 两者中点 (128,128,255)——数值不同、结论也可能不同，是本轮 Finding 2 要修的错误。
ALPHA_DIFFERS = CL.backdrop_samples("#ffffff", "linear-gradient(rgba(255,0,0,0), rgba(0,0,255,1))",
                                     [(255,255,255)])
ok("alpha 也变化的渐变：中点插值先分量再合成，正确值 (191,128,191)",
   (191, 128, 191) in ALPHA_DIFFERS)
ok("alpha 也变化的渐变：错误顺序（先合成再插值）的 (128,128,255) 不该出现",
   (128, 128, 255) not in ALPHA_DIFFERS)

# 恒定 alpha（都是 1.0）时两种顺序数学上等价——证明这次修复没有改动这一支路径。
CONST_ALPHA = CL.backdrop_samples("#ffffff", "linear-gradient(rgba(255,0,0,1), rgba(0,0,255,1))",
                                   [(255,255,255)])
ok("alpha 恒定的渐变中点仍是 (128,0,128)，未预乘插值不改变这个结果",
   (128, 0, 128) in CONST_ALPHA)

# ── 硬停：位置单位不限于 %，但不同单位不能互相判等（不猜换算） ──
# 纹理渐变的真实写法是 px 位置（如 autumn-warm 的 `rgba(...,0.02) 1px, transparent 1px`）：
# 两个色标位置都是 "1px"，数值和单位都相同 → 硬停，只取两端，不做 101 点插值。
HARDSTOP_PX = CL.backdrop_samples("#ffffff", "linear-gradient(#000000 1px, #ffffff 1px)",
                                   [(255,255,255)])
ok("px 位置相同 → 判定硬停，只有两端两个候选",
   set(HARDSTOP_PX) == {(0, 0, 0), (255, 255, 255)})
ok("px 硬停不会漏判成连续渐变——中间的采样点（如灰 128,128,128）不该出现",
   (128, 128, 128) not in HARDSTOP_PX)

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

# ── 非字符串字段值：跳过必须叫出声 ──────────────────────────
# 这条 WARN 曾在评审里被判「不阻塞」而 park：方向确实安全（跳过只让装饰集合变窄、
# 多报，永不藏掉发现）。但它打的是 stderr，而在这之前两套套件都不断言 stderr——
# 谁把那行 print 删掉，全套件照样全绿，行为静默退回「无声跳过」。这几条就是钉那行。
BAD_THEME = {
    "h3_prefix_html": '<span style="color: #6f7a4d;">☘&nbsp;</span>',
    "list_prefix_ol_html": 12345,      # 不是字符串：该被跳过，且必须打 WARN
}
_err = io.StringIO()
with redirect_stderr(_err):
    BAD_SIGS = CL.decor_signatures(BAD_THEME, theme_name="t-bad")
_msg = _err.getvalue()

ok("非字符串字段值会往 stderr 打 WARN（删掉那行 print 这条就红）", "WARN" in _msg)
ok("WARN 点名了主题与字段，不是一句无从追查的空话",
   "t-bad" in _msg and "list_prefix_ol_html" in _msg)
ok("被跳过的只是那一项，同主题其余字段照常进签名",
   CL.is_decor(node("color: #6f7a4d;", "☘"), BAD_SIGS))
ok("被跳过的那一项不进签名——装饰面变窄是预期方向",
   not CL.is_decor(node("", "12345"), BAD_SIGS))

_quiet = io.StringIO()
with redirect_stderr(_quiet):
    CL.decor_signatures(THEME, theme_name="t-ok")
ok("字段值全正常时一个字都不打（不许狼来了）", _quiet.getvalue() == "")

# ── image_reaches_text：被 background-size 限制成条带的图像不算文字的底 ──
# 判据说法：图像被限制成一条贴边条带、且该侧 padding 保证文字够不到它，
# 此时文字的底是 background-color。四条必要条件缺一都倒向「保留图像」。
# 设计与逐条理由见 docs/superpowers/specs/2026-08-11-background-size-backdrop-design.md
STRIP = {
    "background-color": "#ffffff",
    "background-image": "linear-gradient(135deg, #6a5cff, #38c6d9)",
    "background-repeat": "no-repeat",
    "background-size": "100% 4px",
    "background-position": "top",
    "padding": "26px 22px",
}
def without(d, *keys):
    return {k: v for k, v in d.items() if k not in keys}

ok("四条全中：aurora-flow 卡顶那条 4px 渐变够不到卡内文字",
   CL.image_reaches_text(STRIP) is False)
ok("没有 background-image 时无所谓够不够得到",
   CL.image_reaches_text(without(STRIP, "background-image")) is True)

# 条件 1：no-repeat。这是唯一真正承重的一条——真实库里 autumn-warm / ocean-calm /
# spring-fresh 的 card 与 blueprint-grid 的 container 都是 `20px 20px` 这类平铺纹理、
# 且不写 background-repeat，它们确实铺满整个元素、确实在文字后面。
ok("显式 repeat 会把条带平铺满整个元素 → 保留图像",
   CL.image_reaches_text({**STRIP, "background-repeat": "repeat"}) is True)
ok("不写 background-repeat 就是 CSS 默认的 repeat → 保留图像",
   CL.image_reaches_text(without(STRIP, "background-repeat")) is True)

# 条件 2：background-size 两个分量、高度是 px 固定长度
ok("不写 background-size → 保留图像",
   CL.image_reaches_text(without(STRIP, "background-size")) is True)
ok("高度是百分比 → 保留图像",
   CL.image_reaches_text({**STRIP, "background-size": "100% 10%"}) is True)
ok("高度是 auto → 保留图像",
   CL.image_reaches_text({**STRIP, "background-size": "100% auto"}) is True)
ok("cover 是单分量关键字 → 保留图像",
   CL.image_reaches_text({**STRIP, "background-size": "cover"}) is True)
ok("contain 是单分量关键字 → 保留图像",
   CL.image_reaches_text({**STRIP, "background-size": "contain"}) is True)
ok("只给一个分量时那是宽度、高度按 auto 走 → 保留图像",
   CL.image_reaches_text({**STRIP, "background-size": "4px"}) is True)
ok("多层背景（含逗号）一律不解析 → 保留图像",
   CL.image_reaches_text({**STRIP, "background-size": "100% 4px, cover"}) is True)

# 条件 3：background-position 恰好 top 或 bottom
ok("position 是 center 时条带落在元素中间，padding 证明不了任何事 → 保留图像",
   CL.image_reaches_text({**STRIP, "background-position": "center"}) is True)
ok("不写 background-position → 保留图像",
   CL.image_reaches_text(without(STRIP, "background-position")) is True)
ok("position 是 bottom 时看 padding-bottom，同样成立",
   CL.image_reaches_text({**STRIP, "background-position": "bottom"}) is False)

# 条件 4：该侧 padding 是 px 且 ≥ 条带高度——「文字够不到条带」的机械证明
ok("padding 为 0 时文字真压在条带上 → 保留图像",
   CL.image_reaches_text({**STRIP, "padding": "0"}) is True)
ok("padding 单位不是 px 时不猜换算 → 保留图像",
   CL.image_reaches_text({**STRIP, "padding": "2em 22px"}) is True)
ok("_px_or_none 对畸形多点数字（如 1.2.3px）返回 None，不抛 ValueError",
   CL._px_or_none("1.2.3px") is None)
ok("padding 是畸形多点数字时同样保留图像，不炸也不误判达标",
   CL.image_reaches_text({**STRIP, "padding": "1.2.3px 22px"}) is True)
ok("padding 小于条带高度 → 保留图像",
   CL.image_reaches_text({**STRIP, "padding": "2px 22px"}) is True)
ok("padding 长写法优先于简写",
   CL.image_reaches_text({**STRIP, "padding": "0", "padding-top": "26px"}) is False)
# 简写取错侧会让下面两条里恰好一条红：三值简写 top=2px、bottom=30px，
# 条带高 4px，所以 top 那边不够、bottom 那边够。
ok("三值 padding 简写：position top 取的是第 1 个值（2px < 4px）",
   CL.image_reaches_text({**STRIP, "padding": "2px 22px 30px"}) is True)
ok("三值 padding 简写：position bottom 取的是第 3 个值（30px ≥ 4px）",
   CL.image_reaches_text({**STRIP, "padding": "2px 22px 30px",
                          "background-position": "bottom"}) is False)

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
