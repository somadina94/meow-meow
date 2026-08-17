import { memo } from "react";
import { cn } from "@/lib/utils";
import { usePresence } from "@/hooks/usePresence";
import {
  PRESENCE_DOT_CLASS,
  PRESENCE_TEXT_CLASS,
  type PresenceStatus,
} from "@/lib/presence";

interface PresenceDotProps {
  userId: string;
  /** Override status (e.g. typing from a chat-level signal) */
  status?: PresenceStatus;
  className?: string;
  /** Pulse for online/typing */
  pulse?: boolean;
}

/** Small colored dot — use next to avatars in lists. */
export const PresenceDot = memo<PresenceDotProps>(({ userId, status, className, pulse = true }) => {
  const p = usePresence(userId);
  const s = status ?? p.status;
  const dotClass = PRESENCE_DOT_CLASS[s];
  const animate = pulse && (s === "online" || s === "active" || s === "typing");
  return (
    <span
      className={cn(
        "inline-block h-2.5 w-2.5 rounded-full ring-2 ring-background",
        dotClass,
        animate && "animate-pulse",
        className
      )}
      aria-label={p.label}
      title={s === "offline" ? p.lastSeenLabel : p.label}
    />
  );
});
PresenceDot.displayName = "PresenceDot";

interface PresenceBadgeProps {
  userId: string;
  /** Override status (e.g. typing detected via a chat channel) */
  status?: PresenceStatus;
  /** Show "Last seen…" instead of "Offline" when user is offline */
  showLastSeen?: boolean;
  withDot?: boolean;
  className?: string;
}

/** Text label like "Active now", "Away", "Last seen 5 mins ago". */
export const PresenceBadge = memo<PresenceBadgeProps>(
  ({ userId, status, showLastSeen = true, withDot = true, className }) => {
    const p = usePresence(userId);
    const s = status ?? p.status;
    const label =
      s === "offline" && showLastSeen ? p.lastSeenLabel : (s === status ? labelFor(s) : p.label);
    return (
      <span
        className={cn(
          "inline-flex items-center gap-1.5 text-xs",
          PRESENCE_TEXT_CLASS[s],
          className
        )}
        aria-live="polite"
      >
        {withDot && (
          <span
            className={cn(
              "h-1.5 w-1.5 rounded-full",
              PRESENCE_DOT_CLASS[s],
              (s === "online" || s === "active" || s === "typing") && "animate-pulse"
            )}
          />
        )}
        <span className="truncate">{label}</span>
      </span>
    );
  }
);
PresenceBadge.displayName = "PresenceBadge";

function labelFor(s: PresenceStatus): string {
  switch (s) {
    case "online": return "Online";
    case "active": return "Active now";
    case "typing": return "Typing…";
    case "away": return "Away";
    case "busy": return "Busy";
    case "in_call": return "In call";
    case "offline": return "Offline";
  }
}
