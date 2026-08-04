# washi-spring 和纸樱色（扩展主题）

> 和纸白 + 灰樱粉 + 抹茶绿的日式素净（比 candy-pop 的马卡龙粉更灰、更成熟）。适合日系生活、料理、旅日见闻、器物美学。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

一页装帧考究的日文生活杂志：颜色像被和纸滤过一层，粉是樱花落地后的粉，绿是抹茶粉的绿。克制、对称、大量呼吸感，装饰只有细线。

## 色彩系统

- 和纸白底：`#faf6f2`（主容器）
- 正文墨鼠色：`#4a4340`
- 深樱（主强调，文字色）：`#b56b7d`——strong、h3、徽章文字，这是读者真正看得见的强调
- 灰樱粉（线色，不作文字色）：`#d98e9f`——h2 上下双细线、边框、底纹。标注成"线色"是有意的：它太淡，当文字色读不清，而一个只当细线用的颜色不能算主强调，否则整篇会看不出强调在哪
- 抹茶绿（副强调）：`#8a9b6e`
- 次级鼠灰：`#8f8781`
- 樱粉底：`#f3e9e7`
- 边线：`#e5dcd4`

## 容器与布局

- 主容器：`background-color: #faf6f2; padding: 44px 16px; letter-spacing: 1px`
- 无卡片；章节间距 48px，节与节之间一根居中细线：`width: 60px; border-top: 1px solid #e5dcd4; margin: 48px auto`

## 标题体系

- h2：和式上下双细线——`text-align: center; font-size: 18px; font-weight: 600; color: #4a4340; letter-spacing: 6px; margin: 0 0 24px; padding: 10px 0; border-top: 1px solid #d98e9f; border-bottom: 1px solid #d98e9f`
- h3：`font-size: 15.5px; font-weight: 600; color: #4a4340; text-align: left; margin: 28px 0 14px`，前缀 `<span style="color: #8a9b6e;">◦&nbsp;</span>`

## 正文与强调

- 段落：`font-size: 15.5px; line-height: 1.95; color: #4a4340; margin: 0 0 20px; text-align: left`——行高大，字距 1px，读起来慢而稳
- strong：`color: #b56b7d; font-weight: 600`
- em / 日文词、器物名：`color: #8a9b6e`

## 引用 / 代码 / 列表 / 表格

- 引用块：`background-color: #f3e9e7; padding: 16px 20px; margin: 0 0 20px; color: #8f8781; font-size: 14.5px; line-height: 1.9; text-align: left`（无边框无圆角——一块安静的樱色）
- 代码块：`<pre>` 底 `#f1ebe4`、文字 `#4a4340`、`border: 1px solid #e5dcd4; padding: 14px 16px; font-size: 13px`；行内 code：底 `#f3e9e7`、文字 `#b56b7d`
- 列表前缀 `・&nbsp;&nbsp;`（日式中点）
- 表格：表头底 `#f3e9e7`、文字 `#b56b7d; font-weight: 600`，单元格 `border: 1px solid #e5dcd4; padding: 10px 12px; font-size: 14px`

## 收尾

文末居中一个「終」字：`<p style="text-align: center; margin: 40px 0 0;"><span style="display: inline-block; border: 1px solid #d98e9f; color: #b56b7d; font-size: 13px; padding: 3px 8px; letter-spacing: 2px;">終</span></p>`

## 分寸提醒

粉与抹茶的比例约 3:1，粉是主角。任何元素都不用投影和大圆角——和纸的美在"平"，一切立体感都是多余的。
