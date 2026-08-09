# mint-breeze 薄荷清风（扩展主题）

> 薄荷绿的轻盈清爽，自带"干净"和"新鲜"的联想。适合健康养生、运动饮食、居家整理、清单体实用文。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

初夏早晨开窗的那阵风：清淡、透气、让人放松警惕的干净感。绿只做浅调和线条，避免"养生绿"的浓腻。

## 色彩系统

- 薄荷雾底：`#eef7f2`（主容器）
- 卡片：`#ffffff`
- 正文墨绿灰：`#2f4a3e`
- 薄荷绿（主强调）：`#2fa47e`
- 深叶绿：`#1e7a5c`
- 次级灰绿：`#4a6b5b`（题注、引用文字、次要说明段的文字色——声明即须使用，别让它成死色）

> 这一档的明度是被对比度铁律钉住的：在引用底 `#dff0e8` 上 5.01:1、代码底 `#e6f2ec` 上 5.16:1、白卡上 5.92:1。**不要为了「次级」的语感把它调浅**——更浅的一档在引用底上只有 2.4 左右，引用块正文实测不可读。它靠比正文墨绿灰浅（8.19:1）来表达从属，不靠掉到阅读门槛以下。
- 浅绿底（引用/高亮）：`#dff0e8`
- 边线：`#cfe6da`

## 容器与布局

- 主容器：`background-color: #eef7f2; padding: 40px 14px; letter-spacing: 0.4px`
- 章节卡片：`background-color: #ffffff; border-radius: 16px; padding: 24px 20px; margin: 0 0 32px; box-shadow: 0 4px 16px rgba(47, 164, 126, 0.08)`

## 标题体系

- h2：`display: inline-block; font-size: 19px; font-weight: 700; color: #1e7a5c; margin: 0 0 18px; padding: 6px 14px; background-color: #dff0e8; border-radius: 20px; text-align: left`——胶囊标签，轻
- h3：`font-size: 16px; font-weight: 600; color: #2f4a3e; text-align: left; margin: 26px 0 12px`，前缀 `<span style="color: #2fa47e;">✓&nbsp;</span>`（清单感）

## 正文与强调

- 段落：`font-size: 15.5px; line-height: 1.8; color: #2f4a3e; margin: 0 0 16px; text-align: left`
- strong：`color: #1e7a5c; font-weight: 700`
- em / 高亮：`background-color: #dff0e8; padding: 1px 4px; border-radius: 3px`
- 次级灰绿 `#4a6b5b` 的落点：图注、引用块文字、次要说明段、代码块内的注释。**必须真的用上**——声明了却在组件规范里找不到落点的颜色等于不存在

## 引用 / 代码 / 列表 / 表格

- 引用块：`background-color: #dff0e8; border-radius: 12px; padding: 15px 18px; margin: 0 0 16px; color: #4a6b5b; font-size: 14.5px; line-height: 1.75; text-align: left`
- 代码块：`<pre>` 底 `#e6f2ec`、文字 `#2f4a3e`、`border: 1px solid #cfe6da; border-radius: 10px; padding: 14px 16px; font-size: 13px`；行内 code：底 `#dff0e8`、文字 `#1e7a5c`
- 列表：本主题的主场——无序前缀 `<span style="color: #2fa47e;">✓</span>&nbsp;&nbsp;`
- 有序列表序号：**判断层的手工可选项，不是机械规范，`theme.json` 里刻意不配 `list_prefix_ol_html`**。只有当这个有序列表确实在讲「步骤」时，手写路径才给序号加浅绿圆底 `<span style="display: inline-block; background-color: #dff0e8; color: #1e7a5c; font-weight: 700; border-radius: 50%; width: 20px; text-align: center; font-size: 13px;">1</span>&nbsp;&nbsp;`；机械路径一律退回纯文本 `N.`。原因是 `list_prefix_ol_html` 是全局字段，配上去会给每篇文章的每个有序列表都套上圆底徽章，而「是不是步骤类」属于内容语义，机械层判不了（规则 14 的判例）。另注意上面这段示例只演示了单位数序号，圆底是 `width: 20px` 的正圆，手工用到两位数时要改成 `min-width`，否则会被撑破
<!-- census-ok: UNMOUNTED list_prefix_ol_html 规范限定「步骤类」有序列表，而 list_prefix_ol_html 是全局字段、会给每篇文章的每个有序列表都套上圆底徽章；内容类型机械层判不了，所以这条按上一行写明的方式留在判断层手工执行，不配字段 -->
- 表格：表头底 `#dff0e8`、单元格 `border: 1px solid #cfe6da; padding: 9px 11px; font-size: 14px`

## 分寸提醒

绿的浓度只在小元素上走到 `#1e7a5c`，大面积永远停在 `#dff0e8` 以浅。全文出现深绿底白字的块超过一个，清爽感就没了。
