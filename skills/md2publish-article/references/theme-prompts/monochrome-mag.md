# monochrome-mag 黑白杂志（扩展主题）

> 时尚杂志的纯黑白排版：超大黑标题、细线、无一处彩色。适合时尚、摄影、艺术评论、人物特稿。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

一本高级时装杂志的内页：力量全部来自字号对比和黑白灰的秩序。与 ink-wash（水墨纸感、朱砂点睛）不同，这里是现代都市的黑——冷、硬、时髦，且**真正零彩色**。

## 色彩系统

- 纯白底：`#ffffff`（主容器）
- 纯黑：`#111111`
- 中灰：`#767676`
- 浅灰底：`#f2f2f2`
- 细线：`#e0e0e0`
- 没有强调色。强调就是更黑、更大、更粗。

## 容器与布局

- 主容器：`background-color: #ffffff; padding: 44px 18px; letter-spacing: 0.3px`
- 无卡片；章节间距 52px，节前一根全宽细线：`border-top: 1px solid #e0e0e0; margin: 52px 0 0`

## 标题体系

- h2：杂志大标题——`font-size: 30px; font-weight: 900; color: #111111; text-align: left; margin: 24px 0 20px; line-height: 1.25; letter-spacing: -0.5px`（负字距，大字号才压得住）
- h3：小型大写栏目题——`font-size: 13px; font-weight: 700; color: #111111; letter-spacing: 4px; text-align: left; margin: 30px 0 14px`，英文转大写

## 正文与强调

- 段落：`font-size: 15.5px; line-height: 1.8; color: #111111; margin: 0 0 16px; text-align: left`
- strong：`font-weight: 800`（不变色）
- em / 关键句：`border-bottom: 2px solid #111111; padding-bottom: 1px`（黑色下划线替代变色）
- 图片说明、注脚：`font-size: 13px; color: #767676; letter-spacing: 1px`

## 引用 / 代码 / 列表 / 表格

- 引用块（人物语录是主场）：放大处理——`font-size: 20px; font-weight: 700; color: #111111; line-height: 1.5; padding: 8px 0 8px 20px; border-left: 4px solid #111111; margin: 28px 0; text-align: left`，引语后另起一行小灰字署名
- 代码块：`<pre>` 底 `#f2f2f2`、文字 `#111111`、`padding: 16px 18px; font-size: 13px`（无边框无圆角）；行内 code：底 `#f2f2f2`、`padding: 2px 6px`
- 列表前缀 `—&nbsp;&nbsp;`（破折号，编辑感）
- 表格：表头 `border-bottom: 2px solid #111111; font-weight: 800`，单元格只有 `border-bottom: 1px solid #e0e0e0; padding: 12px 10px; font-size: 14px`——无竖线

## 分寸提醒

这个主题的诱惑是"加一点颜色提亮"——不行，一滴彩色都会毁掉整个气场。层级不够时的正确做法是拉大字号差距，而不是引入颜色。
