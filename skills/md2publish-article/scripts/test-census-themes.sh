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

# 受控 fixture 文章：段落 6 段、strong 6 处、h3 2 处、列表 4 项、**em 1 处**。
# 计数写死，INVERT 的倍数关系才可断言。
#
# em 那一处是给 NEAR-ZERO 结构键收窄那一节用的（本文件末尾 case 43）：真实库里
# candy-pop 的 `#e8f2f9` 只挂在 `em` 上，落点恒 1，是规则 1 说的那种死色，收窄判据
# 时**必须继续报**。不在 ART 里放一个 em，就只能拿别的键去近似那个形态，钉不住真靶子。
# 对既有用例无影响：没有任何一条 fixture 的 theme.json 配了 `em` 键，
# `md2html.py:210-211` 于是渲染成 `<em style="">`，不含色值，landings() 数不到它。
ART="$WORK/fixture-article.md"
cat > "$ART" <<'EOF'
# 标题

## 第一章

一段正文，里面有 **强调甲** 和 **强调乙**，还有一处 *轻强调*。

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

# checkcounts <用例名> <色值> <期望"总 文字 面 线">：断言 --counts 某一行的
# 四个数字。awk 用默认空白分列取第 3-6 个字段——本节 fixture 的角色标签都不
# 含 ASCII 空格（沿用全库既有 fixture 的写法），列对不齐的风险因此可控。
checkcounts() {
  local name="$1" color="$2" expected="$3"
  local actual
  actual="$(python3 "$CENSUS" --fixture-dir "$WORK/$name" --article "$ART" --counts "$name" 2>&1 |
    awk -v c="$color" '$1==c {print $3, $4, $5, $6}')"
  if [ "$actual" = "$expected" ]; then
    printf 'ok   %s --counts %s\n' "$name" "$color"; pass=$((pass + 1))
  else
    printf 'FAIL %s --counts %s\n     期望: %s\n     实得: %s\n' \
      "$name" "$color" "$expected" "${actual:-<空>}"
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
#    误报面。形态是「同一行把另一个色值当反例引用」，真实库里 bauhaus-pop.md 的语法
#    高亮行（「红 X 和蓝 Y 不进代码块——只有 2.94:1 和 2.65:1」）就是这个形状。
#    该色在别处有落点，所以不该报。
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

# 10. INVENTED 的色只出现在 HTML 注释里，theme.json 里现造的色真身。规范文
#     一次都没提过这个色——所以正确实现应该照报 INVENTED，不该被注释里的这次
#     「提及」蒙混过去。踩 theme_lib.py:21-24 记的陷阱一：查落点前必须先剥
#     注释，不剥的话注释里的色值会被当成一次真实出现，把 INVENTED 骗过去。
#     Task 6 补记：这条本来写的是 `<!-- census-ok: INVENTED highlight #6a4f1a
#     ... -->`，当时（Task 3/4）L1 还不解析豁免注记，这行纯粹是普通注释、
#     对判据没有任何效力。Task 6 把 census-ok 解析接上了之后，这行会被真的
#     当成一条注记去匹配——而且键还写错了（"highlight" 是 theme.json 的字段名，
#     不是 INVENTED 行真正用的键即色值本身），匹配不到，会多报一条
#     `STALE-NOTE highlight`，把这条测的东西（注释里的色值不算「声明」）跟
#     豁免机制自己的行为搅在一起。改成不带 census-ok 前缀的普通注释，只保留
#     「色值出现在注释里」这一件事，测的东西不变，也不会误触发新解析的注记
#     语法。
mkmd l1-invented-in-comment <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`

<!-- 待定色，先记一笔：#6a4f1a -->
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
checkl2 l2-zero "ZERO #999999"

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
checkl2 l2-nearzero "NEAR-ZERO #0071e3"

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
checkl2 l2-decor "DECOR #cc3366"

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
checkl2 l2-decor-labeled-line

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
checkl2 l2-invert "INVERT #f28ba8" "NEAR-ZERO #f28ba8"

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
checkl2 l2-invert-ok "NEAR-ZERO #7fb5d5"

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
checkl2 l2-dedup "UNCARRIED #767676"

# ── fix round 1（code review 补漏）──────────────────────────────────────
# check_l2 里 INVERT 判据有两条分支：主强调 vs 副/辅强调（用例 21/22 已覆盖），
# 主强调 vs「参照色」（`for rc, rl in refs:`，`text_count(rc) > 3 * max(n, 1)`）。
# 上面 7 条 fixture 里每一条的非强调色标签都落进了 REF_EXCLUDE（背景/主文字/
# 次级……），`refs` 因此恒为空集，参照色分支在这批用例下是死代码——真实库里
# gilded-ink/mint-breeze/terracotta-sun 那 3 条 INVERT 恰恰全靠这条分支才报出来
# （见 task-5-report.md 真实库列表），删掉这条分支或把阈值改到离谱，34 条用例
# 一条不掉。下面两条钉住它：main 挂在 h3 上（ART 恒为 2 次），参照色标签仿真实
# 库 gilded-ink 的形态「深金（strong 用）」——不含强调关键词、也不含 REF_EXCLUDE
# 任何一个子串，是货真价实能进 `refs` 的角色。

# 25.（必修，钉参照色分支）参照色文字落点 9，是主强调 2 的 4.5 倍，超过三分之一
#     阈值（9 > 3×2=6）→ 该报 INVERT。
mkmd l2-invert-ref <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 深橘（主强调）：`#a34a1f`
- 深金（strong 用）：`#b08a3e`

## 正文与强调

- 段落：`color: #b08a3e`
- h3：`color: #a34a1f`
EOF
mkjson l2-invert-ref <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #b08a3e",
 "h3": "color: #a34a1f"}
EOF
checkl2 l2-invert-ref "INVERT #a34a1f" "NEAR-ZERO #a34a1f"

# 26. 对照（近失手）：参照色文字落点 5（只落在真正的段落上，列表项另配了第三个
#     颜色、不再落回 p 的兜底），是主强调 2 的 2.5 倍，没有过三分之一阈值
#     （5 不 > 6）→ 不该报 INVERT。这条和用例 25 只差「列表项要不要单独配色」
#     一行，逼参照色分支的比较是真的在算数，不是「只要存在一个非强调色落点
#     比主强调多就报」这种粗判。
mkmd l2-invert-ref-nearmiss <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 深橘（主强调）：`#a34a1f`
- 深金（strong 用）：`#b08a3e`

## 正文与强调

- 段落：`color: #b08a3e`
- 列表：`color: #556677`
- h3：`color: #a34a1f`
EOF
mkjson l2-invert-ref-nearmiss <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #b08a3e",
 "list_item": "color: #556677",
 "h3": "color: #a34a1f"}
EOF
checkl2 l2-invert-ref-nearmiss "NEAR-ZERO #a34a1f"

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

echo "── 豁免机制 ──────────"

# 自查发现（同一类偏离，第二次出现——case 24/l2-nocorpus-fails-loud 已经踩过
# 一次）：brief 原文的 case 25/27 checkl2 期望值同样没有对着参照实现实测过。
# 这两条都用 --article "$ART" 走 checkl2，而 ART 的 container 全文只渲染一次
# （test-census-themes.sh:702-720 那段总注释已经记过这个恒等式），
# 「背景：#ffffff」在这两条 fixture 里都只声明在 container 上、没有另配
# 复用同一色值的键，落点恒为 1，精确落进 NEAR-ZERO 阈值——且两条注记都只点名
# 了各自的 INVENTED 目标，不会捎带把这条 NEAR-ZERO 也销掉。逐条用
# `python3 census-themes.py --fixture-dir ... --article ...` 核实过（非手算），
# 下面按实测结果补上 "NEAR-ZERO #ffffff"，不改注记匹配逻辑本身、不改判据/
# 阈值——这条 NEAR-ZERO 恰好还顺带证明了 trap 1 要求的性质：INVENTED 注记
# 只销 INVENTED，不会连累同一 fixture 里其它档的发现。

# 25. 写了对应注记 → 该发现被销掉（NEAR-ZERO #ffffff 不在注记射程内，照报）
mkmd ex-silenced <<'EOF'
# fixture

<!-- census-ok: INVENTED #6a4f1a 为凑代码块对比度所加，待主题文件补声明 -->

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
- strong：`color: #222222`
EOF
mkjson ex-silenced <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #222222", "highlight": {"comment": "#6a4f1a"}}
EOF
checkl2 ex-silenced

# 26. 档名打错 → FAIL，不许静默地什么都不销
mkmd ex-badtier <<'EOF'
# fixture

<!-- census-ok: INVENTD #6a4f1a 档名打错了 -->

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
- strong：`color: #222222`
EOF
mkjson ex-badtier <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #222222", "highlight": {"comment": "#6a4f1a"}}
EOF
# 用变量捕获 + 子串判断而不是 `| grep -q`：管道直接喂给 grep 在本机偶发漏判
# （同一条命令反复跑，命中率不稳定，疑似沙箱里 grep 被 rtk/ugrep 代理接管后对
# 实时管道的读取有时序竞争——文件落盘后再 grep 或者这里改用的变量捕获都稳定
# 命中，纯 grep 直接接子进程管道的读法不稳）。command substitution 会等子
# 进程彻底跑完再把全部输出收进变量，没有管道时序这一层，断言的仍是同一个
# 子串「档名不认识」，不改判据。
out="$(python3 "$CENSUS" --fixture-dir "$WORK/ex-badtier" --article "$ART" 2>&1)"
if [[ "$out" == *"档名不认识"* ]]; then
  printf 'ok   ex-badtier\n'; pass=$((pass + 1))
else
  printf 'FAIL ex-badtier\n     期望: 报「档名不认识」\n     实得: %s\n' "$out"; fail=$((fail + 1))
fi

# 27. 注记销不到任何东西 → STALE-NOTE（同样带着不在射程内的 NEAR-ZERO #ffffff）
mkmd ex-stale <<'EOF'
# fixture

<!-- census-ok: INVENTED #aabbcc 这个色早就不在 theme.json 里了 -->

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
- strong：`color: #222222`
EOF
mkjson ex-stale <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #222222"}
EOF
checkl2 ex-stale "STALE-NOTE #aabbcc"

# 28. 无语料时 L2 的注记不判 stale（否则一跑就是一片凭空 ERROR）
#     显式把 MD2HTML_CORPUS 指到不存在的路径——本机真实语料库确实存在
#     （case 24 的注释已经记过这件事），brief 原文这条没有显式覆盖，在本机会
#     绕开 SKIP 分支：默认语料真实存在，L2 会正常跑起来，INVERT 是 L2_TIERS
#     的成员，注记又确实销不到任何发现（fixture 的 .md 里根本没有 #f28ba8
#     这个色值，check_l2 不可能产出这个键的行），于是 l2_active 恒真会让它
#     被判成真正的 STALE-NOTE，跟这条用例本该测的「无语料」路径正好对不上——
#     跟 case 24 是同一个坑，补同一个显式覆盖。
mkmd ex-stale-layergate <<'EOF'
# fixture

<!-- census-ok: INVERT #f28ba8 待真机观感定夺 -->

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
- strong：`color: #222222`
EOF
mkjson ex-stale-layergate <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #222222"}
EOF
# 同 case 26：变量捕获 + 子串判断，不直接管道喂 grep（原因见 case 26 注释）。
out="$(MD2HTML_CORPUS="$WORK/no-such-corpus-dir" python3 "$CENSUS" --fixture-dir "$WORK/ex-stale-layergate" 2>&1)"
if [[ "$out" == *"STALE-NOTE"* ]]; then
  printf 'FAIL ex-stale-layergate\n     期望: 无语料时 L2 注记不判 stale\n     实得: %s\n' "$out"; fail=$((fail + 1))
else
  printf 'ok   ex-stale-layergate\n'; pass=$((pass + 1))
fi

echo "── 豁免机制 fix round 1（review 补漏）──────────"

# 29.（Minor）错档名注记盖在键对的发现上：一次钉两个 mutation。
#     note = (INVENTED, #d2a8ff)：档名 INVENTED 是从 #6a4f1a 那条真实发现
#     借来的「对档不对键」，键 #d2a8ff 是从 UNCARRIED 那条真实发现借来的
#     「对键不对档」。正确实现：(tier, key) 必须同时精确匹配，这条注记两头
#     都够不着，UNCARRIED #d2a8ff 与 INVENTED #6a4f1a 都照报，注记自己变成
#     STALE-NOTE。
#       - 若匹配退化成「只看键，不看档」（drop-tier-from-match）：注记的键
#         #d2a8ff 会碰上 UNCARRIED #d2a8ff，把它错销掉。
#       - 若匹配退化成「只看档，不看键」（drop-key-from-match）：注记的档名
#         INVENTED 会碰上 INVENTED #6a4f1a，把它错销掉。
#     两种退化各自只错销一条、放过另一条，且注记本身都不再是 stale——跟正确
#     实现「两条都在、注记本身 stale」三向都对不上，一条 fixture 堵两个洞。
mkmd wrong-tier-right-key <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 语法高亮

| 角色 | 色值 | 落点 |
|---|---|---|
| 函数名 | `#d2a8ff` | 定义或调用处 |

<!-- census-ok: INVENTED #d2a8ff 键对错了档，钉 drop-tier/drop-key 两个 mutation -->
EOF
mkjson wrong-tier-right-key <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "highlight": {"comment": "#6a4f1a"}}
EOF
check wrong-tier-right-key "UNCARRIED #d2a8ff" "INVENTED #6a4f1a" "STALE-NOTE #d2a8ff"

# 30.（Important 3，方向一）L1 档注记 + 无语料 → 照样 STALE-NOTE。
#     钉住「按层设门写成全局门」这个 mutation：把
#     `if tier in L2_TIERS and not l2_active: continue` 错写成
#     `if not l2_active: continue`，无语料时会把这条本不该被门槛拦住的 L1
#     注记也放过，不报 stale。之前的 case 26/27/28 全部走 --article（l2_active
#     恒真），这条 mutation 在那三条上完全隐形——INVENTED 不在 L2_TIERS 里，
#     `not l2_active` 恒假，跟正确实现的判断结果毫无差别。补一条无语料、纯 L1
#     的孤儿注记才踩得到这条分支。
mkmd ex-stale-l1-nocorpus <<'EOF'
# fixture

<!-- census-ok: INVENTED #aabbcc 这个色不存在，钉住「无语料时 L1 注记也该判 stale」 -->

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
EOF
mkjson ex-stale-l1-nocorpus <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222"}
EOF
check ex-stale-l1-nocorpus "STALE-NOTE #aabbcc"

# 31.（Important 3，方向二）L2 档注记 + 有语料 → 照样 STALE-NOTE。
#     钉住「L2 档注记恒不判 stale」这个 mutation：把
#     `if tier in L2_TIERS and not l2_active: continue` 错写成
#     `if tier in L2_TIERS: continue`，把 l2_active 这个条件整个丢掉，L2 档
#     注记不管有没有语料都不判 stale。case 28（ex-stale-layergate）是无语料
#     场景，这个 mutation 底下它本该「不判 stale」，跟正确实现的结果长得
#     一模一样，完全测不出来——这正是复审报告里「gate ignores l2_active →
#     L2 notes never stale」那行标 ❌ green 的原因。补一条**有语料**、销不到
#     任何发现的 L2 档孤儿注记（tier=NEAR-ZERO，键 #aabbcc 根本没在 .md 里
#     声明过，check_l2 不可能产出这个键），才能把这条分支的两个条件都跑到。
mkmd ex-stale-l2-corpus <<'EOF'
# fixture

<!-- census-ok: NEAR-ZERO #aabbcc 这个色根本没声明过，钉住「有语料时 L2 注记也该判 stale」 -->

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
- strong：`color: #222222`
EOF
mkjson ex-stale-l2-corpus <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #222222"}
EOF
checkl2 ex-stale-l2-corpus "STALE-NOTE #aabbcc"

# 32.（Important 2，第一问）--counts 从来没有自动化断言过——之前只有 Step 5
#     的人工跑一遍核对。钉住「文字列写死成 0」这类 mutation：随便改
#     print_counts 里 tx 的算法（甚至直接写死 0），40 条既有变异测试一条都不会
#     动，因为它们全部走 census 主流程，没有一条调用过 --counts。用 ART 里
#     已知恒定的「strong 6 处」造一个干净配色：#0071e3 只挂在 strong 上，
#     6 次全部是 `color:` 属性（text 桶），断言这一行的 总/文字/面/线。
mkmd counts-basic <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 强调：`#0071e3`

## 正文与强调

- 段落：`color: #222222`
- strong：`color: #0071e3`
EOF
mkjson counts-basic <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #0071e3"}
EOF
checkcounts counts-basic "#0071e3" "6 6 0 0"

# 33.（Important 2，第二问）--counts 的「文字」列必须跟 check_l2.text_count
#     用同一份计算，不能各自维护一套。这条 fixture 跟 l2-decor（case 19）
#     同型但换了名字（避免复用同一个 $WORK 子目录）：#cc3366 标为主强调，却
#     只落在 h3/list_item 的 border-left 上（line 桶），check_l2 靠
#     `text_count(color) == 0` 判出 DECOR。--counts 报的「文字」必须也是 0，
#     跟 DECOR 判据用的同一个数字——这就是 census-themes.py 里 bucket_sum()
#     这个共享函数存在的理由（Important 1 的重构）。mutation 证据见报告：
#     单独改 bucket_sum 的 "text" 分支，DECOR 判定和这一行会一起错。
mkmd counts-decor <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 主强调：`#cc3366`

## 正文与强调

- 段落：`color: #222222`
- h3：`border-left: 3px solid #cc3366`
EOF
mkjson counts-decor <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #222222",
 "h3": "color: #222222; border-left: 3px solid #cc3366",
 "list_item": "color: #222222; border-left: 2px solid #cc3366"}
EOF
checkl2 counts-decor "DECOR #cc3366"
checkcounts counts-decor "#cc3366" "6 0 0 6"

echo "── 终审补漏：豁免注记写残了要大声 FAIL，不许静默 ──────────"

# 34. 缺键——`<!-- census-ok: INVENTED -->` 连键都没写。exemptions() 的严格正则
#     解析不出三元组，第一版会把它当成「压根没写注记」悄悄丢掉：真实 INVENTED
#     照报，但不 FAIL、也不报 STALE-NOTE——用户会以为自己写了一条有效注记。
#     钉住「malformed_exemptions 整个没接上」这个 mutation。
mkmd ex-keyless <<'EOF'
# fixture

<!-- census-ok: INVENTED -->

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
- strong：`color: #222222`
EOF
mkjson ex-keyless <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #222222", "highlight": {"comment": "#6a4f1a"}}
EOF
out="$(python3 "$CENSUS" --fixture-dir "$WORK/ex-keyless" --article "$ART" 2>&1)"
if [[ "$out" == *"写残了"* ]]; then
  printf 'ok   ex-keyless\n'; pass=$((pass + 1))
else
  printf 'FAIL ex-keyless\n     期望: 报「写残了」\n     实得: %s\n' "$out"; fail=$((fail + 1))
fi

# 35. 理由留空——`<!-- census-ok: INVENTED #6a4f1a -->` 有档名有键，唯独没理由。
#     旧正则的 (.*?) 允许空匹配，这条会被当成合法注记，成功把一条 ERROR 销掉、
#     不留任何解释。钉住「strict 正则退回旧的 (.*?)（允许空理由）」这个 mutation：
#     退回后这条注记又能解析成功，INVENTED #6a4f1a 被悄悄销掉，不再 FAIL。
mkmd ex-emptyreason <<'EOF'
# fixture

<!-- census-ok: INVENTED #6a4f1a -->

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
- strong：`color: #222222`
EOF
mkjson ex-emptyreason <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #222222", "highlight": {"comment": "#6a4f1a"}}
EOF
out="$(python3 "$CENSUS" --fixture-dir "$WORK/ex-emptyreason" --article "$ART" 2>&1)"
if [[ "$out" == *"写残了"* ]]; then
  printf 'ok   ex-emptyreason\n'; pass=$((pass + 1))
else
  printf 'FAIL ex-emptyreason\n     期望: 报「写残了」\n     实得: %s\n' "$out"; fail=$((fail + 1))
fi

# 36. 前缀写错——`<!-- audit-ok: INVENTED #6a4f1a 理由 -->` 是另一套注记完整合法
#     的语法（audit-themes.py:86-89 自己的正则），不是「census-ok 写残了」。
#     census 这边该做的是**完全不理它**：不 FAIL（它没在跟这个检查器说话），
#     也不能被它销掉 INVENTED #6a4f1a（两套前缀不能互穿——Task 6 的设计前提）。
#     钉住「malformed 检测不按字面前缀过滤、把所有 `-ok:` 注释都当 census 的事」
#     这个 mutation：那样这条合法的 audit-ok 注记会被错判成「census-ok 写残了」
#     而 FAIL，这条断言用 checkl2 的精确匹配堵死这个方向。
mkmd ex-wrongprefix <<'EOF'
# fixture

<!-- audit-ok: INVENTED #6a4f1a 这条是 audit-themes.py 的注记，不关 census 的事 -->

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
- strong：`color: #222222`
EOF
mkjson ex-wrongprefix <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #222222", "highlight": {"comment": "#6a4f1a"}}
EOF
checkl2 ex-wrongprefix "INVENTED #6a4f1a"

# 37. STALE-NOTE 本身不是合法的注记档名——它是 apply_exemptions 算出来的产物，
#     从不出现在 rows 里，一条 `census-ok: STALE-NOTE ...` 注记永远销不到任何
#     发现，只可能是打错档名。钉住「LEGAL_NOTE_TIERS 退回 SEVERITY（含
#     STALE-NOTE）」这个 mutation：退回后这条注记会被当成合法档名接受，不 FAIL，
#     而是安安静静变成它自己的一条 STALE-NOTE 输出行，跟「档名打错了该大声拒绝」
#     的设计意图对不上。
mkmd ex-stalenote-tier <<'EOF'
# fixture

<!-- census-ok: STALE-NOTE #aabbcc 档名打错了，STALE-NOTE 不该是合法档名 -->

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
- strong：`color: #222222`
EOF
mkjson ex-stalenote-tier <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #222222"}
EOF
out="$(python3 "$CENSUS" --fixture-dir "$WORK/ex-stalenote-tier" --article "$ART" 2>&1)"
if [[ "$out" == *"档名不认识"* ]]; then
  printf 'ok   ex-stalenote-tier\n'; pass=$((pass + 1))
else
  printf 'FAIL ex-stalenote-tier\n     期望: 报「档名不认识」\n     实得: %s\n' "$out"; fail=$((fail + 1))
fi

echo "── 终审补漏：silenced 计数 + report() 退出码的灭口面 ──────────"

# 38. report() 打印「N 条已由注记豁免」——ex-silenced（用例 25）只销掉了 1 条
#     INVENTED，NEAR-ZERO #ffffff 不在注记射程内、照报。断言这个数字真的算对了，
#     不是写死的常量。钉住「silenced 永远打印 0」或「silenced 算成总发现数」
#     这类 mutation。
out="$(python3 "$CENSUS" --fixture-dir "$WORK/ex-silenced" --article "$ART" 2>&1)"
if [[ "$out" == *$'\n''1 条已由注记豁免'* ]]; then
  printf 'ok   ex-silenced-count\n'; pass=$((pass + 1))
else
  printf 'FAIL ex-silenced-count\n     期望: 含「1 条已由注记豁免」\n     实得: %s\n' "$out"; fail=$((fail + 1))
fi

# 39. report() 的退出码路径此前完全没被观测过：有语料时其它用例全部只看 stdout
#     （awk 挑行比对），从没人检查过进程退出码；唯一检查退出码的 l2-nocorpus-
#     fails-loud（用例 24）走的是无语料分支，`report(found=[]) → 0` 和
#     `report(found=[]) → 1` 在那条路径上因为 `or (0 if has_corpus else 1)` 的
#     兜底，结果都一样是非 0，分不出 report() 自己是不是错的。这条换成**有语料
#     + 真的有发现**（l2-zero，产出 ZERO/NEAR-ZERO），此时退出码完全由
#     `report()` 的 `return 1 if found else 0` 决定，才真正钉住「report() 恒
#     return 0」这个 mutation。
echo -n "ok   census-exit-nonzero-when-found ... "
if python3 "$CENSUS" --fixture-dir "$WORK/l2-zero" --article "$ART" >/dev/null 2>&1; then
  printf 'FAIL census-exit-nonzero-when-found\n     期望: 有发现且有语料时退出码非 0\n     实得: 0\n'
  fail=$((fail + 1))
else
  printf '\rok   census-exit-nonzero-when-found                              \n'
  pass=$((pass + 1))
fi

echo "── 终审补漏：调色板大写 hex 不该凭空报 ZERO ──────────"

# 40. 主题 .md 把强调色写成大写 `#CC3366`，theme.json 落地用小写 `#cc3366`——
#     产物里这个色真实落了 6 次（strong，ART 固定 6 处），但 check_l2 若不把
#     pal 的键小写化，`land.get("#CC3366")` 永远查不到 landings() 里那个恒为
#     小写的键，会凭空报一条 ZERO。钉住「lowercase 只做在 palette() 内部（或
#     干脆不做）」这类 mutation：真正要求的是在 check_l2/print_counts 这两个
#     调用点做，不是在 palette() 共享原语里做（会改到 audit-themes.py 的输入）。
mkmd l2-uppercase-hex <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 强调：`#CC3366`

## 正文与强调

- 段落：`color: #222222`
- strong：`color: #cc3366`
EOF
mkjson l2-uppercase-hex <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #cc3366"}
EOF
checkl2 l2-uppercase-hex
# print_counts 也在调用点小写化，输出行本身就是 #cc3366，不是 .md 里写的 #CC3366——
# 断言用小写去配，真正钉住的是「查得到落点」这件事，不是大小写透传。
checkcounts l2-uppercase-hex "#cc3366" "6 6 0 0"

echo "── 判据收窄：container 锚点上的 NEAR-ZERO 不报 ──────────"

# 背景：NEAR-ZERO 第一版对真实库报了 19 条，其中 18 条是同一个形态——那个色在
# theme.json 里**只挂在 `container`**（`27-retro-phosphor` 是 `container` +
# `footer_html`）。容器底色在产物里只出现 1 次，但它**铺满整页**，1 次等于全覆盖，
# 这不是「几乎没出现」。lessons 规则 7 正面适用：一个检查项报了大半个库，是判据
# 下宽了。
#
# **判据锚在 `container` 上，不是锚在「build() 只发一次」上。**
# 这个区别是实打实的，第一版就栽在这里：`md2html.py:426-434` 里 `footer` 与
# `footer_html` 由同一个 `if` 守着、同属文末那一个 `<p>`，**次数**和 `container`
# 一样固定 ≤1。若按「只发一次」推导，三个键平级，判据就会把「唯一强调色只落在
# 落款上」也一起灭口——而那恰恰是 apple-air 立项缺陷的形状：落款段落只是页面上
# 一个小色块，落 1 次就是真的几乎没有。**区分性质是面积/角色，不是次数。**
# 所以判定必须是：
#
#     "container" in mounts and mounts <= {"container", "footer", "footer_html"}
#
# `container` 是**必要条件**（这个色是页底，正当性由它提供）；`footer`/`footer_html`
# 只是允许一起出现的额外一次性挂载点，不单独构成豁免理由（retro-phosphor 就是把
# 容器底色 `#0d120d` 又用在了文末终端行上）。
#
# 五条硬约束（lessons「判据可以下窄」一节）逐条落在下面的用例上：
#   1. 只作用于 NEAR-ZERO，ZERO 一律不动          → case 45（但见该条注释：
#      这条约束现在由 container 锚点结构性地保证，不是靠门放在哪）
#   2. 判定依据是 theme.json 里的**挂载键**       → case 41 / 42
#   3. 不是调色板标签（candy-pop 标签正是「浅蓝底」）→ case 43
#   4. 不得用 REF_EXCLUDE 这类词表                → case 43 同时覆盖（标签整个不参与判定）
#   5. candy-pop 那条挂在 em 上的必须继续报        → case 43
# 外加三条：
#   6. 挂载键集合要整体判，不是「沾一个就算」      → case 44
#   7. 没有 container 锚点就不豁免（含只挂 footer_html 的） → case 46
#   8. 允许集合不许被随手扩大（单键扩大也要挂）    → case 47 / 48

# 41.（收窄的主用例）色只挂在 container 上 → 落点恒 1 → 不该报 NEAR-ZERO。
#     钉住「压根没加这道门」：没有门时这条必报 NEAR-ZERO #faf9f5。
#     形态照 01-autumn-warm / 25-washi-spring 那 17 个主题抄——调色板一行纸白底，
#     theme.json 里除 container 外没有第二个键复用它。
mkmd l2-nearzero-structural <<'EOF'
# fixture

## 色彩系统

- 纸白底：`#faf9f5`（主容器，铺满整页）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
- strong：`color: #222222`
EOF
mkjson l2-nearzero-structural <<'EOF'
{"container": "background-color: #faf9f5", "p": "color: #222222",
 "strong": "color: #222222"}
EOF
checkl2 l2-nearzero-structural

# 42.（retro-phosphor 形态）容器底色又被文末终端行复用 → 挂 container + footer_html
#     → 落点 2 → 仍不该报（container 锚点在，footer_html 在允许集合内）。
#     钉住「允许集合只写了 container、漏了 footer_html」这个 mutation：漏写时
#     这条会报 NEAR-ZERO #0d120d，而真实库里 27-retro-phosphor 正是这一条。
mkmd l2-nearzero-structural-footer <<'EOF'
# fixture

## 色彩系统

- 终端底：`#0d120d`（主容器 / 文末终端行）
- 荧光绿：`#33ff66`

## 正文与强调

- 段落：`color: #33ff66`
- strong：`color: #33ff66`
EOF
mkjson l2-nearzero-structural-footer <<'EOF'
{"container": "background-color: #0d120d", "p": "color: #33ff66",
 "strong": "color: #33ff66",
 "footer": "text-align: center",
 "footer_html": "<span style=\"background-color: #0d120d; color: #33ff66; letter-spacing: 0;\">$ EOF</span>"}
EOF
checkl2 l2-nearzero-structural-footer

# 43.（必须继续报，钉死「按标签判」这条歧路）candy-pop 的真实形态：调色板标签
#     写着「浅蓝底」——含「底」——但这个色在 theme.json 里**只挂在 `em`** 上，
#     ART 里 em 恰好 1 处，落点 1。规则 1：中文公众号文章里 em 可能整篇为零，
#     这是死色，必须继续报。
#     钉住两个错误实现：
#       - 「标签里有『底 / 背景』就豁免」→ 「浅蓝底」命中，这条被灭口；
#       - 「用 REF_EXCLUDE 词表豁免」→ 该表含「底」「背景」，同样灭口
#         （lessons 记的那次险些灭掉 aurora-flow 立身缺陷的方案）。
#     正确实现完全不看标签，只看挂载键 {em} ⊄ {container, footer_html}。
mkmd l2-nearzero-em-labeled-bg <<'EOF'
# fixture

## 色彩系统

- 奶油底：`#fdf6f0`（主容器）
- 深樱粉：`#d96687`
- 浅蓝底：`#e8f2f9`（em 的底）

## 正文与强调

- 段落：`color: #d96687`
- em：`background-color: #e8f2f9`
EOF
mkjson l2-nearzero-em-labeled-bg <<'EOF'
{"container": "background-color: #fdf6f0", "p": "color: #d96687",
 "strong": "color: #d96687",
 "em": "background-color: #e8f2f9"}
EOF
checkl2 l2-nearzero-em-labeled-bg "NEAR-ZERO #e8f2f9"

# 44.（挂载键集合要整体判，不是「沾一个就算」）色挂在 container + td_alt 上：
#     td_alt 是会随文章重复的键（斑马纹每隔一行一次），只是 ART 里没有表格，
#     这一轮落点为 0，总数因此是 1。挂载键集合 {container, td_alt} 不是结构键
#     集合的子集 → 仍按真实计数判 → 报 NEAR-ZERO。
#     钉住「只要挂载键里**有一个**是结构键就豁免」（`any(...)` 而不是 `<=`）
#     这个错误实现：那样这条会被灭口，而它恰恰是「换一篇带表格的文章结论就变」
#     的那种色，不该沉默。
mkmd l2-nearzero-structural-plus <<'EOF'
# fixture

## 色彩系统

- 雾灰底：`#eeecea`（主容器，表格斑马纹复用同一支底）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
- 斑马纹：`background-color: #eeecea`
EOF
mkjson l2-nearzero-structural-plus <<'EOF'
{"container": "background-color: #eeecea", "p": "color: #222222",
 "strong": "color: #222222",
 "td_alt": "background-color: #eeecea"}
EOF
checkl2 l2-nearzero-structural-plus "NEAR-ZERO #eeecea"

# 45.（ZERO 一律不动）色只挂在 `footer_html` 上、产物落点 0 → 必须报 ZERO，
#     不许被这道门捎带灭口。它钉的是**锚点的 ZERO 侧行为**。
#
#     ⚠️ **它不再钉「门放在 `total == 0` 之前还是之后」**——第一版（无锚点）
#     那个说法在锚点版下已经不成立：`container` 的样式串必然渲染进最外层
#     `<div>`，带锚点的色落点恒 ≥1、永远到不了 `total == 0` 分支，所以门放哪儿
#     行为完全一样。实测上移到循环开头：62 条全绿、真实库输出逐字节不变。
#     **没有用例能证死那个改法，这里就不假装钉住了它。**
#
#     ⚠️ 这条 fixture 的形态是**刻意造的**，不是抄真实库：要让一个色 0 落点又只挂
#     在 `footer_html` 上，只能把色值放在 landings() 读不到的位置（这里是
#     `footer_html` 里的一条说明注释——`theme_lib.landings` 只读 `style="..."`
#     属性）。不承担形态保真。
mkmd l2-zero-structural-key <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 朱砂印：`#b5432a`（文末印章）

## 正文与强调

- 段落：`color: #222222`
- 落款：`color: #b5432a`
EOF
mkjson l2-zero-structural-key <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #222222",
 "footer": "text-align: center",
 "footer_html": "<!-- 印色 #b5432a --><span style=\"letter-spacing: 0;\">完</span>"}
EOF
checkl2 l2-zero-structural-key "ZERO #b5432a"

# 46.（container 锚点是必要条件）唯一强调色只挂在 `footer_html` 上、落点 1
#     → 必须报 NEAR-ZERO。**这就是 apple-air 立项缺陷的形状**：一个本该显眼的
#     强调色，整篇只在文末落款那个小色块上出现一次。
#     钉住「判据锚在『build() 只发一次』而不是锚在 container 上」这个错误实现：
#     第一版正是这么写的（允许集合 = {container, footer_html}，不要求 container
#     在场），于是 `{footer_html} ⊆ 允许集合` 成立，这条被静默。
#     它与 case 18（l2-nearzero，色挂 footer + footer_html）的差别**只是颜色写在
#     文末那两个键中的哪一个**——那是个任意的区分，两条必须同判。真实库当前没有
#     主题这么挂（26 个全查过），这一档存在的意义正是替将来的主题守着。
mkmd l2-nearzero-footer-html-only <<'EOF'
# fixture

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 唯一强调色：`#0071e3`

## 正文与强调

- 段落：`color: #222222`
- 落款：`color: #0071e3`
EOF
mkjson l2-nearzero-footer-html-only <<'EOF'
{"container": "background-color: #ffffff", "p": "color: #222222",
 "strong": "color: #222222",
 "footer": "text-align: center",
 "footer_html": "<span style=\"color: #0071e3; letter-spacing: 0;\">完</span>"}
EOF
checkl2 l2-nearzero-footer-html-only "NEAR-ZERO #0071e3"

# 47 / 48.（允许集合不许被随手扩大）容器底色**额外只挂一个**内容相关的键，
#     而这一轮语料里那个键落点为 0，总数仍是 1 → 挂载键集合越出允许集合 →
#     必须按真实计数判 → 报 NEAR-ZERO。
#
#     ⚠️ **每条 fixture 只能多挂一个键**，这是本节自己踩出来的：第一版把 `hr` 与
#     `list_prefix_ol_html` 写进同一份 theme.json，结果**只加其中一个**到允许集合
#     时另一个仍在集合外，子集判定照样为假，用例根本不红——「覆盖到不等于钉住」的
#     又一个实例（实测：加 `hr` 0 挂、加 `list_prefix_ol_html` 0 挂）。拆成两条后
#     单键扩大才真的被证死。
#
#     真正危险的是**这一类**键：在某篇文章里可以落 0 次的（`hr`、
#     `list_prefix_ol_html`、`td_alt`、`blockquote`、`pre`、`table`）——它们能让总数
#     落进 ≤2 却完全依赖内容。case 47 钉 `hr`、case 48 钉 `list_prefix_ol_html`、
#     case 44 钉 `td_alt`。`h2_prefix_html` 那类随标题数增长的键风险低得多
#     （有 h2 就至少 1 次），**这里不假装钉住了它**。

# 47. 容器底色额外挂 `hr`（本轮语料没有 `---`，落点 0）。
mkmd l2-nearzero-allowset-hr <<'EOF'
# fixture

## 色彩系统

- 雾灰底：`#e9e6e2`（主容器，分隔线复用同一支）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
- 分隔线：`border-top: 1px solid #e9e6e2`
EOF
mkjson l2-nearzero-allowset-hr <<'EOF'
{"container": "background-color: #e9e6e2", "p": "color: #222222",
 "strong": "color: #222222",
 "hr": "border-top: 1px solid #e9e6e2; margin: 0 0 24px"}
EOF
checkl2 l2-nearzero-allowset-hr "NEAR-ZERO #e9e6e2"

# 48. 容器底色额外挂 `list_prefix_ol_html`（本轮语料没有有序列表，落点 0）。
mkmd l2-nearzero-allowset-ol <<'EOF'
# fixture

## 色彩系统

- 雾灰底：`#e9e6e2`（主容器，有序列表序号底也复用同一支）
- 主文字：`#222222`

## 正文与强调

- 段落：`color: #222222`
- 序号：`background-color: #e9e6e2`
EOF
mkjson l2-nearzero-allowset-ol <<'EOF'
{"container": "background-color: #e9e6e2", "p": "color: #222222",
 "strong": "color: #222222",
 "list_prefix_ol_html": "<span style=\"background-color: #e9e6e2;\">{n}.</span>&nbsp;&nbsp;"}
EOF
checkl2 l2-nearzero-allowset-ol "NEAR-ZERO #e9e6e2"

printf '\n%d 通过，%d 失败\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
