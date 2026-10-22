#!/usr/bin/env bash
# query.py / cover_path.py 与它们替换掉的 SKILL.md 内联 `python3 -c "…"` 逐字节等价，
# 以及 `--confirmed-by-orca` 开关写在了该写的步骤里。
#
# 为什么要有这些脚本：内联 `python3 -c "…(…)"` 带括号，按前缀/精确匹配写的工具
# 白名单（Orca 派活时用的那种）表达不了它，所以每一条都换成了一行脚本调用。
# 换的前提是**输出一个字节都不变**——下游（`--ar "$ASPECT"`、`--max-bytes "$MAXB"`、
# sidecar 的 `--provider` / `--model`）全靠这些输出，差一个字符就是错图或错账。
# 所以这里对每一条被替换的行，把旧的内联命令原样留着，与新命令在同一份 fixture 上
# 比对 stdout 的字节，而不是拿新命令去对一个手写的期望值。
#
# 旧命令必须先跑通且非空：两边一起失败、一起输出空串时 cmp 也会说「相同」，
# 那种「等价」什么都没证明。
set -uo pipefail
cd "$(dirname "$0")"
SHARED_SCRIPTS=$(pwd)
REPO=$(cd ../../.. && pwd)

PASS=0
FAIL=0
ok()  { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad() { echo "  ❌ $1"; echo "     $2"; FAIL=$((FAIL+1)); }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM

# 沙箱：一个形如 vendor 副本的 skill 目录，命令都在它里面跑（SKILL.md 的约定）。
# costs.yaml 里真实的价目全是 unknown，只能测到 None 那一支；沙箱里把一项改成
# 数字，浮点那一支才有东西可比。改的是沙箱副本，不碰 _shared/。
SK="$TMP/skill"
mkdir -p "$SK/shared/scripts"
\cp -Rf ../platforms "$SK/shared/platforms"
\cp -f ../costs.yaml "$SK/shared/costs.yaml"
for f in ./*.py; do \cp -f "$f" "$SK/shared/scripts/"; done
perl -0pi -e 's/(  openai:\n    gpt-image-2: )unknown/${1}0.3/' "$SK/shared/costs.yaml"
if ! grep -q 'gpt-image-2: 0.3' "$SK/shared/costs.yaml"; then
  bad "沙箱 costs.yaml 没改成功，浮点价目那一支测不到" "$(grep -n -A1 'openai:' "$SK/shared/costs.yaml")"
fi

# limits 读 ~/.config/md2publish/images.yaml；改道到沙箱，绝不读写使用者的真实配置。
# 值取 7 而不是默认的 10：等于默认值时「没读配置」也会被判成等价。
export XDG_CONFIG_HOME="$TMP/xdg"
mkdir -p "$XDG_CONFIG_HOME/md2publish"
echo "max_images_per_run: 7" > "$XDG_CONFIG_HOME/md2publish/images.yaml"

# fixtures：引擎 --json 输出、光栅化 --json 输出、批量 --json 输出、sidecar
GEN='{"savedImage": "/tmp/art/assets/wechat/00-cover.png", "provider": "openai", "model": "gpt-image-2", "attempts": 1}'
RASTER='{"backend": "rsvg-convert", "out": "/tmp/art/assets/wechat/00-diagram.png"}'
BATCH='{"mode": "batch", "total": 2, "succeeded": 2, "failed": 0, "results": [{"id": "00", "provider": "openai", "model": "gpt-image-2", "success": true}, {"id": "01", "provider": "google", "model": "gemini-3-pro-image", "success": true}]}'
ART="$TMP/art"
mkdir -p "$ART/assets/wechat"
echo '{"image": "01-illustration.jpg", "alt_text": "三种写法的对比示意"}' > "$ART/assets/wechat/01-illustration.json"
echo '{"image": "00-cover.jpg"}' > "$ART/assets/wechat/00-cover.json"

# same <label> <old> <new>：两条命令都在 $SK 里 eval，stdout 落文件后逐字节比。
same() {
  local label="$1" old="$2" new="$3"
  (cd "$SK" && eval "$old") > "$TMP/old.out" 2> "$TMP/old.err"
  local orc=$?
  (cd "$SK" && eval "$new") > "$TMP/new.out" 2> "$TMP/new.err"
  local nrc=$?
  if [[ $orc -ne 0 || ! -s "$TMP/old.out" ]]; then
    bad "${label}：旧命令自己没跑通，比对无意义" "rc=$orc err=$(cat "$TMP/old.err")"
  elif [[ $nrc -ne 0 ]]; then
    bad "${label}：新命令失败" "rc=$nrc err=$(cat "$TMP/new.err")"
  elif cmp -s "$TMP/old.out" "$TMP/new.out"; then
    ok "$label → $(head -c 60 "$TMP/new.out" | tr '\n' '⏎')"
  else
    bad "${label}：输出不同" "old=$(od -c "$TMP/old.out" | head -3) new=$(od -c "$TMP/new.out" | head -3)"
  fi
}

PLATFORMS="wechat xiaohongshu bilibili"

echo "== cover =="
for PROVIDER_MODEL in "openai gpt-image-2" "agnes agnes-image"; do
  read -r PV MD <<<"$PROVIDER_MODEL"
  same "cover:130 cost $PV/$MD" \
    "python3 -c \"import sys; sys.path.insert(0,'shared/scripts'); import asset_lib as a; print(a.estimate_cost('$PV', '$MD'))\"" \
    "python3 shared/scripts/query.py cost --provider $PV --model $MD"
done
for PLATFORM in $PLATFORMS; do
  same "cover:149 aspect $PLATFORM" \
    "python3 -c \"import sys; sys.path.insert(0,'shared/scripts'); import asset_lib as a; p=a.load_platform('${PLATFORM}'); print(a.archetype_slot(p,'cover')['aspect'])\"" \
    "python3 shared/scripts/query.py slot --platform ${PLATFORM} --archetype cover --field aspect"
  same "cover:191 max_bytes $PLATFORM" \
    "python3 -c \"import sys; sys.path.insert(0,'shared/scripts'); import asset_lib as a; p=a.load_platform('${PLATFORM}'); print(a.archetype_slot(p,'cover')['max_bytes'])\"" \
    "python3 shared/scripts/query.py slot --platform ${PLATFORM} --archetype cover --field max_bytes"
done
for KEY in savedImage provider model; do
  same "cover:163-165 json stdin $KEY" \
    "python3 -c 'import json,sys; print(json.load(sys.stdin)[\"$KEY\"])' <<<\"\$GEN\"" \
    "python3 shared/scripts/query.py json --key $KEY <<<\"\$GEN\""
done

echo
echo "== diagram =="
for PLATFORM in $PLATFORMS; do
  same "diagram:67 aspect --first $PLATFORM" \
    "python3 -c \"import sys; sys.path.insert(0,'shared/scripts'); import asset_lib as a; s=a.archetype_slot(a.load_platform('\${PLATFORM}'),'diagram'); print(s['aspect'][0] if isinstance(s['aspect'],list) else s['aspect'])\"" \
    "python3 shared/scripts/query.py slot --platform \"\${PLATFORM}\" --archetype diagram --field aspect --first"
  same "diagram:68 max_bytes $PLATFORM" \
    "python3 -c \"import sys; sys.path.insert(0,'shared/scripts'); import asset_lib as a; print(a.archetype_slot(a.load_platform('\${PLATFORM}'),'diagram')['max_bytes'])\"" \
    "python3 shared/scripts/query.py slot --platform \"\${PLATFORM}\" --archetype diagram --field max_bytes"
done
same "diagram:116 json --arg backend" \
  "python3 -c \"import json,sys; print(json.loads(sys.argv[1])['backend'])\" \"\${RASTER}\"" \
  "python3 shared/scripts/query.py json --arg \"\${RASTER}\" --key backend"

echo
echo "== visuals =="
# 每个平台上实际被支持的 archetype（unsupported 的槽旧命令自己就会崩）
for PA in wechat:illustration wechat:infographic xiaohongshu:infographic xiaohongshu:series \
          bilibili:illustration bilibili:infographic; do
  PLATFORM=${PA%%:*}; ARCHETYPE=${PA##*:}
  same "visuals:123 slot json $PLATFORM/$ARCHETYPE" \
    "python3 -c \"import sys,json; sys.path.insert(0,'shared/scripts'); import asset_lib as a; print(json.dumps(a.archetype_slot(a.load_platform('\${PLATFORM}'),'\${ARCHETYPE}'),ensure_ascii=False))\"" \
    "python3 shared/scripts/query.py slot --platform \"\${PLATFORM}\" --archetype \"\${ARCHETYPE}\""
  same "visuals:214 aspect --first $PLATFORM/$ARCHETYPE" \
    "python3 -c \"import sys; sys.path.insert(0,'shared/scripts'); import asset_lib as a; v=a.archetype_slot(a.load_platform('\${PLATFORM}'),'\${ARCHETYPE}')['aspect']; print(v[0] if isinstance(v,list) else v)\"" \
    "python3 shared/scripts/query.py slot --platform \"\${PLATFORM}\" --archetype \"\${ARCHETYPE}\" --field aspect --first"
  same "visuals:269 max_bytes $PLATFORM/$ARCHETYPE" \
    "python3 -c \"import sys; sys.path.insert(0,'shared/scripts'); import asset_lib as a; print(a.archetype_slot(a.load_platform('\${PLATFORM}'),'\${ARCHETYPE}')['max_bytes'])\"" \
    "python3 shared/scripts/query.py slot --platform \"\${PLATFORM}\" --archetype \"\${ARCHETYPE}\" --field max_bytes"
done
for PROVIDER_MODEL in "openai gpt-image-2" "agnes agnes-image"; do
  read -r PV MD <<<"$PROVIDER_MODEL"
  same "visuals:192 limits $PV/$MD" \
    "python3 -c \"import sys; sys.path.insert(0,'shared/scripts'); import config, asset_lib as a; c=config.load_config(); print(c['max_images_per_run'], a.estimate_cost('$PV','$MD'))\"" \
    "python3 shared/scripts/query.py limits --provider $PV --model $MD"
done
for NN in 00 01; do
  same "visuals:244 results-id $NN" \
    "python3 -c \"import json,sys; d=json.loads(sys.argv[1]); r=next(x for x in d['results'] if str(x['id'])=='\${NN}'); print(r['provider'], r['model'])\" \"\${BATCH}\"" \
    "python3 shared/scripts/query.py json --arg \"\${BATCH}\" --results-id \"\${NN}\" --keys provider,model"
  same "visuals:290 results-id $NN (read -r)" \
    "read -r PROVIDER MODEL <<<\"\$(python3 -c \"import json,sys; d=json.loads(sys.argv[1]); r=next(x for x in d['results'] if str(x['id'])=='\${NN}'); print(r['provider'], r['model'])\" \"\${BATCH}\")\"; echo \"\$PROVIDER|\$MODEL\"" \
    "read -r PROVIDER MODEL <<<\"\$(python3 shared/scripts/query.py json --arg \"\${BATCH}\" --results-id \"\${NN}\" --keys provider,model)\"; echo \"\$PROVIDER|\$MODEL\""
done
PLATFORM=wechat
same "visuals:318 json --file image" \
  "python3 -c \"import json,sys; print(json.load(open(sys.argv[1]))['image'])\" \"\$ART/assets/\${PLATFORM}/01-illustration.json\"" \
  "python3 shared/scripts/query.py json --file \"\$ART/assets/\${PLATFORM}/01-illustration.json\" --key image"
same "json --file 非 ASCII 值" \
  "python3 -c \"import json,sys; print(json.load(open(sys.argv[1]))['alt_text'])\" \"\$ART/assets/\${PLATFORM}/01-illustration.json\"" \
  "python3 shared/scripts/query.py json --file \"\$ART/assets/\${PLATFORM}/01-illustration.json\" --key alt_text"

echo
echo "== draft =="
# draft 不是 shared skill，它的脚本在自己的 scripts/ 下；绝对与相对两种 SIDECAR 都比。
for SIDECAR in "$ART/assets/wechat/00-cover.json" "../art/assets/wechat/00-cover.json"; do
  same "draft:48 cover_path $SIDECAR" \
    "python3 -c \"import json,pathlib,sys; p=pathlib.Path(sys.argv[1]); \\
print(p.parent / json.load(p.open())['image'])\" \"$SIDECAR\"" \
    "python3 '$REPO/skills/md2publish-draft/scripts/cover_path.py' \"$SIDECAR\""
done

echo
echo "== query.py 自己的失败要响 =="
(cd "$SK" && python3 shared/scripts/query.py slot --platform wechat --archetype series --field aspect) \
  > "$TMP/u.out" 2> "$TMP/u.err"
rc=$?
if [[ $rc -ne 0 && ! -s "$TMP/u.out" ]] && grep -q 'unsupported' "$TMP/u.err"; then
  ok "unsupported 槽取字段 → 非零退出、stdout 为空、stderr 点名"
else
  bad "unsupported 槽取字段没有硬失败" "rc=$rc out=$(cat "$TMP/u.out") err=$(cat "$TMP/u.err")"
fi
(cd "$SK" && python3 shared/scripts/query.py json --arg "$BATCH" --results-id 99 --keys provider,model) \
  > "$TMP/m.out" 2> "$TMP/m.err"
rc=$?
if [[ $rc -ne 0 && ! -s "$TMP/m.out" ]]; then
  ok "不存在的 results id → 非零退出、stdout 为空"
else
  bad "不存在的 results id 没有硬失败" "rc=$rc out=$(cat "$TMP/m.out")"
fi

echo
echo "== SKILL.md 里写的就是上面比对过的那些行 =="
# 只比对命令而不看文档，文档里写的可能是另一条没被测过的命令。
expect_line() {
  local file="$1" line="$2"
  if grep -Fxq -- "$line" "$REPO/$file"; then
    ok "$file 含：${line:0:70}"
  else
    bad "$file 缺这一行" "$line"
  fi
}
C=skills/md2publish-cover/SKILL.md
D=skills/md2publish-diagram/SKILL.md
V=skills/md2publish-visuals/SKILL.md
R=skills/md2publish-draft/SKILL.md
expect_line $C 'python3 shared/scripts/query.py cost --provider <provider> --model <model>'
expect_line $C 'ASPECT=$(python3 shared/scripts/query.py slot --platform <platform> --archetype cover --field aspect)'
expect_line $C 'RAW=$(python3 shared/scripts/query.py json --key savedImage <<<"$GEN")'
expect_line $C 'PROVIDER=$(python3 shared/scripts/query.py json --key provider <<<"$GEN")'
expect_line $C 'MODEL=$(python3 shared/scripts/query.py json --key model <<<"$GEN")'
expect_line $C 'MAXB=$(python3 shared/scripts/query.py slot --platform <platform> --archetype cover --field max_bytes)'
expect_line $D 'ASPECT=$(python3 shared/scripts/query.py slot --platform "${PLATFORM}" --archetype diagram --field aspect --first)'
expect_line $D 'MAXB=$(python3 shared/scripts/query.py slot --platform "${PLATFORM}" --archetype diagram --field max_bytes)'
expect_line $D 'BACKEND=$(python3 shared/scripts/query.py json --arg "${RASTER}" --key backend)'
expect_line $V 'SLOT=$(python3 shared/scripts/query.py slot --platform "${PLATFORM}" --archetype "${ARCHETYPE}")'
expect_line $V 'python3 shared/scripts/query.py limits --provider <provider> --model <model>'
expect_line $V 'ASPECT=$(python3 shared/scripts/query.py slot --platform "${PLATFORM}" --archetype "${ARCHETYPE}" --field aspect --first)'
expect_line $V 'python3 shared/scripts/query.py json --arg "${BATCH}" --results-id "${NN}" --keys provider,model'
expect_line $V 'MAXB=$(python3 shared/scripts/query.py slot --platform "${PLATFORM}" --archetype "${ARCHETYPE}" --field max_bytes)'
expect_line $V '  read -r PROVIDER MODEL <<<"$(python3 shared/scripts/query.py json --arg "${BATCH}" --results-id "${NN}" --keys provider,model)"'
expect_line $V 'python3 shared/scripts/query.py json --file "$ART/assets/${PLATFORM}/01-illustration.json" --key image'
expect_line $R 'COVER=$(python3 scripts/cover_path.py "$SIDECAR")'

echo
echo "== SKILL.md 里不再有内联 python3 -c（依赖检查 import yaml 除外）=="
# 计数先落文件再读回（不走管道，管道会吞退出码）。
for f in "$REPO"/skills/*/SKILL.md; do
  grep -nE 'python3 +-c' "$f" > "$TMP/inline.txt"
  grep -vE "^[0-9]+:python3 -c 'import yaml'$" "$TMP/inline.txt" > "$TMP/inline-left.txt"
  n=$(wc -l < "$TMP/inline-left.txt" | tr -d ' ')
  rel=${f#"$REPO"/}
  if [[ "$n" == "0" ]]; then
    ok "${rel}：0 条内联 python3 -c"
  else
    bad "${rel}：还剩 $n 条内联 python3 -c" "$(cat "$TMP/inline-left.txt")"
  fi
done

echo
echo "== --confirmed-by-orca 写在该写的地方 =="
# 每个文件里含 `--confirmed-by-orca` 的行数要恰好等于期望值，且每个点名的步骤里都要有；
# diagram 只有步骤 4 的重跑保护归开关管（它零成本，没有花钱确认）。
section() {  # section <file> <heading-prefix>：从该标题到下一个 ### 标题
  awk -v h="$2" 'index($0,h)==1{f=1;print;next} f&&/^#{2,3} /{f=0} f' "$1"
}
intro() { awk '/^## 执行流程/{exit} {print}' "$1"; }
check_count() {
  local file="$1" want="$2"
  grep -c -- '--confirmed-by-orca' "$REPO/$file" > "$TMP/count.txt"
  local got
  got=$(cat "$TMP/count.txt")
  [[ "$got" == "$want" ]] && ok "${file}：$want 行提到 --confirmed-by-orca" \
    || bad "${file}：--confirmed-by-orca 行数不对" "want=$want got=$got"
}
check_in() {
  local file="$1" where="$2" text="$3"
  if [[ "$where" == "intro" ]]; then intro "$REPO/$file"; else section "$REPO/$file" "$where"; fi > "$TMP/sec.txt"
  if [[ -s "$TMP/sec.txt" ]] && grep -qF -- "$text" "$TMP/sec.txt"; then
    ok "${file}「${where}」里有 $text"
  else
    bad "${file}「${where}」里没有 $text" "section bytes=$(wc -c < "$TMP/sec.txt")"
  fi
}
A=skills/md2publish-article/SKILL.md
# 第二批（人裁 2026-10-22，Orca 会话 b37f7ce9）：draft 步骤 2 元数据超限、visuals 步骤 6
# 重跑保护与步骤 9 回写 diff、diagram 步骤 4 重跑保护也归这个开关管。开关下替人做的每个
# 选择都要在交接里打一行 `⚠ confirmed-by-orca:`，Orca 靠这个前缀把它标红——没有这一行，
# 自动决定就和人点过头的决定长得一样。
FLAG='⚠ confirmed-by-orca: <id>'
check_count $R 3
check_in $R intro '--confirmed-by-orca'
check_in $R '### 步骤 2' '--confirmed-by-orca'
check_in $R '### 步骤 2' "$FLAG"
check_in $R '### 步骤 3' '--confirmed-by-orca'
check_in $R '### 步骤 3' 'confirmed-by-orca: <id>'
check_count $V 3
check_in $V '### 步骤 5' '--confirmed-by-orca'
check_in $V '### 步骤 5' 'confirmed-by-orca: <id>'
check_in $V '### 步骤 6' '--confirmed-by-orca'
check_in $V '### 步骤 6' "$FLAG"
check_in $V '### 步骤 9' '--confirmed-by-orca'
check_in $V '### 步骤 9' "$FLAG"
check_count $A 1
check_in $A '### 步骤 7' '--confirmed-by-orca'
check_in $A '### 步骤 7' 'confirmed-by-orca: <id>'
check_count $C 2
check_in $C '### 步骤 6' '--confirmed-by-orca'
check_in $C '### 步骤 6' "$FLAG"
check_count $D 1
check_in $D '### 步骤 4' '--confirmed-by-orca'
check_in $D '### 步骤 4' "$FLAG"

echo
echo "== 开关下重跑也绝不覆盖：旧产物原地保留，新产物另存编号文件 =="
# 人裁「带开关也另存新文件」：a81c5fa6 曾让 cover 在开关下加 --force 覆盖，现已推翻。
# 任何 SKILL.md 里只要出现带 --force 的 guard 命令（# 注释里的「别自己加 --force」不算），
# 就是又能覆盖花钱生成的图了。
for f in "$REPO"/skills/*/SKILL.md; do
  grep -nE 'artifacts\.py guard [^#]*--force' "$f" > "$TMP/force.txt"
  rel=${f#"$REPO"/}
  if [[ ! -s "$TMP/force.txt" ]]; then
    ok "${rel}：没有带 --force 的 guard 命令"
  else
    bad "${rel}：出现带 --force 的 guard 命令" "$(cat "$TMP/force.txt")"
  fi
done
# 不带开关时的原文一字不变：这几行就是人看到的停下来问的那道门。
expect_line $C 'python3 shared/scripts/artifacts.py guard --path "$ART/assets/<platform>/00-cover.png"'
expect_line $C '它非零退出就是文件已存在——**报告并停下问用户**，别自己加 `--force`。'
expect_line $V '逐张过重跑保护（别自己加 `--force`，非零退出就报告并停下问用户）：'
expect_line $V '  python3 shared/scripts/artifacts.py guard --path "$ART/assets/<platform>/${NN}-<role>.png"'
expect_line $D 'python3 shared/scripts/artifacts.py guard --path "${PNG}"        # 报告并停下问用户，别自己加 --force'
expect_line $V '**9b 与用户确认这一步不许跳过**（spec §9：改源文件的门）。锚点命中 0 次或多次时'
expect_line $R '超限时给出压缩建议让用户选择，不要静默截断。'

# 取新文件名的那几行：先确认 SKILL.md 里写的就是这几行，再把它们原样跑在一个已有
# 旧产物（含被占用的 .2.png 和只剩 .3.jpg 的编号）的目录里，量三件事：选中的名字没被
# 占用、guard 放行、旧文件逐字节没动。只看文本不跑，写错一个字符的循环也会是绿的。
COVER_SNIP=(
  'N=2'
  'while [[ -e "$ART/assets/<platform>/00-cover.$N.png" || -e "$ART/assets/<platform>/00-cover.$N.jpg" ]]; do N=$((N+1)); done'
  'COVER_PNG="$ART/assets/<platform>/00-cover.$N.png"'
  'python3 shared/scripts/artifacts.py guard --path "$COVER_PNG"'
)
VIS_SNIP=(
  '  PNG="$ART/assets/<platform>/${NN}-<role>.png"'
  '  if [[ -e "${PNG}" ]]; then'
  '    N=2'
  '    while [[ -e "$ART/assets/<platform>/${NN}-<role>.$N.png" || -e "$ART/assets/<platform>/${NN}-<role>.$N.jpg" ]]; do N=$((N+1)); done'
  '    PNG="$ART/assets/<platform>/${NN}-<role>.$N.png"'
  '  fi'
  '  python3 shared/scripts/artifacts.py guard --path "${PNG}"'
  '  echo "${NN} ${PNG}"'
)
DIA_SNIP=(
  'N=2'
  'while [[ -e "$ART/assets/${PLATFORM}/00-diagram.$N.png" || -e "$ART/assets/${PLATFORM}/00-diagram.$N.jpg" ]]; do N=$((N+1)); done'
  'PNG="$ART/assets/${PLATFORM}/00-diagram.$N.png"'
  'python3 shared/scripts/artifacts.py guard --path "${PNG}"'
)
for l in "${COVER_SNIP[@]}"; do expect_line $C "$l"; done
for l in "${VIS_SNIP[@]}"; do expect_line $V "$l"; done
for l in "${DIA_SNIP[@]}"; do expect_line $D "$l"; done

# run_snip <label> <want-stdout> <body>：在 $SK 里、对一个全新的 $ART 跑 body。
# 预置的旧产物每个写不同内容，跑完逐字节比对，证明没被碰过。
run_snip() {
  local label="$1" want="$2" body="$3"
  local art="$TMP/rerun-$RANDOM"
  mkdir -p "$art/assets/wechat"
  for f in 00-cover.png 00-cover.2.png 00-cover.3.jpg 00-diagram.png 00-diagram.2.png \
           00-illustration.png 00-illustration.2.jpg; do
    echo "old $f" > "$art/assets/wechat/$f"
  done
  \cp -Rf "$art/assets" "$art/before"
  (cd "$SK" && ART="$art" PLATFORM=wechat eval "$body") > "$TMP/snip.out" 2> "$TMP/snip.err"
  local rc=$?
  local got
  got=$(cat "$TMP/snip.out")
  got=${got//$art/\$ART}
  if [[ $rc -ne 0 ]]; then
    bad "${label}：没跑通" "rc=$rc err=$(cat "$TMP/snip.err")"
  elif [[ "$got" != "$want" ]]; then
    bad "${label}：选的文件名不对" "want=$want got=$got"
  elif ! diff -r "$art/before" "$art/assets" > "$TMP/snip.diff"; then
    bad "${label}：旧产物被改动了" "$(cat "$TMP/snip.diff")"
  else
    ok "${label} → ${want}，旧产物逐字节未动"
  fi
}
sub() { local s="$1"; s=${s//<platform>/wechat}; s=${s//<role>/illustration}; printf '%s\n' "$s"; }
body=""; for l in "${COVER_SNIP[@]}"; do body+="$(sub "$l")"$'\n'; done
run_snip "cover 开关下另存" '$ART/assets/wechat/00-cover.4.png' "${body}echo \"\$COVER_PNG\""
body="for NN in 00 01; do"$'\n'; for l in "${VIS_SNIP[@]}"; do body+="$(sub "$l")"$'\n'; done; body+="done"
run_snip "visuals 开关下逐张另存（00 已存在、01 没有）" \
  "00 \$ART/assets/wechat/00-illustration.3.png"$'\n'"01 \$ART/assets/wechat/01-illustration.png" "$body"
body=""; for l in "${DIA_SNIP[@]}"; do body+="$(sub "$l")"$'\n'; done
run_snip "diagram 开关下另存" '$ART/assets/wechat/00-diagram.3.png' \
  "${body}echo \"\$PNG\""

echo
echo "通过 $PASS 项，失败 $FAIL 项"
[[ $FAIL -eq 0 ]]
