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
import LiveExample from "./LiveExample";
import ButtonPreview from "./ButtonPreview";
import {
  WorkingPrinciple,
  SystemDesign,
  LayoutFoundations,
  ReadinessMatrix,
  CompositionPatterns,
  overview,
} from "./SystemArticle";
import DesignFrontiers from "./DesignFrontiers";
import { sdkBaseline } from "./baseline";
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
  const [example, setExample] = useState("");
  const [step, setStep] = useState(4);
  const [streamPlay, setStreamPlay] = useState(false);
  const [variant, setVariant] = useState("card");
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
          <p className="eyebrow">iOS · macOS</p>
          <h1>OpenUI Swift SDK</h1>
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
              <p className="note">两列共享宽度，图片保持占位尺寸。</p>
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
        <SystemDesign variant={variant} onVariantChange={setVariant}>
          <div className="system-content" id="reference">
            <div className="system-sections">
              <section className="section system-subsection" id="scale">
                <div className="split">
                  <div className="article-copy">
                    <p className="eyebrow">2.1</p>
                    <h3>字体与颜色</h3>
                    <p>按文字角色分配字号、字重与行高；字号与字色独立选择。</p>
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
                      desc: "标题与正文。",
                    },
                    {
                      key: "textNeutralSecondary",
                      name: "辅助文字",
                      desc: "规格、说明与图注。",
                    },
                    {
                      key: "borderDefault",
                      name: "边界",
                      desc: "对象与记录边界。",
                    },
                    {
                      key: "sunk",
                      name: "下沉表面",
                      desc: "浅底分组，无边框。",
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
                    Swift SDK 导出的 macOS 系统色；iOS 与 React
                    的选色顺序可能不同。
                  </small>
                </div>
              </section>

              <LayoutFoundations />
              <section className="section system-subsection" id="composition">
                <div className="chapter-heading">
                  <p className="eyebrow">2.3</p>
                  <h3>组件结构与状态</h3>
                  <p className="micro">Web 示意</p>
                </div>
                <div className="experiment-grid">
                  <div className="experiment">
                    <div className="experiment-head">
                      <h4>Card</h4>
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
                      <p>名称识别对象，短介绍提供判断依据。</p>
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
                          : "card：背景、16pt 内边距、边框。"}
                    </p>
                  </div>
                  <div className="experiment">
                    <ButtonPreview />
                  </div>
                </div>
                <div className="experiment-grid">
                  <div className="experiment">
                    <div className="experiment-head">
                      <h4>Form</h4>
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
                      <p className="support">可多选。</p>
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
                    <p className="micro" aria-live="polite">
                      {submitted ? `已选择：${chosen.join("、")}` : ""}
                    </p>
                  </div>
                  <div className="experiment">
                    <div className="experiment-head">
                      <h4>Callout</h4>
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
                    <p>普通说明使用中性色；成功、警告、错误使用状态色。</p>
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
                      IconText：图标与整组文字居中，默认使用中性色。
                    </p>
                  </div>
                </div>
              </section>

              <section className="section system-subsection" id="components">
                <div className="catalog-heading">
                  <div>
                    <p className="eyebrow">2.4</p>
                    <h3>组件 API</h3>
                    <p>87 个注册定义，签名与参数来自 Swift SDK 导出。</p>
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
                              }}
                            >
                              {currentExamples.map((e) => (
                                <option key={e.id} value={e.id}>
                                  {e.name}
                                </option>
                              ))}
                            </select>
                          </label>
                          <span className="subtle-label">交互预览 · React</span>
                        </div>
                        <LiveExample
                          id={activeExample.id}
                          source={activeExample.source}
                          dark={dark}
                        />
                      </>
                    ) : (
                      <p className="note">
                        数据节点由父组件处理；地图与 SVG 见 2.5。
                      </p>
                    )}
                    <div className="parameter-reference">
                      <h4>参数</h4>
                      <pre className="signature">{current.signature}</pre>
                      <p className="micro">{current.description}</p>
                      <CopyButton text={current.signature} />
                    </div>
                  </article>
                </div>
              </section>

              <section className="section system-subsection" id="map-svg">
                <div className="chapter-heading">
                  <p className="eyebrow">2.5</p>
                  <h3>Map 与 SVG</h3>
                  <p>Map、MapPoint、SVG 均已纳入 SDK 默认注册库。</p>
                </div>
                <div className="experiment-grid">
                  <div className="experiment">
                    <div className="experiment-head">
                      <h4>地点选择</h4>
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
                        iOS 模拟器 · SDK b93023f6 · Case 01（历史截图）
                      </p>
                    </details>
                    <p>
                      点位与卡片联动选择，展开后保留状态。原生使用
                      MapKit；此处为 OpenStreetMap 预览。
                    </p>
                    <p className="micro">
                      原生要求 iOS 17／macOS 14。支持 WGS-84 与
                      GCJ-02，后者转换后交给 MapKit；不提供导航与实时交通。
                    </p>
                  </div>
                  <div className="experiment">
                    <div className="experiment-head">
                      <h4>SVG</h4>
                      <span className="subtle-label">viewBox</span>
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
                        iOS 模拟器 · SDK b93023f6 · Case 03（历史截图）
                      </p>
                    </details>
                    <p>
                      viewBox 定义宽高比例。inline content 与 HTTPS src
                      二选一，内容上限 1MB。
                    </p>
                    <p className="micro">
                      原生使用隔离 WKWebView 与限制性
                      CSP，禁用脚本和外部引用。Web 示例仅使用内置图形。
                    </p>
                  </div>
                </div>
              </section>

              <CompositionPatterns />
            </div>
          </div>
        </SystemDesign>
        <section className="section" id="streaming">
          <div className="split streaming-heading">
            <div className="article-copy">
              <p className="eyebrow">03</p>
              <h2>流式渲染</h2>
              <p>
                分片到达时增量更新已有界面；布局、数据与资源分别按就绪条件呈现。
              </p>
            </div>
            <div className="stream-lab specimen">
              <div className="specimen-top">
                <span>呈现顺序</span>
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
                text: "父级分配宽度；关键布局参数未知时局部等待。",
              },
              {
                n: "02",
                title: "组件标识与状态保留",
                term: "Identity / State Preservation",
                text: "增量更新保留组件标识与状态；重播或替换程序可能重置。",
              },
              {
                n: "03",
                title: "异步资源",
                term: "Resource Lifecycle",
                text: "请求按消息隔离，过期结果不回写替换后的程序。",
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
              <p className="eyebrow">附录</p>
              <h3>参考资料</h3>
              <a
                href={`${github}/blob/${sdkBaseline.revision}/packages/swift-ui/README.md#整体设计`}
                target="_blank"
                rel="noreferrer"
              >
                整体设计 <ArrowUpRight size={16} />
              </a>
              <a
                href={`${github}/blob/${sdkBaseline.revision}/packages/swift-ui/UI-DESIGN.md`}
                target="_blank"
                rel="noreferrer"
              >
                渲染与验收 <ArrowUpRight size={16} />
              </a>
              <a
                href={`${github}/blob/${sdkBaseline.revision}/packages/swift-ui/SDK-REFERENCE.zh-CN.md`}
                target="_blank"
                rel="noreferrer"
              >
                组件规范 <ArrowUpRight size={16} />
              </a>
              <a
                href={`${github}/tree/${sdkBaseline.revision}/examples/agent-cases`}
                target="_blank"
                rel="noreferrer"
              >
                标准用例 <ArrowUpRight size={16} />
              </a>
              <a href="./generated/library.json" download>
                组件定义（Spec / Schema） <ArrowUpRight size={16} />
              </a>
              <a href="./generated/tokens.json" download>
                主题 Token <ArrowUpRight size={16} />
              </a>
            </div>
            <details className="traceability">
              <summary>版本与验证范围</summary>
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
                原生截图使用标注的历史版本，仅覆盖已有场景，未覆盖真机和全部流式分片。01—07
                为核心用例，08 未纳入本轮视觉验收。
              </p>
            </details>
          </div>
        </section>
      </main>
      <footer>
        <a className="wordmark" href="#">
          OpenUI
        </a>
        <span>iOS · macOS</span>
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
