import { useEffect, useState } from "react";
import { ArrowUpRight } from "lucide-react";
import { sdkBaseline, sdkSource } from "./baseline";

const learned = [
  {
    title: "按钮尺寸反复失衡",
    symptom: "同一个 small 放进操作组后，胶囊底色被整行高度撑大。",
    rule: "绘制表面、字号与内边距遵守尺寸档位；同行对齐与最低触控范围作用于外层目标。优先级和通栏另由 variant 与布局决定。",
    path: "Sources/OpenUISwiftUI/Components/NativeControlStyle.swift",
  },
  {
    title: "图文列随内容伸缩",
    symptom: "图片被后来的文字撑宽，多列图文出现不一致的缩进与宽度。",
    rule: "由父级和阅读宽度分配空间，文字在列内增长。clear Card 去掉表面与内边距，保留布局作用；集合与普通横排各自遵守约束。",
    path: "Tests/OpenUISwiftUITests/StreamingLayoutContractTests.swift",
  },
  {
    title: "前文被清空或重新播放",
    symptom: "后面的引用或最终快照到达，已经看见的内容再次挂载。",
    rule: "追加、相同终态与主动 reset 分开；用稳定身份、同一呈现树和资源作用域维持连续性，隔离旧请求回调。",
    path: "Tests/OpenUISwiftUITests/StreamingPresentationTests.swift",
  },
  {
    title: "图表等待与数据表达混在一起",
    symptom: "等待时画出假网格或假比例，或者所有图形都等到同一时刻出现。",
    rule: "按数据依赖分别提交真实值。趋势可以逐步成立，比例需要可确认的总量；首次等待使用局部反馈，刷新已有图保留可用内容。",
    path: "Sources/OpenUISwiftUI/Components/NativeChartStreaming.swift",
  },
  {
    title: "图片预览抢走原有动作",
    symptom: "浏览、选中、点击整卡、放大拖动与翻页竞争同一手势。",
    rule: "信息图预览、动作卡与选择控件各有入口；预览区分正常缩放与放大拖动，替代操作和无障碍路径保留。",
    path: "Sources/OpenUISwiftUI/Components/NativeMediaPreview.swift",
  },
];
const frontiers = [
  {
    id: "svg",
    kind: "待实现",
    title: "SVG 的内容就绪，还要接上渲染就绪",
    context:
      "我们希望 loading 在图形真正出现前提供连续反馈。RC20 已经能校验文档、约束内容并在隔离 WebKit 中呈现；现有分支在文档可用后就交给 WebView，尚未把后续加载状态接成完整反馈。",
    difficulty:
      "文档完整、远程请求结束、WebView 加载与可见图形出现处于不同阶段。简单地在网络结束时关掉 spinner，会留下反馈空档；把整个页面藏到结束又会阻挡已有内容。",
    next: "需要补齐这段状态衔接，并分别验证慢加载、无效内容、失败与消息切换。反馈只属于图解区域，既有正文与资源不应被重置。该工作未纳入 RC20。",
    source: "Sources/OpenUISwiftUI/Components/NativeSVG.swift",
    evidence: "UI-DESIGN.md",
  },
  {
    id: "allocation",
    kind: "技术权衡",
    title: "未知内容的布局，要在及时呈现与稳定之间取舍",
    context:
      "图片随着文字增长、首张卡先占满再缩小，是我们反复处理过的现象。RC20 已用阅读宽度、集合形状和布局就绪规则稳定已知关系；未知横排贡献项到达前，媒体局部等待。",
    difficulty:
      "后面的声明可能真正改变方向、换行或可用空间，文字高度也会自然增长。布局容器能约束分配方法，无法预知未来输入。全量等待与立刻猜出一整页，都会付出体验代价。",
    next: "继续用不同分片大小、源码顺序和增长内容做受控回放，观察首块可读内容出现时间、既有区域位移与视图重建。已有单项回归不等于任意输入零跳动；这些观察需要逐步形成可比较的证据。",
    source: "Tests/OpenUISwiftUITests/StreamingLayoutContractTests.swift",
    evidence:
      "UI-DESIGN.md#4-streaming-preserves-known-content-not-an-invented-finished-page",
  },
  {
    id: "gallery",
    kind: "待决策",
    title: "图库末行，选择铺满还是保持同一把尺子",
    context:
      "横向内容换行后是否应铺满，不能从“允许换行”直接推出。RC20 的 ImageGallery 末行保持等宽图项；末行填满方案已暂停，没有作为新默认落地。",
    difficulty:
      "铺满可减少尾部空白，同时会改变最后几张图的宽度和裁切；等宽更方便比较，但保留剩余空间。这个决定会影响媒体角色、对象一致性与流式集合变化，不能只修一张截图。",
    next: "需要先确定图库承担比较还是浏览的任务，再比较不同数量、长宽比和逐项到达的结果。下方是两种设计备选的几何示意，铺满方案仍属讨论。",
    source: "UI-DESIGN.md#3-keep-layout-and-interaction-predictable",
    evidence: "README.md#5-图片图库与预览各有自己的空间规则",
  },
  {
    id: "gestures",
    kind: "待验证",
    title: "缩放、翻页与阅读滚动，要在真实输入中合作",
    context:
      "RC20 已实现翻页、缩放与图片说明，并将放大拖动和正常比例翻页分开。我们也遇到过单图预览影响外层滚动、图形检查浮层被短绘图区和图例遮住的问题；这些已形成各自处理规则。",
    difficulty:
      "手势竞争与内容遮挡都可能只在特定状态、比例或平台出现。当前普通字号模拟器证据覆盖了代表性动作，不能替代真机捏合、极端图片比例、长说明和不同滚动路径的专项检查。",
    next: "保留实际 SDK、宿主与源码身份，用相同输入逐步检查缩放—拖动—换图—关闭，确认状态和阅读位置。图表浮层则需要覆盖短图、长提示与图例位置；不把编译通过当作交互验收。",
    source: "Sources/OpenUISwiftUI/Components/NativeMediaPreview.swift",
    evidence:
      "UI-DESIGN.md#5-verify-each-responsibility-with-the-right-evidence",
  },
  {
    id: "handoff",
    kind: "端到端",
    title: "让稳定的 SDK 规则，走到真实 Agent 的下一步",
    context:
      "表单选择丢失、商品信息重复、价格口径混杂、计划中缺少必要交通，都曾出现在实际案例里。SDK 已提供字段状态、对象上下文和消息封装；组合指引与当前工具结果仍由 Agent 和宿主负责。",
    difficulty:
      "宿主主动重建 State 可能打断 SDK 内的连续性；事件有 payload 不代表 Agent 已收到它；一个正确排版的商品也可能承载过时价格或不对应的入口。各层需要在同一条真实链路上对齐。",
    next: "以客户端实际依赖与导出为准，从选择、提交、消息回传一直核对到 Agent 使用当前条件。把工具字段、对象身份与下一步行为对应起来。RC20 的发布只确认发行基线，客户端接入和业务效果另行验证。",
    source: "README.md#6-交互围绕一个明确任务",
    evidence:
      "UI-DESIGN.md#5-verify-each-responsibility-with-the-right-evidence",
  },
];
function GalleryAlternatives() {
  return (
    <div className="gallery-alternatives" aria-label="图库末行两种设计备选">
      {[false, true].map((fill) => (
        <figure key={String(fill)}>
          <svg
            viewBox="0 0 300 126"
            role="img"
            aria-label={
              fill ? "备选方案，末行两图平分宽度" : "RC20 当前，末行保持等宽"
            }
          >
            {[0, 1, 2, 3, 4].map((n) => {
              const last = n >= 3;
              const width = fill && last ? 145 : 94;
              const x = last ? (n - 3) * (width + 9) : n * 103;
              const y = last ? 67 : 5;
              return (
                <g key={n}>
                  <rect x={x + 1} y={y} width={width} height="53" rx="6" />
                  <text x={x + 1 + width / 2} y={y + 31} textAnchor="middle">
                    {n + 1}
                  </text>
                </g>
              );
            })}
          </svg>
          <figcaption>
            <b>{fill ? "铺满末行" : "保持等宽"}</b>
            <span>{fill ? "设计备选 · 尚未落地" : "RC20 当前规则"}</span>
          </figcaption>
        </figure>
      ))}
    </div>
  );
}
export default function DesignFrontiers() {
  const [kind, setKind] = useState("全部");
  const [anchor, setAnchor] = useState<string | null>(null);
  useEffect(() => {
    const reveal = () => {
      const target = frontiers.find(
        (item) => location.hash === `#frontier-${item.id}`,
      );
      if (target) {
        setKind("全部");
        setAnchor(target.id);
      }
    };
    window.addEventListener("hashchange", reveal);
    reveal();
    return () => window.removeEventListener("hashchange", reveal);
  }, []);
  useEffect(() => {
    if (!anchor || kind !== "全部") return;
    const target = document.getElementById(
      `frontier-${anchor}`,
    ) as HTMLDetailsElement | null;
    if (target) {
      target.open = true;
      target.scrollIntoView({ block: "start" });
    }
    setAnchor(null);
  }, [anchor, kind]);
  const visible = frontiers.filter(
    (item) => kind === "全部" || item.kind === kind,
  );
  return (
    <section className="section design-frontiers" id="frontiers">
      <div className="chapter-heading">
        <p className="eyebrow">09 / THE REMAINING QUESTIONS</p>
        <h2>下一步，要让哪些事情更确定。</h2>
        <p>
          按钮变大、图文收缩、前文闪动与手势竞争，让我们看见了不同层面之间的相互影响。反复调整应当沉淀为共同规则，也应留下清楚的未决问题。以下以{" "}
          {sdkBaseline.label}{" "}
          为界，区分已经建立的处理、尚未完成的能力和仍需补充的证据。
        </p>
      </div>
      <details className="learned-rules">
        <summary>从反复调整中，已经收敛了哪些规则</summary>
        <div>
          {learned.map((item) => (
            <article key={item.title}>
              <h3>{item.title}</h3>
              <p>{item.symptom}</p>
              <p>{item.rule}</p>
              <a
                className="text-link"
                href={sdkSource(item.path)}
                target="_blank"
                rel="noreferrer"
              >
                对应实现 / 回归证据 <ArrowUpRight size={13} />
              </a>
            </article>
          ))}
        </div>
      </details>
      <div
        className="frontier-filters"
        role="group"
        aria-label="按问题性质筛选"
      >
        {["全部", ...frontiers.map((item) => item.kind)].map((k) => (
          <button key={k} aria-pressed={kind === k} onClick={() => setKind(k)}>
            {k}
          </button>
        ))}
      </div>
      <div className="frontier-list">
        {visible.map((item) => (
          <details
            key={item.id}
            id={`frontier-${item.id}`}
            className="frontier"
            open={kind !== "全部" || item.id === "svg"}
          >
            <summary>
              <span className="frontier-index">
                {String(frontiers.indexOf(item) + 1).padStart(2, "0")}
              </span>
              <span className="frontier-heading">
                <span className="frontier-kind">{item.kind}</span>
                <strong>{item.title}</strong>
              </span>
              <span className="frontier-disclosure" aria-hidden="true">
                +
              </span>
            </summary>
            <div className="frontier-body">
              <p>{item.context}</p>
              <p>{item.difficulty}</p>
              {item.id === "gallery" && <GalleryAlternatives />}
              <p className="frontier-next">
                <b>下一步如何判断</b>
                {item.next}
              </p>
              <div className="frontier-sources">
                <a
                  href={sdkSource(item.source)}
                  target="_blank"
                  rel="noreferrer"
                >
                  RC20 对应来源 <ArrowUpRight size={13} />
                </a>
                <a
                  href={sdkSource(item.evidence)}
                  target="_blank"
                  rel="noreferrer"
                >
                  设计与验证边界 <ArrowUpRight size={13} />
                </a>
              </div>
            </div>
          </details>
        ))}
      </div>
      <p className="frontier-ending">
        继续演进时，先明确这次改变的是语言契约、视觉角色、布局算法、呈现生命周期，还是宿主行为；再用相应层面的证据判断效果。这样，每一次改动才能成为系统能力的积累。
      </p>
    </section>
  );
}
