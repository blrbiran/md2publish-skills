# 微信凭证配置与排障（免费路径）

免费路径只需要三样：`WECHAT_APPID`、`WECHAT_SECRET`、IP 白名单。不需要 `MD2WECHAT_API_KEY`。

## 获取 AppID / AppSecret

1. 打开 https://developers.weixin.qq.com/platform ，用公众号管理员微信扫码登录
2. 选择目标公众号（多个号时注意别选错）
3. 进入「开发接口管理」
4. 复制「开发者ID(AppID)」
5. 「开发者密码(AppSecret)」需要点「重置」并完成管理员验证才能拿到

⚠️ 重置会让旧 AppSecret 立即失效。如果这个号在别的系统里也在用同一个 secret，重置前先确认。

## 写入配置

```bash
md2wechat config init
```

编辑 `~/.config/md2wechat/config.yaml`，用**扁平写法**（不要用 `accounts:` 命名账号——那会强制校验付费 API key）：

```yaml
wechat:
  appid: "你的 AppID"
  secret: "你的 AppSecret"
```

或环境变量：

```bash
export WECHAT_APPID="..."
export WECHAT_SECRET="..."
```

验证：

```bash
md2wechat config validate
md2wechat doctor --json     # 看 wechat.config 是否 PASS；api.config FAIL 是预期，忽略
```

## IP 白名单

微信除了校验凭证，还要求发起请求那台机器的**公网 IP** 在白名单里。这是 `upload_image` / `create_draft` 最常见的失败原因。

1. 在**实际运行 md2wechat 的机器**上查公网 IP：
   ```bash
   curl ifconfig.me
   ```
2. 回到微信开发者平台 → 该公众号 →「开发接口管理」→「IP白名单」→ 设置/修改
3. 填入查到的 IP，保存
4. 等 1–5 分钟生效后重试

常见坑：

- 本地查的 IP ≠ 服务器出口 IP——白名单要加的是真正发请求那台机器的 IP
- 家庭宽带 / 公司网络的公网 IP 会变，"昨天能用今天报错"是正常现象，重新查 IP 更新白名单即可
- CI / 动态云环境 IP 不固定，不适合直接调微信接口

## 排障速查

| 报错 | 原因 | 处理 |
|---|---|---|
| `ip xxx not in whitelist` | 当前公网 IP 不在白名单 | 按上面流程加白名单，等几分钟 |
| `WECHAT_APPID is required` | 凭证没写入配置或环境变量 | 检查 `config show --format json` 的 `config_file` 是不是预期文件 |
| invalid appid / 40013 | AppID 抄错或选错公众号 | 回开发接口管理页核对 |
| invalid credential / 40001 | AppSecret 错误或已被重置 | 重新获取并更新配置 |
| `45004` | digest/摘要不合规 | 检查摘要内容和长度（≤128 字符） |
| `API_KEY_REQUIRED` | 配置里有 `accounts:` 命名账号或 `proxy_url` | 改回扁平 `wechat.appid/secret` 写法 |

不确定当前生效的是哪份配置时：

```bash
md2wechat config show --format json   # 重点看 config_file 字段
```
