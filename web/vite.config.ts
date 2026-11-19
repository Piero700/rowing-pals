/// <reference types="vitest/config" />
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  base: "/go/",
  // Built into dist/go so the files sit where /go/ is served: Netlify publishes dist, and the website can sit
  // beside it in dist (npm run build:site).
  build: { outDir: "dist/go", emptyOutDir: true },
  plugins: [react()],
  test: {
    environment: "jsdom",
    setupFiles: ["./src/test-setup.ts"],
    globals: true,
  },
});
