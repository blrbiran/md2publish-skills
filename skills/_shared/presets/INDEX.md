# 图片 preset 与维度词表索引

本文件是 preset 与 dimensions 的**唯一发现入口**。不要靠记忆列举 preset 名，
资产会持续增补——每次选 preset 都回来读这份索引。

## 怎么用

1. 按文章调性从下面的 preset 表里挑一个，用它的 `name` 传给 `--preset`。
2. 用户提了风格偏好（"换暖色"、"别那么花"）时，**不换整个 preset**，
   从维度表里找最接近的值，用 `--palette` / `--rendering` / `--layout` 覆盖那一维。
3. 平台画幅、文字上图策略、体积上限都由 `platforms/<name>.yaml` 决定，
   preset 不管这些——同一个 preset 在微信和小红书会渲染出不同的画幅约束。

## Preset

| name | archetype | 适用 | palette | rendering | layout | 不适用平台 |
|---|---|---|---|---|---|---|
| `editorial-warm` | cover | 人文随笔与商业观察类长文的封面 | `warm-earth` | `flat-vector` | — | — |
| `bento-cool` | infographic | 需要并列展示 4–8 个要点的技术类内容 | `cool-slate` | `flat-vector` | `bento-grid` | — |
| `inline-warm` | illustration | 长文中段落之间的呼吸性插图，不承载信息密度 | `warm-earth` | `soft-gouache` | — | 小红书 |
| `card-warm` | series | 把一篇长文拆成 5–10 张可独立阅读的图卡 | `warm-earth` | `flat-vector` | `bento-grid` | 微信 |

archetype 与平台的支持关系由 `platforms/*.yaml` 的 `archetypes` 槽决定，
槽值为 `unsupported` 时该组合会被渲染器直接拒绝。当前：微信不支持 `series`，
小红书不支持 `illustration`。

## 维度：配色（`--palette`）

| value | 气质 | 用户可能怎么说 |
|---|---|---|
| `warm-earth` | 烧赭与陶土橙，米白打底，柔和 | 暖一点、温和、有人味、纸质感 |
| `cool-slate` | 石板蓝与钢灰，雾白打底，克制 | 冷一点、专业、理性、科技感 |

## 维度：渲染（`--rendering`）

| value | 气质 | 用户可能怎么说 |
|---|---|---|
| `flat-vector` | 扁平矢量，纯色块，无渐变无投影 | 干净、简洁、现代、别太花 |
| `soft-gouache` | 柔和水粉，可见笔触与颗粒 | 手绘感、有温度、别那么硬 |

## 维度：版式（`--layout`）

只有 `infographic` 和 `series` 两个 archetype 用得上。

| value | 结构 | 用户可能怎么说 |
|---|---|---|
| `bento-grid` | 大小不等的矩形格子，主信息占最大格 | 分块、卡片式、一格一个要点 |

## 增补资产时

- 新增 preset：放进 `presets/<archetype>/`，必填字段见 `scripts/asset_lib.py` 的
  `PRESET_REQUIRED_FIELDS`，然后回来更新上面的表——`test-asset-schema.sh` 会检查
  INDEX 是否收录了全部 preset 与 dimension，漏了直接 fail。
- 新增维度值：放进 `presets/dimensions/<kind>/<value>.md`，正文是一段可直接嵌进
  prompt 的中文描述，同样要回来更新表格。
- 新增平台：加一个 `platforms/<name>.yaml`，5 个 archetype 槽必须全部定义
  （不适用的写 `unsupported`）。**不需要**回头改任何 preset——preset 用的是排除制
  `incompatible_platforms`，新平台默认可用。
