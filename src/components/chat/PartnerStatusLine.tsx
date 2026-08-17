import { memo } from "react";
import { cn } from "@/lib/utils";
import type { PartnerPresenceState } from "@/hooks/useChatPresence";

interface PartnerStatusLineProps {
  state: PartnerPresenceState;
  partnerName: string;
  lastSeen: Date | null;
  /** Fallback online flag from parent (DB-driven). Used only when realtime presence shows offline. */
  fallbackOnline?: boolean;
  className?: string;
}

const formatLastSeen = (d: Date | null) => {
  if (!d) return "";
  const diffSec = Math.max(1, Math.floor((Date.now() - d.getTime()) / 1000));
  if (diffSec < 60) return "just now";
  const diffMin = Math.floor(diffSec / 60);
  if (diffMin < 60) return `${diffMin}m ago`;
  const diffHr = Math.floor(diffMin / 60);
  if (diffHr < 24) return `${diffHr}h ago`;
  return d.toLocaleDateString();
};

/**
 * Compact one-line partner status, WhatsApp-style:
 *   - Connecting…
 *   - typing…              (italic, primary color)
 *   - in chat with you     (primary color, dot pulse)
 *   - online               (green)
 *   - left the chat · 2m ago (muted)
 *   - last seen 5m ago     (muted)
 *   - offline              (muted)
 */
export const PartnerStatusLine = memo<PartnerStatusLineProps>(
  ({ state, partnerName, lastSeen, fallbackOnline, className }) => {
    let label = "";
    let tone: "primary" | "online" | "muted" | "warn" = "muted";
    let pulse = false;

    switch (state) {
      case "connecting":
        label = "connecting…";
        tone = "muted";
        break;
      case "typing":
        label = "typing…";
        tone = "primary";
        pulse = true;
        break;
      case "in_chat":
        label = "in chat with you";
        tone = "primary";
        pulse = true;
        break;
      case "online_away":
        label = "online";
        tone = "online";
        break;
      case "left_chat":
        label = `left the chat${lastSeen ? ` · ${formatLastSeen(lastSeen)}` : ""}`;
        tone = "warn";
        break;
      case "offline":
      default:
        if (fallbackOnline) {
          label = "online";
          tone = "online";
        } else {
          label = lastSeen ? `last seen ${formatLastSeen(lastSeen)}` : "offline";
          tone = "muted";
        }
        break;
    }

    return (
      <div
        className={cn(
          "flex items-center gap-1 text-[10px] leading-tight truncate",
          tone === "primary" && "text-primary",
          tone === "online" && "text-online",
          tone === "warn" && "text-warning",
          tone === "muted" && "text-muted-foreground",
          className
        )}
        aria-live="polite"
        aria-label={`${partnerName} ${label}`}
      >
        {pulse && (
          <span className="relative inline-flex h-1.5 w-1.5 flex-shrink-0">
            <span className="absolute inline-flex h-full w-full rounded-full bg-current opacity-60 animate-ping" />
            <span className="relative inline-flex h-1.5 w-1.5 rounded-full bg-current" />
          </span>
        )}
        <span className="truncate italic">{label}</span>
      </div>
    );
  }
);

PartnerStatusLine.displayName = "PartnerStatusLine";
