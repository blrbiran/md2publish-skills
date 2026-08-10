#!/usr/bin/env bash
# sync-shared.sh / check-shared-drift.sh 的行为测试。对应 spec §13 第 5 项。
set -uo pipefail
cd "$(dirname "$0")/.."

PASS=0
FAIL=0
ok()  { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad() { echo "  ❌ $1"; echo "     $2"; FAIL=$((FAIL+1)); }

DEST=skills/md2publish-cover/shared

echo "== sync =="

./scripts/sync-shared.sh >/dev/null 2>&1
[[ $? -eq 0 ]] && ok "sync 成功" || bad "sync 失败" "$(./scripts/sync-shared.sh 2>&1 | tail -3)"

missing=""
for f in platforms/wechat.yaml presets/INDEX.md costs.yaml \
         scripts/asset_lib.py scripts/compose_prompt.py scripts/compress.py \
         scripts/config.py scripts/preflight.py scripts/artifacts.py \
         scripts/imagegen/main.ts scripts/imagegen/providers/openai.ts; do
  [[ -e "$DEST/$f" ]] || missing="$missing $f"
done
[[ -z "$missing" ]] && ok "清单里的关键文件都到位" || bad "vendor 缺文件" "$missing"

[[ -e "$DEST/$(bash -c 'source scripts/shared-manifest.sh; echo $SYNC_MARKER')" ]] \
  && ok "写了 .synced-from-shared 标记" || bad "缺标记文件" ""

[[ ! -e "$DEST/scripts/test-compose-prompt.sh" ]] \
  && ok "测试脚本不进 vendor（测试留在 _shared）" || bad "把测试也拷过去了" ""

echo
echo "== vendor 出来的副本能独立跑 =="

ROOT=$(pwd)
out=$(cd "$DEST/scripts" && python3 compose_prompt.py --platform wechat --preset editorial-warm \
        --brief-file "$ROOT/skills/_shared/scripts/fixtures/brief-sample.md" \
        --out /tmp/mp-vendor-check.md 2>&1)
if [[ $? -eq 0 && -s /tmp/mp-vendor-check.md ]]; then
  ok "vendor 副本里的 compose_prompt.py 能跑（asset_lib 依赖没漏）"
else
  bad "vendor 副本跑不起来" "$out"
fi
rm -f /tmp/mp-vendor-check.md

echo
echo "== drift =="

./scripts/check-shared-drift.sh >/dev/null 2>&1
[[ $? -eq 0 ]] && ok "刚同步完无漂移" || bad "刚同步完就报漂移" "$(./scripts/check-shared-drift.sh 2>&1 | tail -5)"

echo "# drift probe" >> "$DEST/scripts/compress.py"
out=$(./scripts/check-shared-drift.sh 2>&1)
rc=$?
if [[ $rc -ne 0 ]] && grep -q '挪回' <<<"$out" && grep -q 'compress.py' <<<"$out"; then
  ok "改了 vendor 副本时报漂移，并给出'挪回 _shared'的指示"
else
  bad "漂移未被发现或提示不对" "rc=$rc out=$(tail -5 <<<"$out")"
fi

./scripts/sync-shared.sh >/dev/null 2>&1     # 恢复
./scripts/check-shared-drift.sh >/dev/null 2>&1
[[ $? -eq 0 ]] && ok "re-sync 后恢复干净" || bad "re-sync 未恢复" ""

echo
echo "通过 $PASS 项，失败 $FAIL 项"
[[ $FAIL -eq 0 ]]
