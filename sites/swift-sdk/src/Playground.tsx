import React, { useState, useCallback, useMemo } from "react";
import { ThemeContext, useTheme } from "@openuidev/react-ui/ThemeProvider";
import tokens from "../public/generated/tokens.json";
import { Renderer } from "@openuidev/react-lang";
import { previewLibrary } from "./preview-library";
import "@openuidev/react-ui/index.css";
import "@openuidev/react-ui/defaults.css";

export default function Playground({
  initialSource,
  dark = false,
}: {
  initialSource: string;
  dark?: boolean;
}) {
  const inheritedTheme = useTheme();
  const chartTheme = useMemo(
    () => ({
      ...inheritedTheme,
      mode: dark ? ("dark" as const) : ("light" as const),
      theme: {
        ...inheritedTheme.theme,
        defaultChartPalette: tokens.chartPalette.map(
          (c) => c[dark ? "dark" : "light"],
        ),
      },
    }),
    [inheritedTheme, dark],
  );
  const [draft, setDraft] = useState(initialSource);
  const [source, setSource] = useState(initialSource);
  const [errors, setErrors] = useState<string[]>([]);
  const [event, setEvent] = useState<unknown>(null);
  const [revision, setRevision] = useState(0);
  const onErrors = useCallback(
    (items: any[]) => setErrors(items.map((e) => e.message)),
    [],
  );
  return (
    <div className="playground">
      <p className="micro">
        实际 Lang · React 0.18.1 预览。地图与图解使用标明边界的 Web
        适配器，原生行为见下方说明。动作仅显示事件，不跳转、不调用交易。
      </p>
      <div className="react-preview" key={revision}>
        <ThemeContext.Provider value={chartTheme}>
          <Renderer
            response={source}
            library={previewLibrary}
            onError={onErrors}
            onAction={setEvent}
          />
        </ThemeContext.Provider>
      </div>
      <details className="example-source">
        <summary>编辑 OpenUI Lang</summary>
        <label className="source-label">
          编辑源码
          <textarea
            spellCheck={false}
            aria-label="Lang 源码"
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
          />
        </label>
        <div className="preview-actions">
          <button
            className="pill primary"
            onClick={() => {
              setSource(draft);
              setRevision((r) => r + 1);
              setEvent(null);
            }}
          >
            运行这段 Lang
          </button>
          <button
            className="quiet"
            onClick={() => {
              setDraft(initialSource);
              setSource(initialSource);
              setRevision((r) => r + 1);
            }}
          >
            恢复原稿
          </button>
        </div>
      </details>
      {errors.length > 0 && (
        <details>
          <summary>{errors.length} 条预览诊断</summary>
          <ul className="diagnostics">
            {errors.map((e, i) => (
              <li key={i}>{e}</li>
            ))}
          </ul>
        </details>
      )}
      {event != null && (
        <details open>
          <summary>动作事件</summary>
          <pre className="payload">{JSON.stringify(event, null, 2)}</pre>
        </details>
      )}
    </div>
  );
}
