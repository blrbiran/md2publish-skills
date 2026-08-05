# Handoff：md2publish-skills 交接文档

> 更新于 2026-08-05（第二轮）。接手前先读本文，再按「下一步候选」开工。
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

## 二、生成 HTML 的工作方式（这是现在的主路径，先看这节）

**不要手敲 HTML，也不要另写转换脚本。**机械层已经固化在 `scripts/md2html.py`：

```bash
python3 skills/md2publish-article/scripts/md2html.py <article.md> <theme.json> -o <out.html>
```

它包办转义顺序、`&nbsp;` 边界、span 不跨 `<br>`、结构包裹、语法高亮、定宽分层、H1 不进正文、代码块逐字节自校验。**你的工作单元是那份 `theme.json`**——把主题文件的散文规范翻译成内联样式串，外加脚本判断不了的语义判断（哪段升格提示卡、主题没覆盖的元素怎么补）。字段说明见脚本头部注释。

第二轮新增 8 个字段（原脚本只对 cyber-neon 一种形状验证过，另外 5 个主题一上就露洞）：

| 字段 | 解决什么 |
|---|---|
| `h3_prefix_html` | **27 个主题里 18 个需要**，原来只有 h2 有前缀字段 |
| `card_mode: "single"` | 全文一张大卡（editor-slate），区别于默认的每章一卡 |
| `h2_first` | 正文不渲染 H1，首个 h2 顶在页首，要单独去掉上间距/节前线 |
| `h2_text_style` | 标题文字自带色块（bauhaus-pop 的黑底白字） |
| `td_alt` | 表格斑马纹 |
| `list_prefix_cycle` | 列表前缀多色轮换（bauhaus-pop / candy-pop / aurora-flow） |
| `alert` | 提示卡（第三轮补）。文章 md 里写 `> [!NOTE]` 触发，主题没配就剥掉标记按普通引用块渲染 |

另有两处与规范冲突的修正：`sty()` 原来无条件追加 `text-align: left`，会盖掉主题指定的居中；`highlight` 的值原来只能是裸色值，现在也接受完整样式串（无彩色主题靠字重和字形区分 token，只能上色就没有区分手段了）。

跑完必须过 `references/wechat-html.md` 末尾的自检脚本到 PASS。抽取方法：

```bash
awk '/^python3 - <<.EOF.$/{f=1;next} /^EOF$/{f=0} f' skills/md2publish-article/references/wechat-html.md > selfcheck.py
python3 selfcheck.py <out.html>
```

## 三、当前状态

### 已实测验证

- **全链路 E2E 两次跑通**：litellm 技术文（1.7 万字符、13 代码块、11 个 h2、7 个 h3、3 处 `---`）→ HTML → 自检 PASS → `create_draft` → 手机预览确认
- **主题库 27 个**，清单见 `references/theme-prompts/INDEX.md`，全库统一走「`_common-tech.md` + 主题文件 + 原文」一条路径
- **主题实测 7 个**：autumn-warm / ocean-calm / ink-wash / editor-slate / bauhaus-pop / cyber-neon / monochrome-mag。**剩余 20 个未跑**
- **宽度/居中修复已在三种结构上验证成立**：分章卡片（定宽落每张 `<section>`）、全文单卡（落那一张卡，卡内 0 处误加定宽）、无卡片（落每个顶层块）
- **editor-slate 复测通过**：正文强调蓝落点 11 → **68 处**，「给 strong 上色」这个修复成立
- **全库审计归零**：`scripts/audit-themes.py` 27 个主题 0 条

### 产物位置

实验目录 `~/code/skills/writing/wechat_test/litellm-multi-provider-gateway/out/`，每份 HTML 旁边配一份同名 `.theme.json`（**这是复现和继续的入口，比 HTML 本身重要**）：

- `01-autumn-warm-v1.html`、`02-ocean-calm-v5.html`、`04-ink-wash-v5.html`、`06-editor-slate-v5.html`、`11-bauhaus-pop-v5.html`、`20-monochrome-mag-v5.html`
- `13-cyber-neon-v7-edge.html` 是 cyber-neon 定稿；同目录的 v5/v6/v7-grid 是中间产物，可清理（**删文件前问用户**）
- 更早的无版本号产物带旧宽度结构，已作废

## 四、关键契约（教训换来的，别再踩）

### 发布相关

1. **正式发草稿只用 `create_draft` + JSON**；`test-draft` 的标题/摘要在 CLI 源码里硬编码
2. **封面用 `media_id`，正文图用 `wechat_url`**（`upload_image` 返回两个字段，别混）
3. **配置必须扁平 `wechat.appid/secret`**；`accounts:` 或 `proxy_url` 会触发付费 key 校验
4. `doctor` 的 `api.config FAIL` / `overall: blocked` 在免费路径是**预期状态**，只看 `wechat.config PASS`
5. 用户微信凭证已配好（勿外传勿改）；IP 白名单已配，家庭网络 IP 变动会报错，重查后更新即可

### 生成 HTML 相关

6. 五条铁律在 `references/wechat-html.md`，末尾自检脚本**生成后必须跑到 PASS**
7. **标题只进元数据注释，正文不渲染 H1**；去掉 H1 后 H2/H3 层级不上提，首个 h2 用 `h2_first` 单独处理
8. **背景与定宽分层**：主 `<div>` 铺满（背景、padding、**不写 max-width**），定宽落在内容块上
9. **定宽居中的样式串必须拼在主题样式之后**，且用 longhand。拼前面会被主题的 `margin` 简写覆盖——这个错肉眼看代码看不出来
10. **`---` 的语义降级按主题结构分三路**：卡片主题加大卡间距（`hr_gap`）、无卡片主题画分隔线（`hr`）、h2 自带边框的丢弃。测试文里 3 处 `---` 全部紧邻 h2

### 改主题相关

11. **规范行里不夹叙述、不留旧色值**。一句「别只挂在 em 上」会让审计脚本把该行判成 em 落点
12. **改完跑 `audit-themes.py` 到 0 条**；改检查脚本后做变异测试
13. **提交前把 diff 完整读一遍**。第二轮就是在 diff 里才看见 `cyber-neon.md` 同一段里留着「亮一档」和「暗一档」两个相反的指令——改写时静默留下旧条款，只有读 diff 才抓得到

## 五、这一轮新增的判据（写进了 `docs/theme-design-lessons.md` 规则 7）

- **暗色主题上分层要往亮里走**。给 cyber-neon 行内 code 加底，第一次调成比卡底更暗的 `#10182a`，对卡底只有 **1.14:1**，用户反馈仍「看不清」；改成比卡底亮一档的 `#39456b`（1.65:1）才立得起边界。文字对比度从来不是这里的瓶颈（11.6:1）——**量错了对象就会连修两轮**
- **行内 code 的判据是「撞不撞形」，不是「用没用强调色」**。全库 17/27 给行内 code 派了强调色文字，其中 15 个带淡底、形状上和 strong 分得开，实测观感达标。真正翻车的只有 cyber-neon 那种「无底 + 强调色文字」
- **一个检查项报了大半个库，通常是判据下宽了，不是库烂了**。OVER 档第一版报了 15 个主题，收窄成「带底不报」后归零
- **变异用例的书写形态要够杂**。第一轮 4 个变异全是「行内 code 独占一行」，漏掉了「代码块与行内 code 写在同一行」（autumn-warm 就是这么写的），导致漏报

## 六、审计脚本现状

`scripts/audit-themes.py` 五档：`DEAD` 零落点 / `LOW` 只落在 em、链接等低频元素 / `DECOR` 只当边框细线 / **`OVER` 行内 code 无底色又用强调色当文字色** / `DESYNC` 改了组件没同步调色板。

支持豁免注记（HTML 注释，不进渲染，脚本查落点前先剥注释以免注记里的色值变成假落点）：

```
<!-- audit-ok: OVER #3d6a8a 一句话理由 -->
```

变异测试已进仓库，改审计脚本前先跑：

```bash
bash skills/md2publish-article/scripts/test-audit-themes.sh
```

14 条用例覆盖五档各自的正例、OVER 的三种真实书写形态（中文「底/文字」、纯 CSS、代码块与行内 code 同行）、散文句混在规范里、带前缀的 `*-color:` 不算文字色、豁免生效、豁免注记里的色值不能变成假落点；最后一条顺带要求真实主题库仍是 0 条。**这套用例本身也验过牙齿**：对审计脚本做了 9 种定点破坏（去掉截断、去掉「有底不报」守卫、不剥注释、不过滤豁免、逐档删掉 DEAD/LOW/DECOR/OVER、去掉 `color:` 的反向断言），9 种全部有用例变红。

## 七、悬而未决

- **暗色主题在微信浅色模式下可能全篇不可读**。cyber-neon 模拟「浅色模式把背景映射为白」后正文仅 1.52:1，且不存在两边都安全的配色。影响 cyber-neon / midnight-study / velvet-stage / retro-phosphor 四个。**必须真机双模式预览才能定论**，用户表示自己验证，结论未回
- **cyber-neon 的品红落点第 2 条挂在一个它自己没定义的元素上**。`cyber-neon.md` 写「提示卡里属于警示性质的那种用品红」，但该主题文件没有提示卡规范、`theme.json` 也没配 `alert`，这条永远不触发（它的第 3 条兜底说「两者都没有就不用品红」，所以不算破，但是条悬空引用）。暗色提示卡要配色验证，且 cyber-neon 正卡在浅色模式那个悬案上，暂不动
- **`wechat-finetune` 未实测**，eval 循环未跑
- **`md2publish-images` 从未实测**（宿主生图 + 上传封面未走通）

## 八、下一步候选

1. **跑剩余 20 个主题**——每个主题的工作是「读主题文件 → 写 theme.json → 跑脚本 → 过自检 → 看落点」。**强烈建议开新会话跑**：实测下来单个主题的实际工作量只有约 2k 输出 token，成本几乎全部来自上下文重发。大上下文会话里每轮 $3–6，剩余 20 个约 $150–200；新会话上下文只需 `_common-tech.md` + `md2html.py` 用法 + 自检脚本 + 一份主题文件（约 25k），总计约 $25–35
2. **暗色主题真机双模式验证**（在用户那边）
3. **`wechat-finetune` 实测 + eval 循环**
4. **教程文档校订**：`@inbox/md-to-wechat-draft-free-path.md` 写于主题统一重构之前，未反映 `md2html.py`

## 九、Suggested skills

- `superpowers:verification-before-completion` — 本项目里这条格外重要：宽度问题连续改错两次、cyber-neon 对比度连续改错两次，都是因为只验证了「我改的属性在不在」，没验证「渲染出来是什么样」，或者量错了对象
- `skill-creator` — 改 skill 结构、跑 evals、做 description 优化
- `superpowers:brainstorming` — 用户提新主题/新功能方向时先收敛需求
- `tech-writer` — 校订教程文档时（该文档按讲解体写成，改动要守住其风格）

## 十、环境速查

- md2wechat CLI 3.2.0 已装（npm 全局）；源码在 `~/code/skills/writing/md2wechat-skill/`（另一个 git 仓库，别混）
- 实验目录 `~/code/skills/writing/wechat_test/`
- 用户偏好：**传图、建草稿、git commit/push 一律先经用户确认**；成本敏感，大批量开跑前先报预估
- 用户在 main 分支上直接提交，不开特性分支
