#!/usr/bin/env bash
#
# census-themes.py 的变异测试：造带**已知缺陷**的主题对，断言脚本报什么、不报什么。
#
#     bash skills/md2publish-article/scripts/test-census-themes.sh
#
# 每个用例一份 .md + 一份 .theme.json，落到独立临时目录。
# **误报和漏报要一起测**——设计文档第四节记了三个陷阱，第一版三条纪律全踩中，
# 直接把这一档要抓的缺陷杀掉了。fixture 的书写形态贴着真实主题库来。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CENSUS="$SCRIPT_DIR/census-themes.py"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0

# mkmd <用例名>：从 stdin 读主题 .md
mkmd() { mkdir -p "$WORK/$1"; cat > "$WORK/$1/$1.md"; }
# mkjson <用例名>：从 stdin 读 theme.json
mkjson() { mkdir -p "$WORK/$1"; cat > "$WORK/$1/$1.theme.json"; }

# check <用例名> [期望的「档名 键」...]：不给期望 = 断言一条都不该报
# 这是 L1/L3 专用的旧断言函数（Task 3/4 遗留，26 条既有用例全走这条）。
# 本机语料库确实存在（task brief 已核实），如果不显式把 MD2HTML_CORPUS 指到
# 不存在的路径，这些从未为 L2 设计过的 fixture 会被现场拉去跑 L2、混进
# NEAR-ZERO/ZERO 之类的产物侧噪音（比如任何主题的背景色在容器 div 上天然只有
# 1 处落点，会被判 NEAR-ZERO），把这条早就该测完的 L1/L3 断言搅浑。
# L2 有自己的 checkl2（用 --article 显式指定语料），这里保持只测 L1/L3。
check() {
  local name="$1"; shift
  local expected actual
  expected="$(printf '%s\n' "$@" | sed '/^$/d' | sort)"
  actual="$(MD2HTML_CORPUS="$WORK/no-such-corpus-dir" python3 "$CENSUS" --fixture-dir "$WORK/$name" 2>&1 |
    awk '$1 ~ /^(UNCARRIED|INVENTED|INLINE-BLOCK|UNMOUNTED|ZERO|NEAR-ZERO|DECOR|INVERT|STALE-NOTE)$/ {print $1, $3}' | sort)"
  if [ "$actual" = "$expected" ]; then
    printf 'ok   %s\n' "$name"; pass=$((pass + 1))
  else
    printf 'FAIL %s\n     期望: %s\n     实得: %s\n' "$name" "${expected:-<空>}" "${actual:-<空>}"
    fail=$((fail + 1))
  fi
}

# 受控 fixture 文章：段落 6 段、strong 6 处、h3 2 处、列表 4 项。
# 计数写死，INVERT 的倍数关系才可断言。
ART="$WORK/fixture-article.md"
cat > "$ART" <<'EOF'
# 标题

## 第一章

一段正文，里面有 **强调甲** 和 **强调乙**。

又一段正文，**强调丙**。

### 小标题一

第三段正文，**强调丁**。

- 列表项一
- 列表项二

## 第二章

第四段正文，**强调戊**。

### 小标题二

第五段正文，**强调己**。

- 列表项三
- 列表项四
EOF

# checkl2 <用例名> [期望...]：带语料跑
checkl2() {
  local name="$1"; shift
  local expected actual
  expected="$(printf '%s\n' "$@" | sed '/^$/d' | sort)"
  actual="$(python3 "$CENSUS" --fixture-dir "$WORK/$name" --article "$ART" 2>&1 |
    awk '$1 ~ /^(UNCARRIED|INVENTED|INLINE-BLOCK|UNMOUNTED|ZERO|NEAR-ZERO|DECOR|INVERT|STALE-NOTE)$/ {print $1, $3}' | sort)"
  if [ "$actual" = "$expected" ]; then
    printf 'ok   %s\n' "$name"; pass=$((pass + 1))
  else
    printf 'FAIL %s\n     期望: %s\n     实得: %s\n' "$name" "${expected:-<空>}" "${actual:-<空>}"
    fail=$((fail + 1))
  fi
}

echo "── L1：UNCARRIED / INVENTED / INLINE-BLOCK ──────────"

# 1. 主题文件表格行声明了 token 色，theme.json 没兑现 → UNCARRIED
#    形态照 editor-slate 的 GitHub Dark token 表抄。
mkmd l1-uncarried-table <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 语法高亮

| 角色 | 色值 | 落点 |
|---|---|---|
| 注释 | `#6a737d` | 行注释 |
| 函数名 | `#d2a8ff` | 定义或调用处 |
EOF
mkjson l1-uncarried-table <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "highlight": {"comment": "#6a737d"}}
EOF
check l1-uncarried-table "UNCARRIED #d2a8ff"

# 2. 对照：token 色全部兑现 → 不该报
mkmd l1-uncarried-ok <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 语法高亮

| 角色 | 色值 | 落点 |
|---|---|---|
| 注释 | `#6a737d` | 行注释 |
| 函数名 | `#d2a8ff` | 定义或调用处 |
EOF
mkjson l1-uncarried-ok <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "highlight": {"comment": "#6a737d", "function": "#d2a8ff"}}
EOF
check l1-uncarried-ok

# 3. 同一行把色值当反例引用——UNCARRIED 取「规范行里的任意色值」，这行是它天然的
#    误报面。形态照 monochrome-mag.md:15 抄。该色在别处有落点，所以不该报。
mkmd l1-uncarried-counterexample <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 中灰：`#5a5a5a`（浅灰底上的次要文字——`#767676` 在 `#f2f2f2` 上只有 3.96:1，别用在灰底上）
- 浅灰底：`#f2f2f2`
- 浅中灰：`#767676`

## 正文与强调

- 段落：`color: #5a5a5a`
- 图注：`color: #767676`
EOF
mkjson l1-uncarried-counterexample <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #5a5a5a",
 "blockquote": "background-color: #f2f2f2; color: #767676"}
EOF
check l1-uncarried-counterexample

# 4. theme.json 里凭空多出一个色（执行者为凑对比度现造的）→ INVENTED
#    形态照 gilded-ink / terracotta-sun 抄，都在 highlight 键上。
mkmd l1-invented <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
EOF
mkjson l1-invented <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "highlight": {"comment": "#6a4f1a"}}
EOF
check l1-invented "INVENTED #6a4f1a"

# 5. 无卡片主题，h2 承担定宽却是 inline-block → INLINE-BLOCK
#    这是 arena-charge 的原始形态（判例）。
mkmd l1-inlineblock-h2 <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
EOF
mkjson l1-inlineblock-h2 <<'EOF'
{"container": "background-color: #ffffff", "content_width": 800,
 "p": "color: #222222",
 "h2": "color: #222222; display: inline-block; background-color: #222222"}
EOF
check l1-inlineblock-h2 "INLINE-BLOCK h2"

# 6. 有卡片主题，h2 在卡内不承担定宽 → 不该报。
#    这一格是判据的误报面：全库 12 处 inline-block 全在这种位置上。
mkmd l1-inlineblock-card-h2 <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
EOF
mkjson l1-inlineblock-card-h2 <<'EOF'
{"container": "background-color: #ffffff", "content_width": 800,
 "card": "background-color: #ffffff; border: 1px solid #222222",
 "p": "color: #222222",
 "h2": "color: #222222; display: inline-block"}
EOF
check l1-inlineblock-card-h2

# 7. 有卡片主题，card 自己是 inline-block → 该报。
#    第一版判据把 card 漏在范围外，20 个卡片主题等于零覆盖。
mkmd l1-inlineblock-card <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
EOF
mkjson l1-inlineblock-card <<'EOF'
{"container": "background-color: #ffffff", "content_width": 800,
 "card": "background-color: #ffffff; display: inline-block",
 "p": "color: #222222"}
EOF
check l1-inlineblock-card "INLINE-BLOCK card"

# 8. 有卡片主题，footer 是 inline-block → 该报（footer 恒 boxed=True）。
#    第一版被「无卡片」条件屏蔽掉了。
mkmd l1-inlineblock-footer <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
EOF
mkjson l1-inlineblock-footer <<'EOF'
{"container": "background-color: #ffffff", "content_width": 800,
 "card": "background-color: #ffffff",
 "p": "color: #222222",
 "footer": "color: #222222; display: inline-block"}
EOF
check l1-inlineblock-footer "INLINE-BLOCK footer"

# 9. 对照：inline-block 在 *_html 片段的内层 span 上 → 不该报（washi-spring 的形态）
mkmd l1-inlineblock-fragment <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
EOF
mkjson l1-inlineblock-fragment <<'EOF'
{"container": "background-color: #ffffff", "content_width": 800,
 "p": "color: #222222",
 "footer_html": "<span style=\"display: inline-block; color: #222222\">終</span>"}
EOF
check l1-inlineblock-fragment

# 10. INVENTED 的色只出现在 HTML 注释里（预演 Task 4 的豁免注记形态：
#     `<!-- census-ok: INVENTED highlight #6a4f1a ... -->`），theme.json 里现造的色
#     真身。规范文一次都没提过这个色——L1 本档还不解析豁免注记（那是 Task 4/6 的活），
#     所以正确实现应该照报 INVENTED，不该被注释里的这次「提及」蒙混过去。
#     踩 theme_lib.py:21-24 记的陷阱一：查落点前必须先剥注释，不剥的话注释里的色值会
#     被当成一次真实出现，把 INVENTED 骗过去。
mkmd l1-invented-in-comment <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`

<!-- census-ok: INVENTED highlight #6a4f1a 待真机定夺 -->
EOF
mkjson l1-invented-in-comment <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "highlight": {"comment": "#6a4f1a"}}
EOF
check l1-invented-in-comment "INVENTED #6a4f1a"

# 11. 对照：theme.json 里的色，在正文（非注释）里确实提过 → 不该报 INVENTED。
#     INVENTED 的负方向用例——第 4 条只测了「真现造」，没测「真声明」。
#
#     **已知没有牙齿，如实记录**：这条只断言「色在 .md 正文里声明过就不该报
#     INVENTED」，**分辨不了** INVENTED 该用 `jc - all_md` 算还是错写成
#     `jc - declared` 算——把 census-themes.py 里 INVENTED 的判据换成
#     `jc - declared`，这条照样绿，因为 declared 与 all_md 在当前 _ENTITY 下
#     恒等（见 census-themes.py:86-99 那段注释：_ENTITY 第一个分支就是裸色值
#     正则本身，任何带色值的行天然落进 spec_lines，declared 必然等于 all_md）。
#     只要 _ENTITY 的色值分支还在，**没有任何 fixture** 能让这两种写法在这条
#     判据上分出胜负，不是这条用例写弱了。一旦 _ENTITY 的色值分支被收窄
#     （declared 不再恒等于 all_md），这条才重新具备分辨力，届时要回来对着
#     `jc - declared` 变体重新验证一遍（走 census-themes.py:86-99 那段注释里
#     记的「改 _ENTITY 后要做的事」）。
mkmd l1-invented-declared-ok <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 高亮：`#6a4f1a`

## 正文与强调

- 段落：`color: #222222`
EOF
mkjson l1-invented-declared-ok <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "highlight": {"comment": "#6a4f1a"}}
EOF
check l1-invented-declared-ok

# 12. 无卡片主题，table（TOP_BLOCK 里非 h2 的成员）承担定宽却是 inline-block → 该报。
#     前 9 条里 TOP_BLOCK 只有 h2 被真正练到过——`TOP_BLOCK = ("h2",)` 也能过全部
#     9 条。这条钉住 p/p_first/h3/blockquote/pre/table/list_item/hr 至少有一个
#     真的在测。
mkmd l1-inlineblock-table <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
EOF
mkjson l1-inlineblock-table <<'EOF'
{"container": "background-color: #ffffff", "content_width": 800,
 "p": "color: #222222",
 "table": "color: #222222; display: inline-block"}
EOF
check l1-inlineblock-table "INLINE-BLOCK table"

echo "── L3：UNMOUNTED（语义条款没有机械挂载点）──────────"

# 10. 缩进有序条款行 + 关键词枚举里含否定词 → 该报 strong_alt。
#     这是设计文档第四节三个陷阱的现场（cyber-neon.md:36）。
#     「不要」躺在被引用的枚举里，距关键词「警示」约 10 字——8 字窗口挡不住，
#     救它的是引号护栏。
mkmd l3-cyberneon-form <<'EOF'
# fixture

## 色彩系统

- 背景：`#0f1420`（主容器）
- 主文字：`#c9d2e3`
- 副强调：`#ff4ba3`

## 正文与强调

- 段落：`color: #c9d2e3`
  1. 原文里带「注意 / 警告 / 不要 / 会导致」这类警示语义的 `strong`，改用 `color: #ff4ba3; font-weight: 600`
EOF
mkjson l3-cyberneon-form <<'EOF'
{"container": "background-color: #0f1420", "p": "color: #c9d2e3",
 "strong": "color: #ff4ba3"}
EOF
check l3-cyberneon-form "UNMOUNTED strong_alt"

# 11. 对照：同样的条款，theme.json 配了 strong_alt → 不该报
mkmd l3-strongalt-ok <<'EOF'
# fixture

## 色彩系统

- 背景：`#0f1420`（主容器）
- 主文字：`#c9d2e3`
- 副强调：`#ff4ba3`

## 正文与强调

- 段落：`color: #c9d2e3`
  1. 原文里带「注意 / 警告 / 不要 / 会导致」这类警示语义的 `strong`，改用 `color: #ff4ba3; font-weight: 600`
EOF
mkjson l3-strongalt-ok <<'EOF'
{"container": "background-color: #0f1420", "p": "color: #c9d2e3",
 "strong": "color: #c9d2e3",
 "strong_alt": {"keywords": ["注意", "警告"], "style": "color: #ff4ba3"}}
EOF
check l3-strongalt-ok

# 12. 散文体带完整 style 串的规范 → 该报 footer_html（ink-wash.md:47 的形态）
mkmd l3-prose-footer <<'EOF'
# fixture

## 色彩系统

- 背景：`#f7f6f2`（主容器）
- 朱砂：`#b5432a`

## 正文与强调

- 段落：`color: #333333`

## 收尾

文末居中放一个朱砂色小印章式符号：`<p style="text-align: center; color: #b5432a; font-size: 18px;">□</p>` 可换为「完」字。
EOF
mkjson l3-prose-footer <<'EOF'
{"container": "background-color: #f7f6f2", "p": "color: #333333",
 "strong": "color: #b5432a"}
EOF
check l3-prose-footer "UNMOUNTED footer_html"

# 13. 纯比喻句不带实体 → 不该报（ink-wash.md:8 的形态）
mkmd l3-metaphor <<'EOF'
# fixture

## 核心愿景

朱砂红是唯一的颜色，出现频率要低——像印章落在水墨画上，多了就俗。

## 色彩系统

- 背景：`#f7f6f2`（主容器）
- 朱砂：`#b5432a`

## 正文与强调

- 段落：`color: #333333`
- strong：`color: #b5432a`
EOF
mkjson l3-metaphor <<'EOF'
{"container": "background-color: #f7f6f2", "p": "color: #333333",
 "strong": "color: #b5432a"}
EOF
check l3-metaphor

# 14. 「引导语」不该命中「导语」→ 不该报 p_first（apple-air 的子串误报面）
mkmd l3-substring <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 强调：`#0071e3`

## 正文与强调

- 段落：`color: #222222`
- strong：`color: #0071e3`
- eyebrow 引导语用小号蓝字：`color: #0071e3; font-size: 12px`
EOF
mkjson l3-substring <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #0071e3"}
EOF
check l3-substring

# 15. 「无序前缀」里的单字「无」不该杀掉同行的「有序列表」条款 → 该报
mkmd l3-wu-not-negation <<'EOF'
# fixture

## 色彩系统

- 背景：`#eef7f2`（主容器）
- 主强调：`#2fa47e`

## 正文与强调

- 段落：`color: #222222`
- 列表：无序前缀 `<span style="color: #2fa47e;">✓</span>`，步骤类有序列表用绿色序号 `color: #2fa47e`
EOF
mkjson l3-wu-not-negation <<'EOF'
{"container": "background-color: #eef7f2", "p": "color: #222222",
 "strong": "color: #2fa47e",
 "list_prefix_html": "<span style=\"color: #2fa47e;\">✓</span>&nbsp;&nbsp;"}
EOF
check l3-wu-not-negation "UNMOUNTED list_prefix_ol_html"

# 16. 真正的否定句 → 不该报（「不要写…条款」）
mkmd l3-real-negation <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 强调：`#0071e3`

## 正文与强调

- 段落：`color: #222222`
- strong：`color: #0071e3`
- **不要写导语条款**：本主题第一段与其余段落同样处理，`color: #222222`
EOF
mkjson l3-real-negation <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #0071e3"}
EOF
check l3-real-negation

# 17. 自查补充用例（非任务简报原文）：l3-cyberneon-form（用例 10）的注释声称
#     「8 字窗口挡不住，救它的是引号护栏」，但实测「不要」到「警示」的字符距离是
#     11——已经超出 ±8 窗口，窗口本身就把它挡住了，引号护栏在那条用例里其实没有
#     被真正踩到（用 python3 逐字符核过位置，也拿掉引号护栏跑过整套用例验证：
#     19 条全绿，一条不少）。这条补一个「不要」确实落在窗口内、且被引号包住的
#     构造，真正让引号护栏成为唯一救命的一环——没有它这条会被误判为「已否定」
#     而漏报。
mkmd l3-quote-guard-pin <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 强调：`#ff4ba3`

## 正文与强调

- 段落：`color: #222222`
- 警示性 `strong`：引用「不要」这个词举例时也要换色 `color: #ff4ba3; font-weight: 600`
EOF
mkjson l3-quote-guard-pin <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #ff4ba3"}
EOF
check l3-quote-guard-pin "UNMOUNTED strong_alt"

# ── 修复轮 1：负局部性（negation locality）与相邻护栏的正/反方向补测 ──────────
# 复审 mutation-test 出 8 处「实现错了但全部用例照样绿」的缺口，逐条记在
# task-4-report.md「修复轮 1」一节。以下每条用例专门钉一个缺口，注释里点名
# 对应哪个 mutation。

# 18.（必修）一行两个互不相关的语义信号：真否定紧贴其中一个（该被压），
#     另一个离否定词 17 字远（该照报）。同时钉住两个 mutation：
#       - 整行布尔否定（不看局部窗口，一个「不要」压掉全行全部信号）
#       - 窗口从 8 放宽到 40（17 字仍落进 40 字窗口，一样被错压）
#     正确实现：td_alt 照报，alert 因为紧邻「不要」不该报。
mkmd l3-locality-mixed-signal <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 强调：`#0071e3`

## 正文与强调

- 段落：`color: #222222`
- 不要给提示卡加阴影，正文表格另外用一种斑马纹底色区分奇偶行文字更清楚 `color: #0071e3`
EOF
mkjson l3-locality-mixed-signal <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #0071e3"}
EOF
check l3-locality-mixed-signal "UNMOUNTED td_alt"

# 19. 单字「无」紧邻关键词——正方向：真的因为「无斑马纹」而不该报。
#     钉住「去掉无+word 规则」那个 mutation（此前只有反方向用例
#     l3-wu-not-negation，这条补正方向）。
mkmd l3-wu-adjacent-negates <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主强调：`#2fa47e`

## 正文与强调

- 段落：`color: #222222`
- 说明：本表无斑马纹底色处理，保持纯色背景 `background-color: #ffffff`
EOF
mkjson l3-wu-adjacent-negates <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #2fa47e"}
EOF
check l3-wu-adjacent-negates

# 20. 单字「无」落在窗口内但不紧邻关键词——不该被当否定。
#     钉住「无在窗口内任意位置都算否定」这个 mutation：正确实现只认
#     「无」+关键词紧邻组合，这条的「无」和「斑马纹」中间隔着「网格线，」，
#     窗口内但不紧邻，该照报。
mkmd l3-wu-window-not-adjacent <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主强调：`#2fa47e`

## 正文与强调

- 段落：`color: #222222`
- 说明：表格无网格线，斑马纹底色仍要保留 `background-color: #ffffff`
EOF
mkjson l3-wu-window-not-adjacent <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #2fa47e"}
EOF
check l3-wu-window-not-adjacent "UNMOUNTED td_alt"

# 21. HTML 注释里的关键词不算规范条款。钉住「check_l3 里漏剥注释」这个
#     mutation——不剥的话，注释里凑巧带着 style 串的草稿句会被当成真规范。
mkmd l3-comment-not-spec <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 强调：`#0071e3`

## 正文与强调

- 段落：`color: #222222`

<!-- 提示卡建议用 `background-color: #ddf4ff` -->
EOF
mkjson l3-comment-not-spec <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #0071e3"}
EOF
check l3-comment-not-spec

# 22. 「别」这个否定词紧邻关键词——钉住「NEGATIONS 被削成只剩『不要』」这个
#     mutation：「别把这段当导语处理」不该报 p_first。
mkmd l3-bie-negation <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 强调：`#0071e3`

## 正文与强调

- 段落：`color: #222222`
- strong：`color: #0071e3`
- 说明：别把这段当导语处理，普通段落即可 `color: #222222`
EOF
mkjson l3-bie-negation <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #0071e3"}
EOF
check l3-bie-negation

# 23. 同一行两次出现「导语」：一次紧跟在「引」后面（该被黑名单挡住），另一次
#     前面是「的」（不该被挡，该照报）。钉住「黑名单改成非定位判定」这个
#     mutation——错误实现只要行里出现过一次「引导语」，就会连累这一行里
#     所有「导语」命中，把第二个本该照报的也错杀掉。
mkmd l3-blacklist-positional <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 强调：`#0071e3`

## 正文与强调

- 段落：`color: #222222`
- strong：`color: #0071e3`
- eyebrow 引导语用于装饰，正文的导语仍要独立样式 `color: #0071e3`
EOF
mkjson l3-blacklist-positional <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #0071e3"}
EOF
check l3-blacklist-positional "UNMOUNTED p_first"

echo "── L2：ZERO / NEAR-ZERO / DECOR / INVERT ──────────"

# 自查发现（brief 原文的 checkl2 期望值与其自己给出的 ART/fixture 组合实测不符，
# 逐条核对确认后按下方 (a)/(b)/(c) 分类修正，不改判据/阈值/桶定义/fixture 内容）：
#
# ART 的 container 全文只渲染一次（`build()` 只拼一个最外层 div），本节全部
# 7 条 fixture 的 theme.json 都只在 container 上用了背景色、没有另配 card/
# blockquote/td 之类的键复用同一个色值，于是「背景：#ffffff」这个调色板条目
# 在每一条 fixture 里落点恒为 1——精确落进 NEAR-ZERO 的 1–2 阈值。这不是
# 判据错，也不是这几条 fixture 的书写错（brief 明确说了「变异测试断言的是
# 逻辑，不是频率合理性」，允许用极小语料），是 brief 给出的 checkl2 期望值
# 从没有真的跑过参照实现来核对过——7 条里没有一条把这一条 NEAR-ZERO 写进
# 期望值。下面每条都补上，用真实观测到的输出核实过（`python3 census-themes.py
# --fixture-dir ... --article ...` 逐条跑过，非手算）。
#
# l2-invert 还叠了一层同源问题：ART 的 h3 恰好出现 2 次（brief 自己写的
# 「h3 2 处」），h3 上的主强调落点因此也恰好落在 NEAR-ZERO 边界，与 INVERT
# 同时触发；l2-invert-ok 把副强调放在 h3 上，同样落点为 2，触发它自己的
# NEAR-ZERO——这两条原本都不在 brief 给出的期望值里。
#
# 这些追加都只是让期望值贴合「用 brief 给定的判据、阈值、fixture 逐字跑出来
# 的真实结果」，每条用例真正要测的东西（DECOR/INVERT 该不该在目标色上触发、
# 标签解析、去重降级）一个字没有变松——若目标档误触发或误沉默，实得里会多一行
# 或少一行，字符串比对照样会 FAIL。

# 17. 调色板声明了色，theme.json 也有（挂在一个渲染不到的键上）→ 产物 0 处 → ZERO
mkmd l2-zero <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 次级灰：`#999999`

## 正文与强调

- 段落：`color: #222222`
- 图注：`color: #999999`
EOF
mkjson l2-zero <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #222222",
 "td_alt": "background-color: #999999"}
EOF
checkl2 l2-zero "ZERO #999999" "NEAR-ZERO #ffffff"

# 18. 主强调只出现 1 处 → NEAR-ZERO（apple-air 出事时的形态）
#     h3_prefix_html 在 fixture 文章里只命中 2 次，用 footer_html 造 1 次。
mkmd l2-nearzero <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 唯一强调色：`#0071e3`

## 正文与强调

- 段落：`color: #222222`
- 落款：`color: #0071e3`
EOF
mkjson l2-nearzero <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #222222",
 "footer": "color: #0071e3",
 "footer_html": "完"}
EOF
checkl2 l2-nearzero "NEAR-ZERO #0071e3" "NEAR-ZERO #ffffff"

# 19. 强调色落点全是边框细线，文字落点 0 → DECOR（规则 6）
mkmd l2-decor <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 主强调：`#cc3366`

## 正文与强调

- 段落：`color: #222222`
- h3：`border-left: 3px solid #cc3366`
EOF
mkjson l2-decor <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #222222",
 "h3": "color: #222222; border-left: 3px solid #cc3366",
 "list_item": "color: #222222; border-left: 2px solid #cc3366"}
EOF
checkl2 l2-decor "DECOR #cc3366" "NEAR-ZERO #ffffff"

# 20. 标签写「线色，不作文字色」= 没标强调 → 不该报 DECOR。
#     判定只看冒号前的标签，不看破折号后的解释（washi-spring 的形态，
#     audit-themes.py:138-139 的注释逐字引用的就是这句话）。
mkmd l2-decor-labeled-line <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 灰樱粉（线色，不作文字色）：`#d98e9f`——h2 上下双细线、边框。而一个只当细线用的颜色不能算主强调
- 深樱（主强调，文字色）：`#b56b7d`

## 正文与强调

- 段落：`color: #222222`
- strong：`color: #b56b7d`
- h3：`border-bottom: 2px solid #d98e9f`
EOF
mkjson l2-decor-labeled-line <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #b56b7d",
 "h3": "color: #222222; border-bottom: 2px solid #d98e9f",
 "list_item": "color: #222222; border-left: 2px solid #d98e9f"}
EOF
checkl2 l2-decor-labeled-line "NEAR-ZERO #ffffff"

# 21. 主强调文字落点少于副强调 → INVERT（candy-pop 的形态）
mkmd l2-invert <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 樱粉（主强调）：`#f28ba8`
- 雾蓝（辅强调）：`#7fb5d5`

## 正文与强调

- 段落：`color: #222222`
- h3：`color: #f28ba8`
- strong：`color: #7fb5d5`
EOF
mkjson l2-invert <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "h3": "color: #f28ba8",
 "strong": "color: #7fb5d5"}
EOF
checkl2 l2-invert "INVERT #f28ba8" "NEAR-ZERO #ffffff" "NEAR-ZERO #f28ba8"

# 22. 主强调文字落点多于副强调 → 不该报
mkmd l2-invert-ok <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 樱粉（主强调）：`#f28ba8`
- 雾蓝（辅强调）：`#7fb5d5`

## 正文与强调

- 段落：`color: #222222`
- h3：`color: #7fb5d5`
- strong：`color: #f28ba8`
EOF
mkjson l2-invert-ok <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "h3": "color: #7fb5d5",
 "strong": "color: #f28ba8"}
EOF
checkl2 l2-invert-ok "NEAR-ZERO #ffffff" "NEAR-ZERO #7fb5d5"

# 23. UNCARRIED 已报过的色，ZERO 降级为 INFO 不重复计入 ERROR，
#     但事实不许从报告里消失。
mkmd l2-dedup <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 浅中灰：`#767676`

## 正文与强调

- 段落：`color: #222222`
- strong：`color: #222222`
EOF
mkjson l2-dedup <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #222222"}
EOF
checkl2 l2-dedup "UNCARRIED #767676" "NEAR-ZERO #ffffff"

# 24. 无语料时 L2 整体 SKIP，退出码要标红（静默跳过等于没有护栏），
#     且 L1/L3 照常出结论。
#     显式把 MD2HTML_CORPUS 指到不存在的路径——本机真实语料库确实存在
#     （task brief 已核实），不显式覆盖的话这条用例在本机会绕过 SKIP 分支，
#     变成「凑巧通过」而不是真的在测这条路径。l2-zero 本身 L1/L3 干净
#     （0 条），SKIP 时 found 必为空，能唯一暴露 `main()` 结尾漏写
#     `or (0 if has_corpus else 1)` 这个 mutation。
echo -n "ok   l2-nocorpus-fails-loud ... "
if MD2HTML_CORPUS="$WORK/no-such-corpus-dir" python3 "$CENSUS" --fixture-dir "$WORK/l2-zero" >/dev/null 2>&1; then
  printf 'FAIL l2-nocorpus-fails-loud\n     期望: 无语料时退出码非 0\n     实得: 0\n'
  fail=$((fail + 1))
else
  printf '\rok   l2-nocorpus-fails-loud                    \n'
  pass=$((pass + 1))
fi

printf '\n%d 通过，%d 失败\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
