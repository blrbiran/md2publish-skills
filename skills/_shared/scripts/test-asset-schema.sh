#!/usr/bin/env bash
# 资产 schema 校验测试。对应 spec §13 第 3 项。
set -uo pipefail
cd "$(dirname "$0")"

PASS=0
FAIL=0
ok()   { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad()  { echo "  ❌ $1"; echo "     $2"; FAIL=$((FAIL+1)); }

run_py() { python3 -c "$1" 2>&1; }

echo "== platform profile 校验 =="

out=$(run_py '
import asset_lib as a
ps = a.list_platforms()
assert ps == ["bilibili", "wechat", "xiaohongshu"], ps
print("OK")
')
[[ "$out" == "OK" ]] && ok "list_platforms 返回 bilibili/wechat/xiaohongshu" || bad "list_platforms" "$out"

out=$(run_py '
import asset_lib as a
for name in a.list_platforms():
    p = a.load_platform(name)
    for arch in a.ARCHETYPES:
        a.archetype_slot(p, arch)
print("OK")
')
[[ "$out" == "OK" ]] && ok "每个平台都定义了全部 5 个 archetype 槽" || bad "archetype 槽完整性" "$out"

out=$(run_py '
import asset_lib as a
p = a.load_platform("wechat")
assert a.archetype_slot(p, "series") is None, "wechat.series 应为 unsupported"
assert a.archetype_slot(p, "cover") is not None
print("OK")
')
[[ "$out" == "OK" ]] && ok "unsupported 槽返回 None" || bad "unsupported 处理" "$out"

out=$(run_py '
import asset_lib as a
p = a.load_platform("wechat")
try:
    a.archetype_slot(p, "nonexistent")
except a.AssetError:
    print("OK")
else:
    print("未抛 AssetError")
')
[[ "$out" == "OK" ]] && ok "未知 archetype 抛 AssetError" || bad "未知 archetype" "$out"

out=$(run_py '
import asset_lib as a
for name in a.list_platforms():
    p = a.load_platform(name)
    for arch in a.ARCHETYPES:
        slot = a.archetype_slot(p, arch)
        if slot is None:
            continue
        mb = slot["max_bytes"]
        assert isinstance(mb, int), name + "." + arch + ".max_bytes 不是整数: " + repr(mb)
        assert mb > 0
print("OK")
')
[[ "$out" == "OK" ]] && ok "max_bytes 全是正整数" || bad "max_bytes 类型" "$out"

out=$(run_py '
import asset_lib as a
for name in a.list_platforms():
    p = a.load_platform(name)
    for arch in a.ARCHETYPES:
        slot = a.archetype_slot(p, arch)
        if slot is None:
            continue
        t = slot["text_on_image"]
        assert isinstance(t, dict), name + "." + arch + ".text_on_image 不是结构: " + repr(t)
        assert isinstance(t["title"], bool)
        assert isinstance(t["subtitle"], bool)
print("OK")
')
[[ "$out" == "OK" ]] && ok "text_on_image 是含 title/subtitle 布尔的结构" || bad "text_on_image 结构" "$out"

echo
echo "== preset schema 校验 =="

out=$(run_py '
import asset_lib as a
names = a.list_presets()
assert len(names) >= 4, names
for n in names:
    p = a.load_preset(n)
    for f in a.PRESET_REQUIRED_FIELDS:
        assert f in p, n + " 缺字段 " + f
    assert p["metadata"].get("author"), n + " 缺 metadata.author"
    assert p["metadata"].get("provenance"), n + " 缺 metadata.provenance"
print("OK")
')
[[ "$out" == "OK" ]] && ok "所有 preset 必填字段齐全（含 primary_use_case）" || bad "preset 必填字段" "$out"

out=$(run_py '
import asset_lib as a
for n in a.list_presets():
    p = a.load_preset(n)
    arch = p["archetype"]
    assert arch in a.ARCHETYPES, n + " archetype 非法: " + str(arch)
    assert "compatible_platforms" not in p, n + " 用了白名单 compatible_platforms，应改用 incompatible_platforms"
    assert isinstance(p.get("incompatible_platforms", []), list)
print("OK")
')
[[ "$out" == "OK" ]] && ok "archetype 合法且用排除制而非白名单" || bad "preset archetype/平台字段" "$out"

out=$(run_py '
import asset_lib as a
KINDS = {"palette": "palettes", "rendering": "renderings", "layout": "layouts"}
for n in a.list_presets():
    p = a.load_preset(n)
    for field, kind in KINDS.items():
        val = p.get(field)
        if val is None:
            continue
        body = a.load_dimension(kind, val)
        assert body, n + "." + field + " -> " + kind + "/" + val + ".md 是空文件"
print("OK")
')
[[ "$out" == "OK" ]] && ok "preset 引用的 dimensions 文件都存在且非空" || bad "dimensions 引用" "$out"

out=$(run_py '
import asset_lib as a
known = set(a.list_platforms())
for n in a.list_presets():
    p = a.load_preset(n)
    for plat in p.get("incompatible_platforms", []):
        assert plat in known, n + ".incompatible_platforms 含未知平台: " + plat
print("OK")
')
[[ "$out" == "OK" ]] && ok "incompatible_platforms 里的平台都存在" || bad "incompatible_platforms" "$out"

out=$(run_py '
import asset_lib as a
try:
    a.load_dimension("palettes", "no-such-palette")
except a.AssetError:
    print("OK")
else:
    print("未抛 AssetError")
')
[[ "$out" == "OK" ]] && ok "缺失的 dimension 抛 AssetError" || bad "dimension 缺失处理" "$out"

echo
echo "== INDEX.md 一致性 =="

out=$(run_py '
import asset_lib as a
idx = (a.shared_root() / "presets" / "INDEX.md").read_text(encoding="utf-8")
missing = [n for n in a.list_presets() if "`" + n + "`" not in idx]
assert not missing, "INDEX.md 未收录 preset: " + str(missing)
print("OK")
')
[[ "$out" == "OK" ]] && ok "INDEX.md 收录了全部 preset" || bad "INDEX preset 覆盖" "$out"

out=$(run_py '
import asset_lib as a
idx = (a.shared_root() / "presets" / "INDEX.md").read_text(encoding="utf-8")
root = a.shared_root() / "presets" / "dimensions"
missing = []
for kind in sorted(a.DIMENSION_KINDS):
    for f in sorted((root / kind).glob("*.md")):
        if "`" + f.stem + "`" not in idx:
            missing.append(kind + "/" + f.stem)
assert not missing, "INDEX.md 未收录 dimension: " + str(missing)
print("OK")
')
[[ "$out" == "OK" ]] && ok "INDEX.md 收录了全部 dimension 值" || bad "INDEX dimension 覆盖" "$out"

echo
echo "== costs.yaml（spec §9）=="

py() { python3 -c "import sys; sys.path.insert(0,'.'); $1"; }

out=$(py "
import asset_lib as a
c = a.load_costs()
assert c['version'] == 1, c['version']
assert c['currency'], 'currency 缺失'
assert isinstance(c['providers'], dict) and c['providers'], 'providers 为空'
print('ok')
" 2>&1)
if [[ "$out" == "ok" ]]; then ok "costs.yaml 结构合法"; else bad "costs.yaml 结构不合法" "$out"; fi

out=$(py "
import asset_lib as a
extra = sorted(set(a.load_costs()['providers']) - set(a.PROVIDERS))
print('ok' if not extra else 'unknown provider: %s' % extra)
" 2>&1)
if [[ "$out" == "ok" ]]; then ok "costs.yaml 里没有未 vendor 的 provider"; else bad "costs.yaml 有多余 provider" "$out"; fi

out=$(py "
import asset_lib as a
bad_vals = []
for p, models in a.load_costs()['providers'].items():
    for m, v in (models or {}).items():
        if v != 'unknown' and not (isinstance(v, (int, float)) and not isinstance(v, bool) and v > 0):
            bad_vals.append((p, m, v))
print('ok' if not bad_vals else 'bad values: %s' % bad_vals)
" 2>&1)
if [[ "$out" == "ok" ]]; then ok "每个价格是正数或字符串 unknown"; else bad "价格取值非法" "$out"; fi

out=$(py "
import asset_lib as a
assert a.estimate_cost('openai', 'gpt-image-2') is None, '未标价应返回 None'
try:
    a.estimate_cost('no-such-provider', 'x')
    print('未知 provider 没有硬失败')
except a.AssetError:
    print('ok')
" 2>&1)
if [[ "$out" == "ok" ]]; then ok "unknown 返回 None、未知 provider 硬失败"; else bad "estimate_cost 行为不对" "$out"; fi

echo
echo "== provider 名单四处一致 =="

# 同一份「已 vendor 的 11 个 provider」被写了四遍：asset_lib.PROVIDERS、
# preflight.PROVIDER_ENV、imagegen/providers/*.ts、costs.yaml。加第 12 个时漏掉任何
# 一处都不会当场报错，而是等到真要花钱那一刻才炸：漏 asset_lib.PROVIDERS →
# estimate_cost 跑到一半抛异常；漏 PROVIDER_ENV → 凭证门把一个配置正确的用户拦下。
# 下面这条是唯一把四者绑在一起的断言。
out=$(py "
import asset_lib as a, preflight as pf
from pathlib import Path

lists = {
    'asset_lib.PROVIDERS': set(a.PROVIDERS),
    'preflight.PROVIDER_ENV': set(pf.PROVIDER_ENV),
    'imagegen/providers/*.ts': {
        p.stem for p in (Path('imagegen') / 'providers').glob('*.ts')
        if not p.name.endswith('.test.ts')
    },
    'costs.yaml providers': set(a.load_costs()['providers']),
}
union = set().union(*lists.values())
gaps = {k: sorted(union - v) for k, v in lists.items() if union - v}
assert not gaps, '四处名单不一致，各自缺: %s' % gaps
assert len(union) == 11, '总数变了（当前 %d 个），四处都改了才算数: %s' % (len(union), sorted(union))
print('ok')
" 2>&1)
if [[ "$out" == "ok" ]]; then
  ok "provider 名单在 asset_lib / preflight / imagegen / costs.yaml 四处完全一致"
else
  bad "provider 名单四处不一致" "$out"
fi

echo
echo "通过 $PASS 项，失败 $FAIL 项"
[[ $FAIL -eq 0 ]]
