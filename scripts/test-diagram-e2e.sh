#!/usr/bin/env bash
# diagram 的零成本端到端：写好的 SVG → 光栅化 → 压缩 → sidecar。
#
# **退出码 2 表示 SKIPPED**（一个光栅化后端都没有）。check.sh 靠它区分
# "跑过并通过"和"根本没跑"——把没跑过的项算成通过，就是二期 A 教训 4 的假绿。
#
# 为什么这一项值得端到端跑：本仓库另外两条链路（cover / visuals）都要花钱，
# 端到端只能挂账手动。diagram 零成本，它是唯一能自动化验证的完整链路。
set -uo pipefail
cd "$(dirname "$0")/.."

if [[ "$(python3 skills/_shared/scripts/svg2raster.py --check --json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["backends"]))')" == "0" ]]; then
  echo "  ⊘ SKIPPED：rsvg-convert / magick / chrome 一个都没有。"
  echo "     装其中一个即可让这一项真跑：brew install librsvg"
  exit 2
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM

PASS=0
FAIL=0
ok()  { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad() { echo "  ❌ $1"; echo "     $2"; FAIL=$((FAIL+1)); }

S=skills/_shared/scripts
ART="$TMP/article"
mkdir -p "$ART/diagrams/wechat" "$ART/assets/wechat"
SVG="$ART/diagrams/wechat/00-diagram.svg"
PNG="$ART/assets/wechat/00-diagram.png"
\cp -f "$S/fixtures/diagram-sample.svg" "$SVG"

ASPECT=$(python3 -c "import sys; sys.path.insert(0,'${S}'); import asset_lib as a; s=a.archetype_slot(a.load_platform('wechat'),'diagram'); print(s['aspect'][0] if isinstance(s['aspect'],list) else s['aspect'])")
MAXB=$(python3 -c "import sys; sys.path.insert(0,'${S}'); import asset_lib as a; print(a.archetype_slot(a.load_platform('wechat'),'diagram')['max_bytes'])")

echo "== 光栅化 =="

RASTER=$(python3 "$S/svg2raster.py" --svg "$SVG" --out "$PNG" --aspect "${ASPECT}" --json 2>&1)
rc=$?
if [[ $rc -eq 0 && -s "$PNG" ]]; then
  BACKEND=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['backend'])" "${RASTER}")
  ok "SVG → PNG 成功（后端：${BACKEND}）"
else
  bad "光栅化失败" "rc=${rc} out=${RASTER}"
  BACKEND=unknown
fi

echo
echo "== 压缩 =="

BYTES=$(wc -c < "$PNG" | tr -d ' ')
if [[ ${BYTES} -le ${MAXB} ]]; then
  ok "未超平台上限（${BYTES} ≤ ${MAXB}），按流程跳过压缩"
else
  bad "光栅化产物超限，流程要求此处压缩" "bytes=${BYTES} max=${MAXB}"
fi

# 上一条大概率走"不压缩"分支，所以再用一个人为的小上限把压缩这条路也真跑一遍
SMALL=20000
OUT=$(python3 "$S/compress.py" --image "$PNG" --max-bytes "${SMALL}" 2>&1)
if [[ $? -eq 0 && -f "${OUT}" ]] && [[ "$(wc -c < "${OUT}" | tr -d ' ')" -le ${SMALL} ]]; then
  ok "人为压到 ${SMALL} 字节以内也成立（压缩这条分支真跑过）"
else
  bad "压缩分支失败" "$OUT"
fi
[[ -f "$PNG" ]] && ok "压缩没有动原始 PNG（它是新增不是替换）" || bad "原始 PNG 不见了" ""

echo
echo "== sidecar =="

python3 "$S/artifacts.py" sidecar --image "$PNG" \
  --platform wechat --archetype diagram --provider "${BACKEND}" \
  --source-file "$(basename "$SVG")" --alt-text "三层缓存架构示意图" >/dev/null 2>&1
SIDE="$ART/assets/wechat/00-diagram.json"
if [[ -f "${SIDE}" ]]; then
  got=$(python3 -c "import json;d=json.load(open('${SIDE}'));print(d['image'],d['source_file'],d['provider'],d['preset'])")
  if [[ "${got}" == "00-diagram.png 00-diagram.svg ${BACKEND} None" ]]; then
    ok "sidecar 四个关键字段都对（image / source_file / provider / preset=null）"
  else
    bad "sidecar 字段不对" "got=${got}"
  fi
else
  bad "sidecar 没写出来" ""
fi

echo
echo "通过 $PASS 项，失败 $FAIL 项"
[[ $FAIL -eq 0 ]]
