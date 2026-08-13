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
      "card":         "background-color: #1b2438; border: 1px solid ...", # 有值则包卡片
      "card_mode":    "section",                   # section=每章一张（默认）｜single=全文一张大卡
      "p":            "font-size: 15.5px; color: #c9d2e3; ...",
      "p_first":      "font-size: 17px; border-left: 3px solid #9e2b25; ...",  # 导语：全文
                                   # 第一个段落（不是每章），与 h2_first 同构、各自独立计数
      "h2":           "...", "h2_prefix_html": "<span style=...>&gt;_&nbsp;</span>",
      "h2_suffix_html": "<span style=...>&nbsp;◆</span>",   # 与前缀对称，做两侧饰线
      "h2_first":     "...",                       # 首个 h2 顶在页首，通常要去掉上间距/节前线
      "h2_text_style": "background-color: #171614; color: #f4f1ea; ...",  # 标题文字自带色块时用
      "h3":           "...", "h3_prefix_html": "<span style=...>#&nbsp;</span>",
      "strong":       "color: #39d0d8; font-weight: 600",
      "strong_alt":   {"keywords": ["注意", "警告", "不要", "会导致"],   # 警示语义的 strong
                       "style": "color: #ff4ba3; font-weight: 600"},   # 换一套样式
      "em":           "color: #ff4ba3",
      "blockquote":   "...",
      "blockquote_prefix_html": "<span style=...>❝&nbsp;</span>",   # 提示卡上不加
      "footer":       "text-align: center; color: #8a5a3b; margin: 40px 0 0",  # 文末装饰：
      "footer_html":  "<span style=...>終</span>",   # 印章 / 落款 / 「終」字，在所有卡片之外
                                                     # ↑ footer 要自带 color：它是唯一没有
                                                     #   `p` 兜底的段落（脚本会退回正文色，
                                                     #   但那通常不是落款该有的分量）
      "alert":        {"note": {"style": "...",           # 提示卡，文章 md 里写 `> [!NOTE]` 触发；
                                "label_html": "..."},     # 值也可以只是样式串（无标签）
                       "warning": "..."},                 # 主题没配 alert 就退化成普通引用块
      "pre":          "...", "code":  "...",
      "inline_code":  "color: #39d0d8",
      "list_prefix_html": "<span style=\\"color: #39d0d8;\\">▸</span>&nbsp;&nbsp;",
      "list_prefix_cycle": ["<span ...>■</span>&nbsp;&nbsp;", "..."],   # 多色轮换，有它就盖过上一行
      "list_prefix_ol_html": "<span style=...>{n}</span>&nbsp;&nbsp;",  # 有序项，`{n}` = 源文序号
                                                                       # 不配就退回纯文本 `N.`
      "list_item":    "...",
      "table": "...", "th": "...", "td": "...",
      "td_alt":       "background-color: #f6f8fa",  # 斑马纹：叠加在偶数数据行的 td 上
      "hr":           "...",                       # 无卡片/单卡主题的分隔线；分章卡片主题用 hr_gap
      "hr_gap":       56,                          # 分章卡片主题：--- 处把卡间距放大到这个值(px)
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
            # 值可以是裸色值，也可以是完整样式串——低彩主题靠字重和字形区分 token，
            # 只能上色的话它就没有区分手段了（ink-wash；terracotta-sun 的注释与关键字
            # 在自己的代码底上只有一支达标色可用，只能同色不同字重/字形）。
            v = (highlight or {}).get(cls) if cls else None
            css = (v if v and ":" in v else f"color: {v};") if v else None
            parts.append(f'<span style="{css}">{piece}</span>' if css else piece)
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
    def strong_tag(m):
        """strong 默认走 `strong`；配了 `strong_alt` 且文字命中关键词就换一套样式。

        几个主题把「注意 / 警告 / 不要 / 会导致」这类警示性 strong 规定成另一个色。
        这条规范本来就是按关键词写的、机械可判，只是过去没有挂载点，于是在产物里静默
        丢失（cyber-neon 的品红 36 处，落在 strong 上 0 处）。

        命中判定要剥掉标签：此处行内 code 已经变成 `<span style=...>`，不剥的话关键词
        会去和样式串比对。
        """
        inner = m.group(1)
        alt = T.get("strong_alt")
        if alt and any(k in re.sub(r"<[^>]+>", "", inner) for k in alt.get("keywords", [])):
            return f'<strong style="{alt.get("style", "")}">{inner}</strong>'
        return f'<strong style="{T.get("strong", "")}">{inner}</strong>'

    out = re.sub(r"\*\*([^*]+)\*\*", strong_tag, out)
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
            # GitHub Alert 标记：首行 `[!NOTE]` 之类把这个引用块升格成提示卡。
            # 标记无论认不认都要剥掉——主题没配 alert 只是退化成普通引用块，
            # 漏剥则是 `[!NOTE]` 六个字符直接印进文章。
            # GitHub 要求标记独占一行，但写成 `> [!NOTE] 正文` 的人不少，两种都认。
            alert = None
            m = re.match(r"^\s*\[!([A-Za-z]+)\]\s*(.*)$", buf[0]) if buf else None
            if m:
                alert = m.group(1).lower()
                buf = ([m.group(2)] if m.group(2).strip() else []) + buf[1:]
            blocks.append(("quote", "\n".join(buf).strip(), alert))
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

# GitHub 五种 Alert，但主题一般只配 note/warning 两档。配不全时按语气归并，
# 而不是静默掉回灰引用块——`[!CAUTION]` 掉成普通引用块，警示语义就丢了。
ALERT_ALIAS = {"tip": "note", "important": "note", "caution": "warning"}


def alert_spec(T, kind):
    """取提示卡样式。返回 {} 表示这个块照普通引用块渲染。

    `alert` 的值两种写法都认（与 `highlight` 同样的宽松策略）：
        "note": "border-left: 4px solid #0969da; background-color: #ddf4ff; ..."
        "note": {"style": "...", "label_html": "<span style=...>注意</span><br>"}
    """
    table = T.get("alert") or {}
    if not kind or not table:
        return {}
    spec = table.get(kind, table.get(ALERT_ALIAS.get(kind, "")))
    if spec is None:
        return {}
    return {"style": spec} if isinstance(spec, str) else dict(spec)


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
    single_card = use_cards and T.get("card_mode") == "single"   # 全文一张大卡（editor-slate 那种）
    out, card_open, seen_h2, seen_p = [], False, False, False

    def close_card(gap=None, force=False):
        """单卡主题下 h2 不切卡，只有收尾时（force）才真的闭合。"""
        nonlocal card_open
        if card_open and (force or not single_card):
            out.append("</section>")
            card_open = False
        if gap and not single_card:
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

        text-align 只在主题没写时才补 left：ink-wash 的 h2、印章符号是居中的，
        无条件追加 left 会把主题的 center 覆盖掉。
        """
        align = "" if re.search(r"(^|;)\s*text-align\s*:", base) else "; text-align: left"
        s = f'{base}{align}{extra_css}'
        return s + W if boxed else s

    for kind, body, extra in blocks:
        if kind == "h" and extra == 1:
            continue                      # H1 只进元数据，正文不渲染

        if kind == "h":
            if extra == 2:
                close_card()
                open_card()
                text = inline(body, T)
                if T.get("h2_text_style"):       # 标题文字自带色块时，色块只能包文字，不能上到 h2
                    text = f'<span style="{T["h2_text_style"]}">{text}</span>'
                # 正文不渲染 H1，首个 h2 就顶在页面最上面——主题给的上间距和节前
                # 分隔线是为「章节之间」准备的，落在这里就是页首一块空白加一根孤线。
                base_h2 = T["h2_first"] if (seen_h2 is False and T.get("h2_first")) else T.get("h2", "")
                seen_h2 = True
                out.append(f'<h2 style="{sty(base_h2, boxed=not card_open)}">'
                           f'{T.get("h2_prefix_html", "")}{text}'
                           f'{T.get("h2_suffix_html", "")}</h2>')
            else:
                open_card()                      # h3 也可能是一章的开头（源文里 h2 后直接跟 h3）
                out.append(f'<h3 style="{sty(T.get("h3",""), boxed=not card_open)}">'
                           f'{T.get("h3_prefix_html", "")}{inline(body, T)}</h3>')
        elif kind == "p":
            open_card()
            # 导语：全文第一个段落走另一套样式（报纸体的首段引语）。与 h2_first 同构，
            # 计数各自独立。「全文第一段」按文档级算，不是每章一段——主题文件写的是「全文」。
            # 列表/代码/引用打头时它们不占这个位次，导语落在第一个真正的段落上。
            base_p = T["p_first"] if (seen_p is False and T.get("p_first")) else T.get("p", "")
            seen_p = True
            out.append(f'<p style="{sty(base_p, boxed=not card_open)}">{inline(body, T)}</p>')
        elif kind == "code":
            open_card()
            out.append(f'<pre style="{sty(T.get("pre",""), boxed=not card_open, extra_css="; overflow-x: auto; letter-spacing: 0")}">'
                       f'<code style="{T.get("code","")}; display: block; white-space: normal; '
                       f'letter-spacing: 0; font-family: inherit;">'
                       f'{render_code(body, extra, T.get("highlight"))}</code></pre>')
        elif kind == "quote":
            open_card()
            spec = alert_spec(T, extra)
            style = spec.get("style") or T.get("blockquote", "")
            label = spec.get("label_html", "")
            prefix = "" if spec else T.get("blockquote_prefix_html", "")
            out.append(f'<p style="{sty(style, boxed=not card_open)}">'
                       f'{label}{prefix}{inline(body, T)}</p>')
        elif kind == "list":
            open_card()
            cycle = T.get("list_prefix_cycle")
            bullet_n = 0                  # 只数无序项，有序项不占轮换位次
            for item in body:
                ordered = re.match(r"^\s*(\d+)\.\s+(.*)$", item)
                if ordered:
                    text = ordered.group(2)
                    ol_tpl = T.get("list_prefix_ol_html")   # `{n}` 占位符换成源文里的序号
                    pre = (ol_tpl.replace("{n}", ordered.group(1)) if ol_tpl
                           else f'{ordered.group(1)}.&nbsp;&nbsp;')
                else:
                    text = re.sub(r"^\s*[-*+]\s+", "", item)
                    pre = (cycle[bullet_n % len(cycle)] if cycle
                           else T.get("list_prefix_html", "•&nbsp;&nbsp;"))
                    bullet_n += 1
                out.append(f'<p style="{sty(T.get("list_item", T.get("p","")), boxed=not card_open, extra_css="; padding-left: 1.5em; text-indent: -1.5em")}">'
                           f'{pre}{inline(text, T)}</p>')
        elif kind == "table":
            open_card()
            rows = [[c.strip() for c in r.strip().strip("|").split("|")] for r in body]
            rows = [r for r in rows if not all(re.match(r"^:?-+:?$", c) for c in r)]
            cells = []
            for n, row in enumerate(rows):
                tag, st = ("th", T.get("th", "")) if n == 0 else ("td", T.get("td", ""))
                if tag == "td" and T.get("td_alt") and n % 2 == 0:
                    st = f'{st}; {T["td_alt"]}'    # 斑马纹落在第 2、4… 条数据行
                cells.append("<tr>" + "".join(
                    f'<{tag} style="{st}; word-break: break-word; text-align: left;">{inline(c, T)}</{tag}>'
                    for c in row) + "</tr>")
            out.append(f'<table style="{sty(T.get("table",""), boxed=not card_open, extra_css="; table-layout: fixed; border-collapse: collapse; width: 100%")}">'
                       + "".join(cells) + "</table>")
        elif kind == "hr":
            if use_cards and not single_card:
                close_card(gap=T.get("hr_gap", 56))     # 分章卡片主题：用更大的间距表达分组断点
            elif T.get("hr"):
                out.append(f'<div style="{sty(T["hr"], boxed=not card_open)}"></div>')

    close_card(force=True)
    # 文末装饰（印章 / 落款 / 「終」字）。落在所有卡片之外、主容器之内，自己承担定宽——
    # 它是顶层块，和 hr 同一层。6 个主题的规范里有这一笔，早先没有挂载点时是静默丢掉的。
    if T.get("footer_html"):
        # 铁律要求每个 <p> 有显式 color，而 footer 是唯一一处「主题没写就真的没有」的
        # 段落——别的段落至少还有 `p` 兜着。用了这个字段的主题曾经 3/3 全栽在这上面。
        # 兜底色拼在最前面：主题若自己写了 color，它在后面自然覆盖。
        fs = T.get("footer", "")
        if not re.search(r"(^|;)\s*color\s*:", fs):
            m = re.search(r"(?:^|;)\s*color\s*:\s*([^;]+)", T.get("p", ""))
            fs = f'color: {m.group(1).strip() if m else "inherit"}; {fs}'
        out.append(f'<p style="{sty(fs, boxed=True)}">{T["footer_html"]}</p>')
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


def split_frontmatter(md):
    """剥掉开头的 YAML frontmatter，返回 (元数据 dict, 正文)。

    上游 `wechat-finetune` 的产物**必带** frontmatter（它的步骤 5 强制组装
    title/author/digest），所以这条链路默认就会走到这里。早先这个函数不存在，
    后果不是报错而是静默走歪：`---` 被渲染成 hr、`title:` 三行变成正文首段、
    元数据里的 title 从下面那个 H1 兜底逻辑里抓，而它当时连代码块都不排除，
    于是标题变成了验证小节里的一行 shell 注释「# OpenAI Chat 协议 + GLM」，
    一路带到草稿箱都没人发现。

    只认最朴素的 `key: value`，够覆盖 title/author/digest；解析不出键值对就
    当它不是 frontmatter（比如文章真的以一条分隔线开头），原样退回。
    """
    if not md.startswith("---"):
        return {}, md
    m = re.match(r"^---[ \t]*\n(.*?)\n---[ \t]*(?:\n|$)", md, re.S)
    if not m:
        return {}, md
    meta = {}
    for line in m.group(1).split("\n"):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        k, sep, v = line.partition(":")
        if not sep or not k.strip() or k != k.lstrip():   # 缩进行＝嵌套结构，不碰
            return {}, md
        meta[k.strip()] = v.strip().strip("'\"")
    return (meta, md[m.end():]) if meta else ({}, md)


def first_h1(md):
    """取正文第一个 H1 做标题兜底，**跳过围栏代码块**。

    不跳的话，`# 注释` 这种 shell/python 注释会被当成标题——实测踩过一次。
    """
    infence = False
    for line in md.split("\n"):
        if re.match(r"^```", line):
            infence = not infence
        elif not infence and re.match(r"^#\s", line):
            return line.lstrip("#").strip()
    return ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("markdown"); ap.add_argument("theme")
    ap.add_argument("-o", "--out"); ap.add_argument("--verify")
    ap.add_argument("--title", default=""); ap.add_argument("--author", default="")
    ap.add_argument("--digest", default="")
    a = ap.parse_args()

    md = Path(a.markdown).read_text(encoding="utf-8")
    fm, md = split_frontmatter(md)
    if a.verify:
        n_src, n_got, bad = verify(md, Path(a.verify).read_text(encoding="utf-8"))
        print(f"代码块 {n_got}/{n_src}，不一致 {len(bad)} 处" + (f"：#{bad}" if bad else "，全部逐字节保真"))
        return 1 if bad or n_got != n_src else 0

    T = json.loads(Path(a.theme).read_text(encoding="utf-8"))
    # 优先级按 SKILL.md 的声明：显式传参 → frontmatter → 正文 H1（摘要没有 H1 兜底）
    title = a.title or fm.get("title") or first_h1(md)
    author = a.author or fm.get("author", "")
    digest = (a.digest or fm.get("digest") or fm.get("summary")
              or fm.get("description", ""))
    html = build(md, T, Path(a.markdown).name,
                 {"title": title, "author": author, "digest": digest})
    Path(a.out).write_text(html, encoding="utf-8") if a.out else print(html)

    n_src, n_got, bad = verify(md, html)
    print(f"写出 {a.out}；代码块 {n_got}/{n_src}，"
          + (f"不一致 {len(bad)} 处：#{bad}" if bad else "全部逐字节保真"), file=sys.stderr)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
