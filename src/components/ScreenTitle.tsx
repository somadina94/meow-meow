import { memo, ReactNode, Suspense, lazy } from 'react';
import { cn } from '@/lib/utils';

const MeowLogo = lazy(() => import('./MeowLogo'));

interface ScreenTitleProps {
  title: string;
  subtitle?: string;
  showLogo?: boolean;
  logoSize?: 'sm' | 'md' | 'lg';
  className?: string;
  children?: ReactNode;
}

/**
 * Unified screen title component for consistent heading styling.
 * Uses the Aurora theme with:
 * - Display font (Quicksand)
 * - Consistent text colors
 * - Optional logo
 */
const ScreenTitle = memo(({
  title,
  subtitle,
  showLogo = true,
  logoSize = 'md',
  className,
  children,
}: ScreenTitleProps) => {
  return (
    <div className={cn("text-center mb-8 animate-fade-in", className)}>
      {showLogo && (
        <Suspense fallback={
          <div className={cn(
            "mx-auto mb-4 bg-primary/20 rounded-full animate-pulse",
            logoSize === 'sm' && "w-12 h-12",
            logoSize === 'md' && "w-16 h-16",
            logoSize === 'lg' && "w-20 h-20",
          )} />
        }>
          <MeowLogo size={logoSize} className="mx-auto mb-4" />
        </Suspense>
      )}
      <h1 className="font-display text-3xl font-bold text-foreground mb-2 drop-shadow-sm">
        {title}
      </h1>
      {subtitle && (
        <p className="text-muted-foreground text-base max-w-xs mx-auto">
          {subtitle}
        </p>
      )}
      {children}
    </div>
  );
});

ScreenTitle.displayName = 'ScreenTitle';

export default ScreenTitle;
