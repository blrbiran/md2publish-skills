# botanic-press 植物标本（扩展主题）

> 深绿 + 米白 + 干花褐的标本馆学术气（区别于浅绿清单感的 mint-breeze）。适合自然科普、园艺植物、环保议题、博物随笔。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

一页十九世纪植物志：压平的标本、手写的拉丁学名标签、沉稳的墨绿。学术的严谨和自然的柔软共存——线条细、字距稳、绿是深的。

## 色彩系统

- 米白底：`#f4f5ef`（主容器）
- 正文墨绿灰：`#2e3a2a`
- 标本绿（主强调）：`#3f6b3f`
- 干花褐（副强调）：`#7e6447`
- 次级灰绿：`#77816d`
- 浅绿米块：`#e9ecdf`
- 边线：`#d5d9c8`

> 干花褐的明度是被对比度铁律钉住的：在浅绿米块 `#e9ecdf` 上 4.61:1、卡片 `#fbfcf7` 上 5.36:1。**浅绿米块那一处就是它的下限**——2026-08 为此压深过一档（压之前 4.00:1，差 0.50 不达 AA），不要调回去（规则 11）。

## 容器与布局

- 主容器：`background-color: #f4f5ef; padding: 42px 14px; letter-spacing: 0.6px`
- 章节卡片：`background-color: #fbfcf7; border: 1px solid #d5d9c8; border-radius: 6px; padding: 26px 22px; margin: 0 0 34px`——小圆角细边，像标本卡纸

## 标题体系

- 标题衬线字族：`Georgia, 'Songti SC', 'Noto Serif SC', serif`
- h2：`font-size: 20px; font-weight: 600; color: #3f6b3f; text-align: left; margin: 0 0 18px; padding-bottom: 8px; border-bottom: 1px solid #d5d9c8`，尾缀一枚小叶饰 `<span style="color: #77816d;">&nbsp;❦</span>`
- h3：`font-size: 16px; font-weight: 600; color: #2e3a2a; text-align: left; margin: 26px 0 12px`，前缀 `<span style="color: #3f6b3f;">❧&nbsp;</span>`

## 正文与强调

- 段落：`font-size: 15.5px; line-height: 1.85; color: #2e3a2a; margin: 0 0 18px; text-align: left`
- strong：`color: #3f6b3f; font-weight: 700`
- em / 学名、外来词：`color: #7e6447`（拉丁学名保持斜体语义时也用此色，不用 italic 标签）

## 引用 / 代码 / 列表 / 表格

- 引用块（标本标签样式）：`background-color: #fbfcf7; border: 1px solid #d5d9c8; border-left: 4px solid #3f6b3f; padding: 14px 18px; margin: 0 0 18px; color: #77816d; font-size: 14px; line-height: 1.8; text-align: left`，衬线字族——像贴在标本旁的说明卡
- 代码块：`<pre>` 底 `#e9ecdf`、文字 `#2e3a2a`、`border: 1px solid #d5d9c8; padding: 14px 16px; font-size: 13px`；行内 code：底 `#e9ecdf`、文字 `#3f6b3f`
- 列表前缀 `·&nbsp;&nbsp;`
- 有序列表序号：**判断层的手工可选项，不是机械规范，`theme.json` 里刻意不配 `list_prefix_ol_html`**。只有物种清单、标本条目这类内容，手写路径才把序号写成褐色 `<span style="color: #7e6447; font-weight: 700;">No.1</span>&nbsp;&nbsp;`；机械路径一律退回纯文本 `N.`。原因是 `list_prefix_ol_html` 是全局字段，配上去会给每篇文章的每个有序列表都套上 `No.`，而「这个列表是不是物种/条目清单」属于内容语义，机械层判不了（规则 14 的判例）
<!-- census-ok: UNMOUNTED list_prefix_ol_html 规范限定「物种/条目清单」，而 list_prefix_ol_html 是全局字段、会给每篇文章的每个有序列表都套上 No. 前缀；内容类型机械层判不了，所以这条按上一行写明的方式留在判断层手工执行，不配字段 -->
- 表格：表头底 `#e9ecdf`、文字 `#3f6b3f; font-weight: 700`，单元格 `border: 1px solid #d5d9c8; padding: 9px 11px; font-size: 14px`

## 分寸提醒

绿只有一种（`#3f6b3f`），不引入第二种绿——多绿即杂。花饰符号（❦ ❧）只在标题处，正文里一个都不放。
