import { useState, useEffect, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import MeowLogo from "@/components/MeowLogo";
import { useToast } from "@/hooks/use-toast";
import { 
  PartyPopper, 
  LayoutDashboard, 
  Share2, 
  CheckCircle2,
  Sparkles,
  Copy,
  Check
} from "lucide-react";
import { supabase } from "@/integrations/supabase/client";

interface ConfettiPiece {
  id: number;
  x: number;
  delay: number;
  duration: number;
  color: string;
  size: number;
}

const RegistrationCompleteScreen = () => {
  const navigate = useNavigate();
  const { toast } = useToast();
  const [showConfetti, setShowConfetti] = useState(false);
  const [confettiPieces, setConfettiPieces] = useState<ConfettiPiece[]>([]);
  const [isCopied, setIsCopied] = useState(false);
  const [isVisible, setIsVisible] = useState(false);

  const colors = [
    "bg-primary",
    "bg-accent",
    "bg-warning",
    "bg-success",
    "bg-secondary",
    "bg-info",
    "bg-primary",
  ];

  const generateConfetti = useCallback(() => {
    const pieces: ConfettiPiece[] = [];
    for (let i = 0; i < 50; i++) {
      pieces.push({
        id: i,
        x: Math.random() * 100,
        delay: Math.random() * 0.5,
        duration: 2 + Math.random() * 2,
        color: colors[Math.floor(Math.random() * colors.length)],
        size: 6 + Math.random() * 8,
      });
    }
    setConfettiPieces(pieces);
  }, []);

  useEffect(() => {
    // Start animations with delay for dramatic effect
    const timer1 = setTimeout(() => setIsVisible(true), 100);
    const timer2 = setTimeout(() => {
      setShowConfetti(true);
      generateConfetti();
    }, 300);

    // Finalize registration
    finalizeRegistration();

    return () => {
      clearTimeout(timer1);
      clearTimeout(timer2);
    };
  }, [generateConfetti]);

  const [userGender, setUserGender] = useState<string | null>(null);
  const [approvalStatus, setApprovalStatus] = useState<string | null>(null);
  const [isFinalized, setIsFinalized] = useState(false);

  const finalizeRegistration = async () => {
    try {
      const { data: { session } } = await supabase.auth.getSession();
      
      if (!session?.user) return;
      const user = session.user;

      // Fetch profile to get gender and current verification status
      const { data: profile } = await supabase
        .from("profiles")
        .select("gender, approval_status, is_verified")
        .eq("user_id", user.id)
        .single();

      setUserGender(profile?.gender || null);
      setApprovalStatus(profile?.approval_status || "pending");

      // Only mark registration complete — preserve existing verification_status
      // (is_verified is set by AI verification in AIProcessingScreen)
      await supabase
        .from("profiles")
        .update({
          updated_at: new Date().toISOString(),
        })
        .eq("user_id", user.id);

      // Registration finalized successfully
      setIsFinalized(true);
    } catch (error) {
      // Error finalizing registration - still allow navigation with fallback
      setIsFinalized(true);
    }
  };

  const handleGoToDashboard = () => {
    if (!isFinalized) return;
    toast({
      title: "Welcome!",
      description: "Redirecting to your dashboard...",
    });
    
    // Women go to approval pending if not approved, men go to dashboard
    if (userGender === "female" && approvalStatus !== "approved") {
      navigate("/approval-pending");
    } else if (userGender === "female") {
      navigate("/women-dashboard");
    } else {
      navigate("/dashboard");
    }
  };

  const handleShareApp = async () => {
    const shareData = {
      title: "Meow - Connect & Match",
      text: "Join me on Meow! The best way to make meaningful connections.",
      url: window.location.origin,
    };

    try {
      if (navigator.share) {
        await navigator.share(shareData);
        toast({
          title: "Thanks for sharing!",
          description: "You're helping others discover Meow.",
        });
      } else {
        // Fallback: copy link to clipboard
        await navigator.clipboard.writeText(window.location.origin);
        setIsCopied(true);
        toast({
          title: "Link copied!",
          description: "Share the link with your friends.",
        });
        setTimeout(() => setIsCopied(false), 3000);
      }
    } catch (error) {
      console.error("Error sharing:", error);
      toast.error("Sharing failed", { description: "Unable to share via your device. Please copy the link manually." });
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-background to-primary/5 flex flex-col relative overflow-hidden">
      {/* Confetti Layer */}
      {showConfetti && (
        <div className="fixed inset-0 pointer-events-none z-50 overflow-hidden">
          {confettiPieces.map((piece) => (
            <div
              key={piece.id}
              className={`absolute ${piece.color} rounded-sm animate-confetti-fall`}
              style={{
                left: `${piece.x}%`,
                width: `${piece.size}px`,
                height: `${piece.size}px`,
                animationDelay: `${piece.delay}s`,
                animationDuration: `${piece.duration}s`,
                transform: `rotate(${Math.random() * 360}deg)`,
              }}
            />
          ))}
        </div>
      )}

      {/* Header */}
      <header className="p-6 flex justify-center items-center">
        <MeowLogo />
      </header>

      {/* Main Content */}
      <main className="flex-1 flex items-center justify-center p-6">
        <Card 
          className={`w-full max-w-lg p-8 space-y-8 bg-card/80 backdrop-blur-sm border-border/50 shadow-xl transition-all duration-700 ${
            isVisible ? "opacity-100 translate-y-0 scale-100" : "opacity-0 translate-y-8 scale-95"
          }`}
        >
          {/* Success Icon */}
          <div className="text-center">
            <div className="relative inline-flex items-center justify-center">
              <div className="absolute inset-0 animate-ping bg-primary/20 rounded-full" />
              <div className="relative inline-flex items-center justify-center w-24 h-24 rounded-full bg-gradient-to-br from-primary to-primary/60 text-primary-foreground shadow-lg animate-bounce-in">
                <PartyPopper className="w-12 h-12" />
              </div>
            </div>
          </div>

          {/* Success Message */}
          <div 
            className={`text-center space-y-4 transition-all duration-500 delay-200 ${
              isVisible ? "opacity-100 translate-y-0" : "opacity-0 translate-y-4"
            }`}
          >
            <h1 className="text-3xl font-bold text-foreground">
              You're All Set! 🎉
            </h1>
            <p className="text-muted-foreground text-lg leading-relaxed">
              Congratulations! Your registration is complete. Start exploring and make meaningful connections.
            </p>
          </div>

          {/* Success Checklist */}
          <div 
            className={`space-y-3 transition-all duration-500 delay-300 ${
              isVisible ? "opacity-100 translate-y-0" : "opacity-0 translate-y-4"
            }`}
          >
            {[
              "Profile created successfully",
              "Photos uploaded",
              "Account setup complete",
              "Ready to connect",
            ].map((item, index) => (
              <div
                key={index}
                className="flex items-center gap-3 p-3 rounded-xl bg-primary/5 border border-primary/10"
                style={{ animationDelay: `${0.4 + index * 0.1}s` }}
              >
                <CheckCircle2 className="w-5 h-5 text-primary shrink-0" />
                <span className="text-foreground font-medium">{item}</span>
              </div>
            ))}
          </div>

          {/* Action Buttons */}
          <div 
            className={`space-y-3 transition-all duration-500 delay-500 ${
              isVisible ? "opacity-100 translate-y-0" : "opacity-0 translate-y-4"
            }`}
          >
            <Button
              onClick={handleGoToDashboard}
              disabled={!isFinalized}
              className="w-full h-14 text-lg font-medium animate-bounce-subtle"
              variant="aurora"
            >
              <LayoutDashboard className="w-5 h-5 mr-2" />
              Go to Dashboard
              <Sparkles className="w-5 h-5 ml-2" />
            </Button>

            <Button
              variant="auroraOutline"
              onClick={handleShareApp}
              className="w-full h-12 text-base transition-all hover:bg-primary/5"
            >
              {isCopied ? (
                <>
                  <Check className="w-5 h-5 mr-2 text-primary" />
                  Link Copied!
                </>
              ) : (
                <>
                  <Share2 className="w-5 h-5 mr-2" />
                  Share with Friends
                </>
              )}
            </Button>
          </div>

          {/* Welcome Note */}
          <p 
            className={`text-center text-sm text-muted-foreground transition-all duration-500 delay-700 ${
              isVisible ? "opacity-100" : "opacity-0"
            }`}
          >
            Welcome to the community! 💜
          </p>
        </Card>
      </main>

      {/* Background Decorations */}
      <div className="fixed inset-0 pointer-events-none overflow-hidden -z-10">
        <div className="absolute top-1/4 -left-20 w-64 h-64 rounded-full bg-gradient-to-br from-primary to-primary/60 opacity-10 blur-3xl animate-pulse" />
        <div className="absolute bottom-1/4 -right-20 w-80 h-80 rounded-full bg-gradient-to-br from-accent to-warning opacity-10 blur-3xl animate-pulse" />
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-96 h-96 rounded-full bg-gradient-to-br from-secondary to-primary opacity-5 blur-3xl" />
      </div>
    </div>
  );
};

export default RegistrationCompleteScreen;