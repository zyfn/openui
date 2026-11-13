import { useState, type ReactNode } from "react";
import { LoaderCircle, ImageOff } from "lucide-react";
import tokens from "../public/generated/tokens.json";
export { default as WorkingPrinciple } from "./WorkingPrinciple";

export const overview =
  "OpenUI Swift SDK 将 Agent 输出的界面描述（OpenUI Lang）渲染为原生界面。设计系统统一排版、颜色与组件行为；流式渲染管理布局、状态和资源，减少重排、闪动与选择丢失。";

const systemSections = [
  ["scale", "2.1", "排版与颜色"],
  ["geometry", "2.2", "间距与形状"],
  ["composition", "2.3", "组件结构与状态"],
  ["components", "2.4", "组件目录与 API"],
  ["map-svg", "2.5", "地图与 SVG"],
  ["integration", "2.6", "组合模式"],
];
export function SystemDesign({
  children,
  variant,
  onVariantChange,
}: {
  children: ReactNode;
  variant: string;
  onVariantChange: (value: string) => void;
}) {
  const [state, setState] = useState("default");
  const states = [
    { value: "default", label: "默认" },
    { value: "selected", label: "选中" },
    { value: "loading", label: "加载" },
    { value: "disabled", label: "禁用" },
    { value: "error", label: "失败" },
  ];
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
          设计系统结构 <span>Design System Architecture · Web</span>
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
                <div
                  className={`anatomy-object surface-${variant} state-${state}`}
                  aria-label="组件结构与状态预览"
                  aria-busy={state === "loading"}
                >
                  <span>
                    <small>Header</small>对象名称
                  </span>
                  <span className="anatomy-body" aria-live="polite">
                    <small>Body</small>
                    {state === "loading" ? (
                      <>
                        <LoaderCircle size={14} className="loading-spin" />
                        资源加载中
                      </>
                    ) : state === "error" ? (
                      <>
                        <ImageOff size={14} />
                        资源未能加载
                      </>
                    ) : (
                      "对象内容"
                    )}
                  </span>
                  <span>
                    <small>Actions</small>
                    <button
                      className="diagram-action"
                      aria-pressed={state === "selected"}
                      disabled={state === "disabled" || state === "loading"}
                      onClick={() =>
                        setState(state === "selected" ? "default" : "selected")
                      }
                    >
                      {state === "selected" ? "取消选择" : "选择对象"}
                    </button>
                  </span>
                </div>
              </div>
              <div>
                <b>
                  变体 <span>Variants</span>
                </b>
                <div className="variant-examples">
                  {["card", "sunk", "clear"].map((value) => (
                    <button
                      key={value}
                      aria-pressed={variant === value}
                      onClick={() => onVariantChange(value)}
                    >
                      {value}
                    </button>
                  ))}
                </div>
                <p>同一内容结构，采用不同的容器表面。</p>
              </div>
              <div>
                <b>
                  状态 <span>States</span>
                </b>
                <div className="state-examples">
                  {states.map((item) => (
                    <button
                      key={item.value}
                      aria-pressed={state === item.value}
                      onClick={() => setState(item.value)}
                    >
                      {item.label}
                    </button>
                  ))}
                </div>
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

const spacingKeys = [
  "space2xs",
  "spaceS",
  "spaceM",
  "spaceML",
  "spaceXl",
  "space2xl",
] as const;
const radiusKeys = [
  "radiusXs",
  "radiusM",
  "radiusXl",
  "radius3xl",
  "radiusFull",
] as const;
type SpacingKey = (typeof spacingKeys)[number];
type RadiusKey = (typeof radiusKeys)[number];
export function LayoutFoundations() {
  const [target, setTarget] = useState<"padding" | "gap">("padding");
  const [padding, setPadding] = useState<SpacingKey>("spaceML");
  const [gap, setGap] = useState<SpacingKey>("spaceM");
  const [radius, setRadius] = useState<RadiusKey>("radiusFull");
  const currentSpacing = target === "padding" ? padding : gap;
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
          Padding 控制容器内边距，Gap 控制项目间距；Corner Radius
          控制轮廓。选择现有 Token，预览中的尺寸同步变化。
        </p>
      </div>
      <div className="geometry-specimens">
        <div>
          <div className="geometry-controls">
            <h4>
              间距阶梯 <span>Spacing Scale</span>
            </h4>
            <div className="segmented" role="group" aria-label="间距作用位置">
              <button
                aria-pressed={target === "padding"}
                onClick={() => setTarget("padding")}
              >
                Padding
              </button>
              <button
                aria-pressed={target === "gap"}
                onClick={() => setTarget("gap")}
              >
                Gap
              </button>
            </div>
          </div>
          <div className="spacing-scale">
            {spacingKeys.map((key) => (
              <button
                key={key}
                aria-pressed={currentSpacing === key}
                aria-label={`${target === "padding" ? "内边距" : "项目间距"} ${key} ${tokens.metrics[key]} pt`}
                onClick={() =>
                  target === "padding" ? setPadding(key) : setGap(key)
                }
              >
                <code>{key}</code>
                <span
                  className="spacing-bar"
                  style={{ width: tokens.metrics[key] * 3 }}
                />
                <b>{tokens.metrics[key]} pt</b>
              </button>
            ))}
          </div>
        </div>
        <div>
          <h4>
            圆角阶梯 <span>Radius Scale</span>
          </h4>
          <div className="radius-scale">
            {radiusKeys.map((key) => (
              <button
                key={key}
                aria-pressed={radius === key}
                onClick={() => setRadius(key)}
              >
                <span style={{ borderRadius: tokens.metrics[key] }} />
                <code>{key}</code>
                <b>
                  {key === "radiusFull"
                    ? "胶囊形"
                    : `${tokens.metrics[key]} pt`}
                </b>
              </button>
            ))}
          </div>
        </div>
      </div>
      <div className="geometry-live">
        <div className="geometry-live-meta">
          <span>
            Padding <code>{padding}</code> {tokens.metrics[padding]} pt
          </span>
          <span>
            Gap <code>{gap}</code> {tokens.metrics[gap]} pt
          </span>
          <span>
            Corner Radius <code>{radius}</code>
          </span>
          <button
            className="quiet"
            onClick={() => {
              setPadding("spaceML");
              setGap("spaceM");
              setRadius("radiusFull");
            }}
          >
            重置
          </button>
        </div>
        <div
          className="geometry-live-layout"
          aria-label="内边距与项目间距预览"
          style={{ padding: tokens.metrics[padding], gap: tokens.metrics[gap] }}
        >
          <div className="geometry-content-block">内容 A</div>
          <div className="geometry-content-block">内容 B</div>
          <button
            className="geometry-shape-button"
            style={{ borderRadius: tokens.metrics[radius] }}
          >
            操作
          </button>
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
