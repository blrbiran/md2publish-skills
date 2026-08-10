"""共享图片资产的加载与校验。被 compose_prompt.py 和各测试脚本共用。"""

# 必需：本文件用了 `dict | None` 这类 PEP 604 注解，而目标环境是 Python 3.9，
# 3.9 会在 import 时对它求值并抛 TypeError。这行把注解变成惰性字符串。
from __future__ import annotations

from pathlib import Path

import yaml

ARCHETYPES = ["cover", "illustration", "infographic", "series", "diagram"]
PLACEHOLDERS = {"PLATFORM_FRAME", "PALETTE", "RENDERING", "LAYOUT", "CONTENT"}
UNSUPPORTED = "unsupported"
PRESET_REQUIRED_FIELDS = [
    "name",
    "archetype",
    "description",
    "primary_use_case",
    "version",
    "metadata",
    "template",
]
DIMENSION_KINDS = {"palettes", "renderings", "layouts"}

# 已 vendor 进 scripts/imagegen/ 的 provider。codex-cli 不在其中（二期 A 未搬）。
# 改 vendor 范围时这里和 preflight.PROVIDER_ENV 要同步改。
PROVIDERS = [
    "agnes", "azure", "dashscope", "google", "jimeng", "minimax",
    "openai", "openrouter", "replicate", "seedream", "zai",
]
COST_UNKNOWN = "unknown"


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


def list_presets(archetype: str | None = None) -> list[str]:
    root = shared_root() / "presets"
    subdirs = [root / archetype] if archetype else [root / a for a in ARCHETYPES]
    names = []
    for d in subdirs:
        if d.is_dir():
            names.extend(p.stem for p in d.glob("*.yaml"))
    return sorted(names)


def load_preset(name: str) -> dict:
    root = shared_root() / "presets"
    for arch in ARCHETYPES:
        path = root / arch / f"{name}.yaml"
        if path.exists():
            data = yaml.safe_load(path.read_text(encoding="utf-8"))
            _validate_preset(name, data)
            return data
    raise AssetError(f"preset 不存在: {name}")


def _validate_preset(name: str, data: dict) -> None:
    if not isinstance(data, dict):
        raise AssetError(f"{name}.yaml 不是 mapping")
    missing = [f for f in PRESET_REQUIRED_FIELDS if f not in data]
    if missing:
        raise AssetError(f"{name}.yaml 缺必填字段: {missing}")
    if data["archetype"] not in ARCHETYPES:
        raise AssetError(f"{name}.yaml archetype 非法: {data['archetype']}")
    if "compatible_platforms" in data:
        raise AssetError(
            f"{name}.yaml 用了白名单 compatible_platforms；"
            "应改用排除制 incompatible_platforms，否则每加一个平台都要回头改所有 preset"
        )
    incompat = data.get("incompatible_platforms", [])
    if not isinstance(incompat, list):
        raise AssetError(f"{name}.yaml incompatible_platforms 必须是列表")
    meta = data.get("metadata")
    if not isinstance(meta, dict):
        raise AssetError(f"{name}.yaml metadata 必须是 mapping")
    for key in ("author", "provenance"):
        if not meta.get(key):
            raise AssetError(f"{name}.yaml 缺 metadata.{key}")


def load_dimension(kind: str, value: str) -> str:
    if kind not in DIMENSION_KINDS:
        raise AssetError(f"未知 dimension 类别: {kind}")
    path = shared_root() / "presets" / "dimensions" / kind / f"{value}.md"
    if not path.exists():
        raise AssetError(f"dimension 不存在: {kind}/{value}.md")
    return path.read_text(encoding="utf-8").strip()


def preset_supports(preset: dict, platform_name: str) -> bool:
    return platform_name not in preset.get("incompatible_platforms", [])


def load_costs() -> dict:
    path = shared_root() / "costs.yaml"
    if not path.exists():
        raise AssetError(f"costs.yaml 不存在: {path}")
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise AssetError("costs.yaml 不是 mapping")
    for key in ("version", "currency", "providers"):
        if key not in data:
            raise AssetError(f"costs.yaml 缺字段 {key}")
    if not isinstance(data["providers"], dict) or not data["providers"]:
        raise AssetError("costs.yaml 的 providers 必须是非空 mapping")
    unknown = sorted(set(data["providers"]) - set(PROVIDERS))
    if unknown:
        raise AssetError(
            f"costs.yaml 含未 vendor 的 provider {unknown}；已 vendor 的是 {PROVIDERS}"
        )
    for provider, models in data["providers"].items():
        if not isinstance(models, dict) or not models:
            raise AssetError(f"costs.yaml 的 {provider} 必须是非空 mapping")
        for model, value in models.items():
            if value == COST_UNKNOWN:
                continue
            if isinstance(value, bool) or not isinstance(value, (int, float)) or value <= 0:
                raise AssetError(
                    f"costs.yaml 的 {provider}.{model} 必须是正数或字符串 "
                    f"'{COST_UNKNOWN}'，实为 {value!r}"
                )
    return data


def estimate_cost(provider: str, model: str) -> float | None:
    """返回单张估价；无价目返回 None。调用方据此说明'该 provider 无价目表'，别编数字。"""
    if provider not in PROVIDERS:
        raise AssetError(f"未知 provider: {provider}；已 vendor 的是 {PROVIDERS}")
    value = (load_costs()["providers"].get(provider) or {}).get(model, COST_UNKNOWN)
    return None if value == COST_UNKNOWN else float(value)
