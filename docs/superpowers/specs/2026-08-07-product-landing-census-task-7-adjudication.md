# Task 7 裁决建议书（只出建议，未改任何文件）

> ## 迁移说明（2026-08-09 补写，读者请先看这一段）
>
> 本文件从仓库外、被 gitignore 的 SDD 项目工作区迁移进 `docs/`，只为了在条目被逐一处理完之前
> 保留可追溯的执行细节；迁移本身不代表内容被重新审核或被采纳。三条务必记住：
>
> 1. **这是一份建议清单，不是裁决记录。** 除下面标了「✅ 已处理」的六条外，其余条目
>    **没有一条经过用户拍板**——原样保留当时的建议文本，读的时候当待办，不要当结论。
> 2. **本文件是临时文件，会被删除。** 待它记录的条目全部处理完（或被拍板为不处理）后，
>    应当删除本文件；不要把它当长期文档来维护或引用。
> 3. **`docs/handoff/handoff.md` 第六节第 1.1–1.6 条是权威摘要。** 那是本文件溶解、压缩
>    后的结论版本；本文件是它背后可选的执行细节。**若两者叙述不一致，以 handoff.md 为准。**
>
> ---
>
> 本文件是**建议**，不是已执行的改动。执行者按用户拍板后的结论去改；本轮除本文件外
> 没有创建、修改、删除任何文件（`references/theme-prompts/*.md`、
> `references/theme-json/*.theme.json`、任何脚本、任何 commit 都没碰）。
>
> 依据：`docs/theme-design-lessons.md` 规则 1–14 与判例、
> `docs/superpowers/specs/2026-08-07-product-landing-census-design.md` 第八节、
> `task-5-report.md` 的 (a)/(b)/(c) 分类、`progress.md` 里标注「Task 7 必读」的三条。
>
> **共同风险（所有「改主题文件」类建议都适用）**：主题 `.md` 与 `theme.json` 喂的是
> 确定性转换器 `md2html.py`。改错一个值，**此后每一篇用该主题生成的文章都会跟着错**，
> 而且错法是静默的（样式属性都在、值也都对，只是不是你想要的那个）。凡本文标注
> 「改 theme.json」的，改完必须重跑 `census-themes.py` + 产物自检 + `test-md2html.sh`
> （PART B 会变红，那是预期改动，不是回归）。

---

## 一、一句话结论

> **✅ 批次 1b 进度更新（2026-08-09）**：又有 **20 条**被用户拍板并执行——§2 的 18 条
> （**改判据**，按本文建议的挂载键方案，不走备选的批量豁免）与 §5.1 的 2 条
> （**走 (B) 路**，两支金补进 `gilded-ink.md`，产物逐字节不变）。§9.4 的
> `NEAR-ZERO 19-candy-pop #e8f2f9` **被裁定为真缺陷**（用户自述除特殊情况外不用斜体，
> 规则 1 成立，Task 5 的「语料覆盖度」读法作废），但**三条候选修法主题规范一条都推不出来**，
> 执行者按指令停手未动文件——细节转记进 `handoff.md` 第六节 1.5。
> **普查现在报 17 未销 + 5 已豁免（仍 exit 1）。**
>
> **✅ 批次 1a 进度更新（2026-08-09，commit `bf65ac1`）**：下面表格与全文是本文件最初写成
> 时的快照（43 + 1 = 44 条待裁）。其中 **6 条已被用户拍板并执行**：
> `bauhaus-pop strong_alt`（§十，豁免）、`editor-slate` 的 `#d2a8ff`/`#ffa657`/`#ffffff`/
> `#bc4c00`（§七全部四条，豁免）、`celadon-scroll h2_suffix_html`（§3.4，**真改** `theme.json`，
> 产物已变）。**普查现在报 37 未销 + 5 已豁免（仍 exit 1）**，不再是 43。下文各处仍写着
> 当时的建议原文，遇到这六条时以本条与各自小节里补写的「✅ 已处理」标记为准。

本次跑出 **43 条**，加上 **1 条脚本原理上抓不到的真缺陷**（cyber-neon 提示卡品红），
共 **44 条**待裁。（**此计数为历史快照，见上方进度更新。**）

| 处置 | 条数 | 说明 |
|---|---:|---|
| 判据问题 → 改脚本 | 18 | 全是「背景色只挂在 `container`」的结构性 NEAR-ZERO。规则 7 直接适用：一个检查项报了 27 个主题里的 18 个 |
| 真缺陷 → 改 `theme.json`（不动 `.md`） | 7 | 5 条 UNMOUNTED + terracotta-sun 的 INVENTED + cyber-neon 的 `alert` |
| 真缺陷 → 改主题 `.md`（须同步/复核 `theme.json`） | 3 | bauhaus-pop 错值 1 条 + gilded-ink 现造色 2 条 |
| 正当设计 → 写豁免注记 | 11 | 6 条 INVERT + editor-slate 4 条 + bauhaus-pop `strong_alt` 误报 |
| 待定 → 需用户决定 | 5 | monochrome-mag 2 条、candy-pop 2 条、botanic-press 1 条 |
| **合计** | **44** | |

把「改脚本」换成「批量写 18 条豁免注记」的话，豁免数变 29、判据问题变 0；两种走法都
合规，取舍见 §2。

**信心分布**：§2（18 条）、§3（5 条 UNMOUNTED）、§4（bauhaus 错值）、§5.2
（terracotta 现造色）、§7.1（editor-slate 两条 UNCARRIED）、§8（cyber-neon 提示卡）
是**机械事实驱动的高信心**建议；§6（INVERT）、§5.1（gilded-ink 现造色）、§9（待定五条）
含美学判断，请用户过目。

---

## 二、【18 条】结构性 NEAR-ZERO：背景色只挂在 `container`

> **✅ 已处理（改判据，批次 1b，复审后修正过一轮）**：用户拍板走「改脚本」这条，
> 不走备选的 18 条豁免注记。最终落地的判据是
>
> ```python
> "container" in mounts and mounts <= {"container", "footer", "footer_html"}
> ```
>
> 判定用**子集**而不是 `any()`。实测 19 条 NEAR-ZERO → 1 条，`ZERO` 未动，
> candy-pop 那条照报。
>
> **本节建议的 `STRUCTURAL_KEYS = {"container", "footer_html"}` 不要照抄。**
> 它没有 `container` 锚点，留了一个真洞：主题若把唯一强调色**只**声明在
> `footer_html` 里，落点恰为 1，会被静默——正是 apple-air 立项缺陷的形状。
> 更根本的是理由错了：`footer` 与 `footer_html` 同属文末那一个 `<p>`、由同一个
> `if` 守着，**次数**跟 `container` 一样固定 ≤1，所以「build() 只发一次」推不出
> 这个集合；真正的区分性质是**面积/角色**——`container` 铺满整页，落 1 次等于
> 全覆盖。详见 lessons「判据可以下窄」节。
>
> 变异用例也不止本节提的两条：一共补了 7 条（54 → 62），逐一证死了十种错误实现。

**发现**（全部 WARN）：

```
NEAR-ZERO  01-autumn-warm    #faf9f5     NEAR-ZERO  15-mint-breeze    #eef7f2
NEAR-ZERO  02-ocean-calm     #f0f4f8     NEAR-ZERO  17-scarlet-tech   #ffffff
NEAR-ZERO  03-spring-fresh   #f5f8f5     NEAR-ZERO  18-midnight-study #211c18
NEAR-ZERO  04-ink-wash       #f7f6f2     NEAR-ZERO  20-monochrome-mag #ffffff
NEAR-ZERO  07-coffee-journal #f3ede4     NEAR-ZERO  21-aurora-flow    #f4f4fb
NEAR-ZERO  08-morandi-fog    #eeecea     NEAR-ZERO  25-washi-spring   #faf6f2
NEAR-ZERO  10-lavender-dusk  #f6f4f9     NEAR-ZERO  26-velvet-stage   #1d1216
NEAR-ZERO  12-apple-air      #ffffff     NEAR-ZERO  27-retro-phosphor #0d120d
NEAR-ZERO  13-cyber-neon…    #0f1420     NEAR-ZERO  14-celadon-scroll #f6f0e2
```

### 建议处置：**判据问题 → 改脚本**（备选：批量豁免）

**已独立复核的机械事实**（我逐个主题把色值回溯到 `theme.json` 的键，不是抄报告）：

| 主题数 | 该色在 `theme.json` 里的挂载键 | 产物落点 |
|---|---|---|
| 17 | 只有 `container` | 恒 1 |
| 1（`27-retro-phosphor`） | `container` + `footer_html` | 恒 2 |

`md2html.py` 的 `build()` 只拼一个最外层容器 `<div>`、只拼一个文末 `<p>`，
**这两个数字不随文章长度变化**：换一篇 10 万字语料照样是 1 和 2。容器背景出现 1 次
不是「几乎没出现」，它铺满整页——这一档的设计意图（抓 apple-air 那种「本该显眼却
只落 1 次的强调色」）与结构性背景色完全无关。

**规则 7 在这里是正面适用的**：「一个检查项报了大半个库，通常是判据下宽了，不是库烂了
——先去看那 15 个是不是真缺陷，再决定改库还是改判据。」我按这条去看了：18 个全部
不是缺陷，且不是「碰巧不是」，是**结构上不可能是**。

**建议的判据（严格满足 Task 5 复审给出的五条约束）**：

在 `check_l2` 里给 `NEAR-ZERO` 那一档（**只有这一档**）加一道门，判定依据是
**该色在 `theme.json` 里的挂载键集合**，不是调色板标签：

```python
# 需要把 theme 传进 check_l2，复用本文件已有的 json_colors()
STRUCTURAL_KEYS = {"container", "footer_html"}   # build() 各只发射一次的键
...
if total <= 2:
    if json_colors(theme).get(color, set()) <= STRUCTURAL_KEYS:
        continue          # 结构性单点，不报
    found.append(("NEAR-ZERO", ...))
    continue
```

逐条核对约束：

| 约束 | 是否满足 | 为什么 |
|---|---|---|
| 只作用于 NEAR-ZERO | ✅ | 门加在 `total <= 2` 分支内 |
| 只对背景角色 | ✅ | 用挂载键判，比标签判更严——`container`/`footer_html` 就是背景/装饰位 |
| 不得按 `REF_EXCLUDE` 元组判 | ✅ | 完全没有用到这个词表 |
| `ZERO` 一律不动 | ✅ | `total == 0` 分支在门之前就 `continue` 了 |
| candy-pop 的 `em` 必须继续报 | ✅ | `#e8f2f9` 挂载键是 `{"em"}`，不是子集，照报 |

**为什么不能按标签判**（这是本节最要紧的一条，请务必留意）：candy-pop 的
`#e8f2f9` 调色板标签是「**浅蓝底**」——含「底」。任何按「标签里有『底/背景』就豁免」
写的判据，都会连带灭掉 candy-pop 这条必须保留的发现。**按标签判和按 `REF_EXCLUDE`
判一样危险，只是词表不同。**

**这个判据改动必须配变异测试**（规则：新增/修改检查项必配变异）：至少两条——
(1) 把 `STRUCTURAL_KEYS` 扩到含 `"em"`，`l2` 里 candy-pop 形态的用例必须挂；
(2) 把门从 `total <= 2` 分支挪到循环开头（即误伤 `ZERO`），`l2-zero` 必须挂。

### 备选：不改脚本，写 18 条豁免注记

在每个主题 `.md` 的调色板那一行后面加：

```
<!-- census-ok: NEAR-ZERO #faf9f5 背景只挂 container，build() 只发一个容器 div，落点恒为 1 与文章长度无关 -->
```

（`27-retro-phosphor` 的理由改成「挂 container + footer_html，两处都只发射一次，落点恒为 2」。）

**取舍**：豁免路子零脚本风险，但要在 18 个文件里写 18 条几乎一样的注记，而且把一个
「判据下宽了」的事实永久转成 18 处沉默——下一个主题新增时会第 19 次报同样的东西。
**我推荐改脚本**，因为规则 7 说的正是这种情况；但这是本文里唯一一条我建议动判据的，
请用户明确拍板。若拍板走豁免，18 条注记文本按上面模板即可。

---

## 三、【5 条】UNMOUNTED 真缺陷：规范写了、`md2html.py` 有字段、`theme.json` 没挂

这 5 条的共同形态：主题 `.md` 里白纸黑字的规范条款，`md2html.py` **确有对应字段**
（我逐个 grep 确认过实现点，不只是 docstring 里写着），只是 `theme.json` 漏了。
**规则 14 的三条准入线全部满足**（机械可判 ✓ 无替代表达 ✓ 当前静默丢失 ✓），
所以修法是补 `theme.json`，不是改规范。

**共同优点：全部只动 `theme.json`，不动 `.md`，因此不存在「改了 `.md` 忘了重生成」
的失步风险**；用到的色值全部已在各自调色板里，不会引入新的 `INVENTED`。

### 3.1 `UNMOUNTED 04-ink-wash footer_html`（硬清单）

依据 `ink-wash.md:47`。往 `04-ink-wash.theme.json` 加：

```json
"footer": "text-align: center; color: #b5432a; font-size: 18px; margin: 40px 0 0",
"footer_html": "<span style=\"border: 1px solid #b5432a; display: inline-block; padding: 2px 6px; font-size: 13px; letter-spacing: 0;\">完</span>"
```

⚠️ **陷阱**：`footer` 恒定被算进 `boxed_keys`（`census-themes.py:88`），
所以 **`display: inline-block` 只能写在 `footer_html` 的内层 `<span>` 上，绝不能写进
`footer`**——否则触发 `INLINE-BLOCK`（arena-charge 判例）。washi-spring 就是这么写的，
是已验证无害的先例。

### 3.2 `UNMOUNTED 13-cyber-neon-v7-edge strong_alt`（硬清单，覆盖矩阵四缺陷之一）

依据 `cyber-neon.md:36`，原文把关键词列全了。往
`13-cyber-neon-v7-edge.theme.json` 加：

```json
"strong_alt": {"keywords": ["注意", "警告", "不要", "会导致"],
               "style": "color: #ff4ba3; font-weight: 600"}
```

关键词逐字取自规范原句「原文里带「注意 / 警告 / 不要 / 会导致」这类警示语义的 `strong`」。
这条同时兑现 `cyber-neon.md:35` 的「品红在正文里的落点，按这个顺序找，**不要依赖 em**」
——即规则 1。

### 3.3 `UNMOUNTED 22-blueprint-grid strong_alt`（硬清单）

依据 `blueprint-grid.md:35`。往 `22-blueprint-grid.theme.json` 加：

```json
"strong_alt": {"keywords": ["注意", "警告", "易错"],
               "style": "color: #b26a1b; font-weight: 700"}
```

关键词取自原句「原文里带"注意、警告、易错"语义的」。`blueprint-grid.md:36` 明写
「批注橙褐的文字落点不能只有斜体……那样这个色就只剩虚线框」——现状恰好就是它自己
警告的那个状态。

### 3.4 `UNMOUNTED 14-celadon-scroll h2_suffix_html`

> **✅ 已处理（真修，commit `bf65ac1`）**：按下面的建议原样执行，`14-celadon-scroll.theme.json`
> 已加上 `h2_suffix_html`，HTML 已重生成，`test-md2html.sh` 已过。这条**改变了产物**，
> 不是豁免。

依据 `celadon-scroll.md:28`：h2 是「居中 + **两侧**对称饰线」，`theme.json` 只有
`h2_prefix_html`，右侧那根线在产物里根本不存在——不对称。往
`14-celadon-scroll.theme.json` 加（与已有 prefix 逐字对称）：

```json
"h2_suffix_html": "<span style=\"color: #d8cfb8; letter-spacing: 0;\">&nbsp;─</span>"
```

信心：高。这是本轮最干净的一条——缺陷可见、字段现成、色值已在调色板、改动一行。

### 3.5 `UNMOUNTED 15-mint-breeze list_prefix_ol_html`

依据 `mint-breeze.md:44`「步骤类有序列表前缀数字加浅绿圆底」。往
`15-mint-breeze.theme.json` 加（把规范里的字面 `1` 换成 `{n}` 占位符）：

```json
"list_prefix_ol_html": "<span style=\"display: inline-block; background-color: #dff0e8; color: #1e7a5c; font-weight: 700; border-radius: 50%; width: 20px; text-align: center; font-size: 13px; letter-spacing: 0;\">{n}</span>&nbsp;&nbsp;"
```

⚠️ 这里的 `display: inline-block` 无害：`15-mint-breeze` 有 `card`，
`boxed_keys` 只含 `{footer, card}`，`list_prefix_ol_html` 不承担定宽。

⚠️ **影响面**：这是本节唯一会改变**所有有序列表**渲染的改动（现状退回纯文本 `N.`）。
用真实语料看一眼再定稿。

---

## 四、【1 条】UNCARRIED 错值：bauhaus-pop `#1e5aa8`（硬清单）

**发现**：`UNCARRIED 11-bauhaus-pop #1e5aa8`

**事实**：`bauhaus-pop.md:39` 写「**红 `#be1e2d` 和蓝 `#1e5aa8` 不进代码块**」，
而该主题调色板（`:15`）里的蓝是 `#005baa`。`#1e5aa8` 在整个仓库里不存在于任何调色板
——**引用了一个不存在的色值**。设计文档把它定为规则 12「规范行里不留旧色值」的新形态：
留的不是旧值，是**错值**。

### 建议处置：**真缺陷 → 改主题 `.md`**

`skills/md2publish-article/references/theme-prompts/bauhaus-pop.md:39`，把

> **红 `#be1e2d` 和蓝 `#1e5aa8` 不进代码块**——在墨黑底上只有 2.94:1 和 2.65:1

改成

> **红 `#be1e2d` 和蓝 `#005baa` 不进代码块**——在墨黑底上只有 2.94:1 和 2.65:1

**`theme.json` 无需改动**：`#005baa` 已经在 `11-bauhaus-pop.theme.json` 里
（`h3` 的 `border-bottom` 与 `list_prefix_cycle` 第二档），所以改完 UNCARRIED 自动消失，
产物逐字节不变。

⚠️ 顺带核一下那个 `2.65:1`——它是按错值 `#1e5aa8` 算的还是按 `#005baa` 算的？
`#005baa` 在 `#171614` 上是 **2.51:1**（我算的）。既然要动这行，把数字一并改准，
否则规则 12 的问题只修了一半。**这一步我信心中等**：数字对不对不影响结论（两个值都
远低于 4.5，「不进代码块」的判断成立），但留一个错数在规范里就是下一个人的坑。

---

## 五、【3 条】INVENTED：`theme.json` 里现造的色（规则 9）

规则 9 的判据是有序的：**先在调色板内找达标的色 → 找不到就退回默认文字色（放弃该
token 的上色）→ 不要自己造色 → 真要新色，是主题文件该补。** 两个主题走到了第三步。

### 5.1 `INVENTED 09-gilded-ink #6a4f1a #7a5b1f`（硬清单）— 建议改 `.md`，信心中等

> **✅ 已处理（走 (B) 路，批次 1b）**：用户比对两种渲染后选择**保留现观感**，两支金按下面
> (B) 的写法补进 `gilded-ink.md` 的「色彩系统」段并写明明度被对比度钉住。`theme.json`
> **未动**，产物已核**逐字节不变**。下面表里的五个对比度数字全部独立复算无误。
> 一处本节没预见的：只补调色板不够——`audit-themes.py` 立刻报 `DEAD` + `DESYNC`
> （调色板有色、组件规范找不到落点，规则 3 的机械形态）。补了
> 「## 引用 / 代码 / 列表 / 表格」段的语法高亮那一行才归零，已回写进 lessons 规则 9。

**实测对比度**（我算的，代码块底 `#f5f1e8`）：

| 色 | 出处 | 在 `#f5f1e8` 上 |
|---|---|---|
| `#b08a3e` 古金（主强调） | 调色板 | **2.84** ✗ |
| `#8f6f2f` 深金（strong 用） | 调色板 | **4.16** ✗（差 0.34） |
| `#6b6355` 次级灰褐 | 调色板 | 5.26 ✓ |
| `#7a5b1f` | **现造**，`highlight.keyword`/`key` | 5.57 ✓ |
| `#6a4f1a` | **现造**，`highlight.string` | 6.78 ✓ |

执行者是为了凑 AA 把深金再调深——这正是规则 9 记的「四个执行者给出四种处置」里的
第一种。

**两条都合规的修法**：

- **(A) 严格按规则 9 的顺序**：调色板内**有**达标色（`#6b6355`，5.26），所以退回它 /
  退回代码默认字色 `#3a352c`，把 `#6a4f1a` `#7a5b1f` 从 `theme.json` 删掉。
  零 `.md` 改动，但代码块里的金色没了。
- **(B) 走规则 9 的出口「真要新色，是主题文件该补」**：把两个值补进
  `gilded-ink.md` 的「色彩系统」段，并按**规则 11 最后一句**在行下写明这个明度是被
  对比度钉住的。`theme.json` **已经有这两个值**，所以补完 `.md` 后不需要改
  `theme.json`，产物逐字节不变。

**我倾向 (B)**，理由：本主题叫「鎏金墨黑」，代码块里完全没有金色会削掉它的核心识别；
深金差 4.5 只差 0.34，说明设计意图本来就是「一支更沉的金」，不是随手造色。
建议加在 `gilded-ink.md:12-18` 的调色板段末尾：

```markdown
- 代码块内的金：`#7a5b1f`（关键字 / 键名）、`#6a4f1a`（字符串）
  ——**这两个明度是被对比度钉住的，不要往浅里调**：代码块底 `#f5f1e8` 上，
  调色板里的深金 `#8f6f2f` 只有 4.16:1，不达 AA；`#7a5b1f` 5.57、`#6a4f1a` 6.78。
  同一支金在白卡上和在代码底上是两个东西（规则 12）。
```

⚠️ **这条我信心中等**：(A) 是规则 9 的字面默认路径，(B) 是它的出口条款。这是
**审美取向题**（要不要保住代码块里的金），请用户拍。若拍 (A)，改动是：
`09-gilded-ink.theme.json` 的 `highlight` 改成
`{"comment": "#6b6355", "keyword": "#1c1a17", "string": "#6b6355", "key": "#1c1a17", "number": "#3a352c"}`
——但注意这样一来 comment 和 string 同色，语法高亮基本失效，我不推荐。

### 5.2 `INVENTED 23-terracotta-sun #9c8a72`（硬清单）— 建议改 `theme.json`，信心高

和 gilded-ink **不是同一回事**。`#9c8a72` 挂在 `highlight.comment`，在它自己规定的
代码块底 `#efe0cd` 上只有 **2.58:1**——**它不是为凑对比度造的，它自己就不达标**。
规则 11 直接适用：「低饱和、次级、克制都是手段，不是掉到阅读门槛以下的理由。」

调色板内在 `#efe0cd` 上达标的只有 `#4f382b`（8.39）和 `#8f3f28`（5.57，已被
`string`/`key` 占用）；`#6f7a4d` 橄榄绿 3.55 不达标，且 `terracotta-sun.md:46` 的分寸
条款明写橄榄绿「只用于 em 和 h3 前缀」（这正是 lessons 里那条 terracotta-sun 判例
的原句），不能派给注释。

**建议**：`23-terracotta-sun.theme.json` 的 `highlight.comment` 改成

```json
"comment": "color: #4f382b; font-style: italic;"
```

即规则 9 的第二步「退回默认文字色，放弃该 token 的上色」，用斜体保住注释与代码正文的
区分度。`highlight` 的值支持样式串（`md2html.py:167` 与 monochrome-mag / ink-wash 的
既有写法一致），不需要改脚本。**不建议把 `#9c8a72` 补进调色板**——补一个 2.58:1 的
色进调色板就是把违规固化。

---

## 六、【7 条】INVERT：主强调的文字落点少于副强调 / 参照色

`INVERT` 是 INFO 档，设计文档预判「至少 4 条会裁决为正当设计」。我把七条的实测数字
全部拉出来了（`--counts` + 按标签分桶）：

| 主题 | 主强调 | 文字落点 | 压过它的色 | 落点 | 主强调在卡片上的对比度 | 压过它的色的对比度 |
|---|---|---:|---|---:|---:|---:|
| 01-autumn-warm | `#d97758` | 21 | `#c06b4d` 副强调 | 317 | **3.12** ✗ | 3.85 |
| 02-ocean-calm | `#4a7c9b` | 21 | `#3d6a8a` 副强调 | 333 | 4.52 ✓ | 5.79 |
| 03-spring-fresh | `#6b9b7a` | 21 | `#4a8058` 副强调 | 317 | **3.18** ✗ | 4.65 |
| 09-gilded-ink | `#b08a3e` | 16 | `#8f6f2f` 深金（参照） | 253 | **3.21** ✗ | 4.68 |
| 15-mint-breeze | `#2fa47e` | 93 | `#1e7a5c` 深叶绿（参照） | 288 | **3.12** ✗ | 5.26 |
| 23-terracotta-sun | `#c2593b` | 86 | `#8f3f28` 深陶红（参照） | 284 | **4.15** ✗ | 6.83 |
| 19-candy-pop | `#f28ba8` | 29 | `#7fb5d5` 雾蓝（辅强调） | 88 | **2.32** ✗✗ | 2.22 ✗✗ |

**七条里六条是同一个机制**：主强调在白卡上达不到 4.5:1，于是设计者把正文里最高频的
`strong`（60 处）+ `h3` 文字派给了一支更深的同族色；主强调保留在 h2/h3 前缀符号、
列表符号、边框这些「图形」位上（3:1 线即可）。**这正是规则 11「对比度铁律优先于
主题的美学分寸」在设计阶段就已经生效的结果**——`INVERT` 报的是这个结果，不是缺陷。

### 建议处置：6 条 **正当设计 → 写豁免注记**，1 条 **待定**

写在各主题 `.md` 调色板段里主强调那一行的下一行：

```
<!-- census-ok: INVERT #d97758 主强调 3.12:1 达不到正文门槛，正文强调按规则 11 交给深一档的 #c06b4d，本色留给 h3 边线与列表符号（图形 3:1 线） -->
<!-- census-ok: INVERT #4a7c9b 与 autumn-warm/spring-fresh 同模板：正文强调统一交给深一档的 #3d6a8a，主强调留在前缀符号与 h3 边线上 -->
<!-- census-ok: INVERT #6b9b7a 主强调 3.18:1 达不到正文门槛，正文强调按规则 11 交给深一档的 #4a8058 -->
<!-- census-ok: INVERT #b08a3e 主题分寸条款自述「金只以细线、字符、小面积出现」，古金 3.21:1 本就不做正文色，strong 由深金 #8f6f2f 承担 -->
<!-- census-ok: INVERT #2fa47e 薄荷绿 3.12:1 不做正文色，93 处落在列表与 h3 前缀（本主题自述列表是主场），正文强调交给 #1e7a5c -->
<!-- census-ok: INVERT #c2593b 主强调已挂 strong（60 处文字），参照色 #8f3f28 的 284 处里约 190 处是行内 code 文字，不构成主次倒置 -->
```

**逐条信心**：

- **01 / 03 / 09 / 15：高**。对比度数字把结论钉死了，且 09（gilded-ink）的主题文件自己
  就写着「金色只以细线、字符、小面积出现，永不做大底色」——规范与产物完全一致。
- **02（ocean-calm）：中**。它是七条里唯一主强调**通过** 4.5:1（4.52）的，
  所以规则 11 并不强制这个分工，纯粹是与两个同模板兄弟保持一致的设计选择。
  我建议按兄弟主题一起豁免，但这条**没有硬规则背书**，用户若要求 ocean-calm 把
  `strong` 换回 `#4a7c9b`，也说得通（代价：4.52 只比门槛高 0.02，风险边际）。
- **23（terracotta-sun）：中高**。它与前面几条不同——主强调**确实**挂了 `strong`
  （60 处真正的正文强调），是有真落点的。触发 INVERT 的参照色 `#8f3f28` 之所以有 284，
  主要是行内 `code` 的文字色（本仓库实测行内 code 密度 190+ 处，规则 7 记过这个现象）。
  即：这条更像是**参照色分支被行内 code 撑高**的产物，而不是真的主次倒置。
- **19（candy-pop）：待定，见 §9.3。**

### ⚠️ 顺带发现（不是普查报的，需另行核实后再动）

拉对比度时撞见几个**普查看不见、但可能违反规则 11 的数**。我没有做完整的全库对比度
审计，下面只是把撞见的记下来，**请当作线索而非结论**：

| 主题 | 元素 | 色 / 底 | 实测 | 门槛 |
|---|---|---|---:|---|
| 01-autumn-warm | `strong`（15.5px 粗体） | `#c06b4d` / `#ffffff` | 3.85 | 4.5 |
| 23-terracotta-sun | `strong` | `#c2593b` / `#fdf8f1` | 4.15 | 4.5 |
| 19-candy-pop | `strong` | `#d96687` / `#ffffff` | 3.39 | 4.5 |
| 19-candy-pop | h3 前缀 / 列表符号 | `#f28ba8`、`#7fb5d5` / `#ffffff` | 2.32 / 2.22 | 3.0（图形） |

前三条是正文粗体，15.5px 粗体够不上 WCAG 的「大文本 3:1」豁免。candy-pop 那两个符号
连图形的 3:1 都不到。**注意这条与 §6 的关系**：若用户看了这张表决定「把主强调调深、
让它承担正文」，那是**加重**而不是解决 INVERT——两件事要分开处理，先定对比度、
再回头看 INVERT 还成不成立。

---

## 七、【4 条】editor-slate：机械层没有挂载点 / 语料没覆盖到

> **✅ 本节全部 4 条已处理（豁免，commit `bf65ac1`）**：7.1（`#d2a8ff`/`#ffa657`）、7.2
> （`#ffffff`）、7.3（`#bc4c00`）均按下面建议原样写了 `census-ok` 豁免注记，`theme.json`
> **未改**——这是**销声，不是修复**：这几个色的处境一点没变，只是记录了为什么可接受。
> 7.1 里「加 tokenizer 的 `func`/`param` 两类」那件事**没有**被采纳为本轮任务，已记入
> `handoff.md` 第六节第 1.5 条作为独立待办。

### 7.1 `UNCARRIED 06-editor-slate #d2a8ff #ffa657`（硬清单）— 豁免 + 押后，信心高

**设计文档预判的修法是「补 `theme.json`」（失步型），但机械事实不支持这个修法。**
我核过 `md2html.py:104-126`：tokenizer 只产出 **5 个 token 类**——
`comment` / `string` / `key` / `keyword` / `number`。**没有「函数名/类名」类，
也没有「命令行参数」类。** `editor-slate.md:32-40` 的 GitHub Dark 表声明了 6 色，
其中：

| 语法角色 | 色 | 有无 tokenizer 类 |
|---|---|---|
| 注释 / 关键字 / 字符串 / 常量·数字·键名 | `#8b949e` `#ff7b72` `#a5d6ff` `#79c0ff` | ✅ 已兑现 |
| 函数名 / 类名 | `#d2a8ff` | ❌ 没有这个类 |
| 变量 / 属性 / 参数（`--flag`） | `#ffa657` | ❌ 没有这个类 |

所以这两条**不是失步型，是 monochrome-mag 那种「无挂载点」型**，设计文档第八节把
editor-slate 归进「失步」是当时未核 tokenizer 造成的一处偏差。

**为什么不建议按规则 3 把这两行从 `.md` 删掉**：`theme-prompts/*.md` 有两个消费者——
机械路径（翻译成 `theme.json`）和**判断层路径（整份交给生成模型手写 HTML）**。
生成模型认得出函数名和 `--flag`。删掉这两行会削弱判断层路径，而 lessons 案例一记的
editor-slate 黑白化，根因恰恰就是代码块里颜色不够。

**建议**：本轮**写豁免注记 + 押后**，把「给 tokenizer 加 `func` / `param` 两类」
记进 handoff（规则 14 的三条准入线都成立：`--flag` 用正则完全可判、函数名在
Python/JS/Go 里 `\b\w+(?=\()` 也可判；无替代表达；当前静默丢失）。

写在 `editor-slate.md` 语法高亮表下方：

```
<!-- census-ok: UNCARRIED #d2a8ff md2html.py 的 tokenizer 只有 comment/string/key/keyword/number 五类，无函数名类；该色供判断层手写路径使用，加类的事记在 handoff -->
<!-- census-ok: UNCARRIED #ffa657 同上，无「命令行参数/属性」token 类；--flag 机械可判，加类的事记在 handoff -->
```

### 7.2 `NEAR-ZERO 06-editor-slate #ffffff` — 正当设计 → 豁免，信心高

`#ffffff` 挂在 `card`（不是 `container`，后者是 `#f6f8fa`），落点恒 1 的原因是
`card_mode: "single"`（`md2html.py:309`）——**全文一张大卡**，正是
`editor-slate.md:56` 白纸黑字写的「全文一张大卡，不逐节切卡」。规范与产物一致。

不建议把它并进 §2 的判据（那会把 `card` 也加进结构键，而多卡主题的 `card` 落点是 N，
判据会变得依赖 `card_mode`，得不偿失）。写一条注记：

```
<!-- census-ok: NEAR-ZERO #ffffff card_mode 是 single（本主题规范就是「全文一张大卡」），卡片背景落点恒为 1 -->
```

### 7.3 `ZERO 06-editor-slate #bc4c00` — 正当设计 → 豁免，信心高

`theme.json` 的 `alert.warning.style` / `label_html` **都正确挂了这个色**，机械层完全
通路；产物 0 处的唯一原因是语料 `litellm-multi-provider-gateway.md` 里
**一个 `[!WARNING]` 都没有**（我 grep 过：`[!` 出现 0 次，5 处引用块全是
`> **旁注：**` 写法）。

而 `editor-slate.md:86` 明写「够不上这个标准就一张都不做，别为了凑数把旁注升格」
——**这篇语料一张警告卡都没有，是规范期望内的结果，不是缺陷**。

```
<!-- census-ok: ZERO #bc4c00 alert.warning 已正确挂载，产物 0 处仅因测试语料无 [!WARNING] 块；本主题规范明写提示卡「够不上标准就一张都不做」 -->
```

**可选加强（推荐但不必须）**：给测试语料补一个 `> [!WARNING]` 块，让这条通路
至少被验证过一次——「配了机制却从没被验证过真的能触发」是本仓库反复吃亏的形态。
代价：语料一改，27 个主题的产物全部变化，`test-md2html.sh` PART B 需要整体重基线。
**建议单独开一个任务做，不要和本轮混在一起。**

---

## 八、【1 条】脚本原理上抓不到的真缺陷：cyber-neon 的警示提示卡

**这条不在 43 条里**，是用户 2026-08-07 已裁定接受的口径局限，按任务要求在此一并裁决。

`cyber-neon.md:37`：

> 2. 提示卡里属于警示性质的那种，标题和左边框用品红（信息性提示卡仍用青色）

`13-cyber-neon-v7-edge.theme.json` **没有 `alert` 键**。这**完全符合 `UNMOUNTED` 的
定义**，但因为这一行用中文「品红」指色、不带 hex / `style=` / `属性: 值`，进不了
`theme_lib.spec_lines` 的 `_ENTITY` 筛，L3 看不见它，报的是 0。用户已裁定接受这个
局限而不去放宽 `_ENTITY`（放宽的实测代价：全库只多 2 条 = 这条真阳 + `editor-slate:82`
一条假阳）。

### 建议处置：**真缺陷 → 改 `theme.json`**，信心高

局限是「查不出来」，不是「不该修」。往 `13-cyber-neon-v7-edge.theme.json` 加：

```json
"alert": {
  "note":    {"style": "background-color: #10182a; border-left: 3px solid #39d0d8; padding: 14px 18px; margin: 0 0 16px; color: #c9d2e3; font-size: 14.5px; line-height: 1.8",
              "label_html": "<span style=\"color: #39d0d8; font-weight: 700;\">提示</span>&nbsp;"},
  "warning": {"style": "background-color: #10182a; border-left: 3px solid #ff4ba3; padding: 14px 18px; margin: 0 0 16px; color: #c9d2e3; font-size: 14.5px; line-height: 1.8",
              "label_html": "<span style=\"color: #ff4ba3; font-weight: 700;\">警告</span>&nbsp;"}
}
```

（色值全部取自该主题现有调色板，不引入新色。`note` 走青、`warning` 走品红，逐字对应
规范原句。）

⚠️ **但请注意**：这个字段在当前测试语料下**一次也不会触发**（语料里 `[!` 出现 0 次），
所以修完 `census-themes.py` 的输出不会有任何变化——**这一条无法靠普查验收**，
只能靠人读 `theme.json`。这也是 §7.3 建议给语料补一个 `[!WARNING]` 的第二个理由。

**若用户希望本轮不动 cyber-neon 的 `alert`**：那就在 `cyber-neon.md:37` 上方留一条
说明性注释（**不是** `census-ok` 注记——普查没报它，写注记会立刻变成 `STALE-NOTE`
并以 ERROR 挂掉全库）。这一点很容易踩，特别标出。

---

## 九、【5 条】待定：需要用户拍板

### 9.1 `UNCARRIED 20-monochrome-mag #767676` + `ZERO-DUP 20-monochrome-mag #767676`（硬清单，2 条）

**事实**：`monochrome-mag.md:16` 写「浅中灰：`#767676`（仅用在纯白底上：图注、脚注、
署名）」——**声明有、落点也有，缺的是机械挂载点**：`md2html.py` 根本没有「图注 / 脚注」
的概念，Markdown 里也没有能机械识别图注的语法。按**规则 14 的准入线**，
「机械可判」这一条**不成立**，所以这个字段**永远不会被加**——写豁免注记等于永久沉默一个
0 落点色，那正是规则 3 要消灭的「死色」。

两条路，都需要用户拍：

- **(A) 按规则 3 删掉（我略微倾向）**：把 `.md:16` 整行删除，并把 `:15` 的括号注记与
  `:21` 的「上面**五级**文字灰」改成四级、把「白底上的注释浅中灰」这半句去掉。
  `theme.json` 从来没有这个色，**产物逐字节不变，零渲染风险**，一次消掉 2 条发现。
  代价：与**规则 5**（「无彩色主题反而要把灰阶分工写得更细」）方向相反，从五级灰降到四级。
- **(B) 给它一个真挂载点：文末落款**。`md2html.py` 的 `footer_html` 文档原文就是
  「印章 / 落款 / 「終」字」，而 `#767676` 声明的三个用途里正好有「**署名**」。往
  `20-monochrome-mag.theme.json` 加 `footer` + `footer_html`（用 `#767676`），
  并把 `.md:16` 的用途收窄成「文末署名 / 落款」。代价：落点变成 1，这条会从
  `UNCARRIED` 降级成 `NEAR-ZERO`——**换了一档，没有归零**（除非 §2 的判据把
  `footer_html` 算进结构键，那样恰好也被豁免掉）。

⚠️ **两条路都不要走的第三条**：往 `.md` 里再加一句「图注要用浅中灰」之类的强调语。
那是**规则 13** 点名的反模式（apple-air 的 eyebrow）——加一条渲染不出来的规范，
审计从此闭嘴，产物一点没变。

### 9.2 `UNMOUNTED 24-botanic-press list_prefix_ol_html`

`botanic-press.md:41`：「列表前缀 `·&nbsp;&nbsp;`；物种/条目清单**可用**褐色序号
`<span style="color: #8a6d4e; font-weight: 700;">No.1</span>&nbsp;&nbsp;`」。

**「可用」是可选语气**，不是硬规范——这是它与 §3.5 mint-breeze（「步骤类有序列表前缀
数字加浅绿圆底」，陈述句）的唯一区别。判据抓的是关键词「序号」，抓得没错，
但要不要兑现取决于「可用」算不算规范。

- **兑现（我略微倾向）**：往 `24-botanic-press.theme.json` 加
  `"list_prefix_ol_html": "<span style=\"color: #8a6d4e; font-weight: 700;\">No.{n}</span>&nbsp;&nbsp;"`。
  好处：`#8a6d4e` 目前只挂在 `em`（中文文章里近乎零）和 `highlight.string`/`key` 上，
  加这个落点正好治规则 1 的老毛病。
- **豁免**：`<!-- census-ok: UNMOUNTED list_prefix_ol_html 规范原文是「可用」，属可选项而非硬规范，本主题选择不用 -->`

⚠️ 若拍「豁免」，建议同时把 `.md:41` 的「可用」改成明确的否定或删掉整个从句
——否则下一版执行者还会在同一处犹豫（**规则 8 的同源问题：规范里留模糊语气，
模型只能猜**）。

### 9.3 `INVERT 19-candy-pop #f28ba8`

`handoff` 第六节第 3 条已挂着「candy-pop 主次倒置待真机观感定夺」。实测数字：

| 色 | 角色 | 文字落点 | 落在哪 | 白卡上对比度 |
|---|---|---:|---|---:|
| `#f28ba8` | 樱粉（主强调） | 29 | h3 前缀 ◦、列表符号、`highlight.keyword` | 2.32 |
| `#7fb5d5` | 雾蓝（辅强调） | 88 | h3 前缀 ◦、列表符号、`highlight.string`/`key` | 2.22 |
| `#d96687` | 深樱粉（strong 用） | 271 | h2 11 + strong 60 + 行内 code/表头 200 | 3.39 |

**粉色家族合计 300 处，雾蓝 88 处**——从「气质」上看并没有倒置，倒置的是**「主强调」
这个标签本身**：被标为主强调的 `#f28ba8` 只落在装饰符号上（规则 6 的口径下等于没有
文字落点），真正做正文强调的是没被标为强调的 `#d96687`。

**三条路**：
- **(a) 改标签**（改 `candy-pop.md:15-16`，把「樱粉（主强调）」与「深樱粉（strong 用）」
  的角色写法对调成「樱粉（装饰强调 / 符号与前缀）」「深樱粉（主强调，strong 用）」）。
  不改任何色值，`theme.json` 与产物逐字节不变，INVERT 自动消失，且规范变得与实际一致。
- **(b) 豁免**，理由同 §6 其余六条。
- **(c) 判为真缺陷并调色**——但请先看 §6 末尾那张表：candy-pop 的三个色**没有一个**
  过对比度门槛（2.32 / 2.22 / 3.39），真要动就不是 INVERT 的问题了，是整套配色要重定。

**我建议 (a)**，但这是审美 + 命名取向，按 handoff 原意应由真机观感定夺，故列为待定。

### 9.4 `NEAR-ZERO 19-candy-pop #e8f2f9`

> **⚠️ 已裁定为真缺陷，修法未定，文件未动（批次 1b）**：用户 2026-08-09 确认本人写作
> 除特殊情况外不用斜体，因此这个色在实际产出里永远渲染不出来——本节「更像真缺陷
> （规则 1 + 规则 3）」的判断成立，Task 5 的「语料覆盖度」读法作废。但下面三条候选路
> **主题自己的规范一条都推不出来**（`candy-pop.md:36` 明写「用蓝，和 strong 的粉错开」
> 堵死了删除路；`:40`/`:41`/`:43` 把引用块、行内 code、表头全指给了浅粉，改挂哪一个
> 都是审美取向），执行者按指令停手上报。完整论证与三条待选路见
> `handoff.md` 第六节 1.5，**那里是权威版本**。

**这条不是结构性误报，别跟 §2 那 18 条一起批量豁免。** `#e8f2f9`（浅蓝底）在
`theme.json` 里**只挂在 `em` 上**（`container` 是另一个色 `#fdf6f0`），落点为 1 是因为
语料全文只有 **1 处** `*em*`。

**关键判断**：规则 1 明写「低频元素：em、链接、脚注——中文公众号文章里可能整篇为零」，
案例一整节讲的就是这件事。**一个只挂在 `em` 上的色，在中文文章里等于死色**——这不是
语料的问题，换一篇中文技术文照样接近 0。所以我认为**这更像真缺陷（规则 1 + 规则 3）
而不是语料覆盖不足**，与 §7.3 的 `#bc4c00`（`alert` 通路正确、只是这篇文章没有警告）
**不是同一类**。

三条路，都需要用户拍：
- **给它第二个高频落点**：最自然的是表格斑马纹 `td_alt`（现在是 `#fdf6f0`），
  或引用块的一个变体。改动会影响观感，属审美判断。
- **按规则 3 从调色板删掉**，同时把 `em` 的底改成已有的 `#fce8ee`（浅粉底）。
- **豁免**，理由写「本主题接受浅蓝底只服务于 em」——但这等于承认规则 1 在这里不适用，
  我不推荐。

---

## 十、`11-bauhaus-pop strong_alt`：报告之间的一处矛盾，需一并裁定

> **✅ 已处理（豁免，commit `bf65ac1`）**：下面「Task 4 的判读是对的、这是误报」的结论
> 被采纳，`bauhaus-pop.md:14` 下已写豁免注记，`theme.json` **未改**。

**这一条我必须单独标出来，因为两份已归档的文件对它给了相反结论：**

- `progress.md:29`（Task 4）：「`11-bauhaus-pop strong_alt` **为误报**（命中的是调色板
  角色标注 `- 红（strong / 警示）：#be1e2d` 而非指令句）」
- `task-5-report.md:208`（Task 5 表格）：「**新核实为真**：md 写"红（strong / 警示）：
  `#be1e2d`"，`theme.json` 确无 `strong_alt`」

**两句引用的是同一行证据，结论相反。** 我独立复跑了 L3 的匹配过程，确认命中行确实是
`bauhaus-pop.md:14` 那条调色板角色标注，不是任何指令句。

**我认为 Task 4 的判读是对的**：bauhaus-pop 的红**就是** `strong` 的颜色
（`theme.json` 的 `strong: "color: #be1e2d"` 已兑现），`（strong / 警示）` 是在说
「这支红同时承担 strong 和警示语义」，**不存在一个需要另配样式的警示型 strong**。
与 cyber-neon（`:36` 明确说「改用另一套样式」）和 blueprint-grid（`:35`/`:36` 明确说
「普通 strong 保持主强调蓝」，即两套）形态不同。

### 建议处置：**正当设计 → 写豁免注记**，信心中高

写在 `bauhaus-pop.md:14` 下一行：

```
<!-- census-ok: UNMOUNTED strong_alt 本主题的红本身就是 strong 色（theme.json 已挂 strong），「strong / 警示」是同一支色的两个语义，不存在需要另配样式的警示型 strong -->
```

**不建议改判据**去排除「调色板角色标注行」：这类行的判别没有可靠的机械特征
（`_label()` 那套只切冒号前，切不掉这里的问题），为一条发现收窄判据，很容易把
cyber-neon / blueprint-grid 那种真缺陷一起放过——本项目的治理原则说得很清楚，
「收窄到报 0 而缺陷仍在」比过度报告更糟。

---

## 十一、执行顺序建议

若用户全盘采纳，建议按「风险从低到高」分四批，每批之后跑一次
`python3 skills/md2publish-article/scripts/census-themes.py`：

1. **零渲染风险批**（改完产物逐字节不变）：§4 bauhaus 错值、§5.1(B) gilded-ink 补调色板、
   §9.3(a) candy-pop 改标签、以及全部豁免注记。→ 预计消掉 ~15 条。
2. **只加 `theme.json` 字段批**：§3 的 5 条 + §8 cyber-neon `alert`。→ 消掉 5 条
   （`alert` 那条不体现在计数上）。产物变化，`test-md2html.sh` PART B 预期变红。
3. **判据批**：§2 改脚本 + 配两条变异测试。→ 消掉 18 条。**必须先补变异测试再改判据。**
4. **待定批**：§9 的五条，等用户结论。

收尾按 brief Step 6 跑六条基线；结论回写 `docs/theme-design-lessons.md`
（建议新增两条：一是「结构性单点落点不是缺陷，判据要按挂载键而不是标签判」；
二是「写语法高亮 token 表前先核 tokenizer 有没有这个类」——即 §7.1 那件事，
是规则 14 在语法高亮维度上的新形态）。

---

## 十二、本轮未做 / 明确不建议的

- **未采纳**把 `REF_EXCLUDE` 套到 `ZERO`/`NEAR-ZERO` 循环（`progress.md:35` 已判定
  危险：会连带灭掉 aurora-flow 的立身缺陷）。§2 的建议判据完全不碰这个词表。
- **不建议**按调色板标签里的「底 / 背景」做豁免——candy-pop 的 `#e8f2f9` 标签正是
  「浅蓝底」，任何标签法都会误伤它（见 §2）。
- **不建议**改 `md2html.py`（§7.1 的 tokenizer 加类是 handoff 事项，不在本轮）。
- **未做**全库对比度审计。§6 末尾那张表是拉 INVERT 数据时顺带撞见的四处疑似违规，
  **是线索不是结论**，动手前请单独核。
- **未改动任何文件**（除本文件）。所有 `census-ok` 注记文本、`theme.json` 片段都只是
  建议文本，一个字都没有落进 `references/`。
