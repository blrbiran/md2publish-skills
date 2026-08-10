#!/usr/bin/env bash
#
# contrast-themes.py 的变异测试：对每一条「已知的错误实现」造一个能证死它的 fixture。
#
#     bash skills/md2publish-article/scripts/test-contrast-themes.sh
#
# 纪律同 test-census-themes.sh：一条用例如果在错误实现下也是绿的，它就没有价值。
# 每条用例在写下来之后都手工做过定点破坏验证（临时改 contrast_lib.py / contrast-themes.py
# 的真身，跑本文件，看着对应用例变红，再改回来）——证据记在 task-7-report.md，不在这里
# 重复代码化，跟 test-census-themes.sh / test-audit-themes.sh 的先例一致：那两个文件也不
# 在 .sh 里内嵌「自我变异」逻辑，只留下能钉死判据的 fixture。
#
# contrast-themes.py 没有 census-themes.py 那种 --fixture-dir 钩子：它按自己的脚本位置
# 找 test-md2html.sh（权威 PAIRS 表）、references/theme-json、references/contrast-baseline.tsv，
# 语料目录走 MD2HTML_CORPUS。要在不碰产物/仓库文件的前提下控制这些输入，只能给每条用例
# 造一整套隔离的项目骨架（scripts/ + references/theme-json/ + corpus/out/），把 contrast_lib.py
# 与 contrast-themes.py 的真身复制进去——复制不是修改，跟 task-7-brief 允许的
# 「Mutations happen on temporary COPIES」是同一件事。real-library 例外：那条测的是产物库
# 本身，必须用真身、真配对表、真基线，见该用例注释。
#
# 已知的一处偏离：brief 给出的 15 条用例表没有单独列「装饰匹配在字段无 style 时要回落到
# 字面文本」这一条，但外层任务说明把它列进了「至少要有」的错误实现清单。两处对不上，
# 按「宁可多测一条，不可漏测一条被明确点名的错误实现」的原则补了第 16 条
# `decor-no-style-fallback`，commit message 里如实写 16 条，不迁就 brief 的「15」。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_SRC="$SCRIPT_DIR/contrast_lib.py"
CLI_SRC="$SCRIPT_DIR/contrast-themes.py"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0

# ---------------------------------------------------------------- 脚手架

# newcase <名>：搭一套隔离项目骨架，复制真身脚本进去（不改真身，只搭骨架）。
newcase() {
  local p="$WORK/$1"
  mkdir -p "$p/scripts" "$p/references/theme-json" "$p/corpus/out"
  cp "$LIB_SRC" "$p/scripts/contrast_lib.py"
  cp "$CLI_SRC" "$p/scripts/contrast-themes.py"
}

# pairs <名> <j:h> [<j:h>...]：写 test-md2html.sh 里的 PAIRS 表——
# authoritative_pairs() 就是靠正则 `PAIRS="\n(.*?)\n"` 从这份文件里抠出来的，
# 这是它唯一认的权威配对源，不认目录里随便扫到的文件。
pairs() {
  local p="$WORK/$1"; shift
  {
    printf 'PAIRS="\n'
    printf '%s\n' "$@"
    printf '"\n'
  } > "$p/scripts/test-md2html.sh"
}

# case1 <名>：单主题单产物的常见骨架——j 和 h 同名。
case1() { newcase "$1"; pairs "$1" "$1:$1"; }

# themejson <名> <j>：从 stdin 写 j.theme.json
themejson() { cat > "$WORK/$1/references/theme-json/$2.theme.json"; }

# html <名> <h>：从 stdin 写产物 h.html
html() { cat > "$WORK/$1/corpus/out/$2.html"; }

# run <名> [参数...]：跑该项目自己的 CLI 副本，语料指到该项目自己的 corpus/
run() {
  local p="$WORK/$1"; shift
  ( cd "$p" && MD2HTML_CORPUS="$p/corpus" python3 scripts/contrast-themes.py "$@" )
}

# detail_of <名>：--detail 该主题（单主题项目里主题名与项目名相同）
detail_of() { run "$1" --detail "$1"; }

# expect_ratio <名> <期望比值>：--detail 恰好一条发现，且比值列等于期望值。
# 比值精确到字符串两位小数——渐变/alpha 类用例要证死的正是「比值算错了」，
# 光断言「有没有一条发现」抓不住这类错误（错误实现下往往一样会有一条发现，
# 只是比值不对）。取倒数第二列（NF-1）而不是写死第 8 列：比值/处数恒是每行
# 最后两列，键列数万一因为别的用例（比如 baseline-key-has-tag 要钉的 key_of
# 漏标签）而改变，这条也不受连带影响——只测「比值本身对不对」，不掺进「键有
# 几列」这件不相关的事。
expect_ratio() {
  local name="$1" expected="$2"
  local rows n ratio
  rows="$(detail_of "$name" | awk -F'\t' -v t="$name" '$1==t')"
  n="$(printf '%s\n' "$rows" | sed '/^$/d' | wc -l | tr -d ' ')"
  ratio="$(printf '%s\n' "$rows" | awk -F'\t' '{print $(NF-1)}')"
  if [ "$n" = "1" ] && [ "$ratio" = "$expected" ]; then
    printf 'ok   %s（比值 %s）\n' "$name" "$expected"; pass=$((pass + 1))
  else
    printf 'FAIL %s\n     期望: 1 条，比值 %s\n     实得: %s 条，比值 %s\n' \
      "$name" "$expected" "${n:-0}" "${ratio:-<空>}"
    fail=$((fail + 1))
  fi
}

# expect_count <名> <期望条数>：--detail 该主题的发现条数（不看比值，只看报不报）
expect_count() {
  local name="$1" expected="$2"
  local n
  n="$(detail_of "$name" | awk -F'\t' -v t="$name" '$1==t' | sed '/^$/d' | wc -l | tr -d ' ')"
  if [ "$n" = "$expected" ]; then
    printf 'ok   %s（%s 条）\n' "$name" "$expected"; pass=$((pass + 1))
  else
    printf 'FAIL %s\n     期望: %s 条\n     实得: %s 条\n' "$name" "$expected" "$n"
    fail=$((fail + 1))
  fi
}

echo "── 渐变采样：不许只取端点 ──────────────────────"

# 渐变端点法会漏判内部最小值：L(t) 对 t 是凸的，前景比整条渐变都暗时最小对比度落在
# 内部（t≈0.70）。fixture：linear-gradient(#ff0000, #0000ff) + 黑字。
# 正确实现 1.95；只取两端会算出 2.44（比正确值更「安全」，把真实缺陷藏起来）。
case1 grad-interior
themejson grad-interior grad-interior <<'EOF'
{}
EOF
html grad-interior grad-interior <<'EOF'
<div style="background-color: #ffffff"><div style="background-image: linear-gradient(#ff0000, #0000ff)"><p style="color: #000000; font-size: 15px">黑字</p></div></div>
EOF
expect_ratio grad-interior "1.95"

# 前景亮度夹在渐变两端之间：介值定理保证沿途必有一点与前景等亮，最差比值 = 1.0。
# 只取两端会算出 3.95（两端都比前景亮或都比前景暗时才会撞见这个陷阱）。
case1 grad-between
themejson grad-between grad-between <<'EOF'
{}
EOF
html grad-between grad-between <<'EOF'
<div style="background-color: #ffffff"><div style="background-image: linear-gradient(#000000, #ffffff)"><p style="color: #808080; font-size: 15px">灰字</p></div></div>
EOF
expect_ratio grad-between "1.00"

echo "── alpha 合成：半透明色带不许被当成不透明或被跳过 ──────"

# morandi-fog 形态：白卡上盖一条硬停（hard stop）渐变高光带，透明段到 rgba(...,0.35)。
# 正确实现要把 0.35 alpha 的色带压在白底上再算对比度（→ 2.51）。
# 忘了 alpha 合成的典型错法：只对 alpha=1 的层取样、alpha<1 的层整段被跳过不参与
# candidate 底集合——那样只剩下白底一个候选，算出 3.52，把真实存在的高光带对比度
# 缺陷完全藏起来。
case1 alpha-composite
themejson alpha-composite alpha-composite <<'EOF'
{}
EOF
html alpha-composite alpha-composite <<'EOF'
<div style="background-color: #ffffff"><div style="background-image: linear-gradient(transparent 62%, rgba(176, 142, 138, 0.35) 62%)"><span style="color: #8c8884; font-size: 15px">灰字</span></div></div>
EOF
expect_ratio alpha-composite "2.51"

echo "── 大文本阈值：边界含等号，写成 >18.66px 或 >18px 都要分别钉死 ──"

# 18.66px/700 按 WCAG 定义正是「大文本」的下边界（含等号）：阈值该降到 3.0。
# 若实现写成 `size > 18.66`（严格大于，漏了等号），18.66 会被误判成「不是大文本」，
# 阈值错留在 4.5，一条本该通过的发现被错误地报出来。
case1 large-text-1866
themejson large-text-1866 large-text-1866 <<'EOF'
{}
EOF
html large-text-1866 large-text-1866 <<'EOF'
<div style="background-color: #ffffff"><p style="color: #828282; font-size: 18.66px; font-weight: 700">大字</p></div>
EOF
expect_count large-text-1866 0

# 18.2px/700 没有过 18.66 这条大文本粗体线，阈值该是普通文字的 4.5，这条发现该报。
# 若实现写成 `size > 18`（数字抄错、门槛降到 18px），18.2 会被误判成「是大文本」，
# 阈值错降到 3.0，一条本该报出来的发现被吞掉——只放 18.66 那条抓不住这个 mutant：
# 18.66 在 `>18px` 判据下照样被判成大文本，那条 mutant 下 large-text-1866 依然是绿的。
case1 large-text-182
themejson large-text-182 large-text-182 <<'EOF'
{}
EOF
html large-text-182 large-text-182 <<'EOF'
<div style="background-color: #ffffff"><p style="color: #828282; font-size: 18.2px; font-weight: 700">大字</p></div>
EOF
expect_count large-text-182 1

echo "── 装饰判定：按注入来源认，不许按字符类猜 ────────────"

# theme.json 的 list_prefix_html 注入了一个带 style 的 ● 前缀。产物里同时放一个
# 代码块里的 |---|，同色同底同字号（都不达标）。字符类判据会把两者都当「符号，算
# 装饰」，于是全都通过 3.0 门槛、一条都不报——但 |---| 根本不是注入字段产生的，
# 它是正文里的普通文字，该按 4.5 判、该报。正确实现按注入来源判：● 的 style 串
# 与 list_prefix_html 的签名一致 → 装饰 → 通过；|---| 的 style 串不匹配任何注入
# 签名 → 文字 → 不通过 → 报。断言的是「恰好这一条该报」，钉死的正是这条区分力。
case1 decor-by-source
themejson decor-by-source decor-by-source <<'EOF'
{"container": "background-color: #efe0cd",
 "list_prefix_html": "<span style=\"color: #c2593b;\">●</span>&nbsp;&nbsp;"}
EOF
html decor-by-source decor-by-source <<'EOF'
<div style="background-color: #efe0cd">
<p style="color: #222222; font-size: 15px">列表项<span style="color: #c2593b;">●</span>标记</p>
<pre><code style="color: #c2593b; font-size: 15px">|---|</code></pre>
</div>
EOF
out="$(detail_of decor-by-source)"
rows="$(printf '%s\n' "$out" | awk -F'\t' -v t=decor-by-source '$1==t')"
n="$(printf '%s\n' "$rows" | sed '/^$/d' | wc -l | tr -d ' ')"
tag="$(printf '%s\n' "$rows" | awk -F'\t' '{print $2}')"
kind="$(printf '%s\n' "$rows" | awk -F'\t' '{print $(NF-2)}')"
if [ "$n" = "1" ] && [ "$tag" = "code" ] && [ "$kind" = "文字" ]; then
  printf 'ok   decor-by-source（●不报，|---| 按文字报）\n'; pass=$((pass + 1))
else
  printf 'FAIL decor-by-source\n     期望: 1 条，tag=code，kind=文字\n     实得: %s 条，tag=%s，kind=%s\n' \
    "$n" "${tag:-<空>}" "${kind:-<空>}"
  fail=$((fail + 1))
fi

# 装饰匹配的另一半：没有 style 的注入字段（list_prefix_ol_html 这类纯文本模板）
# 必须回落到字面文本比对，不能因为「没有 style 可比」就判定不是装饰。
# fixture：list_prefix_ol_html 不带 style，产物里 "1." 前缀单独一个 span、只有
# color、没有其它 style——若判定只认 style、不做文字回落，"1." 会被误判成文字，
# 按 4.5 门槛报出来；正确实现认出它是 {n}. 模板生成的装饰，按 3.0 门槛通过。
# 这条不在 task-7-brief 给出的 15 条表里，是外层任务说明里点名要求的第 16 条，
# 见文件头注释。
case1 decor-no-style-fallback
themejson decor-no-style-fallback decor-no-style-fallback <<'EOF'
{"container": "background-color: #ffffff", "list_prefix_ol_html": "{n}."}
EOF
html decor-no-style-fallback decor-no-style-fallback <<'EOF'
<div style="background-color: #ffffff">
<p style="font-size: 15px"><span style="color: #828282">1.</span>&nbsp;&nbsp;<span style="color: #222222">第一条</span></p>
</div>
EOF
expect_count decor-no-style-fallback 0

echo "── 同色块跳过：只许对装饰生效，不许放宽到正文 ──────────"

# bauhaus-pop 形态：h2_prefix_html 注入的 ■ 前缀自己声明了背景色，前景与自己的底
# 同色——这是装饰节点故意用「同色块」画出一个纯色方块图形，不是缺陷，该跳过不报。
case1 samecolor-decor-skipped
themejson samecolor-decor-skipped samecolor-decor-skipped <<'EOF'
{"container": "background-color: #ffffff",
 "h2_prefix_html": "<span style=\"background-color: #f0a500; color: #f0a500;\">■</span>"}
EOF
html samecolor-decor-skipped samecolor-decor-skipped <<'EOF'
<div style="background-color: #ffffff"><h2 style="font-size: 18px"><span style="background-color: #f0a500; color: #f0a500;">■</span>标题</h2></div>
EOF
expect_count samecolor-decor-skipped 0

# 同色块规则若被放宽到非装饰节点，会把「正文色刚好等于卡片底色」这种真缺陷也一并
# 跳过——那是读者真的看不见字，不是画图形，必须照报。
case1 samecolor-prose-still-fires
themejson samecolor-prose-still-fires samecolor-prose-still-fires <<'EOF'
{"container": "background-color: #ffffff"}
EOF
html samecolor-prose-still-fires samecolor-prose-still-fires <<'EOF'
<div style="background-color: #ffffff"><p style="background-color: #eeeeee; color: #eeeeee; font-size: 15px">正文</p></div>
EOF
expect_ratio samecolor-prose-still-fires "1.00"

echo "── walk() 的结构假设：宁可 FAIL，不许兜底继续算 ──────────"

# expect_walk_fail <名> <子串>：期望整套 CLI FAIL 且退出非 0，输出含指定的错误子串，
# 且不许出现任何数据行（tab 分隔的发现行）——「不许出数字」比「退出码非 0」更硬的
# 那道线：静默兜底继续算的错误实现会把这两条都破坏掉。
expect_walk_fail() {
  local name="$1" needle="$2"
  local out rc
  out="$(run "$name" 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ] && [[ "$out" == *"$needle"* ]] && [[ "$out" != *$'\t'* ]]; then
    printf 'ok   %s（FAIL 且不出数字）\n' "$name"; pass=$((pass + 1))
  else
    printf 'FAIL %s\n     期望: 退出非 0，含「%s」，不含任何 tab 分隔行\n     实得: rc=%s\n%s\n' \
      "$name" "$needle" "$rc" "$out"
    fail=$((fail + 1))
  fi
}

# 标签栈不闭合（缺 </p>）：走完整份产物后栈没回到根，不许假装什么都没发生继续算。
case1 walk-unclosed
themejson walk-unclosed walk-unclosed <<'EOF'
{}
EOF
html walk-unclosed walk-unclosed <<'EOF'
<div style="background-color:#fff"><p style="color:#000">未闭合
EOF
expect_walk_fail walk-unclosed "标签栈没回到根"

# 最外层不带 background-color：文本节点的祖先链上没有任何底色声明，不许默默按白算——
# 白底是产物里最常见的底，静默兜底这个缺陷极难被人眼发现。
case1 walk-nobg
themejson walk-nobg walk-nobg <<'EOF'
{}
EOF
html walk-nobg walk-nobg <<'EOF'
<div><p style="color: #000000">没有任何底色声明</p></div>
EOF
expect_walk_fail walk-nobg "没有任何底色声明"

echo "── 基线比对：键要含元素标签，不许把比值算进键 ──────────"

# th 与 strong 同色同底同字号字重，只有标签不同——基线键若漏掉标签，两条会在
# `{key_of(f): f for f in findings}` 这个 dict 里互相覆盖，塌成一条，凭空少报
# 一条「新组合」。正确实现：两条都是新组合，各占一行。
# 不建基线文件（read_baseline 对缺失文件优雅退回 {}），模拟「基线还没收录任何东西」。
case1 baseline-key-has-tag
themejson baseline-key-has-tag baseline-key-has-tag <<'EOF'
{}
EOF
html baseline-key-has-tag baseline-key-has-tag <<'EOF'
<div style="background-color: #ffffff">
<table><tr><th style="color: #999999; font-size: 14px; font-weight: 400">表头</th></tr></table>
<p style="font-size: 14px"><strong style="color: #999999; font-weight: 400">强调</strong></p>
</div>
EOF
out="$(run baseline-key-has-tag)"
n_new="$(printf '%s\n' "$out" | grep -c '^  baseline-key-has-tag	')"
has_th="$(printf '%s\n' "$out" | grep -c '^  baseline-key-has-tag	th	')"
has_strong="$(printf '%s\n' "$out" | grep -c '^  baseline-key-has-tag	strong	')"
if [ "$n_new" = "2" ] && [ "$has_th" = "1" ] && [ "$has_strong" = "1" ]; then
  printf 'ok   baseline-key-has-tag（th 与 strong 各占一行，不塌成一条）\n'; pass=$((pass + 1))
else
  printf 'FAIL baseline-key-has-tag\n     期望: 2 条新组合，th 与 strong 各 1 条\n     实得: %s 条（th=%s strong=%s）\n%s\n' \
    "$n_new" "$has_th" "$has_strong" "$out"
  fail=$((fail + 1))
fi

# 基线行的比值列写成别的数（.tsv 里比值只作参考，不参与比对），键（前 7 列）不变，
# 该行仍算「命中基线」，不许报成新增。若比对逻辑误把比值也编入键，任何历史比值
# 尾数的自然波动都会把整条基线打成一片虚假的「新增」。
case1 baseline-ratio-not-in-key
themejson baseline-ratio-not-in-key baseline-ratio-not-in-key <<'EOF'
{}
EOF
html baseline-ratio-not-in-key baseline-ratio-not-in-key <<'EOF'
<div style="background-color: #ffffff"><p style="color: #999999; font-size: 14px">正文</p></div>
EOF
{
  printf '主题\t元素\t前景\t底\t字号\t字重\t类\t比值(参考)\t处数(参考)\n'
  printf 'baseline-ratio-not-in-key\tp\t#999999\t#ffffff\t14\t400\t文字\t9.99\t1\n'
} > "$WORK/baseline-ratio-not-in-key/references/contrast-baseline.tsv"
out="$(run baseline-ratio-not-in-key)"; rc=$?
if [ "$rc" -eq 0 ] && [[ "$out" == *"无新增，基线一致"* ]]; then
  printf 'ok   baseline-ratio-not-in-key（比值尾数不同不算新增）\n'; pass=$((pass + 1))
else
  printf 'FAIL baseline-ratio-not-in-key\n     期望: exit 0，含「无新增，基线一致」\n     实得: rc=%s\n%s\n' "$rc" "$out"
  fail=$((fail + 1))
fi

echo "── 语料收集：只认 PAIRS，不许 glob('*.html') ────────────"

# outdir 里多放一份不在 PAIRS 里的 HTML（形态照真实语料库里 13-cyber-neon-v7-grid
# 这种「中间产物，不在配对表里」），且故意让它装满会不达标的文字——如果实现按
# glob('*.html') 挨个扫目录而不是照 PAIRS 表取权威配对，这份多出来的文件会被
# 一起算进去，总条数会变。正确实现：总条数只由 PAIRS 决定，多放的文件必须被
# 完全无视。
case1 pg-legit
themejson pg-legit pg-legit <<'EOF'
{}
EOF
html pg-legit pg-legit <<'EOF'
<div style="background-color: #ffffff"><p style="color: #999999; font-size: 14px">正文</p></div>
EOF
html pg-legit pg-legit-v7-grid <<'EOF'
<div style="background-color: #ffffff"><p style="color: #dddddd; font-size: 14px">未配对内容一</p><p style="color: #eeeeee; font-size: 14px">未配对内容二</p></div>
EOF
{
  printf '主题\t元素\t前景\t底\t字号\t字重\t类\t比值(参考)\t处数(参考)\n'
  printf 'pg-legit\tp\t#999999\t#ffffff\t14\t400\t文字\t2.85\t1\n'
} > "$WORK/pg-legit/references/contrast-baseline.tsv"
out="$(run pg-legit)"; rc=$?
if [ "$rc" -eq 0 ] && [[ "$out" == *"对比度普查：1 条不达标，基线 1 条"* ]] && [[ "$out" == *"无新增，基线一致"* ]]; then
  printf 'ok   pairs-not-glob（多出的 v7-grid 不改变条数）\n'; pass=$((pass + 1))
else
  printf 'FAIL pairs-not-glob\n     期望: 1 条不达标、1 条基线、无新增，exit 0\n     实得: rc=%s\n%s\n' "$rc" "$out"
  fail=$((fail + 1))
fi

echo "── 语料缺失：整体 SKIP 且退出码要标红 ────────────────"

# MD2HTML_CORPUS 指到不存在的目录：collect() 必须整体 SKIP 并 sys.exit(2)，
# 不许静默跳过（那样看起来像「跑过了、没问题」，实际什么都没测）。
newcase corpus-missing
pairs corpus-missing "corpus-missing:corpus-missing"
themejson corpus-missing corpus-missing <<'EOF'
{}
EOF
out="$( ( cd "$WORK/corpus-missing" && MD2HTML_CORPUS="$WORK/corpus-missing/no-such-corpus" python3 scripts/contrast-themes.py ) 2>&1 )"
rc=$?
if [ "$rc" -eq 2 ] && [[ "$out" == *"SKIP"* ]]; then
  printf 'ok   corpus-missing（SKIP 且退出码非 0）\n'; pass=$((pass + 1))
else
  printf 'FAIL corpus-missing\n     期望: 退出码 2，含 SKIP\n     实得: rc=%s\n%s\n' "$rc" "$out"
  fail=$((fail + 1))
fi

echo "── 真实主题库回归 ──────────────────────────────"

# 变异用例全绿只说明判据方向对，不说明它对真实产物库的写法都认。用真身（不是副本）、
# 真实语料（默认 MD2HTML_CORPUS）、真实基线跑一遍：条数必须与基线文件的数据行数
# 一致，且没有新增/新组合。**不写死这个数字**——写死一个来自探针首跑的数会让这条
# 测试变成「测探针」而不是「测实现」，基线文件本身才是权威来源，运行时从它读。
BASELINE_REAL="$SCRIPT_DIR/../references/contrast-baseline.tsv"
expected_n="$(grep -c '^[0-9]' "$BASELINE_REAL")"
real_out="$(python3 "$CLI_SRC" 2>&1)"
real_rc=$?
actual_n="$(printf '%s\n' "$real_out" | grep -oE '对比度普查：[0-9]+ 条不达标' | grep -oE '[0-9]+' | head -1)"
if [ "$real_rc" -eq 0 ] && [ -n "$actual_n" ] && [ "$actual_n" = "$expected_n" ]; then
  printf 'ok   real-library（真实产物库 %s 条，与基线文件行数一致）\n' "$actual_n"; pass=$((pass + 1))
else
  printf 'FAIL real-library\n     期望: 条数与基线文件（%s 行）一致，exit 0，无新增\n     实得: rc=%s，条数=%s\n%s\n' \
    "$expected_n" "$real_rc" "${actual_n:-<空>}" "$real_out"
  fail=$((fail + 1))
fi

printf '\n%d 通过，%d 失败\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
