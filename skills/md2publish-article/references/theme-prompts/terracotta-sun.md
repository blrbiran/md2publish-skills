# terracotta-sun 陶土阳光（扩展主题）

> 赤陶橙 + 沙米色 + 橄榄绿的地中海暖土气息，拱形圆角的松弛感。适合旅行游记、美食探店、手工生活、假日随笔。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

南欧小城午后的墙面：晒暖的陶土、粗粝的沙色、一点橄榄树的绿。与 autumn-warm（柔光文艺、精致卡片）的区别在质感——这里是"土"的、饱和更高的、边角带拱形的，像手工陶器而不是艺术相册。

## 色彩系统

- 沙米底：`#f8f0e7`（主容器）
- 正文深陶褐：`#4f382b`
- 赤陶橙（主强调）：`#c2593b`
- 深陶红：`#8f3f28`
- 橄榄绿（副强调，少用）：`#6f7a4d`
- 沙色块：`#efe0cd`
- 边线：`#e0cdb5`

## 容器与布局

- 主容器：`background-color: #f8f0e7; padding: 40px 14px; letter-spacing: 0.5px`
- 章节卡片带拱门圆角：`background-color: #fdf8f1; border: 1px solid #e0cdb5; border-radius: 24px 24px 8px 8px; padding: 26px 22px; margin: 0 0 34px`——上大下小的圆角是本主题的签名，像地中海拱窗

## 标题体系

- h2：`display: inline-block; background-color: #c2593b; color: #fdf8f1; font-size: 17px; font-weight: 700; padding: 7px 18px; border-radius: 18px 18px 4px 4px; margin: 0 0 20px; text-align: left`（拱形小圆角与卡片呼应）
- h3：`font-size: 16px; font-weight: 700; color: #8f3f28; text-align: left; margin: 26px 0 12px`，前缀 `<span style="color: #6f7a4d;">☘&nbsp;</span>` 可换 `❋`

## 正文与强调

- 段落：`font-size: 15.5px; line-height: 1.85; color: #4f382b; margin: 0 0 17px; text-align: left`
- strong：`color: #c2593b; font-weight: 700`
- em / 地名、菜名：`color: #6f7a4d`

## 引用 / 代码 / 列表 / 表格

- 引用块：`background-color: #efe0cd; border-radius: 16px 16px 6px 6px; padding: 16px 20px; margin: 0 0 17px; color: #7d6250; font-size: 14.5px; line-height: 1.8; text-align: left`
- 代码块：`<pre>` 底 `#efe0cd`、文字 `#4f382b`、`border-radius: 10px; padding: 14px 16px; font-size: 13px`；行内 code：底 `#efe0cd`、文字 `#8f3f28`
- 列表前缀 `●&nbsp;&nbsp;`（陶橙 span：`<span style="color: #c2593b;">●</span>&nbsp;&nbsp;`）
- 表格：表头底 `#efe0cd`、文字 `#8f3f28; font-weight: 700`，单元格 `border: 1px solid #e0cdb5; padding: 9px 11px; font-size: 14px`

## 分寸提醒

橄榄绿是"一点绿意"，只用于 em 和 h3 前缀，出现频率低于陶橙的一半。拱形圆角只在卡片、h2、引用三处——处处拱形就成了童话城堡。
