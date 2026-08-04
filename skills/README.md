# md2publish-skills

基于 [md2wechat](https://github.com/geekjourneyx/md2wechat-skill) CLI **免费路径**的公众号发布 skill 组合。全程不需要 `MD2WECHAT_API_KEY`，只在推草稿箱阶段需要微信 AppID/Secret + IP 白名单。

## 工作流

```
article.md（tech-writer → tech-writer-deslop 产出的成稿）
   │
   ▼
┌─────────────────────┐
│   wechat-finetune   │  重拟标题 / 删难懂与无关 / 开篇钩子
│   公众号平台适配     │  段落切短 / frontmatter 元数据
│   (零副作用)        │  原文不动，另存
└─────────┬───────────┘
          │  article.wechat.md
          ▼
┌─────────────────────┐     ┌─────────────────────┐
│  md2publish-article │     │  md2publish-images  │
│  md → 内联样式 HTML  │     │  封面图/信息图       │
│  (AI 模式, 零副作用) │     │  (--plan, 零副作用)  │
└─────────┬───────────┘     └──────────┬──────────┘
          │  article.html              │  cover.png
          └──────────┬─────────────────┘
                     ▼
          ┌─────────────────────┐
          │  md2publish-draft   │
          │  用户确认 → 传图 →   │
          │  create_draft 草稿箱 │
          └─────────────────────┘
```

`wechat-finetune` 之前的两步在另一个仓库（`~/code/skills/runskills/skills/`）：`tech-writer` 管读者懂不懂，`tech-writer-deslop` 管像不像 AI 写的，`wechat-finetune` 管适不适合公众号这个平台。三者判据不重叠，顺序不能反。

| Skill | 职责 | 副作用 | 凭证要求 |
|---|---|---|---|
| `wechat-finetune` | 成稿 → 公众号版 Markdown（标题/精简/元数据） | 无（原文不改，另存） | 无 |
| `md2publish-article` | Markdown → 微信内联样式 HTML | 无 | 无 |
| `md2publish-images` | 封面/信息图（计划模式交宿主 Agent 生成） | 无 | 无 |
| `md2publish-draft` | 上传图片 + 创建草稿（确认后执行） | 写微信素材库、草稿箱 | WECHAT_APPID/SECRET + IP 白名单 |

## 前置

```bash
npm install -g @geekjourneyx/md2wechat
md2wechat version --json
```

发布配置见 `md2publish-draft/references/credentials.md`。

## 设计要点

- **免费路径**：`convert --mode ai` 产出排版指令，HTML 由 Agent 生成；草稿走 `upload_image` + `create_draft`（不走需要 API key 的 `convert --draft`）
- **确认边界**：转换和配图零副作用；唯一的外部副作用（传图 + 建草稿）集中在 draft skill，且强制用户确认
- **不用 `test-draft` 发正式文章**：其标题在 CLI 内硬编码，仅作连通性冒烟
