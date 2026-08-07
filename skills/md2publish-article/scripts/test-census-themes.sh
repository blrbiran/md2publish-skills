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
check() {
  local name="$1"; shift
  local expected actual
  expected="$(printf '%s\n' "$@" | sed '/^$/d' | sort)"
  actual="$(python3 "$CENSUS" --fixture-dir "$WORK/$name" 2>&1 |
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

printf '\n%d 通过，%d 失败\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
