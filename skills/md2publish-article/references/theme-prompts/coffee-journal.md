# coffee-journal 咖啡手帐（扩展主题）

> 棕调纸感、虚线框、手作气息，像一本摊开的手帐。适合随笔、生活方式、读书笔记、咖啡馆式闲谈。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

温暖但不甜腻的午后书写感。视觉关键词是"纸、虚线、圆角标签"——装饰有手工感（虚线、圆点）而非精密感（投影、渐变）。

## 色彩系统

- 牛皮纸底：`#f3ede4`（主容器）
- 卡片纸面：`#fbf7f0`
- 正文深棕：`#4b3a2f`
- 意式浓缩（强调）：`#8a5a3b`
- 深咖：`#5c4033`
- 虚线/边线：`#d8cbb8`
- 引用底：`#efe3d3`

## 容器与布局

- 主容器：`background-color: #f3ede4; padding: 40px 12px; letter-spacing: 0.5px`
- 每个章节一张纸卡：`background-color: #fbf7f0; border: 1px dashed #d8cbb8; border-radius: 12px; padding: 24px 20px; margin: 0 0 32px`——虚线边框是本主题的签名

## 标题体系

- h2：做成手帐标签——`display: inline-block; background-color: #8a5a3b; color: #fbf7f0; font-size: 17px; font-weight: 600; padding: 6px 16px; border-radius: 16px; margin: 0 0 20px; text-align: left`
- h3：`font-size: 16px; font-weight: 700; color: #5c4033; text-align: left; margin: 24px 0 12px`，前缀圆点 `<span style="color: #8a5a3b;">●&nbsp;</span>`

## 正文与强调

- 段落：`font-size: 16px; line-height: 1.85; color: #4b3a2f; margin: 0 0 18px; text-align: left`
- strong：`color: #8a5a3b; font-weight: 700`
- em：底色荧光笔效果 `background-color: #efe3d3; padding: 1px 4px`

## 引用 / 代码 / 列表 / 表格

- 引用块：`background-color: #efe3d3; border-radius: 10px; padding: 16px 18px; margin: 0 0 18px; color: #6b5a4c; font-size: 15px; line-height: 1.8; text-align: left`，首行前缀 `❝&nbsp;`（棕色 `#8a5a3b`）
- 代码块：`<pre>` 底 `#efe6d8`、文字 `#4b3a2f`、`border: 1px dashed #d8cbb8; border-radius: 8px; padding: 14px 16px; font-size: 13px`；行内 code：底 `#efe3d3`、文字 `#8a5a3b`
- 列表前缀 `☕` 太重，用 `◦&nbsp;&nbsp;`（空心圆点，手绘感）
- 表格：表头底 `#efe3d3`、单元格 `border: 1px dashed #d8cbb8; padding: 9px 11px; font-size: 14px`

## 收尾

文末居中一行小字：`text-align: center; color: #8a5a3b; font-size: 13px; margin: 32px 0 0`，内容如"—— 记于某个下午 ——"（按文章语境替换）。
