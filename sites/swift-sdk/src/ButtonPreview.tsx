import { useEffect, useRef, useState } from "react";
import { LoaderCircle } from "lucide-react";

type Phase = "ready" | "performing" | "disabled";
export default function ButtonPreview() {
  const [size, setSize] = useState("small");
  const [filled, setFilled] = useState(false);
  const [target, setTarget] = useState(false);
  const [phase, setPhase] = useState<Phase>("ready");
  const [progressVisible, setProgressVisible] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(
    () => () => {
      if (timer.current) clearTimeout(timer.current);
    },
    [],
  );
  useEffect(() => {
    setProgressVisible(false);
    if (phase !== "performing") return;
    // RC20 OpenUIMotion.loadingIndicatorDelay; progress overlays the retained label.
    const delay = setTimeout(() => setProgressVisible(true), 200);
    return () => clearTimeout(delay);
  }, [phase]);
  const choosePhase = (value: Phase) => {
    if (timer.current) clearTimeout(timer.current);
    timer.current = null;
    setPhase(value);
  };
  const activate = () => {
    choosePhase("performing");
    timer.current = setTimeout(() => {
      setPhase("ready");
      timer.current = null;
    }, 1200);
  };
  return (
    <>
      <div className="experiment-head">
        <h4>按钮尺寸、状态与触控区域</h4>
        <select
          aria-label="按钮档位"
          value={size}
          onChange={(event) => setSize(event.target.value)}
        >
          {["extra-small", "small", "medium", "large"].map((value) => (
            <option key={value}>{value}</option>
          ))}
        </select>
      </div>
      <div
        className="segmented button-phases"
        role="group"
        aria-label="按钮状态"
      >
        {(
          [
            { value: "ready", label: "可用" },
            { value: "performing", label: "执行中" },
            { value: "disabled", label: "禁用" },
          ] as const
        ).map((item) => (
          <button
            key={item.value}
            aria-pressed={phase === item.value}
            onClick={() => choosePhase(item.value)}
          >
            {item.label}
          </button>
        ))}
      </div>
      <div className={`button-stage phase-${phase}`}>
        <div
          className={target ? "touch-target" : ""}
          style={{ width: filled ? "100%" : undefined }}
        >
          <button
            className={`sdk-button ${size} action-example`}
            style={{ width: filled ? "100%" : undefined }}
            disabled={phase !== "ready"}
            aria-busy={phase === "performing"}
            aria-label="继续"
            onClick={activate}
          >
            <span style={{ opacity: progressVisible ? 0 : 1 }}>继续</span>
            {progressVisible && (
              <span className="button-progress" aria-hidden="true">
                <LoaderCircle size={14} className="loading-spin" />
              </span>
            )}
          </button>
        </div>
      </div>
      <div className="inline-controls">
        <label>
          <input
            type="checkbox"
            checked={filled}
            onChange={(event) => setFilled(event.target.checked)}
          />
          纵排铺满
        </label>
        <label>
          <input
            type="checkbox"
            checked={target}
            onChange={(event) => setTarget(event.target.checked)}
          />
          显示触控范围
        </label>
      </div>
      <p className="micro">
        可见最小高度{" "}
        {{ "extra-small": 28, small: 32, medium: 40, large: 48 }[size]}
        pt；iOS 触控目标至少 44pt。执行中保持原外观，禁用状态单独呈现。
      </p>
    </>
  );
}
