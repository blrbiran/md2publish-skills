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

- **`bilibili.yaml`** —— B 站的画幅与文字约定属未验证的外部知识，
  需先分别确认视频封面与专栏头图的规格，不猜。
- **`presets/dimensions/layouts/` 只有一个值** —— `infographic` / `series`
  真正用起来（三期）时再补。
- **`costs.yaml` 全是 `unknown`** —— 真实单价同属外部知识，用户实测后自己填。
- **`md2publish-visuals` / `md2publish-diagram`** —— 三期。
- **对现有 skill 的改动** —— `md2publish-images` 的删除与九处引用修改属二期 B。
