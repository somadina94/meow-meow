/**
 * Performance-optimized debounce and throttle hooks
 */

import { useState, useEffect, useRef, useCallback, useMemo } from "react";

/**
 * Debounce a value - delays updating the value until after wait ms
 */
export function useDebounce<T>(value: T, delay = 300): T {
  const [debouncedValue, setDebouncedValue] = useState<T>(value);

  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedValue(value);
    }, delay);

    return () => {
      clearTimeout(timer);
    };
  }, [value, delay]);

  return debouncedValue;
}

/**
 * Debounced callback - returns a stable debounced function
 */
export function useDebouncedCallback<T extends (...args: unknown[]) => unknown>(
  callback: T,
  delay = 300
): T {
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const callbackRef = useRef(callback);
  
  // Keep callback ref up to date
  useEffect(() => {
    callbackRef.current = callback;
  }, [callback]);

  return useCallback(
    ((...args: Parameters<T>) => {
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }
      
      timeoutRef.current = setTimeout(() => {
        callbackRef.current(...args);
      }, delay);
    }) as T,
    [delay]
  );
}

/**
 * Throttled callback - ensures callback is called at most once per interval
 */
export function useThrottledCallback<T extends (...args: unknown[]) => unknown>(
  callback: T,
  interval = 300
): T {
  const lastCallRef = useRef<number>(0);
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const callbackRef = useRef(callback);
  
  // Keep callback ref up to date
  useEffect(() => {
    callbackRef.current = callback;
  }, [callback]);

  return useCallback(
    ((...args: Parameters<T>) => {
      const now = Date.now();
      const timeSinceLastCall = now - lastCallRef.current;
      
      if (timeSinceLastCall >= interval) {
        lastCallRef.current = now;
        callbackRef.current(...args);
      } else {
        // Schedule for when the interval has passed
        if (timeoutRef.current) {
          clearTimeout(timeoutRef.current);
        }
        
        timeoutRef.current = setTimeout(() => {
          lastCallRef.current = Date.now();
          callbackRef.current(...args);
        }, interval - timeSinceLastCall);
      }
    }) as T,
    [interval]
  );
}

/**
 * Memoized expensive computation with comparison
 */
export function useDeepMemo<T>(factory: () => T, deps: unknown[]): T {
  const ref = useRef<{ deps: unknown[]; value: T } | null>(null);
  
  const depsChanged = !ref.current || 
    deps.length !== ref.current.deps.length ||
    deps.some((dep, i) => !Object.is(dep, ref.current!.deps[i]));
  
  if (depsChanged) {
    ref.current = { deps, value: factory() };
  }
  
  return ref.current.value;
}

/**
 * Lazy initialization hook - only runs factory once
 */
export function useLazyRef<T>(factory: () => T): React.MutableRefObject<T> {
  const ref = useRef<T | null>(null);
  
  if (ref.current === null) {
    ref.current = factory();
  }
  
  return ref as React.MutableRefObject<T>;
}

/**
 * Previous value hook - returns the previous value
 */
export function usePrevious<T>(value: T): T | undefined {
  const ref = useRef<T>();
  
  useEffect(() => {
    ref.current = value;
  }, [value]);
  
  return ref.current;
}

/**
 * Intersection observer hook for lazy loading
 */
export function useIntersectionObserver(
  options?: IntersectionObserverInit
): [React.RefCallback<Element>, boolean] {
  const [isIntersecting, setIsIntersecting] = useState(false);
  const [element, setElement] = useState<Element | null>(null);
  
  const setRef = useCallback((node: Element | null) => {
    setElement(node);
  }, []);
  
  useEffect(() => {
    if (!element) return;
    
    const observer = new IntersectionObserver(
      ([entry]) => {
        setIsIntersecting(entry.isIntersecting);
      },
      { threshold: 0.1, ...options }
    );
    
    observer.observe(element);
    
    return () => {
      observer.disconnect();
    };
  }, [element, options?.root, options?.rootMargin, options?.threshold]);
  
  return [setRef, isIntersecting];
}

/**
 * Request idle callback hook for non-urgent work
 */
export function useIdleCallback(
  callback: () => void,
  options?: { timeout?: number }
) {
  const callbackRef = useRef(callback);
  
  useEffect(() => {
    callbackRef.current = callback;
  }, [callback]);
  
  useEffect(() => {
    if ('requestIdleCallback' in window) {
      const handle = requestIdleCallback(
        () => callbackRef.current(),
        options
      );
      return () => cancelIdleCallback(handle);
    } else {
      const handle = setTimeout(() => callbackRef.current(), 1);
      return () => clearTimeout(handle);
    }
  }, [options?.timeout]);
}
