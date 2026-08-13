#!/usr/bin/env bash
# svg2raster.py 的降级链测试。对应 spec §14.3 与三期 D13、D17。
#
# **降级链只能靠遮蔽 PATH 来验证。** 直接调 --backend 只证明"指定后端能用"，
# 证明不了"rsvg 不在时会自动退到下一级"——而后者才是降级链存在的理由。
# 遮蔽是在沙箱 bin 目录里只放需要的那一个后端，再把 PATH 换成它。
# 因此 svg2raster.py **必须只用标准库**：遮蔽后要用 /usr/bin/python3（3.9.6，
# 没装 PyYAML）来跑，import yaml 会直接崩。
#
# **遮掉 rsvg-convert 之后，期望退到的不一定是 magick。** magick 只有探测到真
# 的 RSVG delegate 才会被信任（见 svg2raster.py 的 magick_has_rsvg()）：没有
# delegate 的 magick 能把 SVG"跑通"（exit 0、产出合法 PNG），却会把图上所有
# CJK 文字静默丢光——这是本机实测出来的真实故障模式，比硬失败凶险得多。所以下
# 面"降级链的真行为"那条断言按本机探测结果二选一：探测到 delegate 就该退到
# magick，探测不到就该退到 chrome。如果看到它断言"退到 chrome"，别以为是降级
# 链断了——那是刻意不让一个会丢字的 magick 被静默选中。
set -uo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM

PASS=0
FAIL=0
SKIPPED=0
ok()   { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad()  { echo "  ❌ $1"; echo "     $2"; FAIL=$((FAIL+1)); }
# 跳过的断言需要真实后端（rsvg-convert / magick）才能跑，本机没装就验证不了
# 降级链的那一级。跳过不等于通过——记进 SKIPPED，脚本末尾据此 exit 2，
# 让 check.sh 把这一项标成 SKIPPED 而不是悄悄算作全绿（I4：这是 D14 的
# SKIPPED 语义本该覆盖但漏掉的一个脚本）。
skip() { echo "  ⊘ $1（本机没有该后端，跳过）"; SKIPPED=$((SKIPPED+1)); }

SVG=fixtures/diagram-sample.svg
CHROME_APP="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

png_w() { python3 -c "
import sys
d = open('$1','rb').read(24)
sys.exit(1) if d[:8] != b'\x89PNG\r\n\x1a\n' else print(int.from_bytes(d[16:20],'big'))
"; }

echo "== fixture 自身的约束 =="

missing=""
for f in "PingFang SC" "Noto Sans CJK SC" "Microsoft YaHei" "sans-serif"; do
  grep -q "${f}" "$SVG" || missing="${missing} ${f}"
done
if [[ -z "${missing}" ]]; then
  ok "fixture 的 CJK 字体 fallback 链完整（四个都在）"
else
  bad "字体 fallback 链缺项，换台机器渲染结果就不一样" "缺:${missing}"
fi

echo
echo "== --check =="

out=$(python3 svg2raster.py --check --json 2>&1)
rc=$?
if [[ $rc -eq 0 ]] && python3 -c "import json,sys; json.loads(sys.argv[1])['backends']" "$out" >/dev/null 2>&1; then
  ok "--check 输出合法 JSON 且退出 0（它是报告，不是门）"
else
  bad "--check 输出不对" "rc=${rc} out=${out}"
fi

echo
echo "== 画幅校验（D13） =="

out=$(python3 svg2raster.py --svg "$SVG" --out "$TMP/bad.png" --aspect 3:4 2>&1)
if [[ $? -ne 0 ]] && grep -q '16:9\|1.77\|viewBox' <<<"$out"; then
  ok "viewBox 比例与 --aspect 不符时硬失败（否则位图被拉伸变形）"
else
  bad "画幅不符却通过了" "$out"
fi

echo
echo "== 降级链：先定义遮蔽 PATH 的沙箱 =="

# 沙箱 bin 里只放要暴露的后端；PATH 只留它 + 系统目录（用 /usr/bin/python3 跑）
run_masked() {   # $1=要暴露的后端（空=一个都不暴露） $2=输出文件 $3=chrome 路径或空
  local expose="$1" out="$2" chrome="$3"
  local bin="$TMP/bin-${expose:-none}"
  rm -rf "${bin}"; mkdir -p "${bin}"
  [[ -n "${expose}" ]] && ln -sf "$(command -v "${expose}")" "${bin}/${expose}"
  # PYTHONNOUSERSITE=1：不加这个，/usr/bin/python3 会自动把
  # ~/Library/Python/3.9/lib/python/site-packages 塞进 sys.path（HOME 透传导致），
  # 这套"只用标准库"的隔离沙箱就形同虚设——见下面「沙箱纯净性」那组断言（I6）。
  env -i PATH="${bin}:/usr/bin:/bin" HOME="$HOME" PYTHONNOUSERSITE=1 SVG2RASTER_CHROME="${chrome}" \
    /usr/bin/python3 svg2raster.py --svg "$PWD/$SVG" --out "${out}" --aspect 16:9 --width 800 --json 2>&1
}

echo
echo "== 沙箱纯净性：确实没有第三方包（I6：只用标准库这条约束要有牙） =="
# svg2raster.py 自己声明"只用标准库"，理由就是要能在这套遮蔽 PATH 的沙箱里用
# /usr/bin/python3 跑。但 env -i 透传了 HOME，/usr/bin/python3 会因此把
# ~/Library/Python/3.9/lib/python/site-packages 自动加进 sys.path——如果这台机器
# 装过 PyYAML 之类的包，沙箱里 import 第三方库照样成功，上面 run_masked() 里的
# PYTHONNOUSERSITE=1 就形同虚设、没人会发现。这里直接验证隔离本身：沙箱里
# import 一个常见第三方包必须失败，这样将来有人手滑删掉 PYTHONNOUSERSITE=1，
# 这条断言会先翻红，而不是留到 svg2raster.py 被人加一行 `import xxx` 才发现。
out=$(env -i PATH="/usr/bin:/bin" HOME="$HOME" PYTHONNOUSERSITE=1 /usr/bin/python3 -c "import yaml" 2>&1)
if [[ $? -ne 0 ]] && grep -q "No module named 'yaml'" <<<"$out"; then
  ok "PYTHONNOUSERSITE=1 时，沙箱里 import 第三方包（yaml）确实失败——隔离是真的"
else
  bad "沙箱里 import yaml 没有失败——'只用标准库'这条约束没有测试真的守着" "$out"
fi

echo
echo "== 降级链：逐级遮蔽 PATH =="

if command -v rsvg-convert >/dev/null; then
  out=$(run_masked rsvg-convert "$TMP/a.png" "")
  if [[ $? -eq 0 ]] && grep -q '"backend": "rsvg-convert"' <<<"$out" && [[ "$(png_w "$TMP/a.png")" == "800" ]]; then
    ok "只有 rsvg-convert 时用它，且输出宽度等于 --width"
  else
    bad "rsvg-convert 这一级不成立" "$out"
  fi
else
  skip "rsvg-convert"
fi

# 本机 magick 是否真的可信（探测到 RSVG delegate），用非遮蔽的正常调用判断——
# 这反映的是这台机器的真实能力，跟接下来遮不遮 PATH 无关。
magick_capable=0
if command -v magick >/dev/null && python3 svg2raster.py --check --json 2>/dev/null | grep -q '"magick"'; then
  magick_capable=1
fi

echo
echo "== 降级链的真行为：遮掉 rsvg-convert 之后该退到谁 =="

if command -v magick >/dev/null; then
  out=$(run_masked magick "$TMP/b.png" "$CHROME_APP")
  rc=$?
  if [[ "${magick_capable}" == "1" ]]; then
    if [[ $rc -eq 0 ]] && grep -q '"backend": "magick"' <<<"$out" && [[ "$(png_w "$TMP/b.png")" == "800" ]]; then
      ok "本机 magick 探测到 RSVG delegate，遮掉 rsvg-convert 后信任并退到它"
    else
      bad "本机 magick 应该可信却没被退到（降级链断了）" "$out"
    fi
  else
    if [[ $rc -eq 0 ]] && grep -q '"backend": "chrome"' <<<"$out" && [[ -s "$TMP/b.png" ]]; then
      ok "本机 magick 没有 RSVG delegate，遮掉 rsvg-convert 后没有静默选它，而是退到 chrome"
    else
      bad "遮掉 rsvg-convert 后没有正确避开不可信的 magick" "rc=${rc} out=${out}"
    fi
  fi
else
  skip "magick（本机没装，无法验证遮掉 rsvg-convert 后的落点）"
fi

echo
echo "== 显式 --backend magick 在不可用时硬失败并点名 =="

if [[ "${magick_capable}" == "1" ]]; then
  skip "--backend magick 硬失败（本机 magick 有 RSVG delegate，指定它应当成功）"
else
  out=$(python3 svg2raster.py --svg "$SVG" --out "$TMP/e.png" --aspect 16:9 --backend magick 2>&1)
  rc=$?
  if [[ $rc -ne 0 ]] && grep -q 'RSVG' <<<"$out" && [[ ! -e "$TMP/e.png" ]]; then
    ok "本机 magick 没有 RSVG delegate，显式指定 --backend magick 时硬失败并说明原因"
  else
    bad "--backend magick 在不可用时没有被拦住" "rc=${rc} out=${out}"
  fi
fi

echo
echo "== 假 magick：给 magick_has_rsvg() 一个独立预言 =="
# 上面两条 magick 相关断言的"真值"（magick_capable）是调 svg2raster.py --check
# --json 算出来的——也就是被测代码自己，不是独立预言。这只能验证闸门内部自洽，
# 抓不住"magick_has_rsvg() 被悄悄改坏"这类回归：如果它被简化成无条件 return
# False，本机 magick 本来就会因带引号 fixture 而在实际光栅化时独立失败，两者
# 巧合地看起来一致，上面两条断言会照样全绿。这里改用假 magick 脚本——让
# magick -list format 打印我们指定的文本，直接给闸门的判定逻辑一个独立于本机
# 真实 ImageMagick 构建的预言。

make_fake_magick() {   # $1=bin 目录 $2=magick -list format 应打印的文本
  local bin="$1" text="$2"
  mkdir -p "${bin}"
  printf '%s\n' "${text}" > "${bin}/magick.out"
  cat > "${bin}/magick" <<'EOF'
#!/bin/sh
cat "$(dirname "$0")/magick.out"
exit 0
EOF
  chmod +x "${bin}/magick"
}

run_fake_magick_check() {   # $1=magick -list format 应打印的文本
  local text="$1"
  local bin="$TMP/bin-fakemagick"
  rm -rf "${bin}"
  make_fake_magick "${bin}" "${text}"
  env -i PATH="${bin}:/usr/bin:/bin" HOME="$HOME" PYTHONNOUSERSITE=1 SVG2RASTER_CHROME="/nonexistent/chrome" \
    /usr/bin/python3 svg2raster.py --check --json 2>&1
}

FAKE_MAGICK_RSVG=$'     MSVG* SVG       rw+   ImageMagick internal SVG renderer\n      SVG* SVG       rw+   Scalable Vector Graphics (RSVG 2.40.20)\n     SVGZ* SVG       rw+   Compressed Scalable Vector Graphics (RSVG 2.40.20)'
out=$(run_fake_magick_check "${FAKE_MAGICK_RSVG}")
if grep -q '"magick"' <<<"$out"; then
  ok "假 magick 的 SVG* 行带 RSVG 证据时，backends 里有 magick"
else
  bad "有 RSVG 证据却没被收进 backends" "$out"
fi

FAKE_MAGICK_XML=$'     MSVG* SVG       rw+   ImageMagick internal SVG renderer\n      SVG* SVG       rw+   Scalable Vector Graphics (XML 2.9.13)\n     SVGZ* SVG       rw+   Compressed Scalable Vector Graphics (XML 2.9.13)'
out=$(run_fake_magick_check "${FAKE_MAGICK_XML}")
if grep -q '"magick"' <<<"$out"; then
  bad "只有 XML（本机真实输出）却被收进了 backends" "$out"
else
  ok "假 magick 的 SVG* 行只有 XML、没有 RSVG 证据时，backends 里没有 magick"
fi

FAKE_MAGICK_MSVG_ONLY=$'     MSVG* SVG       rw+   ImageMagick internal SVG renderer (RSVG bait, this line is MSVG not SVG)'
out=$(run_fake_magick_check "${FAKE_MAGICK_MSVG_ONLY}")
if grep -q '"magick"' <<<"$out"; then
  bad "只有 MSVG* 行（描述里塞了 RSVG 诱饵）却被收进了 backends——把 MSVG* 当成了 SVG*，或者对整行 grep RSVG" "$out"
else
  ok "只有 MSVG* 行、没有 SVG* 行时，即使描述里塞了 RSVG 诱饵，backends 里也没有 magick"
fi

echo
echo "== 三者全缺 =="

out=$(run_masked "" "$TMP/none.png" "/nonexistent/chrome")
rc=$?
if [[ $rc -ne 0 ]] && grep -q '自行转换' <<<"$out" && [[ ! -e "$TMP/none.png" ]] && [[ -f "$SVG" ]]; then
  ok "三个后端都没有时硬失败、明说需自行转换、SVG 原样保留"
else
  bad "缺工具时的行为不对（静默失败或删了 SVG）" "rc=${rc} out=${out}"
fi

echo
echo "== 显式 --backend =="

out=$(python3 svg2raster.py --svg "$SVG" --out "$TMP/d.png" --aspect 16:9 --backend no-such-backend 2>&1)
if [[ $? -ne 0 ]] && grep -q 'no-such-backend' <<<"$out"; then
  ok "--backend 传了不认识的名字时硬失败并点名"
else
  bad "未知 backend 未被拦住" "$out"
fi

echo
echo "通过 $PASS 项，失败 $FAIL 项，跳过 $SKIPPED 项"
if [[ $FAIL -gt 0 ]]; then
  exit 1
elif [[ $SKIPPED -gt 0 ]]; then
  echo "跳过的项没有真的验证过降级链的那一级——不算通过。装齐 rsvg-convert / magick 后重跑。"
  exit 2
else
  exit 0
fi
