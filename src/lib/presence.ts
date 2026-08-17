/**
 * Unified presence model.
 *
 * Single source of truth for deriving a user's display status from the
 * real `user_status` row (no fake users, no simulated activity).
 */

export type PresenceStatus =
  | "online"        // app open, last_seen < 60s
  | "active"        // last_seen < 2m
  | "typing"        // ephemeral; only set per-chat
  | "away"          // online flag true but last_seen ≥ 5m
  | "busy"          // manual busy
  | "in_call"       // active_call_count > 0
  | "offline";      // is_online=false or last_seen expired

export interface UserStatusRow {
  user_id: string;
  is_online: boolean | null;
  last_seen: string | null;
  status: string | null;             // 'available' | 'busy' | ...
  status_text?: string | null;
  active_call_count?: number | null;
  active_chat_count?: number | null;
}

/** Heartbeat window — below this, user is considered actively connected. */
const ONLINE_WINDOW_MS = 60 * 1000;
const ACTIVE_WINDOW_MS = 2 * 60 * 1000;
const AWAY_WINDOW_MS = 5 * 60 * 1000;
/** After this, even a stale is_online=true row is treated as offline. */
const STALE_WINDOW_MS = 10 * 60 * 1000;

export function derivePresence(
  row: UserStatusRow | null | undefined,
  opts?: { isTyping?: boolean; now?: number }
): { status: PresenceStatus; lastSeen: Date | null } {
  const now = opts?.now ?? Date.now();
  if (!row) return { status: "offline", lastSeen: null };

  const lastSeen = row.last_seen ? new Date(row.last_seen) : null;
  const age = lastSeen ? now - lastSeen.getTime() : Infinity;

  if (opts?.isTyping) return { status: "typing", lastSeen };
  if ((row.active_call_count ?? 0) > 0) return { status: "in_call", lastSeen };
  if (row.status === "busy") return { status: "busy", lastSeen };

  if (!row.is_online || age > STALE_WINDOW_MS) {
    return { status: "offline", lastSeen };
  }
  if (age <= ONLINE_WINDOW_MS) return { status: "online", lastSeen };
  if (age <= ACTIVE_WINDOW_MS) return { status: "active", lastSeen };
  if (age <= AWAY_WINDOW_MS) return { status: "online", lastSeen };
  return { status: "away", lastSeen };
}

export const PRESENCE_LABEL: Record<PresenceStatus, string> = {
  online: "Online",
  active: "Active now",
  typing: "Typing…",
  away: "Away",
  busy: "Busy",
  in_call: "In call",
  offline: "Offline",
};

/** WhatsApp-style "last seen" formatter. */
export function formatLastSeen(d: Date | null, now: number = Date.now()): string {
  if (!d) return "Offline";
  const diffSec = Math.max(1, Math.floor((now - d.getTime()) / 1000));
  if (diffSec < 60) return "Last seen just now";
  const diffMin = Math.floor(diffSec / 60);
  if (diffMin < 60) return `Last seen ${diffMin} min${diffMin === 1 ? "" : "s"} ago`;

  const seen = new Date(d);
  const today = new Date(now);
  const yesterday = new Date(now); yesterday.setDate(yesterday.getDate() - 1);
  const sameDay = (a: Date, b: Date) =>
    a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();

  const time = seen.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
  if (sameDay(seen, today)) return `Last seen today at ${time}`;
  if (sameDay(seen, yesterday)) return `Last seen yesterday at ${time}`;
  return `Last seen ${seen.toLocaleDateString()} at ${time}`;
}

/**
 * True when a user_status realtime event should refresh online lists.
 * Heartbeats only bump last_seen; those must not remount the Online tab.
 */
export function isVisibilityStatusChange(
  payload: { eventType?: string; new?: Record<string, unknown>; old?: Record<string, unknown> },
  snapshot: Map<string, string>
): boolean {
  const event = payload.eventType;
  const row = (payload.new || payload.old) as
    | { user_id?: string; is_online?: boolean | null; status_text?: string | null }
    | undefined;
  const userId = row?.user_id;
  if (!userId) return true;

  if (event === "DELETE") {
    snapshot.delete(userId);
    return true;
  }

  const key = `${row.is_online ? "1" : "0"}:${row.status_text ?? ""}`;
  if (snapshot.get(userId) === key) return false;
  snapshot.set(userId, key);
  return true;
}

/** Tailwind semantic dot color for each status. */
export const PRESENCE_DOT_CLASS: Record<PresenceStatus, string> = {
  online: "bg-online",
  active: "bg-online",
  typing: "bg-primary",
  away: "bg-warning",
  busy: "bg-destructive",
  in_call: "bg-destructive",
  offline: "bg-muted-foreground/50",
};

export const PRESENCE_TEXT_CLASS: Record<PresenceStatus, string> = {
  online: "text-online",
  active: "text-online",
  typing: "text-primary",
  away: "text-warning",
  busy: "text-destructive",
  in_call: "text-destructive",
  offline: "text-muted-foreground",
};
