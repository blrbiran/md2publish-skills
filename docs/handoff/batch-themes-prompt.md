# 批量重跑主题：什么时候需要，以及怎么跑

> 这份文档是给**人**看的使用说明。第三节那个代码块是给新会话粘贴的。
> 更新于 2026-08-06：**`theme.json` 已经 27 份全部入仓**，这份文档的适用范围因此大幅收窄——
> 先看第一节判断你到底需不需要开新会话。

## 一、先判断：你需要的是哪一种「重跑」

| 场景 | 怎么做 | 成本 |
|---|---|---|
| **换一篇文章，想看 27 个主题的效果** | **不需要开新会话**，直接循环跑脚本（第二节） | **$0** |
| **改了少数几个主题文件，要同步 theme.json** | 自己在当前会话改那几份，别开批量 | 很低 |
| **改了 `_common-tech.md` 或铁律，27 份 theme.json 都要重做判断** | 开新会话，用第三节的 prompt | $25–35 |
| **新增了一批主题文件** | 开新会话，用第三节的 prompt，清单换成新主题 | 按个数 |

**`theme.json` 不含任何与文章相关的内容**（全是 `container` / `card` / `h2` / `p` 这类样式串），对任何文章都可复用。所以「换文章」这个最常见的场景，现在完全不需要重新做判断层的工作。

## 二、换文章：直接循环，不必开会话

```bash
cd ~/code/skills/writing/md2publish-skills
ART=<你的文章.md>
OUT=<你的产物目录>
mkdir -p "$OUT"

awk '/^python3 - <<.EOF.$/{f=1;next} /^EOF$/{f=0} f' \
    skills/md2publish-article/references/wechat-html.md > /tmp/selfcheck.py

for j in skills/md2publish-article/references/theme-json/*.theme.json; do
  n=$(basename "$j" .theme.json)
  python3 skills/md2publish-article/scripts/md2html.py "$ART" "$j" -o "$OUT/$n.html" >/dev/null
  printf '%-24s %s\n' "$n" "$(python3 /tmp/selfcheck.py "$OUT/$n.html" | head -1)"
done
```

27 份全部应当 PASS。**有 FAIL 说明这篇文章命中了某个主题没覆盖到的结构**（比如出现了有序列表、提示卡、导语段，而该主题没配对应字段）——那才需要人去看，而且只需要看 FAIL 的那几个。

## 三、需要重做判断层时：粘贴给新会话的 prompt

**为什么要开新会话**：单个主题的实际产出只有约 2k token，成本几乎全部来自上下文重发。在一个已经跑了半天的大会话里做，每轮 $3–6；新会话约 $25–35 跑完全库。

### 开跑前先确认四条基线

```bash
cd ~/code/skills/writing/md2publish-skills
git status                                                   # 干净，且在 main 上
python3 skills/md2publish-article/scripts/audit-themes.py    # 0 条
bash skills/md2publish-article/scripts/test-audit-themes.sh  # 14 全绿
bash skills/md2publish-article/scripts/test-md2html.sh       # 25 全绿
```

四条都过了再开新会话。这些是基线，跑批量时如果它们变了，是这一批改坏了东西。

> **注意 `test-md2html.sh` 的 PART B 会在批量跑之后变红**——它比对的是「仓库里的 theme.json 能否复现定稿 HTML」，你既然重做了 theme.json，产物当然要跟着重生成。**先重新生成产物，再重跑这条基线**，别改测试迁就它。

### prompt 正文

```
项目：md2publish-skills，仓库 ~/code/skills/writing/md2publish-skills/。
任务：按主题文件重新生成 theme.json——写 theme.json、生成 HTML、过自检、验落点。

先读这四份（只读一次，后面所有主题共用，别重复读）：
- skills/md2publish-article/references/theme-prompts/_common-tech.md   ← 通用技术约束，最重要
- skills/md2publish-article/scripts/md2html.py 的**文件头 docstring**（字段表在里面；
  整个文件 460 行左右，不要全读）
- skills/md2publish-article/references/wechat-html.md                   ← 五条铁律 + 末尾自检脚本
- skills/md2publish-article/references/theme-json/06-editor-slate.theme.json
  ← 一份已定稿的 theme.json，照它的字段形状写

**不要读那篇测试文章**（litellm-multi-provider-gateway.md，2.8 万字符）。md2html.py 自己从磁盘读它，
你不需要它的内容——你的工作单元只有 theme.json。

**仓库里已有一份 theme.json 可以对照**（references/theme-json/<编号>-<主题名>.theme.json）。
你的任务是按主题文件重新做一遍判断，做完与现有那份 diff：**差异处要么是你改对了、要么是你漏了，
两种都要在报告里说明**，不要默默覆盖。

准备工作（做一次）：
  cd ~/code/skills/writing/md2publish-skills
  awk '/^python3 - <<.EOF.$/{f=1;next} /^EOF$/{f=0} f' \
      skills/md2publish-article/references/wechat-html.md > /tmp/selfcheck.py

然后按清单，**一个主题一轮**，每轮五步：

1. 读 `skills/md2publish-article/references/theme-prompts/<主题名>.md`（只读这一个）
2. 把它的散文规范翻译成 theme.json，写到
   `skills/md2publish-article/references/theme-json/<编号>-<主题名>.theme.json`
3. 生成：
   ART=~/code/skills/writing/wechat_test/litellm-multi-provider-gateway/litellm-multi-provider-gateway.md
   OUT=~/code/skills/writing/wechat_test/litellm-multi-provider-gateway/out
   python3 skills/md2publish-article/scripts/md2html.py "$ART" \
       "skills/md2publish-article/references/theme-json/<编号>-<主题名>.theme.json" \
       -o "$OUT/<编号>-<主题名>.html"
4. 自检必须 PASS：
   python3 /tmp/selfcheck.py "$OUT/<编号>-<主题名>.html"
5. 落点普查——每个强调色在产物里出现多少次：
   python3 -c "
   import re,collections,sys
   c=collections.Counter(re.findall(r'#[0-9a-fA-F]{6}', open(sys.argv[1]).read()))
   print(c.most_common(12))" "$OUT/<编号>-<主题名>.html"
   拿这个计数对着主题文件的「色彩系统」逐色看：**声明了的强调色计数接近 0 就是落点失效**，
   回去改 theme.json（不是改主题文件），重跑 3–5。
   **产物里出现了、但调色板里没有的色，也要在报告里列出来**——那多半是你自己造的色。

每个主题跑完，往 $OUT/BATCH-REPORT.md 追加 5 行以内：主题名 / 自检结果 / 各强调色计数 /
与仓库原有 theme.json 的差异 / 有没有踩到下面「会遇到的情况」里的哪一条。
```

## 四、五条判据（实测补的，读了能省一轮返工）

这几条要**连同 prompt 一起粘贴给新会话**。

### 1. 行内 code 用强调色文字 + 带底色 = 正常，不是冲突

本库 27 个主题里 **17 个**给行内 code 派了强调色文字，其中 15 个带淡底。实测裁定过：带底它就有自己的形状，和 strong 分得开，观感达标。审计脚本的 OVER 档就是按这个收窄的。

所以：**主题文件给行内 code 指定了强调色文字色，就照字面色值写，不要改成中性色，也不要报成「与 `_common-tech.md` 冲突」。** 只有「**无底** + 强调色文字」才是真缺陷。

> 这条是第一轮试点用真金白银换来的：一个执行者以「`_common-tech.md` 优先」为由，把 newsprint 的行内 code 从主题规定的报头红擅自改成了灰褐，整个主题要重跑。

### 2. 不要自己造主题文件里没有的颜色

为了凑语法高亮的对比度而现造新色，是这个库里反复出现的形态（lessons 规则 9）。正确做法：**先在该主题自己的调色板里找达标的色**（很多时候是有的，只是没去找）；找不到就退回默认文字色、放弃那个 token 的上色。

造出来的色只活在 `theme.json` 里，主题文件下次重写时它就消失了。**真要新色，是主题文件该补——报告里写清楚，交给人决定。**

### 3. 对比度是铁律，不是可以为气质让步的东西（lessons 规则 11）

「莫兰迪的明度微差」「次级色要够次级」都不是把文字降到 4.5:1 以下的理由。实测有两个主题的定稿产物栽在这上面。遇到主题文件给的色达不到，**照字面实现并在报告里上报**，不要自行降标准，也不要自己调色。

注意 **浅底上成立的强调色，换到深底不一定成立**（lessons 规则 12）：主题若是「浅色正文 + 深色代码块」的混合结构，语法高亮取色要按代码底单独算一遍。

### 4. 文末装饰、导语、有序列表都有专门字段

| 主题文件里写了 | 用这个字段 |
|---|---|
| 文末居中一枚印章 / 一行落款 / 「終」字 | `footer` + `footer_html` |
| 引用块首行前缀（如 `❝`） | `blockquote_prefix_html` |
| 全文第一段做导语处理 | `p_first` |
| 有序列表的序号要上色/加形 | `list_prefix_ol_html`（`{n}` 占位） |
| h2 文字两侧对称饰线 | `h2_prefix_html` + `h2_suffix_html` |
| 警示语义的 strong 换色 | `strong_alt` |
| 标题文字自带色块（收缩的） | `h2_text_style`，**不要把 `display: inline-block` 写在 `h2` 上** |

`footer` 的样式串**要自带 `color`**：脚本虽然会退回正文色兜底，但那通常不是落款该有的分量。

### 5. 这篇测试文没有导语段、没有有序列表

它是 `# H1` 之后直接 `## 导读`。主题文件里若写了「全文第一段做导语处理」，**该配的 `p_first` 还是要配**（换一篇文章就用得上），只是本文章看不出效果，报告里记一笔。**不要为此改文章。**

同理，本文章 0 处有序列表，`list_prefix_ol_html` 配了也看不出来——照配。

## 五、会遇到的情况，怎么处理

- **主题文件自相矛盾**（同一目标两个色值、或分寸与落点无法同时满足）：**不要自行取舍后当没事发生**。按字面能同时满足的那个方向做，然后在报告里写明是哪两条冲突。这是主题文件的缺陷，要单独修，不该埋在 theme.json 里（lessons 规则 4、规则 8）
- **主题文件没覆盖的元素**：按该主题的气质补，在报告里记一笔补了什么
- **规范渲染不出来**（要求逐节不同的内容、要判断「哪个数字算关键」）：**如实上报「机械层做不到」，不要用一个固定串糊弄过去**。加一条渲染不出来的规范会让审计闭嘴而产物毫无变化（lessons 规则 13）
- **提示卡**：只有主题文件里明确写了提示卡规范的才配 `alert` 字段。测试文里 5 处引用全部自标「旁注」，属补充说明，按判据**一张都不该升格**——不要为了用上这个字段去改文章
- **暗色主题**（`18-midnight-study` / `26-velvet-stage` / `27-retro-phosphor` / cyber-neon）：微信浅色模式下是否可读是**未决悬案**。照主题文件原样做，**不要自行改配色去迁就浅色模式**，在报告里标一句「暗色，待双模式验证」
- **想改主题文件本身**（不是 theme.json）：先停下来问用户

## 六、红线

- 不要传图、不要建草稿、不要 git commit/push——这三件事一律先问用户
- 不要另写转换脚本、不要手敲 HTML。唯一的转换入口是 `md2html.py`，你的工作单元只有 `theme.json`
- 产物目录里已有全部 27 个主题的旧产物，**不要删任何文件**

## 七、验收（跑完之后在这边做）

```bash
cd ~/code/skills/writing/md2publish-skills
git diff --stat skills/md2publish-article/references/theme-json/   # 看改了哪几份，逐份读 diff
python3 skills/md2publish-article/scripts/audit-themes.py          # 仍是 0 条
bash skills/md2publish-article/scripts/test-audit-themes.sh        # 仍 14 全绿
bash skills/md2publish-article/scripts/test-md2html.sh             # 25 全绿（产物须已重新生成）
git status skills/md2publish-article/references/theme-prompts/     # 应该干净
```

最后一条若不干净，说明新会话改了主题文件——按红线它应该先问过你，去读 diff 确认。

## 八、成本

- 共享上下文（`_common-tech.md` + docstring + 铁律 + 范例 theme.json）约 20KB，只读一次
- 每个主题增量：主题文件约 4KB + 现有 theme.json 约 3KB + 写出的 theme.json 约 3KB
- 27 个跑完，上下文累计约 200KB，全程约 $30–40

若中途成本明显超出，多半是会话在重复读共享文件或读了那篇测试文章——prompt 里已明确禁止，但值得在进度报告时抽查一次。
