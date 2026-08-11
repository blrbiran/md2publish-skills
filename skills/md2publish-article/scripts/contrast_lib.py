#!/usr/bin/env python3
"""产物 HTML 的对比度原语。

设计与判据理由见 docs/superpowers/specs/2026-08-10-contrast-audit-design.md。
与 theme_lib.py 分开：那边读 theme.json，这边读产物 DOM。
"""
import re
import sys

_HEX3 = re.compile(r"#([0-9a-fA-F]{3})$")
_HEX6 = re.compile(r"#([0-9a-fA-F]{6})$")
_RGB = re.compile(r"rgba?\(\s*([^)]*)\)$")


def parse_color(s):
    """'#fff' / '#rrggbb' / 'rgb(...)' / 'rgba(...)' / 'transparent' → (r,g,b,alpha)；认不出 None。"""
    if s is None:
        return None
    s = s.strip().lower()
    if s == "transparent":
        return (0, 0, 0, 0.0)
    m = _HEX3.match(s)
    if m:
        return tuple(int(ch * 2, 16) for ch in m.group(1)) + (1.0,)
    m = _HEX6.match(s)
    if m:
        h = m.group(1)
        return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (1.0,)
    m = _RGB.match(s)
    if m:
        parts = [p.strip() for p in m.group(1).split(",")]
        if len(parts) < 3:
            return None
        try:
            rgb = tuple(int(round(float(p))) for p in parts[:3])
            a = float(parts[3]) if len(parts) > 3 else 1.0
        except ValueError:
            return None
        return rgb + (a,)
    return None


def composite(top, bottom):
    """上层 (r,g,b,alpha) 压在不透明下层 (r,g,b) 上，返回不透明结果。"""
    r, g, b, a = top
    return tuple(int(round(a * c + (1 - a) * d)) for c, d in zip((r, g, b), bottom))


def relative_luminance(rgb):
    """WCAG 2.1 相对亮度。"""
    def f(v):
        v /= 255.0
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = rgb
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)


def contrast_ratio(fg, bg):
    """WCAG 2.1 对比度，1.0 ~ 21.0，与前后景顺序无关。"""
    a, b = relative_luminance(fg), relative_luminance(bg)
    hi, lo = (a, b) if a >= b else (b, a)
    return (hi + 0.05) / (lo + 0.05)


_STOP_TOKEN = re.compile(
    r"(#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b|rgba?\([^)]*\)|\btransparent\b)"
    r"(?:\s+(-?\d+(?:\.\d+)?)(%|px))?"
)

#: 沿渐变采样的步数。101 = 每 1% 一个采样点。
#: 不许改成只取两端——L(t) 是凸的，最小值可能落在内部（见本文件顶部 spec 链接）。
GRADIENT_SAMPLES = 101


def _parse_gradient_stops(css_value):
    """按出现顺序抽取 (color, position) 对；position 是 (数值, 单位) 二元组，没写位置则 None。
    单位认 `%` 与 `px`；两个位置只在单位相同时才可能相等——`1px` 和 `1%` 不是同一个位置，
    不猜换算（比如把 px 按 100% 当分母折算成百分比），猜换算正是本项目明令禁止的那种臆造。
    非渐变返回 []。"""
    if not css_value or "gradient" not in css_value:
        return []
    out = []
    for tok, pos, unit in _STOP_TOKEN.findall(css_value):
        c = parse_color(tok)
        if c is not None:
            out.append((c, (float(pos), unit) if pos else None))
    return out


def gradient_stops(css_value):
    """从 gradient 声明里按出现顺序抽色标；没有 gradient 关键字返回 []。"""
    return [c for c, _ in _parse_gradient_stops(css_value)]


def backdrop_samples(bg_color, image_value, parent_samples):
    """该元素的有效底候选集（不透明 RGB 列表）。

    background-color 打底（不透明则盖住父级），再把 background-image 的色标合成上去。
    相邻两个色标若显式写了相同的位置（数值与单位都相同——`1px` 和 `1%` 不是同一个位置，
    不猜换算）——CSS 的硬停（hard stop，比如 morandi-fog 的下划线带
    `transparent 62%, rgba(...) 62%`，或纹理渐变的 `rgba(...,0.02) 1px, transparent 1px`）
    ——中间没有过渡区，只取两端；否则视为连续渐变，沿途按 GRADIENT_SAMPLES 采样，因为
    L(t) 对 t 是凸的，最小值可能落在内部，端点法会漏判。

    **插值顺序**：相邻两色标先按分量对 (r, g, b, alpha) 做未预乘的线性插值，插值结果
    再合成到底色上——不能反过来先把两端各自合成、再对合成结果插值。两个色标 alpha 不同
    时二者不等价（CSS 渲染引擎按前者），反过来做会静默算出错误的颜色而不是报错，
    详见 docs/theme-design-lessons.md 里 rgba(255,0,0,0)→rgba(0,0,255,1) 那个反例。
    """
    base = list(parent_samples)
    c = parse_color(bg_color) if bg_color else None
    if c is not None and c[3] > 0:
        base = [composite(c, b) for b in base] if c[3] < 1 else [c[:3]]

    stops_with_pos = _parse_gradient_stops(image_value)
    if not stops_with_pos:
        return base

    stops = [s for s, _ in stops_with_pos]
    positions = [p for _, p in stops_with_pos]

    # 不再无条件保留 base：background-image 的每个色标经 composite() 合成时，
    # alpha=0 的色标本就会还原成 base，无需额外拼接——拼接会把已被不透明渐变
    # 完全盖住的旧底当成候选，污染 worst_contrast。
    out = []
    for b in base:
        for i in range(len(stops) - 1):
            s0, s1 = stops[i], stops[i + 1]
            hard_stop = (positions[i] is not None and positions[i + 1] is not None
                         and positions[i] == positions[i + 1])
            steps = 2 if hard_stop else GRADIENT_SAMPLES
            for k in range(steps):
                t = k / (steps - 1)
                interp = tuple(s0[j] + (s1[j] - s0[j]) * t for j in range(4))
                out.append(composite(interp, b))
    # 去重但保持可预期的顺序
    seen, uniq = set(), []
    for s in out:
        if s not in seen:
            seen.add(s)
            uniq.append(s)
    return uniq


def worst_contrast(fg, samples):
    """对候选底集合取最差对比度。"""
    return min(contrast_ratio(fg, s) for s in samples)


from collections import namedtuple
from html.parser import HTMLParser

Node = namedtuple("Node", "tag fg samples size weight text style own_bg")

#: 自闭合标签，不进栈
VOID_TAGS = {"br", "hr", "img", "meta", "link", "input", "area", "base", "col", "wbr"}


class ContrastWalkError(Exception):
    """产物结构不符合假设——不许继续算，静默兜底会让全部测量变成编造的数字。"""


def parse_style(s):
    """'a: b; c: d' → {'a': 'b', 'c': 'd'}，键小写。"""
    d = {}
    for part in (s or "").split(";"):
        if ":" not in part:
            continue
        k, _, v = part.partition(":")
        d[k.strip().lower()] = v.strip()
    return d


def _px(v, default):
    m = re.match(r"([\d.]+)\s*px", (v or "").strip())
    return float(m.group(1)) if m else default


def _weight(v, default):
    v = (v or "").strip().lower()
    if v in ("bold", "bolder"):
        return 700
    if v == "normal":
        return 400
    return int(v) if v.isdigit() else default


def _px_or_none(v):
    """严格版长度解析：只认 `<数字>px`，别的一律 None。

    **不要用上面的 `_px()`**：它解析失败时返回调用方给的 default，会把
    「解析不出来」变成「等于某个数」。这里两个用处的失败方向正好相反
    （条带高度算大了会放行、padding 算小了会拦住），静默默认值会各错一次。
    `padding: 0` 这种合法的无单位零也判 None——倒向「保留图像」，方向安全。
    """
    m = re.fullmatch(r"\s*(\d+(?:\.\d+)?)px\s*", v or "")
    return float(m.group(1)) if m else None


def _padding_side(shorthand, side):
    """从 padding 简写里取上边或下边的值（px），取不出来返回 None。

    CSS 简写四种形态：1 个值 = 四边；2 个 = 上下 / 左右；3 个 = 上 / 左右 / 下；
    4 个 = 上 / 右 / 下 / 左。上边永远是第 1 个；下边在 3、4 值时是第 3 个，
    1、2 值时与上边同值。
    """
    parts = (shorthand or "").split()
    if not parts or len(parts) > 4:
        return None
    top = parts[0]
    bottom = parts[2] if len(parts) >= 3 else parts[0]
    return _px_or_none(top if side == "top" else bottom)


# 条带贴哪一边 → 该看哪一侧的 padding
_STRIP_SIDES = {"top": "padding-top", "bottom": "padding-bottom"}


def image_reaches_text(st):
    """这个元素的 background-image 有没有可能落在它自己的文字后面。

    **默认 True。**只有当图像被限制成一条贴边条带、且该侧 padding 保证文字
    够不到它时才返回 False——此时元素内文字的底是 background-color，那张
    图像不参与底色候选。

    四条必要条件（全部成立才 False）：
      1. background-repeat 恰好是 no-repeat
      2. background-size 有两个分量，且高度分量（第二个）是 px 固定长度
      3. background-position 恰好是 top 或 bottom
      4. 该侧 padding 是 px 且 ≥ 条带高度

    任何一条判不出来（属性缺失、单位不是 px、值不认识、多层背景）都倒向 True
    = 保留图像 = 继续按渐变判。所以这道门**只可能多报，不可能藏发现**。
    设计与逐条理由：docs/superpowers/specs/2026-08-11-background-size-backdrop-design.md
    """
    if not st.get("background-image"):
        return True

    # 1. 没写 background-repeat 就是 CSS 默认的 repeat——一条 4px 的渐变会平铺满
    #    整个元素。真实库里 autumn-warm / ocean-calm / spring-fresh 的 card 与
    #    blueprint-grid 的 container 正是这个形态（`20px 20px` 纹理，不写 repeat），
    #    它们确实盖在文字后面。这一条是这道门里唯一真正承重的。
    if (st.get("background-repeat") or "").strip().lower() != "no-repeat":
        return True

    # 2. 多层背景（含逗号）一律不解析；必须两个分量且高度是 px。
    size = (st.get("background-size") or "").strip().lower()
    if not size or "," in size:
        return True
    parts = size.split()
    if len(parts) != 2:
        return True
    strip_h = _px_or_none(parts[1])
    if strip_h is None:
        return True

    # 3. 只认光秃秃的 top / bottom。`top left`、`0 0`、`center top` 这些等价写法
    #    一律走保留图像那条路——收窄是安全方向。
    pad_key = _STRIP_SIDES.get((st.get("background-position") or "").strip().lower())
    if pad_key is None:
        return True

    # 4. 长写法优先于简写。这是唯一一条把「条带存在」变成「文字够不到条带」的
    #    机械证明；证明不了就保留图像。
    pad = _px_or_none(st[pad_key]) if st.get(pad_key) else _padding_side(
        st.get("padding"), pad_key.rsplit("-", 1)[1])
    return pad is None or pad < strip_h


class _Walker(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        # (tag, fg, samples, size, weight, style, own_bg)
        self.stack = [("\x00root", (0, 0, 0), [], 16.0, 400, "", None)]
        self.nodes = []

    def handle_starttag(self, tag, attrs):
        if tag in VOID_TAGS:
            return
        raw = dict(attrs).get("style", "")
        st = parse_style(raw)
        _, fg, samples, size, weight, _, _ = self.stack[-1]
        c = parse_color(st.get("color"))
        own = parse_color(st.get("background-color")) or parse_color(st.get("background"))
        self.stack.append((
            tag,
            c[:3] if c else fg,
            # 被 background-size 限制成贴边条带、且文字够不到的图像不算底色
            backdrop_samples(st.get("background-color") or st.get("background"),
                             st.get("background-image") if image_reaches_text(st) else None,
                             samples),
            _px(st.get("font-size"), size),
            _weight(st.get("font-weight"), weight),
            raw,
            own[:3] if own and own[3] == 1.0 else None,
        ))

    def handle_endtag(self, tag):
        for i in range(len(self.stack) - 1, 0, -1):
            if self.stack[i][0] == tag:
                del self.stack[i:]
                return

    def handle_data(self, data):
        text = data.replace("\xa0", " ").strip()
        if not text:
            return
        tag, fg, samples, size, weight, style, own_bg = self.stack[-1]
        if not samples:
            raise ContrastWalkError(
                f"文本节点 {text[:20]!r}（<{tag}>）的祖先链上没有任何底色声明。"
                f"产物最外层按结构必然带 container 的底，出现这种节点说明结构假设已不成立——"
                f"停下来看，不许假设白底继续算。")
        self.nodes.append(Node(tag, fg, samples, size, weight, text, style, own_bg))


def walk(html):
    """遍历产物 HTML，返回所有非空文本节点。结构不符合假设时抛 ContrastWalkError。"""
    w = _Walker()
    w.feed(html)
    w.close()
    if len(w.stack) != 1:
        residue = [t[0] for t in w.stack[1:]]
        raise ContrastWalkError(
            f"走完后标签栈没回到根，残留 {len(residue)} 层：{residue[:8]}。"
            f"栈错位会静默污染全部测量，是这套脚本最危险的失效模式。")
    return w.nodes


#: 会把「装饰」注入产物的 theme.json 字段。装饰按图形 3:1 判，其余按文字 4.5 判。
#: 这份名单是判据本身——加字段时必须同步这里，否则新装饰会被当成正文误报。
DECOR_FIELDS = (
    "h2_prefix_html", "h2_suffix_html", "h3_prefix_html",
    "list_prefix_html", "list_prefix_cycle", "list_prefix_ol_html",
    "blockquote_prefix_html", "footer_html",
)

_STYLE_ATTR = re.compile(r'style\s*=\s*"([^"]*)"')
_TAGS = re.compile(r"<[^>]+>")


def _norm_style(s):
    """比对用的样式串规范形：去首尾空白、去末尾分号、压缩内部空白。"""
    return re.sub(r"\s+", " ", (s or "").strip()).rstrip(";").strip()


def decor_signatures(theme, theme_name=None):
    """从 theme.json 抽出装饰节点的识别签名 → (样式串集合, 字面文本集合)。

    某个注入字段的值若不是字符串（比如未来出现 "footer_html": 12345），该项会被跳过——
    方向是安全的（只会让装饰集合变窄，从而让更多节点被当成文字判 4.5，不会漏判任何
    真发现）；但跳过必须叫出声，不许静默吃掉，否则下次同类字段出现，没人知道被略过了。
    """
    styles, texts = set(), set()
    for field in DECOR_FIELDS:
        val = theme.get(field)
        if not val:
            continue
        for item in (val if isinstance(val, list) else [val]):
            if not isinstance(item, str):
                print(f"WARN 主题 {theme_name!r} 的字段 {field!r} 里有一项不是字符串"
                      f"（类型 {type(item).__name__}），已跳过——装饰识别范围因此变窄，"
                      f"不会漏判真发现，但请确认这是预期的字段值。", file=sys.stderr)
                continue
            found = _STYLE_ATTR.findall(item)
            for s in found:
                styles.add(_norm_style(s))
            if not found:
                # 没有 style 的字段（如纯文本 list_prefix_ol_html）走字面文本；
                # `{n}` 序号占位原样保留在签名里，匹配时按整体模板判断（见 _text_matches），
                # 不拆成两半再比对——拆开后固定半边（比如单独的 "."）会跟任何以句号收尾的
                # 正文句子撞上，那就是又一次「按字符类判」的翻版，回到了本任务要避免的错误。
                plain = _TAGS.sub("", item).replace("&nbsp;", " ").strip()
                if plain:
                    texts.add(plain)
    return frozenset(styles), frozenset(texts)


_NUM_PLACEHOLDER = "{n}"


def _text_matches(t, template):
    """t 是不是由 template 生成的字面文本；template 可能含 `{n}` 数字占位（如 "{n}."）。"""
    if _NUM_PLACEHOLDER not in template:
        return t == template
    pattern = r"\d+".join(re.escape(p) for p in template.split(_NUM_PLACEHOLDER))
    return re.fullmatch(pattern, t) is not None


def is_decor(node, sigs):
    """该文本节点是不是由 theme.json 的注入字段产生的装饰。"""
    styles, texts = sigs
    style = _norm_style(node.style)
    if style and style in styles:
        return True
    t = node.text.strip()
    return any(_text_matches(t, x) for x in texts)


Finding = namedtuple("Finding", "theme tag fg bg size weight kind ratio sample count")

#: WCAG 2.1「大文本」：>=24px，或 >=18.66px 且 >=700。边界含等号。
LARGE_PX = 24.0
LARGE_BOLD_PX = 18.66
LARGE_BOLD_WEIGHT = 700


def is_large_text(size, weight):
    return size >= LARGE_PX or (size >= LARGE_BOLD_PX and weight >= LARGE_BOLD_WEIGHT)


def threshold(is_decor_flag, size, weight):
    """装饰按图形 3:1；文字按 WCAG AA 4.5，大文本 3.0。"""
    if is_decor_flag or is_large_text(size, weight):
        return 3.0
    return 4.5


def _hx(rgb):
    return "#%02x%02x%02x" % rgb


def findings_for(theme_name, html, theme):
    """一份产物的全部不达标发现，同键合并计数。"""
    sigs = decor_signatures(theme, theme_name)
    acc = {}
    for n in walk(html):
        decor = is_decor(n, sigs)
        # 同色块：只对注入装饰生效
        if decor and n.own_bg is not None and n.fg == n.own_bg:
            continue
        ratio = worst_contrast(n.fg, n.samples)
        thr = threshold(decor, n.size, n.weight)
        if ratio >= thr:
            continue
        worst_bg = min(n.samples, key=lambda s: contrast_ratio(n.fg, s))
        key = (theme_name, n.tag, _hx(n.fg), _hx(worst_bg),
               round(n.size, 2), n.weight, "装饰" if decor else "文字")
        if key in acc:
            acc[key] = acc[key]._replace(count=acc[key].count + 1)
        else:
            acc[key] = Finding(*key, round(ratio, 2), n.text[:24], 1)
    return sorted(acc.values(), key=lambda f: (f.ratio, f.theme, f.tag))
