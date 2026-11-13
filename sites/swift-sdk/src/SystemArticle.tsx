import type { ReactNode } from "react";
import tokens from "../public/generated/tokens.json";

export const overview =
  "OpenUI Swift SDK 将 Agent 输出的界面描述（OpenUI Lang）渲染为原生界面。设计系统统一排版、颜色与组件行为；流式渲染管理布局、状态和资源，减少重排、闪动与选择丢失。";

const stages = [
  [
    "组件契约",
    "Component Contract",
    "组件库",
    "名称、参数、槽位与动作形成统一契约，供生成、校验和渲染共同使用。",
  ],
  [
    "声明式描述",
    "Declarative UI",
    "Agent",
    "用 OpenUI Lang 选择组件、填入内容、声明绑定与动作。",
  ],
  [
    "解析与求值",
    "Parsing & Evaluation",
    "语言核心",
    "解析引用和表达式，把程序与当前状态求值为组件树。",
  ],
  [
    "原生呈现",
    "Native Rendering",
    "SwiftUI",
    "按设计系统和可用空间呈现组件；资源到达时更新已有视图。",
  ],
  [
    "状态与事件",
    "State & Events",
    "组件",
    "输入和选择更新本地状态；提交读取当前值并产生动作事件。",
  ],
  [
    "应用处理",
    "Host Integration",
    "客户端",
    "处理导航、工具或继续对话，把实际结果交回 Agent。",
  ],
];
export function WorkingPrinciple() {
  return (
    <section
      className="section"
      id="principle"
      aria-labelledby="principle-title"
    >
      <div className="chapter-heading">
        <p className="eyebrow">01 / 工作原理</p>
        <h2 id="principle-title">从界面描述到原生交互。</h2>
        <p>生成、运行时和客户端各自承担明确职责，组件契约贯穿整个流程。</p>
      </div>
      <ol className="workflow-diagram" aria-label="生成与交互流程">
        {stages.map(([title, term, owner, description], index) => (
          <li key={term}>
            <div className="workflow-topline">
              <span>{String(index + 1).padStart(2, "0")}</span>
              <small>{owner}</small>
            </div>
            <h3>{title}</h3>
            <p className="standard-term">{term}</p>
            <p>{description}</p>
          </li>
        ))}
      </ol>
    </section>
  );
}

const systemSections = [
  ["scale", "2.1", "排版与颜色"],
  ["geometry", "2.2", "间距与形状"],
  ["composition", "2.3", "组件结构与状态"],
  ["components", "2.4", "组件目录与 API"],
  ["map-svg", "2.5", "地图与 SVG"],
  ["integration", "2.6", "组合模式"],
];
export function SystemDesign({ children }: { children: ReactNode }) {
  return (
    <section
      className="section system-chapter"
      id="system"
      aria-labelledby="system-title"
    >
      <div className="chapter-heading">
        <p className="eyebrow">02 / 设计系统</p>
        <h2 id="system-title">从视觉基础，到完整的交互任务。</h2>
        <p>
          视觉基础定义设计规则，设计变量为设计值命名并供组件引用，组件落实结构与行为，组合模式把组件组织成任务。
        </p>
      </div>
      <figure className="system-map" aria-labelledby="system-map-title">
        <figcaption id="system-map-title">
          设计系统结构 <span>Design System Architecture</span>
        </figcaption>
        <ol className="system-layers">
          <li>
            <div className="system-layer-title">
              <h3>视觉基础</h3>
              <span>Foundations</span>
            </div>
            <div className="foundation-domains">
              <div>
                <b>字体排印</b>
                <span>Typography</span>
                <small>文字角色 · 字号阶梯 · 行高</small>
              </div>
              <div>
                <b>颜色</b>
                <span>Color</span>
                <small>文字 · 表面 · 边界 · 状态</small>
              </div>
              <div>
                <b>间距</b>
                <span>Spacing</span>
                <small>内边距 · 项目间距 · 区段间距</small>
              </div>
              <div>
                <b>形状</b>
                <span>Shape</span>
                <small>圆角 · 轮廓 · 对象边界</small>
              </div>
            </div>
          </li>
          <li>
            <div className="system-layer-title">
              <h3>设计变量</h3>
              <span>Design Tokens</span>
            </div>
            <div className="token-mapping">
              <div>
                <b>标题文字</b>
                <code>textHeadingMd</code>
                <span>
                  {tokens.fonts.textHeadingMd.size} pt /{" "}
                  {tokens.fonts.textHeadingMd.weight}
                </span>
              </div>
              <div>
                <b>主文字色</b>
                <code>textNeutralPrimary</code>
                <span>
                  <i className="token-color" />
                  随浅色 / 深色外观解析
                </span>
              </div>
              <div>
                <b>内容内距</b>
                <code>spaceML</code>
                <span>{tokens.metrics.spaceML} pt</span>
              </div>
            </div>
          </li>
          <li>
            <div className="system-layer-title">
              <h3>组件规范</h3>
              <span>Components</span>
            </div>
            <div className="component-system">
              <div className="anatomy-example">
                <b>
                  结构 <span>Anatomy</span>
                </b>
                <div className="anatomy-object">
                  <span>标题 / Header</span>
                  <span>内容 / Body</span>
                  <span>操作 / Actions</span>
                </div>
              </div>
              <div>
                <b>
                  变体 <span>Variants</span>
                </b>
                <div className="variant-examples">
                  <span className="variant-card">card</span>
                  <span className="variant-sunk">sunk</span>
                  <span>clear</span>
                </div>
                <p>同一内容结构，采用不同的容器表面。</p>
              </div>
              <div>
                <b>
                  状态 <span>States</span>
                </b>
                <div className="state-examples">
                  <span>默认</span>
                  <span className="selected-state">选中</span>
                  <span>加载</span>
                  <span className="disabled-state">禁用</span>
                  <span>失败</span>
                </div>
                <p>状态对应真实输入、资源与动作结果。</p>
              </div>
            </div>
          </li>
          <li>
            <div className="system-layer-title">
              <h3>组合模式</h3>
              <span>Patterns</span>
            </div>
            <div className="pattern-examples">
              <div>
                <b>对象比较</b>
                <span>集合布局 → 对象卡片 → 对应操作</span>
              </div>
              <div>
                <b>填写与提交</b>
                <span>字段 → 本地状态 → 校验 → 提交</span>
              </div>
              <div>
                <b>地点浏览</b>
                <span>地图点位 ↔ 对象卡片 → 详情</span>
              </div>
            </div>
          </li>
        </ol>
        <div className="platform-foundation">
          <b>
            平台适配 <span>Platform Adaptation</span>
          </b>
          <span>可用空间 · 深浅外观 · Dynamic Type · 触控与辅助功能</span>
        </div>
      </figure>
      <nav className="system-contents" aria-label="第二章目录">
        {systemSections.map(([id, number, title]) => (
          <a href={`#${id}`} key={id}>
            <span>{number}</span>
            {title}
          </a>
        ))}
      </nav>
      {children}
    </section>
  );
}

export function LayoutFoundations() {
  return (
    <section
      className="section system-subsection"
      id="geometry"
      aria-labelledby="geometry-title"
    >
      <div className="chapter-heading">
        <p className="eyebrow">2.2 / Foundations · Spacing & Shape</p>
        <h3 id="geometry-title">间距表达关系，形状建立边界。</h3>
        <p>
          内边距（Padding）属于容器，项目间距（Gap）属于排列。圆角（Corner
          Radius）决定表面的轮廓，不代替内容分组。
        </p>
      </div>
      <div className="geometry-specimens">
        <div>
          <h4>
            间距阶梯 <span>Spacing Scale</span>
          </h4>
          <div className="spacing-scale">
            {(
              [
                "space2xs",
                "spaceS",
                "spaceM",
                "spaceML",
                "spaceXl",
                "space2xl",
              ] as const
            ).map((key) => (
              <div key={key}>
                <code>{key}</code>
                <span
                  className="spacing-bar"
                  style={{ width: tokens.metrics[key] * 3 }}
                />
                <b>{tokens.metrics[key]} pt</b>
              </div>
            ))}
          </div>
        </div>
        <div>
          <h4>
            圆角阶梯 <span>Radius Scale</span>
          </h4>
          <div className="radius-scale">
            {(
              [
                "radiusXs",
                "radiusM",
                "radiusXl",
                "radius3xl",
                "radiusFull",
              ] as const
            ).map((key) => (
              <div key={key}>
                <span style={{ borderRadius: tokens.metrics[key] }} />
                <code>{key}</code>
                <b>
                  {key === "radiusFull"
                    ? "胶囊形"
                    : `${tokens.metrics[key]} pt`}
                </b>
              </div>
            ))}
          </div>
          <div className="layout-anatomy" aria-label="容器内边距与项目间距示意">
            <span className="padding-label">Padding · 内边距</span>
            <div>
              <span>内容 A</span>
              <b>
                Gap
                <br />
                项目间距
              </b>
              <span>内容 B</span>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

export function ReadinessMatrix() {
  return (
    <div className="readiness-explainer">
      <h3>
        呈现就绪 <span className="standard-term">Rendering Readiness</span>
      </h3>
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
              <td>文档校验后交给 WebKit；完整渲染反馈尚未接入。</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  );
}

export function HostIntegration() {
  return (
    <section className="section system-subsection" id="integration">
      <div className="chapter-heading">
        <p className="eyebrow">2.6 / Patterns · State & Event Flow</p>
        <h3>组件围绕任务组合，事件携带当前状态。</h3>
        <p>
          表单模式（Form
          Pattern）把同一任务的输入、选择、校验与提交组合在一起；即时筛选直接更新本地状态，单个导航动作直接关联当前对象。
        </p>
      </div>
      <ol className="event-flow" aria-label="表单状态与事件流">
        {[
          ["输入与选择", "Input / Selection", "字段写入当前表单状态。"],
          ["校验与提交", "Validation / Submission", "读取提交时的最新值。"],
          ["动作事件", "ActionEvent", "携带当前对象、字段和动作上下文。"],
          ["宿主处理", "Host Handling", "导航、调用工具或交给 Agent。"],
        ].map(([title, term, text]) => (
          <li key={term}>
            <h4>{title}</h4>
            <span>{term}</span>
            <p>{text}</p>
          </li>
        ))}
      </ol>
      <p className="pattern-boundary">
        事件发出、Agent 收到选择、业务执行成功，是三个需要分别确认的结果。
      </p>
    </section>
  );
}
