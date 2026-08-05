#!/usr/bin/env bash
#
# md2html.py 的测试。两部分，性质不同，缺一不可：
#
#     bash skills/md2publish-article/scripts/test-md2html.sh
#
# PART A 字段行为用例：自足的小 fixture（一段 md + 一份最小 theme.json），断言渲染出的
#   HTML 含什么、不含什么。**加渲染字段前先在这里写一条会红的用例**——脚本改完再补的
#   用例一上来就是绿的，证明不了它抓得住任何东西。
#
# PART B 逐字节回归：27 份真实主题的 theme.json 重新生成，必须与已定稿的 HTML 一模一样。
#   这一部分守的是「改 A 字段别碰坏 B 主题」。第三轮全库跑完时这个核对是手工做的
#   （20 份逐份 diff），固化下来才有护栏意义。
#
#   语料在仓库外（实验目录，2.7MB 生成物不进仓库），路径可用 MD2HTML_CORPUS 覆盖。
#   **语料缺失时本部分整体 SKIP 并把退出码标红**——静默跳过等于没有护栏，而「护栏在
#   但没跑」比「没有护栏」更危险，因为它会让人以为验过了。
#
# 注意 PART B 的基线语义：theme.json 没动时，产物必须逐字节不变。**故意改了某份
# theme.json 之后，要先重新生成它的 HTML 再跑本测试**，否则这里报的红是预期内的改动，
# 不是回归。别反过来去改测试迁就它。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MD2HTML="$SCRIPT_DIR/md2html.py"
CORPUS="${MD2HTML_CORPUS:-$HOME/code/skills/writing/wechat_test/litellm-multi-provider-gateway}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0

ok()   { printf 'ok   %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf 'FAIL %s\n'   "$1"; fail=$((fail + 1)); }

# ---------------------------------------------------------------- PART A 的脚手架

# fixture <用例名>：从 stdin 读文章 markdown
fixture() { cat > "$WORK/$1.md"; }

# theme <用例名>：从 stdin 读 theme.json
theme() { cat > "$WORK/$1.theme.json"; }

# render <用例名>：跑脚本，渲染失败直接算这条用例红（别让它静默产出空文件）
render() {
  if ! python3 "$MD2HTML" "$WORK/$1.md" "$WORK/$1.theme.json" -o "$WORK/$1.html" >"$WORK/$1.log" 2>&1; then
    printf 'FAIL %s（渲染就失败了）\n' "$1"
    sed 's/^/     /' "$WORK/$1.log"
    fail=$((fail + 1))
    return 1
  fi
}

# has <用例名> <说明> <子串>：断言产物里有这个子串
has() {
  if grep -qF -- "$3" "$WORK/$1.html"; then
    ok "$1 — $2"
  else
    bad "$1 — $2"
    printf '     期望含: %s\n' "$3"
  fi
}

# lacks <用例名> <说明> <子串>：断言产物里没有这个子串（守误加）
lacks() {
  if grep -qF -- "$3" "$WORK/$1.html"; then
    bad "$1 — $2"
    printf '     不该含: %s\n' "$3"
  else
    ok "$1 — $2"
  fi
}

# 各用例共用的最小主题：只写到「能渲染」为止，被测字段单独往里加。
# 无卡片结构（card 为空），这样断言里不必绕开卡片包裹。
base_theme() {
  cat <<'EOF'
{
  "container": "background-color: #ffffff; padding: 36px 12px",
  "content_width": 800,
  "p": "font-size: 16px; color: #222222",
  "h2": "font-size: 20px; color: #222222",
  "h3": "font-size: 17px; color: #222222",
  "list_item": "font-size: 16px; color: #222222",
  "pre": "background-color: #f5f5f5",
  "code": "color: #222222",
  "strong": "color: #cc3366; font-weight: 700"
}
EOF
}

# ---------------------------------------------------------------- PART A 字段行为

printf '── PART A 字段行为 ─────────────────────────────\n'

# --- 脚手架自检：先证明 has/lacks 真的在看产物，否则下面的红绿都不可信 -----------
fixture scaffold <<'EOF'
# 标题

## 一章

正文一段。
EOF
theme scaffold < <(base_theme)
if render scaffold; then
  has   scaffold "h2 渲染出来了"        '<h2 style='
  has   scaffold "正文渲染出来了"        '正文一段'
  lacks scaffold "H1 不进正文"          '<h1'
fi

# --- h2_suffix_html：h2 文字后缀，与 h2_prefix_html 对称 ------------------------
# celadon-scroll / botanic-press / velvet-stage 三个主题都要「h2 文字两侧对称饰线」，
# 只有前缀字段时只能降级成单边。
fixture h2-suffix <<'EOF'
# 标题

## 一章

正文。
EOF
theme h2-suffix <<'EOF'
{
  "container": "background-color: #ffffff; padding: 36px 12px",
  "content_width": 800,
  "p": "font-size: 16px; color: #222222",
  "h2": "font-size: 20px; color: #222222",
  "h2_prefix_html": "<span style=\"color: #b08d57;\">◆&nbsp;</span>",
  "h2_suffix_html": "<span style=\"color: #b08d57;\">&nbsp;◆</span>"
}
EOF
if render h2-suffix; then
  has h2-suffix "后缀落在 h2 文字之后、h2 之内" \
    '一章<span style="color: #b08d57;">&nbsp;◆</span></h2>'
  has h2-suffix "前缀仍在文字之前"  '"><span style="color: #b08d57;">◆&nbsp;</span>一章'
fi

# 没配这个字段的主题不能凭空多出东西（守「加字段别改默认行为」，与 PART B 互补）
fixture h2-suffix-absent <<'EOF'
# 标题

## 一章

正文。
EOF
theme h2-suffix-absent < <(base_theme)
if render h2-suffix-absent; then
  has h2-suffix-absent "没配后缀时 h2 干净收尾" '一章</h2>'
fi

# --- list_prefix_ol_html：有序列表的序号前缀 ------------------------------------
# mint-breeze / botanic-press / blueprint-grid 三个主题要给序号单独上色或加形，但脚本
# 把有序项的前缀写死成纯文本 `N.&nbsp;&nbsp;`，`list_prefix_html` 只作用于无序项。
# 本轮测试文恰好 0 处有序列表，所以这个缺口没变成产物缺陷——换一篇文章就会。
fixture ol-prefix <<'EOF'
# 标题

## 一章

1. 第一条
2. 第二条

- 无序项
EOF
theme ol-prefix <<'EOF'
{
  "container": "background-color: #ffffff; padding: 36px 12px",
  "content_width": 800,
  "p": "font-size: 16px; color: #222222",
  "h2": "font-size: 20px; color: #222222",
  "list_item": "font-size: 16px; color: #222222",
  "list_prefix_html": "<span style=\"color: #4a9;\">▸</span>&nbsp;&nbsp;",
  "list_prefix_ol_html": "<span style=\"color: #b08d57; font-weight: 700;\">{n}</span>&nbsp;&nbsp;"
}
EOF
if render ol-prefix; then
  has ol-prefix "序号 1 走主题模板" \
    '<span style="color: #b08d57; font-weight: 700;">1</span>&nbsp;&nbsp;第一条'
  has ol-prefix "序号 2 用的是自己的号，不是写死的 1" \
    '<span style="color: #b08d57; font-weight: 700;">2</span>&nbsp;&nbsp;第二条'
  has ol-prefix "同一段落里无序项仍走无序前缀" \
    '<span style="color: #4a9;">▸</span>&nbsp;&nbsp;无序项'
  lacks ol-prefix "不再输出写死的纯文本序号" '1.&nbsp;&nbsp;第一条'
fi

# 没配这个字段时保持原样：纯文本 `N.` + 两个 &nbsp;（27 份定稿产物依赖这个默认值）
fixture ol-prefix-absent <<'EOF'
# 标题

## 一章

1. 第一条
EOF
theme ol-prefix-absent < <(base_theme)
if render ol-prefix-absent; then
  has ol-prefix-absent "没配时退回写死的纯文本序号" '1.&nbsp;&nbsp;第一条'
fi

# --- strong_alt：按关键词给 strong 分叉 -----------------------------------------
# cyber-neon 第 36 行规定「带『注意/警告/不要/会导致』语义的 strong 改用品红」，
# blueprint-grid 有同形规范。这条规范本来就是按关键词写的、机械可判，但脚本没有挂载点，
# 于是定稿产物里品红 36 处、落在 strong 上 0 处——**规范静默丢失，审计还报 0 条**。
fixture strong-alt <<'EOF'
# 标题

## 一章

**注意：这里会翻车**，另外 **普通强调** 不该变色。

**警告：`--config` 会覆盖默认值** 这种带行内 code 的也要认。
EOF
theme strong-alt <<'EOF'
{
  "container": "background-color: #ffffff; padding: 36px 12px",
  "content_width": 800,
  "p": "font-size: 16px; color: #222222",
  "h2": "font-size: 20px; color: #222222",
  "inline_code": "color: #39d0d8",
  "strong": "color: #39d0d8; font-weight: 600",
  "strong_alt": {"keywords": ["注意", "警告", "不要", "会导致"],
                 "style": "color: #ff4ba3; font-weight: 600"}
}
EOF
if render strong-alt; then
  has strong-alt "命中关键词的 strong 走 alt 样式" \
    '<strong style="color: #ff4ba3; font-weight: 600">注意：这里会翻车</strong>'
  has strong-alt "没命中的 strong 走常规样式" \
    '<strong style="color: #39d0d8; font-weight: 600">普通强调</strong>'
  has strong-alt "关键词判定看得见的文字，不被内嵌行内 code 干扰" \
    '<strong style="color: #ff4ba3; font-weight: 600">警告：'
fi

# 没配 strong_alt 的主题：所有 strong 一律常规样式（27 份定稿产物依赖这个）
fixture strong-alt-absent <<'EOF'
# 标题

## 一章

**注意：这里会翻车**
EOF
theme strong-alt-absent < <(base_theme)
if render strong-alt-absent; then
  has strong-alt-absent "没配 alt 时关键词不改变任何东西" \
    '<strong style="color: #cc3366; font-weight: 700">注意：这里会翻车</strong>'
fi

# --- footer 的 <p> 必须有显式 color ---------------------------------------------
# 铁律要求每个 <p> 有显式 color，脚本 docstring 也自称「从机制上保证」这一条——但
# footer 这条路径不保证：主题的 footer 样式串没写 color，产出的就是个裸 <p>，自检直接
# FAIL。用了该字段的主题 3/3 全 FAIL 过一轮，根因是字段示例本身就没写 color。
# 示例已改；这里再补一道机制兜底，让脚本兑现自己的承诺，而不是靠主题作者记性。
fixture footer-nocolor <<'EOF'
# 标题

## 一章

正文。
EOF
theme footer-nocolor <<'EOF'
{
  "container": "background-color: #ffffff; padding: 36px 12px",
  "content_width": 800,
  "p": "font-size: 16px; color: #222222",
  "h2": "font-size: 20px; color: #222222",
  "footer": "text-align: center; margin: 40px 0 0",
  "footer_html": "<span>終</span>"
}
EOF
if render footer-nocolor; then
  # 断言必须落在 footer 那一行上：`color: #222222` 在正文段落里也有，整篇 grep 是假绿
  if grep -F '<span>終</span>' "$WORK/footer-nocolor.html" | grep -q 'color: #222222'; then
    ok "footer-nocolor — footer 那个 <p> 兜底补上了正文色"
  else
    bad "footer-nocolor — footer 那个 <p> 兜底补上了正文色"
    printf '     实得: %s\n' "$(grep -F '<span>終</span>' "$WORK/footer-nocolor.html" | head -1)"
  fi
  # 直接拿自检脚本验，比断言子串更贴近真实验收口径
  if awk '/^python3 - <<.EOF.$/{f=1;next} /^EOF$/{f=0} f' \
       "$SCRIPT_DIR/../references/wechat-html.md" > "$WORK/selfcheck.py" 2>/dev/null &&
     python3 "$WORK/selfcheck.py" "$WORK/footer-nocolor.html" 2>&1 | grep -q '^PASS'; then
    ok "footer-nocolor — 过 wechat-html.md 自检"
  else
    bad "footer-nocolor — 过 wechat-html.md 自检"
    python3 "$WORK/selfcheck.py" "$WORK/footer-nocolor.html" 2>&1 | sed 's/^/     /' | head -5
  fi
fi

# 主题自己写了 color 就不许被兜底盖掉（5 个在用该字段的主题都自带 color）
fixture footer-withcolor <<'EOF'
# 标题

## 一章

正文。
EOF
theme footer-withcolor <<'EOF'
{
  "container": "background-color: #ffffff; padding: 36px 12px",
  "content_width": 800,
  "p": "font-size: 16px; color: #222222",
  "h2": "font-size: 20px; color: #222222",
  "footer": "text-align: center; color: #a63d2f; margin: 40px 0 0",
  "footer_html": "<span>終</span>"
}
EOF
if render footer-withcolor; then
  has footer-withcolor "主题自带的 footer 色保住了" 'color: #a63d2f'
fi

# --- p_first：全文第一段的导语处理，与 h2_first 同构 ----------------------------
# newsprint 规定「全文第一段做导语处理」，但脚本所有 p 一律走 `p` 字段，实测产物里
# 导语的 `border-left: 3px solid #9e2b25` **0 处**——规范静默丢失，和 apple-air 的
# eyebrow 同类。语义在这里定死，别留给下一个人猜：
#   · 「第一段」= 全文档第一个 p 块，不是每章第一个（主题文件写的是「全文」）
#   · 首块是列表/代码/引用打头时，算第一个真正的 p
#   · 与 h2_first 独立计数，互不影响
fixture p-first <<'EOF'
# 标题

## 一章

导语段落。

第二段。

## 二章

二章第一段不该再当导语。
EOF
theme p-first <<'EOF'
{
  "container": "background-color: #f5f1e6; padding: 36px 12px",
  "content_width": 800,
  "p": "font-size: 16px; color: #1f1d1a",
  "p_first": "font-size: 17px; color: #55514a; border-left: 3px solid #9e2b25; padding-left: 14px",
  "h2": "font-size: 22px; color: #1f1d1a"
}
EOF
if render p-first; then
  has   p-first "第一段走导语样式" 'border-left: 3px solid #9e2b25'
  has   p-first "导语就是第一段那一段" \
    'border-left: 3px solid #9e2b25; padding-left: 14px; text-align: left; max-width: 800px; margin-left: auto; margin-right: auto; box-sizing: border-box">导语段落。'
  # 全文只有一处导语：出现两次就说明按「每章第一段」实现了
  n_lede="$(grep -oF 'border-left: 3px solid #9e2b25' "$WORK/p-first.html" | wc -l | tr -d ' ')"
  if [ "$n_lede" = "1" ]; then
    ok "p-first — 全文只有 1 处导语（不是每章一处）"
  else
    bad "p-first — 全文只有 1 处导语（不是每章一处）"
    printf '     实得 %s 处\n' "$n_lede"
  fi
fi

# 首块不是 p（列表打头）时，导语落在第一个真正的 p 上
fixture p-first-after-list <<'EOF'
# 标题

## 一章

- 列表先出现

这才是第一段。
EOF
theme p-first-after-list <<'EOF'
{
  "container": "background-color: #f5f1e6; padding: 36px 12px",
  "content_width": 800,
  "p": "font-size: 16px; color: #1f1d1a",
  "p_first": "font-size: 17px; color: #55514a; border-left: 3px solid #9e2b25",
  "list_item": "font-size: 16px; color: #1f1d1a",
  "h2": "font-size: 22px; color: #1f1d1a"
}
EOF
if render p-first-after-list; then
  has   p-first-after-list "导语落在第一个真正的 p 上" \
    'border-left: 3px solid #9e2b25; text-align: left; max-width: 800px; margin-left: auto; margin-right: auto; box-sizing: border-box">这才是第一段。'
  lacks p-first-after-list "列表项不算段落，不吃导语样式" \
    '#9e2b25; text-align: left; padding-left: 1.5em'
fi

# 没配这个字段的主题：所有段落一律走 `p`（26 个主题都不配，PART B 也守这一条）
fixture p-first-absent <<'EOF'
# 标题

## 一章

第一段。
EOF
theme p-first-absent < <(base_theme)
if render p-first-absent; then
  has p-first-absent "没配时第一段走常规段落样式" 'font-size: 16px; color: #222222'
fi

# ---------------------------------------------------------------- PART B 逐字节回归

printf '\n── PART B 逐字节回归（27 份真实主题）──────────\n'

ARTICLE="$CORPUS/litellm-multi-provider-gateway.md"
OUTDIR="$CORPUS/out"
# theme.json 的权威副本在仓库里（references/theme-json/），语料目录那份只是历史产物。
# 用仓库这份重新生成，顺带就守住了「仓库副本与定稿产物失步」。
THEMEJSON="$SCRIPT_DIR/../references/theme-json"

# theme.json 名  →  定稿 HTML 名。**不是简单同名**：第一轮 6 个主题的定稿带 -v1/-v5
# 后缀，同名无后缀的那份是旧宽度结构、已作废。按文件名循环很容易撞上作废件，所以这里
# 把配对关系写死（每一组都实跑验证过）。
PAIRS="
01-autumn-warm:01-autumn-warm-v1
02-ocean-calm:02-ocean-calm-v5
03-spring-fresh:03-spring-fresh
04-ink-wash:04-ink-wash-v5
05-newsprint:05-newsprint
06-editor-slate:06-editor-slate-v5
07-coffee-journal:07-coffee-journal
08-morandi-fog:08-morandi-fog
09-gilded-ink:09-gilded-ink
10-lavender-dusk:10-lavender-dusk
11-bauhaus-pop:11-bauhaus-pop-v5
12-apple-air:12-apple-air
13-cyber-neon-v7-edge:13-cyber-neon-v7-edge
14-celadon-scroll:14-celadon-scroll
15-mint-breeze:15-mint-breeze
16-arena-charge:16-arena-charge
17-scarlet-tech:17-scarlet-tech
18-midnight-study:18-midnight-study
19-candy-pop:19-candy-pop
20-monochrome-mag:20-monochrome-mag-v5
21-aurora-flow:21-aurora-flow
22-blueprint-grid:22-blueprint-grid
23-terracotta-sun:23-terracotta-sun
24-botanic-press:24-botanic-press
25-washi-spring:25-washi-spring
26-velvet-stage:26-velvet-stage
27-retro-phosphor:27-retro-phosphor
"

if [ ! -f "$ARTICLE" ] || [ ! -d "$OUTDIR" ] || [ ! -d "$THEMEJSON" ]; then
  printf 'SKIP 逐字节回归：语料不在 %s\n' "$CORPUS"
  printf '     这不是通过。设 MD2HTML_CORPUS 指向实验目录再跑，否则改动没有回归护栏。\n'
  fail=$((fail + 1))
else
  n_same=0
  for pair in $PAIRS; do
    j="${pair%%:*}"; h="${pair##*:}"
    if [ ! -f "$THEMEJSON/$j.theme.json" ] || [ ! -f "$OUTDIR/$h.html" ]; then
      bad "回归 ${j}（语料缺文件）"
      continue
    fi
    python3 "$MD2HTML" "$ARTICLE" "$THEMEJSON/$j.theme.json" -o "$WORK/$j.repro.html" >/dev/null 2>&1
    if cmp -s "$WORK/$j.repro.html" "$OUTDIR/$h.html"; then
      n_same=$((n_same + 1))
    else
      bad "回归 $j → ${h}（产物变了）"
      printf '     %s\n' "$(cmp "$WORK/$j.repro.html" "$OUTDIR/$h.html" 2>&1 | head -1)"
    fi
  done
  n_total="$(printf '%s\n' "$PAIRS" | sed '/^$/d' | wc -l | tr -d ' ')"
  [ "$n_same" = "$n_total" ] && ok "逐字节回归 $n_same/$n_total 份主题产物不变"
fi

printf '\n%d 通过，%d 失败\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
