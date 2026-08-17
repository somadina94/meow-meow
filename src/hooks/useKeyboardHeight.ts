import { useEffect } from "react";

/**
 * Side-effect-only hook: writes --keyboard-height CSS custom property
 * to document.documentElement based on window.visualViewport resize events.
 * 
 * On iOS Safari, when the on-screen keyboard opens, visualViewport.height shrinks.
 * We compute the difference between window.innerHeight and visualViewport.height
 * and set it as a CSS variable so fixed bottom bars can stay above the keyboard.
 *
 * SIDE-EFFECT ANALYSIS:
 * - Only writes to CSS custom property (--keyboard-height)
 * - Never touches React state, DOM content, or component structure
 * - Cleans up all listeners on unmount
 */
export function useKeyboardHeight(): void {
  useEffect(() => {
    const vv = window.visualViewport;
    if (!vv) return;

    function onResize() {
      const vv = window.visualViewport;
      if (!vv) return;
      // keyboard height = full window height - visible viewport height
      const kbHeight = Math.max(0, window.innerHeight - vv.height);
      document.documentElement.style.setProperty(
        "--keyboard-height",
        `${kbHeight}px`
      );
    }

    vv.addEventListener("resize", onResize);
    vv.addEventListener("scroll", onResize);

    // Initial measurement
    onResize();

    return () => {
      vv.removeEventListener("resize", onResize);
      vv.removeEventListener("scroll", onResize);
      document.documentElement.style.setProperty("--keyboard-height", "0px");
    };
  }, []);
}
