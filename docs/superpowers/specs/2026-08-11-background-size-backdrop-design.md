# 判据设计：被 `background-size` 限制成条带的 `background-image`，不该当成文字的底

> 2026-08-11。对象是 `skills/md2publish-article/scripts/contrast_lib.py` 的底色走查。
> 这是对比度护栏落地后发现的第一处**判据缺陷**（不是主题缺陷），修完会让冻结基线
> 从 116 条变成 110 条。

## 一、问题

`contrast_lib.py` 里没有任何一处处理 `background-size` / `background-repeat` /
`background-position`。`backdrop_samples()` 只要看见 `background-image` 是个渐变，
就把渐变沿途采样当成该元素**整个面**的底色候选，再传给所有后代文字。

真实库里 aurora-flow 的 `card` 是：

```
background-color: #ffffff; background-image: linear-gradient(135deg, #6a5cff, #38c6d9);
background-repeat: no-repeat; background-size: 100% 4px; background-position: top;
border-radius: 16px; padding: 26px 22px; margin: 0 0 32px
```

渐变实际只画卡顶 **4px** 一条装饰线，卡片其余部分是白底 `#ffffff`。走查却把它读成
「整张卡的底是那条渐变」，于是卡内每一个文字节点都被拿去和渐变最差点比。

## 二、证据（量出来的，不是推的）

基线里 aurora-flow 有 12 行，其中 **7 行的底判错了**：

| 元素 | 记的底与比值 | 真实底 `#ffffff` 下 | 处数 | 判定 |
|---|---|---|---:|---|
| `h3` / `p` / `td` `#33344a` | `#6a5cff`，2.65:1 | **12.13:1** | 278 | 纯假阳 |
| `strong` ×2 / `span` `#6a5cff` | `#6a5cff`，1.00:1 | **4.58:1** | 61 | 纯假阳 |
| `span` `#38c6d9`（装饰） | `#38c6d9`，1.00:1 | 2.05:1（阈值 3.0） | 4 | **发现仍成立**，底与比值都记错 |

**6 行是纯假阳（339 处），1 行是「真发现 + 错数字」。** 那个看着最吓人的
`1.00:1 / 55 处` 不是「文字消失」，是判据把一条 4px 装饰线当成了整张卡的底。

`#6a5cff` 在白底上是 **4.58:1**，只比 4.5 高一点——所以这条假阳不是「本来就宽裕」，
而是恰好压线通过。修完之后它离阈值只有 0.08，值得单独记一笔。

## 三、判据

**说法（必须逐字等于实现）**：

> `background-image` 被限制成一条贴边条带，且该侧 padding 保证元素内文字够不到它——
> 此时元素内文字的底是 `background-color`，那张图像不参与底色候选。

新增纯函数 `image_reaches_text(st)`，入参是 `parse_style()` 出来的声明字典，
返回「这张图像有没有可能落在自己的文字后面」。

**默认返回 `True`。** 只有下列四条**同时**成立才返回 `False`：

1. `background-repeat` 恰好是 `no-repeat`
2. `background-size` 有**两个**分量，且**高度分量**（第二个）是 px 固定长度
3. `background-position` 恰好是 `top` 或 `bottom`
4. 该侧 padding（`top` 看 padding-top，`bottom` 看 padding-bottom）是 px 且 **≥ 条带高度**。
   长写法优先：同时出现 `padding` 简写与 `padding-top` 时以 `padding-top` 为准
   （CSS 里后写的赢，但本项目的样式串都是主题自己写死的、不存在覆盖顺序问题，
   所以取「长写法优先」这条确定规则，而不是去猜声明顺序）

aurora-flow 的 `card` 四条全中：`no-repeat` ✓、`100% 4px` 的高度是 `4px` ✓、
`top` ✓、`padding: 26px 22px` 的 padding-top 是 26px ≥ 4px ✓。

### 为什么每一条都必要（缺一都会变成危险方向）

- **缺 1**：`background-repeat` 默认是 `repeat`。`background-size: 100% 4px` 配 `repeat`
  会让那条 4px 渐变**平铺满整个元素**，图像确实盖在文字后面。少这条就是漏判。
- **缺 2**：只有两个分量、且高度是固定长度，才谈得上「条带」。`cover` / `contain` /
  `auto` / `%` 高度、以及只给一个分量（那是宽度，高度按 auto 走，对渐变等于元素高）——
  这几种图像都可能铺满，必须保留。
- **缺 3**：`background-position` 不是 `top`/`bottom` 时（比如 `center`），条带落在元素
  中间，文字正好压在上面。padding 证明不了任何事。
- **缺 4**：这是唯一一条把「条带存在」变成「文字够不到条带」的**机械证明**。padding
  为 0 时文字确实压在条带上，此时必须照旧拿图像判。

### 全库实测：只有一处命中，条件 1 挡住了另外四处

把 26 份 `theme.json` 里带渐变的 8 处逐个量了一遍（全部写在 `background-image` 上，
`background` 简写 0 处）：

| 主题 | 键 | `background-size` | `background-repeat` | 判定 |
|---|---|---|---|---|
| 21-aurora-flow | `card` | `100% 4px` | `no-repeat` | **`False`（唯一命中）** |
| 01-autumn-warm | `card` | `20px 20px` | 未声明 → `repeat` | `True` |
| 02-ocean-calm | `card` | `20px 20px` | 未声明 → `repeat` | `True` |
| 03-spring-fresh | `card` | `18px 18px` | 未声明 → `repeat` | `True` |
| 22-blueprint-grid | `container` | `24px 24px` | 未声明 → `repeat` | `True` |
| 08-morandi-fog | `h2` | 未声明 | — | `True` |
| 21-aurora-flow | `h2` / `h2_first` | 未声明 | — | `True` |

**这不是理论上的谨慎，是实测**：那四处 `20px 20px` / `24px 24px` 是**平铺纹理**——
它们确实铺满整个元素、确实在文字后面。少了条件 1，这四处会被当成「小尺寸图像 = 条带」
一起误剔，四个主题的底色判定全部失真。**条件 1 是这道门里唯一真正承重的那条**，
其余三条是把它的适用范围钉死。

**方向性**：四条里任何一条判不出来（属性缺失、单位不是 px、值不认识、多层背景），
一律倒向 `True` = 保留图像 = 继续按渐变判。所以这个判据**只可能多报，不可能藏发现**。
lessons「判据可以下窄，下窄比下宽更危险」那一节要求的就是这个方向。

## 四、接口

改在**调用侧**，`backdrop_samples()` 的签名与语义一个字不动：

```python
# _Walker.handle_starttag
image = st.get("background-image") if image_reaches_text(st) else None
backdrop_samples(st.get("background-color") or st.get("background"), image, samples)
```

理由：`backdrop_samples()` 身上压着渐变插值顺序、硬停判定、alpha 合成等一批既有断言，
为这件事改它的签名会把无关的东西一起搅动。新判据是一个独立的、可单独测的纯函数，
边界清楚：**入什么**（一份样式声明字典）、**出什么**（一个 bool）、**依赖谁**（只依赖
自己解析的四个属性，不碰颜色、不碰 DOM）。

### 一个具体的坑：不要复用 `_px()`

`contrast_lib._px(v, default)` 解析失败时**静默返回 default**。在这里用它会把
「这个值我解析不出来」变成「它等于某个数」，方向不可控——比如条带高度解析失败被当成
16.0，padding 解析失败被当成 0，两种错法倒向相反的方向。新函数要用一个**解析不出来就
返回 `None`** 的严格助手，让「不认识」显式地走到「保留图像」那条路上。

## 五、测试

`image_reaches_text` 是 `_lib.py` 的纯函数 → 单测进 `test-contrast-lib.py`（房规）。

**`test-contrast-themes.sh` 不用加用例。** 它已有的 `real-library` 那条不是硬编码
116，而是拿脚本本轮输出的条数与基线**文件行数**动态比对（`:403` 的 `$actual_n`），
两边一起变。而且它顺带就把错误实现 #1 证死了：**谁把这道门去掉，产物侧回到 116 条、
基线 110 条，`real-library` 立刻红。**所以 #1 不需要单独的用例——这不是省事，是那条
既有用例本来就钉得住它。

按「写完一条用例，先说出一个能让它照样通过的错误实现，再真的去改代码验证它红」的纪律，
下列十一种错误实现每一种都要有对应用例证死（#1 由上面那条既有用例承担，其余十条进
`test-contrast-lib.py`）：

| # | 错误实现 | 该被哪条钉死 |
|---|---|---|
| 1 | 压根没这道门（永远 `True`） | aurora-flow 那 6 行不消失 |
| 2 | 忽略 `background-repeat` | `repeat` + `100% 4px` 应判 `True`（会平铺满） |
| 3 | 忽略 `background-size` | 只有 `no-repeat` 的渐变应判 `True` |
| 4 | 高度接受 `%` | `100% 10%` 应判 `True` |
| 5 | 高度接受 `auto` / `cover` / `contain` | 三者都应判 `True` |
| 6 | `background-position` 接受任意值 | `center` 应判 `True` |
| 7 | 不看 padding | `padding: 0` 应判 `True` |
| 8 | padding 非 px 仍照算 | `padding: 2em` 应判 `True` |
| 9 | padding 简写取错侧 | `padding: 4px 22px 30px` 的 top=4px、bottom=30px，两侧要分别验 |
| 10 | 单分量 `background-size` 当成高度 | `background-size: 4px` 应判 `True` |
| 11 | 多层背景按单层解析 | `background-size` 里出现逗号时应判 `True` |

**一条 fixture 只钉一个键**（lessons 的附带纪律）：不要把 `repeat` 和 `cover` 写进同一份
样式串去钉两条，那样只改其中一个时另一个仍然让判定为假，用例根本不红。

## 六、基线影响

**净变化 116 → 110，但不是简单删 6 行。**

**`--prune` 删掉的是 7 行，不是 6 行。** 换键那一行的**旧键**同样从产物侧消失了，
而 `prune_survivors` 只留「基线里有 **且** 本轮仍出现」的行，所以它跟 6 行纯假阳
一起被删。算术是三步：

| 步骤 | 基线行数 | 发生了什么 |
|---|---:|---|
| 起点 | 116 | — |
| `--prune` | **109** | 6 行纯假阳 + 1 行换键的**旧**键，共 7 行从产物侧消失 |
| `--write-baseline` | **110** | 收下换键后的**新**键 |

⚠️ **中途那个 109 是预期值，不是算错了。** 这一段写得细，就是因为跑完 `--prune`
先看到 109 很容易让人以为哪里不对，转头去怀疑判据。

换键的那一行是：`span #38c6d9 on #38c6d9 1.00` → `span #38c6d9 on #ffffff 2.05`。
基线的键含「底」，底变了就是新键——**默认路径会报「新增 1 条」并 exit 1**。
这不是新缺陷，是同一个真发现换上了正确的底和比值（装饰阈值 3.0，2.05 仍不达标）。
收下它唯一的路是 `--write-baseline`，而**唯一的护栏是人读那份 `.tsv` 的 diff**。

因此实施时必须：先 `--prune`（应得 109），再单独确认那条新增行确实是换键而不是
真新增，再 `--write-baseline`（应得 110），最后把 diff 逐行读一遍。三步顺序不能省、
不能并。

## 七、明确不做的

- **不做真实布局。** 这个判据不计算文字实际落在哪个像素，它只回答「有没有机械证据
  证明文字够不到这条带」。够不到就退回底色，证明不了就保留图像。
- **不做 `px` ↔ `%` 换算**（沿用硬停判定已经定下的纪律：那种等价是猜的）。
- **不碰 `background-attachment` / `background-clip` / `background-origin`。** 真实库里
  一个都没用到，加了就是没有调用方的代码。

  > **2026-08-12 更正（复审核实）**：上面这条把三个属性归成一类，理由「真实库一个都没用到」
  > 只对其中安全的那类省略成立，`background-attachment` 与 `background-origin` 不是那类，
  > 本条把它们并进来是事实错误，不是表达问题。这道判据的安全性依赖的是「判不出来就倒向
  > 保留图像」，而「倒向保留图像」对应的是**属性缺席**：左右条带没样本、`px`↔`%` 换算不做、
  > `background` 简写不进底色候选，这几处省略都是「属性/写法不出现，判据照旧继续按已有
  > 路径走，不会藏掉发现」。`background-attachment` 与 `background-origin` 恰好相反——
  > **出现**才危险，**缺席**才安全：`background-origin: content-box` 把 `background-position`
  > 的定位区从 padding box 挪到 content box，`top` 会贴在文字第一行顶上，条件 4「padding
  > 隔开文字与条带」的证明因此不成立；`background-attachment: fixed` 把定位区挪到视口，
  > padding 更是什么都证明不了。一个未处理属性「出现时会让判据错误地删掉一条真发现」，
  > 和一个未处理属性「缺席时判据本就会继续保留图像、不藏发现」，不是同一种省略。
  > **实际入仓的实现**（`contrast_lib.image_reaches_text`，2026-08-12 补）在四条必要条件
  > 之前单独加了一道预判：`background-origin` 或 `background-attachment` 任一出现（不看
  > 值）就直接返回 `True`——这两个已经从「不碰」移出去了。**`background-clip` 仍然不碰**：
  > 它只影响背景的裁剪区域，不影响 `background-position` 的定位基准，条件 4 的 padding
  > 证明不受它干扰，本条对它的原判断仍然成立，没有变。这是事实性更正，不是设计变更——
  > 按 `docs/handoff/handoff.md` 文档地图第 4 条的纪律，存档只在发现事实错误时更正，
  > 本次即是。
  >
  > **2026-08-12 更正之二（复审二轮核实）**：上面那条更正本身在重蹈它要纠正的错误——把
  > 危险属性当成「点名两个」的特判来处理，而不是先问「这一类省略还有没有别的成员」。
  > 复审又核出一个同形的第三个属性：`background-position-x` / `background-position-y`
  > 是 `background-position` 的标准长写法，后写的赢；`background-position: top;
  > background-position-y: bottom` 会让条带实际落在底部，而只点名 origin/attachment
  > 的实现只看 shorthand、查 `padding-top`，照样会算出错误的 `False`，藏掉一条真发现。
  > 同一形状还能再举出 `padding-block*`（覆盖 `padding` 简写判出的那一侧）和
  > `background` 简写（可能带着没被看到的 origin/position/size）——每次核出一个就点名
  > 一个，是在按下葫芦浮起瓢，说明「点名」这个修法本身就是错的，该关的是这一整类，
  > 不是逐个补丁。**实际入仓的实现已改成闭世界白名单**：`image_reaches_text` 只在
  > 元素声明的每一个 `background-*`/`padding-*` 属性都落在 `_MODELED_BG_PADDING`
  > （`background-color`、`background-image`、`background-repeat`、`background-size`、
  > `background-position`、`padding`、`padding-top`、`padding-bottom`、`padding-left`、
  > `padding-right`）这个集合内时才继续往下判；集合外的任何属性——包括上一条点名过的
  > `background-origin`/`background-attachment`、这次新核出的
  > `background-position-x`/`-y`、`background-clip`、`padding-block*`/`padding-inline*`，
  > 以及未来 CSS 新增的、这里谁都没想到的任何一个——一律不看值直接倒向 `True`。
  > `background-clip` 因此也不再是「特意不碰」的一个例外，而是「闭世界名单没收它，
  > 和其它任何一个还没出现过的属性待遇相同」。上一条更正把「不碰」改成「碰了两个」，
  > 这里再改成「碰了整个类」——这同样是事实性更正，不是设计变更，理由同上一条。
- **不为这一处引入 `contrast-ok` 豁免注记。** 这是判据错了，不是「可以永远这样」；
  用豁免注记去盖判据缺陷，正是本项目立项要防的那个形状（见 handoff 里 mint-breeze
  那条用假理由灭真发现的自伤记录）。

## 八、已知局限（修完之后仍然成立，不要读成完整性证明）

- **条件 4 那条「机械证明」有一个没写在判据里的前提：后代元素不能用负 margin 把自己
  拉回条带底下。** padding 只推开元素自己的内容盒，`margin-top: -30px` 的子元素照样能
  骑到条带上。真实库实测 26 份 `theme.json` 负 margin **0 处**，所以前提成立——但它是
  被实测保住的，不是被判据保住的。**将来谁给主题写了负 margin，这条证明就破了**，
  那时要么禁掉负 margin，要么把这道门关掉。
- 只覆盖**贴上下边**的条带。左右两侧的条带（`background-position: left` + 固定宽度）
  同理成立，但真实库里没有样本，**不实现**——没有样本就没有测试能钉住它。
- `background-position` 只认光秃秃的 `top` / `bottom` 两个关键词。`top left`、`0 0`、
  `center top` 这些等价写法一律走保留图像那条路。真实库只用 `top`，收窄是安全方向。
- **这道门只管 `background-image` 这个键。** 走查现在把 `background` 简写整个丢给
  `parse_color()` 当底色（`parse_color` 认不出渐变就返回 `None`），所以写在 `background`
  简写里的渐变**本来就不进底色候选**。这是修改之前就有的行为，本次不动它，也不靠它
  ——真实库 26 个主题的渐变全部写在 `background-image` 上（`aurora-flow`、`morandi-fog`
  的下划线带、纹理渐变都是）。记在这里是免得下一个人以为这道门覆盖了两种写法。
- 判据仍然只看 HTML 里声明的样式，不是微信公众号编辑器最终渲染的样子。这条是
  `contrast-themes.py` 从一开始就有的局限，lessons 已记，这次不改变它。
