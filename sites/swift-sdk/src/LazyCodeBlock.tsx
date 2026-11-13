import { lazy, Suspense, type ComponentProps } from "react";
import type { CodeBlock as PublishedCodeBlock } from "@openuidev/react-ui/CodeBlock";

// Keep the shipped component and language support; load its highlighter only
// when a CodeBlock or Markdown code fence actually renders.
const Original = lazy(() =>
  import("@guide/code-block-source").then((module) => ({
    default: module.CodeBlock,
  })),
);
export function CodeBlock(props: ComponentProps<typeof PublishedCodeBlock>) {
  return (
    <Suspense fallback={<pre className="signature">{props.codeString}</pre>}>
      <Original {...props} />
    </Suspense>
  );
}
