import { lazy, Suspense, useEffect, useRef, useState } from "react";
import PreviewBoundary from "./PreviewBoundary";
const Playground = lazy(() => import("./Playground"));

export default function LiveExample({
  id,
  source,
  dark,
}: {
  id: string;
  source: string;
  dark: boolean;
}) {
  const container = useRef<HTMLDivElement>(null);
  const [visible, setVisible] = useState(false);
  useEffect(() => {
    const element = container.current;
    if (!element) return;
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          setVisible(true);
          observer.disconnect();
        }
      },
      { rootMargin: "240px" },
    );
    observer.observe(element);
    return () => observer.disconnect();
  }, []);
  return (
    <div ref={container} className="live-example">
      {visible ? (
        <PreviewBoundary key={id}>
          <Suspense
            fallback={<p className="micro preview-loading">加载组件预览…</p>}
          >
            <Playground key={id} initialSource={source} dark={dark} />
          </Suspense>
        </PreviewBoundary>
      ) : (
        <div className="preview-loading" aria-label="组件预览区域" />
      )}
    </div>
  );
}
