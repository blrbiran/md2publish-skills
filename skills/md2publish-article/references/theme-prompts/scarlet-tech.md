# scarlet-tech 数码正红（扩展主题）

> 纯白数字界面 + 一抹正红，少数派式的利落。适合数码测评、效率工具、App 推荐、消费电子。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

一篇认真做过信息设计的数码测评：白底让产品图和截图最干净，红色负责导航和结论，灰阶负责一切过渡。理性、利落、结论前置。

## 色彩系统

- 纯白底：`#ffffff`（主容器）
- 正文炭灰：`#2c2c2e`
- 正红（主强调）：`#d71a1b`
- 次级灰：`#8a8a8e`
- 浅灰底：`#f4f4f6`
- 边线：`#e3e3e6`

## 容器与布局

- 主容器：`background-color: #ffffff; padding: 40px 16px; letter-spacing: 0.2px`
- 无卡片；章节间距 48px，靠 h2 的红色标记建立节奏

## 标题体系

- h2：`font-size: 21px; font-weight: 700; color: #2c2c2e; text-align: left; margin: 48px 0 16px; padding-left: 12px; border-left: 4px solid #d71a1b`
- h3：`font-size: 17px; font-weight: 600; color: #2c2c2e; text-align: left; margin: 28px 0 12px`

## 正文与强调

- 段落：`font-size: 15.5px; line-height: 1.75; color: #2c2c2e; margin: 0 0 16px; text-align: left`
- strong：`color: #d71a1b; font-weight: 600`
- em / 型号参数：`color: #8a8a8e`
- 优缺点小结用符号对：`<span style="color: #d71a1b; font-weight: 700;">＋</span>` / `<span style="color: #8a8a8e; font-weight: 700;">－</span>` 开头的模拟列表行

## 引用 / 代码 / 列表 / 表格

- 引用块（结论/一句话点评）：`background-color: #f4f4f6; border-radius: 8px; padding: 16px 20px; margin: 0 0 16px; color: #2c2c2e; font-size: 15px; font-weight: 500; text-align: left`，首词可用红色引导（如 `<span style="color: #d71a1b; font-weight: 700;">结论：</span>`）
- 代码块：`<pre>` 底 `#f4f4f6`、文字 `#2c2c2e`、`border: 1px solid #e3e3e6; border-radius: 8px; padding: 14px 16px; font-size: 13px`；行内 code：底 `#f4f4f6`、文字 `#d71a1b`
- 列表前缀 `·&nbsp;&nbsp;`；对比列表可用上面的 ＋/－ 符号对
- 表格（参数对比是主场）：表头底 `#f4f4f6`、`font-weight: 600`，单元格 `border: 1px solid #e3e3e6; padding: 10px 12px; font-size: 14px`；对比表中的推荐项单元格可整格 `color: #d71a1b; font-weight: 600`

## 分寸提醒

红色只出现在：h2 边线、strong、结论引导词、＋号、推荐项。除此之外全是黑白灰。测评的公信力一半来自克制的配色——红一泛滥就像带货。
