import { useState, type ReactNode } from "react";
import { LoaderCircle, ImageOff } from "lucide-react";
import tokens from "../public/generated/tokens.json";
export { default as WorkingPrinciple } from "./WorkingPrinciple";

export const overview = "将 OpenUI Lang 渲染为可交互的原生界面。";

const systemSections = [
  ["scale", "2.1", "字体与颜色"],
  ["geometry", "2.2", "间距与圆角"],
  ["composition", "2.3", "组件结构与状态"],
  ["components", "2.4", "组件 API"],
  ["map-svg", "2.5", "Map 与 SVG"],
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
        <p className="eyebrow">02</p>
        <h2 id="system-title">设计系统</h2>
      </div>
      <figure className="system-map" aria-labelledby="system-map-title">
        <figcaption id="system-map-title">
          结构 <span>Web 示意</span>
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
            <p className="pattern-summary">按任务组合组件。</p>
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
        <p className="eyebrow">2.2</p>
        <h3 id="geometry-title">间距与圆角</h3>
        <p>Padding：内边距；Gap：项目间距；Corner Radius：圆角。</p>
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
        就绪条件 <span className="standard-term">Rendering Readiness</span>
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
              <td>布局字段确认后分配空间，下载独立进行。</td>
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
                文档校验后交给 WebKit；<a href="#frontier-svg">渲染反馈</a>
                待补齐。
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  );
}

export function CompositionPatterns() {
  return (
    <section className="section system-subsection" id="integration">
      <div className="chapter-heading">
        <p className="eyebrow">2.6</p>
        <h3>组合模式</h3>
      </div>
      <div className="composition-patterns">
        {[
          [
            "对象比较",
            "CompositeCardBlock",
            "图片、规格、价格与操作归属同一对象，同类字段保持一致顺序。",
          ],
          ["条件填写", "Form", "同一任务的字段、校验与提交入口共享边界。"],
          [
            "地点浏览",
            "Map",
            "标记与卡片对应同一地点，位置、介绍与操作保持关联。",
          ],
        ].map(([title, component, text]) => (
          <div key={title}>
            <h4>{title}</h4>
            <p>{text}</p>
            <a className="text-link" href={`#component-${component}`}>
              {component} →
            </a>
          </div>
        ))}
      </div>
    </section>
  );
}
