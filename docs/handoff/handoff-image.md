# Handoff：图片能力线（cover / visuals / diagram）

最后更新：2026-08-19

本文只管**图片这条线**。主题库与 HTML 生成那条线在 `docs/handoff/handoff.md`，两者互不重叠，别读错。

## 快速接手入口

1. 目标：把 `md2publish-images` 拆成 `md2publish-cover` / `md2publish-visuals` / `md2publish-diagram` 三个 skill，并支持微信之外的平台（小红书、B 站）。**三期做完之后，这个目标已经达成**——三个 skill 全部建成。
2. **一期、二期 A、二期 B、三期全部完成并合进本地 `main`**：二期 A vendor 进 `imagegen/` 生图引擎、补齐 `compress.py` / `preflight.py` / `config.py` / `artifacts.py` 机械层、建成 `md2publish-cover`。二期 B 删除了 `md2publish-images`，spec §12 列出的**十一处**活引用全部改指向 `md2publish-cover`。三期建成 `md2publish-visuals`（含 Markdown 回写门）与 `md2publish-diagram`（含 SVG→PNG 降级链），并把 `visuals` 接进 `md2publish-article` 的上游；`scripts/check.sh` 从二期的 9 项长大到**当前的 12 项**。二期 A、二期 B、三期**都跑过整支评审并已执行完毕**：二期 A 是 1 Critical + 6 Important，二期 B 是 4 Important，三期是 **0 Critical + 6 Important**（全部跨组件问题，逐任务评审看不见）；三期评审详情见第六节「三期」小节与第八节。
3. **手动付费 smoke 现在欠两次，不是一次**：`cover`（二期起欠）与 `visuals`（三期新欠）各有一次"真调 provider 生一张图"的 smoke 从未跑过——本机没有任何 provider 凭证。`diagram` 是唯一的例外，它零成本，端到端**已经真跑过**。三者不要混着说，完整口径见第六节。
4. **下一步**：三期留下的 6 项边角**已在 2026-08-19 全部清掉**（含一次否定断言扫尾，逐条见第六节「三期」小节末尾）。仍然欠着的只剩两样，且都不是本机能推进的：`bilibili.yaml`（B 站画幅属未验证的外部知识，见第六节末尾）、配好凭证后要补跑的两次付费 smoke（`cover` + `visuals`）。**spec §15 定义的范围到三期为止，没有排定中的下一期。**
5. 动手前先跑第二节的 `./scripts/check.sh`，全绿（或按 SKIPPED 语义部分跳过）才继续。
6. 二期 A **没有留下已知未修缺陷**；收尾时补修的那处（`preflight.py` 对非 UTF-8 `.env` 抛栈）记在第六节末尾，留着是因为那类错误容易再犯。二期 B **故意留了一条 Minor 未修**：`skills/_shared/scripts/test-artifacts.sh` 第二处 sidecar 断言（"png 与 jpg 共写同一个 .json"）把 `artifacts.py` 的 stdout / stderr 与退出码一起丢掉了，所以一旦它因无关原因失败，浮上来的是"压缩产物没被记下来"这句误导性的消息——已验证它**仍会朝正确方向失败**（不是静默通过），只是诊断信息差。三期**没有留下已知未修缺陷**——两个真 bug（见第八节）都在收尾前修掉并重新验证过。三期整支评审之后另外裁定了 **6 项**"可以留到下一期"的已知项（非缺陷，是评审时明确决定不在本期修的边角情况）——**这 6 项已在 2026-08-19 全部做完**，逐条的修法与验证方式、以及同批做的否定断言扫尾结果，见第六节「三期」小节末尾。
7. git 状态一律**现查**，别信任何文档里写死的 SHA 或"领先/落后几个 commit"的结论——查法与两个坑见第一之二节。
8. 设计与计划不在本文里，见**第零节**的文档地图——**不要**在本文重复它们的内容。

## 零、文档地图

| 文档 | 管什么 |
|---|---|
| `docs/superpowers/specs/2026-08-09-md2publish-image-skills-design.md` | **设计的唯一真相源**（第三版）。skill 边界、资产 schema、执行链路、副作用边界、分期 |
| `docs/superpowers/plans/2026-08-09-shared-image-assets-phase1.md` | 一期的逐步实施计划（已执行完） |
| `docs/superpowers/plans/2026-08-10-image-phase2a.md` | 二期 A 的逐步实施计划（已执行完）。开头有 D1–D4 偏离表与 Global Constraints，写三期的计划时把这套约束照抄过去 |
| `docs/superpowers/plans/2026-08-11-image-phase2b.md` | 二期 B 的逐步实施计划（已执行完）。开头有 D5–D10 偏离表与 Global Constraints——两份计划里更新的一份，写三期的计划时该照抄这份，不是二期 A 那份 |
| `docs/superpowers/plans/2026-08-11-image-phase3.md` | 三期的逐步实施计划（已执行完）。开头有 D11–D17 偏离表与 Global Constraints，已全部折回 spec |
| `skills/_shared/scripts/imagegen/VENDOR.md` | vendor 来源、排除清单、与上游只差的两行、重新同步步骤 |
| `skills/_shared/README.md` | `_shared/` 怎么用、怎么跑测试、哪些是故意没做的（末节「还没做的事」，二期做完后现在指向三期） |
| `skills/_shared/presets/INDEX.md` | preset 与 dimensions 的**唯一发现入口**。选 preset 一律读它，别背名单 |
| 本文 | 跨会话的状态、教训、环境事实 |
| `docs/handoff/handoff.md` | 另一条线（主题库 / HTML 生成），与本文无交集 |

三期执行期间的 SDD 工作区（`.superpowers/sdd/2026-08-11-image-phase3/`，含 ledger、九份任务报告、各轮评审包）**已在收尾时按流程删除**。别去找它——本文第六节与第八节就是从那批材料里提炼出来的持久记录，git 历史是另一半。`.superpowers/` 本身是 git 忽略的临时区，同级还留着别的计划的目录，那些不属于这条线。

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
    skills/md2publish-visuals skills/md2publish-diagram \
    skills/md2publish-article/SKILL.md skills/wechat-finetune skills/README.md \
    skills/md2publish-images scripts \
    docs/handoff/handoff-image.md docs/handoff/handoff.md \
    docs/superpowers/specs/2026-08-09-md2publish-image-skills-design.md \
    docs/superpowers/plans/2026-08-11-image-phase2b.md \
    docs/superpowers/plans/2026-08-11-image-phase3.md
  ```
  **这串路径每加一期就要回头补一次。** 三期新增的
  `skills/md2publish-visuals` / `skills/md2publish-diagram` 与三期的计划文件就是这次补的——
  上一版清单停在二期 B 的 footprint 上，用它算三期会漏掉两个新 skill 的全部 commit。
  第八节第 9 条记的就是这个模式，它在三期又复发了一次。

  只看**某一期**时，给同一串路径加上 range。锚点用**那一期的计划文件**去查（别用写死的
  SHA，也别用 `--grep`——各期的任务 commit 没有共同 message 前缀）：
  ```bash
  P2B=$(git log --format=%H -- docs/superpowers/plans/2026-08-11-image-phase2b.md | tail -1)
  P3=$(git log --format=%H -- docs/superpowers/plans/2026-08-11-image-phase3.md | tail -1)

  git log --oneline "$P2B^..$P3^" -- <上面那串路径>   # 只看二期 B
  git log --oneline "$P3^..HEAD"   -- <上面那串路径>   # 只看三期
  ```
  三期这一段捞出来的是三十条上下（九个任务 commit + 各任务的评审修复 + 整支评审的
  修复波 + 本文自己的若干次修订），中间夹着另一条线的 commit，按上面的方法过滤。
  **这个数字每改一次本文就会涨**，别把它当校验值用。
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

一条命令跑**十二项**检查（二期时是九项，三期又加了三项），期望全部 ✓、末尾打印「全部通过（12 项）。」：

1. 资产 schema + `costs.yaml`（18 项，含 provider 名单四处一致的交叉校验）
2. 渲染器 + 占位符白名单（11 项）
3. 平台 × archetype × preset 矩阵（8 组合）
4. 压缩不超限（8 项）
5. preflight + config 自检（21 项）
6. 产物落盘规则：重跑保护 + sidecar（**21 项**——三期 T1 加 diagram 支路的 6 项断言从 12 变 18；三期之后的边角清理批次又加了输入校验的 3 项：空 `--image`、拼错的 `--archetype`，以及一条「合法 archetype 没被新校验误伤」的对照）
7. **Markdown 回写门**（**14 项**，三期新增，对应 `test-writeback.sh`；覆盖单图与多图 back-to-front 插入顺序，第 14 项是三期整支评审第 5 条补的「同锚点两图不被静默颠倒」）
8. **SVG→位图降级链**（**12 项**，三期新增，对应 `test-svg2raster.sh`；本机 `rsvg-convert` / `magick` / Chrome 三后端齐全时的数字，缺后端的机器上会少几项并 exit 2 报 SKIPPED。第 12 项是三期整支评审第 6 条补的「沙箱里第三方 import 确实失败」）
9. imagegen 引擎（`bun test`，97 pass / 0 fail / 12 files）
10. **diagram 端到端（零成本）**（7 项，三期新增，对应 `scripts/test-diagram-e2e.sh`；本机三后端齐全时真跑并全绿，三者都缺时整项 **SKIPPED**，见下）
11. shared 漂移检查（`md2publish-cover/shared/`、`md2publish-visuals/shared/`、`md2publish-diagram/shared/` 与 `_shared/` 是否一致，三期起从 1 个 skill 扩到 3 个）
12. vendor 同步与漂移（12 项，三期从 9 变 12，T6 给两个新 skill 加了清单断言）

**第 11、12 项的先后顺序是有意的，别调换。** 第 12 项开头就跑一遍 `sync-shared.sh`；
它如今在临时沙箱副本里跑、不碰工作区，但只要有谁把它改回原地跑，真实漂移就会在
第 11 项看见它之前被冲掉，第 11 项从此永远不可能失败。design §4.3 明说漂移是
vendoring 唯一的真实失败模式，且**绝不能靠 re-sync 解决**。

**SKIPPED 是第三态，不是失败也不是通过。** `check.sh` 的 `run()` 除了 ✓ / ✗，子进程退出码为 2 时会打印 `⊘ SKIPPED`——目前只有第 10 项（diagram 端到端）会触发，机器上 `rsvg-convert` / `magick` / Chrome 一个都没装时如实报 SKIPPED，而不是把只想改主题库、没装光栅化工具的人也硬拦住。**SKIPPED 不算通过**：末尾摘要区分「全部通过（12 项）。」（零跳过）与「N 项通过，M 项跳过：……。」（有跳过），后者紧跟一句「跳过的项**没有跑过**，不等于通过」。

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

**sidecar 的 `image` 字段是「下游该消费哪个文件」的唯一真相源，被两方消费。** 二期 B 让 `md2publish-draft` 读它取封面文件名；三期让 `writeback.py` 的 `insertions.json` 也读它取正文插图文件名——两处都不许硬编 `.png`，因为压缩是新增不是替换，超限时 `.png` 与 `.jpg` 并存，文件名本身分不出该用哪个。spec §5.3 是这条契约唯一的定义处，改契约先改那里。

**`diagram` 不走 preset / prompt，这是它与另两个 skill 唯一的结构性差异。** `artifacts.py sidecar --archetype diagram` 不接受 `--preset` / `--model` / `--prompt-file` / `--brief-file`，传了就硬失败；`compose_prompt.py` 也不会被 diagram 调用。它的语义层产物直接是 SVG 本身（agent 手写），机械层只有光栅化（`svg2raster.py`）。别把另两个 skill 步骤 4「渲染 prompt」的心智模型套到它头上。

**`svg2raster.py` 只用标准库，不 import `yaml`、不 import `asset_lib`。** 理由：它的降级链测试要在 PATH 遮蔽沙箱里用 `/usr/bin/python3` 跑（见第四节），任何第三方 import 都会让那组测试无法进行，逼着往生产代码里塞"假装某后端不存在"的测试后门。这道护栏三期一度有个洞（沙箱没屏蔽住用户级 site-packages），**已在三期整支评审的修复波里补上并加断言钉死**，来龙去脉见第四节。

## 四、环境事实（都是实测的，会咬人）

- **Python 是 3.9.13**（anaconda3）。`dict | None` 这类 PEP 604 注解在 3.9 上 import 即 `TypeError`，所有脚本靠 `from __future__ import annotations` 工作。**新增脚本别漏这行。**
- PyYAML 6.0 已装，是本层唯一的第三方依赖。
- **`mv` 和 `cp` 在这台机器上都是交互式的**（覆盖已存在的目标时会停下来等 y/n，在自动化里表现为卡死）。脚本里用 `\cp -f`（反斜杠绕过 alias），别用裸 `mv` / 裸 `cp`。
  `cp` 这一条是三期之后的边角清理批次实测补上的：做变异自证时用 `cp <备份> artifacts.py` 回滚，命令卡在
  `overwrite artifacts.py? (y/n [n])` 上直到超时被移到后台，而**卡住之前那一步的变异结果已经打印出来了**，
  很容易被误读成「这轮测试跑完了」。判断输出完整与否，看结尾有没有那行 `通过 N 项，失败 M 项`，别看有没有内容。
  连带的第二个坑：`\cp -f` 的目标目录不存在时它只报一行 `No such file or directory` 就走，**回滚静默失败**，
  下一轮变异于是叠在上一轮之上，两条断言一起红，看起来像「断言没有区分能力」。变异自证的每一次回滚都要验一下真的回滚了。
- **本仓库没有 CI、没有 git hooks、没有 `.github/`。** 所有测试靠手跑。`skills/_shared/README.md` 里那句"改完必须跑一遍"是**文档约束，不是自动闸门**——不要在任何文档里把它写成强制。
- **可能有另一个 agent 同时在这个仓库里工作**（一期执行期间就有，它在做主题普查那条线）。因此：只用显式路径 `git add`，**绝不 `git add -A` / `git commit -a`**；切分支前先看 `git status`；算"本次改了什么"时不要拿 `main` 当基线，用本次第一个 commit 的父提交。
- **这台机器的 bash 是 GNU bash 3.2.57。** `$var` 后面紧跟全角标点（`）`、`：`等）会破坏变量名解析，在 `set -u` 下直接报错。二期 A 已踩过两次，三期又踩了第三次：`scripts/check.sh` 的 `run()` 里 SKIPPED 分支最初写的是裸 `echo "  ⊘ $label：SKIPPED"`，只有真的产生一次跳过（三个光栅化后端都不可用）才会触发 `line 21: label�: unbound variable`，本机三后端齐全，第一次没跑出这条路径，是专门造了一次"三后端全缺"的场景才炸出来的。写含中文提示的脚本时一律用 `${var}`，别用裸 `$var`；**光靠本机常规跑测试测不出这类 bug，得刻意触发那条平时不走的分支**。
- **`/usr/bin/python3` 是 3.9.6，`svg2raster.py` 的 PATH 遮蔽沙箱测试（`test-svg2raster.sh`）靠它验证「只用标准库」这条约束。**这里曾有个洞，**现已修好；记下来是因为这类「沙箱其实没隔离」的假象很容易再犯**：沙箱最初只清空了 `PATH`（`env -i PATH=... HOME=...`），**没有清空用户级 site-packages**——本机 `~/Library/Python/3.9/lib/python/site-packages` 装着 PyYAML 6.0.1，Python 按保留下来的 `HOME` 仍会把它加进 `sys.path`，于是给 `svg2raster.py` 临时加一行 `import yaml` 也不会崩。三期整支评审第 6 条修掉了它：三处 `env -i` 全部加上 `PYTHONNOUSERSITE=1`，并补了一条「沙箱里 `import yaml` 必须失败」的断言把隔离本身钉死（`test-svg2raster.sh` 因此从 11 项变 12 项）。**现在这条约束是真受保护的**，别再照抄旧结论说它没人守。
- **`git commit` 的 `--` 必须排在 `-m` / `-F` 之后。** `git commit -- <路径> -m "msg"` 会把 `-m` 当成 pathspec 报错，正确形式是 `git commit -F <消息文件> -- <路径>`。三期计划的 Global Constraints 提前点出了这个坑并把九个任务的提交步骤都按正确形式写好，本期因此没有一次真的踩雷——记在这里是防止这条护栏因为"从没人踩过"在下一期被漏抄。
- **vendor 进来的 `imagegen/` 与上游只差两行**，都在 `main.ts`：`loadProviderModule()` 里 `codex-cli` 分支改成硬失败（D1），`MAX_ATTEMPTS` 从 `3` 改成 `2`（D2）。除这两处外逐字与上游一致，可直接 `diff`。细节与重新同步步骤见 `skills/_shared/scripts/imagegen/VENDOR.md`。

## 五、语言约定（新规则，优先级高）

- **git commit message 与分支名一律英文**，跨所有项目生效，且**不因仓库既有历史是中文而放宽**。这条与 `CLAUDE.md` Rule 0 一致。
- 文档内容（`docs/`）、与用户的对话：中文。
- 注意：`main` 上已有的六条 `一期 T1`…`一期 T6` commit 是中文的，属规则生效前的遗留，未改写历史。**从下一个 commit 起必须英文。**

## 六、剩下的活（按 spec §15 的分期）

**二期 A（已完成，纯新增，无破坏性）**
- 从 `baoyu-skills/skills/baoyu-image-gen/` 搬入 `imagegen/`（11 个 provider，`codex-cli` 按 D1 剔除；零第三方依赖，纯 `node:` + fetch）。`bun test` 实测 **97 pass / 0 fail，12 个文件**。
- 写好 `compress.py`（sips → magick，见 D3）、`preflight.py`、`config.py`、`artifacts.py`、`costs.yaml`。实测（**含最终评审七项修复后的数字**）：资产 schema + costs **18 项**、压缩不超限 **8 项**、preflight + config **21 项**、产物落盘规则 **10 项**，全绿——这是二期 A 收尾时测到的数字。**二期 B 的 T1 又把它从 10 项改成了 12 项**（加了 `image` 字段的两条断言，见下面「二期 B」那块），**三期 T1 再从 12 项改成 18 项**（diagram 支路的 6 条断言）。**当前基线是 18 项，以第二节为准**——本节记的是各期收尾当时的数字，是历史快照，不是现状。
- 建成 `md2publish-cover`；`shared-manifest.sh` / `sync-shared.sh` / `check-shared-drift.sh` / `scripts/check.sh` 全部写好并跑通，vendor 同步与漂移实测 **9 项**全绿。
- **`md2publish-images` 原地保留**，两者并存，本期未改它一个字。
- 完成判据两条分开看：spec §13 五项全绿——**已验证**（`./scripts/check.sh` 当时九项全 ✓，现在是十二项，见第二节）；端到端产出一张微信封面并压到 2MB 内的**手动付费 smoke——未做**。本机 `preflight.py` 实测「一个 provider 凭证都没配置」，无法真调用付费 API，这一步只能留给配好凭证的会话去跑，步骤见 spec §7 / `md2publish-cover/SKILL.md`。**check.sh 全绿不等于端到端验证过——没跑就是没跑，别混着说。**
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

**二期 B（已完成并已过整支评审，唯一有破坏性的一期；跑成了逐任务 commit，不是单 commit）**

本期在 `main` 上是 T1–T8 八个逐任务 commit，**外加数量不固定的评审修复 commit**——
每个任务的评审、以及最终那次整支评审，各自都产生了若干。所以算 footprint 时
**别只数那八个**，合计是十几条。

起点 `0f79f78`（T1：sidecar 记录最终产物文件名）是稳定锚点，可以放心当 range 的下界。
但**别去记"最后一个是哪个"**：本文每被修订一次就多一个 commit，任何写死的末端 SHA
当天就过期。要清单就现查：

```bash
git log --oneline 0f79f78^..HEAD -- <第一之二节那串路径>
```

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

- **整支评审做过了，结论对三期有直接用处**：八个任务各自的评审全部通过之后，最终整支
  评审仍抓出 **4 个 Important（0 Critical）**，而且四条是**同一个物种**——同一个事实在
  一处改对了，没扫到其余几处断言同一事实的地方。具体是：`image` 不是路径这件事只改了
  spec，`md2publish-cover/SKILL.md` 与 `skills/README.md` 漏了；完成判据与回滚方式只改
  了本文，spec §15 漏了；第一之二节的 git recipe 在本期把 footprint 扩大之后从没回头看。
  其中 spec §15 那条最危险：它当时还写着"回滚 = `git revert`"，照做会连带删掉另一条线
  的文件（来历见上面那段）。四条已由一次性修复波关掉，教训见第八节第 9 条。

**二期 B 的教训（两条）**：一是 spec、`md2publish-cover/SKILL.md`、本文的硬约束三处都在
写"读 sidecar 里记的路径"，而 `artifacts.py` 写出的 sidecar 曾经根本没有路径字段——一条
契约被反复引用不等于它被实现过。二是上面那条整支评审的发现。完整版见第八节。

**三期（九个任务已完成并逐任务过了评审，最后一期；跑成了逐任务 commit T1–T9，不是单 commit；整支评审已执行，0 Critical + 6 Important，见下）**

- 建成 `md2publish-visuals`（含 Markdown 回写门，`writeback.py` 新脚本）与 `md2publish-diagram`（含 SVG→PNG 降级链，`svg2raster.py` 新脚本）；`artifacts.py` 加了 diagram 支路（`source_file` 字段 + 确定性 archetype 分支）；`scripts/check.sh` 从 9 项接入到 **12 项**（新增 Markdown 回写门 13 项、SVG→位图降级链 11 项、diagram 端到端 7 项）；`shared-manifest.sh` / `test-sync-drift.sh` 从只认 1 个 skill 扩到 3 个；把 `visuals` 接进 `md2publish-article` 的上游，`article` 步骤 1 输入表默认认 `article.illustrated.md`。
- **`visuals` 在 `md2publish-article` 的上游**，不是并行分支（spec §8）。它产出 `article.illustrated.md`，`md2publish-article` 的步骤 1 输入表必须认这个文件，否则它永远不被转换。
- **完成判据三分版，别混着说**（这是本条最重要的口径，spec §15 已同步）：
  - **自动化**：`check.sh` 12 项全绿——**已验证**（见第二节，本报告"验证"一节有实跑输出）。
  - **本机零成本端到端**：`diagram` 链路真跑通了——写 SVG → 光栅化（本机 `rsvg-convert` 可用）→ 压缩判断 → 写 sidecar，`test-diagram-e2e.sh` 覆盖，且**压缩产物真正串进了 sidecar**（`image` 字段指向 `.jpg` 而非未压缩的 `.png`，这是执行中修的一个真 bug，见下）。**`diagram` 是三个 skill 里唯一被端到端真跑过的一个。**
  - **手动付费挂账，现在欠两次，不是一次**：真调 provider 生一张图的最小 smoke，`cover`（二期起欠）与 `visuals`（三期新欠，小红书 5 张卡片系列要花钱）**均未跑**——本机 `preflight.py` 实测一个 provider 凭证都没配置。**`diagram` 不欠这笔账**，它零成本、不需要 provider。三条线索不要混着说：check.sh 全绿 ≠ 端到端验证过；`diagram` 端到端真跑过 ≠ 另外两条线也跑过；欠款是两次不是一次。

**三期执行中记下的、计划里没有的几件事（都是评审抓出来、有实证的）**

1. **一条 commit message 的措辞与实测不符，未改写历史。** commit `54fd0b8`（"test(shared): make the diagram --preset assertion discriminate"）的正文写着"Supplying the three AI-only flags makes the old code succeed"，但实测：旧实现（`9fd2481`）在补齐 `--model x --prompt-file x --brief-file x` 三个 dummy 参数后**并不会**成功（RC=0）——它压根不认识三期新加的 `--source-file` 参数，以 `unrecognized arguments: --source-file 00-diagram.svg` 报错，RC=2；而**这条报错走的是顶层 parser 的 usage 横幅，不含 `--preset` 字符串**，所以 `grep -q -- '--preset'` 不命中，断言仍然判失败——不是"succeed"。修复前的旧断言之所以是假绿，是因为**不给三个 dummy 参数时**旧代码报的是子命令级"缺少必填参数"的 usage（会完整列出 `--preset PRESET` 等全部已知 flag 名），grep 碰巧命中；补上三个 dummy 参数后触发的是完全不同的"不认识的参数"错误路径，两条路径都不产生 RC=0，只是触发 grep 命中与否的原因不同。**结论（消除巧合通过、断言现在只因目标行为而红/绿）成立，commit message 对机制的描述有误。** 本仓库并发共享工作区、不改写历史，此处记下正确机制供以后查阅。已用 `git show 9fd2481:...` 取出旧版 `artifacts.py` 实跑复现，输出见本任务的验证记录。
2. **本期连续四个任务被评审抓到"没有区分能力的断言"——RED 阶段是假的，它在正确与错误实现下都会通过。** 四次的形态都不一样，值得当一类教训记：
   - **T1**：断言靠 argparse 的 usage 横幅碰巧回显了 `--preset` 这个 flag 名而"命中"，与被测的 diagram 分支逻辑毫无关系（即上一条）。
   - **T2**：断言的"真值"本身是调被测代码（`magick_has_rsvg()`）自己算出来的，于是不管被测逻辑对不对，断言都会自洽地"通过"。
   - **T3**：主用法（`visuals` 一次插多张图）一条断言都没覆盖，12 条断言全部只给单条 insertion，`writeback.py` 里"从后往前插入"防止行号漂移的那段行号数学从未被真正跑过，插反了也测不出来——而多图恰恰是 `visuals` 的常态用法（一篇插 2–4 张）。
   - **T6**：`scripts/fixtures/diagram-sample.svg` 被本任务自己点名为硬要求的文件，`test-sync-drift.sh` 的断言循环却唯独没检查它——manifest 里虽然列了它，但没有断言钉住，将来被删掉不会被任何测试发现。
   
   **有效的对策，本期后半程每个任务都做了：变异自证**——写完断言之后，临时在生产代码里制造对应缺陷（删一行校验、写松一个条件、从清单里拿掉一项……），确认目标断言**确实翻红**、且红的是它而不是别的（其余断言仍绿），再把生产代码改回去。这一步在三期抓出了 T1/T2/T3/T6 以上四条，是本期最有效的单一手段。
3. **两个只有真跑才会暴露的 bug，都在"写了但从没走过"的代码路径上：**
   - `scripts/check.sh` 的 `run()` SKIPPED 分支写的是裸 `$label` 紧跟全角冒号（`echo "  ⊘ $label：SKIPPED"`），bash 3.2.57 + `set -u` 下会把变量名解析坏、报假的 `unbound variable`。本机三个光栅化后端齐全，日常跑测试永远走不到这条分支，只有专门造一次"三后端全缺"的场景才会触发（T7）。
   - `scripts/test-diagram-e2e.sh` 最初写的压缩阈值 `SMALL=20000`，比本机实际光栅化出的原始 PNG（18914 字节）还大，导致 `compress.py` 的"未超限"分支直接生效、返回 `action: "none"`，"强制压缩"那条断言名义上跑了，实际压缩代码路径从未被走到——这同时也是 Important 1（压缩产物没有真正喂给 sidecar）能够藏住的原因：两个假象叠在一起，直到把压缩产物真正串进下游消费（sidecar 的 `image` 字段）才同时暴露（T7）。两处都已修：前者改 `${label}`；后者改用光栅化产物实际字节数的 90% 作为阈值，并补了断言确认压缩代码路径真的被走到。
4. **`bilibili.yaml` 仍然故意未做**：B 站画幅与文字约定属未验证的外部知识（一期就已留白），三期不猜，需要先分别确认视频封面与专栏头图各自的规格。

**三期整支评审已执行：0 Critical，6 Important，全部是跨组件问题**——没有一条是逐任务评审能看见的。这是连续第三期证明整支评审不可省（一期不算，那次是 spec 事实核查；二期 A：1 Critical + 6 Important；二期 B：4 Important）。六条依次是：

1. **D15 的契约钉在一个上游并不保证的文件名上。** `md2publish-article` 匹配字面量 `article.illustrated.md`，`md2publish-visuals` 硬编码 `$ART/article.wechat.md` → `$ART/article.illustrated.md`，README 与 spec §8 同样；但上游的 `wechat-finetune` 写出的是 `<name>.wechat.md`（`<name>` 是用户的文件名），仓库里根本没有"每篇文章一个目录"的约定。失效方式**恰是 D15 要杀掉的那个**：article 的默认永不触发，花钱生成的配图静默进不了 HTML。已改为推导规则 `<name>.wechat.md` → `<name>.illustrated.md`，article 步骤 1 改为在同目录匹配 `*.illustrated.md`、匹配到多份时列出候选问用户。
2. **diagram → 正文 的回写路线三处都写了、一处都跑不通。** diagram 的 SKILL.md、spec §7.2、§8 都说"交给 visuals 的回写门"，但 diagram 的 vendor 子集不含 `writeback.py`，而 visuals 的步骤 9 排在凭证门、计费门和一次真 provider 调用之后。照做的 agent 要么为插一张零成本图去跑付费流水线、要么卡住。已给 diagram 自己 vendor 一份 `writeback.py` 并加了独立的回写步骤（`writeback.py` 只依赖 `artifacts.py`/`asset_lib.py`，两者本就在 diagram 清单里，没有把付费资产拖进来）。
3. **`skills/README.md` 里唯一做否定断言的那句话过时了**——「cover 另需（其余 skill 不需要）：bun / sips|magick」，而 visuals 两个都要、diagram 需要光栅化后端。扫尾改了紧挨着的流程框和表，漏了这句。
4. **`test-svg2raster.sh` 在一台从没跑过降级链的机器上照样全绿。** `skip()` 既不计 PASS 也不计 FAIL、脚本从不 exit 2；没有 rsvg 也没有 magick 的机器上两条真降级断言被跳过，`check.sh` 照打 ✓ 和「全部通过」。**这正是 D14 要防的假绿**——D14 只把 SKIPPED 语义给了 `test-diagram-e2e.sh`，按它自己的道理这个脚本也该有。**这条是计划缺陷**：基线表只写了"缺后端的机器上会少几项并打印 ⊘"，没要求 exit 2。已改为记录跳过数并 exit 2。
5. **`writeback.py` 会把共用同一锚点的两条 insertion 静默颠倒。** 一个小标题下放两张图是正常需求，而这个文件自己的哲学就是不容忍静默错序（"插错位置比没插更难发现——产物看起来是成功的"）。原测试的多图用例用了**三个不同的锚点**，所以它在正确与错误实现下都会通过。已加原始索引做 tie-break，并补了同锚点断言 + 变异自证。
6. **「只用标准库」这条约束，沙箱并没有在守它。** `test-svg2raster.sh` 的 `env -i` 透传了 `HOME`，`/usr/bin/python3` 会自动加载 `~/Library/Python/3.9/.../site-packages`，所以沙箱里 `import yaml` 成功——有人加一句 `import asset_lib` 也会全绿。已加 `PYTHONNOUSERSITE=1`（三处 `env -i` 全部），并加了一条"沙箱里第三方 import 确实失败"的断言把它钉死。

**修复波自己引入的一条回归（值得单独记）**：给 diagram 加回写步骤时写了 `OUT="${SOURCE%.wechat.md}.illustrated.md"`，并在注释里断言"SOURCE 已经是 `.illustrated.md` 时 OUT 和 SOURCE 相同"。**那句断言是假的**：bash 的 `%` 后缀剥离只在真以该后缀结尾时生效，`SOURCE` 已是 `.illustrated.md` 时剥离不生效，产出 `name.illustrated.md.illustrated.md`——而那恰恰是这条修法专门要支持的场景（visuals 已回写过、diagram 再往同一篇里插）。更难查的是：这个错误命名的文件**仍然匹配 `*.illustrated.md`**，于是下游 article 会看到两个候选、触发多匹配问询，链路不断、只是错。已改成 `case` 三分支并用 bash 3.2 实跑三种输入验证过。教训：**修复引入的缺陷与原缺陷同源**——都是"注释/文档在断言一件代码没做的事"。

**一条被推翻的评审归因（记下来，因为它关乎该信谁）**：整支评审给第 5 条的归因是"`sorted` 带 `reverse=True` 不保持相同键的原顺序"。**这是事实错误**——Python 的排序是稳定的，官方文档明文保证 `reverse` 参数仍维持稳定性。真正的颠倒来自插入循环本身（在同一 offset 处从后往前插两条会把它们翻过来）。修复者验证后指出了这一点，照样应用了建议的修法代码（修法是对的），并把注释改成描述真实机制；定向复审独立复验，判定**修复者对、评审错**。值得记的不是这个具体知识点，而是：**评审的结论可能对而理由是错的**，照着错理由去改代码会改出别的问题。实现者验证归因、而不是只照抄修法，是对的。

**口径重申一遍（最容易被下一个人说漏，值得在评审结果旁边再钉一次）**：上面"完成判据三分版"已经把三层说清楚了——`check.sh` 十二项全绿（末尾措辞现在是「全部通过（12 项）。」）≠ 端到端验证过；`diagram` 端到端真跑过 ≠ 另外两条线也跑过；付费 smoke 欠款是两次（`cover` + `visuals`）不是一次。整支评审的六条发现，正是在 `check.sh` 全绿的前提下抓出来的——**十二项全绿从来不等于没有跨组件问题**，这正是本节要证明的事，别把两者混成一句话说。

**评审指出的一个可复用模式**：第 1、2、3 条同源——三期都把"正向引用"改对了（这个 skill 交接给那个 skill），漏掉了"反向或否定断言"（上游实际产出什么；其余 skill 不需要什么）。评审建议：下一期的扫尾任务里加一遍针对否定断言的 grep——`不需要` / `其余` / `只有` / `尚未`。

**三期留下的 6 项边角：已全部清掉（2026-08-19）。** 它们当时被裁定为"可以留到下一期"的非缺陷，
现在做完了，逐条与对应的验证方式如下（`git log --oneline -- skills/_shared/scripts scripts/test-sync-drift.sh`
能捞到这三个 commit）：

| 原条目 | 怎么修的 | 怎么验的 |
|---|---|---|
| `svg2raster.py` 的 `rasterize()` 里 `available_backends()` 每元素调一次（3 次） | 直接用 `available_backends()` 的返回值，删掉那份重复的优先级元组——它是同一个顺序的第二个真相源 | 行为不变，靠既有 `test-svg2raster.sh` 12 项（含两条真降级断言）兜底 |
| `artifacts.py` 收 `--image ""` 抛裸 `ValueError` traceback | `check_sidecar_args` 开头加空值校验 | 新断言同时否掉 `Traceback`——只判 rc≠0 的话抛栈退出 1 也算通过 |
| `artifacts.py` 不校验 `--archetype` 在不在 `asset_lib.ARCHETYPES` 里 | 同处按权威清单校验 | 新断言同时钉"没留下乱码 sidecar"——只判 rc 的话"先写文件再报错"也会通过 |
| `writeback.py` 的 `--out` 帮助文案留着旧字面量 | 改成写推导规则 | 措辞，无断言 |
| `test-sync-drift.sh` 隔离探针在文件缺失时空转通过 | 两个探针都加存在性校验并当场 `exit 1` | 见下面单独一条 |
| `writeback.py` tie-break 注释说顺序"不受控" | 改成写实际机制（稳定排序 → 顺序确定、但确定地错） | 措辞，无断言 |

**这批里唯一值得单独记的**：`test-sync-drift.sh` 的隔离探针那条，交接文档原本只点了**第二个**探针，
但两个探针同形——`$(cksum < "$probe" 2>/dev/null || echo "缺失")` 在文件本就不存在时 before / after
双双落到 `"缺失"`，断言空转。**只修被点名的那一个，正是第八节第 9 条那个物种。**先实测证明了洞是真的
（把 `REAL_PROBE2` 指向不存在的路径，整支照样打两个 ✅ 和「通过 12 项，失败 0 项」），两个一起修。
修法选了"当场 `exit 1`"而不是只记一笔 FAIL：探针没了，后面那两条隔离断言仍会打 ✅，
**一份既报 ❌ 又报 ✅ 的输出比只报错更难判读**。

**顺带做的否定断言扫尾**（三期整支评审开的方子：grep `不需要` / `其余` / `只有` / `尚未`）。
`skills/` 与 spec 里的否定断言逐条核过，**都还成立**；漂移全在本文自己身上，共四处，已一次改完：

1. 第二节第 6 项：产物落盘规则 18 → **21**（本批新增 3 条断言）。
2. 第二节第 7 项：Markdown 回写门 13 → **14**。
3. 第二节第 8 项：SVG→位图降级链 11 → **12**。
4. 第三节末尾与第四节：`svg2raster.py`"只用标准库"那道护栏还写着"有个洞""未动代码"。

**第 2、3、4 条与本批的改动无关——它们是三期整支评审的修复波改了测试却没回头改基线表。**
修复波补的断言（评审第 5 条的同锚点用例、第 6 条的 `PYTHONNOUSERSITE=1` + 沙箱隔离断言）
各自让对应脚本多了一项，而第二节那张表和第三、四节的结论停在修复之前。
**教训与第八节第 9 条同源，但换了个入口：这次不是"同一事实散落在多份文档"，
而是"改了代码却没回头改那份记录它的表"。收尾时除了 grep 否定断言，还该把基线表里每个数字
重新跑一遍对齐——数字是最容易悄悄过期的一种断言，而且它过期时看起来完全正常。**

**一期故意没做、别当成遗漏的**：`bilibili.yaml`（同上）、vendor 脚本、`imagegen/`、`costs.yaml`。清单见 `skills/_shared/README.md` 末节。

## 七、建议调用的 skills

| 场景 | skill |
|---|---|
| 开始新一期前（三期已完成，spec §15 定义的四期到此为止；本行留作下次再拆新一期时的参考） | `superpowers:writing-plans`（三期就是这么写出来的：输入是 spec §15 的范围，Global Constraints 照抄上一期计划开头那套——避免每期都重新踩一遍并发提交、bash 3.2.57 之类的老坑） |
| 执行计划 | `superpowers:subagent-driven-development`（二期 A 就是这么跑完 8 个任务的，在有并发 agent 的情况下也没出事——关键是每个任务只用显式路径 `git add`）或 `superpowers:executing-plans`（内联） |
| 动任何设计决策前 | `superpowers:brainstorming`（本设计的两版都是这么产出的） |
| 每一期收尾 | `superpowers:requesting-code-review`。**必须做一次整支评审，逐任务评审替代不了它**——理由见第八节末尾。也顺带做事实核查：一期的 spec 复审抓出 6 处事实错误，其中"悬空引用四处"实为九处 |
| 排查测试失败 | `superpowers:systematic-debugging` |
| 收尾分支 | `superpowers:finishing-a-development-branch` |

## 八、执行中修掉的计划缺陷（写下一份计划前先读这节）

全都属于同一族：**计划看着对、跑起来错**。一期三条、二期 A 四条、二期 B 两条、三期三条；
二期 A 那四条里有三条、二期 B 那两条全部、三期那三条全部，是单个任务的评审看不出来、
只有跨任务视角才暴露的。

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

**二期 B（两条）**

8. **文档三处承诺的契约，代码里一处都没实现。** spec §12、`md2publish-cover/SKILL.md`
   步骤 8、handoff 第六节的硬约束，全都写着"读 sidecar 里记的路径"，而 `artifacts.py`
   写出的 sidecar **根本没有路径字段**——只有 `bytes`。更糟的是 sidecar 路径是
   `image.with_suffix(".json")`，压缩产物 `.jpg` 与原图 `.png` 算出来**是同一个
   `00-cover.json`**，文件名本身也区分不了。照 spec 原样执行二期 B，只会退回硬编
   `00-cover.png`，正是二期 A 要消灭的失败模式。
   **教训：一条契约被多份文档反复引用，不等于它被实现过。跨组件的"谁读谁"改动，
   动手前先去读被读那一方的代码，确认它真的写了那个字段。**

9. **改对一处不等于改完——同一个事实往往被四五份文档各自断言过。** 二期 B 的最终整支
   评审抓出的 4 个 Important 全是这一种：`image` 是文件名不是路径，只在 spec 改了，
   `md2publish-cover/SKILL.md` 的「产物布局」和 `skills/README.md` 的流水线图漏了；
   完成判据与回滚方式只在本文改了，spec §15 那一行漏了，而它还停在"回滚 = `git revert`"
   这个**照做会误删另一条线文件**的状态；第一之二节的 git recipe 在本期把 footprint
   从"`_shared` + `cover`"扩大到七八个路径之后，从没有人回头看它还准不准。
   **教训：改一条事实之前，先 `grep` 出所有断言过它的地方，一次改完。**
   `grep` 的关键词要用**那句话的说法**（如"记的路径"、"单 commit"、"九处"），
   不是被改的标识符名——正是措辞不同才让它们躲过了前面八次逐任务评审。

**给三期的一条方法论（三期已验证成立）**：二期 A 的八个任务全部通过了各自的评审，最终整支评审仍然
抓出 1 个 Critical + 6 个 Important，全部是**跨组件**的（顺序依赖、四处 provider 名单
不同步、文档里两套路径无法在同一个 cwd 下成立、sidecar 记录的 provider 与引擎实际
选的不是一回事）。二期 B 换了一批任务、换了一批评审者，结果**同样**是逐任务全绿、
整支评审再抓 4 个 Important。三期又换了一批任务，逐任务评审同样全绿，最终整支评审
抓出 **0 Critical + 6 Important**，同样全部跨组件（六条详情见第六节「三期」小节）。
**连续三期复现，这已经不是偶然：逐任务评审不能替代一次整支评审，下一期照做，别省。**

**三期（三条，全部是计划自带的代码快照被原样抄进实现，快照本身就是错的）**

10. **计划给的断言快照没有区分能力，抄进实现就把假绿一起抄了。** Task 1 Step 2 给的
    "diagram 传 `--preset` 应硬失败"断言快照，只补了 `--source-file`，没有同时补
    `--model` / `--prompt-file` / `--brief-file` 三个旧实现本就必填的参数——于是断言
    在旧实现（补丁前）下也会"通过"：argparse 因缺这三个参数报错，其 usage 横幅碰巧
    完整列出了包括 `--preset` 在内的全部已知 flag 名，`grep -q -- '--preset'` 命中的是
    这个巧合，不是"diagram 分支正确拒绝了 preset"这件事本身。commit `54fd0b8` 同时
    改了实现里的测试脚本和计划本身的同一段代码快照（缺陷源头），详见第六节"三期执行中
    记下的几件事"第 1、2 条。**教训：计划里给的断言代码块要按"能不能在旧实现下失败"
    的标准审一遍，不是审"语法对不对"。**
11. **计划把 SVG→PNG 降级链的三级都当成同等可信的渲染器，实际第二级（`magick`）的
    可信度取决于一个必须运行时探测的编译期 delegate。** Task 2 深入排查后发现：本机
    `magick`（Homebrew 版）没有 RSVG delegate，渲染带引号 `font-family` 的 CJK SVG 时
    会直接报错硬失败（安全但吵）；一度怀疑是 fixture 的 `font-family` 加了引号导致的
    兼容性问题，去掉引号后重新验证，结果更糟——**去引号后 magick 变成 exit 0、产出合法
    PNG，但图上所有中文文字被静默丢光**，比硬失败更危险。结论：问题不在引号写法，在
    "无条件信任 magick 的退出码"这个假设本身站不住。最终没有改 fixture 的字体写法
    （字体 fallback 链保持带引号，见 `md2publish-diagram/SKILL.md` 步骤 3 的硬约束），
    而是给 `svg2raster.py` 加了 D17 的能力闸——magick 是否可信必须先探测，不能假定。
    **教训：降级链的每一级"能用"，本身可能是需要验证的假设，而不是设计时就能断言的
    事实；排查这类问题时，目视检查产物（而不是只看退出码）能发现比报错更隐蔽的故障。**
12. **计划里两处独立的代码快照都漏抄了同一个文件，因为它们是分开写的，没有一个共同
    定义处。** Task 6 的 Step 4（diagram 的 vendor case）与 Step 2b（漂移测试的断言
    循环）各自单独列出 diagram 需要 vendor 的文件清单，两处都漏了
    `scripts/fixtures/diagram-sample.svg`——这个文件在 Task 2 里已经被点名为硬要求
    （测试与端到端共用的 fixture），但因为两份快照各自维护自己的清单，没有一处是
    单一真相源，漏改一处不会被另一处发现。计划与 `scripts/shared-manifest.sh`、
    `scripts/test-sync-drift.sh` 一并修正。**教训：同一份文件清单如果在计划里被写了
    两次（一次给实现抄、一次给测试断言抄），两次必须来自同一处来源，否则漏改必然
    只改对一半。**

**三期整支评审阶段的两条元教训（不是计划缺陷，是关于评审本身怎么用的教训）**

13. **修复引入的缺陷可能与原缺陷同源。** 给 diagram 加回写步骤时的
    `OUT="${SOURCE%.wechat.md}.illustrated.md"` 一行，连同它注释里"SOURCE 已是
    `.illustrated.md` 时 OUT 和 SOURCE 相同"这句假断言，犯的是和被修的评审发现同一种
    错：注释/文档在断言一件代码没做的事。已改成 `case` 三分支并实跑验证。详见第六节
    「三期」小节"修复波自己引入的一条回归"。
14. **评审的结论可能对、理由却是错的。** 整支评审把 `writeback.py` 插入顺序颠倒
    归因于"`sorted(reverse=True)` 不保持稳定"——这是事实错误，Python 排序稳定性有
    官方文档背书；真正原因是插入循环本身在同一 offset 从后往前插时会颠倒。修复者
    验证了归因、采用了建议的修法代码（修法本身是对的）、把注释改成写实际机制，定向
    复审独立复验判定"修复者对、评审错"。**教训：照抄评审给的修法代码可以，但归因要
    自己验证一遍**，不然下次会照着错的理由去改别的代码，改出新问题。详见第六节
    「三期」小节。

三期整支评审的六条发现（0 Critical + 6 Important，全部跨组件）详见第六节「三期」
小节，不在此处重复；六条里第 1、2、3 条同源——都是漏掉了"否定/反向断言"，可复用
的应对方式（扫尾时加一遍针对否定断言的 grep）也记在该小节末尾。
