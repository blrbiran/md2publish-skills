# 三期：md2publish-visuals 与 md2publish-diagram 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal：** 建成 `md2publish-visuals`（正文配图 / 信息图 / 卡片系列，含 Markdown 回写门）与 `md2publish-diagram`（架构图 / 流程图，不调 AI、直接写 SVG，含 SVG→PNG 降级链），并把 `visuals` 接进 `md2publish-article` 的上游。

**Architecture：** 机械层只新增两个脚本（`writeback.py`、`svg2raster.py`）、改一处既有脚本（`artifacts.py` 加 diagram 支路）；语义层是两份新的 `SKILL.md`。承重的跨组件契约只有一条——**sidecar 的 `image` 字段是「下游该消费哪个文件」的唯一真相源**：二期 B 已经让 `md2publish-draft` 读它，本期让 `writeback.py` 的 insertions 也读它。`diagram` 与另两个 skill 的形状差异是有意的：它零成本，整条链路**没有**「═══ 以下开始计费 ═══」那条线，也不走 preset / prompt。

**Tech Stack：** Python 3.9.13（anaconda3）+ PyYAML 6.0；bash 3.2.57；`scripts/check.sh` 作为唯一验证入口。本期**不引入任何新的语言级依赖**；新增的外部工具依赖（`rsvg-convert` / `magick` / headless Chrome）只影响 diagram，且缺失时降级而不是硬失败。

**设计真相源：** `docs/superpowers/specs/2026-08-09-md2publish-image-skills-design.md`（§3 边界、§6 机械/语义分层、§7 执行链路、§8 流水线次序、§9 副作用与成本门、§10 失败处理、§13 验证、§14.3 SVG 转位图、§15 三期）。本计划不重复 spec 的论证，只给可执行步骤，并在下方偏离表里列出与 spec 不一致之处及理由。

---

## Global Constraints

每个任务的要求都隐含包含本节，不再逐条重复。

- **Python 版本是 3.9.13。** 任何新增 `.py` 文件的 import 区第一行必须是 `from __future__ import annotations`。本期新增两个：`writeback.py`、`svg2raster.py`。
- **`svg2raster.py` 只许用标准库**，不许 `import yaml`、不许 `import asset_lib`。理由不是洁癖：它的降级链测试要在 PATH 遮蔽沙箱里用 `/usr/bin/python3`（3.9.6，**没装 PyYAML**）跑，只有纯标准库才跑得起来。否则就只能往生产代码里塞一个"假装某后端不存在"的测试后门。
- **这台机器的 bash 是 GNU bash 3.2.57。** 写含中文提示的 shell 断言时，变量一律 `${var}`，**不要**裸 `$var`——`$var）` 会让变量名被解析坏，`set -u` 下报假的 unbound variable。二期 A 栽过两次。
- **`mv` 在这台机器上是交互式的**（覆盖时等 y/n，自动化里表现为卡死）。脚本里一律 `\cp -f` / `\cp -Rf`。
- **仓库里有另一个 agent 在并发提交。** 只用显式路径 `git add <path>`，**绝不** `git add -A` / `git commit -a`。每个任务开工前先 `git status`。**不要切分支、不要 `git stash`**——工作区是共享的。
- **`git commit` 的写法有坑：`--` 必须排在 `-m` / `-F` 之后。** `git commit -- <路径> -m "msg"` 会把 `-m` 当成 pathspec 报错。正确形式是 `git commit -F <消息文件> -- <路径>`。本计划每个任务的提交步骤都已按正确形式写好，照抄即可。
- **commit message 与分支名一律英文**（`CLAUDE.md` Rule 0 / handoff §5）。文档内容中文。
- **行号会漂。** 本计划给出的所有行号都是写计划当天的快照。**每一处改动都先 `grep -n` 定位，再改**，不许照着计划里的行号盲改。
- **本仓库没有 CI、没有 git hooks、没有 `.github/`。** 所有测试手跑。任何文档都不许把 `check.sh` 写成"自动闸门"。
- **`_shared/` 是唯一真相源。** 改了 `skills/_shared/` 下的任何文件，必须跑 `scripts/sync-shared.sh` 再跑 `scripts/check.sh`。发现某个 skill 的 `shared/` 与 `_shared/` 不一致时，正确动作永远是"把改动挪回 `_shared/` 再 re-sync"，绝不是"re-sync 覆盖掉"。
- **`check.sh` 里「shared 漂移检查」必须排在「vendor 同步与漂移」之前，本期不许调换，新项也不许插到这两项之间或之后。** 后者开头就跑一遍 `sync-shared.sh`，调换后真实漂移会在被看见之前被冲掉（design §4.3：漂移是 vendoring 唯一的真实失败模式，且绝不能靠 re-sync 解决）。本期新增的三项全部插在它们**之前**。
- **不许改这三处的措辞**：`compose_prompt.py:render_platform_frame` 产出的契约串 `图上必须包含` / `图上不要出现标题文字`，以及 `test-compose-prompt.sh`、`test-platform-matrix.sh` 里 grep 它的那两行。
- **本期不新增 preset、不新增维度值、不做 `bilibili.yaml`。** `illustration` / `infographic` / `series` 各已有一个可用 preset，矩阵测试的 2 平台 × 4 preset = 8 组合已经覆盖它们。B 站画幅属未验证的外部知识（一期故意留白），本期不猜。
- **不许把 `md2publish-images` 写回任何地方。** 它在二期 B 已被删除。

### 本期基线（每个任务开工前应仍然成立）

```bash
./scripts/check.sh                                            # 本期开工时九项全 ✓，末尾「全部通过。」
python3 skills/md2publish-article/scripts/test-theme-lib.py   # ok：0 条失败（不在 check.sh 里，单跑）
```

各项当前数字，变了就是碰坏了别的东西，停下来查：

| check.sh 项 | 开工时 | 本期结束时 |
|---|---|---|
| 资产 schema + costs | 18 | 18（不变） |
| 渲染器 + 占位符白名单 | 11 | 11（不变） |
| 平台 × archetype × preset 矩阵 | 8 | 8（不变） |
| 压缩不超限 | 8 | 8（不变） |
| preflight + config | 21 | 21（不变） |
| 产物落盘规则 | 12 | **18**（T1 加 6 项） |
| imagegen 引擎 | 97 pass / 12 files | 不变 |
| **Markdown 回写门**（新） | — | **12**（T3） |
| **SVG→位图降级链**（新） | — | **11**（T2，本机三后端齐全时；缺后端的机器上会少几项并打印 ⊘） |
| **diagram 端到端**（新） | — | 通过或 SKIPPED（T7） |
| shared 漂移检查 | 1 skill | **3 skills**（T6） |
| vendor 同步与漂移 | 9 | **12**（T6 加 3 项） |

**项数由 9 变 12。** 收尾时所有文档里写"九项"的地方都要改（T9 负责，用 `grep -rn '九项'` 一次找全）。

### 口径（别混着说）

- `check.sh` 全绿 **≠** 端到端验证过。**真调一次 provider 生一张图的付费 smoke 从未跑过**（本机一个 provider 凭证都没配置）。本期新增的 `visuals` 同样**不会**被端到端验证——小红书 5 张卡片系列要花钱。收尾报告里不许把两者混为一谈。
- **`diagram` 是例外**：它零成本，本机 `rsvg-convert` / `magick` / Chrome 三个后端都在，端到端**会被真跑**（T7）。这是本期唯一一条真正端到端验证过的链路，说的时候要说清楚是哪一条。

### 与 spec 的偏离（已论证，实施时照本计划走）

| # | spec 怎么说 | 实际怎么做 | 为什么 |
|---|---|---|---|
| D11 | §5.3 的 sidecar schema 假定每张图都有 `preset` / `provider` / `prompt_file` / `brief_file` | `artifacts.py` 按 `--archetype diagram` 分出「确定性产物」支路：`preset` / `preset_version` / `model` / `prompt_file` / `brief_file` 一律记 `null`，新增 `source_file`（SVG 文件名），`provider` 记**实际用的光栅化后端名** | diagram 不调 AI、不走 preset，照 spec 原样执行会在写 sidecar 时硬失败——`artifacts.py:43` 拿到 `--preset` 立刻 `load_preset()`。另外"这张 PNG 是谁光栅化的"必须被记下来：同一份 SVG 在装了 rsvg 和只有 Chrome 的两台机器上产出不同的位图，不记就无从查。这是二期 A「sidecar 记的 provider 与引擎实际选的不是一回事」的同族问题 |
| D12 | §6 / §7：三个 skill 共用同一条链路，步骤 4 一律「渲染 prompt」 | `diagram` **不走** `compose_prompt.py` / preset / `prompts/`；复现记录是 SVG 源文件本身，落在 `diagrams/<platform>/NN-diagram.svg` | 维度词表（`soft-gouache`、`flat-vector`）是写给 AI 生图 prompt 的，SVG 根本不消费它们；硬套只会多产出一份没有任何消费者的中间文件。SVG 比 prompt 更强的复现记录——改它重跑是确定性的 |
| D13 | §14.3：降级链三者都缺时「保留 SVG 并告知用户，不静默失败」 | 照做；**另加**一条 spec 没有的机械约束：`svg2raster.py --aspect` 与 SVG `viewBox` 的比例相差超过 1% 时直接硬失败 | diagram 不过矩阵测试（它不走 composer），这是唯一能机械验证"平台画幅真被用上"的地方。少了它，agent 画一个正方形却声称 16:9，位图被拉伸变形，肉眼在小图上看不出来 |
| D14 | §13：`check.sh` 串起五项；「一项不进自动化、手动跑：真调 provider 的最小 smoke」 | `check.sh` 由 9 项扩到 **12 项**；新增的「diagram 端到端」在三个后端全缺时打印 `SKIPPED`，并把末尾口径由「全部通过。」改成「全部通过（N 项跳过：…）」 | diagram 零成本，它的端到端**可以**自动化，不该跟付费 smoke 一起挂账。但它依赖机器上装了 rsvg/magick/chrome，硬失败会把只想改主题库的人也拦在门外。SKIPPED 必须显式改末尾口径——不改就是二期 A 教训 4 的假绿：一项从未真正跑过，而摘要在说"全部通过" |
| D15 | §8：「有配图时，`article` 的输入是 `article.illustrated.md` 而不是 `article.wechat.md`」 | 输入表写成：同目录存在 `article.illustrated.md` 时**默认用它，并告知用户选了哪份、不带图的那份叫什么**；用户显式给了路径则优先 | spec 只说"必须认"，没说默认规则。每次都问会退化成 §3.2 明确反对的多轮问答；静默改默认又会让用户不知道自己转的是哪一份 |
| D16 | §3.1：`visuals` 的三种形态（插图 / 信息图 / 卡片系列）统一处理 | **`series` 不回写 Markdown**：`visuals` 跑小红书时到写完 sidecar 就结束，**不产生** `article.illustrated.md` | 卡片系列是内容本身、不进正文（§3.1 自己就是这么论证 series 与 illustration 的差别的）。回写门只在 `illustration` / `infographic` / `diagram` 要插进正文时触发 |
| D17 | §14.3：降级链 `rsvg-convert → magick → headless Chrome` 三级 | magick 这一级加能力闸：`magick -list format` 的 SVG 行里没有 `RSVG` 证据时，既不进降级链、显式指定也硬失败 | 本机实测：没有 RSVG delegate 的 magick 会 **exit 0 却把图上所有文字丢光**，只剩图形。静默产出无字废图比硬失败坏得多——它要到发布后才会被发现。spec 假定三级都是可用的渲染器，实际第二级的可用性取决于一个必须探测的编译期 delegate |

### 为什么是逐任务 commit

与二期 B 同理，不再重复论证：并发 agent 下切分支危险；逐任务 commit 才能逐任务过评审（二期 A、二期 B 连续两期证明整支评审抓得到逐任务评审抓不到的东西）。本期**没有破坏性删除**，唯一有下游影响的改动是 T8 的 `md2publish-article` 输入表，回滚就是 `git revert` 那一个 commit（它只动文档，不与另一条线的文件同 commit——前提是照 Global Constraints 用显式路径提交）。

---

## 文件结构

| 文件 | 本期做什么 | 归属任务 |
|---|---|---|
| `skills/_shared/scripts/artifacts.py` | `sidecar()` 加 diagram 支路 + `source_file` 字段 | T1 |
| `skills/_shared/scripts/test-artifacts.sh` | 加 6 项断言（12 → 18） | T1 |
| `skills/_shared/scripts/svg2raster.py` | **新建**。SVG→PNG，三级降级链，画幅校验 | T2 |
| `skills/_shared/scripts/fixtures/diagram-sample.svg` | **新建**。测试与端到端共用的 fixture | T2 |
| `skills/_shared/scripts/test-svg2raster.sh` | **新建**。8 项，含 PATH 遮蔽沙箱 | T2 |
| `skills/_shared/scripts/writeback.py` | **新建**。Markdown 回写 | T3 |
| `skills/_shared/scripts/test-writeback.sh` | **新建**。12 项 | T3 |
| `skills/md2publish-diagram/SKILL.md` | **新建** | T4 |
| `skills/md2publish-visuals/SKILL.md` | **新建** | T5 |
| `scripts/shared-manifest.sh` | `SHARED_SKILLS` 加两个；两个新 case | T6 |
| `scripts/test-sync-drift.sh` | 沙箱改为遍历 `SHARED_SKILLS`；按 skill 分别断言（9 → 12） | T6 |
| `skills/md2publish-visuals/shared/`、`skills/md2publish-diagram/shared/` | **由 `sync-shared.sh` 生成，不手改** | T6 |
| `scripts/test-diagram-e2e.sh` | **新建**。零成本端到端，缺工具时 exit 2 = SKIPPED | T7 |
| `scripts/check.sh` | `run()` 支持 SKIPPED；接入三个新项；改末尾口径 | T7 |
| `skills/md2publish-article/SKILL.md` | 步骤 1 输入表加一行；边界节改 | T8 |
| `skills/README.md`、`skills/_shared/README.md`、`skills/md2publish-cover/SKILL.md`、`skills/wechat-finetune/SKILL.md` | 去掉「三期，尚未实现」，接上流水线次序 | T8 |
| `docs/superpowers/specs/2026-08-09-md2publish-image-skills-design.md` | §5.3 §6 §7 §13 §14.3 §15 §16 反向修订 | T9 |
| `docs/handoff/handoff-image.md` | 三期完成记录 + 教训 | T9 |

---

### Task 1: artifacts.py 的 diagram 支路

**Files:**
- Modify: `skills/_shared/scripts/artifacts.py`（`sidecar()` 与 `main()` 的参数定义）
- Modify: `skills/_shared/scripts/test-artifacts.sh`（在末尾 `run_sidecar no-such-preset` 那项之后追加）
- Generated: `skills/md2publish-cover/shared/scripts/artifacts.py`（跑 `sync-shared.sh`，不手改）

**Interfaces:**
- Consumes: 无（本期第一个任务）
- Produces:
  - `artifacts.py sidecar --archetype diagram` 支路。**必填**：`--image` `--platform` `--archetype` `--alt-text` `--source-file` `--provider`；**不接受**：`--preset` `--model` `--prompt-file` `--brief-file`（传了就硬失败）。
  - sidecar JSON 新增字段 `"source_file"`：diagram 时是 SVG 的**文件名**（不是路径），其余 archetype 一律 `null`。
  - diagram 的 `"provider"` 语义是**光栅化后端名**（`rsvg-convert` / `magick` / `chrome`），不是 AI provider。T2 的 `svg2raster.py --json` 输出的 `backend` 就是要填进这里的值。
  - T4（diagram SKILL.md）、T7（端到端脚本）依赖这条命令行契约。

- [ ] **Step 1: 确认起点**

```bash
git status                                     # 干净，或只有另一条线的改动；有我们的残留先停下来问
cd skills/_shared/scripts && bash test-artifacts.sh | tail -2 && cd ../../..
```

预期：测试打印「通过 12 项，失败 0 项」。

- [ ] **Step 2: 写会失败的断言**

在 `skills/_shared/scripts/test-artifacts.sh` 末尾的 `通过 $PASS 项` 那两行**之前**插入下面整段。注意每一条中文提示里的变量都写成 `${var}`（bash 3.2.57，见 Global Constraints）。

```bash
echo
echo "== sidecar：diagram 支路（零成本产物，不走 preset/prompt） =="

printf 'fake-png-bytes' > "$TMP/00-diagram.png"
DSIDE="$TMP/00-diagram.json"
djq() { python3 -c "import json,sys; print(json.load(open('$DSIDE'))$1)"; }

out=$(python3 artifacts.py sidecar \
  --image "$TMP/00-diagram.png" \
  --platform wechat --archetype diagram \
  --provider rsvg-convert \
  --source-file 00-diagram.svg \
  --alt-text "三层缓存架构示意图" 2>&1)
rc=$?
if [[ $rc -eq 0 && -f "$DSIDE" ]]; then
  ok "diagram：不传 preset/model/prompt/brief 也能写出 sidecar"
else
  bad "diagram 支路写不出 sidecar" "rc=${rc} out=${out}"
fi

got=$(djq "['preset']" 2>&1)
got_v=$(djq "['preset_version']" 2>&1)
if [[ "$got" == "None" && "$got_v" == "None" ]]; then
  ok "diagram：preset 与 preset_version 都是 null"
else
  bad "diagram 的 preset 字段不对" "preset=${got} version=${got_v}"
fi

got=$(djq "['source_file']" 2>&1)
if [[ "$got" == "00-diagram.svg" ]]; then
  ok "diagram：source_file 记着 SVG 文件名（它是唯一的复现记录）"
else
  bad "source_file 不对" "got=${got}"
fi

got=$(djq "['provider']" 2>&1)
if [[ "$got" == "rsvg-convert" ]]; then
  ok "diagram：provider 记的是实际光栅化后端"
else
  bad "provider 不是后端名（换台机器就查不出 PNG 是谁生成的）" "got=${got}"
fi

out=$(python3 artifacts.py sidecar \
  --image "$TMP/00-diagram.png" \
  --platform wechat --archetype diagram \
  --provider rsvg-convert --preset editorial-warm \
  --model x --prompt-file x --brief-file x \
  --source-file 00-diagram.svg \
  --alt-text "三层缓存架构示意图" 2>&1)
if [[ $? -ne 0 ]] && grep -q -- '--preset' <<<"$out"; then
  ok "diagram 传了 --preset 时硬失败并点名（照抄 cover 命令会被拦住）"
else
  bad "diagram 接受了 --preset" "$out"
fi

out=$(python3 artifacts.py sidecar \
  --image "$TMP/exists.png" \
  --platform wechat --archetype cover \
  --provider openai --model gpt-image-2 \
  --prompt-file prompts/wechat/00-cover.md \
  --brief-file briefs/wechat/00-cover.md \
  --alt-text "暖色调编辑风封面" 2>&1)
if [[ $? -ne 0 ]] && grep -q -- '--preset' <<<"$out"; then
  ok "非 diagram 缺 --preset 仍硬失败（支路没把 cover 的必填放松掉）"
else
  bad "cover 少了 --preset 却通过了" "$out"
fi
```

- [ ] **Step 3: 跑测试，确认它以正确的方式失败**

```bash
cd skills/_shared/scripts && bash test-artifacts.sh | tail -14 && cd ../../..
```

预期：新加的 6 项里至少第 1 项失败（`unrecognized arguments: --source-file` 或 `--preset is required`），末行「通过 12 项，失败 6 项」。**看到「失败 0 项」要停下来查**——那说明断言没被执行到。

- [ ] **Step 4: 改 artifacts.py**

把 `sidecar()` 整个替换成下面这版（`guard` / `parse_overrides` 不动）：

```python
# 零成本、确定性产出的 archetype：不调 AI，因此没有 preset / prompt / brief / model。
# 它们的 provider 字段记的是**光栅化后端**（rsvg-convert / magick / chrome）——
# 同一份 SVG 在不同机器上会被不同后端渲染成不同的位图，不记就无从追溯。
DETERMINISTIC_ARCHETYPES = {"diagram"}


def sidecar(image: Path, meta: dict) -> Path:
    if not image.exists():
        raise a.AssetError(f"图片不存在，无法写 sidecar: {image}")
    if meta["archetype"] in DETERMINISTIC_ARCHETYPES:
        preset_name = None
        preset_version = None
    else:
        preset = a.load_preset(meta["preset"])   # preset 不存在时在这里硬失败
        preset_name = meta["preset"]
        preset_version = preset["version"]
    record = {
        "platform": meta["platform"],
        "archetype": meta["archetype"],
        "preset": preset_name,
        "preset_version": preset_version,
        "overrides": meta["overrides"],
        "provider": meta["provider"],
        "model": meta["model"],
        "prompt_file": meta["prompt_file"],
        "brief_file": meta["brief_file"],
        "source_file": meta["source_file"],
        "alt_text": meta["alt_text"],
        "image": image.name,
        "bytes": image.stat().st_size,
        "generated_at": datetime.now().astimezone().isoformat(timespec="seconds"),
    }
    out = image.with_suffix(".json")
    out.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return out


def check_sidecar_args(args) -> None:
    """按 archetype 分支校验必填项。

    argparse 的 required=True 做不到这件事：cover 必须有 preset，diagram 必须没有。
    放任 diagram 传 preset 不报错的话，照抄 cover 命令的人会得到一份声称走过
    preset 链路、实际根本没有的 sidecar。
    """
    ai_only = (
        ("--preset", args.preset),
        ("--model", args.model),
        ("--prompt-file", args.prompt_file),
        ("--brief-file", args.brief_file),
    )
    if args.archetype in DETERMINISTIC_ARCHETYPES:
        if not args.source_file:
            raise a.AssetError(
                f"--archetype {args.archetype} 必须给 --source-file"
                "（SVG 的文件名，不是路径）：它是这张图唯一的复现记录"
            )
        given = [flag for flag, value in ai_only if value]
        if given:
            raise a.AssetError(
                f"--archetype {args.archetype} 不接受 {given}："
                "它不调 AI、不走 preset / prompt 链路，这些字段一律记 null"
            )
        return
    missing = [flag for flag, value in ai_only if not value]
    if missing:
        raise a.AssetError(f"--archetype {args.archetype} 缺必填参数: {missing}")
    if args.source_file:
        raise a.AssetError("--source-file 只用于确定性 archetype（当前：diagram）")
```

`main()` 里 sidecar 子命令的参数定义替换成：

```python
    s = sub.add_parser("sidecar", help="写 <image 同名>.json，记录生成它的全部输入")
    s.add_argument("--image", required=True)
    # 所有 archetype 都必须有的
    for field in ("platform", "archetype", "provider", "alt-text"):
        s.add_argument(f"--{field}", required=True)
    # 按 archetype 分支必填，由 check_sidecar_args 校验（argparse 表达不了这种条件必填）
    for field in ("preset", "model", "prompt-file", "brief-file", "source-file"):
        s.add_argument(f"--{field}", default=None)
    s.add_argument("--override", action="append", default=[], metavar="KEY=VALUE")
```

`main()` 里 `args.cmd == "guard"` 之后那段替换成：

```python
        check_sidecar_args(args)
        out = sidecar(Path(args.image), {
            "platform": args.platform,
            "archetype": args.archetype,
            "preset": args.preset,
            "provider": args.provider,
            "model": args.model,
            "prompt_file": args.prompt_file,
            "brief_file": args.brief_file,
            "source_file": args.source_file,
            "alt_text": args.alt_text,
            "overrides": parse_overrides(args.override),
        })
```

- [ ] **Step 5: 跑测试，确认全绿**

```bash
cd skills/_shared/scripts && bash test-artifacts.sh | tail -3 && cd ../../..
```

预期：「通过 18 项，失败 0 项」。

- [ ] **Step 6: 同步 vendor 副本并跑全量检查**

```bash
./scripts/sync-shared.sh && ./scripts/check.sh 2>&1 | tail -6
```

预期：九项全 ✓、末尾「全部通过。」，且第 6 项打印「通过 18 项」。

- [ ] **Step 7: Commit**

```bash
cat > /tmp/t1.txt <<'EOF'
feat(shared): give artifacts.py a deterministic-archetype branch

diagram produces no preset, prompt, brief or model -- it is written by
hand as SVG and rasterized locally. sidecar() used to call load_preset()
unconditionally, so writing a sidecar for a diagram was impossible.

- --archetype diagram now requires --source-file (the SVG filename) and
  rejects --preset/--model/--prompt-file/--brief-file outright, so a
  copied-from-cover command fails loudly instead of recording a sidecar
  that claims a preset chain it never went through
- provider carries the rasterization backend for diagrams; the same SVG
  renders differently under rsvg-convert and chrome and that has to be
  traceable
- new source_file field, null for every AI-generated archetype

test-artifacts.sh: 12 -> 18 assertions, including one that cover still
hard-fails without --preset (the branch must not loosen the old path).

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
git add skills/_shared/scripts/artifacts.py skills/_shared/scripts/test-artifacts.sh \
        skills/md2publish-cover/shared/scripts/artifacts.py
git commit -F /tmp/t1.txt -- skills/_shared/scripts/artifacts.py \
        skills/_shared/scripts/test-artifacts.sh \
        skills/md2publish-cover/shared/scripts/artifacts.py
```

---

### Task 2: svg2raster.py 与它的降级链测试

**Files:**
- Create: `skills/_shared/scripts/svg2raster.py`
- Create: `skills/_shared/scripts/fixtures/diagram-sample.svg`
- Create: `skills/_shared/scripts/test-svg2raster.sh`

**Interfaces:**
- Consumes: 无（不依赖 T1）
- Produces:
  - `python3 svg2raster.py --check [--json]` → 报告可用后端。JSON 形如 `{"backends": ["rsvg-convert", "magick"], "chrome": "/path/to/chrome"}`；一个都没有时 `backends` 为空数组，**退出码仍是 0**（这是报告，不是门）。
  - `python3 svg2raster.py --svg S --out O --aspect 16:9 [--width 1600] [--backend NAME] [--json]` → 产出 PNG。`--json` 输出 `{"backend": "...", "out": "...", "width": N, "height": N, "bytes": N}`。**`backend` 就是 T1 里要填进 sidecar `--provider` 的值。**
  - 退出码：0 成功；1 失败（含"一个后端都没有"，此时明说 SVG 已保留、需自行转换）。
  - T4（diagram SKILL.md）、T7（端到端脚本）依赖这两条命令行契约。

- [ ] **Step 1: 确认起点与本机后端**

```bash
git status
for c in rsvg-convert magick; do printf '%-14s ' "${c}"; command -v "${c}" || echo "(缺)"; done
ls -d "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" 2>/dev/null || echo "chrome (缺)"
/usr/bin/python3 -V        # 期望 3.9.x；PATH 遮蔽测试要用它
```

写计划当天：三个后端都在，`/usr/bin/python3` 是 3.9.6。**任何一个缺失都不阻塞本任务**——测试会自动跳过对应的那一级并如实打印。

- [ ] **Step 2: 写 fixture SVG**

创建 `skills/_shared/scripts/fixtures/diagram-sample.svg`。它的 `viewBox` 是 1600×900（16:9），字体 fallback 链完整——**四个字体名一个都不能少**，`test-svg2raster.sh` 会 grep 它们（spec §14.3：只写"用系统安全字体"不够，macOS 与 Linux 的 CJK 默认字体不同）：

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1600 900" width="1600" height="900">
  <rect x="0" y="0" width="1600" height="900" fill="#F7F5F2"/>
  <g font-family="&quot;PingFang SC&quot;, &quot;Noto Sans CJK SC&quot;, &quot;Microsoft YaHei&quot;, sans-serif"
     font-size="36" fill="#2B2B2B" text-anchor="middle">
    <rect x="120" y="380" width="320" height="140" rx="12" fill="#FFFFFF" stroke="#8C6A4F" stroke-width="3"/>
    <text x="280" y="458">客户端</text>
    <rect x="640" y="380" width="320" height="140" rx="12" fill="#FFFFFF" stroke="#8C6A4F" stroke-width="3"/>
    <text x="800" y="458">缓存层</text>
    <rect x="1160" y="380" width="320" height="140" rx="12" fill="#FFFFFF" stroke="#8C6A4F" stroke-width="3"/>
    <text x="1320" y="458">数据库</text>
    <line x1="440" y1="450" x2="640" y2="450" stroke="#8C6A4F" stroke-width="3"/>
    <line x1="960" y1="450" x2="1160" y2="450" stroke="#8C6A4F" stroke-width="3"/>
  </g>
</svg>
```

- [ ] **Step 3: 写会失败的测试**

创建 `skills/_shared/scripts/test-svg2raster.sh`（`chmod +x` 不需要，`check.sh` 用 `bash` 调）：

```bash
#!/usr/bin/env bash
# svg2raster.py 的降级链测试。对应 spec §14.3 与三期 D13、D17。
#
# **降级链只能靠遮蔽 PATH 来验证。** 直接调 --backend 只证明"指定后端能用"，
# 证明不了"rsvg 不在时会自动退到下一级"——而后者才是降级链存在的理由。
# 遮蔽是在沙箱 bin 目录里只放需要的那一个后端，再把 PATH 换成它。
# 因此 svg2raster.py **必须只用标准库**：遮蔽后要用 /usr/bin/python3（3.9.6，
# 没装 PyYAML）来跑，import yaml 会直接崩。
#
# **遮掉 rsvg-convert 之后，期望退到的不一定是 magick。** magick 只有探测到真
# 的 RSVG delegate 才会被信任（见 svg2raster.py 的 magick_has_rsvg()）：没有
# delegate 的 magick 能把 SVG"跑通"（exit 0、产出合法 PNG），却会把图上所有
# CJK 文字静默丢光——这是本机实测出来的真实故障模式，比硬失败凶险得多。所以下
# 面"降级链的真行为"那条断言按本机探测结果二选一：探测到 delegate 就该退到
# magick，探测不到就该退到 chrome。如果看到它断言"退到 chrome"，别以为是降级
# 链断了——那是刻意不让一个会丢字的 magick 被静默选中。
set -uo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM

PASS=0
FAIL=0
ok()   { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad()  { echo "  ❌ $1"; echo "     $2"; FAIL=$((FAIL+1)); }
skip() { echo "  ⊘ $1（本机没有该后端，跳过）"; }

SVG=fixtures/diagram-sample.svg
CHROME_APP="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

png_w() { python3 -c "
import sys
d = open('$1','rb').read(24)
sys.exit(1) if d[:8] != b'\x89PNG\r\n\x1a\n' else print(int.from_bytes(d[16:20],'big'))
"; }

echo "== fixture 自身的约束 =="

missing=""
for f in "PingFang SC" "Noto Sans CJK SC" "Microsoft YaHei" "sans-serif"; do
  grep -q "${f}" "$SVG" || missing="${missing} ${f}"
done
if [[ -z "${missing}" ]]; then
  ok "fixture 的 CJK 字体 fallback 链完整（四个都在）"
else
  bad "字体 fallback 链缺项，换台机器渲染结果就不一样" "缺:${missing}"
fi

echo
echo "== --check =="

out=$(python3 svg2raster.py --check --json 2>&1)
rc=$?
if [[ $rc -eq 0 ]] && python3 -c "import json,sys; json.loads(sys.argv[1])['backends']" "$out" >/dev/null 2>&1; then
  ok "--check 输出合法 JSON 且退出 0（它是报告，不是门）"
else
  bad "--check 输出不对" "rc=${rc} out=${out}"
fi

echo
echo "== 画幅校验（D13） =="

out=$(python3 svg2raster.py --svg "$SVG" --out "$TMP/bad.png" --aspect 3:4 2>&1)
if [[ $? -ne 0 ]] && grep -q '16:9\|1.77\|viewBox' <<<"$out"; then
  ok "viewBox 比例与 --aspect 不符时硬失败（否则位图被拉伸变形）"
else
  bad "画幅不符却通过了" "$out"
fi

echo
echo "== 降级链：逐级遮蔽 PATH =="

# 沙箱 bin 里只放要暴露的后端；PATH 只留它 + 系统目录（用 /usr/bin/python3 跑）
run_masked() {   # $1=要暴露的后端（空=一个都不暴露） $2=输出文件 $3=chrome 路径或空
  local expose="$1" out="$2" chrome="$3"
  local bin="$TMP/bin-${expose:-none}"
  rm -rf "${bin}"; mkdir -p "${bin}"
  [[ -n "${expose}" ]] && ln -sf "$(command -v "${expose}")" "${bin}/${expose}"
  env -i PATH="${bin}:/usr/bin:/bin" HOME="$HOME" SVG2RASTER_CHROME="${chrome}" \
    /usr/bin/python3 svg2raster.py --svg "$PWD/$SVG" --out "${out}" --aspect 16:9 --width 800 --json 2>&1
}

if command -v rsvg-convert >/dev/null; then
  out=$(run_masked rsvg-convert "$TMP/a.png" "")
  if [[ $? -eq 0 ]] && grep -q '"backend": "rsvg-convert"' <<<"$out" && [[ "$(png_w "$TMP/a.png")" == "800" ]]; then
    ok "只有 rsvg-convert 时用它，且输出宽度等于 --width"
  else
    bad "rsvg-convert 这一级不成立" "$out"
  fi
else
  skip "rsvg-convert"
fi

# 本机 magick 是否真的可信（探测到 RSVG delegate），用非遮蔽的正常调用判断——
# 这反映的是这台机器的真实能力，跟接下来遮不遮 PATH 无关。
magick_capable=0
if command -v magick >/dev/null && python3 svg2raster.py --check --json 2>/dev/null | grep -q '"magick"'; then
  magick_capable=1
fi

echo
echo "== 降级链的真行为：遮掉 rsvg-convert 之后该退到谁 =="

if command -v magick >/dev/null; then
  out=$(run_masked magick "$TMP/b.png" "$CHROME_APP")
  rc=$?
  if [[ "${magick_capable}" == "1" ]]; then
    if [[ $rc -eq 0 ]] && grep -q '"backend": "magick"' <<<"$out" && [[ "$(png_w "$TMP/b.png")" == "800" ]]; then
      ok "本机 magick 探测到 RSVG delegate，遮掉 rsvg-convert 后信任并退到它"
    else
      bad "本机 magick 应该可信却没被退到（降级链断了）" "$out"
    fi
  else
    if [[ $rc -eq 0 ]] && grep -q '"backend": "chrome"' <<<"$out" && [[ -s "$TMP/b.png" ]]; then
      ok "本机 magick 没有 RSVG delegate，遮掉 rsvg-convert 后没有静默选它，而是退到 chrome"
    else
      bad "遮掉 rsvg-convert 后没有正确避开不可信的 magick" "rc=${rc} out=${out}"
    fi
  fi
else
  skip "magick（本机没装，无法验证遮掉 rsvg-convert 后的落点）"
fi

echo
echo "== 显式 --backend magick 在不可用时硬失败并点名 =="

if [[ "${magick_capable}" == "1" ]]; then
  skip "--backend magick 硬失败（本机 magick 有 RSVG delegate，指定它应当成功）"
else
  out=$(python3 svg2raster.py --svg "$SVG" --out "$TMP/e.png" --aspect 16:9 --backend magick 2>&1)
  rc=$?
  if [[ $rc -ne 0 ]] && grep -q 'RSVG' <<<"$out" && [[ ! -e "$TMP/e.png" ]]; then
    ok "本机 magick 没有 RSVG delegate，显式指定 --backend magick 时硬失败并说明原因"
  else
    bad "--backend magick 在不可用时没有被拦住" "rc=${rc} out=${out}"
  fi
fi

echo
echo "== 假 magick：给 magick_has_rsvg() 一个独立预言 =="
# 上面两条 magick 相关断言的"真值"（magick_capable）是调 svg2raster.py --check
# --json 算出来的——也就是被测代码自己，不是独立预言。这只能验证闸门内部自洽，
# 抓不住"magick_has_rsvg() 被悄悄改坏"这类回归：如果它被简化成无条件 return
# False，本机 magick 本来就会因带引号 fixture 而在实际光栅化时独立失败，两者
# 巧合地看起来一致，上面两条断言会照样全绿。这里改用假 magick 脚本——让
# magick -list format 打印我们指定的文本，直接给闸门的判定逻辑一个独立于本机
# 真实 ImageMagick 构建的预言。

make_fake_magick() {   # $1=bin 目录 $2=magick -list format 应打印的文本
  local bin="$1" text="$2"
  mkdir -p "${bin}"
  printf '%s\n' "${text}" > "${bin}/magick.out"
  cat > "${bin}/magick" <<'EOF'
#!/bin/sh
cat "$(dirname "$0")/magick.out"
exit 0
EOF
  chmod +x "${bin}/magick"
}

run_fake_magick_check() {   # $1=magick -list format 应打印的文本
  local text="$1"
  local bin="$TMP/bin-fakemagick"
  rm -rf "${bin}"
  make_fake_magick "${bin}" "${text}"
  env -i PATH="${bin}:/usr/bin:/bin" HOME="$HOME" SVG2RASTER_CHROME="/nonexistent/chrome" \
    /usr/bin/python3 svg2raster.py --check --json 2>&1
}

FAKE_MAGICK_RSVG=$'     MSVG* SVG       rw+   ImageMagick internal SVG renderer\n      SVG* SVG       rw+   Scalable Vector Graphics (RSVG 2.40.20)\n     SVGZ* SVG       rw+   Compressed Scalable Vector Graphics (RSVG 2.40.20)'
out=$(run_fake_magick_check "${FAKE_MAGICK_RSVG}")
if grep -q '"magick"' <<<"$out"; then
  ok "假 magick 的 SVG* 行带 RSVG 证据时，backends 里有 magick"
else
  bad "有 RSVG 证据却没被收进 backends" "$out"
fi

FAKE_MAGICK_XML=$'     MSVG* SVG       rw+   ImageMagick internal SVG renderer\n      SVG* SVG       rw+   Scalable Vector Graphics (XML 2.9.13)\n     SVGZ* SVG       rw+   Compressed Scalable Vector Graphics (XML 2.9.13)'
out=$(run_fake_magick_check "${FAKE_MAGICK_XML}")
if grep -q '"magick"' <<<"$out"; then
  bad "只有 XML（本机真实输出）却被收进了 backends" "$out"
else
  ok "假 magick 的 SVG* 行只有 XML、没有 RSVG 证据时，backends 里没有 magick"
fi

FAKE_MAGICK_MSVG_ONLY=$'     MSVG* SVG       rw+   ImageMagick internal SVG renderer (RSVG bait, this line is MSVG not SVG)'
out=$(run_fake_magick_check "${FAKE_MAGICK_MSVG_ONLY}")
if grep -q '"magick"' <<<"$out"; then
  bad "只有 MSVG* 行（描述里塞了 RSVG 诱饵）却被收进了 backends——把 MSVG* 当成了 SVG*，或者对整行 grep RSVG" "$out"
else
  ok "只有 MSVG* 行、没有 SVG* 行时，即使描述里塞了 RSVG 诱饵，backends 里也没有 magick"
fi

echo
echo "== 三者全缺 =="

out=$(run_masked "" "$TMP/none.png" "/nonexistent/chrome")
rc=$?
if [[ $rc -ne 0 ]] && grep -q '自行转换' <<<"$out" && [[ ! -e "$TMP/none.png" ]] && [[ -f "$SVG" ]]; then
  ok "三个后端都没有时硬失败、明说需自行转换、SVG 原样保留"
else
  bad "缺工具时的行为不对（静默失败或删了 SVG）" "rc=${rc} out=${out}"
fi

echo
echo "== 显式 --backend =="

out=$(python3 svg2raster.py --svg "$SVG" --out "$TMP/d.png" --aspect 16:9 --backend no-such-backend 2>&1)
if [[ $? -ne 0 ]] && grep -q 'no-such-backend' <<<"$out"; then
  ok "--backend 传了不认识的名字时硬失败并点名"
else
  bad "未知 backend 未被拦住" "$out"
fi

echo
echo "通过 $PASS 项，失败 $FAIL 项"
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 4: 跑测试，确认它以正确的方式失败**

```bash
cd skills/_shared/scripts && bash test-svg2raster.sh 2>&1 | tail -6 && cd ../../..
```

预期：大量失败（`svg2raster.py` 还不存在，报 `can't open file`）。**第 1 项（字体 fallback 链）应当已经通过**——它只查 fixture。

- [ ] **Step 5: 写 svg2raster.py**

创建 `skills/_shared/scripts/svg2raster.py`：

```python
#!/usr/bin/env python3
"""把 SVG 光栅化成 PNG。降级链：rsvg-convert → magick → headless Chrome。

**只用标准库。** 不 import yaml、不 import asset_lib——降级链测试要在 PATH 遮蔽
沙箱里用 /usr/bin/python3（3.9.6，没装 PyYAML）跑它，任何第三方 import 都会让
那组测试无法进行，进而只能往生产代码里塞"假装某后端不存在"的测试后门。

画幅由本脚本强制（三期 D13）：diagram 不走 compose_prompt，平台画幅没有别的
机械校验点。viewBox 比例与 --aspect 不符时直接失败，否则位图会被拉伸变形，
而这件事在缩略图上肉眼看不出来。
"""

from __future__ import annotations

import argparse
import functools
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

PNG_MAGIC = b"\x89PNG\r\n\x1a\n"
ASPECT_TOLERANCE = 0.01          # 1%
DEFAULT_WIDTH = 1600
CHROME_CANDIDATES = (
    "google-chrome",
    "chromium",
    "chromium-browser",
)
CHROME_MAC_APP = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


class RasterError(Exception):
    """光栅化失败。所有失败统一抛这个，main 里转成退出码 1。"""


def find_chrome() -> str | None:
    """SVG2RASTER_CHROME 优先——它既是给 Chrome 装在别处的用户的开关，
    也是降级链测试用来遮蔽 Chrome 的手段（PATH 遮蔽管不到绝对路径的 .app）。"""
    override = os.environ.get("SVG2RASTER_CHROME")
    if override is not None:
        return override if os.access(override, os.X_OK) else None
    for name in CHROME_CANDIDATES:
        found = shutil.which(name)
        if found:
            return found
    return CHROME_MAC_APP if os.access(CHROME_MAC_APP, os.X_OK) else None


@functools.lru_cache(maxsize=None)
def magick_has_rsvg() -> bool:
    """ImageMagick 的 SVG coder 探测——正向要证据，找不到证据一律判"不可用"。

    没有编译进 RSVG delegate 的 magick 会退到它自己那套很弱的内置 MSVG
    渲染器：带 CJK 文字的 SVG 能被它"跑通"（exit 0、产出合法 PNG），但
    图上所有文字会被静默丢光——这是本机实测出来的真实故障模式，比直接
    报错凶险得多，因为退出码看不出任何异常，要等发布出去才会被发现。

    判据：`magick -list format` 的输出里，第一列恰好是 SVG/SVG*（不是
    MSVG*，也不是 SVGZ*）的那一行，描述里必须出现 RSVG 字样。magick 不
    存在、命令失败、或输出格式认不出来，一律当作"不可用"处理——宁可漏用
    一个其实可用的 magick（顶多降级到 chrome，无害），也不能误用一个会
    丢字的 magick。

    用 lru_cache 缓存：一次进程里只 fork 一次 magick 探测子进程，不会
    每次挑后端就重新问一遍。
    """
    exe = shutil.which("magick")
    if not exe:
        return False
    try:
        proc = subprocess.run([exe, "-list", "format"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except OSError:
        return False
    if proc.returncode != 0:
        return False
    for line in proc.stdout.decode("utf-8", errors="replace").splitlines():
        m = re.match(r"^\s*SVG\*?\s+\S+\s+\S+\s+(.*)$", line)
        if m and "RSVG" in m.group(1).upper():
            return True
    return False


def available_backends() -> list[str]:
    """顺序即优先级。rsvg-convert 质量最好且最快，Chrome 最重，排最后。

    magick 只有在探测到真的 RSVG delegate 时才计入——见 magick_has_rsvg()。"""
    found = []
    if shutil.which("rsvg-convert"):
        found.append("rsvg-convert")
    if shutil.which("magick") and magick_has_rsvg():
        found.append("magick")
    if find_chrome():
        found.append("chrome")
    return found


def parse_aspect(text: str) -> float:
    m = re.fullmatch(r"\s*(\d+(?:\.\d+)?)\s*:\s*(\d+(?:\.\d+)?)\s*", text)
    if not m:
        raise RasterError(f"--aspect 要写成 W:H（如 16:9），实为 {text!r}")
    w, h = float(m.group(1)), float(m.group(2))
    if w <= 0 or h <= 0:
        raise RasterError(f"--aspect 的两个数都必须为正，实为 {text!r}")
    return w / h


def svg_ratio(svg: Path) -> float:
    """从 viewBox 取比例；没有 viewBox 就退到 width/height 属性。

    用正则而不是 XML 解析器：SVG 可能带 DOCTYPE、注释、命名空间前缀，
    而我们只需要根元素上的两个属性，正则更不容易被这些噎住。
    """
    head = svg.read_text(encoding="utf-8", errors="replace")[:4000]
    m = re.search(r'viewBox\s*=\s*["\']\s*[-\d.]+\s+[-\d.]+\s+([\d.]+)\s+([\d.]+)', head)
    if m:
        w, h = float(m.group(1)), float(m.group(2))
    else:
        mw = re.search(r'\bwidth\s*=\s*["\']([\d.]+)', head)
        mh = re.search(r'\bheight\s*=\s*["\']([\d.]+)', head)
        if not (mw and mh):
            raise RasterError(
                f"{svg} 既没有 viewBox 也没有数值型 width/height，无法校验画幅。"
                "给根元素加上 viewBox（如 viewBox=\"0 0 1600 900\"）"
            )
        w, h = float(mw.group(1)), float(mh.group(1))
    if w <= 0 or h <= 0:
        raise RasterError(f"{svg} 的画布尺寸非法: {w}x{h}")
    return w / h


def check_aspect(svg: Path, aspect: str) -> None:
    want = parse_aspect(aspect)
    got = svg_ratio(svg)
    if abs(got - want) / want > ASPECT_TOLERANCE:
        raise RasterError(
            f"SVG 的 viewBox 比例是 {got:.3f}，平台要求 {aspect}（{want:.3f}），"
            f"相差超过 {ASPECT_TOLERANCE:.0%}。改 SVG 的 viewBox，别改 --aspect——"
            "画幅是平台硬约束，硬转会把图拉伸变形"
        )


def _run(cmd: list[str]) -> bool:
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except OSError:
        return False
    return proc.returncode == 0


def rsvg_step(svg: Path, out: Path, w: int, h: int) -> bool:
    return _run(["rsvg-convert", "-w", str(w), "-h", str(h), "-o", str(out), str(svg)])


def magick_step(svg: Path, out: Path, w: int, h: int) -> bool:
    return _run(["magick", "-background", "none", str(svg),
                 "-resize", f"{w}x{h}", str(out)])


def chrome_step(svg: Path, out: Path, w: int, h: int) -> bool:
    exe = find_chrome()
    if not exe:
        return False
    return _run([exe, "--headless", "--disable-gpu", "--hide-scrollbars",
                 f"--screenshot={out}", f"--window-size={w},{h}",
                 "--default-background-color=00000000", svg.resolve().as_uri()])


BACKENDS = {
    "rsvg-convert": rsvg_step,
    "magick": magick_step,
    "chrome": chrome_step,
}


def png_size(path: Path) -> tuple[int, int]:
    data = path.read_bytes()[:24]
    if data[:8] != PNG_MAGIC:
        raise RasterError(f"{path} 不是 PNG（后端产出了别的格式）")
    return int.from_bytes(data[16:20], "big"), int.from_bytes(data[20:24], "big")


def rasterize(svg: Path, out: Path, aspect: str, width: int, backend: str | None) -> dict:
    if not svg.exists():
        raise RasterError(f"SVG 不存在: {svg}")
    check_aspect(svg, aspect)
    height = round(width / parse_aspect(aspect))

    if backend is not None:
        if backend not in BACKENDS:
            raise RasterError(f"未知 backend: {backend}；可选 {sorted(BACKENDS)}")
        if backend == "magick" and not magick_has_rsvg():
            raise RasterError(
                "本机的 magick 没有 RSVG delegate（magick -list format 里 SVG 一行"
                "显示的是内置渲染器），它能跑通但会丢掉图上所有文字。"
                "装 librsvg（brew install librsvg）后 magick 才能用，"
                "或者直接用 rsvg-convert / chrome。"
            )
        order = [backend]
    else:
        order = [b for b in ("rsvg-convert", "magick", "chrome") if b in available_backends()]

    if not order:
        raise RasterError(
            f"找不到任何可用的光栅化后端（rsvg-convert / magick / chrome）。\n"
            f"SVG 已保留在 {svg}，需自行转换成 PNG 后再继续。\n"
            "装其中一个即可：brew install librsvg 或 brew install imagemagick"
        )

    out.parent.mkdir(parents=True, exist_ok=True)
    tried = []
    for name in order:
        if BACKENDS[name](svg, out, width, height) and out.exists() and out.stat().st_size > 0:
            got_w, got_h = png_size(out)
            return {
                "backend": name,
                "out": str(out),
                "width": got_w,
                "height": got_h,
                "bytes": out.stat().st_size,
            }
        tried.append(name)
        # 失败的那一级可能留下半个文件，清掉再试下一级。
        # 只删本函数自己刚写的这个路径，不碰目录里的任何既有文件（二期 A 教训 6）。
        if out.exists():
            out.unlink()
    raise RasterError(f"所有后端都失败了（试过 {tried}）。SVG 已保留在 {svg}")


def main() -> int:
    ap = argparse.ArgumentParser(description="SVG → PNG，降级链 rsvg-convert → magick → chrome")
    ap.add_argument("--check", action="store_true", help="只报告可用后端，不转换")
    ap.add_argument("--svg")
    ap.add_argument("--out")
    ap.add_argument("--aspect", help="平台画幅，如 16:9。取自 platform profile 的 diagram 槽")
    ap.add_argument("--width", type=int, default=DEFAULT_WIDTH)
    ap.add_argument("--backend", default=None, help="跳过降级链，指定用哪个后端")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    if args.check:
        info = {"backends": available_backends(), "chrome": find_chrome()}
        if args.json:
            print(json.dumps(info, ensure_ascii=False))
        elif info["backends"]:
            print("可用后端（按优先级）: " + ", ".join(info["backends"]))
        else:
            print("没有可用的光栅化后端。装一个：brew install librsvg（推荐）"
                  "或 brew install imagemagick；也可以装 Google Chrome。")
        return 0

    missing = [f"--{n}" for n in ("svg", "out", "aspect") if not getattr(args, n)]
    if missing:
        print(f"缺参数: {missing}（或改用 --check）", file=sys.stderr)
        return 1

    try:
        info = rasterize(Path(args.svg), Path(args.out), args.aspect, args.width, args.backend)
    except RasterError as e:
        print(str(e), file=sys.stderr)
        return 1
    print(json.dumps(info, ensure_ascii=False) if args.json else info["out"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 6: 跑测试，确认全绿**

```bash
cd skills/_shared/scripts && bash test-svg2raster.sh 2>&1 | tail -20 && cd ../../..
```

预期：「通过 11 项，失败 0 项」（本机三个后端齐全时是 11 项；缺后端的机器上会少几项并打印 ⊘）。

- [ ] **Step 7: 眼看一次产物，别只信断言**

```bash
python3 skills/_shared/scripts/svg2raster.py \
  --svg skills/_shared/scripts/fixtures/diagram-sample.svg \
  --out /tmp/diagram-check.png --aspect 16:9 --json
open /tmp/diagram-check.png     # 三个方框、三个中文标签、两条连线，文字不该是豆腐块
```

- [ ] **Step 8: Commit**

```bash
cat > /tmp/t2.txt <<'EOF'
feat(shared): add svg2raster.py with a three-rung fallback chain

rsvg-convert -> magick -> headless Chrome, per spec 14.3. When all three
are missing it exits non-zero, says the SVG has been kept and needs
manual conversion, and never leaves a half-written PNG behind.

Two decisions worth recording:

- stdlib only, no yaml/asset_lib import. The fallback chain can only be
  tested by masking PATH, and the masked interpreter is /usr/bin/python3
  (3.9.6, no PyYAML). Keeping the module dependency-free is what makes
  the test possible without a "pretend this backend is missing" hook in
  production code.
- --aspect is enforced against the SVG viewBox within 1%. diagram never
  goes through compose_prompt, so this is the only mechanical check that
  the platform frame was actually honoured; without it a square drawing
  claimed as 16:9 gets stretched and nobody notices at thumbnail size.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
git add skills/_shared/scripts/svg2raster.py \
        skills/_shared/scripts/fixtures/diagram-sample.svg \
        skills/_shared/scripts/test-svg2raster.sh
git commit -F /tmp/t2.txt -- skills/_shared/scripts/svg2raster.py \
        skills/_shared/scripts/fixtures/diagram-sample.svg \
        skills/_shared/scripts/test-svg2raster.sh
```

---

### Task 3: writeback.py 与它的测试

**Files:**
- Create: `skills/_shared/scripts/writeback.py`
- Create: `skills/_shared/scripts/test-writeback.sh`

**Interfaces:**
- Consumes: `artifacts.guard(path, force)`（T1 未改动它，直接 import）
- Produces:
  - `python3 writeback.py --source A.md --insertions ins.json --assets-dir DIR --out B.md [--force] [--dry-run]`
  - insertions JSON 是一个数组，每项四个键、一个都不能多不能少：`anchor`（原文中的**一整行**，前后空白忽略）、`position`（`after` | `before`）、`image`（**文件名**，不是路径）、`alt`。
  - 永远把 unified diff 打到 stdout；`--dry-run` 时只打印不写文件（回写门的预览就用它）。
  - **源文件只读**，永不修改。
  - T5（visuals SKILL.md）依赖这条命令行契约。

- [ ] **Step 1: 确认起点**

```bash
git status
ls skills/_shared/scripts/writeback.py 2>/dev/null && echo "已存在，停下来查" || echo "ok: 尚未创建"
```

- [ ] **Step 2: 写会失败的测试**

创建 `skills/_shared/scripts/test-writeback.sh`：

```bash
#!/usr/bin/env bash
# writeback.py 测试。对应 spec §9（改源文件的门）与三期 D16。
set -uo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM

PASS=0
FAIL=0
ok()  { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad() { echo "  ❌ $1"; echo "     $2"; FAIL=$((FAIL+1)); }

ART="$TMP/article-dir"
mkdir -p "$ART/assets/wechat"
SRC="$ART/article.wechat.md"
OUT="$ART/article.illustrated.md"
ASSETS="$ART/assets/wechat"

cat > "$SRC" <<'EOF'
# 缓存失效

开篇一段。

## 三种写法

正文一段。

## 取舍

结尾一段。

## 三种写法

这一行是故意重复的小标题，用来验证多重命中会被拦住。
EOF

printf 'fake' > "$ASSETS/01-illustration.jpg"
SRC_BEFORE=$(cksum < "$SRC")

ins() { printf '%s' "$1" > "$TMP/ins.json"; }
runwb() { python3 writeback.py --source "$SRC" --insertions "$TMP/ins.json" \
            --assets-dir "$ASSETS" --out "$OUT" "$@" 2>&1; }

echo "== 正常插入 =="

ins '[{"anchor": "## 取舍", "position": "after", "image": "01-illustration.jpg", "alt": "三种写法对比"}]'
out=$(runwb)
rc=$?
if [[ $rc -eq 0 && -f "$OUT" ]] && grep -q '!\[三种写法对比\](assets/wechat/01-illustration.jpg)' "$OUT"; then
  ok "插入了正确的 Markdown 图片引用，路径相对文章目录"
else
  bad "回写产物不对" "rc=${rc} out=${out}"
fi

anchor_line=$(grep -n '^## 取舍' "$OUT" | head -1 | cut -d: -f1)
img_line=$(grep -n '!\[三种写法对比\]' "$OUT" | head -1 | cut -d: -f1)
if [[ -n "${anchor_line}" && -n "${img_line}" && ${img_line} -gt ${anchor_line} ]]; then
  ok "position=after 时图片在锚点行之后"
else
  bad "插入位置不对" "anchor=${anchor_line} img=${img_line}"
fi

if [[ "$(cksum < "$SRC")" == "$SRC_BEFORE" ]]; then
  ok "源文件一字节未动（spec §9：原文不动，另存）"
else
  bad "改了源文件" "before=${SRC_BEFORE} after=$(cksum < "$SRC")"
fi

echo
echo "== 重跑保护 =="

out=$(runwb)
if [[ $? -ne 0 ]] && grep -q 'article.illustrated.md' <<<"$out"; then
  ok "--out 已存在时拦住并报出路径"
else
  bad "已存在却直接覆盖" "$out"
fi

out=$(runwb --force)
[[ $? -eq 0 ]] && ok "--force 时放行" || bad "--force 未生效" "$out"

echo
echo "== 锚点 =="

rm -f "$OUT"
ins '[{"anchor": "## 不存在的小标题", "position": "after", "image": "01-illustration.jpg", "alt": "x"}]'
out=$(runwb)
if [[ $? -ne 0 ]] && grep -q '不存在的小标题' <<<"$out" && grep -q '0' <<<"$out"; then
  ok "锚点 0 次命中时硬失败并把锚点原文打出来"
else
  bad "找不到锚点却继续了" "$out"
fi

ins '[{"anchor": "## 三种写法", "position": "after", "image": "01-illustration.jpg", "alt": "x"}]'
out=$(runwb)
if [[ $? -ne 0 ]] && grep -q '2' <<<"$out"; then
  ok "锚点 2 次命中时硬失败（插错位置比不插更难发现）"
else
  bad "多重命中却挑了一个插" "$out"
fi

echo
echo "== 图片引用 =="

ins '[{"anchor": "## 取舍", "position": "after", "image": "99-missing.jpg", "alt": "x"}]'
out=$(runwb)
if [[ $? -ne 0 ]] && grep -q '99-missing.jpg' <<<"$out"; then
  ok "引用的图不在 assets-dir 时硬失败并点名（正文会引到不存在的文件）"
else
  bad "引用了不存在的图" "$out"
fi

ins '[{"anchor": "## 取舍", "position": "after", "image": "assets/wechat/01-illustration.jpg", "alt": "x"}]'
out=$(runwb)
if [[ $? -ne 0 ]] && grep -q '文件名' <<<"$out"; then
  ok "image 写成路径时硬失败（路径由 --assets-dir 决定，写两遍必然打架）"
else
  bad "接受了路径形式的 image" "$out"
fi

echo
echo "== schema =="

ins '[{"anchor": "## 取舍", "position": "after", "image": "01-illustration.jpg", "alt": "x", "postion": "before"}]'
out=$(runwb)
if [[ $? -ne 0 ]] && grep -q 'postion' <<<"$out"; then
  ok "未知字段硬失败并点名（拼错的键静默丢失最难查）"
else
  bad "未知字段被静默忽略" "$out"
fi

echo
echo "== --dry-run（回写门的预览） =="

rm -f "$OUT"
ins '[{"anchor": "## 取舍", "position": "before", "image": "01-illustration.jpg", "alt": "对比图"}]'
out=$(runwb --dry-run)
if [[ $? -eq 0 ]] && [[ ! -e "$OUT" ]] && grep -q '^+.*01-illustration.jpg' <<<"$out"; then
  ok "--dry-run 打印 diff 但不写文件"
else
  bad "--dry-run 写了文件或没打 diff" "$out"
fi

out=$(runwb)
img_line=$(grep -n '!\[对比图\]' "$OUT" | head -1 | cut -d: -f1)
anchor_line=$(grep -n '^## 取舍' "$OUT" | head -1 | cut -d: -f1)
if [[ -n "${img_line}" && -n "${anchor_line}" && ${img_line} -lt ${anchor_line} ]]; then
  ok "position=before 时图片在锚点行之前"
else
  bad "before 位置不对" "anchor=${anchor_line} img=${img_line}"
fi

echo
echo "通过 $PASS 项，失败 $FAIL 项"
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 3: 跑测试，确认它以正确的方式失败**

```bash
cd skills/_shared/scripts && bash test-writeback.sh 2>&1 | tail -6 && cd ../../..
```

预期：12 项全部失败（`writeback.py` 不存在）。

- [ ] **Step 4: 写 writeback.py**

创建 `skills/_shared/scripts/writeback.py`：

```python
#!/usr/bin/env python3
"""把生成好的图片引用回写进 Markdown，另存为新文件。

**原文永不修改**（spec §9，与 wechat-finetune「原文不动、另存」一致）：本脚本
只读 --source，产物写到 --out。

**为什么是脚本而不是让 agent 手抄正文**：回写门要给用户看 diff，diff 必须是
确定性的；而让模型重打一遍整篇正文，漏字改字既无法断言也无法回滚。语义判断
（插哪、alt 写什么）仍然全在 agent 手里，它们由 --insertions 传进来。

**insertions 里的 image 必须抄自 sidecar 的 `image` 字段。** 压缩是新增不是
替换：超限时 NN-x.png 与 NN-x.jpg 并存，硬编 .png 会让正文引用到一个超限的
文件——这正是二期 A 把压缩塞进流程要消灭的失败模式，换个位置又活了。
"""

from __future__ import annotations

import argparse
import difflib
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import artifacts  # noqa: E402
import asset_lib as a  # noqa: E402

REQUIRED_KEYS = {"anchor", "position", "image", "alt"}
POSITIONS = ("after", "before")


def load_insertions(path: Path) -> list[dict]:
    if not path.exists():
        raise a.AssetError(f"insertions 文件不存在: {path}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        raise a.AssetError(f"insertions 不是合法 JSON: {e}")
    if not isinstance(data, list) or not data:
        raise a.AssetError("insertions 必须是非空数组")
    for i, item in enumerate(data):
        if not isinstance(item, dict):
            raise a.AssetError(f"insertions[{i}] 不是对象")
        keys = set(item)
        unknown = sorted(keys - REQUIRED_KEYS)
        if unknown:
            raise a.AssetError(
                f"insertions[{i}] 有未知字段 {unknown}；只接受 {sorted(REQUIRED_KEYS)}。"
                "拼错的键如果被静默忽略，图就会插到默认位置而没人发现"
            )
        missing = sorted(REQUIRED_KEYS - keys)
        if missing:
            raise a.AssetError(f"insertions[{i}] 缺字段 {missing}")
        if item["position"] not in POSITIONS:
            raise a.AssetError(
                f"insertions[{i}].position 必须是 {POSITIONS} 之一，实为 {item['position']!r}"
            )
        if os.sep in item["image"] or "/" in item["image"]:
            raise a.AssetError(
                f"insertions[{i}].image 只写文件名，实为 {item['image']!r}。"
                "目录由 --assets-dir 决定；两处各写一遍必然打架"
            )
    return data


def locate(lines: list[str], anchor: str, index: int) -> int:
    """锚点按整行匹配（忽略前后空白）。

    不用子串匹配：Markdown 里 "## 取舍" 这样的短串很容易在正文段落里再次出现，
    而插错位置比没插更难发现——产物看起来是成功的。
    """
    want = anchor.strip()
    hits = [i for i, line in enumerate(lines) if line.strip() == want]
    if len(hits) != 1:
        raise a.AssetError(
            f"insertions[{index}] 的锚点在原文里命中 {len(hits)} 次，必须恰好 1 次：\n"
            f"  {anchor!r}\n"
            "锚点要写成原文里的一整行（前后空白会被忽略）。命中 0 次多半是抄错了，"
            "命中多次要换一个更长、更独特的行"
        )
    return hits[0]


def build(source: Path, insertions: list[dict], assets_dir: Path, out: Path) -> list[str]:
    lines = source.read_text(encoding="utf-8").splitlines()
    rel = os.path.relpath(assets_dir.resolve(), out.resolve().parent)
    plan = []
    for i, item in enumerate(insertions):
        image_path = assets_dir / item["image"]
        if not image_path.exists():
            raise a.AssetError(
                f"insertions[{i}] 引用的图不存在: {image_path}\n"
                "image 要抄 sidecar 里的 image 字段——压缩过的图是 .jpg 不是 .png"
            )
        plan.append((locate(lines, item["anchor"], i), item))

    # 从后往前插，前面的行号才不会被前一次插入顶偏
    result = list(lines)
    for at, item in sorted(plan, key=lambda p: p[0], reverse=True):
        ref = f"![{item['alt']}]({rel}/{item['image']})".replace(os.sep, "/")
        block = ["", ref, ""]
        pos = at + 1 if item["position"] == "after" else at
        result[pos:pos] = block
    return result


def main() -> int:
    ap = argparse.ArgumentParser(description="把图片引用回写进 Markdown，另存为新文件")
    ap.add_argument("--source", required=True, help="原文，只读，永不修改")
    ap.add_argument("--insertions", required=True, help="agent 写的插入计划 JSON")
    ap.add_argument("--assets-dir", required=True, help="图片所在目录")
    ap.add_argument("--out", required=True, help="回写产物，默认 article.illustrated.md")
    ap.add_argument("--force", action="store_true", help="覆盖已存在的 --out")
    ap.add_argument("--dry-run", action="store_true", help="只打印 diff，不写文件")
    args = ap.parse_args()

    source, out = Path(args.source), Path(args.out)
    try:
        if not source.exists():
            raise a.AssetError(f"源文件不存在: {source}")
        if not args.dry_run:
            artifacts.guard(out, args.force)
        insertions = load_insertions(Path(args.insertions))
        new_lines = build(source, insertions, Path(args.assets_dir), out)
    except a.AssetError as e:
        print(str(e), file=sys.stderr)
        return 1

    old_lines = source.read_text(encoding="utf-8").splitlines()
    diff = difflib.unified_diff(old_lines, new_lines,
                                fromfile=str(source), tofile=str(out), lineterm="")
    print("\n".join(diff))

    if args.dry_run:
        print(f"\n（--dry-run：未写入 {out}）")
        return 0
    out.write_text("\n".join(new_lines) + "\n", encoding="utf-8")
    print(f"\n已写入 {out}（源文件 {source} 未改动）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 5: 跑测试，确认全绿**

```bash
cd skills/_shared/scripts && bash test-writeback.sh 2>&1 | tail -20 && cd ../../..
```

预期：「通过 12 项，失败 0 项」。

- [ ] **Step 6: Commit**

```bash
cat > /tmp/t3.txt <<'EOF'
feat(shared): add writeback.py for the Markdown insertion gate

The semantic half stays with the agent (where to insert, what the alt
text says) and arrives as an insertions JSON; the script does the
deterministic half: locate anchors, insert references, write a new file,
print a unified diff. The source is opened read-only and never written,
matching wechat-finetune's "leave the original alone, save a copy".

Anchors match a whole line, not a substring: a short heading like
"## 取舍" reappears inside prose easily, and an image inserted at the
wrong place looks like success. Zero or multiple hits hard-fail with the
anchor printed back.

insertions[].image is a bare filename that must exist under --assets-dir,
and the docstring points at the sidecar image field as its source --
hardcoding .png would reintroduce the oversized-asset failure mode that
compression was added to kill.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
git add skills/_shared/scripts/writeback.py skills/_shared/scripts/test-writeback.sh
git commit -F /tmp/t3.txt -- skills/_shared/scripts/writeback.py \
        skills/_shared/scripts/test-writeback.sh
```

---

### Task 4: md2publish-diagram skill

**Files:**
- Create: `skills/md2publish-diagram/SKILL.md`

**Interfaces:**
- Consumes: T1 的 `artifacts.py sidecar --archetype diagram`；T2 的 `svg2raster.py`
- Produces: 一个可被 agent 调用的 skill。产物布局 `diagrams/<platform>/NN-diagram.svg` + `assets/<platform>/NN-diagram.png` + `.json`。T8 的流程图与 T9 的 spec 修订引用它。

- [ ] **Step 1: 读模板**

```bash
sed -n '1,60p' skills/md2publish-cover/SKILL.md      # frontmatter、工作目录约定、职责边界的写法
```

**照抄它的结构，但不要照抄「═══ 以下开始计费 ═══」那条线**——diagram 零成本，整条链路没有计费段。

- [ ] **Step 2: 写 SKILL.md**

创建 `skills/md2publish-diagram/SKILL.md`。必须包含下面这些**内容要点**（措辞可打磨，要点一个不能少）：

1. **frontmatter**：

```yaml
---
name: md2publish-diagram
description: 画架构图 / 流程图 / 时序图 / 示意图，产出 SVG 与 PNG 双产物。当用户说"画个架构图"、"流程图"、"时序图"、"示意图"时使用。**不调 AI、不花钱**：图由你直接写成 SVG，再本地光栅化成 PNG（微信不接受 SVG）。
allowed-tools: Read, Write, Bash, AskUserQuestion
---
```

2. **工作目录与路径约定**：照抄 cover 的那一节（脚本路径相对 skill 目录、产物路径用文章目录的绝对路径、`cd` 到 skill 目录、`ART=` 文章目录绝对路径）。`mkdir -p "$ART/diagrams" "$ART/assets"`。

3. **职责边界表**：封面 → `md2publish-cover`；正文配图 / 信息图 / 卡片系列 → `md2publish-visuals`；传微信素材库 → `md2publish-draft`；架构图 / 流程图 → 本 skill。

4. **本 skill 与另两个的结构差异**（单独一节，这是最容易被照抄错的地方）：

> 本 skill **不调 AI、不读 preset、不渲染 prompt、没有成本门**。另两个 skill 的步骤 4「渲染 prompt」在这里不存在——图是你直接写出来的 SVG，SVG 源文件本身就是复现记录（改它重跑，结果是确定的，比改 prompt 重生成强）。因此**不要**去调 `compose_prompt.py`，也**不要**建 `prompts/` 目录。

5. **步骤 1：查后端（零成本）**

```bash
python3 shared/scripts/svg2raster.py --check
```

一个后端都没有时**如实告诉用户**：可以照常写 SVG 并交付 `.svg` 文件，但转不出 PNG，微信发不了；装 `brew install librsvg` 之后回来跑步骤 4 即可。**不要**因此中止整个流程。

6. **步骤 2：定平台，取画幅与体积上限**

```bash
PLATFORM=wechat      # 或 xiaohongshu
ASPECT=$(python3 -c "import sys; sys.path.insert(0,'shared/scripts'); import asset_lib as a; s=a.archetype_slot(a.load_platform('${PLATFORM}'),'diagram'); print(s['aspect'][0] if isinstance(s['aspect'],list) else s['aspect'])")
MAXB=$(python3 -c "import sys; sys.path.insert(0,'shared/scripts'); import asset_lib as a; print(a.archetype_slot(a.load_platform('${PLATFORM}'),'diagram')['max_bytes'])")
```

微信 diagram 的 `aspect` 是列表 `["16:9", "4:3"]`，上面取第一个；用户要竖图时手动改成 `4:3`。小红书是 `"3:4"`。

7. **步骤 3：写 SVG（语义层，你的活）**——这一节是本 skill 的核心，要写死三条硬约束：

- **`viewBox` 必须与平台画幅一致**（16:9 → `viewBox="0 0 1600 900"`）。步骤 4 会机械校验，差 1% 以上直接失败——**改 SVG，不要改 `--aspect` 绕过去**，画幅是平台硬约束。
- **字体必须写完整的 fallback 链**，一个都不能少：`"PingFang SC", "Noto Sans CJK SC", "Microsoft YaHei", sans-serif`。只写"系统字体"不够——macOS 与 Linux 的 CJK 默认字体不同，同一份 SVG 会渲染出不同的图。
- **不要在 SVG 里引用外部资源**（外链字体、外链图片）：光栅化在离线环境里跑，引用不到就是空白，而空白在缩略图上看不出来。

样例可参考 `shared/scripts/fixtures/diagram-sample.svg`（它同时是测试 fixture，别改它）。

8. **步骤 4：光栅化**

```bash
SVG="$ART/diagrams/${PLATFORM}/00-diagram.svg"
PNG="$ART/assets/${PLATFORM}/00-diagram.png"
mkdir -p "$(dirname "${SVG}")" "$(dirname "${PNG}")"
python3 shared/scripts/artifacts.py guard --path "${PNG}"        # 已存在就停，别静默覆盖
RASTER=$(python3 shared/scripts/svg2raster.py --svg "${SVG}" --out "${PNG}" --aspect "${ASPECT}" --json)
BACKEND=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['backend'])" "${RASTER}")
```

`${BACKEND}` 是**实际用的光栅化后端**，步骤 6 要如实填进 sidecar。**不要**凭印象写 `rsvg-convert`——降级链可能已经退到 magick 或 chrome，填错了 sidecar 就成了一份误导性的追溯记录。

9. **步骤 5：压缩（多半用不上）**

```bash
FINAL="${PNG}"
if [[ $(wc -c < "${PNG}") -gt ${MAXB} ]]; then
  FINAL=$(python3 shared/scripts/compress.py --image "${PNG}" --max-bytes "${MAXB}")
fi
```

diagram 的上限是 10MB（微信）/ 20MB（小红书），光栅化出来的图通常远低于它，**这一步大概率不动**。真超限时压缩产出的是 JPEG，示意图的文字会变糊——这时更该做的是**降低 `--width` 重新光栅化**，而不是压缩。把这个选择说给用户。

10. **步骤 6：写 sidecar**

```bash
python3 shared/scripts/artifacts.py sidecar \
  --image "${FINAL}" \
  --platform "${PLATFORM}" --archetype diagram \
  --provider "${BACKEND}" \
  --source-file "$(basename "${SVG}")" \
  --alt-text "<一句话描述这张图>"
```

**不要传 `--preset` / `--model` / `--prompt-file` / `--brief-file`**——diagram 支路会硬失败并点名。那不是 bug，是防止照抄 cover 的命令写出一份声称走过 preset 链路、实际没有的 sidecar。

11. **步骤 7：交接**——两种去向说清楚：

- **要插进正文**：把 `${FINAL}` 的**文件名**（sidecar 的 `image` 字段）交给 `md2publish-visuals` 的回写门，或用户自己插。**必须在 `md2publish-article` 转 HTML 之前插进 Markdown**，否则示意图不会出现在正文里（spec §8）。
- **只是单独导出一张图**：直接把 `${FINAL}` 给用户，与流水线无耦合。
- 两种情况都要告诉用户：`.svg` 源文件留在 `$ART/diagrams/` 下，**要改图就改它再重跑步骤 4**，不要去 P 图。

12. **产物布局**与**前置**两节，照 cover 的写法：

```
$ART/
├─ diagrams/<platform>/00-diagram.svg   ← 你写的 SVG，复现记录，别删
└─ assets/<platform>/
   ├─ 00-diagram.png                    ← 光栅化产物
   └─ 00-diagram.json                   ← sidecar；image 字段是下游该消费的文件名
```

前置：`python3 -c 'import yaml'`；`rsvg-convert` / `magick` / Chrome **三者有其一**（都没有也能产出 SVG，只是转不了 PNG）。**不需要 bun**——diagram 不碰 imagegen。

- [ ] **Step 3: 自查三件事**

```bash
grep -c '计费' skills/md2publish-diagram/SKILL.md          # 期望 0：diagram 没有计费段
grep -c 'compose_prompt' skills/md2publish-diagram/SKILL.md # 期望 0：不走 prompt 链路
grep -n 'PingFang SC' skills/md2publish-diagram/SKILL.md    # 期望至少 1：字体链写进去了
```

- [ ] **Step 4: 照着 SKILL.md 手跑一遍**（这是本任务的真正验收，别跳过）

用 fixture 当 SVG，跑完整的步骤 4→6，确认每条命令都能照抄执行：

```bash
T=$(mktemp -d); mkdir -p "$T/diagrams/wechat" "$T/assets/wechat"
\cp -f skills/_shared/scripts/fixtures/diagram-sample.svg "$T/diagrams/wechat/00-diagram.svg"
# 注意：此时 shared/ 尚未 vendor（T6 才做），所以这里用 _shared 版本验证命令语义。
# SKILL.md 里写的 shared/scripts/... 路径要等 T6 之后才跑得通，那是 T6 Step 6 验的事。
python3 skills/_shared/scripts/svg2raster.py --svg "$T/diagrams/wechat/00-diagram.svg" \
  --out "$T/assets/wechat/00-diagram.png" --aspect 16:9 --json
python3 skills/_shared/scripts/artifacts.py sidecar \
  --image "$T/assets/wechat/00-diagram.png" --platform wechat --archetype diagram \
  --provider rsvg-convert --source-file 00-diagram.svg --alt-text "三层缓存架构示意图"
cat "$T/assets/wechat/00-diagram.json"; rm -rf "$T"
```

预期：PNG 生成、sidecar 里 `preset` 与 `model` 是 `null`、`source_file` 是 `00-diagram.svg`。

- [ ] **Step 5: Commit**

```bash
cat > /tmp/t4.txt <<'EOF'
feat(diagram): add the md2publish-diagram skill

Deterministic, zero-cost pipeline: the agent writes the SVG by hand, the
mechanical layer only rasterizes it. Deliberately shaped unlike cover and
visuals -- there is no billing section, no preset lookup and no prompts/
directory, because none of those have a consumer here. The SVG source is
the reproduction record.

Three hard constraints live in step 3 because they are the ones that fail
silently: viewBox must match the platform aspect (step 4 enforces it), the
CJK font fallback chain must be complete (macOS and Linux disagree
otherwise), and no external resources may be referenced (rasterization
runs offline and a missing asset just renders blank).

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
git add skills/md2publish-diagram/SKILL.md
git commit -F /tmp/t4.txt -- skills/md2publish-diagram/SKILL.md
```

---

### Task 5: md2publish-visuals skill

**Files:**
- Create: `skills/md2publish-visuals/SKILL.md`

**Interfaces:**
- Consumes: T3 的 `writeback.py`；既有的 `preflight.py` / `compose_prompt.py` / `compress.py` / `artifacts.py` / `imagegen`
- Produces: 一个可被 agent 调用的 skill，产出 `article.illustrated.md`。T8 的 `md2publish-article` 输入表依赖这个文件名。

- [ ] **Step 1: 读模板**

```bash
sed -n '55,240p' skills/md2publish-cover/SKILL.md    # 步骤 1–8 的完整写法，本 skill 的 1–8 与它同构
```

- [ ] **Step 2: 写 SKILL.md**

创建 `skills/md2publish-visuals/SKILL.md`。要点：

1. **frontmatter**：

```yaml
---
name: md2publish-visuals
description: 为文章生成一组配图——微信正文插图、信息图、小红书图卡系列，并把图片引用回写进 Markdown（另存，原文不动）。当用户说"配图"、"插图"、"信息图"、"图文笔记"、"小红书卡片"时使用。步骤 1–4 零成本零副作用（产出 prompt 文件），步骤 5 起才调 provider、才花钱。
allowed-tools: Read, Write, Bash, AskUserQuestion
---
```

2. **工作目录与路径约定** / **职责边界表** / **机械层与语义层**：照 cover 的写法。职责边界表里，封面 → `md2publish-cover`，架构图 → `md2publish-diagram`，本 skill 管配图。

3. **触发路由表**（spec §3.2，照抄，别自己发明）：

| 平台 | 用户说"配图 / 图" | 怎么办 |
|---|---|---|
| 微信 | 正文插图（`illustration`） | 直接开工 |
| 小红书 | 卡片系列（`series`），**首图即封面** | 直接开工；**别再去调 `md2publish-cover`**，小红书的封面就是系列第一张 |
| 其他平台 | — | 本仓库只有微信与小红书两个 platform profile。用户说 B 站时**如实说没有该平台的画幅规格**，别猜 |

只有用户明确要"单张主图 / 封面"时才交给 `md2publish-cover`（小红书除外）。

4. **多平台必须拆两次执行**（spec §7.2，单独一节）：

> `--platform wechat,xiaohongshu` 对本 skill **不成立**。微信要的是 3–8 张装点长文的插图，小红书要的是整个卡片系列——**不同内容、不同张数、不同源材料**，不是同一个视觉概念换画幅。收到多平台请求时**拆成两次独立执行**：各自选 preset、各自写 brief、各自过成本门。**不允许一次确认覆盖两个平台的花费。**

5. **步骤 1 preflight** / **步骤 2 定平台**：照 cover。

6. **步骤 3：选 preset + 定张数与位置（语义层，本 skill 独有的重活）**

```bash
SLOT=$(python3 -c "import sys,json; sys.path.insert(0,'shared/scripts'); import asset_lib as a; print(json.dumps(a.archetype_slot(a.load_platform('${PLATFORM}'),'${ARCHETYPE}'),ensure_ascii=False))")
```

`count_range` 是硬约束：微信 `illustration` 是 `[3, 8]`，小红书 `series` 是 `[1, 18]`。**张数必须落在区间内**，并且要通读全文之后再定——这是 cover 没有的一步（spec §3：封面只需要标题和摘要，序列必须通读全文才能定位置、定数量）。

同时定下每张图的**锚点**：它必须是原文里的**一整行**（通常是小标题），后面回写要用，命中必须唯一。

7. **步骤 4：逐张写 brief 并渲染 prompt**（零成本）——与 cover 同构，只是循环 N 次，`NN` 从 `00` 起，`<role>` 取 `illustration` / `infographic` / `series`。

8. **═══ 以下开始计费 ═══** + **步骤 5：凭证门 + 成本门**——与 cover 的**关键差异**要写死：

> **批量必须问。** cover 是单张所以不问，本 skill 一律要报「将生成 N 张 / 预估 ¥X / provider / model」并等用户确认（spec §9）。取不到价目时明说"该 provider 无价目表"，**不要编一个数字**。
> 另外 `max_images_per_run`（配置文件，默认 10）是**硬上限**：超过直接拒绝，不是提示。

```bash
python3 -c "import sys; sys.path.insert(0,'shared/scripts'); import config, asset_lib as a; c=config.load_config(); print(c['max_images_per_run'], a.estimate_cost('<provider>','<model>'))"
```

9. **步骤 6：批量生成** —— `imagegen/main.ts --batchfile batch.json --jobs <max_concurrency>`。**部分失败不整体回滚**（spec §10）：10 张成 7 张就保留 7 张，报告失败的 3 张，允许只重跑失败的那几张。

10. **步骤 7：逐张压缩** / **步骤 8：逐张 sidecar**：与 cover 同构。压缩同样是**新增不是替换**，最终产物一律以 sidecar 的 `image` 字段为准。

11. **步骤 9：回写门（本 skill 独有）**——最重要的一节：

> **小红书 `series` 不回写，走到步骤 8 就结束。** 卡片系列是内容本身，不进正文；`article.illustrated.md` 只在微信 `illustration` / `infographic`（以及要插正文的示意图）时产生。

回写三步走：

```bash
# 9a 写 insertions（语义层）。image 一律抄 sidecar 的 image 字段，绝不硬编 .png
python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['image'])" "$ART/assets/${PLATFORM}/01-illustration.json"

cat > "$ART/insertions.json" <<'JSON'
[
  {"anchor": "## 缓存失效的三种写法", "position": "after",
   "image": "01-illustration.jpg", "alt": "三种写法的对比示意"}
]
JSON

# 9b 预览 diff，给用户看（此时还没写任何文件）
python3 shared/scripts/writeback.py \
  --source "$ART/article.wechat.md" --insertions "$ART/insertions.json" \
  --assets-dir "$ART/assets/${PLATFORM}" --out "$ART/article.illustrated.md" --dry-run

# 9c 用户确认后才真写
python3 shared/scripts/writeback.py \
  --source "$ART/article.wechat.md" --insertions "$ART/insertions.json" \
  --assets-dir "$ART/assets/${PLATFORM}" --out "$ART/article.illustrated.md"
```

**9b 与用户确认这一步不许跳过**（spec §9：改源文件的门）。锚点命中 0 次或多次时脚本会硬失败并把锚点打回来——**改锚点，别去改原文来迁就它**。

12. **步骤 10：交接**：

> 告诉用户产出了 `article.illustrated.md`（**原文 `article.wechat.md` 一字未改**），接下来 `md2publish-article` 会**默认**用这份带图的版本转 HTML。部分失败时要说清楚少了哪几张、原计划插在哪。

13. **产物布局**：

```
$ART/
├─ article.wechat.md                     ← 原文，本 skill 永不修改
├─ article.illustrated.md                ← 回写产物（series 不产生这个）
├─ insertions.json                       ← 插入计划，复现记录
├─ briefs/<platform>/NN-<role>.md
├─ prompts/<platform>/NN-<role>.md
└─ assets/<platform>/NN-<role>.png|.jpg + NN-<role>.json
```

- [ ] **Step 3: 自查**

```bash
grep -c 'wechat,xiaohongshu' skills/md2publish-visuals/SKILL.md   # 期望 ≥1：多平台拆两次那节在
grep -n 'series' skills/md2publish-visuals/SKILL.md | grep -c '不回写'   # 期望 ≥1
grep -c '00-cover.png' skills/md2publish-visuals/SKILL.md          # 期望 0：不许硬编封面文件名
```

- [ ] **Step 4: 照着步骤 9 手跑一遍回写门**

```bash
T=$(mktemp -d); mkdir -p "$T/assets/wechat"
printf '# 标题\n\n开头。\n\n## 小节一\n\n正文。\n' > "$T/article.wechat.md"
printf 'fake' > "$T/assets/wechat/01-illustration.jpg"
printf '[{"anchor":"## 小节一","position":"after","image":"01-illustration.jpg","alt":"示意"}]' > "$T/ins.json"
python3 skills/_shared/scripts/writeback.py --source "$T/article.wechat.md" \
  --insertions "$T/ins.json" --assets-dir "$T/assets/wechat" \
  --out "$T/article.illustrated.md" --dry-run
python3 skills/_shared/scripts/writeback.py --source "$T/article.wechat.md" \
  --insertions "$T/ins.json" --assets-dir "$T/assets/wechat" --out "$T/article.illustrated.md"
cat "$T/article.illustrated.md"; rm -rf "$T"
```

预期：`--dry-run` 打印 diff 不写文件；第二条写出文件，图片引用是 `assets/wechat/01-illustration.jpg`。

- [ ] **Step 5: Commit**

```bash
cat > /tmp/t5.txt <<'EOF'
feat(visuals): add the md2publish-visuals skill

Steps 1-8 mirror md2publish-cover; the differences are the ones that
matter and they are spelled out rather than left to be inferred:

- batch generation always asks (cover deliberately does not), and
  max_images_per_run is a hard refusal rather than a warning
- a multi-platform request is split into two independent runs. wechat
  wants 3-8 inline illustrations, xiaohongshu wants a card series --
  different content, not the same concept at another aspect ratio, so one
  confirmation must never cover both platforms' spend
- step 9 is the writeback gate: preview with --dry-run, get confirmation,
  then write. Series skips it entirely: xiaohongshu cards are the content,
  they do not belong in the article body
- insertions[].image is read out of the sidecar, never hardcoded to .png

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
git add skills/md2publish-visuals/SKILL.md
git commit -F /tmp/t5.txt -- skills/md2publish-visuals/SKILL.md
```

---

### Task 6: 把两个新 skill 接进 vendor 体系

**Files:**
- Modify: `scripts/shared-manifest.sh`
- Modify: `scripts/test-sync-drift.sh`
- Generated: `skills/md2publish-visuals/shared/`、`skills/md2publish-diagram/shared/`

**Interfaces:**
- Consumes: T2 / T3 的新脚本，T4 / T5 的 skill 目录
- Produces: 三个 skill 各自的 vendor 副本。`check-shared-drift.sh` 自动覆盖它们（它本来就遍历 `SHARED_SKILLS`）。

- [ ] **Step 1: 确认起点**

```bash
git status
bash scripts/test-sync-drift.sh 2>&1 | tail -3        # 期望「通过 9 项，失败 0 项」
grep -n 'SHARED_SKILLS' scripts/shared-manifest.sh scripts/test-sync-drift.sh
```

注意 `test-sync-drift.sh` 当前**硬编了 `md2publish-cover`**（沙箱只拷这一个 skill、`DEST` 也指向它）。清单一变它就名不副实——这正是本任务要一起改掉的。

- [ ] **Step 2: 写会失败的断言**

在 `scripts/test-sync-drift.sh` 里，把沙箱构建那段（`\cp -Rf "$REPO/skills/md2publish-cover" ...` 那一行）替换成遍历，并在「清单里的关键文件都到位」之后追加三条按 skill 分别断言的检查。完整替换如下三处：

**(a) 沙箱构建**——原来那行 `\cp -Rf "$REPO/skills/md2publish-cover" "$SANDBOX/skills/md2publish-cover"` 换成：

```bash
source "$REPO/scripts/shared-manifest.sh"
for s in "${SHARED_SKILLS[@]}"; do
  \cp -Rf "$REPO/skills/${s}" "$SANDBOX/skills/${s}"
done
```

**(b) 关键文件检查之后**追加：

```bash
# diagram 的清单必须**更小**：它不调 AI，带上 imagegen 就是白白多 vendor 一个引擎。
if [[ ! -e "skills/md2publish-diagram/shared/scripts/imagegen" ]]; then
  ok "diagram 的 vendor 副本里没有 imagegen（它不调 AI）"
else
  bad "diagram 带上了 imagegen（多 vendor 一整个引擎）" ""
fi

for f in scripts/svg2raster.py scripts/artifacts.py scripts/compress.py platforms/wechat.yaml; do
  [[ -e "skills/md2publish-diagram/shared/${f}" ]] || missing="${missing} diagram:${f}"
done
for f in scripts/writeback.py scripts/compose_prompt.py scripts/imagegen/main.ts; do
  [[ -e "skills/md2publish-visuals/shared/${f}" ]] || missing="${missing} visuals:${f}"
done
[[ -z "${missing}" ]] && ok "两个新 skill 的清单都到位" || bad "新 skill 的 vendor 缺文件" "${missing}"
```

（`missing` 变量在原脚本里已定义并在上一条断言里用过；这里复用它之前要先 `missing=""` 重置。加一行 `missing=""` 在这段最前面。）

**(c) 沙箱隔离检查**：`REAL_PROBE` 那两行下面追加一个对新 skill 的探针——

```bash
REAL_PROBE2="$REPO/skills/md2publish-diagram/shared/scripts/svg2raster.py"
REAL_BEFORE2=$(cksum < "$REAL_PROBE2" 2>/dev/null || echo "缺失")
```

——并在末尾「沙箱隔离」那节里为它加**一条独立的断言**（不要并进现有那条：两个探针合成一条，失败时看不出是哪个 skill 的副本被污染了）：

```bash
REAL_AFTER2=$(cksum < "$REAL_PROBE2" 2>/dev/null || echo "缺失")
if [[ "$REAL_BEFORE2" == "$REAL_AFTER2" ]]; then
  ok "diagram 的 vendor 副本也全程未被改动"
else
  bad "本测试改到了 diagram 的真实 vendor 副本" "before=${REAL_BEFORE2} after=${REAL_AFTER2}"
fi
```

三条新断言加起来：9 → **12 项**。

- [ ] **Step 3: 跑测试，确认它以正确的方式失败**

```bash
bash scripts/test-sync-drift.sh 2>&1 | tail -8
```

预期：新加的断言失败（`skills/md2publish-diagram` 目录里还没有 `shared/`），并且**沙箱构建那步会报 `cp: skills/md2publish-visuals: No such file`**——如果报的是这个，说明 T4/T5 的 skill 目录没建好，回头查。

- [ ] **Step 4: 改清单**

`scripts/shared-manifest.sh`：

```bash
SHARED_SKILLS=("md2publish-cover" "md2publish-visuals" "md2publish-diagram")
```

`shared_items_for` 加两个 case（**diagram 那份刻意更小**，注释要写清楚为什么）：

```bash
    md2publish-visuals)
      # 与 cover 同构，另加 writeback.py（回写门）
      echo "platforms presets costs.yaml \
scripts/asset_lib.py scripts/compose_prompt.py scripts/compress.py \
scripts/config.py scripts/preflight.py scripts/artifacts.py \
scripts/writeback.py scripts/imagegen"
      ;;
    md2publish-diagram)
      # 刻意比另两个小得多：diagram 不调 AI，因此不带 imagegen（一整个 TS 引擎）、
      # 不带 presets/costs.yaml/config.py/preflight.py（没有 provider 可查）。
      # asset_lib.py 仍要带——artifacts.py 硬 import 它，且画幅要从 platform profile 取。
      echo "platforms \
scripts/asset_lib.py scripts/artifacts.py scripts/compress.py scripts/svg2raster.py"
      ;;
```

- [ ] **Step 5: 同步并验证**

```bash
./scripts/sync-shared.sh
bash scripts/check-shared-drift.sh
bash scripts/test-sync-drift.sh 2>&1 | tail -6
```

预期：sync 打印三行「已同步 …」；漂移检查三个 skill 全 ✅；测试「通过 12 项，失败 0 项」。

- [ ] **Step 6: 确认 vendor 出来的 diagram 副本能独立跑**

```bash
cd skills/md2publish-diagram && python3 shared/scripts/svg2raster.py --check && cd ..
cd md2publish-visuals && python3 -c "import sys; sys.path.insert(0,'shared/scripts'); import writeback" && cd ../..
```

预期：两条都成功。第二条证明 `writeback.py` 的 `import artifacts` / `import asset_lib` 在 vendor 副本里也解析得到（少 vendor 一个依赖就会在这里炸）。

- [ ] **Step 7: Commit**

```bash
cat > /tmp/t6.txt <<'EOF'
feat(scripts): vendor the shared layer into visuals and diagram

diagram gets a deliberately smaller subset: no imagegen (a whole TS
engine it never calls), no presets, costs.yaml, config.py or preflight.py
(there is no provider to check). asset_lib.py stays because artifacts.py
imports it and the platform frame is read from the profile.

test-sync-drift.sh no longer hardcodes md2publish-cover -- it iterates
SHARED_SKILLS for both the sandbox copy and the isolation probe, so the
next skill added to the manifest is covered automatically instead of
silently untested. New assertion: diagram's vendor copy must NOT contain
imagegen, which is the one way this subset can rot back into "copy
everything".

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
git add scripts/shared-manifest.sh scripts/test-sync-drift.sh \
        skills/md2publish-visuals/shared skills/md2publish-diagram/shared
git commit -F /tmp/t6.txt -- scripts/shared-manifest.sh scripts/test-sync-drift.sh \
        skills/md2publish-visuals/shared skills/md2publish-diagram/shared
```

---

### Task 7: check.sh 接线（含 SKIPPED 语义与 diagram 端到端）

**Files:**
- Create: `scripts/test-diagram-e2e.sh`
- Modify: `scripts/check.sh`

**Interfaces:**
- Consumes: T1–T3 的脚本与测试，T6 的 vendor
- Produces: `check.sh` 由 9 项变 12 项；退出码语义：0 = 全绿（可能含 SKIPPED），1 = 有失败。`test-diagram-e2e.sh` 的退出码 **2 专门表示 SKIPPED**。

- [ ] **Step 1: 确认起点**

```bash
./scripts/check.sh 2>&1 | tail -5      # 期望九项全 ✓、「全部通过。」
```

- [ ] **Step 2: 写端到端脚本**

创建 `scripts/test-diagram-e2e.sh`：

```bash
#!/usr/bin/env bash
# diagram 的零成本端到端：写好的 SVG → 光栅化 → 压缩 → sidecar。
#
# **退出码 2 表示 SKIPPED**（一个光栅化后端都没有）。check.sh 靠它区分
# "跑过并通过"和"根本没跑"——把没跑过的项算成通过，就是二期 A 教训 4 的假绿。
#
# 为什么这一项值得端到端跑：本仓库另外两条链路（cover / visuals）都要花钱，
# 端到端只能挂账手动。diagram 零成本，它是唯一能自动化验证的完整链路。
set -uo pipefail
cd "$(dirname "$0")/.."

if [[ "$(python3 skills/_shared/scripts/svg2raster.py --check --json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["backends"]))')" == "0" ]]; then
  echo "  ⊘ SKIPPED：rsvg-convert / magick / chrome 一个都没有。"
  echo "     装其中一个即可让这一项真跑：brew install librsvg"
  exit 2
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM

PASS=0
FAIL=0
ok()  { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad() { echo "  ❌ $1"; echo "     $2"; FAIL=$((FAIL+1)); }

S=skills/_shared/scripts
ART="$TMP/article"
mkdir -p "$ART/diagrams/wechat" "$ART/assets/wechat"
SVG="$ART/diagrams/wechat/00-diagram.svg"
PNG="$ART/assets/wechat/00-diagram.png"
\cp -f "$S/fixtures/diagram-sample.svg" "$SVG"

ASPECT=$(python3 -c "import sys; sys.path.insert(0,'${S}'); import asset_lib as a; s=a.archetype_slot(a.load_platform('wechat'),'diagram'); print(s['aspect'][0] if isinstance(s['aspect'],list) else s['aspect'])")
MAXB=$(python3 -c "import sys; sys.path.insert(0,'${S}'); import asset_lib as a; print(a.archetype_slot(a.load_platform('wechat'),'diagram')['max_bytes'])")

echo "== 光栅化 =="

RASTER=$(python3 "$S/svg2raster.py" --svg "$SVG" --out "$PNG" --aspect "${ASPECT}" --json 2>&1)
rc=$?
if [[ $rc -eq 0 && -s "$PNG" ]]; then
  BACKEND=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['backend'])" "${RASTER}")
  ok "SVG → PNG 成功（后端：${BACKEND}）"
else
  bad "光栅化失败" "rc=${rc} out=${RASTER}"
  BACKEND=unknown
fi

echo
echo "== 压缩 =="

BYTES=$(wc -c < "$PNG" | tr -d ' ')
if [[ ${BYTES} -le ${MAXB} ]]; then
  ok "未超平台上限（${BYTES} ≤ ${MAXB}），按流程跳过压缩"
else
  bad "光栅化产物超限，流程要求此处压缩" "bytes=${BYTES} max=${MAXB}"
fi

# 上一条大概率走"不压缩"分支，所以再用一个人为的小上限把压缩这条路也真跑一遍
SMALL=20000
OUT=$(python3 "$S/compress.py" --image "$PNG" --max-bytes "${SMALL}" 2>&1)
if [[ $? -eq 0 && -f "${OUT}" ]] && [[ "$(wc -c < "${OUT}" | tr -d ' ')" -le ${SMALL} ]]; then
  ok "人为压到 ${SMALL} 字节以内也成立（压缩这条分支真跑过）"
else
  bad "压缩分支失败" "$OUT"
fi
[[ -f "$PNG" ]] && ok "压缩没有动原始 PNG（它是新增不是替换）" || bad "原始 PNG 不见了" ""

echo
echo "== sidecar =="

python3 "$S/artifacts.py" sidecar --image "$PNG" \
  --platform wechat --archetype diagram --provider "${BACKEND}" \
  --source-file "$(basename "$SVG")" --alt-text "三层缓存架构示意图" >/dev/null 2>&1
SIDE="$ART/assets/wechat/00-diagram.json"
if [[ -f "${SIDE}" ]]; then
  got=$(python3 -c "import json;d=json.load(open('${SIDE}'));print(d['image'],d['source_file'],d['provider'],d['preset'])")
  if [[ "${got}" == "00-diagram.png 00-diagram.svg ${BACKEND} None" ]]; then
    ok "sidecar 四个关键字段都对（image / source_file / provider / preset=null）"
  else
    bad "sidecar 字段不对" "got=${got}"
  fi
else
  bad "sidecar 没写出来" ""
fi

echo
echo "通过 $PASS 项，失败 $FAIL 项"
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 3: 单跑它**

```bash
bash scripts/test-diagram-e2e.sh; echo "exit=$?"
```

预期（本机三后端齐全）：「通过 5 项，失败 0 项」，`exit=0`。

- [ ] **Step 4: 验证 SKIPPED 分支真的会走到**

```bash
env -i PATH=/usr/bin:/bin HOME="$HOME" SVG2RASTER_CHROME=/nonexistent \
  bash scripts/test-diagram-e2e.sh; echo "exit=$?"
```

预期：打印 `⊘ SKIPPED`，`exit=2`。**这一步不许跳过**——SKIPPED 分支如果自己是坏的，`check.sh` 在别人机器上就会报一个假的失败。

（注：这条命令下 `python3` 会退到 `/usr/bin/python3`，它没有 PyYAML；`svg2raster.py --check` 是纯标准库所以仍能跑，这正是 Global Constraints 里那条约束的用处。）

- [ ] **Step 5: 改 check.sh**

`run()` 换成能识别退出码 2：

```bash
FAILED=()
SKIPPED=()

run() {
  local label="$1"; shift
  echo
  echo "───── $label ─────"
  "$@"
  local rc=$?
  if [[ $rc -eq 0 ]]; then
    echo "  ✓ $label"
  elif [[ $rc -eq 2 ]]; then
    echo "  ⊘ $label：SKIPPED"
    SKIPPED+=("$label")
  else
    echo "  ✗ $label"
    FAILED+=("$label")
  fi
}
```

三个新项插进去（**位置有讲究**，见 Global Constraints：全部排在「shared 漂移检查」之前）：

```bash
run "产物落盘规则"                            bash skills/_shared/scripts/test-artifacts.sh
run "Markdown 回写门"                         bash skills/_shared/scripts/test-writeback.sh
run "SVG→位图降级链"                          bash skills/_shared/scripts/test-svg2raster.sh
run "imagegen 引擎"                           bash -c 'cd skills/_shared/scripts/imagegen && bun test'
run "diagram 端到端（零成本）"                 bash scripts/test-diagram-e2e.sh
```

末尾摘要改成（**有跳过时绝不允许打印无条件的「全部通过。」**）：

```bash
echo
if [[ ${#FAILED[@]} -eq 0 ]]; then
  if [[ ${#SKIPPED[@]} -eq 0 ]]; then
    echo "全部通过。"
  else
    echo "全部通过（${#SKIPPED[@]} 项跳过：$(IFS=、; echo "${SKIPPED[*]}")）。"
    echo "跳过的项**没有跑过**，不等于通过。装齐工具后重跑。"
  fi
  echo
  echo "注意：还有两项**不在这里**——真调一次 provider 生一张图的最小 smoke"
  echo "（cover 与 visuals 各一次）。它们计费，因此永远手动跑，"
  echo "见 docs/handoff/handoff-image.md。"
  exit 0
fi
```

- [ ] **Step 6: 跑全量，确认 12 项**

```bash
./scripts/check.sh 2>&1 | grep -cE '^  ✓|^  ⊘'      # 期望 12
./scripts/check.sh 2>&1 | tail -8
```

预期：12 项全 ✓、末尾「全部通过。」。

- [ ] **Step 7: 确认另一条线没被碰坏**

```bash
python3 skills/md2publish-article/scripts/test-theme-lib.py 2>&1 | tail -2   # ok：0 条失败
```

- [ ] **Step 8: Commit**

```bash
cat > /tmp/t7.txt <<'EOF'
feat(scripts): wire the phase-3 checks into check.sh (9 -> 12 items)

Adds the writeback and svg2raster unit suites plus a real end-to-end run
of the diagram chain: fixture SVG -> rasterize -> compress -> sidecar.
This is the only chain in the repo that can be verified end to end
without spending money, so it is worth automating rather than filing next
to the paid smoke.

check.sh now understands a third outcome. A suite exiting 2 is SKIPPED,
and a run with skips prints "全部通过（N 项跳过：…）" plus an explicit
"skipped is not passed" line instead of the unconditional "全部通过。".
Without that, a machine with no rasterizer would report a green run for a
check that never executed -- the same false-green shape as the phase-2A
ordering bug.

All three new items sit ahead of the drift checks: the last two must stay
at the tail because the vendor suite re-syncs before it asserts.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
git add scripts/check.sh scripts/test-diagram-e2e.sh
git commit -F /tmp/t7.txt -- scripts/check.sh scripts/test-diagram-e2e.sh
```

---

### Task 8: 上下游接线（article 输入表 + 全仓库「三期未实现」清扫）

**Files:**
- Modify: `skills/md2publish-article/SKILL.md`
- Modify: `skills/README.md`
- Modify: `skills/_shared/README.md`
- Modify: `skills/md2publish-cover/SKILL.md`
- Modify: `skills/wechat-finetune/SKILL.md`（如果 grep 命中）

**Interfaces:**
- Consumes: T5 产出的 `article.illustrated.md` 契约
- Produces: `md2publish-article` 默认消费 `article.illustrated.md`（D15）；全仓库不再有「三期，尚未实现」的说法

- [ ] **Step 1: 先 grep 出所有要改的地方，一次改完**

这一步是二期 B 教训 9 的直接应用：**同一个事实往往被四五份文档各自断言过，改一处不等于改完。** 关键词要用**那句话的说法**，不是标识符名：

```bash
grep -rn '三期' skills/ | grep -v '^skills/_shared/scripts/'
grep -rn '尚未实现\|还没有\|三期才建' skills/
grep -rn 'md2publish-visuals\|md2publish-diagram' skills/ docs/handoff/
grep -rn 'article.illustrated' skills/ docs/
grep -rn '九项' docs/ skills/
```

把命中清单列出来再动手。**每一条都要么改、要么明确判定"这是历史记录，保留"**，不许漏。

- [ ] **Step 2: 改 `md2publish-article/SKILL.md` 步骤 1 输入表**

先定位（行号会漂）：

```bash
grep -n '步骤 1：拿到输入' -A 8 skills/md2publish-article/SKILL.md
```

在表格**最前面**加一行，并保持其余三行不动：

```markdown
| 场景 | 处理 |
|---|---|
| 同目录存在 `article.illustrated.md` | **默认用它**——那是 `md2publish-visuals` 的回写产物，正文里已经插好了配图。**要告诉用户你选了哪一份**，以及不带图的原文叫什么（通常是 `article.wechat.md`）。用户明确要不带图的版本时才改用原文 |
| 用户给了文件路径 | 直接使用（显式指定优先于上面的默认） |
| 用户粘贴了 Markdown | 先 Write 保存为 `.md` 文件再继续 |
| 只说"转换文章"没给内容 | 询问文件路径或让用户粘贴 |
```

表格下面补一句，把 spec §8 的理由写进去：

> `md2publish-visuals` 在本 skill 的**上游**，不是并行分支（spec §8）。它另存 `article.illustrated.md` 而不改原文，所以两份会并存；不认这个文件的话，用户花钱生成的配图会静默地永远不进 HTML。

- [ ] **Step 3: 改 `md2publish-article/SKILL.md` 的边界节**

原文写着 `md2publish-visuals` 与 `md2publish-diagram`「三期才建、现在还没有」。改成实到的去向：

```markdown
- 用户要正文配图 / 信息图 / 卡片系列时，交接给 `md2publish-visuals`；要架构图 / 流程图时，交接给 `md2publish-diagram`。
  **配图要在本 skill 之前做完**——它回写出的 `article.illustrated.md` 才是本 skill 该转的那一份。
```

- [ ] **Step 4: 改 `skills/README.md` 的流水线图与 skill 表**

流程图要画成**串联**，不是三个并行框（spec §8 点名警告过）：

```
wechat-finetune → article.wechat.md
                       │
                       ├──→ md2publish-visuals ──→ article.illustrated.md ──┐
                       │    （回写图片引用，另存原文不动）                    │
                       │                                                    ▼
                       └────────────────────────────────→ md2publish-article ──→ .html
                                                                              │
   md2publish-cover ────→ assets/<platform>/00-cover.*（以 sidecar 的 image 为准）┤
   md2publish-diagram ──→ assets/<platform>/NN-diagram.png（插正文则在 article 之前）
                                                                              ▼
                                                                    md2publish-draft
```

skill 表格里把两个新 skill 加上，并去掉所有「三期，尚未实现」。

- [ ] **Step 5: 改 `skills/_shared/README.md` 与 `md2publish-cover/SKILL.md`**

- `_shared/README.md` 末节「还没做的事」：三期的两项已完成，删掉；留下 `bilibili.yaml` 那条（仍然故意没做）。同时把「谁在用 `_shared/`」从一个 skill 更新成三个。
- `md2publish-cover/SKILL.md` 的职责边界表：两行「三期，尚未实现」改成实到的去向。

- [ ] **Step 6: 验证**

```bash
grep -rn '三期，尚未实现\|三期才建' skills/     # 期望：无输出
./scripts/check.sh 2>&1 | tail -4              # 12 项全绿（改了 _shared/README.md 要先 sync？不用，README 不在 vendor 清单里）
```

**再手工验一次 D15 真的成立**（这是本期完成判据第 2 条的一半）：

```bash
T=$(mktemp -d)
printf '# 标题\n\n正文。\n' > "$T/article.wechat.md"
printf '# 标题\n\n正文。\n\n![示意](assets/wechat/01-illustration.jpg)\n' > "$T/article.illustrated.md"
ls "$T"
grep -n 'article.illustrated.md' skills/md2publish-article/SKILL.md | head -3
rm -rf "$T"
```

预期：SKILL.md 步骤 1 的表格第一行确实命中，且措辞是"默认用它 + 告知用户"。

- [ ] **Step 7: Commit**

```bash
cat > /tmp/t8.txt <<'EOF'
docs(skills): put visuals upstream of article and retire the "phase 3
is not built yet" wording

md2publish-article's step-1 input table now takes article.illustrated.md
as the default when it exists, and says so out loud along with the name of
the un-illustrated original. Asking every time would decay into the
multi-turn Q&A the design explicitly rejected; switching silently would
leave the user unsure which file got converted.

The pipeline diagram in skills/README.md is drawn as a chain, not three
parallel boxes -- the failure mode the spec names is exactly the parallel
drawing, after which article.illustrated.md is silently never converted.

Swept every place that asserted "phase 3, not implemented yet": article,
cover, _shared/README and the skill table. Grepped by phrasing rather than
by identifier, which is what the phase-2B review found eight per-task
reviews had missed.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
git add skills/md2publish-article/SKILL.md skills/README.md \
        skills/_shared/README.md skills/md2publish-cover/SKILL.md
git commit -F /tmp/t8.txt -- skills/md2publish-article/SKILL.md skills/README.md \
        skills/_shared/README.md skills/md2publish-cover/SKILL.md
```

（若 Step 1 的 grep 在 `skills/wechat-finetune/SKILL.md` 也有命中，把它一起加进这两条命令的路径列表。）

---

### Task 9: 反向修订 spec 与 handoff

**Files:**
- Modify: `docs/superpowers/specs/2026-08-09-md2publish-image-skills-design.md`（§5.3 §6 §7 §13 §14.3 §15 §16）
- Modify: `docs/handoff/handoff-image.md`

**Interfaces:**
- Consumes: T1–T8 的全部产出
- Produces: spec 重新成为唯一真相源；handoff 记录三期状态与教训

- [ ] **Step 1: 先 grep，一次改完（教训 9）**

```bash
grep -n '九项\|五项' docs/superpowers/specs/2026-08-09-md2publish-image-skills-design.md docs/handoff/handoff-image.md
grep -n 'preset_version\|sidecar' docs/superpowers/specs/2026-08-09-md2publish-image-skills-design.md
grep -n '三期' docs/superpowers/specs/2026-08-09-md2publish-image-skills-design.md
```

- [ ] **Step 2: 改 spec**

逐节要点（**每一处都要与实现核对，不许凭这份计划的描述改**——计划可能与最终实现有出入，以代码为准）：

- **§5.3 sidecar schema**：加 `source_file` 字段；补一段说明 diagram 支路（`preset` / `preset_version` / `model` / `prompt_file` / `brief_file` 为 `null`，`provider` 是光栅化后端名）。
- **§6 机械层 / 语义层**：补一行——`diagram` 的语义层产物是 SVG 本身，不经过 `compose_prompt.py`（D12）。
- **§7 执行链路**：补 `diagram` 的链路（无计费段）与 `visuals` 的步骤 9 回写门；§7.2 补一句 `visuals` 的 `series` 不回写（D16）。
- **§13 验证**：五项 → 说明 `check.sh` 现在是 12 项；补 SKIPPED 语义（D14）；把"一项不进自动化"改成"两项"（cover 与 visuals 各一次付费 smoke），并明说 diagram 的端到端**已进自动化**。
- **§14.3**：补 D13 的画幅强制校验。
- **§15 三期那一行**：完成判据改成三分版（自动化 / 本机零成本端到端 / 手动付费挂账）；破坏性一栏写「改 `md2publish-article` 输入表，回滚 = `git revert` 那一个 commit」。
- **§16 修订记录**：追加第四版（2026-08-11，三期收尾），列出本期六条偏离与对应的正文改动。

- [ ] **Step 3: 改 handoff-image.md**

- 快速接手入口：三期已完成；下一步是什么（付费 smoke 仍未跑；`bilibili.yaml` 仍未做）。
- 第二节基线：九项 → **12 项**，逐项列出新数字（见本计划开头那张表）；补一句 SKIPPED 的含义。
- 第三节关键契约：补「sidecar 的 `image` 是唯一真相源，被 draft 与 writeback 两方消费」、「diagram 不走 preset/prompt」、「`svg2raster.py` 只用标准库且原因」。
- 第四节环境事实：补 `/usr/bin/python3` 是 3.9.6 且没有 PyYAML（PATH 遮蔽测试靠它）；补 **`git commit` 的 `--` 必须排在 `-m`/`-F` 之后**（本期实测踩过）。
- 第六节：三期的完成/未完成如实分开写；**付费 smoke 现在是两次未跑**（cover 与 visuals）。
- 第八节：追加三期在执行中发现的计划缺陷（执行时如实记，没有就写"本期没有新增"，**不要为了凑数编**）。

- [ ] **Step 4: 全量验证**

```bash
./scripts/check.sh 2>&1 | tail -8
python3 skills/md2publish-article/scripts/test-theme-lib.py 2>&1 | tail -2
grep -rn '九项' docs/ skills/       # 期望：无输出（全改成 12 项了）
```

- [ ] **Step 5: Commit**

```bash
cat > /tmp/t9.txt <<'EOF'
docs(image): fold phase 3 back into the spec and the handoff

The spec is the single source of truth, so the six deviations recorded in
the phase-3 plan (D11-D16) are merged into the sections that assert them:
5.3 gains source_file and the deterministic-archetype branch, 6 and 7 gain
the diagram chain and the writeback gate, 13 gains the 12-item check.sh
and the SKIPPED semantics, 14.3 gains the aspect enforcement, 15 gains the
three-way completion criterion.

Every count that moved was grepped by phrase, not by identifier -- "九项"
appeared in both documents and in two skill files.

Handoff records what is and is not verified: the diagram chain really runs
end to end on this machine, and there are now TWO unpaid smokes owed
(cover and visuals), not one.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
git add docs/superpowers/specs/2026-08-09-md2publish-image-skills-design.md \
        docs/handoff/handoff-image.md
git commit -F /tmp/t9.txt -- \
        docs/superpowers/specs/2026-08-09-md2publish-image-skills-design.md \
        docs/handoff/handoff-image.md
```

---

## 收尾：整支评审（不许省）

九个任务各自的评审全部通过之后，**必须再做一次整支评审**（`superpowers:requesting-code-review`，范围是本期全部 commit）。

理由不是流程洁癖，是连续两期的实测：二期 A 八个任务逐个全绿，整支评审仍抓出 1 Critical + 6 Important；二期 B 换了一批任务、换了一批评审者，结果同样是逐任务全绿、整支评审再抓 4 个 Important。两期加起来 11 条，**全部是跨组件问题**——顺序依赖、四处名单不同步、同一个事实只在一处改对。逐任务评审在结构上看不见这类问题。

本期最可能藏这类问题的地方，评审时重点看：

1. **`sidecar` 的 `image` / `source_file` 语义有没有四处一致**：`artifacts.py` 的实现、`writeback.py` 的 docstring、两个新 SKILL.md、`md2publish-draft/SKILL.md`、spec §5.3 §12。
2. **「12 项」这个数字有没有全仓库一致**：`check.sh` 的实际项数、handoff 第二节、spec §13、`_shared/README.md`。
3. **`shared_items_for` 的三份清单与三个 skill 实际 import 的东西是否吻合**——diagram 少 vendor 了什么，只有在别的机器上第一次跑才会炸。
4. **`check.sh` 里新项的位置**有没有破坏"漂移检查必须在 re-sync 之前"。
5. **回写门的措辞**在 `visuals/SKILL.md`、`writeback.py`、spec §9 三处是否说的是同一件事。

评审收尾后，把整支评审的发现补进 `docs/handoff/handoff-image.md` 第八节。

---

## 本计划的自查记录

写完后按 spec 逐节核对的结果，留在这里供评审时反查：

| spec 小节 | 由谁实现 |
|---|---|
| §3 三个 skill 的边界与张数 | T4 / T5 的职责边界表与路由表 |
| §3.2 触发歧义路由 | T5 的路由表（照抄 spec，未改动） |
| §5.3 sidecar | T1（含 D11 的 diagram 支路）、T9（回写 spec） |
| §6 机械 / 语义分层 | T2 / T3 的脚本边界；T4 / T5 的「你负责语义」节 |
| §7 执行链路 | T4（diagram 七步）、T5（visuals 十步） |
| §7.2 多平台只对 cover / diagram 开放 | T5 的「多平台必须拆两次执行」节 |
| §7.3 产物布局与重跑跳过 | T3（`artifacts.guard` 复用）、T4 / T5 的产物布局节 |
| §8 流水线次序 | T8（article 输入表 + README 流程图） |
| §9 成本门与改源文件的门 | T5 的步骤 5 与步骤 9 |
| §10 失败处理（部分失败不整体回滚） | T5 的步骤 6；T2 的降级链失败路径 |
| §13 验证五项 | T7（扩到 12 项）；矩阵 / 白名单 / schema 三项本期未改动，仍覆盖新 preset 之外的全部组合 |
| §14.3 SVG 转位图 | T2（含 D13 的画幅强制） |
| §15 三期完成判据 | T9（改成三分版） |

**已知不覆盖的（有意）**：`bilibili.yaml`（§14.5，外部知识未验证）；新 preset / 新维度值（范围外）；`md2publish-draft` 的多平台分化（§14.1，独立的一轮）。
