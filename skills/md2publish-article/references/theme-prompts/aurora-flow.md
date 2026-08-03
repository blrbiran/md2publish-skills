# aurora-flow 极光渐变（扩展主题）

> 紫到青的极光渐变点缀在浅色底上，当代产品官网的流光感。适合新品发布、活动预告、增长营销、潮流科技盘点。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

SaaS 产品发布页的现代感：底子是安静的浅灰紫，渐变只出现在细窄的关键元素上（胶囊、细线、按钮感块）——流光是勾边，不是泼墨。

## 色彩系统

- 浅灰紫底：`#f4f4fb`（主容器）
- 卡片：`#ffffff`
- 正文墨蓝灰：`#33344a`
- 极光紫：`#6a5cff`
- 极光青：`#38c6d9`
- 渐变（唯一允许的渐变）：`linear-gradient(135deg, #6a5cff, #38c6d9)`
- 次级灰：`#8688a3`
- 浅紫底：`#ecebfb`
- 边线：`#e3e3f0`

## 容器与布局

- 主容器：`background-color: #f4f4fb; padding: 40px 14px; letter-spacing: 0.3px`
- 章节卡片：`background-color: #ffffff; border-radius: 16px; padding: 26px 22px; margin: 0 0 32px; box-shadow: 0 8px 24px rgba(106, 92, 255, 0.08)`
- 卡片顶部渐变细线：`border-top: 3px solid transparent` 不可行（渐变边框微信不稳），改为卡片内第一个元素前放一根渐变条：`<p style="margin: 0 0 18px; height: 4px; border-radius: 2px; background-image: linear-gradient(135deg, #6a5cff, #38c6d9); font-size: 0; line-height: 4px;">&nbsp;</p>`

## 标题体系

- h2：渐变胶囊——`display: inline-block; background-image: linear-gradient(135deg, #6a5cff, #38c6d9); color: #ffffff; font-size: 17px; font-weight: 700; padding: 7px 18px; border-radius: 20px; margin: 0 0 18px; text-align: left`（渐变做底、白字，不做渐变文字——`background-clip: text` 会被微信剥掉）
- h3：`font-size: 16px; font-weight: 700; color: #33344a; text-align: left; margin: 26px 0 12px; padding-left: 10px; border-left: 3px solid #6a5cff`

## 正文与强调

- 段落：`font-size: 15.5px; line-height: 1.8; color: #33344a; margin: 0 0 16px; text-align: left`
- strong：`color: #6a5cff; font-weight: 700`
- em / 数据亮点：`color: #38c6d9; font-weight: 600`（紫管重点、青管数据，分工不混）

## 引用 / 代码 / 列表 / 表格

- 引用块：`background-color: #ecebfb; border-radius: 12px; padding: 15px 18px; margin: 0 0 16px; color: #61638a; font-size: 14.5px; text-align: left`
- 代码块：`<pre>` 底 `#282a45`（深紫蓝）、文字 `#e8e8f8`、`border-radius: 10px; padding: 16px; font-size: 13px`；行内 code：底 `#ecebfb`、文字 `#6a5cff`
- 列表前缀 `◆&nbsp;&nbsp;`（紫青轮换：`<span style="color: #6a5cff;">◆</span>` 与 `<span style="color: #38c6d9;">◆</span>` 交替）
- 表格：表头底 `#ecebfb`、文字 `#33344a; font-weight: 700`，单元格 `border: 1px solid #e3e3f0; padding: 9px 12px; font-size: 14px`

## 分寸提醒

渐变只出现在两处：h2 胶囊和卡片顶部细条。正文底色、引用底、表格一律纯色——渐变一旦铺开就是 2016 年的微商海报。
