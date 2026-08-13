---
name: md2publish-article
description: 用 md2wechat CLI 免费路径把 Markdown 文章转成微信公众号可用的内联样式 HTML。当用户想"转换公众号文章"、"md 转 html"、"排版公众号"、"生成微信文章 HTML"、"美化文章"，或提供一篇 Markdown 并提到微信公众号/公众号发布时使用。本 skill 只做转换和本地预览，不上传图片、不创建草稿；发草稿箱交给 md2publish-draft skill。
allowed-tools: Read, Write, Bash, AskUserQuestion
---

# md2publish-article：Markdown 转公众号 HTML（免费路径）

把 Markdown 文章转成微信公众号编辑器可直接粘贴的 HTML（免费路径）。排版指令来自本地主题库 `references/theme-prompts/`，HTML 由你（Claude）按指令生成；md2wechat CLI 只用于元数据检查（及可选的内置主题实时指令）。全程不需要 `MD2WECHAT_API_KEY`。

## 边界

- 本 skill 产物是**本地 HTML 文件**，零副作用：不联网上传、不建草稿。
- 用户要"推草稿箱 / 发布 / 上传"时，转换完成后交接给 `md2publish-draft` skill。
- 用户要封面图时，交接给 `md2publish-cover` skill。
- 用户要正文配图 / 信息图 / 卡片系列时，交接给 `md2publish-visuals`；要架构图 / 流程图时，交接给 `md2publish-diagram`。
  **配图要在本 skill 之前做完**——它回写出的 `article.illustrated.md` 才是本 skill 该转的那一份。

## 执行流程

### 步骤 1：拿到输入

| 场景 | 处理 |
|---|---|
| 同目录存在 `article.illustrated.md` | **默认用它**——那是 `md2publish-visuals` 的回写产物，正文里已经插好了配图。**要告诉用户你选了哪一份**，以及不带图的原文叫什么（通常是 `article.wechat.md`）。用户明确要不带图的版本时才改用原文 |
| 用户给了文件路径 | 直接使用（显式指定优先于上面的默认） |
| 用户粘贴了 Markdown | 先 Write 保存为 `.md` 文件再继续 |
| 只说"转换文章"没给内容 | 询问文件路径或让用户粘贴 |

`md2publish-visuals` 在本 skill 的**上游**，不是并行分支（spec §8）。它另存 `article.illustrated.md` 而不改原文，所以两份会并存；不认这个文件的话，用户花钱生成的配图会静默地永远不进 HTML。

### 步骤 2：检查元数据和限制

```bash
md2wechat inspect <article.md> --mode ai --theme <theme> --json
```

读 `data` 中解析出的标题、作者、摘要，对照微信硬限制：

- 标题 ≤ 32 字符（超出建草稿时会被拒）
- 作者 ≤ 16 字符
- 摘要 ≤ 128 字符

元数据来源优先级：frontmatter（`title` / `author` / `digest`，摘要也接受 `summary` / `description`）→ 正文首个 Markdown 标题（H1）。缺摘要不阻塞转换，但要提醒用户建草稿前需要补上。超限时直接告诉用户超了多少，给出压缩建议，不要静默截断。

**标题只进元数据，不进正文 HTML。** 公众号的文章标题由草稿的 `title` 字段承载，编辑器会在正文上方单独渲染它；正文 HTML 里再出现一次就是重复标题，读者看到的是同一句话连着出现两遍。所以不论标题来自 frontmatter 还是正文 H1，步骤 5 生成 HTML 时都**不渲染 H1**，正文从第一段（或第一个 H2）开始。文章内部的 H2/H3 层级照常渲染，不需要因为去掉 H1 而整体上提。

### 步骤 3：选主题

主题清单以 [references/theme-prompts/INDEX.md](references/theme-prompts/INDEX.md) 为准（不要背名单，主题会持续增补），覆盖从水墨极简到包豪斯撞色、从苹果留白到午夜暗色的不同气质。所有主题都是本地主题文件，用法统一。

用户没指定主题时，读 INDEX.md 按文章调性推荐（如技术教程推 `editor-slate`，商业分析推 `gilded-ink`，随笔推 `autumn-warm`），简短说明理由；用户明确说了就直接用。暗色主题按 INDEX.md 的说明做双模式手机预览。

### 步骤 4：组装排版指令

生成输入 = `theme-prompts/_common-tech.md`（技术约束）+ `theme-prompts/<theme>.md`（视觉规范）+ 文章原文。两者冲突时以 `_common-tech.md` 为准。这一步不需要调 CLI——**生成 HTML 是你的工作**（步骤 5）。

备选路径：`autumn-warm` / `ocean-calm` / `spring-fresh` 三个名字源自 CLI 内置，若用户明确要求用 CLI 实时指令，可改走 `md2wechat convert <article.md> --mode ai --theme <theme> --json`（返回 `CONVERT_AI_REQUEST_READY`，指令在 `data.prompt`，已含文章原文）。两条路不要混用；CLI 路径的产物同样要过步骤 6 自检。**不要给 CLI 传其他主题名**——`default` 等 api 主题报 `THEME_MODE_MISMATCH`，扩展主题名 CLI 不认识。

### 步骤 5：生成 HTML

严格按 `data.prompt` 里的设计指令，结合文章内容生成完整 HTML。指令覆盖配色和视觉风格，但**没有覆盖微信编辑器的粘贴陷阱**——生成前必须先读 [references/wechat-html.md](references/wechat-html.md)，其中五条铁律（代码块 `<br>`+`&nbsp;` 转义、显式 `text-align: left`、用 `<p>` 模拟列表、块间不留空行、纯内联样式）每条都对应真实翻车案例，与 `data.prompt` 冲突时以铁律为准。

承步骤 2：**正文 H1 不渲染**。主题文件里若有 h1 的样式规范，那是给"万一需要"准备的，正常流程用不到——标题走草稿元数据。

关于源文件里的 `:::module` 语法（hero / callout 等高级排版块）：免费模式没有 renderer 解析它们。**不要原样输出 `:::` 文本**——把模块内容理解成语义（引用、要点卡、结语等），用主题风格的内联样式 HTML 手工表达出来，并在完成后告知用户"高级排版模块是按语义手工降级渲染的，效果与付费 API 模式不同"。

在 HTML `<body>` 内容最前面嵌入一行元数据注释，供 `md2publish-draft` 交接使用：

```html
<!-- md2publish {"title":"...","author":"...","digest":"...","source":"article.md"} -->
```

生成用 `scripts/md2html.py` 做机械层（转义/`&nbsp;`/`<br>`/高亮/结构包裹/定宽），你只写主题配置 `theme.json` 和做语义判断——用法见 `_common-tech.md` 的「生成方式」节。不要另写转换脚本。

### 步骤 6：机械自检（不可跳过）

跑 [references/wechat-html.md](references/wechat-html.md) 末尾的自检脚本。它检查裸换行代码块、justify、原生列表标签、空段落、连续空行、缺失的 text-align/color——这些问题在浏览器预览里看不出来，只在粘贴进微信后台或手机预览时爆发。任何一项 FAIL 都要修复后重跑，直到 PASS 才能交付。

### 步骤 7：落盘和预览

- 输出文件默认写到源文件同目录：`<article-name>.html`。**如果该路径已存在文件，先问用户是否覆盖。**
- 保存后用 `open <file>.html`（macOS）让用户在浏览器里检查效果。
- 明确告诉用户：浏览器效果和微信编辑器效果有差异，最终以粘贴进公众号后台的效果为准。

### 步骤 8：交接

转换完成后报告：输出文件路径、使用的主题、元数据检查结果（含超限警告）。然后问用户下一步：

- 需要封面图 → `md2publish-cover`（与本 skill 并行，封面不进正文）
- 需要正文配图 / 信息图 / 卡片系列 → `md2publish-visuals`；需要架构图 / 流程图 → `md2publish-diagram`。
  `visuals` 要跑在本 skill **之前**——它回写出的 `article.illustrated.md` 才是本 skill 的输入；
  `diagram` 的示意图要插进正文时，同样要在本 skill 之前完成引用
- 要推草稿箱 → `md2publish-draft`
- 只要 HTML → 结束

不要未经询问就继续执行发布动作。

## 失败处理

- `THEME_MODE_MISMATCH`（仅 CLI 备选路径）：给 `convert --mode ai` 传了 api 主题；改传三个内置 ai 主题名之一，或直接走本地主题文件路径。
- `inspect` 报 blockers：逐条转述给用户，按 `data.readiness.blockers` 处理，不要猜。
- CLI 不在 PATH：提示安装 `npm install -g @geekjourneyx/md2wechat`，然后 `md2wechat version --json` 验证。
