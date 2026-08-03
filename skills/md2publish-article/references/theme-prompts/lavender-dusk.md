# lavender-dusk 暮紫（扩展主题）

> 薰衣草紫到暮色灰紫的柔和过渡，安静诗意。适合情感、心理、诗歌散文、夜读向内容。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

黄昏最后一段光线的颜色。紫不能艳（艳则廉价），要往灰里调；整体是"低语"的氛围——圆角大、对比柔、没有任何锐利的线。

## 色彩系统

- 暮雾底：`#f6f4f9`（主容器）
- 正文暮灰：`#453f4e`
- 薰衣草（主强调）：`#7f6a9e`
- 深暮紫：`#5d4b7c`
- 浅紫线/装饰：`#b9a7d8`
- 引用/代码底：`#eee9f5`
- 次级灰紫：`#8d8497`

## 容器与布局

- 主容器：`background-color: #f6f4f9; padding: 42px 14px; letter-spacing: 0.6px`
- 章节卡片：`background-color: #ffffff; border-radius: 18px; padding: 26px 22px; margin: 0 0 34px; box-shadow: 0 8px 24px rgba(127, 106, 158, 0.10)`——紫调柔影，圆角是全部主题里最大的

## 标题体系

- h2：`display: inline-block; font-size: 19px; font-weight: 600; color: #5d4b7c; margin: 0 0 20px; padding-bottom: 6px; border-bottom: 3px solid #b9a7d8; text-align: left`
- h3：`font-size: 16px; font-weight: 600; color: #453f4e; text-align: left; margin: 26px 0 12px`，前缀 `<span style="color: #7f6a9e;">✦&nbsp;</span>`

## 正文与强调

- 段落：`font-size: 15.5px; line-height: 1.9; color: #453f4e; margin: 0 0 18px; text-align: left`
- strong：`color: #5d4b7c; font-weight: 600`
- em：`color: #7f6a9e`

## 引用 / 代码 / 列表 / 表格

- 引用块：`background-color: #eee9f5; border-radius: 12px; padding: 16px 20px; margin: 0 0 18px; color: #8d8497; font-size: 14.5px; line-height: 1.85; text-align: left`——诗句、歌词类引用居中排（`text-align: center`）也允许
- 代码块：`<pre>` 底 `#eee9f5`、文字 `#4d475a`、`border-radius: 12px; padding: 15px 17px; font-size: 13px`；行内 code：底 `#eee9f5`、文字 `#7f6a9e`
- 列表前缀 `✦&nbsp;&nbsp;`（四角星 span：`<span style="color: #b9a7d8;">✦</span>&nbsp;&nbsp;`）
- 表格：表头底 `#eee9f5`、单元格 `border: 1px solid #ded5ec; padding: 9px 12px; font-size: 14px`

## 收尾

文末居中三颗渐淡的星：`<p style="text-align: center; margin: 36px 0 0; font-size: 14px;"><span style="color: #5d4b7c;">✦</span>&nbsp;<span style="color: #7f6a9e;">✦</span>&nbsp;<span style="color: #b9a7d8;">✦</span></p>`
