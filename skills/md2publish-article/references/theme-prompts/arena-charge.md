# arena-charge 竞技冲刺（扩展主题）

> 黑白高对比 + 冲刺红，体育海报的力量感。适合体育赛事、健身训练、电竞、挑战与复盘类内容。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

赛前更衣室的白板：信息短促有力，黑是底气，红是冲刺信号。力量感来自粗字重和高对比，不来自花哨装饰——像球衣号码，简单但没人觉得弱。

## 色彩系统

- 冷白底：`#f7f7f5`（主容器）
- 炭黑：`#141414`（正文 + 大标题底色）
- 冲刺红（主强调）：`#e03131`
- 次级灰：`#6b6b68`（题注、数据来源、次要说明段的文字色——声明即须使用，别让它成死色）
- 边线：`#d9d9d5`
- 浅灰底（引用/代码）：`#ececea`

## 容器与布局

- 主容器：`background-color: #f7f7f5; padding: 36px 14px; letter-spacing: 0.3px`
- 不用卡片；章节间距 44px，节与节之间一根粗短红线：`width: 48px; border-top: 4px solid #e03131; margin: 44px 0`（左对齐，不居中——有冲出去的方向感）

## 标题体系

- h2：黑底白字块。**色块只包标题文字，不能上到 h2 本身**——h2 是块级元素、要承担定宽居中，而 `display: inline-block` 的 auto 外边距计算为 0，黑块会贴容器左边、与正文的定宽栏错开。
  h2 外层：`font-size: 18px; font-weight: 800; color: #141414; margin: 0 0 20px; text-align: left`；
  文字色块：`display: inline-block; background-color: #141414; color: #f7f7f5; padding: 8px 16px; letter-spacing: 2px; border-radius: 0`（方角）
- h3：`font-size: 16px; font-weight: 800; color: #141414; text-align: left; margin: 26px 0 12px`，前缀红色斜杠 `<span style="color: #e03131; font-weight: 800;">//&nbsp;</span>`

## 正文与强调

- 段落：`font-size: 15.5px; line-height: 1.75; color: #141414; margin: 0 0 16px; text-align: left`
- strong：`color: #e03131; font-weight: 800`
- 关键数据（配速、重量、比分）：`font-weight: 800; font-size: 18px; color: #141414`——数字放大是体育版式的本能
- 次级灰 `#6b6b68` 的落点：图注、数据来源标注、表格里的次要列、代码块内的注释。**必须真的用上**——声明了却在组件规范里找不到落点的颜色等于不存在

## 引用 / 代码 / 列表 / 表格

- 引用块（战术板/金句）：`background-color: #ececea; padding: 14px 18px; margin: 0 0 16px; font-size: 15.5px; line-height: 1.75; color: #141414; font-weight: 600; text-align: left; border-left: 4px solid #e03131`。
  **不要用实心黑底反色**：实心黑是全篇最重的一块色，会把重音从 h2 标签块和表头抢走；而且调色板里 `#ececea` 的角色写的就是「引用/代码底」，反色是脱离本主题块语言的孤例。
  与代码块的区分靠三样：边框色（引用红、代码黑）、字体（引用无衬线、代码等宽）、字重
- 代码块：`<pre>` 底 `#ececea`、文字 `#141414`、`border-left: 4px solid #141414; padding: 14px 16px; font-size: 13px`；行内 code：底 `#ececea`、文字 `#e03131`
- 列表前缀 `▸&nbsp;&nbsp;`（红色 span：`<span style="color: #e03131;">▸</span>&nbsp;&nbsp;`）
- 表格（数据/成绩表是主场）：表头 `background-color: #141414; color: #f7f7f5; font-weight: 700`，单元格 `border: 1px solid #d9d9d5; padding: 9px 11px; font-size: 14px`

## 分寸提醒

红只做信号：出现在斜杠、粗线、strong 和引用边线上。红底大色块一个都不要——红一多，力量感就变成促销感。
