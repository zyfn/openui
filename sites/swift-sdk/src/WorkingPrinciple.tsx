import { useState } from "react";
import { ArrowRight, RotateCcw } from "lucide-react";
import { sdkBaseline } from "./baseline";

export const runtimeExample = `$quantity = 1
root = Stack([
  TextContent("已选数量：" + $quantity),
  Buttons([
    Button("增加一件", @Set($quantity, $quantity + 1)),
    Button("提交选择", @ToAssistant("按当前数量继续", {quantity: $quantity}))
  ])
])`;

const processingSteps = [
  {
    title: "接收",
    api: "客户端 → OpenUIState",
    description: "客户端将 Lang 分片送入同一个 OpenUIState。",
    artifact: "Lang 源码",
    path: "packages/swift-ui/Sources/OpenUISwiftUI/OpenUIState.swift",
  },
  {
    title: "解析",
    api: "StreamParser → ParseResult",
    description: "读出组件、参数、引用和状态声明，生成程序结构。",
    artifact: "程序结构（示意）",
    path: "packages/swift-lang/Sources/OpenUILang/StreamingParser.swift",
  },
  {
    title: "求值",
    api: "Evaluator + Store → 组件树",
    description: "读取 Store 当前值，计算组件属性。",
    artifact: "组件树（示意）",
    path: "packages/swift-lang/Sources/OpenUILang/Evaluator.swift",
  },
  {
    title: "渲染",
    api: "渲染器 → 注册表 → 原生组件",
    description: "通过注册表调用原生组件，完成布局、显示与交互。",
    artifact: "界面（Web 示意）",
    path: "packages/swift-ui/Sources/OpenUISwiftUI/RenderNode.swift",
  },
] as const;

function Architecture() {
  return (
    <figure
      className="ownership-map"
      aria-label="Agent、客户端和 SDK 的代码归属"
    >
      <div className="ownership-server">
        <span className="ownership-domain">服务端</span>
        <h4>Agent</h4>
        <p>组织回答，生成界面描述。</p>
        <code>OpenUI Lang</code>
      </div>
      <div className="ownership-transfer" aria-hidden="true">
        <ArrowRight size={20} />
      </div>
      <div className="ownership-client">
        <div className="ownership-client-heading">
          <h4>
            客户端 <span>Host App</span>
          </h4>
          <p>接收消息、管理会话，处理导航和业务请求。</p>
        </div>
        <div className="ownership-sdk">
          <h5>OpenUI Swift SDK</h5>
          <div className="ownership-packages">
            <section aria-label="语言运行时模块">
              <h6>语言运行时</h6>
              <code>OpenUILang</code>
              <dl>
                <div>
                  <dt>解析器</dt>
                  <dd>读出程序结构</dd>
                </div>
                <div>
                  <dt>求值器</dt>
                  <dd>计算属性的当前值</dd>
                </div>
                <div>
                  <dt>Store</dt>
                  <dd>保存变量与表单状态</dd>
                </div>
              </dl>
            </section>
            <section aria-label="原生 UI 模块">
              <h6>原生 UI 层</h6>
              <code>OpenUISwiftUI</code>
              <dl>
                <div>
                  <dt>OpenUIState</dt>
                  <dd>协调更新</dd>
                </div>
                <div>
                  <dt>渲染器</dt>
                  <dd>把组件数据映射为视图</dd>
                </div>
                <div>
                  <dt>组件库</dt>
                  <dd>完成布局、显示与交互</dd>
                </div>
              </dl>
            </section>
          </div>
          <p className="ownership-theme">
            Theme / Presentation：组件样式与平台呈现参数。
          </p>
        </div>
      </div>
    </figure>
  );
}

function ProcessingExample() {
  const [step, setStep] = useState(0);
  const [quantity, setQuantity] = useState(1);
  const [submitted, setSubmitted] = useState<number | null>(null);
  const current = processingSteps[step];
  const programStructure = `状态声明：$quantity 的默认值是 1

Stack
├─ TextContent
│  └─ text: "已选数量：" + $quantity
└─ Buttons
   ├─ Button: "增加一件" → @Set(...)
   └─ Button: "提交选择" → @ToAssistant(...)`;
  const evaluatedTree = `Store 当前值：$quantity = ${quantity}

Stack
├─ TextContent
│  └─ text: "已选数量：${quantity}"
└─ Buttons
   ├─ Button: "增加一件"
   └─ Button: "提交选择"

组件树：类型与属性数据。`;
  const event =
    submitted === null
      ? null
      : {
          type: "continue_conversation",
          humanFriendlyMessage: "按当前数量继续",
          params: { context: { quantity: submitted } },
        };
  function reset() {
    setStep(0);
    setQuantity(1);
    setSubmitted(null);
  }
  return (
    <>
      <div className="processing-example">
        <div
          className="processing-mobile-tabs"
          role="group"
          aria-label="处理步骤"
        >
          {processingSteps.map((item, index) => (
            <button
              key={item.title}
              aria-pressed={step === index}
              aria-controls="processing-artifact"
              onClick={() => setStep(index)}
            >
              <span>{index + 1}</span>
              {item.title}
            </button>
          ))}
        </div>
        <ol className="processing-steps" aria-label="SDK 处理过程">
          {processingSteps.map((item, index) => (
            <li key={item.title}>
              <button
                aria-pressed={step === index}
                aria-controls="processing-artifact"
                onClick={() => setStep(index)}
              >
                <span className="processing-number">{index + 1}</span>
                <span className="processing-step-copy">
                  <b>{item.title}</b>
                  <code>{item.api}</code>
                  <span>{item.description}</span>
                </span>
              </button>
            </li>
          ))}
        </ol>
        <div
          className="processing-artifact"
          id="processing-artifact"
          aria-live="polite"
        >
          <div className="processing-artifact-heading">
            <h4>{current.artifact}</h4>
            <button className="quiet" onClick={reset} aria-label="重置处理示意">
              <RotateCcw size={13} /> 重置
            </button>
          </div>
          <div className="processing-mobile-description">
            <code>{current.api}</code>
            <p>{current.description}</p>
          </div>
          {step < 3 ? (
            <pre>
              {step === 0
                ? runtimeExample
                : step === 1
                  ? programStructure
                  : evaluatedTree}
            </pre>
          ) : (
            <div className="processing-view">
              <p className="processing-state">
                <code>Store · $quantity = {quantity}</code>
              </p>
              <strong>已选数量：{quantity}</strong>
              <div className="processing-view-actions">
                <button
                  className="pill"
                  onClick={() => setQuantity((value) => value + 1)}
                >
                  增加一件
                </button>
                <button
                  className="pill primary"
                  onClick={() => setSubmitted(quantity)}
                >
                  提交选择
                </button>
              </div>
              <div className="processing-submission">
                <h4>上次提交事件</h4>
                {submitted === null ? (
                  <p>尚未提交。</p>
                ) : (
                  <>
                    <p>
                      按当前数量继续 <code>quantity: {submitted}</code>
                    </p>
                    <details>
                      <summary>ActionEvent 摘要</summary>
                      <pre>{JSON.stringify(event, null, 2)}</pre>
                    </details>
                  </>
                )}
              </div>
            </div>
          )}
          <div className="processing-artifact-footer">
            <a
              className="text-link"
              href={`https://github.com/zyfn/openui/blob/${sdkBaseline.revision}/${current.path}`}
              target="_blank"
              rel="noreferrer"
            >
              对应实现 <ArrowRight size={13} />
            </a>
            <div className="processing-navigation">
              <button
                className="quiet"
                disabled={step === 0}
                onClick={() => setStep((value) => value - 1)}
              >
                上一步
              </button>
              <button
                className="quiet"
                disabled={step === 3}
                onClick={() => setStep((value) => value + 1)}
              >
                下一步 <ArrowRight size={13} />
              </button>
            </div>
          </div>
        </div>
      </div>
      <div className="interaction-return-paths">
        <div>
          <h4>状态管理</h4>
          <p>
            绑定关联控件与 Store 变量。写入或 <code>@Set</code>
            修改后，重新求值并更新界面，无需请求 Agent。
          </p>
        </div>
        <div>
          <h4>动作处理</h4>
          <p>
            <code>@ToAssistant</code> 将点击时的值封装为
            ActionEvent，客户端据此请求 Agent。
          </p>
        </div>
      </div>
      <p className="micro processing-note">Web 机制示意，不运行 Swift SDK。</p>
    </>
  );
}

export default function WorkingPrinciple() {
  return (
    <section
      className="section working-principle"
      id="principle"
      aria-labelledby="principle-title"
    >
      <div className="chapter-heading">
        <p className="eyebrow">01</p>
        <h2 id="principle-title">工作原理</h2>
      </div>
      <section className="principle-part" aria-labelledby="architecture-title">
        <div className="principle-part-heading">
          <p className="eyebrow">1.1</p>
          <h3 id="architecture-title">架构</h3>
        </div>
        <Architecture />
      </section>
      <section className="principle-part" aria-labelledby="processing-title">
        <div className="principle-part-heading">
          <p className="eyebrow">1.2</p>
          <h3 id="processing-title">解析与渲染</h3>
        </div>
        <ProcessingExample />
      </section>
      <section className="principle-part" aria-labelledby="contract-title">
        <div className="principle-part-heading">
          <p className="eyebrow">1.3</p>
          <h3 id="contract-title">组件契约</h3>
          <p>OpenUIComponentLibrary 注册组件定义与原生实现，导出生成契约。</p>
        </div>
        <div className="component-contract-outputs">
          <div>
            <b>Prompt</b>
            <p>供 Agent 使用的组件、参数与组合说明。</p>
          </div>
          <div>
            <b>Schema</b>
            <p>供运行时使用的类型、参数与绑定约束。</p>
          </div>
          <div>
            <b>Registry</b>
            <p>供渲染器使用的组件名称与原生视图映射。</p>
          </div>
        </div>
        <details className="implementation-note">
          <summary>实现细节</summary>
          <p>OpenUILang 通过 JavaScriptCore 执行随包提供的官方 lang-core。</p>
          <p>
            每个 OpenUI 内容块持有独立的 OpenUIState。complete()
            正常结束；interrupt() 停止生成并保留已完成内容。
          </p>
          <a
            className="text-link"
            href={`https://github.com/zyfn/openui/blob/${sdkBaseline.revision}/packages/swift-ui/ARCHITECTURE.md`}
            target="_blank"
            rel="noreferrer"
          >
            源码 <ArrowRight size={13} />
          </a>
        </details>
      </section>
    </section>
  );
}
