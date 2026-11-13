# OpenUI · 界面的秩序

面向展示与讲述的交互式 Swift SDK 说明站点。正文呈现工作原理、设计决策、示例与当前限制，不加入讲稿工具、阅读指引或编辑过程。

保持白底阅读网格与原有视觉标本，主线只保留四章：工作流程 → 设计系统 → 流式渲染 → 当前限制。排版、按钮、表单、地图和组件 API 保留在按需展开的参考区。目录覆盖默认注册的 87 项。

## 运行

```sh
cd sites/swift-sdk
npm ci
npm run dev
```

生产构建：`npm run build`。网站是静态产物，`.github/workflows/swift-sdk-guide.yml` 负责 main 的 GitHub Pages 部署。

## 内容与版本归属

- `src/baseline.ts` 记录已核对的 RC20 tag、提交与发布日期；发布包、当前客户端依赖和历史截图分别标明。
- `SystemArticle.tsx` 说明工作流程和视觉规范（Foundations）、设计变量（Design Tokens）、组件（Components）、组合模式（Patterns）；`overview` 是页面的 SDK 简介。术语表链接 Material、Carbon、Apple 与 React 官方依据。
- `DesignFrontiers.tsx` 只列实现与验证缺口，图库末行铺满单独标记为暂缓的设计选择。
- `main.tsx` 默认收起参考面板，从正文链接或组件深链接进入时自动展开。控件和编辑状态保留；Map 在面板尺寸变化后重新计算视口。工作流程图和时间轴属于教学内容。
- 章节按设计责任组织，没有按版本先后排列修复流水。事实依据来自 SDK README、逐组件说明、UI-DESIGN 与相应源码／回归。

## 唯一的数据来源

在 macOS 上运行 `npm run generate`：

- Swift 导出器实例化 `OpenUIThemeValues`，导出浅深色、透明度、字体、尺寸和系统图表色表，从 `OpenUIStandardComponents.library()` 导出 spec。
- Python 从 SDK 说明取得各组件用途与处理边界，从实际 `NativeTextRole` 读取行高，从标准示例和短能力标本构造参考索引。
- `source-manifest.json` 记录 SDK Swift 源码、本地化和固定目录的内容哈希。`npm run check:data` 拒绝源文件变化后未重新导出的快照。
- `npm run validate:examples` 使用实际 Swift schema 校验 30 份站点示例。

页面框架保留自己的阅读排版，SDK 尺度面板直接显示导出值。文章由编辑维护，组件逐项说明与契约由 SDK 文档和实际库生成；不手写另一套默认 token。

## Web 与原生的边界

Web 预览使用固定的 `@openuidev/react-ui@0.18.1`。该包遗漏 FollowUpBlock/Item 的注册；本站通过其已发布的 Web 组件与原有契约补齐。Map/MapPoint/SVG 有明确的 Web 适配器：地图使用 Leaflet/OpenStreetMap，SVG 使用隔离 iframe。它们与 MapKit／WKWebView 原生运行结果分别标识；GCJ-02 与远程 SVG 的完整资源策略在 Swift 宿主验证。

原理时间轴和工作流程图为可控教学标本。01—07 来自标准示例，08 未纳入本轮视觉验收。点击动作只显示事件，不调用 Agent 或执行交易。原生图片折叠区保留 b93023f6 迁入阶段的截图与 manifest，不冒充 RC20 的新验收。

图表预览使用 SDK 导出的系统色表。GenUI 预编译入口内嵌独立 ThemeContext，Vite 因此引用同包已发布源码入口，让主题与图表共用上下文，并使用同版本 Lucide 官方映射。没有分叉组件实现；React 系列选色顺序与 Swift 仍可能不同。

## 验证方式

本次文章更新不修改 SDK 运行代码。SDK 发行验收以 RC20 发布记录为准；网页验证涵盖 TypeScript／Vite、生成数据一致性、示例语法、桌面与手机阅读及交互。

重点检查默认阅读长度、四章层级、参考区自动展开与状态保留、地图展开后的尺寸、流程点选、问题筛选，以及主题／字号／表面／表单／组件预览。页面视觉沿用原基调，新增信息使用文章网格、行式结构和渐进披露，不增加后台侧栏或等权卡片墙。网页检查不扩大为全部 87 项的原生验收。

SDK 图片沿用用例的外部地址，底图由 OpenStreetMap 提供并显示归属说明。外部资源故障与 Lang 诊断分别呈现。
