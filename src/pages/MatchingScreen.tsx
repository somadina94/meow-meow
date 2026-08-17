import { classifyError, ERROR_MESSAGES, logError } from "@/lib/errors";
import { useState, useEffect, useCallback, useRef } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import MeowLogo from "@/components/MeowLogo";
import { useToast } from "@/hooks/use-toast";
import { 
  Phone, 
  PhoneOff,
  ArrowLeft,
  Circle,
  Languages,
  Loader2,
  MessageCircle,
  RefreshCw,
  User,
  Clock,
  IndianRupee,
  Shield,
  Sparkles,
  Info
} from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { isVisibilityStatusChange } from "@/lib/presence";
import { Badge } from "@/components/ui/badge";
import { isIndianLanguage } from "@/data/supportedLanguages";
import { filterWomenByNLLBRules, getVisibilityExplanation, WomanProfile, ProfileVisibility, getVisibilityWeight, shouldShowProfile } from "@/hooks/useNLLBVisibility";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";

interface MatchableWoman {
  userId: string;
  fullName: string;
  age: number | null;
  photoUrl: string | null;
  motherTongue: string;
  country: string | null;
  isOnline: boolean;
  isBusy: boolean;
  currentChatCount: number;
  aiVerified: boolean;
  profileVisibility: ProfileVisibility;
}

const MatchingScreen = () => {
  const navigate = useNavigate();
  const { toast } = useToast();
  const [isLoading, setIsLoading] = useState(true);
  const [isConnecting, setIsConnecting] = useState(false);
  const [matchableWomen, setMatchableWomen] = useState<MatchableWoman[]>([]);
  const [currentUserLanguage, setCurrentUserLanguage] = useState<string>("");
  const [currentUserId, setCurrentUserId] = useState<string>("");
  const [selectedWoman, setSelectedWoman] = useState<MatchableWoman | null>(null);
  const [connectionStatus, setConnectionStatus] = useState<"idle" | "searching" | "connecting" | "connected" | "reconnecting">("idle");
  const [activeChatId, setActiveChatId] = useState<string | null>(null);
  const reconnectAttempts = useRef(0);
  const maxReconnectAttempts = 3;
  const userStatusSnapshotRef = useRef<Map<string, string>>(new Map());
  const reloadTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    loadMatchableWomen();
    const cleanup = setupRealtimeSubscription();
    return () => {
      if (reloadTimeoutRef.current) clearTimeout(reloadTimeoutRef.current);
      cleanup();
    };
  }, []);

  const setupRealtimeSubscription = () => {
    const scheduleReload = () => {
      if (reloadTimeoutRef.current) clearTimeout(reloadTimeoutRef.current);
      reloadTimeoutRef.current = setTimeout(() => {
        void loadMatchableWomen();
      }, 1500);
    };

    const statusChannel = supabase
      .channel('women-status-changes')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'user_status'
        },
        (payload) => {
          if (!isVisibilityStatusChange(payload as { eventType?: string; new?: Record<string, unknown>; old?: Record<string, unknown> }, userStatusSnapshotRef.current)) return;
          scheduleReload();
        }
      )
      .subscribe();

    const availabilityChannel = supabase
      .channel('women-availability-changes')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'women_availability'
        },
        () => {
          scheduleReload();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(statusChannel);
      supabase.removeChannel(availabilityChannel);
    };
  };

  const loadMatchableWomen = async () => {
    try {
      const { data: { session } } = await supabase.auth.getSession();
      
      if (!session?.user) {
        navigate("/");
        return;
      }
      const user = session.user;

      setCurrentUserId(user.id);

      // Get current user's profile and mother tongue - check both tables
      const { data: currentProfile } = await supabase
        .from("profiles")
        .select("gender, primary_language, preferred_language")
        .eq("user_id", user.id)
        .maybeSingle();

      // Also check male_profiles if no main profile exists
      const { data: maleProfile } = await supabase
        .from("male_profiles")
        .select("primary_language, preferred_language")
        .eq("user_id", user.id)
        .maybeSingle();

      // If user has a male_profiles record, they're male
      // If user has a profile with gender, use that
      const isMaleUser = maleProfile !== null || currentProfile?.gender?.toLowerCase() === "male";
      
      if (!isMaleUser) {
        toast({
          title: "Access Denied",
          description: "This feature is only available for male users",
          variant: "destructive",
        });
        navigate("/women-dashboard");
        return;
      }

      // Get user's languages (mother tongue)
      const { data: userLanguages } = await supabase
        .from("user_languages")
        .select("language_name")
        .eq("user_id", user.id)
        .limit(1);

      const motherTongue = userLanguages?.[0]?.language_name || 
                          maleProfile?.primary_language ||
                          maleProfile?.preferred_language ||
                          currentProfile?.primary_language || 
                          currentProfile?.preferred_language || 
                          "English";
      
      setCurrentUserLanguage(motherTongue);

      // Fetch online women (exclude busy = currently in audio/video/group call)
      const { data: onlineStatus } = await supabase
        .from("user_status")
        .select("user_id, is_online, status_text")
        .eq("is_online", true)
        .neq("status_text", "busy");

      const onlineUserIds = onlineStatus?.map(s => s.user_id) || [];

      if (onlineUserIds.length === 0) {
        setMatchableWomen([]);
        setIsLoading(false);
        return;
      }

      // Fetch female profiles with country info and AI verification status
      const { data: profiles } = await supabase
        .from("profiles")
        .select("user_id, full_name, photo_url, age, primary_language, preferred_language, country, ai_approved, approval_status")
        .ilike("gender", "female")
        .in("user_id", onlineUserIds);

      // Fetch availability status
      const { data: availability } = await supabase
        .from("women_availability")
        .select("user_id, is_available, current_chat_count, max_concurrent_chats")
        .in("user_id", onlineUserIds);

      const availabilityMap = new Map(
        (availability as any[] || []).map(a => [a.user_id, a])
      );

      // Fetch user settings for profile visibility
      const { data: userSettings } = await supabase
        .from("user_settings")
        .select("user_id, profile_visibility")
        .in("user_id", onlineUserIds);

      const settingsMap = new Map(
        userSettings?.map(s => [s.user_id, s.profile_visibility]) || []
      );

      // Fetch languages for each user
      const women: MatchableWoman[] = await Promise.all(
        (profiles || []).map(async (profile) => {
          const { data: languages } = await supabase
            .from("user_languages")
            .select("language_name")
            .eq("user_id", profile.user_id)
            .limit(1);

          const womanLanguage = languages?.[0]?.language_name || 
                               profile.primary_language || 
                               profile.preferred_language || 
                               "Unknown";

          const avail = availabilityMap.get(profile.user_id);
          const isBusy = avail ? avail.current_chat_count >= avail.max_concurrent_chats : false;
          const aiVerified = profile.ai_approved === true && profile.approval_status === "approved";
          const profileVisibility = (settingsMap.get(profile.user_id) || "high") as ProfileVisibility;

          return {
            userId: profile.user_id,
            fullName: profile.full_name || "Anonymous",
            age: profile.age,
            photoUrl: profile.photo_url,
            motherTongue: womanLanguage,
            country: profile.country,
            isOnline: true,
            isBusy,
            currentChatCount: avail?.current_chat_count || 0,
            aiVerified,
            
            profileVisibility,
          };
        })
      );

      // Apply profile visibility filtering (probability-based)
      const visibilityFilteredWomen = women.filter(w => {
        // Simple probability-based visibility using profileVisibility
        const vis = (w as any).profileVisibility as string;
        if (vis === 'low') return Math.random() < 0.25;
        if (vis === 'medium') return Math.random() < 0.5;
        return true; // high, very_high
      });

      // Apply Language visibility rules
      const visibilityResult = filterWomenByNLLBRules(
        visibilityFilteredWomen.map(w => ({
          ...w,
          aiVerified: w.aiVerified,
        })),
        motherTongue
      );

      // Sort visible women: visibility priority first, then not busy, then by chat count
      const sortedWomen = visibilityResult.visibleWomen.sort((a, b) => {
        // First by visibility priority (higher = first)
        const visA = getVisibilityWeight(a, motherTongue);
        const visB = getVisibilityWeight(b, motherTongue);
        if (visA !== visB) return visB - visA;
        
        // Then by busy status
        if (a.isBusy !== b.isBusy) return a.isBusy ? 1 : -1;
        
        // Finally by chat count
        return a.currentChatCount - b.currentChatCount;
      });

      setMatchableWomen(sortedWomen as MatchableWoman[]);
    } catch (error) {
      console.error("Error loading matchable women:", error);
      toast({
        title: "Error",
        description: "Failed to load available users",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  const findNextAvailableWoman = useCallback(async (excludeUserId?: string): Promise<MatchableWoman | null> => {
    try {
      // Use backend to find best match with load balancing
      const { data, error } = await supabase.functions.invoke("chat-manager", {
        body: {
          action: "find_match",
          man_user_id: currentUserId,
          preferred_language: currentUserLanguage
        }
      });

      if (error || !data?.success) {
        // Backend matching failed, falling back to local matching
        // Fallback to local matching if backend fails
        const availableWomen = matchableWomen.filter(w => 
          !w.isBusy && 
          w.isOnline && 
          w.userId !== excludeUserId
        );

        // Priority 1: Same language women
        const sameLanguageWomen = availableWomen.filter(
          w => w.motherTongue.toLowerCase() === currentUserLanguage.toLowerCase()
        );

        if (sameLanguageWomen.length > 0) {
          // Sort by load (lowest first)
          return sameLanguageWomen.sort((a, b) => a.currentChatCount - b.currentChatCount)[0];
        }

        // Priority 2: For non-Indian language men, fallback to Indian women
        const manHasIndianLanguage = isIndianLanguage(currentUserLanguage);
        
        if (!manHasIndianLanguage) {
          const indianLanguageWomen = availableWomen.filter(w => isIndianLanguage(w.motherTongue));
          if (indianLanguageWomen.length > 0) {
            return indianLanguageWomen.sort((a, b) => a.currentChatCount - b.currentChatCount)[0];
          }
          return null;
        }

        return availableWomen.sort((a, b) => a.currentChatCount - b.currentChatCount)[0] || null;
      }

      // Find the matched woman in our local list
      const matchedWoman = matchableWomen.find(w => w.userId === data.woman_user_id);
      if (matchedWoman) {
        return matchedWoman;
      }

      // If not in local list, construct from backend data
      return {
        userId: data.woman_user_id,
        fullName: data.profile?.full_name || "User",
        age: null,
        photoUrl: data.profile?.photo_url,
        motherTongue: data.profile?.primary_language || "Unknown",
        country: data.profile?.country,
        isOnline: true,
        isBusy: false,
        currentChatCount: data.current_load || 0,
        aiVerified: true,
        
        profileVisibility: "high" as ProfileVisibility
      };
    } catch (error) {
      console.error("Error finding match:", error);
      // Return null - caller handles no-match gracefully
      return null;
    }
  }, [matchableWomen, currentUserLanguage, currentUserId]);

  const initiateChat = async (woman: MatchableWoman) => {
    if (!currentUserId) return;

    setIsConnecting(true);
    setConnectionStatus("connecting");
    setSelectedWoman(woman);

    try {
      // Check wallet balance first (canonical SoT RPC)
      const { data: walletRpc } = await supabase.rpc("get_men_wallet_balance", { p_user_id: currentUserId });
      const balance = Number((walletRpc as Record<string, number> | null)?.balance) || 0;

      if (balance <= 0) {
        toast({
          title: "Insufficient Balance",
          description: "Please recharge your wallet to start chatting",
          variant: "destructive",
        });
        navigate("/wallet");
        return;
      }

      // Start chat via edge function
      const { data, error } = await supabase.functions.invoke("chat-manager", {
        body: {
          action: "start_chat",
          man_user_id: currentUserId,
          woman_user_id: woman.userId,
          preferred_language: currentUserLanguage
        }
      });

      if (error) throw error;

      // Mark as self-initiated to prevent incoming chat popup
      if (data?.session_id || data?.chat_id) {
        const { markChatAsSelfInitiated } = await import("@/hooks/useIncomingChats");
        markChatAsSelfInitiated(data.session_id, data.chat_id);
      }

      if (data?.success) {
        setActiveChatId(data.chat_id);
        setConnectionStatus("connected");
        toast({
          title: "Connected!",
          description: `You're now chatting with ${woman.fullName}`,
        });
        
        // Navigate to dashboard - parallel chat container will show the chat
        navigate("/dashboard");
      } else if (data?.message === "Insufficient balance") {
        toast({
          title: "Insufficient Balance",
          description: "Please recharge to continue",
          variant: "destructive",
        });
        navigate("/wallet");
      } else {
        // Woman might be busy, try next available
        await handleAutoConnect(woman.userId);
      }
    } catch (error) {
      console.error("Error initiating chat:", error);
      toast.error("Chat unavailable", { description: classifyError(error, "start the chat").message });
      // Try to connect to next available woman
      await handleAutoConnect(woman.userId);
    } finally {
      setIsConnecting(false);
    }
  };

  const handleAutoConnect = async (excludeUserId?: string) => {
    setConnectionStatus("searching");
    
    const nextWoman = await findNextAvailableWoman(excludeUserId);
    
    if (nextWoman) {
      toast({
        title: "Finding available user...",
        description: `Connecting to ${nextWoman.fullName}`,
      });
      await initiateChat(nextWoman);
    } else {
      setConnectionStatus("idle");
      toast({
        title: "No one available",
        description: "All users are currently busy. Please try again later.",
        variant: "destructive",
      });
    }
  };

  const handleReconnect = async () => {
    if (reconnectAttempts.current >= maxReconnectAttempts) {
      toast({
        title: "Connection failed",
        description: "Unable to find available users. Please try again later.",
        variant: "destructive",
      });
      setConnectionStatus("idle");
      reconnectAttempts.current = 0;
      return;
    }

    reconnectAttempts.current += 1;
    setConnectionStatus("reconnecting");
    
    await loadMatchableWomen();
    await handleAutoConnect(selectedWoman?.userId);
  };

  const handleQuickConnect = async () => {
    const availableWoman = await findNextAvailableWoman();
    
    if (availableWoman) {
      await initiateChat(availableWoman);
    } else {
      toast({
        title: "No one available",
        description: "No users are currently online with matching language",
        variant: "destructive",
      });
    }
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="text-center space-y-4">
          <Loader2 className="w-12 h-12 text-primary animate-spin mx-auto" />
          <p className="text-muted-foreground">Finding users who speak {currentUserLanguage}...</p>
        </div>
      </div>
    );
  }

  const manHasIndianLanguage = isIndianLanguage(currentUserLanguage);
  const visibilityExplanation = getVisibilityExplanation(currentUserLanguage);

  const sameLanguageWomen = matchableWomen.filter(
    w => w.motherTongue.toLowerCase() === currentUserLanguage.toLowerCase()
  );
  const otherWomen = matchableWomen.filter(
    w => w.motherTongue.toLowerCase() !== currentUserLanguage.toLowerCase()
  );

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-background to-primary/5">
      {/* Header */}
      <header className="sticky top-0 z-50 bg-background/80 backdrop-blur-lg border-b border-border/50">
        <div className="max-w-4xl mx-auto px-4 py-4 flex items-center justify-between">
          <button 
            onClick={() => navigate("/dashboard")}
            className="flex items-center gap-2 text-muted-foreground hover:text-foreground transition-colors"
          >
            <ArrowLeft className="w-5 h-5" />
            <span className="text-sm font-medium">Back</span>
          </button>
          
          <MeowLogo size="sm" />
          
          <div className="flex items-center gap-2">
            <Circle className="w-3 h-3 fill-emerald-500 text-emerald-500" />
            <span className="text-sm text-muted-foreground">{matchableWomen.length} online</span>
          </div>
        </div>
      </header>

      <main className="max-w-4xl mx-auto px-4 py-6 space-y-6">
        {/* Status Banner */}
        {connectionStatus !== "idle" && (
          <Card className="p-4 bg-primary/10 border-primary/30 animate-pulse">
            <div className="flex items-center gap-3">
              {connectionStatus === "searching" && (
                <>
                  <Loader2 className="w-5 h-5 text-primary animate-spin" />
                  <span className="text-foreground">Searching for available users...</span>
                </>
              )}
              {connectionStatus === "connecting" && (
                <>
                  <Phone className="w-5 h-5 text-primary animate-bounce" />
                  <span className="text-foreground">Connecting to {selectedWoman?.fullName}...</span>
                </>
              )}
              {connectionStatus === "reconnecting" && (
                <>
                  <RefreshCw className="w-5 h-5 text-primary animate-spin" />
                  <span className="text-foreground">Reconnecting... Attempt {reconnectAttempts.current}/{maxReconnectAttempts}</span>
                </>
              )}
            </div>
          </Card>
        )}

        {/* Language Visibility Info Banner */}
        <Card className="p-4 bg-muted/50 border-border/50">
          <div className="flex items-start gap-3">
            <div className="p-2 rounded-full bg-primary/10">
              <Languages className="w-5 h-5 text-primary" />
            </div>
            <div className="flex-1">
              <div className="flex items-center gap-2 mb-1">
                <h3 className="font-semibold text-foreground">Auto-Translation Active</h3>
                <Badge variant={manHasIndianLanguage ? "default" : "secondary"}>
                  {manHasIndianLanguage ? "Same Language Priority" : "Cross-Language Mode"}
                </Badge>
              </div>
              <p className="text-sm text-muted-foreground">
                {visibilityExplanation}
              </p>
            </div>
            <TooltipProvider>
              <Tooltip>
                <TooltipTrigger>
                  <Info className="w-5 h-5 text-muted-foreground" />
                </TooltipTrigger>
                <TooltipContent className="max-w-xs">
                  <p>Messages will be translated automatically when needed. You can chat with anyone regardless of language!</p>
                </TooltipContent>
              </Tooltip>
            </TooltipProvider>
          </div>
        </Card>

        {/* Quick Connect Button */}
        <Card className="p-6 bg-gradient-to-r from-primary/20 to-rose-500/20 border-primary/30">
          <div className="flex flex-col sm:flex-row items-center justify-between gap-4">
            <div>
              <h2 className="text-xl font-bold text-foreground mb-1">Quick Connect</h2>
              <p className="text-sm text-muted-foreground">
                Auto-connect to the best available match
                {sameLanguageWomen.length > 0 ? ` who speaks ${currentUserLanguage}` : " with auto-translation"}
              </p>
            </div>
            <Button 
              variant="aurora" 
              size="lg"
              onClick={handleQuickConnect}
              disabled={isConnecting || matchableWomen.length === 0}
              className="min-w-[150px]"
            >
              {isConnecting ? (
                <Loader2 className="w-5 h-5 animate-spin" />
              ) : (
                <>
                  <Phone className="w-5 h-5 mr-2" />
                  Connect Now
                </>
              )}
            </Button>
          </div>
        </Card>

        {/* Same Language Users */}
        {sameLanguageWomen.length > 0 && (
          <section className="space-y-4">
            <div className="flex items-center gap-2">
              <Languages className="w-5 h-5 text-primary" />
              <h3 className="text-lg font-semibold text-foreground">
                Speaks {currentUserLanguage}
              </h3>
              <Badge variant="secondary" className="ml-2">
                {sameLanguageWomen.length} available
              </Badge>
            </div>

        <div className="grid grid-cols-2 sm:grid-cols-2 lg:grid-cols-3 gap-2 sm:gap-4">
              {sameLanguageWomen.map((woman) => (
                <WomanCard 
                  key={woman.userId}
                  woman={woman}
                  onConnect={() => initiateChat(woman)}
                  onViewProfile={() => navigate(`/profile/${woman.userId}`)}
                  isConnecting={isConnecting && selectedWoman?.userId === woman.userId}
                  isPriority
                />
              ))}
            </div>
          </section>
        )}

        {/* Other Language Users */}
        {otherWomen.length > 0 && (
          <section className="space-y-4">
            <div className="flex items-center gap-2">
              <Sparkles className="w-5 h-5 text-amber-500" />
              <h3 className="text-lg font-semibold text-foreground">
                {manHasIndianLanguage ? "Other Languages" : "Indian Language Speakers"}
              </h3>
              <Badge variant="outline" className="ml-2">
                {otherWomen.length} online
              </Badge>
              <Badge variant="secondary" className="ml-1">
                <Languages className="w-3 h-3 mr-1" />
                Auto-translate
              </Badge>
            </div>

            <div className="grid grid-cols-2 sm:grid-cols-2 lg:grid-cols-3 gap-2 sm:gap-4">
              {otherWomen.map((woman) => (
                <WomanCard 
                  key={woman.userId}
                  woman={woman}
                  onConnect={() => initiateChat(woman)}
                  onViewProfile={() => navigate(`/profile/${woman.userId}`)}
                  isConnecting={isConnecting && selectedWoman?.userId === woman.userId}
                  showTranslationBadge
                />
              ))}
            </div>
          </section>
        )}

        {/* Empty State */}
        {matchableWomen.length === 0 && (
          <Card className="p-12 text-center">
            <div className="w-20 h-20 mx-auto mb-6 rounded-full bg-muted flex items-center justify-center">
              <PhoneOff className="w-10 h-10 text-muted-foreground" />
            </div>
            <h2 className="text-2xl font-bold text-foreground mb-2">No one online right now</h2>
            <p className="text-muted-foreground mb-6">
              {manHasIndianLanguage 
                ? `Check back later to find users who speak ${currentUserLanguage}`
                : "Check back later to find users with auto-translation support"}
            </p>
            <Button variant="gradient" onClick={() => navigate("/dashboard")}>
              Back to Dashboard
            </Button>
          </Card>
        )}
      </main>
    </div>
  );
};

interface WomanCardProps {
  woman: MatchableWoman;
  onConnect: () => void;
  onViewProfile: () => void;
  isConnecting: boolean;
  isPriority?: boolean;
  showTranslationBadge?: boolean;
}

const WomanCard = ({ woman, onConnect, onViewProfile, isConnecting, isPriority, showTranslationBadge }: WomanCardProps) => {
  return (
    <Card className={`overflow-hidden transition-all hover:shadow-lg ${
      isPriority ? "ring-2 ring-primary/50" : ""
    } ${woman.isBusy ? "opacity-70" : ""}`}>
      {/* Photo */}
      <div 
        className="relative aspect-[4/3] bg-muted cursor-pointer"
        onClick={onViewProfile}
      >
        {woman.photoUrl ? (
          <img 
            src={woman.photoUrl} 
            alt={woman.fullName}
            className="w-full h-full object-cover"
          />
        ) : (
          <div className="w-full h-full flex items-center justify-center bg-gradient-to-br from-primary/20 to-rose-500/20">
            <span className="text-4xl font-bold text-primary/50">
              {woman.fullName.charAt(0).toUpperCase()}
            </span>
          </div>
        )}

        {/* Status badges */}
        <div className="absolute top-1.5 right-1.5 sm:top-2 sm:right-2 flex flex-col gap-0.5 sm:gap-1">
          <div className="flex items-center gap-1 px-1.5 py-0.5 sm:px-2 sm:py-1 rounded-full bg-background/80 backdrop-blur-sm">
            <Circle className={`w-1.5 h-1.5 sm:w-2 sm:h-2 ${woman.isBusy ? "fill-amber-500 text-amber-500" : "fill-emerald-500 text-emerald-500"} animate-pulse`} />
            <span className="text-[9px] sm:text-xs font-medium text-foreground">
              {woman.isBusy ? "Busy" : "Free"}
            </span>
          </div>
          {isPriority && (
            <div className="px-1.5 py-0.5 sm:px-2 sm:py-1 rounded-full bg-primary/90 text-primary-foreground text-[9px] sm:text-xs font-medium text-center">
              Same Lang
            </div>
          )}
          {showTranslationBadge && (
            <div className="flex items-center gap-0.5 px-1.5 py-0.5 sm:px-2 sm:py-1 rounded-full bg-warning/90 text-warning-foreground text-[9px] sm:text-xs font-medium">
              <Languages className="w-2.5 h-2.5 sm:w-3 sm:h-3" />
              <span>Auto</span>
            </div>
          )}
          {woman.aiVerified && (
            <div className="flex items-center gap-0.5 px-1.5 py-0.5 sm:px-2 sm:py-1 rounded-full bg-info/90 text-info-foreground text-[9px] sm:text-xs font-medium">
              <Shield className="w-2.5 h-2.5 sm:w-3 sm:h-3" />
              <span>✓</span>
            </div>
          )}
          <div className="flex items-center gap-0.5 px-1.5 py-0.5 sm:px-2 sm:py-1 rounded-full bg-success/90 text-success-foreground text-[9px] sm:text-xs font-medium">
            <IndianRupee className="w-2.5 h-2.5 sm:w-3 sm:h-3" />
            <span>Earns</span>
          </div>
        </div>
      </div>

      {/* Info */}
      <div className="p-2.5 sm:p-4 space-y-2 sm:space-y-3">
        <div>
          <h4 className="font-semibold text-sm sm:text-base text-foreground truncate">{woman.fullName}</h4>
          <div className="flex items-center gap-1 sm:gap-2 text-[10px] sm:text-sm text-muted-foreground flex-wrap">
            {woman.age && <span>{woman.age} yrs</span>}
            <span>•</span>
            <div className="flex items-center gap-0.5 sm:gap-1">
              <Languages className="w-3 h-3 sm:w-3.5 sm:h-3.5 shrink-0" />
              <span className="truncate max-w-[60px] sm:max-w-none">{woman.motherTongue}</span>
            </div>
            {woman.country && (
              <>
                <span>•</span>
                <span className="truncate max-w-[50px] sm:max-w-none">{woman.country}</span>
              </>
            )}
          </div>
        </div>

        {/* Actions */}
        <div className="flex gap-1.5 sm:gap-2">
          <Button 
            variant={woman.isBusy ? "outline" : "gradient"}
            size="sm"
            className="flex-1 text-[10px] xs:text-xs sm:text-sm gap-1 !px-2 sm:!px-3"
            onClick={onConnect}
            disabled={isConnecting}
          >
            {isConnecting ? (
              <Loader2 className="w-3.5 h-3.5 sm:w-4 sm:h-4 animate-spin shrink-0" />
            ) : woman.isBusy ? (
              <>
                <Clock className="w-3.5 h-3.5 sm:w-4 sm:h-4 shrink-0" />
                <span className="truncate">Queue</span>
              </>
            ) : (
              <>
                <MessageCircle className="w-3.5 h-3.5 sm:w-4 sm:h-4 shrink-0" />
                <span className="truncate">Chat</span>
              </>
            )}
          </Button>
          <Button 
            variant="outline" 
            size="sm"
            onClick={onViewProfile}
            className="!px-2 sm:!px-3"
          >
            <User className="w-3.5 h-3.5 sm:w-4 sm:h-4" />
          </Button>
        </div>
      </div>
    </Card>
  );
};

export default MatchingScreen;
