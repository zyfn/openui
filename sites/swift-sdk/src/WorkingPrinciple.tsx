import { useRef, useState, type ReactNode } from "react";
import { ArrowDown, ArrowRight, RotateCcw } from "lucide-react";
import { sdkBaseline } from "./baseline";

const modules = {
  host: {
    title: "客户端宿主",
    api: "Host App",
    responsibility:
      "把 SDK 嵌入聊天界面：接收网络消息、识别 OpenUI 内容块，为每块保留运行状态，处理停止、历史恢复、资源访问策略与动作回调，再接到导航、工具或下一次 Agent 请求。",
    input: "服务端消息分片、SDK 发出的 ActionEvent。",
    output: "对运行时的输入，以及应用自己的导航或业务请求。",
    path: "packages/swift-ui/README.md",
  },
  coordinator: {
    title: "运行时协调器",
    api: "OpenUIState",
    responsibility:
      "持有当前程序的解析器、Store 与查询管理器。收到内容或状态变化时组织求值，发布组件树、诊断和完成状态，并把可执行的动作交到相应出口。",
    input: "push(chunk)、complete()、控件写入与工具结果。",
    output: "root、错误与查询状态；onAction、onStateUpdate 等回调。",
    path: "packages/swift-ui/Sources/OpenUISwiftUI/OpenUIState.swift",
  },
  parser: {
    title: "流式解析器",
    api: "StreamParser",
    responsibility:
      "把不断到达的 Lang 文本解析为程序结构，处理声明、引用、位置参数与未完成内容。它知道程序写了什么，尚未决定每个状态表达式当前的值。",
    input: "Lang 分片 + 组件 Schema。",
    output: "ParseResult：程序语法结构（AST）、状态声明、引用和就绪信息。",
    path: "packages/swift-lang/Sources/OpenUILang/StreamingParser.swift",
  },
  evaluator: {
    title: "求值器",
    api: "Evaluator",
    responsibility:
      "结合解析结果与当前状态，解析引用并计算表达式，得到组件此刻应读取的属性。状态变化后可以重新求值，无需 Agent 重写整段程序。",
    input: "ParseResult + Store 当前值 + 已有工具结果。",
    output: "EvaluatedElement 组件树及求值诊断。",
    path: "packages/swift-lang/Sources/OpenUILang/Evaluator.swift",
  },
  store: {
    title: "程序状态",
    api: "Store",
    responsibility:
      "保存 $变量、绑定值和表单字段。控件与 @Set 写入这里，求值器从这里读取；更新默认值时保留已发生的用户输入。焦点、滚动和图片缩放等界面状态仍由原生视图管理。",
    input: "声明默认值、用户写入、恢复的状态快照。",
    output: "最新状态值与 snapshot；跨会话保存由客户端接入。",
    path: "packages/swift-lang/Sources/OpenUILang/Store.swift",
  },
  renderer: {
    title: "原生渲染器",
    api: "OpenUIRenderer / RenderNode",
    responsibility:
      "观察运行时发布的组件树，按节点类型查注册表，并把属性交给对应的原生构建器。组件树说明要显示什么，渲染器把它接到平台视图。",
    input: "EvaluatedElement 树 + ComponentRegistry。",
    output: "由原生组件组成的 SwiftUI 视图树。",
    path: "packages/swift-ui/Sources/OpenUISwiftUI/RenderNode.swift",
  },
  components: {
    title: "原生组件实现",
    api: "Components / Theme / Presentation",
    responsibility:
      "实现 Stack、Card、文字、控件、图表与媒体。容器分配空间，组件选择文字和颜色 Token、处理资源与交互，再通过运行时写回状态或触发动作。",
    input: "节点属性、父级空间、主题与组件上下文。",
    output: "可阅读、可操作的界面，以及状态写入或动作。",
    path: "packages/swift-ui/Sources/OpenUISwiftUI/GenUILib/ComponentBindings.swift",
  },
} as const;
type ModuleID = keyof typeof modules;

function ModuleButton({
  id,
  selected,
  onSelect,
  children,
}: {
  id: ModuleID;
  selected: ModuleID;
  onSelect: (id: ModuleID, button: HTMLButtonElement) => void;
  children: ReactNode;
}) {
  return (
    <button
      className="runtime-node"
      aria-pressed={selected === id}
      aria-controls="runtime-module-detail"
      onClick={(event) => onSelect(id, event.currentTarget)}
    >
      {children}
    </button>
  );
}

export const runtimeExample = `$quantity = 1
root = Stack([
  TextContent("已选数量：" + $quantity),
  Buttons([
    Button("增加一件", @Set($quantity, $quantity + 1)),
    Button("提交选择", @ToAssistant("按当前数量继续", {quantity: $quantity}))
  ])
])`;

const updatePaths = [
  {
    title: "收到内容",
    path: ["客户端 push", "解析", "求值", "组件树", "原生呈现"],
    text: "源程序增加。解析器接续已有内容，运行时据此更新界面。正常结束调用 complete()；用户停止调用 interrupt()。",
  },
  {
    title: "本地调整",
    path: ["控件 / @Set", "Store", "重新求值", "更新呈现"],
    text: "源程序不变。改写状态后重新计算依赖它的内容，这一步无需重新请求 Agent。",
  },
  {
    title: "提交动作",
    path: ["ActionPlan", "ActionEvent", "客户端", "后续请求"],
    text: "动作执行时读取最新值。本例的 @ToAssistant 产生继续对话事件，由客户端发起下一次请求。",
  },
] as const;

function UpdateLifecycle() {
  const [quantity, setQuantity] = useState(1);
  const [phase, setPhase] = useState(0);
  const [submitted, setSubmitted] = useState<number | null>(null);
  const event =
    submitted === null
      ? "等待点击「提交选择」"
      : JSON.stringify(
          {
            type: "continue_conversation",
            humanFriendlyMessage: "按当前数量继续",
            params: { context: { quantity: submitted } },
          },
          null,
          2,
        );
  function reset() {
    setQuantity(1);
    setSubmitted(null);
    setPhase(0);
  }
  return (
    <section className="principle-part" aria-labelledby="lifecycle-title">
      <div className="principle-part-heading">
        <p className="eyebrow">1.3 / Update Lifecycle</p>
        <h3 id="lifecycle-title">界面更新，有三条不同的路径。</h3>
        <p>
          收到新文字、修改本地值、提交给 Agent，触发的工作各不相同。
          用同一段小程序，可以看清哪些数据发生了变化。
        </p>
      </div>
      <ol className="runtime-update-paths" aria-label="三条更新路径">
        {updatePaths.map((item, index) => (
          <li key={item.title} data-active={phase === index}>
            <h4>
              <span>{index + 1}</span>
              {item.title}
            </h4>
            <p className="runtime-path">
              {item.path.map((name, i) => (
                <span key={name}>
                  {i > 0 ? <ArrowRight size={12} aria-hidden="true" /> : null}
                  {name}
                </span>
              ))}
            </p>
            <p>{item.text}</p>
          </li>
        ))}
      </ol>
      <div className="runtime-lab">
        <div className="runtime-lab-heading">
          <span>固定程序的机制演示 · Web</span>
          <button className="quiet" onClick={reset}>
            <RotateCcw size={13} /> 重置演示
          </button>
        </div>
        <div className="runtime-lab-columns">
          <div className="runtime-program">
            <h4>源程序</h4>
            <p>本地操作保留这段声明。</p>
            <pre>{runtimeExample}</pre>
          </div>
          <div className="runtime-live-state">
            <div className="runtime-state-heading">
              <div>
                <h4>当前 Store</h4>
                <code>$quantity = {quantity}</code>
              </div>
              <span className="subtle-label">{updatePaths[phase].title}</span>
            </div>
            <div className="runtime-output" aria-live="polite">
              <span>求值后的文字属性</span>
              <strong>已选数量：{quantity}</strong>
            </div>
            <div className="runtime-demo-actions">
              <button
                className="pill"
                onClick={() => {
                  setQuantity((value) => value + 1);
                  setPhase(1);
                }}
              >
                增加一件
              </button>
              <button
                className="pill primary"
                onClick={() => {
                  setSubmitted(quantity);
                  setPhase(2);
                }}
              >
                提交选择
              </button>
            </div>
            <div className="runtime-event" aria-live="polite">
              <h4>上次提交 · ActionEvent 摘要</h4>
              <pre>{event}</pre>
            </div>
          </div>
        </div>
        <p className="micro">
          此处用 Web 状态演示固定程序的变化，不运行 Swift SDK，也不发送请求。
          真正的字段绑定、动作求值与事件生成由 SDK 运行时执行。
        </p>
      </div>
      <p className="runtime-closing-note">
        <b>客户端维护消息，SDK 维护这段程序。</b>
        同一内容块持续追加时应保留同一个
        OpenUIState；替换程序或重播时再显式重置。
        页面可见、动作已发出、业务已执行，分别由呈现、事件与业务结果确认。
      </p>
    </section>
  );
}

export default function WorkingPrinciple() {
  const [selected, setSelected] = useState<ModuleID>("coordinator");
  const detail = useRef<HTMLElement>(null);
  const returnTarget = useRef<HTMLButtonElement>(null);
  const current = modules[selected];
  function revealModule(id: ModuleID, button: HTMLButtonElement) {
    setSelected(id);
    returnTarget.current = button;
    if (window.matchMedia("(max-width: 700px)").matches) {
      requestAnimationFrame(() => {
        detail.current?.focus({ preventScroll: true });
        detail.current?.scrollIntoView({ block: "start" });
      });
    }
  }
  const node = (id: ModuleID, title: string, api: string, text: string) => (
    <ModuleButton id={id} selected={selected} onSelect={revealModule}>
      <b>{title}</b>
      <code>{api}</code>
      <span>{text}</span>
    </ModuleButton>
  );
  return (
    <section
      className="section working-principle"
      id="principle"
      aria-labelledby="principle-title"
    >
      <div className="chapter-heading">
        <p className="eyebrow">01 / 工作原理</p>
        <h2 id="principle-title">从一段程序，到一个可交互的界面。</h2>
        <p>
          Agent 生成描述，客户端承载消息，SDK 运行并呈现这段描述。 SDK
          内部再分运行时、渲染器和组件实现；解析器、求值器与 Store
          共同支撑运行时。
        </p>
      </div>
      <section className="principle-part" aria-labelledby="architecture-title">
        <div className="principle-part-heading">
          <p className="eyebrow">1.1 / Runtime Architecture</p>
          <h3 id="architecture-title">先看包含关系，再看谁调用谁。</h3>
          <p>
            “执行引擎”指运行时整体。解析器负责读懂程序，求值器计算当前结果，Store
            保存可变的值，OpenUIState 把它们组织成一次次更新。
          </p>
        </div>
        <figure className="runtime-architecture">
          <figcaption>
            运行架构 <span>点击模块，查看职责、输入与输出</span>
          </figcaption>
          <div className="runtime-architecture-columns">
            <div className="runtime-architecture-map">
              <div className="runtime-agent">
                <b>Agent · 生成端</b>
                <span>
                  依据组件契约与工具结果，组织内容、组件、绑定和动作。
                </span>
              </div>
              <div className="runtime-connector">
                <ArrowDown size={14} aria-hidden="true" /> OpenUI Lang 消息流
              </div>
              <div className="runtime-host-boundary">
                {node(
                  "host",
                  "客户端宿主 · Host App",
                  "消息接入 / 生命周期 / 业务出口",
                  "接收分片、保留状态、处理停止与恢复，承接导航和后续请求。",
                )}
                <div className="runtime-sdk-boundary">
                  <div className="runtime-scope-heading">
                    <b>OpenUI Swift SDK</b>
                    <span>运行在客户端内</span>
                  </div>
                  <div className="runtime-engine">
                    <div className="runtime-area-label">
                      <span>01</span> 运行时 · Runtime
                    </div>
                    {node(
                      "coordinator",
                      "运行时协调器",
                      "OpenUIState",
                      "接收内容与状态变化，组织解析、求值和动作，发布结果。",
                    )}
                    <div className="runtime-core-modules">
                      {node(
                        "parser",
                        "解析器",
                        "StreamParser",
                        "文本 → 程序结构",
                      )}
                      {node(
                        "evaluator",
                        "求值器",
                        "Evaluator",
                        "程序 + 当前值 → 组件树",
                      )}
                      {node(
                        "store",
                        "程序状态",
                        "Store",
                        "变量、绑定与表单字段",
                      )}
                    </div>
                    <p className="runtime-execution-note">
                      解析结果 + Store 当前值 → 求值 → 组件树
                    </p>
                    <p className="runtime-execution-note">
                      动作执行：ActionPlan · 工具接入：QueryManager /
                      ToolProvider（可选）
                    </p>
                  </div>
                  <div className="runtime-connector">
                    <ArrowDown size={14} aria-hidden="true" /> EvaluatedElement
                    组件树
                  </div>
                  <div className="runtime-native-modules">
                    {node(
                      "renderer",
                      "02 · 原生渲染器",
                      "OpenUIRenderer / RenderNode",
                      "观察组件树，查找注册表，调用对应构建器。",
                    )}
                    <ArrowRight
                      size={16}
                      className="runtime-native-arrow"
                      aria-hidden="true"
                    />
                    {node(
                      "components",
                      "03 · 原生组件实现",
                      "Stack / Card / Input / Chart…",
                      "测量布局、呈现内容、处理交互，写回状态或触发动作。",
                    )}
                  </div>
                  <p className="runtime-theme-rail">
                    Theme / Presentation{" "}
                    <span>统一组件的视觉值与平台呈现规则</span>
                  </p>
                </div>
                <p className="runtime-return-path">
                  控件变化 → 运行时；外部动作 → 客户端 onAction
                </p>
              </div>
            </div>
            <aside
              ref={detail}
              className="runtime-module-detail"
              id="runtime-module-detail"
              tabIndex={-1}
              aria-labelledby="runtime-module-title"
              aria-live="polite"
            >
              <p className="eyebrow">模块职责</p>
              <h4 id="runtime-module-title">{current.title}</h4>
              <code className="runtime-detail-api">{current.api}</code>
              <p>{current.responsibility}</p>
              <dl>
                <div>
                  <dt>输入</dt>
                  <dd>{current.input}</dd>
                </div>
                <div>
                  <dt>输出</dt>
                  <dd>{current.output}</dd>
                </div>
              </dl>
              <a
                className="text-link"
                href={`https://github.com/zyfn/openui/blob/${sdkBaseline.revision}/${current.path}`}
                target="_blank"
                rel="noreferrer"
              >
                对应实现 <ArrowRight size={13} />
              </a>
              <button
                className="quiet runtime-return-button"
                onClick={() => {
                  returnTarget.current?.focus({ preventScroll: true });
                  returnTarget.current?.scrollIntoView({ block: "center" });
                }}
              >
                返回已选模块
              </button>
            </aside>
          </div>
        </figure>
        <p className="runtime-package-note">
          <b>职责图与代码模块对应：</b>
          OpenUILang 提供语言核心；OpenUISwiftUI 提供
          OpenUIState、渲染器与原生组件。 当前语言核心通过 JavaScriptCore 执行随
          SDK 打包的官方 lang-core，界面由原生层构建。
        </p>
      </section>
      <section className="principle-part" aria-labelledby="contract-title">
        <div className="principle-part-heading">
          <p className="eyebrow">1.2 / Component Contract</p>
          <h3 id="contract-title">一份注册，让生成和呈现说同一种语言。</h3>
          <p>
            OpenUIComponentLibrary 把组件定义与原生构建器配在一起。
            同一份定义导出 Prompt 与 Schema，注册表则把组件名称映射到实际视图。
          </p>
        </div>
        <div className="runtime-contract-origin">
          <code>OpenUIComponent</code>
          <span>组件名称、参数与槽位 + 原生 View Builder</span>
        </div>
        <div className="runtime-contract-branches">
          <div>
            <b>Prompt → Agent</b>
            <p>告诉模型有哪些组件、参数顺序、合法组合和动作。</p>
          </div>
          <div>
            <b>Schema → 语言运行时</b>
            <p>把名称、参数类型、绑定等约束交给解析与求值。</p>
          </div>
          <div>
            <b>Registry → 渲染器</b>
            <p>把组件类型对应到原生实现，实际绘制并响应交互。</p>
          </div>
        </div>
        <p className="micro runtime-contract-note">
          客户端以实际注册库生成契约，再交给服务端使用。Agent 选择组件与语义，
          SDK 组件按 Token 和可用空间呈现；业务事实与真实执行由
          Agent、工具和客户端承接。
        </p>
      </section>
      <UpdateLifecycle />
    </section>
  );
}
