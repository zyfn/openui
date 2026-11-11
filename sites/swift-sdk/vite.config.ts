import { defineConfig } from "vite";
import { fileURLToPath } from "node:url";
export default defineConfig({
  base: "./",
  esbuild: { jsx: "automatic", jsxImportSource: "react" },
  // The published GenUI bundle embeds its own ThemeContext. Use the package's
  // pinned source entries so chart components and the provider share one context.
  resolve: {
    alias: [
      {
        find: "./lucide/lucideDynamicImports.mjs",
        replacement: fileURLToPath(
          new URL(
            "./node_modules/lucide-react/dynamicIconImports.mjs",
            import.meta.url,
          ),
        ),
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
