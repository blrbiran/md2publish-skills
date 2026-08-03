---
name: md2publish-images
description: 用 md2wechat 的图片计划模式（--plan）为公众号文章生成封面图或信息图。当用户说"生成封面"、"封面图"、"配图"、"信息图"、"文章头图"，或在公众号文章工作流中需要图片素材时使用。计划模式不需要图片 provider API key——CLI 产出图片 prompt，由宿主 Agent 的图片生成工具或用户自选工具执行。
allowed-tools: Read, Write, Bash, AskUserQuestion
---

# md2publish-images：封面图 / 信息图（计划模式）

为公众号文章生成封面图或信息图。主路径是 md2wechat 的**计划模式**（`--plan`）：CLI 根据文章内容和内置 preset 产出结构化图片 prompt，实际生成交给宿主 Agent 的图片生成能力，或把 prompt 给用户拿去任意生图工具使用。计划模式不需要 `IMAGE_API_KEY`，不需要 `MD2WECHAT_API_KEY`，无副作用。

## 执行流程

### 步骤 1：确定图片类型和 preset

封面 (`generate_cover`) 还是信息图 (`generate_infographic`)？用户没说清就问。

preset 用 CLI 发现，不要背名单：

```bash
md2wechat prompts list --kind image --archetype cover --json
md2wechat prompts list --kind image --archetype infographic --json
```

用户没指定 preset 时用命令默认值即可（不传 `--preset`）；用户提了风格偏好（如"科技感"、"暖色"）时，从 list 结果的 `description` 里挑最接近的，用 `prompts show <name> --kind image --json` 确认后再用。

### 步骤 2：生成图片计划

```bash
md2wechat generate_cover --article <article.md> --plan --json
# 或
md2wechat generate_infographic --article <article.md> --plan --json
# 指定 preset 时加 --preset <name>
```

成功返回 `code: "IMAGE_PLAN_READY"`、`status: "action_required"`，关键字段：

| 字段 | 用途 |
|---|---|
| `data.prompt` | 生图 prompt，已融合文章标题/摘要/关键词 |
| `data.aspect` / `data.default_aspect_ratio` | 画幅（封面默认 16:9） |
| `data.suggested_filename` | 建议保存文件名 |
| `data.alt_text` | 图片 alt 文本 |

### 步骤 3：执行生成

按优先级选择执行方式：

1. **当前运行时有图片生成工具**（如 imagegen skill / 内置生图能力）：直接用 `data.prompt` + 画幅生成，保存为 `suggested_filename`（存到文章同目录）。
2. **没有生图工具**：把 `data.prompt` 和画幅完整展示给用户，说明可以粘贴到即梦、Midjourney、DALL·E 等工具，生成后把图片文件放到文章目录。

生成或收到图片后，和用户确认效果是否满意；不满意可调整 prompt 重新生成（微调 `data.prompt` 而不是从头写）。

### 步骤 4：交接

- 封面图确认后，告诉用户文件路径。推草稿箱时 `md2publish-draft` 会用它作为 `--cover`。
- 信息图确认后，提醒用户在 Markdown 正文中插入 `![alt](path)` 引用，位置由用户定。

## 直连 provider 路径（可选）

如果用户自己配置了图片 provider（火山、ModelScope、OpenRouter、OpenAI、Gemini 等，属于用户自有 key，不是 md2wechat 付费 API），可以去掉 `--plan` 直接生成：

```bash
md2wechat providers list --json    # 看 current 和 current_configured
md2wechat generate_cover --article <article.md>
```

仅当 `current_configured: true` 时走这条路；否则回到计划模式，不要引导用户为此配置 provider。

## 注意

- 微信封面在不同位置会被裁剪（头条约 2.35:1，次条 1:1）。16:9 原图基本安全，但提醒用户重要视觉元素放画面中央。
- 计划模式零副作用：不请求 provider、不上传微信。上传发生在 `md2publish-draft` 的发布阶段。
