#!/usr/bin/env python3
"""把图片压到给定字节上限以内。降级链：sips → ImageMagick →（需显式开启）cwebp。

纯机械压缩：不判断画质好不好、不改画幅比例（缩边是等比的）。
压不下去就硬失败——交付一个仍然超限的文件，等于把问题推到推草稿箱那一步才炸。
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

# (质量, 最长边上限)。最长边为 None 表示不缩放。
# 先降质量再缩边：封面在信息流里会被裁切，分辨率是最后才该牺牲的东西。
LADDER = [(85, None), (70, None), (55, None), (70, 2048), (70, 1600), (60, 1280)]


class CompressError(Exception):
    """压缩失败。所有失败路径统一抛这个，主函数负责转成退出码 1。"""


def _run(cmd: list[str]) -> bool:
    proc = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return proc.returncode == 0


def sips_step(src: Path, dst: Path, quality: int, max_dim: int | None) -> bool:
    cmd = ["sips", "-s", "format", "jpeg", "-s", "formatOptions", str(quality)]
    if max_dim:
        cmd += ["-Z", str(max_dim)]
    cmd += [str(src), "--out", str(dst)]
    return _run(cmd)


def magick_step(src: Path, dst: Path, quality: int, max_dim: int | None) -> bool:
    cmd = ["magick", str(src)]
    if max_dim:
        cmd += ["-resize", f"{max_dim}x{max_dim}>"]   # '>' = 只缩不放
    cmd += ["-quality", str(quality), str(dst)]
    return _run(cmd)


def cwebp_step(src: Path, dst: Path, quality: int, max_dim: int | None) -> bool:
    cmd = ["cwebp", "-q", str(quality)]
    if max_dim:
        cmd += ["-resize", str(max_dim), "0"]         # 0 = 按比例算高
    cmd += [str(src), "-o", str(dst)]
    return _run(cmd)


# 顺序即优先级。cwebp 排最后且默认不启用：它只产出 WebP，
# 而目标平台是否接受 WebP 属未核实的外部知识，不静默交付可能用不了的格式。
TOOLS = [
    ("sips", sips_step, ".jpg"),
    ("magick", magick_step, ".jpg"),
    ("cwebp", cwebp_step, ".webp"),
]


def available_tools(allow_webp: bool) -> list:
    out = []
    for name, fn, ext in TOOLS:
        if name == "cwebp" and not allow_webp:
            continue
        if shutil.which(name):
            out.append((name, fn, ext))
    return out


def _target_path(image: Path, out: Path | None, ext: str) -> Path:
    dst = out if out else image.with_suffix(ext)
    if dst == image:
        # 源本身就是 .jpg 时 with_suffix 会指回原文件。永不就地覆盖。
        dst = image.with_name(f"{image.stem}.compressed{ext}")
    return dst


def _staging_path(dst: Path) -> Path:
    """每一级阶梯先写这个临时文件，只有压到上限内才落到 dst。

    理由：dst 很可能是**上一次跑出来的、已经花过钱的好产物**。直接往 dst 上写，
    压缩失败时它就被一堆超限的中间结果覆盖掉了；后面再 unlink 一次更是连尸体
    都不剩。同目录、同扩展名——同目录保证 os.replace 不跨文件系统，同扩展名
    保证 magick / cwebp 仍按原来的格式判定输出（它们看扩展名）。
    """
    return dst.with_name(f".{dst.stem}.compress-tmp{dst.suffix}")


def compress(image: Path, max_bytes: int, out: Path | None, allow_webp: bool) -> dict:
    if not image.exists():
        raise CompressError(f"图片不存在: {image}")
    size = image.stat().st_size
    if size <= max_bytes:
        return {"action": "none", "path": str(image), "bytes": size, "tool": None, "steps": []}

    tools = available_tools(allow_webp)
    if not tools:
        raise CompressError(
            "找不到可用的压缩工具（sips / magick）。macOS 自带 sips；"
            "否则 brew install imagemagick。cwebp 只在 --allow-webp 时启用。"
        )

    steps: list[dict] = []
    staged: set[Path] = set()
    try:
        for name, fn, ext in tools:
            dst = _target_path(image, out, ext)
            tmp = _staging_path(dst)
            staged.add(tmp)
            for quality, max_dim in LADDER:
                if not fn(image, tmp, quality, max_dim):
                    steps.append({"tool": name, "quality": quality,
                                  "max_dim": max_dim, "bytes": None})
                    continue
                got = tmp.stat().st_size
                steps.append({"tool": name, "quality": quality, "max_dim": max_dim, "bytes": got})
                if got <= max_bytes:
                    os.replace(tmp, dst)   # 原子落盘；此前 dst 一直保持原样
                    staged.discard(tmp)
                    return {"action": "compressed", "path": str(dst), "bytes": got,
                            "tool": name, "steps": steps}
    finally:
        # 只清自己写的临时文件。**绝不碰 dst**——它可能是上一轮花钱生成的好产物，
        # 本次失败没有资格把它带走。
        for path in staged:
            path.unlink(missing_ok=True)

    sizes = [s["bytes"] for s in steps if s["bytes"]]
    best = min(sizes) if sizes else "无"
    raise CompressError(
        f"压不到 {max_bytes} 字节以内（原图 {size} 字节）。"
        f"已尝试 {len(steps)} 个阶梯，最小得到 {best} 字节。"
        "换一张构图更简单的图，或调高该 archetype 的 max_bytes。"
    )


def main() -> int:
    ap = argparse.ArgumentParser(description="把图片压到字节上限以内（机械压缩，不做画质判断）")
    ap.add_argument("--image", required=True)
    ap.add_argument("--max-bytes", required=True, type=int)
    ap.add_argument("--out", default=None, help="不给则在原图旁边写同名 .jpg")
    ap.add_argument("--allow-webp", action="store_true",
                    help="允许用 cwebp 产出 WebP。默认关闭：目标平台未必接受 WebP")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    try:
        result = compress(
            Path(args.image), args.max_bytes,
            Path(args.out) if args.out else None, args.allow_webp,
        )
    except CompressError as e:
        print(str(e), file=sys.stderr)
        return 1

    print(json.dumps(result, ensure_ascii=False, indent=2) if args.json else result["path"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
