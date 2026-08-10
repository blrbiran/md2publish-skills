#!/usr/bin/env bash
# 比对各 skill 的 shared/ 与 _shared/ 是否一致。
#
# 漂移的正确处理**永远是**"你的改动改错地方了，把它挪回 _shared/ 再 re-sync"，
# 绝不是"re-sync 覆盖掉"——后者会静默丢掉别人写在 vendor 副本里的改动。
# 因此这里必须打印那句话和 diff，不能只 exit 1。
set -uo pipefail
cd "$(dirname "$0")/.."
source scripts/shared-manifest.sh

SHARED=skills/_shared
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

DRIFTED=0

for skill in "${SHARED_SKILLS[@]}"; do
  dest="skills/$skill/shared"
  expected="$TMP/$skill"

  if [[ ! -d "$dest" ]]; then
    echo "❌ ${skill}：$dest 不存在。跑 scripts/sync-shared.sh。"
    DRIFTED=1
    continue
  fi

  mkdir -p "$expected"
  for item in $(shared_items_for "$skill"); do
    mkdir -p "$expected/$(dirname "$item")"
    \cp -Rf "$SHARED/$item" "$expected/$item"
  done
  find "$expected" -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true
  find "$expected" -name '.ccmem' -type d -prune -exec rm -rf {} + 2>/dev/null || true
  find "$expected" -name '.DS_Store' -delete 2>/dev/null || true

  if diff -r -x "$SYNC_MARKER" -x '__pycache__' "$expected" "$dest" > "$TMP/$skill.diff" 2>&1; then
    echo "✅ ${skill}：与 _shared/ 一致"
  else
    DRIFTED=1
    echo "❌ ${skill}：与 _shared/ 不一致"
    echo
    echo "   怎么处理：**把你的改动挪回 skills/_shared/ 里的对应文件，再跑"
    echo "   scripts/sync-shared.sh**。不要反过来用 re-sync 覆盖掉 —— 那会静默"
    echo "   丢掉写在 vendor 副本里的改动。_shared/ 是唯一真相源。"
    echo
    sed 's/^/   /' "$TMP/$skill.diff"
    echo
  fi
done

exit $DRIFTED
