# OpenUISwiftUI

OpenUI 的原生 SwiftUI 渲染 SDK，依赖方向为 `swift-ui → swift-lang → lang-core`。SwiftPM 产品为 `OpenUISwiftUI` 和 `OpenUILang`。

本文是整体设计入口，说明设计目标、组件职责和关键取舍。完整组件处理见 [SDK 设计与组件说明](SDK-REFERENCE.zh-CN.md)，渲染和验收边界见 [UI-DESIGN.md](UI-DESIGN.md)，公开 API 见 [组件编写](COMPONENTS.md)与[架构](ARCHITECTURE.md)。

> **版本范围（2026-11-12）**：本文对应 [0.1.1-rc.20](https://github.com/zyfn/openui/releases/tag/0.1.1-rc.20) 的设计。RC19 不包含本版后续的卡片、图库和预览改进。图库末行铺满的方案仍暂停；SVG 的 WebView 渲染完成阶段尚未补齐加载反馈。客户端是否采用本版，以实际依赖和导出的契约为准。

## 整体设计

### 1. 一条回答怎样成为可阅读、可操作的页面

**Intelligent UI 是 Assistant Message 中可阅读、理解和操作的内容页面；OpenUI Lang 声明这页内容的结构、数据、状态与动作。** SDK 将它映射为原生界面。页面可以很轻，也可以包含图文、比较、数据或局部操作，不要求每条回答都成为卡片墙或表单。

```text
Agent 使用实际组件契约组织回答
  → assistant 正文交付完整 OpenUI Lang
  → 共享核心解析、求值，OpenUIState 维持程序状态
  → 原生组件根据空间与就绪状态逐步呈现
  → 用户浏览、选择或提交
  → 宿主处理 ActionEvent、导航、业务执行和后续 Agent 请求
```

| 归属 | 责任 |
| --- | --- |
| Lang 与注册库 | 合法组件、位置参数、类型、槽位、绑定和动作语义 |
| SDK | 字体与颜色、布局测量、控件状态、资源、增量呈现及事件生成 |
| 客户端宿主 | 消息生命周期、实际注册库、资源权限与代理、事件回传、导航与真正执行 |
| 服务端／Agent | 事实来源、信息组织、组件选择，以及下一步意图 |

SDK 不按地名、商品名或 case 编号选择布局。生成规范来自客户端实际注册库；渲染库和生成库可能不同，不手工维护第二套签名。

### 2. 视觉基调与 token

以连续阅读为主，用留白、对齐和文字层级建立秩序；表面、描边、图标和状态色承担具体职责。字体采用平台系统字体，数字保留数字角色。明暗外观与系统文字缩放沿用同一套语义。

- **文字先定角色，再取样式。** 当前默认对象标题 18pt 半粗、正文 16pt、紧凑正文与辅助信息 14pt；主文字和辅助文字按职责区分颜色。小字号不自动等于浅色，价格、时间和按钮保持自己的尺度。
- **颜色表达含义。** 普通属性使用中性色；成功、警告、错误有真实状态依据时才使用状态色。图表分类色属于数据表达，与控件状态色分别管理。
- **尺寸、优先级和宽度分开。** 按钮 variant 表达强调程度，size 决定尺寸，容器决定是否通栏。可见小按钮不会因为触控区域而变成大块底色。
- **几何与主题分开。** `OpenUITheme` 管共享字体、颜色、间距和表面；`OpenUIPresentation` 管原生阅读宽度、媒体比例、触控目标和动效，不成为新的 Lang 参数。

完整字号、字重、颜色与行距见[文字角色表](SDK-REFERENCE.zh-CN.md#31-文字和颜色)。映射集中在 [TextStyles.swift](Sources/OpenUISwiftUI/Theme/TextStyles.swift)，实际值来自 [OpenUITheme.swift](Sources/OpenUISwiftUI/Theme/OpenUITheme.swift)；[文档站数据](../../sites/swift-sdk/public/generated/tokens.json)由代码导出。默认值是本 SDK 的设计选择，不宣称是 Apple 对所有组件的唯一规定。

### 3. 容器先组织空间，再由组件完成阅读

布局依据父级实际提供的空间，而非整屏长宽比。父容器分配宽度，文字在已分配的列内换行、向下增长，图片按既定媒体角色占位。

| 能力 | 当前规则 |
| --- | --- |
| `Stack` | 方向、对齐、间距、分布与换行；普通横排不隐式变成等宽网格 |
| `Card` | 同时参与空间分配和表面呈现；直接位于横排时可共享宽度，普通 Stack 包装不自动透传它的布局偏好 |
| `Card(card)` | 有背景、边框和内容留白，适合需要独立识别的对象或区域 |
| `Card(sunk)` | 浅底和内容留白，无分组边框 |
| `Card(clear)` | 无边框、无内边距，仍保留宽度分配能力，可用于无框多列图文 |
| 卡片网格 | 根据可用宽度、间距和已有阅读宽度分列；不同家族保留自己的上限和槽位规则 |
| 横向卡片集合 | 卡宽与横滑浏览独立处理，保留下一项预览；选页不把后面的正文上下推移 |

`wrap=true` 允许换行。原生 Card 以稳定的阅读宽度参与行分配，空间不足则换行；显式不换行或非响应式的声明保持原意。`align=stretch` 作用于交叉轴，不表示所有任意子项自动等宽。

集合数量已知时可提前分配槽位，但未知条目不会变成可点击的假内容。横滑轨道按已挂载内容的最高项保持高度，内容继续增长仍可能改变整体高度。表格保留列关系，必要时横向滚动，不自动变成另一种卡片模板。

### 4. Cards 是不同的信息结构，不是一种万能外框

普通解释和章节可直接由文字、图文行、列表与留白组成；独立对象、比较候选和局部操作才需要清楚边界。减少不必要的描边，不等于删除 `clear Card` 的布局作用。

| 家族 | 适合承担的职责 |
| --- | --- |
| Snippet | 左侧对象摘要与右侧短值；文字在右列换行，完整数字保留必要空间。集合仅支持 grid |
| Overview | 标题／图文头与关键指标分层，适合概览与比较 |
| Context | 简短背景、情境或前提，不承担整篇解释 |
| Composite | 完整对象的 header、body 和价格／操作 footer |
| Visual | 图片主导的视觉入口，标题和标签叠图并保持对比 |

五种 CardBlock 的 items 均至少两项。单对象使用合法 Card 组合；Card.children 是受限槽位，不能把 CompositeCardItem 直接当任意内容塞进去。单对象和集合中的同类对象使用一致的图片、文字和操作规则，合法写法参考[标准用例](../../examples/agent-cases/README.md)。

商品名称、图片、规格、价格口径和入口应对应同一对象；介绍、推荐判断和来源字段分清，不重复堆放。大图可铺满 Card 顶部或 Composite 图头，文字与操作仍保留内边距；正文中的图片不因此穿过内容边界。价格和按钮按空间并排或换行，不破坏金额，也不丢失动作。

### 5. 图片、图库与预览各有自己的空间规则

卡内照片默认使用宽度派生的 16:9 覆盖裁切；点开后的原图预览使用 fit，保持完整来源比例。缩略图、文档插图和叠图卡分别遵守各自角色，下载状态不决定栏目宽度。

图库根据内容区域的宽度、间距和紧凑阅读宽度分列，内联最多预览五项；点击任意缩略图即可进入完整图库，通过滑动或缩略图查看所有图片，正文不再显示“查看全部图片”入口。**当前图库最后一行仍为等宽图项；是否改为铺满已暂停，不把它当作已定的新规则。**

预览统一使用本地化的工具栏与动态页码，说明放在图片下方。左右滑动切图、缩略图跳转与图片缩放分工明确：放大后拖动当前图片，恢复原尺寸后继续翻页，换图重置缩放。普通图片点击预览；已有整卡动作或选择语义时，通过长按菜单预览，原有点击意图保留。网络失败在原图位置点击重试，不另添 Retry 按钮。

资源由宿主的 `OpenUIResourceContext` 统一提供，保持原地址、签名和权限。默认 SDK Map、MapPoint、SVG 不需要客户端再维护同名实现；Map 展示地点关系，SVG 展示受约束的图解，不代替实时导航或任意网页执行。

### 6. 交互围绕一个明确任务

Form 收集同一任务的字段并统一提交，默认已有 Card 面板；不为加框重复套 Card，不把纯展示商品或单个跳转包装成 Form。即时筛选和无需提交的勾选可以只用本地状态。

操作事件保留当前对象、formName、formState 和既有动作上下文。宿主通过标准 `buildMessage`／`parseMessage` 与现有消息通道承载它们；点击意图不等于业务成功，SDK 不自行宣称已保存、已支付或已下单。

Callout 的普通说明与真实状态分别呈现。中性／信息提示使用安静的引述形式，成功、警告、错误保留明确语义。分割线表达记录边界或结构关系，不作为每个章节标题的装饰。图表来自真实可确认数据，不用补零或虚构数值丰富画面。

### 7. 流式渲染保留连续性，不猜测完整页面

| 阶段 | 呈现原则 |
| --- | --- |
| 布局和集合形状尚未明确 | 保留安全阅读前缀；未确定宽度的媒体局部等待，不先猜一种完整布局 |
| 布局角色已知、文字继续到达 | 按已分配宽度逐步显示，文字增长不反复撑大图片 |
| URL 到齐、图片仍在下载 | 保留媒体框与中性加载反馈，不阻挡整组已有文字 |
| 图表数据陆续确认 | 按图形语义消费数据；依赖完整总量的图形等待必要数据，不画虚假的完整骨架 |
| 刷新、失败或旧请求晚返回 | 保留可用的既有内容，以程序和资源作用域隔离回调 |
| 相同最终快照、空分片 | 保留当前呈现；主动重播使用显式 reset |

容器定义关系与空间，不等于灰色骨架。SDK 不生成“正在整理内容”等业务叙述，不以整段隐藏或重建等待所有内容完成。稳定 statement／key 与同一布局子树共同保留控件和浏览状态。

布局优先、叶子随后填充有利于增量呈现；它不保证未知文字高度、任意源码顺序或宿主主动重建消息时都零位移。具体就绪依赖见[流式处理表](SDK-REFERENCE.zh-CN.md#4-最难的部分是流式过程中保持可信与连续)。

### 8. 语言、平台和验证边界

SDK 内置文案随最近的 SwiftUI locale 选择中英文，图注和业务名称按输入原文显示。包最低支持 iOS 16／macOS 13；Map 需要 iOS 17／macOS 14，较旧系统保留可用性说明。横向意图识别在 iOS 18 起使用原生手势路径，旧系统有兼容实现。

验证分开看：解析与契约、原生几何与状态、实际手势与语言、视觉审阅、业务端到端。编译、测试数量或某张截图都不能替代其他层的验收。案例资料、原始程序、候选版本、容器宽度、语言和证据应能对应；当前普通字号的模拟器检查不代表全部设备、真机手势或所有流式片段都已通过。

图文选择、卡片数量和内容密度由 Agent 的组合指引承担；字体几何、资源生命周期和原生交互由 SDK／宿主实现。详见[验证契约](UI-DESIGN.md)与[生成指引分析材料](AGENT-AUTHORING-HANDOFF.zh-CN.md)。文档站的 Web 标本与 Swift 原生效果分别标识，以所测版本的原生结果为验收依据。

### 9. 文档怎样保持一致

- README 保留设计目标、整体规则和取舍，不复制 87 项组件的完整签名。
- [SDK-REFERENCE.zh-CN.md](SDK-REFERENCE.zh-CN.md) 维护逐组件用途、处理和限制；[NATIVE-COMPONENTS.md](NATIVE-COMPONENTS.md) 与实际库说明接口。
- 字体、颜色和几何的来源是 Theme／Presentation；交互站点从实际代码导出 token 和契约，不手写另一套默认值。
- [examples/agent-cases](../../examples/agent-cases/README.md) 是标准用例唯一源码，消费方通过标准 examples 接口加入实际 Lang。
- 发布时核对本文的版本范围、实际客户端导出与证据身份。main 的说明、已发布 tag、客户端实际注册库不混为一谈。

---

下文保留安装、公开 API 与开发说明。

## Installation

The repository-root `Package.swift` exposes `OpenUISwiftUI` and `OpenUILang`.
Select `OpenUISwiftUI` for native rendering; it includes the language dependency.
Swift 6 tools, iOS 16+ and macOS 13+ are required.

To develop or review the SDK before release, add the repository checkout as a
local package in Xcode, or use:

```swift
.package(path: "../openui")
```

A consuming package target selects:

```swift
.product(name: "OpenUISwiftUI", package: "openui")
```

```swift
import OpenUILang
import OpenUISwiftUI
```

This fork's published Swift SDK is distributed from `https://github.com/zyfn/openui.git`.
For the released baseline, select the exact tag in Xcode or use:

```swift
.package(url: "https://github.com/zyfn/openui.git", exact: "0.1.1-rc.20")
```

The design overview above describes RC20. Later main changes must be reviewed
against their own revision; adopting this release does not update a client or its
exported contract automatically. Other distributions must use their own release identity.

For a language-only consumer, select `OpenUILang`. The nested manifests in
`packages/swift-lang` and `packages/swift-ui` are local development entry points;
use either the root package or the nested packages in an application's dependency
graph. Consumers do not need Node.js to build the checked-in runtime and UI resources.

## Official prompt preset

Use the pinned general-purpose library's examples and rules explicitly:

```swift
let components = try OpenUIStandardComponents.library()
let prompt = components.prompt(OpenUIStandardComponents.promptOptions)
```

`prompt()` without options keeps its existing behavior. The preset is exported
from upstream `openuiPromptOptions`; it does not include application tools. When
removing components, curate the preset and group notes to match the selected
library. This is the general-purpose preset, not `openuiChatPromptOptions`.

The eight user-reviewed, Agent-facing composition examples are maintained separately in
[examples/agent-cases](../../examples/agent-cases/README.md). They are not injected into every
SDK prompt. CaseLab mirrors that single source for native streaming review.

## Appearance

The default theme requires no setup. The following values demonstrate intentional
host overrides, not the SDK defaults. Override the supported React-named tokens
without changing the generated content:

```swift
var light = OpenUITheme()
light.spaceM = 16
light.textBodyDefault = OpenUIFont(size: 17)

OpenUIRenderer(state: state, registry: components.registry)
    .openUITheme(mode: .system, lightTheme: light)
```

Use `darkTheme:` for independent dark overrides. Each nested theme scope starts
from SDK defaults; omitted fields do not inherit parent overrides. Custom
components read resolved values from `context.theme`. Media sizes, cover ratio
and motion belong to `OpenUIPresentation`, applied with `.openUIPresentation(...)`.
See [theme overrides and the RC migration](COMPONENTS.md#theme-overrides).

## Component catalogue

`OpenUIStandardComponents.library()` registers the 84 pinned upstream components plus
`Map`, `MapPoint` and `SVG` (87 total). Map uses MapKit on iOS 17/macOS 14 and later;
older supported systems show an availability message. SVG uses an isolated WebKit
renderer with validated viewBox and restricted content. Existing host parameter
order is retained. Remove duplicate host registrations when migrating.

Generate the prompt and render using the same library. Further host additions use
the existing library extension API. The interactive guide lives in
[`sites/swift-sdk`](../../sites/swift-sdk); its tokens and contracts are generated
from this SDK.

## Rich text and source citations

`TextContent` uses the upstream Markdown extensions for tables, line breaks,
citations and mathematics. `MarkDownRenderer` retains its basic Markdown mode.
`Text`/`BoldText` and `ImageText` titles use the upstream inline Markdown rules.
Image alt text and gallery detail strings are displayed as plain source text. Paragraphs,
tables, links and code blocks are native SwiftUI views; fenced code shares the
standard `CodeBlock` renderer and copy action.

Provide citation metadata with `CardSourceProvider(sources: [...]) { ... }`,
using `CardSource(url:title:sourceName:)`. This is a typed host context rather
than another language component. Valid numbered citations open a native source
list and route links through the host's `openURL` environment.

Remark and KaTeX are bundled as static JavaScript resources and run in
JavaScriptCore. Only equation layout is rasterized by a message-owned,
nonpersistent WebKit view. Fonts are embedded and no external equation resource
is loaded. Consumers do not need Node.js or npm to build or run the Swift package.

## Responsive composition

The host offers a container width. Text measures and wraps within that proposal;
containers measure their children and grow with content. `Stack`/`Card` preserve
the program's row/column direction. With `wrap=true`, a row flows onto additional
lines when the children no longer fit. It does not invent a different composition
based on image count or business meaning. Adaptive grids choose a column count
from available space; Carousel pages are measured synchronously at the current container width; Table
keeps aligned component columns and horizontal scrolling when necessary.

Standard Table accepts registered cell components, matching the upstream library.
Hosts can opt into a read-only comparison policy on a rendered subtree:

```swift
OpenUIRenderer(state: state, registry: installed.registry)
    .openUITableCellPolicy(.readOnly)
```

The read-only policy permits text/numbers and 9 lightweight components, applying
the same reduced registry recursively through Stack and arrays. A custom
policy can name another registered subset. Outside this opt-in subtree the full
component library remains available; the language and Col contract are unchanged.

Prompt generation forwards the supplied core options without hidden additions:

```swift
let prompt = installed.prompt()
```

Hosts that opt into a narrower table policy should make their own generation
policy consistent with the rendering policy.

Native Layout handles measured baseline, stretch and main-axis distribution on
the minimum supported iOS 16/macOS 13 versions. There is one layout implementation;
older stack/grid approximations have been removed.
Accessibility text and parent width are environment inputs, not screen-global
breakpoints. The pinned component schema has no CSS/media-query or arbitrary flex-weight
API. A fixed row should therefore not be described as automatic column reflow.

The standard 84 registration names and their parameter contracts stay intact.
Visual design belongs to the SDK's shared theme and native presentation; it can
improve on upstream styling without renaming components or dropping capabilities.
Image uses a 16:9/fill cover default; ImageBlock and ImageTextLarge use
that same theme cover role. Document illustrations in Markdown and original-image
viewing retain complete source proportions. ImageText accepts an explicit imageSize in both
orientations, and Table paginates at ten rows. Design defaults
are distinct from imposing a native-only 40% table-column cap or ignoring a field.

## Usage

```swift
import SwiftUI
import OpenUILang
import OpenUISwiftUI

@MainActor
struct OpenUIScreen: View {
    @StateObject private var state: OpenUIState

    init(schema: LibrarySchema) {
        _state = StateObject(wrappedValue: OpenUIState(schema: schema))
    }

    private var registry: ComponentRegistry {
        [
            "Stack": { element, registry in
                AnyView(VStack(alignment: .leading) {
                    RenderValue(PropValue.value(element, "children") ?? .array([]), registry: registry)
                })
            },
            "Text": { element, _ in
                AnyView(Text(PropValue.string(element, "text") ?? ""))
            },
            "Button": { element, _ in
                AnyView(Button(PropValue.string(element, "label") ?? "") {
                    Task {
                        let events = await state.triggerAction(
                            PropValue.string(element, "label") ?? "",
                            action: PropValue.value(element, "action"))
                        // Route these events to the application's navigation/chat.
                    }
                })
            }
        ]
    }

    var body: some View {
        OpenUIRenderer(state: state, registry: registry)
            .onAppear {
                state.setSource("root = Stack([Text(\"Hello\")])")
            }
    }
}
```

The example's schema must declare those components and their positional props. Models receive the matching LibrarySpec/prompt, and clients register views under the same component names.

## State and interaction

`OpenUIState` is an `@MainActor ObservableObject`. It publishes `root`, `errors`, completion status, and Query/Mutation states.

- Feed chunks using `push`, then `complete`. A push after completion starts a fresh stream.
- `setSource(_:streaming:)` replaces source while retaining user state. `applyPatch` merges a completed patch; source replacement invalidates pending action plans.
- Read/write state using `stateValue`, `setState`, `snapshotState`, and `restoreState`. Snapshots use lossless `OpenUIString` keys; native String convenience methods remain available. Pass `persistedState` during initialization to restore a previous response.
- `binding(for:prop:)` creates a native `Binding<Value>` for both a `$variable` binding and a write transform such as `$count = $value + 1`.
- For application form components, use `fieldValue`, `setFieldValue`, `fieldBinding`, and `initializeField`. Call initialization when a field mounts; existing persisted or user-entered values win. Pass the nearest form's name to dispatch, preserving the application's form scope.
- `perform(_:formName:)` runs an ActionPlan. `triggerAction(_:formName:action:)` also supports a button's default message and legacy action objects. Plain data cannot impersonate a declared custom action.
- Choose returned events **or** `onAction` for host routing to avoid dispatching twice. `onStateUpdate` supplies snapshots for host-owned persistence.

Queries show defaults during streaming and start automatically after completion. Relevant state/argument changes trigger synchronization; equivalent requests share a cache. Refetch retains the previous value, stale results are discarded, and timers are removed when declarations disappear. Explicit `runQuery` and `@Run(query)` refetch; mutations run only when requested, reject concurrent submission, and halt a plan on failure. Reset/source replacement prevents an old mutation from continuing into a different response.

The optional standard collection supplies native Form/Input/selection/date/slider controls, field registration, validation feedback and primary-submit blocking. These views use the existing runtime store and core validators. Applications can override them. See the [native component contracts](NATIVE-COMPONENTS.md) for exact arguments, value shapes, supported reference contracts and remaining limits.

`onParseResult` observes source parsing; state edits do not emit a new parse result. `onError` observes diagnostic changes, including recovery and reset. `sourceRevision` and component contexts guard against callbacks from a replaced response. Components disable actions and field writes until streaming completes.

Use the upstream `Button(label, action)` for host navigation. The extra NavigationLink/OpenUINavigationComponents registration is removed. The application routes its existing ActionEvents to maps, itinerary or other destinations and shares the same runtime across expanded surfaces.

## Rendering

- `OpenUIRenderer` owns the observed state subscription and injects the state as an environment object.
- `RenderNode` renders a registered element. `RenderValue` handles elements, strings, numbers, booleans, and nested child arrays. Explicit key/id/resourceId props retain exact UTF-16 identity through reordering; named statements retain statementId. Anonymous children require explicit keys for stateful reordering.
- `PropValue` exposes raw values, display strings, element-only children, and action plans. `PropValue.string` repairs isolated surrogates for SwiftUI display; `PropValue.codeUnitString` retains exact units. Display conversion does not write back into state. Use `RenderValue` for heterogeneous or nested children.
- `ElementErrorBoundary` retains the latest registered element if input becomes unavailable. SwiftUI has no general boundary for catching framework crashes or `fatalError`; this view does not make unsafe host builders recoverable.
- `QueryView` shows a spinner while loading and can retain last-good/default data on failure. Inspect published errors for application-specific error presentation.

## Development

Requires Swift 6, with Swift 5 source language mode. Deployment targets are macOS 13+ and iOS 16+.

```sh
swift test --package-path packages/swift-ui
swift build --package-path packages/swift-ui \
  --scratch-path /tmp/openui-ios-build \
  --triple arm64-apple-ios16.0-simulator \
  --sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)"
```

For Xcode GUI builds, open `Package.swift` or an application that consumes the package and choose an Apple destination. Package tests, a consuming application’s Simulator checks, and physical-device runs are distinct validation scopes. The SDK-only branch does not include the separate preview/acceptance application.

The repository's `Build Swift` workflow configures package suites and the iOS Simulator compile on macOS, using the bundled shared core. The JavaScriptCore adapter targets Apple platforms. This is independent of pnpm/npm packaging. A local consumer can use `.package(path: "../openui/packages/swift-ui")` and select the `OpenUISwiftUI` product.

Native value and ToolProvider interfaces are documented in the language package.
The remote package identity is `openui`, with products `OpenUILang` and
`OpenUISwiftUI`. The nested `swift-lang` and `swift-ui` packages remain local
SDK development entry points.

Maintainers rebuilding the rich-text resources use Node.js at development time:

```sh
cd packages/swift-ui/scripts/rich-text
npm ci --ignore-scripts
npm run build
```

Commit the generated resources, dependency lockfile and license notices together.
`rich-text-manifest.json` records the pinned upstream sources, dependency versions,
resource hashes and embedded font count. npm is not invoked by SwiftPM or the app.


## Scoped resources

Apply `.openUIResourceContext(OpenUIResourceContext(baseURL: ...))` once to the
renderer. Image, ImageBlock, ImageText, ImageTextLarge, ImageGallery, ListItem,
Visual/Context cards and Markdown image destinations inherit it. It resolves
relative URLs while preserving the original language and action values. The
public `OpenUIResourceLoading` protocol supplies both request construction and
async transport (for example authorization or an application-owned resolver).
The default uses URLSession, accepts HTTP(S), and treats HTTP failures as failures.
A changed request cancels the previous load; an obsolete result cannot replace
current content. Gallery previews share the same loaded resource.

Chart inspection is anchored within the chart. Tap selects/deselects a datum;
a deliberate hold supports scrubbing while ordinary vertical swipes still scroll.

`OpenUIState.onActionEvaluation` is an optional diagnostic hook exposing the real
action AST, source revision, prior state and evaluated value before the state write.
It does not re-evaluate the expression or replace core action semantics.


## Upstream presentation state during streaming

Tabs always use a horizontally scrollable label row, including a single item.
Selection follows the pinned React renderer: before a user changes the active
value, the last panel whose JSON-serialized content length grows becomes active.
The complete initial snapshot uses the same rule. A manual value change stops
automatic following; removing that value does not invent a fallback. Accordion
opens the newest item as the item count grows until the user opens or closes one.
These are renderer-local states, without extra component parameters or DSL state.
Local tab, disclosure, carousel and table browsing remain available while form
writes and business actions wait for streaming completion.

Native component-local state is scoped to `OpenUIState.presentationRevision`.
`push`, `complete`, growing full-buffer `setSource` snapshots and `applyPatch`
retain it. A new program/reset replaces it at the common component-host boundary.
Store values retain their existing core semantics. Anonymous child identities
preserve their original array paths around null/undefined slots; declared
runtime-provided statement ids and schema-defined keys retain semantic identity.
Carousel retains its outer page groups and current page on appends; unkeyed page
reordering remains positional. Table calculates a safe visible page while retaining
the upstream current-page state when rows temporarily disappear. Gallery resource keys include the resolved
request and loader identity; appending photos does not clear previously loaded
photos or selection.


Image loading and failure use the same declared slot as successful images:
thumbnail dimensions, cover aspect ratios and background bounds are preserved.
The standard Image reserves its cover before decoding, without a separate 4:5
row mode or shared resource-level thumbnail cap. A local container with an
unresolved positional direction can still reserve a compact 16:9 proposal until
its direction arrives. Markdown document illustrations can still
use intrinsic source proportions; their unresolved placeholder ratio is not
inferred from URLs. Original-image viewing uses fit rather than the cover crop.

Snippet cards retain their compact left-label/right-value structure. Their
adaptive grid gives a row enough room instead of changing it into a vertical
product card. Overview metrics use the inline metric typography role. Grid items
align at the top; EntityList allocates short values their intrinsic width. These
presentation rules do not branch on business labels or values.

Images support SDK-owned preview and in-place tap-to-retry. Normal images open on tap; images inside primary-action or choice cards use a native context menu so their existing tap keeps its meaning. Preview geometry is independent of the 16:9 card crop. Gallery failures no longer add a separate Retry button.

Repeated final `setSource` snapshots and empty `push` chunks do not replace the presentation. Use `reset()` explicitly to replay a program. On iOS 18+, the pager recognizer accepts horizontal intent before beginning; single pages and grids do not activate it.

For the server-side Prompt/Skill review, see [Intelligent UI 与 OpenUI Lang：生成指引分析材料](AGENT-AUTHORING-HANDOFF.zh-CN.md). It maps observed authoring failures to responsibilities and is not an additional language contract.
