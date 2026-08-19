---
name: md2publish-diagram
description: 画架构图 / 流程图 / 时序图 / 示意图，产出 SVG 与 PNG 双产物。当用户说"画个架构图"、"流程图"、"时序图"、"示意图"时使用。**不调 AI、不花钱**：图由你直接写成 SVG，再本地光栅化成 PNG（微信不接受 SVG）。
allowed-tools: Read, Write, Bash, AskUserQuestion
---

# md2publish-diagram：架构图 / 流程图

一篇文章可以有多张示意图，按 `NN-diagram` 编号（`00-diagram`、`01-diagram`……）。

本 skill 的资产（平台 profile、脚本）全在 `shared/` 下，是从 `skills/_shared/`
vendor 来的副本。**不要改 `shared/` 里的任何文件**——改了会被
`scripts/check-shared-drift.sh` 拦住，正确做法是改 `skills/_shared/`
再跑 `scripts/sync-shared.sh`。

## 工作目录与路径约定（先读这段，否则每条命令都会跑错地方）

本文里的两类路径**基准不同**，混用必错：

- **脚本路径**（`shared/scripts/...`）相对**本 skill 目录**；
- **产物路径**（SVG / PNG / sidecar）一律用**文章目录的绝对路径**。

所以约定是固定的一条：**在本 skill 目录里执行命令，把产物写到文章目录的绝对路径下。**
开工先把这两个变量定下来，后面每条命令都直接用它们：

```bash
cd <本 skill 目录的绝对路径>        # 例如 .../skills/md2publish-diagram
ART=<文章目录的绝对路径>            # 例如 /Users/me/posts/2026-08-10-cache-invalidation
mkdir -p "$ART/diagrams" "$ART/assets"
```

`ART` 取文章 Markdown 所在的那个目录。**绝不要用相对路径写产物**——那会把 SVG、
PNG 和 sidecar 全部落在 skill 目录里：脱离了文章，还脏了本仓库的工作区。

## 职责边界

| 这件事 | 归谁 |
|---|---|
| 封面 | `md2publish-cover` |
| 正文里的插图（3–8 张）、小红书图卡系列 | `md2publish-visuals` |
| 把图传进微信素材库、建草稿 | `md2publish-draft` |
| 架构图 / 流程图 / 时序图 / 示意图 | 本 skill |

## 本 skill 与另两个的结构差异

本 skill **不调 AI、不读 preset、不渲染 prompt、没有成本门**。另两个 skill 的步骤 4
「渲染 prompt」在这里不存在——图是你直接写出来的 SVG，SVG 源文件本身就是复现记录
（改它重跑，结果是确定的，比改 prompt 重生成强）。因此**不要**去调另两个 skill
步骤 4 里那条渲染 prompt 模板的脚本，也**不要**建 `prompts/` 目录。

## 执行流程

### 步骤 1：查后端（零成本）

```bash
python3 shared/scripts/svg2raster.py --check
```

一个后端都没有时**如实告诉用户**：可以照常写 SVG 并交付 `.svg` 文件，但转不出
PNG，微信发不了；装 `brew install librsvg` 之后回来跑步骤 4 即可。**不要**因此
中止整个流程。

### 步骤 2：定平台，取画幅与体积上限

```bash
PLATFORM=wechat      # 或 xiaohongshu
ASPECT=$(python3 -c "import sys; sys.path.insert(0,'shared/scripts'); import asset_lib as a; s=a.archetype_slot(a.load_platform('${PLATFORM}'),'diagram'); print(s['aspect'][0] if isinstance(s['aspect'],list) else s['aspect'])")
MAXB=$(python3 -c "import sys; sys.path.insert(0,'shared/scripts'); import asset_lib as a; print(a.archetype_slot(a.load_platform('${PLATFORM}'),'diagram')['max_bytes'])")
```

微信 diagram 的 `aspect` 是列表 `["16:9", "4:3"]`，上面取第一个；用户要竖图时手动
改成 `4:3`。小红书是 `"3:4"`。

### 步骤 3：写 SVG（语义层，你的活）

这一步是本 skill 的核心。你直接手写 SVG，落到
`$ART/diagrams/<platform>/NN-diagram.svg`。三条硬约束一个都不能少：

- **`viewBox` 必须与平台画幅一致**（16:9 → `viewBox="0 0 1600 900"`）。步骤 4
  会机械校验，差 1% 以上直接失败——**改 SVG，不要改 `--aspect` 绕过去**，画幅是
  平台硬约束。
- **字体必须写完整的 fallback 链**，一个都不能少：`"PingFang SC", "Noto Sans CJK SC", "Microsoft YaHei", sans-serif`。
  只写"系统字体"不够——macOS 与 Linux 的 CJK 默认字体不同，同一份 SVG 会渲染出
  不同的图。
- **不要在 SVG 里引用外部资源**（外链字体、外链图片）：光栅化在离线环境里跑，
  引用不到就是空白，而空白在缩略图上看不出来。

样例可参考 `shared/scripts/fixtures/diagram-sample.svg`（它同时是测试 fixture，别改它）。

起手处，一个节点 + 一条连线的最小骨架：

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1600 900" width="1600" height="900">
  <rect x="0" y="0" width="1600" height="900" fill="#F7F5F2"/>
  <g font-family="&quot;PingFang SC&quot;, &quot;Noto Sans CJK SC&quot;, &quot;Microsoft YaHei&quot;, sans-serif"
     font-size="36" fill="#2B2B2B" text-anchor="middle">
    <rect x="120" y="380" width="320" height="140" rx="12" fill="#FFFFFF" stroke="#8C6A4F" stroke-width="3"/>
    <text x="280" y="458">节点</text>
    <line x1="440" y1="450" x2="640" y2="450" stroke="#8C6A4F" stroke-width="3"/>
  </g>
</svg>
```

节点是 `rect` + `text` 的组合：`text` 的坐标取 `rect` 的中心，配合
`text-anchor="middle"` 居中；连线用 `line`，端点接在相邻节点的边界上。多节点的图
照这个模式重复摆放、用 `line` 依次连起来即可。

### 步骤 4：光栅化

```bash
SVG="$ART/diagrams/${PLATFORM}/00-diagram.svg"
PNG="$ART/assets/${PLATFORM}/00-diagram.png"
mkdir -p "$(dirname "${SVG}")" "$(dirname "${PNG}")"
python3 shared/scripts/artifacts.py guard --path "${PNG}"        # 报告并停下问用户，别自己加 --force
RASTER=$(python3 shared/scripts/svg2raster.py --svg "${SVG}" --out "${PNG}" --aspect "${ASPECT}" --json)
BACKEND=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['backend'])" "${RASTER}")
```

`${BACKEND}` 是**实际用的光栅化后端**，步骤 6 要如实填进 sidecar。**不要**凭印象
写 `rsvg-convert`——降级链按可用性降级，`--check` 报告的就是本机实际可用的那些，
实际用的未必是排在第一的那个，填错了 sidecar 就成了一份误导性的追溯记录。

### 步骤 5：压缩（多半用不上）

```bash
FINAL="${PNG}"
if [[ $(wc -c < "${PNG}") -gt ${MAXB} ]]; then
  FINAL=$(python3 shared/scripts/compress.py --image "${PNG}" --max-bytes "${MAXB}")
fi
```

diagram 的上限是 10MB（微信）/ 20MB（小红书）/ 10MB（B 站专栏，未核实），光栅化出来的图通常远低于它，
**这一步大概率不动**。真超限时压缩产出的是 JPEG，示意图的文字会变糊——这时更该
做的是**降低 `--width` 重新光栅化**，而不是压缩。把这个选择说给用户。

### 步骤 6：写 sidecar

```bash
python3 shared/scripts/artifacts.py sidecar \
  --image "${FINAL}" \
  --platform "${PLATFORM}" --archetype diagram \
  --provider "${BACKEND}" \
  --source-file "$(basename "${SVG}")" \
  --alt-text "<一句话描述这张图>"
```

**不要传 `--preset` / `--model` / `--prompt-file` / `--brief-file`**——diagram
支路会硬失败并点名。那不是 bug，是防止照抄 cover 的命令写出一份声称走过 preset
链路、实际没有的 sidecar。

### 步骤 7：回写门（要插进正文时才做，本 skill 自带，零成本）

本 skill vendor 了自己的一份 `writeback.py`——与 `md2publish-visuals` 用的是
同一份机制脚本（都从 `_shared/` 同步来），但**不需要、也不要去调 visuals 的
目录或走它步骤 5–8 那条凭证门 + 成本门 + 真 provider 调用的付费流水线**：
直接在本 skill 目录里把它当独立脚本跑，全程零成本。

先定下 `$SOURCE` / `$OUT`（推导规则与 visuals 一致，见其 SKILL.md「工作目录与
路径约定」）：`wechat-finetune` 产出的是 `<name>.wechat.md`（`<name>` 是用户
原始文件名，不是字面量 `article`），回写产物是同目录下把 `.wechat.md` 换成
`.illustrated.md` 的 `<name>.illustrated.md`。**这篇文章如果 `md2publish-visuals`
已经跑过回写**（同目录已存在 `<name>.illustrated.md`），`$SOURCE` 就用那份
已有产物、`$OUT` 写同一个路径并加 `--force`——这是往已经插过图的正文里继续
累加插入，不是误覆盖；反之 `$SOURCE` 用 `<name>.wechat.md` 起头，`$OUT` 是
新产出的 `<name>.illustrated.md`：

```bash
SOURCE=<按上面规则选出的 .wechat.md 或 .illustrated.md 绝对路径>
case "${SOURCE}" in
  *.illustrated.md) OUT="${SOURCE}" ;;                          # 已经是带图版本，原地追加，下面必须带 --force
  *.wechat.md)      OUT="${SOURCE%.wechat.md}.illustrated.md" ;;
  *)                OUT="${SOURCE%.md}.illustrated.md" ;;
esac
# bash 的 % 后缀剥离只在 SOURCE 真以对应后缀结尾时生效；SOURCE 已是
# .illustrated.md 时若仍套用 wechat.md 的剥离规则，剥离不生效，会产出
# name.illustrated.md.illustrated.md 这种和 SOURCE 不同的双重后缀路径。

# 7a 写 insertions（语义层）。image 一律抄 sidecar 的 image 字段
cat > "$ART/insertions.json" <<'JSON'
[
  {"anchor": "## 架构总览", "position": "after",
   "image": "00-diagram.png", "alt": "架构总览示意图"}
]
JSON

# 7b 预览 diff，给用户看（此时还没写任何文件）
python3 shared/scripts/writeback.py \
  --source "$SOURCE" --insertions "$ART/insertions.json" \
  --assets-dir "$ART/assets/${PLATFORM}" --out "$OUT" --dry-run

# 7c 用户确认后才真写（OUT 已存在时——即 SOURCE 就是 illustrated.md 那种情况——要加 --force）
python3 shared/scripts/writeback.py \
  --source "$SOURCE" --insertions "$ART/insertions.json" \
  --assets-dir "$ART/assets/${PLATFORM}" --out "$OUT" [--force]
```

`insertions.json` 的 schema、锚点唯一命中的规则、`--dry-run` 预览、`--force`
行为，与 `md2publish-visuals` SKILL.md 步骤 9 完全一致——机制是同一份脚本，
只是两个 skill 各自 vendor 了一份。

**必须在 `md2publish-article` 转 HTML 之前完成这一步**，否则示意图不会出现在
正文里（spec §8）。

### 步骤 8：交接

- **只是单独导出一张图，不插进正文**：跳过步骤 7，直接把 `${FINAL}` 给用户，
  与流水线无耦合。
- 两种情况都要告诉用户：`.svg` 源文件留在 `$ART/diagrams/` 下，**要改图就改它
  再重跑步骤 4**，不要去 P 图。

## 产物布局

```
$ART/
├─ diagrams/<platform>/00-diagram.svg   ← 你写的 SVG，复现记录，别删
└─ assets/<platform>/
   ├─ 00-diagram.png                    ← 光栅化产物
   └─ 00-diagram.json                   ← sidecar；image 字段是下游该消费的文件名
```

按平台分目录，所以 `wechat,xiaohongshu` 两张图不会同名相撞。

## 前置

```bash
python3 -c 'import yaml'
```

`rsvg-convert` / `magick` / Chrome **三者有其一**（都没有也能产出 SVG，只是转不了
PNG）。**不需要 bun**——diagram 不碰 imagegen。
