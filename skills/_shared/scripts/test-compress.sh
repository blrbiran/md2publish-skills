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
echo "== 失败时不许动既有产物 =="

# 场景：上一轮已经生成并压好了一张 00-cover.jpg（花过钱），这一轮换了张更复杂的
# 原图、上限又收紧，压缩必然失败。失败**不能**把上一轮那张好图删掉或覆盖掉。
PREV="$TMP/prev-good.jpg"
printf 'PREVIOUS-GOOD-PAID-ARTIFACT' > "$PREV"
prev_before=$(cksum < "$PREV")
python3 compress.py --image "$TMP/big.png" --max-bytes 500 --out "$PREV" >/dev/null 2>&1
rc=$?
prev_after=$(cksum < "$PREV" 2>/dev/null || echo "已被删除")
if [[ $rc -ne 0 && -f "$PREV" && "$prev_before" == "$prev_after" ]]; then
  ok "压缩失败后既有产物仍在、内容一字未改"
else
  bad "压缩失败把上一轮花钱生成的产物毁了" "rc=$rc before=${prev_before} after=${prev_after}"
fi

# 反方向：本来没有产物时，失败不能留下半成品——否则下次 artifacts.py guard 会
# 误判"已生成"，把用户挡在门外。
FRESH="$TMP/fresh.jpg"
rm -f "$FRESH"
python3 compress.py --image "$TMP/big.png" --max-bytes 500 --out "$FRESH" >/dev/null 2>&1
strays=$(find "$TMP" -maxdepth 1 -name 'fresh*' -o -maxdepth 1 -name '.fresh*' | tr '\n' ' ')
if [[ ! -e "$FRESH" && -z "${strays// /}" ]]; then
  ok "压缩失败且原本无产物时不留残骸（含临时文件）"
else
  bad "失败后留下了残骸" "strays=${strays:-无} fresh 存在=$([[ -e "$FRESH" ]] && echo 是 || echo 否)"
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
