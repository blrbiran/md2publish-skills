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
bad_quotes = [t for t in re.findall(r'<[a-zA-Z][^>]*>', html) if t.count('"') % 2]
if bad_quotes:
    fails.append(f'{len(bad_quotes)} 个标签内引号不配对（style 属性被截断，整段样式会失效）：{bad_quotes[0][:60]}')
if not re.search(r'max-width:\s*\d+px', html):
    fails.append('内容块缺 max-width：公众号电脑端是定宽渲染，不加会铺满整屏')
main = re.search(r'<div[^>]*>', html)
if main and 'background' in main.group() and re.search(r'max-width:\s*\d+px', main.group()):
    fails.append('主容器同时有 background 和 max-width：背景会被夹成 800px 宽，两边露白。'
                 '背景挂主 div（不限宽），定宽挂内容块')
def _eff_margin(style):
    ml = mr = '0'
    for decl in style.split(';'):
        if ':' not in decl: continue
        p, v = [x.strip() for x in decl.split(':', 1)]
        if p == 'margin':
            q = v.split()
            if len(q) == 1: ml = mr = q[0]
            elif len(q) in (2, 3): ml = mr = q[1]
            elif len(q) == 4: mr, ml = q[1], q[3]
        elif p == 'margin-left': ml = v
        elif p == 'margin-right': mr = v
    return ml, mr
boxed = re.findall(r'style="([^"]*max-width:\s*\d+px[^"]*)"', html)
off_center = [s for s in boxed if _eff_margin(s) != ('auto', 'auto')]
if off_center:
    fails.append(f'{len(off_center)}/{len(boxed)} 个定宽块没有水平居中：主题样式里的 margin 简写'
                 f'覆盖了 margin-left/right: auto，内容会贴在左边。定宽居中要拼在主题样式之后')
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
# 以下三条防的是同一类事故：产物看着正常、错在元数据和首段，肉眼扫不出来。
# 上游 wechat-finetune 的产物必带 frontmatter，md2html.py 早先不认它，于是
# title 从代码块里的 shell 注释抓、frontmatter 三行变成正文首段，一路带到草稿箱。
body = html[m.end():] if m else html
leaked = re.findall(r'<p[^>]*>\s*(?:title|author|digest|summary|description)\s*[:：]', body, re.I)
if leaked:
    fails.append(f'{len(leaked)} 处 frontmatter 泄漏进正文：源 md 的 --- 元数据块没被剥掉')
if m:
    try:
        t = json.loads(m.group(1)).get('title', '')
    except json.JSONDecodeError:
        t = ''
    # title 只要在任何一个代码块里出现过，就极可能是从 `# 注释` 抓来的
    if t and any(t in c for c in re.findall(r'<pre[^>]*>(.*?)</pre>', html, re.S)):
        fails.append(f'元数据 title「{t}」在代码块里出现过：多半是把代码注释当成 H1 抓了，'
                     f'去核对源 md 的 frontmatter')
h3s = set(re.findall(r'<h3[^>]*style="([^"]*)"', html))
first_p = re.search(r'<p[^>]*style="([^"]*)"', body)
def _key(s):
    d = dict(x.split(':', 1) for x in (y for y in s.split(';') if ':' in y))
    return (d.get('font-size', '').strip(), d.get('font-weight', '').strip())
if first_p and h3s and _key(first_p.group(1)) in {_key(h) for h in h3s} and _key(first_p.group(1))[0]:
    fails.append('导语段的字号+字重和 h3 完全一致：读者会把第一段当成小标题，'
                 '把主题的 p_first 调开（导语只加大字号、拉开间距，别加粗）')
print('FAIL:\n- ' + '\n- '.join(fails) if fails else 'PASS: 全部检查通过')
EOF
```

## 自检清单（人工过一遍）

- [ ] 机械自检 PASS
- [ ] 主 div 容器存在，全局样式在它身上
- [ ] 头部有 `<!-- md2publish {...} -->` 元数据注释
- [ ] 源文件的 `:::module` 块没有以原始文本残留
- [ ] 浏览器打开检查：代码块缩进完整、无异常空行、无大字间距行
