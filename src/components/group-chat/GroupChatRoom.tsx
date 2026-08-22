/**
 * GroupChatRoom — MS Teams style live group chat UI.
 *  - LEFT: chat messages (sender photo + name)
 *  - RIGHT: participants panel (host + members) with photo + name
 *  - Composer: text, photo, camera, file, voice
 *  - Profile language is not a send or join gate
 *  - On send: stores original body
 *  - On read: viewer sees raw native text
 */
import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  ArrowLeft, Send, Pin, X, Radio, Image as ImageIcon, Camera, Paperclip,
  Mic, StopCircle, Users, Crown, Circle,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Badge } from "@/components/ui/badge";
import {
  useGroupChatRoom, useGroupChatBilling, gcLeave, gcEndLive, gcAnnounce,
  groupChatBothEngaged, groupChatActiveMen, groupChatMaleUserIds,
  billGroupChatLeftover, dispatchWalletRefresh,
  MAN_GROUP_CHAT_RATE, HOST_GROUP_CHAT_RATE_PER_MAN,
  type GroupChatMessage, type GroupChatParticipantInfo,
} from "@/hooks/useGroupChat";
import { supabase } from "@/integrations/supabase/client";
import { toast } from "@/hooks/use-toast";

interface Props {
  sessionId: string;
  roomId: string;
  roomName: string;
  hostId: string;
  hostName?: string | null;
  currentUserId: string;
  viewerGender: "male" | "female";
  viewerName: string;
  viewerLanguage?: string;
  onClose: () => void;
}

const BUCKET = "meowmeow-app-attachment";
const LEGACY_BUCKET = "chat-attachments";
const FOLDER_PREFIX = "meowmeow/app/attachment";

function initials(name?: string | null) {
  if (!name) return "U";
  return name.split(/\s+/).map(s => s[0]).filter(Boolean).slice(0, 2).join("").toUpperCase();
}

function formatDuration(seconds: number) {
  const s = Math.max(0, Math.floor(seconds));
  const m = Math.floor(s / 60);
  const r = s % 60;
  return `${m}:${r.toString().padStart(2, "0")}`;
}

async function signedUrl(path: string): Promise<string | null> {
  if (!path) return null;
  if (path.startsWith("http")) return path;
  const clean = path.replace(/^chat-attachment:\/\//, "");
  const primary = clean.startsWith(`${FOLDER_PREFIX}/`) ? BUCKET : LEGACY_BUCKET;
  let res = await supabase.storage.from(primary).createSignedUrl(clean, 3600);
  if (!res.data?.signedUrl && primary === BUCKET) {
    res = await supabase.storage.from(LEGACY_BUCKET).createSignedUrl(clean, 3600);
  }
  return res.data?.signedUrl ?? null;
}

const AttachmentView: React.FC<{ url: string; type?: string | null; duration?: number | null }> = ({ url, type, duration }) => {
  const [resolved, setResolved] = useState<string | null>(null);
  useEffect(() => { signedUrl(url).then(setResolved); }, [url]);
  if (!resolved) return <div className="text-xs opacity-60 italic">Loading…</div>;
  if (type === "image") return <img src={resolved} alt="" className="rounded-lg max-h-56 max-w-full" />;
  if (type === "video") return <video src={resolved} controls className="rounded-lg max-h-56 max-w-full" />;
  if (type === "voice" || type === "audio") return (
    <div className="flex items-center gap-2">
      <audio src={resolved} controls className="h-8" />
      {duration ? <span className="text-[10px] opacity-60">{duration}s</span> : null}
    </div>
  );
  return <a href={resolved} target="_blank" rel="noreferrer" className="underline text-xs">Open file</a>;
};

export const GroupChatRoom: React.FC<Props> = ({
  sessionId, roomId, roomName, hostId, hostName, currentUserId, viewerGender, viewerName, viewerLanguage, onClose,
}) => {
  const isHost = currentUserId === hostId;
  const isMan = viewerGender === "male";
  const { messages, participants, sessionHostEarning, reloadParticipants, reloadSessionStats } = useGroupChatRoom(sessionId, hostId);

  const activeMen = useMemo(
    () => groupChatActiveMen(participants, hostId, messages),
    [participants, hostId, messages],
  );
  const maleUserIds = useMemo(
    () => groupChatMaleUserIds(participants, hostId, messages),
    [participants, hostId, messages],
  );
  const bothEngaged = useMemo(
    () => groupChatBothEngaged(messages, hostId, maleUserIds),
    [messages, hostId, maleUserIds],
  );

  const [walletBalance, setWalletBalance] = useState<number | null>(null);

  const refreshWallet = useCallback(async () => {
    if (!currentUserId) return;
    if (isMan) {
      const { data } = await supabase.rpc("get_men_wallet_balance", { p_user_id: currentUserId });
      if (data) setWalletBalance(Number((data as { balance?: number }).balance) || 0);
    } else if (isHost) {
      const { data } = await supabase.rpc("get_women_wallet_balance", { p_user_id: currentUserId });
      if (data) {
        setWalletBalance(Number((data as { available_balance?: number }).available_balance) || 0);
      }
    }
  }, [currentUserId, isMan, isHost]);

  useEffect(() => {
    void refreshWallet();
    const onRefresh = () => { void refreshWallet(); };
    window.addEventListener("meow:wallet-refresh", onRefresh);
    const poll = window.setInterval(() => { void refreshWallet(); }, 5000);
    return () => {
      window.removeEventListener("meow:wallet-refresh", onRefresh);
      window.clearInterval(poll);
    };
  }, [refreshWallet]);

  const [nowMs, setNowMs] = useState(Date.now());
  useEffect(() => {
    const t = window.setInterval(() => setNowMs(Date.now()), 1000);
    return () => window.clearInterval(t);
  }, []);

  const viewerLangName = (viewerLanguage || "").trim() || "English";

  const [draft, setDraft] = useState("");
  const [sending, setSending] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [recording, setRecording] = useState(false);
  const [recordSecs, setRecordSecs] = useState(0);
  const [tab, setTab] = useState<"chat" | "people">("chat");

  const scrollRef = useRef<HTMLDivElement>(null);
  const photoInput = useRef<HTMLInputElement>(null);
  const cameraInput = useRef<HTMLInputElement>(null);
  const fileInput = useRef<HTMLInputElement>(null);
  const recRef = useRef<MediaRecorder | null>(null);
  const recChunks = useRef<Blob[]>([]);
  const recTimer = useRef<ReturnType<typeof setInterval> | null>(null);

  const [hostProfile, setHostProfile] = useState<{ full_name: string | null; photo_url: string | null; gender: string | null } | null>(null);

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: "smooth" });
  }, [messages.length]);

  useEffect(() => {
    if (!hostId) return;
    let cancelled = false;
    supabase
      .from("profiles")
      .select("full_name, photo_url, gender")
      .eq("user_id", hostId)
      .maybeSingle()
      .then(({ data }) => {
        if (!cancelled && data) setHostProfile(data);
      });
    return () => { cancelled = true; };
  }, [hostId]);

  const closedRef = useRef(false);
  const closeRoom = (reason?: string) => {
    if (closedRef.current) return;
    closedRef.current = true;
    if (reason) toast({ title: "Room closed", description: reason });
    onClose();
  };

  useEffect(() => {
    if (!sessionId || !roomId || isHost) return;
    const closeIfEnded = (ended: boolean) => {
      if (!ended) return;
      closeRoom("Host ended the live session.");
    };
    const pollEnded = async () => {
      const [{ data: session }, { data: room }] = await Promise.all([
        supabase.from("group_chat_sessions").select("ended_at").eq("id", sessionId).maybeSingle(),
        supabase.from("group_chat_rooms").select("status, current_session_id").eq("id", roomId).maybeSingle(),
      ]);
      if (session?.ended_at) { closeIfEnded(true); return; }
      if (room && (room.status !== "live" || room.current_session_id !== sessionId)) closeIfEnded(true);
    };
    const ch = supabase
      .channel(`gc_room_end:${roomId}:${Math.random().toString(36).slice(2, 8)}`)
      .on("postgres_changes",
        { event: "UPDATE", schema: "public", table: "group_chat_sessions", filter: `id=eq.${sessionId}` },
        (p) => closeIfEnded(!!(p.new as { ended_at: string | null }).ended_at))
      .on("postgres_changes",
        { event: "UPDATE", schema: "public", table: "group_chat_rooms", filter: `id=eq.${roomId}` },
        (p) => {
          const row = p.new as { status?: string; current_session_id?: string | null };
          closeIfEnded(row.status !== "live" || row.current_session_id !== sessionId);
        })
      .subscribe();
    const poll = window.setInterval(() => { void pollEnded(); }, 4000);
    void pollEnded();
    return () => {
      window.clearInterval(poll);
      supabase.removeChannel(ch);
    };
  }, [sessionId, roomId, isHost, onClose]);

  const {
    elapsedSeconds, minutesBilled, isBilling, billingActive, activeMenCount, skipReason,
  } = useGroupChatBilling({
    sessionId,
    hostId,
    currentUserId,
    isHost,
    isMan,
    bothEngaged,
    activeMen,
    onInsufficient: async (manId) => {
      if (manId !== currentUserId) return;
      toast({ title: "Wallet empty", description: "Top up to keep chatting.", variant: "destructive" });
      await gcLeave(sessionId);
      onClose();
    },
    onBilled: (result) => {
      void reloadParticipants();
      void reloadSessionStats();
      void refreshWallet();
      dispatchWalletRefresh();
      const charged = Number(result.charged) || MAN_GROUP_CHAT_RATE;
      if (isMan) {
        toast({ title: "Group chat billed", description: `₹${charged.toFixed(2)} charged for this minute.` });
      } else if (isHost) {
        const earned = Number(result.earned) || HOST_GROUP_CHAT_RATE_PER_MAN;
        toast({ title: "Group chat earning", description: `₹${earned.toFixed(2)} credited for this minute.` });
      }
    },
    onBillingSkip: (reason) => {
      if (reason === "admin") {
        toast({
          title: "Billing skipped",
          description: "Admin test accounts are not charged in group chat. Use a regular account to test wallets.",
        });
      }
    },
    onWalletUpdated: refreshWallet,
  });

  const myParticipant = participants.find((p) => p.user_id === currentUserId);
  const partialMinute = isBilling ? Math.max(0, elapsedSeconds - minutesBilled * 60) / 60 : 0;
  const manSpentDisplay = isMan
    ? (myParticipant?.total_billed ?? 0) + partialMinute * MAN_GROUP_CHAT_RATE
    : 0;
  const hostEarnedDisplay = isHost
    ? sessionHostEarning + activeMen.length * partialMinute * HOST_GROUP_CHAT_RATE_PER_MAN
    : 0;

  async function insertMessage(payload: Partial<GroupChatMessage>) {
    if (closedRef.current) return;
    const { error } = await supabase.from("group_chat_messages").insert({
      session_id: sessionId,
      room_id: roomId,
      sender_id: currentUserId,
      sender_name: viewerName,
      sender_gender: viewerGender,
      original_lang: viewerLangName,
      ...payload,
    } as any);
    if (!error) return;
    const code = String((error as { code?: string }).code || "");
    const msg = (error.message || "").toLowerCase();
    const denied = code === "42501" || code === "PGRST301" || /permission|row-level|rls|forbidden|not allowed/i.test(msg);
    if (denied) {
      closeRoom("This room is no longer live.");
      return;
    }
    toast({ title: "Send failed", description: error.message, variant: "destructive" });
  }

  const sendText = async () => {
    const text = draft.trim();
    if (!text || sending) return;
    setSending(true);
    try {
      await insertMessage({ body: text });
      setDraft("");
    } finally { setSending(false); }
  };

  const upload = async (file: File, kind: "image" | "video" | "file" | "voice", durationSec?: number) => {
    setUploading(true);
    try {
      const ext = (file.name.split(".").pop() || "bin").toLowerCase();
      const path = `${FOLDER_PREFIX}/group/${sessionId}/${currentUserId}/${Date.now()}.${ext}`;
      const { error } = await supabase.storage.from(BUCKET).upload(path, file, { upsert: false, contentType: file.type || undefined });
      if (error) { toast({ title: "Upload failed", description: error.message, variant: "destructive" }); return; }
      await insertMessage({
        body: kind === "voice" ? "🎤 Voice" : kind === "image" ? "📷 Image" : kind === "video" ? "🎬 Video" : `📎 ${file.name}`,
        media_url: path,
        media_type: kind,
        voice_duration_seconds: durationSec ?? null,
      });
    } finally { setUploading(false); }
  };

  const onPickFile = (e: React.ChangeEvent<HTMLInputElement>, kind: "image" | "video" | "file") => {
    const f = e.target.files?.[0]; e.target.value = "";
    if (!f) return;
    const auto = f.type.startsWith("image/") ? "image" : f.type.startsWith("video/") ? "video" : kind;
    upload(f, auto);
  };

  const startRecording = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const mr = new MediaRecorder(stream);
      recChunks.current = [];
      mr.ondataavailable = (e) => e.data.size && recChunks.current.push(e.data);
      mr.onstop = async () => {
        stream.getTracks().forEach(t => t.stop());
        const blob = new Blob(recChunks.current, { type: "audio/webm" });
        const file = new File([blob], `voice-${Date.now()}.webm`, { type: "audio/webm" });
        await upload(file, "voice", recordSecs);
        setRecordSecs(0);
      };
      mr.start();
      recRef.current = mr;
      setRecording(true);
      recTimer.current = setInterval(() => setRecordSecs((s) => s + 1), 1000);
    } catch (e: any) {
      toast({ title: "Mic error", description: e?.message ?? "Cannot access microphone", variant: "destructive" });
    }
  };
  const stopRecording = () => {
    if (recTimer.current) { clearInterval(recTimer.current); recTimer.current = null; }
    recRef.current?.stop();
    recRef.current = null;
    setRecording(false);
  };

  const pin = async (m: GroupChatMessage) => {
    if (!isHost) return;
    await supabase.from("group_chat_messages").update({ pinned: !m.pinned }).eq("id", m.id);
  };

  const handleLeave = async () => {
    if (isHost) {
      // Announce while still host of a live session — insert after end_live is RLS 403.
      await gcAnnounce(sessionId, roomId, currentUserId, viewerName, viewerGender, "leave");
      const res = await gcEndLive(sessionId);
      if (!res.success) {
        toast({ title: "Could not end room", description: res.error, variant: "destructive" });
        return;
      }
      closedRef.current = true;
      onClose();
      return;
    }
    await gcAnnounce(sessionId, roomId, currentUserId, viewerName, viewerGender, "leave");
    if (isMan) await billGroupChatLeftover(sessionId, currentUserId);
    await gcLeave(sessionId);
    closedRef.current = true;
    dispatchWalletRefresh();
    onClose();
  };

  const pinned = messages.filter(m => m.pinned);
  const hostParticipant = participants.find(p => p.is_host) ?? (
    hostId
      ? {
          user_id: hostId,
          joined_at: "",
          full_name: hostProfile?.full_name ?? hostName ?? "Host",
          photo_url: hostProfile?.photo_url ?? null,
          gender: hostProfile?.gender ?? "female",
          is_host: true,
        }
      : undefined
  );
  const others = participants.filter(p => !p.is_host);
  const hostLabel = hostParticipant?.full_name || hostName || "Host";

  const PeoplePanel = (
    <div className="h-full flex flex-col bg-card">
      <div className="px-3 py-2 border-b border-border text-sm font-semibold flex items-center gap-1.5">
        <Users className="w-4 h-4" /> People ({participants.length})
      </div>
      <ScrollArea className="flex-1">
        <div className="p-2 space-y-2">
          <div>
            <div className="text-[10px] uppercase tracking-wider text-muted-foreground px-1 mb-1">Host</div>
            {hostParticipant ? (
              <PersonRow
                p={hostParticipant}
                nowMs={nowMs}
                billingElapsed={isBilling ? elapsedSeconds : 0}
                moneyLabel={isHost && billingActive ? `Earned ₹${hostEarnedDisplay.toFixed(2)}` : undefined}
              />
            ) : (
              <div className="text-xs text-muted-foreground px-1">No host</div>
            )}
          </div>
          <div>
            <div className="text-[10px] uppercase tracking-wider text-muted-foreground px-1 mb-1 mt-2">
              Participants ({others.length})
            </div>
            {others.length === 0 ? (
              <div className="text-xs text-muted-foreground px-1">No one else yet</div>
            ) : others.map(p => (
              <PersonRow
                key={p.user_id}
                p={p}
                nowMs={nowMs}
                billingElapsed={isBilling && p.user_id === currentUserId ? elapsedSeconds : 0}
                moneyLabel={
                  p.user_id === currentUserId && isMan && billingActive
                    ? `Spent ₹${manSpentDisplay.toFixed(2)}`
                    : p.total_billed
                      ? `Spent ₹${Number(p.total_billed).toFixed(2)}`
                      : undefined
                }
              />
            ))}
          </div>
        </div>
      </ScrollArea>
    </div>
  );

  const ChatPanel = (
    <div className="h-full flex flex-col bg-background">
      {pinned.length > 0 && (
        <div className="shrink-0 px-3 py-1.5 bg-muted/40 border-b border-border text-xs">
          {pinned.map((p) => (
            <div key={p.id} className="flex items-center gap-1 truncate">
              <Pin className="w-3 h-3 text-primary" />
              <span className="truncate"><b>{p.sender_name}:</b> {p.body}</span>
            </div>
          ))}
        </div>
      )}

      <div ref={scrollRef} className="flex-1 overflow-y-auto px-3 py-2 space-y-3">
        {messages.length === 0 && (
          <div className="text-center text-sm text-muted-foreground py-8">Say hi to start the conversation.</div>
        )}
        {messages.map((m) => {
          const mine = m.sender_id === currentUserId;
          const senderInfo = participants.find(p => p.user_id === m.sender_id);
          return (
            <div key={m.id} className={`flex gap-2 ${mine ? "flex-row-reverse" : ""}`}>
              <Avatar className="w-8 h-8 shrink-0">
                <AvatarImage src={senderInfo?.photo_url ?? undefined} />
                <AvatarFallback className="text-[10px]">{initials(m.sender_name ?? senderInfo?.full_name)}</AvatarFallback>
              </Avatar>
              <div className={`max-w-[78%] flex flex-col ${mine ? "items-end" : "items-start"}`}>
                <div className="flex items-center gap-1 mb-0.5">
                  <span className="text-[11px] font-semibold">{m.sender_name ?? senderInfo?.full_name ?? "User"}</span>
                  {m.sender_id === hostId && <Crown className="w-3 h-3 text-yellow-500" />}
                  <span className="text-[10px] opacity-50">
                    {new Date(m.created_at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
                  </span>
                </div>
                <div className={`rounded-2xl px-3 py-2 text-sm ${mine ? "bg-primary text-primary-foreground" : "bg-muted"}`}>
                  {m.media_url ? (
                    <AttachmentView url={m.media_url} type={m.media_type} duration={m.voice_duration_seconds ?? undefined} />
                  ) : (
                    <div className="break-words whitespace-pre-wrap">{m.body}</div>
                  )}
                  {isHost && !mine && (
                    <button onClick={() => pin(m)} className="opacity-50 hover:opacity-100 ml-2">
                      <Pin className={`w-3 h-3 inline ${m.pinned ? "fill-current" : ""}`} />
                    </button>
                  )}
                </div>
              </div>
            </div>
          );
        })}
      </div>

      <div className="shrink-0 border-t border-border bg-card p-2 pb-[env(safe-area-inset-bottom)]">
        <div className="flex items-center gap-1">
          <input ref={photoInput} type="file" accept="image/*,video/*" hidden onChange={(e) => onPickFile(e, "image")} />
          <input ref={cameraInput} type="file" accept="image/*" capture="environment" hidden onChange={(e) => onPickFile(e, "image")} />
          <input ref={fileInput} type="file" hidden onChange={(e) => onPickFile(e, "file")} />
          <Button size="icon" variant="ghost" onClick={() => photoInput.current?.click()} disabled={uploading}><ImageIcon className="w-4 h-4" /></Button>
          <Button size="icon" variant="ghost" onClick={() => cameraInput.current?.click()} disabled={uploading}><Camera className="w-4 h-4" /></Button>
          <Button size="icon" variant="ghost" onClick={() => fileInput.current?.click()} disabled={uploading}><Paperclip className="w-4 h-4" /></Button>
          <Input
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            onKeyDown={(e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); sendText(); } }}
            placeholder="Type a message..."
            className="flex-1"
            disabled={recording}
          />
          {recording ? (
            <Button size="icon" variant="destructive" onClick={stopRecording}>
              <StopCircle className="w-4 h-4" />
              <span className="sr-only">Stop ({recordSecs}s)</span>
            </Button>
          ) : draft.trim() ? (
            <Button onClick={sendText} disabled={sending} size="icon"><Send className="w-4 h-4" /></Button>
          ) : (
            <Button size="icon" variant="secondary" onClick={startRecording}><Mic className="w-4 h-4" /></Button>
          )}
        </div>
        {recording && <div className="text-[11px] text-destructive mt-1 px-1">● Recording {recordSecs}s — tap stop to send</div>}
      </div>
    </div>
  );

  return (
    <div className="fixed inset-0 z-[125] flex flex-col bg-background">
      <div className="shrink-0 flex items-center gap-2 px-3 py-2 border-b border-border bg-card">
        <Button size="icon" variant="ghost" onClick={handleLeave}><ArrowLeft className="w-5 h-5" /></Button>
        <div className="flex-1 min-w-0">
          <div className="font-semibold truncate flex items-center gap-1.5">
            <Radio className="w-3.5 h-3.5 text-red-500 animate-pulse" />
            {roomName}
          </div>
          <div className="text-[11px] text-muted-foreground truncate">
            Host {hostLabel} · {participants.length} online
            {walletBalance !== null ? ` · Wallet ₹${walletBalance.toFixed(2)}` : ""}
            {!bothEngaged && maleUserIds.length > 0 ? " · Say hi to start billing" : null}
            {skipReason === "waiting_for_replies" ? " · Waiting for both to message" : null}
            {skipReason === "admin" ? " · Admin: no wallet charges" : null}
          </div>
        </div>
        {billingActive ? (
          <Badge variant="outline" className="shrink-0 text-[11px] gap-1 border-accent/50">
            <Circle className="h-2 w-2 fill-accent text-accent animate-pulse" />
            {isHost
              ? `Earned ₹${hostEarnedDisplay.toFixed(2)}`
              : isMan
                ? `Spent ₹${manSpentDisplay.toFixed(2)}`
                : `${activeMenCount} billing`}
            {" · "}{formatDuration(elapsedSeconds)}
          </Badge>
        ) : isHost && activeMenCount === 0 ? (
          <Badge variant="outline" className="shrink-0 text-[11px] text-muted-foreground">
            Not billing
          </Badge>
        ) : null}
        <Button size="sm" variant="destructive" onClick={handleLeave}>
          <X className="w-3.5 h-3.5 mr-1" />{isHost ? "End" : "Leave"}
        </Button>
      </div>

      <div className="flex-1 min-h-0 md:hidden">
        <Tabs value={tab} onValueChange={(v) => setTab(v as any)} className="h-full flex flex-col">
          <TabsList className="mx-2 mt-2 grid grid-cols-2">
            <TabsTrigger value="chat">Chat</TabsTrigger>
            <TabsTrigger value="people">People ({participants.length})</TabsTrigger>
          </TabsList>
          <TabsContent value="chat" className="flex-1 min-h-0 mt-0">{ChatPanel}</TabsContent>
          <TabsContent value="people" className="flex-1 min-h-0 mt-0">{PeoplePanel}</TabsContent>
        </Tabs>
      </div>
      <div className="hidden md:flex flex-1 min-h-0">
        <div className="flex-1 min-w-0 border-r border-border">{ChatPanel}</div>
        <div className="w-72 shrink-0">{PeoplePanel}</div>
      </div>
    </div>
  );
};

const PersonRow: React.FC<{
  p: GroupChatParticipantInfo;
  nowMs: number;
  billingElapsed?: number;
  moneyLabel?: string;
}> = ({ p, nowMs, billingElapsed = 0, moneyLabel }) => {
  const inRoomSecs = p.joined_at
    ? Math.max(0, Math.floor((nowMs - new Date(p.joined_at).getTime()) / 1000))
    : billingElapsed;
  const timeLabel = billingElapsed > 0 ? formatDuration(billingElapsed) : formatDuration(inRoomSecs);

  return (
    <div className="flex items-center gap-2 p-1.5 rounded hover:bg-muted/50">
      <Avatar className="w-8 h-8">
        <AvatarImage src={p.photo_url ?? undefined} />
        <AvatarFallback className="text-[10px]">{initials(p.full_name)}</AvatarFallback>
      </Avatar>
      <div className="flex-1 min-w-0">
        <div className="text-sm truncate flex items-center gap-1">
          {p.full_name ?? "User"}
          {p.is_host && <Crown className="w-3 h-3 text-yellow-500 shrink-0" />}
        </div>
        <div className="text-[10px] text-muted-foreground capitalize flex flex-wrap gap-x-1.5">
          <span>{p.gender ?? ""}</span>
          <span>· {timeLabel}</span>
          {moneyLabel ? <span className="text-accent">· {moneyLabel}</span> : null}
        </div>
      </div>
      <span className="w-2 h-2 rounded-full bg-green-500" />
    </div>
  );
};

export default GroupChatRoom;
