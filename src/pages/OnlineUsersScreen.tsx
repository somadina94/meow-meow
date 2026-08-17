import { useState, useEffect, useRef } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import MeowLogo from "@/components/MeowLogo";
import { useToast } from "@/hooks/use-toast";
import { 
  Heart, 
  X, 
  ArrowLeft,
  Circle,
  Languages,
  Loader2,
  Eye
} from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { isVisibilityStatusChange } from "@/lib/presence";

import {
  Carousel,
  CarouselContent,
  CarouselItem,
  CarouselNext,
  CarouselPrevious,
  type CarouselApi,
} from "@/components/ui/carousel";
import { getQuickMatchScore } from "@/lib/matchScoreCalculator";

interface OnlineUser {
  userId: string;
  avatar: string;
  fullName: string;
  onlineStatus: boolean;
  motherTongue: string;
  gender: string;
}

const OnlineUsersScreen = () => {
  const navigate = useNavigate();
  const { toast } = useToast();
  const t = (key: string, def: string) => def;
  const [isLoading, setIsLoading] = useState(true);
  const [onlineUsers, setOnlineUsers] = useState<OnlineUser[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [selectedUser, setSelectedUser] = useState<OnlineUser | null>(null);
  const [api, setApi] = useState<CarouselApi>();
  const [currentUserGender, setCurrentUserGender] = useState<string>("");
  const userStatusSnapshotRef = useRef<Map<string, string>>(new Map());
  const loadTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const selectedUserIdRef = useRef<string | null>(null);

  useEffect(() => {
    loadOnlineUsers();
    const cleanup = setupRealtimeSubscription();
    return () => {
      if (loadTimeoutRef.current) clearTimeout(loadTimeoutRef.current);
      cleanup();
    };
  }, []);

  useEffect(() => {
    if (!api) return;

    api.on("select", () => {
      setCurrentIndex(api.selectedScrollSnap());
    });
  }, [api]);

  const setupRealtimeSubscription = () => {
    const channel = supabase
      .channel('online-users-carousel')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'user_status'
        },
        (payload) => {
          if (!isVisibilityStatusChange(payload as { eventType?: string; new?: Record<string, unknown>; old?: Record<string, unknown> }, userStatusSnapshotRef.current)) return;
          if (loadTimeoutRef.current) clearTimeout(loadTimeoutRef.current);
          loadTimeoutRef.current = setTimeout(() => {
            void loadOnlineUsers();
          }, 1500);
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  };

  const loadOnlineUsers = async () => {
    try {
      const { data: { session } } = await supabase.auth.getSession();
      
      if (!session?.user) {
        navigate("/");
        return;
      }
      const user = session.user;

      // Get current user's gender
      const { data: currentProfile } = await supabase
        .from("profiles")
        .select("gender")
        .eq("user_id", user.id)
        .maybeSingle();

      const userGender = currentProfile?.gender || "";
      setCurrentUserGender(userGender);

      // Determine opposite gender
      const oppositeGender = userGender.toLowerCase() === "male" ? "female" : 
                            userGender.toLowerCase() === "female" ? "male" : "";

      // Fetch online users of opposite gender (exclude busy = in active call/group)
      const { data: onlineStatus } = await supabase
        .from("user_status")
        .select("user_id, is_online, last_seen, status_text")
        .eq("is_online", true)
        .neq("status_text", "busy")
        .neq("user_id", user.id);

      if (!onlineStatus || onlineStatus.length === 0) {
        setOnlineUsers([]);
        setIsLoading(false);
        return;
      }

      const onlineUserIds = onlineStatus.map(s => s.user_id);

      // Fetch profiles of online users with opposite gender (must have photo)
      let query = supabase
        .from("profiles")
        .select("user_id, full_name, photo_url, gender, preferred_language")
        .in("user_id", onlineUserIds)
        .not("photo_url", "is", null)
        .neq("photo_url", "");

      if (oppositeGender) {
        query = query.ilike("gender", oppositeGender);
      }

      const { data: profiles } = await query;

      const validProfiles = (profiles || []).filter(
        profile => profile.photo_url && profile.photo_url.trim() !== ""
      );
      const validUserIds = validProfiles.map(p => p.user_id);

      // Batch fetch languages for all users in a single query
      const { data: allLanguages } = validUserIds.length > 0
        ? await supabase
            .from("user_languages")
            .select("user_id, language_name")
            .in("user_id", validUserIds)
        : { data: [] };

      const languageMap = new Map<string, string>();
      for (const lang of allLanguages || []) {
        if (!languageMap.has(lang.user_id)) {
          languageMap.set(lang.user_id, lang.language_name);
        }
      }

      const users: OnlineUser[] = validProfiles.map((profile) => ({
        userId: profile.user_id,
        avatar: profile.photo_url!,
        fullName: profile.full_name || "Anonymous",
        onlineStatus: true,
        motherTongue: languageMap.get(profile.user_id) || profile.preferred_language || "Unknown",
        gender: profile.gender || "",
      }));

      setOnlineUsers(users);

      const stillSelected = users.find(u => u.userId === selectedUserIdRef.current);
      if (stillSelected) {
        setSelectedUser(stillSelected);
      } else if (users.length > 0) {
        selectedUserIdRef.current = users[0].userId;
        setSelectedUser(users[0]);
      } else {
        selectedUserIdRef.current = null;
        setSelectedUser(null);
      }
    } catch (error) {
      console.error("Error loading online users:", error);
      toast({
        title: t('error', 'Error'),
        description: t('failedToLoadData', 'Failed to load online users'),
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleLike = async (user: OnlineUser) => {
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.user) return;
      const currentUser = session.user;

      // Check if match already exists
      const { data: existingMatch } = await supabase
        .from("matches")
        .select("id")
        .or(`and(user_id.eq.${currentUser.id},matched_user_id.eq.${user.userId}),and(user_id.eq.${user.userId},matched_user_id.eq.${currentUser.id})`)
        .maybeSingle();

      if (existingMatch) {
      toast({
        title: t('alreadyMatched', 'Already matched!'),
        description: `${t('youveAlreadyConnectedWith', "You've already connected with")} ${user.fullName}`,
      });
      return;
    }

      // Calculate match score based on profile compatibility
      const matchScore = await getQuickMatchScore(supabase, currentUser.id, user.userId);

      // Create match with calculated score
      await supabase
        .from("matches")
        .insert({
          user_id: currentUser.id,
          matched_user_id: user.userId,
          status: "pending",
          match_score: matchScore,
        });

      toast({
        title: `${t('liked', 'Liked')}! 💕`,
        description: `${t('waitingForResponse', 'Waiting for them to respond!')}`,
      });

      // Move to next user
      if (api && currentIndex < onlineUsers.length - 1) {
        api.scrollNext();
      }
    } catch (error) {
      console.error("Error liking user:", error);
      toast({
        title: t('error', 'Error'),
        description: t('failedToSave', 'Failed to send like'),
        variant: "destructive",
      });
    }
  };

  const handlePass = () => {
    if (api && currentIndex < onlineUsers.length - 1) {
      api.scrollNext();
    } else {
      toast({
        title: t('noMoreUsers', 'No more users'),
        description: t('checkBackLaterForMore', 'Check back later for more online users!'),
      });
    }
  };

  const handleUserSelect = (user: OnlineUser, index: number) => {
    selectedUserIdRef.current = user.userId;
    setSelectedUser(user);
    setCurrentIndex(index);
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="text-center space-y-4">
          <Loader2 className="w-12 h-12 text-primary animate-spin mx-auto" />
          <p className="text-muted-foreground">{t('findingOnlineUsers', 'Finding online users...')}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-background to-primary/5">
      {/* Header */}
      <header className="sticky top-0 z-50 bg-background/80 backdrop-blur-lg border-b border-border/50">
        <div className="max-w-4xl mx-auto px-6 py-4 flex items-center justify-between">
          <button 
            onClick={() => navigate("/dashboard")}
            className="flex items-center gap-2 text-muted-foreground hover:text-foreground transition-colors"
          >
            <ArrowLeft className="w-5 h-5" />
            <span className="text-sm font-medium">{t('back', 'Back')}</span>
          </button>
          
          <MeowLogo size="sm" />
          
          <div className="flex items-center gap-2">
            <Circle className="w-3 h-3 fill-emerald-500 text-emerald-500" />
            <span className="text-sm text-muted-foreground">{onlineUsers.length} {t('online', 'online')}</span>
          </div>
        </div>
      </header>

      <main className="max-w-4xl mx-auto px-6 py-8">
        {onlineUsers.length === 0 ? (
          <Card className="p-12 text-center animate-fade-in">
            <div className="w-20 h-20 mx-auto mb-6 rounded-full bg-muted flex items-center justify-center">
              <Heart className="w-10 h-10 text-muted-foreground" />
            </div>
            <h2 className="text-2xl font-bold text-foreground mb-2">{t('noOneOnlineRightNow', 'No one online right now')}</h2>
            <p className="text-muted-foreground mb-6">
              {t('checkBackLater', 'Check back later to find users matching your preferences')}
            </p>
            <Button variant="aurora" onClick={() => navigate("/dashboard")}>
              {t('backToDashboard', 'Back to Dashboard')}
            </Button>
          </Card>
        ) : (
          <div className="space-y-8">
            {/* Title */}
            <div className="text-center animate-fade-in">
              <h1 className="text-2xl font-bold text-foreground mb-2">{t('onlineNow', 'Online Now')}</h1>
              <p className="text-muted-foreground">
                {t('browseOnlineUsers', 'Browse users who are online right now')}
              </p>
            </div>

            {/* Main Carousel */}
            <div className="relative animate-fade-in" style={{ animationDelay: "0.1s" }}>
              <Carousel
                setApi={setApi}
                opts={{
                  align: "center",
                  loop: false,
                }}
                className="w-full"
              >
                <CarouselContent className="-ml-4">
                  {onlineUsers.map((user, index) => (
                    <CarouselItem key={user.userId} className="pl-4 md:basis-1/2 lg:basis-1/3">
                      <Card 
                        className={`relative overflow-hidden cursor-pointer transition-all duration-500 ${
                          currentIndex === index 
                            ? "scale-100 shadow-glow border-primary/50" 
                            : "scale-90 opacity-70 hover:opacity-90"
                        }`}
                        onClick={() => handleUserSelect(user, index)}
                        onDoubleClick={() => navigate(`/profile/${user.userId}`)}
                      >
                        {/* Avatar - only shows users with photos */}
                        <div className="relative aspect-[3/4] overflow-hidden bg-muted">
                          <img 
                            src={user.avatar} 
                            alt={user.fullName}
                            className={`w-full h-full object-cover transition-transform duration-500 ${
                              currentIndex === index ? "scale-110" : "scale-100"
                            }`}
                          />

                          {/* Online indicator */}
                          <div className="absolute top-4 right-4 flex items-center gap-2 px-3 py-1.5 rounded-full bg-background/80 backdrop-blur-sm">
                            <Circle className="w-2.5 h-2.5 fill-emerald-500 text-emerald-500 animate-pulse" />
                            <span className="text-xs font-medium text-foreground">{t('online', 'Online')}</span>
                          </div>

                          {/* Gradient overlay */}
                          <div className="absolute inset-0 bg-gradient-to-t from-background via-transparent to-transparent" />

                          {/* User info */}
                          <div className="absolute bottom-0 left-0 right-0 p-5">
                            <h3 className="text-xl font-bold text-foreground mb-1">
                              {user.fullName}
                            </h3>
                            <div className="flex items-center gap-2 text-muted-foreground">
                              <Languages className="w-4 h-4" />
                              <span className="text-sm">{user.motherTongue}</span>
                            </div>
                          </div>
                        </div>
                      </Card>
                    </CarouselItem>
                  ))}
                </CarouselContent>

                <CarouselPrevious className="left-2 bg-background/80 backdrop-blur-sm border-border/50 hover:bg-background" />
                <CarouselNext className="right-2 bg-background/80 backdrop-blur-sm border-border/50 hover:bg-background" />
              </Carousel>
            </div>

            {/* Carousel indicators */}
            <div className="flex justify-center gap-2 animate-fade-in" style={{ animationDelay: "0.2s" }}>
              {onlineUsers.map((_, index) => (
                <button
                  key={index}
                  onClick={() => api?.scrollTo(index)}
                  className={`w-2 h-2 rounded-full transition-all ${
                    currentIndex === index 
                      ? "w-8 bg-primary" 
                      : "bg-muted-foreground/30 hover:bg-muted-foreground/50"
                  }`}
                />
              ))}
            </div>

            {/* Action Buttons */}
            <div className="flex justify-center gap-6 animate-fade-in" style={{ animationDelay: "0.3s" }}>
              {/* Pass Button */}
              <button
                onClick={handlePass}
                className="group w-16 h-16 rounded-full bg-card border-2 border-border hover:border-destructive/50 hover:bg-destructive/10 flex items-center justify-center transition-all duration-300 shadow-card hover:shadow-lg"
              >
                <X className="w-8 h-8 text-muted-foreground group-hover:text-destructive transition-colors" />
              </button>

              {/* Like Button */}
              <button
                onClick={() => selectedUser && handleLike(selectedUser)}
                className="group w-20 h-20 rounded-full bg-gradient-to-br from-primary to-rose-500 hover:from-primary/90 hover:to-rose-500/90 flex items-center justify-center transition-all duration-300 shadow-glow hover:shadow-lg hover:scale-110"
              >
                <Heart className="w-10 h-10 text-white fill-white group-hover:animate-bounce-subtle" />
              </button>

              {/* View Profile Button */}
              <button
                onClick={() => selectedUser && navigate(`/profile/${selectedUser.userId}`)}
                className="group w-16 h-16 rounded-full bg-card border-2 border-border hover:border-primary/50 hover:bg-primary/10 flex items-center justify-center transition-all duration-300 shadow-card hover:shadow-lg"
              >
                <Eye className="w-8 h-8 text-muted-foreground group-hover:text-primary transition-colors" />
              </button>
            </div>

            {/* User counter */}
            <p className="text-center text-sm text-muted-foreground animate-fade-in" style={{ animationDelay: "0.4s" }}>
              {currentIndex + 1} {t('of', 'of')} {onlineUsers.length} {t('onlineUsers', 'online users')}
            </p>
          </div>
        )}
      </main>
    </div>
  );
};

export default OnlineUsersScreen;
