#!/usr/bin/env bash
# writeback.py 测试。对应 spec §9（改源文件的门）与三期 D16。
set -uo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM

PASS=0
FAIL=0
ok()  { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad() { echo "  ❌ $1"; echo "     $2"; FAIL=$((FAIL+1)); }

ART="$TMP/article-dir"
mkdir -p "$ART/assets/wechat"
SRC="$ART/article.wechat.md"
OUT="$ART/article.illustrated.md"
ASSETS="$ART/assets/wechat"

cat > "$SRC" <<'EOF'
# 缓存失效

开篇一段。

## 三种写法

正文一段。

## 取舍

结尾一段。

## 三种写法

这一行是故意重复的小标题，用来验证多重命中会被拦住。
EOF

printf 'fake' > "$ASSETS/01-illustration.jpg"
SRC_BEFORE=$(cksum < "$SRC")

ins() { printf '%s' "$1" > "$TMP/ins.json"; }
runwb() { python3 writeback.py --source "$SRC" --insertions "$TMP/ins.json" \
            --assets-dir "$ASSETS" --out "$OUT" "$@" 2>&1; }

echo "== 正常插入 =="

ins '[{"anchor": "## 取舍", "position": "after", "image": "01-illustration.jpg", "alt": "三种写法对比"}]'
out=$(runwb)
rc=$?
if [[ $rc -eq 0 && -f "$OUT" ]] && grep -q '!\[三种写法对比\](assets/wechat/01-illustration.jpg)' "$OUT"; then
  ok "插入了正确的 Markdown 图片引用，路径相对文章目录"
else
  bad "回写产物不对" "rc=${rc} out=${out}"
fi

anchor_line=$(grep -n '^## 取舍' "$OUT" | head -1 | cut -d: -f1)
img_line=$(grep -n '!\[三种写法对比\]' "$OUT" | head -1 | cut -d: -f1)
if [[ -n "${anchor_line}" && -n "${img_line}" && ${img_line} -gt ${anchor_line} ]]; then
  ok "position=after 时图片在锚点行之后"
else
  bad "插入位置不对" "anchor=${anchor_line} img=${img_line}"
fi

if [[ "$(cksum < "$SRC")" == "$SRC_BEFORE" ]]; then
  ok "源文件一字节未动（spec §9：原文不动，另存）"
else
  bad "改了源文件" "before=${SRC_BEFORE} after=$(cksum < "$SRC")"
fi

echo
echo "== 重跑保护 =="

out=$(runwb)
if [[ $? -ne 0 ]] && grep -q 'article.illustrated.md' <<<"$out"; then
  ok "--out 已存在时拦住并报出路径"
else
  bad "已存在却直接覆盖" "$out"
fi

out=$(runwb --force)
[[ $? -eq 0 ]] && ok "--force 时放行" || bad "--force 未生效" "$out"

echo
echo "== 锚点 =="

rm -f "$OUT"
ins '[{"anchor": "## 不存在的小标题", "position": "after", "image": "01-illustration.jpg", "alt": "x"}]'
out=$(runwb)
if [[ $? -ne 0 ]] && grep -q '不存在的小标题' <<<"$out" && grep -q '0' <<<"$out"; then
  ok "锚点 0 次命中时硬失败并把锚点原文打出来"
else
  bad "找不到锚点却继续了" "$out"
fi

ins '[{"anchor": "## 三种写法", "position": "after", "image": "01-illustration.jpg", "alt": "x"}]'
out=$(runwb)
if [[ $? -ne 0 ]] && grep -q '命中 2 次' <<<"$out"; then
  ok "锚点 2 次命中时硬失败（插错位置比不插更难发现）"
else
  bad "多重命中却挑了一个插" "$out"
fi

echo
echo "== 图片引用 =="

ins '[{"anchor": "## 取舍", "position": "after", "image": "99-missing.jpg", "alt": "x"}]'
out=$(runwb)
if [[ $? -ne 0 ]] && grep -q '99-missing.jpg' <<<"$out"; then
  ok "引用的图不在 assets-dir 时硬失败并点名（正文会引到不存在的文件）"
else
  bad "引用了不存在的图" "$out"
fi

ins '[{"anchor": "## 取舍", "position": "after", "image": "assets/wechat/01-illustration.jpg", "alt": "x"}]'
out=$(runwb)
if [[ $? -ne 0 ]] && grep -q '文件名' <<<"$out"; then
  ok "image 写成路径时硬失败（路径由 --assets-dir 决定，写两遍必然打架）"
else
  bad "接受了路径形式的 image" "$out"
fi

echo
echo "== schema =="

ins '[{"anchor": "## 取舍", "position": "after", "image": "01-illustration.jpg", "alt": "x", "postion": "before"}]'
out=$(runwb)
if [[ $? -ne 0 ]] && grep -q 'postion' <<<"$out"; then
  ok "未知字段硬失败并点名（拼错的键静默丢失最难查）"
else
  bad "未知字段被静默忽略" "$out"
fi

echo
echo "== --dry-run（回写门的预览） =="

rm -f "$OUT"
ins '[{"anchor": "## 取舍", "position": "before", "image": "01-illustration.jpg", "alt": "对比图"}]'
out=$(runwb --dry-run)
if [[ $? -eq 0 ]] && [[ ! -e "$OUT" ]] && grep -q '^+.*01-illustration.jpg' <<<"$out"; then
  ok "--dry-run 打印 diff 但不写文件"
else
  bad "--dry-run 写了文件或没打 diff" "$out"
fi

out=$(runwb)
img_line=$(grep -n '!\[对比图\]' "$OUT" | head -1 | cut -d: -f1)
anchor_line=$(grep -n '^## 取舍' "$OUT" | head -1 | cut -d: -f1)
if [[ -n "${img_line}" && -n "${anchor_line}" && ${img_line} -lt ${anchor_line} ]]; then
  ok "position=before 时图片在锚点行之前"
else
  bad "before 位置不对" "anchor=${anchor_line} img=${img_line}"
fi

echo
echo "== 多图（back-to-front 插入顺序） =="

rm -f "$OUT"
printf 'fake' > "$ASSETS/02-middle.jpg"
printf 'fake' > "$ASSETS/03-end.jpg"
ins '[
  {"anchor": "开篇一段。", "position": "after", "image": "01-illustration.jpg", "alt": "开篇配图"},
  {"anchor": "## 取舍", "position": "before", "image": "02-middle.jpg", "alt": "取舍前配图"},
  {"anchor": "结尾一段。", "position": "after", "image": "03-end.jpg", "alt": "结尾配图"}
]'
out=$(runwb)
rc=$?
front_anchor=$(grep -n -F '开篇一段。' "$OUT" | head -1 | cut -d: -f1)
front_img=$(grep -n -F '![开篇配图]' "$OUT" | head -1 | cut -d: -f1)
mid_anchor=$(grep -n '^## 取舍' "$OUT" | head -1 | cut -d: -f1)
mid_img=$(grep -n -F '![取舍前配图]' "$OUT" | head -1 | cut -d: -f1)
end_anchor=$(grep -n -F '结尾一段。' "$OUT" | head -1 | cut -d: -f1)
end_img=$(grep -n -F '![结尾配图]' "$OUT" | head -1 | cut -d: -f1)
if [[ $rc -eq 0 \
      && -n "${front_anchor}" && -n "${front_img}" && ${front_img} -gt ${front_anchor} \
      && -n "${mid_anchor}"   && -n "${mid_img}"   && ${mid_img}   -lt ${mid_anchor} \
      && -n "${end_anchor}"   && -n "${end_img}"   && ${end_img}   -gt ${end_anchor} ]]; then
  ok "三条 insertion 分布在前中后时各自落在自己锚点的正确一侧（从后往前插入不会互相顶偏）"
else
  bad "多图插入位置错乱" "rc=${rc} front=${front_anchor}/${front_img} mid=${mid_anchor}/${mid_img} end=${end_anchor}/${end_img} out=${out}"
fi

echo
echo "通过 $PASS 项，失败 $FAIL 项"
[[ $FAIL -eq 0 ]]
