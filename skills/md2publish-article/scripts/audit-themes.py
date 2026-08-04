#!/usr/bin/env python3
"""主题文件的落点审计：找出「声明了但没有高频文字色落点」的强调色。

用法：
    python3 audit-themes.py [主题目录]        # 默认 ../references/theme-prompts

背景见 docs/theme-design-lessons.md。核心问题是：主题文件的「色彩系统」列了一堆颜色，
但组件规范里如果没给它高频落点，生成模型不会自己找地方用掉——声明了却没落点的颜色
等于不存在，产物就会退化成黑白或单色。这个脚本把「凭感觉读主题文件」变成机械检查。

判定分四档：
  DEAD   调色板声明了，组件规范里一次都没出现
  LOW    落点全在低频元素（em / 链接 / 脚注）——中文技术文里这些可能整篇为零
  DECOR  落点全是装饰性的（边框、细线、小符号），没有文字色落点
  OVER   行内 code **无底色**又用强调色当文字色——与 strong 同形同色，读者分不出

OVER 是 2026-08 补的，查的是与前三档相反的方向：落点过载。行内 code 在技术文里有一两百
处，它拿了强调色就吃掉该色三分之二的落点（规则 7）。cyber-neon 实测：280 处青色落点里
193 处是行内 code，strong 同为青色又同样不带底，用户反馈是「区分不出来哪些是行内 code、
哪些是强调的文字」。

**这一档最初写宽了，报了 15 个主题**——全库 17/27 都给行内 code 派了强调色文字。但那 15 个
都带底色，有自己的形状，和 strong 分得开，实测观感可接受。所以判据不是「用没用强调色」，
是「有没有和 strong 撞形」：带底就不报，只有「无底 + 强调色文字」才是真缺陷。
**一个报了大半个库的检查项，通常是判据下宽了，不是库烂了。**

若某个落点经真机确认可接受，在主题文件里写一行豁免注记（HTML 注释，不进渲染）：
    <!-- audit-ok: OVER #3d6a8a 一句话理由 -->
脚本解析注记后会跳过该条，并且在查落点前先剥掉全部 HTML 注释——否则注记里的色值本身
会变成一个假落点，把 DEAD 检查骗过去。

DECOR 这一档是 2026-08 才补的：cyber-neon 的品红有 h3 border-left 落点，前两档都不报警，
但产物里它只以 3px 细线出现 8 次，用户的反馈是「颜色单调」。装饰落点的视觉权重远低于
文字色，不能算数。

脚本报的是**嫌疑**不是结论——背景色天然只出现一两次，属正常，脚本已按角色关键词跳过，
但仍可能有漏网。人工确认后再改主题。

已知限制：脚本分不清「规范」和「说明文字」。主题文件里若写了「原先的 `#171e2e` 只有
1.11:1」这类引用旧色值的注解，脚本会把它当成该色的落点，检查就失效了。这不是靠把脚本
写得更聪明能解决的——**规范里就不该留旧色值**，它同样会误导按规范生成 HTML 的模型
（模型可能真的把旧值用上）。要说明历史，用文字描述，别贴色值。
"""

import re
import sys
from pathlib import Path

# 中文技术文里可能整篇为零的元素——强调色只落在这些上面，产物必然掉色
LOW_FREQ = ("em", "斜体", "链接", "脚注", "作品名", "a 标签")
# 只有被调色板标为「强调」的颜色才需要查落点质量。
# 边线色、代码块底色这类本来就只该出现在装饰上，对它们报 DECOR 是纯噪音。
ACCENT_ROLE = ("强调", "点睛", "accent", "主色")
SKIP = {"INDEX.md", "_common-tech.md"}


def element_of(line):
    """从「- h3：`font-size...`」里取出元素名 h3。取不到就返回整行。

    按元素名判定，而不是拿关键词在整行里搜——否则规范里一句
    「别只挂在 em 上」这样的说明文字，会把该行误判成 em 落点。
    """
    m = re.match(r"^[-*]\s*\*{0,2}([^：:`]{1,24})", line.strip())
    return (m.group(1) if m else line).strip().rstrip("*")


def declared_colors(palette):
    """调色板里真正被「声明」的颜色 → 它那行的角色描述。

    一行只声明一个色，取该行的第一个色值。后面解释里引用的其它色值
    （「`#2a3550` 在新底色上只有 1.27:1」这种）不算声明——否则一句解释
    就会凭空造出一个零落点的死色。
    """
    out = {}
    for line in palette.splitlines():
        if not line.strip().startswith(("-", "*")):
            continue
        m = re.search(r"#[0-9a-fA-F]{6}", line)
        if m and m.group() not in out:
            out[m.group()] = line
    return out


def inline_code_fg(body):
    """行内 code 规范里指定的**文字色**（不是底色）→ (色值, 该行原文)。

    底色和文字色必须分开看：底色用强调色是小面积色块，文字色才会变成上百处斑点。
    两种写法都要认——「底 `#x`、文字 `#y`」和「`background-color: #x; color: #y`」。
    """
    for line in body.splitlines():
        # 必须从「行内 code」这个词往后截再搜。有的主题把代码块和行内 code 写在同一行
        # （autumn-warm），在整行里搜「文字」会先撞上代码块那个色值，行内 code 的就永远查不到。
        i = line.find("行内")
        if i < 0 or "code" not in line[i:i + 12]:
            continue
        line = line[i:]
        # 有底色 = 它有自己的形状，和 strong 分得开，不算过载（全库 15 个主题都是这形态，
        # 2026-08 实测观感可接受）。只有「无底 + 强调色文字」才会与 strong 同形同色。
        if re.search(r"底\s*`?#[0-9a-fA-F]{6}|background-color:\s*#[0-9a-fA-F]{6}", line):
            return None, None
        # 第二个模式必须挡住 `background-color:`——它里面就含 `color:`，不挡的话
        # 取到的永远是底色，文字色查不到了（变异测试抓到的，漏报和误报同一个根因）
        for pat in (r"文字[^#\n]{0,4}`?(#[0-9a-fA-F]{6})",
                    r"(?<![-\w])color:\s*(#[0-9a-fA-F]{6})"):
            m = re.search(pat, line)
            if m:
                return m.group(1), line.strip()
    return None, None


def exemptions(text):
    """`<!-- audit-ok: LEVEL #色值 理由 -->` → {(LEVEL, 色值)}。经真机确认的落点走这里豁免。"""
    return {(lv, c.lower()) for lv, c in
            re.findall(r"<!--\s*audit-ok:\s*([A-Z]+)\s+(#[0-9a-fA-F]{6})", text)}


def audit(path):
    raw = path.read_text(encoding="utf-8")
    exempt = exemptions(raw)
    # 先剥注释再查落点：豁免注记里的色值不能算落点，否则一条注记就能把 DEAD 检查骗过去
    text = re.sub(r"<!--.*?-->", "", raw, flags=re.S)
    start = text.find("## 色彩系统")
    if start < 0:
        return [(path.name, "-", "NOSPEC", "没有「## 色彩系统」段，无法审计")]
    end = text.find("\n## ", start + 5)
    palette, body = text[start:end], text[end:]

    findings = []
    ic_color, ic_line = inline_code_fg(body)
    for color, role in declared_colors(palette).items():
        hits = [l.strip() for l in body.splitlines() if color in l]

        if not hits:
            # 零落点对任何颜色都是问题——包括次级灰这种"声明了就该用"的
            findings.append((path.name, color, "DEAD", role.strip()[:70]))
            continue

        # 只看冒号前的标签，不看后面的解释文字——否则一句
        # 「只当细线用的颜色不能算主强调」会把该色误判成强调色
        label = re.split(r"[：:]", role, 1)[0]
        if not any(k in label for k in ACCENT_ROLE):
            continue  # 非强调色，有落点即可，不查落点质量

        # 只看**文字色**落点。边框、细线这类装饰落点不参与判定——它们视觉权重太低，
        # 一个强调色如果只当边框用，读者根本感觉不到这个颜色存在。
        text_hits = [h for h in hits if re.search(r"color:\s*" + re.escape(color), h)]

        if not text_hits:
            findings.append((path.name, color, "DECOR", hits[0][:70]))
        elif all(any(k in element_of(h) for k in LOW_FREQ) for h in text_hits):
            # 有装饰落点也救不了——文字色只挂在 em/链接上，中文技术文里可能整篇为零
            findings.append((path.name, color, "LOW", text_hits[0][:70]))

        # 反方向：落点过载。行内 code 一篇文里有一两百处，它拿了强调色，
        # 这一个元素就吃掉该色三分之二的落点（规则 7）。
        if ic_color and ic_color.lower() == color.lower():
            findings.append((path.name, color, "OVER", ic_line[:70]))

    # 「改了值没同步」检查。
    #
    # 组件规范里出现调色板没声明的颜色是**正常的**——代码块底、引用块底这些派生色
    # 本来就不都进调色板，单报它们会有几十条噪音，人就不看了。
    #
    # 真正要抓的是这个组合：调色板里有个色零落点（旧值被孤立了）+ 组件里有个没声明的
    # 色（新值）。这正是"改了组件忘了同步调色板"留下的痕迹，一份文件里两个值并存，
    # 生成模型读到哪个算哪个。只在两者同时出现时才报。
    dead = [c for f, c, level, _ in findings if level == "DEAD" and f == path.name]
    if dead:
        declared = set(declared_colors(palette))
        orphans = [c for c in dict.fromkeys(re.findall(r"#[0-9a-fA-F]{6}", body))
                   if c not in declared]
        if orphans:
            findings.append((path.name, "/".join(dead[:2]), "DESYNC",
                             f"调色板有零落点色，组件里有未声明色 {'、'.join(orphans[:3])}"
                             f"——是不是改了值没同步？"))
    return [f for f in findings if (f[2], f[1].lower()) not in exempt]


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else
                Path(__file__).parent.parent / "references" / "theme-prompts")
    files = sorted(f for f in root.glob("*.md") if f.name not in SKIP)
    if not files:
        print(f"没找到主题文件：{root}")
        return 2

    all_findings = [f for p in files for f in audit(p)]
    for name, color, level, evidence in all_findings:
        print(f"{level:6s} {name:22s} {color}\n{'':29s}└ {evidence}")

    print(f"\n审计 {len(files)} 个主题，{len(all_findings)} 条嫌疑"
          f"（DEAD 零落点 / LOW 低频落点 / DECOR 只当装饰 / OVER 行内 code 落点过载 /"
          f" DESYNC 改值没同步）")
    print("逐条人工确认后再改主题——背景色、纯装饰色可能是误报。")
    return 1 if all_findings else 0


if __name__ == "__main__":
    sys.exit(main())
