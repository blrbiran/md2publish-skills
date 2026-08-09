#!/usr/bin/env python3
"""contrast-themes.py 的单元测试。目前只钉 --prune 的核心纯函数 prune_survivors。

Task 7 会补全库的变异测试套件（test-contrast-themes.sh）；这里先钉住修复
review-1 轮那条 Critical：`--prune` 曾经的过滤条件 `key_of(f) in base or
key_of(f) in seen` 里 `seen` 就是本轮 findings 自己算出来的，`in seen` 恒真，
整个 or 是同义反复，等价于把 --prune 悄悄做成了 --write-baseline——新组合会
在清理 stale 行的同一时刻被无声写进基线，从不报新增、从不 exit 1。
"""
import importlib.util
import sys
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
import contrast_lib as CL

spec = importlib.util.spec_from_file_location("contrast_themes", HERE / "contrast-themes.py")
CT = importlib.util.module_from_spec(spec)
spec.loader.exec_module(CT)

fails = 0
def ok(name, cond):
    global fails
    if cond:
        print(f"ok   {name}")
    else:
        fails += 1
        print(f"FAIL {name}")


def finding(theme, tag, fg, bg, size, weight, kind, ratio, count):
    return CL.Finding(theme, tag, fg, bg, size, weight, kind, ratio, "样本", count)


# 三种键同时出场：
#   OLD  —— 基线里有、本轮产物里也还在 → 该留
#   NEW  —— 基线里没有、本轮产物里新出现（未经人评审） → 绝不能被 --prune 写进基线
#   STALE—— 基线里有、本轮产物里已经没有 → 该被清掉（不在 findings 里，天然被滤掉）
OLD = finding("t", "strong", "#c2593b", "#efe0cd", 14.5, 700, "文字", 3.39, 6)
NEW = finding("t", "p", "#111111", "#efe0cd", 14.5, 400, "文字", 3.90, 9)

base = {
    CT.key_of(OLD): list(CT.key_of(OLD)) + ["3.39", "6"],
    ("t", "th", "#999999", "#dddddd", "13", "400", "文字"): ["stale", "row"],  # STALE
}
findings = [OLD, NEW]   # 本轮产物：OLD 还在，STALE 已经不在了，外加一条全新的 NEW

survivors = CT.prune_survivors(findings, base)
survivor_keys = {CT.key_of(f) for f in survivors}

ok("prune_survivors 保留仍在基线里的旧组合", CT.key_of(OLD) in survivor_keys)
ok("prune_survivors 绝不把新组合写进基线（钉住 tautology 那个 bug）",
   CT.key_of(NEW) not in survivor_keys)
ok("prune_survivors 不会凭空多产出任何行", len(survivors) == 1)

# 用旧的（错误）判据重放一次，证明这条测试真的会抓住那个 bug——
# 不是刚好两种写法在这份数据上殊途同归。
seen = {CT.key_of(f): f for f in findings}
tautological = [f for f in findings if CT.key_of(f) in base or CT.key_of(f) in seen]
ok("旧判据在这份数据上确实会把 NEW 悄悄收进去（证明本用例抓得住那个回归）",
   CT.key_of(NEW) in {CT.key_of(f) for f in tautological})

print(f"\nok：{fails} 条失败")
sys.exit(1 if fails else 0)
