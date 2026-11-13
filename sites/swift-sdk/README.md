# OpenUI · 界面的秩序

面向展示与讲述的交互式 Swift SDK 说明站点。正文呈现工作原理、设计决策、示例与当前限制，不加入讲稿工具、阅读指引或编辑过程。

保持白底阅读网格与原有视觉标本，主线为四章：工作原理 → 设计系统 → 流式渲染 → 当前限制。第二章直接包含设计系统总图，以及 2.1 排版与颜色、2.2 间距与形状、2.3 组件结构与状态、2.4 组件目录与 API、2.5 地图与 SVG、2.6 组合模式；章节及核心内容不折叠。组件目录覆盖默认注册的 87 项。

## 运行

```sh
cd sites/swift-sdk
npm ci
npm run dev
```

生产构建：`npm run build`。网站是静态产物，`.github/workflows/swift-sdk-guide.yml` 负责 main 的 GitHub Pages 部署。

## 内容与版本归属

- `src/baseline.ts` 记录已核对的 RC20 tag、提交与发布日期；发布包、当前客户端依赖和历史截图分别标明。
- `SystemArticle.tsx` 保留常驻流程图与四层总图。总图的表面与状态可以切换，Card 表面与 2.3 示例共享选择；2.2 使用 SDK 导出的既有 Token 选择 Padding、Gap、Corner Radius，直接驱动局部几何示例。默认值不被改写。
- `DesignFrontiers.tsx` 只列实现与验证缺口，图库末行铺满单独标记为暂缓的设计选择。
- `main.tsx` 将全部组件示例和 API 放在第二章，核心说明和参数直接展示。选择组件后自动显示可操作预览，源码编辑单独展开；预览进入阅读区域后才加载。组件深链接、编辑状态和事件保留。
- 章节按设计责任组织，没有按版本先后排列修复流水。事实依据来自 SDK README、逐组件说明、UI-DESIGN 与相应源码／回归。

## 唯一的数据来源

在 macOS 上运行 `npm run generate`：

- Swift 导出器实例化 `OpenUIThemeValues`，导出浅深色、透明度、字体、尺寸和系统图表色表，从 `OpenUIStandardComponents.library()` 导出 spec。
- Python 从 SDK 说明取得各组件用途与处理边界，从实际 `NativeTextRole` 读取行高，从标准示例和短能力标本构造参考索引。
- `source-manifest.json` 记录 SDK Swift 源码、本地化和固定目录的内容哈希。`npm run check:data` 拒绝源文件变化后未重新导出的快照。
- `npm run validate:examples` 使用实际 Swift schema 校验 30 份站点示例。

页面框架保留自己的阅读排版，SDK 尺度面板直接显示导出值。文章由编辑维护，组件逐项说明与契约由 SDK 文档和实际库生成；不手写另一套默认 token。

## 交互与分隔

章节、子节、示例与字阶以标题、对齐和留白分组，删除重复的页面级横线。Card、Form、控件及 Anatomy 槽位等示例自身的语义边界保留。总图与几何控制展示局部 Web 状态，ButtonPreview 区分可用、执行中和禁用；不执行实际业务，不新增 Lang 参数。

## Web 与原生的边界

Web 预览使用固定的 `@openuidev/react-ui@0.18.1`。该包遗漏 FollowUpBlock/Item 的注册；本站通过其已发布的 Web 组件与原有契约补齐。Map/MapPoint/SVG 有明确的 Web 适配器：地图使用 Leaflet/OpenStreetMap，SVG 使用隔离 iframe。它们与 MapKit／WKWebView 原生运行结果分别标识；GCJ-02 与远程 SVG 的完整资源策略在 Swift 宿主验证。

原理时间轴和工作流程图为可控教学标本。01—07 来自标准示例，08 未纳入本轮视觉验收。点击动作只显示事件，不调用 Agent 或执行交易。原生图片折叠区保留 b93023f6 迁入阶段的截图与 manifest，不冒充 RC20 的新验收。

图表预览使用 SDK 导出的系统色表。GenUI 预编译入口内嵌独立 ThemeContext，Vite 因此引用同包已发布源码入口，让主题与图表共用上下文，并使用同版本 Lucide 官方映射。没有分叉组件实现；React 系列选色顺序与 Swift 仍可能不同。

## 验证方式

本次文章更新不修改 SDK 运行代码。SDK 发行验收以 RC20 发布记录为准；网页验证涵盖 TypeScript／Vite、生成数据一致性、示例语法、桌面与手机阅读及交互。

重点检查四章层级、第二章各节的可见归属、设计系统总图、字体角色与真实导出值、间距和圆角标本、深链接与状态保留、地图尺寸、问题筛选，以及主题／表面／表单／组件预览。页面视觉沿用原基调，使用常驻的编号、标题与关系图表达结构；可选披露只容纳原始数据和证据。网页检查不扩大为全部 87 项的原生验收。

SDK 图片沿用用例的外部地址，底图由 OpenStreetMap 提供并显示归属说明。外部资源故障与 Lang 诊断分别呈现。

## 预览加载

组件定义、Schema 和状态逻辑保持官方实现。CodeBlock 高亮、图表、日期选择器和可编辑表格的视图通过薄 Suspense 包装按使用加载，引用同一固定包的原始源码，未复制或修改组件实现。局部视图加载不阻塞整份组件契约注册。

首次预览入口从约 1.97MB 降为 1.05MB，gzip 从约 587KB 降为 274KB；组件区域前一节进入视口时提前预热。该指标描述构建体积，不保证某一网络下的固定加载时长。
