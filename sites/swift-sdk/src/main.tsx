import React, { useState, useEffect, useMemo, Suspense, lazy } from "react";
import { createRoot } from "react-dom/client";
import {
  ArrowUpRight,
  ArrowRight,
  Play,
  Pause,
  RotateCcw,
  Check,
  Copy,
  Search,
  ChevronDown,
  Moon,
  Sun,
  MapPin,
  MessageCircle,
  FileText,
  Keyboard,
  Maximize2,
  X,
  Code2,
  Layers,
} from "lucide-react";
import tokens from "../public/generated/tokens.json";
import reference from "../public/generated/reference.json";
import "./style.css";
import PreviewBoundary from "./PreviewBoundary";
import {
  WorkingPrinciple,
  SystemDesign,
  LayoutFoundations,
  ReadinessMatrix,
  HostIntegration,
  overview,
} from "./SystemArticle";
import DesignFrontiers from "./DesignFrontiers";
import { sdkBaseline } from "./baseline";
const Playground = lazy(() => import("./Playground"));
const MapSpecimen = lazy(() => import("./MapSpecimen"));
const github = "https://github.com/zyfn/openui";
const lake =
  "https://img1.qunarzz.com/travel/d0/1508/b5/86a1839a0346a8.jpg_r_720x480x95_04ad6f0a.jpg";
const palace =
  "https://p9.itc.cn/q_70/images03/20221030/ec6c914e9d9e483bb46ef2e1359a2d8b.jpeg";
const source =
  'root = Stack([\n  Card([Image("苏堤", "' +
  lake +
  '"),\n    CardHeader("湖边漫步", "沿湖步道与柳树"),\n    TextContent("走一段喜欢的风景。", "small")], "clear"),\n  Card([Image("德寿宫", "' +
  palace +
  '"),\n    CardHeader("宋韵建筑", "红墙与宫苑遗址"),\n    TextContent("从建筑看见历史的层次。", "small")], "clear")\n], "row", "xl", "stretch", "start", true)';
const componentGroups: Record<string, string> = {
  Layout: "布局",
  Content: "文字与媒体",
  Charts: "图表",
  "Charts (1D)": "占比图",
  "Charts (2D)": "趋势与数量",
  "Charts (Scatter)": "散点图",
  Tables: "表格",
  Cards: "卡片",
  Forms: "表单",
  Buttons: "操作",
  "Data Display": "数据与图标",
  "Card Building Blocks": "图文原件",
  "Card Blocks": "卡片集合",
  "Map & SVG": "地图与图解",
};
type ComponentInfo = (typeof reference.components)[number];
function CopyButton({
  text,
  label = "复制",
}: {
  text: string;
  label?: string;
}) {
  const [copied, set] = useState(false);
  return (
    <button
      className="quiet copy"
      onClick={async () => {
        try {
          await navigator.clipboard.writeText(text);
          set(true);
          setTimeout(() => set(false), 1500);
        } catch {
          set(false);
        }
      }}
      aria-label={label}
    >
      {copied ? <Check size={15} /> : <Copy size={15} />}{" "}
      {copied ? "已复制" : label}
    </button>
  );
}
function App() {
  const [dark, setDark] = useState(false);
  const [progress, setProgress] = useState(100);
  const [playing, setPlaying] = useState(false);
  const [speed, setSpeed] = useState(1);
  const [code, setCode] = useState(false);
  const [query, setQuery] = useState("");
  const [group, setGroup] = useState("全部");
  const [selected, setSelected] = useState("Card");
  const [preview, setPreview] = useState(false);
  const [example, setExample] = useState("");
  const [step, setStep] = useState(4);
  const [streamPlay, setStreamPlay] = useState(false);
  const [variant, setVariant] = useState("card");
  const [size, setSize] = useState("small");
  const [filled, setFilled] = useState(false);
  const [target, setTarget] = useState(false);
  const [chosen, setChosen] = useState(["自然松弛"]);
  const [submitted, setSubmitted] = useState(false);
  const [status, setStatus] = useState("neutral");
  useEffect(() => {
    document.documentElement.dataset.theme = dark ? "dark" : "light";
  }, [dark]);
  useEffect(() => {
    if (!playing) return;
    const t = setInterval(
      () =>
        setProgress((p) => {
          if (p >= 100) return 100;
          return Math.min(100, p + speed * 2);
        }),
      70,
    );
    return () => clearInterval(t);
  }, [playing, speed]);
  useEffect(() => {
    if (!streamPlay) return;
    const t = setInterval(
      () =>
        setStep((s) => {
          if (s >= 4) return 4;
          return s + 1;
        }),
      1600,
    );
    return () => clearInterval(t);
  }, [streamPlay]);
  useEffect(() => {
    if (progress >= 100) setPlaying(false);
  }, [progress]);
  useEffect(() => {
    if (step >= 4) setStreamPlay(false);
  }, [step]);
  const filtered = reference.components.filter(
    (c) =>
      (group === "全部" || c.group === group) &&
      `${c.name} ${c.purpose} ${c.treatment}`
        .toLowerCase()
        .includes(query.toLowerCase()),
  );
  const current = reference.components.find((c) => c.name === selected)!;
  const currentExamples = reference.examples.filter((e) =>
    current.examples.includes(e.id),
  );
  const activeExample =
    reference.examples.find((e) => e.id === example) || currentExamples[0];
  const style = useMemo(() => {
    const t: Record<string, string> = {};
    for (const [k, v] of Object.entries(tokens.colors))
      t["--sdk-" + k] = v[dark ? "dark" : "light"];
    for (const [k, v] of Object.entries(tokens.metrics))
      t["--sdk-" + k] = `${v}px`;
    return t as React.CSSProperties;
  }, [dark]);
  const choose = (c: ComponentInfo) => {
    setSelected(c.name);
    setExample(c.examples[0] || "");
    setPreview(false);
    history.replaceState(null, "", `#component-${c.name}`);
  };
  useEffect(() => {
    const reveal = () => {
      const hash = decodeURIComponent(location.hash.slice(1));
      const component = hash.startsWith("component-")
        ? reference.components.find((c) => c.name === hash.slice(10))
        : undefined;
      if (component) {
        setSelected(component.name);
        setExample(component.examples[0] || "");
        setPreview(false);
      }
      const target = document.getElementById(component ? "components" : hash);
      if (!target) return;
      requestAnimationFrame(() => target.scrollIntoView({ block: "start" }));
    };
    const click = (event: MouseEvent) => {
      const link = (event.target as Element).closest?.('a[href^="#"]');
      if (link?.getAttribute("href") === location.hash)
        window.dispatchEvent(new HashChangeEvent("hashchange"));
    };
    window.addEventListener("hashchange", reveal);
    document.addEventListener("click", click);
    reveal();
    return () => {
      window.removeEventListener("hashchange", reveal);
      document.removeEventListener("click", click);
    };
  }, []);
  return (
    <div style={style}>
      <header className="nav">
        <a className="wordmark" href="#">
          OpenUI<span>Swift SDK</span>
        </a>
        <nav aria-label="文章导航">
          <a href="#principle">01 工作原理</a>
          <a href="#system">02 设计系统</a>
          <a href="#streaming">03 流式渲染</a>
          <a href="#frontiers">04 当前限制</a>
        </nav>
        <div className="nav-end">
          <button
            className="icon-button"
            onClick={() => setDark(!dark)}
            aria-label={dark ? "切换浅色" : "切换深色"}
          >
            {dark ? <Sun size={18} /> : <Moon size={18} />}
          </button>
          <a href={github} target="_blank" rel="noreferrer">
            GitHub <ArrowUpRight size={14} />
          </a>
        </div>
      </header>
      <main>
        <section className="hero" id="language">
          <p className="eyebrow">OPENUI · THE SWIFT EXPERIENCE</p>
          <h1>
            模型生成结构，
            <br className="mobile-break" />
            SDK 负责渲染。
          </h1>
          <p className="lede">{overview}</p>
          <p className="release-note">
            <a href={sdkBaseline.url} target="_blank" rel="noreferrer">
              当前发布：{sdkBaseline.label}
              <ArrowUpRight size={13} />
            </a>
          </p>
          <div className="hero-stage">
            <div className="garden-grid" aria-label="生成过程示意">
              {[
                {
                  title: "湖边漫步",
                  sub: "沿湖步道与柳树",
                  body: "走一段喜欢的风景。",
                  tag: "苏堤",
                  url: lake,
                },
                {
                  title: "宋韵建筑",
                  sub: "红墙与宫苑遗址",
                  body: "从建筑看见历史的层次。",
                  tag: "德寿宫",
                  url: palace,
                },
              ].map((c, i) => (
                <div className="garden-card" key={c.title}>
                  <div className="garden-image">
                    {progress > 20 + i * 28 ? (
                      <img
                        src={c.url}
                        alt={c.sub}
                        fetchPriority={i === 0 ? "high" : "auto"}
                      />
                    ) : (
                      <div className="image-wait">
                        <Layers size={22} />
                      </div>
                    )}
                  </div>
                  <div className="garden-body">
                    <h3>{progress > 6 + i * 28 ? c.title : "\u00a0"}</h3>
                    <p className="support">
                      {progress > 12 + i * 28 ? c.sub : "\u00a0"}
                    </p>
                    <p>{progress > 30 + i * 28 ? c.body : "\u00a0"}</p>
                    <span className="tag">
                      <MapPin size={13} />
                      {c.tag}
                    </span>
                  </div>
                </div>
              ))}
            </div>
            <aside className="hero-notes">
              <div className="play-controls">
                <button
                  className="pill primary"
                  onClick={() => {
                    if (progress >= 100) setProgress(0);
                    setPlaying(!playing);
                  }}
                >
                  {playing ? <Pause size={14} /> : <Play size={14} />}{" "}
                  {playing ? "暂停" : "播放生成"}
                </button>
                <label className="speed">
                  速度
                  <select
                    aria-label="生成速度"
                    value={speed}
                    onChange={(e) => setSpeed(Number(e.target.value))}
                  >
                    <option value={0.5}>0.5×</option>
                    <option value={1}>1×</option>
                    <option value={2}>2×</option>
                  </select>
                </label>
                <button
                  className="icon-button"
                  aria-label="重新生成"
                  onClick={() => {
                    setProgress(0);
                    setPlaying(true);
                  }}
                >
                  <RotateCcw size={17} />
                </button>
              </div>
              <label className="range-label">
                内容到达 <output>{Math.round(progress)}%</output>
                <input
                  aria-label="内容到达进度"
                  type="range"
                  min="0"
                  max="100"
                  value={progress}
                  onChange={(e) => {
                    setPlaying(false);
                    setProgress(+e.target.value);
                  }}
                />
              </label>
              <p className="note">
                两列先分配宽度，文字在列内增长。图片下载只替换像素，不决定卡片大小。
              </p>
              <button
                className="disclosure"
                aria-expanded={code}
                onClick={() => setCode(!code)}
              >
                查看这段 Lang{" "}
                <ChevronDown size={16} className={code ? "rotated" : ""} />
              </button>
              {code ? (
                <div className="code-block">
                  <CopyButton text={source} />
                  <pre>{source}</pre>
                </div>
              ) : (
                <div className="small-chain">
                  <span>结构</span>
                  <ArrowRight size={14} />
                  <span>内容</span>
                  <ArrowRight size={14} />
                  <span>交互</span>
                </div>
              )}
              <p className="micro">布局示意 · Web</p>
            </aside>
          </div>
        </section>
        <WorkingPrinciple />
        <SystemDesign>
          <div className="system-content" id="reference">
            <div className="system-sections">
              <section className="section system-subsection" id="scale">
                <div className="split">
                  <div className="article-copy">
                    <p className="eyebrow">
                      2.1 / Foundations · Typography & Color
                    </p>
                    <h3>字体排印与语义颜色。</h3>
                    <p>
                      字体排印（Typography）统一字体、字号、字重与行高。字号阶梯（Type
                      Scale）定义文字角色的相对尺度，形成排版层级（Typographic
                      Hierarchy）。
                    </p>
                    <p>
                      语义颜色（Semantic
                      Color）按用途分配：标题与正文使用主文字色，规格与图注使用辅助色，状态色表达真实状态。文字较小，不意味着它应当变浅。
                    </p>
                  </div>
                  <div className="type-lab specimen">
                    <div className="specimen-top">
                      <span>字号阶梯 · Type Scale</span>
                      <div className="segmented">
                        <button
                          aria-pressed={!dark}
                          onClick={() => setDark(false)}
                        >
                          浅色
                        </button>
                        <button
                          aria-pressed={dark}
                          onClick={() => setDark(true)}
                        >
                          深色
                        </button>
                      </div>
                    </div>
                    <div className="type-lines">
                      {[
                        {
                          key: "textHeadingMd",
                          label: "大标题",
                          term: "Heading MD",
                          role: "display",
                          text: "杭州文化漫游",
                        },
                        {
                          key: "textHeadingSm",
                          label: "章节标题",
                          term: "Heading SM",
                          role: "section",
                          text: "沿着湖岸认识城市",
                        },
                        {
                          key: "textHeadingXs",
                          label: "对象标题",
                          term: "Heading XS",
                          role: "title",
                          text: "对象名称",
                        },
                        {
                          key: "textBodyDefault",
                          label: "正文",
                          term: "Body",
                          role: "body",
                          text: "从建筑、街巷与湖岸，观察一座城市。",
                        },
                        {
                          key: "textBodySm",
                          label: "紧凑正文",
                          term: "Body Small",
                          role: "detail",
                          text: "对象的介绍与主要判断信息。",
                        },
                        {
                          key: "textBodyXs",
                          label: "图注与补充",
                          term: "Caption",
                          role: "caption",
                          text: "图片来源、图注与补充说明。",
                        },
                      ].map((r) => {
                        const f =
                          tokens.fonts[r.key as keyof typeof tokens.fonts];
                        return (
                          <div className="type-line" key={r.key}>
                            <div className="type-role">
                              <b>{r.label}</b>
                              <small>{r.term}</small>
                              <code>{r.key}</code>
                            </div>
                            <span
                              style={{
                                fontSize: f.size,
                                fontWeight: f.weight,
                                lineHeight:
                                  reference.leading[
                                    r.role as keyof typeof reference.leading
                                  ],
                                color:
                                  r.role === "caption"
                                    ? "var(--sdk-textNeutralSecondary)"
                                    : undefined,
                              }}
                            >
                              {r.text}
                            </span>
                            <span className="type-meta">
                              {f.size} pt · {f.weight}
                              <small>
                                {
                                  reference.leading[
                                    r.role as keyof typeof reference.leading
                                  ]
                                }
                                × 行高
                              </small>
                            </span>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                </div>
                <div className="swatches">
                  {[
                    {
                      key: "textNeutralPrimary",
                      name: "主文字",
                      desc: "标题与正文，共享清晰的阅读对比。",
                    },
                    {
                      key: "textNeutralSecondary",
                      name: "辅助文字",
                      desc: "规格、说明与图注，保持次序。",
                    },
                    {
                      key: "borderDefault",
                      name: "边界",
                      desc: "用于对象或记录的边界。",
                    },
                    {
                      key: "sunk",
                      name: "下沉表面",
                      desc: "通过浅底分组，不叠加边框。",
                    },
                  ].map((c) => (
                    <button
                      className="swatch"
                      key={c.key}
                      title="点击复制色值"
                      onClick={() =>
                        navigator.clipboard.writeText(
                          tokens.colors[c.key as keyof typeof tokens.colors][
                            dark ? "dark" : "light"
                          ],
                        )
                      }
                    >
                      <span
                        className="swatch-color"
                        style={{ background: `var(--sdk-${c.key})` }}
                      />
                      <span>
                        <b>{c.name}</b>
                        <code>
                          {
                            tokens.colors[c.key as keyof typeof tokens.colors][
                              dark ? "dark" : "light"
                            ]
                          }
                        </code>
                        <small>{c.desc}</small>
                      </span>
                    </button>
                  ))}
                </div>
                <div className="chart-color-reference">
                  <span>图表 · 系统色</span>
                  <div>
                    {tokens.chartPalette.map((c, i) => (
                      <button
                        key={i}
                        style={{ background: c[dark ? "dark" : "light"] }}
                        title={c[dark ? "dark" : "light"]}
                        aria-label={`复制图表颜色 ${i + 1}`}
                        onClick={() =>
                          navigator.clipboard.writeText(
                            c[dark ? "dark" : "light"],
                          )
                        }
                      />
                    ))}
                  </div>
                  <small>
                    由 Swift SDK 实际导出；此处为 macOS 系统色。React
                    预览选色顺序可能不同，原生呈现跟随所在平台。
                  </small>
                </div>
              </section>

              <LayoutFoundations />
              <section className="section system-subsection" id="composition">
                <div className="chapter-heading">
                  <p className="eyebrow">
                    2.3 / Components · Anatomy, Variants & States
                  </p>
                  <h3>卡片、按钮与表单。</h3>
                  <p>
                    容器管理空间，卡片的表面表达边界，表单收集并提交选择。透明
                    Card 也可分配横排宽度，组件名不等于一定出现一个边框。
                  </p>
                </div>
                <div className="experiment-grid">
                  <div className="experiment">
                    <div className="experiment-head">
                      <h4>同一个对象，三种表面</h4>
                      <div className="segmented">
                        {["card", "sunk", "clear"].map((v) => (
                          <button
                            aria-pressed={variant === v}
                            onClick={() => setVariant(v)}
                            key={v}
                          >
                            {v}
                          </button>
                        ))}
                      </div>
                    </div>
                    <div className={`object-sample ${variant}`}>
                      <h4>住在步行方便的地方</h4>
                      <p className="support">离主要目的地较近</p>
                      <p>
                        名称负责识别，短介绍提供判断依据。背景与边框表达分组，内容的职责保持一致。
                      </p>
                      <div className="tags">
                        <span className="tag">步行友好</span>
                        <span className="tag">位置</span>
                      </div>
                    </div>
                    <p className="micro">
                      {variant === "clear"
                        ? "clear：无边框、零内边距，仍可共享横排宽度；列间距由父容器管理。"
                        : variant === "sunk"
                          ? "sunk：下沉背景与内边距，无分组边框。"
                          : "card：背景、16pt 内边距与边框共同建立对象边界。"}
                    </p>
                  </div>
                  <div className="experiment">
                    <div className="experiment-head">
                      <h4>按钮的尺寸与触控区域</h4>
                      <select
                        aria-label="按钮档位"
                        value={size}
                        onChange={(e) => setSize(e.target.value)}
                      >
                        {["extra-small", "small", "medium", "large"].map(
                          (s) => (
                            <option key={s}>{s}</option>
                          ),
                        )}
                      </select>
                    </div>
                    <div className="button-stage">
                      <div
                        className={target ? "touch-target" : ""}
                        style={{ width: filled ? "100%" : undefined }}
                      >
                        <button
                          className={`sdk-button ${size}`}
                          style={{ width: filled ? "100%" : undefined }}
                          onClick={() => setTarget(!target)}
                        >
                          查看详情
                        </button>
                      </div>
                    </div>
                    <div className="inline-controls">
                      <label>
                        <input
                          type="checkbox"
                          checked={filled}
                          onChange={(e) => setFilled(e.target.checked)}
                        />
                        纵排铺满
                      </label>
                      <label>
                        <input
                          type="checkbox"
                          checked={target}
                          onChange={(e) => setTarget(e.target.checked)}
                        />
                        显示触控范围
                      </label>
                    </div>
                    <p className="micro">
                      可见最小高度{" "}
                      {
                        { "extra-small": 28, small: 32, medium: 40, large: 48 }[
                          size
                        ]
                      }
                      pt；外层目标至少 44pt。small 常用于卡内入口，large
                      留给独立主要操作。
                    </p>
                  </div>
                </div>
                <div className="experiment-grid">
                  <div className="experiment">
                    <div className="experiment-head">
                      <h4>一项选择，一次明确提交</h4>
                      <span className="subtle-label">Form</span>
                    </div>
                    <form
                      className="form-sample"
                      onSubmit={(e) => {
                        e.preventDefault();
                        setSubmitted(true);
                      }}
                    >
                      <h4>喜欢哪种卧室氛围？</h4>
                      <p className="support">可以多选，提交时携带当前选择。</p>
                      <div className="options">
                        {["自然松弛", "温暖复古", "清爽利落"].map((o) => (
                          <label
                            className={chosen.includes(o) ? "chosen" : ""}
                            key={o}
                          >
                            <input
                              type="checkbox"
                              checked={chosen.includes(o)}
                              onChange={() => {
                                setChosen((a) =>
                                  a.includes(o)
                                    ? a.filter((v) => v !== o)
                                    : [...a, o],
                                );
                                setSubmitted(false);
                              }}
                            />
                            <span>{o}</span>
                            {chosen.includes(o) && <Check size={16} />}
                          </label>
                        ))}
                      </div>
                      <button
                        className="sdk-button medium full"
                        disabled={!chosen.length}
                      >
                        生成布置建议
                      </button>
                    </form>
                    <details open={submitted}>
                      <summary>查看提交事件</summary>
                      <pre className="payload">
                        {JSON.stringify(
                          {
                            type: "continue_conversation",
                            formName: "bedroom-style-exploration",
                            formState: {
                              "bedroom-style-exploration": {
                                卧室氛围: {
                                  value: chosen,
                                  componentType: "OptionCards",
                                },
                              },
                            },
                          },
                          null,
                          2,
                        )}
                      </pre>
                    </details>
                  </div>
                  <div className="experiment">
                    <div className="experiment-head">
                      <h4>说明，和真正的状态</h4>
                      <select
                        aria-label="提示状态"
                        value={status}
                        onChange={(e) => setStatus(e.target.value)}
                      >
                        {["neutral", "info", "success", "warning", "error"].map(
                          (s) => (
                            <option key={s}>{s}</option>
                          ),
                        )}
                      </select>
                    </div>
                    <div className={`callout-sample ${status}`}>
                      {["success", "warning", "error"].includes(status) && (
                        <span className="state-symbol">
                          {status === "success"
                            ? "✓"
                            : status === "warning"
                              ? "!"
                              : "×"}
                        </span>
                      )}
                      <div>
                        <h4>
                          {
                            {
                              neutral: "补充说明",
                              info: "相关信息",
                              success: "已完成",
                              warning: "仍需确认",
                              error: "需要处理",
                            }[status]
                          }
                        </h4>
                        <p>
                          {
                            {
                              neutral: "用于交代背景、口径或假设。",
                              info: "开放时段及预约要求，以对应地点的公告为准。",
                              success: "明确操作完成后，才展示成功反馈。",
                              warning: "缺少完成操作所需的信息，请检查后继续。",
                              error:
                                "操作未完成，说明问题并提供可以继续的方向。",
                            }[status]
                          }
                        </p>
                      </div>
                    </div>
                    <p>
                      普通说明采用轻量竖线；成功、待确认、错误保留克制的状态识别。颜色用于表达事实，不因为出现一个图标，就给整块内容染色。
                    </p>
                    <div className="icontext-sample">
                      <MessageCircle size={24} />
                      <div>
                        <h4>空白聊天页</h4>
                        <p className="support">
                          输入入口是主角，导航保持可发现。
                        </p>
                      </div>
                    </div>
                    <p className="micro">
                      IconText
                      的图标与整组标题和说明垂直居中；普通样式使用中性色。
                    </p>
                  </div>
                </div>
              </section>

              <section className="section system-subsection" id="components">
                <div className="catalog-heading">
                  <div>
                    <p className="eyebrow">2.4 / Components · Catalog & API</p>
                    <h3>组件 API 参考。</h3>
                    <p>
                      87 个已注册组件。定义从当前 Swift SDK
                      导出，说明对应实际处理；数据记录随父级呈现，不为它们虚构独立界面。
                    </p>
                  </div>
                  <label className="search">
                    <Search size={18} />
                    <input
                      value={query}
                      onChange={(e) => setQuery(e.target.value)}
                      placeholder="搜索组件或用途"
                      aria-label="搜索组件"
                    />
                  </label>
                </div>
                <div
                  className="category-strip"
                  role="group"
                  aria-label="组件类别"
                >
                  {[
                    "全部",
                    ...new Set(reference.components.map((c) => c.group)),
                  ].map((g) => (
                    <button
                      aria-pressed={group === g}
                      onClick={() => setGroup(g)}
                      key={g}
                    >
                      {componentGroups[g] || g}
                    </button>
                  ))}
                </div>
                <div className="catalog">
                  <div className="component-list" aria-label="组件目录">
                    {filtered.length ? (
                      filtered.map((c) => (
                        <button
                          aria-pressed={selected === c.name}
                          onClick={() => choose(c)}
                          key={c.name}
                        >
                          <span>{c.name}</span>
                          <small>{c.purpose}</small>
                          <ArrowRight size={14} />
                        </button>
                      ))
                    ) : (
                      <p className="empty-state">
                        没有匹配的组件。试试“图表”“选择”或组件名称。
                      </p>
                    )}
                    <span className="micro">{filtered.length} 个组件</span>
                  </div>
                  <article
                    className="component-detail"
                    id={`component-${selected}`}
                  >
                    <div className="detail-title">
                      <h4>{current.name}</h4>
                      <span className="subtle-label">{current.purpose}</span>
                    </div>
                    <p>{current.treatment}</p>
                    <div className="parameter-reference">
                      <h4>参数与位置顺序</h4>
                      <pre className="signature">{current.signature}</pre>
                      <p className="micro">{current.description}</p>
                      <CopyButton text={current.signature} />
                    </div>
                    {activeExample ? (
                      <>
                        <div className="preview-toolbar">
                          <label>
                            关联示例
                            <select
                              aria-label="关联示例"
                              value={activeExample.id}
                              onChange={(e) => {
                                setExample(e.target.value);
                                setPreview(false);
                              }}
                            >
                              {currentExamples.map((e) => (
                                <option key={e.id} value={e.id}>
                                  {e.name}
                                </option>
                              ))}
                            </select>
                          </label>
                          <button
                            className="pill primary"
                            onClick={() => setPreview(!preview)}
                          >
                            <Code2 size={14} />
                            {preview ? "收起预览" : "打开可编辑预览"}
                          </button>
                        </div>
                        {preview ? (
                          <PreviewBoundary key={activeExample.id}>
                            <Suspense
                              fallback={<p className="micro">加载交互预览…</p>}
                            >
                              <Playground
                                key={activeExample.id}
                                initialSource={activeExample.source}
                                dark={dark}
                              />
                            </Suspense>
                          </PreviewBoundary>
                        ) : (
                          <p className="micro">
                            {activeExample.origin}。预览使用固定版本 React
                            组件与相同 Lang；Swift
                            的表面、触控与流式就绪策略以本页说明为准。
                          </p>
                        )}
                      </>
                    ) : (
                      <p className="note">
                        这是由父级消费的记录或原生专属能力。请结合上方用途与参数使用；地图和图解可在下文交互查看。
                      </p>
                    )}
                  </article>
                </div>
              </section>

              <section className="section system-subsection" id="map-svg">
                <div className="chapter-heading">
                  <p className="eyebrow">2.5 / Components · Map & SVG</p>
                  <h3>地图与 SVG。</h3>
                  <p>
                    Map 与 SVG 已进入 SDK
                    默认注册库。沿用原有位置参数，客户端无需再维护一份同名渲染代码。
                  </p>
                </div>
                <div className="experiment-grid">
                  <div className="experiment">
                    <div className="experiment-head">
                      <h4>地图：地点与对象彼此对应</h4>
                      <span className="subtle-label">Map · MapPoint</span>
                    </div>
                    <Suspense
                      fallback={<div className="map-loading">加载地图…</div>}
                    >
                      <MapSpecimen />
                    </Suspense>
                    <details className="native-proof">
                      <summary>查看 Swift 原生呈现</summary>
                      <img
                        src="./native/map.png"
                        alt="Case 01 在 iOS 模拟器中的 MapKit 地图与地点卡"
                        loading="lazy"
                      />
                      <p className="micro">
                        迁入阶段的 iOS 模拟器实拍，SDK
                        b93023f6。保留真实案例标题与上下文，用于对照
                        MapKit；不代替 RC20 的完整验收。
                      </p>
                    </details>
                    <p>
                      标记与地点卡联动，展开地图后保留选择。SDK 的原生实现使用
                      MapKit；此处通过 OpenStreetMap
                      呈现同一组坐标，供观察选择关系。
                    </p>
                    <p className="micro">
                      原生地图要求 iOS 17／macOS 14。支持 WGS-84 与 GCJ-02
                      输入，后者转换后交给
                      MapKit。地点图不等于导航、路线或实时交通结果。
                    </p>
                  </div>
                  <div className="experiment">
                    <div className="experiment-head">
                      <h4>图解：先有比例，再有图形</h4>
                      <span className="subtle-label">SVG</span>
                    </div>
                    <SVGSpecimen />
                    <details className="native-proof">
                      <summary>查看 Swift 原生呈现</summary>
                      <img
                        src="./native/svg.png"
                        alt="Case 03 在 iOS 模拟器中通过 WKWebView 呈现的热泵原理图"
                        loading="lazy"
                      />
                      <p className="micro">
                        迁入阶段的 iOS 模拟器实拍，SDK b93023f6。图解来自 Case
                        03 的实际 SVG；不作为 RC20 渲染就绪反馈的证据。
                      </p>
                    </details>
                    <p>
                      viewBox
                      决定图形比例。内容需要完整、可解析，才能成为图解；远程资源、脚本与界面导航不属于图形内容。
                    </p>
                    <p className="micro">
                      原生采用隔离 WKWebView 与限制性
                      CSP，禁用脚本和外部引用；inline content 与 HTTPS src
                      二选一，内容上限 1MB。Web 示例仅运行内置图形。
                    </p>
                  </div>
                </div>
              </section>

              <HostIntegration />
            </div>
          </div>
        </SystemDesign>
        <section className="section" id="streaming">
          <div className="split streaming-heading">
            <div className="article-copy">
              <p className="eyebrow">03 / 流式渲染</p>
              <h2>控制重排，保留状态。</h2>
              <p>
                增量渲染（Incremental
                Rendering）是在分片到达后更新已有界面。难点是内容还没完整时，用户已经开始阅读和操作。
              </p>
              <p>
                RC20
                通过布局约束、组件标识和异步资源管理，减少更新中的重排、闪动与状态丢失。
              </p>
            </div>
            <div className="stream-lab specimen">
              <div className="specimen-top">
                <span>逐步观察呈现顺序</span>
                <button
                  className="quiet"
                  onClick={() => {
                    if (step >= 4) setStep(0);
                    setStreamPlay(!streamPlay);
                  }}
                >
                  {streamPlay ? <Pause size={14} /> : <Play size={14} />}{" "}
                  {streamPlay ? "暂停" : "播放"}
                </button>
              </div>
              <input
                type="range"
                min="0"
                max="4"
                step="1"
                value={step}
                aria-label="流式阶段"
                onChange={(e) => {
                  setStreamPlay(false);
                  setStep(+e.target.value);
                }}
              />
              <div className="stage-labels">
                {["结构", "引用", "文字", "资源", "完成"].map((s, i) => (
                  <button
                    key={s}
                    className={step === i ? "active" : ""}
                    onClick={() => {
                      setStreamPlay(false);
                      setStep(i);
                    }}
                  >
                    {s}
                  </button>
                ))}
              </div>
              <div className="stream-view">
                <p>已经呈现的段落持续保留。</p>
                <div className="stream-columns">
                  {[0, 1].map((i) => (
                    <div key={i}>
                      <div className="stream-image">
                        {step >= 3 ? (
                          <img
                            src={i ? palace : lake}
                            alt={i ? "德寿宫红墙" : "苏堤实景"}
                            loading="lazy"
                          />
                        ) : (
                          <div className="image-wait">
                            <Layers size={18} />
                          </div>
                        )}
                      </div>
                      <h4>{step >= 1 ? (i ? "德寿宫" : "苏堤") : "\u00a0"}</h4>
                      <p>
                        {step >= 2
                          ? i
                            ? "红墙与建筑，让时间可见。"
                            : "柳树、湖面和沿堤的石桥。"
                          : "\u00a0"}
                      </p>
                    </div>
                  ))}
                </div>
                {step >= 4 && (
                  <p className="stream-appended">
                    后续段落按源顺序追加，不重新播放前面的图片。
                  </p>
                )}
              </div>
              <p className="micro">流式过程示意 · Web</p>
            </div>
          </div>
          <div className="difficulty-list concise-mechanisms">
            {[
              {
                n: "01",
                title: "布局稳定性",
                term: "Layout Stability",
                text: "容器先分配宽度，文字在列内换行，图片不被后到的文字撑宽；关键布局参数未知时局部等待。",
              },
              {
                n: "02",
                title: "组件标识与状态保留",
                term: "Identity / State Preservation",
                text: "普通增量更新保留组件与状态；主动重播、切换程序或客户端重建状态时可能重置。",
              },
              {
                n: "03",
                title: "异步资源与数据管理",
                term: "Resource Lifecycle",
                text: "下载不决定列宽；图表只使用已确认数据；旧请求不能覆盖新回答。",
              },
            ].map((item) => (
              <div key={item.n}>
                <span>{item.n}</span>
                <div>
                  <h3>{item.title}</h3>
                  <p className="mechanism-term">{item.term}</p>
                  <p>{item.text}</p>
                </div>
              </div>
            ))}
          </div>
          <p className="micro">
            内容自然增高属于正常布局变化；目标是减少无谓重排与重建。
          </p>
          <ReadinessMatrix />
        </section>
        <DesignFrontiers />
        <section
          className="section references-appendix"
          id="sources"
          aria-label="参考资料"
        >
          <div className="article-reference">
            <div className="reading">
              <p className="eyebrow">参考 / 设计依据与版本</p>
              <h3>规范来源与验证范围</h3>
              <a
                href={`${github}/blob/${sdkBaseline.revision}/packages/swift-ui/README.md#整体设计`}
                target="_blank"
                rel="noreferrer"
              >
                RC20 整体设计与实现规则 <ArrowUpRight size={16} />
              </a>
              <a
                href={`${github}/blob/${sdkBaseline.revision}/packages/swift-ui/UI-DESIGN.md`}
                target="_blank"
                rel="noreferrer"
              >
                原生渲染与验证说明 <ArrowUpRight size={16} />
              </a>
              <a
                href={`${github}/blob/${sdkBaseline.revision}/packages/swift-ui/SDK-REFERENCE.zh-CN.md`}
                target="_blank"
                rel="noreferrer"
              >
                逐组件处理说明 <ArrowUpRight size={16} />
              </a>
              <a
                href={`${github}/tree/${sdkBaseline.revision}/examples/agent-cases`}
                target="_blank"
                rel="noreferrer"
              >
                核心用例的标准源码 <ArrowUpRight size={16} />
              </a>
              <a href="./generated/library.json" download>
                下载组件规范（Spec / Schema） <ArrowUpRight size={16} />
              </a>
              <a href="./generated/tokens.json" download>
                下载实际主题导出 <ArrowUpRight size={16} />
              </a>
            </div>
            <details className="traceability">
              <summary>发布基线、历史截图与验证范围</summary>
              <p>
                当前发布基线为{" "}
                <a href={sdkBaseline.url} target="_blank" rel="noreferrer">
                  {sdkBaseline.tag}
                </a>
                ，发布于 {sdkBaseline.publishedOn}，对应提交{" "}
                <code>{sdkBaseline.revision.slice(0, 8)}</code>
                。Map、MapPoint、SVG 已在默认注册库内，共 87
                项；客户端的生成库与接入状态，以它自己的依赖和实际导出为准。
              </p>
              <p>
                主题与组件定义来自本仓库 Swift 导出器，SDK 源内容指纹为{" "}
                <code>{reference.sourceFingerprint}</code>。固定上游目录为{" "}
                <code>{String(reference.upstreamRevision).slice(0, 12)}</code>
                。本页的架构图与流式时间轴属于交互示意，React 0.18.1 预览与
                SwiftUI 的原生度量、手势和平台行为分别验证。
              </p>
              <p>
                展开区保留的 iOS
                截图来自标明版本的历史迁入验证。当前记录覆盖代表性卡片、部分
                Case02
                区域、中英文预览和特定翻页／缩放动作；不扩展为全部设备、真机捏合或所有流式片段已经通过。01—07
                为核心用例，08 保留原稿，未纳入这轮视觉验收。站点不会调用 Agent
                或执行交易动作。
              </p>
            </details>
          </div>
        </section>
      </main>
      <footer>
        <a className="wordmark" href="#">
          OpenUI
        </a>
        <span>把复杂留给系统，把清晰留给阅读。</span>
        <a href={github} target="_blank" rel="noreferrer">
          Source <ArrowUpRight size={14} />
        </a>
      </footer>
    </div>
  );
}
function SVGSpecimen() {
  const [axis, setAxis] = useState("wide");
  const [labels, setLabels] = useState(true);
  const w = axis === "wide" ? 520 : 400;
  const markup = `<svg viewBox="0 0 ${w} 180" xmlns="http://www.w3.org/2000/svg"><rect x="12" y="34" width="132" height="112" rx="16" fill="none" stroke="currentColor" opacity=".3"/><path d="M164 90 H${w - 165} m-10 -7 10 7 -10 7" fill="none" stroke="currentColor"/><rect x="${w - 144}" y="34" width="132" height="112" rx="16" fill="none" stroke="currentColor" opacity=".3"/>${labels ? `<text x="78" y="87" text-anchor="middle" fill="currentColor" font-family="system-ui" font-size="16">分配空间</text><text x="${w - 78}" y="87" text-anchor="middle" fill="currentColor" font-family="system-ui" font-size="16">持续呈现</text><text x="78" y="114" text-anchor="middle" fill="currentColor" opacity=".6" font-family="system-ui" font-size="12">父级确定宽度</text><text x="${w - 78}" y="114" text-anchor="middle" fill="currentColor" opacity=".6" font-family="system-ui" font-size="12">资源替换像素</text>` : ""}</svg>`;
  return (
    <>
      <div
        className="svg-specimen"
        role="img"
        aria-label="父级分配空间后，资源在原位持续呈现"
        dangerouslySetInnerHTML={{ __html: markup }}
      />
      <div className="inline-controls">
        <label>
          viewBox{" "}
          <select
            aria-label="SVG 比例"
            value={axis}
            onChange={(e) => setAxis(e.target.value)}
          >
            <option value="wide">520 × 180</option>
            <option value="compact">400 × 180</option>
          </select>
        </label>
        <label>
          <input
            type="checkbox"
            checked={labels}
            onChange={(e) => setLabels(e.target.checked)}
          />
          显示说明
        </label>
      </div>
      <details>
        <summary>查看 SVG 源码</summary>
        <pre className="signature">{markup}</pre>
        <CopyButton text={markup} />
      </details>
    </>
  );
}
createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
