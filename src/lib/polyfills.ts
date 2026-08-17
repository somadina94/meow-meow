/**
 * Browser Polyfills
 * 
 * Provides polyfills for older browsers to ensure cross-browser compatibility.
 * Only loads polyfills that are actually needed based on feature detection.
 */

/**
 * Check if polyfills are needed and load them
 */
export async function loadPolyfillsIfNeeded(): Promise<void> {
  const needed: Promise<void>[] = [];

  // IntersectionObserver polyfill
  if (!('IntersectionObserver' in window)) {
    needed.push(polyfillIntersectionObserver());
  }

  // ResizeObserver polyfill
  if (!('ResizeObserver' in window)) {
    needed.push(polyfillResizeObserver());
  }

  // AbortController polyfill
  if (!('AbortController' in window)) {
    needed.push(polyfillAbortController());
  }

  // Promise.allSettled polyfill
  if (!Promise.allSettled) {
    polyfillPromiseAllSettled();
  }

  // Array.prototype.flat polyfill
  if (!Array.prototype.flat) {
    polyfillArrayFlat();
  }

  // Array.prototype.flatMap polyfill
  if (!Array.prototype.flatMap) {
    polyfillArrayFlatMap();
  }

  // Object.fromEntries polyfill
  if (!Object.fromEntries) {
    polyfillObjectFromEntries();
  }

  // String.prototype.replaceAll polyfill
  if (!(String.prototype as any).replaceAll) {
    polyfillStringReplaceAll();
  }

  // globalThis polyfill
  if (typeof (window as any).globalThis === 'undefined') {
    polyfillGlobalThis();
  }

  // requestIdleCallback polyfill
  if (!('requestIdleCallback' in window)) {
    polyfillRequestIdleCallback();
  }

  // Element.prototype.matches polyfill
  if (!Element.prototype.matches) {
    polyfillElementMatches();
  }

  // Element.prototype.closest polyfill
  if (!Element.prototype.closest) {
    polyfillElementClosest();
  }

  // CustomEvent polyfill for IE
  if (typeof CustomEvent !== 'function') {
    polyfillCustomEvent();
  }

  // Scroll behavior polyfill
  if (!('scrollBehavior' in document.documentElement.style)) {
    needed.push(polyfillScrollBehavior());
  }

  await Promise.all(needed);
}

// ============================================
// ASYNC POLYFILLS (loaded on demand)
// ============================================

async function polyfillIntersectionObserver(): Promise<void> {
  // Lightweight IntersectionObserver polyfill
  (window as any).IntersectionObserver = class IntersectionObserver {
    private callback: IntersectionObserverCallback;
    private elements: Set<Element> = new Set();
    private intervalId: number | null = null;

    constructor(callback: IntersectionObserverCallback, options?: IntersectionObserverInit) {
      this.callback = callback;
      this.startPolling();
    }

    observe(element: Element): void {
      this.elements.add(element);
    }

    unobserve(element: Element): void {
      this.elements.delete(element);
    }

    disconnect(): void {
      this.elements.clear();
      if (this.intervalId) {
        clearInterval(this.intervalId);
      }
    }

    private startPolling(): void {
      this.intervalId = window.setInterval(() => {
        const entries: IntersectionObserverEntry[] = [];
        this.elements.forEach((element) => {
          const rect = element.getBoundingClientRect();
          const isIntersecting = 
            rect.top < window.innerHeight &&
            rect.bottom > 0 &&
            rect.left < window.innerWidth &&
            rect.right > 0;

          entries.push({
            target: element,
            isIntersecting,
            intersectionRatio: isIntersecting ? 1 : 0,
            boundingClientRect: rect,
            intersectionRect: rect,
            rootBounds: null,
            time: Date.now(),
          } as IntersectionObserverEntry);
        });

        if (entries.length > 0) {
          this.callback(entries, this as any);
        }
      }, 100);
    }
  };
}

async function polyfillResizeObserver(): Promise<void> {
  // Lightweight ResizeObserver polyfill
  (window as any).ResizeObserver = class ResizeObserver {
    private callback: ResizeObserverCallback;
    private elements: Map<Element, DOMRectReadOnly> = new Map();
    private rafId: number | null = null;

    constructor(callback: ResizeObserverCallback) {
      this.callback = callback;
    }

    observe(element: Element): void {
      const rect = element.getBoundingClientRect();
      this.elements.set(element, DOMRectReadOnly.fromRect(rect));
      this.startObserving();
    }

    unobserve(element: Element): void {
      this.elements.delete(element);
    }

    disconnect(): void {
      this.elements.clear();
      if (this.rafId) {
        cancelAnimationFrame(this.rafId);
      }
    }

    private startObserving(): void {
      const check = () => {
        const entries: ResizeObserverEntry[] = [];

        this.elements.forEach((oldRect, element) => {
          const newRect = element.getBoundingClientRect();
          
          if (oldRect.width !== newRect.width || oldRect.height !== newRect.height) {
            this.elements.set(element, DOMRectReadOnly.fromRect(newRect));
            entries.push({
              target: element,
              contentRect: newRect,
              borderBoxSize: [{ blockSize: newRect.height, inlineSize: newRect.width }],
              contentBoxSize: [{ blockSize: newRect.height, inlineSize: newRect.width }],
              devicePixelContentBoxSize: [{ blockSize: newRect.height, inlineSize: newRect.width }],
            } as ResizeObserverEntry);
          }
        });

        if (entries.length > 0) {
          this.callback(entries, this as any);
        }

        this.rafId = requestAnimationFrame(check);
      };

      this.rafId = requestAnimationFrame(check);
    }
  };
}

async function polyfillAbortController(): Promise<void> {
  class AbortSignal extends EventTarget {
    aborted = false;
    reason?: any;

    throwIfAborted(): void {
      if (this.aborted) {
        throw this.reason;
      }
    }
  }

  (window as any).AbortController = class AbortController {
    signal = new AbortSignal();

    abort(reason?: any): void {
      if (!this.signal.aborted) {
        this.signal.aborted = true;
        this.signal.reason = reason;
        this.signal.dispatchEvent(new Event('abort'));
      }
    }
  };
}

async function polyfillScrollBehavior(): Promise<void> {
  // Simple scroll behavior polyfill
  const originalScrollTo = window.scrollTo;
  const originalScrollBy = window.scrollBy;

  (window as any).scrollTo = function(optionsOrX?: ScrollToOptions | number, y?: number) {
    if (typeof optionsOrX === 'object' && optionsOrX.behavior === 'smooth') {
      smoothScroll(optionsOrX.left ?? 0, optionsOrX.top ?? 0);
    } else if (typeof optionsOrX === 'number') {
      originalScrollTo.call(window, optionsOrX, y ?? 0);
    } else {
      originalScrollTo.call(window, optionsOrX as any);
    }
  };

  function smoothScroll(targetX: number, targetY: number): void {
    const startX = window.pageXOffset;
    const startY = window.pageYOffset;
    const diffX = targetX - startX;
    const diffY = targetY - startY;
    const duration = 500;
    let startTime: number | null = null;

    function step(currentTime: number) {
      if (!startTime) startTime = currentTime;
      const elapsed = currentTime - startTime;
      const progress = Math.min(elapsed / duration, 1);
      
      // Easing function
      const easeProgress = 1 - Math.pow(1 - progress, 3);
      
      window.scrollTo(
        startX + diffX * easeProgress,
        startY + diffY * easeProgress
      );

      if (elapsed < duration) {
        requestAnimationFrame(step);
      }
    }

    requestAnimationFrame(step);
  }
}

// ============================================
// SYNC POLYFILLS (applied immediately)
// ============================================

function polyfillPromiseAllSettled(): void {
  Promise.allSettled = function<T>(promises: Iterable<T | PromiseLike<T>>): Promise<PromiseSettledResult<Awaited<T>>[]> {
    return Promise.all(
      Array.from(promises).map((p) =>
        Promise.resolve(p).then(
          (value) => ({ status: 'fulfilled' as const, value }),
          (reason) => ({ status: 'rejected' as const, reason })
        )
      )
    );
  };
}

function polyfillArrayFlat(): void {
  Object.defineProperty(Array.prototype, 'flat', {
    value: function<T>(this: T[], depth = 1): T[] {
      return depth > 0
        ? this.reduce((acc: T[], val) =>
            acc.concat(Array.isArray(val) ? (val as any[]).flat(depth - 1) : val), [])
        : this.slice();
    },
  });
}

function polyfillArrayFlatMap(): void {
  Object.defineProperty(Array.prototype, 'flatMap', {
    value: function<T, U>(this: T[], callback: (value: T, index: number, array: T[]) => U | U[]): U[] {
      return (this.map(callback) as any).flat() as U[];
    },
  });
}

function polyfillObjectFromEntries(): void {
  Object.fromEntries = function<T>(entries: Iterable<readonly [PropertyKey, T]>): { [k: string]: T } {
    const obj: { [k: string]: T } = {};
    for (const [key, value] of entries) {
      obj[key as string] = value;
    }
    return obj;
  };
}

function polyfillStringReplaceAll(): void {
  Object.defineProperty(String.prototype, 'replaceAll', {
    value: function(this: string, search: string | RegExp, replace: string): string {
      if (typeof search === 'string') {
        return this.split(search).join(replace);
      }
      return this.replace(new RegExp(search, 'g'), replace);
    },
  });
}

function polyfillGlobalThis(): void {
  if (typeof window !== 'undefined') {
    (window as any).globalThis = window;
  }
}

function polyfillRequestIdleCallback(): void {
  (window as any).requestIdleCallback = function(
    callback: IdleRequestCallback,
    options?: IdleRequestOptions
  ): number {
    const start = Date.now();
    return window.setTimeout(() => {
      callback({
        didTimeout: false,
        timeRemaining: () => Math.max(0, 50 - (Date.now() - start)),
      });
    }, options?.timeout ?? 1);
  };

  (window as any).cancelIdleCallback = function(id: number): void {
    clearTimeout(id);
  };
}

function polyfillElementMatches(): void {
  Element.prototype.matches = 
    (Element.prototype as any).matchesSelector ||
    (Element.prototype as any).mozMatchesSelector ||
    (Element.prototype as any).msMatchesSelector ||
    (Element.prototype as any).oMatchesSelector ||
    (Element.prototype as any).webkitMatchesSelector ||
    function(this: Element, s: string): boolean {
      const doc = this.ownerDocument || document;
      const matches = doc.querySelectorAll(s);
      let i = matches.length;
      while (--i >= 0 && matches.item(i) !== this) {}
      return i > -1;
    };
}

function polyfillElementClosest(): void {
  Element.prototype.closest = function(this: Element, s: string): Element | null {
    let el: Element | null = this;
    do {
      if (el.matches(s)) return el;
      el = el.parentElement;
    } while (el !== null);
    return null;
  };
}

function polyfillCustomEvent(): void {
  (window as any).CustomEvent = function(
    event: string,
    params: CustomEventInit = { bubbles: false, cancelable: false, detail: null }
  ): CustomEvent {
    const evt = document.createEvent('CustomEvent');
    evt.initCustomEvent(event, params.bubbles ?? false, params.cancelable ?? false, params.detail);
    return evt;
  };
}

export default loadPolyfillsIfNeeded;
