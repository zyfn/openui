import { useEffect, useState } from "react";
import { ArrowUpRight } from "lucide-react";
import { sdkSource } from "./baseline";
const frontiers = [
  {
    id: "svg",
    kind: "待实现",
    title: "SVG 渲染反馈",
    current: "文档交给 WebKit 后，尚未接入完整的渲染状态反馈。",
    next: "补齐加载、完成与失败状态，验证慢资源和消息切换。",
    source: "Sources/OpenUISwiftUI/Components/NativeSVG.swift",
  },
  {
    id: "allocation",
    kind: "待验证",
    title: "动态布局",
    current: "后续声明与文字增高仍会触发必要重排。",
    next: "回放不同分片顺序和长文本，测量内容位移、视图重建与首次呈现时间。",
    source: "Tests/OpenUISwiftUITests/StreamingLayoutContractTests.swift",
  },
  {
    id: "gestures",
    kind: "待验证",
    title: "图片手势",
    current: "已有模拟器验证；真机捏合、极端比例和长图注待测。",
    next: "真机验证缩放、换图、关闭及手势冲突。",
    source: "Sources/OpenUISwiftUI/Components/NativeMediaPreview.swift",
  },
  {
    id: "handoff",
    kind: "待验证",
    title: "交互回传",
    current: "SDK 已生成事件；客户端传递与 Agent 使用当前选择的链路待验。",
    next: "核对选择、事件、后续回答中的条件与对象是否一致。",
    source: "README.md#6-交互围绕一个明确任务",
  },
];
function GalleryAlternatives() {
  return (
    <div className="gallery-alternatives" aria-label="图库末行设计备选">
      {[false, true].map((fill) => (
        <figure key={String(fill)}>
          <svg
            viewBox="0 0 300 126"
            role="img"
            aria-label={fill ? "备选：末行两图平分宽度" : "RC20：末行保持等宽"}
          >
            {[0, 1, 2, 3, 4].map((n) => {
              const last = n >= 3,
                width = fill && last ? 145 : 94,
                x = last ? (n - 3) * (width + 9) : n * 103,
                y = last ? 67 : 5;
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
            <span>{fill ? "备选方案 · 暂缓" : "RC20 当前规则"}</span>
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
    const target = document.getElementById(`frontier-${anchor}`);
    if (target) {
      target.scrollIntoView({ block: "start" });
    }
    setAnchor(null);
  }, [anchor, kind]);
  return (
    <section className="section design-frontiers" id="frontiers">
      <div className="chapter-heading">
        <p className="eyebrow">04</p>
        <h2>当前限制</h2>
      </div>
      <div className="frontier-filters" role="group" aria-label="按状态筛选">
        {["全部", "待实现", "待验证"].map((k) => (
          <button key={k} aria-pressed={kind === k} onClick={() => setKind(k)}>
            {k}
          </button>
        ))}
      </div>
      <div className="frontier-list">
        {frontiers
          .filter((item) => kind === "全部" || item.kind === kind)
          .map((item) => (
            <article
              key={item.id}
              id={`frontier-${item.id}`}
              className="frontier"
            >
              <div className="frontier-title">
                <span className="frontier-index">
                  {String(frontiers.indexOf(item) + 1).padStart(2, "0")}
                </span>
                <div className="frontier-heading">
                  <span className="frontier-kind">{item.kind}</span>
                  <h3>{item.title}</h3>
                </div>
              </div>
              <div className="frontier-body">
                <p>{item.current}</p>
                <p className="frontier-next">
                  <b>待办</b>
                  {item.next}
                </p>
                <a
                  className="text-link"
                  href={sdkSource(item.source)}
                  target="_blank"
                  rel="noreferrer"
                >
                  实现依据 <ArrowUpRight size={13} />
                </a>
              </div>
            </article>
          ))}
      </div>
      <div className="gallery-decision">
        <h3>图库末行</h3>
        <p>RC20 保持等宽；铺满会改变尺寸与裁切，方案暂缓。</p>
        <GalleryAlternatives />
      </div>
    </section>
  );
}
