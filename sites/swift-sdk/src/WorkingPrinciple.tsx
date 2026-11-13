import { useState } from "react";
import { ArrowDown, ArrowRight, RotateCcw } from "lucide-react";
import { sdkBaseline } from "./baseline";

export const runtimeExample = `$quantity = 1
root = Stack([
  TextContent("已选数量：" + $quantity),
  Buttons([
    Button("增加一件", @Set($quantity, $quantity + 1)),
    Button("提交选择", @ToAssistant("按当前数量继续", {quantity: $quantity}))
  ])
])`;

export default function WorkingPrinciple() {
  const [quantity, setQuantity] = useState(1);
  const [submitted, setSubmitted] = useState<number | null>(null);
  const event =
    submitted === null
      ? null
      : {
          type: "continue_conversation",
          humanFriendlyMessage: "按当前数量继续",
          params: { context: { quantity: submitted } },
        };
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
      <figure className="runtime-map" aria-label="OpenUI 运行架构与交互回传">
        <div className="runtime-source">
          <b>Agent · 服务端</b>
          <span>根据组件契约与事实生成回答</span>
          <ArrowRight size={15} aria-hidden="true" />
          <code>OpenUI Lang</code>
        </div>
        <div className="runtime-client">
          <div className="runtime-client-heading">
            <h3>
              客户端 <span>Host App</span>
            </h3>
            <p>
              接收消息、管理会话与历史，处理导航、业务执行和后续 Agent 请求。
            </p>
          </div>
          <div className="runtime-sdk">
            <h4>OpenUI Swift SDK</h4>
            <div className="runtime-coordinator">
              <div>
                <b>运行协调</b>
                <code>OpenUIState · OpenUISwiftUI</code>
              </div>
              <p>
                接收 Lang 分片，驱动解析与求值，发布组件树、诊断和完成状态。
              </p>
            </div>
            <div className="runtime-data-flow">
              <div className="runtime-language">
                <div className="runtime-group-label">
                  语言核心 <code>OpenUILang</code>
                </div>
                <div className="runtime-language-flow">
                  <div className="runtime-module">
                    <h4>解析</h4>
                    <code>StreamParser</code>
                    <p>Lang 分片 → 程序结构、引用和状态声明。</p>
                  </div>
                  <ArrowRight
                    className="runtime-flow-arrow"
                    size={18}
                    aria-hidden="true"
                  />
                  <div className="runtime-module">
                    <h4>求值</h4>
                    <code>Evaluator</code>
                    <p>程序结构 + 当前状态 → 组件类型与属性。</p>
                    <small>text = “已选数量：{quantity}”</small>
                  </div>
                </div>
                <div className="runtime-store">
                  <div>
                    <b>状态管理</b>
                    <code>Store · $quantity = {quantity}</code>
                  </div>
                  <p>保存变量、绑定值与表单字段，供求值器读取。</p>
                  <span>状态写入 → 重新求值</span>
                </div>
              </div>
              <div className="runtime-tree">
                <ArrowRight size={18} aria-hidden="true" />
                <span>组件树</span>
                <code>EvaluatedElement</code>
              </div>
              <div className="runtime-native">
                <div className="runtime-group-label">
                  原生呈现 <code>OpenUISwiftUI</code>
                </div>
                <div className="runtime-module">
                  <h4>渲染</h4>
                  <code>OpenUIRenderer / RenderNode</code>
                  <p>通过 Registry 查找组件名称对应的原生构建器。</p>
                </div>
                <ArrowDown
                  className="runtime-component-arrow"
                  size={16}
                  aria-hidden="true"
                />
                <div className="runtime-module">
                  <h4>组件库</h4>
                  <p>
                    负责布局与交互，维护焦点、展开和缩放等视图状态。Theme /
                    Presentation 提供样式与平台参数。
                  </p>
                </div>
              </div>
            </div>
            <div className="runtime-feedback">
              <div>
                <b>本地交互</b>
                <p>
                  控件或 <code>@Set</code> 写入 Store，更新界面，无需请求
                  Agent。
                </p>
              </div>
              <div>
                <b>外部动作</b>
                <p>
                  动作执行时读取最新值，生成
                  ActionEvent，由客户端处理导航或继续对话。
                </p>
              </div>
            </div>
          </div>
        </div>
        <figcaption className="runtime-contract">
          <div>
            <b>组件契约</b>
            <code>OpenUIComponentLibrary</code>
          </div>
          <dl>
            <div>
              <dt>Prompt → Agent</dt>
              <dd>生成说明</dd>
            </div>
            <div>
              <dt>Schema → 语言核心</dt>
              <dd>类型与参数约束</dd>
            </div>
            <div>
              <dt>Registry → 渲染器</dt>
              <dd>组件名称与原生视图映射</dd>
            </div>
          </dl>
        </figcaption>
      </figure>
      <div className="runtime-example">
        <div className="runtime-example-source">
          <h4>Lang 源码</h4>
          <pre>{runtimeExample}</pre>
        </div>
        <div className="runtime-example-view">
          <div className="runtime-example-heading">
            <h4>交互示意 · Web</h4>
            <button
              className="quiet"
              aria-label="重置交互示意"
              onClick={() => {
                setQuantity(1);
                setSubmitted(null);
              }}
            >
              <RotateCcw size={13} />
              重置
            </button>
          </div>
          <p>
            <code>Store · $quantity = {quantity}</code>
          </p>
          <strong aria-live="polite">已选数量：{quantity}</strong>
          <div className="runtime-example-actions">
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
          <div className="runtime-example-event" aria-live="polite">
            <h4>上次提交事件</h4>
            <p>
              {submitted === null ? "尚未提交。" : `quantity: ${submitted}`}
            </p>
            {event ? (
              <details>
                <summary>ActionEvent 摘要</summary>
                <pre>{JSON.stringify(event, null, 2)}</pre>
              </details>
            ) : null}
          </div>
        </div>
      </div>
      <p className="micro runtime-example-note">
        示意使用 Web 状态，不运行 Swift SDK 或发送请求。
      </p>
      <details className="implementation-note">
        <summary>实现细节与源码</summary>
        <p>
          OpenUILang 通过 JavaScriptCore 执行随包提供的官方
          lang-core；OpenUIState 属于 OpenUISwiftUI，持有解析器、Store
          与查询管理器。
        </p>
        <p>
          客户端为每个 OpenUI 内容块保留独立的 OpenUIState。push()
          追加内容，complete() 正常结束，interrupt() 停止生成并保留已完成内容。
        </p>
        <p>
          按需接入工具时，QueryManager 管理查询与变更状态，ToolProvider
          由客户端提供实际调用。
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
  );
}
