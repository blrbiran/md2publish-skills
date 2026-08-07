# 产物落点普查（census-themes.py）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建一个机械检查，把「主题文件声明了什么」「`theme.json` 兑现了什么」「产物里实际出现几次」三侧对起来，堵住本仓库唯一没有护栏的那一层。

**Architecture:** 抽一个 `theme_lib.py` 承载解析纪律，`audit-themes.py` 改为 import 它（纯重构，行为零变化），新写 `census-themes.py` 做九项检查，分 L1（`.md` ↔ `theme.json`，无语料依赖）、L2（`theme.json` ↔ 产物，需语料）、L3（散文条款 ↔ 机械字段，无语料依赖）三层。每一档配变异测试。

**Tech Stack:** Python 3（仅标准库）、Bash（变异测试）。无第三方依赖。

**权威设计文档：** `docs/superpowers/specs/2026-08-07-product-landing-census-design.md`。本计划是它的执行分解，**判据以设计文档为准**；两者冲突时改计划，不改设计。

## Global Constraints

- **只用 Python 标准库**，不引入任何第三方依赖（`audit-themes.py` / `md2html.py` 都是如此）。
- **所有文档、注释、报告文案用中文**，与仓库现有风格一致。
- **不改 `md2html.py`，不加任何 `theme.json` 新字段。** 本轮只做检查，不做修复。
- **不手改任何 HTML 产物。** 产物只能由 `md2html.py` 生成。
- **红线：改主题文件（`references/theme-prompts/*.md`、`references/theme-json/*.theme.json`）、`git commit`、`git push` 一律先经用户确认。** 计划里所有 `git commit` 步骤都是**建议时机**，执行者必须先问用户。
- 语料路径统一用 `MD2HTML_CORPUS` 环境变量，默认 `$HOME/code/skills/writing/wechat_test/litellm-multi-provider-gateway`（与 `test-md2html.sh:27` 一致）。
- 严重度档名固定为：`UNCARRIED` `INVENTED` `INLINE-BLOCK` `UNMOUNTED` `ZERO` `NEAR-ZERO` `DECOR` `INVERT` `STALE-NOTE`。
- 豁免注记前缀固定为 `census-ok:`，**不复用 `audit-ok:`**。

## File Structure

| 文件 | 职责 |
|---|---|
| `skills/md2publish-article/scripts/theme_lib.py` | **新建。** 解析纪律的唯一一份：剥注释、解析调色板、解析规范行、解析豁免注记、主题名对照表、色值计数原语 |
| `skills/md2publish-article/scripts/audit-themes.py` | **改。** 删掉自己的解析函数，改 import `theme_lib`。行为必须零变化 |
| `skills/md2publish-article/scripts/census-themes.py` | **新建。** 九项检查 + 报告 + `--counts` 模式 |
| `skills/md2publish-article/scripts/test-audit-themes.sh` | **改。** 补两条守卫用例（14 → 16） |
| `skills/md2publish-article/scripts/test-census-themes.sh` | **新建。** 变异测试 |
| `docs/theme-design-lessons.md` | **改（最后一步）。** 回写本轮学到的规则 |
| `docs/handoff/handoff.md` | **改（最后一步）。** 基线四条 → 六条 |

## 任务依赖

```
Task 1（重构 + 守卫用例）
   └→ Task 2（theme_lib 新原语）
        ├→ Task 3（L1 三档）
        ├→ Task 4（L3 UNMOUNTED）
        └→ Task 5（L2 五档）
             └→ Task 6（豁免机制 + --counts）
                  └→ Task 7（真实库裁决，人工介入）
                       └→ Task 8（文档收尾）
```

Task 3 / 4 / 5 之间没有依赖，可并行。

---

### Task 1: 抽出 theme_lib.py（纯重构）+ 补两条守卫用例

**这一步不许加任何新功能。** 唯一的目标是把解析纪律搬到共用模块，且证明 `audit-themes.py` 行为零变化。

**Files:**
- Create: `skills/md2publish-article/scripts/theme_lib.py`
- Modify: `skills/md2publish-article/scripts/audit-themes.py`（删掉 `strip_comments` / `declared_colors` / `element_of` 的实现，改 import）
- Test: `skills/md2publish-article/scripts/test-audit-themes.sh`（14 → 16 条）

**Interfaces:**
- Produces:
  - `theme_lib.strip_comments(text: str) -> str`
  - `theme_lib.palette(md_text: str) -> dict[str, str]`（色值小写 → 该行原文）
  - `theme_lib.element_of(line: str) -> str`

- [ ] **Step 1: 存下重构前的基线输出**

这是本任务的验收依据，比测试全绿有力得多。

```bash
cd ~/code/skills/writing/md2publish-skills
python3 skills/md2publish-article/scripts/audit-themes.py > /tmp/audit-baseline.txt 2>&1
wc -l /tmp/audit-baseline.txt
```

- [ ] **Step 2: 在 test-audit-themes.sh 末尾（真实库用例之前）补两条守卫用例**

这两条守的是 `theme_lib.palette()` 将要继承的核心纪律。**没有它们，14 绿证明不了行为等价**——已实测：把 `declared_colors` 改成「取每行全部色值」、以及删掉 `NOSPEC` 分支，两次定点破坏都是 14 通过 0 失败。

```bash
# ------------------------------------------------ 守卫：palette 的解析纪律

# 15. 调色板行里带第二个色值（说明用），只有第一个算声明 → 一条都不该报。
#     破坏 declared_colors 成「取全部色值」，#aa1144 会变成零落点死色 → DEAD。
mk guard-first-color-only <<'EOF'
# fixture：调色板行里带第二个色值（说明用）

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 主强调：`#cc3366`——旧值 `#aa1144` 在白底上只有 3.1:1，已弃用

## 容器与布局

- 主容器：`background-color: #ffffff; padding: 40px 10px`

## 正文与强调

- 段落：`color: #222222; font-size: 16px`
- strong：`color: #cc3366; font-weight: 700`
EOF
check guard-first-color-only

# 16. 缺「## 色彩系统」段要报 NOSPEC，不许静默跳过。
#     删掉 NOSPEC 分支改为 return []，这条会变红。
mk guard-nospec <<'EOF'
# fixture：没有色彩系统段

## 容器与布局

- 主容器：`background-color: #ffffff; padding: 40px 10px`
EOF
check guard-nospec "NOSPEC -"
```

- [ ] **Step 3: 跑测试，确认这两条在未改动的脚本上是绿的**

```bash
bash skills/md2publish-article/scripts/test-audit-themes.sh
```
Expected: `16 通过，0 失败`

这两条是**回归守卫**不是新功能，所以现在就该绿。绿不代表它们有牙齿——下一步验证。

- [ ] **Step 4: 定点破坏，验证这两条有牙齿**

```bash
cp skills/md2publish-article/scripts/audit-themes.py /tmp/audit-backup.py
# 破坏 1：取每行全部色值
python3 - <<'PY'
import re,pathlib
p=pathlib.Path('skills/md2publish-article/scripts/audit-themes.py')
s=p.read_text()
s=s.replace('        m = re.search(r"#[0-9a-fA-F]{6}", line)\n        if m and m.group() not in out:\n            out[m.group()] = line',
            '        for m in re.finditer(r"#[0-9a-fA-F]{6}", line):\n            if m.group() not in out:\n                out[m.group()] = line')
p.write_text(s)
PY
bash skills/md2publish-article/scripts/test-audit-themes.sh | tail -3
```
Expected: `guard-first-color-only` **FAIL**（期望 `<空>`，实得 `DEAD #aa1144`）

```bash
cp /tmp/audit-backup.py skills/md2publish-article/scripts/audit-themes.py
bash skills/md2publish-article/scripts/test-audit-themes.sh | tail -1
```
Expected: 恢复到 `16 通过，0 失败`

如果破坏之后测试仍然全绿，**停下来**——守卫用例写错了，先修它再往下走。

- [ ] **Step 5: 创建 theme_lib.py，把三个函数原样搬过去**

从 `audit-themes.py` 剪切 `strip_comments`、`declared_colors`、`element_of` 三个函数的**实现**（含 docstring 和注释，一字不改），粘进新文件。`declared_colors` 更名为 `palette`。

```python
#!/usr/bin/env python3
"""主题文件的解析纪律——audit-themes.py 与 census-themes.py 共用的唯一一份。

这些函数每一个都对应一次踩过的坑，改动前先读它们自己的 docstring：

- strip_comments：豁免注记里的色值会变成假落点，必须先剥
- palette：一行只声明一个色，取第一个；后面解释里引用的其它色值不算声明
- element_of：按元素名判定，不拿关键词在整行里搜

搬进本模块时一字未改。若要改判据，先跑 test-audit-themes.sh 与 test-census-themes.sh。
"""

import re

# ↓ 以下三个函数从 audit-themes.py 原样搬入，实现不变
```

- [ ] **Step 6: 改 audit-themes.py 为 import**

删掉那三个函数的定义，顶部加：

```python
from theme_lib import strip_comments, element_of, palette as declared_colors
```

保留 `declared_colors` 这个本地别名，这样 `audit-themes.py` 正文一行都不用改——**改动面越小，行为漂移的机会越少**。

- [ ] **Step 7: 逐字节 diff 验收（本任务的真正验收）**

```bash
python3 skills/md2publish-article/scripts/audit-themes.py > /tmp/audit-after.txt 2>&1
diff /tmp/audit-baseline.txt /tmp/audit-after.txt && echo "✅ 27 个主题输出逐字节一致"
bash skills/md2publish-article/scripts/test-audit-themes.sh | tail -1
```
Expected: `diff` 无输出 + `16 通过，0 失败`

diff 有任何输出就是重构改坏了行为，回退重来。**不要因为「差异看起来无害」就放过。**

- [ ] **Step 8: Commit（先问用户）**

```bash
git add skills/md2publish-article/scripts/theme_lib.py \
        skills/md2publish-article/scripts/audit-themes.py \
        skills/md2publish-article/scripts/test-audit-themes.sh
git commit -m "抽出 theme_lib 承载解析纪律，audit-themes 改 import；补两条守卫用例"
```

---

### Task 2: theme_lib 新增四个原语

**Files:**
- Modify: `skills/md2publish-article/scripts/theme_lib.py`
- Test: `skills/md2publish-article/scripts/test-theme-lib.py`（新建，纯 Python 单元测试，用 `assert`）

**Interfaces:**
- Consumes: Task 1 的 `strip_comments` / `palette`
- Produces:
  - `spec_lines(md_text: str) -> list[tuple[int, str]]` — 规范行，返回 `(行号, 行文)`
  - `theme_pairs(ref_dir: str) -> list[tuple[str, str, str]]` — `(主题名, md 绝对路径, theme.json 绝对路径)`
  - `exemptions(md_text: str, prefix: str) -> list[tuple[str, str, str]]` — `(档名, 键, 理由)`
  - `landings(html: str) -> dict[str, collections.Counter]` — 色值 → `Counter[(标签, 桶)]`，桶 ∈ `{"text","fill","line"}`

- [ ] **Step 1: 写失败的测试**

Create `skills/md2publish-article/scripts/test-theme-lib.py`：

```python
#!/usr/bin/env python3
"""theme_lib 新原语的单元测试。跑法：python3 test-theme-lib.py"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import theme_lib as T

fails = []
def eq(name, actual, expected):
    if actual == expected:
        print(f"ok   {name}")
    else:
        print(f"FAIL {name}\n     期望: {expected!r}\n     实得: {actual!r}")
        fails.append(name)

# ---- spec_lines：判「是不是规范」看有没有可机械化实体，不看行首符号

MD = """# t

## 色彩系统

- 主强调：`#cc3366`

## 收尾

文末居中放一个印章：`<p style="text-align: center; color: #cc3366;">□</p>` 可换为「完」字。

朱砂红是唯一的颜色，出现频率要低——像印章落在水墨画上，多了就俗。

  1. 原文里带「注意 / 警告 / 不要 / 会导致」这类警示语义的 `strong`，改用 `color: #ff4ba3`

| 函数名 | `#d2a8ff` | 定义或调用处 |
"""
got = [t for _, t in T.spec_lines(MD)]
eq("spec_lines 收散文体带 style 的规范",
   any("印章" in l and "style=" in l for l in got), True)
eq("spec_lines 不收纯比喻句",
   any("多了就俗" in l for l in got), False)
eq("spec_lines 收缩进有序条款行",
   any("警示语义" in l for l in got), True)
eq("spec_lines 收表格行",
   any("#d2a8ff" in l for l in got), True)

# ---- exemptions：按前缀分流，键是不透明 token

EX = """<!-- census-ok: INVERT #f28ba8 待真机定夺 -->
<!-- census-ok: UNMOUNTED p_first 本主题刻意不做导语 -->
<!-- audit-ok: OVER #3d6a8a 别的脚本的注记 -->
"""
eq("exemptions 只认自己的前缀",
   T.exemptions(EX, "census-ok"),
   [("INVERT", "#f28ba8", "待真机定夺"),
    ("UNMOUNTED", "p_first", "本主题刻意不做导语")])
eq("exemptions 认得 audit-ok",
   T.exemptions(EX, "audit-ok"),
   [("OVER", "#3d6a8a", "别的脚本的注记")])

# ---- landings：三个桶按属性名分，background-color 不许被当成 color

HTML = ('<p style="color: #111111; background-color: #eeeeee">x</p>'
        '<h3 style="border-left: 3px solid #cc3366">y</h3>'
        '<span style="color: #cc3366">z</span>')
land = T.landings(HTML)
eq("landings text 桶", land["#111111"][("p", "text")], 1)
eq("landings fill 桶", land["#eeeeee"][("p", "fill")], 1)
eq("landings 不把 background-color 记成 text",
   land["#eeeeee"].get(("p", "text"), 0), 0)
eq("landings line 桶", land["#cc3366"][("h3", "line")], 1)
eq("landings 同色跨桶分开记", land["#cc3366"][("span", "text")], 1)

print(f"\n{len(got) and ''}{'FAIL' if fails else 'ok'}：{len(fails)} 条失败")
sys.exit(1 if fails else 0)
```

- [ ] **Step 2: 跑测试确认它红**

```bash
python3 skills/md2publish-article/scripts/test-theme-lib.py
```
Expected: FAIL，报 `AttributeError: module 'theme_lib' has no attribute 'spec_lines'`

- [ ] **Step 3: 实现四个原语**

追加到 `theme_lib.py`：

```python
import collections
import json
import os

# 可机械化实体：色值、内联样式串、CSS 声明。带其一即为规范行。
_ENTITY = re.compile(r"#[0-9a-fA-F]{6}|style\s*=|[a-z-]+\s*:\s*[^\s;]")


def spec_lines(md_text):
    """规范行 = 行里含可机械化实体的行。返回 [(行号, 行文)]。

    **判定不看行首符号。**第一版按 bullet/表格行判，两头都错：
    漏掉 ink-wash.md:47 那种散文体带完整 style 串的规范（全库 15 行，
    「## 收尾」节的通用写法），也漏掉 cyber-neon.md:36 那种缩进有序项。
    而纯比喻句（「像印章落在水墨画上」）不带实体，自然落选。
    """
    out = []
    for i, line in enumerate(strip_comments(md_text).splitlines(), 1):
        if _ENTITY.search(line):
            out.append((i, line))
    return out


def theme_pairs(ref_dir):
    """主题名 → (md 路径, theme.json 路径)。**显式对照表，不用正则从文件名推。**

    13-cyber-neon-v7-edge.theme.json ↔ cyber-neon.md 推不出来，而兜底 regex
    会在下一个带后缀的主题上静默失配。双向完整性在调用处断言。
    """
    md_dir = os.path.join(ref_dir, "theme-prompts")
    js_dir = os.path.join(ref_dir, "theme-json")
    pairs = []
    for js in sorted(os.listdir(js_dir)):
        if not js.endswith(".theme.json"):
            continue
        base = js[: -len(".theme.json")]
        name = re.sub(r"^\d+-", "", base)
        md = os.path.join(md_dir, _MD_NAME.get(base, name) + ".md")
        pairs.append((base, md, os.path.join(js_dir, js)))
    return pairs


# 推不出来的映射写死在这里。新增带后缀的主题要在这里加一行。
_MD_NAME = {"13-cyber-neon-v7-edge": "cyber-neon"}


def exemptions(md_text, prefix):
    """解析豁免注记。prefix 是 'census-ok' 或 'audit-ok'，**不能省**。

    两套注记共存于同一批主题文件，各认各的前缀，互不干扰。
    """
    pat = re.compile(r"<!--\s*" + re.escape(prefix) + r":\s*(\S+)\s+(\S+)\s+(.*?)\s*-->", re.S)
    return [(m.group(1), m.group(2), m.group(3)) for m in pat.finditer(md_text)]


_TAG_STYLE = re.compile(r'<([a-zA-Z][a-zA-Z0-9]*)\b[^>]*?style="([^"]*)"')
_COLOR_PROP = re.compile(r"(?<![-\w])color\s*$")


def landings(html):
    """色值 → Counter[(标签, 桶)]，桶 ∈ text / fill / line。

    桶按 **CSS 属性名**分，不按视觉直觉分：
      text = color；fill = background 开头的任何属性；line = 其余
    取属性名必须带 (?<![-\\w]) 守卫——background-color: 含子串 color:，
    不挡就永远取到底色（audit-themes.py:103 踩过一次，配了变异用例）。
    """
    res = collections.defaultdict(collections.Counter)
    for tag, style in _TAG_STYLE.findall(html):
        for decl in style.split(";"):
            if ":" not in decl:
                continue
            prop, val = decl.split(":", 1)
            prop = prop.strip().lower()
            if _COLOR_PROP.search(prop):
                bucket = "text"
            elif prop.startswith("background"):
                bucket = "fill"
            else:
                bucket = "line"
            for c in re.findall(r"#[0-9a-fA-F]{6}", val):
                res[c.lower()][(tag.lower(), bucket)] += 1
    return res
```

- [ ] **Step 4: 跑测试确认它绿**

```bash
python3 skills/md2publish-article/scripts/test-theme-lib.py
```
Expected: 全部 `ok`，退出码 0

- [ ] **Step 5: 确认没碰坏 Task 1 的成果**

```bash
bash skills/md2publish-article/scripts/test-audit-themes.sh | tail -1
python3 skills/md2publish-article/scripts/audit-themes.py > /tmp/audit-after2.txt 2>&1
diff /tmp/audit-baseline.txt /tmp/audit-after2.txt && echo "✅ 仍然一致"
```
Expected: `16 通过，0 失败` + diff 无输出

- [ ] **Step 6: Commit（先问用户）**

```bash
git add skills/md2publish-article/scripts/theme_lib.py \
        skills/md2publish-article/scripts/test-theme-lib.py
git commit -m "theme_lib 加规范行/对照表/豁免注记/落点计数四个原语"
```

---

### Task 3: L1 三档（UNCARRIED / INVENTED / INLINE-BLOCK）

**Files:**
- Create: `skills/md2publish-article/scripts/census-themes.py`
- Create: `skills/md2publish-article/scripts/test-census-themes.sh`

**Interfaces:**
- Consumes: `theme_lib.spec_lines` / `palette` / `theme_pairs` / `strip_comments`
- Produces:
  - `census-themes.py --fixture-dir DIR`：把 `DIR/<name>.md` + `DIR/<name>.theme.json` 当成一对主题跑（变异测试用）
  - 报告行格式：`<档名> <主题名> <键> <一句话>`，`awk '{print $1, $3}'` 可取「档名 + 键」

- [ ] **Step 1: 写变异测试骨架 + L1 三档用例**

Create `skills/md2publish-article/scripts/test-census-themes.sh`：

```bash
#!/usr/bin/env bash
#
# census-themes.py 的变异测试：造带**已知缺陷**的主题对，断言脚本报什么、不报什么。
#
#     bash skills/md2publish-article/scripts/test-census-themes.sh
#
# 每个用例一份 .md + 一份 .theme.json，落到独立临时目录。
# **误报和漏报要一起测**——设计文档第四节记了三个陷阱，第一版三条纪律全踩中，
# 直接把这一档要抓的缺陷杀掉了。fixture 的书写形态贴着真实主题库来。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CENSUS="$SCRIPT_DIR/census-themes.py"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0

# mkmd <用例名>：从 stdin 读主题 .md
mkmd() { mkdir -p "$WORK/$1"; cat > "$WORK/$1/$1.md"; }
# mkjson <用例名>：从 stdin 读 theme.json
mkjson() { mkdir -p "$WORK/$1"; cat > "$WORK/$1/$1.theme.json"; }

# check <用例名> [期望的「档名 键」...]：不给期望 = 断言一条都不该报
check() {
  local name="$1"; shift
  local expected actual
  expected="$(printf '%s\n' "$@" | sed '/^$/d' | sort)"
  actual="$(python3 "$CENSUS" --fixture-dir "$WORK/$name" 2>&1 |
    awk '$1 ~ /^(UNCARRIED|INVENTED|INLINE-BLOCK|UNMOUNTED|ZERO|NEAR-ZERO|DECOR|INVERT|STALE-NOTE)$/ {print $1, $3}' | sort)"
  if [ "$actual" = "$expected" ]; then
    printf 'ok   %s\n' "$name"; pass=$((pass + 1))
  else
    printf 'FAIL %s\n     期望: %s\n     实得: %s\n' "$name" "${expected:-<空>}" "${actual:-<空>}"
    fail=$((fail + 1))
  fi
}

echo "── L1：UNCARRIED / INVENTED / INLINE-BLOCK ──────────"

# 1. 主题文件表格行声明了 token 色，theme.json 没兑现 → UNCARRIED
#    形态照 editor-slate 的 GitHub Dark token 表抄。
mkmd l1-uncarried-table <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 语法高亮

| 角色 | 色值 | 落点 |
|---|---|---|
| 注释 | `#6a737d` | 行注释 |
| 函数名 | `#d2a8ff` | 定义或调用处 |
EOF
mkjson l1-uncarried-table <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "highlight": {"comment": "#6a737d"}}
EOF
check l1-uncarried-table "UNCARRIED #d2a8ff"

# 2. 对照：token 色全部兑现 → 不该报
mkmd l1-uncarried-ok <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 语法高亮

| 角色 | 色值 | 落点 |
|---|---|---|
| 注释 | `#6a737d` | 行注释 |
| 函数名 | `#d2a8ff` | 定义或调用处 |
EOF
mkjson l1-uncarried-ok <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "highlight": {"comment": "#6a737d", "function": "#d2a8ff"}}
EOF
check l1-uncarried-ok

# 3. 同一行把色值当反例引用——UNCARRIED 取「规范行里的任意色值」，这行是它天然的
#    误报面。形态照 monochrome-mag.md:15 抄。该色在别处有落点，所以不该报。
mkmd l1-uncarried-counterexample <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 中灰：`#5a5a5a`（浅灰底上的次要文字——`#767676` 在 `#f2f2f2` 上只有 3.96:1，别用在灰底上）
- 浅灰底：`#f2f2f2`
- 浅中灰：`#767676`

## 正文与强调

- 段落：`color: #5a5a5a`
- 图注：`color: #767676`
EOF
mkjson l1-uncarried-counterexample <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #5a5a5a",
 "blockquote": "background-color: #f2f2f2; color: #767676"}
EOF
check l1-uncarried-counterexample

# 4. theme.json 里凭空多出一个色（执行者为凑对比度现造的）→ INVENTED
#    形态照 gilded-ink / terracotta-sun 抄，都在 highlight 键上。
mkmd l1-invented <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
EOF
mkjson l1-invented <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "highlight": {"comment": "#6a4f1a"}}
EOF
check l1-invented "INVENTED #6a4f1a"

# 5. 无卡片主题，h2 承担定宽却是 inline-block → INLINE-BLOCK
#    这是 arena-charge 的原始形态（判例）。
mkmd l1-inlineblock-h2 <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
EOF
mkjson l1-inlineblock-h2 <<'EOF'
{"container": "background-color: #ffffff", "content_width": 800,
 "p": "color: #222222",
 "h2": "color: #222222; display: inline-block; background-color: #222222"}
EOF
check l1-inlineblock-h2 "INLINE-BLOCK h2"

# 6. 有卡片主题，h2 在卡内不承担定宽 → 不该报。
#    这一格是判据的误报面：全库 12 处 inline-block 全在这种位置上。
mkmd l1-inlineblock-card-h2 <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
EOF
mkjson l1-inlineblock-card-h2 <<'EOF'
{"container": "background-color: #ffffff", "content_width": 800,
 "card": "background-color: #ffffff; border: 1px solid #222222",
 "p": "color: #222222",
 "h2": "color: #222222; display: inline-block"}
EOF
check l1-inlineblock-card-h2

# 7. 有卡片主题，card 自己是 inline-block → 该报。
#    第一版判据把 card 漏在范围外，20 个卡片主题等于零覆盖。
mkmd l1-inlineblock-card <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
EOF
mkjson l1-inlineblock-card <<'EOF'
{"container": "background-color: #ffffff", "content_width": 800,
 "card": "background-color: #ffffff; display: inline-block",
 "p": "color: #222222"}
EOF
check l1-inlineblock-card "INLINE-BLOCK card"

# 8. 有卡片主题，footer 是 inline-block → 该报（footer 恒 boxed=True）。
#    第一版被「无卡片」条件屏蔽掉了。
mkmd l1-inlineblock-footer <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
EOF
mkjson l1-inlineblock-footer <<'EOF'
{"container": "background-color: #ffffff", "content_width": 800,
 "card": "background-color: #ffffff",
 "p": "color: #222222",
 "footer": "color: #222222; display: inline-block"}
EOF
check l1-inlineblock-footer "INLINE-BLOCK footer"

# 9. 对照：inline-block 在 *_html 片段的内层 span 上 → 不该报（washi-spring 的形态）
mkmd l1-inlineblock-fragment <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
EOF
mkjson l1-inlineblock-fragment <<'EOF'
{"container": "background-color: #ffffff", "content_width": 800,
 "p": "color: #222222",
 "footer_html": "<span style=\"display: inline-block; color: #222222\">終</span>"}
EOF
check l1-inlineblock-fragment

printf '\n%d 通过，%d 失败\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

- [ ] **Step 2: 跑测试确认它红**

```bash
bash skills/md2publish-article/scripts/test-census-themes.sh
```
Expected: 9 条全 FAIL（`census-themes.py` 还不存在，`python3` 报错，`actual` 为空）

- [ ] **Step 3: 实现 census-themes.py 的 L1 三档**

```python
#!/usr/bin/env python3
"""产物落点普查：把「声明了什么」「兑现了什么」「实际出现几次」三侧对起来。

用法：
    python3 census-themes.py                      # 扫真实主题库
    python3 census-themes.py --fixture-dir DIR    # 变异测试用，DIR/<n>.md + DIR/<n>.theme.json
    python3 census-themes.py --counts <主题名>     # 输出该主题每个调色板色的落点分解

背景见 docs/superpowers/specs/2026-08-07-product-landing-census-design.md。
核心认知：audit-themes.py 报 0 条不等于主题成立——它查主题文件里有没有**声明**落点，
不查产物里这个色出现几次。本仓库已知四次「规范白纸黑字写着、产物里 0 处」全部逃过了
现有的每一条检查。

判定分九档，严重度三级（ERROR / WARN / INFO），三级都可用注记豁免：

    <!-- census-ok: <档名> <键> <一句话理由> -->

**基线是「未销掉的 = 0 条」**，与 audit-themes.py 同一套约定。
"""

import argparse
import collections
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from theme_lib import strip_comments, palette, spec_lines, theme_pairs, exemptions, landings

SEVERITY = {
    "UNCARRIED": "ERROR", "INVENTED": "ERROR", "INLINE-BLOCK": "ERROR",
    "UNMOUNTED": "ERROR", "ZERO": "ERROR", "NEAR-ZERO": "WARN",
    "DECOR": "WARN", "INVERT": "INFO", "STALE-NOTE": "ERROR",
}

# 承担定宽的键，照 md2html.py 里 boxed=True 的实际集合定，不用「主题有没有卡片」近似。
#   card   md2html.py:324  恒 True
#   顶层块  md2html.py:356 起  boxed = not card_open，即仅无卡片主题
#   footer md2html.py:434  恒 True，与有无卡片无关
TOP_BLOCK = ("p", "p_first", "h2", "h2_first", "h3", "blockquote",
             "pre", "table", "list_item", "hr")


def json_colors(theme):
    """theme.json 里出现的全部色值 → 出现在哪些键上。"""
    out = collections.defaultdict(set)

    def walk(key, val):
        if isinstance(val, dict):
            for v in val.values():
                walk(key, v)
        elif isinstance(val, list):
            for v in val:
                walk(key, v)
        else:
            for c in re.findall(r"#[0-9a-fA-F]{6}", str(val)):
                out[c.lower()].add(key)

    for k, v in theme.items():
        walk(k, v)
    return out


def boxed_keys(theme):
    """这份 theme.json 里，哪些键会被 md2html.py 拼上定宽串。"""
    keys = ["footer"]
    if theme.get("card"):
        keys.append("card")
    else:
        keys.extend(TOP_BLOCK)
    return keys


def check_l1(name, md_text, theme):
    """L1：主题 .md ↔ theme.json。不需要语料，任何时候都能跑完。"""
    found = []
    clean = strip_comments(md_text)
    jc = json_colors(theme)

    # UNCARRIED：规范行里声明的色，theme.json 一次都不出现
    declared = set()
    for _, line in spec_lines(clean):
        declared.update(c.lower() for c in re.findall(r"#[0-9a-fA-F]{6}", line))
    for c in sorted(declared - set(jc)):
        found.append(("UNCARRIED", name, c, "主题文件声明了，theme.json 没兑现"))

    # INVENTED：theme.json 里的色，主题文件任何位置都没有（规则 9：不许自己造色）
    all_md = set(c.lower() for c in re.findall(r"#[0-9a-fA-F]{6}", clean))
    for c in sorted(set(jc) - all_md):
        found.append(("INVENTED", name, c,
                      f"theme.json 现造的色，主题文件里没有（落在 {sorted(jc[c])}）"))

    # INLINE-BLOCK：承担定宽的键不能是 inline-block（判例）
    for k in boxed_keys(theme):
        v = theme.get(k)
        if isinstance(v, str) and "inline-block" in v:
            found.append(("INLINE-BLOCK", name, k,
                          "承担定宽的元素用 inline-block，auto 外边距会算成 0"))
    return found


def report(found):
    for tier, theme, key, why in found:
        print(f"{tier:<13}{theme:<24}{key:<12}{why}")
    print(f"\n普查完毕，{len(found)} 条未销")
    return 1 if found else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fixture-dir")
    args = ap.parse_args()

    found = []
    if args.fixture_dir:
        d = args.fixture_dir
        for f in sorted(os.listdir(d)):
            if not f.endswith(".md"):
                continue
            name = f[:-3]
            jp = os.path.join(d, name + ".theme.json")
            if not os.path.exists(jp):
                continue
            found += check_l1(name, open(os.path.join(d, f)).read(),
                              json.load(open(jp)))
    else:
        ref = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "references")
        for base, md, js in theme_pairs(ref):
            if not os.path.exists(md):
                print(f"FAIL 对照表不完整：{base} 找不到 {md}")
                return 1
            found += check_l1(base, open(md).read(), json.load(open(js)))
    return report(found)


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: 跑测试确认 9 条全绿**

```bash
bash skills/md2publish-article/scripts/test-census-themes.sh
```
Expected: `9 通过，0 失败`

- [ ] **Step 5: 对真实库跑一次，核对 L1 的必抓清单**

```bash
python3 skills/md2publish-article/scripts/census-themes.py
```
Expected: 报告里**必须**出现这 6 条（设计文档第八节的硬指标）：

```
UNCARRIED  06-editor-slate  #d2a8ff
UNCARRIED  06-editor-slate  #ffa657
UNCARRIED  11-bauhaus-pop   #1e5aa8
UNCARRIED  20-monochrome-mag #767676
INVENTED   09-gilded-ink    #6a4f1a
INVENTED   09-gilded-ink    #7a5b1f
INVENTED   23-terracotta-sun #9c8a72
```

少一条就是判据漏了，**回去改脚本，不要改期望**。总条数会比这多（规范行判定比第一版宽），多出来的留到 Task 7 裁决。

- [ ] **Step 6: Commit（先问用户）**

```bash
git add skills/md2publish-article/scripts/census-themes.py \
        skills/md2publish-article/scripts/test-census-themes.sh
git commit -m "census-themes 实现 L1 三档 + 9 条变异用例"
```

---

### Task 4: L3（UNMOUNTED）

**Files:**
- Modify: `skills/md2publish-article/scripts/census-themes.py`
- Modify: `skills/md2publish-article/scripts/test-census-themes.sh`

**Interfaces:**
- Consumes: `theme_lib.spec_lines`
- Produces: `check_l3(name, md_text, theme) -> list[tuple]`

- [ ] **Step 1: 追加 L3 变异用例**

在 `test-census-themes.sh` 的 `printf '\n%d 通过...'` 之前插入：

```bash
echo "── L3：UNMOUNTED（语义条款没有机械挂载点）──────────"

# 10. 缩进有序条款行 + 关键词枚举里含否定词 → 该报 strong_alt。
#     这是设计文档第四节三个陷阱的现场（cyber-neon.md:36）。
#     「不要」躺在被引用的枚举里，距关键词「警示」约 10 字——8 字窗口挡不住，
#     救它的是引号护栏。
mkmd l3-cyberneon-form <<'EOF'
# fixture

## 色彩系统

- 背景：`#0f1420`（主容器）
- 主文字：`#c9d2e3`
- 副强调：`#ff4ba3`

## 正文与强调

- 段落：`color: #c9d2e3`
  1. 原文里带「注意 / 警告 / 不要 / 会导致」这类警示语义的 `strong`，改用 `color: #ff4ba3; font-weight: 600`
EOF
mkjson l3-cyberneon-form <<'EOF'
{"container": "background-color: #0f1420", "p": "color: #c9d2e3",
 "strong": "color: #ff4ba3"}
EOF
check l3-cyberneon-form "UNMOUNTED strong_alt"

# 11. 对照：同样的条款，theme.json 配了 strong_alt → 不该报
mkmd l3-strongalt-ok <<'EOF'
# fixture

## 色彩系统

- 背景：`#0f1420`（主容器）
- 主文字：`#c9d2e3`
- 副强调：`#ff4ba3`

## 正文与强调

- 段落：`color: #c9d2e3`
  1. 原文里带「注意 / 警告 / 不要 / 会导致」这类警示语义的 `strong`，改用 `color: #ff4ba3; font-weight: 600`
EOF
mkjson l3-strongalt-ok <<'EOF'
{"container": "background-color: #0f1420", "p": "color: #c9d2e3",
 "strong": "color: #c9d2e3",
 "strong_alt": {"keywords": ["注意", "警告"], "style": "color: #ff4ba3"}}
EOF
check l3-strongalt-ok

# 12. 散文体带完整 style 串的规范 → 该报 footer_html（ink-wash.md:47 的形态）
mkmd l3-prose-footer <<'EOF'
# fixture

## 色彩系统

- 背景：`#f7f6f2`（主容器）
- 朱砂：`#b5432a`

## 正文与强调

- 段落：`color: #333333`

## 收尾

文末居中放一个朱砂色小印章式符号：`<p style="text-align: center; color: #b5432a; font-size: 18px;">□</p>` 可换为「完」字。
EOF
mkjson l3-prose-footer <<'EOF'
{"container": "background-color: #f7f6f2", "p": "color: #333333",
 "strong": "color: #b5432a"}
EOF
check l3-prose-footer "UNMOUNTED footer_html"

# 13. 纯比喻句不带实体 → 不该报（ink-wash.md:8 的形态）
mkmd l3-metaphor <<'EOF'
# fixture

## 核心愿景

朱砂红是唯一的颜色，出现频率要低——像印章落在水墨画上，多了就俗。

## 色彩系统

- 背景：`#f7f6f2`（主容器）
- 朱砂：`#b5432a`

## 正文与强调

- 段落：`color: #333333`
- strong：`color: #b5432a`
EOF
mkjson l3-metaphor <<'EOF'
{"container": "background-color: #f7f6f2", "p": "color: #333333",
 "strong": "color: #b5432a"}
EOF
check l3-metaphor

# 14. 「引导语」不该命中「导语」→ 不该报 p_first（apple-air 的子串误报面）
mkmd l3-substring <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 强调：`#0071e3`

## 正文与强调

- 段落：`color: #222222`
- strong：`color: #0071e3`
- eyebrow 引导语用小号蓝字：`color: #0071e3; font-size: 12px`
EOF
mkjson l3-substring <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #0071e3"}
EOF
check l3-substring

# 15. 「无序前缀」里的单字「无」不该杀掉同行的「有序列表」条款 → 该报
mkmd l3-wu-not-negation <<'EOF'
# fixture

## 色彩系统

- 背景：`#eef7f2`（主容器）
- 主强调：`#2fa47e`

## 正文与强调

- 段落：`color: #222222`
- 列表：无序前缀 `<span style="color: #2fa47e;">✓</span>`，步骤类有序列表用绿色序号 `color: #2fa47e`
EOF
mkjson l3-wu-not-negation <<'EOF'
{"container": "background-color: #eef7f2", "p": "color: #222222",
 "strong": "color: #2fa47e",
 "list_prefix_html": "<span style=\"color: #2fa47e;\">✓</span>&nbsp;&nbsp;"}
EOF
check l3-wu-not-negation "UNMOUNTED list_prefix_ol_html"

# 16. 真正的否定句 → 不该报（「不要写…条款」）
mkmd l3-real-negation <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 强调：`#0071e3`

## 正文与强调

- 段落：`color: #222222`
- strong：`color: #0071e3`
- **不要写导语条款**：本主题第一段与其余段落同样处理，`color: #222222`
EOF
mkjson l3-real-negation <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #0071e3"}
EOF
check l3-real-negation
```

- [ ] **Step 2: 跑测试确认新增 7 条红**

```bash
bash skills/md2publish-article/scripts/test-census-themes.sh
```
Expected: 前 9 条 ok，后 7 条里至少 `l3-cyberneon-form` / `l3-prose-footer` / `l3-wu-not-negation` FAIL（期望有值、实得为空）

- [ ] **Step 3: 实现 L3**

追加到 `census-themes.py`：

```python
# 关键词 → 必须存在的 theme.json 字段。信号写成**组合**而不是字面整串：
# 第一版写「警示性 strong」，而 cyber-neon.md:36 的原文是「这类警示语义的 `strong`」，
# 字面不匹配——靶子就是这么丢的。
# 每项：(必须全部出现的信号组, 字段名, 前缀黑名单)
KEYWORD_FIELDS = [
    ((("导语", "首段", "全文第一段"),), "p_first", ("引",)),
    ((("首个 h2", "第一个 h2", "首节标题"),), "h2_first", ()),
    ((("警示", "注意", "警告"), ("strong",)), "strong_alt", ()),
    ((("印章", "落款", "文末装饰"),), "footer_html", ()),
    ((("提示卡",),), "alert", ()),
    ((("斑马纹", "隔行"),), "td_alt", ()),
    ((("有序列表", "序号"),), "list_prefix_ol_html", ()),
    ((("语法高亮",),), "highlight", ()),
    ((("轮换", "轮转"),), "list_prefix_cycle", ()),
    ((("对称饰线", "两侧饰线"),), "h2_suffix_html", ()),
]

# md2html.py docstring 字段表里的位置性/语义性字段，每个都必须在上表里有条目。
# 新增字段时忘记同步会立刻 FAIL，而不是静默漏检——与 theme_pairs 的完整性断言同一招。
SEMANTIC_FIELDS = {
    "p_first", "h2_first", "strong_alt", "footer_html", "alert", "td_alt",
    "list_prefix_ol_html", "highlight", "list_prefix_cycle", "h2_suffix_html",
}

NEGATIONS = ("不要", "别", "不用", "建议改用")
# 引号内的否定词不算——引号里是被引用的字面串，不是作者在否定什么。
_QUOTED = re.compile(r"「[^」]*」|\"[^\"]*\"|“[^”]*”|`[^`]*`")


def _negated(line, pos, word):
    """关键词命中位置附近有没有真正的否定。

    三条护栏缺一不可，第一版三条全踩了：
      1. 只在前后各 8 字的局部窗口内判，不做整行布尔判定
      2. 引号内的否定词不算（cyber-neon.md:36 的「不要」躺在被引用的枚举里，
         距关键词约 10 字，光靠窗口挡不住）
      3. 单字「无」只在「无<关键词>」这种紧邻组合里算否定
         （全库到处是「无序前缀」「无卡片」「无彩色」）
    """
    masked = _QUOTED.sub(lambda m: "　" * len(m.group()), line)
    lo, hi = max(0, pos - 8), min(len(masked), pos + len(word) + 8)
    window = masked[lo:hi]
    if any(n in window for n in NEGATIONS):
        return True
    return ("无" + word) in masked


def check_l3(name, md_text, theme):
    """L3：散文条款 ↔ 机械字段。不需要语料。"""
    found = []
    lines = spec_lines(strip_comments(md_text))
    for signals, field, blacklist in KEYWORD_FIELDS:
        if theme.get(field):
            continue
        for _, line in lines:
            hits = []
            for group in signals:
                hit = None
                for word in group:
                    for m in re.finditer(re.escape(word), line):
                        # 前缀黑名单：CJK 没有词边界，\b 在汉字之间永不成立
                        if any(line[max(0, m.start() - len(b)):m.start()] == b
                               for b in blacklist):
                            continue
                        if _negated(line, m.start(), word):
                            continue
                        hit = (m.start(), word)
                        break
                    if hit:
                        break
                if not hit:
                    hits = []
                    break
                hits.append(hit)
            if hits:
                found.append(("UNMOUNTED", name, field,
                              f"规范里写了这条，theme.json 无 {field} 字段"))
                break
    return found


def assert_keyword_table_complete():
    """语义字段必须在关键词表里有条目，缺一条 FAIL。"""
    covered = {f for _, f, _ in KEYWORD_FIELDS}
    missing = SEMANTIC_FIELDS - covered
    if missing:
        print(f"FAIL 关键词表漏了语义字段：{sorted(missing)}")
        print("     新增 md2html.py 字段时要同步 KEYWORD_FIELDS。")
        return False
    return True
```

在 `main()` 里，`found = []` 之后立刻加：

```python
    if not assert_keyword_table_complete():
        return 1
```

并把每处 `check_l1(...)` 改成 `check_l1(...) + check_l3(...)`（参数相同）。

- [ ] **Step 4: 跑测试确认 16 条全绿**

```bash
bash skills/md2publish-article/scripts/test-census-themes.sh
```
Expected: `16 通过，0 失败`

- [ ] **Step 5: 对真实库核对 L3 的必抓清单**

```bash
python3 skills/md2publish-article/scripts/census-themes.py | grep UNMOUNTED
```
Expected: **必须**包含这三条（设计文档第八节的硬指标）：

```
UNMOUNTED  13-cyber-neon-v7-edge  strong_alt
UNMOUNTED  22-blueprint-grid      strong_alt
UNMOUNTED  04-ink-wash            footer_html
```

这三条是覆盖矩阵里 cyber-neon 那格、blueprint-grid 那条新缺陷、以及 handoff 第六节第 2 条挂着的 ink-wash 朱砂印。**少一条就是判据漏了。**

- [ ] **Step 6: Commit（先问用户）**

```bash
git add skills/md2publish-article/scripts/census-themes.py \
        skills/md2publish-article/scripts/test-census-themes.sh
git commit -m "census-themes 实现 L3 UNMOUNTED + 7 条变异用例"
```

---

### Task 5: L2 五档（ZERO / NEAR-ZERO / DECOR / INVERT + 去重降级）

**Files:**
- Modify: `skills/md2publish-article/scripts/census-themes.py`
- Modify: `skills/md2publish-article/scripts/test-census-themes.sh`

**Interfaces:**
- Consumes: `theme_lib.landings` / `palette`
- Produces: `check_l2(name, md_text, theme, html) -> list[tuple]`

- [ ] **Step 1: 在测试脚本里加一篇受控 fixture 文章 + L2 用例**

变异测试**必须**用受控 fixture 文章（重复次数写死，`INVERT` 的倍数关系才可断言）。这与真实库跑要用 2.8 万字符长文不冲突：变异测试断言的是逻辑，不是频率合理性。

在 `test-census-themes.sh` 的 `check()` 定义之后加：

```bash
# 受控 fixture 文章：段落 6 段、strong 6 处、h3 2 处、列表 4 项。
# 计数写死，INVERT 的倍数关系才可断言。
ART="$WORK/fixture-article.md"
cat > "$ART" <<'EOF'
# 标题

## 第一章

一段正文，里面有 **强调甲** 和 **强调乙**。

又一段正文，**强调丙**。

### 小标题一

第三段正文，**强调丁**。

- 列表项一
- 列表项二

## 第二章

第四段正文，**强调戊**。

### 小标题二

第五段正文，**强调己**。

- 列表项三
- 列表项四
EOF

# checkl2 <用例名> [期望...]：带语料跑
checkl2() {
  local name="$1"; shift
  local expected actual
  expected="$(printf '%s\n' "$@" | sed '/^$/d' | sort)"
  actual="$(python3 "$CENSUS" --fixture-dir "$WORK/$name" --article "$ART" 2>&1 |
    awk '$1 ~ /^(UNCARRIED|INVENTED|INLINE-BLOCK|UNMOUNTED|ZERO|NEAR-ZERO|DECOR|INVERT|STALE-NOTE)$/ {print $1, $3}' | sort)"
  if [ "$actual" = "$expected" ]; then
    printf 'ok   %s\n' "$name"; pass=$((pass + 1))
  else
    printf 'FAIL %s\n     期望: %s\n     实得: %s\n' "$name" "${expected:-<空>}" "${actual:-<空>}"
    fail=$((fail + 1))
  fi
}
```

在末尾 `printf` 之前插入用例：

```bash
echo "── L2：ZERO / NEAR-ZERO / DECOR / INVERT ──────────"

# 17. 调色板声明了色，theme.json 也有（挂在一个渲染不到的键上）→ 产物 0 处 → ZERO
mkmd l2-zero <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 次级灰：`#999999`

## 正文与强调

- 段落：`color: #222222`
- 图注：`color: #999999`
EOF
mkjson l2-zero <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #222222",
 "td_alt": "background-color: #999999"}
EOF
checkl2 l2-zero "ZERO #999999"

# 18. 主强调只出现 1 处 → NEAR-ZERO（apple-air 出事时的形态）
#     h3_prefix_html 在 fixture 文章里只命中 2 次，用 footer_html 造 1 次。
mkmd l2-nearzero <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 唯一强调色：`#0071e3`

## 正文与强调

- 段落：`color: #222222`
- 落款：`color: #0071e3`
EOF
mkjson l2-nearzero <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #222222",
 "footer": "color: #0071e3",
 "footer_html": "完"}
EOF
checkl2 l2-nearzero "NEAR-ZERO #0071e3"

# 19. 强调色落点全是边框细线，文字落点 0 → DECOR（规则 6）
mkmd l2-decor <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 主强调：`#cc3366`

## 正文与强调

- 段落：`color: #222222`
- h3：`border-left: 3px solid #cc3366`
EOF
mkjson l2-decor <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #222222",
 "h3": "color: #222222; border-left: 3px solid #cc3366",
 "list_item": "color: #222222; border-left: 2px solid #cc3366"}
EOF
checkl2 l2-decor "DECOR #cc3366"

# 20. 标签写「线色，不作文字色」= 没标强调 → 不该报 DECOR。
#     判定只看冒号前的标签，不看破折号后的解释（washi-spring 的形态，
#     audit-themes.py:138-139 的注释逐字引用的就是这句话）。
mkmd l2-decor-labeled-line <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 灰樱粉（线色，不作文字色）：`#d98e9f`——h2 上下双细线、边框。而一个只当细线用的颜色不能算主强调
- 深樱（主强调，文字色）：`#b56b7d`

## 正文与强调

- 段落：`color: #222222`
- strong：`color: #b56b7d`
- h3：`border-bottom: 2px solid #d98e9f`
EOF
mkjson l2-decor-labeled-line <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #b56b7d",
 "h3": "color: #222222; border-bottom: 2px solid #d98e9f",
 "list_item": "color: #222222; border-left: 2px solid #d98e9f"}
EOF
checkl2 l2-decor-labeled-line

# 21. 主强调文字落点少于副强调 → INVERT（candy-pop 的形态）
mkmd l2-invert <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 樱粉（主强调）：`#f28ba8`
- 雾蓝（辅强调）：`#7fb5d5`

## 正文与强调

- 段落：`color: #222222`
- h3：`color: #f28ba8`
- strong：`color: #7fb5d5`
EOF
mkjson l2-invert <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "h3": "color: #f28ba8",
 "strong": "color: #7fb5d5"}
EOF
checkl2 l2-invert "INVERT #f28ba8"

# 22. 主强调文字落点多于副强调 → 不该报
mkmd l2-invert-ok <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 樱粉（主强调）：`#f28ba8`
- 雾蓝（辅强调）：`#7fb5d5`

## 正文与强调

- 段落：`color: #222222`
- h3：`color: #7fb5d5`
- strong：`color: #f28ba8`
EOF
mkjson l2-invert-ok <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "h3": "color: #7fb5d5",
 "strong": "color: #f28ba8"}
EOF
checkl2 l2-invert-ok

# 23. UNCARRIED 已报过的色，ZERO 降级为 INFO 不重复计入 ERROR，
#     但事实不许从报告里消失。
mkmd l2-dedup <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 浅中灰：`#767676`

## 正文与强调

- 段落：`color: #222222`
- strong：`color: #222222`
EOF
mkjson l2-dedup <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #222222"}
EOF
checkl2 l2-dedup "UNCARRIED #767676"

# 24. 无语料时 L2 整体 SKIP，退出码要标红（静默跳过等于没有护栏），
#     且 L1/L3 照常出结论。
echo -n "ok   l2-nocorpus-fails-loud ... "
if python3 "$CENSUS" --fixture-dir "$WORK/l2-zero" >/dev/null 2>&1; then
  printf 'FAIL l2-nocorpus-fails-loud\n     期望: 无语料时退出码非 0\n     实得: 0\n'
  fail=$((fail + 1))
else
  printf '\rok   l2-nocorpus-fails-loud                    \n'
  pass=$((pass + 1))
fi
```

- [ ] **Step 2: 跑测试确认新增用例红**

```bash
bash skills/md2publish-article/scripts/test-census-themes.sh
```
Expected: 前 16 条 ok，L2 那批 FAIL（`--article` 参数还不认识）

- [ ] **Step 3: 实现 L2**

追加到 `census-themes.py`：

```python
import subprocess
import tempfile

ACCENT_ROLE = ("强调", "点睛", "accent", "主色")
# 参照色的排除项：装饰面计数天然高或天然低；正文色必然压倒一切强调色，
# 拿它作参照会把全库都报了。
REF_EXCLUDE = ("底", "背景", "线", "边", "卡片", "面板", "纸面", "块",
               "正文", "主文字", "默认文字", "次级")


def _label(line):
    """只取冒号前的角色标签，不看破折号后的解释文字。

    这是 audit-themes.py:138-139 已有的纪律。washi-spring 的
    「灰樱粉（线色，不作文字色）：#d98e9f——……不能算主强调」整行搜「强调」
    会把它误判成强调色，而它恰恰声明了自己不是。
    """
    return re.split(r"[：:]", line.lstrip("-* "), 1)[0]


def render(article, theme_path, workdir, name):
    """现场用 md2html.py 生成产物。不读 out/ 定稿——那套 -v1/-v5 命名混乱，
    且「定稿与 theme.json 同步」这个假设失效恰恰是本脚本要报的毛病之一。"""
    out = os.path.join(workdir, name + ".html")
    md2html = os.path.join(os.path.dirname(os.path.abspath(__file__)), "md2html.py")
    r = subprocess.run([sys.executable, md2html, article, theme_path, "-o", out],
                       capture_output=True)
    if r.returncode != 0:
        return None, r.stderr.decode()[:200]
    return open(out).read(), None


def check_l2(name, md_text, html, already):
    """L2：theme.json ↔ 产物。already 是 L1 已报过 UNCARRIED 的色值集合。"""
    found = []
    land = landings(html)
    pal = palette(strip_comments(md_text))

    def text_count(c):
        return sum(v for (_, b), v in land.get(c, {}).items() if b == "text")

    for color, line in pal.items():
        total = sum(land.get(color, {}).values())
        label = _label(line)
        is_accent = any(k in label for k in ACCENT_ROLE)

        if total == 0:
            if color in already:
                # 去重只降级不消失：若直接删掉，一旦给 UNCARRIED 写了豁免注记，
                # 「这个色在产物里 0 处」这个事实就从报告里彻底消失了。
                found.append(("ZERO-DUP", name, color, "产物 0 处（已由 UNCARRIED 报过）"))
            else:
                found.append(("ZERO", name, color, "调色板声明了，产物里 0 处"))
            continue
        if total <= 2:
            found.append(("NEAR-ZERO", name, color, f"产物里只有 {total} 处"))
            continue
        if is_accent and text_count(color) == 0:
            found.append(("DECOR", name, color,
                          f"标为强调却没有文字色落点（{total} 处全是边框/底色）"))

    # INVERT：主强调的文字落点少于副/辅强调，或不足参照色的三分之一
    mains = [(c, l) for c, l in pal.items()
             if "主强调" in _label(l) or "唯一强调" in _label(l)]
    subs = [(c, l) for c, l in pal.items()
            if "副强调" in _label(l) or "辅强调" in _label(l)]
    refs = [(c, l) for c, l in pal.items()
            if not any(k in _label(l) for k in ACCENT_ROLE)
            and not any(k in _label(l) for k in REF_EXCLUDE)]
    for c, _ in mains:
        n = text_count(c)
        why = None
        for sc, sl in subs:
            if text_count(sc) > n:
                why = f"主强调文字落点 {n}，少于副/辅强调 {_label(sl)} 的 {text_count(sc)}"
                break
        if not why:
            for rc, rl in refs:
                if text_count(rc) > 3 * max(n, 1):
                    why = f"主强调文字落点 {n}，不足参照色 {_label(rl)}（{text_count(rc)}）的三分之一"
                    break
        if why:
            found.append(("INVERT", name, c, why))
    return found
```

`SEVERITY` 加一项：

```python
SEVERITY["ZERO-DUP"] = "INFO"
```

`main()` 加 `--article` 参数，并在每个主题的 L1/L3 之后接 L2：

```python
    ap.add_argument("--article", help="语料文章；不给则从 MD2HTML_CORPUS 推")
    ...
    corpus = os.environ.get(
        "MD2HTML_CORPUS",
        os.path.expanduser("~/code/skills/writing/wechat_test/litellm-multi-provider-gateway"))
    article = args.article or os.path.join(corpus, "litellm-multi-provider-gateway.md")
    has_corpus = os.path.exists(article)
    if not has_corpus:
        print(f"SKIP L2：语料不在 {article}")
        print("     这不是通过。设 MD2HTML_CORPUS 或 --article 再跑，否则产物侧没有护栏。")
```

每个主题处理里，L1 跑完后：

```python
        l1 = check_l1(base, md_text, theme)
        rows = l1 + check_l3(base, md_text, theme)
        if has_corpus:
            html, err = render(article, js, workdir, base)
            if err:
                rows.append(("RENDER-FAIL", base, "-", err))
            else:
                already = {c for t, _, c, _ in l1 if t == "UNCARRIED"}
                rows += check_l2(base, md_text, html, already)
        found += rows
```

`main()` 结尾：

```python
    code = report(found)
    return code or (0 if has_corpus else 1)   # 语料缺失也要标红
```

`workdir` 用 `tempfile.TemporaryDirectory()` 包住整个循环。

- [ ] **Step 4: 跑测试确认 24 条全绿**

```bash
bash skills/md2publish-article/scripts/test-census-themes.sh
```
Expected: `24 通过，0 失败`

- [ ] **Step 5: 对真实库跑全套，核对 DECOR 预期为 0**

```bash
python3 skills/md2publish-article/scripts/census-themes.py | grep -c "^DECOR"
```
Expected: `0`

若报出 washi-spring `#d98e9f`，说明 `_label()` 没生效、判定整行搜了「强调」——**回去修脚本**。设计文档第八节明确写了这条不该报。

```bash
python3 skills/md2publish-article/scripts/census-themes.py | grep "^INVERT"
```
Expected: 7 条，主题为 autumn-warm / ocean-calm / spring-fresh / candy-pop / gilded-ink / mint-breeze / terracotta-sun

- [ ] **Step 6: Commit（先问用户）**

```bash
git add skills/md2publish-article/scripts/census-themes.py \
        skills/md2publish-article/scripts/test-census-themes.sh
git commit -m "census-themes 实现 L2 五档 + 8 条变异用例"
```

---

### Task 6: 豁免机制 + STALE-NOTE + --counts

**Files:**
- Modify: `skills/md2publish-article/scripts/census-themes.py`
- Modify: `skills/md2publish-article/scripts/test-census-themes.sh`

**Interfaces:**
- Consumes: `theme_lib.exemptions`
- Produces: `--counts <主题名>` 模式

- [ ] **Step 1: 加豁免机制的变异用例**

```bash
echo "── 豁免机制 ──────────"

# 25. 写了对应注记 → 该发现被销掉
mkmd ex-silenced <<'EOF'
# fixture

<!-- census-ok: INVENTED #6a4f1a 为凑代码块对比度所加，待主题文件补声明 -->

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
- strong：`color: #222222`
EOF
mkjson ex-silenced <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #222222", "highlight": {"comment": "#6a4f1a"}}
EOF
checkl2 ex-silenced

# 26. 档名打错 → FAIL，不许静默地什么都不销
mkmd ex-badtier <<'EOF'
# fixture

<!-- census-ok: INVENTD #6a4f1a 档名打错了 -->

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
- strong：`color: #222222`
EOF
mkjson ex-badtier <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #222222", "highlight": {"comment": "#6a4f1a"}}
EOF
echo -n ""
if python3 "$CENSUS" --fixture-dir "$WORK/ex-badtier" --article "$ART" 2>&1 | grep -q "档名不认识"; then
  printf 'ok   ex-badtier\n'; pass=$((pass + 1))
else
  printf 'FAIL ex-badtier\n     期望: 报「档名不认识」\n'; fail=$((fail + 1))
fi

# 27. 注记销不到任何东西 → STALE-NOTE
mkmd ex-stale <<'EOF'
# fixture

<!-- census-ok: INVENTED #aabbcc 这个色早就不在 theme.json 里了 -->

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
- strong：`color: #222222`
EOF
mkjson ex-stale <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #222222"}
EOF
checkl2 ex-stale "STALE-NOTE #aabbcc"

# 28. 无语料时 L2 的注记不判 stale（否则一跑就是一片凭空 ERROR）
mkmd ex-stale-layergate <<'EOF'
# fixture

<!-- census-ok: INVERT #f28ba8 待真机观感定夺 -->

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
- strong：`color: #222222`
EOF
mkjson ex-stale-layergate <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #222222"}
EOF
if python3 "$CENSUS" --fixture-dir "$WORK/ex-stale-layergate" 2>&1 | grep -q "STALE-NOTE"; then
  printf 'FAIL ex-stale-layergate\n     期望: 无语料时 L2 注记不判 stale\n'; fail=$((fail + 1))
else
  printf 'ok   ex-stale-layergate\n'; pass=$((pass + 1))
fi
```

- [ ] **Step 2: 跑测试确认这 4 条红**

```bash
bash skills/md2publish-article/scripts/test-census-themes.sh
```
Expected: 前 24 条 ok，新增 4 条 FAIL

- [ ] **Step 3: 实现豁免机制与 --counts**

```python
L2_TIERS = {"ZERO", "ZERO-DUP", "NEAR-ZERO", "DECOR", "INVERT"}


def apply_exemptions(name, md_text, rows, l2_active):
    """豁免在去重之后、输出之前。返回 (剩余发现, stale 注记)。"""
    notes = exemptions(md_text, "census-ok")
    for tier, key, _ in notes:
        if tier not in SEVERITY:
            print(f"FAIL {name}：豁免注记档名不认识 —— {tier}")
            print(f"     合法档名：{sorted(SEVERITY)}")
            raise SystemExit(1)
    used = set()
    kept = []
    for row in rows:
        tier, _, key, _ = row
        idx = next((i for i, (t, k, _) in enumerate(notes)
                    if t == tier and k == key and i not in used), None)
        if idx is None:
            kept.append(row)
        else:
            used.add(idx)
    stale = []
    for i, (tier, key, _) in enumerate(notes):
        if i in used:
            continue
        # 按层设门：某层 SKIP 时该层的注记一律不判 stale，否则语料缺失
        # 会把所有 L2 注记变成凭空的 ERROR——而它们恰恰是要求写下来留档的。
        if tier in L2_TIERS and not l2_active:
            continue
        stale.append(("STALE-NOTE", name, key, f"这条 {tier} 注记销不到任何发现"))
    return kept, stale


def print_counts(name, md_text, html):
    """--counts：每个调色板色的落点分解。把「改完必须去数产物」变成一条命令。"""
    land = landings(html)
    pal = palette(strip_comments(md_text))
    print(f"{'色值':<10}{'角色':<24}{'总':>5}{'文字':>6}{'面':>5}{'线':>5}")
    for color, line in pal.items():
        c = land.get(color, {})
        tot = sum(c.values())
        tx = sum(v for (_, b), v in c.items() if b == "text")
        fl = sum(v for (_, b), v in c.items() if b == "fill")
        ln = sum(v for (_, b), v in c.items() if b == "line")
        print(f"{color:<10}{_label(line)[:22]:<24}{tot:>5}{tx:>6}{fl:>5}{ln:>5}")
```

在 `main()` 里，每个主题的 `rows` 组装完之后：

```python
        rows, stale = apply_exemptions(base, md_text, rows, has_corpus)
        found += rows + stale
```

并加 `--counts` 分支（在真实库模式下按主题名匹配，渲染后调 `print_counts` 并 `return 0`）。

- [ ] **Step 4: 跑测试确认 28 条全绿**

```bash
bash skills/md2publish-article/scripts/test-census-themes.sh
```
Expected: `28 通过，0 失败`

- [ ] **Step 5: 手验 --counts**

```bash
python3 skills/md2publish-article/scripts/census-themes.py --counts 12-apple-air
```
Expected: 6 行，其中 `#0071e3` 总 17 / 文字 17 / 面 0 / 线 0，`#ffffff` 总 1 / 面 1

- [ ] **Step 6: Commit（先问用户）**

```bash
git add skills/md2publish-article/scripts/census-themes.py \
        skills/md2publish-article/scripts/test-census-themes.sh
git commit -m "census-themes 加豁免机制、STALE-NOTE 按层设门、--counts 模式"
```

---

### Task 7: 对真实库跑，逐条裁决（人工介入）

**这一步不是机械劳动，条数在这一步才知道。** 设计文档第八节的「必须抓到的」那张表是硬指标；其余每一条都要人工判断是真缺陷还是正当设计。

**Files:**
- Modify: `references/theme-prompts/*.md`（写豁免注记，或改规范）——**改任何主题文件前必读 `docs/theme-design-lessons.md`，且先经用户确认**
- Modify: `references/theme-json/*.theme.json`（若改了主题 `.md` 要同步重生成）

- [ ] **Step 1: 跑全套，把报告存档**

```bash
cd ~/code/skills/writing/md2publish-skills
python3 skills/md2publish-article/scripts/census-themes.py > /tmp/census-first-run.txt 2>&1
grep -c . /tmp/census-first-run.txt
awk '{print $1}' /tmp/census-first-run.txt | sort | uniq -c | sort -rn
```

- [ ] **Step 2: 核对「必须抓到的」7 组硬指标**

```bash
for pat in "UNCARRIED.*editor-slate.*#d2a8ff" "UNCARRIED.*editor-slate.*#ffa657" \
           "UNCARRIED.*bauhaus-pop.*#1e5aa8" "UNCARRIED.*monochrome-mag.*#767676" \
           "INVENTED.*gilded-ink" "INVENTED.*terracotta-sun.*#9c8a72" \
           "UNMOUNTED.*blueprint-grid.*strong_alt" "UNMOUNTED.*cyber-neon.*strong_alt" \
           "UNMOUNTED.*ink-wash.*footer_html"; do
  grep -qE "$pat" /tmp/census-first-run.txt && echo "✅ $pat" || echo "❌ 漏了：$pat"
done
```
Expected: 全部 ✅。**任何一个 ❌ 都是判据漏了，回 Task 3/4 修脚本，不要改期望。**

- [ ] **Step 3: 逐条裁决，先分三堆**

对报告里每一条问三个问题，分堆处理：

| 判断 | 处置 |
|---|---|
| 真缺陷、这轮能修 | 改主题 `.md` + 同步 `theme.json`（**先问用户**） |
| 真缺陷、这轮不修（如需加 `md2html.py` 字段） | 写豁免注记，理由里写清楚为什么押后、记在 handoff 哪一条 |
| 正当设计 | 写豁免注记，理由要能说服下一个人 |

已知的裁决方向（设计文档第八节）：

- **`UNCARRIED` 三条的修法互不相同**，看组件规范里有没有落点来分：有落点没兑现 = 补 `theme.json`（editor-slate）；无落点 = 改 `.md` 或按规则 3 从调色板删掉（bauhaus-pop 的 `#1e5aa8` 是**错值**，该主题的蓝是 `#005baa`）；有落点但机械层无挂载点 = 按规则 14 判定加不加字段（monochrome-mag 的图注/脚注）
- **`INVERT` 7 条**预判至少 4 条是正当设计：深色变体是被对比度钉住的正文强调色（规则 11），不是缺陷。写豁免注记时那行理由本身就是留档
- **candy-pop 的主次倒置**待真机观感定夺（handoff 第六节第 3 条），写注记指过去

- [ ] **Step 4: 若改了任何主题 `.md`，重生成 theme.json 与产物**

```bash
# 改完主题 .md 之后，重新生成对应的 theme.json（人工翻译，见 md2html.py docstring 字段表），
# 再重新生成产物 HTML：
python3 skills/md2publish-article/scripts/md2html.py \
  "$MD2HTML_CORPUS/litellm-multi-provider-gateway.md" \
  skills/md2publish-article/references/theme-json/<编号>-<名>.theme.json \
  -o "$MD2HTML_CORPUS/out/<产物名>.html"
```

**`test-md2html.sh` 的 PART B 会因此变红——那是预期改动不是回归，别反过来改测试迁就它。** 确认变红的正是你改的那几个主题之后，PART B 的比对基准就是新产物。

- [ ] **Step 5: 跑到未销为 0**

```bash
python3 skills/md2publish-article/scripts/census-themes.py; echo "退出码 $?"
```
Expected: `普查完毕，0 条未销`，退出码 0

- [ ] **Step 6: 六条基线全绿**

```bash
python3 skills/md2publish-article/scripts/audit-themes.py | tail -2
bash skills/md2publish-article/scripts/test-audit-themes.sh | tail -1
bash skills/md2publish-article/scripts/test-md2html.sh | tail -1
bash skills/md2publish-article/scripts/test-census-themes.sh | tail -1
python3 skills/md2publish-article/scripts/census-themes.py | tail -1
# 产物自检
awk '/^python3 - <<.EOF.$/{f=1;next} /^EOF$/{f=0} f' \
    skills/md2publish-article/references/wechat-html.md > /tmp/selfcheck.py
for h in "$MD2HTML_CORPUS"/out/*.html; do python3 /tmp/selfcheck.py "$h" | tail -1; done | sort | uniq -c
```
Expected: 审计 0 条 / 16 绿 / 25 绿 / 28 绿 / 普查 0 条未销 / 自检全 PASS

- [ ] **Step 7: Commit（先问用户）**

```bash
git add -A skills/md2publish-article/references/
git commit -m "按普查结果裁决 N 条：修 X 处、豁免 Y 处"
```

---

### Task 8: 文档收尾

**Files:**
- Modify: `docs/theme-design-lessons.md`
- Modify: `docs/handoff/handoff.md`
- Modify: `skills/md2publish-article/references/theme-prompts/_common-tech.md`（若 Task 7 改动了主题写作约定）

- [ ] **Step 1: 回写 lessons**

判断标准（handoff 第零节）：这条结论换一篇文章、换一个主题还成立吗？成立就进 lessons。本轮至少这几条成立：

- **判据可以下窄，窄的失败方式是「跑到 0 条而缺陷还在」。** 规则 7 记的是下宽（报了大半个库），这是它的镜像。两种都要防，且**下窄更危险——它看起来像成功**
- **关键词判据靠引用某组词来定义自己时，否定词过滤会自杀。** cyber-neon 的「带『注意/警告/不要/会导致』语义的 strong」现场
- **CJK 没有词边界。** `\b` 在汉字之间永不成立，中文关键词匹配要用显式前缀黑名单
- **散文体规范是本仓库主题库的通用写作约定**（「## 收尾」节几乎清一色），判「是不是规范」要看行里有没有可机械化实体，不能看行首符号
- **测试全绿不等于行为等价。** 14 条变异用例挡不住把 `palette()` 改成「取全部色值」——fixture 的形态覆盖不到的判据改动，测试是瞎的。重构的验收要用真实库输出的逐字节 diff

在「机械审计方法」节里，把「这一步目前还是手工的，没有固化进任何脚本」那段更新为指向 `census-themes.py`，并保留那段盲区说明（它解释了为什么需要这个脚本）。

- [ ] **Step 2: 更新 handoff**

- 第三节「四条基线」→ **六条**，补 `test-census-themes.sh` 与 `census-themes.py`
- 第六节第 1 条（产物落点普查脚本）标记完成，把它从「剩下的活」移走
- 第六节第 2 条按 Task 7 的实际处置更新（ink-wash 朱砂印、cyber-neon 警示 strong 现在有档在管了）
- 第零节文档地图加一行：`docs/superpowers/specs/` 与 `docs/superpowers/plans/` 是什么、什么时候读

- [ ] **Step 3: 确认没有临时文件沉淀**

```bash
ls docs/superpowers/specs/ docs/superpowers/plans/
```
Expected: 只有设计文档和本计划。**任何 `*-findings.md` / `*-todo.md` 都要在这一步溶解**（handoff 第零节：临时发现记录不许沉淀）。

- [ ] **Step 4: 六条基线再跑一遍**

同 Task 7 Step 6。文档改动不该影响任何一条，跑一遍是确认没手滑碰到脚本。

- [ ] **Step 5: Commit（先问用户）**

```bash
git add docs/
git commit -m "普查脚本落地：lessons 补 5 条规则，handoff 基线四条改六条"
```

---

## Self-Review

**Spec coverage：** 设计文档十节逐节核对——

| 设计文档 | 由哪个任务实现 |
|---|---|
| 一、覆盖矩阵 4 格 | Task 3 Step 5（aurora-flow 形态）、Task 4 Step 5（newsprint / cyber-neon 形态）、Task 5 Step 5（apple-air 的 NEAR-ZERO） |
| 二、三层结构 | Task 3（L1）/ Task 4（L3）/ Task 5（L2） |
| 三、theme_lib 五个导出 | Task 1（前三个）+ Task 2（后四个，`element_of` 在 Task 1） |
| 四、九项检查 + 三个术语 | Task 3 / 4 / 5，术语在各自的实现代码注释里 |
| 五、豁免机制三条硬规则 | Task 6 用例 25–28 |
| 六、报告 + `--counts` + 语料缺失 | Task 5 Step 3（SKIP 标红）、Task 6 Step 3（`--counts`） |
| 七、变异测试三点要求 | Task 3 / 4 / 5 / 6 共 28 条，受控 fixture 文章在 Task 5 Step 1，真实库核对在 Task 7 Step 2 |
| 八、必须抓到的清单 | Task 7 Step 2 逐条断言 |
| 九、实施顺序六步 | Task 1–8（设计文档的第 5、6 步对应 Task 7、8） |
| 十、明确不做的 | Global Constraints |

**Placeholder scan：** 无 TBD / TODO / 「类似 Task N」。每个代码步都有可粘贴的代码块；每个测试步都有具体命令和期望输出。Task 7 Step 3 的「逐条裁决」不给死数字是**有意的**——设计文档第八节明确要求总条数在这一步才产出，写死会让测试红在设计的算术错误上。

**Type consistency：** `strip_comments` / `palette` / `element_of` / `spec_lines` / `theme_pairs` / `exemptions` / `landings` 七个 `theme_lib` 导出在 Task 1–2 定义，Task 3–6 的用法与签名一致。`check_l1` / `check_l3` 参数同为 `(name, md_text, theme)`；`check_l2` 是 `(name, md_text, html, already)`，在 Task 5 Step 3 的 `main()` 接线里对得上。发现行统一是四元组 `(档名, 主题名, 键, 一句话)`，`report()` / `apply_exemptions()` / 测试脚本的 `awk '{print $1, $3}'` 三处一致。

## 已知风险

1. **Task 3 Step 5 的真实库报数会比第一版多。** 规范行判定换轴之后，散文体规范和缩进有序行都进来了，`UNCARRIED` 的口径变宽。多出来的条目留到 Task 7 裁决，**不要在 Task 3 就急着收窄判据**——先看那批是不是真缺陷（规则 7 的判断法）。
2. **`--counts` 的 `apple-air #0071e3 = 17` 这个期望值依赖当前的 `theme.json`。** 若 Task 7 改了 apple-air，这个数会变，届时更新 Task 6 Step 5 的期望。
3. **Task 7 会让 `test-md2html.sh` PART B 变红。** 这是预期的，处置写在 Task 7 Step 4。
