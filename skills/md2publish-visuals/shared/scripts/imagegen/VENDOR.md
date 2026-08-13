# imagegen —— vendor 自 baoyu-image-gen

本目录是**拷贝**，不是原创代码。改这里之前先读完本文件。

## 来源

| 项 | 值 |
|---|---|
| 上游仓库 | `~/code/skills/writing/baoyu-skills` |
| 上游路径 | `skills/baoyu-image-gen/scripts/` |
| 上游 commit | `6b7a2e4` |
| 搬入日期 | 2026-08-10（二期 A） |
| 第三方依赖 | **零**。所有 import 都是 `node:*` 或相对路径 |
| 运行时 | bun（本机 1.3.14）。不需要 `package.json`，不需要 `tsconfig.json` |

## 排除了什么

| 排除项 | 理由 |
|---|---|
| `providers/codex-cli.ts` + `.test.ts` | 二期 A 首批不含 codex-cli 后端 |
| `codex-imagegen/`（7 个文件） | 上面那个 provider 的 wrapper 实现 |
| `build-batch.ts` + `.test.ts` | baoyu 专用的"大纲 → batch.json"转换器，依赖 `tsx`，本仓库不需要 |
| `references/`、`SKILL.md` | 上游文档 |

## 相对上游改了什么（只有两处）

1. **`main.ts` `loadProviderModule()`**：`codex-cli` 分支由 `await import("./providers/codex-cli")`
   改为 `throw new Error("codex-cli provider is not vendored in md2publish-skills. ...")`。
   理由：该 provider 未 vendor，静默 import 一个不存在的模块会给出难懂的模块解析错误。
2. **`main.ts` `MAX_ATTEMPTS`**：`3` → `2`。
   理由：设计文档 §9 规定"单张最多 2 次**计费**尝试"。一次超时的图片 API 调用可能已经计费，
   按次数重试三遍等于一张图扣三次钱。

**除这两处外逐字未改**，因此可以直接与上游 diff：

```bash
diff -r -x '*.test.ts' <上游>/skills/baoyu-image-gen/scripts <本目录>
```

## 怎么跟上游同步

1. 在上游确认要的改动，`diff` 出来。
2. 覆盖本目录对应文件。
3. **重新打上面两处修改**（`git diff` 会提醒你它们不见了）。
4. `bun test skills/_shared/scripts/imagegen`，期望 97 pass / 0 fail。
5. `scripts/sync-shared.sh` 把新版本推到各 skill 的 `shared/`。
6. 更新本文件的上游 commit 与日期。
