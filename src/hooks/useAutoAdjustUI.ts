import { useEffect } from "react";
import { useKeyboardHeight } from "./useKeyboardHeight";

/**
 * Side-effect-only hook for auto-adjustable UI across all devices.
 *
 * Writes ONLY to:
 * - CSS custom properties on document.documentElement.style
 * - data-* attributes on document.documentElement
 *
 * Never touches React state, DOM content, component structure, or routing.
 */
export function useAutoAdjustUI(): void {
  useKeyboardHeight();

  useEffect(() => {
    const html = document.documentElement;

    type CompatibleMQ = MediaQueryList & {
      addListener?: (listener: (event: MediaQueryListEvent) => void) => void;
      removeListener?: (listener: (event: MediaQueryListEvent) => void) => void;
    };

    function setViewportVars() {
      const vw = window.innerWidth * 0.01;
      const vh = window.innerHeight * 0.01;
      html.style.setProperty("--vw", `${vw}px`);
      html.style.setProperty("--vh", `${vh}px`);
    }

    function setDeviceAttributes() {
      const touchQuery = window.matchMedia("(hover: none) and (pointer: coarse)");
      const hoverQuery = window.matchMedia("(hover: hover) and (pointer: fine)");
      html.setAttribute("data-touch", String(touchQuery.matches));
      html.setAttribute("data-hover", String(hoverQuery.matches));

      const nav = navigator as Navigator & { deviceMemory?: number; standalone?: boolean };
      if (nav.deviceMemory !== undefined) {
        html.setAttribute("data-memory", String(nav.deviceMemory));
      }

      const isPWA = window.matchMedia("(display-mode: standalone)").matches || nav.standalone === true;
      html.setAttribute("data-pwa", String(isPWA));

      const ua = navigator.userAgent;
      const isIOS = /iPad|iPhone|iPod/.test(ua) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
      const isAndroid = /Android/.test(ua);
      html.setAttribute("data-ios", String(isIOS));
      html.setAttribute("data-android", String(isAndroid));

      const orientation = window.innerWidth > window.innerHeight ? "landscape" : "portrait";
      html.setAttribute("data-orientation", orientation);

      const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
      html.setAttribute("data-reduced-motion", String(reducedMotion));
    }

    function onResize() {
      setViewportVars();
      const orientation = window.innerWidth > window.innerHeight ? "landscape" : "portrait";
      html.setAttribute("data-orientation", orientation);
    }

    function onOrientationChange() {
      setTimeout(() => {
        setViewportVars();
        const orientation = window.innerWidth > window.innerHeight ? "landscape" : "portrait";
        html.setAttribute("data-orientation", orientation);
      }, 100);
    }

    const addMQListener = (mq: CompatibleMQ, handler: (event: MediaQueryListEvent) => void) => {
      if (typeof mq.addEventListener === "function") {
        mq.addEventListener("change", handler);
      } else {
        mq.addListener?.(handler);
      }
    };

    const removeMQListener = (mq: CompatibleMQ, handler: (event: MediaQueryListEvent) => void) => {
      if (typeof mq.removeEventListener === "function") {
        mq.removeEventListener("change", handler);
      } else {
        mq.removeListener?.(handler);
      }
    };

    setViewportVars();
    setDeviceAttributes();

    window.addEventListener("resize", onResize);
    window.addEventListener("orientationchange", onOrientationChange);

    const touchMQ = window.matchMedia("(hover: none) and (pointer: coarse)") as CompatibleMQ;
    const motionMQ = window.matchMedia("(prefers-reduced-motion: reduce)") as CompatibleMQ;
    const pwaMQ = window.matchMedia("(display-mode: standalone)") as CompatibleMQ;

    const onTouchChange = (e: MediaQueryListEvent) => {
      html.setAttribute("data-touch", String(e.matches));
    };
    const onMotionChange = (e: MediaQueryListEvent) => {
      html.setAttribute("data-reduced-motion", String(e.matches));
    };
    const onPWAChange = (e: MediaQueryListEvent) => {
      html.setAttribute("data-pwa", String(e.matches));
    };

    addMQListener(touchMQ, onTouchChange);
    addMQListener(motionMQ, onMotionChange);
    addMQListener(pwaMQ, onPWAChange);

    return () => {
      window.removeEventListener("resize", onResize);
      window.removeEventListener("orientationchange", onOrientationChange);
      removeMQListener(touchMQ, onTouchChange);
      removeMQListener(motionMQ, onMotionChange);
      removeMQListener(pwaMQ, onPWAChange);

      html.style.removeProperty("--vw");
      html.style.removeProperty("--vh");

      const attrs = [
        "data-touch", "data-hover", "data-memory", "data-pwa",
        "data-ios", "data-android", "data-orientation", "data-reduced-motion",
      ];
      attrs.forEach((attr) => html.removeAttribute(attr));
    };
  }, []);
}
