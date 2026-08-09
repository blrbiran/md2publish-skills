# 全库对比度审计 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给主题库加上第四套机械检查——从产物 HTML 量出每一处文字的真实前景/背景/字号字重，算 WCAG 对比度，用「冻结基线、只挡新增」的方式防住对比度回归。

**Architecture:** 两个新模块：`contrast_lib.py` 提供纯函数原语（颜色解析、alpha 合成、相对亮度、对比度、渐变采样、DOM 祖先链遍历、注入装饰识别），`contrast-themes.py` 是 CLI（按权威配对表读产物、判定、与基线 TSV 比对、报告）。基线存 `references/contrast-baseline.tsv`，只许减不许增。变异测试逐条证死错误实现。

**Tech Stack:** Python 3 标准库（`html.parser`、`re`、`unicodedata`、`json`、`pathlib`），无第三方依赖；shell 变异测试。

## Global Constraints

以下条款来自 spec，**每个任务都隐含包含**，不再逐任务重复：

- **只用标准库。**本仓库现有脚本（`md2html.py`/`theme_lib.py`/`census-themes.py`）零第三方依赖，不许引入。
- **文件集合必须来自 `skills/md2publish-article/scripts/test-md2html.sh` 的 `PAIRS` 表**，**不许 `glob("*.html")`**。`out/` 里混着中间产物（`13-cyber-neon-v7-grid.html` 不在 `PAIRS` 里）。
- **不许静默兜底。**栈不闭合、祖先链上无底色声明、语料缺失——三种情况都要 FAIL 或整体 SKIP 并把退出码标红，不许假设一个值继续算。
- **不许在测试里写死总条数。**首版基数要等 Task 6 首跑才能定；`real-library` 用例比对的是「基线文件的行数」，不是字面量。
- **改动主题文件之前必读 `docs/theme-design-lessons.md`。**本计划不改任何主题文件与 `theme.json`，若执行中发现需要改，停手上报。
- **红线：`git commit` 每一步都写在计划里，但 `git push`、传图、建草稿一律先经用户确认。**
- 术语：**「装饰」= 由 theme.json 那八个注入字段产生的节点**（阈值 3.0）；**「文字」= 其余一切**（阈值 4.5，大文本 3.0）。判据**不是字符类**。

**参考文档：** spec 在 `docs/superpowers/specs/2026-08-10-contrast-audit-design.md`；判据设计的历史教训在 `docs/theme-design-lessons.md` 的「机械审计方法」节；现有同类脚本 `census-themes.py` / `theme_lib.py` / `test-theme-lib.py` / `test-census-themes.sh` 是范式来源。

---

## 文件结构

| 文件 | 责任 | 任务 |
|---|---|---|
| `skills/md2publish-article/scripts/contrast_lib.py` | 纯函数原语：颜色、合成、亮度、对比度、渐变、走链、装饰识别、阈值 | 1–4 |
| `skills/md2publish-article/scripts/test-contrast-lib.py` | 上述原语的单元测试 | 1–4 |
| `skills/md2publish-article/scripts/contrast-themes.py` | CLI：读 `PAIRS`、跑判定、比对基线、报告、`--detail`、`--prune` | 5–6 |
| `skills/md2publish-article/references/contrast-baseline.tsv` | 存量快照（Task 6 首跑生成） | 6 |
| `skills/md2publish-article/scripts/test-contrast-themes.sh` | 变异测试：逐条证死错误实现 | 7 |
| `docs/handoff/handoff.md`、`docs/theme-design-lessons.md` | 回写基线第 8 条与新判据教训 | 8 |

`contrast_lib.py` 与 `theme_lib.py` **分开**：后者读 theme.json，前者读产物 DOM，输入与职责都不重叠。

---

## Task 1: 颜色原语与对比度

**Files:**
- Create: `skills/md2publish-article/scripts/contrast_lib.py`
- Create: `skills/md2publish-article/scripts/test-contrast-lib.py`

**Interfaces:**
- Consumes: 无
- Produces:
  - `parse_color(s: str) -> tuple[int,int,int,float] | None` —— 认 `#rgb`/`#rrggbb`/`rgb(...)`/`rgba(...)`/`transparent`，返回 `(r, g, b, alpha)`；认不出返回 `None`
  - `composite(top: tuple[int,int,int,float], bottom: tuple[int,int,int]) -> tuple[int,int,int]` —— `c = α·上 + (1−α)·下`，四舍五入取整
  - `relative_luminance(rgb: tuple[int,int,int]) -> float`
  - `contrast_ratio(fg: tuple[int,int,int], bg: tuple[int,int,int]) -> float`

- [ ] **Step 1: 写会失败的测试**

新建 `test-contrast-lib.py`。测试骨架照 `test-theme-lib.py` 的现有范式（逐条打印 `ok   <名字>`，累计失败数，末尾打印 `ok：N 条失败` 并按失败数决定退出码）——**先打开 `test-theme-lib.py` 读一遍它的 harness 写法，照抄结构**，再填下面的用例。

```python
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
```

> **为什么锚点选这七对**：`3.39`/`2.58`/`8.39`/`5.57`/`3.55` 是本项目在批次 2、3 里**人手量出来并写进 handoff 的数**，`1.45` 是本轮探针量的 celadon 饰线。用它们当锚点等于同时校验「新实现与当年人手算的是同一套公式」——一个只测自己的实现无法发现的错误。

- [ ] **Step 2: 跑测试确认它红，且红在预期原因上**

```bash
cd ~/code/skills/writing/md2publish-skills
python3 skills/md2publish-article/scripts/test-contrast-lib.py
```

Expected: `ModuleNotFoundError: No module named 'contrast_lib'`（不是别的错——若报别的错说明测试文件本身写错了，先修测试）

- [ ] **Step 3: 写最小实现**

新建 `contrast_lib.py`：

```python
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
```

- [ ] **Step 4: 跑测试确认全绿**

```bash
python3 skills/md2publish-article/scripts/test-contrast-lib.py
```
Expected: 每条 `ok`，末尾 `ok：0 条失败`，退出码 0

- [ ] **Step 5: 提交**

```bash
git add skills/md2publish-article/scripts/contrast_lib.py \
        skills/md2publish-article/scripts/test-contrast-lib.py
git commit -m "对比度原语：颜色解析、alpha 合成、WCAG 亮度与对比度

锚点值取自项目历史人手量过的真实色对（terracotta 五对 + celadon 饰线），
等于同时校验新实现与当年人手算的是同一套公式。"
```

---

## Task 2: 渐变最差底（沿渐变采样，不取端点）

**Files:**
- Modify: `skills/md2publish-article/scripts/contrast_lib.py`
- Modify: `skills/md2publish-article/scripts/test-contrast-lib.py`

**Interfaces:**
- Consumes: Task 1 的 `parse_color` / `composite` / `contrast_ratio`
- Produces:
  - `gradient_stops(css_value: str) -> list[tuple[int,int,int,float]]` —— 从 `linear-gradient(...)`/`radial-gradient(...)` 里按出现顺序抽色标；没有 gradient 关键字返回 `[]`
  - `backdrop_samples(bg_color, image_value, parent_samples) -> list[tuple[int,int,int]]` —— 返回该元素的**有效底候选集**（不透明 RGB 列表，长度 ≥ 1）
  - `worst_contrast(fg: tuple[int,int,int], samples: list) -> float` —— 对候选集取最差

**为什么必须采样：** 相对亮度 `L` 是各通道 `f(v)` 的加权和，`f` 在 sRGB 上凸增（且在 0.03928 拐点处左右导数都是 0.0774，C¹），渐变逐通道线性插值，所以 `L(t)` 对 `t` 凸。**凸函数最大值在端点，最小值可能在内部**——前景比整条渐变都暗时最差点会落在中间；前景亮度夹在两端之间时由介值定理必有一点等亮、最差值就是 1.0。分类讨论容易写错，采样一次全覆盖。

- [ ] **Step 1: 写会失败的测试**

追加到 `test-contrast-lib.py`（放在 `print(f"\nok：...")` 之前）：

```python
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
```

- [ ] **Step 2: 跑测试确认它红**

```bash
python3 skills/md2publish-article/scripts/test-contrast-lib.py
```
Expected: 前面 Task 1 的用例仍 `ok`，新增用例报 `AttributeError: module 'contrast_lib' has no attribute 'gradient_stops'`

- [ ] **Step 3: 写最小实现**

追加到 `contrast_lib.py`：

```python
_COLOR_TOKEN = re.compile(r"#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b|rgba?\([^)]*\)|\btransparent\b")

#: 沿渐变采样的步数。101 = 每 1% 一个采样点。
#: 不许改成只取两端——L(t) 是凸的，最小值可能落在内部（见本文件顶部 spec 链接）。
GRADIENT_SAMPLES = 101


def gradient_stops(css_value):
    """从 gradient 声明里按出现顺序抽色标；非渐变返回 []。"""
    if not css_value or "gradient" not in css_value:
        return []
    out = []
    for tok in _COLOR_TOKEN.findall(css_value):
        c = parse_color(tok)
        if c is not None:
            out.append(c)
    return out


def backdrop_samples(bg_color, image_value, parent_samples):
    """该元素的有效底候选集（不透明 RGB 列表）。

    background-color 打底（不透明则盖住父级），再把 background-image 的色标
    按 alpha 合成上去。渐变的两个相邻色标之间沿途采样——L(t) 凸，最小值可能在内部。
    """
    base = list(parent_samples)
    c = parse_color(bg_color) if bg_color else None
    if c is not None and c[3] > 0:
        base = [composite(c, b) for b in base] if c[3] < 1 else [c[:3]]

    stops = gradient_stops(image_value)
    if not stops:
        return base

    out = list(base)
    for b in base:
        solid = [composite(s, b) for s in stops]
        for i in range(len(solid) - 1):
            p, q = solid[i], solid[i + 1]
            for k in range(GRADIENT_SAMPLES):
                t = k / (GRADIENT_SAMPLES - 1)
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
```

- [ ] **Step 4: 跑测试确认全绿**

```bash
python3 skills/md2publish-article/scripts/test-contrast-lib.py
```
Expected: `ok：0 条失败`

- [ ] **Step 5: 定点破坏，确认这张网有牙齿**

把 `GRADIENT_SAMPLES` 临时改成 `2`（等于只取端点），重跑：

```bash
python3 skills/md2publish-article/scripts/test-contrast-lib.py
```
Expected: **恰好两条红**——「最差点在内部」（会给出 2.4440）与「夹在两端之间」（会给出 3.9494）；aurora-flow 那条仍绿（它的最差点本来就在端点）。确认后改回 `101`，重跑到全绿。

> 这一步不是可选的。判据的正确性只能靠「错误实现会被抓住」来证明，不能靠「正确实现通过了」。

- [ ] **Step 6: 提交**

```bash
git add skills/md2publish-article/scripts/contrast_lib.py \
        skills/md2publish-article/scripts/test-contrast-lib.py
git commit -m "渐变底：沿渐变采样取最差，不取端点

L(t) 对 t 是凸的（sRGB 传递函数凸增且 C1），凸函数最小值可能落在内部；
前景亮度夹在两端之间时由介值定理最差值是 1.0。两种情况端点法都会漏判，
已用 GRADIENT_SAMPLES=2 定点破坏验证这两条用例会红。"
```

---

## Task 3: 走 DOM 祖先链

**Files:**
- Modify: `skills/md2publish-article/scripts/contrast_lib.py`
- Modify: `skills/md2publish-article/scripts/test-contrast-lib.py`

**Interfaces:**
- Consumes: Task 2 的 `backdrop_samples`
- Produces:
  - `Node` —— `collections.namedtuple("Node", "tag fg samples size weight text style own_bg")`
    - `fg`: `(r,g,b)`；`samples`: 有效底候选集；`size`: float(px)；`weight`: int；`style`: 该节点自己的 `style` 属性原文（Task 4 用它认装饰）；`own_bg`: 该节点自己声明的 `background-color`（`(r,g,b)` 或 `None`，Task 5 的同色块规则用）
  - `walk(html: str) -> list[Node]` —— 遍历产物，返回所有非空文本节点。**栈没回到根、或某个文本节点的底候选集为空 → 抛 `ContrastWalkError`**
  - `ContrastWalkError(Exception)`

**继承规则：** `color` / `font-size` / `font-weight` 继承，子元素声明则覆盖，根默认 `16px` / `400`。有效底 = 最近一个声明了底的祖先（由 `backdrop_samples` 逐层累积）。

- [ ] **Step 1: 写会失败的测试**

追加到 `test-contrast-lib.py`：

```python
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
```

- [ ] **Step 2: 跑测试确认它红**

Run: `python3 skills/md2publish-article/scripts/test-contrast-lib.py`
Expected: 新增用例报 `AttributeError: module 'contrast_lib' has no attribute 'walk'`

- [ ] **Step 3: 写最小实现**

追加到 `contrast_lib.py`：

```python
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
```

- [ ] **Step 4: 跑测试确认全绿**

Run: `python3 skills/md2publish-article/scripts/test-contrast-lib.py`
Expected: `ok：0 条失败`

- [ ] **Step 5: 对真实产物跑一遍，确认 26 份都能走通**

```bash
cd ~/code/skills/writing/md2publish-skills
python3 - <<'EOF'
import re, sys
sys.path.insert(0, "skills/md2publish-article/scripts")
import contrast_lib as CL
from pathlib import Path
sh = Path("skills/md2publish-article/scripts/test-md2html.sh").read_text()
pairs = [l.strip().split(":") for l in
         re.search(r'PAIRS="\n(.*?)\n"', sh, re.S).group(1).strip().splitlines() if l.strip()]
out = Path.home() / "code/skills/writing/wechat_test/litellm-multi-provider-gateway/out"
total = 0
for _, h in pairs:
    nodes = CL.walk((out / f"{h}.html").read_text(encoding="utf-8"))
    total += len(nodes)
print(f"{len(pairs)} 份产物全部走通，共 {total} 个文本节点")
EOF
```
Expected: `26 份产物全部走通，共 <N> 个文本节点`，无异常。**若抛 `ContrastWalkError`，不要改脚本迁就它——先看那份产物到底长什么样，那是真发现。**

- [ ] **Step 6: 提交**

```bash
git add skills/md2publish-article/scripts/contrast_lib.py \
        skills/md2publish-article/scripts/test-contrast-lib.py
git commit -m "走 DOM 祖先链：算每个文本节点的真实前景/底/字号字重

栈不闭合、祖先链无底色声明两种情况都抛 ContrastWalkError 而不是兜底，
静默兜底会让量出来的全是编造的数字。26 份真实产物已实测全部走通。"
```

---

## Task 4: 注入装饰识别（按来源判，不按字符类判）

**Files:**
- Modify: `skills/md2publish-article/scripts/contrast_lib.py`
- Modify: `skills/md2publish-article/scripts/test-contrast-lib.py`

**Interfaces:**
- Consumes: Task 3 的 `Node`（用它的 `style` 与 `text` 字段）
- Produces:
  - `DECOR_FIELDS: tuple[str, ...]` —— 八个注入字段名
  - `decor_signatures(theme: dict) -> tuple[frozenset[str], frozenset[str]]` —— `(样式串集合, 字面文本集合)`
  - `is_decor(node: Node, sigs) -> bool`

**判据不是字符类。** 「文本里没有字母/数字/CJK 就算装饰」这条是**错的**：代码块里的 `{`、`|---|`、`---` 全是纯符号，会被误放宽到 3:1，而代码里的符号是要读的。按注入来源判是机械事实、可逐条核——正是 lessons 从 `REF_EXCLUDE` 那次学到的教训（**按挂载来源判，不按词表/字符类判**）。

匹配走两条路：优先按「节点的 `style` 属性精确等于该字段内联样式串」；字段里没有 `style` 的，退回按字段的字面文本匹配。

- [ ] **Step 1: 写会失败的测试**

追加到 `test-contrast-lib.py`：

```python
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
```

- [ ] **Step 2: 跑测试确认它红**

Run: `python3 skills/md2publish-article/scripts/test-contrast-lib.py`
Expected: `AttributeError: module 'contrast_lib' has no attribute 'decor_signatures'`

- [ ] **Step 3: 写最小实现**

追加到 `contrast_lib.py`：

```python
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
                # 没有 style 的字段（如纯文本 list_prefix_ol_html）走字面文本
                plain = _TAGS.sub("", item).replace("&nbsp;", " ").strip()
                # `{n}` 是序号占位，认前后两半
                for piece in plain.split("{n}"):
                    piece = piece.strip()
                    if piece:
                        texts.add(piece)
    return frozenset(styles), frozenset(texts)


def is_decor(node, sigs):
    """该文本节点是不是由 theme.json 的注入字段产生的装饰。"""
    styles, texts = sigs
    if _norm_style(node.style) in styles and _norm_style(node.style):
        return True
    t = node.text.strip()
    return any(t == x or t.rstrip(".").rstrip() == x.rstrip(".").rstrip() for x in texts)
```

- [ ] **Step 4: 跑测试确认全绿**

Run: `python3 skills/md2publish-article/scripts/test-contrast-lib.py`
Expected: `ok：0 条失败`

- [ ] **Step 5: 提交**

```bash
git add skills/md2publish-article/scripts/contrast_lib.py \
        skills/md2publish-article/scripts/test-contrast-lib.py
git commit -m "装饰识别：按 theme.json 注入字段判，不按字符类判

字符类判据（没有字母/数字/CJK 就算装饰）会把代码块里的 |---| 和 { 误放宽到 3:1，
而代码里的符号是要读的。用例里钉住了这两个反例。"
```

---

## Task 5: 判定规则与发现生成

**Files:**
- Modify: `skills/md2publish-article/scripts/contrast_lib.py`
- Modify: `skills/md2publish-article/scripts/test-contrast-lib.py`

**Interfaces:**
- Consumes: Task 3 的 `Node`、Task 4 的 `is_decor`
- Produces:
  - `is_large_text(size: float, weight: int) -> bool`
  - `threshold(is_decor_flag: bool, size: float, weight: int) -> float`
  - `Finding` —— `namedtuple("Finding", "theme tag fg bg size weight kind ratio sample count")`
  - `findings_for(theme_name: str, html: str, theme: dict) -> list[Finding]` —— 一份产物的全部不达标发现，**同键合并计数**

**同色块规则：** 节点自带 `background-color` 且前景色等于它 → 是色块不是字（bauhaus-pop 的 `■`）。**只对 `is_decor` 认定的注入装饰生效**——否则主题真把正文写成和底同色（真缺陷）也会被静默吃掉。

- [ ] **Step 1: 写会失败的测试**

追加到 `test-contrast-lib.py`：

```python
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
```

- [ ] **Step 2: 跑测试确认它红**

Run: `python3 skills/md2publish-article/scripts/test-contrast-lib.py`
Expected: `AttributeError: module 'contrast_lib' has no attribute 'is_large_text'`

- [ ] **Step 3: 写最小实现**

追加到 `contrast_lib.py`：

```python
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
```

- [ ] **Step 4: 跑测试确认全绿**

Run: `python3 skills/md2publish-article/scripts/test-contrast-lib.py`
Expected: `ok：0 条失败`

- [ ] **Step 5: 提交**

```bash
git add skills/md2publish-article/scripts/contrast_lib.py \
        skills/md2publish-article/scripts/test-contrast-lib.py
git commit -m "判定规则：大文本豁免、装饰 3:1、同色块跳过、同键合并计数

同色块规则只对注入装饰生效——否则主题真把正文写成和底同色也会被静默吃掉，
用例里钉住了这个反例。"
```

---

## Task 6: CLI、权威配对表、基线首跑

**Files:**
- Create: `skills/md2publish-article/scripts/contrast-themes.py`
- Create: `skills/md2publish-article/references/contrast-baseline.tsv`

**Interfaces:**
- Consumes: Task 5 的 `findings_for`、`Finding`
- Produces: 可执行 CLI。退出码：0 = 无新增；1 = 有新增或走链失败；2 = 语料缺失（SKIP，标红）

**基线键**：`主题 ⇥ 元素标签 ⇥ 前景 ⇥ 底 ⇥ 字号 ⇥ 字重 ⇥ 装饰|文字`。**不含出现次数、不含样本文字**（次数随文章长短变）。**比值单独存一列，只作参考、不参与比对**（避免浮点尾数抖动误报）。

- [ ] **Step 1: 写脚本**

```python
#!/usr/bin/env python3
"""产物对比度普查：量出每一处文字的真实对比度，与冻结基线比对。

设计与判据理由见 docs/superpowers/specs/2026-08-10-contrast-audit-design.md。

它回答的问题是「落下来的东西读不读得清」，与 census-themes.py 的
「声明的色有没有落点」不重叠，两套基线各认各的、不要混。

用法：
    python3 contrast-themes.py                 # 与基线比对，只在有新增时 exit 1
    python3 contrast-themes.py --detail 19-candy-pop   # 单主题详表
    python3 contrast-themes.py --write-baseline        # 首跑：生成基线
    python3 contrast-themes.py --prune                 # 删掉产物里已不存在的基线行
"""
import argparse
import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import contrast_lib as CL

SCRIPT_DIR = Path(__file__).resolve().parent
THEME_JSON_DIR = SCRIPT_DIR / ".." / "references" / "theme-json"
BASELINE = SCRIPT_DIR / ".." / "references" / "contrast-baseline.tsv"
CORPUS = Path(os.environ.get(
    "MD2HTML_CORPUS",
    Path.home() / "code/skills/writing/wechat_test/litellm-multi-provider-gateway"))

HEADER = ["主题", "元素", "前景", "底", "字号", "字重", "类", "比值(参考)", "处数(参考)"]
KEY_COLS = 7   # 前 7 列是键；后两列只作参考，不参与比对


def authoritative_pairs():
    """从 test-md2html.sh 的 PAIRS 表取权威配对。

    绝不 glob('*.html')——out/ 里混着中间产物（13-cyber-neon-v7-grid 不在配对表里），
    按文件名循环会把它算成第 27 个主题。handoff §4 用黑体写过这条。
    """
    sh = (SCRIPT_DIR / "test-md2html.sh").read_text(encoding="utf-8")
    m = re.search(r'PAIRS="\n(.*?)\n"', sh, re.S)
    if not m:
        sys.exit("FAIL：test-md2html.sh 里找不到 PAIRS 表——它是权威配对关系，不能绕过")
    return [tuple(l.strip().split(":")) for l in m.group(1).strip().splitlines() if l.strip()]


def collect():
    pairs = authoritative_pairs()
    outdir = CORPUS / "out"
    if not outdir.is_dir():
        print(f"SKIP 对比度普查：语料不在 {CORPUS}")
        print("     这不是通过。设 MD2HTML_CORPUS 指向实验目录再跑，否则改动没有护栏。")
        sys.exit(2)
    rows = []
    for j, h in pairs:
        tj, html = THEME_JSON_DIR / f"{j}.theme.json", outdir / f"{h}.html"
        if not tj.is_file() or not html.is_file():
            print(f"SKIP 对比度普查：{j} 缺文件（{tj.name} 或 {html.name}）")
            sys.exit(2)
        theme = json.loads(tj.read_text(encoding="utf-8"))
        try:
            rows.extend(CL.findings_for(j, html.read_text(encoding="utf-8"), theme))
        except CL.ContrastWalkError as e:
            sys.exit(f"FAIL {j}：{e}")
    return rows


def key_of(f):
    return (f.theme, f.tag, f.fg, f.bg, f"{f.size:g}", str(f.weight), f.kind)


def row_of(f):
    return list(key_of(f)) + [f"{f.ratio:.2f}", str(f.count)]


def read_baseline():
    if not BASELINE.is_file():
        return {}
    out = {}
    for line in BASELINE.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        cols = line.split("\t")
        if cols[:KEY_COLS] == HEADER[:KEY_COLS]:
            continue
        out[tuple(cols[:KEY_COLS])] = cols
    return out


def write_baseline(findings):
    lines = [
        "# 对比度审计基线：已知、未处置的存量。含义不是「可接受」，只是「还没排到」。",
        "# 判定为可以永远这样的走主题 .md 里的 <!-- contrast-ok: ... --> 注记，两者不许混。",
        "# 只许减、不许增——脚本管不了这条，唯一护栏是人读这份文件的 diff。",
        "# 前 7 列是键；比值与处数只作参考，不参与比对。",
        "\t".join(HEADER),
    ]
    lines += ["\t".join(row_of(f)) for f in
              sorted(findings, key=lambda f: (f.theme, f.tag, f.fg, f.bg))]
    BASELINE.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--detail", metavar="主题")
    ap.add_argument("--write-baseline", action="store_true")
    ap.add_argument("--prune", action="store_true")
    args = ap.parse_args()

    findings = collect()

    if args.detail:
        sel = [f for f in findings if f.theme == args.detail]
        print("\t".join(HEADER))
        for f in sorted(sel, key=lambda f: f.ratio):
            print("\t".join(row_of(f)))
        print(f"\n{args.detail}：{len(sel)} 条")
        return 0

    if args.write_baseline:
        write_baseline(findings)
        print(f"已写入基线 {BASELINE}：{len(findings)} 条")
        return 0

    base = read_baseline()
    seen = {key_of(f): f for f in findings}
    new = [f for k, f in seen.items() if k not in base]
    stale = [k for k in base if k not in seen]

    if args.prune:
        write_baseline([f for f in findings if key_of(f) in base or key_of(f) in seen])
        print(f"已清理 {len(stale)} 条产物里已不存在的基线行")
        return 0

    print(f"\n对比度普查：{len(findings)} 条不达标，基线 {len(base)} 条")
    if stale:
        print(f"\n{len(stale)} 条基线行在产物里已不存在（不算失败；确认是修好了或换了语料，"
              f"再跑 --prune 清理）：")
        for k in sorted(stale)[:20]:
            print("  stale  " + "  ".join(k))
        if len(stale) > 20:
            print(f"  …… 另有 {len(stale) - 20} 条")
    if new:
        print(f"\n{len(new)} 条基线里没有的新组合：")
        print("  " + "\t".join(HEADER))
        for f in sorted(new, key=lambda f: f.ratio):
            print("  " + "\t".join(row_of(f)))
        print("\n基线只许减、不许增。要么修掉它，要么在主题 .md 里写 contrast-ok 注记"
              "并说明理由——不要直接往 .tsv 里加行。")
        return 1
    print("\n无新增，基线一致")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: 首跑，把真实基数定下来**

```bash
cd ~/code/skills/writing/md2publish-skills
python3 skills/md2publish-article/scripts/contrast-themes.py --write-baseline
wc -l skills/md2publish-article/references/contrast-baseline.tsv
```

Expected: `已写入基线 …：<N> 条`。**`N` 就是真实基数——spec §1 里的 113 是探针口径的下限，真值预期在 113–156 之间（探针有 43 条被字符类规则误放宽的组合要重新分类）。把量到的 `N` 记下来，Task 8 要回写。**

若 `N` 落在 113–156 之外，**停手上报**，不要调判据去凑区间——区间是估计，判据才是设计。

- [ ] **Step 3: 空跑一次确认基线自洽**

```bash
python3 skills/md2publish-article/scripts/contrast-themes.py; echo "exit=$?"
```
Expected: `无新增，基线一致`，`exit=0`

- [ ] **Step 4: 抽查一个主题的详表，人眼核一条**

```bash
python3 skills/md2publish-article/scripts/contrast-themes.py --detail 23-terracotta-sun
```
Expected: 表里应当能看到 `#c2593b` / `#efe0cd` / `strong` 那条，比值 **3.39**。这个数是批次 2 人手量出来并写进 handoff 的——**对上了才说明这套机械实现和当年的人量的是同一件事**。对不上就停手查，不要往下走。

- [ ] **Step 5: 提交**

```bash
git add skills/md2publish-article/scripts/contrast-themes.py \
        skills/md2publish-article/references/contrast-baseline.tsv
git commit -m "对比度普查 CLI 与基线首版

文件集合走 test-md2html.sh 的 PAIRS 权威配对，不 glob——out/ 里混着
不在配对表里的中间产物。基线只挡新增，存量列出不阻塞。
terracotta-sun 的 strong 3.39 与批次 2 人手量的数字吻合。"
```

---

## Task 7: 变异测试——逐条证死错误实现

**Files:**
- Create: `skills/md2publish-article/scripts/test-contrast-themes.sh`

**Interfaces:**
- Consumes: Task 6 的 CLI、Task 1–5 的原语
- Produces: 可执行测试脚本，全绿时 exit 0

**纪律：**`test-census-themes.sh` 的教训是——**一条用例如果在错误实现下也是绿的，它就没有价值**。每条用例都要先把对应的错误实现写出来、看着它红，再写正确实现。

- [ ] **Step 1: 写测试脚本**

结构照 `test-census-themes.sh`：临时目录造 fixture（一份最小 HTML + 一份最小 theme.json），跑判定，比对期望。**先打开 `test-census-themes.sh` 读一遍它怎么造 fixture、怎么打印 `ok`/`bad`、怎么统计**，照它的结构写。

必须包含这些用例：

| 用例名 | 要证死的错误实现 | fixture 与期望 |
|---|---|---|
| `gradient-interior-min` | 渐变只取端点 | `linear-gradient(#ff0000, #0000ff)` + 黑字。期望比值 **1.95**；端点法会给 **2.44** |
| `gradient-fg-between` | 渐变只取端点 | `linear-gradient(#000000, #ffffff)` + `#808080` 字。期望比值 **1.00**；端点法会给 **3.95** |
| `alpha-composite` | 忘了 alpha 合成 | 白底 + `linear-gradient(transparent 62%, rgba(176,142,138,0.35) 62%)` + `#8c8884` 15px 字。期望比值 **2.51**；不合成会给 **3.52** |
| `large-text-1866` | 阈值写成 `>18.66px` | 18.66px/700、比值 3.2。期望**不报**（是大文本，阈值 3.0）|
| `large-text-182` | 阈值写成 `>18px` | 18.2px/700、比值 3.2。期望**报**（不是大文本，阈值 4.5）。**只放 18.66 那条抓不住 `>18px`——那个错误实现下 18.66 照样算大文本，mutant 活着** |
| `decor-by-source` | 装饰改用字符类判 | theme.json 里 `list_prefix_html` 是 `<span style="color: #c2593b;">●</span>`，产物里既有那个 `●`（比值 3.2，期望**不报**）又有代码块里的 `|---|`（同色同底同字号，期望**报**）|
| `samecolor-decor-skipped` | 同色块规则没实现 | `h2_prefix_html` 注入的 `<span style="background-color:#f0a500;color:#f0a500;">■</span>`。期望**不报** |
| `samecolor-prose-still-fires` | 同色块规则放宽到非装饰 | `<p style="background-color:#eeeeee;color:#eeeeee">`。期望**报** |
| `walk-unclosed` | 栈不闭合时继续算 | 缺 `</p>` 的 HTML。期望 **FAIL 并退出非 0**，不许出数字 |
| `walk-nobg` | 无底色祖先默默按白算 | 最外层不带 `background-color`。期望 **FAIL 并退出非 0** |
| `baseline-key-has-tag` | 基线键漏掉元素标签 | 同主题、同色、同底、同字号字重但分属 `th` 与 `strong`。期望**两行**，不许塌成一行 |
| `baseline-ratio-not-in-key` | 基线比对把比值算进键 | 基线行的比值列改一位小数、键不变。期望**不报新增** |
| `pairs-not-glob` | 用 `glob("*.html")` 取文件 | 语料目录里多放一份不在 `PAIRS` 里的 HTML（形态照 `13-cyber-neon-v7-grid`）。期望**条数不变** |
| `corpus-missing` | 语料缺失时静默跳过 | `MD2HTML_CORPUS` 指向不存在的目录。期望打印 SKIP 且**退出码非 0** |
| `real-library` | —— | 对真实库跑一遍，条数必须**与基线文件的行数一致**。**不许写死数字**——首版基数由 Task 6 首跑决定，写死一个来自探针的数会让这条测试变成「测探针」而不是「测实现」|

- [ ] **Step 2: 逐条做定点破坏，确认每条都有牙齿**

对每一条用例，把 `contrast_lib.py` 里对应的实现临时改成表格第二列描述的错误形态，跑：

```bash
bash skills/md2publish-article/scripts/test-contrast-themes.sh
```

Expected: **该条用例红，且只有它（以及与它同源的那几条）红**。若某条错误实现下测试全绿，说明那条用例没有牙齿，**要么改 fixture 要么删掉它**——留一条抓不住任何东西的用例比没有更坏，它会让人以为那一层有护栏。

改完全部改回，跑到全绿。

- [ ] **Step 3: 跑全套确认绿**

```bash
bash skills/md2publish-article/scripts/test-contrast-themes.sh; echo "exit=$?"
python3 skills/md2publish-article/scripts/test-contrast-lib.py; echo "exit=$?"
```
Expected: 两条都 0 失败、exit 0

- [ ] **Step 4: 提交**

```bash
git add skills/md2publish-article/scripts/test-contrast-themes.sh
git commit -m "对比度普查的变异测试：15 条，逐条证死错误实现

每条都做过定点破坏验证有牙齿。real-library 比对基线文件行数而不是写死数字——
写死一个来自探针的数会让这条测试变成测探针。"
```

---

## Task 8: 接入基线、回写 handoff 与 lessons

**Files:**
- Modify: `docs/handoff/handoff.md`（第三节加第 8 条基线；第六节加这一轮的状态）
- Modify: `docs/theme-design-lessons.md`（「机械审计方法」节）

**Interfaces:**
- Consumes: Task 6 首跑得到的真实基数 `N`
- Produces: 文档，无代码接口

- [ ] **Step 1: 跑全部基线，拿到当前真实数字**

```bash
cd ~/code/skills/writing/md2publish-skills
python3 skills/md2publish-article/scripts/audit-themes.py
bash skills/md2publish-article/scripts/test-audit-themes.sh | tail -2
bash skills/md2publish-article/scripts/test-md2html.sh | tail -2
bash skills/md2publish-article/scripts/test-census-themes.sh | tail -2
python3 skills/md2publish-article/scripts/census-themes.py | tail -2
python3 skills/md2publish-article/scripts/test-theme-lib.py | tail -2
python3 skills/md2publish-article/scripts/test-contrast-lib.py | tail -2
bash skills/md2publish-article/scripts/test-contrast-themes.sh | tail -2
python3 skills/md2publish-article/scripts/contrast-themes.py | tail -2
```
Expected: 前七条与本轮开工时一致（0 条 / 16 / 25 / 71 / 0 条+8 豁免 / 17 / 新增两条全绿），最后一条 `无新增，基线一致`。**把实际数字抄下来，下一步照抄，不要凭记忆写。**

- [ ] **Step 2: 在 handoff 第三节加第 8、9 条基线**

在现有第 7 条（`test-theme-lib.py`）之后追加：

```markdown
# 8. contrast_lib.py 原语的单元测试，要 0 条失败
python3 skills/md2publish-article/scripts/test-contrast-lib.py

# 9. 对比度普查的变异测试 + 对真实库跑一遍
bash skills/md2publish-article/scripts/test-contrast-themes.sh
python3 skills/md2publish-article/scripts/contrast-themes.py
```

并在第 6 条那段说明之后补一段（**把 `<N>` 换成 Step 1 抄下来的真实数字**）：

> 第 9 条**不是「要 0 条」的基线，是「不许新增」的基线**：`contrast-themes.py` 目前对真实库
> 报 `<N>` 条不达标、全部已冻结进 `references/contrast-baseline.tsv`，exit 0。
> **存量不阻塞，`exit 1` 只在出现基线里没有的新组合时。**修好一条就从 `.tsv` 里删一行，
> **只许减、不许增**——这条纪律脚本管不了（往 `.tsv` 里追加一行就能让新发现消声且 exit 0），
> **唯一护栏是人读那份文件的 diff**。
>
> 它与第 6 条的普查**回答的是两个不同的问题**，两个数字不要混：census 问「主题文件声明的色
> 在产物里有没有落点」，contrast 问「落下来的东西读不读得清」。census 报 0 条**不等于**
> 主题库的对比度成立——本轮实测 26 个主题里有 <M> 个存在不达标组合，而普查从头到尾一声不吭。

- [ ] **Step 3: 在 handoff 第六节加这一轮的状态**

在第六节「剩下的活」里，把第 2 条「待真机观感定夺」之前插入一条新的第 2 条（原第 2–5 条顺延），内容包括：本轮建立了对比度护栏、真实基数 `N`、存量按「冻基线」处理未动任何主题文件、以及处置这批存量与 census 那 43 条性质的区别（几乎每条都要动配色、都会改产物、都含审美判断，candy-pop / washi-spring / morandi-fog 是整套配色系统性偏浅）。

同时**更新第 1 条 1.5 末尾那条「一条待核的线索」**：那四处疑似对比度问题现在已经被机械覆盖，改写成指向 `contrast-baseline.tsv`，并写明「没有做过全库对比度审计」这句话**已经不成立了**。

- [ ] **Step 4: 在 lessons 的「机械审计方法」节加这一轮的判据教训**

至少写进这四条（每条都是本轮真实踩过或差点踩的）：

1. **按挂载来源判，不按字符类判。**「文本里没有字母/数字/CJK 就算装饰」会把代码块里的 `{`、`|---|` 误放宽到图形阈值，而代码里的符号是要读的。这与 `REF_EXCLUDE` 那次是同一个形状的错误，只是词表换成了字符类。
2. **凸性：渐变最差点可能在内部。**相对亮度对渐变参数是凸的，凸函数最小值可能落在内部；前景亮度夹在两端之间时最差值直接是 1.0。只取端点会漏判，实测两个反例分别是 1.95 vs 2.44、1.00 vs 3.95。
3. **别按文件名循环。**本轮探针用 `glob("*.html")`，把不在 `PAIRS` 里的 `13-cyber-neon-v7-grid` 算成第 27 个主题，导致第一版数字（114 / 19 个主题）整体偏高。handoff §4 早就用黑体写过这条，照样踩了——**写过的纪律不等于会被执行，得让脚本自己拿权威表**。
4. **不要把探针口径的数字写进文档当事实。**本轮 spec 初稿把探针算的 113 当成基线大小和验收值，而探针用的装饰判据正是 spec 自己否掉的那条。**一个数字要进文档，得是最终判据算出来的。**

- [ ] **Step 5: 完整读一遍 diff**

```bash
git diff
```

按第五节第 16 条：**提交前把 diff 完整读一遍。**特别核对第 2 步里所有替换进去的数字是不是 Step 1 抄下来的真实值，而不是本计划里的示例值。

- [ ] **Step 6: 提交**

```bash
git add docs/handoff/handoff.md docs/theme-design-lessons.md
git commit -m "对比度护栏进基线第 8-9 条；lessons 补四条判据教训

handoff 1.5 那句「没有做过全库对比度审计」已不成立，改写指向基线文件。
lessons 记下按字符类判、渐变只取端点、按文件名循环、拿探针数字当事实四条。"
```

---

## Self-Review

**Spec 覆盖核对：**

| spec 条款 | 落在哪个任务 |
|---|---|
| §3 数产物、不推 theme.json | Task 3 走链 |
| §3 必须走 `PAIRS`、不许 glob | Task 6 `authoritative_pairs()`；Task 7 `pairs-not-glob` |
| §4.1 继承规则、有效底 | Task 3 |
| §4.1 栈必须闭合、无底色 FAIL | Task 3 Step 1/3；Task 7 `walk-unclosed`/`walk-nobg` |
| §4.2 alpha 合成、渐变采样 | Task 2；Task 7 `alpha-composite`/两条 gradient |
| §4.3 规则 1 大文本 | Task 5；Task 7 两条 `large-text-*` |
| §4.3 规则 2 装饰按注入字段 | Task 4；Task 7 `decor-by-source` |
| §4.3 规则 3 同色块只对装饰 | Task 5；Task 7 两条 `samecolor-*` |
| §4.3 规则 4 代码面进网 | 无需专门实现——走链不区分 `<pre>`，Task 7 的 `decor-by-source` 用 `\|---\|` 反向钉住 |
| §5 基线键含元素标签、不含次数 | Task 6 `key_of`；Task 7 `baseline-key-has-tag` |
| §5 比值不参与比对 | Task 6 `KEY_COLS`；Task 7 `baseline-ratio-not-in-key` |
| §5 exit 1 只在新增 | Task 6 `main()` |
| §5 stale 不 fail、`--prune` | Task 6 |
| §5 只许减不许增靠人读 diff | Task 6 基线文件头注释；Task 8 Step 2 写进 handoff |
| §5 `contrast-ok` 注记 | **本计划不实现**——见下方「本计划刻意不做」 |
| §6 五个文件 | Task 1–7 |
| §6 `--detail` 而非 `--counts` | Task 6 |
| §7 语料缺失 SKIP 标红 | Task 6 `collect()`；Task 7 `corpus-missing` |
| §7 不做边框/hr、不做浅色模式、不给建议色 | 全计划均未实现，符合 |
| §8 变异测试逐条证死 | Task 7 |
| §9 已知局限 | Task 8 Step 4 写进 lessons |

**本计划刻意不做（留档，避免下一轮当成遗漏）：**

- **`contrast-ok` 注记的解析**。spec §5 定义了它，但**首版一条都用不到**——存量全部走「冻基线」，没有任何一条已经判定为「可以永远这样」。现在就实现等于写一段没有任何调用方的代码，还得配一套变异测试。**等真的要写第一条注记时再加**，那时才知道它该长什么样（`census_ok` 在 `theme_lib.exemptions` 里已有可复用的形状）。
- **改任何主题文件与 `theme.json`**。本计划只建护栏、不动存量。处置 `N` 条存量是另一轮的事，且几乎每条都含审美判断、需要用户逐条拍板。

**类型一致性核对：** `Node` 的七个字段在 Task 3 定义、Task 4（`style`/`text`）与 Task 5（`fg`/`samples`/`size`/`weight`/`own_bg`/`tag`）消费，名字一致。`Finding` 在 Task 5 定义、Task 6 的 `key_of`/`row_of` 消费，九个字段对应 `HEADER` 九列。`decor_signatures` 返回二元组，`is_decor` 接同一个二元组。`backdrop_samples` 的第三参数在 Task 2 单测里直接传 list，在 Task 3 里传父级 `samples`，类型一致。

**已知的执行顺序约束：** Task 6 Step 2 之前**任何任务都不许断言总条数**——真实基数在那一步才产生。本计划里出现的 113 / 43 / 156 都是探针口径的估计，只用来判断首跑结果有没有离谱。
