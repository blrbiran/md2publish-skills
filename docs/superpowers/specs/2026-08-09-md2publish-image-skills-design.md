# 设计：图片能力重构为 cover / visuals / diagram 三个 skill

日期：2026-08-09
状态：待实施
取代：`skills/md2publish-images/`（本次拆除）

## 1. 背景

`md2publish-images` 当前完全依赖 `md2wechat` CLI 的计划模式（`--plan`）：CLI 根据 25 个内置 preset 产出图片 prompt，实际生成"交给宿主 Agent 的图片生成能力"。这个设计有两个问题。

**执行环节是空洞的。** SKILL.md 步骤 3 只写了"如果当前运行时有图片生成工具就用它"，没有指定是什么工具、用什么参数、失败怎么办。实际效果取决于运行时碰巧有什么，不可控也不可复现。

**与同仓库的演进方向不一致。** `md2publish-article` 已经完成过一次同类迁移：主题库从"调 CLI 拿实时指令"改成本地资产 `references/theme-prompts/`，CLI 只保留 `inspect` 做元数据检查。`md2publish-images` 还停在旧形态。

同时出现了新需求：`md2publish-*` 系列不再只服务微信公众号，要扩展到小红书、B 站等平台。这是本次重构的主要驱动力——多平台把图片需求撕成了几条不兼容的工作流。

### 1.1 多平台带来的差异

| | 微信公众号 | 小红书 | B 站专栏/视频 |
|---|---|---|---|
| 封面画幅 | 16:9（头条按 2.35:1 裁，次条按 1:1 裁） | 3:4 | 16:9 |
| 封面文字 | **图上不放标题**（标题走草稿 `title` 字段） | **图上必须有大字标题** | 图上有字 |
| 正文图 | 穿插插图 + 信息图 | 无"正文"概念 | 穿插插图 |
| 主体形态 | 长文 + 配图 | **1–18 张卡片系列**，文字是附属 | 长文 + 配图 |
| 单次产出 | 1 封面 + 3–8 张 | 1 系列 | 1 封面 + N |

关键结论：**平台差异不是拆分轴**。"给小红书生成卡片"和"给微信生成封面"共用同一套风格资产和同一个 provider 引擎，差异只在画幅、文字上图与否、张数——这些是参数。真正差异大的是工作流：单张决策 vs 分析全文找配图位 vs 拆成卡片序列 vs 确定性画 SVG。

## 2. 决策摘要

| 决策点 | 选择 | 否决的替代方案 |
|---|---|---|
| 生成引擎归属 | 本地化自包含：把 `baoyu-image-gen` 的 provider 引擎搬进本仓库 | 编排外部 skill（引入硬依赖）；纯计划模式（执行环节仍是空洞） |
| 覆盖形态 | 封面、信息图、文中配图、SVG 示意图 | 知识漫画、幻灯片（不属于发布流水线） |
| 拆分粒度 | 3 个 skill，按工作流拆 | 2 个（SKILL.md 会膨胀到四条并行流程）；4–5 个（信息图与卡片系列工作流高度重叠，拆开大量重复） |
| 共享资产 | 仓库级 `_shared/` 单一真相源 + 构建期 vendor 进各 skill | 每 skill 各自一份手工维护（必然漂移）；软链接（见 4.2） |
| provider 凭证 | 阻塞式首配，强制要求 | 三级降级链。"免费路径"指 md2publish 系统本身不收费，模型费用不在此列 |
| 风格资产范式 | 混合：成品 preset 为默认入口，内部维度可单独覆盖 | 纯成品 preset（不可微调）；纯维度组合（每次都要多轮问答，批量场景磨人） |
| 旧 skill 处置 | 直接拆除 `md2publish-images` | 保留作路由入口（多一层跳转，四个 description 互相拦截） |

## 3. Skill 边界

| skill | 触发意图 | 产物 | 张数 | 生成方式 |
|---|---|---|---|---|
| `md2publish-cover` | 封面 / 头图 / 首图 / 主图 | 1 张主图 | 1 | AI 生图 |
| `md2publish-visuals` | 配图 / 信息图 / 卡片 / 图文笔记 | 图片序列 + Markdown 引用回写 | 按平台 profile（微信正文 3–8，小红书系列 1–18） | AI 生图（批量） |
| `md2publish-diagram` | 架构图 / 流程图 / 时序图 / 画个图 | SVG + 位图双产物 | 1 | **不调 AI**，直接写 SVG |

三个判据彼此不重叠：

- **张数**：单张 vs 序列
- **是否需要先分析全文**：封面只需要标题和摘要；序列必须通读全文才能定位置、定数量
- **是否走模型**：diagram 是确定性输出，零 API 成本，也因此不需要首配

### 3.1 归属判断

**信息图归 `visuals`，不独立成 skill。** 理由是工作流同构：信息图和小红书卡片系列都是「内容 → 结构化 → 排版成图」，而封面是「一句话概念 → 视觉隐喻」。信息图常常只出一张，但它的决策过程跟封面完全不像。

**`md2publish-visuals` 的命名。** 三种形态（正文配图、信息图、卡片系列）的共同点是"一组视觉素材"，不是"插图"——小红书卡片系列的产物是内容本身。`visuals` 中性、好念，与 `cover`（单张主图）、`diagram`（结构图）构成清晰三元；后两者名字更具体，不会抢它的触发。

### 3.2 触发词冲突的兜底

"配图"既可能指封面也可能指正文插图，靠 `description` 区分不可靠。`md2publish-visuals` 的第一步**强制确认范围**：「你要的是文章封面，还是正文里的插图？」宁可多问一句，也不要生成完了才发现方向错了——生图是计费动作。

## 4. 仓库结构与共享层

```
md2publish-skills/skills/
├─ _shared/                        ← 单一真相源，人只改这里；无 SKILL.md，不会被 skill 加载器扫描
│  ├─ platforms/
│  │  ├─ wechat.yaml
│  │  ├─ xiaohongshu.yaml
│  │  └─ bilibili.yaml
│  ├─ presets/
│  │  ├─ INDEX.md                  ← 唯一发现入口（对标 article 的 theme-prompts/INDEX.md）
│  │  ├─ cover/*.yaml
│  │  ├─ infographic/*.yaml
│  │  ├─ illustration/*.yaml
│  │  ├─ series/*.yaml
│  │  └─ dimensions/
│  │     ├─ palettes/*.md
│  │     ├─ renderings/*.md
│  │     └─ layouts/*.md
│  └─ scripts/
│     ├─ imagegen/                 ← 从 baoyu-image-gen 搬入
│     ├─ compose-prompt.py         ← platform + preset + 维度覆盖 → 最终 prompt
│     └─ compress.py               ← sips → cwebp → ImageMagick 降级链
│
├─ md2publish-cover/
│  ├─ SKILL.md
│  └─ shared/                      ← 机器生成，提交进 git
├─ md2publish-visuals/
│  ├─ SKILL.md
│  └─ shared/
├─ md2publish-diagram/
│  ├─ SKILL.md
│  └─ shared/                      ← 只 vendor platforms/ 和 scripts/compress.py，不含 imagegen/ 和 presets/
│
├─ md2publish-article/             ← 现有，需改交接引用
├─ md2publish-draft/               ← 现有，需改封面来源引用
└─ wechat-finetune/                ← 现有，不动

scripts/
├─ sync-shared.sh                  ← _shared/ → 各 skill/shared/
└─ check-shared-drift.sh           ← 比 hash，漂移则 fail
```

### 4.1 搬迁可行性

`baoyu-image-gen` 的 12 个 provider 模块**零第三方依赖**——只用 `node:` 内置模块和 `fetch`（见 `skills/baoyu-image-gen/scripts/main.ts:1-13`、`providers/openai.ts:1-3`）。`baoyu-skills/package.json` 里的 `sharp` / `pdf-lib` / `pptxgenjs` 是其他 skill 用的。因此搬迁是纯文件复制，不拖 npm 依赖树。

例外：`codex-cli` provider 通过 spawn 调用 `codex` 二进制，属于可选后端，缺失时降级为不可用而非报错。

### 4.2 为什么不用软链接

软链接在真正需要它的场景里恰好失效：

| 场景 | 相对路径 `../_shared/` | 软链接 | vendor |
|---|---|---|---|
| 整仓库 clone（macOS/Linux） | ✅ | ✅ | ✅ |
| Windows git clone | ✅ | ❌ 未开开发者模式时 git 把 symlink 存成含路径的普通文本文件 | ✅ |
| 单 skill 被拷走 | ❌ | ❌ `cp -R`/`tar`/`zip` 默认保留链接不跟随 → 悬空 | ✅ |
| plugin 打包分发 | ❌ | ❌ 同上 | ✅ |

软链接额外的问题是 GNU 与 BSD 的 `cp` 在符号链接处理上行为不一致，依赖它等于依赖一个平台相关的实现细节。（本条未实测，依据文档行为。）

vendor 的代价是仓库里有重复文件，`_shared/` 一改会产生较大的 commit。缓解：`.gitattributes` 把 `skills/*/shared/**` 标为 `linguist-generated` 折叠 diff；`check-shared-drift.sh` 进 quality gate 拦截人工改动 vendor 副本。

`sync-shared.sh` **按 skill 需要的子集拷贝**，不是全量三份。清单在脚本内声明：

| skill | platforms/ | presets/ | scripts/imagegen/ | scripts/compose-prompt.py | scripts/compress.py |
|---|---|---|---|---|---|
| `md2publish-cover` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `md2publish-visuals` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `md2publish-diagram` | ✅ | ❌ | ❌ | ❌ | ✅ |

这个选择同时满足了 baoyu `CLAUDE.md` 里那条自包含约束（"Never link from SKILL.md to files outside the skill's own directory"）——未来想把某个 skill 单独发出去不用返工。

## 5. 资产 schema

### 5.1 platform profile

平台只管画幅、文字上图策略、硬限制，不管视觉风格。

```yaml
# _shared/platforms/wechat.yaml
name: wechat
display_name: 微信公众号
cover:
  aspect: "16:9"
  text_on_image: none              # none | title | title+subtitle
  crop_warning: 头条按 2.35:1 裁，次条按 1:1 裁，重要视觉元素放画面中央
  max_bytes: 2MB
body_images:
  aspect: ["16:9", "4:3"]
  max_bytes: 10MB
series: null
# 预留给 md2publish-article 多平台化，本次不消费。值为相对 skills/ 的路径。
html_constraints: md2publish-article/references/wechat-html.md
```

```yaml
# _shared/platforms/xiaohongshu.yaml
name: xiaohongshu
display_name: 小红书
cover:
  aspect: "3:4"
  text_on_image: title+subtitle
  safe_area: 上下各留 12%，标题置于上 1/3
  max_bytes: 20MB
body_images: null
series:
  aspect: "3:4"
  count_range: [1, 18]
  first_is_cover: true
html_constraints: null
```

`text_on_image` 是 schema 里最关键的字段：它不是尺寸参数，而是改变 prompt 正文的开关。微信标题走草稿字段、图上不放字；小红书首图不放大字标题就没人点。

### 5.2 preset

preset 只管视觉，画幅从 platform 取。维度字段引用 `dimensions/` 下的词表文件，可被用户单独覆盖。

```yaml
# _shared/presets/cover/editorial-warm.yaml
name: editorial-warm
archetype: cover                   # cover | infographic | illustration | series
description: 杂志编辑风封面，暖色调，适合人文/商业随笔
version: 1.0.0
palette: warm-earth                # → dimensions/palettes/warm-earth.md，可覆盖
rendering: flat-vector             # → dimensions/renderings/flat-vector.md，可覆盖
layout: null                       # infographic / series 才用
compatible_platforms: [wechat, xiaohongshu, bilibili]
metadata:
  author: md2publish-skills
  provenance: 改编自 md2wechat cover-editorial + baoyu-cover-image 维度体系
template: |
  {{PLATFORM_FRAME}}
  {{PALETTE}}
  {{RENDERING}}
  内容主题：{{CONTENT}}
```

必填字段（缺失应被 schema 校验直接拦住，参考 md2wechat `CLAUDE.md` 的同类要求）：`name`、`archetype`、`description`、`version`、`compatible_platforms`、`metadata.author`、`metadata.provenance`、`template`。

最终 prompt = `{{PLATFORM_FRAME}}`（画幅 + 文字策略 + 安全区，来自 platform）+ `{{PALETTE}}` + `{{RENDERING}}`（来自 preset 或用户覆盖）+ `{{CONTENT}}`。preset 与 platform 正交，加一个新平台 = 加一个 YAML，所有 preset 自动可用。

这与 `md2publish-article` 的 `_common-tech.md` + `<theme>.md` 拼接方式同构。

## 6. 执行链路

```
步骤 0  首配（阻塞）       ~/.config/md2publish/images.yaml
        └ provider / model / 默认平台 / 并发上限
        └ 缺失 → AskUserQuestion 引导写入，写完才继续
        └ 只对 cover 和 visuals 生效；diagram 不走模型，不做首配阻塞

步骤 1  确定平台           用户明说 → 文章 frontmatter 的 platform: → 配置默认值 → 询问
        └ 支持一稿多投：--platform wechat,xiaohongshu 一次出两套画幅

步骤 2  选 preset          读 shared/presets/INDEX.md 按文章调性推荐
        └ 用户提偏好（如"换暖色"）→ 只覆盖那一个维度，不换整个 preset

步骤 3  组 prompt 并落盘    compose-prompt.py --platform X --preset Y [--palette Z] \
                                             --content-file article.md --out prompts/01-cover.md
        └ 落盘是硬要求，不是可选

步骤 4  生成               单张：imagegen/main.ts --promptfiles prompts/01-cover.md \
                                                  --image assets/cover.png --ar <平台画幅>
                          多张：imagegen/main.ts --batchfile batch.json --jobs N

步骤 5  压缩到平台限制内    compress.py --max-bytes <platform.*.max_bytes>

步骤 6  落盘 + 回写/交接    全部产物落 <article-dir>/assets/
```

三个设计要点：

**prompt 强制落盘。** 沿用 baoyu `CLAUDE.md` 的硬约束（"Every rendered image's full prompt must be written to a standalone `prompts/NN-*.md` file before any backend is invoked"）。它换来的是：生成不满意时改文件重跑那一张，而不是从头重走决策流程；同一批图的风格一致性也有据可查。

**压缩必须在 images 阶段做完，不能留给 draft。** 微信封面 2MB 是硬限制，等到推草稿箱才发现超限，前面所有决策都白做。

**配置文件不复用 baoyu 的 `EXTEND.md`。** 两套 skill 可能同时装在一台机器上，共用配置文件会互相覆盖。用自己的 `~/.config/md2publish/images.yaml`。

## 7. 副作用与确认边界（重划）

现有 `skills/README.md` 中「配图零副作用」的承诺在本次重构后不再成立，两处都不成立：

| | 原来 | 现在 |
|---|---|---|
| 生成 | `--plan` 只吐 prompt，零调用 | 真调 provider，**真花钱**，且不可逆 |
| 产物 | 只写新文件 | `visuals` 要**回写用户的 Markdown 源文件** |

原设计把"唯一的外部副作用集中在 draft skill"当作核心卖点，这个格局被打破。重新划的边界：

- **花钱的门**：批量生成前必须报「将生成 N 张 / 调用 N 次 API / provider 是 X」，确认后执行。单张不问——用户主动要封面就是要了。
- **改源文件的门**：回写 Markdown 前展示插入位置和 diff，确认后执行；且**默认另存 `article.illustrated.md` 而不是原地改**，与 `wechat-finetune`「原文不动，另存」的既有做法保持一致。

于是 `md2publish-draft` 仍然是唯一有**外部系统**副作用（写微信素材库 / 草稿箱）的 skill；images 侧的副作用是**本地文件 + API 消费**，性质不同、门也不同。

## 8. 失败处理

生图的失败模式与 CLI 转换不同——不是"命令错了"，而是"钱花了但结果不对"。按能否重试分类：

| 类别 | 典型 | 处理 | 直接重试 |
|---|---|---|---|
| 配置类 | 认证失败、模型名不存在 | 回步骤 0 改配置 | 是（重试免费） |
| 配额类 | 余额不足、限流 | 报告并停，**不自动重试** | 否 |
| 审核类 | 内容策略拒绝 | 定位 prompt 中的触发词，给具体改写建议，不是笼统"换个说法" | 改后重试 |
| 网络类 | 超时、连接中断 | 退避重试最多 2 次 | 是 |
| 质量类 | 生成了但不满意 | 改 `prompts/NN.md` 重跑那一张 | 计费 |

批量场景两条规则：

- **部分失败不整体回滚。** 10 张成功 7 张就保留那 7 张，报告失败的 3 张，允许只重跑失败的。已经花掉的钱不能因为一个失败被丢弃。
- **成本护栏前置。** 批量前报数量和 provider，确认后执行。这是第 7 节"花钱的门"的具体落地。

## 9. 对现有 skill 的改动清单

拆除 `md2publish-images` 会留下四处悬空引用：

| 文件 | 位置 | 改动 |
|---|---|---|
| `md2publish-article/SKILL.md` | `:16` 边界节 | 「封面图/信息图 → md2publish-images」拆成 cover / visuals / diagram 三个去向 |
| `md2publish-article/SKILL.md` | `:85` 步骤 8 交接 | 同上 |
| `md2publish-draft/SKILL.md` | `:33` 封面来源 | 「md2publish-images 产物」→「md2publish-cover 产物（`<article-dir>/assets/`）」 |
| `skills/README.md` | `:18-30` 工作流图 | 重画，images 一支变三支 |
| `skills/README.md` | `:39` skill 表格 | 三行替一行，副作用列不再是「无」 |
| `skills/README.md` | `:51-56` 设计要点 | 「免费路径」改口径（系统免费 ≠ 模型免费）；「确认边界」按第 7 节重述 |

## 10. 验证

沿用 `md2publish-article/scripts/test-*.sh` 的既有写法。四项必须自动化：

1. **平台 × preset 矩阵**：每个组合都能产出非空 prompt，且断言平台字段真的注入了（画幅、`text_on_image` 策略出现在结果里）。这是最容易静默漂移的地方——preset 加了占位符但 compose 脚本不认，出来的图就少一半约束，而且肉眼看不出来。
2. **preset schema 校验**：必填字段齐全、引用的 `dimensions/*` 文件存在、`compatible_platforms` 里的平台 profile 存在。对标 md2wechat `CLAUDE.md`：「漏了主用途、默认比例、来源字段，测试应直接拦住」。
3. **压缩后不超限**：给定 `max_bytes`，压完必须真的小于它。
4. **shared 漂移检查**：`check-shared-drift.sh` 比 hash，进 quality gate。

一项不进 CI、手动跑：**真调一次 provider 生一张图的最小 smoke**。它计费，不能放进自动化。

## 11. 不在本次范围（Known Limitations）

1. **`md2publish-draft` 仍是微信专用。** `doctor` / `upload_image` / `create_draft` 全是微信 API。多平台真正落地时它要分化成 `-draft-wechat` / `-draft-xhs` / `-draft-bilibili`，那是独立的一轮。本次只保证 `_shared/platforms/` 的 schema 能承载它们，不动 draft 本身。
2. **`md2publish-article` 未多平台化。** `references/wechat-html.md` 的五条铁律是微信编辑器专属。`platforms/*.yaml` 已预留 `html_constraints` 字段给它，避免以后为了塞字段返工。
3. **`md2publish-diagram` 的 SVG 需要转位图。** 微信不接受 SVG，因此 diagram 输出 SVG + PNG 双产物，Markdown 引 PNG。转换降级链：`rsvg-convert` → `ImageMagick convert` → headless Chrome（`--screenshot`）；三者都缺时保留 SVG 并告知用户需自行转换，不静默失败。SVG 里若嵌入了非系统字体，rsvg 与 Chrome 的渲染结果会不同——因此 diagram 的 SVG 只用系统安全字体族。
4. **未纳入的 baoyu 能力**：知识漫画（`baoyu-comic`）、幻灯片（`baoyu-slide-deck`）——它们是独立内容形态，不属于文章发布流水线。

## 12. 实施分期建议

本设计的工作量超出单个实施计划的合适规模，建议拆三期，每期各自可验证、可交付：

| 期 | 内容 | 完成判据 |
|---|---|---|
| 一 | `_shared/` 骨架（platforms 三个 + preset schema + dimensions 词表 + INDEX.md）、`compose-prompt.py`、`sync-shared.sh` / `check-shared-drift.sh`、第 10 节第 1、2、4 项测试 | 平台 × preset 矩阵测试通过；此时尚无 skill 消费它 |
| 二 | 搬入 `imagegen/` 与 `compress.py`，建 `md2publish-cover`，拆除 `md2publish-images`，改第 9 节的四处悬空引用 | 端到端产出一张微信封面并压到 2MB 内；手动 smoke 通过 |
| 三 | `md2publish-visuals`（含 Markdown 回写门）与 `md2publish-diagram`（含 SVG→PNG 降级链） | 小红书 5 张卡片系列 + 一张架构图端到端通过 |

一期不动任何现有 skill，风险最低；二期是唯一有破坏性变更的一期，`md2publish-images` 在此消失。

## 13. 参考

- `baoyu-skills/skills/baoyu-image-gen/` — provider 引擎来源
- `baoyu-skills/skills/baoyu-cover-image/`、`baoyu-article-illustrator/`、`baoyu-infographic/`、`baoyu-xhs-images/`、`baoyu-diagram/` — 风格维度与工作流参考
- `md2wechat-skill/internal/assets/builtin/prompts/image/` — 25 个成品 preset YAML，preset schema 的字段要求参考
- `md2publish-skills/skills/md2publish-article/` — 本地资产 + INDEX.md 发现模式的既有实现
