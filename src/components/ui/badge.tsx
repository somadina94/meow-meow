import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";

import { cn } from "@/lib/utils";

const badgeVariants = cva(
  "inline-flex items-center rounded-full border px-2 py-0.5 text-[11px] sm:px-2.5 sm:text-xs font-semibold transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2",
  {
    variants: {
      variant: {
        default: "border-transparent bg-primary text-primary-foreground hover:bg-primary/80 hover:shadow-[0_0_10px_hsl(var(--primary)/0.4)]",
        secondary: "border-transparent bg-secondary text-secondary-foreground hover:bg-secondary/80",
        destructive: "border-transparent bg-destructive text-destructive-foreground hover:bg-destructive/80",
        outline: "text-foreground border-primary/30 hover:border-primary/50 hover:bg-primary/5",
        aurora: "border-transparent gradient-aurora text-primary-foreground shadow-[0_0_10px_hsl(var(--primary)/0.3)] hover:shadow-[0_0_15px_hsl(var(--primary)/0.5)]",
        auroraOutline: "border-primary/40 bg-transparent text-primary hover:bg-primary/10 hover:shadow-[0_0_10px_hsl(var(--primary)/0.3)]",
        // Semantic status variants - use these for consistent theming across all 20 themes
        success: "border-transparent bg-success text-success-foreground hover:bg-success/80",
        warning: "border-transparent bg-warning text-warning-foreground hover:bg-warning/80",
        info: "border-transparent bg-info text-info-foreground hover:bg-info/80",
        // Status outline variants
        successOutline: "border-success/30 bg-success/10 text-success hover:bg-success/20",
        warningOutline: "border-warning/30 bg-warning/10 text-warning hover:bg-warning/20",
        infoOutline: "border-info/30 bg-info/10 text-info hover:bg-info/20",
        destructiveOutline: "border-destructive/30 bg-destructive/10 text-destructive hover:bg-destructive/20",
        // Online/offline status
        online: "border-online/30 bg-online/10 text-online hover:bg-online/20",
        offline: "border-offline/30 bg-offline/10 text-offline hover:bg-offline/20",
        busy: "border-busy/30 bg-busy/10 text-busy hover:bg-busy/20",
      },
    },
    defaultVariants: {
      variant: "default",
    },
  },
);

export interface BadgeProps extends React.HTMLAttributes<HTMLDivElement>, VariantProps<typeof badgeVariants> {}

function Badge({ className, variant, ...props }: BadgeProps) {
  return <div className={cn(badgeVariants({ variant }), className)} {...props} />;
}

export { Badge, badgeVariants };
