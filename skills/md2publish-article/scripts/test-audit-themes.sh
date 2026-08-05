#!/usr/bin/env bash
#
# audit-themes.py 的变异测试：造一批带**已知缺陷**的主题文件，断言脚本报什么、不报什么。
#
#     bash skills/md2publish-article/scripts/test-audit-themes.sh
#
# 为什么要有这个：审计脚本对真实主题库跑出 0 条时，你分不清是「库真的干净」还是
# 「脚本根本没在查」。改了 audit-themes.py 的判据或正则之后必须先跑这里跑到全绿，
# 再去跑真实主题库（见 docs/theme-design-lessons.md「机械审计方法」）。
#
# 每个用例一份 fixture、一个独立临时目录，比对的是输出里「档位 + 色值」的集合——
# 既断言该报的报了，也断言不该报的没报。**误报和漏报要一起测**：OVER 这一档第一版
# 只测了「该报的报没报」，判据下宽了报掉大半个库，测试全绿也照样没抓到。
#
# fixture 的书写形态要贴着真实主题库来。第一轮 4 个变异全写成「行内 code 独占一行」，
# 就漏掉了 autumn-warm 那种「代码块与行内 code 同写一行」的形态，脚本对它漏报。
# 下面 over-sameline 这个用例专门守这个形态。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT="$SCRIPT_DIR/audit-themes.py"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0

# mk <用例名>：从 stdin 读 fixture 正文，落到独立目录（审计脚本按目录扫，隔离才不互相干扰）
mk() {
  mkdir -p "$WORK/$1"
  cat > "$WORK/$1/$1.md"
}

# check <用例名> [期望的「档位 色值」...]：不给期望 = 断言一条都不该报
check() {
  local name="$1"; shift
  local expected actual
  expected="$(printf '%s\n' "$@" | sed '/^$/d' | sort)"
  actual="$(python3 "$AUDIT" "$WORK/$name" |
    awk '$1 ~ /^(DEAD|LOW|DECOR|OVER|DESYNC|NOSPEC)$/ {print $1, $3}' | sort)"
  if [ "$actual" = "$expected" ]; then
    printf 'ok   %s\n' "$name"
    pass=$((pass + 1))
  else
    printf 'FAIL %s\n     期望: %s\n     实得: %s\n' \
      "$name" "${expected:-<空>}" "${actual:-<空>}"
    fail=$((fail + 1))
  fi
}

# ---------------------------------------------------------------- OVER（落点过载）

# 1. 无底 + 强调色文字 = 与 strong 同色同形，读者分不出 → 该报
mk over-nobg <<'EOF'
# fixture：行内 code 无底 + 强调色文字

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 主强调：`#cc3366`
- 代码底：`#f5f5f5`

## 容器与布局

- 主容器：`background-color: #ffffff; padding: 40px 10px`

## 正文与强调

- 段落：`font-size: 16px; color: #222222`
- strong：`color: #cc3366; font-weight: 700`

## 引用 / 代码 / 列表 / 表格

- 代码块：`<pre>` 底 `#f5f5f5`、文字 `#222222`
- 行内 code：文字 `#cc3366`、`padding: 2px 6px`
EOF
check over-nobg "OVER #cc3366"

# 2. 带底 + 强调色文字 = 有自己的形状，和 strong 分得开 → 不该报
#    这也是全库 15 个主题的形态，判据下宽的话这里立刻变红。
mk over-withbg <<'EOF'
# fixture：行内 code 带底，形状上与 strong 分得开

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 主强调：`#cc3366`
- 代码底：`#f5f5f5`

## 容器与布局

- 主容器：`background-color: #ffffff; padding: 40px 10px`

## 正文与强调

- 段落：`font-size: 16px; color: #222222`
- strong：`color: #cc3366; font-weight: 700`

## 引用 / 代码 / 列表 / 表格

- 代码块：`<pre>` 底 `#f5f5f5`、文字 `#222222`
- 行内 code：底 `#f5f5f5`、文字 `#cc3366`、`padding: 2px 6px`
EOF
check over-withbg

# 3. 代码块与行内 code 写在同一行（autumn-warm 的形态）：必须取到**行内 code 那一段**的色值。
#    这里故意让代码块的文字色也是个强调色（#3366cc）——取错了就会报成 #3366cc 或干脆
#    被代码块的「底」挡掉不报，两种错都会让下面这条断言变红。
mk over-sameline <<'EOF'
# fixture：代码块与行内 code 同写一行

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 主强调：`#cc3366`
- 副强调：`#3366cc`
- 代码底：`#f5f5f5`

## 容器与布局

- 主容器：`background-color: #ffffff; padding: 40px 10px`

## 标题体系

- h3：`font-size: 17px; color: #3366cc; margin: 26px 0 12px`

## 正文与强调

- 段落：`font-size: 16px; color: #222222`
- strong：`color: #cc3366; font-weight: 700`

## 引用 / 代码 / 列表 / 表格

- 代码块：`<pre>` 底 `#f5f5f5`、文字 `#3366cc`；行内 code：文字 `#cc3366`、`padding: 2px 6px`
EOF
check over-sameline "OVER #cc3366"

# 4. 纯 CSS 写法、无底（真实库有 2 个主题用这种写法，不是「底/文字」的中文写法）
mk over-css-nobg <<'EOF'
# fixture：行内 code 用 CSS 写法，无底

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 主强调：`#cc3366`
- 代码底：`#f5f5f5`

## 容器与布局

- 主容器：`background-color: #ffffff; padding: 40px 10px`

## 正文与强调

- 段落：`font-size: 16px; color: #222222`
- strong：`color: #cc3366; font-weight: 700`

## 引用 / 代码 / 列表 / 表格

- 代码块：`<pre>` 底 `#f5f5f5`、文字 `#222222`
- 行内 code：`color: #cc3366; padding: 2px 6px; border-radius: 4px`
EOF
check over-css-nobg "OVER #cc3366"

# 5. 纯 CSS 写法、带底 → 不该报。这一条守的是「`background-color:` 这个串里本身就含
#    `color:`」——正则不挡的话取到的永远是底色，文字色查不到，OVER 整档静默失效。
mk over-css-withbg <<'EOF'
# fixture：行内 code 用 CSS 写法，带底

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 主强调：`#cc3366`
- 代码底：`#f5f5f5`

## 容器与布局

- 主容器：`background-color: #ffffff; padding: 40px 10px`

## 正文与强调

- 段落：`font-size: 16px; color: #222222`
- strong：`color: #cc3366; font-weight: 700`

## 引用 / 代码 / 列表 / 表格

- 代码块：`<pre>` 底 `#f5f5f5`、文字 `#222222`
- 行内 code：`background-color: #f5f5f5; color: #cc3366; padding: 2px 6px`
EOF
check over-css-withbg

# 6. 带前缀的 `*-color:` 属性不是文字色。真实库目前只有 `background-color:`（已被上面那条
#    「有底就不报」的守卫挡掉），所以这一条守的是将来：任何 `border-color:` 之类的写法都
#    含子串 `color:`，正则不加反向断言就会把装饰色读成文字色，凭空报一条 OVER。
mk over-prefixed-color-prop <<'EOF'
# fixture：border-color 不是文字色

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 主强调：`#cc3366`
- 代码底：`#f5f5f5`

## 容器与布局

- 主容器：`background-color: #ffffff; padding: 40px 10px`

## 正文与强调

- 段落：`font-size: 16px; color: #222222`
- strong：`color: #cc3366; font-weight: 700`

## 引用 / 代码 / 列表 / 表格

- 代码块：`<pre>` 底 `#f5f5f5`、文字 `#222222`
- 行内 code：`border-color: #cc3366; color: #222222; padding: 2px 6px`
EOF
check over-prefixed-color-prop

# 7. 规范行前面先有一句提到「行内 code」的散文（分寸条款）。散文句不带色值，不能让扫描
#    在它身上停下，也不能把它当成规范行——真实主题文件里这两种句子是混在一起的。
mk over-prose-before-spec <<'EOF'
# fixture：散文句在前，规范行在后

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 主强调：`#cc3366`
- 代码底：`#f5f5f5`

## 容器与布局

- 主容器：`background-color: #ffffff; padding: 40px 10px`

## 正文与强调

- 段落：`font-size: 16px; color: #222222`
- strong：`color: #cc3366; font-weight: 700`
- **行内 code 不承担强调色的主要落点**——技术文里它有一两百处，密度太高

## 引用 / 代码 / 列表 / 表格

- 代码块：`<pre>` 底 `#f5f5f5`、文字 `#222222`
- 行内 code：文字 `#cc3366`、`padding: 2px 6px`
EOF
check over-prose-before-spec "OVER #cc3366"

# ---------------------------------------------------------------- 豁免注记

# 4. 经真机确认的落点写豁免注记 → 该条不再报
mk exempt-ok <<'EOF'
# fixture：OVER 落点已豁免

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 主强调：`#cc3366`
- 代码底：`#f5f5f5`

## 容器与布局

- 主容器：`background-color: #ffffff; padding: 40px 10px`

## 正文与强调

- 段落：`font-size: 16px; color: #222222`
- strong：`color: #cc3366; font-weight: 700`

## 引用 / 代码 / 列表 / 表格

- 代码块：`<pre>` 底 `#f5f5f5`、文字 `#222222`
- 行内 code：文字 `#cc3366`、`padding: 2px 6px`

<!-- audit-ok: OVER #cc3366 真机确认：本主题 strong 走字重不变色，两者分得开 -->
EOF
check exempt-ok

# 5. 豁免注记里的色值**不能变成落点**。这个色在正文规范里一次都没出现，只在注记里露过脸，
#    脚本查落点前不剥注释的话，DEAD 就被一条注记骗过去了（注记豁免的是 OVER，不是 DEAD）。
#    与下面的 dead 用例是一对：加不加这条注记，判定都该是 DEAD。
mk exempt-no-fake-hit <<'EOF'
# fixture：豁免注记里的色值不算落点

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 主强调：`#cc3366`
- 代码底：`#f5f5f5`

## 容器与布局

- 主容器：`background-color: #ffffff; padding: 40px 10px`

## 正文与强调

- 段落：`font-size: 16px; color: #222222`
- strong：`color: #222222; font-weight: 700`

<!-- audit-ok: OVER #cc3366 注记里的色值不该被当成落点 -->

## 引用 / 代码 / 列表 / 表格

- 代码块：`<pre>` 底 `#f5f5f5`、文字 `#222222`
- 行内 code：底 `#f5f5f5`、文字 `#222222`
EOF
check exempt-no-fake-hit "DEAD #cc3366"

# ---------------------------------------------------------------- DEAD / LOW / DECOR

# 6. DEAD：调色板声明了，组件规范里一次都没出现 → 该色等于不存在
mk dead <<'EOF'
# fixture：强调色零落点

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 主强调：`#cc3366`
- 代码底：`#f5f5f5`

## 容器与布局

- 主容器：`background-color: #ffffff; padding: 40px 10px`

## 正文与强调

- 段落：`font-size: 16px; color: #222222`
- strong：`color: #222222; font-weight: 700`

## 引用 / 代码 / 列表 / 表格

- 代码块：`<pre>` 底 `#f5f5f5`、文字 `#222222`
- 行内 code：底 `#f5f5f5`、文字 `#222222`
EOF
check dead "DEAD #cc3366"

# 7. LOW：文字色落点只挂在 em 上——中文技术文里 em 可能整篇为零，等于没落点
mk low <<'EOF'
# fixture：强调色只落在 em 上

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 主强调：`#cc3366`
- 代码底：`#f5f5f5`

## 容器与布局

- 主容器：`background-color: #ffffff; padding: 40px 10px`

## 正文与强调

- 段落：`font-size: 16px; color: #222222`
- strong：`color: #222222; font-weight: 700`
- em：`color: #cc3366`

## 引用 / 代码 / 列表 / 表格

- 代码块：`<pre>` 底 `#f5f5f5`、文字 `#222222`
- 行内 code：底 `#f5f5f5`、文字 `#222222`
EOF
check low "LOW #cc3366"

# 8. DECOR：只当 3px 细线用，没有文字色落点——视觉权重接近零（规则 6）
mk decor <<'EOF'
# fixture：强调色只当边框细线

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 主强调：`#cc3366`
- 代码底：`#f5f5f5`

## 容器与布局

- 主容器：`background-color: #ffffff; padding: 40px 10px`

## 标题体系

- h3：`font-size: 17px; color: #222222; border-bottom: 2px solid #cc3366`

## 正文与强调

- 段落：`font-size: 16px; color: #222222`
- strong：`color: #222222; font-weight: 700`

## 引用 / 代码 / 列表 / 表格

- 代码块：`<pre>` 底 `#f5f5f5`、文字 `#222222`
- 行内 code：底 `#f5f5f5`、文字 `#222222`
EOF
check decor "DECOR #cc3366"

# ---------------------------------------------------------------- DESYNC

# 9. 调色板里有零落点色（旧值）+ 组件里有未声明色（新值）= 改了组件忘了同步调色板，
#    一份文件里两个值并存，生成模型读到哪个算哪个。
mk desync <<'EOF'
# fixture：改了组件没同步调色板

## 色彩系统

- 背景：`#ffffff`（主容器）
- 主文字：`#222222`
- 主强调：`#cc3366`
- 代码底：`#f5f5f5`

## 容器与布局

- 主容器：`background-color: #ffffff; padding: 40px 10px`

## 正文与强调

- 段落：`font-size: 16px; color: #222222`
- strong：`color: #dd4477; font-weight: 700`

## 引用 / 代码 / 列表 / 表格

- 代码块：`<pre>` 底 `#f5f5f5`、文字 `#222222`
- 行内 code：底 `#f5f5f5`、文字 `#222222`
EOF
check desync "DEAD #cc3366" "DESYNC #cc3366"

# ---------------------------------------------------------------- 真实主题库回归

# 变异用例全绿只说明判据的方向对，不说明它对真实文件的写法都认。真实库必须仍是 0 条——
# 这一步同时是「判据别下宽了」的兜底：宽一档就会有真主题被报出来。
real_out="$(python3 "$AUDIT" 2>&1)"
real_n="$(printf '%s\n' "$real_out" |
  awk '$1 ~ /^(DEAD|LOW|DECOR|OVER|DESYNC|NOSPEC)$/' | wc -l | tr -d ' ')"
if [ "$real_n" = "0" ]; then
  printf 'ok   real-library（真实主题库 0 条）\n'
  pass=$((pass + 1))
else
  printf 'FAIL real-library（真实主题库 %s 条，应为 0）\n%s\n' "$real_n" "$real_out"
  fail=$((fail + 1))
fi

printf '\n%d 通过，%d 失败\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
