#!/usr/bin/env bash
# sync-shared.sh / check-shared-drift.sh 的行为测试。对应 spec §13 第 5 项。
#
# **全程在临时沙箱副本里跑，绝不碰真实工作区。** 两条理由，都不是洁癖：
#
# 1. 本测试必须故意制造一次漂移才能验证漂移检查有效。在真实工作区里做，就意味着
#    它开头那句 sync-shared.sh 会先把**别人真实的漂移**冲掉——`check.sh` 里紧随其后
#    的漂移检查从此永远不可能失败，而 design §4.3 明说漂移是 vendoring 唯一的真实
#    失败模式，且**绝不能靠 re-sync 解决**。
# 2. 半途被打断（Ctrl-C、超时）时不会在真实工作区留下一个被改过的 vendor 副本。
#    这个仓库里可能有另一个 agent 在同时提交，脏文件会被顺手带进他的 commit。
set -uo pipefail
cd "$(dirname "$0")/.."
REPO=$(pwd)

PASS=0
FAIL=0
ok()  { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad() { echo "  ❌ $1"; echo "     $2"; FAIL=$((FAIL+1)); }

DEST=skills/md2publish-cover/shared

# 真实工作区里那份 vendor 副本的指纹。跑完要原样，证明沙箱确实隔离。
#
# 探针文件必须真的存在：不存在时 before 和 after 都会落到同一个 "缺失"，
# 两条隔离断言于是空转通过——它们号称在看的那个文件根本没被看过。实测过：
# 把 REAL_PROBE2 指向一个不存在的路径，整个脚本照样打「通过 12 项，失败 0 项」。
REAL_PROBE="$REPO/$DEST/scripts/compress.py"
REAL_PROBE2="$REPO/skills/md2publish-diagram/shared/scripts/svg2raster.py"
for probe in "$REAL_PROBE" "$REAL_PROBE2"; do
  if [[ ! -f "${probe}" ]]; then
    # 当场退出，别往下跑：探针没了，后面那两条隔离断言的 before / after 会双双
    # 落到 "缺失" 而打出 ✅，一份既报错又报通过的输出比只报错更难判读。
    bad "隔离探针文件不存在，隔离断言会空转" "${probe}"
    exit 1
  fi
done

REAL_BEFORE=$(cksum < "$REAL_PROBE" 2>/dev/null || echo "缺失")
REAL_BEFORE2=$(cksum < "$REAL_PROBE2" 2>/dev/null || echo "缺失")

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

mkdir -p "$SANDBOX/skills"
\cp -Rf "$REPO/scripts" "$SANDBOX/scripts"
\cp -Rf "$REPO/skills/_shared" "$SANDBOX/skills/_shared"
source "$REPO/scripts/shared-manifest.sh"
for s in "${SHARED_SKILLS[@]}"; do
  \cp -Rf "$REPO/skills/${s}" "$SANDBOX/skills/${s}"
done
cd "$SANDBOX"

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

missing=""
# diagram 的清单必须**更小**：它不调 AI，带上 imagegen 就是白白多 vendor 一个引擎。
if [[ ! -e "skills/md2publish-diagram/shared/scripts/imagegen" ]]; then
  ok "diagram 的 vendor 副本里没有 imagegen（它不调 AI）"
else
  bad "diagram 带上了 imagegen（多 vendor 一整个引擎）" ""
fi

for f in scripts/svg2raster.py scripts/artifacts.py scripts/compress.py platforms/wechat.yaml \
         scripts/writeback.py scripts/fixtures/diagram-sample.svg; do
  [[ -e "skills/md2publish-diagram/shared/${f}" ]] || missing="${missing} diagram:${f}"
done
for f in scripts/writeback.py scripts/compose_prompt.py scripts/imagegen/main.ts presets/INDEX.md; do
  [[ -e "skills/md2publish-visuals/shared/${f}" ]] || missing="${missing} visuals:${f}"
done
[[ -z "${missing}" ]] && ok "两个新 skill 的清单都到位" || bad "新 skill 的 vendor 缺文件" "${missing}"

echo
echo "== vendor 出来的副本能独立跑 =="

out=$(cd "$DEST/scripts" && python3 compose_prompt.py --platform wechat --preset editorial-warm \
        --brief-file "$SANDBOX/skills/_shared/scripts/fixtures/brief-sample.md" \
        --out "$SANDBOX/vendor-check.md" 2>&1)
if [[ $? -eq 0 && -s "$SANDBOX/vendor-check.md" ]]; then
  ok "vendor 副本里的 compose_prompt.py 能跑（asset_lib 依赖没漏）"
else
  bad "vendor 副本跑不起来" "$out"
fi
rm -f "$SANDBOX/vendor-check.md"

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
echo "== 沙箱隔离 =="

REAL_AFTER=$(cksum < "$REAL_PROBE" 2>/dev/null || echo "缺失")
if [[ "$REAL_BEFORE" == "$REAL_AFTER" ]]; then
  ok "真实工作区的 vendor 副本全程未被改动（漂移探针只落在沙箱里）"
else
  bad "本测试改到了真实工作区" "before=${REAL_BEFORE} after=${REAL_AFTER}"
fi

REAL_AFTER2=$(cksum < "$REAL_PROBE2" 2>/dev/null || echo "缺失")
if [[ "$REAL_BEFORE2" == "$REAL_AFTER2" ]]; then
  ok "diagram 的 vendor 副本也全程未被改动"
else
  bad "本测试改到了 diagram 的真实 vendor 副本" "before=${REAL_BEFORE2} after=${REAL_AFTER2}"
fi

echo
echo "通过 $PASS 项，失败 $FAIL 项"
[[ $FAIL -eq 0 ]]
