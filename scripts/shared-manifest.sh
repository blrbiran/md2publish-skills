#!/usr/bin/env bash
# _shared/ 的 vendor 子集清单。**唯一定义处**——sync 与 drift 两个脚本都 source 它。
# 清单写两份必然漂移，spec §4.3 的表格只是文档，这里才是真相。

SHARED_SKILLS=("md2publish-cover" "md2publish-visuals" "md2publish-diagram")
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
    md2publish-visuals)
      # 与 cover 同构，另加 writeback.py（回写门）
      echo "platforms presets costs.yaml \
scripts/asset_lib.py scripts/compose_prompt.py scripts/compress.py \
scripts/config.py scripts/preflight.py scripts/artifacts.py \
scripts/writeback.py scripts/imagegen"
      ;;
    md2publish-diagram)
      # 刻意比另两个小得多：diagram 不调 AI，因此不带 imagegen（一整个 TS 引擎）、
      # 不带 presets/costs.yaml/config.py/preflight.py（没有 provider 可查）。
      # asset_lib.py 仍要带——artifacts.py 硬 import 它，且画幅要从 platform profile 取。
      # scripts/fixtures/diagram-sample.svg 也要带：SKILL.md 步骤 3 把它当样例引用，
      # 且它同时是 test-svg2raster.sh 的 fixture，vendor 里没有这个文件就是死链接。
      # scripts/writeback.py 也要带：diagram 的图要插进正文时，回写门必须是本 skill
      # 能独立跑的东西，而不是要求 agent 跨去 visuals 目录、顺带跑一遍它的付费流水线。
      # writeback.py 只硬 import artifacts / asset_lib，两者都已经在这份清单里，
      # 不必因此带上 imagegen/presets/costs.yaml/config.py 这些付费专属资产。
      echo "platforms \
scripts/asset_lib.py scripts/artifacts.py scripts/compress.py scripts/svg2raster.py \
scripts/writeback.py scripts/fixtures/diagram-sample.svg"
      ;;
    *)
      echo "未知 skill: $1" >&2
      return 1
      ;;
  esac
}
