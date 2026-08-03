# velvet-stage 丝绒剧场（扩展主题·暗色）

> 深酒红黑底 + 幕布红 + 鎏金字，开演前的剧场（区别于冷调 cyber-neon 和暖纸 midnight-study）。适合影评、剧评、音乐现场、演出预告。
> 用法：与 `_common-tech.md` 一起交给生成模型，技术约束以该文件为准。

## 核心愿景

大幕未启的剧场：绒布吸掉了大部分光，金色是舞台边缘漏出来的灯。庄重带一点戏剧性的华丽——但华丽在"质感"（深色层次、金线），不在亮度。

## 色彩系统

- 剧场黑底：`#1d1216`（主容器，带一丝酒红）
- 绒布面板：`#2a1a20`
- 正文暖白：`#e8dcd2`
- 鎏金（主强调）：`#c9a36a`
- 幕布红（副强调）：`#a04252`
- 次级灰褐：`#96857e`
- 边线：`#46303a`

## 容器与布局

- 主容器：`background-color: #1d1216; padding: 42px 14px; letter-spacing: 0.8px`
- 章节面板：`background-color: #2a1a20; border: 1px solid #46303a; border-radius: 10px; padding: 26px 22px; margin: 0 0 34px`

## 标题体系

- 标题衬线字族：`Georgia, 'Songti SC', 'Noto Serif SC', serif`
- h2：金色居中 + 两侧幕布红短线——`<h2 style="text-align: center; font-size: 19px; font-weight: 600; color: #c9a36a; letter-spacing: 4px; margin: 0 0 22px;"><span style="color: #a04252;">━&nbsp;</span>标题文本<span style="color: #a04252;">&nbsp;━</span></h2>`
- h3：`font-size: 16px; font-weight: 600; color: #e8dcd2; text-align: left; margin: 26px 0 12px; padding-left: 10px; border-left: 3px solid #a04252`

## 正文与强调

- 段落：`font-size: 15.5px; line-height: 1.9; color: #e8dcd2; margin: 0 0 18px; text-align: left`
- strong：`color: #c9a36a; font-weight: 600`
- em / 作品名、台词引语：`color: #96857e`

## 引用 / 代码 / 列表 / 表格

- 引用块（台词、歌词是主场）：居中排——`background-color: #241419; padding: 18px 22px; margin: 0 0 18px; color: #c9a36a; font-size: 15px; line-height: 1.9; text-align: center; border-top: 1px solid #46303a; border-bottom: 1px solid #46303a`，衬线字族，像场刊上的引文页
- 代码块（少见但要能用）：`<pre>` 底 `#150d10`、文字 `#e8dcd2`、`border: 1px solid #46303a; border-radius: 8px; padding: 15px 17px; font-size: 13px`；行内 code：底 `#150d10`、文字 `#c9a36a`
- 列表前缀 `·&nbsp;&nbsp;`；演出信息类条目用金色小标 `<span style="color: #c9a36a; font-weight: 600;">▸</span>&nbsp;&nbsp;`
- 表格（场次/曲目单）：表头底 `#150d10`、文字 `#c9a36a`，单元格 `border: 1px solid #46303a; padding: 9px 11px; font-size: 14px; color: #e8dcd2`

## 分寸提醒

暗色主题通用风险：所有文字显式写亮色 `color`，漏一处就是黑底黑字；微信 App 深色/浅色双模式都要手机预览。幕布红永远不做文字主色（暗底上红字难读），只做线条和短符号。
