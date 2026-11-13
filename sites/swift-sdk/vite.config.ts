import { defineConfig } from "vite";
import { fileURLToPath } from "node:url";
const lucideImports = fileURLToPath(
  new URL(
    "./node_modules/lucide-react/dynamicIconImports.mjs",
    import.meta.url,
  ),
);
const codeBlockAdapter = fileURLToPath(
  new URL("./src/LazyCodeBlock.tsx", import.meta.url),
);
const codeBlockSource = fileURLToPath(
  new URL(
    "./node_modules/@openuidev/react-ui/src/components/CodeBlock/CodeBlock.tsx",
    import.meta.url,
  ),
);
const lazyViews = fileURLToPath(
  new URL("./src/LazyViews.tsx", import.meta.url),
);
const previewSources: Record<string, string> = {
  "@guide/chart-source": fileURLToPath(
    new URL(
      "./node_modules/@openuidev/react-ui/src/components/Charts/index.ts",
      import.meta.url,
    ),
  ),
  "@guide/date-picker-source": fileURLToPath(
    new URL(
      "./node_modules/@openuidev/react-ui/src/components/DatePicker/index.ts",
      import.meta.url,
    ),
  ),
  "@guide/editable-table-source": fileURLToPath(
    new URL(
      "./node_modules/@openuidev/react-ui/src/components/EditableTable/index.ts",
      import.meta.url,
    ),
  ),
};
export default defineConfig({
  base: "./",
  esbuild: { jsx: "automatic", jsxImportSource: "react" },
  // Optimize the complete source-entry preview and provider together. This
  // preserves their shared context and converts transitive CommonJS modules.
  optimizeDeps: {
    extensions: [".tsx", ".jsx"],
    esbuildOptions: {
      jsx: "automatic",
      jsxImportSource: "react",
      plugins: [
        {
          name: "openui-source-icon-map",
          setup(build) {
            build.onResolve(
              {
                filter:
                  /^\.\.\/\.\.\/components\/(Charts|DatePicker|EditableTable)$/,
              },
              () => ({ path: lazyViews }),
            );
            build.onResolve(
              { filter: /^@guide\/(chart|date-picker|editable-table)-source$/ },
              (args) => ({ path: previewSources[args.path] }),
            );
            build.onResolve(
              {
                filter: /^(\.\.\/\.\.\/components\/CodeBlock|\.\.\/CodeBlock)$/,
              },
              () => ({ path: codeBlockAdapter }),
            );
            build.onResolve({ filter: /^@guide\/code-block-source$/ }, () => ({
              path: codeBlockSource,
            }));
            build.onResolve(
              { filter: /^\.\/lucide\/lucideDynamicImports\.mjs$/ },
              () => ({ path: lucideImports }),
            );
          },
        },
      ],
    },
    include: [
      "react/jsx-runtime",
      "react/jsx-dev-runtime",
      "@openuidev/react-ui/genui-lib",
      "@openuidev/react-ui/ThemeProvider",
    ],
  },
  // The published GenUI bundle embeds its own ThemeContext. Use the package's
  // pinned source entries so chart components and the provider share one context.
  resolve: {
    alias: [
      { find: "../../components/Charts", replacement: lazyViews },
      { find: "../../components/DatePicker", replacement: lazyViews },
      { find: "../../components/EditableTable", replacement: lazyViews },
      ...Object.entries(previewSources).map(([find, replacement]) => ({
        find,
        replacement,
      })),
      { find: "../../components/CodeBlock", replacement: codeBlockAdapter },
      { find: "../CodeBlock", replacement: codeBlockAdapter },
      { find: "@guide/code-block-source", replacement: codeBlockSource },
      {
        find: "./lucide/lucideDynamicImports.mjs",
        replacement: lucideImports,
      },
      {
        find: "@openuidev/react-ui/genui-lib",
        replacement: fileURLToPath(
          new URL(
            "./node_modules/@openuidev/react-ui/src/genui-lib/openuiLibrary.tsx",
            import.meta.url,
          ),
        ),
      },
      {
        find: "@openuidev/react-ui/ThemeProvider",
        replacement: fileURLToPath(
          new URL(
            "./node_modules/@openuidev/react-ui/src/components/ThemeProvider/index.ts",
            import.meta.url,
          ),
        ),
      },
    ],
  },
  build: { target: "es2022", chunkSizeWarningLimit: 1800 },
});
