# `_shared/` — 图片资产共享层

本目录**不是 skill**（没有 SKILL.md，不会被 skill 加载器扫描），
而是 `md2publish-cover` / `md2publish-visuals` / `md2publish-diagram` 三个 skill
的单一真相源。

设计文档：`docs/superpowers/specs/2026-08-09-md2publish-image-skills-design.md`

## 布局

| 路径 | 内容 |
|---|---|
| `platforms/*.yaml` | 平台 profile：按 archetype 分槽，管画幅、文字上图策略、体积上限 |
| `presets/**/*.yaml` | 视觉风格 preset，引用 `dimensions/` 词表 |
| `presets/dimensions/` | 配色 / 渲染 / 版式词表，每个文件是一段可直接嵌进 prompt 的中文 |
| `presets/INDEX.md` | preset 与 dimensions 的唯一发现入口 |
| `scripts/asset_lib.py` | 资产加载与 schema 校验 |
| `scripts/compose_prompt.py` | prompt 渲染器（纯模板，不调模型） |
| `costs.yaml` | provider × model 单张估价，允许 `unknown` |
| `scripts/imagegen/` | vendor 自 baoyu-image-gen 的生图引擎（TS / bun），见 `VENDOR.md` |
| `scripts/compress.py` | 压到字节上限内（sips → magick 降级链） |
| `scripts/config.py` | 读 `~/.config/md2publish/images.yaml` |
| `scripts/preflight.py` | 运行时 / provider / 压缩工具三项自检 |
| `scripts/artifacts.py` | 重跑保护 + 产物 sidecar |

## 前置

```bash
python3 --version          # 3.9+
python3 -c 'import yaml'   # 缺就 pip3 install pyyaml
```

PyYAML 是本层唯一的第三方依赖。

脚本用了 `dict | None` 这类 PEP 604 注解，靠 `from __future__ import annotations`
在 3.9 上工作——新增脚本时别漏掉那一行。

## 跑测试

一条命令跑全部（推荐）：

```bash
./scripts/check.sh          # 仓库根目录
```

单跑：

```bash
./scripts/test-asset-schema.sh      # 资产 schema + costs.yaml
./scripts/test-compose-prompt.sh    # 渲染器行为 + 占位符白名单
./scripts/test-platform-matrix.sh   # 平台 × archetype × preset 全矩阵
./scripts/test-compress.sh          # 压缩不超限
python3 scripts/test-preflight.py   # 自检与配置
./scripts/test-artifacts.sh         # 重跑保护与 sidecar
./scripts/test-writeback.sh         # Markdown 回写门
./scripts/test-svg2raster.sh        # SVG→位图降级链（缺后端时 exit 2 报 SKIPPED）
(cd scripts/imagegen && bun test)   # 生图引擎
```

**这里故意不写每个脚本几项。** 每个脚本结尾自己会打
`通过 N 项，失败 M 项`，以那行为准。这份清单曾经写着七个数字，其中五个在被
加断言、加平台之后悄悄过期（「8 组合」是加 `bilibili.yaml` 当场作废的），
而过期的数字看起来和正确的数字完全一样——**数字是最容易悄悄过期的一种断言**。
`docs/handoff/handoff-image.md` 第二节留了一份逐项计数，是给交接时对基线用的，
那一份每次改测试都必须回头对齐。

**改了 `platforms/`、`presets/`、`costs.yaml` 或 `scripts/` 里任何东西之后，
跑一遍 `scripts/check.sh`。** 本仓库没有 CI、没有 git hooks，这是一条
**有文档约束的手工流程，不是自动闸门**。

改完 `_shared/` 还要跑 `scripts/sync-shared.sh` 把改动推到各 skill 的 `shared/`，
否则 `check.sh` 的漂移检查会红。

## 机械层与语义层

`compose_prompt.py` 是**纯模板渲染器**：读 YAML、填占位符、写文件。
它不读文章原文、不做内容抽取、不调模型。

文章的语义部分（这张图要表达什么、主体是什么、放在哪、alt 文本）由 agent
事先写成 **brief 文件**，通过 `--brief-file` 传入。样例见
`scripts/fixtures/brief-sample.md`。

这条边界让矩阵测试可以脱离模型运行，也让三个 skill 的差异活在各自的
SKILL.md 里而不是脚本里。

用法：

```bash
cd scripts
python3 compose_prompt.py \
  --platform wechat --preset editorial-warm \
  --brief-file ../../../path/to/briefs/wechat/00-cover.md \
  --out ../../../path/to/prompts/wechat/00-cover.md \
  [--palette cool-slate] [--rendering soft-gouache] [--layout bento-grid]
```

平台不支持某 archetype（如微信 × `series`）时命令直接失败并说明原因，不静默回退。

## 还没做的事

- **`bilibili.yaml` 的数字未经官方核实** —— 文件已经有了（2026-08-19），建模的是**专栏**、不是视频投稿；
  画幅取自第三方教程与 B 站用户专栏，体积上限借的是视频封面的 5MB 作保守值。
  每个未核实的槽在 yaml 里都标了 `unverified`，谁有创作中心的实际提示请回来改。
  **视频封面（≈16:10）仍然没建模**：schema 每个平台只有一个 `cover` 槽，两种封面装不下，
  真要同时支持得往 `asset_lib.ARCHETYPES` 里加新 archetype——那是 spec 改动。
- **`presets/dimensions/layouts/` 只有一个值** —— `infographic` / `series` 现在都在用
  `_shared/`（`md2publish-visuals`），但两者共用同一个 `bento-grid`，尚未按品类分化出更多布局，需要时再补。
- **`costs.yaml` 全是 `unknown`** —— 真实单价同属外部知识，用户实测后自己填。
