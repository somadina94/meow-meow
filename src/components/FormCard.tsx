import { memo, ReactNode } from 'react';
import { cn } from '@/lib/utils';

interface FormCardProps {
  children: ReactNode;
  className?: string;
}

/**
 * Unified form card component for consistent styling across all registration and form screens.
 * Uses the Aurora theme with:
 * - Glassmorphic background
 * - Primary border glow
 * - Consistent padding and border radius
 */
const FormCard = memo(({
  children,
  className,
}: FormCardProps) => {
  return (
    <div className={cn(
      "w-full max-w-md mx-auto",
      "bg-card/70 backdrop-blur-xl",
      "rounded-3xl p-6",
      "shadow-[0_0_40px_hsl(var(--primary)/0.1)]",
      "border border-primary/20",
      "animate-slide-up",
      className
    )}>
      {children}
    </div>
  );
});

FormCard.displayName = 'FormCard';

export default FormCard;
