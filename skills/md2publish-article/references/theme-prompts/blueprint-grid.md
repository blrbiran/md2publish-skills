# blueprint-grid 工程蓝图（扩展主题）

> 白图纸 + 制图蓝网格 + 虚线框 + 批注橙，工程制图的理性美。适合建筑、工程、硬核科普、系统设计解析。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

一张摊在桌上的白图纸：淡蓝网格是底，制图蓝画结构线，橙褐色是工程师铅笔写的批注。一切装饰都要像"图纸元素"——虚线、编号、标注框，而不是网页装饰。

## 色彩系统

- 图纸白底：`#f5f8fb`（主容器）
- 正文钢蓝黑：`#23405c`
- 制图蓝（主强调）：`#1d5a8a`
- 批注橙褐（副强调）：`#b26a1b`
- 次级灰蓝：`#7189a0`
- 网格/边线：`#c9d9e8`
- 浅蓝底：`#e7eff7`

## 容器与布局

- 主容器带网格底纹：`background-color: #f5f8fb; background-image: linear-gradient(rgba(29, 90, 138, 0.06) 1px, transparent 1px), linear-gradient(90deg, rgba(29, 90, 138, 0.06) 1px, transparent 1px); background-size: 24px 24px; padding: 40px 14px; letter-spacing: 0.3px`
- 章节图框：`background-color: #ffffff; border: 1px solid #1d5a8a; border-radius: 0; padding: 24px 20px; margin: 0 0 34px`——直角实线框，像图纸的图框

## 标题体系

- h2：图签样式——`<h2 style="margin: 0 0 20px; text-align: left; font-size: 17px;"><span style="display: inline-block; background-color: #1d5a8a; color: #f5f8fb; font-weight: 700; padding: 5px 12px; font-family: Menlo, Consolas, monospace;">01</span><span style="display: inline-block; border: 1px solid #1d5a8a; color: #1d5a8a; font-weight: 700; padding: 4px 14px;">标题文本</span></h2>`（编号随章节递增 01/02/03）
- h3：`font-size: 15.5px; font-weight: 700; color: #23405c; text-align: left; margin: 26px 0 12px`，前缀 `<span style="color: #1d5a8a; font-family: Menlo, Consolas, monospace;">▹&nbsp;</span>`

## 正文与强调

- 段落：`font-size: 15.5px; line-height: 1.8; color: #23405c; margin: 0 0 16px; text-align: left`
- strong：`color: #1d5a8a; font-weight: 700`
- em / 批注语气（"注意""易错点"）：`color: #b26a1b`

## 引用 / 代码 / 列表 / 表格

- 引用块（批注框）：`border: 1px dashed #b26a1b; background-color: #fdf8f0; padding: 14px 18px; margin: 0 0 16px; color: #8a5c22; font-size: 14.5px; text-align: left`——虚线橙框，像图纸上圈出的手写批注
- 代码块：`<pre>` 底 `#e7eff7`、文字 `#23405c`、`border: 1px solid #c9d9e8; padding: 15px 17px; font-size: 13px`；行内 code：底 `#e7eff7`、文字 `#1d5a8a`
- 列表前缀用制图编号：`<span style="color: #1d5a8a; font-family: Menlo, Consolas, monospace;">[1]</span>&nbsp;&nbsp;` 递增；无序用 `▹&nbsp;&nbsp;`
- 表格（规格表是主场）：表头 `background-color: #1d5a8a; color: #f5f8fb; font-weight: 700`，单元格 `border: 1px solid #c9d9e8; padding: 9px 11px; font-size: 14px`

## 分寸提醒

网格底纹只在主容器上出现一次，卡片内部必须纯白——纹上叠纹图纸就脏了。橙褐色只属于"批注"语义（提醒、易错、经验），普通强调一律用蓝。
