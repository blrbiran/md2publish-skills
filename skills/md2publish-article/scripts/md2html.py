#!/usr/bin/env python3
"""Markdown → 微信公众号内联样式 HTML 的机械层。

用法：
    python3 md2html.py <article.md> <theme.json> -o <out.html>
    python3 md2html.py <article.md> <theme.json> --verify <out.html>   # 只跑代码块保真核对

## 为什么有这个脚本

转义顺序、`&nbsp;` 边界、装饰 `<span>` 不能跨 `<br>`——这些坑对所有主题都一样，
但过去每次生成都由模型现写一份转换脚本，等于每次都重新有一次写错的机会，正确性
全靠事后逐字节 diff 兜住。这里把与主题无关的机械层固定下来，主题差异从 theme.json
传入，模型只做判断层（哪段升格提示卡、语法高亮取哪几个色、主题没覆盖的元素怎么补）。

## theme.json 的形状

所有 `style` 字段都是内联样式串，直接进 HTML。缺的字段用空串，不会报错但会少样式。

    {
      "container":    "background-color: #0f1420; padding: 36px 12px",   # 不写 max-width，它负责铺满
      "content_width": 800,                                             # 定宽加在内容块上
      "card":         "background-color: #1b2438; border: 1px solid ...", # 有值则每章包一张卡
      "p":            "font-size: 15.5px; color: #c9d2e3; ...",
      "h2":           "...", "h2_prefix_html": "<span style=...>&gt;_&nbsp;</span>",
      "h3":           "...",
      "strong":       "color: #39d0d8; font-weight: 600",
      "em":           "color: #ff4ba3",
      "blockquote":   "...",
      "pre":          "...", "code":  "...",
      "inline_code":  "color: #39d0d8",
      "list_prefix_html": "<span style=\\"color: #39d0d8;\\">▸</span>&nbsp;&nbsp;",
      "list_item":    "...",
      "table": "...", "th": "...", "td": "...",
      "hr":           "...",                       # 无卡片主题的分隔线；卡片主题留空，用 hr_gap
      "hr_gap":       56,                          # 卡片主题：--- 处把卡间距放大到这个值(px)
      "highlight":    {"comment": "#7a869e", "string": "#39d0d8",
                       "key": "#39d0d8", "keyword": "#ff4ba3", "number": "#c9d2e3"}
    }

## 与铁律的关系

脚本从机制上保证的：代码块无裸换行、`<pre>` 内 `&nbsp;` 缩进、块间无空行、无原生
列表标签、每个 `<p>` 有显式 color 和 text-align、装饰 span 不跨 `<br>`、正文不渲染 H1。
主题配置里写错颜色这类事脚本管不了，仍要跑 wechat-html.md 的自检。
"""

import argparse
import html as H
import json
import re
import sys
from pathlib import Path

# ── 语法高亮：按语言切 (文本, token 类) 段 ───────────────────────────────────

KEYWORDS = {
    "python": r"\b(?:def|class|import|from|return|if|elif|else|for|while|try|except|with|as|in|not|and|or|None|True|False|lambda|yield|async|await)\b",
    "bash": r"(?:^|(?<=[|;&]\s))\s*(?:curl|export|cd|echo|python3?|pip|uv|npm|npx|docker|git|source|mkdir|cat|grep|sed|awk)\b",
    "json": r"\b(?:true|false|null)\b",
    "yaml": r"\b(?:true|false|null|yes|no)\b",
    "toml": r"\b(?:true|false)\b",
}


def tokenize(line, lang):
    """把一行切成 [(文本, 类名或 None)]，拼回去必须与原行逐字符相同。

    只认几类高置信度的 token。宁可少上色也不要切错——切错会改变代码显示，
    而这个脚本的第一职责是保真。
    """
    lang = (lang or "").lower()
    spans = []           # (start, end, cls)

    def claim(m, cls):
        s, e = m.span()
        if not any(s < ee and ss < e for ss, ee, _ in spans):
            spans.append((s, e, cls))

    # 注释：# 开头（yaml/bash/python/toml）或 // （json5 等）
    if lang in ("yaml", "bash", "sh", "shell", "python", "py", "toml", "ini", ""):
        m = re.search(r"(?<!\S)#(?!\{).*$", line)
        if m:
            claim(m, "comment")
    for m in re.finditer(r"//.*$", line):
        claim(m, "comment")

    # 字符串：成对引号，不跨行
    for m in re.finditer(r"\"(?:[^\"\\\n]|\\.)*\"|'(?:[^'\\\n]|\\.)*'", line):
        claim(m, "string")

    # 键名：行首缩进后的 key:（yaml/toml）或 "key":（json）
    if lang in ("yaml", "yml", "toml", "ini", ""):
        m = re.match(r"^(\s*-?\s*)([A-Za-z_][\w.-]*)(?=\s*:)", line)
        if m:
            claim(re.match(r"^" + re.escape(m.group(1)) + r"([A-Za-z_][\w.-]*)", line), "key")
    if lang == "json":
        for m in re.finditer(r"\"[^\"\n]+\"(?=\s*:)", line):
            claim(m, "key")

    if lang in KEYWORDS:
        for m in re.finditer(KEYWORDS[lang], line):
            claim(m, "keyword")

    for m in re.finditer(r"(?<![\w.#-])\d+(?:\.\d+)?(?![\w.-])", line):
        claim(m, "number")

    spans.sort()
    out, pos = [], 0
    for s, e, cls in spans:
        if s > pos:
            out.append((line[pos:s], None))
        out.append((line[s:e], cls))
        pos = e
    if pos < len(line):
        out.append((line[pos:], None))
    return out or [(line, None)]


# ── 机械层：转义 → &nbsp; → <br> → span，顺序固定 ────────────────────────────

def esc(text):
    return H.escape(text, quote=False)


def spaces_to_nbsp(escaped):
    """行首每个空格 + 行中连续空格 → &nbsp;。

    必须在转义之后做（否则 &nbsp; 的 & 会被转义），在包 span 之前做
    （否则会动到标签内部）。
    """
    m = re.match(r"^( +)", escaped)
    if m:
        escaped = "&nbsp;" * len(m.group(1)) + escaped[m.end():]
    return re.sub(r"  +", lambda x: "&nbsp;" * len(x.group()), escaped)


def render_code(code, lang, highlight):
    """代码块内容 → HTML。每行独立处理，span 绝不跨越 <br>。"""
    lines_out = []
    for line in code.split("\n"):
        parts = []
        for text, cls in tokenize(line, lang):
            piece = spaces_to_nbsp(esc(text))
            color = (highlight or {}).get(cls) if cls else None
            parts.append(f'<span style="color: {color};">{piece}</span>' if color else piece)
        lines_out.append("".join(parts))
    return "<br>".join(lines_out)


def decode_code(fragment):
    """render_code 的逆运算，用于保真核对：剥 span → <br> → &nbsp; → 实体还原。"""
    t = re.sub(r"(?i)<br\s*/?>", "\n", fragment)   # 先把 <br> 换回换行
    t = re.sub(r"<[^>]+>", "", t)                  # 再剥掉全部标签（span、code 包装都要剥干净）
    t = t.replace("&nbsp;", " ")
    return H.unescape(t)


# ── 行内标记 ────────────────────────────────────────────────────────────────

def inline(text, T):
    """段落内的 Markdown 行内标记 → HTML。先转义，再替换标记。

    转义不会碰 `*` 和反引号，所以标记在转义后依然可识别；反过来先替换标记
    再转义，会把刚生成的标签一起转义掉。
    """
    out = esc(text)
    out = re.sub(r"`([^`]+)`",
                 lambda m: f'<span style="{T.get("inline_code", "")}">{m.group(1)}</span>', out)
    out = re.sub(r"\*\*([^*]+)\*\*",
                 lambda m: f'<strong style="{T.get("strong", "")}">{m.group(1)}</strong>', out)
    out = re.sub(r"(?<![*\w])\*([^*\n]+)\*(?!\*)",
                 lambda m: f'<em style="{T.get("em", "")}">{m.group(1)}</em>', out)
    out = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r"\1（\2）", out)   # 公众号正文不支持外链
    return out


# ── 解析 ────────────────────────────────────────────────────────────────────

def parse(md):
    """切成块。只认这套语料实际用到的语法，不做通用 Markdown 解析器。"""
    lines, blocks, i = md.split("\n"), [], 0
    while i < len(lines):
        line = lines[i]
        if re.match(r"^```", line):
            lang = line.strip("`").strip()
            buf, i = [], i + 1
            while i < len(lines) and not re.match(r"^```", lines[i]):
                buf.append(lines[i]); i += 1
            blocks.append(("code", "\n".join(buf), lang)); i += 1
        elif re.match(r"^#{1,6}\s", line):
            level = len(line) - len(line.lstrip("#"))
            blocks.append(("h", line.lstrip("#").strip(), level)); i += 1
        elif re.match(r"^\s*(?:---+|\*\*\*+)\s*$", line):
            blocks.append(("hr", "", None)); i += 1
        elif line.strip().startswith(">"):
            buf = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                buf.append(re.sub(r"^\s*>\s?", "", lines[i])); i += 1
            blocks.append(("quote", "\n".join(buf).strip(), None))
        elif re.match(r"^\s*\|.*\|\s*$", line):
            buf = []
            while i < len(lines) and re.match(r"^\s*\|", lines[i]):
                buf.append(lines[i]); i += 1
            blocks.append(("table", buf, None))
        elif re.match(r"^\s*(?:[-*+]|\d+\.)\s+", line):
            buf = []
            while i < len(lines) and re.match(r"^\s*(?:[-*+]|\d+\.)\s+", lines[i]):
                buf.append(lines[i]); i += 1
            blocks.append(("list", buf, None))
        elif line.strip():
            buf = []
            while i < len(lines) and lines[i].strip() and not re.match(
                    r"^(```|#{1,6}\s|\s*[-*+]\s|\s*\d+\.\s|\s*\||\s*>)", lines[i]):
                buf.append(lines[i].strip()); i += 1
            blocks.append(("p", " ".join(buf), None))
        else:
            i += 1
    return blocks


# ── 生成 ────────────────────────────────────────────────────────────────────

def width_style(T):
    """定宽 + 水平居中，加在内容块上（不加在主容器上——主容器要铺满，背景才不会被夹成一条）。

    两个坑，都踩过：
    1. 用 margin-left/right 而不是简写 `margin: 0 auto`——简写会把主题定的上下间距清掉
    2. **这串必须拼在主题样式之后**。主题样式里通常有 `margin: 0 0 32px` 这样的简写，
       它出现在后面就会把 margin-left/right 覆盖回 0，定宽还在但居中没了，内容贴左边
    """
    w = T.get("content_width")
    return (f"; max-width: {w}px; margin-left: auto; margin-right: auto; "
            f"box-sizing: border-box") if w else ""


def build(md, T, source_name, meta):
    blocks = parse(md)
    W = width_style(T)
    use_cards = bool(T.get("card"))
    out, card_open = [], False

    def close_card(gap=None):
        nonlocal card_open
        if card_open:
            out.append("</section>")
            card_open = False
        if gap:
            out.append(f'<div style="height: {gap}px; line-height: 0;">&nbsp;</div>')

    def open_card():
        nonlocal card_open
        if use_cards and not card_open:
            out.append(f'<section style="{sty(T["card"], boxed=True)}">')
            card_open = True

    def sty(base, boxed=False, extra_css=""):
        """拼样式串。定宽居中永远拼在最后——主题样式里的 `margin` 简写若出现在它之后，
        会把 margin-left/right: auto 覆盖回 0，结果就是定宽生效但内容贴左边。

        boxed=True 表示这个元素自己承担定宽（卡片，或无卡片主题下的顶层块）。
        已经在卡片里的元素不再定宽——卡片已经把宽度管住了。
        """
        s = f'{base}; text-align: left{extra_css}'
        return s + W if boxed else s

    for kind, body, extra in blocks:
        if kind == "h" and extra == 1:
            continue                      # H1 只进元数据，正文不渲染
        top = not card_open               # 不在卡片里 → 这个元素自己定宽

        if kind == "h":
            if extra == 2:
                close_card()
                open_card()
                prefix = T.get("h2_prefix_html", "")
                out.append(f'<h2 style="{sty(T.get("h2",""), boxed=not card_open)}">'
                           f'{prefix}{inline(body, T)}</h2>')
            else:
                out.append(f'<h3 style="{sty(T.get("h3",""), boxed=top)}">{inline(body, T)}</h3>')
        elif kind == "p":
            open_card()
            out.append(f'<p style="{sty(T.get("p",""), boxed=not card_open)}">{inline(body, T)}</p>')
        elif kind == "code":
            open_card()
            out.append(f'<pre style="{sty(T.get("pre",""), boxed=not card_open, extra_css="; overflow-x: auto; letter-spacing: 0")}">'
                       f'<code style="{T.get("code","")}; display: block; white-space: normal; '
                       f'letter-spacing: 0; font-family: inherit;">'
                       f'{render_code(body, extra, T.get("highlight"))}</code></pre>')
        elif kind == "quote":
            open_card()
            out.append(f'<p style="{sty(T.get("blockquote",""), boxed=not card_open)}">'
                       f'{inline(body, T)}</p>')
        elif kind == "list":
            open_card()
            for item in body:
                ordered = re.match(r"^\s*(\d+)\.\s+(.*)$", item)
                if ordered:
                    pre, text = f'{ordered.group(1)}.&nbsp;&nbsp;', ordered.group(2)
                else:
                    text = re.sub(r"^\s*[-*+]\s+", "", item)
                    pre = T.get("list_prefix_html", "•&nbsp;&nbsp;")
                out.append(f'<p style="{sty(T.get("list_item", T.get("p","")), boxed=not card_open, extra_css="; padding-left: 1.5em; text-indent: -1.5em")}">'
                           f'{pre}{inline(text, T)}</p>')
        elif kind == "table":
            open_card()
            rows = [[c.strip() for c in r.strip().strip("|").split("|")] for r in body]
            rows = [r for r in rows if not all(re.match(r"^:?-+:?$", c) for c in r)]
            cells = []
            for n, row in enumerate(rows):
                tag, st = ("th", T.get("th", "")) if n == 0 else ("td", T.get("td", ""))
                cells.append("<tr>" + "".join(
                    f'<{tag} style="{st}; word-break: break-word; text-align: left;">{inline(c, T)}</{tag}>'
                    for c in row) + "</tr>")
            out.append(f'<table style="{sty(T.get("table",""), boxed=not card_open, extra_css="; table-layout: fixed; border-collapse: collapse; width: 100%")}">'
                       + "".join(cells) + "</table>")
        elif kind == "hr":
            if use_cards:
                close_card(gap=T.get("hr_gap", 56))     # 卡片主题：用更大的间距表达分组断点
            elif T.get("hr"):
                out.append(f'<div style="{sty(T["hr"], boxed=True)}"></div>')

    close_card()
    head = ('<!-- md2publish ' + json.dumps(
        {"title": meta.get("title", ""), "author": meta.get("author", ""),
         "digest": meta.get("digest", ""), "source": source_name},
        ensure_ascii=False) + ' -->')
    return (head + "\n<div style=\"" + T.get("container", "") + "; text-align: left;\">\n"
            + "\n".join(out) + "\n</div>")


# ── 保真核对 ────────────────────────────────────────────────────────────────

def verify(md, html):
    """把产物里每个 <pre> 反解，与原文代码块逐字节比对。"""
    src, buf, infence = [], None, False
    for line in md.split("\n"):
        if re.match(r"^```", line):
            if infence:
                src.append("\n".join(buf)); infence = False
            else:
                infence, buf = True, []
        elif infence:
            buf.append(line)
    got = [decode_code(m) for m in re.findall(r"<pre[^>]*>(.*?)</pre>", html, re.S)]
    bad = []
    for n, (a, b) in enumerate(zip(got, src)):
        if a.rstrip("\n") != b.rstrip("\n"):
            bad.append(n)
    return len(src), len(got), bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("markdown"); ap.add_argument("theme")
    ap.add_argument("-o", "--out"); ap.add_argument("--verify")
    ap.add_argument("--title", default=""); ap.add_argument("--author", default="")
    ap.add_argument("--digest", default="")
    a = ap.parse_args()

    md = Path(a.markdown).read_text(encoding="utf-8")
    if a.verify:
        n_src, n_got, bad = verify(md, Path(a.verify).read_text(encoding="utf-8"))
        print(f"代码块 {n_got}/{n_src}，不一致 {len(bad)} 处" + (f"：#{bad}" if bad else "，全部逐字节保真"))
        return 1 if bad or n_got != n_src else 0

    T = json.loads(Path(a.theme).read_text(encoding="utf-8"))
    title = a.title or next((l.lstrip("#").strip() for l in md.split("\n")
                             if re.match(r"^#\s", l)), "")
    html = build(md, T, Path(a.markdown).name,
                 {"title": title, "author": a.author, "digest": a.digest})
    Path(a.out).write_text(html, encoding="utf-8") if a.out else print(html)

    n_src, n_got, bad = verify(md, html)
    print(f"写出 {a.out}；代码块 {n_got}/{n_src}，"
          + (f"不一致 {len(bad)} 处：#{bad}" if bad else "全部逐字节保真"), file=sys.stderr)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
