#!/usr/bin/env python3
"""产物 HTML 的对比度原语。

设计与判据理由见 docs/superpowers/specs/2026-08-10-contrast-audit-design.md。
与 theme_lib.py 分开：那边读 theme.json，这边读产物 DOM。
"""
import re

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
    r"(?:\s+(-?\d+(?:\.\d+)?)%)?"
)

#: 沿渐变采样的步数。101 = 每 1% 一个采样点。
#: 不许改成只取两端——L(t) 是凸的，最小值可能落在内部（见本文件顶部 spec 链接）。
GRADIENT_SAMPLES = 101


def _parse_gradient_stops(css_value):
    """按出现顺序抽取 (color, position) 对；position 是显式百分比数字，没写则 None。非渐变返回 []。"""
    if not css_value or "gradient" not in css_value:
        return []
    out = []
    for tok, pos in _STOP_TOKEN.findall(css_value):
        c = parse_color(tok)
        if c is not None:
            out.append((c, float(pos) if pos else None))
    return out


def gradient_stops(css_value):
    """从 gradient 声明里按出现顺序抽色标；没有 gradient 关键字返回 []。"""
    return [c for c, _ in _parse_gradient_stops(css_value)]


def backdrop_samples(bg_color, image_value, parent_samples):
    """该元素的有效底候选集（不透明 RGB 列表）。

    background-color 打底（不透明则盖住父级），再把 background-image 的色标按 alpha
    依次合成上去。相邻两个色标若显式写了相同的百分比位置——CSS 的硬停（hard stop，
    比如 morandi-fog 的下划线带 `transparent 62%, rgba(...) 62%`）——中间没有过渡区，
    只取两端合成值；否则视为连续渐变，沿途按 GRADIENT_SAMPLES 采样，因为 L(t) 对 t
    是凸的，最小值可能落在内部，端点法会漏判。
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
        solid = [composite(s, b) for s in stops]
        for i in range(len(solid) - 1):
            p, q = solid[i], solid[i + 1]
            hard_stop = (positions[i] is not None and positions[i + 1] is not None
                         and positions[i] == positions[i + 1])
            steps = 2 if hard_stop else GRADIENT_SAMPLES
            for k in range(steps):
                t = k / (steps - 1)
                out.append(tuple(int(round(p[j] + (q[j] - p[j]) * t)) for j in range(3)))
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
            backdrop_samples(st.get("background-color") or st.get("background"),
                             st.get("background-image"), samples),
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


def decor_signatures(theme):
    """从 theme.json 抽出装饰节点的识别签名 → (样式串集合, 字面文本集合)。"""
    styles, texts = set(), set()
    for field in DECOR_FIELDS:
        val = theme.get(field)
        if not val:
            continue
        for item in (val if isinstance(val, list) else [val]):
            if not isinstance(item, str):
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
    sigs = decor_signatures(theme)
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
