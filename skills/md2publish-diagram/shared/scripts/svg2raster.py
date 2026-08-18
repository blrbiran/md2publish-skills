#!/usr/bin/env python3
"""把 SVG 光栅化成 PNG。降级链：rsvg-convert → magick → headless Chrome。

**只用标准库。** 不 import yaml、不 import asset_lib——降级链测试要在 PATH 遮蔽
沙箱里用 /usr/bin/python3（3.9.6，没装 PyYAML）跑它，任何第三方 import 都会让
那组测试无法进行，进而只能往生产代码里塞"假装某后端不存在"的测试后门。

画幅由本脚本强制（三期 D13）：diagram 不走 compose_prompt，平台画幅没有别的
机械校验点。viewBox 比例与 --aspect 不符时直接失败，否则位图会被拉伸变形，
而这件事在缩略图上肉眼看不出来。
"""

from __future__ import annotations

import argparse
import functools
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

PNG_MAGIC = b"\x89PNG\r\n\x1a\n"
ASPECT_TOLERANCE = 0.01          # 1%
DEFAULT_WIDTH = 1600
CHROME_CANDIDATES = (
    "google-chrome",
    "chromium",
    "chromium-browser",
)
CHROME_MAC_APP = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


class RasterError(Exception):
    """光栅化失败。所有失败统一抛这个，main 里转成退出码 1。"""


def find_chrome() -> str | None:
    """SVG2RASTER_CHROME 优先——它既是给 Chrome 装在别处的用户的开关，
    也是降级链测试用来遮蔽 Chrome 的手段（PATH 遮蔽管不到绝对路径的 .app）。"""
    override = os.environ.get("SVG2RASTER_CHROME")
    if override is not None:
        return override if os.access(override, os.X_OK) else None
    for name in CHROME_CANDIDATES:
        found = shutil.which(name)
        if found:
            return found
    return CHROME_MAC_APP if os.access(CHROME_MAC_APP, os.X_OK) else None


@functools.lru_cache(maxsize=None)
def magick_has_rsvg() -> bool:
    """ImageMagick 的 SVG coder 探测——正向要证据，找不到证据一律判"不可用"。

    没有编译进 RSVG delegate 的 magick 会退到它自己那套很弱的内置 MSVG
    渲染器：带 CJK 文字的 SVG 能被它"跑通"（exit 0、产出合法 PNG），但
    图上所有文字会被静默丢光——这是本机实测出来的真实故障模式，比直接
    报错凶险得多，因为退出码看不出任何异常，要等发布出去才会被发现。

    判据：`magick -list format` 的输出里，第一列恰好是 SVG/SVG*（不是
    MSVG*，也不是 SVGZ*）的那一行，描述里必须出现 RSVG 字样。magick 不
    存在、命令失败、或输出格式认不出来，一律当作"不可用"处理——宁可漏用
    一个其实可用的 magick（顶多降级到 chrome，无害），也不能误用一个会
    丢字的 magick。

    用 lru_cache 缓存：一次进程里只 fork 一次 magick 探测子进程，不会
    每次挑后端就重新问一遍。
    """
    exe = shutil.which("magick")
    if not exe:
        return False
    try:
        proc = subprocess.run([exe, "-list", "format"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except OSError:
        return False
    if proc.returncode != 0:
        return False
    for line in proc.stdout.decode("utf-8", errors="replace").splitlines():
        m = re.match(r"^\s*SVG\*?\s+\S+\s+\S+\s+(.*)$", line)
        if m and "RSVG" in m.group(1).upper():
            return True
    return False


def available_backends() -> list[str]:
    """顺序即优先级。rsvg-convert 质量最好且最快，Chrome 最重，排最后。

    magick 只有在探测到真的 RSVG delegate 时才计入——见 magick_has_rsvg()。"""
    found = []
    if shutil.which("rsvg-convert"):
        found.append("rsvg-convert")
    if shutil.which("magick") and magick_has_rsvg():
        found.append("magick")
    if find_chrome():
        found.append("chrome")
    return found


def parse_aspect(text: str) -> float:
    m = re.fullmatch(r"\s*(\d+(?:\.\d+)?)\s*:\s*(\d+(?:\.\d+)?)\s*", text)
    if not m:
        raise RasterError(f"--aspect 要写成 W:H（如 16:9），实为 {text!r}")
    w, h = float(m.group(1)), float(m.group(2))
    if w <= 0 or h <= 0:
        raise RasterError(f"--aspect 的两个数都必须为正，实为 {text!r}")
    return w / h


def svg_ratio(svg: Path) -> float:
    """从 viewBox 取比例；没有 viewBox 就退到 width/height 属性。

    用正则而不是 XML 解析器：SVG 可能带 DOCTYPE、注释、命名空间前缀，
    而我们只需要根元素上的两个属性，正则更不容易被这些噎住。
    """
    head = svg.read_text(encoding="utf-8", errors="replace")[:4000]
    m = re.search(r'viewBox\s*=\s*["\']\s*[-\d.]+\s+[-\d.]+\s+([\d.]+)\s+([\d.]+)', head)
    if m:
        w, h = float(m.group(1)), float(m.group(2))
    else:
        mw = re.search(r'\bwidth\s*=\s*["\']([\d.]+)', head)
        mh = re.search(r'\bheight\s*=\s*["\']([\d.]+)', head)
        if not (mw and mh):
            raise RasterError(
                f"{svg} 既没有 viewBox 也没有数值型 width/height，无法校验画幅。"
                "给根元素加上 viewBox（如 viewBox=\"0 0 1600 900\"）"
            )
        w, h = float(mw.group(1)), float(mh.group(1))
    if w <= 0 or h <= 0:
        raise RasterError(f"{svg} 的画布尺寸非法: {w}x{h}")
    return w / h


def check_aspect(svg: Path, aspect: str) -> None:
    want = parse_aspect(aspect)
    got = svg_ratio(svg)
    if abs(got - want) / want > ASPECT_TOLERANCE:
        raise RasterError(
            f"SVG 的 viewBox 比例是 {got:.3f}，平台要求 {aspect}（{want:.3f}），"
            f"相差超过 {ASPECT_TOLERANCE:.0%}。改 SVG 的 viewBox，别改 --aspect——"
            "画幅是平台硬约束，硬转会把图拉伸变形"
        )


def _run(cmd: list[str]) -> bool:
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except OSError:
        return False
    return proc.returncode == 0


def rsvg_step(svg: Path, out: Path, w: int, h: int) -> bool:
    return _run(["rsvg-convert", "-w", str(w), "-h", str(h), "-o", str(out), str(svg)])


def magick_step(svg: Path, out: Path, w: int, h: int) -> bool:
    return _run(["magick", "-background", "none", str(svg),
                 "-resize", f"{w}x{h}", str(out)])


def chrome_step(svg: Path, out: Path, w: int, h: int) -> bool:
    exe = find_chrome()
    if not exe:
        return False
    return _run([exe, "--headless", "--disable-gpu", "--hide-scrollbars",
                 f"--screenshot={out}", f"--window-size={w},{h}",
                 "--default-background-color=00000000", svg.resolve().as_uri()])


BACKENDS = {
    "rsvg-convert": rsvg_step,
    "magick": magick_step,
    "chrome": chrome_step,
}


def png_size(path: Path) -> tuple[int, int]:
    data = path.read_bytes()[:24]
    if data[:8] != PNG_MAGIC:
        raise RasterError(f"{path} 不是 PNG（后端产出了别的格式）")
    return int.from_bytes(data[16:20], "big"), int.from_bytes(data[20:24], "big")


def rasterize(svg: Path, out: Path, aspect: str, width: int, backend: str | None) -> dict:
    if not svg.exists():
        raise RasterError(f"SVG 不存在: {svg}")
    check_aspect(svg, aspect)
    height = round(width / parse_aspect(aspect))

    if backend is not None:
        if backend not in BACKENDS:
            raise RasterError(f"未知 backend: {backend}；可选 {sorted(BACKENDS)}")
        if backend == "magick" and not magick_has_rsvg():
            raise RasterError(
                "本机的 magick 没有 RSVG delegate（magick -list format 里 SVG 一行"
                "显示的是内置渲染器），它能跑通但会丢掉图上所有文字。"
                "装 librsvg（brew install librsvg）后 magick 才能用，"
                "或者直接用 rsvg-convert / chrome。"
            )
        order = [backend]
    else:
        # available_backends() 自己就按优先级返回（rsvg-convert → magick → chrome），
        # 直接用它，别再抄一份顺序：抄一份就多一个会跟它跑偏的真相源。
        order = available_backends()

    if not order:
        raise RasterError(
            f"找不到任何可用的光栅化后端（rsvg-convert / magick / chrome）。\n"
            f"SVG 已保留在 {svg}，需自行转换成 PNG 后再继续。\n"
            "装其中一个即可：brew install librsvg 或 brew install imagemagick"
        )

    out.parent.mkdir(parents=True, exist_ok=True)
    tried = []
    for name in order:
        if BACKENDS[name](svg, out, width, height) and out.exists() and out.stat().st_size > 0:
            got_w, got_h = png_size(out)
            return {
                "backend": name,
                "out": str(out),
                "width": got_w,
                "height": got_h,
                "bytes": out.stat().st_size,
            }
        tried.append(name)
        # 失败的那一级可能留下半个文件，清掉再试下一级。
        # 只删本函数自己刚写的这个路径，不碰目录里的任何既有文件（二期 A 教训 6）。
        if out.exists():
            out.unlink()
    raise RasterError(f"所有后端都失败了（试过 {tried}）。SVG 已保留在 {svg}")


def main() -> int:
    ap = argparse.ArgumentParser(description="SVG → PNG，降级链 rsvg-convert → magick → chrome")
    ap.add_argument("--check", action="store_true", help="只报告可用后端，不转换")
    ap.add_argument("--svg")
    ap.add_argument("--out")
    ap.add_argument("--aspect", help="平台画幅，如 16:9。取自 platform profile 的 diagram 槽")
    ap.add_argument("--width", type=int, default=DEFAULT_WIDTH)
    ap.add_argument("--backend", default=None, help="跳过降级链，指定用哪个后端")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    if args.check:
        info = {"backends": available_backends(), "chrome": find_chrome()}
        if args.json:
            print(json.dumps(info, ensure_ascii=False))
        elif info["backends"]:
            print("可用后端（按优先级）: " + ", ".join(info["backends"]))
        else:
            print("没有可用的光栅化后端。装一个：brew install librsvg（推荐）"
                  "或 brew install imagemagick；也可以装 Google Chrome。")
        return 0

    missing = [f"--{n}" for n in ("svg", "out", "aspect") if not getattr(args, n)]
    if missing:
        print(f"缺参数: {missing}（或改用 --check）", file=sys.stderr)
        return 1

    try:
        info = rasterize(Path(args.svg), Path(args.out), args.aspect, args.width, args.backend)
    except RasterError as e:
        print(str(e), file=sys.stderr)
        return 1
    print(json.dumps(info, ensure_ascii=False) if args.json else info["out"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
