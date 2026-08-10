#!/usr/bin/env bash
# compress.py 行为测试。对应 spec §13 第 4 项："给定 max_bytes，压完必须真的小于它"。
set -uo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
ok()  { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad() { echo "  ❌ $1"; echo "     $2"; FAIL=$((FAIL+1)); }

# 造一张必然超限的大图。用 magick 合成而不是塞进仓库——二进制 fixture 不进 git。
if ! command -v magick >/dev/null; then
  echo "跳过：本机没有 magick，造不出测试用大图" >&2
  exit 0
fi
magick -size 3000x1688 plasma:fractal "$TMP/big.png" 2>/dev/null
BIG_BYTES=$(wc -c < "$TMP/big.png" | tr -d ' ')
printf 'x' > "$TMP/tiny.png"

echo "== 已在上限内 =="

out=$(python3 compress.py --image "$TMP/tiny.png" --max-bytes 1000 --json 2>&1)
if grep -q '"action": "none"' <<<"$out" && grep -q 'tiny.png' <<<"$out"; then
  ok "已达标时原样返回，不新建文件"
else
  bad "已达标时行为不对" "$out"
fi

echo
echo "== 超限时压到上限内（spec §13 第 4 项）=="

MAX=2097152    # 微信封面 2MB，与 wechat.yaml 的 archetypes.cover.max_bytes 同值
path=$(python3 compress.py --image "$TMP/big.png" --max-bytes "$MAX" 2>"$TMP/err.txt")
rc=$?
if [[ $rc -eq 0 && -f "$path" ]]; then
  ok "压缩成功且 stdout 的路径真实存在"
else
  bad "压缩失败" "rc=$rc path=$path $(cat "$TMP/err.txt")"
fi

got=$(wc -c < "$path" 2>/dev/null | tr -d ' ')
if [[ -n "${got:-}" && "$got" -le "$MAX" ]]; then
  ok "产物 $got 字节 ≤ 上限 $MAX"
else
  bad "产物仍然超限" "got=${got:-无} max=$MAX"
fi

now=$(wc -c < "$TMP/big.png" | tr -d ' ')
if [[ "$now" == "$BIG_BYTES" && "$path" != "$TMP/big.png" ]]; then
  ok "原图未被就地覆盖"
else
  bad "原图被改了（花钱生成的东西不能就地覆盖）" "before=$BIG_BYTES after=$now path=$path"
fi

echo
echo "== 压不下去时硬失败 =="

out=$(python3 compress.py --image "$TMP/big.png" --max-bytes 500 2>&1)
if [[ $? -ne 0 ]] && grep -q '500' <<<"$out"; then
  ok "不可能的目标硬失败并报出上限"
else
  bad "压不下去却没失败（会交付一个超限文件）" "$out"
fi

echo
echo "== JSON 输出 =="

out=$(python3 compress.py --image "$TMP/big.png" --max-bytes "$MAX" --json 2>&1)
if grep -q '"tool"' <<<"$out" && grep -q '"steps"' <<<"$out" && grep -q '"bytes"' <<<"$out"; then
  ok "--json 含 tool / steps / bytes 字段"
else
  bad "--json 字段不全" "$out"
fi

echo
echo "通过 $PASS 项，失败 $FAIL 项"
[[ $FAIL -eq 0 ]]
