import { createRoot } from "react-dom/client";

// Inline critical CSS synchronously for fastest FCP
import "./index.css";

const APP_MOUNTED_ATTR = "data-app-mounted";

// Self-heal for stale cached bundles (wrong MIME / ChunkLoadError after deploy).
// One-shot: set a session flag so we never reload-loop.
const STALE_BUNDLE_FLAG = "__stale_bundle_recovered";
function isStaleBundleError(message: string): boolean {
  if (!message) return false;
  const m = message.toLowerCase();
  return (
    m.includes("chunkloaderror") ||
    m.includes("failed to fetch dynamically imported module") ||
    m.includes("error loading dynamically imported module") ||
    m.includes("expected a javascript") ||
    m.includes("application/octet-stream") ||
    m.includes("'text/html' is not a valid javascript") ||
    // Mixed old/new deployed chunks can throw runtime ReferenceErrors instead
    // of ChunkLoadError. Recover once by clearing SW/cache and reloading.
    m.includes("useauthready is not defined")
  );
}
async function recoverFromStaleBundle() {
  try {
    if (sessionStorage.getItem(STALE_BUNDLE_FLAG)) return false;
    sessionStorage.setItem(STALE_BUNDLE_FLAG, "1");
    if ("serviceWorker" in navigator) {
      const regs = await navigator.serviceWorker.getRegistrations();
      await Promise.all(regs.map((r) => r.unregister()));
    }
    if ("caches" in window) {
      const keys = await caches.keys();
      await Promise.all(keys.map((k) => caches.delete(k)));
    }
    location.reload();
    return true;
  } catch {
    return false;
  }
}

// Global error handler — catches anything that slips through React ErrorBoundary
window.addEventListener("error", (event) => {
  const msg = event.error?.message || event.message || "";
  if (isStaleBundleError(msg)) { void recoverFromStaleBundle(); return; }
  console.error("[FATAL] Uncaught error:", event.error);
  showFatalError(msg || "Unknown error");
});

window.addEventListener("unhandledrejection", (event) => {
  const msg = event.reason instanceof Error ? event.reason.message : String(event.reason || "");
  if (isStaleBundleError(msg)) { void recoverFromStaleBundle(); return; }
  console.error("[FATAL] Unhandled rejection:", event.reason);
  showFatalError(msg || "Startup failed");
});

function markAppMounted() {
  document.documentElement.setAttribute(APP_MOUNTED_ATTR, "true");
}

function showFatalError(message: string) {
  const root = document.getElementById("root");
  if (!root || document.documentElement.getAttribute(APP_MOUNTED_ATTR) === "true") return;

  root.innerHTML = `
    <div style="display:flex;align-items:center;justify-content:center;min-height:100vh;background:#0a0d14;color:#fff;font-family:sans-serif;padding:20px;text-align:center">
      <div>
        <h1 style="font-size:24px;margin-bottom:12px">Something went wrong</h1>
        <p style="color:#888;margin-bottom:20px;font-size:14px">${message}</p>
        <button onclick="(async()=>{if('serviceWorker' in navigator){const r=await navigator.serviceWorker.getRegistrations();await Promise.all(r.map(r=>r.unregister()))}if('caches' in window){const k=await caches.keys();await Promise.all(k.map(k=>caches.delete(k)))}location.reload()})()" style="padding:10px 24px;background:#0ea5e9;color:#fff;border:none;border-radius:8px;cursor:pointer;font-size:14px">
          Clear Cache & Reload
        </button>
      </div>
    </div>
  `;
}

async function cleanupPreviewServiceWorkers() {
  try {
    const host = window.location.hostname;
    const isPreviewHost = host.includes("id-preview--") || host.includes("lovableproject.com");
    const isInIframe = (() => {
      try { return window.self !== window.top; }
      catch { return true; }
    })();
    if (!isPreviewHost && !isInIframe) return true;

    const registrations = "serviceWorker" in navigator ? await navigator.serviceWorker.getRegistrations() : [];
    if (registrations.length) {
      await Promise.all(registrations.map((registration) => registration.unregister()));
      if ("caches" in window) {
        const keys = await caches.keys();
        await Promise.all(keys.map((key) => caches.delete(key)));
      }
      if (!new URLSearchParams(window.location.search).has("sw-cleanup")) {
        const url = new URL(window.location.href);
        url.searchParams.set("sw-cleanup", Date.now().toString());
        window.location.replace(url.toString());
        return false;
      }
    }
  } catch {
    // Best-effort only; never block app boot.
  }
  return true;
}

// Recover from stale Supabase sessions left over from a previous domain/build.
// Symptom: 403 "invalid claim: missing sub claim" / bad_jwt on /user calls,
// which prevents login UX from working until storage is cleared.
function purgeStaleSupabaseSessionIfBroken() {
  try {
    if (typeof localStorage === "undefined") return;
    const keys: string[] = [];
    for (let i = 0; i < localStorage.length; i++) {
      const k = localStorage.key(i);
      if (k && (k.startsWith("sb-") || k.includes("supabase.auth"))) keys.push(k);
    }
    for (const k of keys) {
      const raw = localStorage.getItem(k);
      if (!raw) continue;
      try {
        const parsed = JSON.parse(raw);
        const token: string | undefined =
          parsed?.access_token || parsed?.currentSession?.access_token;
        if (!token || typeof token !== "string" || token.split(".").length !== 3) {
          localStorage.removeItem(k);
          continue;
        }
        const payload = JSON.parse(atob(token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")));
        // Missing `sub` => malformed/legacy token => will 403 forever. Drop it.
        // NOTE: Do NOT compare `iss` against a hardcoded URL — that wipes valid
        // sessions whenever the app points at a different Supabase (self-hosted,
        // staging, etc.). The Supabase client will reject mismatched tokens itself.
        if (!payload?.sub) {
          localStorage.removeItem(k);
        }
      } catch {
        // Corrupt entry — remove it so Supabase client starts clean.
        localStorage.removeItem(k);
      }
    }
  } catch {
    // ignore — never block bootstrap
  }
}

async function bootstrap() {
  const rootElement = document.getElementById("root");
  if (!rootElement) {
    throw new Error("Root element not found");
  }

  const canContinue = await cleanupPreviewServiceWorkers();
  if (!canContinue) return;

  purgeStaleSupabaseSessionIfBroken();

  const root = createRoot(rootElement);
  const { default: App } = await import("./page");
  root.render(<App />);
  requestAnimationFrame(() => {
    markAppMounted();
  });
}

bootstrap().catch((err) => {
  console.error("[FATAL] App bootstrap failed:", err);
  showFatalError(err instanceof Error ? err.message : "App failed to start");
});

// Load polyfills in background (non-blocking)
if (typeof window !== "undefined") {
  const idleCallback = window.requestIdleCallback?.bind(window);
  const loadPolyfills = () => {
    import("./lib/polyfills").then(({ default: loadPolyfills }) => {
      loadPolyfills();
    });
  };

  if (idleCallback) {
    idleCallback(loadPolyfills);
  } else {
    setTimeout(loadPolyfills, 2000);
  }
}
