#!/usr/bin/env python3
"""md2publish 自己的图片偏好配置：~/.config/md2publish/images.yaml。

**不复用 baoyu 的 EXTEND.md**（spec §7.3）：两套 skill 可能装在同一台机器上，
共用配置文件会互相覆盖。

本文件的值最终以显式命令行参数传给 imagegen 引擎。引擎的取值优先级是
CLI > EXTEND.md > 环境变量，所以这里的设置总是赢，不需要改引擎。

**API key 不进这个文件**，仍走环境变量——配置文件会被 vendor、会被 diff，
不是放凭证的地方。
"""

from __future__ import annotations

import os
from pathlib import Path

import yaml

DEFAULTS = {
    "provider": None,             # 不指定则由引擎按已配置的环境变量自动选
    "model": None,                # 不指定则用 provider 的默认模型
    "default_platform": None,     # 用户没说平台且文章 frontmatter 也没写时的兜底
    "max_concurrency": 3,         # 批量生成的并发上限，传给 imagegen 的 --jobs
    "max_images_per_run": 10,     # 单次运行的张数硬上限，超过直接拒绝（spec §9）
}
INT_FIELDS = ("max_concurrency", "max_images_per_run")


class ConfigError(Exception):
    """配置文件不合法。拼错字段会被硬失败挡住，不静默忽略。"""


def config_path() -> Path:
    base = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
    return Path(base) / "md2publish" / "images.yaml"


def load_config(path: Path | None = None) -> dict:
    path = path or config_path()
    conf = dict(DEFAULTS)
    if not path.exists():
        return conf

    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        raise ConfigError(f"{path} 不是 mapping")

    unknown = sorted(set(data) - set(DEFAULTS))
    if unknown:
        raise ConfigError(
            f"{path} 含未知字段 {unknown}；合法字段为 {sorted(DEFAULTS)}。"
            "拼错的字段被静默忽略比报错更难查，因此这里硬失败。"
        )
    for key in INT_FIELDS:
        if key in data:
            val = data[key]
            if not isinstance(val, int) or isinstance(val, bool) or val <= 0:
                raise ConfigError(f"{path} 的 {key} 必须是正整数，实为 {val!r}")

    conf.update(data)
    return conf
