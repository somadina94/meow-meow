import { useState, useEffect } from "react";
import { fetchPublicProfile } from "@/lib/profile-queries";
import { useNavigate, useParams } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import MeowLogo from "@/components/MeowLogo";
import { useToast } from "@/hooks/use-toast";
// useChatPricing removed — billing system removed
import { 
  Heart, 
  ArrowLeft,
  Languages,
  MapPin,
  MessageCircle,
  Circle,
  Calendar,
  Shield,
  Loader2,
  X,
  Sparkles,
  Home,
  Wallet
} from "lucide-react";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { supabase } from "@/integrations/supabase/client";


interface UserPhoto {
  id: string;
  photo_url: string;
  photo_type: string;
  display_order: number;
  is_primary: boolean;
}

interface ProfileData {
  userId: string;
  userCode: string | null;
  fullName: string;
  avatar: string;
  age: number | null;
  gender: string;
  country: string;
  state: string;
  motherTongue: string;
  optionalLanguages: string[];
  interests: string[];
  isOnline: boolean;
  lastSeen: string;
  isVerified: boolean;
  bio: string | null;
  occupation: string | null;
  photos: UserPhoto[];
}

// Fields that should NEVER be shown to other users
// Phone, Email, and KYC details are strictly private
const HIDDEN_FIELDS = ['phone', 'email', 'kyc', 'date_of_birth'] as const;

const ProfileDetailScreen = () => {
  const navigate = useNavigate();
  const { userId } = useParams<{ userId: string }>();
  const { toast } = useToast();
  const t = (key: string, def: string) => def; const translateDynamicBatch = async (t: string[]) => t; const currentLanguage = "English";
  const [isLoading, setIsLoading] = useState(true);
  const [profile, setProfile] = useState<ProfileData | null>(null);
  const [isLiked, setIsLiked] = useState(false);
  const [currentUserId, setCurrentUserId] = useState<string>("");
  const [selectedPhotoIndex, setSelectedPhotoIndex] = useState(0);
  
  const [currentUserGender, setCurrentUserGender] = useState("");
  const [walletBalance, setWalletBalance] = useState<number>(0);
  const [showRechargeDialog, setShowRechargeDialog] = useState(false);
  const [rechargeMessage, setRechargeMessage] = useState("");
  const pricing = { ratePerMinute: 0 };

  useEffect(() => {
    if (userId) {
      loadProfile(userId);
    }
  }, [userId]);

  // Real-time subscription for online status
  useEffect(() => {
    if (!userId) return;

    const channel = supabase
      .channel(`profile-status-${userId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'user_status',
          filter: `user_id=eq.${userId}`
        },
        (payload: any) => {
          if (payload.new) {
            setProfile(prev => prev ? {
              ...prev,
              isOnline: payload.new.is_online,
              lastSeen: payload.new.last_seen
            } : null);
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [userId]);

  const loadProfile = async (targetUserId: string) => {
    try {
      setIsLoading(true);

      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.user) {
        navigate("/");
        return;
      }
      const user = session.user;
      setCurrentUserId(user.id);

      // PARALLEL: Fetch all data at once instead of sequential
      const [
        currentUserResult,
        profileResult,
        languagesResult,
        photosResult,
        statusResult,
        matchResult,
        walletResult
      ] = await Promise.all([
        supabase.from("profiles")
          .select("gender")
          .eq("user_id", user.id).maybeSingle(),
        fetchPublicProfile(targetUserId).then(data => ({ data, error: null })),
        supabase.from("user_languages")
          .select("language_name")
          .eq("user_id", targetUserId),
        supabase.from("user_photos")
          .select("*")
          .eq("user_id", targetUserId)
          .order("display_order", { ascending: true }),
        supabase.from("user_status")
          .select("is_online, last_seen")
          .eq("user_id", targetUserId).maybeSingle(),
        supabase.from("matches")
          .select("id")
          .eq("user_id", user.id)
          .eq("matched_user_id", targetUserId).maybeSingle(),
        // Placeholder — actual balance loaded gender-aware below via canonical RPC
        Promise.resolve({ data: null, error: null }),
      ]);

      const currentUserProfile = currentUserResult.data;
      const profileData = profileResult.data;
      // Load balance via canonical SoT RPC based on current user's gender
      const myGender = currentUserProfile?.gender?.toLowerCase() || "";
      try {
        if (myGender === "female") {
          const { data: wRpc } = await supabase.rpc("get_women_wallet_balance", { p_user_id: user.id });
          setWalletBalance(Number((wRpc as Record<string, number> | null)?.available_balance) || 0);
        } else {
          const { data: mRpc } = await supabase.rpc("get_men_wallet_balance", { p_user_id: user.id });
          setWalletBalance(Number((mRpc as Record<string, number> | null)?.balance) || 0);
        }
      } catch { setWalletBalance(0); }

      const gender = currentUserProfile?.gender?.toLowerCase() || "";
      setCurrentUserGender(gender);
      

      if (!profileData) {
        toast({
          title: "Profile not found",
          description: "This user profile doesn't exist",
          variant: "destructive",
        });
        navigate(-1);
        return;
      }

      setIsLiked(!!matchResult.data);

      // Use age from profile (date_of_birth is not exposed in public profile for privacy)
      let age: number | null = profileData.age || null;

      const allLanguages = languagesResult.data?.map(l => l.language_name) || [];
      let motherTongue = profileData.preferred_language || allLanguages[0] || "Not specified";
      let optionalLanguages = allLanguages.filter(l => l !== motherTongue);

      if (currentLanguage !== 'English') {
        const textsToTranslate = [
          motherTongue,
          profileData.country || 'Unknown',
          profileData.state || '',
          ...optionalLanguages
        ].filter(Boolean);
        
        const translated = await translateDynamicBatch(textsToTranslate);
        motherTongue = translated[0] || motherTongue;
        const translatedCountry = translated[1] || profileData.country || 'Unknown';
        const translatedState = translated[2] || profileData.state || '';
        const translatedOptionalLangs = optionalLanguages.map((_, i) => translated[3 + i] || optionalLanguages[i]);

        setProfile({
          userId: targetUserId,
          userCode: (profileData as any).user_code ?? null,
          fullName: profileData.full_name || "Anonymous",
          avatar: profileData.photo_url || "",
          age,
          gender: profileData.gender || t('notAvailable', 'Not specified'),
          country: translatedCountry,
          state: translatedState,
          motherTongue,
          optionalLanguages: translatedOptionalLangs,
          interests: profileData.interests || [],
          isOnline: statusResult.data?.is_online || false,
          lastSeen: statusResult.data?.last_seen || "",
          isVerified: profileData.verification_status || false,
          bio: profileData.bio || null,
          occupation: profileData.occupation || null,
          photos: (photosResult.data as UserPhoto[]) || [],
        });
      } else {
        setProfile({
          userId: targetUserId,
          userCode: (profileData as any).user_code ?? null,
          fullName: profileData.full_name || "Anonymous",
          avatar: profileData.photo_url || "",
          age,
          gender: profileData.gender || "Not specified",
          country: profileData.country || "Unknown",
          state: profileData.state || "",
          motherTongue,
          optionalLanguages,
          interests: profileData.interests || [],
          isOnline: statusResult.data?.is_online || false,
          lastSeen: statusResult.data?.last_seen || "",
          isVerified: profileData.verification_status || false,
          bio: profileData.bio || null,
          occupation: profileData.occupation || null,
          photos: (photosResult.data as UserPhoto[]) || [],
        });
      }

    } catch (error) {
      console.error("Error loading profile:", error);
      toast({
        title: "Error",
        description: "Failed to load profile",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleLike = async () => {
    if (!profile || isLiked || profile.userId === currentUserId) return;

    try {
      await supabase
        .from("matches")
        .insert({
          user_id: currentUserId,
          matched_user_id: profile.userId,
          status: "pending",
          match_score: 75,
        });

      setIsLiked(true);
      toast({
        title: "Liked! 💕",
        description: `You liked ${profile.fullName}`,
      });
    } catch (error) {
      console.error("Error liking profile:", error);
      toast({
        title: "Error",
        description: "Failed to send like",
        variant: "destructive",
      });
    }
  };

  const handleChat = async () => {
    if (!profile || !currentUserId) return;

    try {
      // Get current user's gender
      const { data: currentProfile } = await supabase
        .from("profiles")
        .select("gender")
        .eq("user_id", currentUserId)
        .maybeSingle();

      const localGender = currentProfile?.gender?.toLowerCase();
      const isMale = localGender === "male";
      const isFemale = localGender === "female";

      // Check super user bypass
      const userEmail = (await supabase.auth.getSession()).data.session?.user?.email || '';
      const isSuperUser = /^(female|male|admin)([1-9]|1[0-5])@meow-meow\.com$/i.test(userEmail);

      // Men must have some wallet balance to start chat (women earn, no balance needed)
      if (isMale && !isSuperUser) {
        if (walletBalance <= 0) {
          setRechargeMessage("Your wallet balance is ₹0. Recharge is mandatory to start chatting.");
          setShowRechargeDialog(true);
          return;
        }
      }

      const { data, error } = await supabase.functions.invoke("chat-manager", {
        body: {
          action: "start_chat",
          man_user_id: isMale ? currentUserId : profile.userId,
          woman_user_id: isMale ? profile.userId : currentUserId,
        }
      });

      if (error) throw error;
      if (!data?.success) {
        throw new Error(data?.message || "Failed to start chat");
      }

      // Mark as self-initiated to prevent incoming chat popup
      if (data?.session_id || data?.chat_id) {
        const { markChatAsSelfInitiated } = await import("@/hooks/useIncomingChats");
        markChatAsSelfInitiated(data.session_id, data.chat_id);
      }

      if (data.chat_id) {
        await supabase.from("chat_messages").insert({
          chat_id: data.chat_id,
          sender_id: currentUserId,
          receiver_id: profile.userId,
          message: "👋 Hi!"
        });
      }

      // Navigate back to dashboard
      const dashboardRoute = isMale ? "/dashboard" : "/women-dashboard";
      navigate(dashboardRoute);
      setTimeout(() => {
        window.dispatchEvent(new CustomEvent('force-reload-chats'));
      }, 300);
      
      toast({
        title: t('chatStarted', 'Chat Started'),
        description: `${t('chattingWith', 'Chatting with')} ${profile.fullName}`,
      });
    } catch (error) {
      console.error("Error starting chat:", error);
      toast({
        title: "Error",
        description: "Failed to start chat",
        variant: "destructive",
      });
    }
  };

  const formatLastSeen = (lastSeen: string) => {
    if (!lastSeen) return t('unknown', 'Unknown');
    const date = new Date(lastSeen);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMins / 60);
    const diffDays = Math.floor(diffHours / 24);

    if (diffMins < 1) return t('justNow', 'Just now');
    if (diffMins < 60) return `${diffMins} ${t('minutes', 'min')} ${t('ago', 'ago')}`;
    if (diffHours < 24) return `${diffHours} ${t('hours', 'hour')}${diffHours > 1 ? "s" : ""} ${t('ago', 'ago')}`;
    return `${diffDays} day${diffDays > 1 ? "s" : ""} ${t('ago', 'ago')}`;
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="text-center space-y-4">
          <Loader2 className="w-12 h-12 text-primary animate-spin mx-auto" />
          <p className="text-muted-foreground">{t('loadingProfile', 'Loading profile...')}</p>
        </div>
      </div>
    );
  }

  if (!profile) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <Card className="p-8 text-center">
          <X className="w-12 h-12 text-muted-foreground mx-auto mb-4" />
          <h2 className="text-xl font-bold text-foreground mb-2">{t('profileNotFound', 'Profile Not Found')}</h2>
          <Button variant="aurora" onClick={() => navigate(-1)}>
            {t('goBack', 'Go Back')}
          </Button>
        </Card>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-background to-primary/5">
      {/* Header */}
      <header className="sticky top-0 z-50 bg-background/80 backdrop-blur-lg border-b border-border/50">
        <div className="max-w-4xl mx-auto px-6 py-4 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Button 
              variant="auroraGhost"
              size="icon"
              onClick={() => navigate(-1)}
              className="rounded-full"
            >
              <ArrowLeft className="w-5 h-5" />
            </Button>
            <Button 
              variant="auroraGhost"
              size="icon"
              onClick={() => {
                if (currentUserGender === "female") navigate("/women-dashboard");
                else navigate("/dashboard");
              }}
              className="rounded-full"
            >
              <Home className="w-5 h-5" />
            </Button>
          </div>
          
          <MeowLogo size="sm" />
          
          <div className="w-20" />
        </div>
      </header>

      <main className="max-w-2xl mx-auto px-6 py-8 space-y-6">
        {/* Profile Card */}
        <Card className="overflow-hidden animate-fade-in shadow-card">
          {/* Photo Gallery Section */}
          <div className="relative">
            {(() => {
              const allPhotos = profile.photos.length > 0 
                ? profile.photos.map(p => p.photo_url) 
                : profile.avatar ? [profile.avatar] : [];
              const currentPhoto = allPhotos[selectedPhotoIndex] || allPhotos[0];
              
              return (
                <>
                  <div className="aspect-square max-h-[400px] overflow-hidden bg-muted">
                    {currentPhoto ? (
                      <img 
                        src={currentPhoto} 
                        alt={profile.fullName}
                        className="w-full h-full object-cover"
                      />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center bg-gradient-to-br from-primary/20 to-secondary/20">
                        <span className="text-9xl font-bold text-primary/50">
                          {profile.fullName.charAt(0).toUpperCase()}
                        </span>
                      </div>
                    )}
                  </div>

                  {/* Photo thumbnails */}
                  {allPhotos.length > 1 && (
                    <div className="flex gap-1.5 p-3 bg-card/80 backdrop-blur-sm overflow-x-auto">
                      {allPhotos.map((photo, idx) => (
                        <button
                          key={idx}
                          onClick={() => setSelectedPhotoIndex(idx)}
                          className={`w-14 h-14 rounded-lg overflow-hidden flex-shrink-0 border-2 transition-all ${
                            idx === selectedPhotoIndex 
                              ? "border-primary ring-2 ring-primary/30" 
                              : "border-transparent opacity-70 hover:opacity-100"
                          }`}
                        >
                          <img src={photo} alt={`Photo ${idx + 1}`} className="w-full h-full object-cover" />
                        </button>
                      ))}
                    </div>
                  )}

                  {/* Photo counter */}
                  {allPhotos.length > 1 && (
                    <div className="absolute top-4 left-1/2 -translate-x-1/2 px-3 py-1 rounded-full bg-background/70 backdrop-blur-sm text-xs font-medium text-foreground">
                      {selectedPhotoIndex + 1} / {allPhotos.length}
                    </div>
                  )}
                </>
              );
            })()}

            {/* Online Status Badge */}
            <div className={`absolute top-4 right-4 flex items-center gap-2 px-4 py-2 rounded-full backdrop-blur-sm ${
              profile.isOnline 
                ? "bg-emerald-500/20 border border-emerald-500/30" 
                : "bg-muted/80"
            }`}>
              <Circle className={`w-3 h-3 ${
                profile.isOnline 
                  ? "fill-emerald-500 text-emerald-500 animate-pulse" 
                  : "fill-muted-foreground text-muted-foreground"
              }`} />
              <span className={`text-sm font-medium ${
                profile.isOnline ? "text-emerald-600 dark:text-emerald-400" : "text-muted-foreground"
              }`}>
                {profile.isOnline ? t('online', 'Online') : `${t('lastSeen', 'Last seen')} ${formatLastSeen(profile.lastSeen)}`}
              </span>
            </div>

            {/* Verified Badge */}
            {profile.isVerified && (
              <div className="absolute top-4 left-4 flex items-center gap-2 px-3 py-1.5 rounded-full bg-blue-500/20 border border-blue-500/30 backdrop-blur-sm">
                <Shield className="w-4 h-4 text-blue-500" />
                <span className="text-sm font-medium text-blue-600 dark:text-blue-400">{t('verified', 'Verified')}</span>
              </div>
            )}
          </div>

          {/* Profile Info */}
          <div className="p-6 space-y-6">
            {/* Name and Age */}
            <div className="flex items-center justify-between">
              <div>
                <h1 className="text-2xl font-bold text-foreground">
                  {profile.fullName}
                  {profile.age && <span className="text-muted-foreground font-normal">, {profile.age}</span>}
                </h1>
                <p className="text-muted-foreground">{profile.gender}</p>
                {profile.userCode && (
                  <p className="text-xs font-mono text-muted-foreground/80 mt-1 tracking-wider">
                    {profile.userCode}
                  </p>
                )}
              </div>
            </div>

            {/* Location */}
            <div className="flex items-center gap-3 text-muted-foreground">
              <MapPin className="w-5 h-5" />
              <span>
                {profile.state ? `${profile.state}, ` : ""}{profile.country}
              </span>
            </div>

            {/* Languages Section */}
            <div className="space-y-4">
              {/* Mother Tongue */}
              <div className="flex items-start gap-3">
                <Languages className="w-5 h-5 text-primary mt-0.5" />
                <div>
                  <p className="text-sm text-muted-foreground mb-1">{t('motherTongue', 'Mother Tongue')}</p>
                  <span className="px-3 py-1.5 rounded-full bg-primary/10 text-primary font-medium text-sm">
                    {profile.motherTongue}
                  </span>
                </div>
              </div>

              {/* Optional Languages */}
              {profile.optionalLanguages.length > 0 && (
                <div className="flex items-start gap-3">
                  <div className="w-5" /> {/* Spacer for alignment */}
                  <div>
                    <p className="text-sm text-muted-foreground mb-2">{t('alsoSpeaks', 'Also speaks')}</p>
                    <div className="flex flex-wrap gap-2">
                      {profile.optionalLanguages.map(lang => (
                        <span 
                          key={lang}
                          className="px-3 py-1.5 rounded-full bg-muted text-muted-foreground text-sm"
                        >
                          {lang}
                        </span>
                      ))}
                    </div>
                  </div>
                </div>
              )}
            </div>

            {/* Bio Section */}
            {profile.bio && (
              <div className="space-y-2">
                <p className="text-sm text-muted-foreground">{t('about', 'About')}</p>
                <p className="text-foreground">{profile.bio}</p>
              </div>
            )}

            {/* Occupation */}
            {profile.occupation && (
              <div className="flex items-center gap-3 text-muted-foreground">
                <Sparkles className="w-5 h-5" />
                <span>{profile.occupation}</span>
              </div>
            )}

            {/* Interests Section */}
            {profile.interests && profile.interests.length > 0 && (
              <div className="space-y-3">
                <div className="flex items-center gap-2">
                  <Sparkles className="w-5 h-5 text-primary" />
                  <p className="font-medium text-foreground">{t('interests', 'Interests')}</p>
                </div>
                <div className="flex flex-wrap gap-2">
                  {profile.interests.map((interest, idx) => (
                    <span 
                      key={idx}
                      className="px-3 py-1.5 rounded-full bg-primary/10 text-primary text-sm border border-primary/20"
                    >
                      {interest}
                    </span>
                  ))}
                </div>
              </div>
            )}
            {profile.age && (
              <div className="flex items-center gap-3 text-muted-foreground">
                <Calendar className="w-5 h-5" />
                <span>{profile.age} {t('yearsOld', 'years old')}</span>
              </div>
            )}

            {/* Privacy Notice - Hidden Fields */}
            <div className="pt-4 border-t border-border">
              <p className="text-xs text-muted-foreground text-center">
                {t('privacyNotice', 'Phone, email, and identity documents are not visible to other users')}
              </p>
            </div>
          </div>
        </Card>

        {/* Action Buttons */}
        <div className="flex gap-4 animate-fade-in" style={{ animationDelay: "0.2s" }}>
          {/* Like Button */}
          <Button
            variant={isLiked ? "secondary" : "aurora"}
            className="flex-1 h-14 text-lg gap-2"
            onClick={handleLike}
            disabled={isLiked}
          >
            <Heart className={`w-6 h-6 ${isLiked ? "fill-primary text-primary" : ""}`} />
            {isLiked ? t('liked', 'Liked') : t('like', 'Like')}
          </Button>

          {/* Chat Button */}
          <Button
            variant="auroraOutline"
            className="flex-1 h-14 text-lg gap-2"
            onClick={handleChat}
          >
            <MessageCircle className="w-6 h-6" />
            {t('chat', 'Chat')}
          </Button>
        </div>

        {/* Online Status Card */}
        <Card className={`p-4 animate-fade-in border-2 transition-colors ${
          profile.isOnline 
            ? "bg-emerald-500/5 border-emerald-500/20" 
            : "bg-muted/50 border-transparent"
        }`} style={{ animationDelay: "0.3s" }}>
          <div className="flex items-center gap-4">
            <div className={`p-3 rounded-full ${
              profile.isOnline ? "bg-emerald-500/20" : "bg-muted"
            }`}>
              <Circle className={`w-6 h-6 ${
                profile.isOnline 
                  ? "fill-emerald-500 text-emerald-500 animate-pulse" 
                  : "fill-muted-foreground/50 text-muted-foreground/50"
              }`} />
            </div>
            <div>
              <p className={`font-medium ${
                profile.isOnline ? "text-emerald-600 dark:text-emerald-400" : "text-muted-foreground"
              }`}>
                {profile.isOnline ? t('currentlyOnline', 'Currently Online') : t('currentlyOffline', 'Currently Offline')}
              </p>
              <p className="text-sm text-muted-foreground">
                {profile.isOnline 
                  ? t('availableToChatNow', 'Available to chat now')
                  : `${t('lastActive', 'Last active')} ${formatLastSeen(profile.lastSeen)}`
                }
              </p>
            </div>
          </div>
        </Card>
      </main>

      {/* Recharge Required Dialog */}
      <AlertDialog open={showRechargeDialog} onOpenChange={setShowRechargeDialog}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle className="flex items-center gap-2">
              <Wallet className="h-5 w-5 text-destructive" />
              Recharge Required
            </AlertDialogTitle>
            <AlertDialogDescription>
              {rechargeMessage}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction onClick={() => navigate('/wallet')}>
              Recharge Now
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
};

export default ProfileDetailScreen;
