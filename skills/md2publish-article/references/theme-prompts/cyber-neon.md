# cyber-neon 赛博霓虹（扩展主题）

> 深空蓝黑底 + 霓虹青/品红双色光，终端与夜城的科技感。适合 AI 前沿、游戏、加密/极客文化、未来主义话题。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

夜里亮着的显示器：暗底上两种霓虹各司其职——青色是信息，品红是警示/强调。光要"细"（细线、文字发色），不要大面积荧光底。

## 色彩系统

- 深空底：`#0f1420`（主容器）
- 面板底：`#1b2438`（必须比主容器底亮一档，否则十几张卡看不出边界）
- 正文亮灰：`#c9d2e3`
- 霓虹青（主强调）：`#39d0d8`
- 霓虹品红（副强调）：`#ff4ba3`——落点是 h2 终端符（每章一次，高权重）、h3 左边框、警示词。**别把它降级成只有边框落点**：3px 细边框在长文里视觉权重接近零，产物会退化成纯青单色
- 次级灰蓝：`#7a869e`
- 面板边线：`#39456b`（暗底上真正立起卡片边界的是这根线，不是底色差）
- 表格网格线：`#445280`——比面板边线再亮一档。网格线在暗底上低于 2:1 就会糊进底色，表格看着像没有线

## 容器与布局

- 主容器：`background-color: #0f1420; padding: 36px 12px; letter-spacing: 0.5px`
- 章节面板：`background-color: #1b2438; border: 1px solid #39456b; border-radius: 10px; padding: 24px 20px; margin: 0 0 32px`，顶部一根霓虹线：`border-top: 2px solid #39d0d8`——面板底比主容器底亮一档是**必须的**，两者太近的话十几张卡片实际看不出边界；真正立起边界的是边框，不是底色差

## 标题体系

- h2：`font-size: 19px; font-weight: 700; color: #39d0d8; text-align: left; margin: 0 0 20px; letter-spacing: 2px`，前缀等宽终端符 `<span style="font-family: Menlo, Consolas, monospace; color: #ff4ba3;">&gt;_&nbsp;</span>`——**终端符用品红**，这是品红唯一的高频文字色落点，靠它和青色形成双色对比
- h3：`font-size: 16px; font-weight: 600; color: #c9d2e3; text-align: left; margin: 26px 0 12px; padding-left: 10px; border-left: 3px solid #ff4ba3`

## 正文与强调

- 段落：`font-size: 15.5px; line-height: 1.8; color: #c9d2e3; margin: 0 0 16px; text-align: left`
- strong：`color: #39d0d8; font-weight: 600`
- 品红在正文里的落点，按这个顺序找，**不要依赖 em**（中文技术文全篇斜体通常为零，挂在 em 上等于没落点）：
  1. 原文里带「注意 / 警告 / 不要 / 会导致」这类警示语义的 `strong`，改用 `color: #ff4ba3; font-weight: 600`
  2. 提示卡里属于警示性质的那种，标题和左边框用品红（信息性提示卡仍用青色）
  3. 若两者都没有，就不在正文用品红——h2 终端符和代码关键字已经保证了它的存在感，硬凑反而破坏"品红是警报"的语义
- 普通 `strong` 保持青色。品红每屏不超过 2 处：它是警报不是装饰

## 引用 / 代码 / 列表 / 表格

- 引用块：`background-color: #10182a; border-left: 2px solid #39d0d8; padding: 14px 18px; margin: 0 0 16px; color: #7a869e; font-size: 14.5px; text-align: left`
- 代码块：`<pre>` 底 `#0a0e18`、文字 `#c9d2e3`、`border: 1px solid #39456b; border-radius: 8px; padding: 16px; font-size: 13px`——比面板更黑一档，像终端窗口
- **代码块内语法高亮**：注释 `#7a869e`、字符串/值 `#39d0d8`、关键字 `#ff4ba3`、数字 `#c9d2e3`，其余保持默认字色，一行不超过 3 类。四色在 `#0a0e18` 上都过 4.5:1
- 行内 code：**只改文字色 `#39d0d8`，不加底色和 padding**。行内 code 在技术文里有一两百处，带底色的实心块在手机断行时会裂成两截；暗色主题上这种碎块尤其扎眼
- 列表前缀 `▸&nbsp;&nbsp;`（青色 span：`<span style="color: #39d0d8;">▸</span>&nbsp;&nbsp;`）
- 表格：表头 `background-color: #0a0e18; color: #39d0d8`，单元格 `border: 1px solid #445280; padding: 9px 11px; font-size: 14px; color: #c9d2e3`

## 分寸提醒

暗色主题的两个专属风险：一，所有文字必须显式写亮色 `color`，漏一处就是黑底黑字；二，微信 App 自身的深色/浅色模式可能对颜色做映射，发布前两种模式的手机预览都要看一眼。品红大面积使用会变成"促销页"，克制。
