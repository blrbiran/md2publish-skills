---
name: md2publish-visuals
description: 为文章生成一组配图——微信/B 站专栏的正文插图、信息图、小红书图卡系列，并把图片引用回写进 Markdown（另存，原文不动）。当用户说"配图"、"插图"、"信息图"、"图文笔记"、"小红书卡片"时使用。步骤 1–4 零成本零副作用（产出 prompt 文件），步骤 5 起才调 provider、才花钱。
allowed-tools: Read, Write, Bash, AskUserQuestion
---

# md2publish-visuals：正文配图

一篇文章可以配一组图，按 `archetype` 分三种形态：`illustration`（微信正文插图，
3–8 张）、`infographic`（信息图，固定 1 张）、`series`（小红书图卡系列，1–18 张，
首图即封面）。三种形态共用一套流程，差异集中在张数约束、是否回写正文这两件事上。

本 skill 的资产（平台 profile、preset、维度词表、脚本、生图引擎）全在 `shared/` 下，
是从 `skills/_shared/` vendor 来的副本。**不要改 `shared/` 里的任何文件**——
改了会被 `scripts/check-shared-drift.sh` 拦住，正确做法是改 `skills/_shared/`
再跑 `scripts/sync-shared.sh`。

## 工作目录与路径约定（先读这段，否则每条命令都会跑错地方）

本文里的两类路径**基准不同**，混用必错：

- **脚本路径**（`shared/scripts/...`）相对**本 skill 目录**；
- **产物路径**（brief / prompt / 图 / sidecar / 回写产物）一律用
  **文章目录的绝对路径**。

所以约定是固定的一条：**在本 skill 目录里执行命令，把产物写到文章目录的绝对路径下。**
开工先把这三个变量定下来，后面每条命令都直接用它们：

```bash
cd <本 skill 目录的绝对路径>        # 例如 .../skills/md2publish-visuals
ART=<文章目录的绝对路径>            # 例如 /Users/me/posts/2026-08-10-cache-invalidation
SOURCE=<要配图的 .wechat.md 绝对路径>   # 例如 $ART/2026-08-10-cache-invalidation.wechat.md
mkdir -p "$ART/briefs" "$ART/prompts" "$ART/assets"
```

`ART` 取文章 Markdown 所在的那个目录。**绝不要用相对路径写产物**——那会把 brief、
prompt、图和 sidecar 全部落在 skill 目录里：脱离了文章，还脏了本仓库的工作区。

**文件名推导规则**（下游 `md2publish-article` 靠它找带图版本，务必按这条来，
不要自己另起文件名）：`wechat-finetune` 产出的是 `<name>.wechat.md`——`<name>`
是用户原始文件名，**不是**字面量 `article`；本 skill 回写时把 `.wechat.md`
换成 `.illustrated.md`，同目录另存为 `<name>.illustrated.md`，其余不变：

```bash
OUT="${SOURCE%.wechat.md}.illustrated.md"
```

## 职责边界

| 这件事 | 归谁 |
|---|---|
| 封面 | `md2publish-cover` |
| 架构图 / 流程图 / 时序图 / 示意图 | `md2publish-diagram` |
| 把图传进微信素材库、建草稿 | `md2publish-draft` |
| 正文插图、信息图、小红书图卡系列 | 本 skill |

## 机械层与语义层

你负责**语义**：这组图要表达什么、每张的主体是什么、张数多少、插在正文哪里、
alt 文本怎么写、选哪个 preset。脚本负责**机械**：填画幅、填文字策略、拼模板、
压字节、写元数据、按你给的插入计划精确回写 Markdown。

`compose_prompt.py` 不读文章原文、不调模型。`writeback.py` 不判断"哪张图该插哪"，
只按你写的 `insertions.json` 机械执行、对不上就硬失败。文章的语义部分、插入计划
全由你写成文件传进去。

## 触发路由表（spec §3.2）

"配图"既可能指封面也可能指正文插图，但大多数情况可以由平台推导，不必每次都问：

| 平台 | 用户说"配图 / 图" | 怎么办 |
|---|---|---|
| 微信 | 正文插图（`illustration`） | 直接开工 |
| 小红书 | 卡片系列（`series`），**首图即封面** | 直接开工；**别再去调 `md2publish-cover`**，小红书的封面就是系列第一张 |
| B 站专栏 | 正文插图（`illustration`）或信息图（`infographic`） | 有 `bilibili.yaml`，但**画幅与体积上限未经官方核实**（见该文件顶部注释）。照常走，并把这条成色告诉用户 |
| 其他平台 | — | 本仓库只有 `wechat` / `xiaohongshu` / `bilibili` 三个 platform profile。用户说别的平台时**如实说没有该平台的画幅规格**，别猜 |

只有用户明确要"单张主图 / 封面"时才交给 `md2publish-cover`（小红书除外）。

用户明确说"信息图"时，不论平台，本次运行的 archetype 都改为 `infographic`——
三个平台都支持它，且都没有 `count_range`，视为固定 1 张，不套用上表的
默认 archetype。

## 多平台必须拆两次执行（spec §7.2）

`--platform wechat,xiaohongshu` 对本 skill **不成立**。微信要的是 3–8 张装点长文的
插图，小红书要的是整个卡片系列——**不同内容、不同张数、不同源材料**，不是同一个
视觉概念换画幅。收到多平台请求时**拆成两次独立执行**：各自选 preset、各自写 brief、
各自过成本门。**不允许一次确认覆盖两个平台的花费。**

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

当前支持 `wechat` / `xiaohongshu` / `bilibili`（B 站专栏，画幅数字未经官方核实，见 `shared/platforms/bilibili.yaml` 顶部）。平台一旦确定，按上面的路由表定下本次的
`ARCHETYPE`（`illustration` / `infographic` / `series`）。

### 步骤 3：选 preset + 定张数与位置（语义层，本 skill 独有的重活）

读 `shared/presets/INDEX.md`，按文章调性挑一个 `archetype` 与 `ARCHETYPE` 一致的
preset。**不要背 preset 名单**——资产会持续增补，每次都回去读那份索引。

取该 archetype 的槽配置，重点是 `count_range`：

```bash
SLOT=$(python3 -c "import sys,json; sys.path.insert(0,'shared/scripts'); import asset_lib as a; print(json.dumps(a.archetype_slot(a.load_platform('${PLATFORM}'),'${ARCHETYPE}'),ensure_ascii=False))")
```

`count_range` 是硬约束：微信 `illustration` 是 `[3, 8]`，小红书 `series` 是 `[1, 18]`。
**张数必须落在区间内**，并且要通读全文之后再定——这是 cover 没有的一步（spec §3：
封面只需要标题和摘要，序列必须通读全文才能定位置、定数量）。`infographic` 没有
`count_range` 字段，张数固定为 1，同 cover。

通读全文的同时，逐张定下**锚点**：它必须是原文里的**一整行**（通常是小标题），
后面回写要用，命中必须唯一——挑一个短小标题级别但独一无二的行，别挑正文里可能
重复出现的短句。把这份"第几张、锚点、插在前面还是后面"的清单记下来（不必落成
文件），步骤 9 写 `insertions.json` 时要用。

用户提风格偏好（"换暖色"、"别那么花"）时**不换整个 preset**，从 INDEX.md 的
维度表里找最接近的值，用 `--palette` / `--rendering` / `--layout` 覆盖那一维。

### 步骤 4：逐张写 brief 并渲染 prompt（零成本，到此为止零副作用）

与 cover 同构，只是循环 `count_range` 定下的 N 次，`NN` 从 `00` 起，`<role>` 取
`${ARCHETYPE}`（`illustration` / `infographic` / `series`）。

**4a 语义层**：每张图写一份 `$ART/briefs/<platform>/NN-<role>.md`。四行，中文，
不要写画幅和配色（那些由平台和 preset 决定，写进来只会打架）：

```
主题：<这张图要表达文章的什么>
主体：<画面里具体有什么>
情绪：<什么调性>
alt：<给读者的替代文本，一句话>
```

`series` 的第 1 张同时是封面（`first_is_cover: true`），写它的 brief 时主题要能
独立成立——`compose_prompt.py` 会自动在 prompt 里加一行"第 1 张同时充当封面"的
提示，你不需要重复写。

**4b 机械层**：

```bash
mkdir -p "$ART/briefs/<platform>" "$ART/prompts/<platform>" "$ART/assets/<platform>"
for NN in 00 01 ...; do
  python3 shared/scripts/compose_prompt.py \
    --platform <platform> --preset <preset> \
    --brief-file "$ART/briefs/<platform>/${NN}-<role>.md" \
    --out "$ART/prompts/<platform>/${NN}-<role>.md" \
    [--palette <value>] [--rendering <value>] [--layout <value>]
done
```

平台不支持该 archetype × preset 组合时它直接失败并说明原因，不静默回退。

**到这里为止零成本、零副作用。** 没配 provider 的用户就在这里收工——把
`$ART/prompts/<platform>/` 下的所有文件交给他，拿去即梦 / Midjourney / DALL·E 自己
生，生成后把文件按 `NN-<role>.png` 命名放到 `$ART/assets/<platform>/` 再跳到步骤 7
（此时步骤 8 的 `--provider` / `--model` 照实写成他用的那个工具，别填本仓库的
provider 名）。

### ═══ 以下开始计费 ═══

### 步骤 5：凭证门 + 成本门

**凭证门**：步骤 1 报告 provider 一个都没配置 → **报告 prompt 文件目录并停止**。
不要引导用户为此现配 API key，把选择权交给他。

**成本门，与 cover 的关键差异**：**批量必须问。** cover 是单张所以不问，本 skill
一律要报「将生成 N 张 / 预估 ¥X / provider / model」并等用户确认（spec §9）。
取不到价目时明说"该 provider 无价目表"，**不要编一个数字**。另外
`max_images_per_run`（配置文件，默认 10）是**硬上限**：超过直接拒绝，不是提示。

```bash
python3 -c "import sys; sys.path.insert(0,'shared/scripts'); import config, asset_lib as a; c=config.load_config(); print(c['max_images_per_run'], a.estimate_cost('<provider>','<model>'))"
```

`N`（本次张数）超过 `max_images_per_run` 就直接拒绝，不要问用户要不要放宽。
估价乘以 `N` 得到总预估金额，与 provider / model 一起报给用户，等确认后再往下走。
注意这里只是预告：省略 `--provider` / `--model` 时，引擎会自己回退挑一个，**真相
以步骤 6 的 `--json` 输出为准**，sidecar 只能填那份输出里的值。

### 步骤 6：批量生成

逐张过重跑保护（别自己加 `--force`，非零退出就报告并停下问用户）：

```bash
for NN in 00 01 ...; do
  python3 shared/scripts/artifacts.py guard --path "$ART/assets/<platform>/${NN}-<role>.png"
done
```

取画幅（微信 `illustration` 是列表 `["16:9","4:3"]`，取第一个；小红书 `series` 是
`"3:4"`）：

```bash
ASPECT=$(python3 -c "import sys; sys.path.insert(0,'shared/scripts'); import asset_lib as a; v=a.archetype_slot(a.load_platform('${PLATFORM}'),'${ARCHETYPE}')['aspect']; print(v[0] if isinstance(v,list) else v)")
```

写 batch 文件，一次性把 N 张任务都提交给引擎（`--jobs` 取配置文件的
`max_concurrency`）：

```bash
cat > "$ART/assets/<platform>/batch.json" <<JSON
{
  "jobs": <max_concurrency>,
  "tasks": [
    {"id": "00", "promptFiles": ["$ART/prompts/<platform>/00-<role>.md"],
     "image": "$ART/assets/<platform>/00-<role>.png", "ar": "${ASPECT}"},
    {"id": "01", "promptFiles": ["$ART/prompts/<platform>/01-<role>.md"],
     "image": "$ART/assets/<platform>/01-<role>.png", "ar": "${ASPECT}"}
  ]
}
JSON

BATCH=$(bun shared/scripts/imagegen/main.ts \
  --batchfile "$ART/assets/<platform>/batch.json" --jobs <max_concurrency> --json)
```

**必须带 `--json`**：批量模式的 stdout 是 `{mode, total, succeeded, failed, results}`，
`results[]` 每项含 `id` / `provider` / `model` / `outputPath` / `success` / `attempts` /
`error`。逐张的 `provider` / `model` 只准从这里取，不准填步骤 5 里的预告值——省略
`--provider` / `--model` 时引擎会自己挑，猜错的 sidecar 比没有更坏。按 `id` 取某一张
的 `provider` / `model`（`id` 是字符串，与 batch.json 里写的 `"00"` 一致）：

```bash
python3 -c "import json,sys; d=json.loads(sys.argv[1]); r=next(x for x in d['results'] if str(x['id'])=='${NN}'); print(r['provider'], r['model'])" "${BATCH}"
```

步骤 8 的 sidecar 就用这条命令逐张查。

**部分失败不整体回滚**（spec §10）：10 张成 7 张就保留 7 张，用 `results[]` 里
`success:false` 的项报告失败的是哪几张、原因是什么，允许只对失败的那几张重新写
一份只含它们的 `batch.json` 重跑（同样计入计费尝试）。别把已经生成的 7 张也删了
重来。

失败分类同 cover：

| 类别 | 典型 | 怎么做 |
|---|---|---|
| 配置类 | 认证失败、模型名不存在 | 回步骤 5 改配置，重试免费 |
| 配额类 | 余额不足、限流 | 报告并停，**不自动重试** |
| 审核类 | 内容策略拒绝 | 指出对应 prompt 里可能的触发词，给**具体**改写建议 |
| 网络类 | 超时、连接中断 | 引擎已内建退避 |

### 步骤 7：逐张压缩

微信正文插图 10MB、小红书 20MB 是硬限制。**必须在这里压完**，等到推草稿箱才发现
超限，前面全白做。

```bash
MAXB=$(python3 -c "import sys; sys.path.insert(0,'shared/scripts'); import asset_lib as a; print(a.archetype_slot(a.load_platform('${PLATFORM}'),'${ARCHETYPE}')['max_bytes'])")
```

**压缩不是替换，是新增。** 压完之后 `NN-<role>.png`（超限的原图）和
`NN-<role>.jpg`（压缩产物）**两个文件同时存在**。从这一步起，每张图的最终产物是
压缩脚本吐出的那个路径，**任何地方都不许硬编 `NN-<role>.png`**。

**压缩和步骤 8 的 sidecar 要在同一个循环体里、对每一张图连着做完，再处理下一张
图**——`bash` 没有"动态变量名"这回事，`FINAL_${NN}=...` 不会创建一个叫
`FINAL_00`、`FINAL_01` 的变量，它会被展开成一整行普通命令去执行，而步骤 8 里的
`${FINAL_NN}` 也只是字面意义上一个从未赋值过的变量，永远是空字符串。要跨"压缩"
和"写 sidecar"这两个动作传值，唯一稳妥的办法是**不跨循环传**：每张图进一次循环，
`FINAL` 在这次循环里赋值、在这次循环里用完，下一张图重新赋值，见步骤 8 的代码块。

### 步骤 8：逐张压缩 + 写 sidecar（同一循环内完成，紧接着步骤 7）

```bash
for NN in 00 01 ...; do
  RAW="$ART/assets/<platform>/${NN}-<role>.png"
  FINAL=$(python3 shared/scripts/compress.py --image "${RAW}" --max-bytes "${MAXB}")

  read -r PROVIDER MODEL <<<"$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); r=next(x for x in d['results'] if str(x['id'])=='${NN}'); print(r['provider'], r['model'])" "${BATCH}")"

  python3 shared/scripts/artifacts.py sidecar \
    --image "${FINAL}" \
    --platform <platform> --archetype <ARCHETYPE> --preset <preset> \
    --provider "${PROVIDER}" --model "${MODEL}" \
    --prompt-file "$ART/prompts/<platform>/${NN}-<role>.md" \
    --brief-file "$ART/briefs/<platform>/${NN}-<role>.md" \
    --alt-text "<该 NN 张 brief 里那句 alt>" \
    [--override palette=<value>]
done
```

sidecar 写在各自最终产物旁边、与它同名。**最终产物一律以 sidecar 的 `image`
字段为准**——`.png` 和 `.jpg` 算出来是同一个 `.json`，文件名区分不了，只有这个
字段能。`${PROVIDER}` / `${MODEL}` 取步骤 6 那份 `--json` 输出里对应 `id` 的值，
不是步骤 5 的预告值。

### 步骤 9：回写门（本 skill 独有）

**小红书 `series` 不回写，走到步骤 8 就结束。** 卡片系列是内容本身，不进正文；
`$OUT`（`<name>.illustrated.md`）只在微信 `illustration` / `infographic` 时产生。

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
  --source "$SOURCE" --insertions "$ART/insertions.json" \
  --assets-dir "$ART/assets/${PLATFORM}" --out "$OUT" --dry-run

# 9c 用户确认后才真写
python3 shared/scripts/writeback.py \
  --source "$SOURCE" --insertions "$ART/insertions.json" \
  --assets-dir "$ART/assets/${PLATFORM}" --out "$OUT"
```

`insertions.json` 是一个数组，每项**恰好四个键、一个都不能多不能少**：`anchor`
（原文中的一整行，必须恰好命中一次）、`position`（`after` 或 `before`）、`image`
（文件名，不是路径）、`alt`。出现未知字段（比如把 `position` 拼成 `postion`）会
硬失败并点名；`image` 指向的文件不在 `--assets-dir` 里也会硬失败并点名。

**9b 与用户确认这一步不许跳过**（spec §9：改源文件的门）。锚点命中 0 次或多次时
脚本会硬失败并把锚点打回来——**改锚点，别去改原文来迁就它**。源文件只读，永不
修改；`--out`（即 `$OUT`）已存在时脚本会拦住，除非 `--force`。

### 步骤 10：交接

告诉用户产出了 `$OUT`（`<name>.illustrated.md`；**原文 `$SOURCE` 一字未改**），
接下来 `md2publish-article` 会**默认**用同目录下这份 `*.illustrated.md` 转 HTML。
部分失败时要说清楚少了哪几张、原计划插在哪，让用户决定是重跑还是先带着缺口往下走。

`series` 走完步骤 8 就收工：告诉用户 N 张（步骤 3 定下的张数）卡片系列已生成在
`$ART/assets/<platform>/` 下，第 1 张兼作封面，本仓库**还没有**小红书的发布
skill，产物需要用户自己上传。

## 产物布局

```
$ART/
├─ <name>.wechat.md                      ← 原文（wechat-finetune 产出），本 skill 永不修改
├─ <name>.illustrated.md                 ← 回写产物（series 不产生这个）
├─ insertions.json                       ← 插入计划，复现记录（series 不产生这个）
├─ briefs/<platform>/NN-<role>.md
├─ prompts/<platform>/NN-<role>.md
└─ assets/<platform>/
   ├─ NN-<role>.png                      ← 引擎的原始产物
   ├─ NN-<role>.jpg                      ← 压缩产物（超限时才有，与 .png 共存）
   └─ NN-<role>.json                     ← sidecar，image 字段记着最终产物的文件名
```

`<role>` 取 `illustration` / `infographic` / `series`，与本次运行的 `ARCHETYPE`
一致。按平台分目录，所以 `wechat` 和 `xiaohongshu` 各自跑一次不会同名相撞。

## 前置

```bash
bun --version                                  # 或 npx -y bun --version
sips --version || magick --version             # 二者有其一
python3 -c 'import yaml'
```

生成图片需要至少一个 provider 的 API key（清单见 `shared/scripts/preflight.py`
的 `PROVIDER_ENV`）。凭证有三个来源，优先级从高到低：进程环境变量、
`~/.baoyu-skills/.env`、`<当前目录>/.baoyu-skills/.env`——preflight 与生图引擎查的是
同一组、同一顺序。第三个来源跟着当前目录走，这也是"命令一律在 skill 目录里跑"
这条约定要守住的原因之一：换个目录跑，生效的 `.env` 就可能换了一份。

**没有凭证也能用**——步骤 1–4 照跑，交付 prompt 文件。
