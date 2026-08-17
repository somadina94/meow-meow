/**
 * ScrollToggleFab — Floating buttons to jump to top/bottom and left/right edges.
 * Vertically scrolls the window; horizontally scrolls the nearest scrollable
 * ancestor (e.g., admin <main> with overflow-x-auto) or the window as fallback.
 */
import { ArrowUp, ArrowDown, ArrowLeft, ArrowRight } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useRef } from "react";

const findHorizontalScroller = (start: HTMLElement | null): HTMLElement | null => {
  let el: HTMLElement | null = start?.parentElement ?? null;
  while (el && el !== document.body) {
    const style = window.getComputedStyle(el);
    if (
      (style.overflowX === "auto" || style.overflowX === "scroll") &&
      el.scrollWidth > el.clientWidth
    ) {
      return el;
    }
    el = el.parentElement;
  }
  return null;
};

const ScrollToggleFab = () => {
  const anchorRef = useRef<HTMLDivElement>(null);

  const toTop = () => window.scrollTo({ top: 0, behavior: "smooth" });
  const toBottom = () =>
    window.scrollTo({ top: document.documentElement.scrollHeight, behavior: "smooth" });

  const toLeft = () => {
    const sc = findHorizontalScroller(anchorRef.current);
    if (sc) sc.scrollTo({ left: 0, behavior: "smooth" });
    else window.scrollTo({ left: 0, behavior: "smooth" });
  };
  const toRight = () => {
    const sc = findHorizontalScroller(anchorRef.current);
    if (sc) sc.scrollTo({ left: sc.scrollWidth, behavior: "smooth" });
    else
      window.scrollTo({
        left: document.documentElement.scrollWidth,
        behavior: "smooth",
      });
  };

  const btn =
    "h-11 w-11 rounded-full shadow-lg bg-primary text-primary-foreground hover:bg-primary/90";

  return (
    <div
      ref={anchorRef}
      className="fixed right-4 bottom-[max(1rem,env(safe-area-inset-bottom))] z-[120] flex flex-col gap-2"
    >
      <Button size="icon" className={btn} onClick={toTop} aria-label="Scroll to top">
        <ArrowUp className="h-5 w-5" />
      </Button>
      <Button size="icon" className={btn} onClick={toBottom} aria-label="Scroll to bottom">
        <ArrowDown className="h-5 w-5" />
      </Button>
      <Button size="icon" className={btn} onClick={toLeft} aria-label="Scroll to left">
        <ArrowLeft className="h-5 w-5" />
      </Button>
      <Button size="icon" className={btn} onClick={toRight} aria-label="Scroll to right">
        <ArrowRight className="h-5 w-5" />
      </Button>
    </div>
  );
};

export default ScrollToggleFab;
