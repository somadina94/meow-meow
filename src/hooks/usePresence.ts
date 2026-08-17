import { useEffect, useState, useMemo } from "react";
import { supabase } from "@/integrations/supabase/client";
import {
  derivePresence,
  formatLastSeen,
  PRESENCE_LABEL,
  type PresenceStatus,
  type UserStatusRow,
} from "@/lib/presence";

const COLUMNS = "user_id,is_online,last_seen,status,status_text,active_call_count,active_chat_count";

interface PresenceResult {
  status: PresenceStatus;
  lastSeen: Date | null;
  label: string;
  lastSeenLabel: string;
  row: UserStatusRow | null;
}

interface UsePresenceOptions {
  /** When false, fetch once and skip realtime (history lists, etc.). Default true. */
  realtime?: boolean;
}

function uniqueTopic(prefix: string): string {
  return `${prefix}:${Math.random().toString(36).slice(2, 10)}`;
}

/**
 * Subscribe to ONE user's real presence row.
 * Never returns fabricated state — if no row exists, status is "offline".
 *
 * Channel names are unique per hook instance. Reusing `presence:user:<id>`
 * crashes supabase-js: "cannot add postgres_changes callbacks after subscribe()".
 */
export function usePresence(
  userId: string | null | undefined,
  isTyping = false,
  options?: UsePresenceOptions
): PresenceResult {
  const realtime = options?.realtime !== false;
  const [row, setRow] = useState<UserStatusRow | null>(null);
  const [tick, setTick] = useState(0);

  useEffect(() => {
    if (!userId) { setRow(null); return; }
    let cancelled = false;
    let channel: ReturnType<typeof supabase.channel> | null = null;

    supabase
      .from("user_status")
      .select(COLUMNS)
      .eq("user_id", userId)
      .maybeSingle()
      .then(({ data }) => { if (!cancelled) setRow((data as UserStatusRow) ?? null); });

    if (realtime) {
      try {
        channel = supabase
          .channel(uniqueTopic(`presence:user:${userId}`))
          .on(
            "postgres_changes",
            { event: "*", schema: "public", table: "user_status", filter: `user_id=eq.${userId}` },
            (payload) => {
              if (cancelled) return;
              if (payload.eventType === "DELETE") setRow(null);
              else setRow((payload.new as UserStatusRow) ?? null);
            }
          );
        channel.subscribe();
      } catch (err) {
        console.warn("[usePresence] realtime subscribe skipped:", err);
      }
    }

    const interval = setInterval(() => setTick((t) => t + 1), 30_000);

    return () => {
      cancelled = true;
      clearInterval(interval);
      if (channel) void supabase.removeChannel(channel);
    };
  }, [userId, realtime]);

  return useMemo(() => {
    const { status, lastSeen } = derivePresence(row, { isTyping });
    return {
      status,
      lastSeen,
      label: PRESENCE_LABEL[status],
      lastSeenLabel: formatLastSeen(lastSeen),
      row,
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [row, isTyping, tick]);
}

/**
 * Subscribe to many users at once (online lists, matches, groups).
 * Returns a map keyed by user_id. Missing users are simply absent (no ghosts).
 */
export function usePresenceMap(userIds: string[]): Record<string, PresenceResult> {
  const [rows, setRows] = useState<Record<string, UserStatusRow>>({});
  const [tick, setTick] = useState(0);

  const key = useMemo(() => [...new Set(userIds)].sort().join(","), [userIds]);

  useEffect(() => {
    const ids = key ? key.split(",").filter(Boolean) : [];
    if (ids.length === 0) { setRows({}); return; }
    let cancelled = false;
    let channel: ReturnType<typeof supabase.channel> | null = null;

    supabase
      .from("user_status")
      .select(COLUMNS)
      .in("user_id", ids)
      .then(({ data }) => {
        if (cancelled || !data) return;
        const map: Record<string, UserStatusRow> = {};
        for (const r of data as UserStatusRow[]) map[r.user_id] = r;
        setRows(map);
      });

    try {
      channel = supabase
        .channel(uniqueTopic(`presence:map:${ids.length}`))
        .on(
          "postgres_changes",
          { event: "*", schema: "public", table: "user_status" },
          (payload) => {
            if (cancelled) return;
            const next = (payload.new as UserStatusRow) ?? (payload.old as UserStatusRow);
            if (!next || !ids.includes(next.user_id)) return;
            setRows((prev) => {
              if (payload.eventType === "DELETE") {
                const copy = { ...prev }; delete copy[next.user_id]; return copy;
              }
              return { ...prev, [next.user_id]: next };
            });
          }
        );
      channel.subscribe();
    } catch (err) {
      console.warn("[usePresenceMap] realtime subscribe skipped:", err);
    }

    const interval = setInterval(() => setTick((t) => t + 1), 30_000);

    return () => {
      cancelled = true;
      clearInterval(interval);
      if (channel) void supabase.removeChannel(channel);
    };
  }, [key]);

  return useMemo(() => {
    const out: Record<string, PresenceResult> = {};
    for (const [uid, row] of Object.entries(rows)) {
      const { status, lastSeen } = derivePresence(row);
      out[uid] = {
        status, lastSeen,
        label: PRESENCE_LABEL[status],
        lastSeenLabel: formatLastSeen(lastSeen),
        row,
      };
    }
    return out;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [rows, tick]);
}
