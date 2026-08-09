# Handoff：md2publish-skills 交接文档

> 更新于 2026-08-09（第五轮：`product-landing-census` 项目）。仓库位置：`~/code/skills/writing/md2publish-skills/`
>
> 本文只说「做到哪一步了」，不写 commit hash——提交本文本身就会移动 HEAD，写死了立刻就是错的。
> 要确认仓库实际状态，跑 `git log` / `git status`。

## 快速接手入口（读完这 8 行就能开工，细节再往下翻）

1. 项目：Markdown → 微信公众号可粘贴 HTML 的 skill 链。**唯一转换入口是 `skills/md2publish-article/scripts/md2html.py`，你的工作单元只有 `theme.json`**——别手敲 HTML、别另写脚本。
2. 27 个主题全部跑完并修过一轮；`theme.json` 27 份已入仓（`references/theme-json/`），HTML 产物在仓库外的 `~/code/skills/writing/wechat_test/litellm-multi-provider-gateway/out/`。
3. **动手前先跑第三节那七条基线**（审计 0 条 / 审计变异 16 绿 / md2html 测试 25 绿 / 产物自检 PASS / 普查变异 59 绿 / 普查跑通 / theme_lib 单测 11 绿），确认没被上一轮改坏。
4. **下一件事看第六节第 1 条**：产物落点普查脚本（`census-themes.py`）首轮对真实库报出 **43 条**，因此 **exit 1**。批次 1a 处理 6 条（5 条豁免注记 + celadon-scroll 补 `h2_suffix_html`）、批次 1b 处理 20 条（收窄 `NEAR-ZERO` 判据 18 条 + gilded-ink 两支现造色转正），现在是 **17 条未销 + 5 条已豁免、仍 exit 1**。**剩下的 17 条一条都没有被处理**——不是失败，也不是体检合格，是**等用户逐组拍板**。第六节第 1 条装着分组、执行顺序和最要紧的几条的全部细节，逐组过一遍、拍板一批、改一批、再跑一遍 `census-themes.py` 确认条数下降。
5. 最要紧的认知：**`audit-themes.py` 报 0 条不等于主题成立**——它查主题文件里有没有*声明*落点，不查产物里这个色出现几次。本仓库已知四次「规范白纸黑字写着、产物里 0 处」曾经全部逃过审计/自检/回归三道检查；现在 `census-themes.py`（第三节）补上了这一层，但**它报出发现不等于发现已被处理**——43 条里 17 条截至目前仍待裁决。
6. 因此本项目的通用做法是：**改完必须去数产物**，不是看自检 PASS 就算完。现在有 `python3 skills/md2publish-article/scripts/census-themes.py --counts <主题名>` 可以直接跑，不用每次手写 `Counter(re.findall(...))`。
7. 改任何主题文件之前必读 `docs/theme-design-lessons.md`（规则 11–14 和两条判例是第四轮新立的）。
8. 红线：**传图、建草稿、git commit/push 一律先经用户确认**；成本敏感，大批量开跑前先报预估。

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

## 三、七条基线（动手前先跑）

```bash
cd ~/code/skills/writing/md2publish-skills

# 1. 主题文件审计，要 0 条
python3 skills/md2publish-article/scripts/audit-themes.py

# 2. 审计脚本的变异测试，要 16 全绿
bash skills/md2publish-article/scripts/test-audit-themes.sh

# 3. md2html.py 的测试，要 25 全绿（含 27 份主题的逐字节回归）
bash skills/md2publish-article/scripts/test-md2html.sh

# 4. 产物过铁律自检，要 PASS
awk '/^python3 - <<.EOF.$/{f=1;next} /^EOF$/{f=0} f' \
    skills/md2publish-article/references/wechat-html.md > /tmp/selfcheck.py
python3 /tmp/selfcheck.py <out.html>

# 5. 产物落点普查脚本（census-themes.py）的变异测试，要 59 全绿
bash skills/md2publish-article/scripts/test-census-themes.sh

# 6. 普查脚本对真实库跑一遍——目前预期是 17 条待裁决 + 5 条已豁免、exit 1，不是 0 条
python3 skills/md2publish-article/scripts/census-themes.py

# 7. theme_lib.py 共享原语的单元测试，要 11 全绿（`ok：0 条失败`，exit 0）
python3 skills/md2publish-article/scripts/test-theme-lib.py
```

第 3 条的 PART B 从 `references/theme-json/` 读 theme.json、与实验目录里的定稿 HTML 逐字节比对。**故意改了某份 theme.json 之后要先重新生成它的 HTML 再跑**，否则那里报的红是预期内的改动，不是回归——别反过来改测试迁就它。语料目录缺失时 PART B 会整体 SKIP 并把退出码标红（静默跳过等于没有护栏）。

第 6 条**不是「要 0 条」的基线，是「要和上次一致」的基线**：`census-themes.py` 目前对真实库跑出 **17 条未销 + 5 条已由注记豁免**、exit 1。首轮报的是 43 条，第六轮（批次 1a）处理掉 6 条——5 条写豁免注记、1 条真改（celadon-scroll 补 `h2_suffix_html`）；第七轮（批次 1b）再处理掉 20 条——18 条靠收窄 `NEAR-ZERO` 判据、2 条靠 gilded-ink 把现造色转正。两批的细节见第六节第 1 条开头的进度块。这一步的作用是确认这一轮没有意外新增或消失的发现——数字变了要么是有人动了主题文件却没更新第六节的清单，要么就是真的在按那份清单处理。处理完一批之后，这里的期望数字要跟着往下调，不要让某个旧数字在这份文档里僵化成永久数字。语料缺失时这一条同样会整体 SKIP 并标红（与第 3 条同一纪律）。

剩下的 17 条**不是 17 个错误**：按设计文档自己的严重度分级，7 条 INVERT + 1 条 NEAR-ZERO + 1 条 ZERO-DUP 共 9 条是 WARN/INFO，只有 8 条（UNCARRIED 2 + INVENTED 1 + UNMOUNTED 5）是 ERROR——脚本输出本身不打严重度标签（`report()` 只报总数），读这份数字前先记住这个比例，别把「17 条待裁决」直接当成「17 个 bug」。

第 7 条不是可选项：`test-census-themes.sh`/`test-audit-themes.sh` 两套变异测试合计 75 条全绿，也测不出 `theme_lib.py` 两处纪律被破坏——它是这两处的**唯一**护栏：
- 去掉 `theme_lib.py:133`（`landings` 里 `_COLOR_PROP` 的 `(?<![-\w])` 守卫）会让 `background-color:` 被当成 `color:` 落地，污染 `DECOR`/`INVERT` 判定和 `--counts` 的「文字」列，`census-themes.py` 真实库输出照样不变（真实库当前没有踩中这个差异的样本）
- 去掉 `theme_lib.py:107`（`exemptions` 的前缀参数化，若被写死或写宽）会让 `audit-ok:` 注记也能销掉 `census-themes.py` 的发现，两套注记本该各认各的前缀、互不干扰

改 `theme_lib.py` 之后，三套测试（59 + 16 + 11）都要跑，缺一套都不能证明改动安全。

## 四、当前状态

### 主题库

- **27 个主题全部实测跑完**，清单见 `references/theme-prompts/INDEX.md`
- **`theme.json` 27 份已入仓**：`skills/md2publish-article/references/theme-json/<编号>-<主题名>.theme.json`。它不含任何与文章相关的内容，对任何文章可复用，**不必每次重新生成**
- **HTML 产物在仓库外**：`~/code/skills/writing/wechat_test/litellm-multi-provider-gateway/out/`。命名不统一——第一轮 6 个主题的定稿带 `-v1`/`-v5` 后缀，同名无后缀的那份是旧宽度结构、**已作废**。`test-md2html.sh` 里的 `PAIRS` 表是权威配对关系（每组都实跑验证过），**别按文件名循环**
- cyber-neon 的 v2/v3/v4/v5/v6/v7-grid 是中间产物，可清理（**删文件前问用户**）

### 第四轮做完的

- **`md2html.py` 有测试了**：新增 `scripts/test-md2html.sh`，25 条。PART A 是字段行为用例（每个字段配一条「没配时默认行为不变」的对照），PART B 是 27 份主题的逐字节回归（第三轮是手工做的）。对脚本做过定点破坏验证这张网有牙齿——去掉 h3 前缀输出，15 个主题立刻变红
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
  `exemptions`/`landings` 七个共享原语）、`test-census-themes.sh`（54 条变异测试）、
  `test-theme-lib.py`（11 条）。这是第四轮遗留的「唯一没有护栏的一层」，见第零节
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

### 1. 普查报出的 43 条：已处理 26 条，剩 17 条（脚本本身已完成）

> **进度：批次 1b（第七轮）已执行，37 → 17。** 用户逐条裁决了三项，全部落地：
>
> | 项 | 发现 | 处置 | 结果 |
> |---|---|---|---|
> | 1 | 18 条结构性 `NEAR-ZERO` | **改判据**（`census-themes.py`） | **销声**：色只挂在 `{container, footer_html}` 这类 `build()` 只发射一次的结构键上时不再报 `NEAR-ZERO`。五条硬约束逐条配了变异用例（新增 5 条，共 59 条），七种错误实现各自被证死；`ZERO` 未动，candy-pop 那条挂 `em` 的照报。详见 1.3 与 lessons「判据可以下窄」节 |
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
> **两批之后仍然未动的**：candy-pop（`NEAR-ZERO` 与 `INVERT` 两条）、monochrome-mag 2 条、
> botanic-press 1 条、terracotta-sun 的 `#9c8a72`、bauhaus-pop 的错值 `#1e5aa8`、5 条
> `UNMOUNTED`、全部 7 条 INVERT，以及 1.4 那条脚本抓不到的 cyber-neon 警示提示卡。

**脚本本身已完成，第五轮做的**（见第四节）。`census-themes.py` 现在把「主题文件声明了什么」
和「产物里实际出现几次」两侧都机械化了，本仓库已知四次「主题文件白纸黑字写着、产物里 0
处」——apple-air 的 eyebrow、cyber-neon 的警示 strong、newsprint 的导语、aurora-flow 的
次级灰——曾经全部逃过审计/自检/逐字节回归三道检查，现在这一层有护栏了。

**没有完成的是处理结果**：首轮对真实库跑出 **43 条、exit 1**，**用户裁定那一轮只出建议、
不改文件**——主题 `.md` 与 `theme.json` 一律未动。下面 1.1–1.6 是当时逐条复核后给出的
**处置建议**，**除上面两个进度块列的 26 条外一条都没有被采纳**。读的时候当待办清单，不是判决书：每一条都还需要用户
拍板，尤其是标了「审美判断」的那些。动手时按第五节第 12/13/14/16 条的老规矩：规范行不留
旧值、改完跑 `audit-themes.py`/`census-themes.py` 到期望条数、`.md` 与 `theme.json` 同步、
提交前把 diff 完整读一遍。

#### 1.1 建议处置的分布，以及建议的执行顺序

| 建议处置 | 条数 | 是什么 | 状态 |
|---|---:|---|---|
| 判据问题 → 改脚本 | 18 | 「背景色只挂在 `container`」的结构性 NEAR-ZERO，见 1.3 | **✅ 批次 1b 已执行** |
| 正当设计 → 写豁免注记 | 11 | 6 条 INVERT + editor-slate 4 条 + bauhaus-pop `strong_alt` 误报 | editor-slate 4 条 + bauhaus-pop 1 条已办（批次 1a），6 条 INVERT 未办 |
| 真缺陷 → 改 `theme.json`（不动 `.md`） | 7 | 5 条 UNMOUNTED + terracotta-sun 的 INVENTED + cyber-neon 的 `alert` | celadon-scroll 1 条已办（批次 1a），其余未办 |
| 待定 → 需用户拍板 | 5 | monochrome-mag 2 条、candy-pop 2 条、botanic-press 1 条 | candy-pop 的 `NEAR-ZERO` 已裁为真缺陷但修法未定（见 1.5），其余未办 |
| 真缺陷 → 改主题 `.md`（须同步 `theme.json`） | 3 | bauhaus-pop 错值 1 条 + gilded-ink 现造色 2 条 | gilded-ink 2 条**✅ 批次 1b 已执行**（走 (B) 路，产物不变），bauhaus-pop 未办 |
| **合计** | **44** | 脚本报的 43 条 + 1 条脚本原理上抓不到的（见 1.4） | 已处理 26 条，剩 17 条 + 1 条抓不到的 |

前三档基本是**机械事实驱动**的（对比度数字、`theme.json` 里有没有这个键、tokenizer 有没有
这个类），可以照着核；「待定」那 5 条、外加 INVERT 里 gilded-ink 与 ocean-calm 两条，
**含美学判断，只有用户能拍**。

**建议按风险从低到高分四批**，每批之后跑一遍 `census-themes.py`：

1. **零渲染风险批**（改完产物逐字节不变）：bauhaus-pop 的错值、gilded-ink 把两个现造色补进
   调色板（**✅ 已做**）、candy-pop 改角色标签，以及全部豁免注记
2. **只加 `theme.json` 字段批**：5 条 UNMOUNTED + cyber-neon 的 `alert`。产物会变，
   `test-md2html.sh` 的 PART B 预期变红，**要先重新生成 HTML 再跑**（第三节已写这条纪律）
3. **判据改动批**：18 条结构性 NEAR-ZERO，见 1.3。**必须先补变异测试再改判据**（**✅ 已做**）
4. **待定批**：等用户结论

**剩下没做的是第 1 批的 bauhaus-pop 错值 + 6 条 INVERT 豁免、整个第 2 批、以及第 4 批。**

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
  `#9c8a72` 补进调色板**：补一个 2.58:1 的色进调色板等于把违规固化
- **18 条结构性 NEAR-ZERO**，见下条——它是 43 条里最大的一块，也是唯一一处建议动判据的
  （**✅ 批次 1b 已按建议改判据执行**）

#### 1.3 18 条结构性 NEAR-ZERO：要改判据，只能按挂载键判，不能按标签判

> **✅ 已执行（批次 1b，2026-08-09）**：按下面的建议改了判据，不走备选的 18 条豁免注记。
> `census-themes.py` 新增 `STRUCTURAL_KEYS = {container, footer_html}`（照 `md2html.py`
> 的 `build()` 源码定，不照文档抄），门只加在 `total <= 2` 分支内、判定用**子集**而非
> `any()`。实测 19 条 NEAR-ZERO → 1 条（只剩 candy-pop 那条），`ZERO` 未动，无意外新增。
> **`footer` 也只发射一次却故意不进集合**——理由与七种错误实现的证死记录见 lessons
> 「判据可以下窄」节。变异测试从 54 条加到 59 条。

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
- **`NEAR-ZERO 19-candy-pop #e8f2f9`：已裁为真缺陷，但修法未定，文件未动（批次 1b）。**
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
- **一条待核的线索（不是结论）**：拉 INVERT 数据时顺带撞见四处疑似违反规则 11 的对比度——
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
第四轮记的「两条收尾」——**现在都在 1.1 的第二批里**（都判为真缺陷、信心高，建议直接补
`theme.json`），不再是本文件单独追踪的两条零散活，并入这一条统一处理。ink-wash 那条有个
已知陷阱：`footer` 恒定被算进 `boxed_keys`，所以 `display: inline-block` **只能写在
`footer_html` 的内层 `<span>` 上，绝不能写进 `footer`**——否则触发 `INLINE-BLOCK`
（arena-charge 判例）；washi-spring 就是这么写的，是已验证无害的先例。

> **这一条是压缩过的。**它由一份 638 行的逐条建议书溶解而来。**压缩掉、且没有别处备份的是**：
> 每条建议的 `theme.json` 片段与 `census-ok` 注记原文（要用时按各主题现有写法重写，不难）；
> 七条 INVERT 的逐主题落点/对比度对照表（只留下 1.5 里那四行线索）；gilded-ink 两个现造色
> (A) 删掉 / (B) 补进调色板两条路的完整取舍论证与实测对比度表；monochrome-mag `#767676`
> 与 botanic-press `list_prefix_ol_html` 两条待定项的逐条候选修法。**这些细节要用时得重新
> 量一遍**——用 `census-themes.py --counts <主题名>` 加手算对比度，不要凭印象。
>
> 那份建议书本来在项目工作区里、被 gitignore；**2026-08-09 已改口**——因为它还装着
> 未销的 37 条的执行细节，用户决定把它挪进 `docs/superpowers/specs/2026-08-07-product-landing-census-task-7-adjudication.md`
> 并入仓，作为 1.1–1.6 的**可选**背景细节。**它是临时文件、迟早删**：等它记的条目全部
> 被处理完，就该删掉，不要长期维护它；**1.1–1.6 才是权威摘要，两者不一致时以这里为准**。

### 2. 待真机观感定夺（不要凭代码改）

- **暗色主题在微信浅色模式下可能全篇不可读**。cyber-neon 模拟「浅色模式把背景映射为白」后正文仅 1.52:1，且不存在两边都安全的配色。影响 `13-cyber-neon-v7-edge` / `18-midnight-study` / `26-velvet-stage` / `27-retro-phosphor` 四个产物。**必须真机双模式预览才能定论**，用户表示自己验证，结论未回
- **candy-pop 主次强调实际是倒过来的**（也是第六节第 1 条那 5 条待定之一，`INVERT 19-candy-pop #f28ba8`）：标为「主强调」的 `#f28ba8` 文字落点只有 29 处、全落在 h3 前缀与列表符号这类装饰位上，真正做正文强调的是没被标为强调的「深樱粉」`#d96687`（271 处）。审计不报。**倒置的更像是「主强调」这个标签本身**，所以有一条零渲染风险的候选修法：只改 `candy-pop.md:15-16` 的角色写法（樱粉改标「装饰强调」、深樱粉改标「主强调」），色值与产物逐字节不变，INVERT 自动消失。但这仍是命名 + 审美取向题，**按原意由真机观感定夺**；另注意该主题三个色没有一个过对比度门槛（2.32 / 2.22 / 3.39，见第六节 1.5），真要动色就不是 INVERT 的问题了
- **retro-phosphor 的注释色在代码底上只有 4.10:1**：但那是主题明文指定的三级绿之一，改成中亮色就和默认字色没区别、丢掉分层。真机双模式验证时一并看

### 3. 未实测的两个 skill

- **`wechat-finetune` 未实测**，eval 循环未跑
- **`md2publish-images` 从未实测**（宿主生图 + 上传封面未走通）

### 4. 教程文档校订

`~/org/markdown/prompt/@inbox/md-to-wechat-draft-free-path.md` 写于主题统一重构之前，未反映 `md2html.py`。该文档按讲解体写成，改动要守住其风格（用 `tech-writer` skill）。

### 5. 明确不做的（留档，别反复重新发现）

「按内容语义分流」的装饰，`theme.json` 的字段模型管不到，脚本也不该为单个主题加字段：

- scarlet-tech：优点/缺点行用 ＋/－ 双色前缀；对比表里「推荐项」整格标红
- arena-charge：关键数据（配速/重量/比分）放大加粗
- velvet-stage：演出信息类条目用金色 ▸ 标
- celadon-scroll：诗词/古文引文居中排（无独立 block 类型）

这几条执行者都如实上报、没有手改 HTML 硬凑——**红线里「不许手改 HTML」正是为了让这类缺口浮出来**，而不是被一次性手工修补盖住。

同样不加的字段（准入线三条不全满足）：blueprint-grid 的章节自增编号（有 `§` 顶着）、aurora-flow 的卡顶渐变条（已用 `background-image` 等价绕过）。

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
