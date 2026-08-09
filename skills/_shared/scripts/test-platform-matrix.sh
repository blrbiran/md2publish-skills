#!/usr/bin/env bash
# 平台 × archetype × preset 全矩阵。对应 spec §13 第 1 项。
# 每个组合只有两种合法结果：成功且注入了平台字段，或因 unsupported 明确失败。
set -uo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

BRIEF=fixtures/brief-sample.md
PASS=0
FAIL=0

platforms=$(python3 -c 'import asset_lib as a; print(" ".join(a.list_platforms()))')
presets=$(python3 -c 'import asset_lib as a; print(" ".join(a.list_presets()))')

echo "平台: $platforms"
echo "preset: $presets"
echo

for p in $platforms; do
  for s in $presets; do
    # 该组合是否应当被支持，由 asset_lib 独立判定（不依赖 composer）
    expect=$(python3 -c "
import asset_lib as a
plat = a.load_platform('$p')
pre  = a.load_preset('$s')
slot = a.archetype_slot(plat, pre['archetype'])
print('ok' if slot is not None and a.preset_supports(pre, '$p') else 'unsupported')
")
    out=$(python3 compose_prompt.py --platform "$p" --preset "$s" \
            --brief-file "$BRIEF" --out "$TMP/$p-$s.md" 2>&1)
    rc=$?

    if [[ "$expect" == "unsupported" ]]; then
      if [[ $rc -ne 0 ]]; then
        echo "  ✅ $p × $s → 按预期拒绝"; PASS=$((PASS+1))
      else
        echo "  ❌ $p × $s → 应拒绝却成功了"; FAIL=$((FAIL+1))
      fi
      continue
    fi

    if [[ $rc -ne 0 ]]; then
      echo "  ❌ $p × $s → 应成功却失败: $out"; FAIL=$((FAIL+1)); continue
    fi

    body=$(cat "$TMP/$p-$s.md")
    problems=""
    grep -q '{{' <<<"$body" && problems="$problems 有占位符残留;"
    # 画幅必须出现在产物里
    aspect_ok=$(python3 -c "
import asset_lib as a
plat = a.load_platform('$p')
pre  = a.load_preset('$s')
slot = a.archetype_slot(plat, pre['archetype'])
asp = slot['aspect']
asp = asp if isinstance(asp, list) else [asp]
body = open('$TMP/$p-$s.md', encoding='utf-8').read()
print('yes' if any(x in body for x in asp) else 'no')
")
    [[ "$aspect_ok" == "yes" ]] || problems="$problems 画幅未注入;"
    # 文字策略必须出现（要么要求放标题，要么明确不放）
    grep -qE '图上必须包含|图上不要出现标题文字' <<<"$body" || problems="$problems 文字策略未注入;"

    if [[ -z "$problems" ]]; then
      echo "  ✅ $p × $s"; PASS=$((PASS+1))
    else
      echo "  ❌ $p × $s →$problems"; FAIL=$((FAIL+1))
    fi
  done
done

echo
echo "通过 $PASS 项，失败 $FAIL 项"
[[ $FAIL -eq 0 ]]
