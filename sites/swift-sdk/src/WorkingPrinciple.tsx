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
    title: "接收描述",
    api: "客户端 → OpenUIState",
    description:
      "客户端把收到的 Lang 分片送进同一个 OpenUIState，由它保持这块内容的运行状态。",
    artifact: "OpenUI Lang · 输入文本",
    path: "packages/swift-ui/Sources/OpenUISwiftUI/OpenUIState.swift",
  },
  {
    title: "解析程序",
    api: "StreamParser → ParseResult",
    description:
      "解析器读出组件、参数、引用与状态声明，形成程序结构；变量表达式仍保留在结构中。",
    artifact: "程序结构 · 示意",
    path: "packages/swift-lang/Sources/OpenUILang/StreamingParser.swift",
  },
  {
    title: "计算属性",
    api: "Evaluator + Store → 组件树",
    description:
      "Store 保存变量当前值，求值器据此计算属性，得到这一次要显示的组件数据。",
    artifact: "组件树 · 求值结果示意",
    path: "packages/swift-lang/Sources/OpenUILang/Evaluator.swift",
  },
  {
    title: "生成视图",
    api: "渲染器 → 注册表 → 原生组件",
    description:
      "渲染器按组件名称找到原生实现。组件完成布局与显示，并接收用户的输入和点击。",
    artifact: "界面与交互 · Web 示意",
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
          <p>接收消息、管理会话与历史，处理导航和业务请求。</p>
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
                  <dd>协调一次次更新</dd>
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
            Theme 与 Presentation 为原生组件提供视觉值和平台呈现规则。
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

组件树是带有类型与属性的数据，还不是屏幕上的视图。`;
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
                <h4>交给客户端的上次提交</h4>
                {submitted === null ? (
                  <p>点击“提交选择”，查看点击时读取的值。</p>
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
          <h4>本地修改，回到运行时</h4>
          <p>
            绑定把控件值关联到 Store 中的变量。控件写入或 <code>@Set</code>
            修改变量后，运行时重新求值并更新界面，无需请求 Agent。
          </p>
        </div>
        <div>
          <h4>外部动作，交给客户端</h4>
          <p>
            <code>@ToAssistant</code> 读取点击时的值，发出
            ActionEvent；客户端再发起 Agent
            请求。链接导航与真正的业务执行也由客户端承接。
          </p>
        </div>
      </div>
      <p className="micro processing-note">
        以上是固定程序的 Web 机制示意，不运行 Swift
        SDK或发送请求。流式分片下的布局、组件就绪与资源处理见第三章。
      </p>
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
        <p className="eyebrow">01 / 工作原理</p>
        <h2 id="principle-title">OpenUI 在客户端的运行过程。</h2>
        <p>
          Agent 返回的是界面描述；实际的布局、显示和交互，由客户端中的 OpenUI
          Swift SDK 完成。
        </p>
      </div>
      <section className="principle-part" aria-labelledby="architecture-title">
        <div className="principle-part-heading">
          <p className="eyebrow">1.1 / Architecture</p>
          <h3 id="architecture-title">SDK 随客户端运行，内部有两个模块。</h3>
        </div>
        <Architecture />
      </section>
      <section className="principle-part" aria-labelledby="processing-title">
        <div className="principle-part-heading">
          <p className="eyebrow">1.2 / Parsing & Rendering</p>
          <h3 id="processing-title">一段描述，经过解析、求值，成为视图。</h3>
          <p>
            用“已选数量”这段程序，观察文本、程序结构、组件数据与显示结果的区别。
          </p>
        </div>
        <ProcessingExample />
      </section>
      <section className="principle-part" aria-labelledby="contract-title">
        <div className="principle-part-heading">
          <p className="eyebrow">1.3 / Component Contract</p>
          <h3 id="contract-title">组件契约连接 Agent 与 SDK。</h3>
          <p>
            每个组件都有参数定义与原生实现。客户端通过 OpenUIComponentLibrary
            把两者注册在一起，并导出供服务端使用的生成契约。
          </p>
        </div>
        <div className="component-contract-outputs">
          <div>
            <b>Prompt</b>
            <span>给 Agent 的生成说明</span>
            <p>可用组件、参数顺序和组合规则。</p>
          </div>
          <div>
            <b>Schema</b>
            <span>给运行时的结构约束</span>
            <p>组件类型、参数与绑定的合法范围。</p>
          </div>
          <div>
            <b>Registry</b>
            <span>给渲染器的视图映射</span>
            <p>组件名称所对应的原生构建器。</p>
          </div>
        </div>
        <details className="implementation-note">
          <summary>实现与接入说明</summary>
          <p>
            语言运行时通过 JavaScriptCore 执行随包提供的官方
            lang-core。OpenUIState 属于
            OpenUISwiftUI，负责调用语言运行时并把结果交给原生渲染器。
          </p>
          <p>
            客户端为每个 OpenUI 内容块保留独立状态。正常结束调用
            complete()，用户停止调用
            interrupt()；历史快照、资源访问策略和外部动作由客户端接入。
          </p>
          <a
            className="text-link"
            href={`https://github.com/zyfn/openui/blob/${sdkBaseline.revision}/packages/swift-ui/ARCHITECTURE.md`}
            target="_blank"
            rel="noreferrer"
          >
            架构与实现依据 <ArrowRight size={13} />
          </a>
        </details>
      </section>
    </section>
  );
}
