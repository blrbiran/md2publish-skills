# editor-slate 代码编辑器（扩展主题）

> 浅色 GitHub 阅读界面 + **带语法高亮的深色代码块**，开发者最熟悉的视觉语言。适合技术教程、开发实践、工具评测。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

README 的阅读体验：正文克制到近乎素净，**颜色几乎全部集中在代码块里**——这是本主题成立的前提。正文是文档，代码是主角；素的正文正是为了让彩色代码跳出来。

**最容易做砸的地方**：把代码块做成纯色深砖。技术文里代码块常占页面一半面积，不上语法高亮的话整篇会显得又暗又平，像终端截图而不像 GitHub。语法高亮不是可选项，是本主题的核心工作量。

## 色彩系统

正文（浅色，GitHub Light）：

- 页面底：`#f6f8fa`（主容器）
- 正文：`#24292f`
- 链接蓝（强调）：`#0969da`
- 次级灰：`#57606a`
- 边线：`#d0d7de`
- 行内代码底：`#eff1f3`

代码块（深色，GitHub Dark）：

- 底：`#0d1117`
- 默认文字：`#e6edf3`

## 语法高亮（必做）

代码块内每个 token 用 `<span style="color: ...">` 上色，配色取 GitHub Dark 官方值：

| 语法角色 | 色值 | 典型对象 |
|---|---|---|
| 注释 | `#8b949e` | `#` `//` `/* */` 整行或行尾注释 |
| 关键字 / 保留字 | `#ff7b72` | `if` `for` `def` `import` `export` `class` `return`；shell 命令名（`curl` `docker` `uv`） |
| 字符串 | `#a5d6ff` | 引号内文本、URL、路径字面量 |
| 常量 / 数字 / 布尔 | `#79c0ff` | 数字、`true/false/null`、环境变量名、**YAML/JSON 的键名** |
| 函数名 / 类名 | `#d2a8ff` | 定义或调用处的标识符 |
| 变量 / 属性 / 参数 | `#ffa657` | 命令行参数（`--flag`）、对象属性 |
| 标点 / 操作符 | `#e6edf3` | 保持默认色，不要上色 |

按语言的落点建议：

- **YAML**：键名 `#79c0ff`，值里的字符串 `#a5d6ff`，`#` 注释 `#8b949e`，`-` 列表符号保持默认
- **JSON**：键名 `#79c0ff`，字符串值 `#a5d6ff`，数字/布尔 `#79c0ff`，括号引号保持默认
- **Bash**：命令名 `#ff7b72`，`--参数` `#ffa657`，引号内字符串 `#a5d6ff`，`#` 注释 `#8b949e`
- **Python/JS/Go**：关键字 `#ff7b72`，函数名 `#d2a8ff`，字符串 `#a5d6ff`，注释 `#8b949e`

分寸：一行代码里上色的 token 一般不超过 3 类，**标点和普通标识符一律保持默认色**——全部上色会变成彩虹，比不上色更糟。

> 与 `_common-tech.md` 的配合：`<span>` 标签写在**实体转义和 `<br>`/`&nbsp;` 替换之后**，不要让高亮标签被转义成 `&lt;span&gt;`。顺序是：原始代码 → HTML 实体转义 → 换行转 `<br>`、空格转 `&nbsp;` → 再包 `<span>` 上色。

## 容器与布局

- 主容器：`background-color: #f6f8fa; padding: 32px 12px; letter-spacing: 0.3px`
- 正文区包一层白卡：`background-color: #ffffff; border: 1px solid #d0d7de; border-radius: 8px; padding: 28px 20px`（全文一张大卡，不逐节切卡）
- **`<pre>`、块级和行内 `<code>` 上显式写 `letter-spacing: 0`** 复位全局字距，否则等宽字符被撑开、代码列对不齐

## 标题体系

- h1：`font-size: 24px; font-weight: 700; color: #24292f; text-align: left; margin: 0 0 20px; padding-bottom: 10px; border-bottom: 1px solid #d0d7de`
- h2：`font-size: 20px; font-weight: 600; color: #24292f; text-align: left; margin: 36px 0 16px; padding-bottom: 8px; border-bottom: 1px solid #d0d7de`
- h3：`font-size: 17px; font-weight: 600; color: #24292f; text-align: left; margin: 28px 0 12px`，标题前置等宽 `#` 前缀：`<span style="color: #0969da; font-family: Menlo, Consolas, monospace; letter-spacing: 0;">#&nbsp;</span>`

## 正文与强调

- 段落：`font-size: 15px; line-height: 1.75; color: #24292f; margin: 0 0 16px; text-align: left; overflow-wrap: break-word`
- strong：`color: #0969da; font-weight: 600`。**这是强调蓝在正文里唯一的高频落点，别改回不变色**——早期版本让 strong 跟随正文色，结果强调蓝只落在 h3 前缀、em 和链接上，中文技术文里后两者几乎为零，正文彩色面积归零。代码密集的文章还能靠语法高亮撑住观感，代码少的文章就会整篇黑白化（`docs/theme-design-lessons.md` 案例一记的就是这个）
- em / 关键术语：`color: #0969da`
- 链接文本统一 `color: #0969da`

## 引用 / 代码 / 列表 / 表格

- 引用块：`border-left: 4px solid #d0d7de; padding: 4px 0 4px 16px; margin: 0 0 16px; color: #57606a; font-size: 15px; text-align: left`（GitHub blockquote 原样）
- 代码块外壳：`<pre style="background-color: #0d1117; border-radius: 6px; padding: 16px; overflow-x: auto; text-align: left; letter-spacing: 0;">` + `<code style="display: block; white-space: normal; color: #e6edf3; font-size: 13px; line-height: 1.6; letter-spacing: 0; font-family: Menlo, Consolas, Monaco, 'Courier New', monospace;">`，内部按上面的语法高亮上色
- 行内 code：`background-color: #eff1f3; color: #24292f; padding: 2px 6px; border-radius: 4px; font-size: 13px; letter-spacing: 0; font-family: Menlo, Consolas, Monaco, 'Courier New', monospace`
- 列表前缀 `-&nbsp;&nbsp;`（连字符，Markdown 味）
- 表格：`width: 100%; border-collapse: collapse; table-layout: fixed`；表头 `background-color: #f6f8fa; font-weight: 600`；单元格 `border: 1px solid #d0d7de; padding: 8px 12px; font-size: 14px; word-break: break-word`；**偶数行加斑马纹** `background-color: #f6f8fa`（GitHub 表格的标志性特征）

## 提示卡（遇到就用，但别凑数）

正文里凡是"注意 / 提醒 / 前提 / 坑"性质的段落，用 GitHub Alert 样式，不要混在普通引用块里——普通引用块在本主题是灰边框无彩色，提示卡是正文里唯一带底色的块，比 strong 高一档：

- 提示（NOTE）：`border-left: 4px solid #0969da; background-color: #ddf4ff; padding: 12px 16px; border-radius: 0 6px 6px 0; color: #24292f`，首行加粗蓝字标签 `<span style="color: #0969da; font-weight: 700;">注意</span>`
- 警告（WARNING）：`border-left: 4px solid #bc4c00; background-color: #fff1e5;`，标签色 `#bc4c00`，文案如"小心"
- 全文提示卡**不超过 4 个**，多了就失去强调意义。判断标准是"读者跳过这段会踩坑"，只是补充说明的仍走普通引用块——**够不上这个标准就一张都不做，别为了凑数把旁注升格**。这是上限不是配额：正文彩色由 strong 保底，不靠提示卡撑
