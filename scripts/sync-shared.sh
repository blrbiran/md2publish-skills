#!/usr/bin/env bash
# skills/_shared/ → skills/<skill>/shared/。按清单只拷子集，不是全量三份。
#
# 本脚本会删除并重建目标目录。这是受控的：只删自己生成的目录，
# 靠 .synced-from-shared 标记确认；目录存在但没有标记时硬失败，绝不猜。
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/shared-manifest.sh

SHARED=skills/_shared

sync_one() {
  local skill="$1"
  local dest="skills/$skill/shared"
  local items
  items=$(shared_items_for "$skill")

  if [[ -e "$dest" && ! -e "$dest/$SYNC_MARKER" ]]; then
    echo "拒绝写 $dest：它存在但没有 $SYNC_MARKER 标记。" >&2
    echo "本脚本只重建自己生成的目录。确认里面没有手写内容后，自行删掉它再跑。" >&2
    return 1
  fi

  rm -rf "$dest"
  mkdir -p "$dest"
  for item in $items; do
    mkdir -p "$dest/$(dirname "$item")"
    \cp -Rf "$SHARED/$item" "$dest/$item"
  done

  find "$dest" -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true
  find "$dest" -name '.ccmem' -type d -prune -exec rm -rf {} + 2>/dev/null || true
  find "$dest" -name '.DS_Store' -delete 2>/dev/null || true

  cat > "$dest/$SYNC_MARKER" <<'EOF'
本目录由 scripts/sync-shared.sh 从 skills/_shared/ 生成，不要手改。
要改内容请改 skills/_shared/ 下的对应文件，然后重新跑 scripts/sync-shared.sh。
EOF

  echo "已同步 ${skill}（$(find "$dest" -type f | wc -l | tr -d ' ') 个文件）"
}

for skill in "${SHARED_SKILLS[@]}"; do
  sync_one "$skill"
done
