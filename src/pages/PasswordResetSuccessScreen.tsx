import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import MeowLogo from "@/components/MeowLogo";
import AuroraBackground from "@/components/AuroraBackground";
import { CheckCircle2, ArrowRight } from "lucide-react";

const PasswordResetSuccessScreen = () => {
  const navigate = useNavigate();

  return (
    <div className="min-h-screen flex flex-col relative">
      <AuroraBackground />
      
      <main className="flex-1 flex flex-col items-center justify-center px-6 pb-8 relative z-10">
        <Card className="w-full max-w-md p-6 bg-card/70 backdrop-blur-xl border border-primary/20 shadow-[0_0_40px_hsl(174_72%_50%/0.1)] animate-slide-up">
          <CardContent className="flex flex-col items-center text-center space-y-6 p-0">
            {/* Logo */}
            <MeowLogo size="lg" className="mb-2" />
            
            {/* Success Icon */}
            <div className="w-20 h-20 rounded-full bg-accent/10 flex items-center justify-center">
              <CheckCircle2 className="w-10 h-10 text-accent" />
            </div>
            
            {/* Title */}
            <div className="space-y-2">
              <h1 className="text-2xl font-bold text-foreground font-display">
                Password Reset Complete!
              </h1>
              <p className="text-muted-foreground">
                Your password has been successfully updated. You can now log in with your new password.
              </p>
            </div>

            {/* Success Message */}
            <div className="w-full p-4 bg-accent/10 rounded-xl border border-accent/20">
              <p className="text-sm text-accent font-medium">
                ✓ Password changed successfully
              </p>
            </div>

            {/* Login Button */}
            <Button
              onClick={() => navigate("/")}
              variant="aurora"
              size="xl"
              className="w-full group"
            >
              Go to Login
              <ArrowRight className="w-5 h-5 transition-transform group-hover:translate-x-1" />
            </Button>

          </CardContent>
        </Card>
      </main>
    </div>
  );
};

export default PasswordResetSuccessScreen;
