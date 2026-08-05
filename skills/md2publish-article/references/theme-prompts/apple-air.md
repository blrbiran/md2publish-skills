# apple-air 苹果留白（扩展主题）

> 纯白、大留白、灰阶层级、唯一的科技蓝。发布会文案式的克制。适合产品介绍、设计评论、极简主义、效率方法论。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

Apple 产品页的呼吸感：没有卡片、没有边框、没有任何一根多余的线，层级全靠字号跳变和大间距。留白本身就是设计。

## 色彩系统

- 纯白底：`#ffffff`（主容器）
- 主文字：`#1d1d1f`
- 次级灰：`#6e6e73`
- 科技蓝（唯一强调色）：`#0071e3`
- 浅灰底（引用/代码）：`#f5f5f7`
- 极细线：`#d2d2d7`

## 容器与布局

- 主容器：`background-color: #ffffff; padding: 48px 18px; letter-spacing: 0.2px`
- 无卡片无边框；章节之间纯粹用 56px 上边距分隔——间距是全部主题里最大的
- 全局无阴影、无纹理

## 标题体系

- **不要写 eyebrow 引导语条款。**曾经有过一版：每个 h2 上方一行小号蓝字，内容「从该节主旨提炼 2–6 字、逐节不同」。它渲染不出来——机械层只能给全局固定串，逐节不同的内容它给不了。那一版被记为「已修复」，实测产物里蓝色仍只有 1 处：**加了一条渲染不出来的规范，审计从此闭嘴，产物一点没变**。蓝色的保底落点必须落在机械层给得出的元素上，见下面的列表前缀和 h3 前缀
- h2：字号跳变制造层级——`font-size: 26px; font-weight: 700; color: #1d1d1f; text-align: left; margin: 0 0 20px; letter-spacing: 0`（无任何装饰，就是大和粗）
- h3：`font-size: 18px; font-weight: 600; color: #1d1d1f; text-align: left; margin: 32px 0 12px`，前缀 `<span style="color: #0071e3;">▍&nbsp;</span>`（一道细蓝竖条，**蓝色的保底落点之一**）

## 正文与强调

- 段落：`font-size: 16px; line-height: 1.7; color: #1d1d1f; margin: 0 0 18px; text-align: left`
- 次要说明段（如参数、注脚性内容）：`font-size: 14px; color: #6e6e73`
- strong：`color: #1d1d1f; font-weight: 700`（不变色——黑就是强调）
- em / 关键短语：`color: #0071e3`（**不是保底落点**——中文技术文里 em 可能整篇为零）
- 关键数字/数据：`color: #0071e3; font-weight: 700`（keynote 式的数据强调。**也不是保底落点**——「哪个数字算关键」是内容语义，机械层判不了，有就有、没有不强求）
- 蓝色预算：**下限由列表前缀和 h3 前缀保证**（每篇必然有若干处，实测本仓库测试文 17 处）；**上限**是 em + 关键数字合计不超过 6 处。strong 保持黑粗体不上蓝——那是 Apple 官方文档的真实做法，蓝留给结构性的小元素

## 引用 / 代码 / 列表 / 表格

- 引用块：`background-color: #f5f5f7; border-radius: 14px; padding: 20px 24px; margin: 0 0 18px; color: #6e6e73; font-size: 15px; line-height: 1.75; text-align: left`——圆角是本主题唯一的曲线
- 代码块：`<pre>` 底 `#f5f5f7`、文字 `#1d1d1f`、`border-radius: 14px; padding: 18px 20px; font-size: 13px`（无边框）；行内 code：底 `#f5f5f7`、文字 `#1d1d1f`、`padding: 2px 6px; border-radius: 5px`
- 列表前缀 `<span style="color: #0071e3;">•</span>&nbsp;&nbsp;`（蓝色圆点，**蓝色的保底落点之一**：高频但视觉权重低，不破坏克制感）
- 表格：无竖线风格——单元格只有 `border-bottom: 1px solid #d2d2d7; padding: 12px 10px; font-size: 14px`，表头 `font-weight: 600; color: #6e6e73; font-size: 13px`

## 分寸提醒

这个主题有两种失败方式：一是加东西——没有分隔线、没有图标前缀、没有色块，犹豫要不要加装饰时答案永远是不加；二是**黑白化**——把克制执行成全篇无蓝。实测栽过一次：全文只剩 1 处蓝，`strong` 与正文同色，整篇实际上是灰度文档。**克制指的是装饰，不是颜色归零**；蓝的下限由列表前缀和 h3 前缀这两个机械层给得出的落点保证，不要指望内容语义类的落点（em、关键数字）兜底。

技术文代码块多时不适合本主题（代码块刻意素色、无语法高亮），建议改用 `editor-slate`。
