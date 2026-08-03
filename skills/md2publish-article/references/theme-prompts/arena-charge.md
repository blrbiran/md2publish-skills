# arena-charge 竞技冲刺（扩展主题）

> 黑白高对比 + 冲刺红，体育海报的力量感。适合体育赛事、健身训练、电竞、挑战与复盘类内容。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

赛前更衣室的白板：信息短促有力，黑是底气，红是冲刺信号。力量感来自粗字重和高对比，不来自花哨装饰——像球衣号码，简单但没人觉得弱。

## 色彩系统

- 冷白底：`#f7f7f5`（主容器）
- 炭黑：`#141414`（正文 + 大标题底色）
- 冲刺红（主强调）：`#e03131`
- 次级灰：`#6b6b68`
- 边线：`#d9d9d5`
- 浅灰底（引用/代码）：`#ececea`

## 容器与布局

- 主容器：`background-color: #f7f7f5; padding: 36px 14px; letter-spacing: 0.3px`
- 不用卡片；章节间距 44px，节与节之间一根粗短红线：`width: 48px; border-top: 4px solid #e03131; margin: 44px 0`（左对齐，不居中——有冲出去的方向感）

## 标题体系

- h2：黑底白字块——`display: inline-block; background-color: #141414; color: #f7f7f5; font-size: 18px; font-weight: 800; padding: 8px 16px; margin: 0 0 20px; letter-spacing: 2px; text-align: left`（radius 0，方角）
- h3：`font-size: 16px; font-weight: 800; color: #141414; text-align: left; margin: 26px 0 12px`，前缀红色斜杠 `<span style="color: #e03131; font-weight: 800;">//&nbsp;</span>`

## 正文与强调

- 段落：`font-size: 15.5px; line-height: 1.75; color: #141414; margin: 0 0 16px; text-align: left`
- strong：`color: #e03131; font-weight: 800`
- 关键数据（配速、重量、比分）：`font-weight: 800; font-size: 18px; color: #141414`——数字放大是体育版式的本能

## 引用 / 代码 / 列表 / 表格

- 引用块（战术板/金句）：`background-color: #141414; color: #f7f7f5; padding: 16px 20px; margin: 0 0 16px; font-size: 15px; font-weight: 600; text-align: left; border-left: 4px solid #e03131`——引用反色，是本主题的记忆点
- 代码块：`<pre>` 底 `#ececea`、文字 `#141414`、`border-left: 4px solid #141414; padding: 14px 16px; font-size: 13px`；行内 code：底 `#ececea`、文字 `#e03131`
- 列表前缀 `▸&nbsp;&nbsp;`（红色 span：`<span style="color: #e03131;">▸</span>&nbsp;&nbsp;`）
- 表格（数据/成绩表是主场）：表头 `background-color: #141414; color: #f7f7f5; font-weight: 700`，单元格 `border: 1px solid #d9d9d5; padding: 9px 11px; font-size: 14px`

## 分寸提醒

红只做信号：出现在斜杠、粗线、strong 和引用边线上。红底大色块一个都不要——红一多，力量感就变成促销感。
