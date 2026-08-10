#!/usr/bin/env python3
"""preflight.py / config.py 的测试。

重点在**失败分支**：本机三样工具齐全，不注入空 PATH 就永远测不到缺失路径。
"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import config as cfg          # noqa: E402
import preflight as pf        # noqa: E402

PASS = 0
FAIL = 0


def ok(msg: str) -> None:
    global PASS
    print(f"  ✅ {msg}")
    PASS += 1


def bad(msg: str, detail: str) -> None:
    global FAIL
    print(f"  ❌ {msg}")
    print(f"     {detail}")
    FAIL += 1


def check(cond: bool, msg: str, detail: str = "") -> None:
    ok(msg) if cond else bad(msg, detail)


print("== TS 运行时 ==")
real = pf.check_runtime()
check(real["found"] and real["version"], "真实 PATH 下找到 bun 并拿到版本号", str(real))
empty = pf.check_runtime(path="")
check(not empty["found"] and empty["hint"], "空 PATH 下报缺失并给出安装提示", str(empty))

print("\n== 压缩工具 ==")
real_c = pf.check_compressors()
check(real_c["found"]["sips"] and real_c["any"], "真实 PATH 下 sips 可用", str(real_c))
empty_c = pf.check_compressors(path="")
check(
    not any(empty_c["found"].values()) and not empty_c["any"] and empty_c["hint"],
    "空 PATH 下三者皆缺、any=False 且给出提示",
    str(empty_c),
)

print("\n== provider 凭证 ==")
# env_files=[] 是**必须的**：不关掉 .env 读取，这些失败分支会被本机真实的
# ~/.baoyu-skills/.env 污染，断言就此失去意义。
none_p = pf.check_providers(env={}, env_files=[])
check(none_p["configured"] == [], "无任何环境变量时 configured 为空", str(none_p))
check(set(none_p["missing"]) == set(pf.PROVIDER_ENV), "缺失清单覆盖全部 provider", str(sorted(none_p["missing"])))

one_p = pf.check_providers(env={"OPENAI_API_KEY": "sk-x"}, env_files=[])
check(one_p["configured"] == ["openai"], "只配 OPENAI_API_KEY 时只认 openai", str(one_p))

half_azure = pf.check_providers(env={"AZURE_OPENAI_API_KEY": "x"}, env_files=[])
check("azure" not in half_azure["configured"], "azure 缺 BASE_URL 时不算已配置", str(half_azure))

alias = pf.check_providers(env={"GEMINI_API_KEY": "x"}, env_files=[])
check("google" in alias["configured"], "GEMINI_API_KEY 是 GOOGLE_API_KEY 的别名", str(alias))

print("\n== .env 文件（引擎 loadEnv 的同款来源）==")
with tempfile.TemporaryDirectory() as d:
    home_env = Path(d) / "home.env"
    cwd_env = Path(d) / "cwd.env"
    home_env.write_text(
        '# 注释行\nOPENAI_API_KEY="sk-from-home"\nARK_API_KEY=ark-home\n没有等号的行\n',
        encoding="utf-8",
    )
    cwd_env.write_text("OPENAI_API_KEY=sk-from-cwd\nMINIMAX_API_KEY=mm-cwd\n", encoding="utf-8")

    from_file = pf.check_providers(env={}, env_files=[home_env])
    check(
        from_file["configured"] == ["openai", "seedream"],
        "只写在 .env 里的凭证也算已配置（不再误报'一个都没配置'）",
        str(from_file),
    )
    check(
        from_file["sources"]["openai"]["OPENAI_API_KEY"] == str(home_env),
        "报告里点名凭证来自哪个 .env 文件",
        str(from_file["sources"]),
    )

    win = pf.check_providers(env={"OPENAI_API_KEY": "sk-from-process"},
                             env_files=[home_env, cwd_env])
    check(
        win["sources"]["openai"]["OPENAI_API_KEY"] == pf.ENV_SOURCE_PROCESS,
        "进程环境变量压过 .env（与引擎 loadEnv 的优先级一致）",
        str(win["sources"]),
    )

    order = pf.resolve_env(env={}, env_files=[home_env, cwd_env])
    check(
        order["OPENAI_API_KEY"] == ("sk-from-home", str(home_env))
        and order["MINIMAX_API_KEY"][0] == "mm-cwd",
        "home 的 .env 压过 cwd 的 .env，各自独有的 key 都保留",
        str(order),
    )

    off = pf.check_providers(env={}, env_files=[])
    check(off["configured"] == [] and off["env_files"] == [],
          "env_files=[] 能彻底关掉文件读取（失败分支断言才可信）", str(off))

    # 非 UTF-8 的 .env（如误存成 UTF-16 或含单个坏字节）不该让 preflight 崩溃。
    bad_env = Path(d) / "bad.env"
    bad_env.write_bytes(b"OPENAI_API_KEY=sk-\xff\xfe-bad\n")
    bad_parsed = pf.parse_env_file(bad_env)  # 不抛异常即是关键断言
    check(
        bad_parsed.get("OPENAI_API_KEY", "").startswith("sk-") and "�" in bad_parsed["OPENAI_API_KEY"],
        "非 UTF-8 字节被替换为 U+FFFD 而不是让整份文件解析失败",
        str(bad_parsed),
    )

    default_files = [e["path"] for e in pf.check_providers(env={})["env_files"]]
    check(
        default_files == [str(Path.home() / pf.ENV_FILE_RELPATH),
                          str(Path.cwd() / pf.ENV_FILE_RELPATH)],
        "默认查的就是引擎那两个位置：~/.baoyu-skills/.env 与 <cwd>/.baoyu-skills/.env",
        str(default_files),
    )

print("\n== 配置文件 ==")
with tempfile.TemporaryDirectory() as d:
    missing = Path(d) / "images.yaml"
    conf = cfg.load_config(missing)
    check(conf == cfg.DEFAULTS, "文件不存在时返回全默认", str(conf))

    good = Path(d) / "good.yaml"
    good.write_text("provider: openai\nmodel: gpt-image-2\nmax_images_per_run: 4\n", encoding="utf-8")
    conf = cfg.load_config(good)
    check(
        conf["provider"] == "openai" and conf["model"] == "gpt-image-2"
        and conf["max_images_per_run"] == 4 and conf["max_concurrency"] == 3,
        "已给字段生效、未给字段保持默认",
        str(conf),
    )

    unknown = Path(d) / "unknown.yaml"
    unknown.write_text("provder: openai\n", encoding="utf-8")
    try:
        cfg.load_config(unknown)
        bad("未知字段应硬失败", "没抛异常——拼错的字段会被静默忽略")
    except cfg.ConfigError as e:
        check("provder" in str(e), "未知字段硬失败并点名", str(e))

    negative = Path(d) / "negative.yaml"
    negative.write_text("max_concurrency: 0\n", encoding="utf-8")
    try:
        cfg.load_config(negative)
        bad("非正整数应硬失败", "没抛异常")
    except cfg.ConfigError as e:
        check("max_concurrency" in str(e), "非正整数硬失败并点名", str(e))

print("\n== 只报告不阻塞 ==")
rc = pf.report(runtime=pf.check_runtime(path=""), providers=pf.check_providers(env={}, env_files=[]),
               compressors=pf.check_compressors(path=""), conf=dict(cfg.DEFAULTS), as_json=False)
check(rc == 0, "三项全缺时仍返回 0（拦截发生在后面的步骤）", f"rc={rc}")

print(f"\n通过 {PASS} 项，失败 {FAIL} 项")
sys.exit(0 if FAIL == 0 else 1)
