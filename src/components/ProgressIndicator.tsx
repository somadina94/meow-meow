import { cn } from "@/lib/utils";

interface ProgressIndicatorProps {
  currentStep: number;
  totalSteps: number;
  className?: string;
}

const ProgressIndicator = ({ currentStep, totalSteps, className }: ProgressIndicatorProps) => {
  return (
    <div className={cn("flex items-center gap-2", className)}>
      {Array.from({ length: totalSteps }, (_, i) => (
        <div
          key={i}
          className={cn(
            "h-2 rounded-full transition-all duration-500",
            i < currentStep
              ? "w-8 gradient-primary"
              : i === currentStep
              ? "w-8 bg-primary/40"
              : "w-2 bg-muted"
          )}
        />
      ))}
    </div>
  );
};

export default ProgressIndicator;
