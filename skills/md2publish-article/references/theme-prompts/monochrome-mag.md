# monochrome-mag 黑白杂志（扩展主题）

> 时尚杂志的纯黑白排版：超大黑标题、细线、无一处彩色。适合时尚、摄影、艺术评论、人物特稿。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

一本高级时装杂志的内页：力量全部来自字号对比和黑白灰的秩序。与 ink-wash（水墨纸感、朱砂点睛）不同，这里是现代都市的黑——冷、硬、时髦，且**真正零彩色**。

## 色彩系统

- 纯白底：`#ffffff`（主容器）
- 纯黑：`#111111`（正文、标题）
- 深灰：`#3a3a3a`（代码块正文、次级说明）
- 中灰：`#5a5a5a`（浅灰底上的次要文字——`#767676` 在 `#f2f2f2` 上只有 3.96:1，不达 AA，别用在灰底上）
- 浅中灰：`#767676`（仅用在纯白底上：图注、脚注、署名）
- 浅灰底：`#f2f2f2`
- 细线：`#e0e0e0`
- 没有强调色。强调就是更黑、更大、更粗。

**灰阶是这个主题唯一的层次手段，所以必须够用。**上面五级文字灰不是备选清单，是要在长文里真正分工的：正文纯黑、代码块深灰、灰底上的次要信息中灰、白底上的注释浅中灰。只用黑加一级灰的话，十几个代码块会退化成一块块纯色砖——无彩色是定位，没层次是缺陷，两件事别混。

## 容器与布局

- 主容器：`background-color: #ffffff; padding: 44px 18px; letter-spacing: 0.3px`
- 无卡片；章节间距 52px，节前一根全宽细线：`border-top: 1px solid #e0e0e0; margin: 52px 0 0`

## 标题体系

- h2：杂志大标题——`font-size: 30px; font-weight: 900; color: #111111; text-align: left; margin: 24px 0 20px; line-height: 1.25; letter-spacing: -0.5px`（负字距，大字号才压得住）
- h3：小型大写栏目题——`font-size: 13px; font-weight: 700; color: #111111; letter-spacing: 4px; text-align: left; margin: 30px 0 14px`，英文转大写

## 正文与强调

- 段落：`font-size: 15.5px; line-height: 1.8; color: #111111; margin: 0 0 16px; text-align: left`
- strong：`font-weight: 800`（不变色）
- em / 关键句：`border-bottom: 2px solid #111111; padding-bottom: 1px`（黑色下划线替代变色）
- 图片说明、注脚：`font-size: 13px; color: #767676; letter-spacing: 1px`

## 引用 / 代码 / 列表 / 表格

- **引用块分两档，按语义选，不要一律放大**：
  - **金句/人物语录**（值得占版面的）：放大处理——`font-size: 20px; font-weight: 700; color: #111111; line-height: 1.5; padding: 8px 0 8px 20px; border-left: 4px solid #111111; margin: 28px 0; text-align: left`，引语后另起一行小灰字署名
  - **旁注/提示/补充说明**（读者可跳过的）：收小处理——`font-size: 14px; color: #5a5a5a; background-color: #f2f2f2; padding: 12px 16px; margin: 0 0 16px; border-left: 3px solid #e0e0e0; text-align: left`
  - 技术文里的 `>` 大多是后者。把「可跳过的旁注」渲染成全页最大最黑的字，视觉权重和语义正好相反，是这个主题最容易犯的错
- 代码块：`<pre>` 底 `#f2f2f2`、文字 `#3a3a3a`、`padding: 16px 18px; font-size: 13px`（无边框无圆角）
- **代码块内的无彩色高亮**（靠字重和灰阶，不靠颜色）：关键字 `#111111` + `font-weight: 700`、字符串/值 `#3a3a3a`、注释 `#5a5a5a` + `font-style: italic`、其余 `#3a3a3a`。三级灰加一级字重，足够把结构区分出来。注释这一档用中灰而不是浅中灰——代码块底是浅灰 `#f2f2f2`，上面「色彩系统」已写明 `#767676` 在这个底上只有 3.96:1、不达 AA
- 行内 code：底 `#f2f2f2`、文字 `#111111`、`padding: 1px 5px`（底色浅、padding 小，手机断行时裂开也不明显）
- 列表前缀 `—&nbsp;&nbsp;`（破折号，编辑感）
- 表格：表头 `border-bottom: 2px solid #111111; font-weight: 800`，单元格只有 `border-bottom: 1px solid #e0e0e0; padding: 12px 10px; font-size: 14px`——无竖线

## 分寸提醒

这个主题的诱惑是"加一点颜色提亮"——不行，一滴彩色都会毁掉整个气场。层级不够时的正确做法是拉大字号差距，而不是引入颜色。
