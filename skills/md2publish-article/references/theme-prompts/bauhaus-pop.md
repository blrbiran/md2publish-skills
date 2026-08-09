# bauhaus-pop 包豪斯撞色（扩展主题）

> 红黄蓝三原色 + 黑框硬阴影的现代主义几何风。声音最大的一个主题。适合观点输出、营销、潮流文化、产品安利。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

包豪斯海报的秩序感：颜色是纯的、边框是粗的、阴影是硬的（无模糊偏移色块）、圆角是零。看起来"用力"，但用力得讲规则——三原色各司其职，不混用。

## 色彩系统

- 米白底：`#f4f1ea`（主容器）
- 墨黑：`#171614`（正文 + 全部边框）
- 红（strong / 警示）：`#be1e2d`
<!-- census-ok: UNMOUNTED strong_alt 上一行是调色板角色标注、不是指令句：这支红本身就是 strong 色（theme.json 的 strong 已挂 #be1e2d），「strong / 警示」说的是同一支色的两个语义，本主题不存在需要另配一套样式的警示型 strong -->
- 蓝（h3 / 链接感）：`#005baa`
- 黄（高亮底 / 装饰块）：`#f0a500`，浅黄底：`#f8e8c4`
- 卡片：`#ffffff`

## 容器与布局

- 主容器：`background-color: #f4f1ea; padding: 36px 14px; letter-spacing: 0.3px`
- 章节卡片：`background-color: #ffffff; border: 2px solid #171614; border-radius: 0; padding: 24px 20px; margin: 0 0 36px; box-shadow: 6px 6px 0 #171614`——硬阴影（无 blur）是本主题的签名，绝不用柔影

## 标题体系

- h2：黑底白字色块 + 黄色引导块——`<h2 style="margin: 0 0 20px; text-align: left; font-size: 18px;"><span style="display: inline-block; background-color: #f0a500; padding: 6px 5px; color: #f0a500;">■</span><span style="display: inline-block; background-color: #171614; color: #f4f1ea; font-weight: 700; padding: 6px 14px;">标题文本</span></h2>`
- h3：`font-size: 16px; font-weight: 700; color: #171614; text-align: left; margin: 26px 0 12px; padding-bottom: 4px; border-bottom: 4px solid #005baa; display: inline-block`

## 正文与强调

- 段落：`font-size: 15.5px; line-height: 1.8; color: #171614; margin: 0 0 16px; text-align: left`
- strong：`color: #be1e2d; font-weight: 700`
- em / 高亮：黄底荧光 `background-color: #f8e8c4; padding: 1px 4px; font-weight: 600`

## 引用 / 代码 / 列表 / 表格

- 引用块：`background-color: #f8e8c4; border-left: 4px solid #171614; padding: 14px 18px; margin: 0 0 16px; color: #171614; font-size: 15px; font-weight: 500; text-align: left`
- 代码块：`<pre>` 底 `#171614`、文字 `#f4f1ea`、`border-radius: 0; padding: 16px; font-size: 13px`（黑块，和卡片形成正负形）
- **代码块内语法高亮**：注释 `#9a958c`、字符串/值 `#f0a500`、关键字 `#f4f1ea` 加 `font-weight: 700`，其余保持默认字色，一行不超过 3 类。**红 `#be1e2d` 和蓝 `#1e5aa8` 不进代码块**——在墨黑底上只有 2.94:1 和 2.65:1，达不到可读标准。三原色留给列表前缀、卡片色块这些大块面
- 行内 code：底 `#f8e8c4`、文字 `#171614`、`padding: 1px 5px`。**不要用墨黑底**——技术文里行内 code 有一两百处，深色实心块在正文里像贴满补丁，且手机窄屏断行时会从中间裂成两截（实测 193 处里 47 处断行）
- 列表前缀轮换三原色方块：`<span style="color: #be1e2d;">■</span>&nbsp;&nbsp;`，依次红→蓝→黄循环（同一列表内轮换）。**黄色这一档的小符号用深一档的琥珀 `#b87700`**——纯黄 `#f0a500` 在白卡上只有 2.08:1，红蓝两档是 6.15 和 6.81，三个方块并排时黄的那个基本看不见。**黄色按尺寸分工**：大面积色块、黑底上的文字用 `#f0a500`（招牌色，在深色上很亮），白底上的小符号用 `#b87700`（3.7:1，过图形元素的 3:1 线）
- 表格：表头 `background-color: #171614; color: #f4f1ea`，单元格 `border: 2px solid #171614; padding: 9px 11px; font-size: 14px`

## 分寸提醒

三原色只做小面积（色块、边线、字色），大面积永远是米白 + 白 + 黑。同一屏三色同时出现没问题，但任何一色做整段底色就破功了。
