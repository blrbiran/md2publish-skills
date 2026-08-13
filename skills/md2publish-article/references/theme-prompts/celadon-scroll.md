# celadon-scroll 青瓷卷轴（扩展主题）

> 绢黄纸底 + 青瓷绿 + 朱红印色的彩色国风（区别于黑白的 ink-wash）。适合传统文化、节气民俗、历史、茶酒器物。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

一卷设色典雅的绢本：青绿是山水的颜色，朱红是钤印的颜色，绢黄是时间的颜色。整体像博物馆图录的内页——古意来自配色与纹样级的细节，不靠仿古字体堆砌。

## 色彩系统

- 绢黄底：`#f6f0e2`（主容器）
- 正文墨褐：`#3a3226`
- 青瓷绿（主强调）：`#2c6e63`
- 朱红（印色，少用）：`#a63d2f`
- 次级褐灰：`#6f665a`
> 次级褐灰的明度是被对比度铁律钉住的：在引用/代码底 `#efe8d5` 上 4.61:1、卡片 `#fbf7ec` 上 5.27:1。**`#efe8d5` 那一处就是它的下限**——2026-08 为此压深过一档（压之前 3.82:1，差 0.68 不达 AA），不要调回去（规则 11）。
- 边线：`#d8cfb8`
- 引用/代码底：`#efe8d5`

## 容器与布局

- 主容器：`background-color: #f6f0e2; padding: 42px 14px; letter-spacing: 1px`
- 章节卡片：`background-color: #fbf7ec; border: 1px solid #d8cfb8; border-radius: 4px; padding: 26px 22px; margin: 0 0 34px`——小圆角，像装裱的绫边；无阴影

## 标题体系

- 衬线字族贯穿标题：`Georgia, 'Songti SC', 'Noto Serif SC', serif`
- h2：居中 + 两侧对称饰线——`<h2 style="text-align: center; font-size: 20px; font-weight: 600; color: #2c6e63; letter-spacing: 6px; margin: 0 0 24px;"><span style="color: #d8cfb8;">─&nbsp;</span>标题文本<span style="color: #d8cfb8;">&nbsp;─</span></h2>`
- h3：`font-size: 16px; font-weight: 600; color: #3a3226; text-align: left; margin: 28px 0 14px`，前缀朱红印点 `<span style="color: #a63d2f;">◉&nbsp;</span>`

## 正文与强调

- 段落：`font-size: 16px; line-height: 1.9; color: #3a3226; margin: 0 0 20px; text-align: left`
- strong：`color: #2c6e63; font-weight: 600`
- em：`color: #a63d2f`（朱红是钤印，每屏不超过 2 处）
- 诗词、古文引文：居中排，`color: #6f665a; letter-spacing: 2px`

## 引用 / 代码 / 列表 / 表格

- 引用块：`background-color: #efe8d5; border-left: 3px solid #2c6e63; padding: 16px 20px; margin: 0 0 20px; color: #6f665a; font-size: 15px; line-height: 1.85; text-align: left`
- 代码块：`<pre>` 底 `#efe8d5`、文字 `#4a4234`、`border: 1px solid #d8cfb8; padding: 15px 17px; font-size: 13px`；行内 code：底 `#efe8d5`、文字 `#2c6e63`
- 列表前缀 `·&nbsp;&nbsp;`（间隔号，句读感）
- 表格：表头底 `#e5dcc4`、单元格 `border: 1px solid #d8cfb8; padding: 10px 12px; font-size: 14px`

## 收尾

文末右下角一枚朱红小印：`<p style="text-align: right; margin: 36px 0 0;"><span style="display: inline-block; border: 1px solid #a63d2f; color: #a63d2f; font-size: 13px; padding: 3px 6px; letter-spacing: 2px;">某某印</span></p>`（印文按公众号名或文章主题定，两到四字）。
