# OpenUI · 界面的秩序

交互式 Swift SDK 说明站点。六个章节连接语言、视觉尺度、组件边界、流式连续性、地图图解和宿主责任；组件目录覆盖默认注册的 87 项。

## 运行

```sh
cd sites/swift-sdk
npm ci
npm run dev
```

生产构建：`npm run build`。网站是静态产物，可部署到 GitHub Pages；`.github/workflows/swift-sdk-guide.yml` 负责 main 的部署。

## 唯一的数据来源

在 macOS 上运行 `npm run generate`：

- Swift 导出器实际实例化 `OpenUIThemeValues`，导出浅深色、透明度、字体、尺寸，并从 `OpenUIStandardComponents.library()` 导出 spec。
- Python 从现有 SDK 说明逐行取得用途与处理边界，从实际 `NativeTextRole` 读取行高，从标准示例和短能力标本构造参考索引。
- `source-manifest.json` 记录 SDK Swift 源码、本地化和固定目录的内容哈希。CI 的 `npm run check:data` 拒绝源文件变化后未重新导出的快照。
- `npm run validate:examples` 使用实际 Swift schema 校验所有站点示例。

主题没有独立手写一份数值表。页面框架有自己的阅读排版，SDK 尺度面板直接显示导出值。文章的六章为手写内容；组件逐项说明与契约从 SDK 文档和实际库生成。

## 交互与边界

字号、深浅色、Card 表面、按钮档位与目标范围、Form 选择与事件、流式阶段、Map 地点联动、SVG viewBox 都可操作。组件目录支持搜索、类别筛选、直接锚点、源码编辑和真实 Lang 预览。

Web 预览使用固定的 `@openuidev/react-ui@0.18.1`。该发布包遗漏 FollowUpBlock/Item 的注册；本站通过其已发布的 Web 组件与原有契约补齐。Map/MapPoint/SVG 有明确的 Web 适配器：地图使用 Leaflet/OpenStreetMap，SVG 使用隔离 iframe。它们不冒充 MapKit 或 WKWebView 的原生运行结果；GCJ-02 与远程 SVG 的完整资源策略在 Swift 宿主验证。

原理时间轴是可控的教学标本，不能作为 SDK 流式稳定性的验收证据。01—07 的内容仍来自标准示例；没有将 08 纳入本轮视觉验收。点击动作只显示事件，不调用 Agent、打开交易地址或执行业务。

## 验证与视觉比对

- SDK：444 项全量测试通过；本次契约、安全与坐标相关的 18 项定向测试在后续本地化修改后复跑通过。iOS 16 模拟器目标可编译，地图在 iOS 17/macOS 14 起呈现。
- 站点：TypeScript + Vite 生产构建通过；30 份源码经 Swift 实际 schema 校验。
- 浏览器：1440×900 与 390×844，页面整体无横向溢出；实际检查主题、尺度、播放、表面、按钮、表单、检索与编辑、时间轴、地图和 SVG。另复核 Card、FollowUpBlock、Modal、Slider、LineChart、Map、SVG 默认预览和动作，无未知组件或运行时错误。
- 视觉比对保留了样稿的白底阅读网格、大标题、轻导航、横向色板、文章与标本并置。没有引入侧栏后台、彩色卡片墙或虚构的 TravelCard。生成样稿中的错误字号替换为实际 SDK 导出值；手机按阅读顺序堆叠，双列标本保留双列。
- 没有覆盖所有 87 项的原生逐项视觉验收，也不把浏览器检查等同于 SwiftUI 验收。

SDK 图片沿用已有用例的外部地址；底图由 OpenStreetMap 提供并显示归属说明。外部资源故障与 Lang 诊断分别呈现。

图表预览使用 SDK 导出的平台系统色表。固定版本 npm 包的 GenUI 预编译入口内嵌了独立 ThemeContext，站点通过 Vite 引用同包已发布的源码入口，并启用 automatic JSX，使主题与图表共用上下文；缺失的生成图标映射使用同版本 Lucide 官方映射。没有复制或分叉组件实现。React 的系列选色分布顺序仍与 Swift 不同，网页预览不等同于原生验收。
