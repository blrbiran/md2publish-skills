# candy-pop 奶油马卡龙（扩展主题）

> 奶油白底 + 樱粉/雾蓝马卡龙双色，圆润轻甜。适合母婴育儿、萌宠、好物安利、轻松日常向内容。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

甜品店的配色逻辑：奶油是底，马卡龙只是点缀。甜而不腻的关键是"粉不艳、蓝不冷、处处圆角"——可爱来自形状和留白，不来自把粉色糊满屏。

## 色彩系统

- 奶油白底：`#fdf6f0`（主容器）
- 卡片：`#ffffff`
- 正文暖褐：`#5a4a42`
- 樱粉（符号与前缀装饰用）：`#f28ba8`——落点是 h3 前缀的双色圆点、列表前缀轮换的粉那一档、代码高亮的关键字。**它不是正文强调色**：实测全文文字落点只有 29 处，正文里真正承担强调的是下面那支深樱粉（271 处）
- 深樱粉（strong 用）：`#d96687`
- 雾蓝（辅强调）：`#7fb5d5`
- 浅粉底：`#fce8ee`
- 浅蓝底：`#e8f2f9`
- 边线：`#f0e2d8`

## 容器与布局

- 主容器：`background-color: #fdf6f0; padding: 40px 14px; letter-spacing: 0.5px`
- 章节卡片：`background-color: #ffffff; border-radius: 20px; padding: 24px 20px; margin: 0 0 32px; box-shadow: 0 6px 18px rgba(242, 139, 168, 0.10)`——圆角全场最大

## 标题体系

- h2：粉底胶囊——`display: inline-block; background-color: #fce8ee; color: #d96687; font-size: 18px; font-weight: 700; padding: 7px 16px; border-radius: 22px; margin: 0 0 18px; text-align: left`
- h3：`font-size: 16px; font-weight: 700; color: #5a4a42; text-align: left; margin: 24px 0 12px`，前缀 `<span style="color: #7fb5d5;">◦</span><span style="color: #f28ba8;">◦&nbsp;</span>`（双色小圆点）

## 正文与强调

- 段落：`font-size: 15.5px; line-height: 1.85; color: #5a4a42; margin: 0 0 16px; text-align: left`
- strong：`color: #d96687; font-weight: 700`
- em / 高亮：`background-color: #e8f2f9; padding: 1px 5px; border-radius: 4px; color: #457190`（用蓝，和 strong 的粉错开）

> 那支蓝的明度是被对比度铁律钉住的：在自己的高亮底 `#e8f2f9` 上 4.60:1。**2026-08 为此压深过一档**（压之前 4.07:1，差 0.43 不达 AA），不要往浅里调回去（规则 11）——高亮块的底本来就浅，蓝再浅一点这段字就读不出来了。

<!-- census-ok: NEAR-ZERO #e8f2f9 这条样式串里**没有 font-style: italic**，所以 `*文字*` 渲染出来是一枚圆角浅蓝高亮块、不是斜体——它服务的是「高亮」这个用法，不是斜体；用户确认高亮是常用写法，所以这支蓝不是规则 1 说的死色。产物里只有 1 处，是因为本篇语料通篇只有 1 个 `*em*`（实测 `<em` 1 次、`#e8f2f9` 1 次），是语料的性质，不是落点失效 -->

## 引用 / 代码 / 列表 / 表格

- 引用块（经验之谈、温馨提示）：`background-color: #fce8ee; border-radius: 14px; padding: 15px 18px; margin: 0 0 16px; color: #8b5f59; font-size: 14.5px; line-height: 1.8; text-align: left`，首行可加 `<span style="color: #d96687; font-weight: 700;">💡 </span>` 类引导（emoji 限提示引导处，正文不撒）
> 引用块这支褐粉的明度是被对比度铁律钉住的：在引用底 `#fce8ee` 上 4.62:1、代码底 `#faf0e8` 上 4.82:1（它同时是代码块的注释色）。**引用底那一处就是它的下限**——2026-08 为此压深过一档（压之前 3.33:1，差 1.17 不达 AA），不要调回去（规则 11）。糖果色的甜是靠饱和度和圆角撑起来的，不靠把引用块正文调浅。
- 代码块：`<pre>` 底 `#faf0e8`、文字 `#5a4a42`、`border: 1px solid #f0e2d8; border-radius: 12px; padding: 14px 16px; font-size: 13px`；行内 code：底 `#fce8ee`、文字 `#d96687`
- 列表前缀粉蓝轮换：`<span style="color: #f28ba8;">●</span>&nbsp;&nbsp;` 与 `<span style="color: #7fb5d5;">●</span>&nbsp;&nbsp;` 交替
- 表格：表头底 `#fce8ee`、文字 `#d96687`，单元格 `border: 1px solid #f0e2d8; padding: 9px 11px; font-size: 14px`

## 分寸提醒

粉与蓝永远不在同一元素上混用（渐变尤其禁止）；emoji 只出现在提示引导位，每屏最多 1 个。甜度超标的判断标准：截图给一个不看这类内容的人，对方皱眉就是超了。
