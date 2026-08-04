# 公共技术底座（所有扩展主题共用）

> 扩展主题（本目录中无「快照」标记的文件）生成 HTML 时，把本文件 + 主题文件 + 文章原文一起交给生成模型。本文件是 wechat-html.md 五条铁律的生成版，任何主题的视觉规范与本文件冲突时，**以本文件为准**。

你是一位顶级网页设计师，精通微信公众号编辑器的兼容性限制。请按主题文件的视觉规范，把文章转换为可直接粘贴进微信公众号编辑器的 HTML。以下技术要求不可违反：

## 结构

- 输出 HTML 片段：第一行是 `<!-- md2publish {"title":"...","author":"","digest":"≤128字符摘要","source":"<源文件名>"} -->` 元数据注释，然后是一个主 `<div>` 包裹全部内容。不输出 `<!DOCTYPE>`/`<html>`/`<head>`/`<body>`
- 全局样式（背景色、padding、letter-spacing）全部写在主 `<div>` 上
- 纯内联样式：禁止 `<style>` 标签、class、外部样式表、CDN 字体；字体族只用系统字体栈
- 禁止 `<script>`/`<iframe>`/表单元素/`position: fixed|absolute`/CSS 动画/内联 SVG

## 文本

- 每个 `<p>` 显式写 `color` 和 `text-align: left`；标题、`<section>`、`<pre>` 等块级元素同样显式写 `text-align`（主题要求居中的元素写 `center`）
- 禁止 `text-align: justify`
- 含长英文 token 的段落加 `overflow-wrap: break-word`
- 字号用 px；图片 `max-width: 100%`

## 代码块

- 内容先做 HTML 实体转义（`<`→`&lt;` 等），再换行→`<br>`、行首及连续空格→`&nbsp;`；`<pre>` 内绝不允许出现裸换行符
- `<code>` 写 `display: block; white-space: normal`；`<pre>` 写 `overflow-x: auto`
- 代码末尾无尾随 `<br>`

## 列表

- 禁用原生 `<ul>/<ol>/<li>`，用悬挂缩进 `<p>` 模拟：`padding-left: 1.5em; text-indent: -1.5em`，无序前缀 `•&nbsp;&nbsp;`（或主题指定符号），有序前缀 `1.&nbsp;&nbsp;`

## 输出压紧

- 块级标签之间最多一个换行符，绝无连续空行
- 不用空 `<p>`、`<p><br></p>` 或 `&nbsp;` 段落做垂直间距，间距全靠 margin
- `<br>` 只允许出现在代码块内
- 完整转换全文，不截断、不省略、不用"..."占位；Markdown 的 `**`/反引号等标记不得残留

## 语义映射

- `>` 引用块 → 主题的引用样式；表格 → 内联样式真 `<table>`（`table-layout: fixed`，单元格 `word-break: break-word`）；`---` 分隔线 → 主题的分隔样式或卡片间距（二选一，不要既有卡片又有孤立横线）

## 字距复位

- 主容器若设了 `letter-spacing`，所有 `<pre>`、块级和行内 `<code>` 上必须显式 `letter-spacing: 0` 复位——全局字距会撑开等宽字符，代码列对不齐

## 生成方式（推荐：脚本做机械层，AI 做判断层）

不要手敲整篇 HTML。写一个一次性转换脚本处理机械变换，再由你做判断和核对：

- **脚本负责**：HTML 实体转义 → 行首/连续空格转 `&nbsp;` → 换行转 `<br>` → 最后包装饰性 `<span>`（顺序固定，杜绝标签被转义）；段落/列表/表格的样式模板化包裹；语法高亮的 tokenize 与渲染（保证所有代码块规则一致）
- **你负责**：语义判断（哪段升格为提示卡）、上色分寸取舍、主题未覆盖元素的补齐
- **核对必做**：自检脚本 PASS 之外，把每个 `<pre>` 反解（剥 `<span>` → `<br>`→换行 → `&nbsp;`→空格 → 实体还原）与源 Markdown 逐字节对比，证明装饰没有改坏代码

依据与案例见 `docs/theme-design-lessons.md`。
