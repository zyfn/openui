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
  const [scale, setScale] = useState(100);
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
  const [article, setArticle] = useState(false);
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
    const name = decodeURIComponent(location.hash.replace("#component-", ""));
    if (reference.components.some((c) => c.name === name)) {
      setSelected(name);
      document.getElementById("components")?.scrollIntoView();
    }
  }, []);
  return (
    <div style={style}>
      <header className="nav">
        <a className="wordmark" href="#">
          OpenUI<span>Swift SDK</span>
        </a>
        <nav aria-label="文章导航">
          <a href="#language">语言与界面</a>
          <a href="#scale">视觉尺度</a>
          <a href="#components">组件</a>
          <a href="#streaming">生成的过程</a>
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
            界面在生成，
            <br className="mobile-break" />
            秩序先成立。
          </h1>
          <p className="lede">
            文字、图片、选择与数据，拥有各自的表达方式。
            <br className="desktop-break" />
            一套共享的语言，让不断到来的内容，成为清晰、稳定的原生界面。
          </p>
          <div className="hero-stage">
            <div className="garden-grid" aria-label="生成过程交互标本">
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
              <p className="micro">
                此处为布局原理交互标本；下方可运行真实 Lang 的 React
                预览。SwiftUI 的呈现与平台边界均在组件说明中列明。
              </p>
            </aside>
          </div>
        </section>
        <section className="section" id="scale">
          <div className="split">
            <div className="article-copy">
              <p className="eyebrow">01 / A SHARED MEASURE</p>
              <h2>看见尺度。</h2>
              <p>
                界面的层次，始于信息的职责。标题让人找到方向，正文承载回答，辅助文字交代条件。字号、字重、颜色与行距共同建立节奏，任何一项都不应独自承担全部区分。
              </p>
              <p>
                标题与正文共用主文字色；规格、图注与提示走辅助色。紧凑的介绍依然是主要内容，因此小字不必一律变浅。影响判断的条件，更不该因为字号小就失去分量。
              </p>
              <a
                className="text-link"
                href={`${github}/blob/main/packages/swift-ui/Sources/OpenUISwiftUI/Theme/TextStyles.swift`}
                target="_blank"
                rel="noreferrer"
              >
                阅读统一的文字映射 <ArrowUpRight size={15} />
              </a>
            </div>
            <div className="type-lab specimen">
              <div className="specimen-top">
                <span>系统字体 · 默认阅读尺度</span>
                <div className="segmented">
                  <button aria-pressed={!dark} onClick={() => setDark(false)}>
                    浅色
                  </button>
                  <button aria-pressed={dark} onClick={() => setDark(true)}>
                    深色
                  </button>
                </div>
              </div>
              <div
                className="type-lines"
                style={{ "--type-scale": scale / 100 } as React.CSSProperties}
              >
                {[
                  {
                    key: "textHeadingMd",
                    role: "display",
                    text: "一页内容，有自己的重心",
                  },
                  {
                    key: "textHeadingSm",
                    role: "section",
                    text: "章节让阅读有起落",
                  },
                  { key: "textHeadingXs", role: "title", text: "对象名称" },
                  {
                    key: "textBodyDefault",
                    role: "body",
                    text: "让正文安静地被读完。",
                  },
                  {
                    key: "textBodySm",
                    role: "detail",
                    text: "卡片里的短介绍，紧凑而清楚。",
                  },
                  {
                    key: "textBodyXs",
                    role: "caption",
                    text: "来源、图注，以及必要的补充。",
                  },
                ].map((r) => {
                  const f = tokens.fonts[r.key as keyof typeof tokens.fonts];
                  return (
                    <div className="type-line" key={r.key}>
                      <span
                        style={{
                          fontSize: (f.size * scale) / 100,
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
              <label className="range-label">
                观察文字尺度 <output>{scale}%</output>
                <input
                  aria-label="文字尺度"
                  type="range"
                  min="85"
                  max="140"
                  step="5"
                  value={scale}
                  onChange={(e) => setScale(+e.target.value)}
                />
              </label>
              <p className="micro">
                Web 用 px 映射默认 pt 比例；滑杆用于比较层次，不模拟 iOS Dynamic
                Type。
              </p>
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
                    navigator.clipboard.writeText(c[dark ? "dark" : "light"])
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
        <section className="section">
          <div className="chapter-heading">
            <p className="eyebrow">02 / BOUNDARIES AND RELATIONSHIPS</p>
            <h2>组件有边界，组合才自由。</h2>
            <p>
              容器管理空间，卡片的表面表达边界，表单收集并提交选择。透明 Card
              也可分配横排宽度，组件名不等于一定出现一个边框。
            </p>
          </div>
          <div className="principle-grid">
            <div>
              <h3>空间先归容器</h3>
              <p>
                Stack 决定方向、间距、换行与对齐。Card
                可以在横排中共享宽度，但一行图标和一句说明，不必被变成等宽网格。多列与自然宽度，服务于不同关系。
              </p>
            </div>
            <div>
              <h3>外观不替代语义</h3>
              <p>
                Card 的 card、sunk、clear 决定表面；clear 保留宽度分配能力。
                Form 表达填写与提交，原生默认已有任务面板，无需为同一层边界再套
                Card。
              </p>
            </div>
            <div>
              <h3>操作不靠体积抢眼</h3>
              <p>
                重要性、尺寸、宽度分开决定。按钮胶囊可以很轻，触控区域仍达到 iOS
                的 44pt；通栏是布局选择，不代表更高一级的动作。
              </p>
            </div>
          </div>
          <div className="experiment-grid">
            <div className="experiment">
              <div className="experiment-head">
                <h3>同一个对象，三种表面</h3>
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
                <h3>按钮的尺寸与触控区域</h3>
                <select
                  aria-label="按钮档位"
                  value={size}
                  onChange={(e) => setSize(e.target.value)}
                >
                  {["extra-small", "small", "medium", "large"].map((s) => (
                    <option key={s}>{s}</option>
                  ))}
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
                {{ "extra-small": 28, small: 32, medium: 40, large: 48 }[size]}
                pt；外层目标至少 44pt。small 常用于卡内入口，large
                留给独立主要操作。
              </p>
            </div>
          </div>
          <div className="experiment-grid">
            <div className="experiment">
              <div className="experiment-head">
                <h3>一项选择，一次明确提交</h3>
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
                <h3>说明，和真正的状态</h3>
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
                        error: "操作未完成，说明问题并提供可以继续的方向。",
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
                  <p className="support">输入入口是主角，导航保持可发现。</p>
                </div>
              </div>
              <p className="micro">
                IconText 的图标与整组标题和说明垂直居中；普通样式使用中性色。
              </p>
            </div>
          </div>
        </section>
        <section className="section" id="components">
          <div className="catalog-heading">
            <div>
              <p className="eyebrow">03 / THE COMPONENT REFERENCE</p>
              <h2>每一种表达，都有来处。</h2>
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
          <div className="category-strip" role="group" aria-label="组件类别">
            {["全部", ...new Set(reference.components.map((c) => c.group))].map(
              (g) => (
                <button
                  aria-pressed={group === g}
                  onClick={() => setGroup(g)}
                  key={g}
                >
                  {componentGroups[g] || g}
                </button>
              ),
            )}
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
            <article className="component-detail" id={`component-${selected}`}>
              <div className="detail-title">
                <h3>{current.name}</h3>
                <span className="subtle-label">{current.purpose}</span>
              </div>
              <p>{current.treatment}</p>
              <details>
                <summary>参数与位置顺序</summary>
                <pre className="signature">{current.signature}</pre>
                <p className="micro">{current.description}</p>
                <CopyButton text={current.signature} />
              </details>
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
                      {activeExample.origin}。预览使用固定版本 React 组件与相同
                      Lang；Swift 的表面、触控与流式就绪策略以本页说明为准。
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
        <section className="section" id="streaming">
          <div className="split streaming-heading">
            <div className="article-copy">
              <p className="eyebrow">04 / CONTINUITY UNDER CHANGE</p>
              <h2>
                后来的内容，
                <br />
                不该改写已经看见的世界。
              </h2>
              <p>
                一份完整的界面，很容易排得整齐。困难发生在它尚未完整的时候：容器参数还没到，引用指向后文，数值只写了一半，图片还在网络上。
              </p>
              <p>
                布局容器能规定分配规则，却不能预知所有未来内容。我们让结构、值、资源与交互各自判断就绪：保留已读前缀，等待真正影响布局的字段；宽度由父级分配，资源只更新自己的区域。
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
              <p className="micro">
                原理标本，非原生渲染回放。拖动时间轴可观察稳定的两列与图片区。
              </p>
            </div>
          </div>
          <div className="difficulty-list">
            {[
              {
                n: "01",
                title: "先确认结构，再分配空间",
                text: "已知列结构可以先确定宽度。未知布局参数不能靠后续文字反复修正；普通横排也不自动等同于等宽网格。图片、选择项和表格分别消费自己的容器规则。",
              },
              {
                n: "02",
                title: "保留身份，而不是整段重建",
                text: "引用解析、父级参数到达或请求刷新时，已完成内容保留同一呈现身份。图片请求与缓存属于整棵呈现树；后文到来不应让前文清空、闪动或重新下载。",
              },
              {
                n: "03",
                title: "等到数字成立，再画出关系",
                text: "柱形和折线可以使用已确认数据逐步呈现。饼图、环形和组成关系依赖完整总量，应等待所需数据。缺值不补零，也不画假图形暗示尚不存在的结论。",
              },
              {
                n: "04",
                title: "等待资源，不代替 Agent 讲述",
                text: "局部、延迟出现的加载动效提示等待。图片保留自己的框架；未知图形不占一整块虚构骨架。SDK 不自行宣称“正在整理内容”，也不把控件禁用涂成突兀的过渡按钮。",
              },
            ].map((d) => (
              <div key={d.n}>
                <span>{d.n}</span>
                <div>
                  <h3>{d.title}</h3>
                  <p>{d.text}</p>
                </div>
              </div>
            ))}
          </div>
        </section>
        <section className="section" id="map-svg">
          <div className="chapter-heading">
            <p className="eyebrow">05 / SPACE AND EXPLANATION</p>
            <h2>让位置可辨，让关系可见。</h2>
            <p>
              Map 与 SVG 已进入 SDK
              默认注册库。沿用原有位置参数，客户端无需再维护一份同名渲染代码。
            </p>
          </div>
          <div className="experiment-grid">
            <div className="experiment">
              <div className="experiment-head">
                <h3>地图：地点与对象彼此对应</h3>
                <span className="subtle-label">Map · MapPoint</span>
              </div>
              <Suspense
                fallback={<div className="map-loading">加载地图标本…</div>}
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
                  iOS 模拟器实拍，SDK
                  b93023f6。保留真实案例标题与上下文；原生地图使用 MapKit。
                </p>
              </details>
              <p>
                标记与地点卡联动，展开地图后保留选择。SDK 的原生实现使用
                MapKit；此处通过 OpenStreetMap 呈现同一组坐标，供观察选择关系。
              </p>
              <p className="micro">
                原生地图要求 iOS 17／macOS 14。支持 WGS-84 与 GCJ-02
                输入，后者转换后交给
                MapKit。地点图不等于导航、路线或实时交通结果。
              </p>
            </div>
            <div className="experiment">
              <div className="experiment-head">
                <h3>图解：先有比例，再有图形</h3>
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
                  iOS 模拟器实拍，SDK b93023f6。图解来自 Case 03 的实际
                  SVG；完整截图未经过改图。
                </p>
              </details>
              <p>
                viewBox
                决定图形比例。内容需要完整、可解析，才能成为图解；远程资源、脚本与界面导航不属于图形内容。
              </p>
              <p className="micro">
                原生采用隔离 WKWebView 与限制性 CSP，禁用脚本和外部引用；inline
                content 与 HTTPS src 二选一，内容上限 1MB。Web
                标本仅运行内置图形。
              </p>
            </div>
          </div>
        </section>
        <section className="section closing">
          <p className="eyebrow">
            06 / THE CONTRACT BETWEEN PEOPLE AND SYSTEMS
          </p>
          <h2>好的界面，也需要准确的内容。</h2>
          <div className="split">
            <div className="article-copy">
              <p>
                商品名称负责识别，短介绍解释价值，Tag
                提供短属性，价格说明交代票种与计价口径，按钮指向真实行为。信息不重复，推荐理由不挤占事实，界面才有可信的秩序。
              </p>
              <p>
                SDK 提供表单值、动作及上下文；宿主决定如何发给 Agent
                或执行业务。模型使用的规范来自实际注册库，示例通过标准
                PromptOptions.examples
                加入。界面语言不承诺库存，示例价格也不代表一次新的查询。
              </p>
            </div>
            <div className="reading">
              <h3>继续阅读</h3>
              <a
                href={`${github}/blob/main/packages/swift-ui/SDK-REFERENCE.zh-CN.md`}
                target="_blank"
                rel="noreferrer"
              >
                完整设计与组件说明 <ArrowUpRight size={18} />
              </a>
              <a
                href={`${github}/tree/main/examples/agent-cases`}
                target="_blank"
                rel="noreferrer"
              >
                七个核心用例与标准源码 <ArrowUpRight size={18} />
              </a>
              <a href="./generated/library.json" download>
                下载当前组件契约 <ArrowUpRight size={18} />
              </a>
              <a href="./generated/tokens.json" download>
                下载实际主题导出 <ArrowUpRight size={18} />
              </a>
            </div>
          </div>
          <details className="traceability">
            <summary>版本、来源与验证边界</summary>
            <p>
              视觉基准 RC18。Map、MapPoint、SVG 集成位于当前 main；页面不把 main
              改动称为已发布 RC。87 个组件定义和主题值由本仓库 Swift
              导出器产生，源代码状态见交付记录。
            </p>
            <p>
              固定上游目录：
              <code>{String(reference.upstreamRevision).slice(0, 12)}</code>
              。网页使用 React 0.18.1 组件预览与 Web
              原理标本；原生字体度量、MapKit、系统控件、动画与触控行为需要在
              Swift 宿主中验证。
            </p>
            <p>
              01—07 为核心用例；08
              保留原稿，未纳入这轮视觉验收。站点不会自动调用 Agent
              或执行示例中的交易动作。
            </p>
          </details>
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
