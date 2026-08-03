---
name: md2publish-draft
description: 把公众号 HTML 文章推送到微信公众号草稿箱（免费路径：upload_image + create_draft，只需微信 AppID/Secret，不需要 md2wechat 付费 API key）。当用户说"推到草稿箱"、"发到公众号"、"上传草稿"、"发布文章"、"push to wechat"，或在完成文章转换后确认要发布时使用。创建草稿前必须让用户确认——这是唯一有外部副作用的步骤。
allowed-tools: Read, Write, Edit, Bash, AskUserQuestion
---

# md2publish-draft：推送草稿箱（免费路径）

把 HTML 文章推到微信公众号草稿箱。链路：上传正文图片 → 上传封面 → 组装 draft JSON → **用户确认** → `create_draft`。全程只需要微信 `WECHAT_APPID` / `WECHAT_SECRET` + IP 白名单，不需要 `MD2WECHAT_API_KEY`。

创建草稿是本工作流唯一的外部副作用。用户确认之前，任何 `upload_image` / `create_draft` 都不能执行——上传图片也会写入用户的微信素材库。

## 执行流程

### 步骤 1：前置检查

```bash
md2wechat doctor --json
```

- 看 `wechat.config`：必须 PASS。缺 `WECHAT_APPID` / `WECHAT_SECRET` 时，引导用户按 [references/credentials.md](references/credentials.md) 配置，配置完成前停止。
- `api.config` FAIL 和 `format_api: false` 在免费路径下是**预期状态，直接忽略**，不要向用户报为问题。
- 配置里若用了命名账号（`wechat.accounts`）或 `wechat.proxy_url`：这两者会强制校验 `MD2WECHAT_API_KEY`，属于付费能力。告知用户免费路径需要扁平配置（顶层 `wechat.appid` / `wechat.secret`），让用户自己改配置，不要代改。

### 步骤 2：收集发布材料

需要四样东西：

| 材料 | 来源（按优先级） |
|---|---|
| HTML 文件 | 用户指定 → 当前目录最新 `.html` |
| 标题/作者/摘要 | HTML 头部 `<!-- md2publish {...} -->` 注释 → 源 md frontmatter → 询问用户 |
| 封面图 | 用户指定 → md2publish-images 产物 → 询问用户 |
| 正文本地图片清单 | 扫描 HTML 中非 `mmbiz.qpic.cn` 的 `<img src>` |

元数据硬限制（微信侧强制，超限 `create_draft` 会失败）：

- 标题 ≤ 32 字符（必填）
- 作者 ≤ 16 字符
- 摘要 ≤ 128 字符

超限时给出压缩建议让用户选择，不要静默截断。

### 步骤 3：向用户展示发布摘要并确认

用 AskUserQuestion（或运行时等价工具）展示并确认，格式：

```
准备推送草稿箱：
- 标题：xxx（12/32 字符）
- 作者：xxx
- 摘要：xxx（45/128 字符）
- 封面：cover.png
- 正文图片：3 张本地图片将上传到微信素材库
- 目标公众号 AppID：wx****（后 4 位）

将执行：上传 4 张图片 → 创建草稿。是否继续？
```

用户明确同意才继续；犹豫或修改要求时回到步骤 2。

### 步骤 4：上传图片

正文里每张本地图片：

```bash
md2wechat upload_image <path> --json
```

返回 `data.wechat_url` 和 `data.media_id`。用 Edit 把 HTML 中对应 `<img src>` 替换为 `wechat_url`（微信正文只显示 `mmbiz.qpic.cn` 域名的图，外链图会挂）。

封面单独上传，记下它的 **`media_id`**（封面用 media_id，正文图用 wechat_url，不要混）：

```bash
md2wechat upload_image <cover> --json
```

失败时看 [references/credentials.md](references/credentials.md) 的排障表（最常见：`ip not in whitelist`）。

### 步骤 5：组装 draft JSON 并创建草稿

写 `draft.json`（放临时目录或文章同目录）：

```json
{
  "articles": [
    {
      "title": "文章标题",
      "author": "作者名",
      "digest": "摘要",
      "content": "<div>…完整 HTML（图片 URL 已替换）…</div>",
      "thumb_media_id": "封面上传返回的 media_id"
    }
  ]
}
```

`content` 是 HTML 字符串，注意 JSON 转义。然后：

```bash
md2wechat create_draft draft.json --json
```

成功返回 `data.media_id`（和可能的 `data.draft_url`）。报告给用户：草稿已创建，请到公众号后台「草稿箱」查看，发布动作在微信后台人工完成。

### 不要用 test-draft 发正式文章

`test-draft` 的标题和摘要在 CLI 里是硬编码的（"AI生成测试文章"），只适合做凭证/白名单连通性冒烟测试。正式文章一律走 `create_draft`。首次配置后如果用户想先验证链路，可以建议：

```bash
md2wechat upload_image <cover> --json   # 只验证凭证 + 白名单
```

这一步成功即说明凭证和白名单就绪，无需真的建测试草稿。

## 失败处理

| 现象 | 处理 |
|---|---|
| `ip ... not in whitelist` | 引导按 references/credentials.md 配置 IP 白名单，改完等 1–5 分钟重试 |
| `WECHAT_APPID is required` | 回到步骤 1 配置凭证 |
| 错误码 `45004` | 摘要/digest 问题，先检查 digest 内容而不是怀疑正文过长 |
| `API_KEY_REQUIRED` | 用户配置里有命名账号或 proxy_url，回到步骤 1 的免费配置说明 |
| 封面上传成功但草稿失败 | 封面 media_id 可复用，修复问题后直接重建 draft.json，不必重传 |
