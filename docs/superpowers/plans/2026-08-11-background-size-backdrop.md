# background-size 条带门 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 `contrast_lib.py` 的底色走查认出「被 `background-size` 限制成贴边条带的 `background-image`」，不再把它当成整个元素的底，从而消掉冻结基线里 6 行纯假阳、修正 1 行记错底色的真发现。

**Architecture:** 新增一个纯函数 `image_reaches_text(st)`，在 `_Walker.handle_starttag` 的调用侧拦一道——判为 `False` 时不把 `background-image` 传给 `backdrop_samples()`。`backdrop_samples()` 的签名与语义一个字不动，它身上那批既有断言（渐变插值顺序、硬停、alpha 合成）不受影响。

**Tech Stack:** Python 3 标准库（`re`、`html.parser`）。无第三方依赖。测试是本仓库自己的断言式脚本，不用 pytest。

## Global Constraints

以下约束逐字来自 spec（`docs/superpowers/specs/2026-08-11-background-size-backdrop-design.md`），每个任务都隐含包含：

- **判据的说法必须逐字等于实现。**不许出现「文档写的理由 ≠ 代码里的判据」（lessons「判据可以下窄」那一节的教训）。
- **`image_reaches_text` 默认返回 `True`。**四条必要条件里任何一条判不出来（属性缺失、单位不是 px、值不认识、多层背景），一律倒向 `True` = 保留图像。这个判据**只可能多报，不可能藏发现**。
- **不许复用 `contrast_lib._px()`。**它解析失败时静默返回调用方给的 default，会把「解析不出来」变成「等于某个数」；本判据的两个用处（条带高度、padding）失败方向相反，静默默认值会各错一次。必须用解析不出来就返回 `None` 的严格助手。
- **一条 fixture 只钉一个键。**不要把 `repeat` 和 `cover` 写进同一份样式串去钉两条——只改其中一个时另一个仍让判定为假，用例根本不红（lessons 的附带纪律）。
- **变异测试纪律：**写完一条用例，先说出一个「这里错了也能让这条用例照样通过」的实现，再真的去改代码验证它红。覆盖到不等于钉住。
- **不做真实布局、不做 `px` ↔ `%` 换算、不碰 `background-attachment` / `background-clip` / `background-origin`、不引入 `contrast-ok` 豁免注记。**
- **红线：`git commit` 前必须经用户确认。**本计划每个任务末尾的 Commit 步骤都要先停下来问。
- **改动只 `git add <具体路径>`，永不 `git add -A`。**`main` 上有另一个会话（图片 skill 线）在并行提交，两条线交错。

---

## File Structure

| 文件 | 责任 | 本计划怎么动 |
|---|---|---|
| `skills/md2publish-article/scripts/contrast_lib.py` | 色彩原语 + DOM 底色走查 | **改**：加 `_px_or_none`、`_padding_side`、`image_reaches_text` 三个纯函数（Task 1）；`_Walker.handle_starttag` 接线（Task 2） |
| `skills/md2publish-article/scripts/test-contrast-lib.py` | 上者的单元测试 | **改**：加 14 条断言（Task 1） |
| `skills/md2publish-article/references/contrast-baseline.tsv` | 冻结基线 | **改**：116 → 109 → 110（Task 2） |
| `docs/handoff/handoff.md` | 每轮重写的状态文档 | **改**：基线 9 的期望数字、第六节第 2 条（Task 3） |
| `docs/theme-design-lessons.md` | 只增不删的判据与规则 | **改**：已知局限那一段补这条（Task 3） |

`test-contrast-themes.sh` **不动**：它的 `real-library` 用例（`:403`）拿脚本本轮输出条数与基线**文件行数**动态比对（`$actual_n`），两边一起变；而且它顺带钉死了「压根没这道门」这个错误实现——去掉门之后产物侧回到 116 条、基线 110 条，该用例立刻红。

---

## Task 1: 判据纯函数 + 单元测试

**Files:**
- Modify: `skills/md2publish-article/scripts/contrast_lib.py`（在 `_weight()` 之后、`class _Walker` 之前插入三个函数）
- Test: `skills/md2publish-article/scripts/test-contrast-lib.py`（在「非字符串字段值」那一节之后、「── 阈值 ──」之前插入）

**Interfaces:**
- Consumes: `contrast_lib.parse_style(s) -> dict`（已存在，键小写）
- Produces:
  - `_px_or_none(v: str | None) -> float | None`
  - `_padding_side(shorthand: str | None, side: str) -> float | None`，`side` 取 `"top"` / `"bottom"`
  - `image_reaches_text(st: dict) -> bool`，Task 2 在 `_Walker.handle_starttag` 里调用

---

- [ ] **Step 1: 写失败的测试**

打开 `skills/md2publish-article/scripts/test-contrast-lib.py`，在这两行之后：

```python
ok("字段值全正常时一个字都不打（不许狼来了）", _quiet.getvalue() == "")
```

插入下面整段（`# ── 阈值 ──` 那一节之前）：

```python
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
```

- [ ] **Step 2: 跑测试，确认它红，且红在预期原因上**

```bash
cd ~/code/skills/writing/md2publish-skills
python3 skills/md2publish-article/scripts/test-contrast-lib.py
```

预期：`AttributeError: module 'contrast_lib' has no attribute 'image_reaches_text'`。

**这一步不许跳过。**看不见红，就不知道这批断言到底有没有在断言——本仓库有过一整条判断分支是死代码、34 条用例一条不挂的先例（lessons「变异测试要能证明自己真的挡住了那个错误实现」）。

- [ ] **Step 3: 写实现**

打开 `skills/md2publish-article/scripts/contrast_lib.py`，在 `_weight()` 函数之后、`class _Walker(HTMLParser):` 之前插入：

```python
def _px_or_none(v):
    """严格版长度解析：只认 `<数字>px`，别的一律 None。

    **不要用上面的 `_px()`**：它解析失败时返回调用方给的 default，会把
    「解析不出来」变成「等于某个数」。这里两个用处的失败方向正好相反
    （条带高度算大了会放行、padding 算小了会拦住），静默默认值会各错一次。
    `padding: 0` 这种合法的无单位零也判 None——倒向「保留图像」，方向安全。
    """
    m = re.fullmatch(r"\s*([\d.]+)px\s*", v or "")
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
```

- [ ] **Step 4: 跑测试，确认全绿**

```bash
python3 skills/md2publish-article/scripts/test-contrast-lib.py
```

预期：`ok：0 条失败`，exit 0，`ok` 行数从 69 变成 **89**（新增 20 条）。

- [ ] **Step 5: 变异验证——证死每一条判据**

这是本仓库的硬纪律：没证死错误实现的测试不算护栏。**在临时副本上改，不要直接改工作树**（本机 `cp` 带交互别名，还原一律用 `/bin/cp -f`）。

```bash
cd ~/code/skills/writing/md2publish-skills/skills/md2publish-article/scripts
SP=/tmp/mut && mkdir -p $SP && /bin/cp -f contrast_lib.py $SP/contrast_lib.py.bak
```

逐个做下面 6 种变异，每次跑 `python3 test-contrast-lib.py`，记下**红了几条、红的是哪几条**，然后 `/bin/cp -f $SP/contrast_lib.py.bak contrast_lib.py` 还原：

| 变异 | 怎么改 | 预期变红的断言 |
|---|---|---|
| 去掉整道门 | `image_reaches_text` 直接 `return True` | 「四条全中」「position bottom」「padding 长写法优先」「三值简写 bottom」4 条 |
| 忽略 repeat | 删掉条件 1 整个 `if` | 「显式 repeat」「不写 background-repeat」2 条 |
| 忽略 size | 把条件 2 整段换成 `strip_h = 0`（**不要直接删**——后面还引用 `strip_h`，删了是 `NameError` 而不是「错误实现」） | 「不写 background-size」「百分比」「auto」「cover」「contain」「单分量」「多层」7 条 |
| 忽略 position | 把 `pad_key` 固定成 `"padding-top"` | 「center」「不写 position」「三值简写 bottom」3 条 |
| 不看 padding | 条件 4 改成 `return False` | 「padding 为 0」「2em」「2px」「三值简写 top」4 条 |
| 简写取错侧 | `_padding_side` 里 `bottom` 也返回 `parts[0]` | 「三值简写 bottom」1 条 |

**每一种都必须真的变红。**哪一种全绿，就说明对应的断言没钉住任何东西，回去补用例——不要改判据去迁就。

- [ ] **Step 6: 还原并核对**

```bash
/bin/cp -f $SP/contrast_lib.py.bak contrast_lib.py
cd ~/code/skills/writing/md2publish-skills
/usr/bin/git diff --stat skills/md2publish-article/scripts/contrast_lib.py
python3 skills/md2publish-article/scripts/test-contrast-lib.py | tail -2
```

预期：diff 里只有本任务加的三个函数，测试 `ok：0 条失败`。

- [ ] **Step 7: 确认真实库此刻还没变**

判据函数已存在但**还没接线**，所以对比度普查应该一个数都没变。

```bash
python3 skills/md2publish-article/scripts/contrast-themes.py; echo "exit=$?"
```

预期：`116 条不达标，基线 116 条`、`无新增`、exit 0。**如果这里已经变了，说明你不小心把 Task 2 的接线一起做了，停下来。**

- [ ] **Step 8: 提交（先问用户）**

```bash
/usr/bin/git add skills/md2publish-article/scripts/contrast_lib.py \
                 skills/md2publish-article/scripts/test-contrast-lib.py
/usr/bin/git commit -F - <<'MSG'
feat(contrast): add image_reaches_text, the background-size strip gate

A pure predicate, not yet wired in: it answers whether an element's
background-image can sit behind that element's own text. It returns True by
default and only returns False when four conditions all hold — no-repeat, a
background-size with two components whose height is a fixed px length, a
background-position of exactly top or bottom, and padding on that side that is
px and at least the strip height. Every unresolved case falls back to True, so
the gate can only over-report and can never hide a finding.

Ships with two strict helpers. _px_or_none deliberately does not reuse _px:
_px returns the caller's default on a parse failure, which would turn "cannot
parse" into "equals some number", and the two uses here fail in opposite
directions. _padding_side reads the top or bottom value out of the padding
shorthand across all four CSS forms.

20 assertions, each mutation-verified: removing the gate, ignoring repeat,
ignoring size, ignoring position, skipping the padding check, and reading the
wrong side of the shorthand each turn a distinct set red.

The contrast census is untouched at 116 findings / 116 baseline rows — the
call site changes in the next commit.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
```

---

## Task 2: 接线 + 基线三步

**Files:**
- Modify: `skills/md2publish-article/scripts/contrast_lib.py:206-207`（`_Walker.handle_starttag` 里 `backdrop_samples(...)` 那两行）
- Modify: `skills/md2publish-article/references/contrast-baseline.tsv`（116 → 109 → 110）

**Interfaces:**
- Consumes: `image_reaches_text(st) -> bool`（Task 1）
- Produces: 基线文件 110 行；`contrast-themes.py` 默认路径 exit 0

---

- [ ] **Step 1: 接线**

`contrast_lib.py` 的 `_Walker.handle_starttag` 里，把这两行：

```python
            backdrop_samples(st.get("background-color") or st.get("background"),
                             st.get("background-image"), samples),
```

改成：

```python
            # 被 background-size 限制成贴边条带、且文字够不到的图像不算底色
            backdrop_samples(st.get("background-color") or st.get("background"),
                             st.get("background-image") if image_reaches_text(st) else None,
                             samples),
```

- [ ] **Step 2: 跑普查，确认发现数变了、且方向对**

```bash
cd ~/code/skills/writing/md2publish-skills
python3 skills/md2publish-article/scripts/contrast-themes.py; echo "exit=$?"
```

预期：**110 条不达标、基线 116 条、报「新增 1 条」、exit 1**。

⚠️ **这个 exit 1 是预期的**，不是回归。新增的那一条应当是
`21-aurora-flow  span  #38c6d9  #ffffff  ...  2.05`——同一个真发现换上了正确的底。

- [ ] **Step 3: 人工确认那条新增行确实是换键，不是真新增**

```bash
grep -n "aurora-flow" skills/md2publish-article/references/contrast-baseline.tsv
```

对着基线里 aurora-flow 的 12 行，逐条核对下面这张表——**必须一条一条对上，不许只看总数**：

| 基线原行 | 本轮应该 |
|---|---|
| `h3 #33344a #6a5cff` | 消失（白底 12.13:1，达标） |
| `p #33344a #6a5cff` | 消失（同上） |
| `td #33344a #6a5cff` | 消失（同上） |
| `span #6a5cff #6a5cff` | 消失（白底 4.58:1，达标） |
| `strong #6a5cff #6a5cff`（15.5px） | 消失（同上） |
| `strong #6a5cff #6a5cff`（14px） | 消失（同上） |
| `span #38c6d9 #38c6d9` | **换键**成 `span #38c6d9 #ffffff`，比值 2.05，装饰阈值 3.0，**仍不达标** |
| 其余 5 行（底是 `#ecebfb` / `#38c6d9` 的 h2） | 一行不动 |

**其他 19 个主题的行必须一行不变。**若有变化，停下来——那说明这道门误伤了别的主题，回 Task 1 查条件 1。

- [ ] **Step 4: `--prune`，应得 109**

```bash
python3 skills/md2publish-article/scripts/contrast-themes.py --prune
wc -l < skills/md2publish-article/references/contrast-baseline.tsv
```

预期：文件行数 **109 + 4 行注释 + 1 行表头 = 114**（原先是 121）。
即数据行 116 → **109**。

⚠️ **中途这个 109 是预期值，不是算错了。**`--prune` 删的是 7 行：6 行纯假阳 + 换键那行的**旧**键（它同样从产物侧消失了，而 `prune_survivors` 只留「基线里有 **且** 本轮仍出现」的行）。

- [ ] **Step 5: `--write-baseline`，应得 110**

```bash
python3 skills/md2publish-article/scripts/contrast-themes.py --write-baseline
```

预期：它会先打印「相对旧基线新增 1 条组合」并把那一行列出来——**核对它就是 Step 3 里那条 `span #38c6d9 #ffffff`**，然后才写文件。

- [ ] **Step 6: 逐行读 diff（这一步是唯一的护栏，不许跳）**

```bash
/usr/bin/git diff skills/md2publish-article/references/contrast-baseline.tsv
```

`--write-baseline` 会重写整份文件（重新排序、刷新参考列的比值与计数），所以 diff 又大又吵。**要确认的只有三件事**：

1. 删掉的 7 行就是 Step 3 表里那 7 行，一行不多
2. 新增的 1 行就是 `span #38c6d9 #ffffff`，一行不多
3. 其余 19 个主题的行只有排序/参考列抖动，**键（前 7 列）一个字没变**

「只许减、不许增」这条纪律脚本管不了。**这一步是它唯一的护栏。**

- [ ] **Step 7: 跑全套十条基线**

```bash
cd ~/code/skills/writing/md2publish-skills
for c in "python3 skills/md2publish-article/scripts/audit-themes.py" \
         "bash skills/md2publish-article/scripts/test-audit-themes.sh" \
         "bash skills/md2publish-article/scripts/test-md2html.sh" \
         "bash skills/md2publish-article/scripts/test-census-themes.sh" \
         "python3 skills/md2publish-article/scripts/census-themes.py" \
         "python3 skills/md2publish-article/scripts/test-theme-lib.py" \
         "python3 skills/md2publish-article/scripts/test-contrast-lib.py" \
         "bash skills/md2publish-article/scripts/test-contrast-themes.sh" \
         "python3 skills/md2publish-article/scripts/test-contrast-cli.py" \
         "python3 skills/md2publish-article/scripts/contrast-themes.py"; do
  eval "$c" >/dev/null 2>&1; printf 'exit=%s  %s\n' "$?" "${c##*/}"
done
```

预期：**十条全部 exit 0**。特别是：

- `test-contrast-themes.sh` 的 `real-library` 用例现在比对的是 110 对 110
- `contrast-themes.py` 报 `110 条不达标，基线 110 条`、`无新增`
- `test-md2html.sh` 仍是 25 通过（本任务不碰产物，PART B 不该变）

- [ ] **Step 8: 提交（先问用户）**

```bash
/usr/bin/git add skills/md2publish-article/scripts/contrast_lib.py \
                 skills/md2publish-article/references/contrast-baseline.tsv
/usr/bin/git commit -F - <<'MSG'
fix(contrast): stop treating a background-size strip as the backdrop for text

Wires image_reaches_text into the DOM walk. aurora-flow's card paints its
gradient as a 4px strip at the top (no-repeat, background-size 100% 4px,
position top) over a white card, but the walk had no notion of background-size
and handed the gradient to every text node inside as its backdrop.

Seven baseline rows carried the wrong background. Six of them pass on the real
white card and were pure false positives: h3, p and td at #33344a are 12.13:1
rather than the recorded 2.65:1, and strong and span at #6a5cff are 4.58:1
rather than the recorded 1.00:1. The alarming "1.00:1 across 55 occurrences"
was never disappearing text — it was a 4px decorative rule being read as the
whole card.

The seventh row stays a finding but changes key: span #38c6d9 measured against
#38c6d9 becomes #38c6d9 against #ffffff, 2.05:1, still under the 3.0 decor
threshold. Because the baseline key includes the background, that is a removal
plus an addition rather than an edit, so it took --prune (116 to 109) followed
by --write-baseline (109 to 110), with the intermediate 109 expected and the
resulting diff read line by line.

The other nineteen themes are untouched. Measured across all 26: only
aurora-flow's card trips all four conditions; the tiling textures in
autumn-warm, ocean-calm, spring-fresh and blueprint-grid declare no
background-repeat, so they default to repeat and genuinely do cover their text.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
```

---

## Task 3: 文档回写

**Files:**
- Modify: `docs/handoff/handoff.md`（第三节基线 9、第六节第 2 条）
- Modify: `docs/theme-design-lessons.md`（「机械审计方法」节的已知局限那一段，约 `:356`）

**Interfaces:** 无代码接口。

⚠️ **动手前先 `git pull` / 看 `git status`**：另一个会话（图片 skill 线）也在改 `docs/handoff/handoff.md`。若它有未提交改动，先问用户，不要覆盖。

---

- [ ] **Step 1: 改 handoff 第三节基线 9 的期望数字**

把基线 9 注释里的 `116 条不达标、116 条基线` 改成 `110 条不达标、110 条基线`。
第六节第 2 条里所有出现 **116** 的地方同样改成 **110**，并在该条开头加一段：

```markdown
**⚠️ 116 这个数里有 6 条是判据假阳，2026-08-11 已修，现为 110。**
`contrast_lib.py` 原先不认 `background-size`，把 aurora-flow 卡顶那条 4px 渐变
当成了整张卡的底，7 行的底判错——6 行在真实白底上其实达标（`#33344a` 12.13:1、
`#6a5cff` 4.58:1），第 7 行发现仍成立但底与比值都记错。判据、四条必要条件、
以及「为什么 `no-repeat` 是唯一承重的那条」见
`docs/superpowers/specs/2026-08-11-background-size-backdrop-design.md`。
**这是对比度护栏落地后发现的第一处判据缺陷，不是主题缺陷。**
```

- [ ] **Step 2: 改 lessons 的已知局限**

在 `docs/theme-design-lessons.md` 「机械审计方法」节那句「**已知的局限，不要把它读成完整性证明**」所在段落的末尾，追加：

```markdown
2026-08-11 又补上一条**曾经不在这张清单里的局限**：走查原先完全不认
`background-size` / `background-repeat` / `background-position`，只要看见
`background-image` 是渐变，就当它铺满整个元素。aurora-flow 的卡顶 4px 装饰条
因此被读成整张卡的底，制造了 6 行纯假阳（339 处）——其中最扎眼的
`1.00:1 / 55 处` 看着像「文字消失」，实际只是判据把一条装饰线当成了底。
现由 `image_reaches_text()` 拦下，判据是「图像被限制成贴边条带 **且** 该侧
padding 保证文字够不到它」，四条必要条件缺一都倒向「保留图像」。
**留给后来者的通则：一个数字大得吓人的发现，先怀疑判据，再怀疑主题。**
本项目此前所有教训都在讲「别把 0 读成完工」；这一条是它的镜像——
**也别把一个很低的比值直接读成很严重的缺陷**，先确认量的是不是对的东西。
```

- [ ] **Step 3: 通读 diff**

```bash
/usr/bin/git diff docs/
```

按契约 16 逐行读。特别检查：handoff 里所有 116 是不是都改到了（`grep -n "116" docs/handoff/handoff.md` 应当只剩讲历史的地方，且上下文说得清那是旧数）。

- [ ] **Step 4: 提交（先问用户）**

```bash
/usr/bin/git add docs/handoff/handoff.md docs/theme-design-lessons.md
/usr/bin/git commit -F - <<'MSG'
docs: record the background-size limitation and drop the baseline to 110

handoff: baseline 9 now expects 110 findings against 110 baseline rows, and
section 6.2 opens by saying six of the original 116 were a criterion false
positive rather than a backlog item.

lessons: the known-limitations paragraph gains the limitation that was missing
from it — the walk did not model background-size, background-repeat or
background-position, so any gradient was treated as covering its whole
element. The general lesson is the mirror of this project's usual one: it has
always warned against reading a 0 as done; this one warns against reading a
very low ratio as very broken. Check what is being measured first.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
```

---

## Self-Review

**Spec coverage** — spec 八节逐节核对：

| Spec 节 | 落在哪 |
|---|---|
| 一、问题 | Task 2 Step 1 的接线注释 + Task 3 的 lessons 段落 |
| 二、证据（7 行明细） | Task 2 Step 3 的逐行核对表 |
| 三、判据四条 + 全库实测 | Task 1 Step 3 的实现与 docstring；条件 1 承重的理由写进了代码注释 |
| 四、接口（不动 `backdrop_samples`）+ 不复用 `_px` | Task 1 Step 3；`_px_or_none` 的 docstring 写死了理由 |
| 五、测试（11 种错误实现） | Task 1 Step 1 的 20 条断言 + Step 5 的 6 组变异；#1 由 `test-contrast-themes.sh` 既有的 `real-library` 承担（File Structure 里说明了为什么不加用例） |
| 六、基线三步 116→109→110 | Task 2 Step 4–6，含「109 是预期值」的警告 |
| 七、明确不做的 | Global Constraints 逐条列了 |
| 八、已知局限（含负 margin 前提） | Task 3 Step 2 |

**缺口**：spec §八 那条「负 margin 会破坏 padding 证明」只写进了 lessons，没有测试钉住——**这是有意的**：真实库负 margin 0 处，没有样本就没有能钉住它的用例（spec §八 自己也是这么说左右条带的）。记在这里，免得下一轮 review 当成漏项。

**Placeholder scan**：无 TBD / TODO / 「类似 Task N」/ 无代码的代码步骤。Task 1 Step 1 里那处语法错误是**有意的**，Step 2 明写了要先看见它。

**Type consistency**：三个函数在 Task 1 定义、Task 2 只调用 `image_reaches_text`，名字与签名前后一致；`_STRIP_SIDES` 的值（`padding-top`/`padding-bottom`）与 `_padding_side` 的 `side` 参数（`top`/`bottom`）通过 `pad_key.rsplit("-", 1)[1]` 衔接，已在 Task 1 Step 3 的代码里写死。
