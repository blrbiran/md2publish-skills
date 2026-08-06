# newsprint 铅字报纸（扩展主题）

> 米黄新闻纸底、墨黑铅字、报头红点缀，双线报眉的老派严肃感。适合深度报道、行业分析、时事评论。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

一份被认真排版过的报纸版面：信息密度可以高，但秩序感必须强。所有装饰都来自报纸排版传统——双线、细线、大写字距、首段引语，而不是现代 UI 的圆角投影。

## 色彩系统

- 新闻纸底：`#f5f1e6`（主容器）
- 铅字墨色：`#1f1d1a`
- 报头红（强调）：`#9e2b25`
- 次级灰褐：`#55514a`
- 线条：`#c9c2b2`
- 引用/代码底：`#eae5d6`
- 代码文字：`#3a362e`（比正文铅字墨色略浅一档，避免代码块整块发死）

## 容器与布局

- 主容器：`background-color: #f5f1e6; padding: 40px 14px; letter-spacing: 0.3px`
- 不用卡片，版面直排；章节间距 44px
- 圆角一律为 0 或 2px，无阴影

## 标题体系

- h2（版块标题）：衬线字族 `Georgia, 'Songti SC', 'Noto Serif SC', serif`，`font-size: 22px; font-weight: 700; color: #1f1d1a; text-align: left; margin: 44px 0 20px; padding-bottom: 10px`，底部双线：`border-bottom: 3px double #1f1d1a`
- h3（栏目题）：`font-size: 15px; font-weight: 700; color: #9e2b25; letter-spacing: 3px; text-align: left; margin: 30px 0 14px`，英文标题转大写

## 正文与强调

- 段落：`font-size: 16px; line-height: 1.8; color: #1f1d1a; margin: 0 0 18px; text-align: left`
- 全文第一段做导语处理（机械层的 `p_first` 字段，**只作用于全文第一个段落，不是每章第一段**）：`font-size: 17px; line-height: 1.8; color: #55514a; border-left: 3px solid #9e2b25; padding-left: 14px; margin: 0 0 18px`。
  这一条曾经静默丢失过：机械层原本所有段落一律走「段落」那条规范，导语的红边框在产物里 **0 处**。写位置性的规范时先确认机械层有对应的挂载点，否则它只是写在文件里好看
- strong：`color: #9e2b25; font-weight: 700`
- em：`color: #55514a`

## 引用 / 代码 / 列表 / 表格

- 引用块：上下细线夹注式——`border-top: 1px solid #c9c2b2; border-bottom: 1px solid #c9c2b2; padding: 16px 8px; margin: 0 0 18px; color: #55514a; font-size: 15px; text-align: left`，衬线字族
- 代码块：`<pre>` 底 `#eae5d6`、文字 `#3a362e`、`border: 1px solid #c9c2b2; padding: 14px 16px; font-size: 13px`；行内 code：底 `#eae5d6`、文字 `#9e2b25`
- 列表前缀 `▪&nbsp;&nbsp;`（方块，铅字感）
- 表格：表头 `background-color: #1f1d1a; color: #f5f1e6`，单元格 `border: 1px solid #c9c2b2; padding: 9px 11px; font-size: 14px`

## 收尾

文末右对齐一行小字（`text-align: right; color: #55514a; font-size: 13px; border-top: 1px solid #c9c2b2; padding-top: 12px; margin-top: 40px`），内容可为文章日期或"—— 完 ——"。
