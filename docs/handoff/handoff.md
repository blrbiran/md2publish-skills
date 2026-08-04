# Handoff：md2publish-skills 交接文档

> 更新于 2026-08-05。接手前先读本文，再按「下一步候选」开工。
> 仓库位置：`~/code/skills/writing/md2publish-skills/`
>
> **本文不记录 commit hash**——提交本文这个动作本身就会移动 HEAD。仓库状态一律以实时的
> `git log` / `git status` 为准；本文只描述「做到哪一步了」，不描述「在哪个提交上」。

## 一、项目是什么

基于 [md2wechat CLI](https://github.com/geekjourneyx/md2wechat-skill) **免费路径**（不买 `MD2WECHAT_API_KEY`）的公众号发布 skill 组合，四个 skill 各管一段：

- `skills/wechat-finetune/` — 成稿 → 公众号版 Markdown（重拟标题/删难懂与无关/开篇钩子/段落切短/frontmatter），原文不动、另存 `<name>.wechat.md`
- `skills/md2publish-article/` — Markdown → 微信可粘贴 HTML（排版指令来自本地主题库）
- `skills/md2publish-images/` — 封面/信息图（`--plan` 计划模式，交宿主 agent 生成）
- `skills/md2publish-draft/` — 推草稿箱（`upload_image` + `create_draft`，强制用户确认）

完整链路：`tech-writer`（读者懂不懂）→ `tech-writer-deslop`（像不像 AI 写的）→ `wechat-finetune`（适不适合公众号平台）→ `md2publish-article` → `md2publish-images` → `md2publish-draft`。前两个在另一个仓库 `~/code/skills/runskills/skills/`，三者判据不重叠、顺序不能反。

架构与职责边界见 `skills/README.md`；给人读的全流程教程在 `~/org/markdown/prompt/@inbox/md-to-wechat-draft-free-path.md`（仓库外）。

## 二、当前状态

### 已实测验证

- **全链路 E2E 两次跑通**：litellm 技术文（2.8 万字符、13 代码块）用 autumn-warm 和 editor-slate v2 生成 HTML → 自检 PASS → `create_draft` 推草稿 → 用户手机预览确认。产物在 `~/code/skills/writing/wechat_test/litellm-multi-provider-gateway/`
- **主题库 27 个**（不是 26），清单见 `references/theme-prompts/INDEX.md`。三个原 CLI 内置主题已重写为扩展主题格式，全库统一走「`_common-tech.md` + 主题文件 + 原文」一条生成路径
- **主题批量实测第一批 6 个**：ocean-calm / ink-wash / editor-slate / bauhaus-pop / cyber-neon / monochrome-mag。产物在实验目录的 `out/`，编号按 INDEX.md 顺序，每份配一份 `.report.md`。**剩余 21 个未跑**
- **全库落点审计归零**：`scripts/audit-themes.py` 扫 27 个主题，0 条嫌疑

### 关键产出（这一轮新增）

- **`scripts/md2html.py`**——机械层共享脚本。此前每次生成都由模型现写一份转换脚本，等于每次都有一次写错的机会。现在转义顺序、`&nbsp;` 边界、span 不跨 `<br>`、结构包裹、语法高亮、定宽分层、H1 处理、代码块逐字节自校验全部固定下来，主题差异从 `theme.json` 传入。**用法见 `_common-tech.md` 的「生成方式」节，不要再另写转换脚本**。示例配置：实验目录的 `out/13-cyber-neon-v3.theme.json`
- **`scripts/audit-themes.py`**——主题落点审计，四档：`DEAD`（零落点）/ `LOW`（文字色落点全在 em、链接等中文文章里可能为零的元素）/ `DECOR`（强调色只当边框细线用，无文字色落点）/ `DESYNC`（改了组件值没同步调色板）。四档都做过变异测试
- **`wechat-finetune` skill**：画像存 cwd 的 `./.md2publish/audience-profile.md`；标题出 4–5 个不同路子的候选让用户选；`scripts/verify.py` 自检（代码块逐字节保真、frontmatter 三字段限长、正文无残留 H1、删减比例）。**eval 循环尚未跑**（用户选择后置）
- **`docs/theme-design-lessons.md` 扩到三个案例、七条规则**，新增/改主题前必读

## 三、关键契约（教训换来的，别再踩）

### 发布相关

1. **正式发草稿只用 `create_draft` + JSON**；`test-draft` 的标题/摘要在 CLI 源码里硬编码（`cmd/md2wechat/test_draft.go`）
2. **封面用 `media_id`，正文图用 `wechat_url`**（`upload_image` 返回两个字段，别混）
3. **配置必须扁平 `wechat.appid/secret`**；`accounts:` 命名账号或 `proxy_url` 会触发付费 key 校验（`API_KEY_REQUIRED`）
4. `doctor` 的 `api.config FAIL` / `overall: blocked` 在免费路径是**预期状态**，只看 `wechat.config PASS`
5. 用户微信凭证已配好（`~/.config/md2wechat/config.yaml`，勿外传勿改）；IP 白名单已配，家庭网络 IP 变动会报 `ip not in whitelist`，`curl ifconfig.me` 重查后更新即可

### 生成 HTML 相关

6. 五条铁律在 `references/wechat-html.md`，每条对应真实翻车；末尾自检脚本**生成后必须跑到 PASS**
7. **标题只进元数据注释，正文不渲染 H1**；去掉 H1 后 H2/H3 层级不上提，开篇按 `_common-tech.md` 的处理顺序补起手式
8. **背景与定宽分层**：主 `<div>` 负责铺满（背景、padding、**不写 max-width**），定宽居中落在内容块上（卡片式主题落每张卡，无卡片主题落每个顶层块）
9. **定宽居中的样式串必须拼在主题样式之后**，且用 longhand。拼前面会被主题的 `margin` 简写覆盖，结果是定宽生效但内容贴左边——这个错肉眼看代码看不出来，两个属性都在、值也对，只是顺序错了
10. **行内 code 装饰要克制**：技术文里它有一两百处，实心深底 + padding 在手机断行时裂成两截（实测 193 处中 46 处跨行）。断行本身避免不了，能控制的只是裂开时有多难看。它也不承担强调色落点

### 改主题相关

11. **规范行里不夹叙述、不留旧色值**。一句「别只挂在 em 上」会让审计脚本把该行判成 em 落点；一个「原先的 `#xxxxxx` 是 1.11:1」会让旧值看起来仍有落点。这既是脚本的要求，也是给生成模型的要求——它可能真把旧值用上
12. **改完跑 `audit-themes.py` 到 0 条**，改自检脚本或审计脚本后做变异测试（故意制造缺陷确认报警），否则你分不清「真没问题」和「根本没在查」

## 四、悬而未决的问题

- **暗色主题在微信浅色模式下可能全篇不可读**。cyber-neon 实测：模拟「浅色模式把背景映射为白」后，正文 1.52:1、主强调 1.88:1，且**不存在两边都安全的配色**。影响 cyber-neon / midnight-study / velvet-stage / retro-phosphor 四个。**必须真机双模式预览才能定论**——要么确认微信不做这个映射，要么接受它们只在深色模式可用，要么改成「深色卡 + 浅色页面底」的结构
- **editor-slate 的历史修复只做了一半**：补语法高亮让代码块变彩了，但正文强调蓝落点不足的根因刚修（给 strong 上色），**未复测**。代码占比低的文章仍是风险场景
- **第一批 6 份产物和 bauhaus-pop v2 都带旧的宽度结构**，要看正确效果需用新脚本重生成。目前唯一结构正确的产物是 `out/13-cyber-neon-v4.html`

## 五、下一步候选

按价值排序，与用户确认后再动：

1. **用 `md2html.py` 重生成已测主题**，确认宽度/居中修复在各主题上都成立（成本很低，不必开 subagent，写好 `theme.json` 直接跑）
2. **跑剩余 21 个主题**（第一批 6 个 ≈ $45 量级，全量按同等负载估计三到四倍，跑前先跟用户确认预算）
3. **暗色主题真机双模式验证**（见上，唯一能解那个悬案的办法）
4. **`wechat-finetune` 实测 + eval 循环**：拿一篇真文章走一遍比跑 eval 更直接；skill-creator 的 description 优化循环也未做
5. **`md2publish-images` skill 从未实测**（宿主生图 + 上传封面未走通）
6. **教程文档校订**：`@inbox/md-to-wechat-draft-free-path.md` 写于主题统一重构之前，「第二步：拿排版设计指令」仍以 CLI convert 为主路径，且未反映 `md2html.py`

## 六、Suggested skills

- `superpowers:verification-before-completion` — 任何「改完了」之前跑验证。本项目里这条格外重要：宽度问题连续改错两次，都是因为只验证了「我改的属性在不在」，没验证「渲染出来是什么样」
- `skill-creator` — 改 skill 结构、跑 evals、做 description 优化
- `superpowers:brainstorming` — 用户提新主题/新功能方向时先收敛需求
- `tech-writer` — 校订教程文档时（该文档按讲解体写成，改动要守住其风格）

## 七、环境速查

- md2wechat CLI 3.2.0 已装（npm 全局）；源码在 `~/code/skills/writing/md2wechat-skill/`（另一个 git 仓库，别混）
- 实验目录 `~/code/skills/writing/wechat_test/`
- 用户偏好：HTML 生成用 **Opus 模型 subagent**；**传图、建草稿、git commit/push 一律先经用户确认**；成本敏感，大批量跑 subagent 前先报预估
