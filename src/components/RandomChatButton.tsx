import { classifyError, ERROR_MESSAGES, logError } from "@/lib/errors";
import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
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
import { Badge } from "@/components/ui/badge";
import { Loader2, Shuffle, MessageCircle, UserCheck, X, Shield, Wallet } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { useToast } from "@/hooks/use-toast";
import { isIndianLanguage } from "@/data/supportedLanguages";


interface RandomChatButtonProps {
  userGender: "male" | "female";
  userLanguage: string;
  userCountry: string;
  walletBalance?: number;
  variant?: "default" | "gradient" | "hero" | "aurora" | "auroraOutline" | "auroraGhost";
  size?: "default" | "lg" | "sm";
  className?: string;
  onInsufficientBalance?: () => void;
  
  chatMode?: "paid" | "free" | "exclusive_free";
}

export const RandomChatButton = ({
  userGender,
  userLanguage,
  userCountry,
  walletBalance = 0,
  variant = "aurora",
  size = "lg",
  className = "",
  onInsufficientBalance,
  
  chatMode = "paid"
}: RandomChatButtonProps) => {
  const navigate = useNavigate();
  const { toast } = useToast();
  const [isSearching, setIsSearching] = useState(false);
  const [searchDialogOpen, setSearchDialogOpen] = useState(false);
  const [showRechargeDialog, setShowRechargeDialog] = useState(false);
  const [rechargeMessage, setRechargeMessage] = useState("");
  const [searchStatus, setSearchStatus] = useState<string>("");
  const [matchedUser, setMatchedUser] = useState<{
    userId: string;
    fullName: string;
    photoUrl: string | null;
    language: string;
    isSameLanguage: boolean;
  } | null>(null);

  const findRandomPartner = async () => {

    // Men need some wallet balance to start chat (women earn, no balance needed)
    if (userGender === "male") {
      if (walletBalance <= 0) {
        setRechargeMessage("Your wallet balance is ₹0. Recharge is mandatory to start chatting.");
        setShowRechargeDialog(true);
        onInsufficientBalance?.();
        return;
      }
    }

    setIsSearching(true);
    setSearchDialogOpen(true);
    setSearchStatus("Looking for available partners...");
    setMatchedUser(null);

    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.user) {
        toast({
          title: "Error",
          description: "You must be logged in to start a chat",
          variant: "destructive"
        });
        setSearchDialogOpen(false);
        return;
      }
      const user = session.user;

      if (userGender === "male") {
        // Men looking for women - language-agnostic, based on availability and load
        setSearchStatus("Finding an available partner for you...");
        
        const { data, error } = await supabase.functions.invoke("chat-manager", {
          body: {
            action: "get_available_indian_woman",
            man_user_id: user.id,
            preferred_language: userLanguage,
            man_country: userCountry
          }
        });

        if (error) throw error;

        if (data.success && data.woman_user_id) {
          const womanLanguage = data.profile?.primary_language || "Unknown";
          const isSameLanguage = womanLanguage.toLowerCase() === userLanguage.toLowerCase();
          
          setSearchStatus("Found a match!");
          setMatchedUser({
            userId: data.woman_user_id,
            fullName: data.profile?.full_name || "Anonymous",
            photoUrl: data.profile?.photo_url || null,
            language: womanLanguage,
            isSameLanguage,
          });
        } else {
          setSearchStatus("No partners available right now. Please try again later.");
        }
      } else {
        // Women looking for men - language-agnostic random matching
        setSearchStatus("Finding an available partner for you...");
        
        // Get online men
        const { data: onlineStatuses } = await supabase
          .from("user_status")
          .select("user_id")
          .eq("is_online", true);

        if (!onlineStatuses || onlineStatuses.length === 0) {
          setSearchStatus("No men online right now. Please try again later.");
          return;
        }

        const onlineUserIds = onlineStatuses.map(s => s.user_id);

        // Get men profiles
        const { data: menProfiles } = await supabase
          .from("profiles")
          .select("user_id, full_name, photo_url, primary_language, preferred_language")
          .in("user_id", onlineUserIds)
          .or("gender.eq.male,gender.eq.Male");

        if (!menProfiles || menProfiles.length === 0) {
          setSearchStatus("No men available right now. Please try again later.");
          return;
        }

        // Filter men based on woman's chat mode
        let qualifiedMen;
        
        if (chatMode === "paid") {
          const { data: walletData } = await supabase.rpc('get_men_with_balance', {
            p_user_ids: menProfiles.map(m => m.user_id)
          });
          const menWithBalance = walletData?.map((w: any) => w.user_id) || [];
          qualifiedMen = menProfiles.filter(m => menWithBalance.includes(m.user_id));
          
          if (qualifiedMen.length === 0) {
            setSearchStatus("No available men with wallet balance. Please try again later.");
            return;
          }
        } else {
          const { data: walletData } = await supabase.rpc('get_men_with_balance', {
            p_user_ids: menProfiles.map(m => m.user_id)
          });
          const menWithBalance = new Set(walletData?.map((w: any) => w.user_id) || []);
          const regularMen = menProfiles.filter(m => !menWithBalance.has(m.user_id));
          qualifiedMen = regularMen.length > 0 ? regularMen : menProfiles;
          
          if (qualifiedMen.length === 0) {
            setSearchStatus("No available men right now. Please try again later.");
            return;
          }
        }

        // Check active chat sessions to find idle/free men
        const { data: activeSessions } = await supabase
          .from("active_chat_sessions")
          .select("man_user_id")
          .eq("status", "active")
          .in("man_user_id", qualifiedMen.map(m => m.user_id));

        const busyMenIds = new Set(activeSessions?.map(s => s.man_user_id) || []);
        const freeMen = qualifiedMen.filter(m => !busyMenIds.has(m.user_id));
        const poolToSearch = freeMen.length > 0 ? freeMen : qualifiedMen;

        if (poolToSearch.length === 0) {
          setSearchStatus("No available men right now. Please try again later.");
          return;
        }

        // Randomly pick from all available men (language-agnostic)
        const chosenMan = poolToSearch[Math.floor(Math.random() * poolToSearch.length)];
        
        // Get language info for display only
        const { data: userLanguages } = await supabase
          .from("user_languages")
          .select("language_name")
          .eq("user_id", chosenMan.user_id)
          .limit(1);

        const manLang = userLanguages?.[0]?.language_name || chosenMan.primary_language || "Unknown";
        const isSameLanguage = manLang.toLowerCase() === userLanguage.toLowerCase();

        setSearchStatus("Found a match!");
        setMatchedUser({
          userId: chosenMan.user_id,
          fullName: chosenMan.full_name || "Anonymous",
          photoUrl: chosenMan.photo_url || null,
          language: manLang,
          isSameLanguage,
        });
      }
    } catch (error: any) {
      console.error("Error finding partner:", error);
      setSearchStatus("Something went wrong. Please try again.");
      toast({
        title: "Error",
        description: classifyError(error, "find a chat partner").message,
        variant: "destructive"
      });
    } finally {
      setIsSearching(false);
    }
  };

  const startChatWithMatch = async () => {
    if (!matchedUser) return;

    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.user) return;
      const user = session.user;

      if (userGender === "male") {
        // Man initiating chat with woman
        const { data, error } = await supabase.functions.invoke("chat-manager", {
          body: {
            action: "start_chat",
            man_user_id: user.id,
            woman_user_id: matchedUser.userId
          }
        });

        if (error) throw error;

        // Mark as self-initiated to prevent incoming chat popup
        if (data?.session_id || data?.chat_id) {
          const { markChatAsSelfInitiated } = await import("@/hooks/useIncomingChats");
          markChatAsSelfInitiated(data.session_id, data.chat_id);
        }

        if (!data.success) {
          toast({
            title: "Cannot Start Chat",
            description: data.message || "Unable to start chat session",
            variant: "destructive"
          });
          return;
        }

        // Send initial message so the incoming chat hook doesn't treat it as "incoming" for the man
        if (data.chat_id) {
          await supabase.from("chat_messages").insert({
            chat_id: data.chat_id,
            sender_id: user.id,
            receiver_id: matchedUser.userId,
            message: "👋 Hi!"
          });
        }
      } else if (userGender === "female") {
        // Woman initiating chat with man
        const { data, error } = await supabase.functions.invoke("chat-manager", {
          body: {
            action: "start_chat",
            man_user_id: matchedUser.userId,
            woman_user_id: user.id
          }
        });

        if (error) throw error;

        // Mark as self-initiated to prevent incoming chat popup
        if (data?.session_id || data?.chat_id) {
          const { markChatAsSelfInitiated } = await import("@/hooks/useIncomingChats");
          markChatAsSelfInitiated(data.session_id, data.chat_id);
        }

        if (!data.success) {
          toast({
            title: "Cannot Start Chat",
            description: data.message || "Unable to start chat session",
            variant: "destructive"
          });
          return;
        }

        // Auto-accept this session for the woman since she initiated it
        // Send an initial message so the incoming chat hook doesn't treat it as "incoming"
        if (data.chat_id) {
          await supabase.from("chat_messages").insert({
            chat_id: data.chat_id,
            sender_id: user.id,
            receiver_id: matchedUser.userId,
            message: "👋 Hi!"
          });
        }
      }

      // Close dialog and navigate back to dashboard
      // Chat windows are handled via parallel chat containers on the dashboard
      setSearchDialogOpen(false);
      // Chat started silently
      navigate(userGender === "female" ? "/women-dashboard" : "/dashboard");
    } catch (error: any) {
      console.error("Error starting chat:", error);
      toast({
        title: "Error",
        description: classifyError(error, "start the chat").message,
        variant: "destructive"
      });
    }
  };

  const cancelSearch = () => {
    setSearchDialogOpen(false);
    setIsSearching(false);
    setMatchedUser(null);
    setSearchStatus("");
  };

  return (
    <>
      <Button
        variant={variant}
        size={size}
        onClick={findRandomPartner}
        className={`gap-1 sm:gap-2 w-full ${className}`}
        disabled={isSearching}
      >
        {isSearching ? (
          <Loader2 className="h-4 w-4 sm:h-5 sm:w-5 animate-spin shrink-0" />
        ) : (
          <Shuffle className="h-4 w-4 sm:h-5 sm:w-5 shrink-0" />
        )}
        <span className="truncate">Random Chat</span>
      </Button>

      <Dialog open={searchDialogOpen} onOpenChange={setSearchDialogOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <MessageCircle className="h-5 w-5" />
              {matchedUser ? "Match Found!" : "Finding a Partner"}
            </DialogTitle>
            <DialogDescription>
              {matchedUser 
                ? "We found someone for you to chat with!"
                : `Looking for available ${userGender === "male" ? "women" : "men"}...`
              }
            </DialogDescription>
          </DialogHeader>

          <div className="py-6">
            {isSearching && !matchedUser && (
              <div className="text-center">
                <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-primary/10 flex items-center justify-center">
                  <Loader2 className="h-8 w-8 text-primary animate-spin" />
                </div>
                <p className="text-muted-foreground">{searchStatus}</p>
              </div>
            )}

            {!isSearching && !matchedUser && searchStatus && (
              <div className="text-center">
                <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-muted flex items-center justify-center">
                  <X className="h-8 w-8 text-muted-foreground" />
                </div>
                <p className="text-muted-foreground">{searchStatus}</p>
                <Button 
                  variant="auroraOutline" 
                  className="mt-4"
                  onClick={findRandomPartner}
                >
                  Try Again
                </Button>
              </div>
            )}

            {matchedUser && (
              <div className="text-center">
                <div className="relative w-20 h-20 mx-auto mb-4">
                  {matchedUser.photoUrl ? (
                    <img 
                      src={matchedUser.photoUrl} 
                      alt={matchedUser.fullName}
                      className="w-20 h-20 rounded-full object-cover border-4 border-primary/20"
                    />
                  ) : (
                    <div className="w-20 h-20 rounded-full bg-gradient-to-br from-primary to-accent flex items-center justify-center text-primary-foreground text-2xl font-bold">
                      {matchedUser.fullName.charAt(0)}
                    </div>
                  )}
                  <div className="absolute -bottom-1 -right-1 w-6 h-6 bg-online rounded-full border-2 border-background flex items-center justify-center">
                    <UserCheck className="h-3 w-3 text-online-foreground" />
                  </div>
                </div>
                <h3 className="text-lg font-semibold">{matchedUser.fullName}</h3>
                <div className="flex items-center justify-center gap-2 mb-4">
                  <p className="text-sm text-muted-foreground">
                    Speaks {matchedUser.language}
                  </p>
                  {matchedUser.isSameLanguage ? (
                    <Badge variant="successOutline" className="text-xs">
                      Same language
                    </Badge>
                  ) : (
                    <Badge variant="outline" className="text-xs">
                      Different language
                    </Badge>
                  )}
                </div>
                <div className="flex gap-3 justify-center">
                  <Button variant="auroraOutline" onClick={cancelSearch}>
                    Cancel
                  </Button>
                  <Button variant="aurora" onClick={startChatWithMatch}>
                    <MessageCircle className="h-4 w-4 mr-2" />
                    Start Chat
                  </Button>
                </div>
              </div>
            )}
          </div>
        </DialogContent>
      </Dialog>

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
    </>
  );
};
