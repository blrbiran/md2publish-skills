---
name: md2publish-cover
description: 为文章生成封面图，支持微信公众号与小红书两种画幅。当用户说"生成封面"、"封面图"、"文章头图"、"小红书首图"，或在发布工作流里需要封面素材时使用。步骤 1–4 零成本零副作用（产出 prompt 文件），步骤 5 起才调 provider、才花钱。
allowed-tools: Read, Write, Bash, AskUserQuestion
---

# md2publish-cover：封面图

一篇文章一张封面。**同一个视觉概念可以一次出两个平台的画幅**（`--platform wechat,xiaohongshu`），
但那是两次渲染、两次生成、两次成本确认。

本 skill 的资产（平台 profile、preset、维度词表、脚本、生图引擎）全在 `shared/` 下，
是从 `skills/_shared/` vendor 来的副本。**不要改 `shared/` 里的任何文件**——
改了会被 `scripts/check-shared-drift.sh` 拦住，正确做法是改 `skills/_shared/`
再跑 `scripts/sync-shared.sh`。

## 职责边界

| 这件事 | 归谁 |
|---|---|
| 正文里的插图（3–8 张）、小红书图卡系列 | `md2publish-visuals`（三期，尚未实现） |
| 架构图 / 流程图 / 示意图 | `md2publish-diagram`（三期，尚未实现） |
| 把图传进微信素材库、建草稿 | `md2publish-draft` |
| 封面 | 本 skill |

三期之前，用户要插图或示意图时**如实说这两个 skill 还没建**，
不要用封面流程凑合，也不要去改 `md2publish-images`（那是旧路径，二期 B 才处理）。

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

当前支持 `wechat` 与 `xiaohongshu`。要两个都出就写 `wechat,xiaohongshu`，
但**每个平台各走一遍步骤 3–8，成本各确认各的**，不许一次确认覆盖两个平台的花费。

### 步骤 3：选 preset（零成本）

读 `shared/presets/INDEX.md`，按文章调性挑一个 `archetype: cover` 的 preset。
**不要背 preset 名单**——资产会持续增补，每次都回去读那份索引。

用户提风格偏好（"换暖色"、"别那么花"）时**不换整个 preset**，
从 INDEX.md 的维度表里找最接近的值，用 `--palette` / `--rendering` 覆盖那一维。

### 步骤 4：写 brief 并渲染 prompt（零成本，到此为止零副作用）

**4a 语义层**：你写 `briefs/<platform>/00-cover.md`。四行，中文，不要写画幅和配色
（那些由平台和 preset 决定，写进来只会打架）：

```
主题：<这张图要表达文章的什么>
主体：<画面里具体有什么>
情绪：<什么调性>
alt：<给读者的替代文本，一句话>
```

**4b 机械层**：

```bash
python3 shared/scripts/compose_prompt.py \
  --platform <platform> --preset <preset> \
  --brief-file briefs/<platform>/00-cover.md \
  --out prompts/<platform>/00-cover.md \
  [--palette <value>] [--rendering <value>]
```

平台不支持该组合时它直接失败并说明原因，不静默回退。

**到这里为止零成本、零副作用。** 没配 provider 的用户就在这里收工——
把 `prompts/<platform>/00-cover.md` 交给他，拿去即梦 / Midjourney / DALL·E 自己生，
生成后把文件放到 `assets/<platform>/00-cover.png` 再跳到步骤 7。

### ═══ 以下开始计费 ═══

### 步骤 5：凭证门 + 成本门

**凭证门**：步骤 1 报告 provider 一个都没配置 → **报告 prompt 文件路径并停止**。
不要引导用户为此现配 API key，把选择权交给他。

**成本门**：封面是单张，**不问**——用户主动要封面就是要了（spec §9）。
但要把用什么 provider / 什么 model 说出来。价目查询：

```bash
python3 -c "import sys; sys.path.insert(0,'shared/scripts'); import asset_lib as a; print(a.estimate_cost('<provider>', '<model>'))"
```

返回 `None` 就明说"该 provider 无价目表"，**不要编一个数字**。

### 步骤 6：生成

先过重跑保护：

```bash
python3 shared/scripts/artifacts.py guard --path assets/<platform>/00-cover.png
```

它非零退出就是文件已存在——**报告并停下问用户**，别自己加 `--force`。
`briefs/` 和 `prompts/` 是复现记录，不是临时文件，一并保留。

取画幅（别硬编 16:9，小红书是 3:4）：

```bash
ASPECT=$(python3 -c "import sys; sys.path.insert(0,'shared/scripts'); import asset_lib as a; p=a.load_platform('<platform>'); print(a.archetype_slot(p,'cover')['aspect'])")
```

生成：

```bash
bun shared/scripts/imagegen/main.ts \
  --promptfiles prompts/<platform>/00-cover.md \
  --image assets/<platform>/00-cover.png \
  --ar "$ASPECT" \
  [--provider <p>] [--model <m>]
```

成功时 stdout 是产物绝对路径，日志走 stderr。

**单张最多 2 次计费尝试**（引擎里已经压到 2）。生成了但不满意属于"质量类"失败：
改 `prompts/<platform>/00-cover.md` 重跑那一张，**同样计入计费尝试**——
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
python3 shared/scripts/compress.py --image assets/<platform>/00-cover.png --max-bytes "$MAXB"
```

stdout 是最终产物路径——**可能不是你传进去的那个**（需要压缩时会产出同名 `.jpg`）。
后面的步骤一律用它打印的路径。压不下去时它硬失败，别自己降低上限绕过去。

### 步骤 8：写 sidecar 并交接

```bash
python3 shared/scripts/artifacts.py sidecar \
  --image <步骤 7 打印的路径> \
  --platform <platform> --archetype cover --preset <preset> \
  --provider <provider> --model <model> \
  --prompt-file prompts/<platform>/00-cover.md \
  --brief-file briefs/<platform>/00-cover.md \
  --alt-text "<brief 里那句 alt>" \
  [--override palette=<value>]
```

交接话术：

- 告诉用户最终文件路径，以及**它是否被压缩过、压成了什么格式**。
- 微信：提醒头条按 2.35:1 裁、次条按 1:1 裁，重要视觉元素要在画面中央。
  推草稿箱时 `md2publish-draft` 会拿它当 `--cover`。
- 小红书：本仓库**还没有**小红书的发布 skill，产物需要用户自己上传。如实说，别暗示能自动发。
- 封面**不进正文**，不要往 Markdown 里插 `![]()`。

## 产物布局

```
<article-dir>/
├─ briefs/<platform>/00-cover.md      ← 你写的语义 brief
├─ prompts/<platform>/00-cover.md     ← 渲染后的 prompt（复现记录，别删）
└─ assets/<platform>/00-cover.png     ← 产物（压缩过则是 .jpg）
   assets/<platform>/00-cover.json    ← sidecar
```

按平台分目录，所以 `wechat,xiaohongshu` 两张封面不会同名相撞。

## 前置

```bash
bun --version                                  # 或 npx -y bun --version
sips --version || magick --version             # 二者有其一
python3 -c 'import yaml'
```

生成图片需要至少一个 provider 的 API key（环境变量，见 `shared/scripts/preflight.py`
的 `PROVIDER_ENV`）。**没有也能用**——步骤 1–4 照跑，交付 prompt 文件。
