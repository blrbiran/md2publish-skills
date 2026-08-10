# Handoff：图片能力线（cover / visuals / diagram）

最后更新：2026-08-10

本文只管**图片这条线**。主题库与 HTML 生成那条线在 `docs/handoff/handoff.md`，两者互不重叠，别读错。

## 快速接手入口

1. 目标：把 `md2publish-images` 拆成 `md2publish-cover` / `md2publish-visuals` / `md2publish-diagram` 三个 skill，并支持微信之外的平台（小红书、B 站）。
2. **二期 A 已完成并合进本地 `main`**：vendor 进 `imagegen/` 生图引擎（11 个 provider，D1 剔除了 codex-cli）、补齐 `compress.py` / `preflight.py` / `config.py` / `artifacts.py` 机械层、建成 `md2publish-cover` skill、`scripts/check.sh` 一条命令串起九项检查。纯新增，`md2publish-images` 原地未动。**手动付费 smoke 未做**——见第六节。
3. 下一步是**二期 B**（删除 `md2publish-images`，改 spec §12 列出的引用，唯一有破坏性的一期）。
4. 动手前先跑第二节的 `./scripts/check.sh`，全绿才继续。
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
./scripts/check.sh
```

一条命令跑九项检查，期望全部 ✓、末尾打印「全部通过。」：

1. 资产 schema + `costs.yaml`（18 项，含 provider 名单四处一致的交叉校验）
2. 渲染器 + 占位符白名单（11 项）
3. 平台 × archetype × preset 矩阵（8 组合）
4. 压缩不超限（8 项）
5. preflight + config 自检（20 项）
6. 产物落盘规则：重跑保护 + sidecar（10 项）
7. imagegen 引擎（`bun test`，97 pass / 0 fail / 12 files）
8. shared 漂移检查（`md2publish-cover/shared/` 与 `_shared/` 是否一致）
9. vendor 同步与漂移（9 项）

**第 8、9 项的先后顺序是有意的，别调换。** 第 9 项开头就跑一遍 `sync-shared.sh`；
它如今在临时沙箱副本里跑、不碰工作区，但只要有谁把它改回原地跑，真实漂移就会在
第 8 项看见它之前被冲掉，第 8 项从此永远不可能失败。design §4.3 明说漂移是
vendoring 唯一的真实失败模式，且**绝不能靠 re-sync 解决**。

外加确认没碰坏另一条线（`check.sh` 不包含这一项，得单跑）：

```bash
python3 skills/md2publish-article/scripts/test-theme-lib.py   # 期望：ok：0 条失败
```

矩阵测试（第 3 项）是这条线**唯一防静默漂移**的东西，已实测有效：删掉某个 preset 模板里的 `{{PLATFORM_FRAME}}`，它会报「画幅未注入; 文字策略未注入;」。改了资产之后如果它还是全绿，先怀疑你没改到点上。

## 三、关键契约（踩过才写下来的，别再踩）

**机械层 / 语义层的分界**。`compose_prompt.py` 是纯模板渲染器：读 YAML、填占位符、写文件。它**不读文章原文、不做内容抽取、不调模型**。文章的语义部分由 agent 事先写成 **brief 文件**（"这张图要表达什么、主体是什么、放哪、alt 文本"），经 `--brief-file` 传入。样例：`scripts/fixtures/brief-sample.md`。这条边界是矩阵测试能脱离模型运行的原因，动它等于让一期的测试全部失效。

**占位符是固定白名单**：`PLATFORM_FRAME` / `PALETTE` / `RENDERING` / `LAYOUT` / `CONTENT`。模板里出现集合外的占位符**硬失败**，绝不原样输出——原样输出会让生成的图少掉一半约束，而且肉眼看不出来。

**文字策略的契约串**。`test-compose-prompt.sh` 与 `test-platform-matrix.sh` 都 grep `图上必须包含|图上不要出现标题文字`，而这两句由 `compose_prompt.py:render_platform_frame` 产生。改措辞要三处同改，否则测试会假绿或假红（一期执行时这里已经踩过一次：计划里 grep 的是「不放」，渲染器输出的是「不要」）。

**平台按 archetype 分槽，不支持就写 `unsupported`**，composer 遇到它硬失败不静默回退。当前：微信不支持 `series`，小红书不支持 `illustration`。新增 archetype 时每个平台都必须给出定义——`asset_lib._validate_platform` 会拦。

**preset 用排除制 `incompatible_platforms`，不用白名单。** `asset_lib` 会显式拒绝 `compatible_platforms` 字段。理由：白名单下加第 4 个平台要回头编辑每一个 preset，正是不手工维护共享资产的那个成本。

**`max_bytes` 一律整数字节**，不写 `2MB`。二期的 `compress.py` 直接消费，不做后缀解析。

**INDEX.md 必须同步。** 新增 preset 或维度值后不更新 `INDEX.md`，`test-asset-schema.sh` 直接 fail。

**二期 A 与 spec 的四处偏离**（已确认，实施时照计划走，完整论证见
`docs/superpowers/plans/2026-08-10-image-phase2a.md` 开头的表）：

| # | spec 怎么说 | 实际怎么做 | 为什么 |
|---|---|---|---|
| D1 | §4.1：`codex-cli` 经 wrapper 间接 spawn，"两层要一起搬" | 首批不搬 codex-cli，删 `providers/codex-cli.ts` + 测试，`loadProviderModule` 里改成硬失败 | 用户决策（2026-08-10）。wrapper 已内联在 `codex-imagegen/`，不搬 = 少 9 个文件、少一层 spawn |
| D2 | §9：单张最多 2 次计费尝试 | vendor 时把 `main.ts` 的 `MAX_ATTEMPTS` 由 `3` 改成 `2` | 引擎默认重试 3 次，超时类错误可能每次都已计费；已实测该常量无测试断言，改后仍 97 pass |
| D3 | §4/§11：压缩降级链 `sips → cwebp → ImageMagick` | 改成 `sips → magick`，`cwebp` 需显式 `--allow-webp` 才启用 | `cwebp` 只产出 WebP，目标平台是否接受属未核实的外部知识；默认产出 JPEG，不静默交付可能用不了的格式 |
| D4 | §4.3 vendor 清单没列 `asset_lib.py` | 清单里加上 `scripts/asset_lib.py` | 它是 `compose_prompt.py` / `artifacts.py` 的硬 import 依赖，不带上跑不起来 |

## 四、环境事实（都是实测的，会咬人）

- **Python 是 3.9.13**（anaconda3）。`dict | None` 这类 PEP 604 注解在 3.9 上 import 即 `TypeError`，所有脚本靠 `from __future__ import annotations` 工作。**新增脚本别漏这行。**
- PyYAML 6.0 已装，是本层唯一的第三方依赖。
- **`mv` 在这台机器上是交互式的**（覆盖时会停下来等 y/n，在自动化里表现为卡死）。脚本里用 `\cp -f`，别用 `mv`。
- **本仓库没有 CI、没有 git hooks、没有 `.github/`。** 所有测试靠手跑。`skills/_shared/README.md` 里那句"改完必须跑一遍"是**文档约束，不是自动闸门**——不要在任何文档里把它写成强制。
- **可能有另一个 agent 同时在这个仓库里工作**（一期执行期间就有，它在做主题普查那条线）。因此：只用显式路径 `git add`，**绝不 `git add -A` / `git commit -a`**；切分支前先看 `git status`；算"本次改了什么"时不要拿 `main` 当基线，用本次第一个 commit 的父提交。
- **这台机器的 bash 是 GNU bash 3.2.57。** `$var` 后面紧跟全角标点（`）`、`：`等）会破坏变量名解析，在 `set -u` 下直接报错。二期 A 已踩过两次。写含中文提示的脚本时一律用 `${var}`，别用裸 `$var`。
- **vendor 进来的 `imagegen/` 与上游只差两行**，都在 `main.ts`：`loadProviderModule()` 里 `codex-cli` 分支改成硬失败（D1），`MAX_ATTEMPTS` 从 `3` 改成 `2`（D2）。除这两处外逐字与上游一致，可直接 `diff`。细节与重新同步步骤见 `skills/_shared/scripts/imagegen/VENDOR.md`。

## 五、语言约定（新规则，优先级高）

- **git commit message 与分支名一律英文**，跨所有项目生效，且**不因仓库既有历史是中文而放宽**。这条与 `CLAUDE.md` Rule 0 一致。
- 文档内容（`docs/`）、与用户的对话：中文。
- 注意：`main` 上已有的六条 `一期 T1`…`一期 T6` commit 是中文的，属规则生效前的遗留，未改写历史。**从下一个 commit 起必须英文。**

## 六、剩下的活（按 spec §15 的分期）

**二期 A（已完成，纯新增，无破坏性）**
- 从 `baoyu-skills/skills/baoyu-image-gen/` 搬入 `imagegen/`（11 个 provider，`codex-cli` 按 D1 剔除；零第三方依赖，纯 `node:` + fetch）。`bun test` 实测 **97 pass / 0 fail，12 个文件**。
- 写好 `compress.py`（sips → magick，见 D3）、`preflight.py`、`config.py`、`artifacts.py`、`costs.yaml`。实测（**含最终评审七项修复后的数字**）：资产 schema + costs **18 项**、压缩不超限 **8 项**、preflight + config **20 项**、产物落盘规则 **10 项**，全绿。
- 建成 `md2publish-cover`；`shared-manifest.sh` / `sync-shared.sh` / `check-shared-drift.sh` / `scripts/check.sh` 全部写好并跑通，vendor 同步与漂移实测 **9 项**全绿。
- **`md2publish-images` 原地保留**，两者并存，本期未改它一个字。
- 完成判据两条分开看：spec §13 五项全绿——**已验证**（`./scripts/check.sh` 九项全 ✓，见第二节）；端到端产出一张微信封面并压到 2MB 内的**手动付费 smoke——未做**。本机 `preflight.py` 实测「一个 provider 凭证都没配置」，无法真调用付费 API，这一步只能留给配好凭证的会话去跑，步骤见 spec §7 / `md2publish-cover/SKILL.md`。**九项检查全绿不等于端到端验证过——没跑就是没跑，别混着说。**
- 已引入 TypeScript 运行时依赖（bun），README 前置已写明。

**二期 B（下一步，唯一有破坏性的一期，单 commit 便于 revert）**

> ⚠️ **给二期 B 的硬约束：`md2publish-draft` 绝不许硬编 `assets/<platform>/00-cover.png`。**
>
> 压缩**不是替换，是新增**。`md2publish-cover` 步骤 7 压完之后，超限的原图
> `00-cover.png` 和压缩产物 `00-cover.jpg` **两个文件同时存在**，而 `.png` 恰好占着
> 那个看起来最"正规"的名字。二期 B 若把 draft skill 指向 `.png`，就等于把
> "推草稿箱时才发现封面超过 2MB" 这个失败模式原样请回来——而把压缩硬塞进
> 二期 A 的封面流程，全部目的就是消灭它。
>
> 正确做法：**读 sidecar `assets/<platform>/00-cover.json` 里记的路径**（它永远指向
> 最终产物），或直接消费 `compress.py` 打印的那个路径。未超限时该路径就是 `.png`，
> 超限时是 `.jpg`——两种情况都由 sidecar 说了算，调用方不需要自己判断。
> 契约写在 `skills/md2publish-cover/SKILL.md` 的步骤 7、步骤 8 与「产物布局」三处。

- 删除 `md2publish-images`，改 spec §12 列出的**九处**引用。别信"四处"——`wechat-finetune/SKILL.md` 两处和 `docs/handoff/handoff.md` 三处极易漏。
- **动手第一步**：spec §12 正文首句写的是"留下**七处**悬空引用"，但其下表格是 **9 行**，§16 修订记录写的是"从四处更正为九处"——三个数字互相矛盾。**以表格为准**：先把 §12 正文那句话改成"九处"，再照表格逐条改，别把正文的"七处"当真数抄一遍漏掉两处。
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
