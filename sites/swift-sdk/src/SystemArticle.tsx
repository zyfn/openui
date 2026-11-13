import { useState } from "react";
import { ArrowUpRight, ArrowRight } from "lucide-react";
import { sdkSource } from "./baseline";

export const overview =
  "OpenUI Swift SDK 将 Agent 输出的界面描述（OpenUI Lang）渲染为原生界面。设计系统统一排版、颜色与组件行为；流式渲染管理布局、状态和资源，减少重排、闪动与选择丢失。";
const source = `root = Stack([intro, details, actions], "column", "xl")
intro = TextContent("先看对象，再决定下一步。")
details = Card([CardHeader("对象名称", "必要的说明")])
actions = Buttons([Button("继续了解", @ToAssistant("继续了解"))])`;
const stages = [
  {
    title: "组件定义",
    term: "API / Schema",
    owner: "组件库",
    description:
      "组件库定义名称、参数类型和内容槽位，并关联原生实现。同一份定义生成给模型的说明，并用于解析和校验返回结果。",
    example:
      "CardHeader(title?, subtitle?)\nTextContent(text, size?)\n组件定义 → prompt / spec / schema",
    link: "GenUILib/ComponentLibrary.swift",
  },
  {
    title: "模型生成",
    term: "OpenUI Lang",
    owner: "Agent",
    description:
      "Agent 选择组件、组织内容并声明动作。字体、颜色与布局细节由 SDK 的统一规则落实。",
    example: source,
    link: "SDK-REFERENCE.zh-CN.md",
  },
  {
    title: "解析求值",
    term: "Parser / Evaluator",
    owner: "共享语言核心",
    description:
      "解析组件声明、引用、状态绑定与动作。后面的引用尚未到达时，已有内容继续保留。",
    example: "已解析的文字 → 可供显示\n未解析的引用 → 等待后续分片",
    link: "ARCHITECTURE.md",
  },
  {
    title: "原生渲染",
    term: "Native Rendering",
    owner: "SwiftUI",
    description:
      "组件按主题和可用空间布局。内容、图片与数据逐步到达时，更新已有视图，保留其状态。",
    example: "设计变量 → 组件样式\n布局约束 → 宽度与排列\n增量更新 → 已有视图",
    link: "UI-DESIGN.md",
  },
  {
    title: "交互事件",
    term: "State / Events",
    owner: "组件",
    description:
      "选择与输入更新当前状态；提交读取最新值，并携带对象和表单上下文产生事件。",
    example: "选择 / 输入 → 当前字段值\n校验 → ActionEvent",
    link: "Context/ComponentContext.swift",
  },
  {
    title: "应用处理",
    term: "App Integration",
    owner: "客户端",
    description:
      "客户端处理导航、工具调用或继续对话，将真实结果交回 Agent。点击成功与业务执行成功分别确认。",
    example: "事件与当前选择 → 客户端\n真实结果 → 下一轮回答",
    link: "README.md#6-交互围绕一个明确任务",
  },
];
export function WorkingPrinciple() {
  const [stage, setStage] = useState(0);
  const selected = stages[stage];
  return (
    <section className="section" id="principle">
      <div className="chapter-heading">
        <p className="eyebrow">01 / 工作流程</p>
        <h2>模型描述结构，SDK 渲染组件。</h2>
        <p>
          OpenUI 采用声明式 UI（Declarative UI）。模型声明组件、内容和动作，SDK
          根据组件定义创建原生界面。
        </p>
      </div>
      <div className="pipeline">
        <div className="pipeline-steps" role="group" aria-label="选择工作环节">
          {stages.map((item, index) => (
            <button
              key={item.title}
              aria-pressed={stage === index}
              aria-controls="pipeline-detail"
              onClick={() => setStage(index)}
            >
              <span className="pipeline-number">
                {String(index + 1).padStart(2, "0")}
              </span>
              <b>{item.title}</b>
              <small>{item.term}</small>
              {index < stages.length - 1 && (
                <ArrowRight size={14} aria-hidden="true" />
              )}
            </button>
          ))}
        </div>
        <article
          id="pipeline-detail"
          className="pipeline-detail compact-pipeline"
          aria-live="polite"
        >
          <div className="pipeline-copy">
            <p className="eyebrow">{selected.owner}</p>
            <h3>{selected.title}</h3>
            <p>{selected.description}</p>
            <a
              className="text-link"
              href={sdkSource(
                selected.link.startsWith("GenUILib/") ||
                  selected.link.startsWith("Context/")
                  ? "Sources/OpenUISwiftUI/" + selected.link
                  : selected.link,
              )}
              target="_blank"
              rel="noreferrer"
            >
              查看实现 <ArrowUpRight size={14} />
            </a>
          </div>
          <pre className="pipeline-code">{selected.example}</pre>
        </article>
        <p className="pipeline-loop">
          每个分片更新同一份程序；用户操作携带当前选择进入下一轮对话。
        </p>
      </div>
    </section>
  );
}
const designParts = [
  {
    term: "Foundations",
    title: "视觉规范",
    decision:
      "确定字体、字号、字重、行高、颜色、间距与圆角。正文、说明、价格和操作分别使用对应样式。",
    example: "正文 16pt；辅助说明 14pt、辅助色。价格和按钮保持各自尺度。",
    href: "#scale",
    label: "查看排版与颜色",
  },
  {
    term: "Design Tokens",
    title: "设计变量",
    decision:
      "将共享的设计值命名，组件统一引用。修改正文样式或主文字色时，同一角色的内容一起更新。",
    example: "值来自 OpenUITheme；文字样式由 TextStyles 映射到组件槽位。",
    href: "#scale",
    label: "查看实际变量",
  },
  {
    term: "Components",
    title: "组件规范",
    decision:
      "定义组件结构（Anatomy）、变体（Variants）和状态（States），包括选中、加载、禁用、失败及相应交互。",
    example: "按钮的可见尺寸与点击区域分开；表单提交读取最新选择。",
    href: "#composition",
    label: "查看组件示例",
  },
  {
    term: "Patterns",
    title: "组合模式",
    decision:
      "规定多个组件怎样完成一项任务：比较对象、展示商品、收集偏好或继续对话。",
    example:
      "商品按名称、介绍、属性、价格口径和操作组织；Form 用于填写与统一提交。",
    href: "#integration",
    label: "查看组合与事件",
  },
];
export function SystemDesign() {
  return (
    <section className="section" id="system">
      <div className="chapter-heading">
        <p className="eyebrow">02 / 设计系统</p>
        <h2>统一视觉、组件和组合规则。</h2>
        <p>
          OpenUI
          的设计系统包含视觉规范、设计变量、组件规范与组合模式，使不同内容使用一致的样式和行为。
        </p>
      </div>
      <div className="design-layers concise-layers">
        {designParts.map((item, index) => (
          <article key={item.term}>
            <div className="layer-heading">
              <span className="layer-index">
                {String(index + 1).padStart(2, "0")}
              </span>
              <div>
                <p className="eyebrow">{item.term}</p>
                <h3>{item.title}</h3>
              </div>
            </div>
            <div className="layer-copy">
              <p>{item.decision}</p>
              <p className="layer-lesson">{item.example}</p>
              <a className="text-link" href={item.href}>
                {item.label}
                <ArrowRight size={14} />
              </a>
            </div>
          </article>
        ))}
      </div>
      <Terminology />
    </section>
  );
}
function Terminology() {
  return (
    <details className="terminology">
      <summary>术语与参考</summary>
      <div className="article-table-wrap">
        <table className="article-table">
          <thead>
            <tr>
              <th>术语</th>
              <th>含义</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <th>Typography</th>
              <td>排版：字体、字号、字重、行高和文字层级。</td>
            </tr>
            <tr>
              <th>Design Tokens</th>
              <td>
                设计变量：对共享设计值的命名，如主文字色、正文样式、间距。
              </td>
            </tr>
            <tr>
              <th>Anatomy / States</th>
              <td>
                组件结构与状态：内容区域、变体，以及选中、加载、禁用等行为。
              </td>
            </tr>
            <tr>
              <th>Layout Stability</th>
              <td>布局稳定性：减少更新引发的不必要位移与重排。</td>
            </tr>
            <tr>
              <th>Identity / Key</th>
              <td>组件标识：让更新后的组件保留原有状态。</td>
            </tr>
            <tr>
              <th>Incremental Rendering</th>
              <td>增量渲染：分片到达后更新已有界面。</td>
            </tr>
          </tbody>
        </table>
      </div>
      <div className="term-sources">
        <a
          href="https://m3.material.io/foundations/design-tokens/overview"
          target="_blank"
          rel="noreferrer"
        >
          Material · Design Tokens <ArrowUpRight size={13} />
        </a>
        <a
          href="https://m3.material.io/styles/typography/overview"
          target="_blank"
          rel="noreferrer"
        >
          Material · Typography <ArrowUpRight size={13} />
        </a>
        <a
          href="https://carbondesignsystem.com/components/button/style/"
          target="_blank"
          rel="noreferrer"
        >
          Carbon · Component States <ArrowUpRight size={13} />
        </a>
        <a
          href="https://developer.apple.com/videos/play/wwdc2021/10022/"
          target="_blank"
          rel="noreferrer"
        >
          Apple · Identity / Lifetime <ArrowUpRight size={13} />
        </a>
        <a
          href="https://react.dev/learn/preserving-and-resetting-state"
          target="_blank"
          rel="noreferrer"
        >
          React · State / Keys <ArrowUpRight size={13} />
        </a>
      </div>
      <p className="micro">OpenUI 的具体取值与平台行为以 SDK 为准。</p>
    </details>
  );
}
export function ReadinessMatrix() {
  return (
    <details className="readiness-explainer">
      <summary>各类组件的增量渲染条件</summary>
      <p className="micro">
        这是 SDK 内部的呈现判断，不要求 Agent 增加 Lang 参数。
      </p>
      <div
        className="article-table-wrap"
        role="region"
        aria-label="组件呈现条件表，可横向滚动"
        tabIndex={0}
      >
        <table className="article-table">
          <thead>
            <tr>
              <th>类型</th>
              <th>呈现条件</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <th>文字</th>
              <td>已解析的安全前缀持续显示，后方引用不清空前文。</td>
            </tr>
            <tr>
              <th>图片与卡片</th>
              <td>先确定宽度与排列，再显示媒体；下载不决定列宽。</td>
            </tr>
            <tr>
              <th>折线与柱形</th>
              <td>使用已确认分类和数值，不提交半截数字或补零。</td>
            </tr>
            <tr>
              <th>比例图</th>
              <td>占比所需数据与总量完整后呈现。</td>
            </tr>
            <tr>
              <th>字段与按钮</th>
              <td>所需参数、状态和当前来源有效；提交通过校验。</td>
            </tr>
            <tr>
              <th>SVG</th>
              <td>
                文档校验后交给 WebKit；
                <a href="#frontier-svg">渲染反馈仍待补齐</a>。
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </details>
  );
}
export function HostIntegration() {
  return (
    <section className="section" id="integration">
      <div className="chapter-heading">
        <p className="eyebrow">REFERENCE / 应用集成</p>
        <h3>交互事件要携带当前选择。</h3>
        <p>
          Form
          收集同一任务的字段并统一提交。即时筛选可以直接更新本地状态，商品展示和单个跳转无需套用
          Form。
        </p>
      </div>
      <div className="handoff-chain">
        <span>当前对象与字段值</span>
        <ArrowRight size={15} />
        <span>校验 / ActionEvent</span>
        <ArrowRight size={15} />
        <span>客户端处理</span>
        <ArrowRight size={15} />
        <span>下一轮回答</span>
      </div>
      <p className="micro">
        客户端通过既有 buildMessage／parseMessage 传递上下文。事件已发出、Agent
        收到选择、业务执行成功分别确认。
      </p>
    </section>
  );
}
