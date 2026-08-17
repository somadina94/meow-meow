import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card } from "@/components/ui/card";
import MeowLogo from "@/components/MeowLogo";
import AuroraBackground from "@/components/AuroraBackground";
import { toast } from "@/hooks/use-toast";
import { classifyError } from "@/lib/errors";
import { supabase } from "@/integrations/supabase/client";
import { Mail, ArrowLeft, ArrowRight, Loader2, ShieldCheck, Phone } from "lucide-react";
import { cn } from "@/lib/utils";
import PhoneInputWithCode from "@/components/PhoneInputWithCode";

const ForgotPasswordScreen = () => {
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [emailError, setEmailError] = useState<string | undefined>();
  const [phoneError, setPhoneError] = useState<string | undefined>();

  const validateEmail = (value: string) => {
    if (!value.trim()) return "Email is required";
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(value)) return "Please enter a valid email";
    return undefined;
  };

  const validatePhone = (value: string) => {
    if (!value.trim()) return "Phone number is required";
    // Require international format: optional +, starts with 1-9, 7-14 more digits
    const phoneRegex = /^\+?[1-9]\d{6,14}$/;
    const normalized = value.replace(/[\s\-()]/g, '');
    if (!phoneRegex.test(normalized)) return "Please enter a valid phone number (e.g. +91XXXXXXXXXX)";
    return undefined;
  };

  // Debounced live (AJAX-style) format validation while typing
  useEffect(() => {
    if (!email) { setEmailError(undefined); return; }
    const h = setTimeout(() => setEmailError(validateEmail(email)), 500);
    return () => clearTimeout(h);
  }, [email]);

  useEffect(() => {
    if (!phone) { setPhoneError(undefined); return; }
    const h = setTimeout(() => setPhoneError(validatePhone(phone)), 500);
    return () => clearTimeout(h);
  }, [phone]);


  const handleVerifyAccount = async () => {
    const emailErr = validateEmail(email);
    const phoneErr = validatePhone(phone);
    
    setEmailError(emailErr);
    setPhoneError(phoneErr);

    if (emailErr || phoneErr) {
      toast({
        title: "Please fix the errors",
        description: [emailErr, phoneErr].filter(Boolean).join(". "),
        variant: "destructive",
      });
      return;
    }

    setIsLoading(true);

    try {
      // Verify email + phone match an existing account
      const { data, error } = await supabase.functions.invoke(
        "reset-password",
        {
          body: {
            action: "verify-account",
            email: email.trim().toLowerCase(),
            phone: phone.trim(),
          },
        }
      );

      if (error) {
        throw error;
      }

      if (!data?.verified || !data?.token) {
        toast({
          title: "Account not found",
          description: data?.error || "No account found with this email and phone combination. Please check and try again.",
          variant: "destructive",
        });
        setIsLoading(false);
        return;
      }

      // Navigate to password reset page with secure token (not userId)
      navigate(`/reset-password?token=${data.token}`);
      
      toast({
        title: "Account verified!",
        description: "You can now set a new password. The link expires in 10 minutes.",
      });
    } catch (error: any) {
      toast({
        title: "Verification failed",
        description: classifyError(error, "send the reset link").message,
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex flex-col relative bg-background">
      <AuroraBackground />
      
      {/* Header */}
      <header className="px-6 pt-8 pb-4 relative z-10">
        <div className="flex items-center gap-4">
          <Button
            variant="auroraGhost"
            size="icon"
            onClick={() => navigate("/")}
            className="shrink-0"
          >
            <ArrowLeft className="w-5 h-5" />
          </Button>
          <div className="flex-1 text-center pr-10">
            <MeowLogo size="sm" className="mx-auto" />
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="flex-1 flex flex-col items-center justify-center px-6 pb-8 relative z-10">
        <Card className="w-full max-w-md p-6 bg-card/70 backdrop-blur-xl border border-primary/20 shadow-[0_0_40px_hsl(174_72%_50%/0.1)] animate-slide-up">
          <div className="space-y-6">
            {/* Title */}
            <div className="text-center space-y-2">
              <div className="w-16 h-16 mx-auto bg-primary/10 rounded-2xl flex items-center justify-center mb-4">
                <ShieldCheck className="w-8 h-8 text-primary" />
              </div>
              <h1 className="text-2xl font-bold text-foreground font-display">
                Reset Password
              </h1>
              <p className="text-muted-foreground text-sm">
                Enter your registered email and phone number to verify your account
              </p>
            </div>

            {/* Email Input */}
            <div className="space-y-2">
              <Label htmlFor="email" className="text-sm font-semibold flex items-center gap-2">
                <Mail className="w-4 h-4 text-primary" />
                Email Address
              </Label>
              <Input
                id="email"
                type="email"
                placeholder="Enter your email"
                value={email}
                onChange={(e) => {
                  setEmail(e.target.value);
                  setEmailError(undefined);
                }}
                className={cn(
                  "h-12 rounded-xl border-2 transition-all bg-background/50 backdrop-blur-sm",
                  emailError ? "border-destructive" : "border-input focus:border-primary"
                )}
              />
              {emailError && (
                <p className="text-xs text-destructive">{emailError}</p>
              )}
            </div>

            {/* Phone Input with Country Code */}
            <div className="space-y-2">
              <Label htmlFor="phone" className="text-sm font-semibold flex items-center gap-2">
                <Phone className="w-4 h-4 text-primary" />
                Phone Number
              </Label>
              <PhoneInputWithCode
                value={phone}
                onChange={(value) => {
                  setPhone(value);
                  setPhoneError(undefined);
                }}
                error={!!phoneError}
                placeholder="Enter your phone number"
                defaultCountryCode="IN"
              />
              {phoneError && (
                <p className="text-xs text-destructive">{phoneError}</p>
              )}
            </div>

            {/* Verify Button */}
            <Button
              variant="aurora"
              size="xl"
              className="w-full group"
              onClick={handleVerifyAccount}
              disabled={isLoading}
            >
              {isLoading ? (
                <>
                  <Loader2 className="w-5 h-5 animate-spin mr-2" />
                  Verifying...
                </>
              ) : (
                <>
                  Verify & Continue
                  <ArrowRight className="w-5 h-5 transition-transform group-hover:translate-x-1" />
                </>
              )}
            </Button>

            {/* Security Note */}
            <div className="p-3 bg-amber-500/10 rounded-lg border border-amber-500/20">
              <p className="text-xs text-amber-600 dark:text-amber-400 text-center">
                🔒 Both email and phone must match your registered account
              </p>
            </div>

            {/* Back to Login */}
            <p className="text-center text-sm text-muted-foreground">
              Remember your password?{" "}
              <button
                onClick={() => navigate("/")}
                className="text-primary hover:text-primary/80 transition-colors font-medium"
              >
                Back to Login
              </button>
            </p>
          </div>
        </Card>
      </main>
    </div>
  );
};

export default ForgotPasswordScreen;
