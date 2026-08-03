# retro-phosphor 磷光终端（扩展主题·暗色）

> 近黑绿底 + 磷光绿单色 + 等宽字标题，八十年代 CRT 终端的复古计算美学（与未来感的 cyber-neon 相反方向）。适合计算机历史、黑客文化、复古游戏、命令行工具专题。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

一台还在工作的老终端：单色磷光屏，信息全靠亮度分级和 ASCII 符号组织。整个主题只有一种颜色的三个亮度——这是它和所有其他主题的根本区别。

## 色彩系统（单色三级）

- 磷屏底：`#0d120d`（主容器）
- 面板：`#131a13`
- 正文磷光绿（中亮）：`#a8d8a0`
- 高亮绿（强调）：`#5ee87a`
- 暗绿（次级/注释）：`#5a7a58`
- 边线：`#243524`

## 容器与布局

- 主容器：`background-color: #0d120d; padding: 36px 12px; letter-spacing: 0.5px`
- 章节面板：`background-color: #131a13; border: 1px solid #243524; border-radius: 4px; padding: 22px 18px; margin: 0 0 30px`

## 标题体系

- 标题一律等宽字族：`Menlo, Consolas, 'Courier New', monospace`
- h2：`font-size: 17px; font-weight: 700; color: #5ee87a; text-align: left; margin: 0 0 18px; letter-spacing: 1px`，格式为 `<span style="color: #5a7a58;">$&nbsp;</span>标题文本`（shell 提示符）
- h3：`font-size: 15px; font-weight: 700; color: #a8d8a0; text-align: left; margin: 24px 0 12px`，前缀 `<span style="color: #5a7a58;">##&nbsp;</span>`
- 章节分隔可用 ASCII 线：`<p style="color: #243524; font-size: 13px; margin: 0 0 18px; font-family: Menlo, Consolas, monospace; text-align: left;">────────────────────</p>`

## 正文与强调

- 段落：`font-size: 15px; line-height: 1.8; color: #a8d8a0; margin: 0 0 16px; text-align: left`（正文可用普通字族，全文等宽会太累）
- strong：`color: #5ee87a; font-weight: 700`
- em / 注释语气：`color: #5a7a58`，可加等宽前缀 `<span style="font-family: Menlo, Consolas, monospace;">//&nbsp;</span>`

## 引用 / 代码 / 列表 / 表格

- 引用块（日志/摘录）：`background-color: #0a0e0a; border-left: 2px solid #5a7a58; padding: 14px 16px; margin: 0 0 16px; color: #5a7a58; font-size: 14px; text-align: left; font-family: Menlo, Consolas, monospace`
- 代码块（主场，和正文区分靠更黑的底）：`<pre>` 底 `#080b08`、文字 `#a8d8a0`、`border: 1px solid #243524; border-radius: 4px; padding: 16px; font-size: 13px`；行内 code：底 `#080b08`、文字 `#5ee87a`、`padding: 2px 6px`
- 列表前缀等宽标记：`<span style="color: #5ee87a; font-family: Menlo, Consolas, monospace;">*</span>&nbsp;&nbsp;`；状态类条目可用 `[ok]` / `[!!]`（`#5ee87a` / `#5a7a58`）
- 表格：表头底 `#080b08`、文字 `#5ee87a; font-family: Menlo, Consolas, monospace`，单元格 `border: 1px solid #243524; padding: 8px 10px; font-size: 13px; color: #a8d8a0`

## 分寸提醒

单色是纪律：除三级绿之外一个色相都不进（连红色警告都用 `[!!]` + 暗绿表达）。暗色通用风险照旧：所有文字显式亮色 `color`；微信 App 深浅双模式都要手机预览。扫描线、闪烁光标等拟物效果一律不做——CSS 动画会被微信剥掉，静态假装反而廉价。
