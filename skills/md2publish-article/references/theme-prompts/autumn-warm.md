# autumn-warm 秋日暖光（本地重写版，原 CLI 内置主题）

> 温暖治愈的橙色调文艺美学，方格纹理白卡 + 暖光阴影。适合生活方式、随笔、人文类文章。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。
> 本文件由 md2wechat 3.2.0 的 V4.0 提示词重写为扩展主题格式（视觉规格一致，剔除 ul/li、CDN 字体、`<!-- IMG:n -->` 等与铁律冲突的历史条款）。想用 CLI 实时指令时仍可走 `convert --mode ai --theme autumn-warm`。

## 核心愿景

被秋日暖光浸染的文艺世界：精致的卡片、柔和的光效、清晰的层次。温暖但不甜腻——暖橙是点睛，米白和深棕才是主体。

## 色彩系统

- 暖白背景：`#faf9f5`（主容器）
- 主文字：`#4a413d`
- 秋日暖橙（副强调）：`#d97758`——装饰位的亮色：h2 符号、h3 短线、列表前缀、引用边框、em
- 橙红高亮（主强调）：`#c06b4d`——承担文字的深色：h2/h3 标题文字、strong、行内 code、表头、代码高亮
- 引用/代码底：`#fef4e7`

## 容器与布局

- 主容器：`background-color: #faf9f5; padding: 40px 10px; letter-spacing: 0.5px`
- 每个章节一张卡：`background-color: #ffffff; background-image: linear-gradient(rgba(0,0,0,0.02) 1px, transparent 1px), linear-gradient(90deg, rgba(0,0,0,0.02) 1px, transparent 1px); background-size: 20px 20px; border: 1px solid rgba(0,0,0,0.05); border-radius: 18px; padding: 25px; margin: 0 0 40px; box-shadow: 0 10px 30px rgba(0,0,0,0.04), 0 0 15px rgba(217,119,88,0.4)`——米白方格纹理 + 暖光阴影是本主题的签名

## 标题体系

- h2：两个 `<span>` 构成——`▶` 符号 `<span style="color: #d97758; text-shadow: 0 0 10px rgba(217,119,88,0.4);">▶&nbsp;</span>` + 标题文本 `<span style="color: #c06b4d;">`；整体 `font-size: 20px; font-weight: 700; text-align: left; margin: 0 0 20px; padding-bottom: 8px; border-bottom: 1px dashed rgba(217,119,88,0.3)`
- h3：`font-size: 17px; font-weight: 600; color: #c06b4d; text-align: left; margin: 26px 0 12px; padding-bottom: 4px; border-bottom: 2px solid #d97758; display: inline-block`（短实线，无 text-shadow）

## 正文与强调

- 段落：`font-size: 16px; line-height: 1.75; color: #4a413d; margin: 0 0 16px; text-align: left`
- strong：`color: #c06b4d; font-weight: 700`
- em：`color: #d97758`

## 引用 / 代码 / 列表 / 表格

- 引用块：`background-color: #fef4e7; border-left: 5px solid #d97758; box-shadow: inset 0 0 12px rgba(217,119,88,0.08); padding: 16px 20px; margin: 0 0 16px; color: #6b5f57; font-size: 15px; line-height: 1.8; text-align: left`
- 代码块：`<pre>` 底 `#fdf8f2`、文字 `#4a413d`、`border: 1px solid rgba(217,119,88,0.22); border-radius: 12px; padding: 16px 18px; font-size: 13.5px`；**代码内注释用 `#846d5b`、字符串/值用 `#c06b4d` 做轻量高亮**（其余保持默认色，一行不超过 2 类上色——本主题的代码块是配角，不追求编辑器级高亮）；行内 code：底 `#fef4e7`、文字 `#c06b4d`、`padding: 2px 6px; border-radius: 4px`
> 注释这支浅褐的明度是被对比度铁律钉住的：在代码块底 `#fdf8f2` 上 4.60:1。2026-08 为此压深过一档（压之前 3.17:1，差 1.33 不达 AA），不要调回去（规则 11）。代码块在本主题里是配角，但配角也要读得清。
- 列表前缀 `•&nbsp;&nbsp;`（暖橙 span：`<span style="color: #d97758;">•</span>&nbsp;&nbsp;`）
- 表格：表头底 `#fef4e7`、文字 `#c06b4d`，单元格 `border: 1px solid rgba(217,119,88,0.2); padding: 9px 12px; font-size: 14px`
- 卡内分隔（如需要）：`height: 1px; border: none; background-image: linear-gradient(90deg, transparent, rgba(217,119,88,0.25), transparent); margin: 24px 0`

## 分寸提醒

暖橙的高频落点已由 h2 符号、h3 短线、列表前缀、引用边框保底，正文里的 strong/em 不必刻意加密。技术文代码块多时建议改用 `editor-slate`——本主题代码块刻意轻量。
