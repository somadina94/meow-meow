import { classifyError, ERROR_MESSAGES, logError } from "@/lib/errors";
import { countries } from "@/data/countries";
import { useState, useEffect, useRef } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarImage, AvatarFallback } from "@/components/ui/avatar";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import ProfileEditDialog from "@/components/ProfileEditDialog";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useToast } from "@/hooks/use-toast";
import { 
  Heart, 
  Bell, 
  MessageCircle, 
  Settings,
  ChevronRight,
  LogOut,
  Wallet,
  CreditCard,
  CheckCircle2,
  RefreshCw,
  Eye,
  Compass,
  UserCircle,
  Video,
  Gift,
  Shield,
  Mail,
  Phone,
  User,
  Loader2,
  Search
} from "lucide-react";
import { Input } from "@/components/ui/input";
import { FriendsBlockedPanel } from "@/components/FriendsBlockedPanel";
import { Switch } from "@/components/ui/switch";
import { supabase } from "@/integrations/supabase/client";
import { cn, formatChatTime } from "@/lib/utils";
// ActiveChatsSection removed - chats now handled via EnhancedParallelChatsContainer
// RandomChatButton removed — not used in WhatsApp-style layout
// TeamsChatLayout removed - chats now handled via EnhancedParallelChatsContainer only
import EnhancedParallelChatsContainer from "@/components/EnhancedParallelChatsContainer";
import { AvailableGroupsSection } from "@/components/AvailableGroupsSection";
import { UserAdminChat } from "@/components/UserAdminChat";
import { AdminMessagesWidget } from "@/components/AdminMessagesWidget";
import { useAdminUnreadCounts } from "@/hooks/useAdminUnreadCounts";
// MenFreeMinutesBadge removed - free minutes feature removed
import { useIncomingCallListener } from "@/hooks/useIncomingCallListener";
import { useAppCall } from "@/hooks/useAppCall";
import { CallScreen } from "@/components/CallScreen";
import { IncomingCallBanner } from "@/components/IncomingCallBanner";
// LanguageCommunityPanel removed - language chat is women-only

import { useChatPricing } from '@/hooks/useChatPricing';
import { StatementTab } from '@/components/StatementTab';
import { useAutoReconnect } from "@/hooks/useAutoReconnect";
import { useAtomicTransaction } from "@/hooks/useAtomicTransaction";
import { useActivityBasedStatus } from "@/hooks/useActivityBasedStatus";
import { useAppSettings } from "@/hooks/useAppSettings";
import { useMessageSound } from "@/hooks/useMessageSound";
import { MatchFiltersPanel, MatchFilters } from "@/components/MatchFiltersPanel";
import { AppHeader } from "@/components/AppHeader";
import { AppBottomTabs, getMenTabs } from "@/components/AppBottomTabs";
import GroupChatTab from "@/components/GroupChatTab";

import { UserContactCard } from "@/components/UserContactCard";
import { isVisibilityStatusChange } from "@/lib/presence";
// WhatsAppFAB removed — unused in current layout
import { CallHistoryTab } from "@/components/CallHistoryTab";
import { ErrorBoundary } from "@/components/ErrorBoundary";
import { ScrollingAnnouncementsBar } from "@/components/ScrollingAnnouncementsBar";
import { canCallEachOther, isIndianCallLanguage, pickCallLanguage } from "@/lib/call-languages";
// TransactionStatementTab removed — billing system removed
interface Notification {
  id: string;
  title: string;
  message: string;
  type: string;
  is_read: boolean;
  created_at: string;
}

interface OnlineWoman {
  id: string;
  user_id: string;
  full_name: string;
  photo_url: string | null;
  age: number | null;
  country: string | null;
  state: string | null;
  primary_language: string | null;
  active_chat_count?: number; // 0=Free (green), 1-2=Busy (yellow), 3=Full (red)
  is_available?: boolean;
  max_chats?: number;
  is_earning_eligible?: boolean; // Badged women shown at top
  walletBalance?: number; // Women's wallet/earning balance
}

interface MatchedWoman {
  matchId: string;
  userId: string;
  fullName: string;
  photoUrl: string | null;
  age: number | null;
  country: string | null;
  state: string | null;
  primaryLanguage: string | null;
  isOnline: boolean;
  matchedAt: string;
}

interface DashboardStats {
  onlineUsersCount: number;
  matchCount: number;
  unreadNotifications: number;
}

interface PaymentGateway {
  id: string;
  name: string;
  logo: string;
  description: string;
  features?: string[];
}

// Payment gateways for men's wallet recharge
const INDIAN_GATEWAYS: PaymentGateway[] = [
  { id: "razorpay", name: "Razorpay", logo: "💳", description: "Cards, UPI, Wallets, EMI", features: ["Cards", "UPI", "Wallets", "EMI"] },
];

const INTERNATIONAL_GATEWAYS: PaymentGateway[] = [];

const ALL_PAYMENT_GATEWAYS: PaymentGateway[] = [...INDIAN_GATEWAYS, ...INTERNATIONAL_GATEWAYS];

// ScrollableUserList removed — not used in WhatsApp tab layout

const DashboardScreen = () => {
  const navigate = useNavigate();
  const { toast } = useToast();
  // Plain English helper - no translation, returns fallback directly
  
  const { creditWallet } = useAtomicTransaction();
  const [isLoading, setIsLoading] = useState(true);
  const [currentUserId, setCurrentUserId] = useState("");
  const [userName, setUserName] = useState("");
  const [appId, setAppId] = useState<string | null>(null);
  const [userPhoto, setUserPhoto] = useState<string | null>(null); // User's photo for chat validation
  const { incomingCall, clearIncomingCall } = useIncomingCallListener(currentUserId || null, "male");
  const [userCountry, setUserCountry] = useState("IN");
  const [userCountryName, setUserCountryName] = useState(""); // Full country name for language feature
  const [userLanguage, setUserLanguage] = useState("English"); // User's primary language
  const userLanguageRef = useRef(userLanguage);
  const [userLanguageCode, setUserLanguageCode] = useState("eng_Latn"); // Language language code
  const [walletBalance, setWalletBalance] = useState(0);
  const { status: callStatus, activeCall, isMuted, isCameraOff, initiateCall, acceptCall, declineCall, endCall, toggleMute, toggleCamera } = useAppCall(currentUserId || null, 'male', walletBalance);
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [sameLanguageWomen, setSameLanguageWomen] = useState<OnlineWoman[]>([]);
  const [indianTranslatedWomen, setIndianTranslatedWomen] = useState<OnlineWoman[]>([]);
  const [loadingOnlineWomen, setLoadingOnlineWomen] = useState(false);
  const [matchedWomen, setMatchedWomen] = useState<MatchedWoman[]>([]);
  const [loadingMatches, setLoadingMatches] = useState(false);
  const [isNonIndianUser, setIsNonIndianUser] = useState(false); // Is man's language non-Indian but Language supported
  const [activeChatCount, setActiveChatCount] = useState(0);
  const [isConnecting, setIsConnecting] = useState(false);
  const [connectingUserId, setConnectingUserId] = useState<string | null>(null);
  const [stats, setStats] = useState<DashboardStats>({
    onlineUsersCount: 0,
    matchCount: 0,
    unreadNotifications: 0,
  });
  const [rechargeDialogOpen, setRechargeDialogOpen] = useState(false);
  const [profileEditOpen, setProfileEditOpen] = useState(false);
  const [showFriendsPanel, setShowFriendsPanel] = useState(false);
  const [showAdminChat, setShowAdminChat] = useState(false);
  const [showAdminMessages, setShowAdminMessages] = useState(false);
  const [selectedGateway, setSelectedGateway] = useState("razorpay");
  const [selectedAmount, setSelectedAmount] = useState<number | null>(null);
  const [processingPayment, setProcessingPayment] = useState(false);
  const [customAmount, setCustomAmount] = useState("");
  const [privateGroupsRefreshKey, setPrivateGroupsRefreshKey] = useState(0);
  const [activeTab, setActiveTab] = useState("online");
  const matchesFetchedRef = useRef(false);
  const chatsFetchedRef = useRef(false);
  const chatsInFlightRef = useRef(false);
  const lastChatsFetchRef = useRef(0);
  const onlineWomenLoadedRef = useRef(false);
  const userStatusSnapshotRef = useRef<Map<string, string>>(new Map());
  const [activeChats, setActiveChats] = useState<Array<{
    chatId: string;
    partnerId: string;
    partnerName: string;
    partnerPhoto: string | null;
    lastMessage: string;
    lastMessageAt: string;
    lastMessageSenderId: string;
    unreadCount: number;
    partnerIsOnline: boolean;
    partnerStatus: string;
    partnerActiveChatCount: number;
  }>>([]);
  const [loadingChats, setLoadingChats] = useState(false);
  // GESS ID search across Online / Chats / Matches tabs
  const [userCodeMap, setUserCodeMap] = useState<Record<string, string>>({});
  const [searchOnline, setSearchOnline] = useState("");
  const [searchChats, setSearchChats] = useState("");
  const [searchMatches, setSearchMatches] = useState("");
  // App settings (currency rates, payment gateways, recharge amounts - all from database)
  const { settings } = useAppSettings();
  const [matchFilters, setMatchFilters] = useState<MatchFilters>({
    ageRange: [18, 60],
    heightRange: [140, 200],
    bodyType: "all",
    educationLevel: "all",
    occupation: "all",
    religion: "all",
    maritalStatus: "all",
    hasChildren: "all",
    country: "all",
    language: "all",
    distanceRange: [0, 15000],
    smokingHabit: "all",
    drinkingHabit: "all",
    dietaryPreference: "all",
    fitnessLevel: "all",
    petPreference: "all",
    travelFrequency: "all",
    zodiacSign: "all",
    personalityType: "all",
    onlineNow: false,
    verifiedOnly: false,
    premiumOnly: false,
    newUsersOnly: false,
    hasPhoto: false,
    hasBio: false,
  });

  // Chat pricing from database
  const { pricing, hasSufficientBalance, formatPrice } = useChatPricing();
  
  // Auto-reconnect functionality
  const { 
    isReconnecting, 
    findNextAvailableWoman, 
    initiateReconnect 
  } = useAutoReconnect(currentUserId, userLanguage);

  const { unreadMessages: unreadAdminMessages, unreadChat: unreadAdminChat } = useAdminUnreadCounts(currentUserId || null);

  // Fetch GESS user_code map for any visible user (women lists / matches / chats)
  useEffect(() => {
    const ids = new Set<string>();
    sameLanguageWomen.forEach(w => w.user_id && ids.add(w.user_id));
    indianTranslatedWomen.forEach(w => w.user_id && ids.add(w.user_id));
    matchedWomen.forEach(m => m.userId && ids.add(m.userId));
    activeChats.forEach(c => c.partnerId && ids.add(c.partnerId));
    const missing = Array.from(ids).filter(id => !(id in userCodeMap));
    if (missing.length === 0) return;
    (async () => {
      const { data } = await supabase.from('profiles').select('user_id, user_code').in('user_id', missing);
      if (!data) return;
      setUserCodeMap(prev => {
        const next = { ...prev };
        (data as Array<{ user_id: string; user_code: string | null }>).forEach(p => {
          if (p.user_code) next[p.user_id] = p.user_code;
        });
        return next;
      });
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sameLanguageWomen, indianTranslatedWomen, matchedWomen, activeChats]);

  const matchesUserSearch = (q: string, userId: string, name?: string | null) => {
    const s = q.trim().toLowerCase();
    if (!s) return true;
    const code = (userCodeMap[userId] || '').toLowerCase();
    return code.includes(s) || (userId || '').toLowerCase().includes(s) || (name || '').toLowerCase().includes(s);
  };

  // Men's free chat minutes removed - feature deprecated

  // ScrollableUserList extracted to avoid hooks-in-render violations - see below

  const { playMessageSound } = useMessageSound();

  // Activity-based online/offline status (10 min inactivity = offline)
  const { 
    isOnline, 
    isManuallyOffline,
    toggleOnlineStatus 
  } = useActivityBasedStatus({
    userId: currentUserId,
    inactivityTimeout: 10 * 60 * 1000, // 10 minutes
    onStatusChange: (online) => {
      if (!online) {
        toast({
          title: 'Gone Offline',
          description: 'You went offline due to inactivity',
        });
      }
    }
  });

  // Derived values from settings (dynamic, not hardcoded)
  const CURRENCY_RATES = settings.currencyRates;
  const RECHARGE_AMOUNTS_INR = settings.rechargeAmounts;
  // Payment gateways are defined as constants above, not from app_settings
  const ALL_GATEWAYS = ALL_PAYMENT_GATEWAYS;

  // Get currency info based on user's country
  const getCurrencyInfo = () => {
    return CURRENCY_RATES[userCountry] || CURRENCY_RATES.DEFAULT || { rate: 0.012, symbol: "$", code: "USD" };
  };

  // Convert INR to local currency
  const convertToLocal = (amountINR: number) => {
    const currency = getCurrencyInfo();
    const converted = amountINR * currency.rate;
    // Round appropriately based on currency
    if (currency.code === "JPY" || currency.code === "KRW") {
      return Math.round(converted);
    }
    return Math.round(converted * 100) / 100;
  };

  // formatChatTime now imported from @/lib/utils

  // Format currency display
  const formatLocalCurrency = (amountINR: number) => {
    const currency = getCurrencyInfo();
    const converted = convertToLocal(amountINR);
    return `${currency.symbol}${converted.toFixed(2)}`;
  };

  const wentOnlineRef = useRef(false);
  const mountedRef = useRef(true);
  useEffect(() => {
    mountedRef.current = true;
    return () => { mountedRef.current = false; };
  }, []);
  // Hoisted function declaration prevents production minifier TDZ regressions.
  function redirectToWomenDashboard() {
    if (!mountedRef.current) return;
    if (window.location.pathname === "/women-dashboard") return;
    navigate("/women-dashboard", { replace: true });
  }

  // TDZ-safe dashboard helpers: declared before effects and before callers.
  async function fetchOnlineUsersCount() {
    try {
      const { count, error } = await supabase
        .from("user_status")
        .select("*", { count: "exact", head: true })
        .eq("is_online", true)
        .neq("status_text", "busy");

      if (error) {
        console.warn('[Dashboard] Error fetching online users count:', error);
        return;
      }

      setStats(prev => ({ ...prev, onlineUsersCount: count || 0 }));
    } catch (error) {
      console.warn('[Dashboard] Failed to fetch online users count:', error);
    }
  };

  async function fetchMatchCount(userId: string) {
    // Kept for backward compat; UI now uses matchedWomen.length (deduped, gender-filtered)
    const { count } = await supabase
      .from("matches")
      .select("*", { count: "exact", head: true })
      .or(`user_id.eq.${userId},matched_user_id.eq.${userId}`)
      .eq("status", "accepted");

    setStats(prev => ({ ...prev, matchCount: count || 0 }));
  };

  async function fetchNotifications(userId: string) {
    try {
      const { data, count } = await supabase
        .from("notifications")
        .select("*", { count: "exact" })
        .eq("user_id", userId)
        .eq("is_read", false)
        .order("created_at", { ascending: false })
        .limit(5);

      // Display notifications as-is (no translation)
      setNotifications(data || []);
      setStats(prev => ({ ...prev, unreadNotifications: count || 0 }));
    } catch (error) {
      console.error('[Dashboard] fetchNotifications error:', error);
    }
  };

  async function fetchOnlineWomen(language: string) {
    // Only show the full-list spinner on the first load. Background refetches
    // used to unmount the Online tab on every user_status heartbeat.
    if (!onlineWomenLoadedRef.current) setLoadingOnlineWomen(true);
    try {

      // Get ONLY truly-online & not-busy user IDs.
      // Ghost-user guard: require last_seen within the last 5 minutes so
      // stale is_online=true rows from crashed sessions are excluded.
      const freshCutoffIso = new Date(Date.now() - 5 * 60 * 1000).toISOString();
      const { data: onlineUsers } = await supabase
        .from("user_status")
        .select("user_id, status_text, last_seen")
        .eq("is_online", true)
        .neq("status_text", "busy")
        .gte("last_seen", freshCutoffIso);

      const onlineUserIds = (onlineUsers || []).map(u => u.user_id);
      
      // If no users online, show empty lists
      if (onlineUserIds.length === 0) {
        setSameLanguageWomen([]);
        setIndianTranslatedWomen([]);
        setLoadingOnlineWomen(false);
        return;
      }

      // Fetch ONLY online women from safe public view (excludes sensitive bank/PAN/phone/DOB fields)
      const { data: femaleProfiles } = await supabase
        .from("public_female_profiles" as any)
        .select("id, user_id, full_name, photo_url, age, country, state, primary_language, is_earning_eligible")
        .in("user_id", onlineUserIds)
        .limit(50);

      const onlineWomenList: OnlineWoman[] = femaleProfiles || [];

      if (onlineWomenList.length === 0) {
        setSameLanguageWomen([]);
        setIndianTranslatedWomen([]);
        setLoadingOnlineWomen(false);
        return;
      }

      // Fetch chat counts, availability, and languages in PARALLEL
      const womenUserIds = onlineWomenList.map(w => w.user_id);
      const [chatCountsRes, availabilityRes, userLanguagesRes, walletsRes] = await Promise.all([
        supabase
          .from("active_chat_sessions")
          .select("woman_user_id, status")
          .in("woman_user_id", womenUserIds)
          .in("status", ["active", "pending"]),
        supabase
          .from("women_availability")
          .select("user_id, is_available, current_chat_count, max_concurrent_chats")
          .in("user_id", womenUserIds),
        supabase
          .from("user_languages")
          .select("user_id, language_name")
          .in("user_id", womenUserIds),
        supabase
          .from("wallets")
          .select("user_id, balance")
          .in("user_id", womenUserIds),
      ]);

      const chatCountMap = new Map<string, number>();
      chatCountsRes.data?.forEach(chat => {
        const count = chatCountMap.get(chat.woman_user_id) || 0;
        chatCountMap.set(chat.woman_user_id, count + 1);
      });

      const availabilityMap = new Map(
        (availabilityRes.data as any[] || []).map(a => [a.user_id, a])
      );

      const languageMap = new Map<string, string>();
      for (const l of (userLanguagesRes.data as { user_id: string; language_name: string }[] || [])) {
        const existing = languageMap.get(l.user_id);
        if (!existing || (!isIndianCallLanguage(existing) && isIndianCallLanguage(l.language_name))) {
          languageMap.set(l.user_id, l.language_name);
        }
      }

      const walletMap = new Map<string, number>(
        (walletsRes.data as any[] || []).map((w: any) => [w.user_id, Number(w.balance) || 0])
      );

      const womenWithChatCount = onlineWomenList.map(w => {
        const avail = availabilityMap.get(w.user_id);
        const chatCount = avail?.current_chat_count || chatCountMap.get(w.user_id) || 0;
        const womanLanguage = pickCallLanguage(w.primary_language, languageMap.get(w.user_id)) || w.primary_language || "Unknown";
        return {
          ...w,
          primary_language: womanLanguage,
          active_chat_count: chatCount,
          is_available: avail?.is_available !== false,
          max_chats: avail?.max_concurrent_chats || 3,
          is_earning_eligible: w.is_earning_eligible || false,
          walletBalance: walletMap.get(w.user_id) || 0,
        };
      });

      // Sort: Badged (earning eligible) women first, then by availability and load
      const sortByBadgeAndLoad = (a: typeof womenWithChatCount[0], b: typeof womenWithChatCount[0]) => {
        if (a.is_earning_eligible !== b.is_earning_eligible) {
          return a.is_earning_eligible ? -1 : 1;
        }
        if (a.is_available !== b.is_available) return a.is_available ? -1 : 1;
        const aAtMax = a.active_chat_count >= a.max_chats;
        const bAtMax = b.active_chat_count >= b.max_chats;
        if (aAtMax !== bAtMax) return aAtMax ? 1 : -1;
        return a.active_chat_count - b.active_chat_count;
      };

      // Apply match filters client-side
      const filteredWomen = womenWithChatCount.filter(w => {
        if (matchFilters.ageRange && w.age != null) {
          if (w.age < matchFilters.ageRange[0] || w.age > matchFilters.ageRange[1]) return false;
        }
        if (matchFilters.country && matchFilters.country !== "all" && w.country) {
          if (w.country.toLowerCase() !== matchFilters.country.toLowerCase()) return false;
        }
        if (matchFilters.language && matchFilters.language !== "all" && w.primary_language) {
          if (w.primary_language.toLowerCase() !== matchFilters.language.toLowerCase()) return false;
        }
        if (matchFilters.verifiedOnly) return true;
        return true;
      });

      // Split: same language first, others second
      const sameLanguage = filteredWomen
        .filter(w => w.primary_language?.toLowerCase() === language.toLowerCase())
        .sort(sortByBadgeAndLoad);

      const otherWomen = filteredWomen
        .filter(w => w.primary_language?.toLowerCase() !== language.toLowerCase())
        .sort(sortByBadgeAndLoad);

      setSameLanguageWomen(sameLanguage.slice(0, 10));
      setIndianTranslatedWomen(otherWomen.slice(0, 15));
    } catch (error) {
      console.error("Error fetching online women:", error);
      setSameLanguageWomen([]);
      setIndianTranslatedWomen([]);
    } finally {
      onlineWomenLoadedRef.current = true;
      setLoadingOnlineWomen(false);
    }
  };

  async function fetchActiveChats() {
    if (!currentUserId) return;
    const now = Date.now();
    const isFirstLoad = !chatsFetchedRef.current;
    // Debounce background refetches so presence/message storms cannot pile up RPCs.
    if (!isFirstLoad && (chatsInFlightRef.current || now - lastChatsFetchRef.current < 2500)) return;
    lastChatsFetchRef.current = now;
    chatsInFlightRef.current = true;
    if (isFirstLoad) setLoadingChats(true);
    try {
      const { data, error } = await supabase.rpc('get_man_active_chats', {
        p_user_id: currentUserId,
      });
      if (error) throw error;

      const chats = ((data as any[]) || []).map(r => ({
        chatId: r.chat_id as string,
        partnerId: r.partner_id as string,
        partnerName: r.partner_name as string,
        partnerPhoto: (r.partner_photo as string) || null,
        lastMessage: (r.last_message as string) || '',
        lastMessageAt: r.last_message_at as string,
        lastMessageSenderId: (r.last_message_sender_id as string) || '',
        unreadCount: Number(r.unread_count) || 0,
        partnerIsOnline: Boolean(r.partner_is_online),
        partnerStatus: (r.partner_status as string) || 'offline',
        partnerActiveChatCount: Number(r.partner_active_chat_count) || 0,
      }));
      setActiveChats(chats);
      chatsFetchedRef.current = true;
    } catch (error) {
      console.error('[Dashboard] Error fetching active chats:', error);
    } finally {
      chatsInFlightRef.current = false;
      setLoadingChats(false);
    }
  };

  async function loadActiveChatCount() {
    if (!currentUserId) return;
    
    const { count } = await supabase
      .from("active_chat_sessions")
      .select("*", { count: "exact", head: true })
      .eq("man_user_id", currentUserId)
      .in("status", ["active", "pending"]);
    
    setActiveChatCount(count || 0);
    
    // Only fetch chat details if chats tab has been opened
    if (chatsFetchedRef.current) {
      fetchActiveChats();
    }
  };

  async function loadWalletBalance() {
    if (!currentUserId) return;
    const { data } = await supabase.rpc('get_men_wallet_balance', {
      p_user_id: currentUserId
    });
    if (data) {
      const bd = data as Record<string, number>;
      setWalletBalance(Number(bd.balance) || 0);
    }
  };

  async function fetchMatchedWomen(userId: string) {
    setLoadingMatches(true);
    try {
      // Fetch all matches (both pending and accepted) where this man is involved
      const { data: matches } = await supabase
        .from("matches")
        .select("id, matched_user_id, user_id, matched_at, status")
        .or(`user_id.eq.${userId},matched_user_id.eq.${userId}`)
        .order("matched_at", { ascending: false })
        .limit(50);

      if (!matches || matches.length === 0) {
        setMatchedWomen([]);
        setLoadingMatches(false);
        return;
      }

      // Get unique other user IDs from each match (deduplicate)
      const otherUserIds = [...new Set(matches.map(m => 
        m.user_id === userId ? m.matched_user_id : m.user_id
      ))] as string[];

      // Fetch profiles for matched users via secure RPC
      const { fetchPublicProfiles } = await import("@/lib/profile-queries");
      const profiles = await fetchPublicProfiles(otherUserIds);

      // Fetch online status
      const { data: statuses } = await supabase
        .from("user_status")
        .select("user_id, is_online")
        .in("user_id", otherUserIds);

      const statusMap = new Map((statuses as any[] || []).map(s => [s.user_id, s.is_online]));
      const profileMap = new Map((profiles as any[] || []).map(p => [p.user_id, p]));

      const seenUserIds = new Set<string>();
      const matched: MatchedWoman[] = matches
        .map(m => {
          const otherId = m.user_id === userId ? m.matched_user_id : m.user_id;
          if (seenUserIds.has(otherId)) return null;
          seenUserIds.add(otherId);
          const profile = profileMap.get(otherId);
          if (!profile || profile.gender?.toLowerCase() !== 'female') return null;
          return {
            matchId: m.id,
            userId: otherId,
            fullName: profile.full_name || 'Anonymous',
            photoUrl: profile.photo_url,
            age: profile.age,
            country: profile.country,
            state: profile.state,
            primaryLanguage: profile.primary_language,
            isOnline: statusMap.get(otherId) || false,
            matchedAt: m.matched_at,
          };
        })
        .filter(Boolean) as MatchedWoman[];

      setMatchedWomen(matched);
    } catch (error) {
      console.error("Error fetching matched women:", error);
      // Non-critical - matches list, will retry
    } finally {
      setLoadingMatches(false);
    }
  };

  async function updateUserOnlineStatus(online: boolean) {
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.user) return;
      const user = session.user;

      // Use upsert so that new users get a row inserted and existing users get updated.
      // update() returns no error when 0 rows are matched, so insert would never fire.
      const { error } = await supabase
        .from("user_status")
        .upsert(
          {
            user_id: user.id,
            is_online: online,
            last_seen: new Date().toISOString(),
          },
          { onConflict: "user_id" }
        );

      if (error) {
        console.error("Error upserting user status:", error);
      }
    } catch (error) {
      console.error("Error updating status:", error);
      // Non-critical background status update
    }
  };

  async function loadDashboardData(userOrNull?: import('@supabase/supabase-js').User) {
    try {
      let user = userOrNull;
      if (!user) {
        const { data: { session } } = await supabase.auth.getSession();
        if (!session?.user) {
          setIsLoading(false);
          return;
        }
        user = session.user;
      }

      setCurrentUserId(user.id);

      // Wrap profile fetch in timeout to prevent hang
      const profilePromise = supabase
        .from("profiles")
        .select("gender, full_name, date_of_birth, primary_language, preferred_language, country, photo_url, app_id")
        .eq("user_id", user.id)
        .maybeSingle();
      
      const profileTimeout = new Promise<{ data: null, error: Error }>((resolve) =>
        setTimeout(() => resolve({ data: null, error: new Error('Profile fetch timeout') }), 5000)
      );
      
      let mainProfile: { gender?: string | null; full_name?: string | null; date_of_birth?: string | null; primary_language?: string | null; preferred_language?: string | null; country?: string | null; photo_url?: string | null; app_id?: string | null } | null = null;
      try {
        const result = await Promise.race([profilePromise, profileTimeout]);
        mainProfile = result.data;
      } catch {
        console.warn('[Dashboard] Profile fetch timed out or failed');
      }
      
      // Store user's photo for chat validation
      setUserPhoto(mainProfile?.photo_url || null);

      // Redirect women to their dashboard (case-insensitive check)
      if (mainProfile?.gender?.toLowerCase() === "female") {
        redirectToWomenDashboard();
        return;
      }

      // Fetch user languages and female_profiles check in parallel
      const [userLangsResult, femaleCheckResult] = await Promise.all([
        supabase
          .from("user_languages")
          .select("language_name, language_code")
          .eq("user_id", user.id),
        // Check female_profiles in case user registered as female but no main profile
        supabase
          .from("female_profiles")
          .select("user_id")
          .eq("user_id", user.id)
          .maybeSingle(),
      ]);

      if (femaleCheckResult.data) {
        redirectToWomenDashboard();
        return;
      }

      const userLanguages = userLangsResult.data;

      // Use main profiles table (single source of truth)
      const motherTongue = pickCallLanguage(
        mainProfile?.primary_language,
        ...((userLanguages || []) as { language_name?: string | null }[]).map((l) => l.language_name),
        mainProfile?.preferred_language,
      ) || "English";
      const languageCode = userLanguages?.find((l: { language_code?: string | null; language_name?: string | null }) =>
        l.language_name && l.language_name === motherTongue
      )?.language_code || userLanguages?.[0]?.language_code || "eng_Latn";
      setUserLanguage(motherTongue);
      setUserLanguageCode(languageCode);

      // Use name from main profiles table
      const fullName = mainProfile?.full_name;
      if (fullName) {
        setUserName(fullName.split(" ")[0]);
      }
      // App ID (GESS-M-<n>) from profiles — single source of truth
      if (mainProfile?.app_id) setAppId(mainProfile.app_id);
      
      // Use country from main profiles table
      const userCountryValue = mainProfile?.country;
      if (userCountryValue) {
        setUserCountryName(userCountryValue);
        // Look up country code from the full countries dataset
        const match = countries.find(c => c.name.toLowerCase() === userCountryValue.toLowerCase());
        setUserCountry(match?.code || "IN");
      }

      // Fetch wallet balance via server-side RPC (with timeout)
      try {
        const { data: walletRpc } = await supabase.rpc('get_men_wallet_balance', {
          p_user_id: user.id
        });

        if (walletRpc) {
          const wd = walletRpc as Record<string, number>;
          setWalletBalance(Number(wd.balance) || 0);
        }
      } catch {
        console.warn('[Dashboard] Wallet balance fetch failed');
      }

      // Fetch stats in parallel - each with individual error handling
      await Promise.allSettled([
        fetchOnlineUsersCount(),
        fetchMatchCount(user.id),
        fetchNotifications(user.id),
        fetchOnlineWomen(motherTongue),
      ]);

    } catch (error) {
      console.error("Error loading dashboard:", error);
      toast({ title: "Dashboard unavailable", description: "Unable to load dashboard data. Please refresh.", variant: "destructive" });
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    let mounted = true;
    let loadingTimeoutId: NodeJS.Timeout;
    
    // Safety timeout - show error state after 12 seconds instead of silently rendering empty
    loadingTimeoutId = setTimeout(() => {
      if (mounted && isLoading) {
        console.warn('[Dashboard] Loading timed out after 12s');
        setIsLoading(false);
        toast({ 
          title: 'Dashboard load timeout', 
          description: 'Some data may not have loaded. Tap refresh to try again.', 
          variant: 'destructive' 
        });
      }
    }, 12000);

    // Wait for session to be restored from localStorage before checking auth
    // This prevents false redirects to "/" on page refresh
    const init = async () => {
      try {
        const { data: { session } } = await supabase.auth.getSession();
        if (!mounted) return;
        
        if (!session?.user) {
          // Don't redirect - ProtectedRoute handles auth.
          // Just stop loading to avoid stuck state on token refresh race.
          clearTimeout(loadingTimeoutId);
          setIsLoading(false);
          return;
        }
        await loadDashboardData(session.user);
        updateUserOnlineStatus(true);
        wentOnlineRef.current = true;
        loadActiveChatCount();
      } catch (error) {
        console.error('[Dashboard] Init error:', error);
        toast({ title: 'Dashboard error', description: 'Unable to load your dashboard. Please refresh the page.', variant: 'destructive' });
        if (mounted) setIsLoading(false);
      } finally {
        if (mounted) clearTimeout(loadingTimeoutId);
      }
    };
    init();

    // Cleanup: only set offline if we successfully went online
    return () => {
      mounted = false;
      clearTimeout(loadingTimeoutId);
      if (wentOnlineRef.current) {
        wentOnlineRef.current = false;
        updateUserOnlineStatus(false);
      }
    };
  }, []);

  // Real-time subscription with throttled callbacks to avoid excessive DB calls
  const lastFetchWomenRef = useRef<number>(0);
  const fetchWomenTimeoutRef = useRef<NodeJS.Timeout | null>(null);

  // Keep ref in sync with state so throttled callback always has latest value
  useEffect(() => {
    userLanguageRef.current = userLanguage;
  }, [userLanguage]);

  function throttledFetchOnlineWomen() {
    const now = Date.now();
    const lang = userLanguageRef.current;
    if (now - lastFetchWomenRef.current < 5000) {
      if (fetchWomenTimeoutRef.current) clearTimeout(fetchWomenTimeoutRef.current);
      fetchWomenTimeoutRef.current = setTimeout(() => {
        lastFetchWomenRef.current = Date.now();
        fetchOnlineUsersCount();
        if (userLanguageRef.current) fetchOnlineWomen(userLanguageRef.current);
      }, 3000);
      return;
    }
    lastFetchWomenRef.current = now;
    fetchOnlineUsersCount();
    if (lang) fetchOnlineWomen(lang);
  }

  useEffect(() => {
    if (!currentUserId) return;

    const channel = supabase
      .channel('dashboard-updates')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'user_status' },
        (payload) => {
          if (!isVisibilityStatusChange(payload as { eventType?: string; new?: Record<string, unknown>; old?: Record<string, unknown> }, userStatusSnapshotRef.current)) return;
          throttledFetchOnlineWomen();
        }
      )
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'active_chat_sessions', filter: `man_user_id=eq.${currentUserId}` },
        () => {
          loadActiveChatCount();
          fetchActiveChats();
        }
      )
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'active_chat_sessions', filter: `man_user_id=eq.${currentUserId}` },
        (payload) => {
          loadActiveChatCount();
          fetchActiveChats();
        }
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'wallets' },
        () => { loadWalletBalance(); }
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'wallet_transactions', filter: `user_id=eq.${currentUserId}` },
        () => { loadWalletBalance(); }
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'women_availability' },
        () => { throttledFetchOnlineWomen(); }
      )
      // Note: We don't listen to all female_profiles changes as that would cause
      // cross-dashboard interference. The women list is refreshed when:
      // 1. user_status changes (online/offline)
      // 2. women_availability changes (availability status)
      // 3. THIS man's language changes (user_languages or male_profiles)
      // Women changing their language affects their visibility to men based on
      // the man's language filter - which is recalculated on user_status changes
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'chat_messages', filter: `receiver_id=eq.${currentUserId}` },
        () => { fetchActiveChats(); playMessageSound({ repeat: 3 }); }
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'video_call_sessions' },
        () => { loadActiveChatCount(); }
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'notifications', filter: `user_id=eq.${currentUserId}` },
        () => { 
          if (currentUserId) {
            fetchNotifications(currentUserId);
          }
        }
      )
      // Listen for user's language changes in user_languages table (INSERT events - no filter for new records)
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'user_languages' },
        async (payload) => {
          const record = payload.new as { user_id?: string; language_name?: string; language_code?: string };
          // Only process if this is our user's language change
          if (record?.user_id === currentUserId && record?.language_name) {
            setUserLanguage(record.language_name);
            setUserLanguageCode(record.language_code || "eng_Latn");
            fetchOnlineWomen(record.language_name);
          }
        }
      )
      // Listen for user's language updates in user_languages table
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'user_languages', filter: `user_id=eq.${currentUserId}` },
        async (payload) => {
          const newLanguage = (payload.new as { language_name?: string })?.language_name;
          const newCode = (payload.new as { language_code?: string })?.language_code || "eng_Latn";
          if (newLanguage) {
            setUserLanguage(newLanguage);
            setUserLanguageCode(newCode);
            fetchOnlineWomen(newLanguage);
          }
        }
      )
      // Listen for profile language changes in male_profiles table
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'male_profiles', filter: `user_id=eq.${currentUserId}` },
        async (payload) => {
          const newProfile = payload.new as { primary_language?: string; preferred_language?: string };
          const newLanguage = newProfile?.primary_language || newProfile?.preferred_language;
          if (newLanguage) {
            setUserLanguage(newLanguage);
            fetchOnlineWomen(newLanguage);
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [currentUserId]); // stable — throttledFetchOnlineWomen reads from refs; language handlers fetch directly

  // Wallet balance refresh — keep off the hot path that was exhausting the pool.
  useEffect(() => {
    if (!currentUserId) return;
    const intervalId = setInterval(() => {
      loadWalletBalance();
    }, 10000);
    return () => clearInterval(intervalId);
  }, [currentUserId]);

  // Eager-load active chats on mount for unread badge
  useEffect(() => {
    if (!currentUserId) return;
    if (!chatsFetchedRef.current && !chatsInFlightRef.current) {
      fetchActiveChats();
    }
  }, [currentUserId]);

  // Lazy-load data on tab switch
  useEffect(() => {
    if (!currentUserId) return;
    if (activeTab === "matches" && !matchesFetchedRef.current) {
      matchesFetchedRef.current = true;
      fetchMatchedWomen(currentUserId);
    }
  }, [activeTab, currentUserId]);

  const getStatusText = () => {
    if (isManuallyOffline) return 'Offline';
    if (!isOnline) return 'Away';
    return 'Available';
  };

  const getStatusColor = () => {
    if (isManuallyOffline) return 'bg-muted-foreground';
    if (!isOnline) return 'bg-amber-500';
    return 'bg-online';
  };

  // getStatusDotColor removed — use getStatusColor directly

  // Handle starting chat with a woman - with auto-reconnect if woman is busy (max 2 retries)
  async function handleStartChatWithWoman(womanUserId: string, womanName: string, _reconnectDepth = 0) {
    if (isConnecting) return;
    if (settings.chatEnabled === false) {
      toast({ title: "Chat temporarily unavailable", description: "Chat is paused due to high system load. Please try again shortly.", variant: "destructive" });
      return;
    }
    setIsConnecting(true);
    setConnectingUserId(womanUserId);

    // Navigate immediately so the chat window opens on single click
    navigate(`/chat/${womanUserId}`);

    // Start the chat session in the background
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.user) return;
      const user = session.user;

      const { data, error } = await supabase.functions.invoke("chat-manager", {
        body: {
          action: "start_chat",
          man_user_id: user.id,
          woman_user_id: womanUserId
        }
      });

      if (error) {
        console.error("Chat manager error:", error);
        return;
      }

      // Mark as self-initiated to prevent incoming chat popup
      if (data?.session_id || data?.chat_id) {
        const { markChatAsSelfInitiated } = await import("@/hooks/useIncomingChats");
        markChatAsSelfInitiated(data.session_id, data.chat_id);
      }

      if (!data?.success) {
        // Insufficient balance - show recharge dialog
        if (data?.message?.includes("balance") || data?.message?.includes("Insufficient")) {
          toast({
            title: 'Insufficient Balance',
            description: data.message,
            variant: "destructive",
          });
          setRechargeDialogOpen(true);
          return;
        }

        toast({
          title: 'Chat Notice',
          description: data?.message || "Chat session may not have started properly",
          variant: "destructive",
        });
        return;
      }

      // Send initial message
      if (data.chat_id) {
        await supabase.from("chat_messages").insert({
          chat_id: data.chat_id,
          sender_id: user.id,
          receiver_id: womanUserId,
          message: "👋 Hi!"
        });
      }
    } catch (error: any) {
      console.error("Failed to start chat session:", error);
    } finally {
      setIsConnecting(false);
      setConnectingUserId(null);
    }
  };

  // Quick connect: Automatically find and connect to the best available woman
  async function handleQuickConnect() {
    if (isConnecting || isReconnecting) return;
    
    // Note: Photo validation not needed at runtime - photos are mandatory during registration

    // Balance check removed — billing system removed

    setIsConnecting(true);
    toast({
      title: 'Searching...',
      description: 'Finding the best available match for you',
    });

    try {
      const bestMatch = await findNextAvailableWoman();
      
      if (bestMatch) {
        await handleStartChatWithWoman(bestMatch.userId, bestMatch.fullName);
      } else {
        toast({
          title: 'No One Available',
          description: 'All users are busy. Please try again later.',
          variant: "destructive",
        });
      }
    } catch (error) {
      console.error("Quick connect error:", error);
      toast({
        title: 'Error',
        description: 'Failed to connect. Please try again.',
        variant: "destructive",
      });
    } finally {
      setIsConnecting(false);
    }
  };

  const markNotificationRead = async (notificationId: string) => {
    try {
      await supabase
        .from("notifications")
        .update({ is_read: true })
        .eq("id", notificationId);
      // Update local state immediately for instant UI feedback
      setNotifications(prev =>
        prev.map(n => n.id === notificationId ? { ...n, is_read: true } : n)
      );
      setStats(prev => ({
        ...prev,
        unreadNotifications: Math.max(0, prev.unreadNotifications - 1),
      }));
    } catch (err) {
      console.warn('[Dashboard] Failed to mark notification read:', err);
    }
  };

  async function handleLogout() {
    try {
      // Use currentUserId or fall back to the Supabase auth session uid
      const { data: { session } } = await supabase.auth.getSession();
      const uid = currentUserId || session?.user?.id || '';
      if (uid) {
        const { cleanupAllUserSessions } = await import('@/services/session-cleanup.service');
        await cleanupAllUserSessions(uid);
      }
    } catch (err) {
      console.warn('[Logout] Session cleanup failed (continuing):', err);
    }
    await supabase.auth.signOut();
    toast({
      title: 'Logged out',
      description: 'See you soon!',
    });
    navigate('/', { replace: true });
  };

  // Handle Razorpay payment return from URL params (if redirect-flow used)
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const paymentStatus = params.get('payment');
    const orderId = params.get('order_id');
    if (paymentStatus && orderId) {
      const verifyPayment = async () => {
        try {
          const { data, error } = await supabase.functions.invoke('razorpay-payment', {
            body: { action: 'verify', orderId }
          });
          if (error) throw error;
          if (data?.credited) {
            toast({ title: "Payment Successful! 🎉", description: `₹${data.amount} added to your wallet.` });
            loadWalletBalance();
          } else if (data?.status === 'PAID' && data?.alreadyCredited) {
            toast({ title: "Already Credited", description: "This payment was already processed." });
          } else {
            toast({ title: "Payment Not Completed", description: `Status: ${data?.status || 'Unknown'}. No amount charged.`, variant: "destructive" });
          }
        } catch (err) {
          console.error('[Payment Verify]', err);
          toast({ title: "Verification Failed", description: "Please check your wallet balance.", variant: "destructive" });
        }
      };
      verifyPayment();
      window.history.replaceState({}, '', '/dashboard');
    }
  }, []);

  async function handleRecharge(amountINR: number) {
    if (processingPayment || amountINR < 1) return;
    setSelectedAmount(amountINR);
    setProcessingPayment(true);

    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.user) throw new Error("Session expired");

      // Razorpay checkout
      const { data, error } = await supabase.functions.invoke('razorpay-payment', {
        body: { amount: amountINR, userId: session.user.id }
      });

      if (error) throw error;
      if (!data?.success || !data?.orderId || !data?.keyId) {
        throw new Error(data?.error || 'Failed to create Razorpay order');
      }

      // Server returns gross (charged) and walletAmount (credited).
      const grossAmount: number = Number(data.grossAmount ?? amountINR);
      const walletAmount: number = Number(data.walletAmount ?? amountINR);
      const feeAmount: number = Number(data.feeAmount ?? 0);

      const loadScript = () => new Promise<boolean>((resolve) => {
        if ((window as any).Razorpay) return resolve(true);
        const script = document.createElement('script');
        script.src = 'https://checkout.razorpay.com/v1/checkout.js';
        script.onload = () => resolve(true);
        script.onerror = () => resolve(false);
        document.head.appendChild(script);
      });

      const ok = await loadScript();
      if (!ok) {
        toast({ title: "Payment Error", description: "Failed to load Razorpay. Please try again.", variant: "destructive" });
        setProcessingPayment(false);
        setSelectedAmount(null);
        return;
      }

      const rzp = new (window as any).Razorpay({
        key: data.keyId,
        amount: Math.round(grossAmount * 100),
        currency: "INR",
        name: "Wallet Recharge",
        description: `₹${walletAmount} to wallet (+ ₹${feeAmount.toFixed(2)} gateway fee)`,
        order_id: data.orderId,
        handler: async (response: any) => {
          try {
            const { data: vData, error: vErr } = await supabase.functions.invoke('razorpay-payment', {
              body: {
                action: 'verify',
                razorpay_order_id: response.razorpay_order_id,
                razorpay_payment_id: response.razorpay_payment_id,
                razorpay_signature: response.razorpay_signature,
              }
            });
            if (vErr) throw vErr;
            if (vData?.credited) {
              toast({
                title: "Payment Successful! 🎉",
                description: `₹${vData.amount} credited to wallet (paid ₹${vData.gross ?? grossAmount} incl. 3% fee).`,
              });
              loadWalletBalance();
            } else if (vData?.alreadyCredited) {
              toast({ title: "Already Credited", description: "This payment was already processed." });
              loadWalletBalance();
            } else {
              toast({ title: "Payment Not Credited", description: vData?.error || "Please contact support.", variant: "destructive" });
            }
          } catch (e) {
            console.error('[Razorpay Verify]', e);
            toast({ title: "Verification Failed", description: "Please check your wallet balance.", variant: "destructive" });
          } finally {
            setSelectedAmount(null);
            setProcessingPayment(false);
          }
        },
        modal: {
          ondismiss: () => {
            setSelectedAmount(null);
            setProcessingPayment(false);
          }
        },
        theme: { color: "#25D366" }
      });
      rzp.open();
    } catch (error) {
      console.error("Recharge error:", error);
      toast({
        title: "Recharge Failed",
        description: "Payment could not be processed. Please try again.",
        variant: "destructive",
      });
      setSelectedAmount(null);
      setProcessingPayment(false);
    }
  };

  // quickActions removed — not used in WhatsApp-style layout

  if (isLoading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="text-center space-y-4">
          <div className="w-12 h-12 border-4 border-primary/30 border-t-primary rounded-full animate-spin mx-auto" />
          <p className="text-muted-foreground">{'Loading...'}</p>
        </div>
      </div>
    );
  }

  // activeTab state is declared at top of component

  const onlineCount = sameLanguageWomen.length + indianTranslatedWomen.length;
  const totalUnreadCount = activeChats.reduce((sum, c) => sum + (c.unreadCount || 0), 0);
  const showCallGroups = settings.privateGroupsEnabled !== false;
  const menTabs = getMenTabs(onlineCount || undefined, totalUnreadCount || activeChatCount || undefined, matchedWomen.length || undefined, !!settings.statementsTabVisible, settings.chatEnabled !== false, showCallGroups);

  const renderOnlineUsersTab = () => (
    <div className="min-h-0 h-full overflow-y-auto overscroll-contain scroll-smooth">
      {/* Active status bar */}
      <div className="px-4 py-2 bg-muted/30 border-b border-border/30 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Badge className={cn("text-[10px] text-primary-foreground", getStatusColor())}>
            {getStatusText()}
          </Badge>
          <span className="text-xs text-muted-foreground">{formatLocalCurrency(walletBalance)}</span>
        </div>
        <div className="flex items-center gap-1.5">
          <MatchFiltersPanel filters={matchFilters} onFiltersChange={setMatchFilters} userCountry={userCountry} />
          <Button variant="ghost" size="sm" onClick={() => userLanguage && fetchOnlineWomen(userLanguage)} disabled={loadingOnlineWomen} className="h-7 w-7 p-0">
            <RefreshCw className={cn("w-3.5 h-3.5", loadingOnlineWomen && "animate-spin")} />
          </Button>
        </div>
      </div>

      {/* Search by GESS ID, User ID, or name */}
      <div className="px-3 py-2 border-b border-border/30">
        <div className="relative">
          <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-muted-foreground" />
          <Input
            value={searchOnline}
            onChange={(e) => setSearchOnline(e.target.value)}
            placeholder="Search GESS ID, User ID, or name…"
            className="h-8 pl-8 text-xs"
          />
        </div>
      </div>


      {/* Notifications */}
      {notifications.length > 0 && (
        <div id="notifications-section">
          {notifications.map((notification) => (
            <div
              key={notification.id}
              className="flex items-center gap-3 px-4 py-3 hover:bg-muted/50 active:bg-muted/70 transition-colors cursor-pointer border-b border-border/30"
              onClick={() => markNotificationRead(notification.id)}
            >
              <div className={cn(
                "w-12 h-12 rounded-full flex items-center justify-center flex-shrink-0",
                "bg-primary/10 text-primary"
              )}>
                {notification.type === "match" ? <Heart className="w-5 h-5" /> :
                 notification.type === "message" ? <MessageCircle className="w-5 h-5" /> :
                 <Bell className="w-5 h-5" />}
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center justify-between">
                  <span className="font-semibold text-sm text-foreground truncate">{notification.title}</span>
                  <span className="text-[10px] text-muted-foreground flex-shrink-0 ml-2">
                    {new Date(notification.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                  </span>
                </div>
                <div className="flex items-center justify-between mt-0.5">
                  <p className="text-xs text-muted-foreground truncate">{notification.message}</p>
                  {!notification.is_read && (
                    <div className="w-2 h-2 rounded-full bg-primary flex-shrink-0 ml-2" />
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Women Online - Same Language */}
      {loadingOnlineWomen ? (
        <div className="flex items-center justify-center py-16">
          <div className="w-8 h-8 border-4 border-primary/30 border-t-primary rounded-full animate-spin" />
        </div>
      ) : (
        <>
          {(() => {
            const filteredSame = sameLanguageWomen.filter(w => matchesUserSearch(searchOnline, w.user_id, w.full_name));
            const filteredOther = indianTranslatedWomen.filter(w => matchesUserSearch(searchOnline, w.user_id, w.full_name));
            return (
              <>
                {filteredSame.length > 0 && (
                  <>
                    <div className="px-4 py-2 bg-primary/5 border-b border-border/30">
                      <span className="text-xs font-semibold text-primary">{userLanguage}</span>
                      <span className="text-[10px] text-muted-foreground ml-1">({filteredSame.length})</span>
                    </div>
                    {filteredSame.map((woman) => (
                      <UserContactCard
                        key={woman.id}
            userId={woman.user_id}
                        name={woman.full_name || "Anonymous"}
                        subtitle={userCodeMap[woman.user_id] || undefined}
                        photoUrl={woman.photo_url}
                        age={woman.age}
                        language={woman.primary_language}
                        state={woman.state}
                        country={woman.country}
                        activeChatCount={woman.active_chat_count}
                        onClick={() => handleStartChatWithWoman(woman.user_id, woman.full_name || "User")}
                        actions={
                          <div className="flex items-center gap-1">
                            <Button variant="ghost" size="sm" className="h-7 w-7 p-0" onClick={(e) => { e.stopPropagation(); navigate(`/profile/${woman.user_id}`); }}>
                              <Eye className="w-3.5 h-3.5 text-primary" />
                            </Button>
                            {settings.audioCallEnabled !== false && canCallEachOther(userLanguage, woman.primary_language) && (
                              <Button variant="ghost" size="sm" className="h-7 w-7 p-0" onClick={(e) => { e.stopPropagation(); initiateCall(woman.user_id, woman.full_name || "User", woman.photo_url, 'audio'); }}>
                                <Phone className="w-3.5 h-3.5 text-primary" />
                              </Button>
                            )}
                            {settings.videoCallEnabled !== false && canCallEachOther(userLanguage, woman.primary_language) && (
                              <Button variant="ghost" size="sm" className="h-7 w-7 p-0" onClick={(e) => { e.stopPropagation(); initiateCall(woman.user_id, woman.full_name || "User", woman.photo_url, 'video'); }}>
                                <Video className="w-3.5 h-3.5 text-primary" />
                              </Button>
                            )}
                          </div>
                        }
                      />
                    ))}
                  </>
                )}

                {filteredOther.length > 0 && (
                  <>
                    <div className="px-4 py-2 bg-muted/30 border-b border-border/30">
                      <span className="text-xs font-semibold text-muted-foreground">Other Languages</span>
                      <span className="text-[10px] text-muted-foreground ml-1">({filteredOther.length})</span>
                    </div>
                    {filteredOther.map((woman) => (
                      <UserContactCard
                        key={woman.id}
            userId={woman.user_id}
                        name={woman.full_name || "Anonymous"}
                        photoUrl={woman.photo_url}
                        age={woman.age}
                        language={woman.primary_language}
                        state={woman.state}
                        country={woman.country}
                        activeChatCount={woman.active_chat_count}
                        subtitle={userCodeMap[woman.user_id] ? `${userCodeMap[woman.user_id]} • ${woman.primary_language} → ${userLanguage}` : `${woman.primary_language} → ${userLanguage}`}
                        onClick={() => handleStartChatWithWoman(woman.user_id, woman.full_name || "User")}
                        actions={
                          <div className="flex items-center gap-1">
                            <Button variant="ghost" size="sm" className="h-7 w-7 p-0" onClick={(e) => { e.stopPropagation(); navigate(`/profile/${woman.user_id}`); }}>
                              <Eye className="w-3.5 h-3.5 text-primary" />
                            </Button>
                          </div>
                        }
                      />
                    ))}
                  </>
                )}

                {filteredSame.length === 0 && filteredOther.length === 0 && notifications.length === 0 && (
                  <div className="text-center py-16">
                    <MessageCircle className="w-16 h-16 text-muted-foreground/20 mx-auto mb-4" />
                    <p className="text-muted-foreground text-sm">{searchOnline ? 'No matches found' : 'No women online right now'}</p>
                    <p className="text-muted-foreground/60 text-xs mt-1">{searchOnline ? 'Try a different search' : 'Check back later'}</p>
                  </div>
                )}
              </>
            );
          })()}
        </>
      )}
    </div>
  );

  const renderChatsTab = () => (
    <div className="min-h-0 h-full overflow-y-auto overscroll-contain scroll-smooth">
      <div className="px-4 py-2 bg-muted/30 border-b border-border/30 flex items-center justify-between">
        <span className="text-sm font-semibold text-foreground flex items-center gap-1.5">
          <MessageCircle className="h-4 w-4 text-primary" />
          Active Chats ({activeChats.length})
        </span>
        <Button variant="ghost" size="sm" onClick={fetchActiveChats} disabled={loadingChats} className="h-7 w-7 p-0">
          <RefreshCw className={cn("w-3.5 h-3.5", loadingChats && "animate-spin")} />
        </Button>
      </div>
      <div className="px-3 py-2 border-b border-border/30">
        <div className="relative">
          <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-muted-foreground" />
          <Input value={searchChats} onChange={(e) => setSearchChats(e.target.value)} placeholder="Search GESS ID, User ID, or name…" className="h-8 pl-8 text-xs" />
        </div>
      </div>
      {loadingChats && activeChats.length === 0 ? (
        <div className="flex items-center justify-center py-16">
          <div className="w-8 h-8 border-4 border-primary/30 border-t-primary rounded-full animate-spin" />
        </div>
      ) : (() => {
        const filteredChats = activeChats.filter(c => matchesUserSearch(searchChats, c.partnerId, c.partnerName));
        if (filteredChats.length === 0) {
          return (
            <div className="text-center py-16">
              <MessageCircle className="w-16 h-16 text-muted-foreground/20 mx-auto mb-4" />
              <p className="text-muted-foreground text-sm">{searchChats ? 'No matches found' : 'No active chats'}</p>
              <p className="text-muted-foreground/60 text-xs mt-1">{searchChats ? 'Try a different search' : 'Start a chat from the Online tab'}</p>
            </div>
          );
        }
        return filteredChats.map((chat) => (
          <div
            key={chat.chatId}
            className="flex items-center gap-3 px-4 py-3 hover:bg-muted/50 active:bg-muted/70 transition-colors cursor-pointer border-b border-border/30"
            onClick={() => navigate(`/chat/${chat.partnerId}`)}
          >
            <div className="relative flex-shrink-0">
              <Avatar className="h-12 w-12 border-2 border-background shadow-sm">
                <AvatarImage src={chat.partnerPhoto || undefined} />
                <AvatarFallback className="bg-gradient-to-br from-primary to-primary/60 text-primary-foreground">
                  {chat.partnerName?.charAt(0) || <User className="w-5 h-5" />}
                </AvatarFallback>
              </Avatar>
              <span
                className="absolute -bottom-0.5 -right-0.5 w-3 h-3 rounded-full border-2 border-background"
                style={{
                  background: chat.partnerIsOnline
                    ? (chat.partnerStatus === 'busy' ? '#FFA726' : '#4CAF50')
                    : '#9E9E9E',
                }}
              />
            </div>
            <div className="flex-1 min-w-0">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-1.5 min-w-0">
                  <span className={cn("text-sm truncate", chat.unreadCount > 0 ? "font-bold text-foreground" : "font-semibold text-foreground")}>{chat.partnerName}</span>
                  {userCodeMap[chat.partnerId] && (
                    <span className="text-[9px] px-1 py-0.5 rounded bg-muted text-muted-foreground font-mono flex-shrink-0">{userCodeMap[chat.partnerId]}</span>
                  )}
                  {(() => {
                    const ageMs = Date.now() - new Date(chat.lastMessageAt).getTime();
                    if (chat.partnerIsOnline && ageMs < 60000) {
                      return (
                        <span className="text-[9px] px-1.5 py-0.5 rounded bg-red-500 text-white flex items-center gap-1 flex-shrink-0 animate-pulse">
                          <span className="w-1.5 h-1.5 rounded-full bg-white" />
                          LIVE
                        </span>
                      );
                    }
                    if (chat.partnerIsOnline && chat.partnerActiveChatCount > 0) {
                      return <span className="text-[9px] px-1 py-0.5 rounded bg-amber-100 text-amber-700 flex-shrink-0">In Chat</span>;
                    }
                    if (chat.partnerIsOnline) {
                      return <span className="text-[9px] px-1 py-0.5 rounded bg-green-100 text-green-700 flex-shrink-0">Online</span>;
                    }
                    return <span className="text-[9px] px-1 py-0.5 rounded bg-muted text-muted-foreground flex-shrink-0">Offline</span>;
                  })()}
                </div>
                <span className={cn("text-[10px] flex-shrink-0 ml-2", chat.unreadCount > 0 ? "text-[#25D366] font-semibold" : "text-muted-foreground")}>
                  {formatChatTime(chat.lastMessageAt)}
                </span>
              </div>
              <div className="flex items-center justify-between mt-0.5">
                <p className={cn("text-xs truncate flex items-center gap-1", chat.unreadCount > 0 ? "text-foreground font-medium" : "text-muted-foreground")}>
                  {chat.lastMessageSenderId === currentUserId && chat.lastMessage && (
                    <span className="text-[#4FC3F7] flex-shrink-0">✓✓</span>
                  )}
                  {chat.lastMessageSenderId === currentUserId ? `You: ${chat.lastMessage}` : chat.lastMessage || "No messages yet"}
                </p>
                {chat.unreadCount > 0 && (
                  <span className="min-w-[20px] h-[20px] rounded-full bg-[#25D366] text-white text-[11px] font-bold flex items-center justify-center px-1.5 flex-shrink-0 ml-2">
                    {chat.unreadCount > 99 ? "99+" : chat.unreadCount}
                  </span>
                )}
              </div>
            </div>
          </div>
        ));
      })()}
    </div>
  );

  const renderGroupsTab = () => (
    <div className="min-h-0 h-full overflow-y-auto overscroll-contain scroll-smooth">
      <div className="px-4 py-2 bg-muted/30 border-b border-border/30 flex items-center justify-between">
        <span className="text-sm font-semibold text-foreground flex items-center gap-1.5">
          <Video className="h-4 w-4 text-primary" />
          Private Groups
        </span>
        <Button variant="outline" size="sm" onClick={() => setPrivateGroupsRefreshKey(prev => prev + 1)} className="h-7 text-xs px-2">
          <RefreshCw className="w-3.5 h-3.5" />
        </Button>
      </div>
      {currentUserId ? (
        <div className="px-4 py-3">
          <AvailableGroupsSection
            key={privateGroupsRefreshKey}
            currentUserId={currentUserId}
            userName={userName || 'User'}
            userPhoto={userPhoto}
            userLanguage={userLanguage}
          />
        </div>
      ) : (
        <div className="text-center py-10">
          <Video className="w-10 h-10 text-muted-foreground/20 mx-auto mb-2" />
          <p className="text-xs text-muted-foreground">Loading groups...</p>
        </div>
      )}
    </div>
  );

  const renderMatchesTab = () => (
    <div className="min-h-0 h-full overflow-y-auto overscroll-contain scroll-smooth">
      <div className="px-4 py-2 bg-muted/30 border-b border-border/30 flex items-center justify-between">
        <span className="text-sm font-semibold text-foreground">Your Matches ({matchedWomen.length})</span>
        <Button variant="ghost" size="sm" onClick={() => currentUserId && fetchMatchedWomen(currentUserId)} disabled={loadingMatches} className="h-7 w-7 p-0">
          <RefreshCw className={cn("w-3.5 h-3.5", loadingMatches && "animate-spin")} />
        </Button>
      </div>
      <div className="px-3 py-2 border-b border-border/30">
        <div className="relative">
          <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-muted-foreground" />
          <Input value={searchMatches} onChange={(e) => setSearchMatches(e.target.value)} placeholder="Search GESS ID, User ID, or name…" className="h-8 pl-8 text-xs" />
        </div>
      </div>
      {loadingMatches ? (
        <div className="flex items-center justify-center py-16">
          <div className="w-8 h-8 border-4 border-primary/30 border-t-primary rounded-full animate-spin" />
        </div>
      ) : (() => {
        const filteredMatches = matchedWomen.filter(w => matchesUserSearch(searchMatches, w.userId, w.fullName));
        if (filteredMatches.length === 0) {
          return (
            <div className="text-center py-16">
              <Heart className="w-16 h-16 text-muted-foreground/20 mx-auto mb-4" />
              <p className="text-muted-foreground text-sm">{searchMatches ? 'No matches found' : 'No matches yet'}</p>
              {!searchMatches && (
                <Button variant="aurora" size="sm" className="mt-3 gap-1" onClick={() => navigate("/match-discovery")}>
                  <Compass className="w-4 h-4" /> Discover
                </Button>
              )}
            </div>
          );
        }
        return filteredMatches.map((woman) => (
          <UserContactCard
            key={woman.matchId}
            userId={woman.userId}
            name={woman.fullName || "User"}
            subtitle={userCodeMap[woman.userId] || undefined}
            photoUrl={woman.photoUrl}
            age={woman.age}
            language={woman.primaryLanguage}
            state={woman.state}
            country={woman.country}
            isOnline={woman.isOnline}
            onClick={() => handleStartChatWithWoman(woman.userId, woman.fullName || "User")}
            actions={
              <div className="flex items-center gap-1">
                <Button variant="ghost" size="sm" className="h-7 w-7 p-0" onClick={(e) => { e.stopPropagation(); navigate(`/profile/${woman.userId}`); }}>
                  <Eye className="w-3.5 h-3.5 text-primary" />
                </Button>
              </div>
            }
          />
        ));
      })()}
    </div>
  );

  const renderWalletTab = () => (
    <div className="min-h-0 h-full overflow-y-auto overscroll-contain scroll-smooth">
      {/* Wallet Balance */}
      <div className="px-4 py-4 border-b border-border/30 bg-gradient-to-br from-primary/5 to-transparent" onClick={() => setRechargeDialogOpen(true)}>
        <div className="flex items-center gap-3">
          <div className="w-14 h-14 rounded-full bg-primary/10 flex items-center justify-center">
            <Wallet className="w-7 h-7 text-primary" />
          </div>
          <div className="flex-1">
            <p className="text-xs text-muted-foreground">Wallet Balance</p>
            <p className="text-2xl font-bold text-primary">{formatLocalCurrency(walletBalance)}</p>
          </div>
          <Button variant="outline" size="sm" className="gap-1 text-primary border-primary/30" onClick={(e) => { e.stopPropagation(); setRechargeDialogOpen(true); }}>
            <CreditCard className="w-3.5 h-3.5" />Recharge
          </Button>
        </div>
      </div>

      {/* Pricing Info */}
      <div className="px-4 py-3 border-b border-border/30">
        <p className="text-xs font-semibold text-muted-foreground mb-2">Rate Card</p>
        <div className="grid grid-cols-2 gap-2 text-xs">
          <div className="flex justify-between bg-muted/50 rounded px-2 py-1"><span>Chat</span><span className="font-semibold">{formatLocalCurrency(pricing.ratePerMinute)}/min</span></div>
          <div className="flex justify-between bg-muted/50 rounded px-2 py-1"><span>Audio</span><span className="font-semibold">{formatLocalCurrency(pricing.audioRatePerMinute)}/min</span></div>
          <div className="flex justify-between bg-muted/50 rounded px-2 py-1"><span>Video</span><span className="font-semibold">{formatLocalCurrency(pricing.videoRatePerMinute)}/min</span></div>
          <div className="flex justify-between bg-muted/50 rounded px-2 py-1"><span>Group</span><span className="font-semibold">{formatLocalCurrency(pricing.groupCallRatePerMinute)}/min</span></div>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-3 gap-0 border-b border-border/30">
        <div className="text-center py-4 border-r border-border/30">
          <p className="text-xl font-bold text-foreground">{stats.onlineUsersCount}</p>
          <p className="text-[10px] text-muted-foreground">Online</p>
        </div>
        <div className="text-center py-4 border-r border-border/30">
          <p className="text-xl font-bold text-foreground">{matchedWomen.length}</p>
          <p className="text-[10px] text-muted-foreground">Matches</p>
        </div>
        <div className="text-center py-4">
          <p className="text-xl font-bold text-foreground">{activeChatCount}</p>
          <p className="text-[10px] text-muted-foreground">Active Chats</p>
        </div>
      </div>

      {/* View Statement Link */}
      <div className="px-4 py-3 flex items-center gap-3 border-b border-border/30 hover:bg-muted/50 cursor-pointer" onClick={() => navigate('/wallet')}>
        <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center">
          <Wallet className="w-5 h-5 text-primary" />
        </div>
        <span className="text-sm font-medium text-foreground">View Full Statement</span>
        <ChevronRight className="w-4 h-4 text-muted-foreground ml-auto" />
      </div>
    </div>
  );

  const renderProfileTab = () => (
    <div className="min-h-0 h-full overflow-y-auto overscroll-contain scroll-smooth">
      {/* Profile card */}
      <div className="px-4 py-6 flex flex-col items-center border-b border-border/30">
        <Avatar className="w-20 h-20 border-4 border-primary/20 shadow-lg mb-3">
          <AvatarImage src={userPhoto || undefined} />
          <AvatarFallback className="bg-gradient-to-br from-primary to-primary/60 text-primary-foreground text-2xl font-bold">
            {userName?.charAt(0) || <User className="w-8 h-8" />}
          </AvatarFallback>
        </Avatar>
        <h2 className="text-lg font-bold text-foreground">{userName || "User"}</h2>
        {appId && (
          <Badge variant="outline" className="mt-1 font-mono text-[11px] border-primary/40 text-primary">
            App ID: {appId}
          </Badge>
        )}
        <p className="text-xs text-muted-foreground">{userLanguage} • {userCountryName || userCountry}</p>
        <Badge className={cn("mt-2 text-[10px] text-primary-foreground", getStatusColor())}>
          {getStatusText()}
        </Badge>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-3 gap-0 border-b border-border/30">
        <div className="text-center py-4 border-r border-border/30">
          <p className="text-xl font-bold text-foreground">{stats.onlineUsersCount}</p>
          <p className="text-[10px] text-muted-foreground">Online</p>
        </div>
        <div className="text-center py-4 border-r border-border/30">
          <p className="text-xl font-bold text-foreground">{matchedWomen.length}</p>
          <p className="text-[10px] text-muted-foreground">Matches</p>
        </div>
        <div className="text-center py-4">
          <p className="text-xl font-bold text-foreground">{activeChatCount}</p>
          <p className="text-[10px] text-muted-foreground">Active Chats</p>
        </div>
      </div>

      {/* Quick links */}
      {[
        { icon: <UserCircle className="w-5 h-5 text-primary" />, label: "Edit Profile", onClick: () => setProfileEditOpen(true) },
        { icon: <Compass className="w-5 h-5 text-primary" />, label: "Discover Matches", onClick: () => navigate("/match-discovery") },
        { icon: <Eye className="w-5 h-5 text-primary" />, label: "Online Users", onClick: () => navigate("/online-users") },
        { icon: <Gift className="w-5 h-5 text-primary" />, label: "Send Gift", onClick: () => navigate("/match-discovery") },
        { icon: <Settings className="w-5 h-5 text-primary" />, label: "Settings", onClick: () => navigate("/settings") },
      ].map((item, i) => (
        <div key={i} className="px-4 py-3 flex items-center gap-3 border-b border-border/30 hover:bg-muted/50 cursor-pointer" onClick={item.onClick}>
          <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center">{item.icon}</div>
          <span className="text-sm font-medium text-foreground">{item.label}</span>
          <ChevronRight className="w-4 h-4 text-muted-foreground ml-auto" />
        </div>
      ))}
    </div>
  );

  return (
    <div className="flex flex-col bg-background overflow-hidden" style={{ height: '100dvh', maxHeight: '100dvh' }}>
      {/* WhatsApp-style Header */}
      <AppHeader
        isOnline={isOnline}
        onToggleOnline={(checked) => {
          toggleOnlineStatus(checked);
          toast({
            title: checked ? 'You are now Online' : 'You are now Offline',
            description: checked ? 'Women can see you' : 'You are hidden from others',
          });
        }}
        onAdminMessages={() => setShowAdminMessages(true)}
        onAdminChat={() => setShowAdminChat(true)}
        onFriends={() => setShowFriendsPanel(true)}
        onSettings={() => navigate('/settings')}
        onLogout={handleLogout}
        unreadAdminMessages={unreadAdminMessages}
        unreadAdminChat={unreadAdminChat}
        unreadNotifications={stats.unreadNotifications}
        onNotifications={() => {
          setActiveTab("online");
          setTimeout(() => document.getElementById('notifications-section')?.scrollIntoView({ behavior: 'smooth' }), 100);
        }}
      />

      <ScrollingAnnouncementsBar gender="men" />

      {/* Tab Content */}
      <div className="min-h-0 flex-1 overflow-hidden">
        {activeTab === "online" && renderOnlineUsersTab()}
        {activeTab === "chats" && renderChatsTab()}
        {activeTab === "history" && (
          <div className="min-h-0 h-full overflow-y-auto overscroll-contain scroll-smooth">
            <ErrorBoundary
              fallback={
                <div className="flex flex-col items-center justify-center py-16 text-muted-foreground">
                  <p className="text-sm font-medium">Couldn&apos;t load history</p>
                  <p className="text-xs mt-1">Please refresh and try again.</p>
                </div>
              }
            >
              <CallHistoryTab currentUserId={currentUserId} userGender="male" />
            </ErrorBoundary>
          </div>
        )}
        {activeTab === "groups" && renderGroupsTab()}
        {activeTab === "groupchat" && (
          <div className="min-h-0 h-full">
            <GroupChatTab currentUserId={currentUserId} viewerGender="male" viewerName={userName} viewerLanguage={userLanguage} />
          </div>
        )}

        {activeTab === "matches" && renderMatchesTab()}
        {activeTab === "wallet" && renderWalletTab()}
        {activeTab === "statement" && <div className="min-h-0 h-full overflow-y-auto overscroll-contain scroll-smooth"><StatementTab userId={currentUserId} gender="male" /></div>}
        {activeTab === "profile" && renderProfileTab()}
      </div>

      {/* WhatsApp-style Bottom Tabs */}
      <AppBottomTabs tabs={menTabs} activeTab={activeTab} onTabChange={setActiveTab} />

      {/* Recharge Dialog */}
      <Dialog open={rechargeDialogOpen} onOpenChange={setRechargeDialogOpen}>
        <DialogContent className="max-w-md max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <CreditCard className="h-5 w-5 text-primary" />
              {'Recharge Wallet'}
            </DialogTitle>
          </DialogHeader>

          <div className="space-y-6">
            <div className="p-3 rounded-lg bg-muted/50 text-sm">
              <p className="text-muted-foreground">
                {'Your currency'}: <span className="font-semibold text-foreground">{getCurrencyInfo().code}</span>
              </p>
              <p className="text-xs text-muted-foreground mt-1">
                {'Prices shown in your local currency (stored as INR)'}
              </p>
            </div>
            <div>
              <Label className="text-sm font-medium mb-3 block flex items-center gap-2">
                🇮🇳 {'Indian Payment Methods'}
              </Label>
              <RadioGroup value={selectedGateway} onValueChange={setSelectedGateway} className="grid grid-cols-2 gap-3">
                {INDIAN_GATEWAYS.map((gateway) => (
                  <div key={gateway.id} className="relative">
                    <RadioGroupItem value={gateway.id} id={`gateway-${gateway.id}`} className="peer sr-only" />
                    <Label htmlFor={`gateway-${gateway.id}`} className={cn("flex flex-col items-center justify-center p-3 rounded-lg border-2 cursor-pointer transition-all hover:border-primary/50 hover:bg-primary/5", selectedGateway === gateway.id ? "border-primary bg-primary/10" : "border-border")}>
                      <span className="text-2xl mb-1">{gateway.logo}</span>
                      <span className="font-semibold text-sm">{gateway.name}</span>
                      <span className="text-[10px] text-muted-foreground text-center mt-1">{gateway.description}</span>
                      {selectedGateway === gateway.id && <CheckCircle2 className="absolute top-1 right-1 h-4 w-4 text-primary" />}
                    </Label>
                  </div>
                ))}
              </RadioGroup>
            </div>
            <div className="space-y-3">
              <Label className="text-sm font-medium block">Select Amount</Label>
              <Select value={selectedAmount?.toString() || ""} onValueChange={(value) => { if (value === "custom") { setSelectedAmount(null); } else { setSelectedAmount(Number(value)); setCustomAmount(""); } }}>
                <SelectTrigger className="w-full"><SelectValue placeholder="Choose recharge amount" /></SelectTrigger>
                <SelectContent>
                  {RECHARGE_AMOUNTS_INR.map((amountINR) => (<SelectItem key={amountINR} value={amountINR.toString()}>{formatLocalCurrency(amountINR)} (₹{amountINR})</SelectItem>))}
                  <SelectItem value="custom">Custom Amount</SelectItem>
                </SelectContent>
              </Select>
              {(!selectedAmount || customAmount) && (
                <div className="flex gap-2">
                  <div className="relative flex-1">
                    <span className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground">₹</span>
                    <input type="number" min="10" max="100000" placeholder="Enter custom amount" value={customAmount} onChange={(e) => { setCustomAmount(e.target.value); const val = Number(e.target.value); if (val >= 10) setSelectedAmount(val); else setSelectedAmount(null); }} className="w-full pl-8 pr-3 py-2 rounded-md border border-input bg-background text-sm focus:outline-none focus:ring-2 focus:ring-primary" />
                  </div>
                </div>
              )}
              {selectedAmount ? (() => {
                const gross = Math.ceil(selectedAmount * 1.03 * 100) / 100;
                const fee = (gross - selectedAmount).toFixed(2);
                return (
                  <div className="rounded-md border border-border/50 bg-muted/40 p-2.5 text-xs space-y-1">
                    <div className="flex justify-between"><span className="text-muted-foreground">Wallet credit</span><span className="font-medium">₹{selectedAmount.toFixed(2)}</span></div>
                    <div className="flex justify-between"><span className="text-muted-foreground">Gateway fee (3%)</span><span>+ ₹{fee}</span></div>
                    <div className="flex justify-between border-t border-border/40 pt-1 font-semibold"><span>You pay</span><span>₹{gross.toFixed(2)}</span></div>
                  </div>
                );
              })() : null}
              <Button variant="aurora" className="w-full gap-2" onClick={() => selectedAmount && handleRecharge(selectedAmount)} disabled={!selectedAmount || processingPayment}>
                {processingPayment ? <RefreshCw className="h-4 w-4 animate-spin" /> : <><CreditCard className="h-4 w-4" />{selectedAmount ? `Pay ₹${(Math.ceil(selectedAmount * 1.03 * 100) / 100).toFixed(2)}` : "Select Amount"}</>}
              </Button>
            </div>
            <p className="text-xs text-muted-foreground text-center">Secure payment via {ALL_GATEWAYS.find(g => g.id === selectedGateway)?.name}</p>
          </div>
        </DialogContent>
      </Dialog>

      {/* Profile Edit Dialog */}
      <ProfileEditDialog open={profileEditOpen} onOpenChange={setProfileEditOpen} onProfileUpdated={() => loadDashboardData()} />

      {/* Chat windows removed — chats are async (WhatsApp-style), accessed via Chats tab */}

      {/* Incoming Call Banner */}
      {incomingCall && callStatus === 'idle' && (
        <IncomingCallBanner
          callerName={incomingCall.callerName}
          callerPhoto={incomingCall.callerPhoto}
          callType={incomingCall.callType}
          onAccept={() => {
            acceptCall(incomingCall.callId, incomingCall.callType, incomingCall.callerUserId, incomingCall.callerName, incomingCall.callerPhoto);
            clearIncomingCall();
          }}
          onDecline={() => {
            declineCall(incomingCall.callId);
            clearIncomingCall();
          }}
        />
      )}

      {/* WhatsApp Call Screen */}
      {(callStatus === 'calling' || callStatus === 'connecting' || callStatus === 'active') && (
        <CallScreen
          status={callStatus}
          activeCall={activeCall}
          isMuted={isMuted}
          isCameraOff={isCameraOff}
          onEnd={endCall}
          onToggleMute={toggleMute}
          onToggleCamera={toggleCamera}
          userGender="male"
        />
      )}

      {/* Friends & Blocked Panel */}
      {showFriendsPanel && currentUserId && (
        <FriendsBlockedPanel currentUserId={currentUserId} userGender="male" onClose={() => setShowFriendsPanel(false)} />
      )}

      {/* Admin Messages Sheet */}
      <Sheet open={showAdminMessages} onOpenChange={setShowAdminMessages}>
        <SheetContent side="bottom" className="max-h-[85vh] overflow-y-auto rounded-t-2xl pb-[env(safe-area-inset-bottom)]">
          <SheetHeader><SheetTitle className="flex items-center gap-2"><Mail className="w-5 h-5 text-primary" />Admin Messages</SheetTitle></SheetHeader>
          {currentUserId && <div className="mt-4"><AdminMessagesWidget currentUserId={currentUserId} /></div>}
        </SheetContent>
      </Sheet>

      {/* Admin Chat Sheet */}
      <Sheet open={showAdminChat} onOpenChange={setShowAdminChat}>
        <SheetContent side="bottom" className="max-h-[85vh] overflow-y-auto rounded-t-2xl pb-[env(safe-area-inset-bottom)]">
          <SheetHeader><SheetTitle className="flex items-center gap-2"><Shield className="w-5 h-5 text-primary" />Chat with Admin</SheetTitle></SheetHeader>
          {currentUserId && <div className="mt-4"><UserAdminChat currentUserId={currentUserId} userName={userName || 'User'} embedded /></div>}
        </SheetContent>
      </Sheet>
    </div>
  );
};

export default DashboardScreen;