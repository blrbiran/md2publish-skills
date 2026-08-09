"""共享图片资产的加载与校验。被 compose_prompt.py 和各测试脚本共用。"""

# 必需：本文件用了 `dict | None` 这类 PEP 604 注解，而目标环境是 Python 3.9，
# 3.9 会在 import 时对它求值并抛 TypeError。这行把注解变成惰性字符串。
from __future__ import annotations

from pathlib import Path

import yaml

ARCHETYPES = ["cover", "illustration", "infographic", "series", "diagram"]
PLACEHOLDERS = {"PLATFORM_FRAME", "PALETTE", "RENDERING", "LAYOUT", "CONTENT"}
UNSUPPORTED = "unsupported"


class AssetError(Exception):
    """资产结构不合法。所有校验失败统一抛这个。"""


def shared_root() -> Path:
    return Path(__file__).resolve().parent.parent


def list_platforms() -> list[str]:
    return sorted(p.stem for p in (shared_root() / "platforms").glob("*.yaml"))


def load_platform(name: str) -> dict:
    path = shared_root() / "platforms" / f"{name}.yaml"
    if not path.exists():
        raise AssetError(f"平台 profile 不存在: {path}")
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    _validate_platform(name, data)
    return data


def _validate_platform(name: str, data: dict) -> None:
    for key in ("name", "display_name", "archetypes"):
        if key not in data:
            raise AssetError(f"{name}.yaml 缺字段 {key}")
    slots = data["archetypes"]
    missing = [a for a in ARCHETYPES if a not in slots]
    if missing:
        raise AssetError(f"{name}.yaml 缺 archetype 槽: {missing}")
    for arch, slot in slots.items():
        if arch not in ARCHETYPES:
            raise AssetError(f"{name}.yaml 有未知 archetype: {arch}")
        if slot == UNSUPPORTED:
            continue
        _validate_slot(name, arch, slot)


def _validate_slot(platform: str, arch: str, slot: dict) -> None:
    where = f"{platform}.archetypes.{arch}"
    if not isinstance(slot, dict):
        raise AssetError(f"{where} 必须是 dict 或字符串 '{UNSUPPORTED}'，实为 {slot!r}")
    if "aspect" not in slot:
        raise AssetError(f"{where} 缺 aspect")
    mb = slot.get("max_bytes")
    if not isinstance(mb, int) or isinstance(mb, bool) or mb <= 0:
        raise AssetError(f"{where}.max_bytes 必须是正整数字节，实为 {mb!r}")
    text = slot.get("text_on_image")
    if not isinstance(text, dict):
        raise AssetError(f"{where}.text_on_image 必须是结构，实为 {text!r}")
    for key in ("title", "subtitle"):
        if not isinstance(text.get(key), bool):
            raise AssetError(f"{where}.text_on_image.{key} 必须是布尔，实为 {text.get(key)!r}")


def archetype_slot(platform: dict, archetype: str) -> dict | None:
    """返回该 archetype 的槽配置；平台不支持时返回 None。"""
    if archetype not in ARCHETYPES:
        raise AssetError(f"未知 archetype: {archetype}")
    slots = platform["archetypes"]
    if archetype not in slots:
        raise AssetError(f"{platform['name']} 未定义 archetype 槽: {archetype}")
    slot = slots[archetype]
    return None if slot == UNSUPPORTED else slot
