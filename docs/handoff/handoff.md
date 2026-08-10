# Handoff：md2publish-skills 交接文档

> 更新于 2026-08-10（对比度护栏落地——脚本、单测、变异测试、116 条冻结基线全部入仓）。仓库位置：`~/code/skills/writing/md2publish-skills/`
>
> 本文只说「做到哪一步了」，不写 commit hash——提交本文本身就会移动 HEAD，写死了立刻就是错的。
> 要确认仓库实际状态，跑 `git log` / `git status`。
>
> 本文标题**不用「第 N 轮」计数**（故意的）：第六节第 1 条里的「第六轮…第十一轮」是普查
> 批次自己的历史计数，跟本文改了多少版是两套完全独立的编号，都叫「轮」纯属巧合。别把两者
> 当同一个数轴，也别再往标题里填一个新的序数——之前的标题曾经这么做过，结果和正文里的
> 「第八轮」撞车，见第六节第 1 条开头。

## 快速接手入口（读完这 8 行就能开工，细节再往下翻）

1. 项目：Markdown → 微信公众号可粘贴 HTML 的 skill 链。**唯一转换入口是 `skills/md2publish-article/scripts/md2html.py`，你的工作单元只有 `theme.json`**——别手敲 HTML、别另写脚本。
2. 26 个主题全部跑完并修过一轮；`theme.json` 26 份已入仓（`references/theme-json/`）；**原 20-monochrome-mag 已于批次 3 按用户裁定整体删除**（见第六节 1.8），HTML 产物在仓库外的 `~/code/skills/writing/wechat_test/litellm-multi-provider-gateway/out/`。
3. **动手前先跑第三节那九条基线**（审计 0 条 / 审计变异 16 绿 / md2html 测试 25 绿 / 产物自检 PASS / 普查变异 71 绿 / 普查跑通 / theme_lib 单测 17 绿 / contrast_lib 单测 0 条失败 / 对比度变异 16 绿 + 对真实库跑一遍报 116 条不达标、116 条基线、无新增），确认没被上一轮改坏。
4. **普查这条线已收口**：`census-themes.py` 首轮报 43 条，分六个批次处理完，现在是 **0 条未销 + 8 条已豁免、exit 0**。逐批做了什么、每条豁免的理由、哪些是真修哪些只是销声，全在第六节第 1 条——**接着往下做之前先读那一节**，尤其是 1.7（两条被内容类型限定的规范，机械字段接不住）和 1.8（monochrome-mag 已整体删除）。新的活看第六节第 3–5 条。
5. **这个 0 不等于主题库成立。**它只覆盖「主题文件声明的色，在产物里有没有落点」这一层。**对比度达不达标、观感成不成立、写给判断层的规范条款有没有被执行，这套脚本一概查不到**——本轮就有两处对比度不达标（terracotta-sun 的 2.58:1 与 3.39:1）是人量出来的，普查一声不吭；第六节第 1 条末尾还记着一条它**原理上永远抓不到**的真缺陷。把 0 读成完工，正是本项目立项要防的那个等式：当年 `audit-themes.py` 也报 0 条，四个「规范白纸黑字写着、产物里 0 处」的缺陷照样活着。
6. 因此本项目的通用做法是：**改完必须去数产物**，不是看自检 PASS 就算完。现在有 `python3 skills/md2publish-article/scripts/census-themes.py --counts <主题名>` 可以直接跑，不用每次手写 `Counter(re.findall(...))`。
7. 改任何主题文件之前必读 `docs/theme-design-lessons.md`（规则 11–14 和两条判例是第四轮新立的）。
8. 红线：**传图、建草稿、git commit/push 一律先经用户确认**；成本敏感，大批量开跑前先报预估。
9. **对比度护栏本轮已落地**（第六节第 2 条）：第四套机械脚本 `contrast-themes.py` + 冻结基线
   `references/contrast-baseline.tsv` 已入仓。真实基数是 **116 条**（立项那一轮一次性探针估的
   113 只是下限，用的装饰判据已被 spec 否掉，别再当事实抄）。**存量不阻塞，冻结基线只挡新增组合**，
   处置这 116 条是另一轮的事。这是第 5 条那句「0 不等于主题库成立」到目前为止最硬的一份证据。
10. ⚠️ **这个分支上可能有另一个会话在并行提交。**图片 skill 拆分那条工作线（`_shared/` 图片资产层）
    与本文这条线共用 `design/md2publish-image-skills`，它做过 `add -A` 式提交、把本轮四份未提交
    改动卷进过一个消息不符的提交里。**开工前先看一眼 `git log`，确认分支有没有在你不知情时前进。**

## 零、文档地图（先看这张表，别读错文档）

仓库里长期文档只有三份**主线**文档（按生命周期分工，不按主题分工，搞混了就会出现「两份文档抢同一个岗位」——第三轮就是这么乱起来的），外加一类**项目级**存档（specs/plans，只在接手某个具体计划时才翻）。

| 文档 | 什么时候读 | 生命周期 | 装什么 |
|---|---|---|---|
| **`docs/handoff/handoff.md`**（本文） | **接手时第一份**；每轮开工前 | **每轮重写** | 现在在哪、下一步做什么、基线怎么跑、红线 |
| **`docs/theme-design-lessons.md`** | **改任何主题文件之前必读**；改审计/普查脚本前读「机械审计方法」节 | **只增不删** | 判据与规则（规则 1–15 + 案例 + 判例） |
| **`docs/handoff/batch-themes-prompt.md`** | 要**批量重跑**主题时（换文章、或改完脚本字段后） | 按需刷新 | 开新会话用的可粘贴 prompt + 验收命令 |
| **`docs/superpowers/specs/*-design.md`、`docs/superpowers/plans/*.md`** | 接手一个**进行中的多任务计划**时（本文第六节还挂着该计划的未完成事项）；平时不用翻。注意该计划执行期间的逐任务 ledger 在仓库外的 SDD 工作区里、被 gitignore，克隆仓库的人拿不到，**所以本文与 lessons 不许依赖它** | 项目级，一次性——计划收尾后归档，只在发现记录本身有误时才回来更正（如本轮更正设计文档第八节 editor-slate 的分类） | 判据设计与理由（specs）、逐任务实施步骤（plans）。`census-themes.py` 就是这样一份计划（`2026-08-07-product-landing-census`）落地的产物，脚本 docstring 直接指向它的 design 文档 |

四条使用约定：

1. **`theme-design-lessons.md` 是承重文档**：除本文外还被 5 个文件引用（共 6 处），其中两处在脚本里（`audit-themes.py`、`test-audit-themes.sh`），另外三处在 `_common-tech.md`（2 处）、`INDEX.md`、`editor-slate.md`。**不要把它并进别的文档**——会同时断掉这些引用，并把长期判据埋进一份每轮重写的文件里。
2. **新学到的主题设计教训回写进 lessons，不要留在会话里，也不要另开文件。** 判断标准：这条结论换一篇文章、换一个主题还成立吗？成立就是 lessons 的规则；只描述「这一轮做到哪了」就是 handoff 的状态。
3. **允许在一轮进行中开临时的发现记录**（如 `phaseN-findings.md`）当草稿，但**必须在该轮收尾时溶解**——durable 的进 lessons，status 的进本文，测量数据就地写进对应的主题文件。**不许沉淀**，否则每轮攒一个，一年后 `docs/handoff/` 就没法看了。第四轮的 `phase2-findings.md` 已按此溶解删除；`product-landing-census` 项目收尾时同样核对过 `docs/superpowers/specs/`、`docs/superpowers/plans/` 下没有残留的 `*-findings.md`/`*-todo.md`。
4. **`docs/superpowers/specs/`、`docs/superpowers/plans/` 是某一轮 SDD（spec-driven development）计划的存档，不是活文档。** 它们记录一次多任务计划当时的判据设计和实施步骤，计划完成后不再逐轮更新——但如果之后发现里面有**事实错误**（不是决策变更），要回去更正并留痕，不能让错误的存档继续误导下一个读它的人。已发生一次：`2026-08-07-product-landing-census-design.md` 第八节把 editor-slate 两个色误分类为「失步」，2026-08-08 核实 tokenizer 源码后原地更正并加了更正说明。

## 一、项目是什么

基于 [md2wechat CLI](https://github.com/geekjourneyx/md2wechat-skill) **免费路径**（不买 `MD2WECHAT_API_KEY`）的公众号发布 skill 组合，四个 skill 各管一段：

- `skills/wechat-finetune/` — 成稿 → 公众号版 Markdown（重拟标题/删难懂与无关/开篇钩子/段落切短/frontmatter），原文不动、另存 `<name>.wechat.md`
- `skills/md2publish-article/` — Markdown → 微信可粘贴 HTML（排版指令来自本地主题库）
- `skills/md2publish-images/` — 封面/信息图（`--plan` 计划模式，交宿主 agent 生成）
- `skills/md2publish-draft/` — 推草稿箱（`upload_image` + `create_draft`，强制用户确认）

完整链路：`tech-writer`（读者懂不懂）→ `tech-writer-deslop`（像不像 AI 写的）→ `wechat-finetune`（适不适合公众号平台）→ `md2publish-article` → `md2publish-images` → `md2publish-draft`。前两个在另一个仓库 `~/code/skills/runskills/skills/`，三者判据不重叠、顺序不能反。

架构与职责边界见 `skills/README.md`；给人读的全流程教程在 `~/org/markdown/prompt/@inbox/md-to-wechat-draft-free-path.md`（仓库外，**写于主题统一重构之前，未反映 `md2html.py`**）。

## 二、生成 HTML 的工作方式（主路径，先看这节）

**不要手敲 HTML，也不要另写转换脚本。**机械层已经固化在 `scripts/md2html.py`：

```bash
python3 skills/md2publish-article/scripts/md2html.py <article.md> <theme.json> -o <out.html>
```

它包办转义顺序、`&nbsp;` 边界、span 不跨 `<br>`、结构包裹、语法高亮、定宽分层、H1 不进正文、代码块逐字节自校验。**你的工作单元是那份 `theme.json`**——把主题文件的散文规范翻译成内联样式串，外加脚本判断不了的语义判断。

**字段表在 `md2html.py` 的文件头 docstring 里，那是唯一的一份**（`_common-tech.md` 只指过来、不复制，所以没有第二处会漂）。第四轮新增 5 项：

| 字段 | 解决什么 |
|---|---|
| `h2_suffix_html` | h2 文字后缀，与 `h2_prefix_html` 对称，做两侧饰线 |
| `list_prefix_ol_html` | 有序列表序号前缀，`{n}` 占位；不配就退回写死的纯文本 `N.` |
| `strong_alt` | 按关键词给 strong 分叉（「注意/警告/不要/会导致」这类警示语义换一套样式） |
| `p_first` | 全文第一段的导语处理，与 `h2_first` 同构、各自独立计数 |
| `footer` 兜底色 | footer 是唯一没有 `p` 兜底的段落，主题没写 color 就自检 FAIL。示例已补 color，脚本也加了机制兜底 |

**加字段的准入线**（lessons 规则 14）：机械可判 + 无替代表达 + 当前静默丢失，三条同时成立才加。只满足前两条不该加。

## 三、九条基线（动手前先跑）

```bash
cd ~/code/skills/writing/md2publish-skills

# 1. 主题文件审计，要 0 条
python3 skills/md2publish-article/scripts/audit-themes.py

# 2. 审计脚本的变异测试，要 16 全绿
bash skills/md2publish-article/scripts/test-audit-themes.sh

# 3. md2html.py 的测试，要 25 全绿（含 26 份主题的逐字节回归）
bash skills/md2publish-article/scripts/test-md2html.sh

# 4. 产物过铁律自检，要 PASS
awk '/^python3 - <<.EOF.$/{f=1;next} /^EOF$/{f=0} f' \
    skills/md2publish-article/references/wechat-html.md > /tmp/selfcheck.py
python3 /tmp/selfcheck.py <out.html>

# 5. 产物落点普查脚本（census-themes.py）的变异测试，要 71 全绿
bash skills/md2publish-article/scripts/test-census-themes.sh

# 6. 普查脚本对真实库跑一遍——目前预期是 0 条未销 + 8 条已豁免、exit 0
python3 skills/md2publish-article/scripts/census-themes.py

# 7. theme_lib.py 共享原语的单元测试，要 17 全绿（`ok：0 条失败`，exit 0）
python3 skills/md2publish-article/scripts/test-theme-lib.py

# 8. contrast_lib.py 原语的单元测试，要 0 条失败
python3 skills/md2publish-article/scripts/test-contrast-lib.py

# 9. 对比度普查（contrast-themes.py）的变异测试要 16 全绿；对真实库跑一遍——
#    目前预期是 116 条不达标、116 条基线，无新增、exit 0
bash skills/md2publish-article/scripts/test-contrast-themes.sh
python3 skills/md2publish-article/scripts/contrast-themes.py
```

第 3 条的 PART B 从 `references/theme-json/` 读 theme.json、与实验目录里的定稿 HTML 逐字节比对。**故意改了某份 theme.json 之后要先重新生成它的 HTML 再跑**，否则那里报的红是预期内的改动，不是回归——别反过来改测试迁就它。语料目录缺失时 PART B 会整体 SKIP 并把退出码标红（静默跳过等于没有护栏）。

第 6 条**不是「要 0 条」的基线，是「要和上次一致」的基线**：`census-themes.py` 目前对真实库跑出 **0 条未销 + 8 条已由注记豁免**、exit 0。**这个 0 不等于主题库成立**——它只说明「主题文件声明的东西在产物里有落点」这一层没有已知违例；对比度是否达标、观感是否成立、规范写给判断层的那些条款有没有被执行，这套脚本一概查不到（第六节第 1 条末尾记着一条脚本原理上抓不到的真缺陷）。把 0 当成完工，正是本项目立项要防的那个等式。首轮报的是 43 条，第六轮（批次 1a）处理掉 6 条——5 条写豁免注记、1 条真改（celadon-scroll 补 `h2_suffix_html`）；第七轮（批次 1b）再处理掉 20 条——18 条靠收窄 `NEAR-ZERO` 判据、2 条靠 gilded-ink 把现造色转正；第八轮（批次 2）再处理掉 7 条——3 条 UNMOUNTED 补 `theme.json` 字段、1 条 INVENTED 退回正文色、3 条 INVERT 靠对调调色板角色标签（产物逐字节不变）；第九轮（批次 3）再处理掉 6 条——1 条 UNCARRIED 改错值、2 条 INVERT 改角色标签、3 条写豁免注记（其中 2 条连规范一起改写），另加 1 条普查报不出来的对比度失败（terracotta-sun 的 `highlight.keyword`）；同批还整体删除了 monochrome-mag 主题，带走它名下那 2 条；第十轮（批次 4）再处理掉 2 条——1 条 `INVERT` 靠改判据（只比散文面，代码面不计）、1 条 `NEAR-ZERO` 写豁免注记，**同时新暴露出 1 条 `INVERT 10-lavender-dusk`**；第十一轮（批次 5）撤回批次 3 给 mint-breeze 写的那条 `INVERT` 豁免注记——它的理由是拿含代码面的脏数字算的（自称「93 处落点、只差 3 处擦边」，实际 93 里有 77 处是 `highlight.string`/`key`，按散文面口径是 16 vs 78、阈值 26，会报不会擦边），**用假理由灭真发现，属于本项目立项要防的那个形状**，故删注记让它重新报出，与 lavender-dusk 同批裁决。六批的细节见第六节第 1 条开头的进度块。这一步的作用是确认这一轮没有意外新增或消失的发现——数字变了要么是有人动了主题文件却没更新第六节的清单，要么就是真的在按那份清单处理。处理完一批之后，这里的期望数字要跟着往下调，不要让某个旧数字在这份文档里僵化成永久数字。语料缺失时这一条同样会整体 SKIP 并标红（与第 3 条同一纪律）。

第 9 条**不是「要 0 条」的基线，是「不许新增」的基线**：`contrast-themes.py` 目前对真实库
报 **116** 条不达标、全部已冻结进 `references/contrast-baseline.tsv`，exit 0。
**存量不阻塞，`exit 1` 只在出现基线里没有的新组合时。**修好一条就从 `.tsv` 里删一行，
**只许减、不许增**——这条纪律脚本管不了（往 `.tsv` 里追加一行就能让新发现消声且 exit 0），
**唯一护栏是人读那份文件的 diff**。`--prune` 只删「产物里已经不存在」的存量行，永远不会
加行；往基线里加行的路只有一条，`--write-baseline`。

它与第 6 条的普查**回答的是两个不同的问题**，两个数字不要混：census 问「主题文件声明的色
在产物里有没有落点」，contrast 问「落下来的东西读不读得清」。census 报 0 条**不等于**
主题库的对比度成立——本轮实测 26 个主题里有 **20** 个存在不达标组合，而普查从头到尾一声不吭。

⚠️ **「只许减少、不许新增」这条只管改主题文件，不管改判据。**批次 4 改了 `INVERT` 的判据，
条数一减一增：terracotta-sun 那条消失、lavender-dusk 那条冒出来。**判据变锐利本来就该开始报
以前报不出来的东西**；一次判据修正如果只让条数下降，反而该先怀疑是不是在调参
（lessons「`INVERT` 曾经量的是语料的体裁」判例）。

剩下的 1 条**不是 ERROR**：`INVERT 10-lavender-dusk`（INFO）。删掉 monochrome-mag 之后，全库唯一那条 ERROR（`UNCARRIED`）也一并消失了。脚本输出本身不打严重度标签（`report()` 只报总数），读这份数字前先记住这个比例。

第 7 条不是可选项：`test-census-themes.sh`/`test-audit-themes.sh` 两套变异测试合计 78 条全绿，也测不出 `theme_lib.py` 两处纪律被破坏——它是这两处的**唯一**护栏：
- 去掉 `theme_lib.py:133`（`landings` 里 `_COLOR_PROP` 的 `(?<![-\w])` 守卫）会让 `background-color:` 被当成 `color:` 落地，污染 `DECOR`/`INVERT` 判定和 `--counts` 的「文字」列，`census-themes.py` 真实库输出照样不变（真实库当前没有踩中这个差异的样本）
- 去掉 `theme_lib.py:107`（`exemptions` 的前缀参数化，若被写死或写宽）会让 `audit-ok:` 注记也能销掉 `census-themes.py` 的发现，两套注记本该各认各的前缀、互不干扰

改 `theme_lib.py` 之后，三套测试（62 + 16 + 11）都要跑，缺一套都不能证明改动安全。

## 四、当前状态

### 主题库

- **26 个主题全部实测跑完**，清单见 `references/theme-prompts/INDEX.md`
- **`theme.json` 26 份已入仓**：`skills/md2publish-article/references/theme-json/<编号>-<主题名>.theme.json`。它不含任何与文章相关的内容，对任何文章可复用，**不必每次重新生成**
- **HTML 产物在仓库外**：`~/code/skills/writing/wechat_test/litellm-multi-provider-gateway/out/`。命名不统一——第一轮 6 个主题的定稿带 `-v1`/`-v5` 后缀，同名无后缀的那份是旧宽度结构、**已作废**。`test-md2html.sh` 里的 `PAIRS` 表是权威配对关系（每组都实跑验证过），**别按文件名循环**
- cyber-neon 的 v2–v6 中间产物**早已不在**（2026-08-09 核对 `out/` 时确认，不知何时清掉的）。
  现存的中间产物只剩三份：`13-cyber-neon-v7-grid.html` + 同名 `.theme.json`（v7 的另一个版式，
  `PAIRS` 不引用）、`13-cyber-neon.theme.json`（无版本号的旧份）。**没删**——cyber-neon 还挂着
  第六节第 3 条的真机双模式待验，v7-grid 是那次比对可能要用的另一个候选。删文件前问用户
- `out/` 里每个主题还各有一份 `*.theme.json` 副本，**测试不读它们**（PART B 的 `THEMEJSON`
  指向仓库内的 `references/theme-json/`，见 `test-md2html.sh:401`）。它们是历次生成时的留档，
  与仓库内那份可能已经不一致，**别拿它们当权威**

### 第四轮做完的

- **`md2html.py` 有测试了**：新增 `scripts/test-md2html.sh`，25 条。PART A 是字段行为用例（每个字段配一条「没配时默认行为不变」的对照），PART B 是全库主题的逐字节回归（第三轮是手工做的；当时 27 份，删掉 monochrome-mag 后 26 份）。对脚本做过定点破坏验证这张网有牙齿——去掉 h3 前缀输出，15 个主题立刻变红
- **5 个新字段**（见第二节），全部按 TDD 加，每条都先看着它红且红在预期原因上
- **8 个主题修完**：
  - arena-charge（h2 黑块与正文左边缘不齐——`inline-block` 撞定宽层；旁注块实心黑改浅灰底）
  - apple-air（唯一强调蓝全文 1 处 → 17 处）
  - velvet-stage（`━` 读成「一」→ 改 `✦` 两侧对称；幕布红 2.68:1 → 5.22:1）
  - retro-phosphor（正文改等宽、去圆角、绿改 `#00ff41`、补终端骨架符号）
  - morandi-fog（h3 标题 2.41:1 → 5.26:1）
  - mint-breeze（引用块文字 3.87:1 → 5.01:1）
  - aurora-flow（删死色、现造色转正、补代码块子调色板）
  - newsprint（导语从 0 处 → 1 处落地）
- **主题 `.md` 与 `theme.json` 已同步**，两侧逐值比对一致
- **文档按生命周期重组**：四份 720 行 → 三份（见第零节）。`phase2-findings.md` 已溶解删除——
  durable 的进了 lessons（规则 11–14 + 两条判例），status 的进了本文，测量数据早已就地写进
  各主题文件的说明里。根因不是「文件太多」，是 handoff 过时之后 findings 事实上接管了它的岗位，
  **两份文档抢同一个岗位**才是乱的来源

### 第五轮做完的（`product-landing-census` 项目，Task 1–8）

- **产物落点普查脚本落地**：新增 `scripts/census-themes.py`（三层 L1/L2/L3、九档判定 + `STALE-NOTE`）
  与 `scripts/theme_lib.py`（`strip_comments`/`spec_lines`/`palette`/`element_of`/`theme_pairs`/
  `exemptions`/`landings` 七个共享原语；批次 4 又加了 `prose_landings`，共八个）、
  `test-census-themes.sh`（当时 54 条变异测试，**现为 71 条**，见第三节基线 5）、
  `test-theme-lib.py`（当时 11 条，**现为 17 条**）。这是第四轮遗留的「唯一没有护栏的一层」，见第零节
  文档地图新增的一行、`docs/theme-design-lessons.md`「机械审计方法」节
- **对真实库跑了一轮，报出 43 条**，逐条复核后给出处置建议。**用户裁决「本轮只出建议、
  不改文件」**——主题 `.md` 与 `theme.json` 一律未动，43 条全部悬置，等下一轮用户逐组
  拍板再执行。建议的分组、执行顺序与要点已溶解进本文第六节第 1 条（原先那份逐条建议书
  写在项目工作区里，是 gitignore 的临时文件，按第零节第 3 条的纪律于收尾时溶解删除）
- **两处历史记录更正**：`docs/superpowers/specs/2026-08-07-product-landing-census-design.md`
  第八节把 editor-slate `#d2a8ff`/`#ffa657` 错分类为「失步」，已核对 `md2html.py` tokenizer
  源码后更正为「无挂载点」（新增 lessons 规则 15）；bauhaus-pop 的 `strong_alt` 发现此前在
  两处归档文件里有相反结论，已核实为误报（命中的是调色板角色标注，不是指令句），
  见第六节第 1.5 条
- **lessons 新增规则 15** + 「机械审计方法」节新增 `census-themes.py` 的完整说明、
  判据下窄比下宽更危险的镜像教训（含 `REF_EXCLUDE` 险些误伤 aurora-flow 立身缺陷的实例）、
  关键词判据的两个自毁陷阱、变异测试要证死错误实现的纪律、L3 的已知盲区

### 第六轮做完的（普查 43 条的处置，批次 1a–6）

- **43 条全部处置完毕**，现为 0 条未销 + 8 条已豁免、exit 0。逐批明细在第六节第 1 条
- **真改了 8 条**：celadon-scroll 补右侧饰线、ink-wash 补 `footer_html`、cyber-neon 与
  blueprint-grid 补 `strong_alt`（前者是四大立身缺陷之一，**现在产物里真的出现 4 次**）、
  bauhaus-pop 的过期色值、terracotta-sun 的 `highlight.comment` 与 `highlight.keyword`
  两处对比度不达标（2.58:1 / 3.39:1，**都是人量出来的，普查一声不吭**）
- **改了两次判据，都是先补变异测试再改**：`NEAR-ZERO` 按 `theme.json` 挂载键收窄
  （锚在 `container` 上，一次消掉 18 条结构性误报）；`INVERT` 改成只比散文面
  （代码面不计，证据是行内 code 在三个互不相干的主题里各贡献恰好 193 处，是语料常数）。
  **两次都在评审里被查出「按测试结果反推理由」的痕迹并改正**——见 lessons
- **改了 7 个主题的角色标签**（gilded-ink / candy-pop / autumn-warm / ocean-calm /
  spring-fresh / lavender-dusk / mint-breeze）：都是**描述错了不是渲染错了**，
  `theme.json` 未动、产物逐字节不变
- **删除 monochrome-mag 主题**（用户裁定不再使用），主题库 27 → 26，逐字节回归随之 27 → 26
- **撤回一条自己写错的豁免注记**（mint-breeze），见第六节第 1 条的 ⚠️ 块

## 五、关键契约（教训换来的，别再踩）

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
10. **承担定宽的元素不能是 `display: inline-block`**——auto 外边距会算成 0，元素贴容器边而正文居中，宽屏下错开。要收缩色块就用 `h2_text_style` 落到内层 span（lessons 判例）
11. **`---` 的语义降级按主题结构分三路**：卡片主题加大卡间距（`hr_gap`）、无卡片主题画分隔线（`hr`）、h2 自带边框的丢弃

### 改主题相关

12. **规范行里不夹叙述、不留旧色值**。一句「别只挂在 em 上」会让审计脚本把该行判成 em 落点
13. **改完跑 `audit-themes.py` 到 0 条**；改检查脚本后做变异测试。第五轮起还要跑 `census-themes.py`——它不是「要 0 条」，是「按第六节第 1 条的清单处理到期望的那个数」，处理完一批要回写第三节第 6 条的期望数字
14. **改完主题 `.md` 要同步 `theme.json`**（反之亦然）。两者失步没有任何检查会报——第四轮自己制造过一次；`census-themes.py` 的 L1 层（`UNCARRIED`/`INVENTED`）现在能报这个，但只在跑了普查脚本之后
15. **批量替换有两个咬人的形态，都只有事后核对才抓得到**。第四轮各踩一次：
    - **替换吃掉了自己的说明文字**：velvet-stage 做全局色值替换时把警告里的旧色值也换了，「不要调回 `#a04252`」变成「不要调回 `#c97a86`」，一句自相矛盾的规范。**全局替换要么先做、后写说明，要么说明里根本不写旧色值**
    - **链式替换：前一条规则的输出成了后一条的输入**。本文重编号时先 `第四节→第三节`、再 `第三节→第二节`，结果原本的第四节被连着换了两次，指到了第二节。**一批替换里若新值可能命中另一条规则的旧值，就不能顺序跑**——要么一次性映射，要么倒序，要么替换完逐条核对指向
16. **提交前把 diff 完整读一遍。**上面两条都是在核对时才发现的，代码和文本本身看不出问题——被替换掉的地方语法完全正确，只是意思错了

## 六、剩下的活（按价值排序）

> `docs/superpowers/specs/`、`docs/superpowers/plans/` 里大约十处 `第六节第 N 条` 的
> 交叉引用（多数在 `2026-08-07-product-landing-census-design.md`/`.plans` 里），指的是
> `product-landing-census` 那一轮当时的编号，**在本次重排之前就已经是过期的**（本轮只是
> 让其中 3 处因为数字算术上的巧合恰好又对上，剩下约 8 处仍是错的）。按第零节第 4 条，
> specs/plans 是存档、不是活文档——**不要信它们指的编号，也不要回头去改它们**，那不是
> 本次改动的范围，改了反而违反「存档只在事实错误时更正、不为编号漂移去动」的纪律。

### 1. 普查报出的 43 条：已全部处理完（脚本与处置都已收口）

> **进度：六个批次已全部执行完，43 → 0 条未销 + 8 条已豁免、exit 0。**下表是批次 4–6 的明细；批次 1a/1b/2/3 的明细见下方各小节。
>
> | 组 | 发现 | 处置 | 结果 |
> |---|---|---|---|
> | 4a | `INVERT 23-terracotta-sun #c2593b` | **改判据**（`census-themes.py`） | **判据缺陷，不是主题缺陷**：`INVERT` 原先拿全部文字落点比较，而语料是一篇 API 网关文，行内 code 与代码块密度拉满。逐色拆代码面 / 散文面后，三个互不相干的主题挂在 `inline_code` 上的色**各得到恰好 193 处**（terracotta-sun `#8f3f28` 284 = 代码面 270 + 散文 14；gilded-ink `#8f6f2f` 253 = 193 + 60；candy-pop `#d96687` 271 = 193 + 78）——**193 是语料的常数，不是主题的属性**。判据改成只比散文面（`<pre>` 块 + 行内 code 一律不计），这条随之消失：主强调散文面 69，参照色只剩 14，本来就没有倒置。变异测试 62 → 71（新增 9 条，十一种错误实现逐个证死）；`theme_lib` 新增 `prose_landings`，单测 11 → 17。`theme.json` 与主题 `.md` 一个字没改，**产物逐字节不变**（26/26 绿） |
> | 4b | `NEAR-ZERO 19-candy-pop #e8f2f9` | **写豁免注记** | **销声（不是死色）**：`candy-pop.md:36` 的 `em` 样式串里**没有 `font-style: italic`**，所以 `*文字*` 渲染出来是一枚圆角浅蓝高亮块、不是斜体——它服务的是「高亮」这个用法。用户确认高亮是常用写法，所以批次 1b 记的「本人不用斜体 → 规则 1 死色」这个读法**作废**（见 1.5，那三条候选修法 (a)/(b)/(c) 一并作废）。产物里只有 1 处，是因为本篇语料通篇只有 1 个 `*em*`（实测 `<em` 1 次、`#e8f2f9` 1 次），是语料的性质。`candy-pop.md` 的样式与 `theme.json` 均未改 |
> | 4c | **新暴露** `INVERT 10-lavender-dusk #7f6a9e` | 批次 6 处置 | 薰衣草全量文字落点 219 看着很健康，**散文面只有 9**（h3 前缀 ✦ 7 + em 1 + 落款 1），那 210 处全是行内 code（193）与 `highlight.keyword`（17）；而深暮紫 `#5d4b7c` 散文面 73。**旧判据一直被那 193 处喂饱，从没报过它。**处置见第 6 批 |
> | 5 | `INVERT 15-mint-breeze #2fa47e`（原已豁免） | **撤回豁免注记** | 批次 3 写的那条注记理由不实（详见下方 ⚠️），用假理由灭真发现；删注记让它重新报出，与 4c 同批裁 |
> | 6 | 上述两条 `INVERT` | **改角色标签**（`.md`，产物零变化） | 查挂载表确认两者都是**标签错了不是渲染错了**。lavender-dusk：`#7f6a9e` 挂 `h3_prefix_html` / `em` / `inline_code` / `footer_html` / `highlight`，散文面 9；真正扛 `h2` + `strong` 的是 `#5d4b7c`（散文面 73）。mint-breeze：`#2fa47e` 挂 `h3_prefix_html` / `list_prefix_html` / `highlight`，散文面 16；扛 `h2` + `strong` 的是 `#1e7a5c`（散文面 78）。按批次 3 给 gilded-ink、candy-pop 定下的写法把装饰色改名，并给实际主强调补角色标注。**`theme.json` 一字未动，产物按构造逐字节不变** |
>
> ⚠️ **批次 4 查出一条已豁免注记的理由不实；批次 5 已按用户裁定撤回该注记**（下文保留原委，因为它是本项目最值得记住的一次自伤）：
> `mint-breeze.md:16` 的 `census-ok: INVERT #2fa47e` 写的理由是「文字落点 93（h3 前缀 ✓、
> 无序列表前缀 ✓），深叶绿 288，三分之一线 96，只差 3 处」。两处都不成立了——
> (1) 换成散文面口径后是 **16 对 78、三分之一线 48**，不再是擦边；
> (2) 更要紧的是**原注记的归因本来就是错的**：93 里只有 16 处落在它点名的 h3 前缀与列表前缀上，
> 另外 77 处是代码块内的 `highlight.string`/`key`。注记仍然销得掉那条发现（不报 `STALE-NOTE`），
> 所以脚本不会提醒任何人——**这正是「注记从写下来那一刻就是错的」那类 Trap 3**。
> 批次 4 按「不重访已豁免发现」的边界没有动它，批次 5 经用户裁定删除该注记，让发现重新报出，批次 6 与 lavender-dusk 同批处置完毕。
>
> **留给后来者的教训**：这条注记之所以写错，是因为写的时候拿的是**含代码面的脏数字**（93），而没有先查挂载表。挂载表一查就知道那 93 里有 77 处在 `highlight` 上。**写豁免注记前必须先查该色挂在哪些键上**——注记的理由是要留存多年的，写错的理由比不写更坏，因为它看起来已经有人想过了。
>
> **进度：批次 3（第九轮）已执行，10 → 4。** 用户裁决了五组内容修正，全部落地：
>
> | 组 | 发现 | 处置 | 结果 |
> |---|---|---|---|
> | 2a | `UNCARRIED 11-bauhaus-pop #1e5aa8` | **改主题 `.md` 的错值** | **真修复（描述层）**：`bauhaus-pop.md` 那句「红 `#be1e2d` 和蓝 `#1e5aa8` 不进代码块」引用了一个全仓库都不存在的蓝，该主题的蓝是 `#005baa`。改完 `theme.json` 未动、产物逐字节不变。**顺带复算了那两个对比度数字**：`#be1e2d` 在墨黑 `#171614` 上 2.94、`#005baa` 2.6495 → 仍是 2.65，与原句写的数字一致，所以数字不用改（旧建议书 §四 说 `#005baa` 是 2.51，那是错的，已在该文件就地更正） |
> | 2b | `INVERT 23-terracotta-sun #c2593b` 同源的对比度失败 | **改 `theme.json` + 补 `.md` 语法高亮条款** | **真修复**：`highlight.keyword` 的赤陶橙 `#c2593b` 在该主题代码底 `#efe0cd` 上只有 **3.39:1**（已复算），普查报不出来（色是调色板声明的、也确实渲染）。走规则 9 第二步退回正文色 `#4f382b`（8.39:1）+ `font-weight: 700`，与上一批 `comment` 的 `#4f382b` + italic 同形——**这个底上整个调色板只有 `#4f382b` 与 `#8f3f28`（5.57）过 4.5，而 `#8f3f28` 已被 string/key 占住，橄榄绿 `#6f7a4d` 3.55 不达标且被 `:45` 限死**，所以没有第二个选择。`.md` 补了一行语法高亮条款把这个取色链路写死。产物已重生成 |
> | 2c | `INVERT 09-gilded-ink #b08a3e`、`INVERT 19-candy-pop #f28ba8` | **改主题 `.md` 的角色标签** | **改的是描述，不是设计**：与批次 2 那三条不同，**这里压过主强调的色本来就标着「strong 用」，不是「副强调」，所以不能对调**——错的是把一支装饰色叫成「主强调」。gilded-ink 的古金总 43 = 文字 16 + 线 27（h2 上下金线、引用左线、◆ 前缀），改标「金线与饰记，装饰用」；candy-pop 的樱粉 29 处文字（h3 圆点、列表前缀、代码关键字），改标「符号与前缀装饰用」。`theme.json` 未动，**产物逐字节不变**（已核） |
> | 2d | `INVERT 15-mint-breeze #2fa47e` | **写豁免注记** | **销声（阈值擦边）**：薄荷绿文字落点 93，深叶绿 288，判据的三分之一线是 96——**只差 3 处**，而 93 处文字落点本身不弱。注记把这三个数字写进理由里 |
> | 2e | `UNMOUNTED` 15-mint-breeze / 24-botanic-press `list_prefix_ol_html` | **改写规范 + 写豁免注记** | **修正了描述 + 销声**：两条规范都按内容类型限定（「步骤类」/「物种、条目清单」），全局字段接不住（1.7）。两处规范行都重写成**显式声明为判断层手工可选项、机械路径退回纯文本 `N.`**，再各写一条豁免注记。mint-breeze 那条顺带写明示例的 `width: 20px` 正圆只演示单位数，手工用到两位数要改 `min-width` |
>
> 批次 3 只有 2b 改产物（terracotta-sun 已按第三节纪律先重生成再跑 `test-md2html.sh`）；
> 2a/2c/2d/2e 全部零渲染风险。同一批还**整体删除了 monochrome-mag 主题**（用户裁定永不使用），
> 主题库 27 → 26，逐字节回归 26/26 绿，见 1.8。
>
> **进度：批次 2（第八轮）已执行，17 → 10。** 用户逐组裁决了三组，全部落地：
>
> | 组 | 发现 | 处置 | 结果 |
> |---|---|---|---|
> | 1 | `UNMOUNTED` 04-ink-wash `footer_html`、13-cyber-neon `strong_alt`、22-blueprint-grid `strong_alt` | **补 `theme.json` 字段** | **真修复**：三条规范原先无挂载点、静默丢失。ink-wash 按 `ink-wash.md:47` 的主写法配 `footer` + `footer_html`（朱砂 `□`，产物 +1 处）；cyber-neon 按 `:36` 配「注意/警告/不要/会导致」→ 品红（语料里 4 处 strong 变色）；blueprint-grid 按 `:35` 配「注意/警告/易错」→ 批注橙褐（本语料 0 处命中，字段已就位）。三处都只用该主题调色板内已有的色 |
> | 1 | `UNMOUNTED` 15-mint-breeze `list_prefix_ol_html` | **不动，退回用户** | `mint-breeze.md:44` 写的是「**步骤类**有序列表前缀数字加浅绿圆底」——按内容类型限定，和 botanic-press 的「物种/条目清单**可用**褐色序号」同类。机械字段管不了「步骤类」，配上去会给每篇文章的每个有序列表都套圆底徽章；且那个徽章是 `width: 20px; border-radius: 50%` 的单位数圆，两位数会撑破。见下方 1.7 |
> | 2 | `INVENTED 23-terracotta-sun #9c8a72` | **改 `theme.json`，退回正文色** | **真修复**：`#9c8a72` 在该主题自己的代码底 `#efe0cd` 上只有 **2.58:1**（已复算），规则 11 直接适用，不许补进调色板。走规则 9 第二步退回正文色 `#4f382b`（8.39:1）+ `font-style: italic` 保住与普通代码文字的区分 |
> | 3 | `INVERT` 01-autumn-warm / 02-ocean-calm / 03-spring-fresh | **改主题 `.md` 的角色标签** | **改的是描述，不是设计**：三个主题结构同形，标为「副强调」的深色（`#c06b4d`/`#3d6a8a`/`#4a8058`）实际挂在 h2/h3 文字、strong、行内 code、表头、代码高亮上（文字落点 317/333/317），标为「主强调」的亮色（`#d97758`/`#4a7c9b`/`#6b9b7a`）挂的是 h2 符号、h3 短线、列表前缀、引用边框、em（各 21）。设计本身成立（深色承担文字、亮色做装饰），错的是标签。三份 `.md` 对调标签并在色值后写明各自的落点分工，`theme.json` 未动，**产物逐字节不变**（已核） |
>
> 批次 2 的注意事项：Group 1 与 Group 2 改产物，按第三节纪律**先重生成 4 份 HTML 再跑
> `test-md2html.sh`**；Group 3 只改 `.md`，重生成后与定稿逐字节比对确认不变。
> 顺带量到一条**未处置**的线索：terracotta-sun 的 `highlight.keyword` `#c2593b` 在同一个
> 代码底 `#efe0cd` 上只有 **3.39:1**，同样低于 4.5——与 1.5 末尾那条对比度线索同源，
> 本批未获授权处理，动它之前要连 `INVERT #c2593b` 一起看。
>
> **进度：批次 1b（第七轮）已执行，37 → 17。** 用户逐条裁决了三项，全部落地：
>
> | 项 | 发现 | 处置 | 结果 |
> |---|---|---|---|
> | 1 | 18 条结构性 `NEAR-ZERO` | **改判据**（`census-themes.py`） | **销声**：判据是 `"container" in mounts and mounts <= {container, footer, footer_html}`——**锚点是 `container`（铺满整页，落 1 次等于全覆盖），不是「`build()` 只发一次」**。变异测试 54 → 62，十种错误实现各自被证死；`ZERO` 未动，candy-pop 那条挂 `em` 的照报。详见 1.3 与 lessons「判据可以下窄」节 |
> | 2 | `INVENTED 09-gilded-ink #6a4f1a` / `#7a5b1f` | **改主题 `.md`**（走 1.1 的 (B) 路） | **改判断**：用户比对渲染后选择保留现观感，两支金补进 `gilded-ink.md` 调色板 + 语法高亮组件行，并写明明度被对比度钉住（代码底 `#f5f1e8` 上 6.78 / 5.57；调色板里两支金 4.16 / 2.84 全不达 AA）。`theme.json` 未动，**产物逐字节不变**（已核） |
> | 3 | `NEAR-ZERO 19-candy-pop #e8f2f9` | **裁定为真缺陷，但修法未定 → 未动文件** | 用户裁定它是规则 1 的死色（本人写作基本不用斜体）。但**主题自己的规范推不出唯一修法**，按指令停手上报，见 1.5 |
>
> 批次 1b 的注意事项：`audit-themes.py` 在第 2 项上先报了 `DEAD`+`DESYNC`——只把色补进调色板
> 不够，组件规范里也得给落点（lessons 规则 9 已补记）。另外收窄判据让 `test-census-themes.sh`
> 里 15 条既有 L2 用例的期望值少了那条 `NEAR-ZERO #ffffff`，是预期变化不是回归。
>
> **进度：批次 1a（第六轮）已执行，43 → 37。** 用户只授权了三组「靠机械事实、不含审美
> 判断」的处置，已全部落地：
>
> | 组 | 发现 | 处置 | 依据 |
> |---|---|---|---|
> | A | `UNMOUNTED 11-bauhaus-pop strong_alt` | **豁免注记**（误报） | 唯一触发行是 `bauhaus-pop.md:14` 的调色板角色标注，不是指令句；见 1.5 与 §十 |
> | B | `UNCARRIED 06-editor-slate #d2a8ff` / `#ffa657` | **豁免注记**（无挂载点） | tokenizer 只发 5 类，没有函数名/参数类，见 lessons 规则 15 |
> | B | `NEAR-ZERO 06-editor-slate #ffffff` | **豁免注记**（正当设计） | 挂 `card`，`card_mode: "single"`，落点恒 1 |
> | B | `ZERO 06-editor-slate #bc4c00` | **豁免注记**（语料无 WARNING） | `alert.warning` 已正确挂载，通路完整 |
> | C | `UNMOUNTED 14-celadon-scroll h2_suffix_html` | **真改 `theme.json`** | 补 `h2_suffix_html`，用调色板已有的 `#d8cfb8`，右侧饰线补齐 |
>
> **前四组是「销声」不是「修复」**——文件里那些颜色的处境一点没变，只是记录了为什么可接受；
> 只有 C 改变了产物（celadon-scroll 的 HTML 已按第三节纪律先重生成、再跑 `test-md2html.sh`）。
>
> **六批之后仍然未动的，只剩一条**：1.4 那条脚本原理上抓不到的 cyber-neon 警示提示卡——
> 它不在 43 条里，普查永远不会报它，**必须由人带着走**。
> （`INVERT 10-lavender-dusk` 与 `INVERT 15-mint-breeze` 已于批次 6 处置；candy-pop 的
> `NEAR-ZERO #e8f2f9` 与 terracotta-sun 的 `INVERT #c2593b` 已于批次 4 处置。）

**脚本本身已完成，第五轮做的**（见第四节）。`census-themes.py` 现在把「主题文件声明了什么」
和「产物里实际出现几次」两侧都机械化了，本仓库已知四次「主题文件白纸黑字写着、产物里 0
处」——apple-air 的 eyebrow、cyber-neon 的警示 strong、newsprint 的导语、aurora-flow 的
次级灰——曾经全部逃过审计/自检/逐字节回归三道检查，现在这一层有护栏了。

**没有完成的是处理结果**：首轮对真实库跑出 **43 条、exit 1**，**用户裁定那一轮只出建议、
不改文件**——主题 `.md` 与 `theme.json` 一律未动。下面 1.1–1.6 是当时逐条复核后给出的
**处置建议**（1.7 是批次 2 补写的），**除上面四个进度块列的 41 条外一条都没有被采纳**。读的时候当待办清单，不是判决书：每一条都还需要用户
拍板，尤其是标了「审美判断」的那些。动手时按第五节第 12/13/14/16 条的老规矩：规范行不留
旧值、改完跑 `audit-themes.py`/`census-themes.py` 到期望条数、`.md` 与 `theme.json` 同步、
提交前把 diff 完整读一遍。

#### 1.1 建议处置的分布，以及建议的执行顺序

| 建议处置 | 条数 | 是什么 | 状态 |
|---|---:|---|---|
| 判据问题 → 改脚本 | 18 | 「背景色只挂在 `container`」的结构性 NEAR-ZERO，见 1.3 | **✅ 批次 1b 已执行** |
| 正当设计 → 写豁免注记 | 11 | 6 条 INVERT + editor-slate 4 条 + bauhaus-pop `strong_alt` 误报 | editor-slate 4 条 + bauhaus-pop 1 条已办（批次 1a）；6 条 INVERT 里 3 条（autumn-warm / ocean-calm / spring-fresh）**批次 2 改走「对调角色标签」**、gilded-ink 与 candy-pop 2 条**批次 3 改走「把装饰色的『主强调』标签改掉」**（不是对调，压过它的色本来就标着「strong 用」）、mint-breeze 1 条批次 3 **真写了豁免**（阈值只差 3 处）。**六条 INVERT 里只有一条最后走了豁免，其余都是改描述**——遇到 INVERT 先问「是不是标签错了」，见 lessons 判例 |
| 真缺陷 → 改 `theme.json`（不动 `.md`） | 7 | 5 条 UNMOUNTED + terracotta-sun 的 INVENTED + cyber-neon 的 `alert` | celadon-scroll 1 条已办（批次 1a）；ink-wash / cyber-neon / blueprint-grid 3 条 UNMOUNTED + terracotta-sun 的 INVENTED **✅ 批次 2 已执行**；mint-breeze 那条批次 2 退回用户、**批次 3 与 botanic-press 那条一起改写规范 + 写豁免**（见 1.7）；cyber-neon 的 `alert` 未办 |
| 待定 → 需用户拍板 | 5 | monochrome-mag 2 条、candy-pop 2 条、botanic-press 1 条 | candy-pop 的 `INVERT` **✅ 批次 3 改标签**、botanic-press 那条 **✅ 批次 3 改写规范 + 豁免**；candy-pop 的 `NEAR-ZERO` **✅ 批次 4 写豁免注记**（1.5 里那个「不用斜体所以是死色」的前提已作废：`em` 样式串没有 `font-style: italic`，渲染出来是高亮块不是斜体）；monochrome-mag 2 条 **✅ 批次 3 随主题整体删除**（1.8） |
| 真缺陷 → 改主题 `.md`（须同步 `theme.json`） | 3 | bauhaus-pop 错值 1 条 + gilded-ink 现造色 2 条 | gilded-ink 2 条**✅ 批次 1b 已执行**（走 (B) 路，产物不变），bauhaus-pop 的错值 **✅ 批次 3 已执行**（`#1e5aa8` → `#005baa`，2.65:1 复算后不变） |
| **合计** | **44** | 脚本报的 43 条 + 1 条脚本原理上抓不到的（见 1.4） | 已处理 43 条，剩 0 条 + 1 条抓不到的；另有批次 4 新暴露的 1 条不在这 44 里 |

前三档基本是**机械事实驱动**的（对比度数字、`theme.json` 里有没有这个键、tokenizer 有没有
这个类），可以照着核；「待定」那 5 条、外加 INVERT 里 gilded-ink 与 ocean-calm 两条，
**含美学判断，只有用户能拍**。

**建议按风险从低到高分四批**，每批之后跑一遍 `census-themes.py`：

1. **零渲染风险批**（改完产物逐字节不变）：bauhaus-pop 的错值（**✅ 批次 3 已做**）、
   gilded-ink 把两个现造色补进调色板（**✅ 已做**）、candy-pop 改角色标签（**✅ 批次 3 已做**），
   以及全部豁免注记。autumn-warm / ocean-calm /
   spring-fresh 三条 INVERT 也走了这一批的形态（**✅ 批次 2 已做**：对调角色标签，产物不变）
2. **只加 `theme.json` 字段批**：5 条 UNMOUNTED + cyber-neon 的 `alert`。产物会变，
   `test-md2html.sh` 的 PART B 预期变红，**要先重新生成 HTML 再跑**（第三节已写这条纪律）。
   **✅ 批次 2 做掉 3 条**（ink-wash / cyber-neon / blueprint-grid）；mint-breeze 与
   botanic-press 两条 **✅ 批次 3 处理**，但**不是补字段**——是改写规范 + 写豁免（1.7）；
   cyber-neon 的 `alert` 仍未办
3. **判据改动批**：18 条结构性 NEAR-ZERO，见 1.3。**必须先补变异测试再改判据**（**✅ 已做**）
4. **待定批**：等用户结论

**这 44 条里剩下没做的只有第 2 批的 cyber-neon `alert`（1.4，普查报不出来）**——
terracotta-sun 的 `INVERT #c2593b` 与 candy-pop 的 `NEAR-ZERO` 均已于批次 4 处置。
**另有一条不属于这 44 条的新发现**：`INVERT 10-lavender-dusk`，批次 4 改锐判据后才露头，见上方进度块 4c。

#### 1.2 最要紧的三条

- **celadon-scroll 少了右边那根饰线**（`UNMOUNTED 14-celadon-scroll h2_suffix_html`）。
  `celadon-scroll.md:28` 写的是 h2「居中 + **两侧对称**饰线」，而
  `14-celadon-scroll.theme.json` 只有 `h2_prefix_html`——右边那根线在产物里根本不存在，
  每个 h2 都是不对称的。修法是加一行 `h2_suffix_html`，与已有 prefix 逐字对称，色值
  `#d8cfb8` 已在调色板里、不引入新色。**全库最干净的一条**：缺陷可见、字段现成、改一行
- **terracotta-sun 的注释色本身就不达标**（`INVENTED 23-terracotta-sun #9c8a72`）。它挂在
  `highlight.comment`，在该主题自己规定的代码块底 `#efe0cd` 上只有 **2.58:1**——它不是
  为凑对比度调深的色，是掉在阅读门槛以下的色，**规则 11 直接适用**。调色板里在这个底上
  达标的只有 `#4f382b`（8.39）；`#8f3f28`（5.57）已被 `string`/`key` 占用，橄榄绿
  `#6f7a4d` 只有 3.55 且被 `terracotta-sun.md:45` 的分寸条款限死在「em 和 h3 前缀」上。
  当时建议走规则 9 的第二步——退回默认文字色 `#4f382b` 加斜体保住区分度。**不要把
  `#9c8a72` 补进调色板**：补一个 2.58:1 的色进调色板等于把违规固化。
  （**✅ 批次 2 已按此执行**：`highlight.comment` 改成 `color: #4f382b; font-style: italic;`，
  上面四个对比度数字都已复算确认，`terracotta-sun.md:45` 的橄榄绿分寸条款也已核对属实。
  **同一次量到但未处置**：`highlight.keyword` `#c2593b` 在同一个代码底上只有 **3.39:1**，
  也低于 4.5——本批未获授权动它，它与 `INVERT 23-terracotta-sun #c2593b` 是同一支色，
  要动就得一起定）
- **18 条结构性 NEAR-ZERO**，见下条——它是 43 条里最大的一块，也是唯一一处建议动判据的
  （**✅ 批次 1b 已按建议改判据执行**）

#### 1.3 18 条结构性 NEAR-ZERO：要改判据，只能按挂载键判，不能按标签判

> **✅ 已执行（批次 1b，2026-08-09；复审后修正过一轮）**：按下面的建议改了判据，
> 不走备选的 18 条豁免注记。判据是
> `"container" in mounts and mounts <= {container, footer, footer_html}`，
> 判定用**子集**而非 `any()`。实测 19 条 NEAR-ZERO → 1 条（只剩 candy-pop 那条），
> `ZERO` 未动，无意外新增。
>
> **一处必须记住的修正**：初版判据写成「`build()` 只发射一次的键 = {container,
> footer_html}」，把同样只发一次的 `footer` 排除在外——**文档里的理由不是代码里的
> 判据**。复审指出真正的区分性质是**面积/角色而不是次数**：`container` 铺满整页，
> 落 1 次等于全覆盖；文末那个 `<p>` 是落款，落 1 次就是真的几乎没有。初版还留了个
> 真洞：一个主题若把唯一强调色**只**声明在 `footer_html` 里，落点恰为 1，会被静默
> ——正是 apple-air 立项缺陷的形状。现由 `l2-nearzero-footer-html-only` 钉住。
> 十种错误实现的证死记录见 lessons「判据可以下窄」节。变异测试从 54 条加到 62 条。

20 条 NEAR-ZERO 里有 18 条是同一个形态：那个色在 `theme.json` 里**只挂在 `container` 上**
（`27-retro-phosphor` 是 `container` + `footer_html`），而 `md2html.py` 的 `build()` 只拼一个
最外层容器 `<div>`、只拼一个文末 `<p>`——**落点恒为 1 和 2，不随文章长度变化**，换十万字
语料照样是 1 和 2。容器背景出现 1 次不是「几乎没出现」，它铺满整页。规则 7 在这里正面适用。
（另两条 NEAR-ZERO 不属于这一批：editor-slate 的 `#ffffff` 挂在 `card` 且该主题
`card_mode: "single"`，是规范自述的「全文一张大卡」；candy-pop 的 `#e8f2f9` 见 1.5。）

**如果决定改判据，唯一安全的判定依据是该色在 `theme.json` 里的挂载键集合**（`container`
/`footer_html` 这类 `build()` 只发射一次的结构性键），**不是调色板标签**：candy-pop 的
`#e8f2f9` 标签正是「**浅蓝底**」，含「底」——任何「标签里有『底/背景』就豁免」的写法都会
连带灭掉那条必须保留的发现。**按标签判和按 `REF_EXCLUDE` 判一样危险，只是词表不同**：
`REF_EXCLUDE`（`census-themes.py:252`）那个方案已被否决，它能把 NEAR-ZERO 从 20 干到 0，
同时把本项目立项起因之一的 aurora-flow 次级灰零落点一起灭口——「次级灰」含「次级」。
（该缺陷已在第四轮修好，现在由 `test-census-themes.sh` 的 `l2-zero` 用例钉着；
lessons「判据可以下窄」一节记了完整经过与五条硬约束。）

**备选是不改脚本、写 18 条几乎一样的豁免注记**——零脚本风险，但把「判据下宽了」这个事实
永久转成 18 处沉默，第 28 个主题进来时会第 19 次报同样的东西。两条路都合规，这是本条里
唯一一处建议动判据的地方，**需要用户明确拍板**。（用户已拍板走改判据这条，见上方进度块。）

#### 1.4 脚本原理上抓不到的一条：cyber-neon 的警示提示卡

**这条不在 43 条里，`census-themes.py` 永远不会报它，必须由人带着走。**
`cyber-neon.md:37` 写「提示卡里属于警示性质的那种，标题和左边框用品红（信息性提示卡仍用
青色）」，而 `13-cyber-neon-v7-edge.theme.json` **没有 `alert` 键**——这**完全符合
`UNMOUNTED` 的定义**，报的却是 0，因为这一句用中文「品红」指色、不带 hex / `style=` /
`属性: 值`，进不了 `theme_lib.spec_lines` 的机械实体筛，L3 看不见它。用户已于 2026-08-07
裁定**接受这个局限**，不为一条发现去放宽判据（实测代价：放宽后全库只多 2 条 = 这条真阳 +
一条假阳）。

**这就是「43 → 0 不等于主题库成立」的活证据**：修完这条，普查输出一个字都不会变，
只能靠人读 `theme.json` 验收。另注意一个坑——**若决定本轮不动它，不要在那一行上方写
`census-ok` 注记**：普查没报过它，写注记会立刻变成 `STALE-NOTE` 并以 ERROR 挂掉全库；
要留话就写普通说明性注释。

#### 1.5 两处已核实的更正、一处未解决的分歧、一条待核的线索

- **`UNMOUNTED 11-bauhaus-pop strong_alt` 是误报**，不要照着补 `strong_alt`。唯一的触发行
  是 `bauhaus-pop.md:14` 的调色板角色标注「- 红（strong / 警示）：`#be1e2d`」，不是指令句；
  这支红本身就是 strong 色（`theme.json` 的 `strong` 已挂），「strong / 警示」是同一支色的
  两个语义，不存在需要另配样式的警示型 strong。与 cyber-neon（`:36` 明说「改用另一套样式」）
  形态不同。建议处置是写豁免注记。**不要为它去收窄判据**——「调色板角色标注行」没有可靠的
  机械特征，收窄很容易把 cyber-neon / blueprint-grid 那种真缺陷一起放过
- **`UNCARRIED 06-editor-slate #d2a8ff`/`#ffa657` 是「无挂载点型」，不是「失步型」**——
  补 `theme.json` 修不了它们。`md2html.py:104-126` 的 tokenizer 只发 5 个 token 类
  （`comment`/`string`/`key`/`keyword`/`number`），没有函数名/类名，也没有命令行参数/属性。
  完整论证见 **lessons 规则 15**，这里不重复。建议处置是豁免 + 押后，并把「给 tokenizer 加
  `func`/`param` 两类」当成一个独立任务（两类都机械可判，符合规则 14 的准入线）。
  **不建议按规则 3 把那两行从 `.md` 删掉**：`theme-prompts/*.md` 还有判断层这个消费者，
  生成模型认得出函数名和 `--flag`，删掉会削弱判断层路径
- **`NEAR-ZERO 19-candy-pop #e8f2f9`：✅ 批次 4 已写豁免注记结案。下面这整段的前提已作废，
  留档只为说明是哪一步推错了。**
  裁决翻转的机械事实是一行样式串：`candy-pop.md:36` 的 `em` 是
  `background-color: #e8f2f9; padding: 1px 5px; border-radius: 4px; color: #4a7a9b`，
  **里面没有 `font-style: italic`**——所以 `*文字*` 在这个主题里渲染出来根本不是斜体，
  是一枚圆角浅蓝高亮块。用户确认**高亮是常用写法**，于是「本人不用斜体 ⇒ 这支色永远
  渲染不出来 ⇒ 规则 1 的死色」这条推理链在第一环就断了：产物里只有 1 处，是因为**本篇
  语料通篇只有 1 个 `*em*`**（实测 `<em` 1 次、`#e8f2f9` 1 次），是语料的性质，不是落点失效。
  下面 (a)/(b)/(c) 三条候选修法**一并作废**，`candy-pop.md` 的样式与 `theme.json` 都没动。
  **教训：判「这个色是不是死色」之前，先读它那条样式串到底渲染成什么**——
  凭元素名（`em` ⇒ 斜体）推语义，比不上把 CSS 逐条读一遍。

  ~~以下为批次 1b 当时的记录，前提已作废：~~
  它在 `theme.json` 里**只挂在 `em` 上**（`container` 是另一个色 `#fdf6f0`），产物 1 处。
  **用户 2026-08-09 裁定**：本人写作除特殊情况外不用斜体，所以这个色在实际产出里永远
  渲染不出来——规则 1 下的死色，**不是语料覆盖度问题**，Task 5 那个读法作废。

  **但主题自己的规范推不出唯一修法，执行者按指令停手上报，没有替用户做设计决定**：

  - **删不掉。**`candy-pop.md:36` 的原句是「em / 高亮：`background-color: #e8f2f9`…
    （**用蓝，和 strong 的粉错开**）」——按规则 3 删色就得把 em 的底换成浅粉 `#fce8ee`，
    而那正是这条规范明文要避免的（em 会和 strong、行内 code、表头挤进同一支粉）。
  - **改挂哪里没有规范依据。**`candy-pop.md` 把**所有**可能的浅底面——引用块（`:40`）、
    行内 code（`:41`）、表头（`:43`）——逐条指定给了浅粉 `#fce8ee`；`.md` 里根本没有
    斑马纹条款（`td_alt` 是 `theme.json` 自己配的 `#fdf6f0`）。任何改挂都得从粉手里
    抢走一个面，那是审美取向，规范没有表态。
  - **一条有用的旁证**：全库用「em / 高亮」这个写法的还有 mint-breeze 与 bauhaus-pop，
    它们的同位色**都另有高频面**（引用块 + 行内 code，mint-breeze 还加表头），产物计数
    217 / 199。candy-pop 是三者里唯一把那些面全给了另一支色的，所以只有它的蓝底落单。
    **这说明缺陷成立，但也说明修法必然要动配色分工，不是补个字段就完事。**

  **下一步需要用户在这三条里挑一条**：(a) 把某一个浅粉面改成浅蓝（引用块最像，但会破坏
  「引用=粉」的一致性）；(b) 给 `td_alt` 挂浅蓝（`.md` 要同步补一条斑马纹条款）；
  (c) 承认这支蓝只服务 em 并写豁免注记（等于承认规则 1 在这里不适用）。
  ⚠️ 三条都会改产物（(c) 除外），要按第三节纪律先重生成 HTML 再跑 `test-md2html.sh`
- **一条线索，现已被机械覆盖（2026-08-10 已核，结论见第六节第 2 条）**：
  下面这四处是当时顺带撞见的，那句「**没有做过全库对比度审计**」**现在已经不成立**——
  `contrast-themes.py` 已对全库 26 个主题机械跑通，冻结基线
  `references/contrast-baseline.tsv` 收了 **116** 条不达标组合，这四处只是其中几条。
  逐条数据不要照抄下面这段（它只覆盖人眼扫到的那几种组合，且用的是探针口径），要查最新
  明细去看 `references/contrast-baseline.tsv` 本身。原文留档如下（只留作历史记录）：
  拉 INVERT 数据时顺带撞见四处疑似违反规则 11 的对比度——
  autumn-warm 的 `strong` `#c06b4d` 在白卡上 3.85、terracotta-sun 的 `strong` `#c2593b` 在
  `#fdf8f1` 上 4.15、candy-pop 的 `strong` `#d96687` 在白卡上 3.39（都是 15.5px 粗体，够不上
  WCAG 的「大文本 3:1」豁免），以及 candy-pop 的 h3 前缀与列表符号 `#f28ba8` 2.32 /
  `#7fb5d5` 2.22，**连图形的 3:1 都不到**。**没有做过全库对比度审计**，动手前要单独核。
  注意它与 INVERT 的关系：若因此把主强调调深、让它承担正文，那是**加重** INVERT 而不是
  解决它——先定对比度，再回头看 INVERT 还成不成立

#### 1.6 判定为可接受时怎么写豁免注记

凡是「判定为可接受、不必改文件」的发现，处置方式不是删掉那一行，是在对应主题
`.md` 里写一条豁免注记，让 `census-themes.py` 不再报它、同时把「为什么可接受」留档：

    <!-- census-ok: <档名> <键> <一句话理由> -->

档名是九档里的一个（`UNCARRIED`/`INVENTED`/`INLINE-BLOCK`/`UNMOUNTED`/`ZERO`/`ZERO-DUP`/
`NEAR-ZERO`/`DECOR`/`INVERT`，**不含** `STALE-NOTE`——它自己不能被豁免掉）；键是发现那一行
的第三列（色值或字段名）。这套前缀与 `audit-themes.py` 的 `audit-ok:` 故意不同、各认各的，
两批注记共存于同一批主题文件互不干扰。三处易错、脚本现在会大声 FAIL 而不是静默吃掉：漏了
键（只写档名）、理由留空、把 `census-ok` 写成 `audit-ok`（那是另一套注记的合法语法，不会
触发 census 的 FAIL，但也**不会**销掉 census 的发现——census 完全不认它）。写完一条注记，
跑一遍 `census-themes.py` 确认它真的销掉了目标发现、条数按预期下降，而不是新增一条
`STALE-NOTE`（说明档名或键没对上）。

其中 ink-wash 的朱砂印（`footer_html`）、cyber-neon 的警示 strong（`strong_alt`）——
第四轮记的「两条收尾」——**批次 2 已按 1.1 第二批的做法补进 `theme.json`**。ink-wash 那条
有个已知陷阱：`footer` 恒定被算进 `boxed_keys`，所以 `display: inline-block` **只能写在
`footer_html` 的内层 `<span>` 上，绝不能写进 `footer`**——否则触发 `INLINE-BLOCK`
（arena-charge 判例）；washi-spring 就是这么写的，是已验证无害的先例。**批次 2 绕开了这个
陷阱**：`ink-wash.md:47` 的主写法是纯 `<p>` + `□`，带边框的「完」字只是「可换为」的备选，
执行时取了主写法，`footer_html` 里没有任何 `inline-block`。

> **这一条是压缩过的。**它由一份 638 行的逐条建议书溶解而来。**压缩掉、且没有别处备份的是**：
> 每条建议的 `theme.json` 片段与 `census-ok` 注记原文（要用时按各主题现有写法重写，不难）；
> 七条 INVERT 的逐主题落点/对比度对照表（只留下 1.5 里那四行线索）；gilded-ink 两个现造色
> (A) 删掉 / (B) 补进调色板两条路的完整取舍论证与实测对比度表；monochrome-mag `#767676`
> 与 botanic-press `list_prefix_ol_html` 两条待定项的逐条候选修法。**这些细节要用时得重新
> 量一遍**——用 `census-themes.py --counts <主题名>` 加手算对比度，不要凭印象。
>
> 那份建议书本来在项目工作区里、被 gitignore；2026-08-09 一度挪进
> `docs/superpowers/specs/2026-08-07-product-landing-census-task-7-adjudication.md` 并入仓，
> 作为 1.1–1.7 的可选背景细节，说明白了它是临时文件、条目处理完就删。
> **2026-08-09（第七轮）已按此删除**（移进废纸篓，内容仍在 git 历史里）：43 条已全部处置，
> 它记的东西没有一条还在等人执行。**1.1–1.7 就是权威摘要，别再去找那份文件。**

#### 1.7 两条被内容类型限定的有序列表序号：机械字段接不住，退回用户

`UNMOUNTED 15-mint-breeze list_prefix_ol_html` 与 `UNMOUNTED 24-botanic-press
list_prefix_ol_html` 是同一个形态，**批次 2 复核后两条都没动**：

- `botanic-press.md:41`：「物种/条目清单**可用**褐色序号 `No.1`」——既是许可式（「可用」）
  又限定内容类型（物种/条目清单）
- `mint-breeze.md:44`：「**步骤类**有序列表前缀数字加浅绿圆底」——不是许可式，但**限定了
  内容类型**（步骤类）

`list_prefix_ol_html` 是全局字段，一配上去**每篇文章的每个有序列表**都会套上那个前缀，
没有任何机械手段能识别「这是不是步骤类 / 物种清单」。mint-breeze 还有一条独立的机械理由：
它的徽章是 `display: inline-block; border-radius: 50%; width: 20px` 的单位数圆，序号到两位
数就撑破。

**✅ 批次 3 已按 (b) 处理，但比 (b) 多做了一步**：只写豁免注记会把一句读起来像机械规范的话
永久留在文件里，下一个执行者还是会去配字段。所以两处的规范行都**重写成显式声明**——
「判断层的手工可选项，不是机械规范，`theme.json` 里刻意不配 `list_prefix_ol_html`；
机械路径一律退回纯文本 `N.`」——然后各写一条 `census-ok: UNMOUNTED list_prefix_ol_html`
注记。判断层路径的指引因此**加强**而不是丢失（对比 (c)：删掉半句会让手写路径失去这条指引）。
mint-breeze 那条还写明了示例里 `width: 20px` 的正圆只演示单位数、手工用到两位数要改
`min-width`。产物逐字节不变。

当时列的另外两条出路，留档备查：(a) 把限定词从 `.md` 里删掉、承认这是全局规范（会改产物）；
(c) 按规则 3 把这半句从 `.md` 删掉（判断层路径会因此失去这条指引）。
⚠️ 语料里**一个有序列表都没有**，所以 (a) 在当前语料下产物也不会变，
**不能拿「产物没变」当作它被验证过**。

#### 1.8 monochrome-mag 已整体删除（批次 3）

**用户裁定这个主题永不使用，授权整体删除。**它名下的 2 条发现
（`UNCARRIED 20-monochrome-mag #767676` + `ZERO-DUP` 同色，即 1.1 表里「待定」那档的
其中 2 条）随主题一起消失——**这是「问题不存在了」，既不是修复也不是豁免**，
1.1 那两条建议路（(A) 按规则 3 删掉那行灰 / (B) 给它挂 `footer_html`）都作废。

删掉的两个文件（已移进废纸篓，没有 `rm`）：

- `references/theme-prompts/monochrome-mag.md`
- `references/theme-json/20-monochrome-mag.theme.json`

同批清掉的引用点，**全部核过、没有悬空**：

| 位置 | 处置 |
|---|---|
| `references/theme-prompts/INDEX.md` | 删掉目录行 |
| `scripts/test-md2html.sh` 的 `PAIRS` 表 | 删掉配对项；表内外四处「27 份」改 26 |
| `scripts/md2html.py`（语法高亮值可以是样式串的那条注释） | 原来举 monochrome-mag 当例，改举 ink-wash + terracotta-sun（后者的注释/关键字同色不同字重，正是这个机制的活例） |
| `scripts/test-census-themes.sh` 的 `l1-uncarried-counterexample` 注释 | 原来写「形态照 monochrome-mag.md:15 抄」，改成描述形态本身并指向 `bauhaus-pop.md` 的语法高亮行（同形，且是活的）。**fixture 本身一个字没动** |
| `scripts/census-themes.py`、`test-census-themes.sh` 里「全库 27 对/27 个」 | 改 26 |
| `references/theme-prompts/ocean-calm.md`、`docs/handoff/batch-themes-prompt.md` | 「27 个主题里 17 个」等库规模数字改 26 |
| `docs/theme-design-lessons.md` 规则 5 / 规则 15 | **保留**：那是历史案例与类比，删掉会砍掉规则本身的证据。只在规则 5 加了一句「该主题已删除」，免得下一个人去翻文件 |
| `docs/superpowers/specs/*`、`docs/superpowers/plans/*` | **保留不改**：按第零节第 4 条，那是某一轮计划的存档，记录的是当时普查确实报过这两条。它们不是活引用 |

**仓库外那两份孤儿产物已于 2026-08-09（第七轮）经用户确认删除**（移进废纸篓）：
`out/20-monochrome-mag-v5.html` 与 `out/20-monochrome-mag.theme.json`。
`PAIRS` 本来就不引用它们，删完 `test-md2html.sh` 仍是 26/26 绿。

### 2. 对比度护栏已落地（本轮，`2026-08-10-contrast-audit` 计划 Task 1–8）

**第四套机械脚本 `contrast-themes.py` 已入仓**，连同 `contrast_lib.py`（色彩原语：alpha 合成、
渐变最差点采样、DOM 祖先链走查、按注入字段判装饰、阈值规则）、`test-contrast-lib.py`（原语
单测）、`test-contrast-themes.sh`（16 条变异测试）、`test-contrast-themes.py`（4 条
`prune_survivors` 单测）、以及冻结基线 `references/contrast-baseline.tsv`。判据设计见
`docs/superpowers/specs/2026-08-10-contrast-audit-design.md`，实施步骤见
`docs/superpowers/plans/2026-08-10-contrast-audit.md`，判据教训已回写
`docs/theme-design-lessons.md`「机械审计方法」节。**这一轮没有改任何主题文件、`theme.json`
或产物**——只建护栏。

**真实基数是 116 条，不是立项那一轮一次性探针估的 113。**探针的装饰判据（「文本里没有字母/数字/CJK
就算装饰」）正是 spec 自己否掉的那条；探针还曾用 `glob("*.html")` 把不在 `PAIRS` 表里的
中间产物 `13-cyber-neon-v7-grid` 当成第 27 个主题，第一版数字（114 / 19 个主题）因此整体
偏高。设计文档据此估的区间是 113–156，**Task 6 首跑产出 116，落在区间内，且首跑用的判据
在那次 commit 范围里零改动**——这个数是量出来的，不是先设目标再调判据凑出来的。**26 个
主题里有 20 个存在不达标组合。**

**这是一道冻结基线护栏，不是完工声明**：116 条存量全部列在 `.tsv` 里但不阻塞，`exit 1`
只在出现基线里没有的新组合时才触发。基线**只许减、不许增**：`--prune` 只删「产物里已经
不存在」的存量行、绝不会加行；往基线里加行唯一的路是 `--write-baseline`。这条纪律脚本本身
管不了——往 `.tsv` 里手写追加一行就能让新发现消声、脚本照样 exit 0，**唯一护栏是人读那份
文件的 diff**。

**处置这 116 条是另一轮的事，性质与普查那 43 条完全不同**：43 条大半靠改标签、改描述、写
豁免注记就能销，产物逐字节不变；这 116 条几乎每一条都要动配色、都会改产物、都含审美判断，
而且 candy-pop / washi-spring / morandi-fog 是整套配色系统性偏浅，不是一两个色的事。这条
状态不是待办清单，具体怎么处置要等用户逐条拍板。

**已知局限**（这套护栏覆盖不到什么，别把「基线一致」读成「完工」）**已回写
`docs/theme-design-lessons.md`「机械审计方法」节，不在此复制。**

**两件如实记录、不隐瞒的事**（详细理由见 `docs/theme-design-lessons.md`「机械审计方法」节）：

1. `test-contrast-themes.py`（单测，只测 `prune_survivors`，4 条全绿）与
   `test-contrast-themes.sh`（16 条变异测试）**同名只差后缀**——两名评审都点出这是真实的
   维护隐患，本轮未合并、未改名。
2. **`contrast-ok` 豁免注记的解析故意没做**——116 条里没有一条已判定「可以永远这样」，
   现在写等于没有调用方的代码；不是遗漏。

### 3. 待真机观感定夺（不要凭代码改）

- **暗色主题在微信浅色模式下可能全篇不可读**。cyber-neon 模拟「浅色模式把背景映射为白」后正文仅 1.52:1，且不存在两边都安全的配色。影响 `13-cyber-neon-v7-edge` / `18-midnight-study` / `26-velvet-stage` / `27-retro-phosphor` 四个产物。**必须真机双模式预览才能定论**，用户表示自己验证，结论未回
- **candy-pop 的「主强调」标签已于批次 3 改掉**（`INVERT 19-candy-pop #f28ba8` 已消失）：标为「主强调」的 `#f28ba8` 文字落点只有 29 处、全落在 h3 前缀与列表符号这类装饰位上，真正做正文强调的是标着「strong 用」的深樱粉 `#d96687`（271 处）。**倒置的是「主强调」这个标签本身**，所以只改了 `candy-pop.md:15` 的角色写法（樱粉改标「符号与前缀装饰用」）——**没有对调**，因为深樱粉本来就标着「strong 用」而不是「副强调」，对调无从谈起。色值与产物逐字节不变。**仍待真机定夺的是配色本身**：该主题三个色没有一个过对比度门槛（2.32 / 2.22 / 3.39，见第六节 1.5），真要动色就不是 INVERT 的问题了
- **retro-phosphor 的注释色在代码底上只有 4.10:1**：但那是主题明文指定的三级绿之一，改成中亮色就和默认字色没区别、丢掉分层。真机双模式验证时一并看

### 4. 未实测的两个 skill

- **`wechat-finetune` 未实测**，eval 循环未跑
- **`md2publish-images` 从未实测**（宿主生图 + 上传封面未走通）

### 5. 教程文档校订

`~/org/markdown/prompt/@inbox/md-to-wechat-draft-free-path.md` 写于主题统一重构之前，未反映 `md2html.py`。该文档按讲解体写成，改动要守住其风格（用 `tech-writer` skill）。

### 6. 明确不做的（留档，别反复重新发现）

「按内容语义分流」的装饰，`theme.json` 的字段模型管不到，脚本也不该为单个主题加字段：

- scarlet-tech：优点/缺点行用 ＋/－ 双色前缀；对比表里「推荐项」整格标红
- arena-charge：关键数据（配速/重量/比分）放大加粗
- velvet-stage：演出信息类条目用金色 ▸ 标
- celadon-scroll：诗词/古文引文居中排（无独立 block 类型）

这几条执行者都如实上报、没有手改 HTML 硬凑——**红线里「不许手改 HTML」正是为了让这类缺口浮出来**，而不是被一次性手工修补盖住。

同样不加的字段（准入线三条不全满足）：blueprint-grid 的章节自增编号（有 `§` 顶着）、aurora-flow 的卡顶渐变条（已用 `background-image` 等价绕过）。

### 7. 本轮做掉的两项清理（留档，别再问一遍）

- **`2026-08-07-product-landing-census-task-7-adjudication.md` 已删**（进废纸篓，内容在 git 历史里）。
  1.6 末尾那段指向它的话已改写。删的依据是 1.6 自己写的「等它记的条目全部被处理完就该删」。
- **monochrome-mag 的两份孤儿产物已删**（`out/20-monochrome-mag-v5.html` 与同名 `.theme.json`），
  见 1.8。删完 `test-md2html.sh` 仍是 26/26 绿。
- 顺带改正了第四节一条与事实不符的记载：**cyber-neon 的 v2–v6 中间产物早就不在了**，
  现存的只剩 `13-cyber-neon-v7-grid` 那两份和无版本号的 `13-cyber-neon.theme.json`，**没删**
  （cyber-neon 还挂着第 3 条的真机双模式待验，v7-grid 是那次比对可能要用的候选）。

## 七、Suggested skills

- `superpowers:verification-before-completion` — **本项目里这条是第一位的**。历史上宽度问题连续改错两次、cyber-neon 对比度连续改错两次，都是只验证了「我改的属性在不在」而没验证「渲染出来是什么样」，或者量错了对象。第四轮的通用做法是：**改完必须去数产物**，不是看自检 PASS
- `superpowers:brainstorming` — 再要新增机械检查（比如给 `census-themes.py` 加新档、给 `NEAR-ZERO` 收窄判据）之前先用它收敛判据，避免重蹈下宽/下窄两种覆辙（lessons「机械审计方法」节）
- `superpowers:test-driven-development` — 给 `md2html.py` 加字段时照搬 `test-md2html.sh` 的范式：先造会失败的用例，再实现
- `tech-writer` — 校订教程文档时
- `skill-creator` — 改 skill 结构、跑 evals、做 description 优化

## 八、环境速查

- md2wechat CLI 3.2.0 已装（npm 全局）；源码在 `~/code/skills/writing/md2wechat-skill/`（另一个 git 仓库，别混）
- 实验目录 `~/code/skills/writing/wechat_test/`
- 用户偏好：**传图、建草稿、git commit/push 一律先经用户确认**；成本敏感，大批量开跑前先报预估
- 用户在 main 分支上直接提交，不开特性分支
