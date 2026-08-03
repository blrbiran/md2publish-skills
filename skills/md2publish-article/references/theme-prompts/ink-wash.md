# ink-wash 水墨极简（扩展主题）

> 黑白灰水墨基调，朱砂色只在极少处点睛。大量留白、细线分隔、无阴影无纹理——像一页安静的宣纸。适合深度长文、评论、人文思辨。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

克制到近乎素净的阅读页面。视觉层次全靠字号、字重、留白和一根细线表达，不靠色块和装饰。朱砂红是唯一的颜色，出现频率要低——像印章落在水墨画上，多了就俗。

## 色彩系统

- 纸白背景：`#f7f6f2`（主容器）
- 正文墨色：`#2b2b28`
- 次级灰：`#6e6a63`（题注、引用、次要信息）
- 朱砂（唯一强调色）：`#b5432a`（仅用于 h3 标记、strong、分隔符号）
- 细线：`#d9d5cc`
- 引用/代码底：`#efede7`

## 容器与布局

- 主容器：`background-color: #f7f6f2; padding: 44px 16px; letter-spacing: 0.5px`
- **不用卡片**：内容直接排在纸面上，章节之间用 48px 上边距 + 一条居中短细线（`width: 36px; border-top: 1px solid #d9d5cc; margin: 48px auto`）分隔
- 全局无 box-shadow、无 border-radius 大圆角、无背景纹理

## 标题体系

- h2（章节）：`font-size: 21px; font-weight: 600; color: #2b2b28; text-align: center; letter-spacing: 4px; margin: 0 0 28px`，字体族优先衬线：`Georgia, 'Songti SC', 'Noto Serif SC', serif`
- h3（小节）：`font-size: 17px; font-weight: 600; color: #2b2b28; text-align: left; margin: 32px 0 16px`，标题文本前置一个朱砂竖线符号 `<span style="color: #b5432a;">丨</span>`

## 正文与强调

- 段落：`font-size: 16px; line-height: 1.9; color: #2b2b28; margin: 0 0 20px; text-align: left`（行高比常规大，制造留白感）
- strong：`color: #b5432a; font-weight: 600`（不加底色）
- em：`color: #6e6a63`，不用斜体（中文斜体渲染差），改用次级灰表达

## 引用 / 代码 / 列表 / 表格

- 引用块：`background-color: #efede7; padding: 18px 22px; margin: 0 0 20px; color: #6e6a63; font-size: 15px; line-height: 1.85; text-align: left`，无边框无圆角——一块安静的灰
- 代码块：`<pre>` 底 `#efede7`、文字 `#3d3a34`、`border-left: 2px solid #d9d5cc; padding: 16px 18px; font-size: 13px`；行内 code：`background-color: #efede7; color: #b5432a; padding: 2px 5px; font-size: 14px`
- 列表前缀用 `·&nbsp;&nbsp;`（间隔号，比实心圆点轻）
- 表格：表头底 `#efede7`、单元格 `border: 1px solid #d9d5cc; padding: 10px 12px; font-size: 14px`

## 收尾

文末居中放一个朱砂色小印章式符号：`<p style="text-align: center; color: #b5432a; font-size: 18px; margin: 40px 0 0;">□</p>` 可换为「完」字，`border: 1px solid #b5432a; display: inline-block; padding: 2px 6px; font-size: 13px`。
