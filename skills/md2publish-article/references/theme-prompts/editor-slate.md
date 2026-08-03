# editor-slate 代码编辑器（扩展主题）

> 浅色 GitHub 阅读界面 + 深色代码块的经典组合，开发者最熟悉的视觉语言。适合技术教程、开发实践、工具评测。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

README 的阅读体验：克制的灰蓝体系、清晰的层级线、唯一的链接蓝，代码块像编辑器里一样是深色的——正文是文档，代码是主角。

## 色彩系统

- 页面底：`#f6f8fa`（主容器）
- 正文：`#24292f`
- 链接蓝（强调）：`#0969da`
- 次级灰：`#57606a`
- 边线：`#d0d7de`
- 深色代码块：底 `#0d1117`、文字 `#e6edf3`
- 行内代码底：`#eff1f3`

## 容器与布局

- 主容器：`background-color: #f6f8fa; padding: 32px 12px`
- 正文区包一层白卡：`background-color: #ffffff; border: 1px solid #d0d7de; border-radius: 8px; padding: 28px 20px`（全文一张大卡，不逐节切卡）

## 标题体系

- h2：`font-size: 20px; font-weight: 600; color: #24292f; text-align: left; margin: 36px 0 16px; padding-bottom: 8px; border-bottom: 1px solid #d0d7de`
- h3：`font-size: 17px; font-weight: 600; color: #24292f; text-align: left; margin: 28px 0 12px`，标题前置等宽 `#` 前缀：`<span style="color: #0969da; font-family: Menlo, Consolas, monospace;">#&nbsp;</span>`

## 正文与强调

- 段落：`font-size: 15px; line-height: 1.75; color: #24292f; margin: 0 0 16px; text-align: left; overflow-wrap: break-word`
- strong：`color: #24292f; font-weight: 700`（GitHub 风格不变色）
- em / 关键术语：`color: #0969da`
- 链接文本统一 `color: #0969da`

## 引用 / 代码 / 列表 / 表格

- 引用块：`border-left: 4px solid #d0d7de; padding: 4px 0 4px 16px; margin: 0 0 16px; color: #57606a; font-size: 15px; text-align: left`（GitHub blockquote 原样）
- 代码块：`<pre style="background-color: #0d1117; border-radius: 6px; padding: 16px; overflow-x: auto; text-align: left;">`，`<code style="display: block; white-space: normal; color: #e6edf3; font-size: 13px; line-height: 1.6; font-family: Menlo, Consolas, monospace;">`——深色是本主题的招牌，不要改成浅色
- 行内 code：`background-color: #eff1f3; color: #24292f; padding: 2px 6px; border-radius: 4px; font-size: 13px; font-family: Menlo, Consolas, monospace`
- 列表前缀 `-&nbsp;&nbsp;`（连字符，Markdown 味）
- 表格：表头 `background-color: #f6f8fa; font-weight: 600`，单元格 `border: 1px solid #d0d7de; padding: 8px 12px; font-size: 14px`

## 提示卡（可选）

文中"注意/警告"类内容可用 GitHub Alert 风格：`border-left: 4px solid #0969da; background-color: #ddf4ff; padding: 12px 16px; border-radius: 0 6px 6px 0`，警告用橙 `#bc4c00` / 底 `#fff1e5`。
