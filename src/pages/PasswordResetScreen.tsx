import { useState, useEffect, useRef } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { ArrowLeft, Lock, Eye, EyeOff, Check, X, Loader2, AlertCircle, ChevronUp, ChevronDown } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { classifyError } from "@/lib/errors";
import { supabase } from "@/integrations/supabase/client";
import MeowLogo from "@/components/MeowLogo";
import AuroraBackground from "@/components/AuroraBackground";

const PasswordResetScreen = () => {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const { toast } = useToast();
  const scrollRef = useRef<HTMLElement | null>(null);
  
  const [resetToken, setResetToken] = useState<string | null>(null);
  const [userId, setUserId] = useState<string | null>(null);
  const [tokenValid, setTokenValid] = useState<boolean | null>(null);
  const [tokenError, setTokenError] = useState<string | null>(null);
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [isVerifying, setIsVerifying] = useState(true);

  const hasMinLength = password.length >= 8;
  const hasUppercase = /[A-Z]/.test(password);
  const hasLowercase = /[a-z]/.test(password);
  const hasNumber = /[0-9]/.test(password);
  const hasSymbol = /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password);
  const passwordsMatch = password === confirmPassword && confirmPassword.length > 0;
  const isPasswordValid = hasMinLength && hasUppercase && hasLowercase && hasNumber && hasSymbol && passwordsMatch;

  useEffect(() => {
    const token = searchParams.get("token");
    if (!token) {
      setTokenValid(false);
      setTokenError("Invalid access. Please use the forgot password flow.");
      setIsVerifying(false);
      return;
    }
    setResetToken(token);

    // Verify token with backend
    const verifyToken = async () => {
      try {
        const { data, error } = await supabase.functions.invoke("reset-password", {
          body: { action: "verify-token", token },
        });
        if (error) throw error;
        if (data?.valid) {
          // userId is no longer needed client-side — token is sufficient
          setTokenValid(true);
        } else {
          setTokenValid(false);
          setTokenError(data?.error || "Invalid or expired reset token.");
        }
      } catch (err: any) {
        setTokenValid(false);
        setTokenError("Failed to verify reset token. Please try again.");
      } finally {
        setIsVerifying(false);
      }
    };
    verifyToken();
  }, [searchParams]);

  const handleResetPassword = async () => {
    if (!isPasswordValid || !resetToken) return;

    setIsLoading(true);
    try {
      const { data, error } = await supabase.functions.invoke("reset-password", {
        body: { action: "direct-reset", token: resetToken, newPassword: password },
      });
      if (error) throw error;
      if (data?.success) {
        toast({ title: "Password Reset Successful", description: "Your password has been updated. Redirecting to login..." });
        navigate("/password-reset-success");
      } else {
        throw new Error(data?.error || "Failed to reset password");
      }
    } catch (error: any) {
      toast({ title: "Error", description: classifyError(error, "reset your password").message, variant: "destructive" });
    } finally {
      setIsLoading(false);
    }
  };

  const scrollForm = (direction: "up" | "down") => {
    scrollRef.current?.scrollBy({ top: direction === "down" ? 180 : -180, behavior: "smooth" });
  };

  const PasswordRequirement = ({ met, text }: { met: boolean; text: string }) => (
    <div className="flex items-center gap-2 text-sm">
      {met ? <Check className="w-4 h-4 text-accent" /> : <X className="w-4 h-4 text-muted-foreground" />}
      <span className={met ? "text-accent" : "text-muted-foreground"}>{text}</span>
    </div>
  );

  // Loading state while verifying token
  if (isVerifying) {
    return (
      <div className="min-h-screen flex items-center justify-center relative">
        <AuroraBackground />
        <Card className="w-full max-w-md border-border/50 shadow-xl bg-card/70 backdrop-blur-xl">
          <CardContent className="flex flex-col items-center justify-center py-16">
            <Loader2 className="w-12 h-12 text-primary animate-spin mb-4" />
            <p className="text-muted-foreground">Verifying reset token...</p>
          </CardContent>
        </Card>
      </div>
    );
  }

  // Invalid/expired token
  if (!tokenValid) {
    return (
      <div className="min-h-screen flex items-center justify-center relative">
        <AuroraBackground />
        <Card className="w-full max-w-md border-border/50 shadow-xl bg-card/70 backdrop-blur-xl">
          <CardContent className="flex flex-col items-center justify-center py-16 space-y-4">
            <AlertCircle className="w-12 h-12 text-destructive" />
            <p className="text-muted-foreground text-center">{tokenError}</p>
            <Button variant="aurora" onClick={() => navigate("/forgot-password")}>
              Start Over
            </Button>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="h-screen flex flex-col relative overflow-hidden">
      <AuroraBackground />
      <header className="px-6 pt-3 pb-1 relative z-10">
        <div className="flex items-center gap-4">
          <Button variant="auroraGhost" size="icon" onClick={() => navigate("/forgot-password")} className="shrink-0">
            <ArrowLeft className="w-5 h-5" />
          </Button>
          <div className="flex-1 text-center pr-10">
            <MeowLogo size="sm" className="mx-auto" />
          </div>
        </div>
      </header>

      <main ref={scrollRef} className="flex-1 min-h-0 overflow-y-auto overscroll-contain flex flex-col items-center justify-start px-4 pb-16 relative z-10 scrollbar-thin scrollbar-thumb-primary/50 scrollbar-track-transparent">
        <Card className="w-full max-w-md p-4 bg-card/70 backdrop-blur-xl border border-primary/20 shadow-[0_0_40px_hsl(var(--primary)/0.1)] animate-slide-up">
          <CardHeader className="space-y-1 text-center p-0 pb-2">
            <div className="w-10 h-10 mx-auto bg-primary/10 rounded-xl flex items-center justify-center mb-1">
              <Lock className="w-5 h-5 text-primary" />
            </div>
            <h1 className="text-lg font-bold text-foreground font-display">Create New Password</h1>
            <p className="text-muted-foreground text-sm">Enter your new password below</p>
          </CardHeader>

          <CardContent className="space-y-2 p-0">
            <div className="space-y-1">
              <Label htmlFor="password" className="flex items-center gap-2 text-sm font-semibold">
                <Lock className="w-4 h-4 text-primary" /> New Password
              </Label>
              <div className="relative">
                <Input id="password" type={showPassword ? "text" : "password"} placeholder="Enter new password" value={password} onChange={(e) => setPassword(e.target.value)} className="pr-10 h-11 rounded-xl border-2 bg-background/50" />
                <Button type="button" variant="ghost" size="icon" className="absolute right-0 top-0 h-full px-3 hover:bg-transparent" onClick={() => setShowPassword(!showPassword)}>
                  {showPassword ? <EyeOff className="h-4 w-4 text-muted-foreground" /> : <Eye className="h-4 w-4 text-muted-foreground" />}
                </Button>
              </div>
            </div>

            <div className="space-y-0.5 p-2 rounded-xl bg-muted/30 border border-border/50">
              <p className="text-xs font-medium text-muted-foreground mb-1">Password Requirements:</p>
              <PasswordRequirement met={hasMinLength} text="At least 8 characters" />
              <PasswordRequirement met={hasUppercase} text="One uppercase letter" />
              <PasswordRequirement met={hasLowercase} text="One lowercase letter" />
              <PasswordRequirement met={hasNumber} text="One number" />
              <PasswordRequirement met={hasSymbol} text="One special character (!@#$%...)" />
            </div>

            <div className="space-y-1">
              <Label htmlFor="confirmPassword" className="flex items-center gap-2 text-sm font-semibold">
                <Lock className="w-4 h-4 text-primary" /> Confirm Password
              </Label>
              <div className="relative">
                <Input id="confirmPassword" type={showConfirmPassword ? "text" : "password"} placeholder="Confirm new password" value={confirmPassword} onChange={(e) => setConfirmPassword(e.target.value)} className={`pr-10 h-11 rounded-xl border-2 bg-background/50 ${confirmPassword && !passwordsMatch ? "border-destructive" : ""}`} />
                <Button type="button" variant="ghost" size="icon" className="absolute right-0 top-0 h-full px-3 hover:bg-transparent" onClick={() => setShowConfirmPassword(!showConfirmPassword)}>
                  {showConfirmPassword ? <EyeOff className="h-4 w-4 text-muted-foreground" /> : <Eye className="h-4 w-4 text-muted-foreground" />}
                </Button>
              </div>
              {confirmPassword && !passwordsMatch && (
                <p className="text-sm text-destructive flex items-center gap-1"><X className="w-4 h-4" /> Passwords do not match</p>
              )}
              {passwordsMatch && (
                <p className="text-sm text-accent flex items-center gap-1"><Check className="w-4 h-4" /> Passwords match</p>
              )}
            </div>

            <div className="p-2 bg-amber-500/10 rounded-lg border border-amber-500/20">
              <p className="text-xs text-amber-600 dark:text-amber-400 text-center">
                ⏱️ This reset link expires in 10 minutes
              </p>
            </div>

            <Button onClick={handleResetPassword} disabled={!isPasswordValid || isLoading} variant="aurora" size="lg" className="w-full">
              {isLoading ? (<><Loader2 className="w-5 h-5 animate-spin mr-2" /> Resetting Password...</>) : "Reset Password"}
            </Button>
          </CardContent>
        </Card>
      </main>
      <div className="absolute right-3 bottom-4 z-20 flex flex-col gap-2">
        <Button type="button" variant="auroraGhost" size="icon" aria-label="Scroll up" onClick={() => scrollForm("up")} className="h-9 w-9 rounded-full bg-card/80 backdrop-blur-md shadow-lg">
          <ChevronUp className="h-4 w-4" />
        </Button>
        <Button type="button" variant="auroraGhost" size="icon" aria-label="Scroll down" onClick={() => scrollForm("down")} className="h-9 w-9 rounded-full bg-card/80 backdrop-blur-md shadow-lg">
          <ChevronDown className="h-4 w-4" />
        </Button>
      </div>
    </div>
  );
};

export default PasswordResetScreen;
