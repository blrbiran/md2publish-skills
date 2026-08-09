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

## 前置

```bash
python3 --version          # 3.9+
python3 -c 'import yaml'   # 缺就 pip3 install pyyaml
```

PyYAML 是本层唯一的第三方依赖。

脚本用了 `dict | None` 这类 PEP 604 注解，靠 `from __future__ import annotations`
在 3.9 上工作——新增脚本时别漏掉那一行。

## 跑测试

```bash
./scripts/test-asset-schema.sh      # 资产 schema 校验（13 项）
./scripts/test-compose-prompt.sh    # 渲染器行为 + 占位符白名单（11 项）
./scripts/test-platform-matrix.sh   # 平台 × archetype × preset 全矩阵（8 组合）
```

**改了 `platforms/`、`presets/` 或 `scripts/` 里任何东西之后，三个都要跑一遍。**
本仓库没有 CI、没有 git hooks，这是一条**有文档约束的手工流程，不是自动闸门**。
二期会加 `scripts/check.sh` 把它们串起来，但那时也仍然是手工触发。

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

## 一期故意没做的事

以下都推到二期，不是遗漏：

- **`sync-shared.sh` / `check-shared-drift.sh` / `check.sh`** —— 此时没有任何 skill
  消费 `_shared/`，vendor 脚本只能对着想象中的目录结构写，二期必然重写。
- **`imagegen/`、`compress.py`、`preflight.py`** —— 二期从 `baoyu-image-gen` 搬入。
- **`costs.yaml`** —— 成本表服务于生成阶段的确认门，二期才用得上。
- **`bilibili.yaml`** —— B 站的画幅与文字约定属未验证的外部知识，
  实施前需分别确认视频封面与专栏头图的规格，不猜。
- **任何对现有 skill 的改动** —— 一期不碰 `md2publish-article` / `md2publish-draft` /
  `md2publish-images` / `wechat-finetune` / `skills/README.md`。
