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


def available_backends() -> list[str]:
    """顺序即优先级。rsvg-convert 质量最好且最快，Chrome 最重，排最后。"""
    found = []
    if shutil.which("rsvg-convert"):
        found.append("rsvg-convert")
    if shutil.which("magick"):
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
        order = [backend]
    else:
        order = [b for b in ("rsvg-convert", "magick", "chrome") if b in available_backends()]

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
