#!/usr/bin/env bash
# 图片能力线的全部检查。对应 spec §13 的五项 + 引擎测试。
#
# **这不是自动闸门。** 本仓库没有 CI、没有 git hooks。改了 skills/_shared/
# 或 md2publish-cover 之后，靠你自己记得跑这一条。
set -uo pipefail
cd "$(dirname "$0")/.."

FAILED=()

run() {
  local label="$1"; shift
  echo
  echo "───── $label ─────"
  if "$@"; then
    echo "  ✓ $label"
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
run "imagegen 引擎"                           bash -c 'cd skills/_shared/scripts/imagegen && bun test'
run "vendor 同步与漂移（第 5 项）"            bash scripts/test-sync-drift.sh
run "shared 漂移检查"                         bash scripts/check-shared-drift.sh

echo
if [[ ${#FAILED[@]} -eq 0 ]]; then
  echo "全部通过。"
  echo
  echo "注意：有一项**不在这里**——真调一次 provider 生一张图的最小 smoke。"
  echo "它计费，因此永远手动跑，见 docs/handoff/handoff-image.md。"
  exit 0
fi

echo "失败 ${#FAILED[@]} 项："
printf '  - %s\n' "${FAILED[@]}"
exit 1
