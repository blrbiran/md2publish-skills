# cyber-neon 赛博霓虹（扩展主题）

> 深空蓝黑底 + 霓虹青/品红双色光，终端与夜城的科技感。适合 AI 前沿、游戏、加密/极客文化、未来主义话题。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

夜里亮着的显示器：暗底上两种霓虹各司其职——青色是信息，品红是警示/强调。光要"细"（细线、文字发色），不要大面积荧光底。

## 色彩系统

- 深空底：`#0f1420`（主容器）
- 面板底：`#171e2e`
- 正文亮灰：`#c9d2e3`
- 霓虹青（主强调）：`#39d0d8`
- 霓虹品红（副强调，少用）：`#ff2d95`
- 次级灰蓝：`#7a869e`
- 边线：`#2a3550`

## 容器与布局

- 主容器：`background-color: #0f1420; padding: 36px 12px; letter-spacing: 0.5px`
- 章节面板：`background-color: #171e2e; border: 1px solid #2a3550; border-radius: 10px; padding: 24px 20px; margin: 0 0 32px`，顶部一根霓虹线：`border-top: 2px solid #39d0d8`

## 标题体系

- h2：`font-size: 19px; font-weight: 700; color: #39d0d8; text-align: left; margin: 0 0 20px; letter-spacing: 2px`，前缀等宽终端符 `<span style="font-family: Menlo, Consolas, monospace; color: #7a869e;">&gt;_&nbsp;</span>`
- h3：`font-size: 16px; font-weight: 600; color: #c9d2e3; text-align: left; margin: 26px 0 12px; padding-left: 10px; border-left: 3px solid #ff2d95`

## 正文与强调

- 段落：`font-size: 15.5px; line-height: 1.8; color: #c9d2e3; margin: 0 0 16px; text-align: left`
- strong：`color: #39d0d8; font-weight: 600`
- em / 警示词：`color: #ff2d95`（每屏不超过 2 处，品红是警报不是装饰）

## 引用 / 代码 / 列表 / 表格

- 引用块：`background-color: #10182a; border-left: 2px solid #39d0d8; padding: 14px 18px; margin: 0 0 16px; color: #7a869e; font-size: 14.5px; text-align: left`
- 代码块：`<pre>` 底 `#0a0e18`、文字 `#c9d2e3`、`border: 1px solid #2a3550; border-radius: 8px; padding: 16px; font-size: 13px`——比面板更黑一档，像终端窗口；行内 code：底 `#0a0e18`、文字 `#39d0d8`、`padding: 2px 6px; border-radius: 4px`
- 列表前缀 `▸&nbsp;&nbsp;`（青色 span：`<span style="color: #39d0d8;">▸</span>&nbsp;&nbsp;`）
- 表格：表头 `background-color: #0a0e18; color: #39d0d8`，单元格 `border: 1px solid #2a3550; padding: 9px 11px; font-size: 14px; color: #c9d2e3`

## 分寸提醒

暗色主题的两个专属风险：一，所有文字必须显式写亮色 `color`，漏一处就是黑底黑字；二，微信 App 自身的深色/浅色模式可能对颜色做映射，发布前两种模式的手机预览都要看一眼。品红大面积使用会变成"促销页"，克制。
