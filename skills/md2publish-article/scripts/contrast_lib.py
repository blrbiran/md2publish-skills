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
