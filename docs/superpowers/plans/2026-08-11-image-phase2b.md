# 二期 B：删除 md2publish-images 并改掉全部引用 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal：** 拆掉旧的 `md2publish-images`，把仓库里所有指向它的活引用改到 `md2publish-cover`，并让 `md2publish-draft` 真正能拿到封面的最终产物路径。

**Architecture：** 本期几乎全是文档改动，唯一的代码改动在 T1——`artifacts.py` 的 sidecar 现在**不记录图片路径**，而 spec §12、`md2publish-cover/SKILL.md` 与 handoff 都已经在断言「sidecar 记的路径就是下游该消费的路径」。这个契约被三处文档承诺、却没有任何实现。不先补上，T4 里 `md2publish-draft` 的改法就无从落地，只能退回硬编 `00-cover.png`——而那正是本期要消灭的失败模式。所以 T1 是 T4 的前置，顺序不可调换。其余任务按文件分组，一个文件一次 commit，破坏性的删除动作放在最后一个 commit。

**Tech Stack：** Python 3.9.13（anaconda3）+ PyYAML 6.0；bash 3.2.57；`scripts/check.sh` 作为唯一验证入口。本期不引入任何新依赖。

**设计真相源：** `docs/superpowers/specs/2026-08-09-md2publish-image-skills-design.md`（§12 改动清单、§15 二期 B）。本计划不重复 spec 的论证，只给可执行步骤，并在下方偏离表里列出与 spec 不一致之处及理由。

---

## Global Constraints

每个任务的要求都隐含包含本节，不再逐条重复。

- **Python 版本是 3.9.13。** 任何新增 `.py` 文件的 import 区第一行必须是 `from __future__ import annotations`。本期不新增 `.py` 文件，但改到的 `artifacts.py` 已有这行，不要删。
- **这台机器的 bash 是 GNU bash 3.2.57。** 写含中文提示的 shell 断言时，变量一律 `${var}`，**不要**裸 `$var`——`$var）` 会让变量名被解析坏，`set -u` 下报假的 unbound variable。二期 A 栽过两次。
- **`mv` 在这台机器上是交互式的**（覆盖时等 y/n，自动化里表现为卡死）。脚本里一律 `\cp -f` / `\cp -Rf`。
- **仓库里有另一个 agent 在并发提交。** 只用显式路径 `git add <path>`，**绝不** `git add -A` / `git commit -a`。每个任务开工前先 `git status`。**不要切分支、不要 `git stash`**——工作区是共享的。
- **commit message 与分支名一律英文**（`CLAUDE.md` Rule 0 / handoff §5）。文档内容中文。
- **行号会漂。** spec §12 表格里的行号（`:15` `:85` `:33` `:22` `:124` `:43` `:46` `:520`）已经不准了——`docs/handoff/handoff.md` 的三处实际在 `:63` `:66` `:701`。**每一处改动都先 `grep -n` 定位，再改**，不许照着计划里的行号盲改。
- **本仓库没有 CI、没有 git hooks、没有 `.github/`。** 所有测试手跑。任何文档都不许把 `check.sh` 写成"自动闸门"。
- **`_shared/` 是唯一真相源。** 改了 `skills/_shared/` 下的任何文件，必须跑 `scripts/sync-shared.sh` 再跑 `scripts/check.sh`。发现 `skills/md2publish-cover/shared/` 与 `_shared/` 不一致时，正确动作永远是"把改动挪回 `_shared/` 再 re-sync"，绝不是"re-sync 覆盖掉"。
- **`check.sh` 里第 8 项（shared 漂移）必须排在第 9 项（vendor 同步与漂移）之前，本期不许调换。** 第 9 项开头就跑一遍 `sync-shared.sh`，调换后真实漂移会在被看见之前被冲掉。
- **不许改这三处的措辞**：`compose_prompt.py:render_platform_frame` 产出的契约串 `图上必须包含` / `图上不要出现标题文字`，以及 `test-compose-prompt.sh`、`test-platform-matrix.sh` 里 grep 它的那两行。
- **不许把 `md2publish-visuals` / `md2publish-diagram` 写成可用的去向。** 它们属三期、尚未实现。所有提到它们的地方一律带上「三期，尚未实现」并要求 agent 如实告知用户，别路由到不存在的 skill。

### 本期基线（每个任务开工前应仍然成立）

```bash
./scripts/check.sh                                            # 九项全 ✓，末尾「全部通过。」
python3 skills/md2publish-article/scripts/test-theme-lib.py   # ok：0 条失败（不在 check.sh 里，单跑）
```

`check.sh` 第 6 项「产物落盘规则」当前是 **10 项**，**T1 之后变 12 项**。其余八项本期不应有任何数字变化——变了就是碰坏了别的东西，停下来查。

### 口径（别混着说）

`check.sh` 九项全绿 **≠** 端到端验证过。真调一次 provider 生一张图并压到 2MB 内的付费 smoke **从未跑过**（本机一个 provider 凭证都没配）。本期不改变这个状态，收尾报告里不许把两者混为一谈。

### 与 spec 的偏离（已论证，实施时照本计划走）

| # | spec 怎么说 | 实际怎么做 | 为什么 |
|---|---|---|---|
| D5 | §12 表格 `md2publish-draft` 那一格：「`md2publish-images` 产物」→「`md2publish-cover` 产物（`assets/<platform>/00-cover.png`）」 | draft 改成**读 sidecar 里记的路径**，并在 §12 表格里同步改掉这一格 | 压缩是**新增不是替换**：超限时 `00-cover.png`（原图）与 `00-cover.jpg`（压缩产物）两个文件并存，`.png` 还占着看起来最"正规"的名字。指向 `.png` 等于把"推草稿箱才发现超过 2MB"原样请回来，而二期 A 把压缩塞进封面流程的全部目的就是消灭它 |
| D6 | §5.3 的 sidecar schema **没有**图片路径字段，但 §12 / `md2publish-cover/SKILL.md:221` / handoff §6 都断言"sidecar 记的路径就是下游该消费的路径" | **先给 `artifacts.py` 的 record 加 `"image"` 字段**（最终产物的文件名），同步改 §5.3 的示例，再动 draft | 实测 `artifacts.py:44-57` 的 record 只有 `bytes`，没有任何路径字段；而 sidecar 文件名是 `image.with_suffix(".json")`，`.png` 和 `.jpg` 算出来**是同一个 `00-cover.json`**，文件名本身无法区分。这个契约三处文档都在承诺、零处实现，D5 直接落空 |
| D7 | §12 正文写"留下**七处**悬空引用"；其下表格 **9 行**；§16 修订记录写"从四处更正为九处" | **以表格为准**，且表格**补 2 行**（`skills/md2publish-cover/SKILL.md`、`skills/_shared/README.md`）→ 共 **11 行**，正文改成"十一处" | 三个数字互相矛盾，表格是唯一真相。补的两行是二期 A 新建的文件，spec 写于二期 A 之前，不是 spec 写错而是过期。实测 `grep -rn` 确认这两处是活引用 |
| D8 | §12 第二张表第一行：`md2publish-article/SKILL.md` 步骤 1 输入表加「存在 `article.illustrated.md` 时优先于 `article.wechat.md`」 | **本期不做，留给三期** | `article.illustrated.md` 是三期 `md2publish-visuals` 才产出的文件。现在写进输入表，等于让 SKILL.md 指示 agent 去找一个任何流程都不会产生的文件。§12 第二张表第二行（步骤 8 补去向与 visuals 次序）本期**照做**，因为它是一句说明而不是一条查找指令 |
| D9 | §12 要求把「封面图/信息图 → md2publish-images」**拆成 cover / visuals / diagram 三个去向** | 只把 `cover` 写成实到的去向；`visuals` / `diagram` 一律标注「三期，尚未实现」，并要求 agent 如实告知用户 | 与 `md2publish-cover/SKILL.md:40-46` 既有措辞保持一致。写成可用去向会让 agent 路由到不存在的 skill |
| D10 | handoff §6：「完成判据：全仓库 grep 不到 `md2publish-images`」 | 判据改为 **`skills/` 与 `docs/handoff/handoff.md` 下 grep 不到**；`docs/superpowers/specs/`、`docs/superpowers/plans/`、`docs/handoff/handoff-image.md`、`.superpowers/` 里的提及**保留** | 那些是历史记录（spec 讲的就是怎么删它、plans 与 sdd report 是二期 A 的执行档案）。改掉等于篡改过去。实测这四类路径下共 35 处提及，全部属历史 |

### 「单 commit 便于 revert」怎么处理

spec §15 / handoff §6 写的是"单 commit 便于 revert"。本计划走**逐任务 commit、把删除放在最后一个 commit**，理由三条：

1. **切分支在这个仓库是危险动作。** 另一个 agent 在同一个 checkout 里并发提交，切到我们的分支后它的 commit 会落到我们分支上（handoff 第四节）。二期 A 就是在 `main` 上逐任务提交跑完 8 个任务的，没出事。
2. **破坏性动作只有一个文件。** `skills/md2publish-images/` 下只有 `SKILL.md` 一个文件（已实测）。回滚是一条命令：`git checkout <T8 的 commit>^ -- skills/md2publish-images/`。
3. **逐任务 commit 才能逐任务过评审。** 二期 A 的教训是八个任务各自全绿、整支评审仍抓出 1 Critical + 6 Important；把八个任务压成一个 commit 会连各自的评审也一并丢掉。

---

## 文件结构

| 文件 | 本期改什么 | 归属任务 |
|---|---|---|
| `skills/_shared/scripts/artifacts.py` | `sidecar()` 的 record 加 `"image"` 字段 | T1 |
| `skills/_shared/scripts/test-artifacts.sh` | 加 2 项断言（10 → 12 项） | T1 |
| `skills/md2publish-cover/shared/scripts/artifacts.py` | **不手改**，由 `sync-shared.sh` 生成 | T1 |
| `docs/superpowers/specs/…-design.md` §5.3 | sidecar 示例加 `"image"` 字段 | T1 |
| `docs/superpowers/specs/…-design.md` §12 §16 | 正文数字、表格补 2 行、draft 那格改成读 sidecar、修订记录追加一条 | T2 |
| `skills/md2publish-article/SKILL.md` | 2 处 | T3 |
| `skills/md2publish-draft/SKILL.md` | 1 处 + 新增一段读 sidecar 的说明 | T4 |
| `skills/wechat-finetune/SKILL.md` | 2 处 | T5 |
| `skills/README.md` | 3 处（工作流图 / skill 表格 / 设计要点） | T6 |
| `docs/handoff/handoff.md` | 3 处 | T7 |
| `skills/_shared/README.md` | 1 处（删掉已完成的待办项） | T7 |
| `skills/md2publish-cover/SKILL.md` | 1 处（去掉对旧路径的提醒） | T7 |
| `skills/md2publish-images/SKILL.md` | **删除** | T8 |
| `docs/handoff/handoff-image.md` | 更新状态到二期 B 已完成 | T8 |

---

### Task 1: sidecar 记录最终产物的文件名

**Files:**
- Modify: `skills/_shared/scripts/artifacts.py`（`sidecar()` 里的 `record` 字面量）
- Modify: `skills/_shared/scripts/test-artifacts.sh`（在 `preset 不存在时硬失败` 那项之前插入）
- Modify: `docs/superpowers/specs/2026-08-09-md2publish-image-skills-design.md`（§5.3 的 JSON 示例）
- Modify: `skills/md2publish-cover/SKILL.md`（步骤 8 里说明 sidecar 记路径的那两行）
- Generated: `skills/md2publish-cover/shared/scripts/artifacts.py`（跑 `sync-shared.sh`，不手改）

**Interfaces:**
- Consumes: 无（本期第一个任务）
- Produces: sidecar JSON 多一个字段 `"image": "<最终产物的文件名>"`，例如 `"00-cover.jpg"`。它是**文件名**（`Path.name`），不是路径——消费方在 sidecar 所在目录下解析它。T4 依赖这个字段名与这个语义。

- [ ] **Step 1: 确认起点**

```bash
git status                                    # 干净或只有别人的改动；有我们的残留就先停下来问
grep -n '"bytes": image.stat' skills/_shared/scripts/artifacts.py
cd skills/_shared/scripts && ./test-artifacts.sh | tail -2 && cd -
```

预期：`grep` 命中一行；测试打印「通过 10 项，失败 0 项」。

- [ ] **Step 2: 写会失败的断言**

在 `skills/_shared/scripts/test-artifacts.sh` 里，**`out=$(run_sidecar no-such-preset)` 那一行之前**插入下面这段。注意 `run_sidecar` 硬编了 `--image "$TMP/exists.png"`，所以第二条断言要单独调 `artifacts.py`，不能复用它。

```bash
got_image=$(jq_get "['image']" 2>&1)
if [[ "$got_image" == "exists.png" ]]; then
  ok "image 记的是最终产物的文件名"
else
  bad "image 字段缺失或不对（下游只能靠猜 .png/.jpg）" "got=${got_image}"
fi

# 为什么必须有这个字段：sidecar 路径是 image.with_suffix('.json')，
# 所以 exists.png 和 exists.jpg 算出来是同一个 exists.json——
# 文件名本身区分不了这两个，只有字段能。
printf 'fake-compressed-bytes' > "$TMP/exists.jpg"
python3 artifacts.py sidecar \
  --image "$TMP/exists.jpg" \
  --platform wechat --archetype cover --preset editorial-warm \
  --provider openai --model gpt-image-2 \
  --prompt-file prompts/wechat/00-cover.md \
  --brief-file briefs/wechat/00-cover.md \
  --alt-text "暖色调编辑风封面" >/dev/null 2>&1
got_image=$(jq_get "['image']" 2>&1)
if [[ "$got_image" == "exists.jpg" ]]; then
  ok "png 与 jpg 共写同一个 .json 时，image 指向压缩产物"
else
  bad "压缩产物没被记下来（draft 会拿到超限的 .png）" "got=${got_image}"
fi
```

- [ ] **Step 3: 跑测试，确认它失败**

```bash
cd skills/_shared/scripts && ./test-artifacts.sh; cd -
```

预期：FAIL，两条新断言都报 `image 字段缺失或不对` / `压缩产物没被记下来`，`got=` 里是一段 `KeyError: 'image'` 的 traceback。末尾「通过 10 项，失败 2 项」。

- [ ] **Step 4: 加字段**

`skills/_shared/scripts/artifacts.py` 的 `sidecar()` 里，把 `"bytes": image.stat().st_size,` 这一行改成两行：

```python
        "image": image.name,
        "bytes": image.stat().st_size,
```

放在 `bytes` 之前，两者都在描述最终产物。**只加这一行**，别动 `record` 里其余字段的顺序或内容。

- [ ] **Step 5: 跑测试，确认它通过**

```bash
cd skills/_shared/scripts && ./test-artifacts.sh; cd -
```

预期：「通过 12 项，失败 0 项」。

- [ ] **Step 6: 同步 vendor 副本并跑全量检查**

```bash
./scripts/sync-shared.sh
./scripts/check.sh
```

预期：九项全 ✓、末尾「全部通过。」，其中第 6 项「产物落盘规则」从 10 项变成 **12 项**，其余八项数字不变。

- [ ] **Step 7: 改 spec §5.3 的示例**

`docs/superpowers/specs/2026-08-09-md2publish-image-skills-design.md` 的 §5.3 JSON 示例里，把 `"bytes": 1843200,` 改成：

```json
  "image": "00-cover.jpg",
  "bytes": 1843200,
```

并在该示例下方那段「它同时解决三件事」的**之前**插入一句：

```markdown
`image` 记的是**最终产物的文件名**（不是路径）：sidecar 写在最终产物旁边、与它同名，
而压缩产物 `.jpg` 与原图 `.png` 算出来是同一个 `.json`，**文件名本身区分不了两者**。
下游要消费哪个文件，一律读这个字段，在 sidecar 所在目录下解析。
```

- [ ] **Step 8: 改 `md2publish-cover/SKILL.md` 步骤 8 的说明**

先 `grep -n "它记录的路径就是下游该消费的路径" skills/md2publish-cover/SKILL.md` 定位，把那两行：

```markdown
sidecar 写在 `${FINAL}` 旁边、与它同名（`$ART/assets/<platform>/00-cover.json`），
里面记的 `bytes` 也是 `${FINAL}` 的字节数。**它记录的路径就是下游该消费的路径。**
```

改成：

```markdown
sidecar 写在 `${FINAL}` 旁边、与它同名（`$ART/assets/<platform>/00-cover.json`），
里面记的 `image`（文件名）和 `bytes` 都是 `${FINAL}` 的。**`image` 字段就是下游该消费的
那个文件**——`.png` 和 `.jpg` 算出来是同一个 `.json`，文件名区分不了，只有这个字段能。
```

- [ ] **Step 9: 复查 vendor 副本没被手改**

```bash
./scripts/check-shared-drift.sh
```

预期：`✅ md2publish-cover：与 _shared/ 一致`。

- [ ] **Step 10: Commit**

```bash
git status                                    # 确认下面这几个路径之外没有我们的改动
git add skills/_shared/scripts/artifacts.py \
        skills/_shared/scripts/test-artifacts.sh \
        skills/md2publish-cover/shared/scripts/artifacts.py \
        skills/md2publish-cover/SKILL.md \
        docs/superpowers/specs/2026-08-09-md2publish-image-skills-design.md
git commit -m "feat(shared): record final artifact filename in sidecar

The sidecar path is image.with_suffix('.json'), so a compressed
00-cover.jpg and the original 00-cover.png resolve to the same
00-cover.json. Nothing in the record told a consumer which file to
take, while three docs already promised it did. Add an explicit
image field."
```

---

### Task 2: 修 spec §12 的数字与表格

**Files:**
- Modify: `docs/superpowers/specs/2026-08-09-md2publish-image-skills-design.md`（§12 正文、§12 第一张表、§16）

**Interfaces:**
- Consumes: T1 产出的 sidecar `image` 字段（§12 里 draft 那一格要引用它）
- Produces: §12 第一张表成为后续 T3–T7 的唯一清单（11 行）。后面每个任务只照这张表做事。

- [ ] **Step 1: 现查活引用，确认表格该有几行**

```bash
grep -rn "md2publish-images" skills/ docs/handoff/handoff.md \
  | grep -v "^skills/md2publish-images/"
```

预期 13 行输出，落在 7 个文件上：`md2publish-article/SKILL.md`(2)、`md2publish-draft/SKILL.md`(1)、`wechat-finetune/SKILL.md`(2)、`skills/README.md`(3)、`docs/handoff/handoff.md`(3)、`skills/md2publish-cover/SKILL.md`(1)、`skills/_shared/README.md`(1)。**若实际输出与此不符，停下来先把差异搞清楚再改表**——多出来的就是新漂进来的引用，少掉的说明别人已经动过。

- [ ] **Step 2: 改 §12 正文的数字**

把：

```markdown
拆除 `md2publish-images` 会留下**七处**悬空引用（不是四处——`wechat-finetune` 和 `handoff.md` 容易被漏）：
```

改成：

```markdown
拆除 `md2publish-images` 会留下**十一处**悬空引用（不是四处、也不是七处——`wechat-finetune` 和 `handoff.md` 容易被漏，最后两行是二期 A 新建的文件，写这份 spec 时还不存在）。**下表是唯一的清单，正文里的任何数字都以它的行数为准**：
```

- [ ] **Step 3: 改表里 `md2publish-draft` 那一行**

把：

```markdown
| `md2publish-draft/SKILL.md` | `:33` 封面来源 | 「md2publish-images 产物」→「md2publish-cover 产物（`assets/<platform>/00-cover.png`）」 |
```

改成（**不许留下 `00-cover.png`**，理由见本计划 D5）：

```markdown
| `md2publish-draft/SKILL.md` | `:33` 封面来源 | 「md2publish-images 产物」→「`md2publish-cover` 产物，**路径读 sidecar `assets/<platform>/00-cover.json` 的 `image` 字段**」。绝不许硬编 `00-cover.png`：压缩是新增不是替换，超限时 `.png` 与 `.jpg` 并存 |
```

- [ ] **Step 4: 表尾补两行**

在 `skills/README.md` 的三行之后追加：

```markdown
| `skills/md2publish-cover/SKILL.md` | 职责边界节末尾 | 删掉「不要去改 `md2publish-images`（那是旧路径，二期 B 才处理）」——旧路径已不存在 |
| `skills/_shared/README.md` | 「还没做的事」列表 | 删掉「`md2publish-images` 的删除与九处引用修改属二期 B」这一项——已完成 |
```

- [ ] **Step 5: 表下方那句「另有两处不是悬空引用」补一句范围说明**

在第二张表的引言那一句后面追加：

```markdown
（其中第一行**属三期**：`article.illustrated.md` 由三期的 `md2publish-visuals` 产出，二期 B 若把它写进输入表，等于让 SKILL.md 指示 agent 去找一个当前任何流程都不会产生的文件。第二行属二期 B。）
```

- [ ] **Step 6: §16 追加一条修订记录**

在 §16 的「**事实更正**」段末尾（`§4.1 补 codex-cli 是经 wrapper 间接 spawn。` 之后）追加：

```markdown

第三版（2026-08-11，二期 B 开工前）：§12 悬空引用**从九处更正为十一处**——正文原写"七处"、表格 9 行、§16 原写"从四处更正为九处"，三个数字互相矛盾，现统一以表格为准，并补上二期 A 新建的 `skills/md2publish-cover/SKILL.md` 与 `skills/_shared/README.md` 两处；§12 表格中 `md2publish-draft` 一格由硬编 `00-cover.png` 改为读 sidecar 的 `image` 字段（压缩是新增不是替换，`.png` 与 `.jpg` 并存）；§5.3 sidecar schema 补 `image` 字段——原 schema 无任何路径字段，而 §12 与 `md2publish-cover/SKILL.md` 都已在断言"sidecar 记的路径就是下游该消费的路径"。
```

- [ ] **Step 7: 自查**

```bash
grep -n "十一处\|七处\|九处" docs/superpowers/specs/2026-08-09-md2publish-image-skills-design.md
awk '/^## 12\./,/^## 13\./' docs/superpowers/specs/2026-08-09-md2publish-image-skills-design.md \
  | grep -c '^| `'
```

预期：第一条只在 §12 正文与 §16 里出现"十一处"，`§12` 正文再无"七处"；第二条输出 `13`（第一张表 11 行数据 + 第二张表 2 行数据，表头行不以 `` | ` `` 开头）。

- [ ] **Step 8: Commit**

```bash
git status
git add docs/superpowers/specs/2026-08-09-md2publish-image-skills-design.md
git commit -m "docs(spec): fix §12 dangling-reference count and draft cover path

Prose said seven, the table had nine rows, §16 said nine. The table is
the only source of truth; two more live references appeared with the
phase-2A files. Also stop pointing draft at 00-cover.png — compression
adds a file, it does not replace one."
```

---

### Task 3: 改 `md2publish-article/SKILL.md`（2 处）

**Files:**
- Modify: `skills/md2publish-article/SKILL.md`

**Interfaces:**
- Consumes: T2 定下的 §12 表格
- Produces: 无（下游不依赖本任务的产出）

- [ ] **Step 1: 定位**

```bash
grep -n "md2publish-images" skills/md2publish-article/SKILL.md
```

预期两行：边界节一行、步骤 8 交接一行。

- [ ] **Step 2: 改边界节那一处**

把：

```markdown
- 用户要封面图 / 信息图时，交接给 `md2publish-images` skill。
```

改成：

```markdown
- 用户要封面图时，交接给 `md2publish-cover` skill。
- 用户要正文配图 / 信息图 / 示意图时，如实说 `md2publish-visuals`（配图、信息图、卡片系列）
  与 `md2publish-diagram`（架构图、流程图）**三期才建、现在还没有**，别用封面流程凑合。
```

- [ ] **Step 3: 改步骤 8 交接那一处**

把：

```markdown
- 需要封面图 → `md2publish-images`
- 要推草稿箱 → `md2publish-draft`
- 只要 HTML → 结束
```

改成：

```markdown
- 需要封面图 → `md2publish-cover`（与本 skill 并行，封面不进正文）
- 需要正文配图 / 信息图 / 示意图 → `md2publish-visuals` / `md2publish-diagram`，
  **三期，尚未实现**，如实说。三期落地后 `visuals` 要跑在本 skill **之前**——
  它回写出的 `article.illustrated.md` 才是本 skill 的输入
- 要推草稿箱 → `md2publish-draft`
- 只要 HTML → 结束
```

- [ ] **Step 4: 确认没有顺手改到步骤 1 的输入表**

```bash
grep -n "article.illustrated.md" skills/md2publish-article/SKILL.md
```

预期：**只有步骤 8 那一处**命中。步骤 1 的输入表本期不动（D8）——若这里出现第二处命中在步骤 1 附近，删掉它。

- [ ] **Step 5: 验证**

```bash
grep -n "md2publish-images" skills/md2publish-article/SKILL.md; echo "rc=$?"
```

预期：无输出，`rc=1`。

- [ ] **Step 6: Commit**

```bash
git status
git add skills/md2publish-article/SKILL.md
git commit -m "docs(article): route cover handoff to md2publish-cover

visuals/diagram stay marked as phase 3 and unimplemented so the agent
does not route users to a skill that does not exist."
```

---

### Task 4: 改 `md2publish-draft/SKILL.md`（1 处 + 一段说明）

**Files:**
- Modify: `skills/md2publish-draft/SKILL.md`

**Interfaces:**
- Consumes: T1 产出的 sidecar `image` 字段（文件名，在 sidecar 所在目录下解析）
- Produces: 无

- [ ] **Step 1: 定位**

```bash
grep -n "md2publish-images" skills/md2publish-draft/SKILL.md
```

预期一行，在步骤 2 的材料表里。

- [ ] **Step 2: 改表格那一行**

把：

```markdown
| 封面图 | 用户指定 → md2publish-images 产物 → 询问用户 |
```

改成：

```markdown
| 封面图 | 用户指定 → `md2publish-cover` 产物（**路径读 sidecar，见表下**）→ 询问用户 |
```

- [ ] **Step 3: 在材料表下方、「元数据硬限制」那段之前插入说明**

````markdown
**封面来自 `md2publish-cover` 时，路径从 sidecar 里读，不许硬编 `00-cover.png`。**
压缩是**新增不是替换**：封面超过 2MB 时，原图 `00-cover.png` 与压缩产物 `00-cover.jpg`
**两个文件同时存在**，而 `.png` 恰好占着看起来最"正规"的那个名字。拿错就等于把
"推草稿箱才发现封面超限"这个失败模式请回来。

```bash
# $ART 是文章目录，<platform> 通常是 wechat
SIDECAR="$ART/assets/<platform>/00-cover.json"
COVER=$(python3 -c "import json,pathlib,sys; p=pathlib.Path(sys.argv[1]); \
print(p.parent / json.load(p.open())['image'])" "$SIDECAR")
```

`image` 字段记的是最终产物的**文件名**：未超限时是 `.png`、超限时是 `.jpg`，两种情况都由它
说了算，调用方不需要自己判断，也不要去比较两个文件谁更大或谁更新。sidecar 不存在时
（用户从别处拿的图）直接问用户要路径，别猜。
````

- [ ] **Step 4: 验证**

```bash
grep -n "md2publish-images" skills/md2publish-draft/SKILL.md; echo "rc=$?"
grep -n "00-cover.png" skills/md2publish-draft/SKILL.md
```

预期：第一条无输出、`rc=1`；第二条只在那段说明的**警告语境**里命中（"不许硬编"、"原图"），**不出现在任何一条要执行的命令里**。

- [ ] **Step 5: 端到端验一次读法**

```bash
T=$(mktemp -d); mkdir -p "$T/assets/wechat"
printf 'x' > "$T/assets/wechat/00-cover.jpg"
printf '{"image":"00-cover.jpg","bytes":1}' > "$T/assets/wechat/00-cover.json"
python3 -c "import json,pathlib,sys; p=pathlib.Path(sys.argv[1]); \
print(p.parent / json.load(p.open())['image'])" "$T/assets/wechat/00-cover.json"
rm -rf "$T"
```

预期：打印出以 `/assets/wechat/00-cover.jpg` 结尾的绝对路径。SKILL.md 里那段命令若打不出来，是命令写错了，改到能跑为止。

- [ ] **Step 6: Commit**

```bash
git status
git add skills/md2publish-draft/SKILL.md
git commit -m "docs(draft): read cover path from the sidecar

Never hardcode 00-cover.png: compression writes a new .jpg beside the
oversized .png, and the .png keeps the more official-looking name.
Hardcoding it reintroduces the exact failure phase 2A removed."
```

---

### Task 5: 改 `wechat-finetune/SKILL.md`（2 处）

**Files:**
- Modify: `skills/wechat-finetune/SKILL.md`

**Interfaces:**
- Consumes: T2 定下的 §12 表格
- Produces: 无

- [ ] **Step 1: 定位**

```bash
grep -n "md2publish-images" skills/wechat-finetune/SKILL.md
```

预期两行：完整链路一行、步骤 8 交接一行。

- [ ] **Step 2: 改完整链路那一处**

把：

```markdown
推荐的完整链路：`tech-writer` → `tech-writer-deslop` → **`wechat-finetune`** → `md2publish-article` → `md2publish-images` → `md2publish-draft`。
```

改成：

```markdown
推荐的完整链路：`tech-writer` → `tech-writer-deslop` → **`wechat-finetune`** → `md2publish-article` → `md2publish-draft`。封面走 `md2publish-cover`，与 `md2publish-article` 并行、不进正文。（三期的 `md2publish-visuals` 会把正文配图回写进 Markdown，届时它串在 `md2publish-article` **之前**，不是并行分支。）
```

- [ ] **Step 3: 改步骤 8 交接那一处**

把：

```markdown
报告产物路径、改动清单、自检结果，然后问下一步：转 HTML 走 `md2publish-article`，要配图走 `md2publish-images`。不要未经询问就往下走。
```

改成：

```markdown
报告产物路径、改动清单、自检结果，然后问下一步：转 HTML 走 `md2publish-article`，要封面走 `md2publish-cover`；要正文配图 / 信息图 / 示意图，如实说 `md2publish-visuals` / `md2publish-diagram` **三期才建、现在没有**，别拿封面流程凑合。不要未经询问就往下走。
```

- [ ] **Step 4: 验证**

```bash
grep -n "md2publish-images" skills/wechat-finetune/SKILL.md; echo "rc=$?"
```

预期：无输出，`rc=1`。

- [ ] **Step 5: Commit**

```bash
git status
git add skills/wechat-finetune/SKILL.md
git commit -m "docs(finetune): update pipeline handoff to cover skill"
```

---

### Task 6: 改 `skills/README.md`（3 处）

**Files:**
- Modify: `skills/README.md`

**Interfaces:**
- Consumes: T2 定下的 §12 表格；spec §2（免费路径口径）、§8（流水线次序）、§9（副作用与确认边界）
- Produces: 无

- [ ] **Step 1: 定位**

```bash
grep -n "md2publish-images" skills/README.md
```

预期三行：工作流图里一行、skill 表格一行、设计要点一行。

- [ ] **Step 2: 重画工作流图**

把「## 工作流」下整个代码块替换成下面这个。关键是 **`visuals` 串在 `article` 上游、不是并行分支**（spec §8：画成并行框会让 `article.illustrated.md` 静默地永远不被转换），同时**如实标注它还没实现**：

```
article.md（tech-writer → tech-writer-deslop 产出的成稿）
   │
   ▼
┌─────────────────────┐
│   wechat-finetune   │  重拟标题 / 删难懂与无关 / 开篇钩子
│   公众号平台适配     │  段落切短 / frontmatter 元数据
│   (零副作用)        │  原文不动，另存
└─────────┬───────────┘
          │  article.wechat.md
          ▼
┌──────────────────────────┐
│   md2publish-visuals     │  正文配图 / 信息图 / 卡片系列
│   (三期，尚未实现)        │  回写图片引用，另存
└─────────┬────────────────┘
          │  article.illustrated.md（有配图时下游吃它，没配图时下游吃 article.wechat.md）
          ▼
┌─────────────────────┐      ┌──────────────────────────────┐
│  md2publish-article │      │      md2publish-cover        │
│  md → 内联样式 HTML  │      │  真调 provider 生图（花钱）    │
│  (AI 模式, 零副作用) │      │  assets/<platform>/00-cover.*│
└─────────┬───────────┘      └──────────────┬───────────────┘
          │  article.html                   │  以 sidecar 记的路径为准
          └───────────────┬─────────────────┘
                          ▼
               ┌─────────────────────┐
               │  md2publish-draft   │
               │  用户确认 → 传图 →   │
               │  create_draft 草稿箱 │
               └─────────────────────┘
```

在代码块下方、「`wechat-finetune` 之前的两步…」那段之前插入一句：

```markdown
`md2publish-diagram`（三期，尚未实现）视用途而定：示意图要进正文，就必须在 `md2publish-article`
之前被引用进 Markdown；只单独导出一张图，则与这条流水线无耦合。
```

- [ ] **Step 3: 改 skill 表格**

删掉整行：

```markdown
| `md2publish-images` | 封面/信息图（计划模式交宿主 Agent 生成） | 无 | 无 |
```

其余四行不动。在表格下方插入：

```markdown
`md2publish-visuals`（正文配图 / 信息图 / 卡片系列，会**回写 Markdown**）与
`md2publish-diagram`（架构图 / 流程图，不调 AI、零 API 成本）属**三期，尚未实现**。
用户要这两类图时如实说还没建，别用封面流程凑合。
```

- [ ] **Step 4: 重写设计要点**

把「## 设计要点」下的四个 bullet 整体替换成：

```markdown
- **免费路径**：指 **md2publish 系统本身不收费**（不需要 `MD2WECHAT_API_KEY`）——
  `convert --mode ai` 产出排版指令，HTML 由 Agent 生成；草稿走 `upload_image` + `create_draft`
  （不走需要 API key 的 `convert --draft`）。**图片模型的费用不在此列**
- **两道门，性质不同**：
  - **花钱的门**在 `md2publish-cover` 的生成那一步（步骤 5），前四步仍然零成本——
    没配 provider 也能拿到 prompt 文件自己去生。单张封面不额外问；批量生成（三期
    `visuals`）才报「将生成 N 张 / 预估 ¥X / provider / model」再确认
  - **外部系统的门**仍然只有 `md2publish-draft` 一处（写微信素材库、草稿箱），强制用户确认
- **「配图零副作用」已作废**：那是旧计划模式的口径。`md2publish-cover` 真调 provider、
  真花钱、不可逆；三期的 `visuals` 还会回写 Markdown（另存 `article.illustrated.md`，
  与 `wechat-finetune`「原文不动，另存」一致）
- **不用 `test-draft` 发正式文章**：其标题在 CLI 内硬编码，仅作连通性冒烟
```

- [ ] **Step 5: 验证**

```bash
grep -n "md2publish-images" skills/README.md; echo "rc=$?"
grep -n "md2publish-visuals" skills/README.md
```

预期：第一条无输出、`rc=1`；第二条至少三处命中，且**每一处都带着「三期」或「尚未实现」字样**（逐条肉眼确认，别只看命中数）。

- [ ] **Step 6: Commit**

```bash
git status
git add skills/README.md
git commit -m "docs(readme): redraw pipeline with visuals upstream of article

Per spec §8: drawing visuals as a parallel branch is what makes
article.illustrated.md silently never get converted. It is marked
unimplemented (phase 3) rather than presented as available."
```

---

### Task 7: 改 `handoff.md`(3) + `_shared/README.md`(1) + `md2publish-cover/SKILL.md`(1)

**Files:**
- Modify: `docs/handoff/handoff.md`
- Modify: `skills/_shared/README.md`
- Modify: `skills/md2publish-cover/SKILL.md`

**Interfaces:**
- Consumes: T2 定下的 §12 表格（含新补的两行）
- Produces: 无

> **注意：`docs/handoff/handoff.md` 是另一条线（主题库 / HTML 生成）的交接文档，那个 agent 可能正在改它。** 开工前 `git status` 看一眼它是否被改动；改动只碰下面三处，别顺手动别的段落；`git add` 只加这三个显式路径。

- [ ] **Step 1: 定位**

```bash
grep -n "md2publish-images" docs/handoff/handoff.md skills/_shared/README.md skills/md2publish-cover/SKILL.md
```

预期五行：`handoff.md` 三行（skill 清单、完整链路、"未实测"节）、另两个文件各一行。

- [ ] **Step 2: 改 `handoff.md` 的 skill 清单**

把：

```markdown
- `skills/md2publish-images/` — 封面/信息图（`--plan` 计划模式，交宿主 agent 生成）
```

改成：

```markdown
- `skills/md2publish-cover/` — 封面图（微信 / 小红书两种画幅，真调 provider 生成：花钱、不可逆；最终产物路径以 sidecar 的 `image` 字段为准，压缩后 `.png` 与 `.jpg` 并存）
```

- [ ] **Step 3: 改 `handoff.md` 的完整链路**

把那一句结尾处的 “→ md2publish-article → md2publish-images → md2publish-draft”（三个 skill 名都带反引号）改成：

```markdown
→ `md2publish-article` → `md2publish-draft`（封面并行走 `md2publish-cover`）
```

同句其余部分（前两个 skill 在另一个仓库、三者判据不重叠那些话）**一字不动**。

- [ ] **Step 4: 改 `handoff.md` 的「未实测」节**

把：

```markdown
- **`wechat-finetune` 未实测**，eval 循环未跑
- **`md2publish-images` 从未实测**（宿主生图 + 上传封面未走通）
```

改成：

```markdown
- **`wechat-finetune` 未实测**，eval 循环未跑
- **`md2publish-cover` 的端到端付费 smoke 未跑**：本机一个 provider 凭证都没配，
  真调一次 provider 生一张图并压到 2MB 内这一步从未做过。它的九项机械检查全绿，
  但**九项绿不等于端到端验证过**。（旧的 `md2publish-images` 已于二期 B 删除，
  它同样从未实测过）
```

小节标题 `### 4. 未实测的两个 skill` **不改**——改完仍是两项。

- [ ] **Step 5: 改 `skills/_shared/README.md`**

在「## 还没做的事」列表里，**整条删掉**：

```markdown
- **对现有 skill 的改动** —— `md2publish-images` 的删除与九处引用修改属二期 B。
```

它已经做完了，留在"还没做的事"里就是错的。其余四条不动。

- [ ] **Step 6: 改 `skills/md2publish-cover/SKILL.md` 的职责边界节**

把：

```markdown
三期之前，用户要插图或示意图时**如实说这两个 skill 还没建**，
不要用封面流程凑合，也不要去改 `md2publish-images`（那是旧路径，二期 B 才处理）。
```

改成：

```markdown
三期之前，用户要插图或示意图时**如实说这两个 skill 还没建**，不要用封面流程凑合。
封面只有本 skill 这一个入口。
```

- [ ] **Step 7: 验证**

```bash
grep -n "md2publish-images" docs/handoff/handoff.md skills/_shared/README.md skills/md2publish-cover/SKILL.md
echo "rc=$?"
./scripts/check.sh | tail -5
```

预期：第一条无输出、`rc=1`（`md2publish-cover/SKILL.md` 被 `check.sh` 的漂移检查覆盖，所以顺手跑一遍）；`check.sh` 仍然「全部通过。」。

- [ ] **Step 8: Commit**

```bash
git status                              # 另一个 agent 若也改了 handoff.md，只 add 我们改的那个文件，别管它的暂存区
git add docs/handoff/handoff.md skills/_shared/README.md skills/md2publish-cover/SKILL.md
git commit -m "docs(handoff): drop md2publish-images from live docs

Also corrects the untested-skills note: md2publish-cover's paid
end-to-end smoke has never run, and nine green mechanical checks are
not the same claim."
```

---

### Task 8: 删除 `md2publish-images` 并收尾

**Files:**
- Delete: `skills/md2publish-images/SKILL.md`（该目录下只有这一个文件，已实测）
- Modify: `docs/handoff/handoff-image.md`

**Interfaces:**
- Consumes: T3–T7 已经改完全部十一处活引用
- Produces: 本期完成状态，写进 handoff 供下一个会话接手

- [ ] **Step 1: 删除前确认所有活引用都改完了**

```bash
grep -rn "md2publish-images" skills/ docs/handoff/handoff.md \
  | grep -v "^skills/md2publish-images/"
echo "rc=$?"
```

预期：无输出，`rc=1`。**有任何输出就回到对应任务补完，不许带着悬空引用往下删。**

- [ ] **Step 2: 确认要删的东西只有一个文件**

```bash
find skills/md2publish-images -type f
```

预期：只有 `skills/md2publish-images/SKILL.md` 一行。**多出任何文件就停下来问用户**——那说明有人在这期间往里加了东西，删掉会丢别人的工作。

- [ ] **Step 3: 删除**

```bash
git rm -r skills/md2publish-images
```

- [ ] **Step 4: 跑完整验证**

```bash
./scripts/check.sh
python3 skills/md2publish-article/scripts/test-theme-lib.py
```

预期：`check.sh` 九项全 ✓、末尾「全部通过。」，第 6 项是 **12 项**（T1 之后的新数字），其余八项数字与本期开工时一致；`test-theme-lib.py` 打印「ok：0 条失败」。

- [ ] **Step 5: 跑完成判据**

```bash
grep -rn "md2publish-images" skills/ docs/handoff/handoff.md; echo "rc=$?"
```

预期：无输出、`rc=1`。

`docs/superpowers/specs/`、`docs/superpowers/plans/`、`docs/handoff/handoff-image.md`、`.superpowers/` 下仍然会命中——**那是历史记录，本来就该留着**（本计划 D10）。别为了让 `grep -r .` 变干净去改它们。

- [ ] **Step 6: 更新 `docs/handoff/handoff-image.md`**

三处改动：

1. 「快速接手入口」第 2、3 条：把「二期 A 已完成…下一步是二期 B」改成二期 B 已完成、下一步是三期（`md2publish-visuals` + `md2publish-diagram`），并写明三期的实施计划尚未编写。
2. 第六节「二期 B」那一整块：改成已完成的记述，保留那条 ⚠️ 硬约束（它现在是 `md2publish-draft` 的既成契约，不是待办），并把「九处」更正为「十一处」、把完成判据改成 D10 的范围版。
3. 第六节「三期」那块之前，追加一条二期 B 的教训（见下一步）。

- [ ] **Step 7: 把本期的跨组件发现写进第八节**

在第八节「二期 A（四条）」之后追加：

```markdown
**二期 B（一条）**

8. **文档三处承诺的契约，代码里一处都没实现。** spec §12、`md2publish-cover/SKILL.md`
   步骤 8、handoff 第六节的硬约束，全都写着"读 sidecar 里记的路径"，而 `artifacts.py`
   写出的 sidecar **根本没有路径字段**——只有 `bytes`。更糟的是 sidecar 路径是
   `image.with_suffix(".json")`，压缩产物 `.jpg` 与原图 `.png` 算出来**是同一个
   `00-cover.json`**，文件名本身也区分不了。照 spec 原样执行二期 B，只会退回硬编
   `00-cover.png`，正是二期 A 要消灭的失败模式。
   **教训：一条契约被多份文档反复引用，不等于它被实现过。跨组件的"谁读谁"改动，
   动手前先去读被读那一方的代码，确认它真的写了那个字段。**
```

- [ ] **Step 8: Commit**

```bash
git status
git add -u skills/md2publish-images
git add docs/handoff/handoff-image.md
git status                                # 确认暂存区里只有这两项
git commit -m "feat!: remove md2publish-images

All eleven live references now point at md2publish-cover. Historical
mentions in specs, plans and .superpowers are execution records and
stay as they are.

Revert with: git checkout <this commit>^ -- skills/md2publish-images/"
```

- [ ] **Step 9: 整支评审**

逐任务评审替代不了整支评审——二期 A 八个任务各自全绿，整支评审仍抓出 1 Critical + 6 Important，全是跨组件问题。用 `superpowers:requesting-code-review`，评审范围取本期第一个 commit 的**父提交**到 `HEAD`（**不要**拿 `main` 当基线，另一个 agent 的 commit 夹在中间）：

```bash
FIRST=$(git log --oneline --grep='record final artifact filename in sidecar' --format=%H | tail -1)
git diff ${FIRST}^..HEAD -- skills docs
```

评审时重点问三件事：

1. 十一处改完之后，**有没有哪份文档现在把 `visuals` / `diagram` 说得像是可用的**？
2. `md2publish-draft` 拿封面的那条路径，**在 sidecar 缺失、`image` 字段缺失、图片被手工挪走三种情况下分别会怎样**？
3. `check.sh` 第 6 项从 10 变 12，**其余八项的数字有没有意外变动**？

---

## Self-Review

**spec 覆盖**：§12 第一张表 11 行 → T2 补齐后由 T3(2)/T4(1)/T5(2)/T6(3)/T7(5) 全部覆盖；§12 第二张表第二行 → T3 Step 3；第一行 → 明示留给三期（D8）。§5.3 → T1 Step 7。§2 免费路径口径、§9 确认边界 → T6 Step 4。§8 流水线次序 → T6 Step 2。§15 二期 B 的删除动作 → T8。**未覆盖且属有意**：§12 第二张表第一行（D8）、端到端付费 smoke（无凭证，本期不改变其状态）。

**占位符扫描**：无 TBD / TODO；每一处文档改动都给了完整的替换前后原文；每一条验证都给了可执行命令与预期输出。

**类型一致性**：sidecar 新字段在 T1（定义 `"image": image.name`，即**文件名**）、T1 Step 7（spec §5.3）、T1 Step 8（cover SKILL.md）、T2 Step 3（spec §12）、T4 Step 3（draft 的读法）五处出现，命名与语义一致——都是"文件名，在 sidecar 所在目录下解析"，没有任何一处把它当成完整路径。
