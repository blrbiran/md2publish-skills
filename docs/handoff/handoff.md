# Handoff：md2publish-skills 交接文档

> 更新于 2026-08-05（第三轮，全库 27 个主题实测跑完）。接手前先读本文，再按第八节开工。
> 仓库位置：`~/code/skills/writing/md2publish-skills/`
>
> **本文不记录 commit hash**——提交本文这个动作本身就会移动 HEAD。仓库状态一律以实时的
> `git log` / `git status` 为准；本文只描述「做到哪一步了」，不描述「在哪个提交上」。

## 零、Executive Summary（下一位 agent 从这里进）

1. 项目：把 Markdown 变成微信公众号可粘贴 HTML 的 skill 链。**唯一转换入口是 `scripts/md2html.py`，你的工作单元只有 `theme.json`**——别手敲 HTML、别另写脚本。
2. **27 个主题全部实测跑完**，产物在 `~/code/skills/writing/wechat_test/litellm-multi-provider-gateway/out/`（仓库外）。配对关系和作废文件见第三节，命名不统一，容易取错。
3. 三条基线，动手前先跑一遍确认没被上一轮改坏：`audit-themes.py` 要 0 条、`test-audit-themes.sh` 要 14 全绿、产物要过 `wechat-html.md` 末尾的自检到 PASS。
4. **接手就干第八节**，那是全库跑完暴露的问题，已按「改脚本 / 改主题文件 / 审计盲区 / 收尾 / 不该做」分好类，并按独立需求方数量排了序。
5. 最重要的一条认知：**`audit-themes.py` 报 0 条不等于主题成立**——它查的是主题文件里有没有*声明*落点，不是产物里这个色出现了几次。apple-air 审计 0 条但产物里唯一强调色只有 1 处。
6. 改主题前必读 `docs/theme-design-lessons.md`，规则 8/9/10 是这一轮新立的。
7. 红线：**传图、建草稿、git commit/push 一律先经用户确认**；成本敏感，大批量开跑前先报预估。
8. 交接时工作树有三份**未提交**的文档改动（handoff / lessons / batch-prompt），用户尚未批准提交——以实时 `git status` 为准。

## 一、项目是什么

基于 [md2wechat CLI](https://github.com/geekjourneyx/md2wechat-skill) **免费路径**（不买 `MD2WECHAT_API_KEY`）的公众号发布 skill 组合，四个 skill 各管一段：

- `skills/wechat-finetune/` — 成稿 → 公众号版 Markdown（重拟标题/删难懂与无关/开篇钩子/段落切短/frontmatter），原文不动、另存 `<name>.wechat.md`
- `skills/md2publish-article/` — Markdown → 微信可粘贴 HTML（排版指令来自本地主题库）
- `skills/md2publish-images/` — 封面/信息图（`--plan` 计划模式，交宿主 agent 生成）
- `skills/md2publish-draft/` — 推草稿箱（`upload_image` + `create_draft`，强制用户确认）

完整链路：`tech-writer`（读者懂不懂）→ `tech-writer-deslop`（像不像 AI 写的）→ `wechat-finetune`（适不适合公众号平台）→ `md2publish-article` → `md2publish-images` → `md2publish-draft`。前两个在另一个仓库 `~/code/skills/runskills/skills/`，三者判据不重叠、顺序不能反。

架构与职责边界见 `skills/README.md`；给人读的全流程教程在 `~/org/markdown/prompt/@inbox/md-to-wechat-draft-free-path.md`（仓库外）。

## 二、生成 HTML 的工作方式（这是现在的主路径，先看这节）

**不要手敲 HTML，也不要另写转换脚本。**机械层已经固化在 `scripts/md2html.py`：

```bash
python3 skills/md2publish-article/scripts/md2html.py <article.md> <theme.json> -o <out.html>
```

它包办转义顺序、`&nbsp;` 边界、span 不跨 `<br>`、结构包裹、语法高亮、定宽分层、H1 不进正文、代码块逐字节自校验。**你的工作单元是那份 `theme.json`**——把主题文件的散文规范翻译成内联样式串，外加脚本判断不了的语义判断（哪段升格提示卡、主题没覆盖的元素怎么补）。字段说明见脚本头部注释。

第二轮新增 8 个字段（原脚本只对 cyber-neon 一种形状验证过，另外 5 个主题一上就露洞）：

| 字段 | 解决什么 |
|---|---|
| `h3_prefix_html` | **27 个主题里 18 个需要**，原来只有 h2 有前缀字段 |
| `card_mode: "single"` | 全文一张大卡（editor-slate），区别于默认的每章一卡 |
| `h2_first` | 正文不渲染 H1，首个 h2 顶在页首，要单独去掉上间距/节前线 |
| `h2_text_style` | 标题文字自带色块（bauhaus-pop 的黑底白字） |
| `td_alt` | 表格斑马纹 |
| `list_prefix_cycle` | 列表前缀多色轮换（bauhaus-pop / candy-pop / aurora-flow） |
| `alert` | 提示卡（第三轮补）。文章 md 里写 `> [!NOTE]` 触发，主题没配就剥掉标记按普通引用块渲染 |

另有两处与规范冲突的修正：`sty()` 原来无条件追加 `text-align: left`，会盖掉主题指定的居中；`highlight` 的值原来只能是裸色值，现在也接受完整样式串（无彩色主题靠字重和字形区分 token，只能上色就没有区分手段了）。

跑完必须过 `references/wechat-html.md` 末尾的自检脚本到 PASS。抽取方法：

```bash
awk '/^python3 - <<.EOF.$/{f=1;next} /^EOF$/{f=0} f' skills/md2publish-article/references/wechat-html.md > selfcheck.py
python3 selfcheck.py <out.html>
```

## 三、当前状态

### 已实测验证

- **全链路 E2E 两次跑通**：litellm 技术文（1.7 万字符、13 代码块、11 个 h2、7 个 h3、3 处 `---`）→ HTML → 自检 PASS → `create_draft` → 手机预览确认
- **主题库 27 个**，清单见 `references/theme-prompts/INDEX.md`，全库统一走「`_common-tech.md` + 主题文件 + 原文」一条路径
- **主题实测 27 个，全库跑完**。第一轮 7 个：autumn-warm / ocean-calm / ink-wash / editor-slate / bauhaus-pop / cyber-neon / monochrome-mag。第三轮补完剩余 20 个（2026-08-05，20 个并发子 agent，每个只读 `_common-tech.md` + 自己那份主题文件 + `md2html.py` 的 docstring + 一份范例 theme.json，实际花费约 $56）
- **20 份新产物逐份复核过**：过铁律自检 20/20 PASS；每份 `theme.json` 能逐字节重现对应 HTML 20/20；`audit-themes.py` 仍 0 条；变异测试仍 14 条全绿；仓库全程干净（20 个 agent 没有一个改主题文件、改脚本或手改 HTML）
- **宽度/居中修复已在三种结构上验证成立**：分章卡片（定宽落每张 `<section>`）、全文单卡（落那一张卡，卡内 0 处误加定宽）、无卡片（落每个顶层块）
- **editor-slate 复测通过**：正文强调蓝落点 11 → **68 处**，「给 strong 上色」这个修复成立
- **全库审计归零**：`scripts/audit-themes.py` 27 个主题 0 条

### 产物位置

实验目录 `~/code/skills/writing/wechat_test/litellm-multi-provider-gateway/out/`，每份 HTML 旁边配一份同名 `.theme.json`（**这是复现和继续的入口，比 HTML 本身重要**）。

**命名不统一，容易看花眼**，配对关系如下（都实跑验过：左边重新生成能逐字节得到右边）：

| 主题 | theme.json | 定稿 HTML |
|---|---|---|
| 第一轮 7 个 | `01-autumn-warm` / `02-ocean-calm` / `04-ink-wash` / `06-editor-slate` / `11-bauhaus-pop` / `20-monochrome-mag`（**不带版本号**） | 同名 + `-v1` 或 `-v5` |
| cyber-neon | `13-cyber-neon-v7-edge`（**带版本号**） | `13-cyber-neon-v7-edge.html` |
| 第三轮 20 个 | `<编号>-<主题名>` | `<编号>-<主题名>.html`（同名，无版本号） |

- 第一轮那 6 个主题的**无版本号 HTML**（如 `02-ocean-calm.html`）带旧宽度结构，**已作废**，别拿它当定稿——写复核脚本时按文件名循环很容易撞上这个坑
- cyber-neon 的 v2/v3/v4/v5/v6/v7-grid 是中间产物，可清理（**删文件前问用户**）

## 四、关键契约（教训换来的，别再踩）

### 发布相关

1. **正式发草稿只用 `create_draft` + JSON**；`test-draft` 的标题/摘要在 CLI 源码里硬编码
2. **封面用 `media_id`，正文图用 `wechat_url`**（`upload_image` 返回两个字段，别混）
3. **配置必须扁平 `wechat.appid/secret`**；`accounts:` 或 `proxy_url` 会触发付费 key 校验
4. `doctor` 的 `api.config FAIL` / `overall: blocked` 在免费路径是**预期状态**，只看 `wechat.config PASS`
5. 用户微信凭证已配好（勿外传勿改）；IP 白名单已配，家庭网络 IP 变动会报错，重查后更新即可

### 生成 HTML 相关

6. 五条铁律在 `references/wechat-html.md`，末尾自检脚本**生成后必须跑到 PASS**
7. **标题只进元数据注释，正文不渲染 H1**；去掉 H1 后 H2/H3 层级不上提，首个 h2 用 `h2_first` 单独处理
8. **背景与定宽分层**：主 `<div>` 铺满（背景、padding、**不写 max-width**），定宽落在内容块上
9. **定宽居中的样式串必须拼在主题样式之后**，且用 longhand。拼前面会被主题的 `margin` 简写覆盖——这个错肉眼看代码看不出来
10. **`---` 的语义降级按主题结构分三路**：卡片主题加大卡间距（`hr_gap`）、无卡片主题画分隔线（`hr`）、h2 自带边框的丢弃。测试文里 3 处 `---` 全部紧邻 h2

### 改主题相关

11. **规范行里不夹叙述、不留旧色值**。一句「别只挂在 em 上」会让审计脚本把该行判成 em 落点
12. **改完跑 `audit-themes.py` 到 0 条**；改检查脚本后做变异测试
13. **提交前把 diff 完整读一遍**。第二轮就是在 diff 里才看见 `cyber-neon.md` 同一段里留着「亮一档」和「暗一档」两个相反的指令——改写时静默留下旧条款，只有读 diff 才抓得到

## 五、判据沉淀在哪里

改主题前必读 `docs/theme-design-lessons.md`。第二轮立了规则 7（下面四条），第三轮全库跑完又立了**规则 8/9/10 和一条判例**（同一目标只在一处给色值 / 语法高亮色必须在自己代码底上够对比度、找不到就退回默认字色而不是造新色 / 暗色分层缺陷跨主题复发 / 主题专属分寸优先于通用兜底）——第八节 B 类的活都要照那三条做。

第二轮规则 7 的四条：

- **暗色主题上分层要往亮里走**。给 cyber-neon 行内 code 加底，第一次调成比卡底更暗的 `#10182a`，对卡底只有 **1.14:1**，用户反馈仍「看不清」；改成比卡底亮一档的 `#39456b`（1.65:1）才立得起边界。文字对比度从来不是这里的瓶颈（11.6:1）——**量错了对象就会连修两轮**
- **行内 code 的判据是「撞不撞形」，不是「用没用强调色」**。全库 17/27 给行内 code 派了强调色文字，其中 15 个带淡底、形状上和 strong 分得开，实测观感达标。真正翻车的只有 cyber-neon 那种「无底 + 强调色文字」
- **一个检查项报了大半个库，通常是判据下宽了，不是库烂了**。OVER 档第一版报了 15 个主题，收窄成「带底不报」后归零
- **变异用例的书写形态要够杂**。第一轮 4 个变异全是「行内 code 独占一行」，漏掉了「代码块与行内 code 写在同一行」（autumn-warm 就是这么写的），导致漏报

## 六、审计脚本现状

`scripts/audit-themes.py` 五档：`DEAD` 零落点 / `LOW` 只落在 em、链接等低频元素 / `DECOR` 只当边框细线 / **`OVER` 行内 code 无底色又用强调色当文字色** / `DESYNC` 改了组件没同步调色板。

> ⚠️ **它只能证伪，不能证实。**扫的是主题文件里有没有*声明*落点，不是产物里这个色出现了几次。全库跑完发现两个盲区（apple-air 审计 0 条但产物强调色只有 1 处；执行者在 `theme.json` 里造的新色它看不见），详见第八节 C 类和 lessons「机械审计方法」那节。**别把 0 条当成验收通过。**

支持豁免注记（HTML 注释，不进渲染，脚本查落点前先剥注释以免注记里的色值变成假落点）：

```
<!-- audit-ok: OVER #3d6a8a 一句话理由 -->
```

变异测试已进仓库，改审计脚本前先跑：

```bash
bash skills/md2publish-article/scripts/test-audit-themes.sh
```

14 条用例覆盖五档各自的正例、OVER 的三种真实书写形态（中文「底/文字」、纯 CSS、代码块与行内 code 同行）、散文句混在规范里、带前缀的 `*-color:` 不算文字色、豁免生效、豁免注记里的色值不能变成假落点；最后一条顺带要求真实主题库仍是 0 条。**这套用例本身也验过牙齿**：对审计脚本做了 9 种定点破坏（去掉截断、去掉「有底不报」守卫、不剥注释、不过滤豁免、逐档删掉 DEAD/LOW/DECOR/OVER、去掉 `color:` 的反向断言），9 种全部有用例变红。

## 七、悬而未决

- **暗色主题在微信浅色模式下可能全篇不可读**。cyber-neon 模拟「浅色模式把背景映射为白」后正文仅 1.52:1，且不存在两边都安全的配色。影响 cyber-neon / midnight-study / velvet-stage / retro-phosphor 四个。**必须真机双模式预览才能定论**，用户表示自己验证，结论未回
- **cyber-neon 的品红落点第 2 条挂在一个它自己没定义的元素上**。`cyber-neon.md` 写「提示卡里属于警示性质的那种用品红」，但该主题文件没有提示卡规范、`theme.json` 也没配 `alert`，这条永远不触发（它的第 3 条兜底说「两者都没有就不用品红」，所以不算破，但是条悬空引用）。暗色提示卡要配色验证，且 cyber-neon 正卡在浅色模式那个悬案上，暂不动
- **`wechat-finetune` 未实测**，eval 循环未跑
- **`md2publish-images` 从未实测**（宿主生图 + 上传封面未走通）

## 八、全库跑完暴露出来的问题（2026-08-05 第三轮，按性质分四类）

跑 20 个主题时，20 个执行者互不知情、各自撞墙，撞出来的重复形态比单个主题的毛病有价值得多——**同一堵墙被 3 个以上独立执行者撞到，就不是主题的特殊癖好，是缺口**。开工前先读 `docs/theme-design-lessons.md` 规则 8/9/10。

### A. 要改 `md2html.py`（按独立需求方数量排序）

| 缺什么 | 谁需要 | 备注 |
|---|---|---|
| `h2_suffix_html` | celadon-scroll、botanic-press、velvet-stage（**3 个**） | 都要「h2 文字两侧对称饰线」或尾缀符号，只能降级成单边。加法与 `h2_prefix_html` 完全对称，成本极低 |
| `footer` 的示例要补 `color` | 用了该字段的主题 **3/3 全 FAIL 一轮** | **根因是字段表里的示例本身没写 color**，不是使用者疏忽。铁律要求每个 `<p>` 有显式 color，脚本只自动补 `text-align`。改示例，不是加说明 |
| 有序列表前缀字段 | mint-breeze、botanic-press、blueprint-grid（**3 个**） | 脚本写死 `N.&nbsp;&nbsp;` 纯文本，`list_prefix_html` 只作用于无序列表。**本测试文 0 处有序列表，所以这轮没暴露成产物缺陷**——换一篇文章就会 |
| 警示 strong 按关键词分叉 | cyber-neon、blueprint-grid（2 个） | 见下方 C 类第 2 条，**已造成定稿产物的实际缺失** |
| 章节自增编号 | blueprint-grid（1 个） | 脚本无章节计数器，已用固定 `§` 代替 |
| 卡内首元素前插 HTML | aurora-flow（1 个） | **已被绕过**：改用 `card` 字段叠 `background-image` + `background-size` 做卡顶渐变条，视觉等价。不必为它加字段 |

### B. 要改主题文件

- **自相矛盾 4 例**（morandi-fog 的 h3 文字色、mint-breeze 与 aurora-flow 的引用块文字色、newsprint）：都是「色彩系统段」与「组件规范段」给同一目标两个值。判据和改法见 lessons 规则 8
- **语法高亮色对比度不够 4 例**（gilded-ink、terracotta-sun、aurora-flow、velvet-stage）：调色板里没有任何色在该主题自己规定的代码底上达 4.5:1。**四个执行者给出四种不同处置**，说明这条没有判据——见 lessons 规则 9
- **midnight-study 带着 cyber-neon 已修过的暗色分层缺陷**：规定行内 code 底 `#191512`，比卡底 `#2b241e` 更暗（规则 7 修掉的形态）。执行者按先例改用了主题自己的边线色 `#42382e`——**这是这轮唯一一次有意偏离主题文件字面**，产物是对的但文件是错的，不修文件下次重跑就变回去
- **apple-air 结构性失效**：见下方 C 类第 1 条

### C. 审计脚本的两个盲区（这轮最重要的发现）

1. **`audit-themes.py` 0 条不等于主题成立。** apple-air 审计 0 条，产物里唯一强调色只出现 **1 次**。它声明的三个落点——eyebrow 引导语（要逐节不同内容，脚本给不了）、em（中文技术文几乎为零）、关键数字（内容语义）——全部不可达，但都是主题文件里的白纸黑字，所以脚本一条不报。**而 apple-air 上一轮被记为「已修复」，那次修复恰恰是往主题文件里加了 eyebrow 条款：加了一条渲染不出来的规范，审计从此闭嘴，产物一点没变。**详见 lessons「机械审计方法」新增的那节
2. **对产物的落点普查还是手工的，没有固化进任何脚本。** 这轮 20 个主题的落点核对全靠执行者手跑一行 `Counter(re.findall(...))`。**值得补一个「产物落点普查」脚本**，把「主题文件声明了什么」和「产物里实际出现几次」两侧都机械化，两边对不上就报——这正好补上第 1 条那个洞。同源盲区：执行者为凑对比度在 `theme.json` 里造的新色（4 例里有 3 例造了色），主题文件里没有，审计同样看不见

### D. 我欠的收尾（明确的、小的）

- **ink-wash 定稿产物缺那枚朱砂印**：`04-ink-wash-v5.html` 结尾直接是 `</p></div>`。`footer_html` 字段现在有了，补一版即可。注意别和 `-v5` 的命名撞车
- **cyber-neon 定稿产物没兑现警示 strong**：`cyber-neon.md` 第 36 行规定「带『注意/警告/不要/会导致』语义的 strong 改用 `#ff4ba3`」，实测 `13-cyber-neon-v7-edge.html` 里 `#ff4ba3` 共 36 处，**落在 strong 上 0 处**。取决于 A 类那条字段怎么定。可行做法：`strong_alt: {"keywords": [...], "style": "..."}`，脚本查 strong 文本含不含关键词——那条规范本来就是按关键词写的，机械可判
- **candy-pop 主次强调实际是倒过来的**：标为「主强调」的 `#f28ba8` 只有 29 处，「深樱粉」`#d96687` 有 271 处。审计不报（29 不算接近 0 且有文字色落点）。**不一定是缺陷，要看真机观感**
- **retro-phosphor 的注释色在代码底上只有 4.10:1**：但那是主题明文指定的三级绿之一，改成中亮色就和默认字色没区别、丢掉分层。执行者照字面实现并上报，处理正确。真机双模式验证时一并看

### E. 机械层做不到、且不该硬凑的（留档，别反复重新发现）

「按内容语义分流」的装饰，`theme.json` 的字段模型管不到，脚本也不该为单个主题加字段：

- scarlet-tech：优点/缺点行用 ＋/－ 双色前缀；对比表里「推荐项」整格标红
- arena-charge：关键数据（配速/重量/比分）放大加粗
- velvet-stage：演出信息类条目用金色 ▸ 标
- celadon-scroll：诗词/古文引文居中排（无独立 block 类型）

这几条执行者都如实上报、没有手改 HTML 硬凑——**红线里「不许手改 HTML」正是为了让这类缺口浮出来，而不是被一次性手工修补盖住**。

## 九、其它下一步

1. **暗色主题真机双模式验证**（在用户那边）——现在四个暗色主题产物都齐了：`13-cyber-neon-v7-edge` / `18-midnight-study` / `26-velvet-stage` / `27-retro-phosphor`
2. **`wechat-finetune` 实测 + eval 循环**
3. **教程文档校订**：`@inbox/md-to-wechat-draft-free-path.md` 写于主题统一重构之前，未反映 `md2html.py`

批量跑主题的启动 prompt 在 `docs/handoff/batch-themes-prompt.md`（全库已跑完，但换文章或改完上面 A 类字段后要重跑时仍然用它——**记得先把第三节的判据同步成最新的**）。

## 十、Suggested skills

- `superpowers:verification-before-completion` — **本项目里这条是第一位的**。历史上宽度问题连续改错两次、cyber-neon 对比度连续改错两次，都是只验证了「我改的属性在不在」而没验证「渲染出来是什么样」，或者量错了对象。第三轮又添两个同源案例：apple-air 的「已修复」修的是一条渲染不出来的规范；ink-wash 和 cyber-neon 的定稿产物各自静默漏掉了主题规定的特性，直到有人去数产物里的落点才发现
- `superpowers:brainstorming` — 做第八节 C 类那个「产物落点普查脚本」之前先用它收敛：要比对哪两侧、报什么档、怎么避免重蹈 OVER 第一版「判据下宽报了大半个库」的覆辙
- `superpowers:test-driven-development` — 给 `md2html.py` 加字段（第八节 A 类）时，仓库里已有 `test-audit-themes.sh` 这个变异测试的范式可以照搬：先造会失败的用例，再实现
- `tech-writer` — 校订教程文档时（该文档按讲解体写成，改动要守住其风格）
- `skill-creator` — 改 skill 结构、跑 evals、做 description 优化

## 十一、环境速查

- md2wechat CLI 3.2.0 已装（npm 全局）；源码在 `~/code/skills/writing/md2wechat-skill/`（另一个 git 仓库，别混）
- 实验目录 `~/code/skills/writing/wechat_test/`
- 用户偏好：**传图、建草稿、git commit/push 一律先经用户确认**；成本敏感，大批量开跑前先报预估
- 用户在 main 分支上直接提交，不开特性分支
