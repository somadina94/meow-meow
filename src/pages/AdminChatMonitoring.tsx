import { useState, useEffect, useRef, useCallback } from "react";
import AdminNav from "@/components/AdminNav";
import { useNavigate } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { useAdminAccess } from "@/hooks/useAdminAccess";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { toast } from "sonner";
import { format, differenceInMinutes, differenceInSeconds } from "date-fns";
import { countries } from "@/data/countries";
import { languages } from "@/data/languages";
import { 
  ArrowLeft, Search, Flag, MessageSquare, User, Clock, AlertTriangle,
  CheckCircle, XCircle, Eye, Filter, RefreshCw, Bell, Send, Users,
  Globe, EyeOff, Languages, Home, Video, Radio, Shield, PhoneCall,
  Timer, DollarSign, Check, CheckCheck,
} from "lucide-react";

// ─── Types ───────────────────────────────────────────────────────
interface ChatMessage {
  id: string;
  chat_id: string;
  sender_id: string;
  receiver_id: string;
  message: string;
  translated_message: string | null;
  created_at: string;
  is_read: boolean | null;
  flagged: boolean;
  flagged_by: string | null;
  flagged_at: string | null;
  flag_reason: string | null;
  moderation_status: string | null;
}

interface Profile {
  user_id: string;
  full_name: string | null;
  photo_url: string | null;
  gender: string | null;
  country: string | null;
  primary_language: string | null;
}

interface ActiveChat {
  chat_id: string;
  man_user_id: string;
  woman_user_id: string;
  started_at: string;
  last_activity_at: string;
  man_name: string;
  woman_name: string;
  man_country: string;
  woman_country: string;
  man_language: string;
  woman_language: string;
  message_count: number;
}

// ─── Audit helper ────────────────────────────────────────────────
const logAdminAudit = async (action: string, resourceType: string, resourceId?: string, details?: string) => {
  try {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session?.user) return;
    await supabase.from("audit_logs").insert({
      admin_id: session.user.id,
      admin_email: session.user.email,
      action,
      action_type: "ghost_monitor",
      resource_type: resourceType,
      resource_id: resourceId,
      details,
    });
  } catch (e) {
    console.error("[Audit] Failed to log:", e);
  }
};

// ─── Live duration component ─────────────────────────────────────
const LiveDuration = ({ startedAt }: { startedAt: string | null }) => {
  const [elapsed, setElapsed] = useState("");
  useEffect(() => {
    if (!startedAt) { setElapsed("N/A"); return; }
    const tick = () => {
      const now = new Date();
      const start = new Date(startedAt);
      const totalSec = differenceInSeconds(now, start);
      const mins = Math.ceil(totalSec / 60);
      setElapsed(`${mins} min`);
    };
    tick();
    const id = setInterval(tick, 1000);
    return () => clearInterval(id);
  }, [startedAt]);
  return (
    <span className="flex items-center gap-1 font-mono text-xs">
      <Timer className="h-3 w-3 text-destructive animate-pulse" />
      {elapsed}
    </span>
  );
};

// ─── Main component ──────────────────────────────────────────────
const AdminChatMonitoring = () => {
  const navigate = useNavigate();
  
  const { isAdmin, isLoading: adminLoading } = useAdminAccess();
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [profiles, setProfiles] = useState<Record<string, Profile>>({});
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [filterStatus, setFilterStatus] = useState<string>("all");
  const [filterFlagged, setFilterFlagged] = useState<string>("all");
  const [selectedMessage, setSelectedMessage] = useState<ChatMessage | null>(null);
  const [flagDialogOpen, setFlagDialogOpen] = useState(false);
  const [flagReason, setFlagReason] = useState("");
  const [viewDialogOpen, setViewDialogOpen] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);
  
  // Notification states
  const [notificationDialogOpen, setNotificationDialogOpen] = useState(false);
  const [notificationTitle, setNotificationTitle] = useState("");
  const [notificationMessage, setNotificationMessage] = useState("");
  const [notificationTarget, setNotificationTarget] = useState<"all" | "men" | "women">("all");
  const [sendingNotification, setSendingNotification] = useState(false);
  
  // Silent chat monitoring states
  const [activeChats, setActiveChats] = useState<ActiveChat[]>([]);
  const [silentMonitorChatId, setSilentMonitorChatId] = useState<string | null>(null);
  const [silentMonitorMessages, setSilentMonitorMessages] = useState<ChatMessage[]>([]);
  const [monitorCountryFilter, setMonitorCountryFilter] = useState<string>("all");
  const [monitorLanguageFilter, setMonitorLanguageFilter] = useState<string>("all");
  const [monitorLanguageGroupFilter, setMonitorLanguageGroupFilter] = useState<string>("all");
  const [languageGroups, setLanguageGroups] = useState<{ id: string; name: string; languages: string[] }[]>([]);
  const [loadingChats, setLoadingChats] = useState(false);

  // Video call monitoring states
  const [activeVideoCalls, setActiveVideoCalls] = useState<any[]>([]);
  const [loadingVideoCalls, setLoadingVideoCalls] = useState(false);
  const [monitoringVideoCallId, setMonitoringVideoCallId] = useState<string | null>(null);

  // Private group monitoring states
  const [liveGroups, setLiveGroups] = useState<any[]>([]);
  const [loadingGroups, setLoadingGroups] = useState(false);
  const [monitoringGroupId, setMonitoringGroupId] = useState<string | null>(null);
  const [groupMessages, setGroupMessages] = useState<any[]>([]);
  const [groupParticipants, setGroupParticipants] = useState<any[]>([]);

  // ─── Data loaders ──────────────────────────────────────────────
  // Use refs for realtime callbacks to avoid recreating the channel on every state change
  const silentMonitorChatIdRef = useRef(silentMonitorChatId);
  silentMonitorChatIdRef.current = silentMonitorChatId;
  const monitoringGroupIdRef = useRef(monitoringGroupId);
  monitoringGroupIdRef.current = monitoringGroupId;

  useEffect(() => {
    loadMessages();
    loadActiveChats();
    loadLanguageGroups();
    loadActiveVideoCalls();
    loadLiveGroups();
    
    const channel = supabase
      .channel('chat-monitoring')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'chat_messages' }, () => {
        loadMessages();
        if (silentMonitorChatIdRef.current) loadSilentMonitorMessages(silentMonitorChatIdRef.current);
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'active_chat_sessions' }, () => {
        loadActiveChats();
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'video_call_sessions' }, () => {
        loadActiveVideoCalls();
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'private_groups' }, () => {
        loadLiveGroups();
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'group_messages' }, () => {
        if (monitoringGroupIdRef.current) loadGroupMessages(monitoringGroupIdRef.current);
      })
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [filterStatus, filterFlagged]);

  const loadMessages = async () => {
    try {
      // FIX #11: Increased limit from 100 to 500 for better coverage
      let query = supabase
        .from("chat_messages")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(500);

      if (filterFlagged === "flagged") query = query.eq("flagged", true);
      else if (filterFlagged === "unflagged") query = query.eq("flagged", false);
      if (filterStatus !== "all") query = query.eq("moderation_status", filterStatus);

      const { data, error } = await query;
      if (error) throw error;
      setMessages(data || []);

      const userIds = new Set<string>();
      data?.forEach((msg) => { userIds.add(msg.sender_id); userIds.add(msg.receiver_id); });

      if (userIds.size > 0) {
        const { data: profilesData } = await supabase
          .from("profiles")
          .select("user_id, full_name, photo_url, gender, country, primary_language")
          .in("user_id", Array.from(userIds));

        if (profilesData) {
          const profilesMap: Record<string, Profile> = {};
          profilesData.forEach((p) => {
            profilesMap[p.user_id] = { user_id: p.user_id, full_name: p.full_name, photo_url: p.photo_url, gender: p.gender, country: p.country, primary_language: p.primary_language };
          });
          setProfiles(profilesMap);
        }
      }
    } catch (error) {
      console.error("Error loading messages:", error);
      toast.error("Error", { description: "Failed to load messages" });
    } finally {
      setLoading(false);
    }
  };

  const loadActiveChats = async () => {
    setLoadingChats(true);
    try {
      const { data: sessions, error } = await supabase
        .from("active_chat_sessions").select("*").eq("status", "active")
        .order("last_activity_at", { ascending: false });
      if (error) throw error;
      if (!sessions || sessions.length === 0) { setActiveChats([]); return; }

      const userIds = new Set<string>();
      sessions.forEach((s) => { userIds.add(s.man_user_id); userIds.add(s.woman_user_id); });

      const { data: profilesData } = await supabase
        .from("profiles").select("user_id, full_name, country, primary_language")
        .in("user_id", Array.from(userIds));
      const profileMap = new Map<string, any>();
      profilesData?.forEach((p) => profileMap.set(p.user_id, p));

      const chatIds = sessions.map((s) => s.chat_id);
      const { data: messageCounts } = await supabase
        .from("chat_messages").select("chat_id").in("chat_id", chatIds);
      const countMap = new Map<string, number>();
      messageCounts?.forEach((m) => { countMap.set(m.chat_id, (countMap.get(m.chat_id) || 0) + 1); });

      setActiveChats(sessions.map((s) => {
        const man = profileMap.get(s.man_user_id);
        const woman = profileMap.get(s.woman_user_id);
        return {
          chat_id: s.chat_id, man_user_id: s.man_user_id, woman_user_id: s.woman_user_id,
          started_at: s.started_at, last_activity_at: s.last_activity_at,
          man_name: man?.full_name || "Unknown", woman_name: woman?.full_name || "Unknown",
          man_country: man?.country || "Unknown", woman_country: woman?.country || "Unknown",
          man_language: man?.primary_language || "Unknown", woman_language: woman?.primary_language || "Unknown",
          message_count: countMap.get(s.chat_id) || 0,
        };
      }));
    } catch (error) {
      console.error("Error loading active chats:", error);
      toast.error("Error", { description: "Failed to load active chats" });
    } finally {
      setLoadingChats(false);
    }
  };

  const loadLanguageGroups = async () => {
    try {
      const { data, error } = await supabase
        .from("language_groups").select("id, name, languages").eq("is_active", true)
        .order("priority", { ascending: false });
      if (error) throw error;
      setLanguageGroups(data || []);
    } catch (error) {
      console.error("Error loading language groups:", error);
    }
  };

  const loadActiveVideoCalls = async () => {
    setLoadingVideoCalls(true);
    try {
      const { data: sessions, error } = await supabase
        .from("video_call_sessions").select("*")
        .in("status", ["active", "ringing"])
        .order("created_at", { ascending: false });
      if (error) throw error;
      if (!sessions || sessions.length === 0) { setActiveVideoCalls([]); return; }

      const userIds = new Set<string>();
      sessions.forEach((s: any) => { userIds.add(s.man_user_id); userIds.add(s.woman_user_id); });

      const { data: profilesData } = await supabase
        .from("profiles").select("user_id, full_name, country, primary_language, photo_url")
        .in("user_id", Array.from(userIds));
      const profileMap = new Map<string, any>();
      profilesData?.forEach((p: any) => profileMap.set(p.user_id, p));

      setActiveVideoCalls(sessions.map((s: any) => ({
        ...s,
        man_name: profileMap.get(s.man_user_id)?.full_name || "Unknown",
        woman_name: profileMap.get(s.woman_user_id)?.full_name || "Unknown",
        man_country: profileMap.get(s.man_user_id)?.country || "Unknown",
        woman_country: profileMap.get(s.woman_user_id)?.country || "Unknown",
        man_language: profileMap.get(s.man_user_id)?.primary_language || "Unknown",
        woman_language: profileMap.get(s.woman_user_id)?.primary_language || "Unknown",
      })));
    } catch (error) {
      console.error("Error loading video calls:", error);
      toast.error("Error", { description: "Failed to load video calls" });
    } finally {
      setLoadingVideoCalls(false);
    }
  };

  const loadLiveGroups = async () => {
    setLoadingGroups(true);
    try {
      const { data, error } = await supabase
        .from("private_groups").select("*")
        .eq("is_active", true).eq("is_live", true)
        .not("current_host_id", "is", null)
        .order("name", { ascending: true });
      if (error) throw error;

      if (data && data.length > 0) {
        // Enrich with host names and participant counts
        const hostIds = data.map((g: any) => g.current_host_id).filter(Boolean);
        const groupIds = data.map((g: any) => g.id);
        
        const [{ data: hostProfiles }, { data: memberships }] = await Promise.all([
          supabase.from("profiles").select("user_id, full_name").in("user_id", hostIds),
          supabase.from("group_memberships").select("group_id").in("group_id", groupIds).eq("has_access", true),
        ]);
        
        const hostMap = new Map<string, string>();
        hostProfiles?.forEach((p: any) => hostMap.set(p.user_id, p.full_name));
        const countMap = new Map<string, number>();
        memberships?.forEach((m: any) => countMap.set(m.group_id, (countMap.get(m.group_id) || 0) + 1));

        setLiveGroups(data.map((g: any) => ({
          ...g,
          current_host_name: hostMap.get(g.current_host_id) || "Unknown",
          participant_count: countMap.get(g.id) || 0,
        })));
      } else {
        setLiveGroups([]);
      }
    } catch (error) {
      console.error("Error loading live groups:", error);
      toast.error("Error", { description: "Failed to load live groups" });
    } finally {
      setLoadingGroups(false);
    }
  };

  const loadGroupMessages = async (groupId: string) => {
    try {
      const { data, error } = await supabase
        .from("group_messages").select("*").eq("group_id", groupId)
        .order("created_at", { ascending: true }).limit(200);
      if (error) throw error;

      const userIds = new Set<string>();
      data?.forEach((m: any) => userIds.add(m.sender_id));

      const { data: profilesData } = await supabase
        .from("profiles").select("user_id, full_name").in("user_id", Array.from(userIds));
      const profileMap = new Map<string, string>();
      profilesData?.forEach((p: any) => profileMap.set(p.user_id, p.full_name));

      setGroupMessages((data || []).map((m: any) => ({
        ...m, sender_name: profileMap.get(m.sender_id) || "Unknown",
      })));
    } catch (error) {
      console.error("Error loading group messages:", error);
    }
  };

  const loadGroupParticipants = async (groupId: string) => {
    try {
      const { data: memberships } = await supabase
        .from("group_memberships").select("user_id, has_access, joined_at")
        .eq("group_id", groupId).eq("has_access", true);
      if (!memberships || memberships.length === 0) { setGroupParticipants([]); return; }
      
      const userIds = memberships.map((m: any) => m.user_id);
      const { data: profilesData } = await supabase
        .from("profiles").select("user_id, full_name, gender, country").in("user_id", userIds);
      const profileMap = new Map<string, any>();
      profilesData?.forEach((p: any) => profileMap.set(p.user_id, p));
      
      setGroupParticipants(memberships.map((m: any) => ({
        ...m,
        full_name: profileMap.get(m.user_id)?.full_name || "Unknown",
        gender: profileMap.get(m.user_id)?.gender || "Unknown",
        country: profileMap.get(m.user_id)?.country || "Unknown",
      })));
    } catch (error) {
      console.error("Error loading group participants:", error);
    }
  };

  const loadSilentMonitorMessages = async (chatId: string) => {
    try {
      const { data, error } = await supabase
        .from("chat_messages").select("*").eq("chat_id", chatId)
        .order("created_at", { ascending: true });
      if (error) throw error;
      setSilentMonitorMessages(data || []);
    } catch (error) {
      console.error("Error loading monitor messages:", error);
    }
  };

  // ─── Ghost mode actions ────────────────────────────────────────
  const startSilentMonitoring = (chatId: string) => {
    setSilentMonitorChatId(chatId);
    loadSilentMonitorMessages(chatId);
    logAdminAudit("ghost_monitor_chat_start", "chat", chatId, "Started silent chat monitoring");
    toast("👻 Ghost Mode Active", { description: "Silently monitoring chat — participants cannot see you" });
  };

  const stopSilentMonitoring = () => {
    logAdminAudit("ghost_monitor_chat_stop", "chat", silentMonitorChatId || undefined, "Stopped silent chat monitoring");
    setSilentMonitorChatId(null);
    setSilentMonitorMessages([]);
  };

  const startVideoMonitoring = (callId: string) => {
    setMonitoringVideoCallId(callId);
    logAdminAudit("ghost_monitor_video_start", "video_call", callId, "Started ghost video call monitoring");
    toast("👻 Ghost Video Monitor", { description: "Monitoring video call — participants cannot see you" });
  };

  const stopVideoMonitoring = () => {
    logAdminAudit("ghost_monitor_video_stop", "video_call", monitoringVideoCallId || undefined, "Stopped ghost video call monitoring");
    setMonitoringVideoCallId(null);
  };

  const startGroupMonitoring = (groupId: string) => {
    setMonitoringGroupId(groupId);
    loadGroupMessages(groupId);
    loadGroupParticipants(groupId);
    logAdminAudit("ghost_monitor_group_start", "private_group", groupId, "Started ghost group monitoring");
    toast("👻 Ghost Group Monitor", { description: "Silently monitoring group — not visible to participants" });
  };

  const stopGroupMonitoring = () => {
    logAdminAudit("ghost_monitor_group_stop", "private_group", monitoringGroupId || undefined, "Stopped ghost group monitoring");
    setMonitoringGroupId(null);
    setGroupMessages([]);
    setGroupParticipants([]);
  };

  // ─── Notifications ────────────────────────────────────────────
  const sendBroadcastNotification = async () => {
    if (!notificationTitle.trim() || !notificationMessage.trim()) {
      toast.error("Error", { description: "Please provide both title and message" });
      return;
    }
    setSendingNotification(true);
    try {
      let query = supabase.from("profiles").select("user_id, gender");
      if (notificationTarget === "men") query = query.eq("gender", "male");
      else if (notificationTarget === "women") query = query.eq("gender", "female");

      const { data: users, error: usersError } = await query;
      if (usersError) throw usersError;
      if (!users || users.length === 0) {
        toast.error("No users found", { description: "No users match the criteria" });
        return;
      }

      const notifications = users.map((user) => ({
        user_id: user.user_id, title: notificationTitle,
        message: notificationMessage, type: "admin_broadcast", is_read: false,
      }));

      const { error } = await supabase.from("notifications").insert(notifications);
      if (error) throw error;

      toast.success("Success", { description: `Notification sent to ${users.length} ${notificationTarget === "all" ? "users" : notificationTarget}` });
      setNotificationDialogOpen(false);
      setNotificationTitle(""); setNotificationMessage(""); setNotificationTarget("all");
    } catch (error) {
      console.error("Error sending notifications:", error);
      toast.error("Error", { description: "Failed to send notifications" });
    } finally {
      setSendingNotification(false);
    }
  };

  // ─── Moderation actions ────────────────────────────────────────
  const handleFlag = async () => {
    if (!selectedMessage || !flagReason.trim()) {
      toast.error("Error", { description: "Please provide a reason for flagging" });
      return;
    }
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.user) throw new Error("Not authenticated");

      const { error } = await supabase.from("chat_messages").update({
        flagged: true, flagged_by: session.user.id,
        flagged_at: new Date().toISOString(), flag_reason: flagReason.trim(),
        moderation_status: "flagged",
      }).eq("id", selectedMessage.id);
      if (error) throw error;

      toast.success("Success", { description: "Message flagged for review" });
      setFlagDialogOpen(false); setFlagReason(""); setSelectedMessage(null);
      loadMessages();
    } catch (error) {
      console.error("Error flagging message:", error);
      toast.error("Error", { description: "Failed to flag message" });
    }
  };

  const handleUnflag = async (message: ChatMessage) => {
    try {
      const { error } = await supabase.from("chat_messages").update({
        flagged: false, flagged_by: null, flagged_at: null,
        flag_reason: null, moderation_status: "cleared",
      }).eq("id", message.id);
      if (error) throw error;
      toast.success("Success", { description: "Flag removed" });
      loadMessages();
    } catch (error) {
      console.error("Error unflagging:", error);
      toast.error("Error", { description: "Failed to remove flag" });
    }
  };

  const handleResolve = async (message: ChatMessage, status: string) => {
    try {
      const { error } = await supabase.from("chat_messages")
        .update({ moderation_status: status }).eq("id", message.id);
      if (error) throw error;
      toast.success("Success", { description: `Message marked as ${status}` });
      loadMessages();
    } catch (error) {
      console.error("Error updating status:", error);
      toast.error("Error", { description: "Failed to update status" });
    }
  };

  // ─── Helpers ───────────────────────────────────────────────────
  const getUserName = (userId: string) => profiles[userId]?.full_name || userId.slice(0, 8) + "...";

  const filteredMessages = messages.filter((msg) => {
    if (!searchTerm) return true;
    const search = searchTerm.toLowerCase();
    return msg.message.toLowerCase().includes(search) || msg.chat_id.toLowerCase().includes(search) ||
      getUserName(msg.sender_id).toLowerCase().includes(search) || getUserName(msg.receiver_id).toLowerCase().includes(search);
  });

  const filteredActiveChats = activeChats.filter((chat) => {
    if (monitorCountryFilter !== "all" && chat.man_country !== monitorCountryFilter && chat.woman_country !== monitorCountryFilter) return false;
    if (monitorLanguageFilter !== "all" && chat.man_language !== monitorLanguageFilter && chat.woman_language !== monitorLanguageFilter) return false;
    if (monitorLanguageGroupFilter !== "all") {
      const group = languageGroups.find(g => g.id === monitorLanguageGroupFilter);
      if (group && !group.languages.some(lang => chat.man_language === lang || chat.woman_language === lang)) return false;
    }
    return true;
  });

  const getStatusBadge = (message: ChatMessage) => {
    if (message.flagged) return <Badge variant="destructive" className="gap-1"><AlertTriangle className="h-3 w-3" />Flagged</Badge>;
    switch (message.moderation_status) {
      case "cleared": return <Badge variant="secondary" className="gap-1 bg-primary/20 text-primary"><CheckCircle className="h-3 w-3" />Cleared</Badge>;
      case "removed": return <Badge variant="secondary" className="gap-1 bg-destructive/20 text-destructive"><XCircle className="h-3 w-3" />Removed</Badge>;
      default: return <Badge variant="outline" className="gap-1"><Clock className="h-3 w-3" />Pending</Badge>;
    }
  };

  const getGroupEmoji = (name: string) => {
    const map: Record<string, string> = { Rose: "🌹", Lily: "🌸", Jasmine: "🌼", Orchid: "🌺" };
    return map[name] || "🌸";
  };

  // ─── Render ────────────────────────────────────────────────────
  if (adminLoading || !isAdmin) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="w-12 h-12 border-4 border-primary/30 border-t-primary rounded-full animate-spin" />
      </div>
    );
  }

  if (loading) {
    return (
      <AdminNav>
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary" />
        </div>
      </AdminNav>
    );
  }

  return (
    <AdminNav>
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between mb-6 gap-3">
        <div className="flex items-center gap-2">
          <Shield className="h-6 w-6 text-primary" />
          <h1 className="text-lg sm:text-xl font-semibold">Ghost Mode Monitoring</h1>
        </div>
        <div className="flex gap-2 flex-wrap">
          <Button onClick={() => setNotificationDialogOpen(true)} variant="outline" size="sm" className="gap-2">
            <Bell className="h-4 w-4" /><span className="hidden sm:inline">Broadcast</span>
          </Button>
          <Button onClick={() => { loadMessages(); loadActiveChats(); loadActiveVideoCalls(); loadLiveGroups(); }} variant="outline" size="sm" className="gap-2">
            <RefreshCw className="h-4 w-4" /><span className="hidden sm:inline">Refresh</span>
          </Button>
        </div>
      </div>

      <div className="space-y-6">
        {/* Stats */}
        <div className="grid grid-cols-3 sm:grid-cols-6 gap-3">
          <Card><CardContent className="p-3 sm:p-4">
            <div className="text-xl sm:text-2xl font-bold">{messages.length}</div>
            <div className="text-xs sm:text-sm text-muted-foreground">Messages</div>
          </CardContent></Card>
          <Card><CardContent className="p-3 sm:p-4">
            <div className="text-xl sm:text-2xl font-bold text-destructive">{messages.filter(m => m.flagged).length}</div>
            <div className="text-xs sm:text-sm text-muted-foreground">Flagged</div>
          </CardContent></Card>
          <Card><CardContent className="p-3 sm:p-4">
            <div className="text-xl sm:text-2xl font-bold text-warning">{messages.filter(m => m.moderation_status === "pending").length}</div>
            <div className="text-xs sm:text-sm text-muted-foreground">Pending</div>
          </CardContent></Card>
          <Card><CardContent className="p-3 sm:p-4">
            <div className="text-xl sm:text-2xl font-bold text-primary">{activeChats.length}</div>
            <div className="text-xs sm:text-sm text-muted-foreground">Chats</div>
          </CardContent></Card>
          <Card><CardContent className="p-3 sm:p-4">
            <div className="text-xl sm:text-2xl font-bold text-primary">{activeVideoCalls.length}</div>
            <div className="text-xs sm:text-sm text-muted-foreground">Video</div>
          </CardContent></Card>
          <Card><CardContent className="p-3 sm:p-4">
            <div className="text-xl sm:text-2xl font-bold text-primary">{liveGroups.length}</div>
            <div className="text-xs sm:text-sm text-muted-foreground">Groups</div>
          </CardContent></Card>
        </div>

        <Tabs defaultValue="messages" className="space-y-4">
          <div className="overflow-x-auto -mx-3 px-3 sm:mx-0 sm:px-0">
            <TabsList className="inline-flex w-auto min-w-full sm:grid sm:w-full sm:grid-cols-5">
              <TabsTrigger value="messages" className="gap-1.5 text-xs sm:text-sm whitespace-nowrap"><MessageSquare className="h-4 w-4" /><span className="hidden xs:inline">Messages</span></TabsTrigger>
              <TabsTrigger value="monitoring" className="gap-1.5 text-xs sm:text-sm whitespace-nowrap"><EyeOff className="h-4 w-4" /><span className="hidden xs:inline">Chat</span></TabsTrigger>
              <TabsTrigger value="video-monitor" className="gap-1.5 text-xs sm:text-sm whitespace-nowrap"><Video className="h-4 w-4" /><span className="hidden xs:inline">Video</span></TabsTrigger>
              <TabsTrigger value="group-monitor" className="gap-1.5 text-xs sm:text-sm whitespace-nowrap"><Radio className="h-4 w-4" /><span className="hidden xs:inline">Group</span></TabsTrigger>
              <TabsTrigger value="notifications" className="gap-1.5 text-xs sm:text-sm whitespace-nowrap"><Bell className="h-4 w-4" /><span className="hidden xs:inline">Broadcast</span></TabsTrigger>
            </TabsList>
          </div>

          {/* ─── Messages Tab ─── */}
          <TabsContent value="messages" className="space-y-4">
            <div className="flex flex-col sm:flex-row gap-4">
              <div className="relative flex-1">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                <Input placeholder="Search messages, users, or chat IDs..." value={searchTerm} onChange={(e) => setSearchTerm(e.target.value)} className="pl-9" />
              </div>
              <div className="flex gap-2">
                <Select value={filterFlagged} onValueChange={setFilterFlagged}>
                  <SelectTrigger className="w-[140px]"><Filter className="h-4 w-4 mr-2" /><SelectValue placeholder="Flag Status" /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All Messages</SelectItem>
                    <SelectItem value="flagged">Flagged Only</SelectItem>
                    <SelectItem value="unflagged">Unflagged</SelectItem>
                  </SelectContent>
                </Select>
                <Select value={filterStatus} onValueChange={setFilterStatus}>
                  <SelectTrigger className="w-[140px]"><SelectValue placeholder="Mod Status" /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All Status</SelectItem>
                    <SelectItem value="pending">Pending</SelectItem>
                    <SelectItem value="flagged">Flagged</SelectItem>
                    <SelectItem value="cleared">Cleared</SelectItem>
                    <SelectItem value="removed">Removed</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>

            <ScrollArea className="h-[calc(100dvh-480px)] min-h-[150px]" ref={scrollRef}>
              <div className="space-y-3">
                {filteredMessages.length === 0 ? (
                  <Card><CardContent className="p-8 text-center text-muted-foreground">No messages found</CardContent></Card>
                ) : filteredMessages.map((message, index) => (
                  <Card key={message.id} className={`transition-all hover:shadow-md ${message.flagged ? "border-destructive/50 bg-destructive/5" : ""}`}>
                    <CardContent className="p-4">
                      <div className="flex items-start justify-between gap-4">
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2 mb-2 flex-wrap">
                            {getStatusBadge(message)}
                            <Badge variant="outline" className="gap-1"><User className="h-3 w-3" />{getUserName(message.sender_id)}</Badge>
                            <span className="text-muted-foreground">→</span>
                            <Badge variant="outline" className="gap-1"><User className="h-3 w-3" />{getUserName(message.receiver_id)}</Badge>
                            <span className="text-xs text-muted-foreground">{format(new Date(message.created_at), "MMM d, HH:mm")}</span>
                          </div>
                          <p className="text-sm line-clamp-2">{message.message}</p>
                          {message.flag_reason && <p className="text-xs text-destructive mt-2"><strong>Flag reason:</strong> {message.flag_reason}</p>}
                        </div>
                        <div className="flex items-center gap-1 flex-shrink-0">
                          <Button variant="ghost" size="icon" onClick={() => { setSelectedMessage(message); setViewDialogOpen(true); }}>
                            <Eye className="h-4 w-4" />
                          </Button>
                          {!message.flagged ? (
                            <Button variant="ghost" size="icon" className="text-destructive hover:text-destructive hover:bg-destructive/10" onClick={() => { setSelectedMessage(message); setFlagDialogOpen(true); }}>
                              <Flag className="h-4 w-4" />
                            </Button>
                          ) : (
                            <Button variant="ghost" size="icon" className="text-primary hover:text-primary hover:bg-primary/10" onClick={() => handleUnflag(message)}>
                              <CheckCircle className="h-4 w-4" />
                            </Button>
                          )}
                        </div>
                      </div>
                    </CardContent>
                  </Card>
                ))}
              </div>
            </ScrollArea>
          </TabsContent>

          {/* ─── Chat Ghost Monitor Tab ─── */}
          <TabsContent value="monitoring" className="space-y-4">
            {silentMonitorChatId ? (
              <Card className="border-primary/30">
                <CardHeader className="pb-2">
                  <div className="flex items-center justify-between">
                    <CardTitle className="flex items-center gap-2 text-lg">
                      <EyeOff className="h-5 w-5 text-primary animate-pulse" />
                      👻 Ghost Chat Monitoring Active
                    </CardTitle>
                    <Button variant="destructive" size="sm" onClick={stopSilentMonitoring}>Stop Monitoring</Button>
                  </div>
                  <CardDescription>Chat: {silentMonitorChatId} — Real-time updates — You are invisible</CardDescription>
                </CardHeader>
                <CardContent>
                  <ScrollArea className="h-[400px] border rounded-lg p-4 bg-[#ECE5DD]">
                    <div className="space-y-2">
                      {silentMonitorMessages.map((msg) => {
                        const isMale = profiles[msg.sender_id]?.gender === "male";
                        return (
                          <div key={msg.id} className={`flex ${isMale ? "justify-end" : "justify-start"}`}>
                            <div className={`p-2.5 rounded-lg max-w-[75%] shadow-sm ${isMale ? "bg-[#DCF8C6] rounded-tr-none" : "bg-white rounded-tl-none"}`}>
                              <p className="text-xs font-semibold text-[#075E54] mb-0.5">{getUserName(msg.sender_id)}</p>
                              <p className="text-sm text-gray-800">{msg.message}</p>
                              <div className="flex items-center justify-end gap-1 mt-1">
                                <span className="text-[10px] text-gray-500">{format(new Date(msg.created_at), "HH:mm")}</span>
                                {isMale && (
                                  msg.is_read
                                    ? <CheckCheck className="h-3.5 w-3.5 text-[#34B7F1]" />
                                    : <Check className="h-3.5 w-3.5 text-gray-400" />
                                )}
                              </div>
                            </div>
                          </div>
                        );
                      })}
                      {silentMonitorMessages.length === 0 && <p className="text-center text-muted-foreground py-8">No messages yet</p>}
                    </div>
                  </ScrollArea>
                </CardContent>
              </Card>
            ) : (
              <>
                <div className="flex flex-col sm:flex-row gap-3 flex-wrap">
                  <Select value={monitorLanguageGroupFilter} onValueChange={setMonitorLanguageGroupFilter}>
                    <SelectTrigger className="w-full sm:w-[200px]"><Users className="h-4 w-4 mr-2" /><SelectValue placeholder="Language Group" /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">All Language Groups</SelectItem>
                      {languageGroups.map(g => <SelectItem key={g.id} value={g.id}>{g.name} ({g.languages.length})</SelectItem>)}
                    </SelectContent>
                  </Select>
                  <Select value={monitorCountryFilter} onValueChange={setMonitorCountryFilter}>
                    <SelectTrigger className="w-full sm:w-[200px]"><Globe className="h-4 w-4 mr-2" /><SelectValue placeholder="Country" /></SelectTrigger>
                    <SelectContent><ScrollArea className="h-[300px]">
                      <SelectItem value="all">All Countries</SelectItem>
                      {countries.map(c => <SelectItem key={c.code} value={c.name}>{c.flag} {c.name}</SelectItem>)}
                    </ScrollArea></SelectContent>
                  </Select>
                  <Select value={monitorLanguageFilter} onValueChange={setMonitorLanguageFilter}>
                    <SelectTrigger className="w-full sm:w-[200px]"><Languages className="h-4 w-4 mr-2" /><SelectValue placeholder="Language" /></SelectTrigger>
                    <SelectContent><ScrollArea className="h-[300px]">
                      <SelectItem value="all">All Languages</SelectItem>
                      {languages.map(l => <SelectItem key={l.code} value={l.name}>{l.name} ({l.nativeName})</SelectItem>)}
                    </ScrollArea></SelectContent>
                  </Select>
                </div>

                <ScrollArea className="h-[calc(100dvh-480px)] min-h-[150px]">
                  <div className="space-y-3">
                    {loadingChats ? (
                      <div className="flex items-center justify-center py-8"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" /></div>
                    ) : filteredActiveChats.length === 0 ? (
                      <Card><CardContent className="p-8 text-center text-muted-foreground">No active chats</CardContent></Card>
                    ) : filteredActiveChats.map((chat) => (
                      <Card key={chat.chat_id} className="hover:shadow-md transition-shadow">
                        <CardContent className="p-4">
                          <div className="flex items-center justify-between">
                            <div className="space-y-2">
                              <div className="flex items-center gap-3">
                                <Badge variant="outline" className="gap-1"><User className="h-3 w-3" />{chat.man_name}</Badge>
                                <span className="text-muted-foreground">↔</span>
                                <Badge variant="secondary" className="gap-1"><User className="h-3 w-3" />{chat.woman_name}</Badge>
                              </div>
                              <div className="flex items-center gap-4 text-xs text-muted-foreground">
                                <span className="flex items-center gap-1"><Globe className="h-3 w-3" />{chat.man_country} ↔ {chat.woman_country}</span>
                                <span className="flex items-center gap-1"><Languages className="h-3 w-3" />{chat.man_language} ↔ {chat.woman_language}</span>
                                <span className="flex items-center gap-1"><MessageSquare className="h-3 w-3" />{chat.message_count} msgs</span>
                                <LiveDuration startedAt={chat.started_at} />
                              </div>
                            </div>
                            <Button variant="outline" size="sm" className="gap-2" onClick={() => startSilentMonitoring(chat.chat_id)}>
                              <EyeOff className="h-4 w-4" />👻 Monitor
                            </Button>
                          </div>
                        </CardContent>
                      </Card>
                    ))}
                  </div>
                </ScrollArea>
              </>
            )}
          </TabsContent>

          {/* ─── Video Call Ghost Monitor Tab ─── */}
          <TabsContent value="video-monitor" className="space-y-4">
            {monitoringVideoCallId ? (
              <Card className="border-primary/30">
                <CardHeader>
                  <div className="flex items-center justify-between">
                    <CardTitle className="flex items-center gap-2 text-lg">
                      <Video className="h-5 w-5 text-destructive animate-pulse" />
                      👻 Ghost Video Monitoring Active
                    </CardTitle>
                    <Button variant="destructive" size="sm" onClick={stopVideoMonitoring}>Stop Monitoring</Button>
                  </div>
                </CardHeader>
                <CardContent>
                  {(() => {
                    const call = activeVideoCalls.find((c: any) => c.id === monitoringVideoCallId);
                    if (!call) return <p className="text-center text-muted-foreground py-8">Call ended or not found</p>;
                    return (
                      <div className="space-y-4">
                        <div className="grid grid-cols-2 gap-4">
                          <Card className="bg-muted/30">
                            <CardContent className="p-4 text-center">
                              <User className="h-8 w-8 mx-auto mb-2 text-primary" />
                              <p className="font-semibold">{call.man_name}</p>
                              <p className="text-xs text-muted-foreground">{call.man_country} • {call.man_language}</p>
                              <Badge variant="outline" className="mt-2">Man</Badge>
                            </CardContent>
                          </Card>
                          <Card className="bg-muted/30">
                            <CardContent className="p-4 text-center">
                              <User className="h-8 w-8 mx-auto mb-2 text-secondary-foreground" />
                              <p className="font-semibold">{call.woman_name}</p>
                              <p className="text-xs text-muted-foreground">{call.woman_country} • {call.woman_language}</p>
                              <Badge variant="outline" className="mt-2">Woman</Badge>
                            </CardContent>
                          </Card>
                        </div>
                        <div className="flex items-center justify-center gap-6 py-4">
                          <div className="text-center">
                            <LiveDuration startedAt={call.started_at} />
                            <p className="text-xs text-muted-foreground mt-1">Duration</p>
                          </div>
                          <div className="text-center">
                            <span className="flex items-center gap-1 text-xs font-mono">
                              <DollarSign className="h-3 w-3" />₹{call.rate_per_minute || 8}/min
                            </span>
                            <p className="text-xs text-muted-foreground mt-1">Rate</p>
                          </div>
                          <div className="text-center">
                            <Badge variant={call.status === "active" ? "default" : "secondary"} className="gap-1">
                              <PhoneCall className="h-3 w-3" />{call.status}
                            </Badge>
                            <p className="text-xs text-muted-foreground mt-1">Status</p>
                          </div>
                        </div>
                        <div className="bg-muted/50 rounded-lg p-4 text-center">
                          <EyeOff className="h-10 w-10 mx-auto mb-2 text-muted-foreground" />
                          <p className="text-sm text-muted-foreground">Ghost mode — You are monitoring this video call</p>
                          <p className="text-xs text-muted-foreground mt-1">Participants cannot see or hear you. Call metadata updates in real-time.</p>
                        </div>
                      </div>
                    );
                  })()}
                </CardContent>
              </Card>
            ) : (
              <Card>
                <CardHeader>
                  <div className="flex items-center justify-between">
                    <CardTitle className="flex items-center gap-2 text-lg">
                      <Video className="h-5 w-5 text-primary" />Active Video Calls ({activeVideoCalls.length})
                    </CardTitle>
                    <Button variant="outline" size="sm" onClick={loadActiveVideoCalls} className="gap-2">
                      <RefreshCw className="h-4 w-4" />Refresh
                    </Button>
                  </div>
                  <CardDescription>Silently monitor active 1-on-1 video calls. Participants cannot see you.</CardDescription>
                </CardHeader>
                <CardContent>
                  {loadingVideoCalls ? (
                    <div className="flex items-center justify-center py-8"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" /></div>
                  ) : activeVideoCalls.length === 0 ? (
                    <div className="text-center py-8 text-muted-foreground">
                      <Video className="h-10 w-10 mx-auto mb-2 opacity-40" />
                      <p className="text-sm">No active video calls</p>
                    </div>
                  ) : (
                    <ScrollArea className="max-h-[500px]">
                      <div className="space-y-3">
                        {activeVideoCalls.map((call: any) => (
                          <Card key={call.id} className="hover:shadow-md transition-shadow">
                            <CardContent className="p-4">
                              <div className="flex items-center justify-between">
                                <div className="space-y-2">
                                  <div className="flex items-center gap-3">
                                    <Badge variant="outline" className="gap-1"><User className="h-3 w-3" />{call.man_name}</Badge>
                                    <span className="text-muted-foreground">↔</span>
                                    <Badge variant="secondary" className="gap-1"><User className="h-3 w-3" />{call.woman_name}</Badge>
                                    <Badge className={call.status === "active" ? "bg-destructive/20 text-destructive gap-1" : "bg-warning/20 text-warning gap-1"}>
                                      <Video className="h-3 w-3" />{call.status}
                                    </Badge>
                                  </div>
                                  <div className="flex items-center gap-4 text-xs text-muted-foreground">
                                    <span className="flex items-center gap-1"><Globe className="h-3 w-3" />{call.man_country} ↔ {call.woman_country}</span>
                                    <LiveDuration startedAt={call.started_at} />
                                    {call.rate_per_minute && <span>₹{call.rate_per_minute}/min</span>}
                                  </div>
                                </div>
                                <Button variant="outline" size="sm" className="gap-2" onClick={() => startVideoMonitoring(call.id)}>
                                  <EyeOff className="h-4 w-4" />👻 Monitor
                                </Button>
                              </div>
                            </CardContent>
                          </Card>
                        ))}
                      </div>
                    </ScrollArea>
                  )}
                </CardContent>
              </Card>
            )}
          </TabsContent>

          {/* ─── Group Ghost Monitor Tab ─── */}
          <TabsContent value="group-monitor" className="space-y-4">
            {monitoringGroupId ? (
              <Card className="border-primary/30">
                <CardHeader className="pb-2">
                  <div className="flex items-center justify-between">
                    <CardTitle className="flex items-center gap-2 text-lg">
                      <EyeOff className="h-5 w-5 text-primary animate-pulse" />
                      👻 Ghost Group Monitoring Active
                    </CardTitle>
                    <Button variant="destructive" size="sm" onClick={stopGroupMonitoring}>Stop Monitoring</Button>
                  </div>
                  <CardDescription>
                    Group: {liveGroups.find((g: any) => g.id === monitoringGroupId)?.name || "Unknown"} — You are invisible to participants
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  {/* Participants panel */}
                  {groupParticipants.length > 0 && (
                    <div>
                      <h4 className="text-sm font-medium mb-2 flex items-center gap-2"><Users className="h-4 w-4" />Participants ({groupParticipants.length})</h4>
                      <div className="flex flex-wrap gap-2">
                        {groupParticipants.map((p: any) => (
                          <Badge key={p.user_id} variant="outline" className="gap-1 text-xs">
                            <User className="h-3 w-3" />
                            {p.full_name} ({p.gender === "female" ? "W" : "M"} • {p.country})
                          </Badge>
                        ))}
                      </div>
                    </div>
                  )}
                  {/* Chat messages */}
                  <ScrollArea className="h-[400px] border rounded-lg p-4 bg-muted/30">
                    <div className="space-y-3">
                      {groupMessages.map((msg: any) => (
                        <div key={msg.id} className="p-3 rounded-lg max-w-[80%] bg-muted">
                          <div className="flex items-center gap-2 mb-1">
                            <Badge variant="secondary" className="text-xs">{msg.sender_name}</Badge>
                            <span className="text-xs text-muted-foreground">{format(new Date(msg.created_at), "HH:mm:ss")}</span>
                          </div>
                          <p className="text-sm">{msg.message}</p>
                        </div>
                      ))}
                      {groupMessages.length === 0 && <p className="text-center text-muted-foreground py-8">No messages yet</p>}
                    </div>
                  </ScrollArea>
                </CardContent>
              </Card>
            ) : (
              <Card>
                <CardHeader>
                  <div className="flex items-center justify-between">
                    <CardTitle className="flex items-center gap-2 text-lg">
                      <Radio className="h-5 w-5 text-primary" />Live Private Groups ({liveGroups.length})
                    </CardTitle>
                    <Button variant="outline" size="sm" onClick={loadLiveGroups} className="gap-2">
                      <RefreshCw className="h-4 w-4" />Refresh
                    </Button>
                  </div>
                  <CardDescription>Silently monitor active private group calls and chat. Not visible to participants.</CardDescription>
                </CardHeader>
                <CardContent>
                  {loadingGroups ? (
                    <div className="flex items-center justify-center py-8"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" /></div>
                  ) : liveGroups.length === 0 ? (
                    <div className="text-center py-8 text-muted-foreground">
                      <Radio className="h-10 w-10 mx-auto mb-2 opacity-40" />
                      <p className="text-sm">No groups are live</p>
                    </div>
                  ) : (
                    <ScrollArea className="max-h-[500px]">
                      <div className="space-y-3">
                        {liveGroups.map((group: any) => (
                          <Card key={group.id} className="hover:shadow-md transition-shadow border-destructive/30">
                            <CardContent className="p-4">
                              <div className="flex items-center justify-between">
                                <div className="space-y-2">
                                  <div className="flex items-center gap-3">
                                    <span className="text-xl">{getGroupEmoji(group.name)}</span>
                                    <span className="font-semibold">{group.name}</span>
                                    <Badge variant="destructive" className="gap-1 animate-pulse"><Radio className="h-3 w-3" />LIVE</Badge>
                                  </div>
                                  <div className="flex items-center gap-4 text-xs text-muted-foreground">
                                    <span className="flex items-center gap-1"><User className="h-3 w-3" />Host: {group.current_host_name || "Unknown"}</span>
                                    <span className="flex items-center gap-1"><Users className="h-3 w-3" />{group.participant_count} participants</span>
                                  </div>
                                </div>
                                <Button variant="outline" size="sm" className="gap-2" onClick={() => startGroupMonitoring(group.id)}>
                                  <EyeOff className="h-4 w-4" />👻 Monitor
                                </Button>
                              </div>
                            </CardContent>
                          </Card>
                        ))}
                      </div>
                    </ScrollArea>
                  )}
                </CardContent>
              </Card>
            )}
          </TabsContent>

          {/* ─── Notifications Tab ─── */}
          <TabsContent value="notifications" className="space-y-4">
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2"><Bell className="h-5 w-5" />Broadcast Notifications</CardTitle>
                <CardDescription>Send notifications to all users, men only, or women only</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-2">
                  <label className="text-sm font-medium">Target Audience</label>
                  <div className="flex gap-2">
                    <Button variant={notificationTarget === "all" ? "default" : "outline"} size="sm" onClick={() => setNotificationTarget("all")} className="gap-2"><Globe className="h-4 w-4" />All Users</Button>
                    <Button variant={notificationTarget === "men" ? "default" : "outline"} size="sm" onClick={() => setNotificationTarget("men")} className="gap-2"><Users className="h-4 w-4" />Men Only</Button>
                    <Button variant={notificationTarget === "women" ? "default" : "outline"} size="sm" onClick={() => setNotificationTarget("women")} className="gap-2"><Users className="h-4 w-4" />Women Only</Button>
                  </div>
                </div>
                <div className="space-y-2">
                  <label className="text-sm font-medium">Title</label>
                  <Input placeholder="Enter notification title..." value={notificationTitle} onChange={(e) => setNotificationTitle(e.target.value)} />
                </div>
                <div className="space-y-2">
                  <label className="text-sm font-medium">Message</label>
                  <Textarea placeholder="Enter notification message..." value={notificationMessage} onChange={(e) => setNotificationMessage(e.target.value)} rows={4} />
                </div>
                <Button onClick={sendBroadcastNotification} disabled={sendingNotification || !notificationTitle.trim() || !notificationMessage.trim()} className="gap-2">
                  <Send className="h-4 w-4" />{sendingNotification ? "Sending..." : "Send Notification"}
                </Button>
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </div>

      {/* ─── Flag Dialog ─── */}
      <Dialog open={flagDialogOpen} onOpenChange={setFlagDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2"><Flag className="h-5 w-5 text-destructive" />Flag Message</DialogTitle>
            <DialogDescription>Provide a reason for flagging this message.</DialogDescription>
          </DialogHeader>
          {selectedMessage && (
            <div className="space-y-4">
              <div className="p-3 bg-muted rounded-lg"><p className="text-sm">{selectedMessage.message}</p></div>
              <Textarea placeholder="Enter reason..." value={flagReason} onChange={(e) => setFlagReason(e.target.value)} rows={3} />
            </div>
          )}
          <DialogFooter>
            <Button variant="outline" onClick={() => setFlagDialogOpen(false)}>Cancel</Button>
            <Button variant="destructive" onClick={handleFlag}>Flag Message</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ─── View Dialog ─── */}
      <Dialog open={viewDialogOpen} onOpenChange={setViewDialogOpen}>
        <DialogContent className="max-w-lg">
          <DialogHeader><DialogTitle>Message Details</DialogTitle></DialogHeader>
          {selectedMessage && (
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4 text-sm">
                <div><span className="text-muted-foreground">From:</span><p className="font-medium">{getUserName(selectedMessage.sender_id)}</p></div>
                <div><span className="text-muted-foreground">To:</span><p className="font-medium">{getUserName(selectedMessage.receiver_id)}</p></div>
                <div><span className="text-muted-foreground">Sent:</span><p className="font-medium">{format(new Date(selectedMessage.created_at), "MMM d, yyyy HH:mm:ss")}</p></div>
                <div><span className="text-muted-foreground">Status:</span><div className="mt-1">{getStatusBadge(selectedMessage)}</div></div>
              </div>
              <div>
                <span className="text-sm text-muted-foreground">Message:</span>
                <div className="p-3 bg-muted rounded-lg mt-1"><p className="text-sm">{selectedMessage.message}</p></div>
              </div>
              {selectedMessage.flag_reason && (
                <div>
                  <span className="text-sm text-muted-foreground">Flag Reason:</span>
                  <div className="p-3 bg-destructive/10 rounded-lg mt-1 border border-destructive/20"><p className="text-sm text-destructive">{selectedMessage.flag_reason}</p></div>
                </div>
              )}
            </div>
          )}
          <DialogFooter className="flex-wrap gap-2">
            {selectedMessage?.flagged && (
              <>
                <Button variant="outline" className="text-primary" onClick={() => { handleResolve(selectedMessage, "cleared"); setViewDialogOpen(false); }}>
                  <CheckCircle className="h-4 w-4 mr-2" />Cleared
                </Button>
                <Button variant="destructive" onClick={() => { handleResolve(selectedMessage, "removed"); setViewDialogOpen(false); }}>
                  <XCircle className="h-4 w-4 mr-2" />Removed
                </Button>
              </>
            )}
            <Button variant="outline" onClick={() => setViewDialogOpen(false)}>Close</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ─── Broadcast Dialog ─── */}
      <Dialog open={notificationDialogOpen} onOpenChange={setNotificationDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2"><Bell className="h-5 w-5 text-primary" />Broadcast Notification</DialogTitle>
            <DialogDescription>Send a notification to users</DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div className="space-y-2">
              <label className="text-sm font-medium">Audience</label>
              <div className="flex gap-2 flex-wrap">
                <Button variant={notificationTarget === "all" ? "default" : "outline"} size="sm" onClick={() => setNotificationTarget("all")} className="gap-2"><Globe className="h-4 w-4" />All</Button>
                <Button variant={notificationTarget === "men" ? "default" : "outline"} size="sm" onClick={() => setNotificationTarget("men")} className="gap-2"><Users className="h-4 w-4" />Men</Button>
                <Button variant={notificationTarget === "women" ? "default" : "outline"} size="sm" onClick={() => setNotificationTarget("women")} className="gap-2"><Users className="h-4 w-4" />Women</Button>
              </div>
            </div>
            <div className="space-y-2">
              <label className="text-sm font-medium">Title</label>
              <Input placeholder="Title..." value={notificationTitle} onChange={(e) => setNotificationTitle(e.target.value)} />
            </div>
            <div className="space-y-2">
              <label className="text-sm font-medium">Message</label>
              <Textarea placeholder="Message..." value={notificationMessage} onChange={(e) => setNotificationMessage(e.target.value)} rows={4} />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setNotificationDialogOpen(false)}>Cancel</Button>
            <Button onClick={sendBroadcastNotification} disabled={sendingNotification || !notificationTitle.trim() || !notificationMessage.trim()} className="gap-2">
              <Send className="h-4 w-4" />{sendingNotification ? "Sending..." : "Send"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </AdminNav>
  );
};

export default AdminChatMonitoring;