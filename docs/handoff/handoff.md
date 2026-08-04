# Handoff：md2publish-skills 交接文档

> 更新于 2026-08-04。接手前先读本文，再按「下一步候选」开工。
> 仓库位置：`~/code/skills/writing/md2publish-skills/`

## 一、项目是什么

基于 [md2wechat CLI](https://github.com/geekjourneyx/md2wechat-skill) **免费路径**（不买 `MD2WECHAT_API_KEY`）的公众号发布 skill 组合，四个 skill 各管一段：

- `skills/wechat-finetune/` — 成稿 → 公众号版 Markdown（重拟标题/删难懂与无关/开篇钩子/段落切短/frontmatter），原文不动另存 `<name>.wechat.md`
- `skills/md2publish-article/` — Markdown → 微信可粘贴 HTML（排版指令来自本地主题库，HTML 由 agent 生成）
- `skills/md2publish-images/` — 封面/信息图（`--plan` 计划模式，交宿主 agent 生成）
- `skills/md2publish-draft/` — 推草稿箱（`upload_image` + `create_draft`，强制用户确认）

完整链路：`tech-writer`（读者懂不懂）→ `tech-writer-deslop`（像不像 AI 写的）→ `wechat-finetune`（适不适合公众号平台）→ `md2publish-article` → `md2publish-images` → `md2publish-draft`。前两个在另一个仓库 `~/code/skills/runskills/skills/`，三者判据不重叠、顺序不能反。

架构、工作流图和各 skill 的职责边界见 `skills/README.md`；给人读的全流程教程在 `~/org/markdown/prompt/@inbox/md-to-wechat-draft-free-path.md`（仓库外）。

## 二、当前状态（截至本次交接）

### 已完成且实测验证

- **全链路 E2E 两次跑通**：litellm 技术文（2.8 万字符、13 代码块）分别用 autumn-warm（CLI 指令路径）和 editor-slate v2（本地主题路径）生成 HTML → 自检 PASS → `create_draft` 推草稿 → 用户手机预览确认正常。实验产物在 `~/code/skills/writing/wechat_test/litellm-multi-provider-gateway/`（v1/v2/editor-slate 各版 HTML + draft json 都在，可对比）
- **主题库 26 个主题**：`skills/md2publish-article/references/theme-prompts/`，清单和选择建议见其中 `INDEX.md`
- **主题统一重构**：原三个 CLI 快照主题（autumn-warm/ocean-calm/spring-fresh）已重写为扩展主题格式，全库统一走「`_common-tech.md` + 主题文件 + 原文」一条生成路径；CLI `convert --mode ai` 降级为三个内置名的备选
- **设计事故复盘**：editor-slate 曾黑白化翻车（用户实名批评），根因、修法、五条主题设计规则、机械审计方法都在 `docs/theme-design-lessons.md`——**新增/改主题前必读**
- **全库落点审计**：23 个扩展主题扫过一轮，apple-air 同款风险已修（eyebrow 蓝标签保底），4 个死色已补注记，其余误报或达标（详见 lessons 文档）

### 本次会话新增（2026-08-04 第二段）

- **主题统一重构已提交**（commit `1bc709f`），三个重写主题过了落点静态审计（两个强调色各 5–6 个高频落点，无死色）
- **新增 `wechat-finetune` skill**：画像存 cwd 的 `./.md2publish/audience-profile.md`；标题出 4–5 个不同路子的候选让用户选；`scripts/verify.py` 做自检（代码块逐字节保真、frontmatter 三字段限长、正文无残留 H1、删减比例），四种失败模式都用假样本验证过能抓到。**eval 循环尚未跑**（用户选择后置）
- **H1 规则**（标题只进草稿元数据、不渲染进正文 HTML）：写在三处才生效——`md2publish-article/SKILL.md` 步骤 2/5、`_common-tech.md` 新增「标题（H1 不进正文）」节（**这里才是生成模型实际读的**）、`wechat-html.md` 自检脚本新增 `<h1>` 与元数据注释两项检查。规则要求去掉 H1 后 H2/H3 层级不上提
- **主题实测第一批 6 个已跑**（02 ocean-calm / 04 ink-wash / 06 editor-slate / 11 bauhaus-pop / 13 cyber-neon / 20 monochrome-mag），产物在 `~/code/skills/writing/wechat_test/litellm-multi-provider-gateway/out/`，编号按 INDEX.md 顺序，剩余 21 个待跑。主题总数是 **27 个**不是 26

### 仓库有未提交变更

`git status` 会显示本次会话的改动（lessons 文档、SKILL.md、INDEX、三个重写主题等）。**尚未提交**——用户没有明确说提交，接手后如需提交先向用户确认。不要依赖本文写下的任何 commit 位置，以 `git log`/`git status` 实时输出为准。

## 三、关键契约（教训换来的，别再踩）

1. **正式发草稿只用 `create_draft` + JSON**；`test-draft` 的标题/摘要在 CLI 源码里硬编码（`cmd/md2wechat/test_draft.go` 的 `runTestDraft`，在 md2wechat 仓库 `~/code/skills/writing/md2wechat-skill/`）
2. **封面用 `media_id`，正文图用 `wechat_url`**（`upload_image` 返回两个字段，别混）
3. **配置必须扁平 `wechat.appid/secret`**；`accounts:` 命名账号或 `proxy_url` 会触发付费 key 强制校验（`API_KEY_REQUIRED`）
4. `doctor` 的 `api.config FAIL` / `overall: blocked` 在免费路径是**预期状态**，只看 `wechat.config PASS`
5. 生成 HTML 的五条铁律在 `skills/md2publish-article/references/wechat-html.md`，每条对应真实翻车；机械自检脚本在该文件末尾，**生成后必须跑到 PASS**
6. 推荐生成方式：**脚本做机械层（转义/nbsp/br/span 顺序固定），AI 做判断层**，产物做 `<pre>` 反解逐字节 diff——见 `_common-tech.md` 的「生成方式」节
7. 用户的微信凭证已配好（在 `~/.config/md2wechat/config.yaml`，勿外传勿改）；IP 白名单已配，家庭网络 IP 变化时会报 `ip not in whitelist`，重查 `curl ifconfig.me` 更新白名单即可

## 四、下一步候选（未完成的事）

按价值排序，与用户确认后再动：

1. **提交本次变更**（需用户确认 commit）
2. **重写版内置主题未实测**：ocean-calm / spring-fresh / autumn-warm 重写后还没生成过真文章；ocean-calm 对技术分析文最对口，可作首测
3. **暗色主题全部未实测**：cyber-neon / midnight-study / velvet-stage / retro-phosphor 有"微信 App 深浅双模式颜色映射"的未知风险（INDEX 有预警），需真机验证
4. **md2publish-images skill 从未实测**（计划模式产出 prompt 的链路验证过 CLI 侧，宿主生图 + 上传封面未走通过）
5. **skill description 触发优化未做**（skill-creator 的 description 优化循环）
6. 教程文档（`@inbox/md-to-wechat-draft-free-path.md`）的读者测试未跑；且它写于主题统一重构之前，"第二步：拿排版设计指令"一节仍以 CLI convert 为主路径，需按新架构校订

## 五、Suggested skills

- `superpowers:verification-before-completion` — 任何"改完了"之前跑验证（自检脚本、色值普查）
- `skill-creator` — 改 skill 结构、跑 evals、做 description 优化时
- `tech-writer` — 校订教程文档时（该文档按讲解体写成，改动要守住其风格与「关于本文的准确性」三桶）
- `superpowers:brainstorming` — 用户提出新主题/新功能方向时先收敛需求

## 六、环境速查

- md2wechat CLI 3.2.0 已装（npm 全局）；源码仓库在 `~/code/skills/writing/md2wechat-skill/`（另一个 git 仓库，别混）
- 实验目录 `~/code/skills/writing/wechat_test/`
- 用户偏好：HTML 生成用 **Opus 模型 subagent**；发布类副作用（传图/建草稿）必须先经用户确认；git push/commit 必须先经用户确认
