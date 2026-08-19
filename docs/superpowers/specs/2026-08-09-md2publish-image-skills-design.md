# 设计：图片能力重构为 cover / visuals / diagram 三个 skill

日期：2026-08-09
状态：已实施（一期、二期 A、二期 B、三期全部完成，见 §15 与 `docs/handoff/handoff-image.md`）
取代：`skills/md2publish-images/`（已拆除）
修订：2026-08-11 第四版，三期收尾把 D11–D17 折回正文（见文末修订记录）

## 1. 背景

`md2publish-images` 当前以 `md2wechat` CLI 的计划模式（`--plan`）为主路径：CLI 根据 25 个内置 preset 产出图片 prompt，实际生成"交给宿主 Agent 的图片生成能力"。它还有一条次要的直连 provider 路径（`SKILL.md:58-67`），但同样没有指定工具与参数。这个设计有两个问题。

**执行环节是空洞的。** `SKILL.md:44-51` 只写了"按优先级选择执行方式"，没有指定是什么工具、用什么参数、失败怎么办。实际效果取决于运行时碰巧有什么，不可控也不可复现。`docs/handoff/handoff.md:520` 记录着这个 skill **从未实测通过**（"宿主生图 + 上传封面未走通"）——这既印证了问题，也意味着拆除它的迁移风险很低。

**与同仓库的演进方向不一致。** `md2publish-article` 已经完成过一次同类迁移：主题库从"调 CLI 拿实时指令"改成本地资产 `references/theme-prompts/`，CLI 只保留 `inspect` 做元数据检查。`md2publish-images` 还停在旧形态。

同时出现了新需求：`md2publish-*` 系列不再只服务微信公众号，要扩展到小红书、B 站等平台。这是本次重构的主要驱动力——多平台把图片需求撕成了几条不兼容的工作流。

### 1.1 多平台带来的差异

以下平台规格属于外部领域知识，无法从本仓库验证，实施前应各自复核一次：

| | 微信公众号 | 小红书 | B 站（此列为**视频投稿**） |
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
| provider 凭证 | 强制配置才能生成，但**门设在生成那一步**，前面免费的步骤照常跑（见 7.1） | 门设在流程开头（没配 provider 就什么都拿不到，白白丢掉零成本的 prompt 产物） |
| 风格资产范式 | 混合：成品 preset 为默认入口，内部维度可单独覆盖 | 纯成品 preset（不可微调）；纯维度组合（每次都要多轮问答，批量场景磨人） |
| 旧 skill 处置 | 直接拆除 `md2publish-images` | 保留作路由入口（多一层跳转，四个 description 互相拦截） |

"免费路径"的口径：**md2publish 系统本身不收费**（不需要 `MD2WECHAT_API_KEY`），图片模型的费用不在此列。

## 3. Skill 边界

| skill | 触发意图 | 产物 | 张数 | 生成方式 |
|---|---|---|---|---|
| `md2publish-cover` | 封面 / 头图 / 首图 / 主图 | 1 张主图 | 1 | AI 生图 |
| `md2publish-visuals` | 配图 / 信息图 / 卡片 / 图文笔记 | 图片序列 + Markdown 引用回写 | 由平台 profile 的 `count_range` 决定 | AI 生图（批量） |
| `md2publish-diagram` | 架构图 / 流程图 / 时序图 / 画个图 | SVG + 位图双产物 | 1 | **不调 AI**，直接写 SVG |

三个判据彼此不重叠：

- **张数**：单张 vs 序列
- **是否需要先分析全文**：封面只需要标题和摘要；序列必须通读全文才能定位置、定数量
- **是否走模型**：diagram 是确定性输出，零 API 成本，也因此不需要 provider 配置

### 3.1 归属判断

**信息图归 `visuals`，不独立成 skill。** 理由是工作流同构：信息图和小红书卡片系列都是「内容 → 结构化 → 排版成图」，而封面是「一句话概念 → 视觉隐喻」。信息图常常只出一张，但它的决策过程跟封面完全不像。

**`md2publish-visuals` 的命名。** 三种形态（正文配图、信息图、卡片系列）的共同点是"一组视觉素材"，不是"插图"——小红书卡片系列的产物是内容本身。`visuals` 中性、好念，与 `cover`（单张主图）、`diagram`（结构图）构成清晰三元；后两者名字更具体，不会抢它的触发。

### 3.2 触发歧义：先查路由表，查不到才问

"配图"既可能指封面也可能指正文插图。但大多数情况可以由平台推导，不必每次都问——每次都问会退化成 §2 否决纯维度组合时反对的那种多轮问答：

| 平台 | 用户说"配图 / 图" | 依据 |
|---|---|---|
| 微信 | → `visuals`（正文插图） | `wechat.archetypes.cover` 与 `illustration` 是不同产物，"封面"有专属词 |
| 小红书 | → `visuals`（卡片系列），**首图即封面** | `first_is_cover: true`——在小红书，封面和卡片是同一批产物，`cover` 被 `visuals` 吸收 |
| B 站 | 询问 | 专栏头图与正文插图都常被叫"配图"，无可靠推导依据。**`bilibili.yaml` 落地后这条依然成立**——它补的是画幅规格，消除不了命名歧义 |

只有路由表判不出、或用户明确要求单张主图时才提问。用户说"封面 / 头图 / 首图"一律直达 `cover`（小红书除外，见上）。

## 4. 仓库结构与共享层

```
md2publish-skills/skills/
├─ _shared/                        ← 单一真相源，人只改这里；无 SKILL.md，不会被 skill 加载器扫描
│  ├─ platforms/
│  │  ├─ wechat.yaml   xiaohongshu.yaml   bilibili.yaml
│  ├─ presets/
│  │  ├─ INDEX.md                  ← preset 与 dimensions 的唯一发现入口
│  │  ├─ cover/*.yaml   infographic/*.yaml   illustration/*.yaml   series/*.yaml
│  │  └─ dimensions/
│  │     ├─ palettes/*.md   renderings/*.md   layouts/*.md
│  ├─ costs.yaml                   ← provider × model 的单张估价，允许 unknown
│  └─ scripts/
│     ├─ imagegen/                 ← 从 baoyu-image-gen 搬入
│     ├─ compose-prompt.py         ← 纯模板渲染器，零模型调用（见 §6）
│     ├─ compress.py               ← sips → cwebp → ImageMagick 降级链
│     └─ preflight.py              ← 运行时 / provider 配置 / 压缩工具链 三项自检
│
├─ md2publish-cover/     SKILL.md + shared/
├─ md2publish-visuals/   SKILL.md + shared/
├─ md2publish-diagram/   SKILL.md + shared/
│
├─ md2publish-article/   ← 现有，需改输入表与交接
├─ md2publish-draft/     ← 现有，需改封面来源引用
└─ wechat-finetune/      ← 现有，需改交接引用

scripts/
├─ sync-shared.sh         ← _shared/ → 各 skill/shared/
├─ check-shared-drift.sh  ← 比 hash，漂移则 fail
└─ check.sh               ← 跑全部测试 + 漂移检查（见 §13）
```

### 4.1 搬迁可行性

`baoyu-image-gen` 的 provider 模块**零第三方依赖**——`scripts/` 下所有文件（`main.ts`、`build-batch.ts`、`types.ts`、12 个 provider）的每一条 import 都是 `node:*` 或相对路径，没有任何 npm 包。见 `skills/baoyu-image-gen/scripts/main.ts:1-13`、`providers/openai.ts:1-3`。`baoyu-skills/package.json` 里的 `sharp` / `pdf-lib` / `pptxgenjs` 分别属于 `baoyu-compress-image`、`baoyu-comic`、`baoyu-slide-deck`，与本次搬迁无关。

12 个 provider：agnes、azure、codex-cli、dashscope、google、jimeng、minimax、openai、openrouter、replicate、seedream、zai。

例外：`codex-cli` provider 并不直接 spawn `codex`——它 spawn `bun` 去跑 `packages/baoyu-codex-imagegen` 这个 wrapper，由 wrapper 内部 `spawn("codex", ...)`。搬迁时这两层要一起搬，或改写成直接 spawn。它是可选后端，缺失时降级为不可用而非报错。

### 4.2 为什么不用软链接

以下为文档行为，未在本机实测：

| 场景 | 相对路径 `../_shared/` | 软链接 | vendor |
|---|---|---|---|
| 整仓库 clone（macOS/Linux） | ✅ | ✅ | ✅ |
| Windows git clone | ✅ | ❌ 未开开发者模式时 git 把 symlink 存成含路径的普通文本文件 | ✅ |
| 单 skill 被 `cp -R` / `tar` 拷走 | ❌ | ❌ 两者默认保留链接不跟随 → 悬空 | ✅ |
| 单 skill 被 `zip` 打包 | ❌ | ⚠️ zip **默认跟随**链接存实际内容（`-y` 才存链接），不会悬空，但会把 `_shared/` 悄悄复制成三份互不相干的副本 | ✅ |
| plugin 打包分发 | ❌ | ❌ 取决于打包工具，不可预测 | ✅ |

软链接额外的问题是 GNU 与 BSD 的 `cp` 在符号链接处理上行为不一致，且 `zip` 与 `cp`/`tar` 的默认方向相反——依赖它等于依赖一组平台相关且互不一致的实现细节。

vendor 的代价是仓库里有重复文件，`_shared/` 一改会产生较大的 commit。缓解：`.gitattributes` 把 `skills/*/shared/**` 标为 `linguist-generated` 折叠 diff。

### 4.3 vendor 清单与漂移恢复

`sync-shared.sh` **按 skill 需要的子集拷贝**，不是全量三份。清单在脚本内声明：

| skill | platforms/ | presets/ | costs.yaml | imagegen/ | compose-prompt.py | compress.py | preflight.py |
|---|---|---|---|---|---|---|---|
| `md2publish-cover` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `md2publish-visuals` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `md2publish-diagram` | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |

`md2publish-diagram` 仍需 `platforms/`——它要读 `archetypes.diagram` 的画幅与 `max_bytes` 来决定位图转换参数（见 §5.1）。

**漂移恢复程序**（这是 vendoring 唯一的真实失败模式，必须写死）：`check-shared-drift.sh` 报告漂移时，正确动作永远是「你的改动改错地方了，把它挪到 `_shared/` 再 re-sync」，**绝不是**「re-sync 覆盖掉」。脚本输出必须直接打印这句话和 diff，不能只报 exit 1。

## 5. 资产 schema

### 5.1 platform profile

平台按 **archetype 分槽**，使得「新增一个 archetype 却忘了给某平台定义」在结构上不可能发生。每个槽要么完整定义，要么显式写 `unsupported`；composer 遇到 `unsupported` 硬失败并说明原因，不静默回退。

`max_bytes` 一律用整数字节，不用 `2MB` 这类字符串——避免 `compress.py` 收到一个需要解析的后缀。

```yaml
# _shared/platforms/wechat.yaml
name: wechat
display_name: 微信公众号
archetypes:
  cover:
    aspect: "16:9"
    max_bytes: 2097152
    crop_warning: 头条按 2.35:1 裁，次条按 1:1 裁，重要视觉元素放画面中央
    text_on_image:
      title: false
      subtitle: false
      notes: 标题由草稿 title 字段承载，图上再放一次就是重复标题
  illustration:
    aspect: ["16:9", "4:3"]
    count_range: [3, 8]
    max_bytes: 10485760
    text_on_image: {title: false, subtitle: false}
  infographic:
    aspect: "4:3"
    max_bytes: 10485760
    text_on_image:
      title: true
      subtitle: true
      notes: 信息图的文字是内容本体，必须清晰可读
  series: unsupported
  diagram:
    aspect: ["16:9", "4:3"]
    max_bytes: 10485760
    raster_format: png
    notes: 微信不接受 SVG，正文引位图
```

```yaml
# _shared/platforms/xiaohongshu.yaml
name: xiaohongshu
display_name: 小红书
archetypes:
  cover:
    aspect: "3:4"
    max_bytes: 20971520
    safe_area: 上下各留 12%，标题置于上 1/3
    text_on_image:
      title: true
      subtitle: true
      notes: 首图不放大字标题基本没人点
  illustration: unsupported
  infographic:
    aspect: "3:4"
    max_bytes: 20971520
    text_on_image: {title: true, subtitle: true}
  series:
    aspect: "3:4"
    count_range: [1, 18]
    first_is_cover: true
    max_bytes: 20971520
    text_on_image:
      title: true
      subtitle: true
      notes: 第 1 张承载标题，第 2..N 张各承载一个分点
  diagram:
    aspect: "3:4"
    max_bytes: 20971520
    raster_format: png
```

`text_on_image` 是 schema 里最关键的字段，因此它是一个结构而不是枚举——单个枚举值无法表达"系列里第 1 张和第 2..N 张的文字角色不同"。它不是尺寸参数，而是改变 prompt 正文的开关：微信标题走草稿字段、图上不放字；小红书首图不放大字标题就没人点。

`bilibili.yaml` 结构相同。**取值以 §14.5 为准，不是 §1.1**——§1.1 那一列写的是
B 站**视频投稿**（16:9），而本仓库是文章发布线，已落地的 `bilibili.yaml` 建模的是
**专栏**（头图 3:2 中心裁切）。视频封面至今未建模，理由见 §14.5。

### 5.2 preset

preset 只管视觉，画幅从 platform 取。维度字段引用 `dimensions/` 下的词表文件，可被用户单独覆盖。

```yaml
# _shared/presets/cover/editorial-warm.yaml
name: editorial-warm
archetype: cover                   # cover | illustration | infographic | series | diagram
description: 杂志编辑风封面，暖色调
primary_use_case: 人文随笔与商业观察类长文的封面
version: 1.0.0
palette: warm-earth                # → dimensions/palettes/warm-earth.md，可覆盖
rendering: flat-vector             # → dimensions/renderings/flat-vector.md，可覆盖
layout: null                       # infographic / series 才用
incompatible_platforms: []         # 默认空 = 全平台可用
metadata:
  author: md2publish-skills
  provenance: 改编自 md2wechat cover-editorial + baoyu-cover-image 维度体系
template: |
  {{PLATFORM_FRAME}}
  {{PALETTE}}
  {{RENDERING}}
  {{CONTENT}}
```

**必填字段**（缺失应被 schema 校验直接拦住）：`name`、`archetype`、`description`、`primary_use_case`、`version`、`metadata.author`、`metadata.provenance`、`template`。字段集对齐 md2wechat `CLAUDE.md`「新增图片 Prompt 后」一节，`recommended_aspect_ratios` / `default_aspect_ratio` 两项由 platform profile 承担，故不在 preset 侧重复。

**用 `incompatible_platforms`（排除制）而非 `compatible_platforms`（白名单）。** 白名单会让「加一个新平台 = 加一个 YAML」这个卖点失效——加第 4 个平台要回头编辑每一个 preset，正是 §2 拒绝手工维护共享资产的那个成本。排除制下新平台默认可用，个别不适配的 preset 再显式排除。

**占位符是固定集合**：`{{PLATFORM_FRAME}}`、`{{PALETTE}}`、`{{RENDERING}}`、`{{LAYOUT}}`、`{{CONTENT}}`。`compose-prompt.py` 遇到集合外的占位符**硬失败**，不允许原样输出——原样输出正是 §13 第 1 项测试要防的静默降级：图少了一半约束，而肉眼看不出来。

**维度覆盖的完整机制**：合法维度值列在 `presets/INDEX.md`（它同时是 preset 和 dimensions 的发现入口）。CLI 提供 `--palette` / `--rendering` / `--layout` 三个覆盖开关，各自对应一个占位符。用户说"换暖色"时，agent 从 INDEX.md 的 palettes 段找到最接近的值（如 `warm-earth`），用 `--palette warm-earth` 覆盖，其余维度沿用 preset。

最终 prompt = `{{PLATFORM_FRAME}}`（画幅 + 文字策略 + 安全区，来自 platform 的对应 archetype 槽）+ `{{PALETTE}}` + `{{RENDERING}}` + `{{LAYOUT}}`（来自 preset 或覆盖）+ `{{CONTENT}}`（来自 agent 写的 brief，见 §6）。

**prompt 语言**：模板与维度词表一律用中文，`{{CONTENT}}` 也是中文（文章本身是中文）。不做中英双语维护，也不在送 provider 前翻译。这是一个已知取舍——部分 provider 对中英 prompt 的表现有差异，若实测发现某 provider 显著更适合英文，再单独为它加一层译层，不改词表。

### 5.3 产物 sidecar

每张图落盘时同时写一个同名 `.json`，记录**生成它的全部输入**。`prompts/` 保存的是渲染后的 prompt，保存不了输入：

```json
{
  "platform": "wechat",
  "archetype": "cover",
  "preset": "editorial-warm",
  "preset_version": "1.0.0",
  "overrides": {"palette": "cool-slate"},
  "provider": "openai",
  "model": "gpt-image-2",
  "prompt_file": "prompts/wechat/00-cover.md",
  "brief_file": "briefs/wechat/00-cover.md",
  "source_file": null,
  "alt_text": "暖色调的编辑风封面，主体是一支钢笔与散落的稿纸",
  "image": "00-cover.jpg",
  "bytes": 1843200,
  "generated_at": "2026-08-09T14:22:31+08:00"
}
```

`image` 记的是**最终产物的文件名**（不是路径）：sidecar 写在最终产物旁边、与它同名，
而压缩产物 `.jpg` 与原图 `.png` 算出来是同一个 `.json`，**文件名本身区分不了两者**。
下游要消费哪个文件，一律读这个字段，在 sidecar 所在目录下解析。

它同时解决三件事：preset 演进后能查出某张图是哪个版本产的（主题库刚经历过 27 → 26 的删改，preset 也会）；§7 的重跑跳过判断有依据；`alt_text` 有地方存——旧 skill 有这个字段，新设计里一度丢了，Markdown 回写需要它。

**`diagram` 支路**：`archetype: diagram` 不调 AI、不走 preset，因此 `preset`、`preset_version`、`model`、`prompt_file`、`brief_file` 一律记 `null`；新增字段 `source_file` 记它唯一的复现记录——SVG 的**文件名**（不是路径），其余 archetype 一律 `null`。`provider` 字段的语义随之改变：对 AI 生图是 provider 名（`openai` 等），对 `diagram` 是**光栅化后端名**（`rsvg-convert` / `magick` / `chrome`）——同一份 SVG 在装了 `rsvg-convert` 和只装了 Chrome 的两台机器上会产出不同的位图，`provider` 不记就无从追溯是哪个后端渲染的。

## 6. 职责分层：机械层与语义层

这是本设计最容易被实施者猜错的地方，因此单列一节。`md2publish-article/SKILL.md:69` 对同一问题有明确回答（"生成用 `scripts/md2html.py` 做机械层……你只写主题配置和做语义判断"），本设计沿用同样的切法。

| 层 | 谁做 | 输入 | 输出 |
|---|---|---|---|
| **语义层** | Agent | 文章原文 | 每张图一份 **brief**：这张图要表达什么、主体是什么、放在文章哪个位置、alt 文本 |
| **机械层** | `compose-prompt.py` | platform + preset + 维度覆盖 + brief 文件 | 渲染后的 prompt 文件 |

`compose-prompt.py` 是**纯模板渲染器**：读 YAML、填占位符、写文件。它不读文章、不做内容抽取、不调模型。

**`diagram` 不落在这条切法里。** 它的语义层产物就是 SVG 本身——agent 直接手写 SVG，不经过 `compose-prompt.py`，也没有 prompt 这道机械层：维度词表（`soft-gouache`、`flat-vector`）是写给 AI 生图 prompt 消费的，SVG 不消费它们，硬套只会多产出一份没有任何消费者的中间文件。SVG 源文件本身就是复现记录——改它重跑，结果是确定的，比改 prompt 重新生图更强。

这条边界带来三个后果，都是有意的：

1. `--content-file` 指向的是 **agent 写的 brief**，不是文章原文。接口是 `--brief-file briefs/<platform>/NN-<role>.md`。
2. §13 第 1 项「平台 × preset 矩阵」测试可以用 fixture brief 跑，不需要模型，因此一期就能验证。
3. §3.1 的差异（cover 是「一句话概念 → 视觉隐喻」，series 是「通读全文定位置」）活在三个 SKILL.md 里，不在脚本里。脚本对三者一视同仁。

## 7. 执行链路

```
步骤 1  preflight              preflight.py 检查三项：TS 运行时 / provider 配置 / 压缩工具链
        └ 只报告，不阻塞。provider 缺失在此登记，步骤 5 才拦

步骤 2  确定平台                用户明说 → 文章 frontmatter 的 platform: → 配置默认值 → 询问
        └ 多平台见 7.2

步骤 3  选 preset               读 shared/presets/INDEX.md 按文章调性推荐
        └ 用户提偏好 → --palette / --rendering / --layout 覆盖单个维度，不换整个 preset

步骤 4  写 brief 并渲染 prompt   4a 语义层：agent 为每张图写 briefs/<platform>/NN-<role>.md
                               4b 机械层：compose-prompt.py --platform X --preset Y \
                                          [--palette Z] --brief-file ... --out prompts/<platform>/NN-<role>.md
        └ 到此为止零成本、零副作用。没配 provider 也能走完并交付 prompt 文件

═══ 以下开始计费 ═══

步骤 5  凭证门 + 成本门          provider 未配置 → 报告 prompt 文件路径并停止（见 7.1）
        └ 批量 → 报「N 张 / 预估 ¥X / provider / model」，确认后执行（见 §9）

步骤 6  生成                    单张：imagegen/main.ts --promptfiles prompts/<p>/00-cover.md \
                                                       --image assets/<p>/00-cover.png --ar <画幅>
                               多张：imagegen/main.ts --batchfile batch.json --jobs N

步骤 7  压缩                    compress.py --max-bytes <archetypes.<a>.max_bytes>

步骤 8  落盘 + 回写/交接         见 7.3
```

**`visuals` 在步骤 8 之后再加一步（本 skill 独有）：**

```
步骤 9  回写门                  写 insertions.json（语义层：哪张图插哪、alt 文本）
                               → 展示插入位置与 diff → 确认 → writeback.py 另存
                                 article.illustrated.md，原文不动
        └ series 不回写：卡片系列是内容本身，不进正文，走到步骤 8 就收工（见 7.2）
```

**`diagram` 的链路不套用上面这条**：它不调 AI、不走 preset / prompt，没有「═══ 以下开始计费 ═══」那条线，全程零成本，因此也不需要凭证门。

```
步骤 1  查后端（零成本）        svg2raster.py --check 报告本机可用的光栅化后端
步骤 2  定平台                  取 archetypes.diagram 的画幅（aspect）与体积上限（max_bytes）
步骤 3  写 SVG（语义层，本 skill 的核心） agent 直接手写 SVG，落 diagrams/<platform>/NN-diagram.svg；
                               SVG 源文件本身就是复现记录，不经过 compose-prompt.py（见 §6）
步骤 4  光栅化                  svg2raster.py --svg ... --out ... --aspect ...（降级链见 §14.3）
步骤 5  压缩（多半用不上）      光栅化产物通常远低于上限；真超限时更该降低宽度重新光栅化
步骤 6  写 sidecar              provider 记实际用的光栅化后端名，preset 等字段全为 null（见 §5.3）
步骤 7  交接                    要插正文 → 用本 skill 自己 vendor 的 writeback.py 回写
                                （机制与 visuals 步骤 9 相同，各自 vendor 一份，互不依赖）；
                               必须在 md2publish-article 转 HTML 之前完成；
                               只是单独导出一张图 → 与流水线无耦合
```

### 7.1 凭证门放在步骤 5 而不是流程开头

步骤 1–4 全部零成本，而 `prompts/<platform>/NN-*.md` **恰好就是**旧计划模式的产物。把门设在步骤 5，没配 provider 的用户仍然拿得到 prompt 去即梦 / Midjourney 自己生，而"要生成必须先配"这条硬要求一点没松。

这不是把降级链塞回来——它只有一级，且是本来就要落盘的东西。顺带的好处是二期回滚几乎免费（见 §15）。

**prompt 强制落盘**沿用 baoyu `CLAUDE.md` 的硬约束（"Every rendered image's full prompt must be written to a standalone `prompts/NN-*.md` file before any backend is invoked"）。它换来的是：生成不满意时改文件重跑那一张，而不是从头重走决策流程；同一批图的风格一致性也有据可查。

### 7.2 多平台只对 cover 和 diagram 开放

`--platform wechat,xiaohongshu` 一次出两套画幅，对 `cover` 和 `diagram` 成立——同一个视觉概念换两个画幅。

**对 `visuals` 不成立。** 按 §1.1，微信要的是 3–8 张装点长文的插图，小红书要的是整个卡片系列——那是**不同内容、不同张数、不同源材料**，不是不同画幅。§5.1 已在结构上编码了这一点（`wechat.archetypes.series: unsupported`、`xiaohongshu.archetypes.illustration: unsupported`）。

因此 `md2publish-visuals` 收到多平台参数时，**必须拆成一个平台一次的独立执行**（几个平台就几次）：各自选 preset、各自写 brief、各自过成本门。不允许一次确认覆盖多个平台的花费。

**`series` 不回写 Markdown。** 卡片系列的产物是内容本身、不进正文——§3.1 论证 series 与 illustration 的差别用的就是这一点。`visuals` 处理 `series` 时到写完 sidecar（步骤 8）就结束，不产生 `<name>.illustrated.md`，也没有步骤 9 的回写门；回写门只在 `illustration` / `infographic` 要插进正文、以及 `diagram` 的产物要插进正文时触发。**回写门是同一份 `writeback.py` 机制**，`visuals` 与 `diagram` 各自从 `_shared/` vendor 了一份、各跑各的——`diagram` 触发回写时不经过 `visuals` 的凭证门/成本门/生成步骤（那三步 diagram 完全不需要），直接在自己的 skill 目录里把 vendored 的 `writeback.py` 当独立脚本调用即可。

### 7.3 产物布局与重跑行为

```
<article-dir>/
├─ <name>.wechat.md
├─ <name>.illustrated.md           ← visuals 的回写产物（另存，不改原文）
├─ briefs/<platform>/NN-<role>.md
├─ prompts/<platform>/NN-<role>.md
└─ assets/<platform>/NN-<role>.png + NN-<role>.json
```

`<name>` 是 `wechat-finetune` 写出 `<name>.wechat.md` 时用的用户原始文件名——
不是字面量 `article`，本文档下面用 `article.*` 只是示意图里方便指代的占位符，
命名推导规则见 §8。

`<role>` 取 `cover` / `illustration` / `infographic` / `series` / `diagram`；`NN` 从 `00` 起。按平台分目录，因此 `--platform wechat,xiaohongshu` 的两张封面不会同名相撞。

**重跑行为**：目标文件已存在 → **跳过并报告**，除非显式 `--force`。永不静默覆盖。`md2publish-article/SKILL.md:77` 已经确立了"路径已存在先问用户是否覆盖"的房规，而这里被覆盖的东西是花钱生成的，理由只会更强。`briefs/` 和 `prompts/` 与产物一同保留，它们是复现记录，不是临时文件。

**压缩必须在本阶段做完，不能留给 draft。** 微信封面 2MB 是硬限制，等到推草稿箱才发现超限，前面所有决策都白做。

**配置文件不复用 baoyu 的 `EXTEND.md`。** 两套 skill 可能同时装在一台机器上，共用配置文件会互相覆盖。用自己的 `~/.config/md2publish/images.yaml`，字段：`provider`、`model`、`default_platform`、`max_concurrency`、`max_images_per_run`。

## 8. 流水线次序

`visuals` 会回写 Markdown，因此它在 `md2publish-article` 的**上游**，不是并行分支。这一点必须体现在 `skills/README.md` 的流程图里，否则实施者会画成三个并行框，然后带图版本静默地永远不被转换。

```
wechat-finetune → <name>.wechat.md
                       │
                       ├──→ md2publish-visuals ──→ <name>.illustrated.md ──┐
                       │    （回写图片引用，另存）                           │
                       │                                                   ▼
                       └────────────────────────────────→ md2publish-article ──→ .html
                                                                              │
   md2publish-cover ────→ assets/<platform>/00-cover.png ─────────────────────┤
                                                                              ▼
                                                                    md2publish-draft
```

**文件名推导规则（本节唯一的权威定义，其余文档照这条来）**：`wechat-finetune`
产出的是 `<name>.wechat.md`，`<name>` 是用户原始文件名，仓库里**没有**"每篇
文章一个目录"这样的强约定能保证它就是 `article`——`wechat-finetune` 只是把
产物写在用户原文件旁边。`md2publish-visuals` 回写时把 `.wechat.md` 换成
`.illustrated.md`，同目录另存为 `<name>.illustrated.md`，`<name>` 不变。

- **`visuals` 串在 `article` 上游**：有配图时，`article` 的输入是 `<name>.illustrated.md` 而不是 `<name>.wechat.md`。默认规则：`md2publish-article` 步骤 1 在同目录按 `*.illustrated.md` **模式匹配**（不是字面量 `article.illustrated.md`——上游并不保证文件名是 `article`）；恰好一个匹配就默认用它，并告知用户选了哪一份、不带图的原文叫什么；匹配到多个时把候选列给用户，问清楚要哪一份，不擅自挑。用户显式给了路径则以用户给的为准。每次都问会退化成 §3.2 明确反对的多轮问答；静默改默认又会让用户不知道自己转的是哪一份——两者都不要。
- **`cover` 并行**：封面不进正文，只在 draft 阶段作为 `--cover` 使用。
- **`diagram` 视用途而定**：若示意图要插进正文，它的产物必须在 `md2publish-article` 之前被引用进 Markdown（插入动作由用户或 `visuals` 完成，机制见 §7 diagram 步骤 7 的独立回写门）；若只是单独导出一张图，它与流水线无耦合。

## 9. 副作用、确认边界与成本控制

现有 `skills/README.md` 中「配图零副作用」的承诺在本次重构后不再成立，两处都不成立：

| | 原来 | 现在 |
|---|---|---|
| 生成 | `--plan` 只吐 prompt，零调用 | 真调 provider，**真花钱**，且不可逆 |
| 产物 | 只写新文件 | `visuals` 要**回写 Markdown**（另存，不改原文） |

原设计把"唯一的外部副作用集中在 draft skill"当作核心卖点，这个格局被打破。重新划的边界：

- **花钱的门**：批量生成前必须报「将生成 N 张 / 预估 ¥X / provider / model」，确认后执行。单张不问——用户主动要封面就是要了。
- **改源文件的门**：回写 Markdown 前展示插入位置和 diff，确认后执行；且**默认另存 `article.illustrated.md`**，与 `wechat-finetune`「原文不动，另存」的既有做法一致。

于是 `md2publish-draft` 仍然是唯一有**外部系统**副作用（写微信素材库 / 草稿箱）的 skill；images 侧的副作用是**本地文件 + API 消费**，性质不同、门也不同。

**成本控制不能只有一道确认提示**，还需要：

- `_shared/costs.yaml` 存 provider × model 的单张估价，允许 `unknown`；成本门据此给出金额，取不到就明说"该 provider 无价目表"。
- `max_images_per_run` 硬上限（配置文件），超过直接拒绝而不是提示。
- **重试上限按"计费尝试总数"计，不按"重试次数"计**。一次超时的图片 API 调用可能已经计费，§10 里的网络类退避重试若按次数算，一张图可能被扣三次。默认单张最多 2 次计费尝试。

## 10. 失败处理

生图的失败模式与 CLI 转换不同——不是"命令错了"，而是"钱花了但结果不对"。按能否重试分类：

| 类别 | 典型 | 处理 | 直接重试 |
|---|---|---|---|
| 配置类 | 认证失败、模型名不存在 | 回步骤 5 改配置 | 是（重试免费） |
| 配额类 | 余额不足、限流 | 报告并停，**不自动重试** | 否 |
| 审核类 | 内容策略拒绝 | 定位 prompt 中的触发词，给具体改写建议，不是笼统"换个说法" | 改后重试 |
| 网络类 | 超时、连接中断 | 退避重试，**受 §9 的计费尝试上限约束** | 可能已计费 |
| 质量类 | 生成了但不满意 | 改 `prompts/NN.md` 重跑那一张，同样计入计费尝试上限 | 计费 |

批量场景两条规则：

- **部分失败不整体回滚。** 10 张成功 7 张就保留那 7 张，报告失败的 3 张，允许只重跑失败的。已经花掉的钱不能因为一个失败被丢弃。
- **成本护栏前置。** 见 §9。

## 11. 前置依赖

本仓库现有 skill 全是 Python + bash，而 `imagegen/` 是 TypeScript，这是一条新引入的运行时依赖，必须显式声明——`skills/README.md:44` 已确立"前置 + 验证命令"的写法，照办：

```bash
# TypeScript 运行时（imagegen 需要，diagram 不需要）
bun --version          # 或 npx -y bun --version
# 压缩工具链，三者有其一即可
sips --version || cwebp -version || convert --version
```

`preflight.py`（步骤 1）把三项检查合在一起报告：TS 运行时、provider 配置、压缩工具。它只报告不阻塞——provider 缺失在步骤 5 才拦，压缩工具缺失在步骤 7 才拦，运行时缺失在步骤 6 才拦。这样用户能一次看全所有缺口，而不是修一个撞一个。

## 12. 对现有 skill 的改动清单

拆除 `md2publish-images` 会留下**十一处**悬空引用（不是四处、也不是七处——`wechat-finetune` 和 `handoff.md` 容易被漏，最后两行是二期 A 新建的文件，写这份 spec 时还不存在）。**下表是唯一的清单，正文里的任何数字都以它的行数为准**：

| 文件 | 位置 | 改动 |
|---|---|---|
| `md2publish-article/SKILL.md` | `:15` 边界节 | 「封面图/信息图 → md2publish-images」拆成 cover / visuals / diagram 三个去向 |
| `md2publish-article/SKILL.md` | `:85` 步骤 8 交接 | 同上 |
| `md2publish-draft/SKILL.md` | `:33` 封面来源 | 「md2publish-images 产物」→「`md2publish-cover` 产物，**取自 sidecar `assets/<platform>/00-cover.json` 的 `image` 字段（最终产物的文件名，在 sidecar 所在目录下解析，见 §5.3）**」。绝不许硬编 `00-cover.png`：压缩是新增不是替换，超限时 `.png` 与 `.jpg` 并存 |
| `wechat-finetune/SKILL.md` | `:22` 完整链路 | 链路图加入 visuals 的上游位置 |
| `wechat-finetune/SKILL.md` | `:124` 下一步询问 | 「要配图走 md2publish-images」→ 按 §3.2 路由表分流 |
| `docs/handoff/handoff.md` | `:43` `:46` `:520` | skill 清单、完整链路、"从未实测"备注三处 |
| `skills/README.md` | `:19` 工作流图 | 按 §8 重画——visuals 串在 article 上游，cover 并行 |
| `skills/README.md` | `:39` skill 表格 | 三行替一行，副作用列不再是「无」 |
| `skills/README.md` | `:51-55` 设计要点 | 「免费路径」按 §2 改口径；「确认边界」按 §9 重述 |
| `skills/md2publish-cover/SKILL.md` | 职责边界节末尾 | 删掉「不要去改 `md2publish-images`（那是旧路径，二期 B 才处理）」——旧路径已不存在 |
| `skills/_shared/README.md` | 「还没做的事」列表 | 删掉「`md2publish-images` 的删除与九处引用修改属二期 B」这一项——已完成 |

另有**两处不是悬空引用、但必须同步改**的地方（否则 §8 的次序不成立）：（其中第一行**属三期**：`article.illustrated.md` 由三期的 `md2publish-visuals` 产出，二期 B 若把它写进输入表，等于让 SKILL.md 指示 agent 去找一个当前任何流程都不会产生的文件。第二行属二期 B。）

| 文件 | 位置 | 改动 |
|---|---|---|
| `md2publish-article/SKILL.md` | 步骤 1 输入表 | 加一行：存在 `article.illustrated.md` 时优先于 `article.wechat.md` |
| `md2publish-article/SKILL.md` | 步骤 8 交接 | 补 cover / diagram 的去向，并说明 visuals 应在本 skill **之前**执行 |

## 13. 验证

沿用 `md2publish-article/scripts/test-*.sh` 的既有写法（`test-audit-themes.sh`、`test-md2html.sh`、`test-census-themes.sh`）。五项必须自动化：

1. **平台 × archetype × preset 矩阵**：每个组合要么产出非空 prompt，要么因 `unsupported` 明确失败。断言平台字段真的注入了（画幅、`text_on_image` 策略出现在结果里）。用 fixture brief 跑，不需要模型。这是最容易静默漂移的地方——preset 加了占位符但 composer 不认，出来的图就少一半约束，而且肉眼看不出来。
2. **占位符白名单**：模板里出现集合外占位符时 `compose-prompt.py` 必须硬失败，不能原样输出。
3. **preset schema 校验**：必填字段齐全（含 `primary_use_case`）、引用的 `dimensions/*` 文件存在、`incompatible_platforms` 里的平台 profile 存在。对标 md2wechat `CLAUDE.md`：「漏了主用途、默认比例、来源字段，测试应直接拦住」。
4. **压缩后不超限**：给定 `max_bytes`（整数字节），压完必须真的小于它。
5. **shared 漂移检查**：`check-shared-drift.sh` 比 hash。

**执行入口**：本仓库目前**没有 CI、没有 git hooks、没有 `.github/`**，现有测试全靠手跑。因此不能写"进 quality gate"这种没有着落的话。落地方式是新增 `scripts/check.sh` 串起以上五项，并在 `skills/README.md` 写明"改 `_shared/` 或任一 skill 后必须跑一次"。是否再加 pre-commit hook 由实施时决定；在加之前，这是**有文档约束的手工流程**，不是自动闸门——这一点必须诚实写在 README 里，不要让人误以为有强制。

**`check.sh` 后来又长大了两次，现在是 12 项，不再是 5 项。** 二期加了 preflight + config 自检、产物落盘规则（sidecar / 重跑保护）、imagegen 引擎测试（`bun test`）、vendor 同步与漂移，把上面五项之外的机械层测试也串了进来；三期又加了三项：Markdown 回写门（`test-writeback.sh`）、SVG→位图降级链（`test-svg2raster.sh`）、diagram 端到端（`test-diagram-e2e.sh`，见下）。当前项数与顺序以 `scripts/check.sh` 自身的 `run` 调用清单为准，不在本文重复罗列——重复只会在下次改动时再漂移一次。

**三态，不是二态。** `check.sh` 的 `run()` 除了 ✓ / ✗，还会打印 `⊘ SKIPPED`（被跑的脚本退出码为 2 时触发）：diagram 端到端依赖机器上装有 `rsvg-convert` / `magick` / Chrome 中至少一个，三者都缺时脚本如实报 SKIPPED，而不是把只想改主题库、机器上没装光栅化工具的人也硬拦在门外。**SKIPPED 不算通过**——`check.sh` 末尾口径显式区分「全部通过。」与「全部通过（N 项跳过：……）。」，后者紧跟一句「跳过的项没有跑过，不等于通过」，防止摘要含糊成假绿。

两项不进自动化、手动跑：**真调一次 provider 生一张图的最小 smoke**，`cover` 与 `visuals` 各欠一次，都计费。`diagram` 是唯一例外——它零成本，端到端**已经进了自动化**（即上面三态里的 diagram 端到端一项），不算在这两项手动挂账里；说端到端验证情况时必须分清是哪一条链，不要把三者混为一谈。

## 14. 不在本次范围（Known Limitations）

1. **`md2publish-draft` 仍是微信专用。** `doctor` / `upload_image` / `create_draft` 与 `WECHAT_APPID` / `WECHAT_SECRET` 全是微信专属。多平台真正落地时它要分化成 `-draft-wechat` / `-draft-xhs` / `-draft-bilibili`，那是独立的一轮。本次只保证 `_shared/platforms/` 的 schema 能承载它们，不动 draft 本身。
2. **`md2publish-article` 未多平台化。** `references/wechat-html.md` 的五条铁律是微信编辑器专属。本次**不**在 platform profile 里预留 `html_constraints` 字段——它会是一条指向别的 skill 目录的路径，vendor 之后就成了跨 skill 引用，正好破坏 §4.2 的自包含论证。等 article 真要多平台化时，再决定它是路径还是一个由消费方自行解析的不透明标识符。
3. **`md2publish-diagram` 的 SVG 需要转位图。** 微信不接受 SVG，因此输出 SVG + PNG 双产物，Markdown 引 PNG。转换降级链：`rsvg-convert` → `magick`（**仅当探测到 RSVG delegate 时才计入，见下**）→ headless Chrome（`--screenshot`）；三者都不可用时保留 SVG 并告知用户需自行转换，不静默失败。SVG 必须声明完整字体 fallback 链（`"PingFang SC", "Noto Sans CJK SC", "Microsoft YaHei", sans-serif`）——只写"用系统安全字体"不够，macOS 与 Linux 的 CJK 默认字体不同，正是这个约束要防的渲染分歧。

   **`magick` 这一级不是无条件可用的渲染器，前面加了能力闸。** 没有编译进 RSVG delegate 的 ImageMagick 渲染带中文的 SVG 时会 **exit 0 却把图上所有文字丢光**，只剩图形——本机实测出的真实故障模式，退出码看不出任何异常，比硬失败凶险得多，因为它要到发布之后才会被发现。因此 `svg2raster.py` 在把 `magick` 计入降级链之前，先用 `magick -list format` 探测输出里 SVG 那一行的描述中是否有 `RSVG` 字样；探测不到证据时，`magick` 既不进自动降级链，用户显式传 `--backend magick` 也照样硬失败并给出安装建议（`brew install librsvg`）。**不要把这条链读成"三级都会依次尝试"**——第二级能不能用，取决于一个必须运行时探测的编译期 delegate，不是默认可用的渲染器。

   **画幅由本脚本强制校验，不止是文档里写"应当匹配"。** `--aspect` 与 SVG `viewBox` 算出的比例相差超过 1% 时，`svg2raster.py` 直接硬失败，提示去改 SVG 而不是改 `--aspect`。这是 `diagram` 唯一能机械验证"平台画幅真被用上"的地方——它不经过 `compose-prompt.py`，没有 §13 矩阵测试那样的覆盖；少了这道校验，agent 画一个正方形却声称是 16:9，位图会被拉伸变形，而这件事在缩略图上肉眼看不出来。
4. **未纳入的 baoyu 能力**：知识漫画（`baoyu-comic`）、幻灯片（`baoyu-slide-deck`）——独立内容形态，不属于文章发布流水线。
5. **`bilibili.yaml` 已落地（2026-08-19），但只建模了专栏，且数字未经官方核实。** 本条原来的判断成立——B 站视频封面与专栏头图规格不同，而每个平台只有一个 `cover` 槽，两者装不下。用户裁定按**专栏**建模（本仓库是文章发布线），`cover` 取 3:2 中心裁切；**视频封面（1146×717，≈16:10，≤5MB）仍未建模**，要支持须往 `ARCHETYPES` 加新 archetype，届时每个平台都得补槽定义，且矩阵测试组合数会再涨一轮。画幅来源是第三方教程与 B 站用户专栏、非官方文档，每个未核实的槽在 yaml 里标了 `unverified`。

## 15. 实施分期

本设计的工作量超出单个实施计划的合适规模，拆四期，每期各自可验证、可交付：

| 期 | 内容 | 完成判据 | 破坏性 |
|---|---|---|---|
| 一 | `_shared/` 骨架（三个 platform profile + preset schema + dimensions 词表 + INDEX.md）、`compose-prompt.py`、§13 第 1–3 项测试（用 fixture brief） | 矩阵 / 白名单 / schema 三项测试通过 | 无 |
| 二 A | 搬入 `imagegen/` `compress.py` `preflight.py`，建 `md2publish-cover`，加 `sync-shared.sh` / `check-shared-drift.sh` / `check.sh`（此时才有消费者）。**`md2publish-images` 原地保留** | 端到端产出一张微信封面并压到 2MB 内；手动 smoke 通过；§13 五项全绿 | 无（纯新增，两者并存） |
| 二 B | 删除 `md2publish-images`，改 §12 的十一处引用 | **范围版**判据：`skills/` 与 `docs/handoff/handoff.md` 里没有活引用（`docs/superpowers/specs/`、`docs/superpowers/plans/`、`docs/handoff/handoff-image.md`、`.superpowers/` 下的提及是故意保留的执行记录，完整版见 `docs/handoff/handoff-image.md` 第六节） | **有**。回滚 = `git checkout 6b4cea6^ -- skills/md2publish-images/`，**不是** `git revert`：删除被并发会话一次不带 pathspec 的 `git commit` 卷进了 `6b4cea6`，而那个 commit 还装着另一条线的计划文件，revert 会连它一起删 |
| 三 | `md2publish-visuals`（含 Markdown 回写门与 §8 的次序改动）、`md2publish-diagram`（含 SVG→PNG 降级链） | **三分版**判据，三条不能互相代替：自动化——`check.sh` 12 项全绿（矩阵 / 白名单 / schema / 压缩 / preflight+config / 产物落盘规则 / Markdown 回写门 / SVG→位图降级链 / imagegen / diagram 端到端 / shared 漂移 / vendor 同步与漂移），已验证；本机零成本端到端——`diagram` 链路（写 SVG → 光栅化 → 压缩 → 写 sidecar）真跑通，压缩产物真正串进了 sidecar 的 `image` 字段，`test-diagram-e2e.sh` 覆盖，已验证；手动付费挂账——真调 provider 的最小 smoke，`cover`（二期）与 `visuals`（本期）各欠一次，本机无 provider 凭证，**均未跑**。三者不可混为一谈，完整口径见 `docs/handoff/handoff-image.md` 第六节 | 改 `md2publish-article` 输入表，回滚 = `git revert` 那一个 commit（本期照 Global Constraints 用显式路径逐任务提交，未与另一条线的文件同 commit） |

一期不动任何现有 skill，也不写 sync/drift 脚本——那时它们没有消费者，只能对着想象中的目录结构写，二期必然重写。

二期拆成 A / B 是本版新增的：原方案把"建 cover"和"删 images"放在同一期，一旦封面生成不可用，仓库会处在既没有新能力、引用又已经指向不存在的 skill 的状态。拆开后 A 是纯新增，B 的破坏性收窄到"删一个 skill 目录"这一件事。B 实际并没有跑成单 commit（是逐任务多个 commit），删除本身还落进了并发会话的 `6b4cea6`，所以回滚按上表那条 `git checkout` 走，别用 `git revert`。

## 16. 修订记录

第二版（2026-08-09）按事实核查与架构复审修订，主要变更：

**事实更正**：§12 悬空引用从四处更正为九处（漏了 `wechat-finetune/SKILL.md:22` `:124` 与 `docs/handoff/handoff.md:43` `:46` `:520`）；`md2publish-article/SKILL.md:16` → `:15`；`skills/README.md:51-56` → `:51-55`；§4.2 中 `zip` 的符号链接默认行为写反了（默认跟随，非保留）；§1 "完全依赖 `--plan`" 改为"以 `--plan` 为主路径"（另有直连路径）；§5.2 补 `primary_use_case` 必填字段；§4.1 补 `codex-cli` 是经 wrapper 间接 spawn。

**结构性修订**：新增 §6（机械层 / 语义层分界）、§8（流水线次序，`visuals` 在 `article` 上游）、§11（TS 运行时前置）；§5.1 platform profile 改为按 archetype 分槽并补 `infographic` / `diagram` 槽，`text_on_image` 由枚举改为结构，`max_bytes` 改整数；§7 凭证门从流程开头移到生成那一步，新增产物布局与重跑跳过规则；§7.2 多平台限定于 cover / diagram；§5.2 `compatible_platforms` 改为 `incompatible_platforms`，补占位符白名单与维度覆盖机制；§5.3 新增产物 sidecar；§9 补成本表与计费尝试上限；§13 把"进 quality gate"落到具体的 `scripts/check.sh` 并诚实说明无自动闸门，§4.3 补漂移恢复程序；§15 二期拆为 A / B；§14 移除 `html_constraints` 预留字段。

第三版（2026-08-11，二期 B 开工前）：§12 悬空引用**从九处更正为十一处**——正文原写"七处"、表格 9 行、§16 原写"从四处更正为九处"，三个数字互相矛盾，现统一以表格为准，并补上二期 A 新建的 `skills/md2publish-cover/SKILL.md` 与 `skills/_shared/README.md` 两处；§12 表格中 `md2publish-draft` 一格由硬编 `00-cover.png` 改为读 sidecar 的 `image` 字段（压缩是新增不是替换，`.png` 与 `.jpg` 并存）；§5.3 sidecar schema 补 `image` 字段——原 schema 里没有这个字段，而 §12 与 `md2publish-cover/SKILL.md` 都已经在断言"下游该消费哪个文件，读 sidecar 就知道"。

第四版（2026-08-11，三期收尾）：三期实施计划（`docs/superpowers/plans/2026-08-11-image-phase3.md`）记录了七条与本 spec 的偏离（D11–D17），本版把它们全部折回正文，spec 恢复为唯一真相源：

- **D11**（§5.3 sidecar schema 假定每张图都有 `preset` / `provider` / `prompt_file` / `brief_file`）：补 `diagram` 支路——`preset` / `preset_version` / `model` / `prompt_file` / `brief_file` 一律记 `null`，新增 `source_file` 字段（SVG 文件名），`provider` 的语义随 archetype 改变，对 `diagram` 是光栅化后端名。
- **D12**（§6 假定三个 skill 共用同一条链路，步骤 4 一律「渲染 prompt」）：补一段——`diagram` 的语义层产物是 SVG 本身，不经过 `compose-prompt.py`。
- **D13**（§14.3 原文没有画幅的机械校验点）：补 `svg2raster.py` 强制画幅校验——`--aspect` 与 `viewBox` 比例相差超过 1% 直接硬失败。
- **D14**（§13 原写"五项必须自动化""一项不进自动化"）：补 `check.sh` 从 5 项长大到 12 项的沿革、SKIPPED 第三态的语义、"一项"改为"两项"手动付费挂账（`cover` 与 `visuals` 各一次），并明说 `diagram` 端到端已进自动化，不算在这两项里。
- **D15**（§8 只写"必须认 `article.illustrated.md`"，没给默认规则）：§8 补默认规则——同目录存在 `article.illustrated.md` 时默认用它，并告知用户选了哪一份、不带图的原文叫什么；用户显式给了路径则以用户给的为准。每次都问会退化成 §3.2 反对的多轮问答，静默改默认又会让用户不知道自己转的是哪一份。
- **D16**（§3.1 / §7.2 未说明 `series` 是否回写）：§7 新增 `visuals` 的步骤 9（回写门）与 `diagram` 的独立七步链路；§7.2 补一句——`series` 不回写 Markdown，卡片系列是内容本身、不进正文，处理到写完 sidecar 就结束。
- **D17**（§14.3 原写降级链 `rsvg-convert → magick → headless Chrome` 三级都是可用渲染器）：补 `magick` 的能力闸——`magick -list format` 探测不到 RSVG delegate 证据时，`magick` 既不进自动降级链，显式指定也硬失败。原因是本机实测：没有 RSVG delegate 的 `magick` 渲染带中文的 SVG 会 exit 0 却把图上所有文字丢光，只剩图形，比硬失败更危险——它要到发布之后才会被发现。

另有 §15 三期那一行的完成判据改为三分版（自动化 / 本机零成本端到端 / 手动付费挂账），并补上破坏性一栏的回滚方式（改 `md2publish-article` 输入表，回滚 = `git revert` 那一个 commit）。

## 17. 参考

- `baoyu-skills/skills/baoyu-image-gen/` — provider 引擎来源
- `baoyu-skills/skills/baoyu-cover-image/`、`baoyu-article-illustrator/`、`baoyu-infographic/`、`baoyu-xhs-images/`、`baoyu-diagram/` — 风格维度与工作流参考
- `md2wechat-skill/internal/assets/builtin/prompts/image/` — 25 个成品 preset YAML（11 cover + 14 infographic），preset schema 字段要求参考
- `md2publish-skills/skills/md2publish-article/` — 本地资产 + INDEX.md 发现模式、机械层 / 语义层分界的既有实现
