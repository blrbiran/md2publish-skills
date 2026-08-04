# 微信编辑器 HTML 约束清单

微信公众号编辑器会对粘贴进来的 HTML 做激进的清洗、空白归一化和结构重写。以下规则来自真实翻车案例——违反任何一条，粘贴进后台或手机预览时就会出问题。

## 五条铁律（每条都对应一次真实翻车）

### 1. 代码块：禁止裸换行和空格缩进

微信编辑器粘贴时会归一化 `<pre>` 里的空白——换行被合并、缩进空格被吞，YAML/Python 这类靠缩进的代码直接废掉。**必须做转义**：

- 换行 `\n` → `<br>`
- 行首每个空格 → `&nbsp;`（行中连续空格同理）
- 代码内容先做 HTML 实体转义（`<` → `&lt;` 等）再做上述替换

```html
<pre style="margin: 0 0 18px; padding: 14px 16px; background-color: #2d2b28;
  border-radius: 8px; overflow-x: auto; font-size: 13px; line-height: 1.6;
  font-family: Menlo, Consolas, monospace; text-align: left;"><code
  style="display: block; color: #e8e2d9; white-space: normal;
  font-family: inherit;">model_list:<br>&nbsp;&nbsp;-&nbsp;model_name:&nbsp;gpt-5.2<br>&nbsp;&nbsp;&nbsp;&nbsp;litellm_params:</code></pre>
```

注意 `white-space: normal`——换行已由 `<br>` 表达，不要再依赖 pre 的默认 whitespace 行为。代码末尾不要留尾随 `<br>` 或空行。

### 2. 对齐：每个块级元素显式 `text-align: left`

没写 `text-align` 的段落会继承微信容器的对齐方式，在部分环境下表现为两端对齐；中文夹杂长英文 code token（如 `/v1/chat/completions`）时，两端对齐会把整行字间距撑得很大。所以：

- 每个 `<p>` / `<section>` / `<pre>` / 标题元素都显式写 `text-align: left`
- 永远不用 `text-align: justify`
- 含长英文 token 的段落加 `overflow-wrap: break-word`，防止长词把行撑爆

### 3. 列表：不用原生 `<ul>/<li>`，用带前缀的 `<p>` 模拟

微信编辑器会重写 `<ul>/<li>` 结构，常见后果是出现只剩项目符号点、没有内容的空行。用扁平段落 + 悬挂缩进模拟：

```html
<p style="margin: 0 0 10px; padding-left: 1.5em; text-indent: -1.5em;
  color: #4a413d; font-size: 16px; line-height: 1.75; text-align: left;">•&nbsp;&nbsp;列表项内容，换行后悬挂缩进对齐</p>
```

有序列表同理，把 `•` 换成 `1.`、`2.`。

### 4. 输出压紧：块级标签之间不留空行

HTML 源码里块与块之间的空行/多余换行，富文本粘贴时会变成可见的空段落。最终产物要求：

- 块级元素之间最多一个换行符，**绝不出现连续空行**
- 不用空 `<p>`、`<p><br></p>` 或 `&nbsp;` 段落做垂直间距——间距一律用 `margin`
- 全文不出现 `<br>`（代码块内除外）

### 5. 纯内联样式 + 主容器

- 所有样式写在 `style` 属性；`<style>` 标签、class、外部样式表都会被剥掉
- `<body>` 后立即用一个主 `<div>` 包住全部内容，全局样式（背景、padding）加在它身上——加在 body 上会丢
- 每个 `<p>` 显式写 `color`——微信会把无显式颜色的文字重置为黑色
- 图片写 `max-width: 100%`；字号用 px，不用 rem/em

## 其他不能用的

- `<script>`、`<iframe>`、表单元素——被剥除
- `position: fixed/absolute`、CSS 动画——被清洗
- SVG 内联——支持不稳定，转 PNG
- 外部图片 URL 作为最终产物——正文只显示 `mmbiz.qpic.cn` 的图（`md2publish-draft` 上传时替换，本地阶段可暂留本地路径）

## 生成后机械自检（必须执行）

对产物跑这段检查，任何一项不过就修完再交付：

```bash
python3 - <<'EOF'
import re, sys
html = open(sys.argv[1] if len(sys.argv) > 1 else 'article.html').read()
fails = []
pres = re.findall(r'<pre[^>]*>(.*?)</pre>', html, re.S)
if any('\n' in p.strip() for p in pres):
    fails.append('代码块含裸换行，须转成 <br> + &nbsp;')
if re.search(r'text-align:\s*justify', html):
    fails.append('存在 text-align: justify')
if re.search(r'<(ul|ol|li)[\s>]', html):
    fails.append('存在原生 ul/ol/li，须改为 <p> 模拟列表')
if re.search(r'<p[^>]*>(\s|&nbsp;|<br\s*/?>)*</p>', html):
    fails.append('存在空段落')
if re.search(r'\n\s*\n', html):
    fails.append('块之间存在连续空行')
if re.search(r'<(style|script|iframe)[\s>]', html):
    fails.append('存在 style/script/iframe 标签')
if re.search(r'<h1[\s>]', html, re.I):
    fails.append('正文渲染了 <h1>：标题只进元数据注释的 title，编辑器会另行显示，正文里是重复')
m = re.search(r'<!--\s*md2publish\s*(\{.*?\})\s*-->', html, re.S)
if not m:
    fails.append('缺少 <!-- md2publish {...} --> 元数据注释')
else:
    import json
    try:
        if not json.loads(m.group(1)).get('title'):
            fails.append('元数据注释里 title 为空')
    except json.JSONDecodeError:
        fails.append('元数据注释不是合法 JSON')
paras = re.findall(r'<p[^>]*>', html)
no_align = [p for p in paras if 'text-align' not in p]
if no_align:
    fails.append(f'{len(no_align)} 个 <p> 缺少显式 text-align')
no_color = [p for p in paras if 'color' not in p]
if no_color:
    fails.append(f'{len(no_color)} 个 <p> 缺少显式 color')
print('FAIL:\n- ' + '\n- '.join(fails) if fails else 'PASS: 全部检查通过')
EOF
```

## 自检清单（人工过一遍）

- [ ] 机械自检 PASS
- [ ] 主 div 容器存在，全局样式在它身上
- [ ] 头部有 `<!-- md2publish {...} -->` 元数据注释
- [ ] 源文件的 `:::module` 块没有以原始文本残留
- [ ] 浏览器打开检查：代码块缩进完整、无异常空行、无大字间距行
