import * as React from "react";
import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";

import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-xl text-sm font-semibold ring-offset-background transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:size-4 [&_svg]:shrink-0 active:scale-[0.98] touch-manipulation select-none cursor-pointer shadow-sm",
  {
    variants: {
      variant: {
        // Primary - fully solid with strong visibility
        default: "bg-primary text-primary-foreground hover:bg-primary/90 active:bg-primary/80 shadow-md hover:shadow-lg border border-primary",
        
        // Destructive - red solid button
        destructive: "bg-destructive text-destructive-foreground hover:bg-destructive/90 active:bg-destructive/80 shadow-md border border-destructive",
        
        // Outline - visible border with background tint
        outline: "border-2 border-primary bg-background text-primary hover:bg-primary hover:text-primary-foreground active:bg-primary/90 shadow-sm",
        
        // Secondary - subtle but visible
        secondary: "bg-primary/20 text-primary hover:bg-primary/30 active:bg-primary/40 border border-primary/40 shadow-sm",
        
        // Ghost - subtle with visible hover
        ghost: "text-primary hover:bg-primary/15 active:bg-primary/25 border border-transparent hover:border-primary/30",
        
        // Link - text only
        link: "text-primary underline-offset-4 hover:underline shadow-none",
        
        // Gradient buttons - always visible
        gradient: "gradient-primary text-primary-foreground hover:opacity-90 active:opacity-80 shadow-md border border-primary/20",
        hero: "gradient-primary text-primary-foreground font-display font-bold text-base hover:opacity-90 active:opacity-80 shadow-lg border border-primary/20",
        
        // Semantic status variants
        success: "bg-success text-success-foreground hover:bg-success/90 active:bg-success/80 shadow-md border border-success",
        successOutline: "border-2 border-success bg-background text-success hover:bg-success hover:text-success-foreground shadow-sm",
        warning: "bg-warning text-warning-foreground hover:bg-warning/90 active:bg-warning/80 shadow-md border border-warning",
        info: "bg-info text-info-foreground hover:bg-info/90 active:bg-info/80 shadow-md border border-info",
        
        // Aurora themed variants - fully visible
        aurora: "gradient-aurora text-primary-foreground aurora-glow hover:opacity-95 active:opacity-85 shadow-lg border border-primary/20",
        auroraOutline: "border-2 border-primary bg-background text-primary hover:bg-primary hover:text-primary-foreground active:bg-primary/90 shadow-sm",
        auroraGhost: "bg-primary/15 text-primary hover:bg-primary/25 active:bg-primary/35 border border-primary/30 shadow-sm",
        auroraSoft: "bg-primary/25 text-primary border-2 border-primary/40 hover:bg-primary/35 active:bg-primary/45 shadow-sm",
        auroraHero: "gradient-aurora text-primary-foreground aurora-glow font-display font-bold hover:opacity-95 active:opacity-85 shadow-xl border border-primary/20",
      },
      size: {
        default: "h-11 px-6 py-2 min-h-[44px]",
        sm: "h-10 rounded-lg px-4 min-h-[40px]",
        lg: "h-14 rounded-2xl px-10 text-base min-h-[56px]",
        xl: "h-16 rounded-2xl px-12 text-lg min-h-[64px]",
        icon: "h-11 w-11 min-h-[44px] min-w-[44px]",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  },
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : "button";
    return <Comp className={cn(buttonVariants({ variant, size, className }))} ref={ref} {...props} />;
  },
);
Button.displayName = "Button";

export { Button, buttonVariants };
