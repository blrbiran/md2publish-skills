# 一期：`_shared/` 图片资产层与 prompt 渲染器 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立 `skills/_shared/` 图片资产层（平台 profile、preset、维度词表）和纯模板渲染器 `compose-prompt.py`，并用测试锁死 schema 与占位符契约。

**Architecture:** 平台差异（画幅、文字上图策略、体积上限）放进 `platforms/*.yaml` 并按 archetype 分槽；视觉风格放进 `presets/**/*.yaml` 并引用 `dimensions/` 词表。`compose-prompt.py` 是纯模板渲染器——读 YAML、填固定集合的占位符、写文件，不读文章原文、不调模型。文章语义由 agent 事先写成 brief 文件传入。

**Tech Stack:** Python 3（标准库 + PyYAML）、bash 测试脚本（沿用 `skills/md2publish-article/scripts/test-*.sh` 的写法）。

**设计依据:** `docs/superpowers/specs/2026-08-09-md2publish-image-skills-design.md`（第二版）。本期对应 spec §15 的「一期」，只实现 §4（`_shared/` 布局）、§5（资产 schema）、§6（机械/语义分界）、§13 第 1–3 项测试。

## Global Constraints

以下取自 spec，每个任务都隐含适用：

- **本期不修改任何现有 skill。** 不碰 `md2publish-article` / `md2publish-draft` / `md2publish-images` / `wechat-finetune` / `skills/README.md`。（spec §15 一期"破坏性：无"）
- **本期不写 `sync-shared.sh` / `check-shared-drift.sh` / `check.sh`。** 此时 `_shared/` 没有消费者，vendor 脚本只能对着想象中的目录结构写，二期必然重写。（spec §15）
- **`compose-prompt.py` 是纯模板渲染器**：不读文章原文、不做内容抽取、不调模型。（spec §6）
- **占位符是固定集合**：`{{PLATFORM_FRAME}}`、`{{PALETTE}}`、`{{RENDERING}}`、`{{LAYOUT}}`、`{{CONTENT}}`。集合外的占位符**硬失败**，不允许原样输出。（spec §5.2、§13 第 2 项）
- **`max_bytes` 一律整数字节**，不用 `2MB` 这类带后缀的字符串。（spec §5.1）
- **archetype 全集**：`cover`、`illustration`、`infographic`、`series`、`diagram`。平台 profile 的每个 archetype 槽要么完整定义，要么值为字符串 `unsupported`；composer 遇到 `unsupported` 硬失败。（spec §5.1）
- **preset 用 `incompatible_platforms`（排除制），默认 `[]`**，不用 `compatible_platforms` 白名单。（spec §5.2）
- **preset 必填字段**：`name`、`archetype`、`description`、`primary_use_case`、`version`、`metadata.author`、`metadata.provenance`、`template`。（spec §5.2）
- **prompt 语言一律中文**，模板与维度词表都不做中英双语。（spec §5.2）
- **`bilibili.yaml` 本期只建结构、取值标 TODO 是不允许的** —— 按 spec §14.5，B 站取值属未验证的外部知识，因此本期**不创建** `bilibili.yaml`，只保证 schema 能承载它。测试的平台集合是 `wechat` 和 `xiaohongshu` 两个。

---

## File Structure

| 文件 | 职责 |
|---|---|
| `skills/_shared/platforms/wechat.yaml` | 微信平台 profile，5 个 archetype 槽 |
| `skills/_shared/platforms/xiaohongshu.yaml` | 小红书平台 profile，5 个 archetype 槽 |
| `skills/_shared/presets/dimensions/palettes/*.md` | 配色词表，每个文件是一段可直接嵌进 prompt 的中文描述 |
| `skills/_shared/presets/dimensions/renderings/*.md` | 渲染风格词表，同上 |
| `skills/_shared/presets/dimensions/layouts/*.md` | 版式词表，同上 |
| `skills/_shared/presets/cover/*.yaml` | 封面 preset |
| `skills/_shared/presets/infographic/*.yaml` | 信息图 preset |
| `skills/_shared/presets/illustration/*.yaml` | 正文插图 preset |
| `skills/_shared/presets/series/*.yaml` | 卡片系列 preset |
| `skills/_shared/presets/INDEX.md` | preset 与 dimensions 的唯一发现入口 |
| `skills/_shared/scripts/compose_prompt.py` | 纯模板渲染器（CLI + 可导入函数） |
| `skills/_shared/scripts/asset_lib.py` | 资产加载与校验（被 composer 和测试共用） |
| `skills/_shared/scripts/test-compose-prompt.sh` | 渲染器行为测试（含占位符白名单） |
| `skills/_shared/scripts/test-asset-schema.sh` | 资产 schema 校验测试 |
| `skills/_shared/scripts/test-platform-matrix.sh` | 平台 × archetype × preset 矩阵测试 |
| `skills/_shared/scripts/fixtures/brief-sample.md` | 测试用 brief，替代真实文章 |

`asset_lib.py` 与 `compose_prompt.py` 分开，是因为 schema 校验（测试用）和渲染（运行用）会被不同调用方使用，且 spec §13 第 3 项的 schema 测试必须能脱离渲染流程单独跑。

文件名用下划线（`compose_prompt.py`）而非连字符，因为 `asset_lib.py` 需要 `import` 它的兄弟模块——`md2publish-article/scripts/` 里 `theme_lib.py` 是同样的处理。spec §4 写的是 `compose-prompt.py`，本计划按 Python 可导入性改为下划线，属实现细节偏离，无需回改 spec。

---

## Task 1: 资产加载与 schema 校验库

**Files:**
- Create: `skills/_shared/scripts/asset_lib.py`
- Create: `skills/_shared/scripts/test-asset-schema.sh`
- Create: `skills/_shared/platforms/wechat.yaml`
- Create: `skills/_shared/platforms/xiaohongshu.yaml`

**Interfaces:**
- Consumes: 无（首个任务）
- Produces:
  - `ARCHETYPES: list[str]` — `["cover", "illustration", "infographic", "series", "diagram"]`
  - `PLACEHOLDERS: set[str]` — `{"PLATFORM_FRAME", "PALETTE", "RENDERING", "LAYOUT", "CONTENT"}`
  - `shared_root() -> pathlib.Path` — 返回 `_shared/` 目录绝对路径
  - `load_platform(name: str) -> dict` — 读 `platforms/<name>.yaml`，校验后返回；校验失败抛 `AssetError`
  - `list_platforms() -> list[str]` — 返回 `platforms/` 下所有 `.yaml` 的 stem，已排序
  - `class AssetError(Exception)` — 所有资产校验失败统一抛这个
  - `archetype_slot(platform: dict, archetype: str) -> dict | None` — 返回该槽的配置 dict；槽值为 `"unsupported"` 时返回 `None`；archetype 不在 profile 里抛 `AssetError`

- [ ] **Step 1: 写失败的测试**

创建 `skills/_shared/scripts/test-asset-schema.sh`：

```bash
#!/usr/bin/env bash
# 资产 schema 校验测试。对应 spec §13 第 3 项。
set -uo pipefail
cd "$(dirname "$0")"

PASS=0
FAIL=0
ok()   { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad()  { echo "  ❌ $1"; echo "     $2"; FAIL=$((FAIL+1)); }

run_py() { python3 -c "$1" 2>&1; }

echo "== platform profile 校验 =="

out=$(run_py '
import asset_lib as a
ps = a.list_platforms()
assert ps == ["wechat", "xiaohongshu"], ps
print("OK")
')
[[ "$out" == "OK" ]] && ok "list_platforms 返回 wechat/xiaohongshu" || bad "list_platforms" "$out"

out=$(run_py '
import asset_lib as a
for name in a.list_platforms():
    p = a.load_platform(name)
    for arch in a.ARCHETYPES:
        a.archetype_slot(p, arch)   # 不抛异常即为每个 archetype 都有定义
print("OK")
')
[[ "$out" == "OK" ]] && ok "每个平台都定义了全部 5 个 archetype 槽" || bad "archetype 槽完整性" "$out"

out=$(run_py '
import asset_lib as a
p = a.load_platform("wechat")
assert a.archetype_slot(p, "series") is None, "wechat.series 应为 unsupported"
assert a.archetype_slot(p, "cover") is not None
print("OK")
')
[[ "$out" == "OK" ]] && ok "unsupported 槽返回 None" || bad "unsupported 处理" "$out"

out=$(run_py '
import asset_lib as a
p = a.load_platform("wechat")
try:
    a.archetype_slot(p, "nonexistent")
except a.AssetError:
    print("OK")
else:
    print("未抛 AssetError")
')
[[ "$out" == "OK" ]] && ok "未知 archetype 抛 AssetError" || bad "未知 archetype" "$out"

out=$(run_py '
import asset_lib as a
for name in a.list_platforms():
    p = a.load_platform(name)
    for arch in a.ARCHETYPES:
        slot = a.archetype_slot(p, arch)
        if slot is None:
            continue
        mb = slot["max_bytes"]
        assert isinstance(mb, int), f"{name}.{arch}.max_bytes 不是整数: {mb!r}"
        assert mb > 0
print("OK")
')
[[ "$out" == "OK" ]] && ok "max_bytes 全是正整数" || bad "max_bytes 类型" "$out"

out=$(run_py '
import asset_lib as a
for name in a.list_platforms():
    p = a.load_platform(name)
    for arch in a.ARCHETYPES:
        slot = a.archetype_slot(p, arch)
        if slot is None:
            continue
        t = slot["text_on_image"]
        assert isinstance(t, dict), f"{name}.{arch}.text_on_image 不是结构: {t!r}"
        assert isinstance(t["title"], bool)
        assert isinstance(t["subtitle"], bool)
print("OK")
')
[[ "$out" == "OK" ]] && ok "text_on_image 是含 title/subtitle 布尔的结构" || bad "text_on_image 结构" "$out"

echo
echo "通过 $PASS 项，失败 $FAIL 项"
[[ $FAIL -eq 0 ]]
```

```bash
chmod +x skills/_shared/scripts/test-asset-schema.sh
```

- [ ] **Step 2: 运行测试确认它失败**

Run: `./skills/_shared/scripts/test-asset-schema.sh`
Expected: FAIL，全部 6 项报 `ModuleNotFoundError: No module named 'asset_lib'`

- [ ] **Step 3: 写两个 platform profile**

创建 `skills/_shared/platforms/wechat.yaml`：

```yaml
name: wechat
display_name: 微信公众号
archetypes:
  cover:
    aspect: "16:9"
    max_bytes: 2097152
    crop_warning: 头条按 2.35:1 裁，次条按 1:1 裁，重要视觉元素放画面中央
    text_on_image:
      title: false
      subtitle: false
      notes: 标题由草稿 title 字段承载，图上再放一次就是重复标题
  illustration:
    aspect: ["16:9", "4:3"]
    count_range: [3, 8]
    max_bytes: 10485760
    text_on_image:
      title: false
      subtitle: false
      notes: 正文插图不承载标题，避免与小标题重复
  infographic:
    aspect: "4:3"
    max_bytes: 10485760
    text_on_image:
      title: true
      subtitle: true
      notes: 信息图的文字是内容本体，必须清晰可读
  series: unsupported
  diagram:
    aspect: ["16:9", "4:3"]
    max_bytes: 10485760
    raster_format: png
    text_on_image:
      title: false
      subtitle: false
      notes: 示意图的文字是节点与连线标签，不是标题
```

创建 `skills/_shared/platforms/xiaohongshu.yaml`：

```yaml
name: xiaohongshu
display_name: 小红书
archetypes:
  cover:
    aspect: "3:4"
    max_bytes: 20971520
    safe_area: 上下各留 12%，标题置于上 1/3
    text_on_image:
      title: true
      subtitle: true
      notes: 首图不放大字标题基本没人点
  illustration: unsupported
  infographic:
    aspect: "3:4"
    max_bytes: 20971520
    text_on_image:
      title: true
      subtitle: true
      notes: 信息图的文字是内容本体，必须清晰可读
  series:
    aspect: "3:4"
    count_range: [1, 18]
    first_is_cover: true
    max_bytes: 20971520
    text_on_image:
      title: true
      subtitle: true
      notes: 第 1 张承载标题，第 2..N 张各承载一个分点
  diagram:
    aspect: "3:4"
    max_bytes: 20971520
    raster_format: png
    text_on_image:
      title: false
      subtitle: false
      notes: 示意图的文字是节点与连线标签，不是标题
```

- [ ] **Step 4: 写 `asset_lib.py` 的最小实现**

创建 `skills/_shared/scripts/asset_lib.py`：

```python
"""共享图片资产的加载与校验。被 compose_prompt.py 和各测试脚本共用。"""

# 必需：本文件用了 `dict | None` 这类 PEP 604 注解，而目标环境是 Python 3.9，
# 3.9 会在 import 时对它求值并抛 TypeError。这行把注解变成惰性字符串。
from __future__ import annotations

from pathlib import Path

import yaml

ARCHETYPES = ["cover", "illustration", "infographic", "series", "diagram"]
PLACEHOLDERS = {"PLATFORM_FRAME", "PALETTE", "RENDERING", "LAYOUT", "CONTENT"}
UNSUPPORTED = "unsupported"


class AssetError(Exception):
    """资产结构不合法。所有校验失败统一抛这个。"""


def shared_root() -> Path:
    return Path(__file__).resolve().parent.parent


def list_platforms() -> list[str]:
    return sorted(p.stem for p in (shared_root() / "platforms").glob("*.yaml"))


def load_platform(name: str) -> dict:
    path = shared_root() / "platforms" / f"{name}.yaml"
    if not path.exists():
        raise AssetError(f"平台 profile 不存在: {path}")
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    _validate_platform(name, data)
    return data


def _validate_platform(name: str, data: dict) -> None:
    for key in ("name", "display_name", "archetypes"):
        if key not in data:
            raise AssetError(f"{name}.yaml 缺字段 {key}")
    slots = data["archetypes"]
    missing = [a for a in ARCHETYPES if a not in slots]
    if missing:
        raise AssetError(f"{name}.yaml 缺 archetype 槽: {missing}")
    for arch, slot in slots.items():
        if arch not in ARCHETYPES:
            raise AssetError(f"{name}.yaml 有未知 archetype: {arch}")
        if slot == UNSUPPORTED:
            continue
        _validate_slot(name, arch, slot)


def _validate_slot(platform: str, arch: str, slot: dict) -> None:
    where = f"{platform}.archetypes.{arch}"
    if not isinstance(slot, dict):
        raise AssetError(f"{where} 必须是 dict 或字符串 '{UNSUPPORTED}'，实为 {slot!r}")
    if "aspect" not in slot:
        raise AssetError(f"{where} 缺 aspect")
    mb = slot.get("max_bytes")
    if not isinstance(mb, int) or isinstance(mb, bool) or mb <= 0:
        raise AssetError(f"{where}.max_bytes 必须是正整数字节，实为 {mb!r}")
    text = slot.get("text_on_image")
    if not isinstance(text, dict):
        raise AssetError(f"{where}.text_on_image 必须是结构，实为 {text!r}")
    for key in ("title", "subtitle"):
        if not isinstance(text.get(key), bool):
            raise AssetError(f"{where}.text_on_image.{key} 必须是布尔，实为 {text.get(key)!r}")


def archetype_slot(platform: dict, archetype: str) -> dict | None:
    """返回该 archetype 的槽配置；平台不支持时返回 None。"""
    if archetype not in ARCHETYPES:
        raise AssetError(f"未知 archetype: {archetype}")
    slots = platform["archetypes"]
    if archetype not in slots:
        raise AssetError(f"{platform['name']} 未定义 archetype 槽: {archetype}")
    slot = slots[archetype]
    return None if slot == UNSUPPORTED else slot
```

- [ ] **Step 5: 运行测试确认通过**

Run: `./skills/_shared/scripts/test-asset-schema.sh`
Expected: PASS，`通过 6 项，失败 0 项`，exit 0

若报 `ModuleNotFoundError: No module named 'yaml'`：`pip3 install pyyaml`。这是本期唯一的第三方依赖，把它记进 Task 6 的 README。

- [ ] **Step 6: 提交**

```bash
git add skills/_shared/platforms/ skills/_shared/scripts/asset_lib.py skills/_shared/scripts/test-asset-schema.sh
git commit -m "一期 T1：平台 profile 与资产校验库

按 archetype 分槽，每个平台必须定义全部 5 个槽（含显式 unsupported）。
max_bytes 用整数字节，text_on_image 用结构而非枚举——单个枚举值表达不了
小红书系列里第 1 张和第 2..N 张的文字角色不同。"
```

---

## Task 2: 维度词表与 preset schema 校验

**Files:**
- Create: `skills/_shared/presets/dimensions/palettes/warm-earth.md`
- Create: `skills/_shared/presets/dimensions/palettes/cool-slate.md`
- Create: `skills/_shared/presets/dimensions/renderings/flat-vector.md`
- Create: `skills/_shared/presets/dimensions/renderings/soft-gouache.md`
- Create: `skills/_shared/presets/dimensions/layouts/bento-grid.md`
- Create: `skills/_shared/presets/cover/editorial-warm.yaml`
- Create: `skills/_shared/presets/infographic/bento-cool.yaml`
- Create: `skills/_shared/presets/illustration/inline-warm.yaml`
- Create: `skills/_shared/presets/series/card-warm.yaml`
- Modify: `skills/_shared/scripts/asset_lib.py`（追加 preset 相关函数）
- Modify: `skills/_shared/scripts/test-asset-schema.sh`（追加 preset 校验段）

**Interfaces:**
- Consumes: Task 1 的 `AssetError`、`ARCHETYPES`、`shared_root()`
- Produces:
  - `PRESET_REQUIRED_FIELDS: list[str]` — `["name", "archetype", "description", "primary_use_case", "version", "metadata", "template"]`
  - `list_presets(archetype: str | None = None) -> list[str]` — 返回 preset 名（不含扩展名），已排序；`archetype` 为 None 时返回全部
  - `load_preset(name: str) -> dict` — 按名字在全部 archetype 子目录里查找并加载，校验后返回；找不到或校验失败抛 `AssetError`
  - `load_dimension(kind: str, value: str) -> str` — 读 `dimensions/<kind>/<value>.md` 的正文（去掉首尾空白）；`kind` ∈ `{"palettes", "renderings", "layouts"}`；文件不存在抛 `AssetError`
  - `preset_supports(preset: dict, platform_name: str) -> bool` — `platform_name not in preset.get("incompatible_platforms", [])`

- [ ] **Step 1: 写失败的测试**

在 `skills/_shared/scripts/test-asset-schema.sh` 的 `echo` 汇总行**之前**插入：

```bash
echo
echo "== preset schema 校验 =="

out=$(run_py '
import asset_lib as a
names = a.list_presets()
assert len(names) >= 4, names
for n in names:
    p = a.load_preset(n)
    for f in a.PRESET_REQUIRED_FIELDS:
        assert f in p, f"{n} 缺字段 {f}"
    assert p["metadata"].get("author"), f"{n} 缺 metadata.author"
    assert p["metadata"].get("provenance"), f"{n} 缺 metadata.provenance"
print("OK")
')
[[ "$out" == "OK" ]] && ok "所有 preset 必填字段齐全（含 primary_use_case）" || bad "preset 必填字段" "$out"

out=$(run_py '
import asset_lib as a
for n in a.list_presets():
    p = a.load_preset(n)
    arch = p["archetype"]
    assert arch in a.ARCHETYPES, n + " archetype 非法: " + str(arch)
    assert "compatible_platforms" not in p, n + " 用了白名单 compatible_platforms，应改用 incompatible_platforms"
    assert isinstance(p.get("incompatible_platforms", []), list)
print("OK")
')
[[ "$out" == "OK" ]] && ok "archetype 合法且用排除制而非白名单" || bad "preset archetype/平台字段" "$out"

out=$(run_py '
import asset_lib as a
KINDS = {"palette": "palettes", "rendering": "renderings", "layout": "layouts"}
for n in a.list_presets():
    p = a.load_preset(n)
    for field, kind in KINDS.items():
        val = p.get(field)
        if val is None:
            continue
        body = a.load_dimension(kind, val)
        assert body, f"{n}.{field} -> {kind}/{val}.md 是空文件"
print("OK")
')
[[ "$out" == "OK" ]] && ok "preset 引用的 dimensions 文件都存在且非空" || bad "dimensions 引用" "$out"

out=$(run_py '
import asset_lib as a
known = set(a.list_platforms())
for n in a.list_presets():
    p = a.load_preset(n)
    for plat in p.get("incompatible_platforms", []):
        assert plat in known, f"{n}.incompatible_platforms 含未知平台: {plat}"
print("OK")
')
[[ "$out" == "OK" ]] && ok "incompatible_platforms 里的平台都存在" || bad "incompatible_platforms" "$out"

out=$(run_py '
import asset_lib as a
try:
    a.load_dimension("palettes", "no-such-palette")
except a.AssetError:
    print("OK")
else:
    print("未抛 AssetError")
')
[[ "$out" == "OK" ]] && ok "缺失的 dimension 抛 AssetError" || bad "dimension 缺失处理" "$out"
```

- [ ] **Step 2: 运行测试确认新增段失败**

Run: `./skills/_shared/scripts/test-asset-schema.sh`
Expected: 前 6 项 PASS，新增 5 项 FAIL，报 `AttributeError: module 'asset_lib' has no attribute 'list_presets'`

- [ ] **Step 3: 写维度词表**

创建 `skills/_shared/presets/dimensions/palettes/warm-earth.md`：

```markdown
配色：暖土色系。主色为烧赭与陶土橙，辅以米白与浅驼作底，点缀低饱和的墨绿。
整体明度偏中高，对比柔和，不出现纯黑与纯白。避免荧光色与高饱和撞色。
```

创建 `skills/_shared/presets/dimensions/palettes/cool-slate.md`：

```markdown
配色：冷石板色系。主色为石板蓝与钢灰，辅以雾白作底，点缀一处克制的琥珀色作为视觉焦点。
整体明度偏中低，对比清晰但不刺眼。避免暖黄与大面积高饱和色块。
```

创建 `skills/_shared/presets/dimensions/renderings/flat-vector.md`：

```markdown
渲染：扁平矢量。纯色块与简洁几何形，无渐变、无投影、无材质纹理。
边缘干净利落，图形可辨识度优先于细节丰富度。线条统一粗细。
```

创建 `skills/_shared/presets/dimensions/renderings/soft-gouache.md`：

```markdown
渲染：柔和水粉。可见笔触与轻微颗粒感，色块边缘略有晕染，不追求绝对平整。
保留手绘的不规则感，但形体结构清晰，不糊成一团。
```

创建 `skills/_shared/presets/dimensions/layouts/bento-grid.md`：

```markdown
版式：便当格。画面切分为大小不等的矩形格子，格子间留有均匀间隙。
主信息占据最大的格子，次级信息分布在小格中。每格内部左对齐，格与格之间不跨界。
```

- [ ] **Step 4: 写四个 preset**

创建 `skills/_shared/presets/cover/editorial-warm.yaml`：

```yaml
name: editorial-warm
archetype: cover
description: 杂志编辑风封面，暖色调
primary_use_case: 人文随笔与商业观察类长文的封面
version: 1.0.0
palette: warm-earth
rendering: flat-vector
layout: null
incompatible_platforms: []
metadata:
  author: md2publish-skills
  provenance: 改编自 md2wechat cover-editorial + baoyu-cover-image 维度体系
template: |
  {{PLATFORM_FRAME}}
  {{PALETTE}}
  {{RENDERING}}
  {{CONTENT}}
```

创建 `skills/_shared/presets/infographic/bento-cool.yaml`：

```yaml
name: bento-cool
archetype: infographic
description: 便当格信息图，冷色调
primary_use_case: 需要并列展示 4–8 个要点的技术类内容
version: 1.0.0
palette: cool-slate
rendering: flat-vector
layout: bento-grid
incompatible_platforms: []
metadata:
  author: md2publish-skills
  provenance: 改编自 md2wechat infographic-bento
template: |
  {{PLATFORM_FRAME}}
  {{PALETTE}}
  {{RENDERING}}
  {{LAYOUT}}
  {{CONTENT}}
```

创建 `skills/_shared/presets/illustration/inline-warm.yaml`：

```yaml
name: inline-warm
archetype: illustration
description: 正文插图，暖色水粉
primary_use_case: 长文中段落之间的呼吸性插图，不承载信息密度
version: 1.0.0
palette: warm-earth
rendering: soft-gouache
layout: null
incompatible_platforms: [xiaohongshu]
metadata:
  author: md2publish-skills
  provenance: 改编自 baoyu-article-illustrator 的 Type × Style × Palette 体系
template: |
  {{PLATFORM_FRAME}}
  {{PALETTE}}
  {{RENDERING}}
  {{CONTENT}}
```

`incompatible_platforms: [xiaohongshu]` 与 `xiaohongshu.archetypes.illustration: unsupported` 是同一件事的两侧表达，Task 4 的矩阵测试会验证两者一致。

创建 `skills/_shared/presets/series/card-warm.yaml`：

```yaml
name: card-warm
archetype: series
description: 卡片系列，暖色扁平
primary_use_case: 把一篇长文拆成 5–10 张可独立阅读的图卡
version: 1.0.0
palette: warm-earth
rendering: flat-vector
layout: bento-grid
incompatible_platforms: [wechat]
metadata:
  author: md2publish-skills
  provenance: 改编自 baoyu-xhs-images 的 12 风格 × 8 布局体系
template: |
  {{PLATFORM_FRAME}}
  {{PALETTE}}
  {{RENDERING}}
  {{LAYOUT}}
  {{CONTENT}}
```

- [ ] **Step 5: 给 `asset_lib.py` 追加 preset 与 dimension 支持**

在 `skills/_shared/scripts/asset_lib.py` 的 `UNSUPPORTED = "unsupported"` 之后追加：

```python
PRESET_REQUIRED_FIELDS = [
    "name",
    "archetype",
    "description",
    "primary_use_case",
    "version",
    "metadata",
    "template",
]
DIMENSION_KINDS = {"palettes", "renderings", "layouts"}
```

在文件末尾追加：

```python
def list_presets(archetype: str | None = None) -> list[str]:
    root = shared_root() / "presets"
    subdirs = [root / archetype] if archetype else [root / a for a in ARCHETYPES]
    names = []
    for d in subdirs:
        if d.is_dir():
            names.extend(p.stem for p in d.glob("*.yaml"))
    return sorted(names)


def load_preset(name: str) -> dict:
    root = shared_root() / "presets"
    for arch in ARCHETYPES:
        path = root / arch / f"{name}.yaml"
        if path.exists():
            data = yaml.safe_load(path.read_text(encoding="utf-8"))
            _validate_preset(name, data)
            return data
    raise AssetError(f"preset 不存在: {name}")


def _validate_preset(name: str, data: dict) -> None:
    if not isinstance(data, dict):
        raise AssetError(f"{name}.yaml 不是 mapping")
    missing = [f for f in PRESET_REQUIRED_FIELDS if f not in data]
    if missing:
        raise AssetError(f"{name}.yaml 缺必填字段: {missing}")
    if data["archetype"] not in ARCHETYPES:
        raise AssetError(f"{name}.yaml archetype 非法: {data['archetype']}")
    if "compatible_platforms" in data:
        raise AssetError(
            f"{name}.yaml 用了白名单 compatible_platforms；"
            "应改用排除制 incompatible_platforms，否则每加一个平台都要回头改所有 preset"
        )
    incompat = data.get("incompatible_platforms", [])
    if not isinstance(incompat, list):
        raise AssetError(f"{name}.yaml incompatible_platforms 必须是列表")
    meta = data.get("metadata")
    if not isinstance(meta, dict):
        raise AssetError(f"{name}.yaml metadata 必须是 mapping")
    for key in ("author", "provenance"):
        if not meta.get(key):
            raise AssetError(f"{name}.yaml 缺 metadata.{key}")


def load_dimension(kind: str, value: str) -> str:
    if kind not in DIMENSION_KINDS:
        raise AssetError(f"未知 dimension 类别: {kind}")
    path = shared_root() / "presets" / "dimensions" / kind / f"{value}.md"
    if not path.exists():
        raise AssetError(f"dimension 不存在: {kind}/{value}.md")
    return path.read_text(encoding="utf-8").strip()


def preset_supports(preset: dict, platform_name: str) -> bool:
    return platform_name not in preset.get("incompatible_platforms", [])
```

- [ ] **Step 6: 运行测试确认全部通过**

Run: `./skills/_shared/scripts/test-asset-schema.sh`
Expected: PASS，`通过 11 项，失败 0 项`，exit 0

- [ ] **Step 7: 提交**

```bash
git add skills/_shared/presets/ skills/_shared/scripts/asset_lib.py skills/_shared/scripts/test-asset-schema.sh
git commit -m "一期 T2：维度词表、四个 preset 与 preset schema 校验

必填字段含 primary_use_case（md2wechat 防漂移原则点名的字段）。
显式拒绝 compatible_platforms 白名单——加第 4 个平台要回头改每个 preset，
正是不用手工维护共享资产的那个成本。"
```

---

## Task 3: prompt 渲染器

**Files:**
- Create: `skills/_shared/scripts/compose_prompt.py`
- Create: `skills/_shared/scripts/fixtures/brief-sample.md`
- Create: `skills/_shared/scripts/test-compose-prompt.sh`

**Interfaces:**
- Consumes: Task 1 与 Task 2 的 `asset_lib` 全部导出
- Produces:
  - `render_platform_frame(slot: dict, platform: dict) -> str` — 把 archetype 槽渲染成中文画幅约束段
  - `compose(platform_name: str, preset_name: str, brief: str, overrides: dict) -> str` — 返回渲染后的 prompt 文本；`overrides` 形如 `{"palette": "cool-slate"}`，键 ∈ `{"palette", "rendering", "layout"}`
  - CLI：`python3 compose_prompt.py --platform <name> --preset <name> --brief-file <path> --out <path> [--palette V] [--rendering V] [--layout V]`；成功 exit 0 并把路径打到 stdout，失败 exit 1 并把原因打到 stderr

- [ ] **Step 1: 写 fixture brief**

创建 `skills/_shared/scripts/fixtures/brief-sample.md`：

```markdown
主题：为什么大多数缓存失效 bug 出在写入路径而不是读取路径。
主体：一条分叉的管道，左支贴着"读"的标签且畅通，右支贴着"写"的标签且有一处堵塞。
情绪：冷静的技术分析，不夸张、不卖惨。
alt：一条分叉管道示意图，左支畅通标注为读，右支有堵塞标注为写。
```

这份 brief 替代真实文章，让矩阵测试脱离模型运行。它体现了 §6 的分界：brief 里已经是**语义结论**（主体是什么、情绪如何），不是文章原文。

- [ ] **Step 2: 写失败的测试**

创建 `skills/_shared/scripts/test-compose-prompt.sh`：

```bash
#!/usr/bin/env bash
# 渲染器行为测试。对应 spec §13 第 2 项（占位符白名单）与 §6（纯模板渲染）。
set -uo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp -d)
ROGUE=../presets/cover/__rogue.yaml
# 占位符白名单那段会临时往真实 presets 目录塞一个非法 preset。
# 必须进 trap——中途崩了留下残留文件会让 test-asset-schema.sh 的 INDEX 检查误报。
trap 'rm -rf "$TMP"; rm -f "$ROGUE"' EXIT

PASS=0
FAIL=0
ok()  { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad() { echo "  ❌ $1"; echo "     $2"; FAIL=$((FAIL+1)); }

BRIEF=fixtures/brief-sample.md

echo "== 渲染基本行为 =="

out=$(python3 compose_prompt.py --platform wechat --preset editorial-warm \
        --brief-file "$BRIEF" --out "$TMP/a.md" 2>&1)
if [[ $? -eq 0 && -s "$TMP/a.md" ]]; then ok "渲染成功且产物非空"; else bad "渲染失败" "$out"; fi

body=$(cat "$TMP/a.md" 2>/dev/null || true)
if ! grep -q '{{' <<<"$body"; then ok "产物中没有残留占位符"; else bad "占位符残留" "$(grep -o '{{[A-Z_]*}}' <<<"$body" | sort -u)"; fi
if grep -q '16:9' <<<"$body"; then ok "平台画幅已注入"; else bad "画幅未注入" "产物里找不到 16:9"; fi
if grep -q '烧赭' <<<"$body"; then ok "palette 维度已注入"; else bad "palette 未注入" "找不到 warm-earth 的内容"; fi
if grep -q '扁平矢量' <<<"$body"; then ok "rendering 维度已注入"; else bad "rendering 未注入" "找不到 flat-vector 的内容"; fi
if grep -q '缓存失效' <<<"$body"; then ok "brief 内容已注入"; else bad "brief 未注入" "找不到 brief 里的主题"; fi
if grep -q '不放' <<<"$body"; then ok "text_on_image 策略已注入"; else bad "文字策略未注入" "找不到微信的不放标题约束"; fi

echo
echo "== 维度覆盖 =="

python3 compose_prompt.py --platform wechat --preset editorial-warm \
    --brief-file "$BRIEF" --palette cool-slate --out "$TMP/b.md" >/dev/null 2>&1
body=$(cat "$TMP/b.md" 2>/dev/null || true)
if grep -q '石板蓝' <<<"$body" && ! grep -q '烧赭' <<<"$body"; then
  ok "--palette 覆盖生效且原 palette 未残留"
else
  bad "--palette 覆盖" "产物未换成 cool-slate"
fi

out=$(python3 compose_prompt.py --platform wechat --preset editorial-warm \
        --brief-file "$BRIEF" --palette no-such-palette --out "$TMP/c.md" 2>&1)
if [[ $? -ne 0 ]] && grep -q 'no-such-palette' <<<"$out"; then
  ok "覆盖值不存在时硬失败并点名"
else
  bad "非法覆盖值未拦住" "$out"
fi

echo
echo "== 占位符白名单（spec §13 第 2 项）=="

cat > "$TMP/bad-preset.yaml" <<'YAML'
name: rogue
archetype: cover
description: 含非法占位符的 preset
primary_use_case: 仅用于测试
version: 0.0.1
palette: warm-earth
rendering: flat-vector
layout: null
incompatible_platforms: []
metadata:
  author: test
  provenance: test fixture
template: |
  {{PLATFORM_FRAME}}
  {{MOOD}}
  {{CONTENT}}
YAML
cp "$TMP/bad-preset.yaml" "$ROGUE"
out=$(python3 compose_prompt.py --platform wechat --preset __rogue \
        --brief-file "$BRIEF" --out "$TMP/d.md" 2>&1)
rc=$?
rm -f "$ROGUE"
if [[ $rc -ne 0 ]] && grep -q 'MOOD' <<<"$out"; then
  ok "未知占位符硬失败并点名 MOOD"
else
  bad "未知占位符未拦住（会导致静默降级）" "rc=$rc out=$out"
fi

echo
echo "== unsupported 组合 =="

out=$(python3 compose_prompt.py --platform wechat --preset card-warm \
        --brief-file "$BRIEF" --out "$TMP/e.md" 2>&1)
if [[ $? -ne 0 ]] && grep -qi 'unsupported\|不支持' <<<"$out"; then
  ok "wechat × series 硬失败"
else
  bad "unsupported 组合未拦住" "$out"
fi

echo
echo "通过 $PASS 项，失败 $FAIL 项"
[[ $FAIL -eq 0 ]]
```

```bash
chmod +x skills/_shared/scripts/test-compose-prompt.sh
```

- [ ] **Step 3: 运行测试确认它失败**

Run: `./skills/_shared/scripts/test-compose-prompt.sh`
Expected: FAIL，报 `can't open file 'compose_prompt.py'`

- [ ] **Step 4: 写 `compose_prompt.py`**

创建 `skills/_shared/scripts/compose_prompt.py`：

```python
#!/usr/bin/env python3
"""把 platform profile + preset + 维度覆盖 + brief 渲染成最终 prompt。

纯模板渲染器：不读文章原文、不做内容抽取、不调模型。
文章的语义部分由 agent 事先写成 brief 文件传入。
"""

import argparse
import re
import sys

import asset_lib as a

PLACEHOLDER_RE = re.compile(r"\{\{([A-Z_]+)\}\}")
OVERRIDABLE = {"palette": "palettes", "rendering": "renderings", "layout": "layouts"}


def render_platform_frame(slot: dict, platform: dict) -> str:
    aspect = slot["aspect"]
    aspect_text = " 或 ".join(aspect) if isinstance(aspect, list) else aspect
    lines = [f"目标平台：{platform['display_name']}。画幅 {aspect_text}。"]

    text = slot["text_on_image"]
    wants = [n for n, k in (("标题", "title"), ("副标题", "subtitle")) if text[k]]
    if wants:
        lines.append(f"图上必须包含{'与'.join(wants)}，文字要大且清晰可读。")
    else:
        lines.append("图上不要出现标题文字。")
    if text.get("notes"):
        lines.append(text["notes"] + "。")

    for key, label in (("safe_area", "安全区"), ("crop_warning", "裁切"), ("count_range", "张数")):
        if slot.get(key):
            val = slot[key]
            if key == "count_range":
                lines.append(f"{label}：{val[0]}–{val[1]} 张。")
            else:
                lines.append(f"{label}：{val}。")
    if slot.get("first_is_cover"):
        lines.append("第 1 张同时充当封面，需独立成立。")
    return "\n".join(lines)


def compose(platform_name: str, preset_name: str, brief: str, overrides: dict) -> str:
    platform = a.load_platform(platform_name)
    preset = a.load_preset(preset_name)
    archetype = preset["archetype"]

    slot = a.archetype_slot(platform, archetype)
    if slot is None:
        raise a.AssetError(
            f"{platform_name} 不支持 archetype '{archetype}'（槽值为 unsupported），"
            f"因此无法使用 preset '{preset_name}'"
        )
    if not a.preset_supports(preset, platform_name):
        raise a.AssetError(f"preset '{preset_name}' 在 incompatible_platforms 中排除了 {platform_name}")

    values = {"PLATFORM_FRAME": render_platform_frame(slot, platform), "CONTENT": brief}
    for field, kind in OVERRIDABLE.items():
        chosen = overrides.get(field) or preset.get(field)
        if chosen:
            values[field.upper()] = a.load_dimension(kind, chosen)

    template = preset["template"]
    used = set(PLACEHOLDER_RE.findall(template))
    unknown = used - a.PLACEHOLDERS
    if unknown:
        raise a.AssetError(
            f"preset '{preset_name}' 的模板含未知占位符 {sorted(unknown)}；"
            f"合法集合为 {sorted(a.PLACEHOLDERS)}"
        )
    missing = used - set(values)
    if missing:
        raise a.AssetError(
            f"preset '{preset_name}' 的模板用了 {sorted(missing)}，"
            "但该维度在 preset 里为空且未通过命令行覆盖"
        )

    return PLACEHOLDER_RE.sub(lambda m: values[m.group(1)], template).strip() + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(description="渲染图片 prompt（纯模板渲染，不调模型）")
    ap.add_argument("--platform", required=True)
    ap.add_argument("--preset", required=True)
    ap.add_argument("--brief-file", required=True, help="agent 写的 brief，不是文章原文")
    ap.add_argument("--out", required=True)
    for field in OVERRIDABLE:
        ap.add_argument(f"--{field}", default=None)
    args = ap.parse_args()

    try:
        brief = open(args.brief_file, encoding="utf-8").read().strip()
    except OSError as e:
        print(f"读不了 brief 文件: {e}", file=sys.stderr)
        return 1

    overrides = {f: getattr(args, f) for f in OVERRIDABLE if getattr(args, f)}
    try:
        text = compose(args.platform, args.preset, brief, overrides)
    except a.AssetError as e:
        print(str(e), file=sys.stderr)
        return 1

    from pathlib import Path

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text, encoding="utf-8")
    print(str(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 5: 运行测试确认通过**

Run: `./skills/_shared/scripts/test-compose-prompt.sh`
Expected: PASS，`通过 11 项，失败 0 项`，exit 0

- [ ] **Step 6: 提交**

```bash
git add skills/_shared/scripts/compose_prompt.py skills/_shared/scripts/fixtures/ skills/_shared/scripts/test-compose-prompt.sh
git commit -m "一期 T3：prompt 渲染器

纯模板渲染：不读文章、不调模型，语义部分由 agent 写成 brief 传入。
未知占位符硬失败而非原样输出——原样输出会让图少掉一半约束，
而且肉眼看不出来。"
```

---

## Task 4: 平台 × archetype × preset 矩阵测试

**Files:**
- Create: `skills/_shared/scripts/test-platform-matrix.sh`

**Interfaces:**
- Consumes: Task 1–3 的全部产物
- Produces: 无（纯测试）

这是 spec §13 第 1 项，也是**最容易静默漂移的地方**：preset 加了占位符但 composer 不认，出来的图就少一半约束，而且肉眼看不出来。矩阵测试断言每个组合要么产出注入了平台字段的 prompt，要么因 `unsupported` 明确失败——没有第三种结果。

- [ ] **Step 1: 写测试**

创建 `skills/_shared/scripts/test-platform-matrix.sh`：

```bash
#!/usr/bin/env bash
# 平台 × archetype × preset 全矩阵。对应 spec §13 第 1 项。
# 每个组合只有两种合法结果：成功且注入了平台字段，或因 unsupported 明确失败。
set -uo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

BRIEF=fixtures/brief-sample.md
PASS=0
FAIL=0

platforms=$(python3 -c 'import asset_lib as a; print(" ".join(a.list_platforms()))')
presets=$(python3 -c 'import asset_lib as a; print(" ".join(a.list_presets()))')

echo "平台: $platforms"
echo "preset: $presets"
echo

for p in $platforms; do
  for s in $presets; do
    # 该组合是否应当被支持，由 asset_lib 独立判定（不依赖 composer）
    expect=$(python3 -c "
import asset_lib as a
plat = a.load_platform('$p')
pre  = a.load_preset('$s')
slot = a.archetype_slot(plat, pre['archetype'])
print('ok' if slot is not None and a.preset_supports(pre, '$p') else 'unsupported')
")
    out=$(python3 compose_prompt.py --platform "$p" --preset "$s" \
            --brief-file "$BRIEF" --out "$TMP/$p-$s.md" 2>&1)
    rc=$?

    if [[ "$expect" == "unsupported" ]]; then
      if [[ $rc -ne 0 ]]; then
        echo "  ✅ $p × $s → 按预期拒绝"; PASS=$((PASS+1))
      else
        echo "  ❌ $p × $s → 应拒绝却成功了"; FAIL=$((FAIL+1))
      fi
      continue
    fi

    if [[ $rc -ne 0 ]]; then
      echo "  ❌ $p × $s → 应成功却失败: $out"; FAIL=$((FAIL+1)); continue
    fi

    body=$(cat "$TMP/$p-$s.md")
    problems=""
    grep -q '{{' <<<"$body" && problems="$problems 有占位符残留;"
    # 画幅必须出现在产物里
    aspect_ok=$(python3 -c "
import asset_lib as a
plat = a.load_platform('$p')
pre  = a.load_preset('$s')
slot = a.archetype_slot(plat, pre['archetype'])
asp = slot['aspect']
asp = asp if isinstance(asp, list) else [asp]
body = open('$TMP/$p-$s.md', encoding='utf-8').read()
print('yes' if any(x in body for x in asp) else 'no')
")
    [[ "$aspect_ok" == "yes" ]] || problems="$problems 画幅未注入;"
    # 文字策略必须出现（要么要求放标题，要么明确不放）
    grep -qE '图上必须包含|图上不要出现标题文字' <<<"$body" || problems="$problems 文字策略未注入;"

    if [[ -z "$problems" ]]; then
      echo "  ✅ $p × $s"; PASS=$((PASS+1))
    else
      echo "  ❌ $p × $s →$problems"; FAIL=$((FAIL+1))
    fi
  done
done

echo
echo "通过 $PASS 项，失败 $FAIL 项"
[[ $FAIL -eq 0 ]]
```

```bash
chmod +x skills/_shared/scripts/test-platform-matrix.sh
```

- [ ] **Step 2: 运行矩阵测试**

Run: `./skills/_shared/scripts/test-platform-matrix.sh`
Expected: PASS，8 个组合（2 平台 × 4 preset）全绿，`通过 8 项，失败 0 项`

预期的判定：`wechat × card-warm` 与 `xiaohongshu × inline-warm` 走 unsupported 分支被拒绝，其余 6 个成功。

- [ ] **Step 3: 验证矩阵测试真的能抓到漂移**

手工制造一次漂移，确认测试不是摆设：

```bash
# 把 editorial-warm 的模板里 {{PLATFORM_FRAME}} 删掉，模拟"preset 漏了平台约束"
sed -i.bak 's/^  {{PLATFORM_FRAME}}$//' skills/_shared/presets/cover/editorial-warm.yaml
./skills/_shared/scripts/test-platform-matrix.sh
```

Expected: FAIL，`wechat × editorial-warm` 与 `xiaohongshu × editorial-warm` 报「画幅未注入; 文字策略未注入;」

```bash
# 恢复
mv skills/_shared/presets/cover/editorial-warm.yaml.bak skills/_shared/presets/cover/editorial-warm.yaml
./skills/_shared/scripts/test-platform-matrix.sh
```

Expected: 重新全绿

- [ ] **Step 4: 提交**

```bash
git add skills/_shared/scripts/test-platform-matrix.sh
git commit -m "一期 T4：平台 × archetype × preset 矩阵测试

每个组合只有两种合法结果：成功且注入了平台字段，或因 unsupported 明确失败。
已手工验证它能抓到'preset 漏了 PLATFORM_FRAME'这类静默漂移。"
```

---

## Task 5: INDEX.md 发现入口

**Files:**
- Create: `skills/_shared/presets/INDEX.md`
- Modify: `skills/_shared/scripts/test-asset-schema.sh`（追加 INDEX 一致性检查）

**Interfaces:**
- Consumes: Task 2 的 `list_presets()`、`load_preset()`
- Produces: 无新函数

INDEX.md 是 spec §5.2 里「维度覆盖机制」的落地：agent 靠它把用户说的"换暖色"映射到 `warm-earth`。它同时索引 preset 和 dimensions——spec 明确要求它是**两者的唯一发现入口**。

- [ ] **Step 1: 写 INDEX 一致性测试**

在 `test-asset-schema.sh` 的汇总行**之前**插入：

```bash
echo
echo "== INDEX.md 一致性 =="

out=$(run_py '
import asset_lib as a
idx = (a.shared_root() / "presets" / "INDEX.md").read_text(encoding="utf-8")
missing = [n for n in a.list_presets() if f"`{n}`" not in idx]
assert not missing, f"INDEX.md 未收录 preset: {missing}"
print("OK")
')
[[ "$out" == "OK" ]] && ok "INDEX.md 收录了全部 preset" || bad "INDEX preset 覆盖" "$out"

out=$(run_py '
import asset_lib as a
idx = (a.shared_root() / "presets" / "INDEX.md").read_text(encoding="utf-8")
root = a.shared_root() / "presets" / "dimensions"
missing = []
for kind in sorted(a.DIMENSION_KINDS):
    for f in sorted((root / kind).glob("*.md")):
        if f"`{f.stem}`" not in idx:
            missing.append(f"{kind}/{f.stem}")
assert not missing, f"INDEX.md 未收录 dimension: {missing}"
print("OK")
')
[[ "$out" == "OK" ]] && ok "INDEX.md 收录了全部 dimension 值" || bad "INDEX dimension 覆盖" "$out"
```

- [ ] **Step 2: 运行测试确认失败**

Run: `./skills/_shared/scripts/test-asset-schema.sh`
Expected: 前 11 项 PASS，新增 2 项 FAIL，报 `FileNotFoundError` 找不到 INDEX.md

- [ ] **Step 3: 写 INDEX.md**

创建 `skills/_shared/presets/INDEX.md`：

```markdown
# 图片 preset 与维度词表索引

本文件是 preset 与 dimensions 的**唯一发现入口**。不要靠记忆列举 preset 名，
资产会持续增补——每次选 preset 都回来读这份索引。

## 怎么用

1. 按文章调性从下面的 preset 表里挑一个，用它的 `name` 传给 `--preset`。
2. 用户提了风格偏好（"换暖色"、"别那么花"）时，**不换整个 preset**，
   从维度表里找最接近的值，用 `--palette` / `--rendering` / `--layout` 覆盖那一维。
3. 平台画幅、文字上图策略、体积上限都由 `platforms/<name>.yaml` 决定，
   preset 不管这些——同一个 preset 在微信和小红书会渲染出不同的画幅约束。

## Preset

| name | archetype | 适用 | palette | rendering | layout | 不适用平台 |
|---|---|---|---|---|---|---|
| `editorial-warm` | cover | 人文随笔与商业观察类长文的封面 | `warm-earth` | `flat-vector` | — | — |
| `bento-cool` | infographic | 需要并列展示 4–8 个要点的技术类内容 | `cool-slate` | `flat-vector` | `bento-grid` | — |
| `inline-warm` | illustration | 长文中段落之间的呼吸性插图，不承载信息密度 | `warm-earth` | `soft-gouache` | — | 小红书 |
| `card-warm` | series | 把一篇长文拆成 5–10 张可独立阅读的图卡 | `warm-earth` | `flat-vector` | `bento-grid` | 微信 |

archetype 与平台的支持关系由 `platforms/*.yaml` 的 `archetypes` 槽决定，
槽值为 `unsupported` 时该组合会被渲染器直接拒绝。当前：微信不支持 `series`，
小红书不支持 `illustration`。

## 维度：配色（`--palette`）

| value | 气质 | 用户可能怎么说 |
|---|---|---|
| `warm-earth` | 烧赭与陶土橙，米白打底，柔和 | 暖一点、温和、有人味、纸质感 |
| `cool-slate` | 石板蓝与钢灰，雾白打底，克制 | 冷一点、专业、理性、科技感 |

## 维度：渲染（`--rendering`）

| value | 气质 | 用户可能怎么说 |
|---|---|---|
| `flat-vector` | 扁平矢量，纯色块，无渐变无投影 | 干净、简洁、现代、别太花 |
| `soft-gouache` | 柔和水粉，可见笔触与颗粒 | 手绘感、有温度、别那么硬 |

## 维度：版式（`--layout`）

只有 `infographic` 和 `series` 两个 archetype 用得上。

| value | 结构 | 用户可能怎么说 |
|---|---|---|
| `bento-grid` | 大小不等的矩形格子，主信息占最大格 | 分块、卡片式、一格一个要点 |

## 增补资产时

- 新增 preset：放进 `presets/<archetype>/`，必填字段见 `scripts/asset_lib.py` 的
  `PRESET_REQUIRED_FIELDS`，然后回来更新上面的表——`test-asset-schema.sh` 会检查
  INDEX 是否收录了全部 preset 与 dimension，漏了直接 fail。
- 新增维度值：放进 `presets/dimensions/<kind>/<value>.md`，正文是一段可直接嵌进
  prompt 的中文描述，同样要回来更新表格。
- 新增平台：加一个 `platforms/<name>.yaml`，5 个 archetype 槽必须全部定义
  （不适用的写 `unsupported`）。**不需要**回头改任何 preset——preset 用的是排除制
  `incompatible_platforms`，新平台默认可用。
```

- [ ] **Step 4: 运行全部测试**

```bash
./skills/_shared/scripts/test-asset-schema.sh
./skills/_shared/scripts/test-compose-prompt.sh
./skills/_shared/scripts/test-platform-matrix.sh
```

Expected: 三项全绿——13 项 / 11 项 / 8 项，exit 均为 0

- [ ] **Step 5: 提交**

```bash
git add skills/_shared/presets/INDEX.md skills/_shared/scripts/test-asset-schema.sh
git commit -m "一期 T5：INDEX.md 发现入口

同时索引 preset 与 dimensions，并带一列'用户可能怎么说'——
这是把'换暖色'映射到 warm-earth 的依据。
测试检查 INDEX 是否收录全部资产，漏了直接 fail。"
```

---

## Task 6: 一期收尾文档

**Files:**
- Create: `skills/_shared/README.md`

**Interfaces:**
- Consumes: 无
- Produces: 无

`_shared/` 目前没有任何 skill 消费它（二期才有），因此需要一份 README 说清它是什么、怎么跑测试、以及**哪些东西故意还没做**——否则二期接手的人会以为 vendor 脚本被漏掉了。

- [ ] **Step 1: 写 README**

创建 `skills/_shared/README.md`：

```markdown
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
./scripts/test-asset-schema.sh      # 资产 schema 校验
./scripts/test-compose-prompt.sh    # 渲染器行为 + 占位符白名单
./scripts/test-platform-matrix.sh   # 平台 × archetype × preset 全矩阵
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
```

- [ ] **Step 2: 最终验证**

```bash
cd skills/_shared/scripts
./test-asset-schema.sh && ./test-compose-prompt.sh && ./test-platform-matrix.sh
echo "退出码: $?"
```

Expected: 三项全绿，退出码 0

确认一期没有碰任何现有 skill：

```bash
cd "$(git rev-parse --show-toplevel)"
git diff --name-only main...HEAD | grep -v '^skills/_shared/' | grep -v '^docs/superpowers/'
```

Expected: 无输出（除 `_shared/` 和 `docs/superpowers/` 外没有改动任何文件）

- [ ] **Step 3: 提交**

```bash
git add skills/_shared/README.md
git commit -m "一期 T6：_shared/ README

说清它不是 skill、怎么跑测试、以及哪些东西是故意还没做的——
否则二期接手的人会以为 vendor 脚本被漏掉了。"
```

---

## 一期完成判据

对照 spec §15「一期」的完成判据：矩阵 / 白名单 / schema 三项测试通过。

- [ ] `test-asset-schema.sh` 全绿（13 项）
- [ ] `test-compose-prompt.sh` 全绿（11 项），其中「未知占位符硬失败」一项对应 spec §13 第 2 项
- [ ] `test-platform-matrix.sh` 全绿（8 项），且已手工验证它能抓到 PLATFORM_FRAME 缺失
- [ ] `git diff --name-only main...HEAD` 除 `skills/_shared/` 和 `docs/superpowers/` 外无改动
- [ ] `skills/_shared/README.md` 明确列出了推到二期的事项

## 交接给二期

二期（`md2publish-cover` + vendor 脚本）会依赖本期的这些契约，改动它们要同步改二期：

| 契约 | 位置 |
|---|---|
| `compose_prompt.py` 的 CLI 形状 | `--platform` / `--preset` / `--brief-file` / `--out` / 三个覆盖开关 |
| `asset_lib` 的导出函数 | `load_platform` / `load_preset` / `archetype_slot` / `load_dimension` / `preset_supports` |
| `max_bytes` 是整数字节 | `compress.py`（二期）直接消费，不做后缀解析 |
| brief 文件是渲染器的内容入口 | 二期的 SKILL.md 要指导 agent 怎么写 brief |
| INDEX.md 是唯一发现入口 | 二期 SKILL.md 的「选 preset」步骤要指向它，不要在 SKILL.md 里复制 preset 名单 |
