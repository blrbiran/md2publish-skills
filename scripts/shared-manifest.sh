#!/usr/bin/env bash
# _shared/ 的 vendor 子集清单。**唯一定义处**——sync 与 drift 两个脚本都 source 它。
# 清单写两份必然漂移，spec §4.3 的表格只是文档，这里才是真相。

SHARED_SKILLS=("md2publish-cover")
SYNC_MARKER=".synced-from-shared"

# 相对 skills/_shared/ 的路径，空格分隔。
# 注意 scripts/asset_lib.py：spec §4.3 的表格漏了它，但它是 compose_prompt.py
# 与 artifacts.py 的硬 import 依赖，不带上 vendor 出来的 skill 直接不能跑。
shared_items_for() {
  case "$1" in
    md2publish-cover)
      echo "platforms presets costs.yaml \
scripts/asset_lib.py scripts/compose_prompt.py scripts/compress.py \
scripts/config.py scripts/preflight.py scripts/artifacts.py scripts/imagegen"
      ;;
    *)
      echo "未知 skill: $1" >&2
      return 1
      ;;
  esac
}
