---
name: md2publish-cover
description: 为文章生成封面图，支持微信公众号、小红书、B 站专栏三种画幅。当用户说"生成封面"、"封面图"、"文章头图"、"小红书首图"，或在发布工作流里需要封面素材时使用。步骤 1–4 零成本零副作用（产出 prompt 文件），步骤 5 起才调 provider、才花钱。
allowed-tools: Read, Write, Bash, AskUserQuestion
---

# md2publish-cover：封面图

一篇文章一张封面。**同一个视觉概念可以一次出多个平台的画幅**（`--platform` 写成逗号分隔，
如 `wechat,xiaohongshu,bilibili`），但那是各渲染一次、各生成一次、各确认一次成本。

本 skill 的资产（平台 profile、preset、维度词表、脚本、生图引擎）全在 `shared/` 下，
是从 `skills/_shared/` vendor 来的副本。**不要改 `shared/` 里的任何文件**——
改了会被 `scripts/check-shared-drift.sh` 拦住，正确做法是改 `skills/_shared/`
再跑 `scripts/sync-shared.sh`。

## 工作目录与路径约定（先读这段，否则每条命令都会跑错地方）

本文里的两类路径**基准不同**，混用必错：

- **脚本路径**（`shared/scripts/...`）相对**本 skill 目录**；
- **产物路径**（brief / prompt / 图 / sidecar）一律用**文章目录的绝对路径**。

所以约定是固定的一条：**在本 skill 目录里执行命令，把产物写到文章目录的绝对路径下。**
开工先把这两个变量定下来，后面每条命令都直接用它们：

```bash
cd <本 skill 目录的绝对路径>        # 例如 .../skills/md2publish-cover
ART=<文章目录的绝对路径>            # 例如 /Users/me/posts/2026-08-10-cache-invalidation
mkdir -p "$ART/briefs" "$ART/prompts" "$ART/assets"
```

`ART` 取文章 Markdown 所在的那个目录。**绝不要用相对路径写产物**——那会把 brief、
prompt、图和 sidecar 全部落在 skill 目录里：脱离了文章，还脏了本仓库的工作区。

## 职责边界

| 这件事 | 归谁 |
|---|---|
| 正文里的插图（3–8 张）、小红书图卡系列 | `md2publish-visuals` |
| 架构图 / 流程图 / 示意图 | `md2publish-diagram` |
| 把图传进微信素材库、建草稿 | `md2publish-draft` |
| 封面 | 本 skill |

用户要插图或示意图时交接给对应的 skill，不要用封面流程凑合。
封面只有本 skill 这一个入口。

## 机械层与语义层

你负责**语义**：这张封面要表达什么、主体是什么、alt 文本怎么写、选哪个 preset。
脚本负责**机械**：填画幅、填文字策略、拼模板、压字节、写元数据。

`compose_prompt.py` 不读文章原文、不调模型。文章的语义部分由你写成 **brief 文件**传进去。

## 执行流程

### 步骤 1：preflight（零成本）

```bash
python3 shared/scripts/preflight.py
```

它报告三件事：TS 运行时、provider 凭证、压缩工具链。**只报告不阻塞**——
缺 provider 也照样往下走，步骤 5 才拦。把缺口一次性讲给用户，别修一个撞一个。

### 步骤 2：确定平台

按这个顺序取，取到就停：

1. 用户明说（"发小红书"）
2. 文章 frontmatter 的 `platform:`
3. `~/.config/md2publish/images.yaml` 的 `default_platform`
4. 都没有 → 问用户

当前支持 `wechat` / `xiaohongshu` / `bilibili`（B 站专栏，画幅数字未经官方核实，见 `shared/platforms/bilibili.yaml` 顶部）。要多个都出就写成逗号分隔，
但**每个平台各走一遍步骤 3–8，成本各确认各的**，不许一次确认覆盖多个平台的花费。

### 步骤 3：选 preset（零成本）

读 `shared/presets/INDEX.md`，按文章调性挑一个 `archetype: cover` 的 preset。
**不要背 preset 名单**——资产会持续增补，每次都回去读那份索引。

用户提风格偏好（"换暖色"、"别那么花"）时**不换整个 preset**，
从 INDEX.md 的维度表里找最接近的值，用 `--palette` / `--rendering` 覆盖那一维。

### 步骤 4：写 brief 并渲染 prompt（零成本，到此为止零副作用）

**4a 语义层**：你写 `$ART/briefs/<platform>/00-cover.md`。四行，中文，不要写画幅和配色
（那些由平台和 preset 决定，写进来只会打架）：

```
主题：<这张图要表达文章的什么>
主体：<画面里具体有什么>
情绪：<什么调性>
alt：<给读者的替代文本，一句话>
```

**4b 机械层**：

```bash
mkdir -p "$ART/briefs/<platform>" "$ART/prompts/<platform>" "$ART/assets/<platform>"
python3 shared/scripts/compose_prompt.py \
  --platform <platform> --preset <preset> \
  --brief-file "$ART/briefs/<platform>/00-cover.md" \
  --out "$ART/prompts/<platform>/00-cover.md" \
  [--palette <value>] [--rendering <value>]
```

平台不支持该组合时它直接失败并说明原因，不静默回退。

**到这里为止零成本、零副作用。** 没配 provider 的用户就在这里收工——
把 `$ART/prompts/<platform>/00-cover.md` 交给他，拿去即梦 / Midjourney / DALL·E 自己生，
生成后把文件放到 `$ART/assets/<platform>/00-cover.png` 再跳到步骤 7
（此时步骤 8 的 `--provider` / `--model` 照实写成他用的那个工具，别填本仓库的 provider 名）。

### ═══ 以下开始计费 ═══

### 步骤 5：凭证门 + 成本门

**凭证门**：步骤 1 报告 provider 一个都没配置 → **报告 prompt 文件路径并停止**。
不要引导用户为此现配 API key，把选择权交给他。

**成本门**：封面是单张，**不问**——用户主动要封面就是要了（spec §9）。
但要把**预计**用什么 provider / 什么 model 说出来。注意这里只是预告：
省略 `--provider` / `--model` 时，引擎会先看 baoyu `EXTEND.md` 的默认值、再退到
"第一个存在的 env key"，实际用的未必是你这里说的那个。**真相以步骤 6 的
`--json` 输出为准**，sidecar 只能填那份输出里的值。价目查询：

```bash
python3 -c "import sys; sys.path.insert(0,'shared/scripts'); import asset_lib as a; print(a.estimate_cost('<provider>', '<model>'))"
```

返回 `None` 就明说"该 provider 无价目表"，**不要编一个数字**。

### 步骤 6：生成

先过重跑保护：

```bash
python3 shared/scripts/artifacts.py guard --path "$ART/assets/<platform>/00-cover.png"
```

它非零退出就是文件已存在——**报告并停下问用户**，别自己加 `--force`。
`$ART/briefs/` 和 `$ART/prompts/` 是复现记录，不是临时文件，一并保留。

取画幅（别硬编 16:9，小红书是 3:4）：

```bash
ASPECT=$(python3 -c "import sys; sys.path.insert(0,'shared/scripts'); import asset_lib as a; p=a.load_platform('<platform>'); print(a.archetype_slot(p,'cover')['aspect'])")
```

生成。**必须带 `--json`**：不带的话 stdout 只有一个路径，你永远不知道引擎最后
挑了哪个 provider / model，步骤 8 的 sidecar 就只能靠猜——而猜错的 sidecar 比没有
更坏，spec §5.3 要它就是为了事后能追溯是谁生的这张图。

```bash
GEN=$(bun shared/scripts/imagegen/main.ts \
  --promptfiles "$ART/prompts/<platform>/00-cover.md" \
  --image "$ART/assets/<platform>/00-cover.png" \
  --ar "$ASPECT" --json \
  [--provider <p>] [--model <m>])

RAW=$(python3      -c 'import json,sys; print(json.load(sys.stdin)["savedImage"])' <<<"$GEN")
PROVIDER=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["provider"])'   <<<"$GEN")
MODEL=$(python3    -c 'import json,sys; print(json.load(sys.stdin)["model"])'      <<<"$GEN")
```

`--json` 下 stdout 是一个 JSON 对象（`savedImage` / `provider` / `model` / `attempts`），
日志仍走 stderr。产物路径取 `savedImage`，**不要**再把 stdout 整个当路径用。
`${PROVIDER}` 与 `${MODEL}` 是引擎**实际**用的那一对，步骤 8 只准填它们，
不准填步骤 5 里你预告的那个。

**单张最多 2 次计费尝试**（引擎里已经压到 2）。生成了但不满意属于"质量类"失败：
改 `$ART/prompts/<platform>/00-cover.md` 重跑那一张，**同样计入计费尝试**——
不要连着重试三四遍，先问用户还要不要继续花钱。

失败分类处理：

| 类别 | 典型 | 怎么做 |
|---|---|---|
| 配置类 | 认证失败、模型名不存在 | 回步骤 5 改配置，重试免费 |
| 配额类 | 余额不足、限流 | 报告并停，**不自动重试** |
| 审核类 | 内容策略拒绝 | 指出 prompt 里可能的触发词，给**具体**改写建议，不要笼统说"换个说法" |
| 网络类 | 超时、连接中断 | 引擎已内建退避，超出 2 次就停 |

### 步骤 7：压缩

微信封面 2MB 是硬限制。**必须在这里压完**，等到推草稿箱才发现超限，前面全白做。

```bash
MAXB=$(python3 -c "import sys; sys.path.insert(0,'shared/scripts'); import asset_lib as a; p=a.load_platform('<platform>'); print(a.archetype_slot(p,'cover')['max_bytes'])")
FINAL=$(python3 shared/scripts/compress.py --image "$RAW" --max-bytes "$MAXB")
```

（跳过步骤 5–6 自己出图的用户，把 `RAW` 手动设成
`"$ART/assets/<platform>/00-cover.png"` 再跑这条。）

`${FINAL}` 是最终产物路径，**可能不是你传进去的那个**：需要压缩时它是同目录的
同名 `.jpg`。压不下去时脚本硬失败，别自己降低上限绕过去。

**关键：压缩不是替换，是新增。** 压完之后 `00-cover.png`（超限的原图）和
`00-cover.jpg`（压缩产物）**两个文件同时存在**，`.png` 还占着那个看起来最"正规"的名字。
从这一步起，**唯一的交接产物是 `${FINAL}`**，`.png` 只是原始底片，留着备查、不往下游传。
后面每一步（sidecar、给用户的话术、`md2publish-draft`）一律用 `${FINAL}`，
**任何地方都不许硬编 `00-cover.png`**。

### 步骤 8：写 sidecar 并交接

```bash
python3 shared/scripts/artifacts.py sidecar \
  --image "$FINAL" \
  --platform <platform> --archetype cover --preset <preset> \
  --provider "$PROVIDER" --model "$MODEL" \
  --prompt-file "$ART/prompts/<platform>/00-cover.md" \
  --brief-file "$ART/briefs/<platform>/00-cover.md" \
  --alt-text "<brief 里那句 alt>" \
  [--override palette=<value>]
```

sidecar 写在 `${FINAL}` 旁边、与它同名（`$ART/assets/<platform>/00-cover.json`），
里面记的 `image`（文件名）和 `bytes` 都是 `${FINAL}` 的。**`image` 字段就是下游该消费的
那个文件**——`.png` 和 `.jpg` 算出来是同一个 `.json`，文件名区分不了，只有这个字段能。

`--provider` / `--model` 取步骤 6 那份 JSON 里的 `provider` / `model`。
**不要**填步骤 5 的预告值——省略参数时引擎会自己回退挑一个，填错了 sidecar
就成了一份误导性的追溯记录。

交接话术：

- 告诉用户最终文件路径 `${FINAL}`，以及**它是否被压缩过、压成了什么格式**；
  同时说明未压缩的 `.png` 底片还在原地，不是残留垃圾。
- 微信：提醒头条按 2.35:1 裁、次条按 1:1 裁，重要视觉元素要在画面中央。
  推草稿箱时 `md2publish-draft` 拿 `${FINAL}`（即 sidecar `image` 字段记的那个文件名，
  在 sidecar 所在目录下解析出来的文件）当 `--cover`，
  **不是** `00-cover.png`。
- 小红书 / B 站：本仓库**只有微信一条发布链路**（`md2publish-draft`），这两个平台的产物需要用户自己上传。如实说，别暗示能自动发。
- 封面**不进正文**，不要往 Markdown 里插 `![]()`。

## 产物布局

全部落在 `$ART`（文章目录的绝对路径）下，命令都在 skill 目录里跑：

```
$ART/
├─ briefs/<platform>/00-cover.md      ← 你写的语义 brief
├─ prompts/<platform>/00-cover.md     ← 渲染后的 prompt（复现记录，别删）
└─ assets/<platform>/
   ├─ 00-cover.png                    ← 引擎的原始产物。超限时**不会被删**，留在原地当底片
   ├─ 00-cover.jpg                    ← 压缩产物。**只要它存在，交接产物就是它**
   └─ 00-cover.json                   ← sidecar，写在最终产物旁边，`image` 字段记着它的文件名
```

`.png` 和 `.jpg` 是**共存**关系，不是替换：压缩从不删原图（那是花钱生成的东西）。
未超限时就只有 `.png`，`${FINAL}` 也就等于它。判断该交哪个文件，**看 sidecar 的 `image`
字段（最终产物的文件名，在 sidecar 所在目录下解析）或步骤 7 的 `${FINAL}`，不要看谁的
名字更"正规"**。

按平台分目录，所以 `wechat,xiaohongshu` 两张封面不会同名相撞。

## 前置

```bash
bun --version                                  # 或 npx -y bun --version
sips --version || magick --version             # 二者有其一
python3 -c 'import yaml'
```

生成图片需要至少一个 provider 的 API key（清单见 `shared/scripts/preflight.py`
的 `PROVIDER_ENV`）。凭证有三个来源，优先级从高到低：进程环境变量、
`~/.baoyu-skills/.env`、`<当前目录>/.baoyu-skills/.env`——preflight 与生图引擎查的是
同一组、同一顺序。第三个来源跟着当前目录走，这也是"命令一律在 skill 目录里跑"
这条约定要守住的原因之一：换个目录跑，生效的 `.env` 就可能换了一份。

**没有凭证也能用**——步骤 1–4 照跑，交付 prompt 文件。
