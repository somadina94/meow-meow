import { defineConfig } from "vite";
import react from "@vitejs/plugin-react-swc";
import path from "path";
import { componentTagger } from "lovable-tagger";
import { VitePWA } from "vite-plugin-pwa";

// https://vitejs.dev/config/
export default defineConfig(({ mode }) => ({
  server: {
    host: "::",
    port: 3030,
  },
  preview: {
    port: 3030,
    allowedHosts: ["www.meow-meow.co.in", ".meow-meow.co.in"],
  },
  build: {
    // Optimize chunk splitting for faster loading
    rollupOptions: {
      output: {
        manualChunks: {
          // Core React bundle - loaded first
          'react-vendor': ['react', 'react-dom', 'react-router-dom'],
          // UI components bundle
          'ui-vendor': [
            '@radix-ui/react-dialog', 
            '@radix-ui/react-tooltip', 
            '@radix-ui/react-popover',
            '@radix-ui/react-select',
            '@radix-ui/react-tabs',
            '@radix-ui/react-switch',
          ],
          // Query and data
          'query-vendor': ['@tanstack/react-query'],
          // Supabase client
          'supabase-vendor': ['@supabase/supabase-js'],
        },
      },
    },
    // Minimize chunk sizes
    chunkSizeWarningLimit: 500,
    // Enable minification with CSS minification
    minify: 'esbuild',
    cssMinify: true,
    // Target modern browsers for smaller output
    target: 'es2020',
    // Source maps off for production speed
    sourcemap: false,
    // Compress assets
    assetsInlineLimit: 4096,
  },
  // Enable dependency pre-bundling
  optimizeDeps: {
    include: [
      'react', 
      'react-dom', 
      'react-router-dom', 
      '@tanstack/react-query',
      '@supabase/supabase-js',
    ],
    // Exclude heavy optional deps from pre-bundling
    exclude: ['face-api.js', '@huggingface/transformers'],
  },
  plugins: [
    react(),
    mode === "development" && componentTagger(),
    VitePWA({
      strategies: "injectManifest",
      srcDir: "src",
      filename: "sw.ts",
      registerType: "autoUpdate",
      injectRegister: false,
      includeAssets: [
        "favicon.ico", 
        "icons/*.png", 
        "screenshots/*.png", 
        "splash/*.png",
        "robots.txt"
      ],
      manifest: false,
      injectManifest: {
        maximumFileSizeToCacheInBytes: 5 * 1024 * 1024,
        globPatterns: [
          "**/*.{js,css,html,ico,png,svg,woff,woff2,webp,jpg,jpeg,gif}"
        ],
      },
      devOptions: {
        enabled: false,
        type: "module",
        navigateFallback: "index.html",
      },
    }),
  ].filter(Boolean),
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
}));
