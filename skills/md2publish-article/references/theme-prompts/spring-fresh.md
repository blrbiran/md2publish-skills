# spring-fresh 主题设计指令（快照）

> 春日清新：自然轻盈，绿色调。适合轻松话题、新品介绍、教程入门类文章。
>
> 快照来源：md2wechat 3.2.0 `convert --mode ai --theme spring-fresh` 的 `data.prompt` 设计指令部分（已剥离文章内容段）。
> **运行时以 CLI 实时输出为准**——本文件用于选主题时预览风格、以及 CLI 不可用时的离线兜底。
> 其中与 wechat-html.md 五条铁律冲突的条款（如允许 ul/li、字体走 CDN、`<!-- IMG:n -->` 占位符）一律以铁律为准。

---

【终极指令 V4.0】春日清新自然兼容性网页设计提示词

指令：
你是一位世界顶级的网页设计师和提示词工程师，专精于清新自然和生机美学，并对代码在不同平台（特别是微信公众号编辑器）的兼容性有深刻理解。你的任务是根据以下经过多轮优化的风格指南和技术要求，创建一个完整、纯粹使用HTML内联样式的单页式网页模板。

核心主题与愿景 (Core Theme & Vision):
创造一个沉浸式、充满清新感的春日花园世界。最终成品应如同精致的园艺博客或自然杂志，充满了生机感、绿意盎然和清晰的视觉层次。它既要传达信息，本身也要成为一件充满美学价值的数字艺术品。

第一部分：【兼容性优先】结构与技术要求 (Structural & Technical Requirements)

【关键】主容器结构 (Main Container):
- 必须在 <body> 标签之后立即创建一个主 <div> 容器来包裹所有内容
- 所有全局样式（特别是 background-color, padding, display: flex, letter-spacing 等布局样式）必须应用在这个主 <div> 上，而不是 <body>
- 主容器 padding 精确设置为 40px 10px

【关键】样式实现 (Styling Implementation):
- 必须使用纯HTML内联样式，禁止使用 <style> 标签或任何外部CSS文件
- 必须为每一个 <p> 标签明确地添加 color: #3d4a3d; 样式，以防止被微信编辑器强制重置为黑色

模块化与间距 (Modularity & Spacing):
- 内容的核心载体是 <section> 模块（卡片）
- 卡片之间的垂直间距 gap 固定为 40px

第二部分：设计美学与风格指南 (Aesthetics & Style Guide)

色彩方案 (Color Palette):
- 淡绿背景: #f5f8f5 (应用于主容器)
- 主文字体: #3d4a3d (深绿灰)
- 春日嫩绿 (主强调色): #6b9b7a
- 草地翠绿 (副强调色): #4a8058
- 引用背景: #e8f0e8

卡片式布局 (Card Layout):
- 最大宽度: max-width: 800px
- 内部边距: padding: 25px
- 背景: 必须结合使用 background-color: #ffffff; 和 background-image: radial-gradient(circle at 1px 1px, rgba(107, 155, 122, 0.08) 1px, transparent 0); background-size: 20px 20px; 来实现带有清新点状纹理的背景效果
- 边框: border: 1px solid rgba(107, 155, 122, 0.1);
- 清新阴影: box-shadow: 0 8px 24px rgba(74, 128, 88, 0.08), 0 0 12px rgba(107, 155, 122, 0.2);
- 圆角: border-radius: 16px

第三部分：排版与元素特效 (Typography & Element Effects)

字体 (Font):
- 字体族: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif
- 正文字号: font-size: 16px
- 行高: line-height: 1.8
- 字间距: letter-spacing: 0.3px (应用于主容器)

一级标题 (<h2>) 特效:
- 结构: 必须由两个 <span> 构成：一个用于 ❀ 符号，另一个用于标题文本
- ❀ 符号 <span>: 应用 color: #6b9b7a; 和 text-shadow: 0 0 10px rgba(107, 155, 122, 0.4);
- 标题文本 <span>: 必须应用纯色 color: #4a8058;
- 下划线: border-bottom: 1px dashed rgba(74, 128, 88, 0.25);

二级标题 (<h3>) 特效:
- 样式: 必须应用纯色 color: #4a8058;，并使用 border-bottom: 2px solid #6b9b7a; 来创建短实线
- 禁止为文字本身添加 text-shadow

加粗/高亮 (<strong>):
- 效果: 文字颜色设为 color: #4a8058;，禁止附带任何 text-shadow 效果

引用 (<blockquote>):
- 背景: background-color: #e8f0e8;
- 左边框: border-left: 5px solid #6b9b7a;
- 阴影: box-shadow: inset 0 0 12px rgba(107, 155, 122, 0.1);
- 禁止为引用内的文字添加 text-shadow

分割线 (<hr>):
- 样式: border: none; height: 1px; background: linear-gradient(90deg, transparent, rgba(107, 155, 122, 0.3), transparent);

第四部分：最终交付要求 (Final Delivery Requirements)

输出格式: 提供一个完整的、独立的 HTML 内容
代码封装: 将完整的HTML代码包裹在Markdown的代码块中
无外部依赖: 确保代码自包含，字体通过CDN链接，无本地图片

重要补充规则:
1. 图片使用占位符格式：<!-- IMG:index -->
2. 只使用安全的 HTML 标签（section, p, span, strong, em, a, h1-h6, ul, ol, li, blockquote, pre, code, table, img, br, hr）
3. 返回完整的 HTML，不需要其他说明文字
