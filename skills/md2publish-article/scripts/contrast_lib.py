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
