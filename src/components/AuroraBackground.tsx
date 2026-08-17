import { memo, useState, useEffect } from 'react';

/**
 * Optimized Aurora Background
 * - Uses CSS transforms for GPU acceleration
 * - Reduced animation complexity
 * - Memoized to prevent re-renders
 * - Disables animation for prefers-reduced-motion and low-end devices
 */
const AuroraBackground = memo(() => {
  const [shouldAnimate, setShouldAnimate] = useState(true);

  useEffect(() => {
    const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const isLowEndDevice = (navigator as any).deviceMemory && (navigator as any).deviceMemory < 4;
    if (prefersReducedMotion || isLowEndDevice) {
      setShouldAnimate(false);
    }
  }, []);

  return (
    <div className="fixed inset-0 -z-10 overflow-hidden will-change-transform">
      {/* Base gradient - always visible */}
      <div className="absolute inset-0 bg-gradient-to-br from-background via-background to-secondary/30" />
      
      {/* Aurora blobs - disabled on reduced-motion / low-end devices */}
      {shouldAnimate && (
        <>
          <div 
            className="absolute top-0 left-1/4 w-[500px] h-[500px] rounded-full bg-primary/20 blur-[80px] animate-aurora-1 will-change-transform" 
            style={{ transform: 'translateZ(0)' }}
          />
          <div 
            className="absolute top-1/3 right-1/4 w-[400px] h-[400px] rounded-full bg-accent/25 blur-[60px] animate-aurora-2 will-change-transform"
            style={{ transform: 'translateZ(0)' }}
          />
          <div 
            className="absolute bottom-1/4 left-1/3 w-[600px] h-[600px] rounded-full bg-[hsl(270_60%_55%/0.15)] blur-[100px] animate-aurora-3 will-change-transform"
            style={{ transform: 'translateZ(0)' }}
          />
          <div 
            className="absolute bottom-0 right-1/3 w-[350px] h-[350px] rounded-full bg-primary/15 blur-[70px] animate-aurora-4 will-change-transform"
            style={{ transform: 'translateZ(0)' }}
          />
        </>
      )}
      
      {/* Grid overlay - simplified */}
      <div className="absolute inset-0 bg-[linear-gradient(rgba(255,255,255,0.02)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,0.02)_1px,transparent_1px)] bg-[size:50px_50px]" />
    </div>
  );
});

AuroraBackground.displayName = 'AuroraBackground';

export default AuroraBackground;
