# Handoff：图片能力线（cover / visuals / diagram）

最后更新：2026-08-11

本文只管**图片这条线**。主题库与 HTML 生成那条线在 `docs/handoff/handoff.md`，两者互不重叠，别读错。

## 快速接手入口

1. 目标：把 `md2publish-images` 拆成 `md2publish-cover` / `md2publish-visuals` / `md2publish-diagram` 三个 skill，并支持微信之外的平台（小红书、B 站）。
2. **二期 A、二期 B 均已完成并合进本地 `main`**：二期 A vendor 进 `imagegen/` 生图引擎（11 个 provider，D1 剔除了 codex-cli）、补齐 `compress.py` / `preflight.py` / `config.py` / `artifacts.py` 机械层、建成 `md2publish-cover` skill、`scripts/check.sh` 一条命令串起九项检查（第 6 项现在是 12 项）。二期 B 删除了 `md2publish-images`，spec §12 列出的**十一处**活引用全部改指向 `md2publish-cover`。**手动付费 smoke 仍未做**——见第六节。
3. 下一步是**三期**（`md2publish-visuals` + `md2publish-diagram`）。它的实施计划**尚未编写**。
4. 动手前先跑第二节的 `./scripts/check.sh`，全绿才继续。
5. 二期 A **没有留下已知未修缺陷**；收尾时补修的那处（`preflight.py` 对非 UTF-8 `.env` 抛栈）记在第六节末尾，留着是因为那类错误容易再犯。二期 B **故意留了一条 Minor 未修**：`skills/_shared/scripts/test-artifacts.sh` 第二处 sidecar 断言（"png 与 jpg 共写同一个 .json"）把 `artifacts.py` 的 stdout / stderr 与退出码一起丢掉了，所以一旦它因无关原因失败，浮上来的是"压缩产物没被记下来"这句误导性的消息——已验证它**仍会朝正确方向失败**（不是静默通过），只是诊断信息差。除此之外任务循环里没有别的未决项：另外三条 Minor 已由最终整支评审的修复波关掉。
6. git 状态一律**现查**，别信任何文档里写死的 SHA 或"领先/落后几个 commit"的结论——查法与两个坑见第一之二节。
7. 设计与计划不在本文里，见**第零节**的文档地图——**不要**在本文重复它们的内容。

## 零、文档地图

| 文档 | 管什么 |
|---|---|
| `docs/superpowers/specs/2026-08-09-md2publish-image-skills-design.md` | **设计的唯一真相源**（第三版）。skill 边界、资产 schema、执行链路、副作用边界、分期 |
| `docs/superpowers/plans/2026-08-09-shared-image-assets-phase1.md` | 一期的逐步实施计划（已执行完） |
| `docs/superpowers/plans/2026-08-10-image-phase2a.md` | 二期 A 的逐步实施计划（已执行完）。开头有 D1–D4 偏离表与 Global Constraints，写三期的计划时把这套约束照抄过去 |
| `docs/superpowers/plans/2026-08-11-image-phase2b.md` | 二期 B 的逐步实施计划（已执行完）。开头有 D5–D10 偏离表与 Global Constraints——两份计划里更新的一份，写三期的计划时该照抄这份，不是二期 A 那份 |
| `skills/_shared/scripts/imagegen/VENDOR.md` | vendor 来源、排除清单、与上游只差的两行、重新同步步骤 |
| `skills/_shared/README.md` | `_shared/` 怎么用、怎么跑测试、哪些是故意没做的（末节「还没做的事」，二期做完后现在指向三期） |
| `skills/_shared/presets/INDEX.md` | preset 与 dimensions 的**唯一发现入口**。选 preset 一律读它，别背名单 |
| 本文 | 跨会话的状态、教训、环境事实 |
| `docs/handoff/handoff.md` | 另一条线（主题库 / HTML 生成），与本文无交集 |

## 一、一期做完了什么

产物全在 `skills/_shared/`：2 个平台 profile、4 个 preset、5 个维度词表、`INDEX.md`、`asset_lib.py`、`compose_prompt.py`、3 个测试脚本、1 份 fixture brief、README。

分支 `design/md2publish-image-skills` 已删除（完全合并，可从任一一期 commit 重建）。

## 一之二、git 状态怎么查（别信任何写死的 SHA）

**本文每次提交都会改变 HEAD，所以这里不写"当前进度"类的 SHA，只写怎么自己查。**
（已完成的期的 commit SHA 是不变的历史锚点，出现在命令注释里是为了说明某条 grep 会误抓什么，不是进度结论。）

```bash
git log --oneline --grep='^一期 T' -6              # 一期的六个任务 commit（中文，规则生效前的遗留）

# 各期的计划 commit：**按计划文件的路径找，别用 --grep**。
# message 里根本没有期号——二期 A 是 "docs: add phase 2A implementation plan for image
# skills"（`--grep='image-phase2a'` 零命中），二期 B 干脆就叫 "add image plan"；
# 而 `--grep='image-phase2b'` 命中的是后来在正文里引用过计划文件名的 handoff commit，
# 不是计划本身，拿它当句柄会指错人。
git log --oneline -- docs/superpowers/plans/2026-08-10-image-phase2a.md   # 二期 A
git log --oneline -- docs/superpowers/plans/2026-08-11-image-phase2b.md   # 二期 B
P2B=$(git log --format=%H -- docs/superpowers/plans/2026-08-11-image-phase2b.md | tail -1)

# 二期 A 的任务 commit（英文）。**必须用 "$P2B^" 截断**：不截断的话，二期 B 的 T1
# `0f79f78 feat(shared): record final artifact filename in sidecar` 会跟着 ^feat(shared)
# 一起出来，被误读成二期 A 的产物。
git log --oneline --grep='^feat(shared)' --grep='^feat(cover)' --grep='^feat(scripts)' --grep='^fix(image)' "$P2B^"

git status -sb                                     # 本地 main 与 origin/main 的差距
git log --oneline origin/main..main                # 还没推上去的
```

两条会误导人的事实，查之前先知道：

- **`main` 上是两条线交织的。** 另一个 agent（主题库 / contrast 审计那条线，产物在
  `skills/md2publish-article/`、`docs/handoff.md`、`docs/theme-design-lessons.md`）在同一个
  checkout 里并发提交，它的 commit 夹在我们的 commit 之间。算"图片线本次改了什么"时
  **不能**用连续区间，要按路径过滤——而且**路径清单必须覆盖整条线的 footprint**：
  只列 `_shared` / `md2publish-cover` / `scripts` / 本文这四项，会漏掉本线改过的
  `md2publish-article`、`md2publish-draft`、`wechat-finetune`、`skills/README.md`
  与 `docs/superpowers/` 下的 spec 和计划（二期 B 的 14 条里只有 7 条会被捞到）：
  ```bash
  git log --oneline -- \
    skills/_shared skills/md2publish-cover skills/md2publish-draft \
    skills/md2publish-article/SKILL.md skills/wechat-finetune skills/README.md \
    skills/md2publish-images scripts \
    docs/handoff/handoff-image.md docs/handoff/handoff.md \
    docs/superpowers/specs/2026-08-09-md2publish-image-skills-design.md \
    docs/superpowers/plans/2026-08-11-image-phase2b.md
  ```
  只看**二期 B**时，给同一串路径加上 range（二期 B 的任务 commit 没有共同 message
  前缀，`--grep` 抓不全，只能用 range；`$P2B` 见上面那段）：
  ```bash
  git log --oneline "$P2B^..HEAD" -- <上面那串路径>
  ```
  这条会带出三行**不属于图片线**的 commit，别当成本线的产出：`6b4cea6`（另一条线的
  计划 commit，我们的删除被它卷走了，来历见第六节）、`4877c04` 与 `bd34df4`（另一条线
  自己改 `docs/handoff/handoff.md`）。剩下的就是二期 B 的计划 commit 加本期全部
  commit（任务 + 评审修复，清单见第六节）。
  只列 `skills/md2publish-*` 而不列 `docs/handoff/handoff.md` 的话，还会漏掉
  `63859f8`——它只动了那一个文件。
- **那个 agent 会 push，且会顺带把我们的 commit 一起带上远程。** 二期 A 的绝大部分
  在没人主动推的情况下就已经到 `origin/main` 了。所以"本地领先远程"这件事随时在变，
  每次都重新查，别照抄任何一份文档里的结论（包括本文）。

## 二、基线（动手前先跑，全绿才继续）

```bash
./scripts/check.sh
```

一条命令跑九项检查，期望全部 ✓、末尾打印「全部通过。」：

1. 资产 schema + `costs.yaml`（18 项，含 provider 名单四处一致的交叉校验）
2. 渲染器 + 占位符白名单（11 项）
3. 平台 × archetype × preset 矩阵（8 组合）
4. 压缩不超限（8 项）
5. preflight + config 自检（21 项）
6. 产物落盘规则：重跑保护 + sidecar（12 项）
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
- 写好 `compress.py`（sips → magick，见 D3）、`preflight.py`、`config.py`、`artifacts.py`、`costs.yaml`。实测（**含最终评审七项修复后的数字**）：资产 schema + costs **18 项**、压缩不超限 **8 项**、preflight + config **21 项**、产物落盘规则 **10 项**，全绿——这是二期 A 收尾时测到的数字。**二期 B 的 T1 又把它从 10 项改成了 12 项**（加了 `image` 字段的两条断言，见下面「二期 B」那块），当前基线是 12 项，见第二节。
- 建成 `md2publish-cover`；`shared-manifest.sh` / `sync-shared.sh` / `check-shared-drift.sh` / `scripts/check.sh` 全部写好并跑通，vendor 同步与漂移实测 **9 项**全绿。
- **`md2publish-images` 原地保留**，两者并存，本期未改它一个字。
- 完成判据两条分开看：spec §13 五项全绿——**已验证**（`./scripts/check.sh` 九项全 ✓，见第二节）；端到端产出一张微信封面并压到 2MB 内的**手动付费 smoke——未做**。本机 `preflight.py` 实测「一个 provider 凭证都没配置」，无法真调用付费 API，这一步只能留给配好凭证的会话去跑，步骤见 spec §7 / `md2publish-cover/SKILL.md`。**九项检查全绿不等于端到端验证过——没跑就是没跑，别混着说。**
- 已引入 TypeScript 运行时依赖（bun），README 前置已写明。

**收尾时补修的一处（已修，记在这里是因为它是个容易再犯的类型错误）**

`preflight.py` 读 `.env` 的那段原本只 `except OSError`，而 `UnicodeDecodeError` 是
`ValueError` 的子类、**不是** `OSError`。于是一个存成 UTF-16 / GBK、或只是混进一个
坏字节的 `.baoyu-skills/.env`，会让 `preflight.py` 抛栈退出 1——同时违反它自己的三条
承诺：函数 docstring 说"读不到就当空文件，不报错"；模块契约是**只报告、不阻塞**
（`md2publish-cover/SKILL.md` 步骤 1 依赖它永远退出 0）；而它要镜像的 JS 引擎用
`readFile(p,"utf8")`，坏字节会被替换成 U+FFFD 后照常读下去——同一个文件，引擎读得动，
我们的 preflight 却崩。

已改成 `read_text(encoding="utf-8", errors="replace")`（贴引擎行为，坏字节不至于让整份
文件作废），并补了一条**用真的非 UTF-8 字节写文件**（不是 mock）的断言，`test-preflight.py`
因此从 20 项变 **21 项**。改完重跑了 `sync-shared.sh` 同步 vendor 副本。回归复现：

```bash
T=$(mktemp -d); mkdir -p "$T/.baoyu-skills"
printf 'OPENAI_API_KEY=sk-\xff\xfe-bad\n' > "$T/.baoyu-skills/.env"
(cd "$T" && python3 <仓库>/skills/_shared/scripts/preflight.py; echo "exit=$?")
rm -rf "$T"
```

修之前 `exit=1` + `UnicodeDecodeError`；修之后 `exit=0`，且 `openai` 正常出现在已配置清单里。

**可复用的教训**：`except OSError` 挡不住解码错误。凡是"读文件失败就当空"的兜底，
都要问一句——编码错误算不算失败的一种？在这个仓库里还要多问一句：**我们的 Python
层要镜像的那个 JS 引擎，遇到同样的输入是怎么做的？** 两边行为不一致，用户会遇到
"引擎能跑、preflight 说没配置"这种最难查的矛盾。

**二期 B（已完成，唯一有破坏性的一期，跑成了 T1–T8 八个 per-task commit，不是单 commit）**

本期在 `main` 上是八个逐任务 commit，第一个是 `0f79f78`（T1：sidecar 记录最终产物
文件名），最后一个是 `4c8548c`（T8：删除 + 本文的完成记录）。

**八个之外还有评审修复 commit，算 footprint 时别只数这八个**：T2 之后的 `a6e45e3`、
T7 之后的 `63859f8`，加上最终整支评审的修复波 `a0acc2f`、`9ed98ce`、`c0c62ce`、
`e2af7c4` 及其后续——任务 + 评审修复合起来，本期到最终评审为止是 **14 条**（此后每补
一条修复就多一条）。准确清单一律用第一之二节那条带 range 的 `git log` 现查。

`skills/md2publish-images/SKILL.md` 的删除**不在**这八个 commit 的任何一个里：
执行到 T8 时，一个并发会话跑了一次不带 pathspec 的 `git commit`，提交的是整个
暂存区，把本次已经 `git rm` 好、还没来得及提交的删除一起带走了，于是删除被记在
了那个会话的 `6b4cea6`（"docs(plan): implementation plan for the background-size
strip gate"）名下。没有工作丢失，只是归属错了。历史故意没有改写——`main` 上另一
个会话在活跃提交，`reset` / `revert` 有撞坏它的风险。

要撤销这次删除，正确命令是（已用 `git show 6b4cea6^:skills/md2publish-images/SKILL.md`
验证过该版本能读到文件，未在工作区真的复原过）：

```bash
git checkout 6b4cea6^ -- skills/md2publish-images/
```

**可迁移的教训**：`git add <路径>` 管不住 `git commit`——并发会话下要么用
`git commit -- <路径>`，要么在 commit 前紧挨着再看一次 `git status`。

> ⚠️ **`md2publish-draft` 的既成契约：不许硬编 `assets/<platform>/00-cover.png`。**
>
> 压缩**不是替换，是新增**。`md2publish-cover` 步骤 7 压完之后，超限的原图
> `00-cover.png` 和压缩产物 `00-cover.jpg` **两个文件同时存在**，而 `.png` 恰好占着
> 那个看起来最"正规"的名字。若 draft skill 指向 `.png`，就等于把
> "推草稿箱时才发现封面超过 2MB" 这个失败模式原样请回来——而把压缩硬塞进
> 二期 A 的封面流程，全部目的就是消灭它。
>
> 正确做法：**读 sidecar `assets/<platform>/00-cover.json` 里记的 `image` 字段**——
> 最终产物的**文件名**（不是完整路径），要在 sidecar 自己所在的目录下解析。它是二期
> B 的 T1（commit `0f79f78`）补上的：sidecar 路径本身是 `image.with_suffix(".json")`，
> 所以压缩产物 `00-cover.jpg` 与原图 `00-cover.png` 会算出**同一个** `00-cover.json`，
> 文件名区分不了两者，只有这个字段能。未超限时它是 `.png`，超限时是 `.jpg`——两种
> 情况都由 sidecar 说了算，调用方不需要自己判断。契约写在 `skills/md2publish-cover/SKILL.md`
> 的步骤 7、步骤 8 与「产物布局」三处，`md2publish-draft` 已按这条契约读取。

- 删除了 `md2publish-images`，改完 spec §12 列出的**十一处**活引用（T2 把矛盾的
  "七处/九处"更正为十一处——以表格为准；二期 A 新建 `md2publish-cover/SKILL.md`
  与 `_shared/README.md` 时又带出两处新的，加起来是十一）。全部改指向 `md2publish-cover`。
- 完成判据是 D10 的**范围版**，判的是"没有活引用"，不是"grep 不到这串字符"：
  ```bash
  grep -rn "md2publish-images" skills/         # 承重的那一半：必须无输出，rc=1
  grep -n "md2publish-images" docs/handoff/handoff.md
  ```
  `skills/` 必须完全干净——这是判据真正守护的东西，实测确实无输出。
  `docs/handoff/handoff.md` 目前会命中两行，但都在另一条线自己的提交事故记录里
  （见上面"删除不在这八个 commit 里"那段的来历），是**讲那次删除的散文**，不是指向
  该 skill 的活引用。所以下次跑这条 grep，看到 `docs/handoff/handoff.md` 里这两行
  历史记录不算回归，别误判成有人又写了活引用。
  `docs/superpowers/specs/`、`docs/superpowers/plans/`、本文、`.superpowers/` 下仍能
  grep 到——那也是执行记录，故意保留，别为了让全局 `grep -r .` 干净去改它们。

**二期 B 的教训**：spec、`md2publish-cover/SKILL.md`、本文的硬约束三处都在写"读 sidecar
里记的路径"，而 `artifacts.py` 写出的 sidecar 曾经根本没有路径字段——一条契约被反复
引用不等于它被实现过。完整版见第八节「二期 B（一条）」。

**三期**
- `md2publish-visuals`（含 Markdown 回写门）与 `md2publish-diagram`（含 SVG→PNG 降级链）。
- **`visuals` 在 `md2publish-article` 的上游**，不是并行分支（spec §8）。它产出 `article.illustrated.md`，`md2publish-article` 的步骤 1 输入表必须认这个文件，否则它永远不被转换。

**一期故意没做、别当成遗漏的**：`bilibili.yaml`（B 站画幅与文字约定属未验证的外部知识，需先确认视频封面与专栏头图分别是什么规格，不猜）、vendor 脚本、`imagegen/`、`costs.yaml`。清单见 `skills/_shared/README.md` 末节。

## 七、建议调用的 skills

| 场景 | skill |
|---|---|
| 开始三期前 | `superpowers:writing-plans`（三期的实施计划尚未编写。输入是 spec §15 的三期范围，加 `md2publish-visuals`（含 Markdown 回写门）与 `md2publish-diagram`（含 SVG→PNG 降级链）各自的要求；Global Constraints 照抄 `docs/superpowers/plans/2026-08-11-image-phase2b.md` 开头那套——就像那份计划当初照抄二期 A 的一样） |
| 执行计划 | `superpowers:subagent-driven-development`（二期 A 就是这么跑完 8 个任务的，在有并发 agent 的情况下也没出事——关键是每个任务只用显式路径 `git add`）或 `superpowers:executing-plans`（内联） |
| 动任何设计决策前 | `superpowers:brainstorming`（本设计的两版都是这么产出的） |
| 每一期收尾 | `superpowers:requesting-code-review`。**必须做一次整支评审，逐任务评审替代不了它**——理由见第八节末尾。也顺带做事实核查：一期的 spec 复审抓出 6 处事实错误，其中"悬空引用四处"实为九处 |
| 排查测试失败 | `superpowers:systematic-debugging` |
| 收尾分支 | `superpowers:finishing-a-development-branch` |

## 八、执行中修掉的计划缺陷（写三期的计划前先读这节）

全都属于同一族：**计划看着对、跑起来错**。一期三条、二期 A 四条、二期 B 一条；二期 A
那四条里有三条是单个任务的评审看不出来、只有跨任务视角才暴露的。

**一期（三条）**

1. `asset_lib.py` 漏了 `from __future__ import annotations` —— 目标环境 Python 3.9 下 import 即崩。**写计划时要先确认运行时版本**。
2. 测试断言 grep 的字符串与实现输出不一致（「不放」vs「不要」），且同一契约在两个测试里写法不同。**同一契约串只该有一个定义处**。
3. 收尾检查用 `git diff main...HEAD` 判断"本次改了什么"，在有其他 agent 提交的分支上会误报。**基线取本次第一个 commit 的父提交**。

**二期 A（四条）**

4. **检查项的顺序本身可以让检查失效。** 计划里 `check.sh` 把「vendor 同步与漂移」排在
   「shared 漂移检查」**之前**，而前者开头就跑一遍 `sync-shared.sh`——等于每次先把漂移
   抹掉再去检查漂移，后者从此永远不可能失败，spec §13 第 5 项在入口脚本里成了摆设。
   八个任务各自的评审全绿，是最终的整支评审才抓到的。
   **教训：一组检查放进同一个入口脚本时，要问"前一项会不会改变后一项要观察的状态"。**
5. **写 bash 断言消息时，变量后面紧跟中文标点会炸。** `$var）` 在本机 bash 3.2.57 下
   变量名被解析坏，`set -u` 直接报假的 unbound variable。计划里三个测试脚本都中招。
   **一律写 `${var}`**，见第四节。
6. **"清理临时文件"很容易顺手删掉别人的东西。** 计划里 `compress.py` 失败时 unlink
   整个 ladder 的输出，没区分哪些是它自己写的、哪些是上一轮花钱生成后本就存在的，
   于是一次压缩失败会连带毁掉上一次的好产物。**写清理逻辑时，只删自己创建的路径，
   并且写一条"既有文件必须存活"的断言**——原来的测试跑过这条路径却看不见问题，
   因为它紧接着就重建了 fixture。
7. **测试脚本不要改真实工作区。** 计划里的漂移测试直接往被 git 跟踪的 vendor 副本里
   追加探针行，没有 `trap` 恢复；在有并发 agent 的仓库里，中途崩掉就留下污染。
   改成 `mktemp -d` 沙箱 + `trap ... EXIT INT TERM` 之后才安全。

**二期 B（一条）**

8. **文档三处承诺的契约，代码里一处都没实现。** spec §12、`md2publish-cover/SKILL.md`
   步骤 8、handoff 第六节的硬约束，全都写着"读 sidecar 里记的路径"，而 `artifacts.py`
   写出的 sidecar **根本没有路径字段**——只有 `bytes`。更糟的是 sidecar 路径是
   `image.with_suffix(".json")`，压缩产物 `.jpg` 与原图 `.png` 算出来**是同一个
   `00-cover.json`**，文件名本身也区分不了。照 spec 原样执行二期 B，只会退回硬编
   `00-cover.png`，正是二期 A 要消灭的失败模式。
   **教训：一条契约被多份文档反复引用，不等于它被实现过。跨组件的"谁读谁"改动，
   动手前先去读被读那一方的代码，确认它真的写了那个字段。**

**给三期的一条方法论**：二期 A 的八个任务全部通过了各自的评审，最终整支评审仍然
抓出 1 个 Critical + 6 个 Important，全部是**跨组件**的（顺序依赖、四处 provider 名单
不同步、文档里两套路径无法在同一个 cwd 下成立、sidecar 记录的 provider 与引擎实际
选的不是一回事）。**逐任务评审不能替代一次整支评审。**
