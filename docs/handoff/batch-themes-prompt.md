# 批量跑剩余 20 个主题：新会话启动 prompt

> 这份文档是给**人**看的使用说明。第二节那个代码块是给新会话粘贴的。
> 为什么要开新会话：单个主题的实际产出只有约 2k token，成本几乎全部来自上下文重发。
> 在一个已经跑了半天的大会话里做，每轮 $3–6，20 个约 $150–200；新会话约 $25–35。

## 一、开跑前先确认

1. 仓库干净（`git status`），且已经在 `main` 上
2. `python3 skills/md2publish-article/scripts/audit-themes.py` 是 0 条
3. `bash skills/md2publish-article/scripts/test-audit-themes.sh` 全绿

三条都过了再开新会话。这些是基线，跑批量时如果它们变了，是这一批改坏了东西。

## 二、粘贴给新会话的 prompt

```
项目：md2publish-skills，仓库 ~/code/skills/writing/md2publish-skills/。
任务：给主题库里剩余 20 个主题各做一次实测——写 theme.json、生成 HTML、过自检、验落点。

先读这四份（只读一次，后面 20 个主题共用，别重复读）：
- skills/md2publish-article/references/theme-prompts/_common-tech.md   ← 通用技术约束，最重要
- skills/md2publish-article/scripts/md2html.py 的**文件头 docstring**（第 2–53 行，字段表在里面；
  整个文件 443 行，不要全读）
- skills/md2publish-article/references/wechat-html.md                   ← 五条铁律 + 末尾自检脚本
- ~/code/skills/writing/wechat_test/litellm-multi-provider-gateway/out/06-editor-slate.theme.json
  ← 一份已定稿的 theme.json，照它的字段形状写

**不要读那篇测试文章**（litellm-multi-provider-gateway.md，2.8 万字符）。md2html.py 自己从磁盘读它，
你不需要它的内容——你的工作单元只有 theme.json。

准备工作（做一次）：
  cd ~/code/skills/writing/md2publish-skills
  awk '/^python3 - <<.EOF.$/{f=1;next} /^EOF$/{f=0} f' \
      skills/md2publish-article/references/wechat-html.md > /tmp/selfcheck.py

然后按下面的清单，**一个主题一轮**，每轮五步：

1. 读 `skills/md2publish-article/references/theme-prompts/<主题名>.md`（只读这一个）
2. 把它的散文规范翻译成 theme.json，写到
   `~/code/skills/writing/wechat_test/litellm-multi-provider-gateway/out/<编号>-<主题名>.theme.json`
3. 生成：
   ART=~/code/skills/writing/wechat_test/litellm-multi-provider-gateway/litellm-multi-provider-gateway.md
   OUT=~/code/skills/writing/wechat_test/litellm-multi-provider-gateway/out
   python3 skills/md2publish-article/scripts/md2html.py "$ART" \
       "$OUT/<编号>-<主题名>.theme.json" -o "$OUT/<编号>-<主题名>.html"
4. 自检必须 PASS：
   python3 /tmp/selfcheck.py "$OUT/<编号>-<主题名>.html"
5. 落点普查——每个强调色在产物里出现多少次：
   python3 -c "
   import re,collections,sys
   c=collections.Counter(re.findall(r'#[0-9a-fA-F]{6}', open(sys.argv[1]).read()))
   print(c.most_common(12))" "$OUT/<编号>-<主题名>.html"
   拿这个计数对着主题文件的「色彩系统」逐色看：**声明了的强调色计数接近 0 就是落点失效**，
   回去改 theme.json（不是改主题文件），重跑 3–5。

每个主题跑完，往 `$OUT/BATCH-REPORT.md` 追加 5 行以内：主题名 / 自检结果 /
各强调色计数 / 有没有踩到下面「会遇到的情况」里的哪一条。20 个跑完我一次性看这份报告。

## 会遇到的情况，怎么处理

- **主题文件自相矛盾**（比如既写「某色频率要低」又把它派给行内 code）：**不要自行取舍后当没事发生**。
  按字面能同时满足的那个方向做，然后在报告里写明是哪两条冲突。这是主题文件的缺陷，
  要单独修，不该埋在 theme.json 里（依据见 docs/theme-design-lessons.md 规则 4）
- **主题文件没覆盖的元素**：按该主题的气质补，在报告里记一笔补了什么
- **提示卡**：只有主题文件里明确写了提示卡规范的才配 `alert` 字段。测试文里 5 处引用全部自标
  「旁注」，属补充说明，按判据**一张都不该升格**——不要为了用上这个字段去改文章
- **暗色主题**（18-midnight-study / 26-velvet-stage / 27-retro-phosphor）：微信浅色模式下
  是否可读是**未决悬案**，用户尚未真机验证。照主题文件原样做，**不要自行改配色去迁就浅色模式**，
  在报告里标一句「暗色，待双模式验证」
- **想改主题文件本身**（不是 theme.json）：先停下来问用户。改了就必须跑
  `python3 skills/md2publish-article/scripts/audit-themes.py`（要 0 条）和
  `bash skills/md2publish-article/scripts/test-audit-themes.sh`（要全绿）

## 红线

- 不要传图、不要建草稿、不要 git commit/push——这三件事一律先问用户
- 不要另写转换脚本、不要手敲 HTML。唯一的转换入口是 md2html.py，你的工作单元只有 theme.json
- 产物目录 `$OUT` 里已有 7 个主题的旧产物，**不要删任何文件**

## 待跑清单（20 个，编号取自 INDEX.md）

03-spring-fresh / 05-newsprint / 07-coffee-journal / 08-morandi-fog / 09-gilded-ink /
10-lavender-dusk / 12-apple-air / 14-celadon-scroll / 15-mint-breeze / 16-arena-charge /
17-scarlet-tech / 18-midnight-study / 19-candy-pop / 21-aurora-flow / 22-blueprint-grid /
23-terracotta-sun / 24-botanic-press / 25-washi-spring / 26-velvet-stage / 27-retro-phosphor

从 03-spring-fresh 开始，按顺序做。每做完 5 个跟我报一次进度。
```

## 三、验收（跑完之后在这边做）

新会话报完之后，回到主仓库确认这四条：

```bash
cd ~/code/skills/writing/md2publish-skills
git status                                                   # 应该干净——产物在仓库外
python3 skills/md2publish-article/scripts/audit-themes.py    # 仍是 0 条
bash skills/md2publish-article/scripts/test-audit-themes.sh  # 仍全绿
ls ~/code/skills/writing/wechat_test/litellm-multi-provider-gateway/out/*.theme.json | wc -l   # 应为 27
```

`git status` 若不干净，说明新会话改了主题文件——按红线它应该先问过你，去读 diff 确认。

## 四、成本

- 共享上下文（`_common-tech.md` + docstring + 铁律 + 范例 theme.json）约 20KB，只读一次
- 每个主题增量：主题文件约 4KB + 写出的 theme.json 约 3KB
- 20 个跑完，上下文累计约 150KB，全程约 $25–35

若中途成本明显超出，多半是会话在重复读共享文件或读了那篇测试文章——prompt 里已明确禁止，
但值得在进度报告时抽查一次。
