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

  const enrich = useCallback(async (rows: { user_id: string; joined_at: string }[]) => {
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
      } as GroupChatParticipantInfo;
    });
  }, [hostId]);

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
        .select("user_id, joined_at")
        .eq("session_id", sessionId)
        .is("left_at", null);
      if (alive) setParticipants(await enrich(parts ?? []));
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
            .select("user_id, joined_at")
            .eq("session_id", sessionId)
            .is("left_at", null);
          setParticipants(await enrich(data ?? []));
        })
      .subscribe();

    return () => { alive = false; supabase.removeChannel(ch); };
  }, [sessionId, enrich]);

  return { messages, participants };
}


/** Per-minute billing tick for men in a group chat room. Stops when the man leaves or no men remain. */
export function useGroupChatBilling(params: {
  sessionId: string | null;
  manId: string | null;
  enabled: boolean;
  onInsufficient: () => void;
}) {
  const ref = useRef<ReturnType<typeof setInterval> | null>(null);
  useEffect(() => {
    if (!params.enabled || !params.sessionId || !params.manId) return;
    const stop = () => {
      if (ref.current) {
        clearInterval(ref.current);
        ref.current = null;
      }
    };
    const tick = async () => {
      const [{ data: session }, { data: part }] = await Promise.all([
        supabase.from("group_chat_sessions").select("ended_at, host_id").eq("id", params.sessionId!).maybeSingle(),
        supabase.from("group_chat_participants").select("left_at").eq("session_id", params.sessionId!).eq("user_id", params.manId!).maybeSingle(),
      ]);
      if (!session || session.ended_at || session.host_id === params.manId || !part || part.left_at) {
        stop();
        return;
      }
      const { data } = await supabase.rpc("bill_group_chat_minute", {
        p_session_id: params.sessionId!,
        p_man_id: params.manId!,
      });
      const r = data as { success?: boolean; insufficient?: boolean; skipped?: string } | null;
      if (r?.skipped === "no_active_men" || r?.skipped === "man_left" || r?.skipped === "not_live" || r?.skipped === "host_not_billable") {
        stop();
        return;
      }
      if (r && r.success === false && r.insufficient) params.onInsufficient();
    };
    // First tick after 60s so men get the first minute free of immediate debit
    ref.current = setInterval(tick, 60_000);
    return () => stop();
  }, [params.sessionId, params.manId, params.enabled]);
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
