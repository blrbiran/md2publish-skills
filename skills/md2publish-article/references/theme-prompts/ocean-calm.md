# ocean-calm 深海静谧（本地重写版，原 CLI 内置主题）

> 深邃冷静的蓝色调，细网格白卡 + 深海阴影，理性专业。适合技术、分析、行业观察类文章。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。
> 本文件由 md2wechat 3.2.0 的 V4.0 提示词重写为扩展主题格式（视觉规格一致，剔除 ul/li、CDN 字体、`<!-- IMG:n -->` 等与铁律冲突的历史条款）。想用 CLI 实时指令时仍可走 `convert --mode ai --theme ocean-calm`。

## 核心愿景

深海般的沉静秩序：蓝灰的克制层次、精确的线条、不喧哗的强调。它要传达"这篇文章经过认真思考"——视觉上的冷静就是论证的一部分。

## 色彩系统

- 淡蓝背景：`#f0f4f8`（主容器）
- 主文字（深蓝灰）：`#3a4150`
- 深海蔚蓝（副强调）：`#4a7c9b`——装饰位的亮色：h2 符号、h3 短线、列表前缀、引用边框、em
- 静谧石蓝（主强调）：`#3d6a8a`——承担文字的深色：h2/h3 标题文字、strong、行内 code、表头、代码高亮
- 引用/代码底：`#e8f0f8`

## 容器与布局

- 主容器：`background-color: #f0f4f8; padding: 40px 10px; letter-spacing: 0.5px`
- 每个章节一张卡：`background-color: #ffffff; background-image: linear-gradient(rgba(74,124,155,0.03) 1px, transparent 1px), linear-gradient(90deg, rgba(74,124,155,0.03) 1px, transparent 1px); background-size: 20px 20px; border: 1px solid rgba(74,124,155,0.08); border-radius: 14px; padding: 25px; margin: 0 0 40px; box-shadow: 0 8px 28px rgba(58,65,80,0.06), 0 0 16px rgba(74,124,155,0.15)`——蓝调细网格 + 深海阴影是本主题的签名

## 标题体系

- h2：两个 `<span>` 构成——`◆` 符号 `<span style="color: #4a7c9b; text-shadow: 0 0 10px rgba(74,124,155,0.4);">◆&nbsp;</span>` + 标题文本 `<span style="color: #3d6a8a;">`；整体 `font-size: 20px; font-weight: 700; text-align: left; margin: 0 0 20px; padding-bottom: 8px; border-bottom: 1px dashed rgba(74,124,155,0.3)`
- h3：`font-size: 17px; font-weight: 600; color: #3d6a8a; text-align: left; margin: 26px 0 12px; padding-bottom: 4px; border-bottom: 2px solid #4a7c9b; display: inline-block`（短实线，无 text-shadow）

## 正文与强调

- 段落：`font-size: 16px; line-height: 1.75; color: #3a4150; margin: 0 0 16px; text-align: left`
- strong：`color: #3d6a8a; font-weight: 700`
- em / 关键术语：`color: #4a7c9b`

## 引用 / 代码 / 列表 / 表格

- 引用块：`background-color: #e8f0f8; border-left: 5px solid #4a7c9b; box-shadow: inset 0 0 12px rgba(74,124,155,0.08); padding: 16px 20px; margin: 0 0 16px; color: #5a6472; font-size: 15px; line-height: 1.8; text-align: left`
- 代码块：`<pre>` 底 `#eef3f8`、文字 `#3a4150`、`border: 1px solid rgba(74,124,155,0.2); border-radius: 10px; padding: 16px 18px; font-size: 13.5px`
- **代码块内的轻量高亮**：注释 `#626e7f`，外加**每种语言只挑一个锚点**上 `#3d6a8a`——YAML 挑键名、JSON 挑键名、Bash 挑命令名、Python 挑关键字，其余一律保持默认字色。这样一行上色不超过 2 类，单色系的克制感才守得住；把字符串、值、键名全部上色会让 YAML/JSON 整块变蓝，和"克制"是自相矛盾的
> 注释这支灰蓝的明度是被对比度铁律钉住的：在代码块底 `#eef3f8` 上 4.64:1。2026-08 为此压深过一档（压之前 2.72:1，差 1.78 不达 AA），不要调回去（规则 11）。上面那条「克制」管的是一行上色不超过 2 类，不是让注释淡到读不清。
- 行内 code：底 `#e8f0f8`、文字 `#3d6a8a`、`padding: 1px 5px; border-radius: 4px`（淡底小 padding，手机断行时不明显）
- 列表前缀 `▸&nbsp;&nbsp;`（蔚蓝 span：`<span style="color: #4a7c9b;">▸</span>&nbsp;&nbsp;`）
- 表格：表头底 `#e8f0f8`、文字 `#3d6a8a`，单元格 `border: 1px solid rgba(74,124,155,0.18); padding: 9px 12px; font-size: 14px`
- 卡内分隔（如需要）：`height: 1px; border: none; background-image: linear-gradient(90deg, transparent, rgba(74,124,155,0.25), transparent); margin: 24px 0`

## 分寸提醒

蓝色的高频落点已由 h2 符号、h3 短线、列表前缀、引用边框保底。行内 code 的文字色也是石蓝，占了石蓝落点的大半——这在本库是常规写法（26 个主题里 17 个如此），2026-08 实测观感达标。它成立的前提是**行内 code 有自己的淡底**，形状上和 strong 分得开；别把底去掉，cyber-neon 当初就是无底 + 强调色文字，结果行内 code 和 strong 长得一模一样。本主题适合"讲道理"的技术分析文；如果文章代码块密集、需要编辑器级语法高亮，改用 `editor-slate`。
