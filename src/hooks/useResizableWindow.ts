import { useState, useEffect, useRef, useCallback } from "react";

interface UseResizableWindowOptions {
  position: { x: number; y: number };
  setPosition: (pos: { x: number; y: number }) => void;
}

export const useResizableWindow = ({ position, setPosition }: UseResizableWindowOptions) => {
  const getResponsiveSize = () => {
    if (typeof window !== "undefined") {
      const isMobile = window.innerWidth < 640;
      return isMobile ? { width: 280, height: 350 } : { width: 320, height: 400 };
    }
    return { width: 320, height: 400 };
  };

  const [size, setSize] = useState(getResponsiveSize);
  const [isResizing, setIsResizing] = useState(false);
  const resizeRef = useRef<{
    startWidth: number;
    startHeight: number;
    startX: number;
    startY: number;
    corner: string;
  } | null>(null);

  const handleResizeStart = useCallback(
    (e: React.MouseEvent | React.TouchEvent, corner: string = "se") => {
      e.preventDefault();
      e.stopPropagation();
      setIsResizing(true);

      const clientX = "touches" in e ? e.touches[0].clientX : e.clientX;
      const clientY = "touches" in e ? e.touches[0].clientY : e.clientY;

      resizeRef.current = {
        startWidth: size.width,
        startHeight: size.height,
        startX: clientX,
        startY: clientY,
        corner,
      };
    },
    [size]
  );

  // Effect: attach global move/end listeners while resizing
  useEffect(() => {
    const handleResizeMove = (e: MouseEvent | TouchEvent) => {
      if (!isResizing || !resizeRef.current) return;

      const clientX = "touches" in e ? (e as TouchEvent).touches[0].clientX : (e as MouseEvent).clientX;
      const clientY = "touches" in e ? (e as TouchEvent).touches[0].clientY : (e as MouseEvent).clientY;

      const deltaX = clientX - resizeRef.current.startX;
      const deltaY = clientY - resizeRef.current.startY;

      const minWidth = 280;
      const minHeight = 300;
      const maxWidth = Math.min(600, window.innerWidth - 40);
      const maxHeight = Math.min(600, window.innerHeight - 40);

      let newWidth = resizeRef.current.startWidth;
      let newHeight = resizeRef.current.startHeight;
      let newX = position.x;
      let newY = position.y;

      const corner = resizeRef.current.corner;

      if (corner.includes("e")) {
        newWidth = Math.max(minWidth, Math.min(maxWidth, resizeRef.current.startWidth + deltaX));
      }
      if (corner.includes("w")) {
        const widthDelta = -deltaX;
        newWidth = Math.max(minWidth, Math.min(maxWidth, resizeRef.current.startWidth + widthDelta));
        if (newWidth !== resizeRef.current.startWidth) {
          newX = position.x + (resizeRef.current.startWidth - newWidth);
        }
      }
      if (corner.includes("s")) {
        newHeight = Math.max(minHeight, Math.min(maxHeight, resizeRef.current.startHeight + deltaY));
      }
      if (corner.includes("n")) {
        const heightDelta = -deltaY;
        newHeight = Math.max(minHeight, Math.min(maxHeight, resizeRef.current.startHeight + heightDelta));
        if (newHeight !== resizeRef.current.startHeight) {
          newY = position.y + (resizeRef.current.startHeight - newHeight);
        }
      }

      setSize({ width: newWidth, height: newHeight });
      if (newX !== position.x || newY !== position.y) {
        setPosition({ x: Math.max(0, newX), y: Math.max(0, newY) });
      }
    };

    const handleResizeEnd = () => {
      setIsResizing(false);
      resizeRef.current = null;
    };

    if (isResizing) {
      document.addEventListener("mousemove", handleResizeMove);
      document.addEventListener("mouseup", handleResizeEnd);
      document.addEventListener("touchmove", handleResizeMove, { passive: false });
      document.addEventListener("touchend", handleResizeEnd);
    }

    return () => {
      document.removeEventListener("mousemove", handleResizeMove);
      document.removeEventListener("mouseup", handleResizeEnd);
      document.removeEventListener("touchmove", handleResizeMove);
      document.removeEventListener("touchend", handleResizeEnd);
    };
  }, [isResizing, position]);

  return { size, isResizing, handleResizeStart };
};
