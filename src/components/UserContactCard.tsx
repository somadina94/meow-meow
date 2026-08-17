import React from "react";
import { Avatar, AvatarImage, AvatarFallback } from "@/components/ui/avatar";
import { cn } from "@/lib/utils";
import { Crown } from "lucide-react";
import { usePresence } from "@/hooks/usePresence";
import { PRESENCE_TEXT_CLASS, PRESENCE_DOT_CLASS, PRESENCE_LABEL, type PresenceStatus } from "@/lib/presence";

interface UserContactCardProps {
  /** User id — when provided, real-time presence status is shown */
  userId?: string;
  name: string;
  photoUrl?: string | null;
  age?: number | null;
  language?: string | null;
  country?: string | null;
  state?: string | null;
  /** Fallback online flag if userId not provided */
  isOnline?: boolean;
  /** Active chat count badge (0-3) */
  activeChatCount?: number;
  /** Is premium user (wallet > 0) */
  isPremium?: boolean;
  /** Wallet balance (shown for women viewing men) */
  walletBalance?: number;
  /** Optional override status (e.g. "in_group") */
  statusOverride?: PresenceStatus;
  /** Whether this user is currently typing in chat with viewer */
  isTyping?: boolean;
  /** Subtitle text (e.g. user code) */
  subtitle?: string;
  /** Right-side action area */
  actions?: React.ReactNode;
  onClick?: () => void;
  onDoubleClick?: () => void;
  className?: string;
}

const COUNTRY_LABEL: Record<string, string> = {
  IN: "India", US: "USA", GB: "UK", CA: "Canada", AU: "Australia", AE: "UAE", SG: "Singapore",
};

function statusDisplay(status: PresenceStatus, lastSeen: Date | null): string {
  if (status === "away" && lastSeen) {
    const mins = Math.max(1, Math.floor((Date.now() - lastSeen.getTime()) / 60000));
    return `Away ${mins} min${mins === 1 ? "" : "s"} ago`;
  }
  if (status === "offline" && lastSeen) {
    const mins = Math.floor((Date.now() - lastSeen.getTime()) / 60000);
    if (mins < 60) return `Last seen ${Math.max(1, mins)} min${mins === 1 ? "" : "s"} ago`;
    const hrs = Math.floor(mins / 60);
    if (hrs < 24) return `Last seen ${hrs} hr${hrs === 1 ? "" : "s"} ago`;
    return `Last seen ${Math.floor(hrs / 24)}d ago`;
  }
  return PRESENCE_LABEL[status];
}

export const UserContactCard: React.FC<UserContactCardProps> = ({
  userId,
  name,
  photoUrl,
  age,
  language,
  country,
  state,
  isOnline = true,
  activeChatCount,
  isPremium,
  walletBalance,
  statusOverride,
  isTyping,
  subtitle,
  actions,
  onClick,
  onDoubleClick,
  className,
}) => {
  const presence = usePresence(userId, isTyping);
  const status: PresenceStatus = statusOverride
    ?? (userId ? presence.status : isOnline ? "online" : "offline");
  const lastSeen = userId ? presence.lastSeen : null;
  const statusText = statusDisplay(status, lastSeen);
  const countryLabel = country ? (COUNTRY_LABEL[country] ?? country) : null;

  // Build the dotted segments
  const segments: React.ReactNode[] = [
    <span key="name" className="font-semibold text-foreground truncate">{name}</span>,
  ];
  if (age) segments.push(<span key="age">{age}</span>);
  if (language) segments.push(<span key="lang">{language}</span>);
  if (state) segments.push(<span key="loc">{state}</span>);
  if (countryLabel) segments.push(<span key="ctry">{countryLabel}</span>);
  segments.push(
    <span key="status" className={cn("font-medium inline-flex items-center gap-1", PRESENCE_TEXT_CLASS[status])}>
      <span className={cn("w-1.5 h-1.5 rounded-full", PRESENCE_DOT_CLASS[status])} />
      {statusText}
    </span>
  );

  return (
    <div
      className={cn(
        "flex items-center gap-3 px-4 py-3 hover:bg-muted/50 active:bg-muted/70 transition-colors cursor-pointer border-b border-border/30 select-none",
        className
      )}
      onClick={onClick}
      onDoubleClick={onDoubleClick}
    >
      {/* Avatar with status dot */}
      <div className="relative flex-shrink-0">
        <Avatar className="h-12 w-12 border-2 border-background shadow-sm">
          <AvatarImage src={photoUrl || undefined} alt={name} />
          <AvatarFallback className="bg-gradient-to-br from-primary to-primary/60 text-primary-foreground text-sm font-semibold">
            {name.charAt(0).toUpperCase()}
          </AvatarFallback>
        </Avatar>
        {activeChatCount !== undefined && activeChatCount > 0 ? (
          <div
            className={cn(
              "absolute -bottom-0.5 -right-0.5 w-4 h-4 rounded-full border-2 border-background flex items-center justify-center text-[8px] font-bold",
              activeChatCount >= 3 ? "bg-destructive text-destructive-foreground" : "bg-amber-500 text-white"
            )}
          >
            {activeChatCount}
          </div>
        ) : (
          <div className={cn(
            "absolute -bottom-0.5 -right-0.5 w-3.5 h-3.5 rounded-full border-2 border-background",
            PRESENCE_DOT_CLASS[status]
          )} />
        )}
        {isPremium && (
          <div className="absolute -top-1 -left-1">
            <Crown className="h-3.5 w-3.5 text-primary fill-primary/30" />
          </div>
        )}
      </div>

      {/* Content */}
      <div className="flex-1 min-w-0">
        <div className="flex flex-wrap items-center gap-x-1.5 gap-y-0.5 text-xs text-muted-foreground">
          {segments.map((seg, i) => (
            <React.Fragment key={i}>
              {i > 0 && <span className="text-muted-foreground/50">•</span>}
              {seg}
            </React.Fragment>
          ))}
        </div>
        {(subtitle || walletBalance !== undefined) && (
          <div className="flex items-center gap-2 mt-0.5 text-[11px] text-muted-foreground truncate">
            {subtitle && <span className="truncate">{subtitle}</span>}
            {walletBalance !== undefined && (
              <span className={cn("font-semibold", walletBalance > 0 ? "text-primary" : "text-muted-foreground")}>
                ₹{Math.round(walletBalance).toLocaleString("en-IN")}
              </span>
            )}
          </div>
        )}
      </div>

      {/* Actions */}
      {actions && (
        <div className="flex items-center gap-1 flex-shrink-0" onClick={(e) => e.stopPropagation()}>
          {actions}
        </div>
      )}
    </div>
  );
};

export default UserContactCard;
