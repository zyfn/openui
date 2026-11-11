import React from "react";
export default class PreviewBoundary extends React.Component<
  { children: React.ReactNode },
  { error: boolean }
> {
  state = { error: false };
  static getDerivedStateFromError() {
    return { error: true };
  }
  render() {
    return this.state.error ? (
      <div className="note" role="status">
        交互预览暂时无法加载。文章与组件契约仍可阅读；刷新页面可重新加载预览。
      </div>
    ) : (
      this.props.children
    );
  }
}
