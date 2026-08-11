#!/usr/bin/env bash
# artifacts.py 测试。对应 spec §7.3（重跑跳过）与 §5.3（产物 sidecar）。
set -uo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
ok()  { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad() { echo "  ❌ $1"; echo "     $2"; FAIL=$((FAIL+1)); }

echo "== guard：重跑保护 =="

python3 artifacts.py guard --path "$TMP/absent.png" >/dev/null 2>&1
[[ $? -eq 0 ]] && ok "目标不存在时放行" || bad "不存在却被拦" ""

printf 'fake-image-bytes' > "$TMP/exists.png"
out=$(python3 artifacts.py guard --path "$TMP/exists.png" 2>&1)
rc=$?
if [[ $rc -ne 0 ]] && grep -q 'exists.png' <<<"$out"; then
  ok "目标已存在时拦住并报出路径"
else
  bad "已存在却放行（会静默覆盖花钱产出的图）" "rc=$rc out=$out"
fi

python3 artifacts.py guard --path "$TMP/exists.png" --force >/dev/null 2>&1
[[ $? -eq 0 ]] && ok "--force 时放行" || bad "--force 未生效" ""

echo
echo "== sidecar：产物元数据 =="

run_sidecar() {
  python3 artifacts.py sidecar \
    --image "$TMP/exists.png" \
    --platform wechat --archetype cover --preset "$1" \
    --provider openai --model gpt-image-2 \
    --prompt-file prompts/wechat/00-cover.md \
    --brief-file briefs/wechat/00-cover.md \
    --alt-text "暖色调编辑风封面" \
    --override palette=cool-slate 2>&1
}

out=$(run_sidecar editorial-warm)
rc=$?
SIDECAR="$TMP/exists.json"
if [[ $rc -eq 0 && -f "$SIDECAR" ]]; then ok "写出同名 .json"; else bad "sidecar 未生成" "rc=$rc out=$out"; fi

jq_get() { python3 -c "import json,sys; print(json.load(open('$SIDECAR'))$1)"; }

# preset_version 必须来自 preset YAML，不是命令行传入的
expected_version=$(python3 -c "import sys; sys.path.insert(0,'.'); import asset_lib as a; print(a.load_preset('editorial-warm')['version'])")
got_version=$(jq_get "['preset_version']" 2>&1)
if [[ "$got_version" == "$expected_version" ]]; then
  ok "preset_version 取自 preset YAML（${got_version}）"
else
  bad "preset_version 不对" "expected=$expected_version got=$got_version"
fi

real_bytes=$(wc -c < "$TMP/exists.png" | tr -d ' ')
got_bytes=$(jq_get "['bytes']" 2>&1)
if [[ "$got_bytes" == "$real_bytes" ]]; then ok "bytes 等于图片真实字节数"; else bad "bytes 不对" "expected=$real_bytes got=$got_bytes"; fi

got_override=$(jq_get "['overrides']['palette']" 2>&1)
if [[ "$got_override" == "cool-slate" ]]; then ok "--override 解析成对象"; else bad "overrides 不对" "$got_override"; fi

got_alt=$(jq_get "['alt_text']" 2>&1)
if [[ "$got_alt" == "暖色调编辑风封面" ]]; then ok "alt_text 原样保留（Markdown 回写要用）"; else bad "alt_text 不对" "$got_alt"; fi

got_at=$(jq_get "['generated_at']" 2>&1)
if grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{2}:[0-9]{2}$' <<<"$got_at"; then
  ok "generated_at 是带时区的 ISO 8601"
else
  bad "generated_at 格式不对" "$got_at"
fi

got_image=$(jq_get "['image']" 2>&1)
if [[ "$got_image" == "exists.png" ]]; then
  ok "image 记的是最终产物的文件名"
else
  bad "image 字段缺失或不对（下游只能靠猜 .png/.jpg）" "got=${got_image}"
fi

# 为什么必须有这个字段：sidecar 路径是 image.with_suffix('.json')，
# 所以 exists.png 和 exists.jpg 算出来是同一个 exists.json——
# 文件名本身区分不了这两个，只有字段能。
printf 'fake-compressed-bytes' > "$TMP/exists.jpg"
python3 artifacts.py sidecar \
  --image "$TMP/exists.jpg" \
  --platform wechat --archetype cover --preset editorial-warm \
  --provider openai --model gpt-image-2 \
  --prompt-file prompts/wechat/00-cover.md \
  --brief-file briefs/wechat/00-cover.md \
  --alt-text "暖色调编辑风封面" >/dev/null 2>&1
got_image=$(jq_get "['image']" 2>&1)
if [[ "$got_image" == "exists.jpg" ]]; then
  ok "png 与 jpg 共写同一个 .json 时，image 指向压缩产物"
else
  bad "压缩产物没被记下来（draft 会拿到超限的 .png）" "got=${got_image}"
fi

out=$(run_sidecar no-such-preset)
if [[ $? -ne 0 ]] && grep -q 'no-such-preset' <<<"$out"; then
  ok "preset 不存在时硬失败并点名"
else
  bad "不存在的 preset 未拦住" "$out"
fi

echo
echo "通过 $PASS 项，失败 $FAIL 项"
[[ $FAIL -eq 0 ]]
