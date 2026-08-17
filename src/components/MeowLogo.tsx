import { cn } from "@/lib/utils";

interface MeowLogoProps {
  className?: string;
  size?: "sm" | "md" | "lg";
}

const MeowLogo = ({ className, size = "md" }: MeowLogoProps) => {
  const sizeClasses = {
    sm: "w-12 h-12",
    md: "w-20 h-20",
    lg: "w-28 h-28",
  };

  return (
    <div className={cn("relative animate-float", sizeClasses[size], className)}>
      {/* Cat face */}
      <svg
        viewBox="0 0 100 100"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        className="w-full h-full drop-shadow-lg"
      >
        {/* Left ear */}
        <path
          d="M15 35 L25 5 L40 30 Z"
          className="fill-primary"
        />
        <path
          d="M20 30 L27 12 L36 28 Z"
          className="fill-primary-glow"
        />
        
        {/* Right ear */}
        <path
          d="M85 35 L75 5 L60 30 Z"
          className="fill-primary"
        />
        <path
          d="M80 30 L73 12 L64 28 Z"
          className="fill-primary-glow"
        />
        
        {/* Face */}
        <ellipse
          cx="50"
          cy="55"
          rx="38"
          ry="35"
          className="fill-primary"
        />
        
        {/* Inner face */}
        <ellipse
          cx="50"
          cy="58"
          rx="30"
          ry="28"
          className="fill-card"
        />
        
        {/* Left eye */}
        <ellipse
          cx="35"
          cy="50"
          rx="8"
          ry="10"
          className="fill-foreground"
        />
        <ellipse
          cx="36"
          cy="48"
          rx="3"
          ry="4"
          className="fill-background"
        />
        
        {/* Right eye */}
        <ellipse
          cx="65"
          cy="50"
          rx="8"
          ry="10"
          className="fill-foreground"
        />
        <ellipse
          cx="66"
          cy="48"
          rx="3"
          ry="4"
          className="fill-background"
        />
        
        {/* Nose */}
        <path
          d="M50 62 L46 68 L54 68 Z"
          className="fill-primary"
        />
        
        {/* Mouth */}
        <path
          d="M50 68 Q50 73 45 75"
          stroke="currentColor"
          strokeWidth="2"
          fill="none"
          className="stroke-foreground/60"
        />
        <path
          d="M50 68 Q50 73 55 75"
          stroke="currentColor"
          strokeWidth="2"
          fill="none"
          className="stroke-foreground/60"
        />
        
        {/* Whiskers */}
        <g className="stroke-foreground/40" strokeWidth="1.5">
          <line x1="25" y1="60" x2="5" y2="55" />
          <line x1="25" y1="65" x2="5" y2="65" />
          <line x1="25" y1="70" x2="5" y2="75" />
          <line x1="75" y1="60" x2="95" y2="55" />
          <line x1="75" y1="65" x2="95" y2="65" />
          <line x1="75" y1="70" x2="95" y2="75" />
        </g>

        {/* Heart on forehead */}
        <path
          d="M50 35 C50 32, 45 30, 45 34 C45 37, 50 40, 50 40 C50 40, 55 37, 55 34 C55 30, 50 32, 50 35"
          className="fill-destructive/80"
        />
      </svg>
    </div>
  );
};

export default MeowLogo;
