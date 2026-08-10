# 二期 A：搬入 imagegen 引擎 + 建 md2publish-cover 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal：** 让本仓库能从一篇公众号文章端到端产出一张微信封面并压到 2MB 内，全程纯新增，`md2publish-images` 原地不动。

**Architecture：** `skills/_shared/` 已有的资产层（platform profile / preset / 维度词表 / `compose_prompt.py`）之上，补三层：**引擎层**（从 `baoyu-image-gen` vendor 进来的 TypeScript `imagegen/`，真调 provider）、**机械层**（`compress.py` / `preflight.py` / `config.py` / `artifacts.py`，全是确定性 Python，可脱离模型测试）、**语义层**（`md2publish-cover/SKILL.md`，agent 写 brief、选 preset、过成本门）。三层之间只用命令行参数和文件通信，没有共享状态。`_shared/` 是唯一真相源，`scripts/sync-shared.sh` 按 §4.3 的子集清单把它 vendor 进 `skills/md2publish-cover/shared/`，`check-shared-drift.sh` 比 hash 防止有人改错地方。

**Tech Stack：** Python 3.9.13（anaconda3）+ PyYAML 6.0；bun 1.3.14（TypeScript，无构建步骤，零 npm 依赖）；sips / ImageMagick（压缩）；bash + `bun test` 做测试。

**设计真相源：** `docs/superpowers/specs/2026-08-09-md2publish-image-skills-design.md`（§15 二期 A）。本计划不重复 spec 的论证，只给可执行步骤。

---

## Global Constraints

每个任务的要求都隐含包含本节，不再逐条重复。

- **Python 版本是 3.9.13。** 每个新增 `.py` 文件的 import 区第一行必须是 `from __future__ import annotations`，否则 `dict | None` 这类 PEP 604 注解在 import 时就抛 `TypeError`。一期栽过一次。
- **`mv` 在这台机器上是交互式的**（覆盖时等 y/n，自动化里表现为卡死）。脚本里一律用 `\cp -f` / `\cp -Rf`，不用 `mv`。
- **仓库里可能有另一个 agent 在工作。** 只用显式路径 `git add <path>`，**绝不** `git add -A` / `git commit -a`。每个任务开工前先 `git status`。
- **commit message 与分支名一律英文**（`CLAUDE.md` Rule 0 / handoff §5，2026-08-10 由用户再次确认）。文档内容中文。
- **本仓库没有 CI、没有 git hooks、没有 `.github/`。** 所有测试手跑。任何文档都不许把 `check.sh` 写成"自动闸门"，它是**有文档约束的手工流程**。
- **占位符固定白名单**：`PLATFORM_FRAME` / `PALETTE` / `RENDERING` / `LAYOUT` / `CONTENT`。集合外硬失败。
- **`compose_prompt.py` 不读文章原文、不调模型。** 语义部分走 agent 写的 brief 文件。本期新增的任何脚本同样遵守：机械层不做语义判断。
- **平台不支持某 archetype 时槽值是 `unsupported`，遇到硬失败，不静默回退。**
- **`max_bytes` 一律整数字节**，不写 `2MB`。
- **文字策略契约串** `图上必须包含` / `图上不要出现标题文字` 由 `compose_prompt.py:render_platform_frame` 产生，被 `test-compose-prompt.sh` 和 `test-platform-matrix.sh` 同时 grep。本期不许改这三处任何一处的措辞。
- **`md2publish-images` 本期一个字都不改。** 它的删除与九处引用修改属二期 B。
- **`_shared/` 是唯一真相源。** 任何时候发现 `skills/md2publish-cover/shared/` 与 `_shared/` 不一致，正确动作永远是"把改动挪回 `_shared/` 再 re-sync"，绝不是"re-sync 覆盖掉"。

### 本期基线（每个任务开工前应仍然成立）

```bash
cd skills/_shared/scripts
./test-asset-schema.sh      # 通过 13 项，失败 0 项（T4 之后变成 17 项）
./test-compose-prompt.sh    # 通过 11 项，失败 0 项
./test-platform-matrix.sh   # 通过 8 项，失败 0 项
cd - && python3 skills/md2publish-article/scripts/test-theme-lib.py   # ok：0 条失败
```

### 实施前已实测的环境事实（别再猜，也别重新验证）

| 事实 | 值 |
|---|---|
| Python | 3.9.13（anaconda3），PyYAML 6.0 已装 |
| bun | 1.3.14 已装；node v22.13.1 |
| 压缩工具 | `sips`（/usr/bin）、`magick`（/opt/homebrew/bin）、`cwebp`（anaconda3/bin）三者都在 |
| `shutil.which(x, path="")` | 返回 `None`（因此失败分支可以在全绿机器上测出来） |
| vendor 后的 `bun test` | **97 pass / 0 fail / 12 files**，不需要 `package.json`、不需要 `tsconfig.json` |
| baoyu-skills 上游 HEAD | `6b7a2e4` |

### 与 spec 的四处偏离（已确认，实施时照本计划走）

| # | spec 怎么说 | 实际怎么做 | 为什么 |
|---|---|---|---|
| D1 | §4.1：`codex-cli` 经 `packages/baoyu-codex-imagegen` wrapper 间接 spawn，"两层要一起搬" | **首批不搬 codex-cli**。删 `providers/codex-cli.ts` + 测试，`loadProviderModule` 里改成硬失败 | 用户决策（2026-08-10）。另：spec 这条已过期——wrapper 现在**已经内联**在 `skills/baoyu-image-gen/scripts/codex-imagegen/`（7 个文件），不在 `packages/` 下。不搬 = 少 9 个文件、少一层 spawn |
| D2 | §9：单张最多 **2 次**计费尝试 | vendor 时把 `main.ts` 的 `MAX_ATTEMPTS` 由 `3` 改成 `2` | 引擎默认重试 3 次，超时类错误可能每次都已计费。已实测该常量无测试断言，改后仍 97 pass |
| D3 | §4/§11：压缩降级链 `sips → cwebp → ImageMagick` | 改成 `sips → magick`，**cwebp 需显式 `--allow-webp` 才启用** | `cwebp` 只产出 WebP，而目标平台是否接受 WebP 属未核实的外部知识。默认产出 JPEG，不静默交付一个可能用不了的格式。`preflight.py` 仍然三个都检查 |
| D4 | §4.3 的 vendor 清单表没列 `asset_lib.py` | 清单里加上 `scripts/asset_lib.py` | 它是 `compose_prompt.py` / `artifacts.py` 的硬 import 依赖，不带上 vendor 出来的 skill 直接不能跑 |

另有一处 **spec 自身的错数字**，本期不改、留给二期 B 开工时改：§12 正文首句写"留下**七处**悬空引用"，而其下表格是 9 行、§16 修订记录写的是"从四处更正为九处"。二期 B 照正文抄会漏两处。

---

## 文件结构

| 文件 | 责任 |
|---|---|
| `skills/_shared/scripts/imagegen/` | vendor 进来的生图引擎（TS）。**除 D1/D2 两处外逐字不改**，保持可与上游 diff |
| `skills/_shared/scripts/imagegen/VENDOR.md` | 来源、上游 commit、排除了什么、改了哪两行、怎么重新同步 |
| `skills/_shared/scripts/compress.py` | 把图压到字节上限内。只做机械压缩，压不下去硬失败 |
| `skills/_shared/scripts/config.py` | 读 `~/.config/md2publish/images.yaml`。md2publish 自己的偏好，不碰 baoyu 的 EXTEND.md |
| `skills/_shared/scripts/preflight.py` | 三项自检：TS 运行时 / provider 凭证 / 压缩工具。只报告不阻塞 |
| `skills/_shared/scripts/artifacts.py` | 产物落盘规则：`guard`（重跑保护）+ `sidecar`（元数据） |
| `skills/_shared/costs.yaml` | provider × model 单张估价，允许 `unknown` |
| `skills/_shared/scripts/test-compress.sh` 等 3 个 | 新脚本的测试 |
| `scripts/shared-manifest.sh` | vendor 子集清单。**唯一定义处**，被 sync 与 drift 两个脚本 source |
| `scripts/sync-shared.sh` | `_shared/` → `skills/<skill>/shared/` |
| `scripts/check-shared-drift.sh` | 比对，漂移则打印"改动挪回 `_shared/`"+ diff 并 fail |
| `scripts/check.sh` | 串起全部测试 + 漂移检查 |
| `skills/md2publish-cover/SKILL.md` | 语义层：8 步执行链路 |
| `skills/md2publish-cover/shared/` | 由 `sync-shared.sh` 生成，不手改 |

**为什么 `guard` 和 `sidecar` 合在一个 `artifacts.py` 里：** 它们是 spec §7.3 与 §5.3 两条相邻规则，管的是同一件事——"花钱产出的文件怎么落盘"。分成两个 20 行脚本会让 `check.sh` 和 vendor 清单各多一项，收益为零。

---

### Task 1: vendor imagegen 引擎

**Files:**
- Create: `skills/_shared/scripts/imagegen/main.ts`（从上游拷贝 + 2 处修改）
- Create: `skills/_shared/scripts/imagegen/main.test.ts`、`types.ts`（逐字拷贝）
- Create: `skills/_shared/scripts/imagegen/providers/*.ts`（11 个 provider + 11 个 `.test.ts`，逐字拷贝）
- Create: `skills/_shared/scripts/imagegen/VENDOR.md`
- Test: `bun test skills/_shared/scripts/imagegen`

**Interfaces:**
- Consumes: 无（本期第一个任务）
- Produces: 命令行入口 `bun <path>/imagegen/main.ts --promptfiles <f...> --image <out> --ar <ratio> [--provider <p>] [--model <m>] [--json]`。单图模式成功时 **stdout 只有产物绝对路径**一行（`--json` 时是 `{"savedImage","provider","model","attempts","prompt"}`）；日志全走 stderr；失败退出码 1。合法 provider 11 个：`google` `openai` `azure` `openrouter` `dashscope` `zai` `minimax` `replicate` `jimeng` `seedream` `agnes`。

**排除清单（不要拷这些）：**

| 排除项 | 文件数 | 理由 |
|---|---|---|
| `providers/codex-cli.ts` + `.test.ts` | 2 | D1，用户决策不含 codex-cli |
| `codex-imagegen/`（`main.ts` `spawn.ts` `parser.ts` `cache.ts` `logger.ts` `types.ts` `validator.ts`） | 7 | 同上，这是 codex-cli 的 wrapper 实现 |
| `build-batch.ts` + `.test.ts` | 2 | baoyu 自己的"大纲 → batch.json"转换器，假定 baoyu 的大纲格式；本仓库的 batch 由 visuals（三期）自己生成。且它的 5 个测试依赖 `tsx`，在本机必失败 |
| `references/`、`SKILL.md` | 13 | baoyu 的文档，不是引擎 |
| `.ccmem/`、`scripts/.ccmem/` | 2 | 已在 `.gitignore` |

- [ ] **Step 1: 建目录并拷贝引擎文件**

```bash
cd /Users/biran/code/skills/writing/md2publish-skills
SRC=../baoyu-skills/skills/baoyu-image-gen/scripts
DST=skills/_shared/scripts/imagegen

mkdir -p "$DST/providers"
\cp -f "$SRC/main.ts" "$SRC/main.test.ts" "$SRC/types.ts" "$DST/"
for f in "$SRC"/providers/*.ts; do
  case "$(basename "$f")" in
    codex-cli*) echo "skip $(basename "$f")" ;;
    *) \cp -f "$f" "$DST/providers/" ;;
  esac
done
find "$DST" -type f | wc -l    # 期望：25（main.ts + main.test.ts + types.ts + 11 provider + 11 test）
```

- [ ] **Step 2: 打上两处修改**

两处都必须打；只打一处会在运行时才暴露。

```bash
python3 - skills/_shared/scripts/imagegen/main.ts <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text(encoding="utf-8")

# D1：codex-cli 未 vendor，硬失败并列出可用 provider，不静默 import 一个不存在的模块
old_import = '  if (provider === "codex-cli") return (await import("./providers/codex-cli")) as ProviderModule;\n'
new_import = (
    '  if (provider === "codex-cli") {\n'
    '    throw new Error(\n'
    '      "codex-cli provider is not vendored in md2publish-skills. '
    'Use --provider with one of: google, openai, azure, openrouter, dashscope, zai, minimax, replicate, jimeng, seedream, agnes."\n'
    '    );\n'
    '  }\n'
)
assert old_import in s, "D1 anchor not found — upstream changed, stop and re-read main.ts"
s = s.replace(old_import, new_import)

# D2：spec §9 的计费尝试上限是 2，不是 3
old_attempts = "const MAX_ATTEMPTS = 3;"
new_attempts = "const MAX_ATTEMPTS = 2;"
assert old_attempts in s, "D2 anchor not found — upstream changed, stop and re-read main.ts"
s = s.replace(old_attempts, new_attempts)

p.write_text(s, encoding="utf-8")
print("patched D1 + D2")
PY
```

- [ ] **Step 3: 跑引擎测试，确认 97 pass**

```bash
(cd skills/_shared/scripts/imagegen && bun test) 2>&1 | tail -3
```

期望：

```
 97 pass
 0 fail
Ran 97 tests across 12 files.
```

用 `cd` 进去跑而不是 `bun test <path>`：后者是**路径过滤器**不是目录参数，从仓库根跑会把
整个仓库扫一遍，且 vendor 之后 `skills/md2publish-cover/shared/scripts/imagegen/` 里
还有一份同名测试，容易误判跑了几份。

不是 97 就停下来排查，别往下走。少于 97 通常是漏拷了 provider；出现 fail 且信息里有 `Cannot find module './cjs/index.cjs'` 说明误拷了 `build-batch.test.ts`。

- [ ] **Step 4: 验证三条运行时行为**

```bash
D=skills/_shared/scripts/imagegen
echo "test prompt" > /tmp/mp-probe.md

# a) --help 能跑
bun $D/main.ts --help >/dev/null && echo "a ok"

# b) codex-cli 硬失败，退出码 1（注意：不能接管道，否则 $? 是管道末端的）
bun $D/main.ts --provider codex-cli --promptfiles /tmp/mp-probe.md --image /tmp/mp-x.png >/dev/null 2>/tmp/mp-err.txt
[ $? -eq 1 ] && grep -q "not vendored" /tmp/mp-err.txt && echo "b ok"

# c) 无任何 key 时报清晰错误而不是崩栈
env -u OPENAI_API_KEY -u GOOGLE_API_KEY -u GEMINI_API_KEY -u OPENROUTER_API_KEY \
    -u DASHSCOPE_API_KEY -u ZAI_API_KEY -u BIGMODEL_API_KEY -u MINIMAX_API_KEY \
    -u REPLICATE_API_TOKEN -u ARK_API_KEY -u AGNES_API_KEY -u AZURE_OPENAI_API_KEY \
    bun $D/main.ts --promptfiles /tmp/mp-probe.md --image /tmp/mp-x.png 2>&1 | grep -q "No API key found" && echo "c ok"

rm -f /tmp/mp-probe.md /tmp/mp-err.txt
```

期望三行 `a ok` / `b ok` / `c ok` 都出现。

- [ ] **Step 5: 写 VENDOR.md**

创建 `skills/_shared/scripts/imagegen/VENDOR.md`：

```markdown
# imagegen —— vendor 自 baoyu-image-gen

本目录是**拷贝**，不是原创代码。改这里之前先读完本文件。

## 来源

| 项 | 值 |
|---|---|
| 上游仓库 | `~/code/skills/writing/baoyu-skills` |
| 上游路径 | `skills/baoyu-image-gen/scripts/` |
| 上游 commit | `6b7a2e4` |
| 搬入日期 | 2026-08-10（二期 A） |
| 第三方依赖 | **零**。所有 import 都是 `node:*` 或相对路径 |
| 运行时 | bun（本机 1.3.14）。不需要 `package.json`，不需要 `tsconfig.json` |

## 排除了什么

| 排除项 | 理由 |
|---|---|
| `providers/codex-cli.ts` + `.test.ts` | 二期 A 首批不含 codex-cli 后端 |
| `codex-imagegen/`（7 个文件） | 上面那个 provider 的 wrapper 实现 |
| `build-batch.ts` + `.test.ts` | baoyu 专用的"大纲 → batch.json"转换器，依赖 `tsx`，本仓库不需要 |
| `references/`、`SKILL.md` | 上游文档 |

## 相对上游改了什么（只有两处）

1. **`main.ts` `loadProviderModule()`**：`codex-cli` 分支由 `await import("./providers/codex-cli")`
   改为 `throw new Error("codex-cli provider is not vendored in md2publish-skills. ...")`。
   理由：该 provider 未 vendor，静默 import 一个不存在的模块会给出难懂的模块解析错误。
2. **`main.ts` `MAX_ATTEMPTS`**：`3` → `2`。
   理由：设计文档 §9 规定"单张最多 2 次**计费**尝试"。一次超时的图片 API 调用可能已经计费，
   按次数重试三遍等于一张图扣三次钱。

**除这两处外逐字未改**，因此可以直接与上游 diff：

```bash
diff -r -x '*.test.ts' <上游>/skills/baoyu-image-gen/scripts <本目录>
```

## 怎么跟上游同步

1. 在上游确认要的改动，`diff` 出来。
2. 覆盖本目录对应文件。
3. **重新打上面两处修改**（`git diff` 会提醒你它们不见了）。
4. `bun test skills/_shared/scripts/imagegen`，期望 97 pass / 0 fail。
5. `scripts/sync-shared.sh` 把新版本推到各 skill 的 `shared/`。
6. 更新本文件的上游 commit 与日期。
```

- [ ] **Step 6: 提交**

```bash
git status --short          # 先看有没有别的 agent 的改动混进来
git add skills/_shared/scripts/imagegen
git commit -m "feat(shared): vendor baoyu-image-gen engine as imagegen

Vendored from baoyu-skills@6b7a2e4, 25 files, zero third-party deps.
Excludes codex-cli provider, its codex-imagegen wrapper, and build-batch.
Two intentional deviations recorded in VENDOR.md: codex-cli hard-fails,
MAX_ATTEMPTS lowered 3 -> 2 per design spec section 9 billing cap.

Verified: bun test -> 97 pass / 0 fail across 12 files."
```

---

### Task 2: `compress.py` —— 把图压到字节上限内

**Files:**
- Create: `skills/_shared/scripts/compress.py`
- Test: `skills/_shared/scripts/test-compress.sh`

**Interfaces:**
- Consumes: 无
- Produces: `python3 compress.py --image <path> --max-bytes <int> [--out <path>] [--allow-webp] [--json]`。成功时 stdout 是**最终产物路径**一行；`--json` 时是 `{"action": "none"|"compressed", "path": str, "bytes": int, "tool": str|None, "steps": [...]}`。压不下去或无可用工具时 stderr 报错、退出码 1。**原图永不被就地覆盖。**

- [ ] **Step 1: 写失败测试**

创建 `skills/_shared/scripts/test-compress.sh`（`chmod +x`）：

```bash
#!/usr/bin/env bash
# compress.py 行为测试。对应 spec §13 第 4 项："给定 max_bytes，压完必须真的小于它"。
set -uo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
ok()  { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad() { echo "  ❌ $1"; echo "     $2"; FAIL=$((FAIL+1)); }

# 造一张必然超限的大图。用 magick 合成而不是塞进仓库——二进制 fixture 不进 git。
if ! command -v magick >/dev/null; then
  echo "跳过：本机没有 magick，造不出测试用大图" >&2
  exit 0
fi
magick -size 3000x1688 plasma:fractal "$TMP/big.png" 2>/dev/null
BIG_BYTES=$(wc -c < "$TMP/big.png" | tr -d ' ')
printf 'x' > "$TMP/tiny.png"

echo "== 已在上限内 =="

out=$(python3 compress.py --image "$TMP/tiny.png" --max-bytes 1000 --json 2>&1)
if grep -q '"action": "none"' <<<"$out" && grep -q 'tiny.png' <<<"$out"; then
  ok "已达标时原样返回，不新建文件"
else
  bad "已达标时行为不对" "$out"
fi

echo
echo "== 超限时压到上限内（spec §13 第 4 项）=="

MAX=2097152    # 微信封面 2MB，与 wechat.yaml 的 archetypes.cover.max_bytes 同值
path=$(python3 compress.py --image "$TMP/big.png" --max-bytes "$MAX" 2>"$TMP/err.txt")
rc=$?
if [[ $rc -eq 0 && -f "$path" ]]; then
  ok "压缩成功且 stdout 的路径真实存在"
else
  bad "压缩失败" "rc=$rc path=$path $(cat "$TMP/err.txt")"
fi

got=$(wc -c < "$path" 2>/dev/null | tr -d ' ')
if [[ -n "${got:-}" && "$got" -le "$MAX" ]]; then
  ok "产物 $got 字节 ≤ 上限 $MAX"
else
  bad "产物仍然超限" "got=${got:-无} max=$MAX"
fi

now=$(wc -c < "$TMP/big.png" | tr -d ' ')
if [[ "$now" == "$BIG_BYTES" && "$path" != "$TMP/big.png" ]]; then
  ok "原图未被就地覆盖"
else
  bad "原图被改了（花钱生成的东西不能就地覆盖）" "before=$BIG_BYTES after=$now path=$path"
fi

echo
echo "== 压不下去时硬失败 =="

out=$(python3 compress.py --image "$TMP/big.png" --max-bytes 500 2>&1)
if [[ $? -ne 0 ]] && grep -q '500' <<<"$out"; then
  ok "不可能的目标硬失败并报出上限"
else
  bad "压不下去却没失败（会交付一个超限文件）" "$out"
fi

echo
echo "== JSON 输出 =="

out=$(python3 compress.py --image "$TMP/big.png" --max-bytes "$MAX" --json 2>&1)
if grep -q '"tool"' <<<"$out" && grep -q '"steps"' <<<"$out" && grep -q '"bytes"' <<<"$out"; then
  ok "--json 含 tool / steps / bytes 字段"
else
  bad "--json 字段不全" "$out"
fi

echo
echo "通过 $PASS 项，失败 $FAIL 项"
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd skills/_shared/scripts && chmod +x test-compress.sh && ./test-compress.sh
```

期望：FAIL，报 `can't open file ... compress.py: [Errno 2] No such file or directory`，失败项 6 项。

- [ ] **Step 3: 写 `compress.py`**

创建 `skills/_shared/scripts/compress.py`：

```python
#!/usr/bin/env python3
"""把图片压到给定字节上限以内。降级链：sips → ImageMagick →（需显式开启）cwebp。

纯机械压缩：不判断画质好不好、不改画幅比例（缩边是等比的）。
压不下去就硬失败——交付一个仍然超限的文件，等于把问题推到推草稿箱那一步才炸。
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

# (质量, 最长边上限)。最长边为 None 表示不缩放。
# 先降质量再缩边：封面在信息流里会被裁切，分辨率是最后才该牺牲的东西。
LADDER = [(85, None), (70, None), (55, None), (70, 2048), (70, 1600), (60, 1280)]


class CompressError(Exception):
    """压缩失败。所有失败路径统一抛这个，主函数负责转成退出码 1。"""


def _run(cmd: list[str]) -> bool:
    proc = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return proc.returncode == 0


def sips_step(src: Path, dst: Path, quality: int, max_dim: int | None) -> bool:
    cmd = ["sips", "-s", "format", "jpeg", "-s", "formatOptions", str(quality)]
    if max_dim:
        cmd += ["-Z", str(max_dim)]
    cmd += [str(src), "--out", str(dst)]
    return _run(cmd)


def magick_step(src: Path, dst: Path, quality: int, max_dim: int | None) -> bool:
    cmd = ["magick", str(src)]
    if max_dim:
        cmd += ["-resize", f"{max_dim}x{max_dim}>"]   # '>' = 只缩不放
    cmd += ["-quality", str(quality), str(dst)]
    return _run(cmd)


def cwebp_step(src: Path, dst: Path, quality: int, max_dim: int | None) -> bool:
    cmd = ["cwebp", "-q", str(quality)]
    if max_dim:
        cmd += ["-resize", str(max_dim), "0"]         # 0 = 按比例算高
    cmd += [str(src), "-o", str(dst)]
    return _run(cmd)


# 顺序即优先级。cwebp 排最后且默认不启用：它只产出 WebP，
# 而目标平台是否接受 WebP 属未核实的外部知识，不静默交付可能用不了的格式。
TOOLS = [
    ("sips", sips_step, ".jpg"),
    ("magick", magick_step, ".jpg"),
    ("cwebp", cwebp_step, ".webp"),
]


def available_tools(allow_webp: bool) -> list:
    out = []
    for name, fn, ext in TOOLS:
        if name == "cwebp" and not allow_webp:
            continue
        if shutil.which(name):
            out.append((name, fn, ext))
    return out


def _target_path(image: Path, out: Path | None, ext: str) -> Path:
    dst = out if out else image.with_suffix(ext)
    if dst == image:
        # 源本身就是 .jpg 时 with_suffix 会指回原文件。永不就地覆盖。
        dst = image.with_name(f"{image.stem}.compressed{ext}")
    return dst


def compress(image: Path, max_bytes: int, out: Path | None, allow_webp: bool) -> dict:
    if not image.exists():
        raise CompressError(f"图片不存在: {image}")
    size = image.stat().st_size
    if size <= max_bytes:
        return {"action": "none", "path": str(image), "bytes": size, "tool": None, "steps": []}

    tools = available_tools(allow_webp)
    if not tools:
        raise CompressError(
            "找不到可用的压缩工具（sips / magick）。macOS 自带 sips；"
            "否则 brew install imagemagick。cwebp 只在 --allow-webp 时启用。"
        )

    steps: list[dict] = []
    leftovers: set[Path] = set()
    for name, fn, ext in tools:
        dst = _target_path(image, out, ext)
        for quality, max_dim in LADDER:
            if not fn(image, dst, quality, max_dim):
                steps.append({"tool": name, "quality": quality, "max_dim": max_dim, "bytes": None})
                continue
            leftovers.add(dst)
            got = dst.stat().st_size
            steps.append({"tool": name, "quality": quality, "max_dim": max_dim, "bytes": got})
            if got <= max_bytes:
                return {"action": "compressed", "path": str(dst), "bytes": got,
                        "tool": name, "steps": steps}

    for path in leftovers:
        path.unlink(missing_ok=True)   # 失败不留残骸，否则下次 guard 会误判"已生成"
    sizes = [s["bytes"] for s in steps if s["bytes"]]
    best = min(sizes) if sizes else "无"
    raise CompressError(
        f"压不到 {max_bytes} 字节以内（原图 {size} 字节）。"
        f"已尝试 {len(steps)} 个阶梯，最小得到 {best} 字节。"
        "换一张构图更简单的图，或调高该 archetype 的 max_bytes。"
    )


def main() -> int:
    ap = argparse.ArgumentParser(description="把图片压到字节上限以内（机械压缩，不做画质判断）")
    ap.add_argument("--image", required=True)
    ap.add_argument("--max-bytes", required=True, type=int)
    ap.add_argument("--out", default=None, help="不给则在原图旁边写同名 .jpg")
    ap.add_argument("--allow-webp", action="store_true",
                    help="允许用 cwebp 产出 WebP。默认关闭：目标平台未必接受 WebP")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    try:
        result = compress(
            Path(args.image), args.max_bytes,
            Path(args.out) if args.out else None, args.allow_webp,
        )
    except CompressError as e:
        print(str(e), file=sys.stderr)
        return 1

    print(json.dumps(result, ensure_ascii=False, indent=2) if args.json else result["path"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

注意 `Path.unlink(missing_ok=True)` 需要 Python 3.8+，3.9 可用。

- [ ] **Step 4: 跑测试确认通过**

```bash
cd skills/_shared/scripts && ./test-compress.sh
```

期望：`通过 6 项，失败 0 项`。

- [ ] **Step 5: 提交**

```bash
git add skills/_shared/scripts/compress.py skills/_shared/scripts/test-compress.sh
git commit -m "feat(shared): add compress.py with sips -> magick fallback chain

Compresses an image under a byte cap using a quality-then-downscale ladder.
Never overwrites the source. Hard-fails instead of returning an oversized file.
cwebp is gated behind --allow-webp because WebP acceptance by target platforms
is unverified. Covers design spec section 13 item 4.

Verified: test-compress.sh -> 6 pass / 0 fail."
```

---

### Task 3: `config.py` + `preflight.py` —— 配置与三项自检

**Files:**
- Create: `skills/_shared/scripts/config.py`
- Create: `skills/_shared/scripts/preflight.py`
- Test: `skills/_shared/scripts/test-preflight.py`

**Interfaces:**
- Consumes: 无
- Produces:
  - `config.load_config(path: Path | None = None) -> dict`，键固定为 `provider` / `model` / `default_platform` / `max_concurrency` / `max_images_per_run`；文件不存在返回全默认；未知字段或非法类型抛 `config.ConfigError`。
  - `preflight.check_runtime(path: str | None = None) -> dict` → `{"found": bool, "bin": str|None, "version": str|None, "hint": str|None}`
  - `preflight.check_providers(env: dict | None = None) -> dict` → `{"configured": [str], "missing": {str: [str]}}`
  - `preflight.check_compressors(path: str | None = None) -> dict` → `{"found": {"sips": bool, "magick": bool, "cwebp": bool}, "any": bool, "hint": str|None}`
  - CLI：`python3 preflight.py [--json]`，**永远退出 0**（只报告不阻塞）。

**这个任务最容易做错的地方：** 本机 bun / sips / magick / cwebp 全都在，"跑一下看看"永远是绿的，失败分支根本测不到。因此三个 check 函数都必须把 `path` / `env` 做成可注入参数，测试用 `path=""` 和 `env={}` 走失败分支。已实测 `shutil.which(x, path="")` 返回 `None`。

- [ ] **Step 1: 写失败测试**

创建 `skills/_shared/scripts/test-preflight.py`：

```python
#!/usr/bin/env python3
"""preflight.py / config.py 的测试。

重点在**失败分支**：本机三样工具齐全，不注入空 PATH 就永远测不到缺失路径。
"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import config as cfg          # noqa: E402
import preflight as pf        # noqa: E402

PASS = 0
FAIL = 0


def ok(msg: str) -> None:
    global PASS
    print(f"  ✅ {msg}")
    PASS += 1


def bad(msg: str, detail: str) -> None:
    global FAIL
    print(f"  ❌ {msg}")
    print(f"     {detail}")
    FAIL += 1


def check(cond: bool, msg: str, detail: str = "") -> None:
    ok(msg) if cond else bad(msg, detail)


print("== TS 运行时 ==")
real = pf.check_runtime()
check(real["found"] and real["version"], "真实 PATH 下找到 bun 并拿到版本号", str(real))
empty = pf.check_runtime(path="")
check(not empty["found"] and empty["hint"], "空 PATH 下报缺失并给出安装提示", str(empty))

print("\n== 压缩工具 ==")
real_c = pf.check_compressors()
check(real_c["found"]["sips"] and real_c["any"], "真实 PATH 下 sips 可用", str(real_c))
empty_c = pf.check_compressors(path="")
check(
    not any(empty_c["found"].values()) and not empty_c["any"] and empty_c["hint"],
    "空 PATH 下三者皆缺、any=False 且给出提示",
    str(empty_c),
)

print("\n== provider 凭证 ==")
none_p = pf.check_providers(env={})
check(none_p["configured"] == [], "无任何环境变量时 configured 为空", str(none_p))
check(set(none_p["missing"]) == set(pf.PROVIDER_ENV), "缺失清单覆盖全部 provider", str(sorted(none_p["missing"])))

one_p = pf.check_providers(env={"OPENAI_API_KEY": "sk-x"})
check(one_p["configured"] == ["openai"], "只配 OPENAI_API_KEY 时只认 openai", str(one_p))

half_azure = pf.check_providers(env={"AZURE_OPENAI_API_KEY": "x"})
check("azure" not in half_azure["configured"], "azure 缺 BASE_URL 时不算已配置", str(half_azure))

alias = pf.check_providers(env={"GEMINI_API_KEY": "x"})
check("google" in alias["configured"], "GEMINI_API_KEY 是 GOOGLE_API_KEY 的别名", str(alias))

print("\n== 配置文件 ==")
with tempfile.TemporaryDirectory() as d:
    missing = Path(d) / "images.yaml"
    conf = cfg.load_config(missing)
    check(conf == cfg.DEFAULTS, "文件不存在时返回全默认", str(conf))

    good = Path(d) / "good.yaml"
    good.write_text("provider: openai\nmodel: gpt-image-2\nmax_images_per_run: 4\n", encoding="utf-8")
    conf = cfg.load_config(good)
    check(
        conf["provider"] == "openai" and conf["model"] == "gpt-image-2"
        and conf["max_images_per_run"] == 4 and conf["max_concurrency"] == 3,
        "已给字段生效、未给字段保持默认",
        str(conf),
    )

    unknown = Path(d) / "unknown.yaml"
    unknown.write_text("provder: openai\n", encoding="utf-8")
    try:
        cfg.load_config(unknown)
        bad("未知字段应硬失败", "没抛异常——拼错的字段会被静默忽略")
    except cfg.ConfigError as e:
        check("provder" in str(e), "未知字段硬失败并点名", str(e))

    negative = Path(d) / "negative.yaml"
    negative.write_text("max_concurrency: 0\n", encoding="utf-8")
    try:
        cfg.load_config(negative)
        bad("非正整数应硬失败", "没抛异常")
    except cfg.ConfigError as e:
        check("max_concurrency" in str(e), "非正整数硬失败并点名", str(e))

print("\n== 只报告不阻塞 ==")
rc = pf.report(runtime=pf.check_runtime(path=""), providers=pf.check_providers(env={}),
               compressors=pf.check_compressors(path=""), conf=dict(cfg.DEFAULTS), as_json=False)
check(rc == 0, "三项全缺时仍返回 0（拦截发生在后面的步骤）", f"rc={rc}")

print(f"\n通过 {PASS} 项，失败 {FAIL} 项")
sys.exit(0 if FAIL == 0 else 1)
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd skills/_shared/scripts && python3 test-preflight.py
```

期望：`ModuleNotFoundError: No module named 'config'`。

- [ ] **Step 3: 写 `config.py`**

创建 `skills/_shared/scripts/config.py`：

```python
#!/usr/bin/env python3
"""md2publish 自己的图片偏好配置：~/.config/md2publish/images.yaml。

**不复用 baoyu 的 EXTEND.md**（spec §7.3）：两套 skill 可能装在同一台机器上，
共用配置文件会互相覆盖。

本文件的值最终以显式命令行参数传给 imagegen 引擎。引擎的取值优先级是
CLI > EXTEND.md > 环境变量，所以这里的设置总是赢，不需要改引擎。

**API key 不进这个文件**，仍走环境变量——配置文件会被 vendor、会被 diff，
不是放凭证的地方。
"""

from __future__ import annotations

import os
from pathlib import Path

import yaml

DEFAULTS = {
    "provider": None,             # 不指定则由引擎按已配置的环境变量自动选
    "model": None,                # 不指定则用 provider 的默认模型
    "default_platform": None,     # 用户没说平台且文章 frontmatter 也没写时的兜底
    "max_concurrency": 3,         # 批量生成的并发上限，传给 imagegen 的 --jobs
    "max_images_per_run": 10,     # 单次运行的张数硬上限，超过直接拒绝（spec §9）
}
INT_FIELDS = ("max_concurrency", "max_images_per_run")


class ConfigError(Exception):
    """配置文件不合法。拼错字段会被硬失败挡住，不静默忽略。"""


def config_path() -> Path:
    base = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
    return Path(base) / "md2publish" / "images.yaml"


def load_config(path: Path | None = None) -> dict:
    path = path or config_path()
    conf = dict(DEFAULTS)
    if not path.exists():
        return conf

    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        raise ConfigError(f"{path} 不是 mapping")

    unknown = sorted(set(data) - set(DEFAULTS))
    if unknown:
        raise ConfigError(
            f"{path} 含未知字段 {unknown}；合法字段为 {sorted(DEFAULTS)}。"
            "拼错的字段被静默忽略比报错更难查，因此这里硬失败。"
        )
    for key in INT_FIELDS:
        if key in data:
            val = data[key]
            if not isinstance(val, int) or isinstance(val, bool) or val <= 0:
                raise ConfigError(f"{path} 的 {key} 必须是正整数，实为 {val!r}")

    conf.update(data)
    return conf
```

- [ ] **Step 4: 写 `preflight.py`**

创建 `skills/_shared/scripts/preflight.py`：

```python
#!/usr/bin/env python3
"""生成前的三项自检：TS 运行时 / provider 凭证 / 压缩工具链。

**只报告，不阻塞**（spec §11）：provider 缺失由生成那一步拦，压缩工具缺失由
压缩那一步拦，运行时缺失由调用引擎那一步拦。这样用户能一次看全所有缺口，
而不是修一个撞一个。因此本脚本永远退出 0。

三个 check 函数都接受注入的 path / env——开发机上工具通常齐全，
不注入就永远测不到缺失分支。
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import config as cfg  # noqa: E402

# provider → 需要的环境变量。每个元组内**任一**即可；多个元组表示**全都要**。
# 取值来自 imagegen/main.ts:detectProvider，改引擎时要同步改这里。
PROVIDER_ENV = {
    "agnes": [("AGNES_API_KEY",)],
    "azure": [("AZURE_OPENAI_API_KEY",), ("AZURE_OPENAI_BASE_URL",)],
    "dashscope": [("DASHSCOPE_API_KEY",)],
    "google": [("GOOGLE_API_KEY", "GEMINI_API_KEY")],
    "jimeng": [("JIMENG_ACCESS_KEY_ID",), ("JIMENG_SECRET_ACCESS_KEY",)],
    "minimax": [("MINIMAX_API_KEY",)],
    "openai": [("OPENAI_API_KEY",)],
    "openrouter": [("OPENROUTER_API_KEY",)],
    "replicate": [("REPLICATE_API_TOKEN",)],
    "seedream": [("ARK_API_KEY",)],
    "zai": [("ZAI_API_KEY", "BIGMODEL_API_KEY")],
}
COMPRESSORS = ("sips", "magick", "cwebp")


def check_runtime(path: str | None = None) -> dict:
    exe = shutil.which("bun", path=path)
    if not exe:
        return {"found": False, "bin": None, "version": None,
                "hint": "装 bun：brew install oven-sh/bun/bun；或用 npx -y bun 代替"}
    try:
        proc = subprocess.run([exe, "--version"], capture_output=True, text=True, timeout=30)
        version = proc.stdout.strip() or None
    except (OSError, subprocess.SubprocessError):
        version = None
    return {"found": True, "bin": exe, "version": version, "hint": None}


def check_providers(env: dict | None = None) -> dict:
    env = os.environ if env is None else env
    configured, missing = [], {}
    for name, groups in sorted(PROVIDER_ENV.items()):
        lacking = [g for g in groups if not any(env.get(k) for k in g)]
        if lacking:
            missing[name] = [" 或 ".join(g) for g in lacking]
        else:
            configured.append(name)
    return {"configured": configured, "missing": missing}


def check_compressors(path: str | None = None) -> dict:
    found = {t: bool(shutil.which(t, path=path)) for t in COMPRESSORS}
    # cwebp 不算数：它只产出 WebP，默认不参与降级链（见 compress.py）
    usable = found["sips"] or found["magick"]
    return {"found": found, "any": usable,
            "hint": None if usable else "装一个：macOS 自带 sips；或 brew install imagemagick"}


def report(runtime: dict, providers: dict, compressors: dict, conf: dict, as_json: bool) -> int:
    if as_json:
        print(json.dumps({"runtime": runtime, "providers": providers,
                          "compressors": compressors, "config": conf},
                         ensure_ascii=False, indent=2))
        return 0

    mark = lambda flag: "✅" if flag else "❌"  # noqa: E731

    print("== TS 运行时（imagegen 需要）==")
    print(f"  {mark(runtime['found'])} bun {runtime['version'] or ''} {runtime['bin'] or ''}".rstrip())
    if runtime["hint"]:
        print(f"     {runtime['hint']}")

    print("\n== provider 凭证 ==")
    if providers["configured"]:
        print(f"  ✅ 已配置：{', '.join(providers['configured'])}")
    else:
        print("  ❌ 一个都没配置。步骤 4 之前不影响——prompt 文件照样产出，"
              "拿去即梦 / Midjourney 自己生也行")
    for name, lacking in sorted(providers["missing"].items()):
        print(f"     - {name}：缺 {', '.join(lacking)}")

    print("\n== 压缩工具链 ==")
    for tool in COMPRESSORS:
        note = "（只产 WebP，需 --allow-webp）" if tool == "cwebp" else ""
        print(f"  {mark(compressors['found'][tool])} {tool}{note}")
    if compressors["hint"]:
        print(f"     {compressors['hint']}")

    print("\n== md2publish 配置 ==")
    print(f"  {cfg.config_path()}")
    for key in sorted(conf):
        print(f"     {key}: {conf[key]}")

    print("\n以上只是报告，不阻塞。缺凭证在生成那步拦，缺压缩工具在压缩那步拦。")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="生成前自检（只报告，不阻塞，永远退出 0）")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    try:
        conf = cfg.load_config()
    except cfg.ConfigError as e:
        # 配置坏了是唯一值得当场喊的事，但仍然不阻塞——用默认值继续报告
        print(f"配置文件有问题，已按默认值继续：{e}", file=sys.stderr)
        conf = dict(cfg.DEFAULTS)

    return report(check_runtime(), check_providers(), check_compressors(), conf, args.json)


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 5: 跑测试确认通过**

```bash
cd skills/_shared/scripts && python3 test-preflight.py && python3 preflight.py
```

期望：`通过 14 项，失败 0 项`，随后 `preflight.py` 打出人读报告且退出 0。

- [ ] **Step 6: 提交**

```bash
git add skills/_shared/scripts/config.py skills/_shared/scripts/preflight.py skills/_shared/scripts/test-preflight.py
git commit -m "feat(shared): add config.py and preflight.py

config.py reads ~/.config/md2publish/images.yaml -- md2publish's own prefs,
deliberately not baoyu's EXTEND.md, so both skills can coexist on one machine.
Unknown fields hard-fail so typos are not silently ignored.

preflight.py reports TS runtime / provider credentials / compressor chain and
always exits 0; each gate blocks at its own later step. All three checks take
injectable path/env so the missing-tool branches are testable on a machine
where everything happens to be installed.

Verified: test-preflight.py -> 14 pass / 0 fail."
```

---

### Task 4: `costs.yaml` + 成本查询

**Files:**
- Create: `skills/_shared/costs.yaml`
- Modify: `skills/_shared/scripts/asset_lib.py`（追加 `PROVIDERS`、`load_costs()`、`estimate_cost()`）
- Modify: `skills/_shared/scripts/test-asset-schema.sh`（13 项 → 17 项）

**Interfaces:**
- Consumes: `asset_lib.AssetError`、`asset_lib.shared_root()`
- Produces:
  - `asset_lib.PROVIDERS: list[str]` —— 11 个已 vendor 的 provider 名
  - `asset_lib.load_costs() -> dict` —— 解析并校验 `costs.yaml`
  - `asset_lib.estimate_cost(provider: str, model: str) -> float | None` —— 查不到价目返回 `None`（调用方据此说"该 provider 无价目表"），provider 不在 `PROVIDERS` 里则抛 `AssetError`

**不许自己编价格。** 真实单价属外部知识，本仓库不猜（`bilibili.yaml` 推迟的是同一个理由）。首版全部写 `unknown`，用户实测后自己填。

- [ ] **Step 1: 写失败测试**

在 `skills/_shared/scripts/test-asset-schema.sh` 末尾、`echo "通过 $PASS 项..."` 之前插入：

```bash
echo
echo "== costs.yaml（spec §9）=="

py() { python3 -c "import sys; sys.path.insert(0,'.'); $1"; }

out=$(py "
import asset_lib as a
c = a.load_costs()
assert c['version'] == 1, c['version']
assert c['currency'], 'currency 缺失'
assert isinstance(c['providers'], dict) and c['providers'], 'providers 为空'
print('ok')
" 2>&1)
if [[ "$out" == "ok" ]]; then ok "costs.yaml 结构合法"; else bad "costs.yaml 结构不合法" "$out"; fi

out=$(py "
import asset_lib as a
extra = sorted(set(a.load_costs()['providers']) - set(a.PROVIDERS))
print('ok' if not extra else 'unknown provider: %s' % extra)
" 2>&1)
if [[ "$out" == "ok" ]]; then ok "costs.yaml 里没有未 vendor 的 provider"; else bad "costs.yaml 有多余 provider" "$out"; fi

out=$(py "
import asset_lib as a
bad_vals = []
for p, models in a.load_costs()['providers'].items():
    for m, v in (models or {}).items():
        if v != 'unknown' and not (isinstance(v, (int, float)) and not isinstance(v, bool) and v > 0):
            bad_vals.append((p, m, v))
print('ok' if not bad_vals else 'bad values: %s' % bad_vals)
" 2>&1)
if [[ "$out" == "ok" ]]; then ok "每个价格是正数或字符串 unknown"; else bad "价格取值非法" "$out"; fi

out=$(py "
import asset_lib as a
assert a.estimate_cost('openai', 'gpt-image-2') is None, '未标价应返回 None'
try:
    a.estimate_cost('no-such-provider', 'x')
    print('未知 provider 没有硬失败')
except a.AssetError:
    print('ok')
" 2>&1)
if [[ "$out" == "ok" ]]; then ok "unknown 返回 None、未知 provider 硬失败"; else bad "estimate_cost 行为不对" "$out"; fi
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd skills/_shared/scripts && ./test-asset-schema.sh 2>&1 | tail -12
```

期望：新增 4 项全 ❌（`AttributeError: module 'asset_lib' has no attribute 'load_costs'`），末行 `通过 13 项，失败 4 项`。

- [ ] **Step 3: 写 `costs.yaml`**

创建 `skills/_shared/costs.yaml`：

```yaml
# provider × model 的单张估价，服务于生成前的成本门（spec §9）。
#
# 首版全部是 unknown，这是**有意的**：真实单价属外部知识，本仓库不猜。
# 成本门取不到价目时必须明说"该 provider 无价目表"，不许编一个数字出来。
#
# 自己填：把 unknown 换成一个正数（单位见 currency），跑一遍
# scripts/test-asset-schema.sh 确认没写坏。
version: 1
currency: CNY
providers:
  agnes:
    agnes-image: unknown
  azure:
    gpt-image-2: unknown
  dashscope:
    qwen-image-2.0-pro: unknown
  google:
    gemini-3-pro-image: unknown
  jimeng:
    jimeng_t2i_v40: unknown
  minimax:
    image-01: unknown
  openai:
    gpt-image-2: unknown
  openrouter:
    google/gemini-3.1-flash-image: unknown
  replicate:
    google/nano-banana-2: unknown
  seedream:
    doubao-seedream-5-0-260128: unknown
  zai:
    glm-image: unknown
```

- [ ] **Step 4: 给 `asset_lib.py` 追加成本查询**

在 `DIMENSION_KINDS = {...}` 那行之后追加常量：

```python
# 已 vendor 进 scripts/imagegen/ 的 provider。codex-cli 不在其中（二期 A 未搬）。
# 改 vendor 范围时这里和 preflight.PROVIDER_ENV 要同步改。
PROVIDERS = [
    "agnes", "azure", "dashscope", "google", "jimeng", "minimax",
    "openai", "openrouter", "replicate", "seedream", "zai",
]
COST_UNKNOWN = "unknown"
```

在文件末尾追加：

```python
def load_costs() -> dict:
    path = shared_root() / "costs.yaml"
    if not path.exists():
        raise AssetError(f"costs.yaml 不存在: {path}")
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise AssetError("costs.yaml 不是 mapping")
    for key in ("version", "currency", "providers"):
        if key not in data:
            raise AssetError(f"costs.yaml 缺字段 {key}")
    if not isinstance(data["providers"], dict) or not data["providers"]:
        raise AssetError("costs.yaml 的 providers 必须是非空 mapping")
    unknown = sorted(set(data["providers"]) - set(PROVIDERS))
    if unknown:
        raise AssetError(
            f"costs.yaml 含未 vendor 的 provider {unknown}；已 vendor 的是 {PROVIDERS}"
        )
    for provider, models in data["providers"].items():
        if not isinstance(models, dict) or not models:
            raise AssetError(f"costs.yaml 的 {provider} 必须是非空 mapping")
        for model, value in models.items():
            if value == COST_UNKNOWN:
                continue
            if isinstance(value, bool) or not isinstance(value, (int, float)) or value <= 0:
                raise AssetError(
                    f"costs.yaml 的 {provider}.{model} 必须是正数或字符串 "
                    f"'{COST_UNKNOWN}'，实为 {value!r}"
                )
    return data


def estimate_cost(provider: str, model: str) -> float | None:
    """返回单张估价；无价目返回 None。调用方据此说明'该 provider 无价目表'，别编数字。"""
    if provider not in PROVIDERS:
        raise AssetError(f"未知 provider: {provider}；已 vendor 的是 {PROVIDERS}")
    value = (load_costs()["providers"].get(provider) or {}).get(model, COST_UNKNOWN)
    return None if value == COST_UNKNOWN else float(value)
```

- [ ] **Step 5: 跑测试确认通过**

```bash
cd skills/_shared/scripts && ./test-asset-schema.sh 2>&1 | tail -8
```

期望：`通过 17 项，失败 0 项`。

同时确认没碰坏另外两个：

```bash
./test-compose-prompt.sh 2>&1 | tail -1     # 通过 11 项，失败 0 项
./test-platform-matrix.sh 2>&1 | tail -1    # 通过 8 项，失败 0 项
```

- [ ] **Step 6: 提交**

```bash
git add skills/_shared/costs.yaml skills/_shared/scripts/asset_lib.py skills/_shared/scripts/test-asset-schema.sh
git commit -m "feat(shared): add costs.yaml and cost lookup

Ships every price as 'unknown' on purpose -- real per-image pricing is external
knowledge this repo does not guess. estimate_cost returns None for unpriced
entries so the cost gate says 'no price table for this provider' instead of
inventing a number, and hard-fails on providers that were never vendored.

Verified: test-asset-schema.sh -> 17 pass / 0 fail (was 13)."
```

---

### Task 5: `artifacts.py` —— 重跑保护与 sidecar

**Files:**
- Create: `skills/_shared/scripts/artifacts.py`
- Test: `skills/_shared/scripts/test-artifacts.sh`

**Interfaces:**
- Consumes: `asset_lib.AssetError`、`asset_lib.load_preset()`
- Produces:
  - `python3 artifacts.py guard --path <file> [--force]` —— 文件存在且无 `--force` 时 stderr 报告并退出 1；否则退出 0
  - `python3 artifacts.py sidecar --image <png> --platform <p> --archetype <a> --preset <name> --provider <p> --model <m> --prompt-file <f> --brief-file <f> --alt-text <text> [--override k=v ...]` —— 写 `<image 同名>.json`，stdout 打印 sidecar 路径
  - sidecar 字段：`platform` `archetype` `preset` `preset_version` `overrides` `provider` `model` `prompt_file` `brief_file` `alt_text` `bytes` `generated_at`

**为什么是脚本不是让 agent 判断：** 被覆盖的是花钱生成的东西。"永不静默覆盖"不能依赖模型记性（`CLAUDE.md` Rule 5：能用代码回答的就用代码）。`preset_version` 同理——它必须从 preset YAML 里读，让 agent 手填迟早填错版本号，而 sidecar 存在的意义就是事后查得出"这张图是哪个版本的 preset 产的"。

- [ ] **Step 1: 写失败测试**

创建 `skills/_shared/scripts/test-artifacts.sh`（`chmod +x`）：

```bash
#!/usr/bin/env bash
# artifacts.py 测试。对应 spec §7.3（重跑跳过）与 §5.3（产物 sidecar）。
set -uo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
ok()  { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad() { echo "  ❌ $1"; echo "     $2"; FAIL=$((FAIL+1)); }

echo "== guard：重跑保护 =="

python3 artifacts.py guard --path "$TMP/absent.png" >/dev/null 2>&1
[[ $? -eq 0 ]] && ok "目标不存在时放行" || bad "不存在却被拦" ""

printf 'fake-image-bytes' > "$TMP/exists.png"
out=$(python3 artifacts.py guard --path "$TMP/exists.png" 2>&1)
rc=$?
if [[ $rc -ne 0 ]] && grep -q 'exists.png' <<<"$out"; then
  ok "目标已存在时拦住并报出路径"
else
  bad "已存在却放行（会静默覆盖花钱产出的图）" "rc=$rc out=$out"
fi

python3 artifacts.py guard --path "$TMP/exists.png" --force >/dev/null 2>&1
[[ $? -eq 0 ]] && ok "--force 时放行" || bad "--force 未生效" ""

echo
echo "== sidecar：产物元数据 =="

run_sidecar() {
  python3 artifacts.py sidecar \
    --image "$TMP/exists.png" \
    --platform wechat --archetype cover --preset "$1" \
    --provider openai --model gpt-image-2 \
    --prompt-file prompts/wechat/00-cover.md \
    --brief-file briefs/wechat/00-cover.md \
    --alt-text "暖色调编辑风封面" \
    --override palette=cool-slate 2>&1
}

out=$(run_sidecar editorial-warm)
rc=$?
SIDECAR="$TMP/exists.json"
if [[ $rc -eq 0 && -f "$SIDECAR" ]]; then ok "写出同名 .json"; else bad "sidecar 未生成" "rc=$rc out=$out"; fi

jq_get() { python3 -c "import json,sys; print(json.load(open('$SIDECAR'))$1)"; }

# preset_version 必须来自 preset YAML，不是命令行传入的
expected_version=$(python3 -c "import sys; sys.path.insert(0,'.'); import asset_lib as a; print(a.load_preset('editorial-warm')['version'])")
got_version=$(jq_get "['preset_version']" 2>&1)
if [[ "$got_version" == "$expected_version" ]]; then
  ok "preset_version 取自 preset YAML（$got_version）"
else
  bad "preset_version 不对" "expected=$expected_version got=$got_version"
fi

real_bytes=$(wc -c < "$TMP/exists.png" | tr -d ' ')
got_bytes=$(jq_get "['bytes']" 2>&1)
if [[ "$got_bytes" == "$real_bytes" ]]; then ok "bytes 等于图片真实字节数"; else bad "bytes 不对" "expected=$real_bytes got=$got_bytes"; fi

got_override=$(jq_get "['overrides']['palette']" 2>&1)
if [[ "$got_override" == "cool-slate" ]]; then ok "--override 解析成对象"; else bad "overrides 不对" "$got_override"; fi

got_alt=$(jq_get "['alt_text']" 2>&1)
if [[ "$got_alt" == "暖色调编辑风封面" ]]; then ok "alt_text 原样保留（Markdown 回写要用）"; else bad "alt_text 不对" "$got_alt"; fi

got_at=$(jq_get "['generated_at']" 2>&1)
if grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{2}:[0-9]{2}$' <<<"$got_at"; then
  ok "generated_at 是带时区的 ISO 8601"
else
  bad "generated_at 格式不对" "$got_at"
fi

out=$(run_sidecar no-such-preset)
if [[ $? -ne 0 ]] && grep -q 'no-such-preset' <<<"$out"; then
  ok "preset 不存在时硬失败并点名"
else
  bad "不存在的 preset 未拦住" "$out"
fi

echo
echo "通过 $PASS 项，失败 $FAIL 项"
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd skills/_shared/scripts && chmod +x test-artifacts.sh && ./test-artifacts.sh
```

期望：FAIL，`No such file or directory: 'artifacts.py'`，失败 10 项。

- [ ] **Step 3: 写 `artifacts.py`**

创建 `skills/_shared/scripts/artifacts.py`：

```python
#!/usr/bin/env python3
"""产物落盘规则：重跑保护（spec §7.3）与 sidecar 元数据（spec §5.3）。

两件事都是确定性动作，因此写成脚本而不是交给 agent 判断——被覆盖的是花钱
生成的东西，"永不静默覆盖"这条不该依赖模型记性；sidecar 的 preset_version
也必须从 YAML 读，手填迟早填错，而它存在的意义正是事后查得出版本。
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import asset_lib as a  # noqa: E402


def guard(path: Path, force: bool) -> None:
    if path.exists() and not force:
        raise a.AssetError(
            f"目标已存在，跳过：{path}\n"
            "它是花钱生成的产物，不会被静默覆盖。确实要重生成就加 --force。"
        )


def parse_overrides(pairs: list[str]) -> dict:
    out = {}
    for pair in pairs:
        if "=" not in pair:
            raise a.AssetError(f"--override 要写成 key=value，实为 {pair!r}")
        key, value = pair.split("=", 1)
        out[key.strip()] = value.strip()
    return out


def sidecar(image: Path, meta: dict) -> Path:
    if not image.exists():
        raise a.AssetError(f"图片不存在，无法写 sidecar: {image}")
    preset = a.load_preset(meta["preset"])     # preset 不存在时在这里硬失败
    record = {
        "platform": meta["platform"],
        "archetype": meta["archetype"],
        "preset": meta["preset"],
        "preset_version": preset["version"],
        "overrides": meta["overrides"],
        "provider": meta["provider"],
        "model": meta["model"],
        "prompt_file": meta["prompt_file"],
        "brief_file": meta["brief_file"],
        "alt_text": meta["alt_text"],
        "bytes": image.stat().st_size,
        "generated_at": datetime.now().astimezone().isoformat(timespec="seconds"),
    }
    out = image.with_suffix(".json")
    out.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="产物落盘规则：重跑保护与 sidecar 元数据")
    sub = ap.add_subparsers(dest="cmd", required=True)

    g = sub.add_parser("guard", help="目标已存在则拦住，除非 --force")
    g.add_argument("--path", required=True)
    g.add_argument("--force", action="store_true")

    s = sub.add_parser("sidecar", help="写 <image 同名>.json，记录生成它的全部输入")
    s.add_argument("--image", required=True)
    for field in ("platform", "archetype", "preset", "provider", "model",
                  "prompt-file", "brief-file", "alt-text"):
        s.add_argument(f"--{field}", required=True)
    s.add_argument("--override", action="append", default=[], metavar="KEY=VALUE")

    args = ap.parse_args()
    try:
        if args.cmd == "guard":
            guard(Path(args.path), args.force)
            return 0
        out = sidecar(Path(args.image), {
            "platform": args.platform,
            "archetype": args.archetype,
            "preset": args.preset,
            "provider": args.provider,
            "model": args.model,
            "prompt_file": args.prompt_file,
            "brief_file": args.brief_file,
            "alt_text": args.alt_text,
            "overrides": parse_overrides(args.override),
        })
    except a.AssetError as e:
        print(str(e), file=sys.stderr)
        return 1
    print(str(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: 跑测试确认通过**

```bash
cd skills/_shared/scripts && ./test-artifacts.sh
```

期望：`通过 10 项，失败 0 项`。

- [ ] **Step 5: 提交**

```bash
git add skills/_shared/scripts/artifacts.py skills/_shared/scripts/test-artifacts.sh
git commit -m "feat(shared): add artifacts.py for rerun guard and sidecar

guard refuses to overwrite an existing artifact without --force; sidecar writes
the full input record next to each image, reading preset_version from the YAML
rather than trusting a hand-passed value. Both are deterministic, so they are
code rather than agent judgement -- the files at stake cost money to produce.

Verified: test-artifacts.sh -> 10 pass / 0 fail."
```

---

### Task 6: vendor 脚本 —— 清单、同步、漂移检查

**Files:**
- Create: `scripts/shared-manifest.sh`
- Create: `scripts/sync-shared.sh`
- Create: `scripts/check-shared-drift.sh`
- Test: `scripts/test-sync-drift.sh`

**Interfaces:**
- Consumes: `skills/_shared/` 下 T1–T5 产出的全部文件
- Produces:
  - `scripts/shared-manifest.sh` 定义 `SHARED_SKILLS=("md2publish-cover")` 与 `shared_items_for <skill>`（回显空格分隔的条目），**清单的唯一定义处**
  - `scripts/sync-shared.sh` 生成 `skills/md2publish-cover/shared/`
  - `scripts/check-shared-drift.sh` 漂移则退出 1

**这里唯一的真实失败模式是"改错了地方"**（改了 `skills/*/shared/` 而不是 `_shared/`）。因此漂移脚本的输出必须直接打印"把改动挪回 `_shared/` 再 re-sync"这句话和 diff，不能只 exit 1。

**关于 `rm -rf`：** `sync-shared.sh` 会删除并重建 `skills/<skill>/shared/`。这是全局 `CLAUDE.md` 数据安全规则的一个**受控例外**：只删本脚本自己生成的目录，且靠 `.synced-from-shared` 标记文件确认——目录存在但没有标记时**硬失败并让人自己看**，绝不猜。

- [ ] **Step 1: 写清单文件**

创建 `scripts/shared-manifest.sh`：

```bash
#!/usr/bin/env bash
# _shared/ 的 vendor 子集清单。**唯一定义处**——sync 与 drift 两个脚本都 source 它。
# 清单写两份必然漂移，spec §4.3 的表格只是文档，这里才是真相。

SHARED_SKILLS=("md2publish-cover")
SYNC_MARKER=".synced-from-shared"

# 相对 skills/_shared/ 的路径，空格分隔。
# 注意 scripts/asset_lib.py：spec §4.3 的表格漏了它，但它是 compose_prompt.py
# 与 artifacts.py 的硬 import 依赖，不带上 vendor 出来的 skill 直接不能跑。
shared_items_for() {
  case "$1" in
    md2publish-cover)
      echo "platforms presets costs.yaml \
scripts/asset_lib.py scripts/compose_prompt.py scripts/compress.py \
scripts/config.py scripts/preflight.py scripts/artifacts.py scripts/imagegen"
      ;;
    *)
      echo "未知 skill: $1" >&2
      return 1
      ;;
  esac
}
```

- [ ] **Step 2: 写失败测试**

创建 `scripts/test-sync-drift.sh`（`chmod +x`）：

```bash
#!/usr/bin/env bash
# sync-shared.sh / check-shared-drift.sh 的行为测试。对应 spec §13 第 5 项。
set -uo pipefail
cd "$(dirname "$0")/.."

PASS=0
FAIL=0
ok()  { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad() { echo "  ❌ $1"; echo "     $2"; FAIL=$((FAIL+1)); }

DEST=skills/md2publish-cover/shared

echo "== sync =="

./scripts/sync-shared.sh >/dev/null 2>&1
[[ $? -eq 0 ]] && ok "sync 成功" || bad "sync 失败" "$(./scripts/sync-shared.sh 2>&1 | tail -3)"

missing=""
for f in platforms/wechat.yaml presets/INDEX.md costs.yaml \
         scripts/asset_lib.py scripts/compose_prompt.py scripts/compress.py \
         scripts/config.py scripts/preflight.py scripts/artifacts.py \
         scripts/imagegen/main.ts scripts/imagegen/providers/openai.ts; do
  [[ -e "$DEST/$f" ]] || missing="$missing $f"
done
[[ -z "$missing" ]] && ok "清单里的关键文件都到位" || bad "vendor 缺文件" "$missing"

[[ -e "$DEST/$(bash -c 'source scripts/shared-manifest.sh; echo $SYNC_MARKER')" ]] \
  && ok "写了 .synced-from-shared 标记" || bad "缺标记文件" ""

[[ ! -e "$DEST/scripts/test-compose-prompt.sh" ]] \
  && ok "测试脚本不进 vendor（测试留在 _shared）" || bad "把测试也拷过去了" ""

echo
echo "== vendor 出来的副本能独立跑 =="

ROOT=$(pwd)
out=$(cd "$DEST/scripts" && python3 compose_prompt.py --platform wechat --preset editorial-warm \
        --brief-file "$ROOT/skills/_shared/scripts/fixtures/brief-sample.md" \
        --out /tmp/mp-vendor-check.md 2>&1)
if [[ $? -eq 0 && -s /tmp/mp-vendor-check.md ]]; then
  ok "vendor 副本里的 compose_prompt.py 能跑（asset_lib 依赖没漏）"
else
  bad "vendor 副本跑不起来" "$out"
fi
rm -f /tmp/mp-vendor-check.md

echo
echo "== drift =="

./scripts/check-shared-drift.sh >/dev/null 2>&1
[[ $? -eq 0 ]] && ok "刚同步完无漂移" || bad "刚同步完就报漂移" "$(./scripts/check-shared-drift.sh 2>&1 | tail -5)"

echo "# drift probe" >> "$DEST/scripts/compress.py"
out=$(./scripts/check-shared-drift.sh 2>&1)
rc=$?
if [[ $rc -ne 0 ]] && grep -q '挪回' <<<"$out" && grep -q 'compress.py' <<<"$out"; then
  ok "改了 vendor 副本时报漂移，并给出'挪回 _shared'的指示"
else
  bad "漂移未被发现或提示不对" "rc=$rc out=$(tail -5 <<<"$out")"
fi

./scripts/sync-shared.sh >/dev/null 2>&1     # 恢复
./scripts/check-shared-drift.sh >/dev/null 2>&1
[[ $? -eq 0 ]] && ok "re-sync 后恢复干净" || bad "re-sync 未恢复" ""

echo
echo "通过 $PASS 项，失败 $FAIL 项"
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 3: 跑测试确认失败**

```bash
chmod +x scripts/test-sync-drift.sh && ./scripts/test-sync-drift.sh
```

期望：`sync-shared.sh: No such file or directory`，失败 8 项。

- [ ] **Step 4: 写 `sync-shared.sh`**

创建 `scripts/sync-shared.sh`（`chmod +x`）：

```bash
#!/usr/bin/env bash
# skills/_shared/ → skills/<skill>/shared/。按清单只拷子集，不是全量三份。
#
# 本脚本会删除并重建目标目录。这是受控的：只删自己生成的目录，
# 靠 .synced-from-shared 标记确认；目录存在但没有标记时硬失败，绝不猜。
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/shared-manifest.sh

SHARED=skills/_shared

sync_one() {
  local skill="$1"
  local dest="skills/$skill/shared"
  local items
  items=$(shared_items_for "$skill")

  if [[ -e "$dest" && ! -e "$dest/$SYNC_MARKER" ]]; then
    echo "拒绝写 $dest：它存在但没有 $SYNC_MARKER 标记。" >&2
    echo "本脚本只重建自己生成的目录。确认里面没有手写内容后，自行删掉它再跑。" >&2
    return 1
  fi

  rm -rf "$dest"
  mkdir -p "$dest"
  for item in $items; do
    mkdir -p "$dest/$(dirname "$item")"
    \cp -Rf "$SHARED/$item" "$dest/$item"
  done

  find "$dest" -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true
  find "$dest" -name '.ccmem' -type d -prune -exec rm -rf {} + 2>/dev/null || true
  find "$dest" -name '.DS_Store' -delete 2>/dev/null || true

  cat > "$dest/$SYNC_MARKER" <<'EOF'
本目录由 scripts/sync-shared.sh 从 skills/_shared/ 生成，不要手改。
要改内容请改 skills/_shared/ 下的对应文件，然后重新跑 scripts/sync-shared.sh。
EOF

  echo "已同步 $skill（$(find "$dest" -type f | wc -l | tr -d ' ') 个文件）"
}

for skill in "${SHARED_SKILLS[@]}"; do
  sync_one "$skill"
done
```

- [ ] **Step 5: 写 `check-shared-drift.sh`**

创建 `scripts/check-shared-drift.sh`（`chmod +x`）：

```bash
#!/usr/bin/env bash
# 比对各 skill 的 shared/ 与 _shared/ 是否一致。
#
# 漂移的正确处理**永远是**"你的改动改错地方了，把它挪回 _shared/ 再 re-sync"，
# 绝不是"re-sync 覆盖掉"——后者会静默丢掉别人写在 vendor 副本里的改动。
# 因此这里必须打印那句话和 diff，不能只 exit 1。
set -uo pipefail
cd "$(dirname "$0")/.."
source scripts/shared-manifest.sh

SHARED=skills/_shared
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

DRIFTED=0

for skill in "${SHARED_SKILLS[@]}"; do
  dest="skills/$skill/shared"
  expected="$TMP/$skill"

  if [[ ! -d "$dest" ]]; then
    echo "❌ $skill：$dest 不存在。跑 scripts/sync-shared.sh。"
    DRIFTED=1
    continue
  fi

  mkdir -p "$expected"
  for item in $(shared_items_for "$skill"); do
    mkdir -p "$expected/$(dirname "$item")"
    \cp -Rf "$SHARED/$item" "$expected/$item"
  done
  find "$expected" -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true
  find "$expected" -name '.ccmem' -type d -prune -exec rm -rf {} + 2>/dev/null || true
  find "$expected" -name '.DS_Store' -delete 2>/dev/null || true

  if diff -r -x "$SYNC_MARKER" -x '__pycache__' "$expected" "$dest" > "$TMP/$skill.diff" 2>&1; then
    echo "✅ $skill：与 _shared/ 一致"
  else
    DRIFTED=1
    echo "❌ $skill：与 _shared/ 不一致"
    echo
    echo "   怎么处理：**把你的改动挪回 skills/_shared/ 里的对应文件，再跑"
    echo "   scripts/sync-shared.sh**。不要反过来用 re-sync 覆盖掉 —— 那会静默"
    echo "   丢掉写在 vendor 副本里的改动。_shared/ 是唯一真相源。"
    echo
    sed 's/^/   /' "$TMP/$skill.diff"
    echo
  fi
done

exit $DRIFTED
```

- [ ] **Step 6: 跑测试确认通过**

```bash
chmod +x scripts/sync-shared.sh scripts/check-shared-drift.sh
./scripts/test-sync-drift.sh
```

期望：`通过 8 项，失败 0 项`。

- [ ] **Step 7: 提交**

```bash
git add scripts/shared-manifest.sh scripts/sync-shared.sh scripts/check-shared-drift.sh scripts/test-sync-drift.sh skills/md2publish-cover/shared
git commit -m "feat(scripts): add shared-manifest, sync-shared and drift check

The vendor subset is declared once in shared-manifest.sh and sourced by both
sync and drift scripts -- two copies of a manifest always diverge. Drift output
spells out the only correct fix (move the edit back into _shared/ and re-sync)
plus the diff, because re-syncing over a drifted copy silently discards work.
sync only removes directories it created, verified by a marker file.

Adds scripts/asset_lib.py to the subset; the spec section 4.3 table omits it but
compose_prompt.py imports it, so the vendored copy would not run without it.

Verified: test-sync-drift.sh -> 8 pass / 0 fail."
```

---

### Task 7: `md2publish-cover` skill

**Files:**
- Create: `skills/md2publish-cover/SKILL.md`
- Test: 人工按 SKILL.md 走一遍步骤 1–4（零成本），产出真实 prompt 文件

**Interfaces:**
- Consumes: T1–T6 的全部产物，经 `skills/md2publish-cover/shared/` 访问
- Produces: 一个可被 skill 加载器发现的 skill；产物布局 `briefs/<platform>/00-cover.md`、`prompts/<platform>/00-cover.md`、`assets/<platform>/00-cover.{png,jpg}` + `00-cover.json`

- [ ] **Step 1: 写 SKILL.md**

创建 `skills/md2publish-cover/SKILL.md`：

```markdown
---
name: md2publish-cover
description: 为文章生成封面图，支持微信公众号与小红书两种画幅。当用户说"生成封面"、"封面图"、"文章头图"、"小红书首图"，或在发布工作流里需要封面素材时使用。步骤 1–4 零成本零副作用（产出 prompt 文件），步骤 5 起才调 provider、才花钱。
allowed-tools: Read, Write, Bash, AskUserQuestion
---

# md2publish-cover：封面图

一篇文章一张封面。**同一个视觉概念可以一次出两个平台的画幅**（`--platform wechat,xiaohongshu`），
但那是两次渲染、两次生成、两次成本确认。

本 skill 的资产（平台 profile、preset、维度词表、脚本、生图引擎）全在 `shared/` 下，
是从 `skills/_shared/` vendor 来的副本。**不要改 `shared/` 里的任何文件**——
改了会被 `scripts/check-shared-drift.sh` 拦住，正确做法是改 `skills/_shared/`
再跑 `scripts/sync-shared.sh`。

## 职责边界

| 这件事 | 归谁 |
|---|---|
| 正文里的插图（3–8 张）、小红书图卡系列 | `md2publish-visuals`（三期，尚未实现） |
| 架构图 / 流程图 / 示意图 | `md2publish-diagram`（三期，尚未实现） |
| 把图传进微信素材库、建草稿 | `md2publish-draft` |
| 封面 | 本 skill |

三期之前，用户要插图或示意图时**如实说这两个 skill 还没建**，
不要用封面流程凑合，也不要去改 `md2publish-images`（那是旧路径，二期 B 才处理）。

## 机械层与语义层

你负责**语义**：这张封面要表达什么、主体是什么、alt 文本怎么写、选哪个 preset。
脚本负责**机械**：填画幅、填文字策略、拼模板、压字节、写元数据。

`compose_prompt.py` 不读文章原文、不调模型。文章的语义部分由你写成 **brief 文件**传进去。

## 执行流程

### 步骤 1：preflight（零成本）

```bash
python3 shared/scripts/preflight.py
```

它报告三件事：TS 运行时、provider 凭证、压缩工具链。**只报告不阻塞**——
缺 provider 也照样往下走，步骤 5 才拦。把缺口一次性讲给用户，别修一个撞一个。

### 步骤 2：确定平台

按这个顺序取，取到就停：

1. 用户明说（"发小红书"）
2. 文章 frontmatter 的 `platform:`
3. `~/.config/md2publish/images.yaml` 的 `default_platform`
4. 都没有 → 问用户

当前支持 `wechat` 与 `xiaohongshu`。要两个都出就写 `wechat,xiaohongshu`，
但**每个平台各走一遍步骤 3–8，成本各确认各的**，不许一次确认覆盖两个平台的花费。

### 步骤 3：选 preset（零成本）

读 `shared/presets/INDEX.md`，按文章调性挑一个 `archetype: cover` 的 preset。
**不要背 preset 名单**——资产会持续增补，每次都回去读那份索引。

用户提风格偏好（"换暖色"、"别那么花"）时**不换整个 preset**，
从 INDEX.md 的维度表里找最接近的值，用 `--palette` / `--rendering` 覆盖那一维。

### 步骤 4：写 brief 并渲染 prompt（零成本，到此为止零副作用）

**4a 语义层**：你写 `briefs/<platform>/00-cover.md`。四行，中文，不要写画幅和配色
（那些由平台和 preset 决定，写进来只会打架）：

```
主题：<这张图要表达文章的什么>
主体：<画面里具体有什么>
情绪：<什么调性>
alt：<给读者的替代文本，一句话>
```

**4b 机械层**：

```bash
python3 shared/scripts/compose_prompt.py \
  --platform <platform> --preset <preset> \
  --brief-file briefs/<platform>/00-cover.md \
  --out prompts/<platform>/00-cover.md \
  [--palette <value>] [--rendering <value>]
```

平台不支持该组合时它直接失败并说明原因，不静默回退。

**到这里为止零成本、零副作用。** 没配 provider 的用户就在这里收工——
把 `prompts/<platform>/00-cover.md` 交给他，拿去即梦 / Midjourney / DALL·E 自己生，
生成后把文件放到 `assets/<platform>/00-cover.png` 再跳到步骤 7。

### ═══ 以下开始计费 ═══

### 步骤 5：凭证门 + 成本门

**凭证门**：步骤 1 报告 provider 一个都没配置 → **报告 prompt 文件路径并停止**。
不要引导用户为此现配 API key，把选择权交给他。

**成本门**：封面是单张，**不问**——用户主动要封面就是要了（spec §9）。
但要把用什么 provider / 什么 model 说出来。价目查询：

```bash
python3 -c "import sys; sys.path.insert(0,'shared/scripts'); import asset_lib as a; print(a.estimate_cost('<provider>', '<model>'))"
```

返回 `None` 就明说"该 provider 无价目表"，**不要编一个数字**。

### 步骤 6：生成

先过重跑保护：

```bash
python3 shared/scripts/artifacts.py guard --path assets/<platform>/00-cover.png
```

它非零退出就是文件已存在——**报告并停下问用户**，别自己加 `--force`。
`briefs/` 和 `prompts/` 是复现记录，不是临时文件，一并保留。

取画幅（别硬编 16:9，小红书是 3:4）：

```bash
ASPECT=$(python3 -c "import sys; sys.path.insert(0,'shared/scripts'); import asset_lib as a; p=a.load_platform('<platform>'); print(a.archetype_slot(p,'cover')['aspect'])")
```

生成：

```bash
bun shared/scripts/imagegen/main.ts \
  --promptfiles prompts/<platform>/00-cover.md \
  --image assets/<platform>/00-cover.png \
  --ar "$ASPECT" \
  [--provider <p>] [--model <m>]
```

成功时 stdout 是产物绝对路径，日志走 stderr。

**单张最多 2 次计费尝试**（引擎里已经压到 2）。生成了但不满意属于"质量类"失败：
改 `prompts/<platform>/00-cover.md` 重跑那一张，**同样计入计费尝试**——
不要连着重试三四遍，先问用户还要不要继续花钱。

失败分类处理：

| 类别 | 典型 | 怎么做 |
|---|---|---|
| 配置类 | 认证失败、模型名不存在 | 回步骤 5 改配置，重试免费 |
| 配额类 | 余额不足、限流 | 报告并停，**不自动重试** |
| 审核类 | 内容策略拒绝 | 指出 prompt 里可能的触发词，给**具体**改写建议，不要笼统说"换个说法" |
| 网络类 | 超时、连接中断 | 引擎已内建退避，超出 2 次就停 |

### 步骤 7：压缩

微信封面 2MB 是硬限制。**必须在这里压完**，等到推草稿箱才发现超限，前面全白做。

```bash
MAXB=$(python3 -c "import sys; sys.path.insert(0,'shared/scripts'); import asset_lib as a; p=a.load_platform('<platform>'); print(a.archetype_slot(p,'cover')['max_bytes'])")
python3 shared/scripts/compress.py --image assets/<platform>/00-cover.png --max-bytes "$MAXB"
```

stdout 是最终产物路径——**可能不是你传进去的那个**（需要压缩时会产出同名 `.jpg`）。
后面的步骤一律用它打印的路径。压不下去时它硬失败，别自己降低上限绕过去。

### 步骤 8：写 sidecar 并交接

```bash
python3 shared/scripts/artifacts.py sidecar \
  --image <步骤 7 打印的路径> \
  --platform <platform> --archetype cover --preset <preset> \
  --provider <provider> --model <model> \
  --prompt-file prompts/<platform>/00-cover.md \
  --brief-file briefs/<platform>/00-cover.md \
  --alt-text "<brief 里那句 alt>" \
  [--override palette=<value>]
```

交接话术：

- 告诉用户最终文件路径，以及**它是否被压缩过、压成了什么格式**。
- 微信：提醒头条按 2.35:1 裁、次条按 1:1 裁，重要视觉元素要在画面中央。
  推草稿箱时 `md2publish-draft` 会拿它当 `--cover`。
- 小红书：本仓库**还没有**小红书的发布 skill，产物需要用户自己上传。如实说，别暗示能自动发。
- 封面**不进正文**，不要往 Markdown 里插 `![]()`。

## 产物布局

```
<article-dir>/
├─ briefs/<platform>/00-cover.md      ← 你写的语义 brief
├─ prompts/<platform>/00-cover.md     ← 渲染后的 prompt（复现记录，别删）
└─ assets/<platform>/00-cover.png     ← 产物（压缩过则是 .jpg）
   assets/<platform>/00-cover.json    ← sidecar
```

按平台分目录，所以 `wechat,xiaohongshu` 两张封面不会同名相撞。

## 前置

```bash
bun --version                                  # 或 npx -y bun --version
sips --version || magick --version             # 二者有其一
python3 -c 'import yaml'
```

生成图片需要至少一个 provider 的 API key（环境变量，见 `shared/scripts/preflight.py`
的 `PROVIDER_ENV`）。**没有也能用**——步骤 1–4 照跑，交付 prompt 文件。
```

- [ ] **Step 2: 端到端走一遍零成本路径**

在临时目录里真跑一遍步骤 1、3、4，确认 vendor 副本自洽：

```bash
cd /Users/biran/code/skills/writing/md2publish-skills/skills/md2publish-cover
python3 shared/scripts/preflight.py | tail -5

WORK=$(mktemp -d)
mkdir -p "$WORK/briefs/wechat" "$WORK/prompts/wechat"
cat > "$WORK/briefs/wechat/00-cover.md" <<'EOF'
主题：为什么缓存失效的 bug 大多出在写入路径。
主体：一条分叉的管道，左支标"读"且畅通，右支标"写"且有一处堵塞。
情绪：冷静的技术分析。
alt：分叉管道示意图，左支畅通标注为读，右支堵塞标注为写。
EOF

python3 shared/scripts/compose_prompt.py --platform wechat --preset editorial-warm \
  --brief-file "$WORK/briefs/wechat/00-cover.md" \
  --out "$WORK/prompts/wechat/00-cover.md"
cat "$WORK/prompts/wechat/00-cover.md"

# 同一个 brief 换平台，画幅必须跟着变
python3 shared/scripts/compose_prompt.py --platform xiaohongshu --preset editorial-warm \
  --brief-file "$WORK/briefs/wechat/00-cover.md" \
  --out "$WORK/prompts/xiaohongshu/00-cover.md"
grep -q '3:4' "$WORK/prompts/xiaohongshu/00-cover.md" && echo "画幅随平台变：ok"
grep -q '图上必须包含' "$WORK/prompts/xiaohongshu/00-cover.md" && echo "小红书要求图上有标题：ok"
grep -q '图上不要出现标题文字' "$WORK/prompts/wechat/00-cover.md" && echo "微信要求图上无标题：ok"
echo "$WORK"
```

期望：三行 `ok` 都出现，微信产物含 `16:9`、小红书产物含 `3:4`。

- [ ] **Step 3: 提交**

```bash
git add skills/md2publish-cover/SKILL.md
git commit -m "feat(cover): add md2publish-cover skill

Eight-step flow from the design spec section 7: steps 1-4 are free and produce
a prompt file, the credential and cost gates sit at step 5, compression at
step 7 is mandatory because the WeChat 2MB cap is hard. Documents that visuals
and diagram do not exist yet rather than improvising with the cover flow.

Verified: steps 1, 3 and 4 run end to end against the vendored shared/ copy;
the same brief renders 16:9 with no on-image title for WeChat and 3:4 with a
required title for Xiaohongshu."
```

---

### Task 8: `check.sh` + 文档收尾 + 手动 smoke

**Files:**
- Create: `scripts/check.sh`
- Modify: `skills/_shared/README.md`
- Modify: `skills/README.md`
- Modify: `docs/handoff/handoff-image.md`

**Interfaces:**
- Consumes: T1–T7 的全部测试
- Produces: `./scripts/check.sh` —— 一条命令跑全部检查，任一失败则非零退出

- [ ] **Step 1: 写 `check.sh`**

创建 `scripts/check.sh`（`chmod +x`）：

```bash
#!/usr/bin/env bash
# 图片能力线的全部检查。对应 spec §13 的五项 + 引擎测试。
#
# **这不是自动闸门。** 本仓库没有 CI、没有 git hooks。改了 skills/_shared/
# 或 md2publish-cover 之后，靠你自己记得跑这一条。
set -uo pipefail
cd "$(dirname "$0")/.."

FAILED=()

run() {
  local label="$1"; shift
  echo
  echo "───── $label ─────"
  if "$@"; then
    echo "  ✓ $label"
  else
    echo "  ✗ $label"
    FAILED+=("$label")
  fi
}

run "资产 schema + costs（spec §13 第 3 项）" bash skills/_shared/scripts/test-asset-schema.sh
run "渲染器 + 占位符白名单（第 2 项）"        bash skills/_shared/scripts/test-compose-prompt.sh
run "平台 × archetype × preset 矩阵（第 1 项）" bash skills/_shared/scripts/test-platform-matrix.sh
run "压缩不超限（第 4 项）"                   bash skills/_shared/scripts/test-compress.sh
run "preflight + config"                      python3 skills/_shared/scripts/test-preflight.py
run "产物落盘规则"                            bash skills/_shared/scripts/test-artifacts.sh
run "imagegen 引擎"                           bash -c 'cd skills/_shared/scripts/imagegen && bun test'
run "vendor 同步与漂移（第 5 项）"            bash scripts/test-sync-drift.sh
run "shared 漂移检查"                         bash scripts/check-shared-drift.sh

echo
if [[ ${#FAILED[@]} -eq 0 ]]; then
  echo "全部通过。"
  echo
  echo "注意：有一项**不在这里**——真调一次 provider 生一张图的最小 smoke。"
  echo "它计费，因此永远手动跑，见 docs/handoff/handoff-image.md。"
  exit 0
fi

echo "失败 ${#FAILED[@]} 项："
printf '  - %s\n' "${FAILED[@]}"
exit 1
```

- [ ] **Step 2: 跑 `check.sh`，全绿**

```bash
chmod +x scripts/check.sh && ./scripts/check.sh
```

期望：九项全 ✓，末尾 `全部通过。`。**任何一项红就停下来修，不要往下走。**

- [ ] **Step 3: 更新 `skills/_shared/README.md`**

三处改动：

1. 「布局」表格补五行：

```markdown
| `costs.yaml` | provider × model 单张估价，允许 `unknown` |
| `scripts/imagegen/` | vendor 自 baoyu-image-gen 的生图引擎（TS / bun），见 `VENDOR.md` |
| `scripts/compress.py` | 压到字节上限内（sips → magick 降级链） |
| `scripts/config.py` | 读 `~/.config/md2publish/images.yaml` |
| `scripts/preflight.py` | 运行时 / provider / 压缩工具三项自检 |
| `scripts/artifacts.py` | 重跑保护 + 产物 sidecar |
```

2. 「跑测试」一节整节替换：

```markdown
## 跑测试

一条命令跑全部（推荐）：

```bash
./scripts/check.sh          # 仓库根目录
```

单跑：

```bash
./scripts/test-asset-schema.sh      # 资产 schema + costs.yaml（17 项）
./scripts/test-compose-prompt.sh    # 渲染器行为 + 占位符白名单（11 项）
./scripts/test-platform-matrix.sh   # 平台 × archetype × preset 全矩阵（8 组合）
./scripts/test-compress.sh          # 压缩不超限（6 项）
python3 scripts/test-preflight.py   # 自检与配置（14 项）
./scripts/test-artifacts.sh         # 重跑保护与 sidecar（10 项）
(cd scripts/imagegen && bun test)   # 生图引擎（97 项）
```

**改了 `platforms/`、`presets/`、`costs.yaml` 或 `scripts/` 里任何东西之后，
跑一遍 `scripts/check.sh`。** 本仓库没有 CI、没有 git hooks，这是一条
**有文档约束的手工流程，不是自动闸门**。

改完 `_shared/` 还要跑 `scripts/sync-shared.sh` 把改动推到各 skill 的 `shared/`，
否则 `check.sh` 的漂移检查会红。
```

3. 「一期故意没做的事」整节替换成：

```markdown
## 还没做的事

- **`bilibili.yaml`** —— B 站的画幅与文字约定属未验证的外部知识，
  需先分别确认视频封面与专栏头图的规格，不猜。
- **`presets/dimensions/layouts/` 只有一个值** —— `infographic` / `series`
  真正用起来（三期）时再补。
- **`costs.yaml` 全是 `unknown`** —— 真实单价同属外部知识，用户实测后自己填。
- **`md2publish-visuals` / `md2publish-diagram`** —— 三期。
- **对现有 skill 的改动** —— `md2publish-images` 的删除与九处引用修改属二期 B。
```

- [ ] **Step 4: 更新 `skills/README.md`**

只做**纯新增**，不动 `md2publish-images` 那一行（那是二期 B 的活）。

在 skill 表格里 `md2publish-images` 那行**之后**插入：

```markdown
| `md2publish-cover` | 封面图（微信 16:9 / 小红书 3:4），真调 provider 生成 | 本地文件 + **API 消费（花钱）** | provider API key（缺失时降级为只产 prompt） |
```

在「前置」一节末尾追加：

```markdown
`md2publish-cover` 另需（其余 skill 不需要）：

```bash
bun --version                          # 或 npx -y bun --version
sips --version || magick --version     # 二者有其一
```

图片能力线的测试入口：`./scripts/check.sh`。没有 CI，手工跑。
```

在「设计要点」的「确认边界」那条**之后**追加一条：

```markdown
- **配图不再是零副作用**：`md2publish-cover` 真调 provider、真花钱、不可逆。
  它的门在生成那一步（步骤 5），前四步仍然零成本——没配 provider 也能拿到 prompt 文件
  自己去生。表格里 `md2publish-images` 那行的「无」只对旧的计划模式成立
```

- [ ] **Step 5: 手动 smoke（计费，必须先问用户）**

这一项**不进 `check.sh`**，因为它花钱。

**先问用户要不要跑**，说明会真调一次 provider、生成一张图、产生费用。用户说不跑就跳过，
在交付说明里如实写"未做真实生成 smoke"，**不要**声称端到端验证过。

用户同意后：

```bash
cd skills/md2publish-cover
WORK=$(mktemp -d) && mkdir -p "$WORK/briefs/wechat" "$WORK/assets/wechat"
cat > "$WORK/briefs/wechat/00-cover.md" <<'EOF'
主题：为什么缓存失效的 bug 大多出在写入路径。
主体：一条分叉的管道，左支标"读"且畅通，右支标"写"且有一处堵塞。
情绪：冷静的技术分析。
alt：分叉管道示意图，左支畅通标注为读，右支堵塞标注为写。
EOF
python3 shared/scripts/compose_prompt.py --platform wechat --preset editorial-warm \
  --brief-file "$WORK/briefs/wechat/00-cover.md" --out "$WORK/prompts/wechat/00-cover.md"
python3 shared/scripts/artifacts.py guard --path "$WORK/assets/wechat/00-cover.png"
bun shared/scripts/imagegen/main.ts \
  --promptfiles "$WORK/prompts/wechat/00-cover.md" \
  --image "$WORK/assets/wechat/00-cover.png" --ar 16:9
FINAL=$(python3 shared/scripts/compress.py --image "$WORK/assets/wechat/00-cover.png" --max-bytes 2097152)
python3 shared/scripts/artifacts.py sidecar --image "$FINAL" \
  --platform wechat --archetype cover --preset editorial-warm \
  --provider <实际用的> --model <实际用的> \
  --prompt-file "$WORK/prompts/wechat/00-cover.md" \
  --brief-file "$WORK/briefs/wechat/00-cover.md" \
  --alt-text "分叉管道示意图，左支畅通标注为读，右支堵塞标注为写。"
wc -c < "$FINAL"      # 必须 ≤ 2097152
```

完成判据：`$FINAL` 存在、字节数 ≤ 2097152、同名 `.json` 存在且 `preset_version` 非空。

- [ ] **Step 6: 更新 handoff**

改 `docs/handoff/handoff-image.md`：

1. 「快速接手入口」第 2、3 条改成二期 A 已完成、下一步是二期 B。
2. 「二、基线」的三条命令替换成 `./scripts/check.sh`，并写明九项分别是什么、期望全绿。
3. 「六、剩下的活」里把二期 A 整块标记为**已完成**，附实测数字（引擎 97 项、
   schema 17 项、压缩 6 项、preflight 14 项、artifacts 10 项、vendor 8 项），
   并注明手动 smoke 做了没有（**如实写**）。
4. 「三、关键契约」补四条：D1–D4 四处偏离（见本计划开头的表）。
5. 新增一条给二期 B 的警告：**spec §12 正文首句写的是"七处"，表格是 9 行，
   §16 说的是"九处"。以表格为准，改 spec 正文那句话是二期 B 的第一步。**

- [ ] **Step 7: 最终验证与提交**

```bash
./scripts/check.sh                                            # 九项全 ✓
python3 skills/md2publish-article/scripts/test-theme-lib.py   # ok：0 条失败（另一条线没被碰坏）
grep -rn "md2publish-images" skills/md2publish-images | wc -l # 旧 skill 仍在，本期不动它
git status --short
```

```bash
git add scripts/check.sh skills/_shared/README.md skills/README.md docs/handoff/handoff-image.md
git commit -m "feat(scripts): add check.sh and update docs for phase 2A

check.sh runs the five verification items from design spec section 13 plus the
vendored engine tests and the drift check. It is explicitly documented as a
manual step, not a gate -- this repo has no CI and no git hooks.

Docs record the four deliberate deviations from the spec and flag that spec
section 12 still says 'seven' dangling references in prose while its own table
lists nine; phase 2B must fix that sentence first.

Verified: check.sh -> 9/9 green; theme-lib test still 0 failures."
```

---

## 完成判据（spec §15 二期 A）

| 判据 | 怎么验 |
|---|---|
| 端到端产出一张微信封面并压到 2MB 内 | T8 Step 5 手动 smoke，`wc -c` ≤ 2097152 |
| 手动 smoke（真调一次 provider）通过 | 同上。**没跑就如实说没跑** |
| spec §13 五项全绿 | `./scripts/check.sh` |
| `md2publish-images` 原地保留 | `ls skills/md2publish-images/SKILL.md` 仍在，且 `git log` 显示本期未改它 |
| 纯新增、无破坏性 | 本期改的既有文件只有三份文档 + `asset_lib.py`（纯追加）+ `test-asset-schema.sh`（纯追加） |

## 自查记录

**spec 覆盖**：§4.1 搬迁 → T1；§4.3 vendor 清单与漂移恢复 → T6；§5.3 sidecar → T5；
§7 步骤 1–8 → T7；§7.1 凭证门位置 → T7 步骤 5；§7.3 产物布局与重跑 → T5 + T7；
§9 成本门与计费尝试上限 → T4 + T1(D2) + T7；§10 失败分类 → T7 步骤 6 表格；
§11 前置与 preflight → T3 + T7；§13 五项 → T2/T4/T6 + 既有三项，入口 `check.sh` → T8；
§15 二期 A 全部条目 → T1–T8。

**未覆盖且有意为之**：§7.2 多平台对 `visuals` 不成立——那是三期的事，本期只在
SKILL.md 里写明"每平台各走一遍、各确认各的成本"；§9 的 `max_images_per_run` 硬上限
由 `config.py` 载入但封面用不上（永远 1 张），三期批量时才有消费者。
