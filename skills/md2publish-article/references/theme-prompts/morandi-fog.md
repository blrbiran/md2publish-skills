# morandi-fog 莫兰迪雾（扩展主题）

> 低饱和灰玫 + 雾蓝的莫兰迪色系，一切颜色都蒙着一层灰。高级、安静、不抢戏。适合美学、设计、慢生活、女性向内容。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

莫兰迪静物画的质感：没有一种颜色是纯的，对比全靠明度微差。避免任何高饱和色、纯黑、纯白——连正文都是暖灰而非黑。

## 色彩系统

- 雾灰底：`#eeecea`（主容器）
- 卡片：`#f7f5f3`
- 正文暖灰：`#4a4846`
- 灰玫（主强调）：`#b08e8a`
- 雾蓝（辅强调）：`#4e6774`

> 雾蓝的明度是被对比度铁律钉住的：在卡片 `#f7f5f3` 上 5.49:1、主容器 `#eeecea` 上 5.07:1、引用底 `#e6e1de` 上 4.60:1。**最紧的是引用底那一处，它就是这支蓝的下限**——2026-08 为它压深过一档（压之前 4.41:1，差 0.09 不达 AA）。**不要为了莫兰迪的「明度微差」把它调浅**——再浅的一档在卡片上只有 2.4 左右，h3 标题实测不可读。低饱和是这个主题的手段，降对比度不是。
- 次级灰：`#66635f`
> 次级灰的明度同样是被对比度铁律钉住的：在引用/代码底 `#e6e1de` 上 4.61:1、卡片 `#f7f5f3` 上 5.49:1。**引用底那一处就是它的下限**——2026-08 为此压深过一档（压之前 2.71:1，差 1.79 不达 AA），不要调回去（规则 11）。和雾蓝同一个道理：莫兰迪的明度微差是手段，不是让引用块正文停在 2.71:1 的理由。
- 引用底：`#e6e1de`

## 容器与布局

- 主容器：`background-color: #eeecea; padding: 42px 14px; letter-spacing: 0.8px`
- 章节卡片：`background-color: #f7f5f3; border-radius: 14px; padding: 26px 22px; margin: 0 0 36px; box-shadow: 0 6px 20px rgba(74, 72, 70, 0.06)`——阴影必须极轻，若有似无

## 标题体系

- h2：荧光笔色带效果——`display: inline-block; font-size: 19px; font-weight: 600; color: #4a4846; margin: 0 0 20px; padding: 0 4px; background-image: linear-gradient(transparent 62%, rgba(176, 142, 138, 0.35) 62%); text-align: left`
- h3：`font-size: 16px; font-weight: 600; color: #4e6774; text-align: left; margin: 26px 0 12px; padding-left: 10px; border-left: 3px solid #4e6774`（雾蓝做文字 + 细条，与 h2 灰玫区分层级）

## 正文与强调

- 段落：`font-size: 15.5px; line-height: 1.85; color: #4a4846; margin: 0 0 18px; text-align: left`
- strong：`color: #b08e8a; font-weight: 600`
- em：`color: #4e6774`
- 雾蓝的文字落点不能只有斜体——中文文章里斜体可能整篇为零，那样它就只剩 h3 那根 3px 细条，读者感觉不到这个颜色存在。**h3 的标题文字就是它的保底落点**，不要把 h3 文字改回正文暖灰

## 引用 / 代码 / 列表 / 表格

- 引用块：`background-color: #e6e1de; border-radius: 10px; padding: 16px 20px; margin: 0 0 18px; color: #66635f; font-size: 14.5px; line-height: 1.8; text-align: left`
- 代码块：`<pre>` 底 `#e6e1de`、文字 `#55514e`、`border-radius: 10px; padding: 15px 17px; font-size: 13px`（无边框，靠色差）；行内 code：底 `#e6e1de`、文字 `#b08e8a`
- 列表前缀 `—&nbsp;&nbsp;`（破折号，轻于圆点）
- 表格：表头底 `#e6e1de`、单元格 `border: 1px solid #ddd8d4; padding: 9px 12px; font-size: 14px`

## 分寸提醒

灰玫和雾蓝是全部的颜色预算：同一屏内两种强调色出现总次数不宜超过 4 处。宁可素，不可花。
