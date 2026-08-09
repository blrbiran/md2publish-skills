# Handoff：图片能力线（cover / visuals / diagram）

最后更新：2026-08-10

本文只管**图片这条线**。主题库与 HTML 生成那条线在 `docs/handoff/handoff.md`，两者互不重叠，别读错。

## 快速接手入口

1. 目标：把 `md2publish-images` 拆成 `md2publish-cover` / `md2publish-visuals` / `md2publish-diagram` 三个 skill，并支持微信之外的平台（小红书、B 站）。
2. **一期已完成并合进本地 `main`**：`skills/_shared/` 图片资产层 + 纯模板渲染器 `compose_prompt.py`，19 个文件，未碰任何现有 skill。
3. 下一步是**二期 A**（搬 `imagegen/` 引擎 + 建 `md2publish-cover`，纯新增，不删旧 skill）。
4. 动手前先跑第三节的三条基线，全绿才继续。
5. 设计与计划不在本文里，见第二节的文档地图——**不要**在本文重复它们的内容。

## 零、文档地图

| 文档 | 管什么 |
|---|---|
| `docs/superpowers/specs/2026-08-09-md2publish-image-skills-design.md` | **设计的唯一真相源**（第二版）。skill 边界、资产 schema、执行链路、副作用边界、分期 |
| `docs/superpowers/plans/2026-08-09-shared-image-assets-phase1.md` | 一期的逐步实施计划（已执行完）。二期的计划**尚未编写** |
| `skills/_shared/README.md` | `_shared/` 怎么用、怎么跑测试、哪些是故意推到二期的 |
| `skills/_shared/presets/INDEX.md` | preset 与 dimensions 的**唯一发现入口**。选 preset 一律读它，别背名单 |
| 本文 | 跨会话的状态、教训、环境事实 |
| `docs/handoff/handoff.md` | 另一条线（主题库 / HTML 生成），与本文无交集 |

## 一、一期做完了什么

产物全在 `skills/_shared/`：2 个平台 profile、4 个 preset、5 个维度词表、`INDEX.md`、`asset_lib.py`、`compose_prompt.py`、3 个测试脚本、1 份 fixture brief、README。

git 状态请**自行重新推导**，不要信任写死的 SHA（本文提交本身就会改变 HEAD）：

```bash
git log --oneline --grep='^一期 T' -6     # 一期的六个任务 commit
git status -sb                            # 本地 main 与 origin/main 的差距
```

写作当时：一期六个 commit 已 fast-forward 进本地 `main`，**尚未 push**，`origin/main` 落后十余个 commit。分支 `design/md2publish-image-skills` 已删除（完全合并，可从任一一期 commit 重建）。

## 二、基线（动手前先跑，全绿才继续）

```bash
cd skills/_shared/scripts
./test-asset-schema.sh      # 期望：通过 13 项，失败 0 项
./test-compose-prompt.sh    # 期望：通过 11 项，失败 0 项
./test-platform-matrix.sh   # 期望：通过 8 项，失败 0 项（2 平台 × 4 preset）
```

外加确认没碰坏另一条线：

```bash
python3 skills/md2publish-article/scripts/test-theme-lib.py   # 期望：ok：0 条失败
```

矩阵测试是这条线**唯一防静默漂移**的东西，已实测有效：删掉某个 preset 模板里的 `{{PLATFORM_FRAME}}`，它会报「画幅未注入; 文字策略未注入;」。改了资产之后如果它还是全绿，先怀疑你没改到点上。

## 三、关键契约（踩过才写下来的，别再踩）

**机械层 / 语义层的分界**。`compose_prompt.py` 是纯模板渲染器：读 YAML、填占位符、写文件。它**不读文章原文、不做内容抽取、不调模型**。文章的语义部分由 agent 事先写成 **brief 文件**（"这张图要表达什么、主体是什么、放哪、alt 文本"），经 `--brief-file` 传入。样例：`scripts/fixtures/brief-sample.md`。这条边界是矩阵测试能脱离模型运行的原因，动它等于让一期的测试全部失效。

**占位符是固定白名单**：`PLATFORM_FRAME` / `PALETTE` / `RENDERING` / `LAYOUT` / `CONTENT`。模板里出现集合外的占位符**硬失败**，绝不原样输出——原样输出会让生成的图少掉一半约束，而且肉眼看不出来。

**文字策略的契约串**。`test-compose-prompt.sh` 与 `test-platform-matrix.sh` 都 grep `图上必须包含|图上不要出现标题文字`，而这两句由 `compose_prompt.py:render_platform_frame` 产生。改措辞要三处同改，否则测试会假绿或假红（一期执行时这里已经踩过一次：计划里 grep 的是「不放」，渲染器输出的是「不要」）。

**平台按 archetype 分槽，不支持就写 `unsupported`**，composer 遇到它硬失败不静默回退。当前：微信不支持 `series`，小红书不支持 `illustration`。新增 archetype 时每个平台都必须给出定义——`asset_lib._validate_platform` 会拦。

**preset 用排除制 `incompatible_platforms`，不用白名单。** `asset_lib` 会显式拒绝 `compatible_platforms` 字段。理由：白名单下加第 4 个平台要回头编辑每一个 preset，正是不手工维护共享资产的那个成本。

**`max_bytes` 一律整数字节**，不写 `2MB`。二期的 `compress.py` 直接消费，不做后缀解析。

**INDEX.md 必须同步。** 新增 preset 或维度值后不更新 `INDEX.md`，`test-asset-schema.sh` 直接 fail。

## 四、环境事实（都是实测的，会咬人）

- **Python 是 3.9.13**（anaconda3）。`dict | None` 这类 PEP 604 注解在 3.9 上 import 即 `TypeError`，所有脚本靠 `from __future__ import annotations` 工作。**新增脚本别漏这行。**
- PyYAML 6.0 已装，是本层唯一的第三方依赖。
- **`mv` 在这台机器上是交互式的**（覆盖时会停下来等 y/n，在自动化里表现为卡死）。脚本里用 `\cp -f`，别用 `mv`。
- **本仓库没有 CI、没有 git hooks、没有 `.github/`。** 所有测试靠手跑。`skills/_shared/README.md` 里那句"改完必须跑一遍"是**文档约束，不是自动闸门**——不要在任何文档里把它写成强制。
- **可能有另一个 agent 同时在这个仓库里工作**（一期执行期间就有，它在做主题普查那条线）。因此：只用显式路径 `git add`，**绝不 `git add -A` / `git commit -a`**；切分支前先看 `git status`；算"本次改了什么"时不要拿 `main` 当基线，用本次第一个 commit 的父提交。

## 五、语言约定（新规则，优先级高）

- **git commit message 与分支名一律英文**，跨所有项目生效，且**不因仓库既有历史是中文而放宽**。这条与 `CLAUDE.md` Rule 0 一致。
- 文档内容（`docs/`）、与用户的对话：中文。
- 注意：`main` 上已有的六条 `一期 T1`…`一期 T6` commit 是中文的，属规则生效前的遗留，未改写历史。**从下一个 commit 起必须英文。**

## 六、剩下的活（按 spec §15 的分期）

**二期 A（下一步，纯新增，无破坏性）**
- 从 `baoyu-skills/skills/baoyu-image-gen/` 搬入 `imagegen/`（12 个 provider，零第三方依赖，纯 `node:` + fetch）。注意 `codex-cli` provider 是经 `packages/baoyu-codex-imagegen` wrapper 间接 spawn `codex` 的，两层要一起搬或改写。
- 写 `compress.py`（sips → cwebp → ImageMagick 降级链）、`preflight.py`、`costs.yaml`。
- 建 `md2publish-cover`，写 `sync-shared.sh` / `check-shared-drift.sh` / `check.sh`（此时才有消费者）。
- **`md2publish-images` 原地保留**，两者并存。
- 完成判据：端到端产出一张微信封面并压到 2MB 内；手动 smoke（真调一次 provider）通过。
- 新引入 TypeScript 运行时依赖（bun / `npx -y bun`），要在 README 写明前置。

**二期 B（唯一有破坏性的一期，单 commit 便于 revert）**
- 删除 `md2publish-images`，改 spec §12 列出的**九处**引用。别信"四处"——`wechat-finetune/SKILL.md` 两处和 `docs/handoff/handoff.md` 三处极易漏。
- 完成判据：全仓库 grep 不到 `md2publish-images`。

**三期**
- `md2publish-visuals`（含 Markdown 回写门）与 `md2publish-diagram`（含 SVG→PNG 降级链）。
- **`visuals` 在 `md2publish-article` 的上游**，不是并行分支（spec §8）。它产出 `article.illustrated.md`，`md2publish-article` 的步骤 1 输入表必须认这个文件，否则它永远不被转换。

**一期故意没做、别当成遗漏的**：`bilibili.yaml`（B 站画幅与文字约定属未验证的外部知识，需先确认视频封面与专栏头图分别是什么规格，不猜）、vendor 脚本、`imagegen/`、`costs.yaml`。清单见 `skills/_shared/README.md` 末节。

## 七、建议调用的 skills

| 场景 | skill |
|---|---|
| 开始二期前 | `superpowers:writing-plans`（二期的实施计划尚未编写，spec 已就绪可直接喂给它） |
| 执行计划 | `superpowers:executing-plans`（内联，适合本仓库有其他 agent 在场的情况）或 `superpowers:subagent-driven-development`（无并发时更快） |
| 动任何设计决策前 | `superpowers:brainstorming`（本设计的两版都是这么产出的） |
| 二期 A 完成后、二期 B 之前 | `superpowers:requesting-code-review`（尤其做一次事实核查——一期的 spec 复审抓出 6 处事实错误，其中"悬空引用四处"实为九处） |
| 排查测试失败 | `superpowers:systematic-debugging` |
| 收尾分支 | `superpowers:finishing-a-development-branch` |

## 八、一期执行中修掉的计划缺陷（供二期写计划时参考）

三处，都属于"计划看着对、跑起来错"：

1. `asset_lib.py` 漏了 `from __future__ import annotations` —— 目标环境 Python 3.9 下 import 即崩。**写计划时要先确认运行时版本**。
2. 测试断言 grep 的字符串与实现输出不一致（「不放」vs「不要」），且同一契约在两个测试里写法不同。**同一契约串只该有一个定义处**。
3. 收尾检查用 `git diff main...HEAD` 判断"本次改了什么"，在有其他 agent 提交的分支上会误报。**基线取本次第一个 commit 的父提交**。
