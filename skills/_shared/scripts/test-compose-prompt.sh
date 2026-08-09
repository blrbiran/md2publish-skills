#!/usr/bin/env bash
# 渲染器行为测试。对应 spec §13 第 2 项（占位符白名单）与 §6（纯模板渲染）。
set -uo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp -d)
ROGUE=../presets/cover/__rogue.yaml
# 占位符白名单那段会临时往真实 presets 目录塞一个非法 preset。
# 必须进 trap——中途崩了留下残留文件会让 test-asset-schema.sh 的 INDEX 检查误报。
trap 'rm -rf "$TMP"; rm -f "$ROGUE"' EXIT

PASS=0
FAIL=0
ok()  { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad() { echo "  ❌ $1"; echo "     $2"; FAIL=$((FAIL+1)); }

BRIEF=fixtures/brief-sample.md

echo "== 渲染基本行为 =="

out=$(python3 compose_prompt.py --platform wechat --preset editorial-warm \
        --brief-file "$BRIEF" --out "$TMP/a.md" 2>&1)
if [[ $? -eq 0 && -s "$TMP/a.md" ]]; then ok "渲染成功且产物非空"; else bad "渲染失败" "$out"; fi

body=$(cat "$TMP/a.md" 2>/dev/null || true)
if ! grep -q '{{' <<<"$body"; then ok "产物中没有残留占位符"; else bad "占位符残留" "$(grep -o '{{[A-Z_]*}}' <<<"$body" | sort -u)"; fi
if grep -q '16:9' <<<"$body"; then ok "平台画幅已注入"; else bad "画幅未注入" "产物里找不到 16:9"; fi
if grep -q '烧赭' <<<"$body"; then ok "palette 维度已注入"; else bad "palette 未注入" "找不到 warm-earth 的内容"; fi
if grep -q '扁平矢量' <<<"$body"; then ok "rendering 维度已注入"; else bad "rendering 未注入" "找不到 flat-vector 的内容"; fi
if grep -q '缓存失效' <<<"$body"; then ok "brief 内容已注入"; else bad "brief 未注入" "找不到 brief 里的主题"; fi
# 与 test-platform-matrix.sh 用同一个契约串，两处断言必须一致
if grep -qE '图上必须包含|图上不要出现标题文字' <<<"$body"; then
  ok "text_on_image 策略已注入"
else
  bad "文字策略未注入" "产物里既没有'图上必须包含'也没有'图上不要出现标题文字'"
fi

echo
echo "== 维度覆盖 =="

python3 compose_prompt.py --platform wechat --preset editorial-warm \
    --brief-file "$BRIEF" --palette cool-slate --out "$TMP/b.md" >/dev/null 2>&1
body=$(cat "$TMP/b.md" 2>/dev/null || true)
if grep -q '石板蓝' <<<"$body" && ! grep -q '烧赭' <<<"$body"; then
  ok "--palette 覆盖生效且原 palette 未残留"
else
  bad "--palette 覆盖" "产物未换成 cool-slate"
fi

out=$(python3 compose_prompt.py --platform wechat --preset editorial-warm \
        --brief-file "$BRIEF" --palette no-such-palette --out "$TMP/c.md" 2>&1)
if [[ $? -ne 0 ]] && grep -q 'no-such-palette' <<<"$out"; then
  ok "覆盖值不存在时硬失败并点名"
else
  bad "非法覆盖值未拦住" "$out"
fi

echo
echo "== 占位符白名单（spec §13 第 2 项）=="

cat > "$TMP/bad-preset.yaml" <<'YAML'
name: rogue
archetype: cover
description: 含非法占位符的 preset
primary_use_case: 仅用于测试
version: 0.0.1
palette: warm-earth
rendering: flat-vector
layout: null
incompatible_platforms: []
metadata:
  author: test
  provenance: test fixture
template: |
  {{PLATFORM_FRAME}}
  {{MOOD}}
  {{CONTENT}}
YAML
cp "$TMP/bad-preset.yaml" "$ROGUE"
out=$(python3 compose_prompt.py --platform wechat --preset __rogue \
        --brief-file "$BRIEF" --out "$TMP/d.md" 2>&1)
rc=$?
rm -f "$ROGUE"
if [[ $rc -ne 0 ]] && grep -q 'MOOD' <<<"$out"; then
  ok "未知占位符硬失败并点名 MOOD"
else
  bad "未知占位符未拦住（会导致静默降级）" "rc=$rc out=$out"
fi

echo
echo "== unsupported 组合 =="

out=$(python3 compose_prompt.py --platform wechat --preset card-warm \
        --brief-file "$BRIEF" --out "$TMP/e.md" 2>&1)
if [[ $? -ne 0 ]] && grep -qi 'unsupported\|不支持' <<<"$out"; then
  ok "wechat × series 硬失败"
else
  bad "unsupported 组合未拦住" "$out"
fi

echo
echo "通过 $PASS 项，失败 $FAIL 项"
[[ $FAIL -eq 0 ]]
