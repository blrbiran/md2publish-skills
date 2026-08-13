#!/usr/bin/env bash
# diagram 的零成本端到端：写好的 SVG → 光栅化 → sidecar → 人为触发压缩 → sidecar
# 用压缩产物覆盖同一份，证明下游真的会读到压缩后的文件而不是超限的原图。
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
SIDE="$ART/assets/wechat/00-diagram.json"
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
echo "== sidecar（未压缩产物）=="

SIDE_OUT1=$(python3 "$S/artifacts.py" sidecar --image "$PNG" \
  --platform wechat --archetype diagram --provider "${BACKEND}" \
  --source-file "$(basename "$SVG")" --alt-text "三层缓存架构示意图" 2>&1)
side1_rc=$?
if [[ $side1_rc -eq 0 && -f "${SIDE}" ]]; then
  got=$(python3 -c "import json;d=json.load(open('${SIDE}'));print(d['image'],d['source_file'],d['provider'],d['preset'])")
  if [[ "${got}" == "00-diagram.png 00-diagram.svg ${BACKEND} None" ]]; then
    ok "sidecar 四个关键字段都对（image / source_file / provider / preset=null）"
  else
    bad "sidecar 字段不对" "got=${got}"
  fi
else
  bad "sidecar 没写出来" "rc=${side1_rc} out=${SIDE_OUT1}"
fi

echo
echo "== 压缩 =="

BYTES=$(wc -c < "$PNG" | tr -d ' ')
if [[ ${BYTES} -le ${MAXB} ]]; then
  ok "光栅化产物在平台预算内（${BYTES} ≤ ${MAXB} 字节，预算来自 wechat/diagram 槽位的真实配置，不是硬编码）"
else
  bad "光栅化产物超出平台预算" "bytes=${BYTES} max=${MAXB}"
fi

# 是否触发压缩这件事本身没有代码分支——只活在 SKILL.md 的散文里，由 agent 执行。
# 所以下面不测"该不该压"，而是用一个人为的小上限，把压缩这条代码路径真跑一遍，
# 并验证它的产物真的被写回同一份 sidecar（这才是这条链名副其实的地方）。
#
# 上限必须**严格小于**光栅化产物的实际字节数，否则 compress.py 会走
# action=none 的空转分支、原样返回原图路径——那样 $OUT 会等于 $PNG，
# 下面整段"压缩产物覆盖 sidecar"的验证就是在自欺（这台机器上真实踩过：
# 固定 20000 曾经比 18914 字节的原图还大）。用实际字节数的 90% 保证既严格
# 更小，又比压缩阶梯能压到的下限（本机实测约为原图的 75%）宽松，不会把
# 压缩本身逼到失败。
PNG_CKSUM_BEFORE=$(cksum < "$PNG")
SMALL=$(( BYTES * 9 / 10 ))
OUT=$(python3 "$S/compress.py" --image "$PNG" --max-bytes "${SMALL}" 2>&1)
comp_rc=$?
if [[ $comp_rc -eq 0 && -f "${OUT}" ]] && [[ "$(wc -c < "${OUT}" | tr -d ' ')" -le ${SMALL} ]]; then
  ok "人为压到 ${SMALL} 字节以内也成立（压缩这条分支真跑过）"
else
  bad "压缩分支失败" "rc=${comp_rc} out=${OUT}"
fi

PNG_CKSUM_AFTER=$(cksum < "$PNG")
if [[ -f "$PNG" && "${PNG_CKSUM_BEFORE}" == "${PNG_CKSUM_AFTER}" ]]; then
  ok "压缩没有动原始 PNG（压缩前后 cksum 一致，不只是文件还在）"
else
  bad "原始 PNG 被动过或丢失" "before=${PNG_CKSUM_BEFORE} after=${PNG_CKSUM_AFTER}"
fi

echo
echo "== sidecar（压缩产物覆盖同一份）=="

SIDE_OUT2=$(python3 "$S/artifacts.py" sidecar --image "${OUT}" \
  --platform wechat --archetype diagram --provider "${BACKEND}" \
  --source-file "$(basename "$SVG")" --alt-text "三层缓存架构示意图" 2>&1)
side2_rc=$?
if [[ $side2_rc -eq 0 && -f "${SIDE}" ]]; then
  got2=$(python3 -c "import json;d=json.load(open('${SIDE}'));print(d['image'])")
  if [[ "${got2}" == "$(basename "${OUT}")" ]]; then
    ok "压缩后重写 sidecar，image 字段指向压缩产物（${got2}），不是超限的原始 PNG"
  else
    bad "sidecar 的 image 字段没有跟着压缩产物走" "got=${got2}"
  fi
else
  bad "压缩后写 sidecar 失败" "rc=${side2_rc} out=${SIDE_OUT2}"
fi

n_json=$(find "$ART/assets/wechat" -maxdepth 1 -name '*.json' | wc -l | tr -d ' ')
if [[ "${n_json}" == "1" ]]; then
  ok "压缩前后写的是同一份 sidecar（没有多出第二份 .json）"
else
  bad "sidecar 文件数不对，压缩前后应该始终只有一份" "count=${n_json}"
fi

echo
echo "通过 $PASS 项，失败 $FAIL 项"
[[ $FAIL -eq 0 ]]
