# md2publish-skills

基于 [md2wechat](https://github.com/geekjourneyx/md2wechat-skill) CLI **免费路径**的公众号发布 skill 组合。全程不需要 `MD2WECHAT_API_KEY`，只在推草稿箱阶段需要微信 AppID/Secret + IP 白名单。

## 工作流

```
article.md
   │
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

| Skill | 职责 | 副作用 | 凭证要求 |
|---|---|---|---|
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
