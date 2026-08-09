# spring-fresh 春日清新（本地重写版，原 CLI 内置主题）

> 自然轻盈的绿色调，圆点纹理白卡 + 清新阴影。适合轻松话题、新品介绍、教程入门类文章。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。
> 本文件由 md2wechat 3.2.0 的 V4.0 提示词重写为扩展主题格式（视觉规格一致，剔除 ul/li、CDN 字体、`<!-- IMG:n -->` 等与铁律冲突的历史条款）。想用 CLI 实时指令时仍可走 `convert --mode ai --theme spring-fresh`。

## 核心愿景

春日草地的轻盈感：嫩绿点缀、圆点纹理、柔和的圆角。比 mint-breeze 更文艺、比 botanic-press 更轻快——是"散步"而不是"研究"的绿。

## 色彩系统

- 淡绿背景：`#f5f8f5`（主容器）
- 主文字（深绿灰）：`#3d4a3d`
- 春日嫩绿（副强调）：`#6b9b7a`——装饰位的亮色：h2 符号、h3 短线、列表前缀、引用边框、em
- 草地翠绿（主强调）：`#4a8058`——承担文字的深色：h2/h3 标题文字、strong、行内 code、表头、代码高亮
- 引用/代码底：`#e8f0e8`

## 容器与布局

- 主容器：`background-color: #f5f8f5; padding: 40px 10px; letter-spacing: 0.5px`
- 每个章节一张卡：`background-color: #ffffff; background-image: radial-gradient(circle at 1px 1px, rgba(107,155,122,0.08) 1px, transparent 0); background-size: 18px 18px; border: 1px solid rgba(107,155,122,0.1); border-radius: 16px; padding: 25px; margin: 0 0 40px; box-shadow: 0 8px 24px rgba(74,128,88,0.08), 0 0 12px rgba(107,155,122,0.2)`——嫩绿圆点纹理（区别于其他两个内置主题的方格）+ 清新阴影是本主题的签名

## 标题体系

- h2：两个 `<span>` 构成——`❀` 符号 `<span style="color: #6b9b7a; text-shadow: 0 0 10px rgba(107,155,122,0.4);">❀&nbsp;</span>` + 标题文本 `<span style="color: #4a8058;">`；整体 `font-size: 20px; font-weight: 700; text-align: left; margin: 0 0 20px; padding-bottom: 8px; border-bottom: 1px dashed rgba(74,128,88,0.25)`
- h3：`font-size: 17px; font-weight: 600; color: #4a8058; text-align: left; margin: 26px 0 12px; padding-bottom: 4px; border-bottom: 2px solid #6b9b7a; display: inline-block`（短实线，无 text-shadow）

## 正文与强调

- 段落：`font-size: 16px; line-height: 1.75; color: #3d4a3d; margin: 0 0 16px; text-align: left`
- strong：`color: #4a8058; font-weight: 700`
- em：`color: #6b9b7a`

## 引用 / 代码 / 列表 / 表格

- 引用块：`background-color: #e8f0e8; border-left: 5px solid #6b9b7a; box-shadow: inset 0 0 12px rgba(107,155,122,0.1); padding: 16px 20px; margin: 0 0 16px; color: #5c6a5c; font-size: 15px; line-height: 1.8; text-align: left`
- 代码块：`<pre>` 底 `#eef4ee`、文字 `#3d4a3d`、`border: 1px solid rgba(107,155,122,0.2); border-radius: 12px; padding: 16px 18px; font-size: 13.5px`；**代码内注释用 `#8fa08f`、字符串/值用 `#4a8058` 做轻量高亮**（其余保持默认色，一行不超过 2 类上色——本主题面向入门教程，代码块要友好不要炫技）；行内 code：底 `#e8f0e8`、文字 `#4a8058`、`padding: 2px 6px; border-radius: 4px`
- 列表前缀 `•&nbsp;&nbsp;`（嫩绿 span：`<span style="color: #6b9b7a;">•</span>&nbsp;&nbsp;`）
- 表格：表头底 `#e8f0e8`、文字 `#4a8058`，单元格 `border: 1px solid rgba(107,155,122,0.18); padding: 9px 12px; font-size: 14px`
- 卡内分隔（如需要）：`height: 1px; border: none; background-image: linear-gradient(90deg, transparent, rgba(107,155,122,0.3), transparent); margin: 24px 0`

## 分寸提醒

绿色的高频落点已由 h2 符号、h3 短线、列表前缀、引用边框保底。教程文的"步骤"结构优先用 h3 + 有序 `<p>` 列表表达，不要发明新的步骤卡片——本主题的轻盈感靠一致性维持。
