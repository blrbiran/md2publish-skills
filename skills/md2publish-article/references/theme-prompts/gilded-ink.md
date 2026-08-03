# gilded-ink 鎏金墨黑（扩展主题）

> 米白纸面、墨黑正文、古金细线，轻奢商务感。适合商业分析、财经解读、发布会/财报解读、品牌内容。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

高级感来自"金线"而非"金块"：金色只以细线、字符、小面积出现，永不做大底色。整体像一份精装年报的内页——庄重、留白、每一根线都有分寸。

## 色彩系统

- 米白底：`#faf8f4`（主容器）
- 墨黑正文：`#1c1a17`
- 古金（主强调）：`#b08a3e`
- 深金（strong 用，更沉）：`#8f6f2f`
- 次级灰褐：`#6b6355`
- 金边线：`#e5ddc9`
- 引用/代码底：`#f5f1e8`

## 容器与布局

- 主容器：`background-color: #faf8f4; padding: 44px 14px; letter-spacing: 1px`
- 章节卡片：`background-color: #ffffff; border: 1px solid #e5ddc9; border-radius: 8px; padding: 28px 24px; margin: 0 0 36px`——无阴影，靠细金边立起来

## 标题体系

- h2：居中 + 上下金线——`text-align: center; font-size: 19px; font-weight: 600; color: #1c1a17; letter-spacing: 5px; margin: 0 0 24px; padding: 12px 0; border-top: 1px solid #b08a3e; border-bottom: 1px solid #b08a3e`，衬线字族 `Georgia, 'Songti SC', 'Noto Serif SC', serif`
- h3：`font-size: 16px; font-weight: 600; color: #1c1a17; text-align: left; margin: 28px 0 14px`，前缀金色菱形 `<span style="color: #b08a3e;">◆&nbsp;</span>`

## 正文与强调

- 段落：`font-size: 15.5px; line-height: 1.85; color: #1c1a17; margin: 0 0 18px; text-align: left`
- strong：`color: #8f6f2f; font-weight: 700`
- em：`color: #6b6355`
- 关键数字（财经文常见）可用 `color: #8f6f2f; font-weight: 700; font-size: 17px` 微放大

## 引用 / 代码 / 列表 / 表格

- 引用块：`background-color: #f5f1e8; border-left: 2px solid #b08a3e; padding: 16px 20px; margin: 0 0 18px; color: #6b6355; font-size: 14.5px; line-height: 1.8; text-align: left`
- 代码块：`<pre>` 底 `#f5f1e8`、文字 `#3a352c`、`border: 1px solid #e5ddc9; border-radius: 6px; padding: 15px 17px; font-size: 13px`；行内 code：底 `#f5f1e8`、文字 `#8f6f2f`
- 列表前缀 `◆&nbsp;&nbsp;`（金色菱形 span：`<span style="color: #b08a3e;">◆</span>&nbsp;&nbsp;`）
- 表格：表头 `background-color: #1c1a17; color: #faf8f4`，单元格 `border: 1px solid #e5ddc9; padding: 10px 12px; font-size: 14px`——黑金表头是本主题的记忆点

## 分寸提醒

金色出现面积超过屏幕 5% 就俗了。大面积永远是米白和墨黑，金只在留白处走线。
