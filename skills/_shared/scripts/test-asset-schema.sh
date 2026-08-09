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
assert ps == ["wechat", "xiaohongshu"], ps
print("OK")
')
[[ "$out" == "OK" ]] && ok "list_platforms 返回 wechat/xiaohongshu" || bad "list_platforms" "$out"

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
echo "通过 $PASS 项，失败 $FAIL 项"
[[ $FAIL -eq 0 ]]
