# md2publish-skills

基于 [md2wechat](https://github.com/geekjourneyx/md2wechat-skill) CLI **免费路径**的公众号发布 skill 组合。全程不需要 `MD2WECHAT_API_KEY`，只在推草稿箱阶段需要微信 AppID/Secret + IP 白名单。

## 工作流

```
<name>.md（tech-writer → tech-writer-deslop 产出的成稿，<name> 是用户原始文件名）
   │
   ▼
┌─────────────────────┐
│   wechat-finetune   │  重拟标题 / 删难懂与无关 / 开篇钩子
│   公众号平台适配     │  段落切短 / frontmatter 元数据
│   (零副作用)        │  原文不动，另存
└─────────┬───────────┘
          │  <name>.wechat.md
          ▼
┌──────────────────────────┐
│   md2publish-visuals     │  正文配图 / 信息图 / 卡片系列
│   (真花钱，回写门)        │  回写图片引用，另存
└─────────┬────────────────┘
          │  <name>.illustrated.md（有配图时下游吃它，没配图时下游吃 <name>.wechat.md）
          ▼
┌─────────────────────┐      ┌──────────────────────────────┐
│  md2publish-article │      │      md2publish-cover        │
│  md → 内联样式 HTML  │      │  真调 provider 生图（花钱）    │
│  (AI 模式, 零副作用) │      │  assets/<platform>/00-cover.*│
└─────────┬───────────┘      └──────────────┬───────────────┘
          │  article.html                   │  以 sidecar 的 image 字段（文件名）为准
          └───────────────┬─────────────────┘
                          ▼
               ┌─────────────────────┐
               │  md2publish-draft   │
               │  用户确认 → 传图 →   │
               │  create_draft 草稿箱 │
               └─────────────────────┘
```

`md2publish-diagram`（架构图 / 流程图）视用途而定：示意图要进正文，就必须在 `md2publish-article`
之前被引用进 Markdown；只单独导出一张图，则与这条流水线无耦合。

**文件名推导规则**：`<name>.wechat.md`、`<name>.illustrated.md` 里的 `<name>` 是
`wechat-finetune` 写出时用的用户原始文件名，不是字面量 `article`——图里的
`article.*` 只在下面的 skill 表和 `md2publish-article` 的产物那里出现，那是
`md2publish-article` 自己另起的输出名（`<article-name>.html`），与配图链路的
文件名无关，不要混着当同一套命名规则读。`md2publish-article` 找带图版本时按
`*.illustrated.md` 模式匹配同目录文件，匹配到多个要问用户选哪一份，不擅自挑。

`wechat-finetune` 之前的两步在另一个仓库（`~/code/skills/runskills/skills/`）：`tech-writer` 管读者懂不懂，`tech-writer-deslop` 管像不像 AI 写的，`wechat-finetune` 管适不适合公众号这个平台。三者判据不重叠，顺序不能反。

| Skill | 职责 | 副作用 | 凭证要求 |
|---|---|---|---|
| `wechat-finetune` | 成稿 → 公众号版 Markdown（标题/精简/元数据） | 无（原文不改，另存） | 无 |
| `md2publish-article` | Markdown → 微信内联样式 HTML | 无 | 无 |
| `md2publish-cover` | 封面图（微信 16:9 / 小红书 3:4），真调 provider 生成 | 本地文件 + **API 消费（花钱）** | provider API key（缺失时降级为只产 prompt） |
| `md2publish-visuals` | 正文配图 / 信息图 / 卡片系列，真调 provider 生成，**回写 Markdown**（另存 `<name>.illustrated.md`） | 本地文件 + **API 消费（花钱）** | provider API key（缺失时降级为只产 prompt） |
| `md2publish-diagram` | 架构图 / 流程图，不调 AI、零 API 成本，直接写 SVG | 本地文件 | 无 |
| `md2publish-draft` | 上传图片 + 创建草稿（确认后执行） | 写微信素材库、草稿箱 | WECHAT_APPID/SECRET + IP 白名单 |

## 前置

```bash
npm install -g @geekjourneyx/md2wechat
md2wechat version --json
```

发布配置见 `md2publish-draft/references/credentials.md`。

`md2publish-cover` 与 `md2publish-visuals` 另需 bun + 图片压缩工具；`md2publish-diagram`
另需一个光栅化后端（不需要 bun，它不调 AI）：

```bash
bun --version                          # 或 npx -y bun --version   —— cover / visuals
sips --version || magick --version     # 二者有其一                —— cover / visuals
rsvg-convert --version || magick --version   # 二者有其一，或装 headless Chrome 兜底 —— diagram
```

图片能力线的测试入口：`./scripts/check.sh`。没有 CI，手工跑。

## 设计要点

- **免费路径**：指 **md2publish 系统本身不收费**（不需要 `MD2WECHAT_API_KEY`）——
  `convert --mode ai` 产出排版指令，HTML 由 Agent 生成；草稿走 `upload_image` + `create_draft`
  （不走需要 API key 的 `convert --draft`）。**图片模型的费用不在此列**
- **两道门，性质不同**：
  - **花钱的门**在 `md2publish-cover` 的生成那一步（步骤 5），前四步仍然零成本——
    没配 provider 也能拿到 prompt 文件自己去生。单张封面不额外问；批量生成（`visuals`）
    才报「将生成 N 张 / 预估 ¥X / provider / model」再确认
  - **外部系统的门**仍然只有 `md2publish-draft` 一处（写微信素材库、草稿箱），强制用户确认
- **「配图零副作用」已作废**：那是旧计划模式的口径。`md2publish-cover` 真调 provider、
  真花钱、不可逆；`visuals` 还会回写 Markdown（另存 `<name>.illustrated.md`，
  与 `wechat-finetune`「原文不动，另存」一致）
- **不用 `test-draft` 发正式文章**：其标题在 CLI 内硬编码，仅作连通性冒烟
