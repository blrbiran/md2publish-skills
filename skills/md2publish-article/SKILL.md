---
name: md2publish-article
description: 用 md2wechat CLI 免费路径把 Markdown 文章转成微信公众号可用的内联样式 HTML。当用户想"转换公众号文章"、"md 转 html"、"排版公众号"、"生成微信文章 HTML"、"美化文章"，或提供一篇 Markdown 并提到微信公众号/公众号发布时使用。本 skill 只做转换和本地预览，不上传图片、不创建草稿；发草稿箱交给 md2publish-draft skill。
allowed-tools: Read, Write, Bash, AskUserQuestion
---

# md2publish-article：Markdown 转公众号 HTML（免费路径）

把 Markdown 文章转成微信公众号编辑器可直接粘贴的 HTML。走 md2wechat 的**免费 AI 模式**：CLI 只负责产出排版设计指令（prompt），HTML 由你（Claude）按指令生成。全程不需要 `MD2WECHAT_API_KEY`。

## 边界

- 本 skill 产物是**本地 HTML 文件**，零副作用：不联网上传、不建草稿。
- 用户要"推草稿箱 / 发布 / 上传"时，转换完成后交接给 `md2publish-draft` skill。
- 用户要封面图 / 信息图时，交接给 `md2publish-images` skill。

## 执行流程

### 步骤 1：拿到输入

| 场景 | 处理 |
|---|---|
| 用户给了文件路径 | 直接使用 |
| 用户粘贴了 Markdown | 先 Write 保存为 `.md` 文件再继续 |
| 只说"转换文章"没给内容 | 询问文件路径或让用户粘贴 |

### 步骤 2：检查元数据和限制

```bash
md2wechat inspect <article.md> --mode ai --theme <theme> --json
```

读 `data` 中解析出的标题、作者、摘要，对照微信硬限制：

- 标题 ≤ 32 字符（超出建草稿时会被拒）
- 作者 ≤ 16 字符
- 摘要 ≤ 128 字符

元数据来源优先级：frontmatter（`title` / `author` / `digest`，摘要也接受 `summary` / `description`）→ 正文首个 Markdown 标题。缺摘要不阻塞转换，但要提醒用户建草稿前需要补上。超限时直接告诉用户超了多少，给出压缩建议，不要静默截断。

### 步骤 3：选主题

免费 AI 模式只能用 `type: ai` 的主题。用 CLI 发现当前可用列表，不要背名单：

```bash
md2wechat themes list --json
```

过滤 `type == "ai"` 且 `selectable == true`。当前版本通常是：

- `autumn-warm` — 秋日暖光，橙色调，温暖治愈（默认推荐）
- `ocean-calm` — 深海静谧，蓝色调，理性专业（技术/分析类文章）
- `spring-fresh` — 春日清新
- `custom` — 配合 `--custom-prompt` 使用用户自己的排版指令

用户没指定主题时，根据文章调性推荐一个并简短说明理由；用户明确说了就直接用。**不要用 `default` 等 api 主题**——AI 模式会报 `THEME_MODE_MISMATCH`。

### 步骤 4：获取排版指令

```bash
md2wechat convert <article.md> --mode ai --theme <theme> --json
```

成功返回 `code: "CONVERT_AI_REQUEST_READY"`、`status: "action_required"`，排版设计指令在 `data.prompt`。这一步 CLI 不产 HTML——**生成 HTML 是你的工作**。

### 步骤 5：生成 HTML

严格按 `data.prompt` 里的设计指令，结合文章内容生成完整 HTML。指令覆盖配色和视觉风格，但**没有覆盖微信编辑器的粘贴陷阱**——生成前必须先读 [references/wechat-html.md](references/wechat-html.md)，其中五条铁律（代码块 `<br>`+`&nbsp;` 转义、显式 `text-align: left`、用 `<p>` 模拟列表、块间不留空行、纯内联样式）每条都对应真实翻车案例，与 `data.prompt` 冲突时以铁律为准。

关于源文件里的 `:::module` 语法（hero / callout 等高级排版块）：免费模式没有 renderer 解析它们。**不要原样输出 `:::` 文本**——把模块内容理解成语义（引用、要点卡、结语等），用主题风格的内联样式 HTML 手工表达出来，并在完成后告知用户"高级排版模块是按语义手工降级渲染的，效果与付费 API 模式不同"。

在 HTML `<body>` 内容最前面嵌入一行元数据注释，供 `md2publish-draft` 交接使用：

```html
<!-- md2publish {"title":"...","author":"...","digest":"...","source":"article.md"} -->
```

### 步骤 6：机械自检（不可跳过）

跑 [references/wechat-html.md](references/wechat-html.md) 末尾的自检脚本。它检查裸换行代码块、justify、原生列表标签、空段落、连续空行、缺失的 text-align/color——这些问题在浏览器预览里看不出来，只在粘贴进微信后台或手机预览时爆发。任何一项 FAIL 都要修复后重跑，直到 PASS 才能交付。

### 步骤 7：落盘和预览

- 输出文件默认写到源文件同目录：`<article-name>.html`。**如果该路径已存在文件，先问用户是否覆盖。**
- 保存后用 `open <file>.html`（macOS）让用户在浏览器里检查效果。
- 明确告诉用户：浏览器效果和微信编辑器效果有差异，最终以粘贴进公众号后台的效果为准。

### 步骤 8：交接

转换完成后报告：输出文件路径、使用的主题、元数据检查结果（含超限警告）。然后问用户下一步：

- 需要封面图 → `md2publish-images`
- 要推草稿箱 → `md2publish-draft`
- 只要 HTML → 结束

不要未经询问就继续执行发布动作。

## 失败处理

- `THEME_MODE_MISMATCH`：选到了 api 主题，回到步骤 3 用 `themes list --json` 重选。
- `inspect` 报 blockers：逐条转述给用户，按 `data.readiness.blockers` 处理，不要猜。
- CLI 不在 PATH：提示安装 `npm install -g @geekjourneyx/md2wechat`，然后 `md2wechat version --json` 验证。
