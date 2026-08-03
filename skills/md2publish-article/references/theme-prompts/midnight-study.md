# midnight-study 午夜书房（扩展主题）

> 暖调深棕黑底 + 台灯琥珀光，深夜阅读的沉浸感（区别于冷色调的 cyber-neon）。适合夜读故事、悬疑连载、长篇小说节选、深夜电台式内容。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

只开一盏台灯的书房：底色是暗下来的木头和皮革，文字是被灯光照亮的纸。暖不刺眼、暗不压抑——读者应该想一直读下去，而不是想调亮屏幕。

## 色彩系统

- 暗木底：`#211c18`（主容器）
- 皮革面板：`#2b241e`
- 正文暖纸色：`#e3d9c8`
- 琥珀光（主强调）：`#d9a05b`
- 深琥珀：`#b57f3c`
- 次级暖灰：`#96897a`
- 边线：`#42382e`

## 容器与布局

- 主容器：`background-color: #211c18; padding: 40px 14px; letter-spacing: 0.6px`
- 章节面板：`background-color: #2b241e; border: 1px solid #42382e; border-radius: 12px; padding: 26px 22px; margin: 0 0 34px`——无阴影（暗底上阴影无意义）

## 标题体系

- 标题用衬线字族：`Georgia, 'Songti SC', 'Noto Serif SC', serif`
- h2：`font-size: 19px; font-weight: 600; color: #d9a05b; text-align: left; margin: 0 0 20px; padding-bottom: 10px; border-bottom: 1px solid #42382e; letter-spacing: 2px`
- h3：`font-size: 16px; font-weight: 600; color: #e3d9c8; text-align: left; margin: 26px 0 12px`，前缀 `<span style="color: #d9a05b;">§&nbsp;</span>`

## 正文与强调

- 段落：`font-size: 16px; line-height: 1.95; color: #e3d9c8; margin: 0 0 20px; text-align: left`——行高全主题最大，夜读节奏慢
- strong：`color: #d9a05b; font-weight: 600`
- em / 心理描写、旁白：`color: #96897a`

## 引用 / 代码 / 列表 / 表格

- 引用块（对白、信件、回忆）：`background-color: #251f19; border-left: 2px solid #b57f3c; padding: 16px 20px; margin: 0 0 20px; color: #96897a; font-size: 15px; line-height: 1.9; text-align: left`，衬线字族
- 代码块：`<pre>` 底 `#191512`、文字 `#e3d9c8`、`border: 1px solid #42382e; border-radius: 8px; padding: 15px 17px; font-size: 13px`；行内 code：底 `#191512`、文字 `#d9a05b`
- 列表前缀 `·&nbsp;&nbsp;`
- 表格：表头底 `#191512`、文字 `#d9a05b`，单元格 `border: 1px solid #42382e; padding: 9px 11px; font-size: 14px; color: #e3d9c8`

## 分寸提醒

暗色主题通用风险：每个文字元素都必须显式写亮色 `color`，漏一处就是暗底黑字；微信 App 的深色/浅色模式都要手机预览。另外琥珀色不做大底色——台灯的光晕是一小圈，不是满屋顶灯。
