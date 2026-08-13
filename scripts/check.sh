#!/usr/bin/env bash
# 图片能力线的全部检查。对应 spec §13 的五项 + 引擎测试。
#
# **这不是自动闸门。** 本仓库没有 CI、没有 git hooks。改了 skills/_shared/
# 或 md2publish-cover 之后，靠你自己记得跑这一条。
set -uo pipefail
cd "$(dirname "$0")/.."

FAILED=()
SKIPPED=()
TOTAL=0

run() {
  local label="$1"; shift
  TOTAL=$((TOTAL+1))
  echo
  echo "───── $label ─────"
  "$@"
  local rc=$?
  if [[ $rc -eq 0 ]]; then
    echo "  ✓ $label"
  elif [[ $rc -eq 2 ]]; then
    echo "  ⊘ ${label}：SKIPPED"
    SKIPPED+=("$label")
  else
    echo "  ✗ $label"
    FAILED+=("$label")
  fi
}

run "资产 schema + costs（spec §13 第 3 项）" bash skills/_shared/scripts/test-asset-schema.sh
run "渲染器 + 占位符白名单（第 2 项）"        bash skills/_shared/scripts/test-compose-prompt.sh
run "平台 × archetype × preset 矩阵（第 1 项）" bash skills/_shared/scripts/test-platform-matrix.sh
run "压缩不超限（第 4 项）"                   bash skills/_shared/scripts/test-compress.sh
run "preflight + config"                      python3 skills/_shared/scripts/test-preflight.py
run "产物落盘规则"                            bash skills/_shared/scripts/test-artifacts.sh
run "Markdown 回写门"                         bash skills/_shared/scripts/test-writeback.sh
run "SVG→位图降级链"                          bash skills/_shared/scripts/test-svg2raster.sh
run "imagegen 引擎"                           bash -c 'cd skills/_shared/scripts/imagegen && bun test'
run "diagram 端到端（零成本）"                 bash scripts/test-diagram-e2e.sh
# 顺序有意义：漂移检查必须排在同步行为测试**之前**。
# test-sync-drift.sh 如今在沙箱副本里跑、不碰工作区，但即便如此也别把它挪到前面——
# 它做的第一件事是 sync-shared.sh，谁要是哪天把它改回原地跑，真实漂移就会在
# 第 9 项看见它之前被冲掉，而 design §4.3 明说漂移**绝不能靠 re-sync 解决**。
run "shared 漂移检查"                         bash scripts/check-shared-drift.sh
run "vendor 同步与漂移（第 5 项）"            bash scripts/test-sync-drift.sh

echo
if [[ ${#FAILED[@]} -eq 0 ]]; then
  if [[ ${#SKIPPED[@]} -eq 0 ]]; then
    echo "全部通过（${TOTAL} 项）。"
  else
    PASSED=$((TOTAL - ${#SKIPPED[@]}))
    echo "${PASSED} 项通过，${#SKIPPED[@]} 项跳过：$(IFS=、; echo "${SKIPPED[*]}")。"
    echo "跳过的项**没有跑过**，不等于通过。装齐工具后重跑。"
  fi
  echo
  echo "注意：还有两项**不在这里**——真调一次 provider 生一张图的最小 smoke"
  echo "（cover 与 visuals 各一次）。它们计费，因此永远手动跑，"
  echo "见 docs/handoff/handoff-image.md。"
  exit 0
fi

echo "失败 ${#FAILED[@]} 项："
printf '  - %s\n' "${FAILED[@]}"
if [[ ${#SKIPPED[@]} -gt 0 ]]; then
  echo
  echo "另有 ${#SKIPPED[@]} 项跳过（没有真正跑过，不算通过也不算失败）：$(IFS=、; echo "${SKIPPED[*]}")"
fi
exit 1
