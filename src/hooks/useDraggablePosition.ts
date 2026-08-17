import { useState, useEffect, useRef, useCallback } from "react";

interface UseDraggablePositionOptions {
  initialPosition: { x: number; y: number };
  size: { width: number; height: number };
  isMaximized: boolean;
  isMinimized: boolean;
  onFocus?: () => void;
}

export const useDraggablePosition = ({
  initialPosition,
  size,
  isMaximized,
  isMinimized,
  onFocus,
}: UseDraggablePositionOptions) => {
  const [position, setPosition] = useState(() => {
    if (typeof window !== "undefined") {
      const isMobile = window.innerWidth < 640;
      const defaultWidth = isMobile ? 280 : 320;
      const defaultHeight = isMobile ? 350 : 400;
      return {
        x: initialPosition.x === 20 ? window.innerWidth - defaultWidth - 20 : initialPosition.x,
        y: initialPosition.y === 20 ? window.innerHeight - defaultHeight - 20 : initialPosition.y,
      };
    }
    return initialPosition;
  });
  const [isDragging, setIsDragging] = useState(false);
  const dragRef = useRef<{ startX: number; startY: number; startPosX: number; startPosY: number } | null>(null);

  const handleDragStart = useCallback(
    (e: React.MouseEvent | React.TouchEvent) => {
      if (isMaximized) return;

      const target = e.target as HTMLElement | null;
      const interactive = target?.closest?.(
        'button, a, input, textarea, select, [role="button"], [data-no-drag]'
      );
      if (interactive) return;

      e.preventDefault();
      setIsDragging(true);

      const clientX = "touches" in e ? e.touches[0].clientX : e.clientX;
      const clientY = "touches" in e ? e.touches[0].clientY : e.clientY;

      dragRef.current = {
        startX: clientX,
        startY: clientY,
        startPosX: position.x,
        startPosY: position.y,
      };
      onFocus?.();
    },
    [position, isMaximized, onFocus]
  );

  // Effect: attach global move/end listeners while dragging
  useEffect(() => {
    const handleMove = (e: MouseEvent | TouchEvent) => {
      if (!isDragging || !dragRef.current) return;

      const clientX = "touches" in e ? e.touches[0].clientX : e.clientX;
      const clientY = "touches" in e ? e.touches[0].clientY : e.clientY;

      const deltaX = clientX - dragRef.current.startX;
      const deltaY = clientY - dragRef.current.startY;

      const maxX = window.innerWidth - size.width;
      const maxY = window.innerHeight - (isMinimized ? 48 : size.height);

      setPosition({
        x: Math.max(0, Math.min(maxX, dragRef.current.startPosX + deltaX)),
        y: Math.max(0, Math.min(maxY, dragRef.current.startPosY + deltaY)),
      });
    };

    const handleEnd = () => {
      setIsDragging(false);
      dragRef.current = null;
    };

    if (isDragging) {
      document.addEventListener("mousemove", handleMove);
      document.addEventListener("mouseup", handleEnd);
      document.addEventListener("touchmove", handleMove, { passive: false });
      document.addEventListener("touchend", handleEnd);
    }

    return () => {
      document.removeEventListener("mousemove", handleMove);
      document.removeEventListener("mouseup", handleEnd);
      document.removeEventListener("touchmove", handleMove);
      document.removeEventListener("touchend", handleEnd);
    };
  }, [isDragging, size, isMinimized]);

  return { position, setPosition, isDragging, handleDragStart };
};
