#!/usr/bin/env bash
# svg2raster.py 的降级链测试。对应 spec §14.3 与三期 D13。
#
# **降级链只能靠遮蔽 PATH 来验证。** 直接调 --backend 只证明"指定后端能用"，
# 证明不了"rsvg 不在时会自动退到 magick"——而后者才是降级链存在的理由。
# 遮蔽是在沙箱 bin 目录里只放需要的那一个后端，再把 PATH 换成它。
# 因此 svg2raster.py **必须只用标准库**：遮蔽后要用 /usr/bin/python3（3.9.6，
# 没装 PyYAML）来跑，import yaml 会直接崩。
set -uo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM

PASS=0
FAIL=0
ok()   { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad()  { echo "  ❌ $1"; echo "     $2"; FAIL=$((FAIL+1)); }
skip() { echo "  ⊘ $1（本机没有该后端，跳过）"; }

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
echo "== 降级链：逐级遮蔽 PATH =="

# 沙箱 bin 里只放要暴露的后端；PATH 只留它 + 系统目录（用 /usr/bin/python3 跑）
run_masked() {   # $1=要暴露的后端（空=一个都不暴露） $2=输出文件 $3=chrome 路径或空
  local expose="$1" out="$2" chrome="$3"
  local bin="$TMP/bin-${expose:-none}"
  rm -rf "${bin}"; mkdir -p "${bin}"
  [[ -n "${expose}" ]] && ln -sf "$(command -v "${expose}")" "${bin}/${expose}"
  env -i PATH="${bin}:/usr/bin:/bin" HOME="$HOME" SVG2RASTER_CHROME="${chrome}" \
    /usr/bin/python3 svg2raster.py --svg "$PWD/$SVG" --out "${out}" --aspect 16:9 --width 800 --json 2>&1
}

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

if command -v magick >/dev/null; then
  out=$(run_masked magick "$TMP/b.png" "")
  if [[ $? -eq 0 ]] && grep -q '"backend": "magick"' <<<"$out" && [[ "$(png_w "$TMP/b.png")" == "800" ]]; then
    ok "遮掉 rsvg-convert 后自动退到 magick"
  else
    bad "magick 这一级不成立（降级链断了）" "$out"
  fi
else
  skip "magick"
fi

if [[ -x "$CHROME_APP" ]]; then
  out=$(run_masked "" "$TMP/c.png" "$CHROME_APP")
  if [[ $? -eq 0 ]] && grep -q '"backend": "chrome"' <<<"$out" && [[ -s "$TMP/c.png" ]]; then
    ok "前两级都遮掉后退到 headless Chrome"
  else
    bad "chrome 这一级不成立" "$out"
  fi
else
  skip "chrome"
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
echo "通过 $PASS 项，失败 $FAIL 项"
[[ $FAIL -eq 0 ]]
