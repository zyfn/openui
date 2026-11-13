import { useEffect, useState } from "react";
import { ArrowUpRight } from "lucide-react";
import { sdkSource } from "./baseline";
const frontiers = [
  {
    id: "svg",
    kind: "待实现",
    title: "SVG 渲染状态反馈",
    current:
      "RC20 在文档可用后交给 WebKit，但尚未把 WebView 的加载状态接入完整反馈。",
    next: "连接文档校验、下载、渲染和失败状态，验证慢加载与消息切换时的局部反馈。",
    source: "Sources/OpenUISwiftUI/Components/NativeSVG.swift",
  },
  {
    id: "allocation",
    kind: "待验证",
    title: "流式布局的边界场景",
    current:
      "已知布局和集合可以提前分配空间。后续声明改变布局、文字自然增长时，仍可能发生必要重排。",
    next: "用不同分片顺序和内容长度回放，检查既有区域位移、视图重建及首次内容出现时间。",
    source: "Tests/OpenUISwiftUITests/StreamingLayoutContractTests.swift",
  },
  {
    id: "gestures",
    kind: "待验证",
    title: "图片预览与手势冲突",
    current:
      "已有缩放、拖动、翻页和关闭规则；模拟器检查不能覆盖真机捏合、极端比例及长说明。",
    next: "在真实输入下检查缩放、换图、返回的连续操作，确认手势响应和状态保留。",
    source: "Sources/OpenUISwiftUI/Components/NativeMediaPreview.swift",
  },
  {
    id: "handoff",
    kind: "待验证",
    title: "选择值到 Agent 的完整链路",
    current:
      "SDK 能生成字段值和动作上下文；客户端如何传递、Agent 是否使用当前条件，需要实际链路验证。",
    next: "从选择、提交一直核对到 Agent 的后续回答，并确认商品信息与操作入口对应同一对象。",
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
        <p className="eyebrow">04 / 当前限制</p>
        <h2>RC20 仍需完成与验证的工作。</h2>
        <p>SVG 渲染反馈尚未补齐，布局、手势和应用链路仍需补充验证。</p>
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
                  <b>下一步</b>
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
        <h3>图库末行：当前等宽，铺满方案暂缓</h3>
        <p>
          等宽便于比较，铺满会改变末行图片的尺寸与裁切。RC20
          保持等宽，末行铺满方案暂缓。
        </p>
        <GalleryAlternatives />
      </div>
    </section>
  );
}
