# Handoff：md2publish-skills 交接文档

> 更新于 2026-08-06（第四轮）。仓库位置：`~/code/skills/writing/md2publish-skills/`
>
> 本文只说「做到哪一步了」，不写 commit hash——提交本文本身就会移动 HEAD，写死了立刻就是错的。
> 要确认仓库实际状态，跑 `git log` / `git status`。

## 快速接手入口（读完这 8 行就能开工，细节再往下翻）

1. 项目：Markdown → 微信公众号可粘贴 HTML 的 skill 链。**唯一转换入口是 `skills/md2publish-article/scripts/md2html.py`，你的工作单元只有 `theme.json`**——别手敲 HTML、别另写脚本。
2. 27 个主题全部跑完并修过一轮；`theme.json` 27 份已入仓（`references/theme-json/`），HTML 产物在仓库外的 `~/code/skills/writing/wechat_test/litellm-multi-provider-gateway/out/`。
3. **动手前先跑第三节那四条基线**（审计 0 条 / 变异 14 绿 / md2html 测试 25 绿 / 产物自检 PASS），确认没被上一轮改坏。
4. **下一件事看第六节第 1 条：产物落点普查脚本**，那是目前唯一没有护栏的一层，也是唯一的大件。
5. 最要紧的认知：**`audit-themes.py` 报 0 条不等于主题成立**——它查主题文件里有没有*声明*落点，不查产物里这个色出现几次。本仓库已知四次「规范白纸黑字写着、产物里 0 处」全部逃过了现有的每一条检查。
6. 因此本项目的通用做法是：**改完必须去数产物**，不是看自检 PASS 就算完。
7. 改任何主题文件之前必读 `docs/theme-design-lessons.md`（规则 11–14 和两条判例是第四轮新立的）。
8. 红线：**传图、建草稿、git commit/push 一律先经用户确认**；成本敏感，大批量开跑前先报预估。

## 零、文档地图（先看这张表，别读错文档）

仓库里只有三份长期文档，**按生命周期分工，不按主题分工**。搞混了就会出现「两份文档抢同一个岗位」——第三轮就是这么乱起来的。

| 文档 | 什么时候读 | 生命周期 | 装什么 |
|---|---|---|---|
| **`docs/handoff/handoff.md`**（本文） | **接手时第一份**；每轮开工前 | **每轮重写** | 现在在哪、下一步做什么、基线怎么跑、红线 |
| **`docs/theme-design-lessons.md`** | **改任何主题文件之前必读**；改审计脚本前读「机械审计方法」节 | **只增不删** | 判据与规则（规则 1–14 + 案例 + 判例） |
| **`docs/handoff/batch-themes-prompt.md`** | 要**批量重跑**主题时（换文章、或改完脚本字段后） | 按需刷新 | 开新会话用的可粘贴 prompt + 验收命令 |

三条使用约定：

1. **`theme-design-lessons.md` 是承重文档**：除本文外还被 5 个文件引用（共 6 处），其中两处在脚本里（`audit-themes.py`、`test-audit-themes.sh`），另外三处在 `_common-tech.md`（2 处）、`INDEX.md`、`editor-slate.md`。**不要把它并进别的文档**——会同时断掉这些引用，并把长期判据埋进一份每轮重写的文件里。
2. **新学到的主题设计教训回写进 lessons，不要留在会话里，也不要另开文件。** 判断标准：这条结论换一篇文章、换一个主题还成立吗？成立就是 lessons 的规则；只描述「这一轮做到哪了」就是 handoff 的状态。
3. **允许在一轮进行中开临时的发现记录**（如 `phaseN-findings.md`）当草稿，但**必须在该轮收尾时溶解**——durable 的进 lessons，status 的进本文，测量数据就地写进对应的主题文件。**不许沉淀**，否则每轮攒一个，一年后 `docs/handoff/` 就没法看了。第四轮的 `phase2-findings.md` 已按此溶解删除。

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

## 三、四条基线（动手前先跑）

```bash
cd ~/code/skills/writing/md2publish-skills

# 1. 主题文件审计，要 0 条
python3 skills/md2publish-article/scripts/audit-themes.py

# 2. 审计脚本的变异测试，要 14 全绿
bash skills/md2publish-article/scripts/test-audit-themes.sh

# 3. md2html.py 的测试，要 25 全绿（含 27 份主题的逐字节回归）
bash skills/md2publish-article/scripts/test-md2html.sh

# 4. 产物过铁律自检，要 PASS
awk '/^python3 - <<.EOF.$/{f=1;next} /^EOF$/{f=0} f' \
    skills/md2publish-article/references/wechat-html.md > /tmp/selfcheck.py
python3 /tmp/selfcheck.py <out.html>
```

第 3 条的 PART B 从 `references/theme-json/` 读 theme.json、与实验目录里的定稿 HTML 逐字节比对。**故意改了某份 theme.json 之后要先重新生成它的 HTML 再跑**，否则那里报的红是预期内的改动，不是回归——别反过来改测试迁就它。语料目录缺失时 PART B 会整体 SKIP 并把退出码标红（静默跳过等于没有护栏）。

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
13. **改完跑 `audit-themes.py` 到 0 条**；改检查脚本后做变异测试
14. **改完主题 `.md` 要同步 `theme.json`**（反之亦然）。两者失步没有任何检查会报——第四轮自己制造过一次
15. **批量替换有两个咬人的形态，都只有事后核对才抓得到**。第四轮各踩一次：
    - **替换吃掉了自己的说明文字**：velvet-stage 做全局色值替换时把警告里的旧色值也换了，「不要调回 `#a04252`」变成「不要调回 `#c97a86`」，一句自相矛盾的规范。**全局替换要么先做、后写说明，要么说明里根本不写旧色值**
    - **链式替换：前一条规则的输出成了后一条的输入**。本文重编号时先 `第四节→第三节`、再 `第三节→第二节`，结果原本的第四节被连着换了两次，指到了第二节。**一批替换里若新值可能命中另一条规则的旧值，就不能顺序跑**——要么一次性映射，要么倒序，要么替换完逐条核对指向
16. **提交前把 diff 完整读一遍。**上面两条都是在核对时才发现的，代码和文本本身看不出问题——被替换掉的地方语法完全正确，只是意思错了

## 六、剩下的活（按价值排序）

### 1. 产物落点普查脚本（唯一的大件）

**这是目前唯一没有护栏的一层。**本仓库已知四次「主题文件白纸黑字写着、产物里 0 处」——apple-air 的 eyebrow、cyber-neon 的警示 strong、newsprint 的导语、aurora-flow 的次级灰——全部逃过了现有的每一条检查：审计只看主题文件、自检只看铁律、逐字节回归只看「和上次一样」而上次就是错的。

要做的是把「主题文件声明了什么」和「产物里实际出现几次」两侧都机械化，两边对不上就报。开工前：

- 先用 `superpowers:brainstorming` 收敛判据，避免重蹈 OVER 档第一版「判据下宽报了大半个库」的覆辙（lessons 规则 7 记了这件事）
- 照 `test-audit-themes.sh` 的范式配变异测试，且变异形态要覆盖真实文件里出现过的写法
- 已知的坑：**一行声明两个色时角色标签会串**，取角色要按色值在行内的位置切分
- 顺带可以覆盖两条机械可判的检查：boxed 元素带 `display: inline-block` 报警；主题 `.md` 与 `theme.json` 失步报警

### 2. 两条收尾（第四轮加的字段让它们变得可做了）

- **ink-wash 定稿产物缺那枚朱砂印**：`04-ink-wash-v5.html` 结尾直接是 `</p></div>`。`footer_html` 字段现在有了，补一版即可。注意别和 `-v5` 的命名撞车
- **cyber-neon 定稿产物没兑现警示 strong**：`cyber-neon.md` 规定「带『注意/警告/不要/会导致』语义的 strong 改用 `#ff4ba3`」，实测产物里该色 36 处、**落在 strong 上 0 处**。`strong_alt` 字段现在有了，配上即可

### 3. 待真机观感定夺（不要凭代码改）

- **暗色主题在微信浅色模式下可能全篇不可读**。cyber-neon 模拟「浅色模式把背景映射为白」后正文仅 1.52:1，且不存在两边都安全的配色。影响 `13-cyber-neon-v7-edge` / `18-midnight-study` / `26-velvet-stage` / `27-retro-phosphor` 四个产物。**必须真机双模式预览才能定论**，用户表示自己验证，结论未回
- **candy-pop 主次强调实际是倒过来的**：标为「主强调」的 `#f28ba8` 只有 29 处，「深樱粉」`#d96687` 有 271 处。审计不报。**不一定是缺陷，要看真机观感**
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

## 七、Suggested skills

- `superpowers:verification-before-completion` — **本项目里这条是第一位的**。历史上宽度问题连续改错两次、cyber-neon 对比度连续改错两次，都是只验证了「我改的属性在不在」而没验证「渲染出来是什么样」，或者量错了对象。第四轮的通用做法是：**改完必须去数产物**，不是看自检 PASS
- `superpowers:brainstorming` — 做第六节那个普查脚本之前先用它收敛判据
- `superpowers:test-driven-development` — 给 `md2html.py` 加字段时照搬 `test-md2html.sh` 的范式：先造会失败的用例，再实现
- `tech-writer` — 校订教程文档时
- `skill-creator` — 改 skill 结构、跑 evals、做 description 优化

## 八、环境速查

- md2wechat CLI 3.2.0 已装（npm 全局）；源码在 `~/code/skills/writing/md2wechat-skill/`（另一个 git 仓库，别混）
- 实验目录 `~/code/skills/writing/wechat_test/`
- 用户偏好：**传图、建草稿、git commit/push 一律先经用户确认**；成本敏感，大批量开跑前先报预估
- 用户在 main 分支上直接提交，不开特性分支
