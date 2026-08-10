#!/usr/bin/env python3
"""产物对比度普查：量出每一处文字的真实对比度，与冻结基线比对。

设计与判据理由见 docs/superpowers/specs/2026-08-10-contrast-audit-design.md。

它回答的问题是「落下来的东西读不读得清」，与 census-themes.py 的
「声明的色有没有落点」不重叠，两套基线各认各的、不要混。

用法：
    python3 contrast-themes.py                 # 与基线比对，只在有新增时 exit 1
    python3 contrast-themes.py --detail 19-candy-pop   # 单主题详表
    python3 contrast-themes.py --write-baseline        # 首跑：生成基线
    python3 contrast-themes.py --prune                 # 删掉产物里已不存在的基线行
"""
import argparse
import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import contrast_lib as CL

SCRIPT_DIR = Path(__file__).resolve().parent
THEME_JSON_DIR = SCRIPT_DIR / ".." / "references" / "theme-json"
BASELINE = SCRIPT_DIR / ".." / "references" / "contrast-baseline.tsv"
CORPUS = Path(os.environ.get(
    "MD2HTML_CORPUS",
    Path.home() / "code/skills/writing/wechat_test/litellm-multi-provider-gateway"))

HEADER = ["主题", "元素", "前景", "底", "字号", "字重", "类", "比值(参考)", "处数(参考)"]
KEY_COLS = 7   # 前 7 列是键；后两列只作参考，不参与比对


def authoritative_pairs():
    """从 test-md2html.sh 的 PAIRS 表取权威配对。

    绝不 glob('*.html')——out/ 里混着中间产物（13-cyber-neon-v7-grid 不在配对表里），
    按文件名循环会把它算成第 27 个主题。handoff §4 用黑体写过这条。
    """
    sh = (SCRIPT_DIR / "test-md2html.sh").read_text(encoding="utf-8")
    m = re.search(r'PAIRS="\n(.*?)\n"', sh, re.S)
    if not m:
        sys.exit("FAIL：test-md2html.sh 里找不到 PAIRS 表——它是权威配对关系，不能绕过")
    return [tuple(l.strip().split(":")) for l in m.group(1).strip().splitlines() if l.strip()]


def collect():
    pairs = authoritative_pairs()
    outdir = CORPUS / "out"
    if not outdir.is_dir():
        print(f"SKIP 对比度普查：语料不在 {CORPUS}")
        print("     这不是通过。设 MD2HTML_CORPUS 指向实验目录再跑，否则改动没有护栏。")
        sys.exit(2)
    rows = []
    for j, h in pairs:
        tj, html = THEME_JSON_DIR / f"{j}.theme.json", outdir / f"{h}.html"
        if not tj.is_file() or not html.is_file():
            print(f"SKIP 对比度普查：{j} 缺文件（{tj.name} 或 {html.name}）")
            sys.exit(2)
        theme = json.loads(tj.read_text(encoding="utf-8"))
        try:
            rows.extend(CL.findings_for(j, html.read_text(encoding="utf-8"), theme))
        except CL.ContrastWalkError as e:
            sys.exit(f"FAIL {j}：{e}")
    return rows


def key_of(f):
    return (f.theme, f.tag, f.fg, f.bg, f"{f.size:g}", str(f.weight), f.kind)


def row_of(f):
    return list(key_of(f)) + [f"{f.ratio:.2f}", str(f.count)]


def read_baseline():
    if not BASELINE.is_file():
        return {}
    out = {}
    for line in BASELINE.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        cols = line.split("\t")
        if cols[:KEY_COLS] == HEADER[:KEY_COLS]:
            continue
        out[tuple(cols[:KEY_COLS])] = cols
    return out


def prune_survivors(findings, base):
    """--prune 用来算「留下哪些行」的纯函数：只留基线里已有键在本轮仍出现的行，

    绝不把 base 之外的新组合写进去——新组合只能靠显式的 --write-baseline 收录。
    以前的实现是 `key_of(f) in base or key_of(f) in seen`；`seen` 就是本轮
    findings 自己算出来的，`key_of(f) in seen` 对 findings 里的每个 f 恒真，
    整个 or 是同义反复，等于把 --prune 悄悄做成了 --write-baseline。
    """
    return [f for f in findings if key_of(f) in base]


def baseline_diff(findings, base):
    """本轮 findings 相对旧基线的 (新增列表, 移除键列表)。

    默认路径、--prune、--write-baseline 三条路都要用同一份 new/stale——尤其是
    --write-baseline：它重写整份基线文件，diff 噪声很大，唯一能让人看清「有没有
    夹带新组合」的时刻就是这里打印的摘要，算法必须与默认路径逐字一致，不能各算一遍。
    """
    seen = {key_of(f): f for f in findings}
    new = [f for k, f in seen.items() if k not in base]
    stale = [k for k in base if k not in seen]
    return new, stale


def write_baseline(findings):
    lines = [
        "# 对比度审计基线：已知、未处置的存量。含义不是「可接受」，只是「还没排到」。",
        "# 判定为可以永远这样的走主题 .md 里的 <!-- contrast-ok: ... --> 注记，两者不许混。",
        "# 只许减、不许增——脚本管不了这条，唯一护栏是人读这份文件的 diff。",
        "# 前 7 列是键；比值与处数只作参考，不参与比对。",
        "\t".join(HEADER),
    ]
    lines += ["\t".join(row_of(f)) for f in
              sorted(findings, key=lambda f: (f.theme, f.tag, f.fg, f.bg))]
    BASELINE.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--detail", metavar="主题")
    ap.add_argument("--write-baseline", action="store_true")
    ap.add_argument("--prune", action="store_true")
    args = ap.parse_args()

    findings = collect()

    if args.detail:
        sel = [f for f in findings if f.theme == args.detail]
        print("\t".join(HEADER))
        for f in sorted(sel, key=lambda f: f.ratio):
            print("\t".join(row_of(f)))
        print(f"\n{args.detail}：{len(sel)} 条")
        return 0

    baseline_existed = BASELINE.is_file()
    base = read_baseline()
    new, stale = baseline_diff(findings, base)

    if args.write_baseline:
        write_baseline(findings)
        print(f"已写入基线 {BASELINE}：{len(findings)} 条")
        # --write-baseline 重写整份文件（重新排序、参考列重算），diff 本身噪声很大，
        # 会把少量真正新增的行埋进大片预期内的抖动里——这里补上默认路径已经算好的
        # new/stale 摘要，是人还能看见「有没有东西被顺手夹带进基线」的唯一时刻。
        # 不许据此拒绝写入，也不改写入的内容——只负责让新增显眼。
        if not baseline_existed:
            print("（此前没有基线文件——这是首次生成，无旧基线可比，"
                  "以上条数不是相对旧基线的「新增」。）")
        elif new:
            print(f"\n⚠️ 相对旧基线新增 {len(new)} 条组合（未经人审阅，"
                  f"随这次写入一起进了基线——如果不是预期中的改动，先看清楚再继续）：")
            print("  " + "\t".join(HEADER))
            for f in sorted(new, key=lambda f: f.ratio):
                print("  " + "\t".join(row_of(f)))
        else:
            print("（相对旧基线无新增）")
        if baseline_existed and stale:
            print(f"（相对旧基线移除 {len(stale)} 条产物里已不存在的组合）")
        return 0

    if args.prune:
        write_baseline(prune_survivors(findings, base))
        print(f"已清理 {len(stale)} 条产物里已不存在的基线行")
        if new:
            print(f"另有 {len(new)} 条基线里没有的新组合，--prune 不收录它们——"
                  f"仍要跑一次不带参数的普查确认，收录只能用 --write-baseline。")
        return 0

    print(f"\n对比度普查：{len(findings)} 条不达标，基线 {len(base)} 条")
    if stale:
        print(f"\n{len(stale)} 条基线行在产物里已不存在（不算失败；确认是修好了或换了语料，"
              f"再跑 --prune 清理）：")
        for k in sorted(stale)[:20]:
            print("  stale  " + "  ".join(k))
        if len(stale) > 20:
            print(f"  …… 另有 {len(stale) - 20} 条")
    if new:
        print(f"\n{len(new)} 条基线里没有的新组合：")
        print("  " + "\t".join(HEADER))
        for f in sorted(new, key=lambda f: f.ratio):
            print("  " + "\t".join(row_of(f)))
        print("\n基线只许减、不许增。要么修掉它，要么在主题 .md 里写 contrast-ok 注记"
              "并说明理由——不要直接往 .tsv 里加行。")
        return 1
    print("\n无新增，基线一致")
    return 0


if __name__ == "__main__":
    sys.exit(main())
