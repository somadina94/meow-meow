import React, { useRef, useState, useCallback, useEffect } from "react";
import { Button } from "@/components/ui/button";
import { ChevronUp, ChevronDown } from "lucide-react";

interface ScrollableUserListProps {
  children: React.ReactNode;
  maxHeight?: string;
}

const ScrollableUserList: React.FC<ScrollableUserListProps> = ({ children, maxHeight = "60vh" }) => {
  const scrollRef = useRef<HTMLDivElement>(null);
  const [canScrollUp, setCanScrollUp] = useState(false);
  const [canScrollDown, setCanScrollDown] = useState(false);

  const checkScroll = useCallback(() => {
    const el = scrollRef.current;
    if (!el) return;
    setCanScrollUp(el.scrollTop > 10);
    setCanScrollDown(el.scrollTop + el.clientHeight < el.scrollHeight - 10);
  }, []);

  useEffect(() => {
    const el = scrollRef.current;
    if (!el) return;
    checkScroll();
    el.addEventListener('scroll', checkScroll, { passive: true });
    const observer = new ResizeObserver(() => checkScroll());
    observer.observe(el);
    return () => {
      el.removeEventListener('scroll', checkScroll);
      observer.disconnect();
    };
  }, [checkScroll]);

  const scrollBy = (direction: 'up' | 'down') => {
    scrollRef.current?.scrollBy({ top: direction === 'up' ? -200 : 200, behavior: 'smooth' });
  };

  return (
    <div className="relative">
      {canScrollUp && (
        <div className="sticky top-0 z-10 flex justify-center pb-1">
          <Button size="sm" variant="secondary" className="h-7 w-7 rounded-full shadow-md p-0" onClick={() => scrollBy('up')}>
            <ChevronUp className="h-4 w-4" />
          </Button>
        </div>
      )}
      <div ref={scrollRef} className="space-y-2 overflow-y-auto pr-1 scroll-smooth" style={{ maxHeight }}>
        {children}
      </div>
      {canScrollDown && (
        <div className="sticky bottom-0 z-10 flex justify-center pt-1">
          <Button size="sm" variant="secondary" className="h-7 w-7 rounded-full shadow-md p-0" onClick={() => scrollBy('down')}>
            <ChevronDown className="h-4 w-4" />
          </Button>
        </div>
      )}
    </div>
  );
};

export default ScrollableUserList;
