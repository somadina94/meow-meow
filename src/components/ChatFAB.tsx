import React from "react";
import { cn } from "@/lib/utils";
import { MessageCircle } from "lucide-react";

interface ChatFABProps {
  onClick: () => void;
  icon?: React.ReactNode;
  badge?: number;
  className?: string;
}

export const ChatFAB: React.FC<ChatFABProps> = ({
  onClick,
  icon,
  badge,
  className,
}) => {
  return (
    <button
      onClick={onClick}
      className={cn(
        "fixed bottom-20 right-4 z-40 w-14 h-14 rounded-full bg-primary text-primary-foreground",
        "shadow-lg hover:shadow-xl active:scale-95 transition-all duration-200",
        "flex items-center justify-center",
        className
      )}
      aria-label="New action"
    >
      {icon || <MessageCircle className="w-6 h-6" />}
      {badge !== undefined && badge > 0 && (
        <span className="absolute -top-1 -right-1 min-w-[20px] h-[20px] rounded-full bg-destructive text-destructive-foreground text-[10px] font-bold flex items-center justify-center px-1">
          {badge > 9 ? "9+" : badge}
        </span>
      )}
    </button>
  );
};

export default ChatFAB;
