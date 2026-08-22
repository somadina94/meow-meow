/**
 * useGroupChat — hooks for live women-hosted group chat rooms.
 * Pairs with migration 20260615 tables: group_chat_rooms / _sessions / _participants / _messages
 * Billing: ₹2/min man, ₹1/min host per active man, ₹1/min platform (only when men are present).
 */
import { useCallback, useEffect, useRef, useState } from "react";
import { supabase } from "@/integrations/supabase/client";

export interface GroupChatRoom {
  id: string;
  name: string;
  tree_type: string;
  variant_number: number;
  max_users: number;
  status: "offline" | "live";
  current_host_id: string | null;
  current_session_id: string | null;
  current_participant_count: number;
  host_name?: string | null;
}

export interface GroupChatMessage {
  id: string;
  session_id: string;
  sender_id: string;
  sender_name: string | null;
  sender_gender: string | null;
  body: string | null;
  media_url: string | null;
  media_type: string | null;
  media_thumbnail?: string | null;
  voice_duration_seconds?: number | null;
  reply_to: string | null;
  pinned: boolean;
  edited_at: string | null;
  deleted_at: string | null;
  original_lang?: string | null;
  transliteration?: string | null;
  english_translation?: string | null;
  created_at: string;
}

export interface GroupChatParticipantInfo {
  user_id: string;
  joined_at: string;
  full_name?: string | null;
  photo_url?: string | null;
  gender?: string | null;
  is_host?: boolean;
  total_billed?: number;
  last_billed_minute?: number;
}

export const MAN_GROUP_CHAT_RATE = 2;
export const HOST_GROUP_CHAT_RATE_PER_MAN = 1;

function isEngagementMessage(m: GroupChatMessage, hostId: string, maleUserIds: string[]): boolean {
  const fromHost = m.sender_id === hostId;
  const fromMan = maleUserIds.includes(m.sender_id)
    || ((m.sender_gender || "").toLowerCase() === "male" && m.sender_id !== hostId);
  if (!fromHost && !fromMan) return false;
  const b = (m.body || "").trim();
  if (b.length > 0 && !b.startsWith("👋")) return true;
  return !!(m.media_url && m.media_url.trim());
}

/** Active men — participants first; fall back to male senders while participant rows load. */
export function groupChatActiveMen(
  participants: GroupChatParticipantInfo[],
  hostId: string,
  messages: GroupChatMessage[] = [],
): GroupChatParticipantInfo[] {
  const fromParts = participants.filter((p) => p.user_id !== hostId && !p.is_host);
  if (fromParts.length > 0) return fromParts;

  const manIds = new Set<string>();
  for (const m of messages) {
    if (m.sender_id === hostId) continue;
    if ((m.sender_gender || "").toLowerCase() === "male") manIds.add(m.sender_id);
  }
  return Array.from(manIds).map((user_id) => ({
    user_id,
    joined_at: new Date().toISOString(),
  }));
}

export function groupChatMaleUserIds(
  participants: GroupChatParticipantInfo[],
  hostId: string,
  messages: GroupChatMessage[],
): string[] {
  const ids = new Set(groupChatActiveMen(participants, hostId, messages).map((m) => m.user_id));
  for (const m of messages) {
    if (m.sender_id !== hostId && (m.sender_gender || "").toLowerCase() === "male") {
      ids.add(m.sender_id);
    }
  }
  return Array.from(ids);
}

/** Billing starts once the host and at least one man have sent a real message. */
export function groupChatBothEngaged(
  messages: GroupChatMessage[],
  hostId: string,
  maleUserIds: string[],
): boolean {
  if (maleUserIds.length === 0) return false;
  const hostSent = messages.some((m) => m.sender_id === hostId && isEngagementMessage(m, hostId, maleUserIds));
  const manSent = messages.some(
    (m) => maleUserIds.includes(m.sender_id) && isEngagementMessage(m, hostId, maleUserIds),
  );
  return hostSent && manSent;
}

export function dispatchWalletRefresh() {
  if (typeof window !== "undefined") {
    window.dispatchEvent(new CustomEvent("meow:wallet-refresh"));
  }
}


export function useGroupChatRooms(opts?: { onlyLive?: boolean }) {
  const [rooms, setRooms] = useState<GroupChatRoom[]>([]);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    let q = supabase
      .from("group_chat_rooms")
      .select("*")
      .order("status", { ascending: false })
      .order("current_participant_count", { ascending: false })
      .order("tree_type")
      .order("variant_number");
    if (opts?.onlyLive) q = q.eq("status", "live");
    const { data } = await q;
    const list = (data ?? []) as GroupChatRoom[];
    const hostIds = Array.from(new Set(list.map((r) => r.current_host_id).filter(Boolean))) as string[];
    if (hostIds.length > 0) {
      const { data: profs } = await supabase
        .from("profiles")
        .select("user_id, full_name")
        .in("user_id", hostIds);
      const names = new Map((profs ?? []).map((p: { user_id: string; full_name: string | null }) => [p.user_id, p.full_name]));
      for (const r of list) {
        r.host_name = r.current_host_id ? names.get(r.current_host_id) ?? null : null;
      }
    }
    setRooms(list);
    setLoading(false);
  }, [opts?.onlyLive]);

  useEffect(() => {
    load();
    const ch = supabase
      .channel(`group_chat_rooms_changes:${Math.random().toString(36).slice(2, 8)}`)
      .on("postgres_changes", { event: "*", schema: "public", table: "group_chat_rooms" }, () => load())
      .subscribe();
    return () => { supabase.removeChannel(ch); };
  }, [load]);

  return { rooms, loading, reload: load };
}

export function useGroupChatRoom(sessionId: string | null, hostId?: string | null) {
  const [messages, setMessages] = useState<GroupChatMessage[]>([]);
  const [participants, setParticipants] = useState<GroupChatParticipantInfo[]>([]);
  const [sessionHostEarning, setSessionHostEarning] = useState(0);

  const enrich = useCallback(async (rows: {
    user_id: string;
    joined_at: string;
    total_billed?: number;
    last_billed_minute?: number;
  }[]) => {
    if (!rows.length) return [] as GroupChatParticipantInfo[];
    const ids = Array.from(new Set(rows.map(r => r.user_id)));
    const { data: profs } = await supabase
      .from("profiles")
      .select("user_id, full_name, photo_url, gender")
      .in("user_id", ids);
    const byId = new Map((profs ?? []).map((p: any) => [p.user_id, p]));
    return rows.map(r => {
      const p = byId.get(r.user_id) || {};
      return {
        user_id: r.user_id,
        joined_at: r.joined_at,
        full_name: (p as any).full_name ?? null,
        photo_url: (p as any).photo_url ?? null,
        gender: (p as any).gender ?? null,
        is_host: hostId ? r.user_id === hostId : false,
        total_billed: Number(r.total_billed) || 0,
        last_billed_minute: Number(r.last_billed_minute) || 0,
      } as GroupChatParticipantInfo;
    });
  }, [hostId]);

  const reloadParticipants = useCallback(async () => {
    if (!sessionId) return;
    const { data } = await supabase
      .from("group_chat_participants")
      .select("user_id, joined_at, total_billed, last_billed_minute")
      .eq("session_id", sessionId)
      .is("left_at", null);
    setParticipants(await enrich(data ?? []));
  }, [sessionId, enrich]);

  const reloadSessionStats = useCallback(async () => {
    if (!sessionId) return;
    const { data } = await supabase
      .from("group_chat_sessions")
      .select("total_host_earning")
      .eq("id", sessionId)
      .maybeSingle();
    setSessionHostEarning(Number(data?.total_host_earning) || 0);
  }, [sessionId]);

  useEffect(() => {
    if (!sessionId) return;
    let alive = true;
    (async () => {
      const { data: msgs } = await supabase
        .from("group_chat_messages")
        .select("*")
        .eq("session_id", sessionId)
        .is("deleted_at", null)
        .order("created_at", { ascending: true })
        .limit(500);
      if (alive) setMessages((msgs ?? []) as GroupChatMessage[]);

      const { data: parts } = await supabase
        .from("group_chat_participants")
        .select("user_id, joined_at, total_billed, last_billed_minute")
        .eq("session_id", sessionId)
        .is("left_at", null);
      if (alive) setParticipants(await enrich(parts ?? []));

      const { data: sess } = await supabase
        .from("group_chat_sessions")
        .select("total_host_earning")
        .eq("id", sessionId)
        .maybeSingle();
      if (alive) setSessionHostEarning(Number(sess?.total_host_earning) || 0);
    })();

    const ch = supabase
      .channel(`gc_session_${sessionId}:${Math.random().toString(36).slice(2, 8)}`)
      .on("postgres_changes",
        { event: "INSERT", schema: "public", table: "group_chat_messages", filter: `session_id=eq.${sessionId}` },
        (p) => setMessages((m) => [...m, p.new as GroupChatMessage]))
      .on("postgres_changes",
        { event: "UPDATE", schema: "public", table: "group_chat_messages", filter: `session_id=eq.${sessionId}` },
        (p) => {
          const updated = p.new as GroupChatMessage;
          setMessages((m) => m.map((x) => (x.id === updated.id ? updated : x)));
        })
      .on("postgres_changes",
        { event: "*", schema: "public", table: "group_chat_participants", filter: `session_id=eq.${sessionId}` },
        async () => {
          const { data } = await supabase
            .from("group_chat_participants")
            .select("user_id, joined_at, total_billed, last_billed_minute")
            .eq("session_id", sessionId)
            .is("left_at", null);
          setParticipants(await enrich(data ?? []));
        })
      .on("postgres_changes",
        { event: "UPDATE", schema: "public", table: "group_chat_sessions", filter: `id=eq.${sessionId}` },
        (p) => {
          const row = p.new as { total_host_earning?: number };
          setSessionHostEarning(Number(row.total_host_earning) || 0);
        })
      .subscribe();

    return () => { alive = false; supabase.removeChannel(ch); };
  }, [sessionId, enrich]);

  return { messages, participants, sessionHostEarning, reloadParticipants, reloadSessionStats };
}

type GroupChatBillResult = {
  success?: boolean;
  insufficient?: boolean;
  skipped?: string;
  duplicate?: boolean;
  duplicate_skipped?: boolean;
  minute?: number;
  charged?: number;
  earned?: number;
  error?: string;
  balance?: number;
};

export async function billGroupChatMinute(
  sessionId: string,
  manId: string,
): Promise<GroupChatBillResult | null> {
  const { data, error } = await supabase.rpc("bill_group_chat_minute", {
    p_session_id: sessionId,
    p_man_id: manId,
  });
  if (error) {
    console.error("[group-chat billing] RPC error", error.message);
    return { success: false, error: error.message };
  }
  return (data as GroupChatBillResult | null) ?? { success: false, error: "empty response" };
}

export async function billGroupChatLeftover(sessionId: string, manId: string) {
  const { data, error } = await supabase.rpc("bill_group_chat_leftover", {
    p_session_id: sessionId,
    p_man_id: manId,
  });
  if (error) console.warn("[group-chat billing] leftover error", error.message);
  return data as GroupChatBillResult | null;
}

/** Host drives billing for every active man; each man also self-bills as a fallback (idempotent RPC). */
export function useGroupChatBilling(params: {
  sessionId: string | null;
  hostId: string | null;
  currentUserId: string | null;
  isHost: boolean;
  isMan: boolean;
  bothEngaged: boolean;
  activeMen: GroupChatParticipantInfo[];
  onInsufficient: (manId: string) => void;
  onBilled?: (result: GroupChatBillResult) => void;
  onBillingSkip?: (reason: string) => void;
  onWalletUpdated?: () => void;
}) {
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const [minutesBilled, setMinutesBilled] = useState(0);
  const [isBilling, setIsBilling] = useState(false);
  const [skipReason, setSkipReason] = useState<string | null>(null);

  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const startRef = useRef<number | null>(null);
  const billedRef = useRef(0);
  const inFlightRef = useRef(false);
  const sessionIdRef = useRef(params.sessionId);
  const hostIdRef = useRef(params.hostId);
  const activeMenRef = useRef(params.activeMen);
  const onInsufficientRef = useRef(params.onInsufficient);
  const onBilledRef = useRef(params.onBilled);
  const onBillingSkipRef = useRef(params.onBillingSkip);
  const onWalletUpdatedRef = useRef(params.onWalletUpdated);

  sessionIdRef.current = params.sessionId;
  hostIdRef.current = params.hostId;
  activeMenRef.current = params.activeMen;
  onInsufficientRef.current = params.onInsufficient;
  onBilledRef.current = params.onBilled;
  onBillingSkipRef.current = params.onBillingSkip;
  onWalletUpdatedRef.current = params.onWalletUpdated;

  const activeMenCount = params.activeMen.length;
  // Start timer when a man is in the room; server skips charges until mutual engagement.
  const billingActive = activeMenCount > 0;
  const shouldRun = billingActive && !!params.sessionId && (params.isHost || params.isMan);

  const stopInterval = useCallback(() => {
    if (intervalRef.current) {
      clearInterval(intervalRef.current);
      intervalRef.current = null;
    }
  }, []);

  const billMan = useCallback(async (manId: string, reason: string) => {
    const sid = sessionIdRef.current;
    if (!sid) return;
    const r = await billGroupChatMinute(sid, manId);
    if (!r) return;

    if (r.skipped === "admin" || r.skipped === "not_male" || r.skipped === "host_not_billable") {
      setSkipReason(r.skipped);
      onBillingSkipRef.current?.(r.skipped);
      console.info("[group-chat billing] skipped", r.skipped, manId);
      return;
    }
    if (r.skipped === "waiting_for_replies") {
      setSkipReason("waiting_for_replies");
      return;
    }
    if (r.skipped === "no_active_men" || r.skipped === "man_left" || r.skipped === "not_live" || r.skipped === "host_not_live") {
      console.info("[group-chat billing] transient skip", r.skipped);
      return;
    }

    if (r.duplicate || r.duplicate_skipped) return;

    if (r.success === false) {
      if (r.insufficient || (r.error && /insufficient/i.test(r.error))) {
        onInsufficientRef.current(manId);
        return;
      }
      if (r.error) {
        console.error("[group-chat billing] failed", reason, manId, r.error);
        setSkipReason(r.error);
        onBillingSkipRef.current?.(r.error);
      }
      return;
    }

    if (r.success) {
      setSkipReason(null);
      console.info("[group-chat billing] charged", reason, manId, r);
      onBilledRef.current?.(r);
      onWalletUpdatedRef.current?.();
      dispatchWalletRefresh();
    }
  }, []);

  const billDueMinute = useCallback(async (minuteIndex: number) => {
    if (inFlightRef.current) return;
    inFlightRef.current = true;
    try {
      const sid = sessionIdRef.current;
      if (!sid) return;

      const { data: session } = await supabase
        .from("group_chat_sessions")
        .select("ended_at")
        .eq("id", sid)
        .maybeSingle();
      if (session?.ended_at) return;

      const men = activeMenRef.current;
      if (params.isHost) {
        await Promise.all(men.map((m) => billMan(m.user_id, `host minute ${minuteIndex}`)));
      } else if (params.isMan && params.currentUserId) {
        await billMan(params.currentUserId, `man minute ${minuteIndex}`);
      }
    } finally {
      inFlightRef.current = false;
    }
  }, [billMan, params.isHost, params.isMan, params.currentUserId]);

  const billDueMinuteRef = useRef(billDueMinute);
  billDueMinuteRef.current = billDueMinute;

  useEffect(() => {
    if (!shouldRun) {
      stopInterval();
      startRef.current = null;
      billedRef.current = 0;
      setElapsedSeconds(0);
      setMinutesBilled(0);
      setIsBilling(false);
      return;
    }

    if (intervalRef.current) {
      setIsBilling(true);
      return;
    }

    billedRef.current = 0;
    const start = Date.now();
    startRef.current = start;
    setIsBilling(true);
    setElapsedSeconds(0);
    setMinutesBilled(0);
    console.info("[group-chat billing] started", {
      sessionId: params.sessionId,
      isHost: params.isHost,
      activeMen: activeMenRef.current.length,
    });

    intervalRef.current = setInterval(() => {
      const anchor = startRef.current;
      if (!anchor) return;
      const secs = Math.max(0, Math.floor((Date.now() - anchor) / 1000));
      setElapsedSeconds(secs);
      const due = Math.floor(secs / 60);
      if (due > billedRef.current) {
        billedRef.current = due;
        setMinutesBilled(due);
        void billDueMinuteRef.current(due);
      }
    }, 1000);
  }, [shouldRun, params.sessionId, params.isHost, stopInterval]);

  useEffect(() => () => { stopInterval(); }, [stopInterval]);

  return {
    elapsedSeconds,
    minutesBilled,
    isBilling,
    bothEngaged: params.bothEngaged,
    billingActive,
    activeMenCount,
    skipReason,
  };
}

export async function gcGoLive(roomId: string) {
  const { data, error } = await supabase.rpc("group_chat_go_live", { p_room_id: roomId });
  if (error) return { success: false, error: error.message } as const;
  return data as { success: boolean; session_id?: string; error?: string };
}
export async function gcEndLive(sessionId: string) {
  const { data, error } = await supabase.rpc("group_chat_end_live", { p_session_id: sessionId });
  if (error) return { success: false, error: error.message } as const;
  const r = data as { success?: boolean; error?: string } | null;
  if (r && r.success === false) {
    return { success: false, error: r.error || "Could not end room" } as const;
  }
  return { success: true } as const;
}
export async function gcJoin(roomId: string) {
  const { data, error } = await supabase.rpc("group_chat_join", { p_room_id: roomId });
  if (error) return { success: false, error: error.message } as const;
  return data as { success: boolean; session_id?: string; error?: string };
}
export async function gcLeave(sessionId: string) {
  const { data, error } = await supabase.rpc("group_chat_leave", { p_session_id: sessionId });
  if (error) return { success: false, error: error.message } as const;
  const r = data as { success?: boolean; error?: string } | null;
  if (r && r.success === false) {
    return { success: false, error: r.error || "Could not leave" } as const;
  }
  return { success: true } as const;
}

/** Best-effort system announcement into a live group chat (join/leave). */
export async function gcAnnounce(
  sessionId: string,
  roomId: string,
  userId: string,
  name: string,
  gender: "male" | "female",
  kind: "join" | "leave",
) {
  const body = kind === "join" ? `👋 ${name} joined the room` : `👋 ${name} left the room`;
  try {
    const { error } = await supabase.from("group_chat_messages").insert({
      session_id: sessionId,
      room_id: roomId,
      sender_id: userId,
      sender_name: name,
      sender_gender: gender,
      body,
      original_lang: "English",
      transliteration: body,
      english_translation: body,
    } as any);
    if (error) console.warn("[group-chat] announce skipped:", error.message);
  } catch { /* non-fatal */ }
}
