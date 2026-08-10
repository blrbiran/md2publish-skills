#!/usr/bin/env python3
"""生成前的三项自检：TS 运行时 / provider 凭证 / 压缩工具链。

**只报告，不阻塞**（spec §11）：provider 缺失由生成那一步拦，压缩工具缺失由
压缩那一步拦，运行时缺失由调用引擎那一步拦。这样用户能一次看全所有缺口，
而不是修一个撞一个。因此本脚本永远退出 0。

三个 check 函数都接受注入的 path / env——开发机上工具通常齐全，
不注入就永远测不到缺失分支。
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import config as cfg  # noqa: E402

# provider → 需要的环境变量。每个元组内**任一**即可；多个元组表示**全都要**。
# 取值来自 imagegen/main.ts:detectProvider，改引擎时要同步改这里。
PROVIDER_ENV = {
    "agnes": [("AGNES_API_KEY",)],
    "azure": [("AZURE_OPENAI_API_KEY",), ("AZURE_OPENAI_BASE_URL",)],
    "dashscope": [("DASHSCOPE_API_KEY",)],
    "google": [("GOOGLE_API_KEY", "GEMINI_API_KEY")],
    "jimeng": [("JIMENG_ACCESS_KEY_ID",), ("JIMENG_SECRET_ACCESS_KEY",)],
    "minimax": [("MINIMAX_API_KEY",)],
    "openai": [("OPENAI_API_KEY",)],
    "openrouter": [("OPENROUTER_API_KEY",)],
    "replicate": [("REPLICATE_API_TOKEN",)],
    "seedream": [("ARK_API_KEY",)],
    "zai": [("ZAI_API_KEY", "BIGMODEL_API_KEY")],
}
COMPRESSORS = ("sips", "magick", "cwebp")


def check_runtime(path: str | None = None) -> dict:
    exe = shutil.which("bun", path=path)
    if not exe:
        return {"found": False, "bin": None, "version": None,
                "hint": "装 bun：brew install oven-sh/bun/bun；或用 npx -y bun 代替"}
    try:
        proc = subprocess.run([exe, "--version"], capture_output=True, text=True, timeout=30)
        version = proc.stdout.strip() or None
    except (OSError, subprocess.SubprocessError):
        version = None
    return {"found": True, "bin": exe, "version": version, "hint": None}


def check_providers(env: dict | None = None) -> dict:
    env = os.environ if env is None else env
    configured, missing = [], {}
    for name, groups in sorted(PROVIDER_ENV.items()):
        lacking = [g for g in groups if not any(env.get(k) for k in g)]
        if lacking:
            missing[name] = [" 或 ".join(g) for g in lacking]
        else:
            configured.append(name)
    return {"configured": configured, "missing": missing}


def check_compressors(path: str | None = None) -> dict:
    found = {t: bool(shutil.which(t, path=path)) for t in COMPRESSORS}
    # cwebp 不算数：它只产出 WebP，默认不参与降级链（见 compress.py）
    usable = found["sips"] or found["magick"]
    return {"found": found, "any": usable,
            "hint": None if usable else "装一个：macOS 自带 sips；或 brew install imagemagick"}


def report(runtime: dict, providers: dict, compressors: dict, conf: dict, as_json: bool) -> int:
    if as_json:
        print(json.dumps({"runtime": runtime, "providers": providers,
                          "compressors": compressors, "config": conf},
                         ensure_ascii=False, indent=2))
        return 0

    mark = lambda flag: "✅" if flag else "❌"  # noqa: E731

    print("== TS 运行时（imagegen 需要）==")
    print(f"  {mark(runtime['found'])} bun {runtime['version'] or ''} {runtime['bin'] or ''}".rstrip())
    if runtime["hint"]:
        print(f"     {runtime['hint']}")

    print("\n== provider 凭证 ==")
    if providers["configured"]:
        print(f"  ✅ 已配置：{', '.join(providers['configured'])}")
    else:
        print("  ❌ 一个都没配置。步骤 4 之前不影响——prompt 文件照样产出，"
              "拿去即梦 / Midjourney 自己生也行")
    for name, lacking in sorted(providers["missing"].items()):
        print(f"     - {name}：缺 {', '.join(lacking)}")

    print("\n== 压缩工具链 ==")
    for tool in COMPRESSORS:
        note = "（只产 WebP，需 --allow-webp）" if tool == "cwebp" else ""
        print(f"  {mark(compressors['found'][tool])} {tool}{note}")
    if compressors["hint"]:
        print(f"     {compressors['hint']}")

    print("\n== md2publish 配置 ==")
    print(f"  {cfg.config_path()}")
    for key in sorted(conf):
        print(f"     {key}: {conf[key]}")

    print("\n以上只是报告，不阻塞。缺凭证在生成那步拦，缺压缩工具在压缩那步拦。")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="生成前自检（只报告，不阻塞，永远退出 0）")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    try:
        conf = cfg.load_config()
    except cfg.ConfigError as e:
        # 配置坏了是唯一值得当场喊的事，但仍然不阻塞——用默认值继续报告
        print(f"配置文件有问题，已按默认值继续：{e}", file=sys.stderr)
        conf = dict(cfg.DEFAULTS)

    return report(check_runtime(), check_providers(), check_compressors(), conf, args.json)


if __name__ == "__main__":
    sys.exit(main())
