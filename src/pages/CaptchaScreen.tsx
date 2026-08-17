import { useState, useEffect, useCallback, useRef, Suspense } from "react";
import { useNavigate } from "react-router-dom";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Loader2, ShieldCheck, RefreshCw, ArrowRight } from "lucide-react";
import MeowLogo from "@/components/MeowLogo";
import AuroraBackground from "@/components/AuroraBackground";
import { toast } from "@/hooks/use-toast";
import { cn } from "@/lib/utils";

import { supabase } from "@/integrations/supabase/client";


type Op = "+" | "-";

const generateChallenge = () => {
  const op: Op = Math.random() < 0.5 ? "+" : "-";
  let a = Math.floor(Math.random() * 9) + 1; // 1..9
  let b = Math.floor(Math.random() * 9) + 1;
  if (op === "-" && b > a) [a, b] = [b, a]; // keep result non-negative
  const answer = op === "+" ? a + b : a - b;
  return { a, b, op, answer };
};

const MAX_ATTEMPTS = 5;

const CaptchaScreen = () => {
  const navigate = useNavigate();
  const t = (key: string, def: string) => def;
  const [challenge, setChallenge] = useState(generateChallenge);
  const [value, setValue] = useState("");
  const [error, setError] = useState<string | undefined>();
  const [attempts, setAttempts] = useState(0);
  const [isVerifying, setIsVerifying] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    // Must come from a login flow
    const dest = sessionStorage.getItem("postCaptchaRedirect");
    if (!dest) {
      navigate("/", { replace: true });
      return;
    }
    inputRef.current?.focus();
  }, [navigate]);

  const refresh = useCallback(() => {
    setChallenge(generateChallenge());
    setValue("");
    setError(undefined);
    setTimeout(() => inputRef.current?.focus(), 0);
  }, []);

  const handleVerify = useCallback(async () => {
    if (isVerifying) return;
    const trimmed = value.trim();
    if (!trimmed) {
      setError("Please enter your answer.");
      return;
    }
    const parsed = Number(trimmed);
    if (!Number.isFinite(parsed) || !Number.isInteger(parsed)) {
      setError("Please enter a valid number.");
      return;
    }
    setIsVerifying(true);
    if (parsed === challenge.answer) {
      const dest = sessionStorage.getItem("postCaptchaRedirect") || "/dashboard";
      sessionStorage.removeItem("postCaptchaRedirect");
      sessionStorage.setItem("captchaVerifiedAt", String(Date.now()));
      // Persist per-user so a page refresh / transient auth flap doesn't
      // re-prompt. 24h TTL is enforced by ProtectedRoute.
      try {
        const { data } = await supabase.auth.getUser();
        const uid = data?.user?.id;
        if (uid) localStorage.setItem(`captchaVerifiedFor:${uid}`, String(Date.now()));
      } catch {}
      toast({ title: "Verified", description: "Redirecting to your dashboard..." });
      navigate(dest, { replace: true });

    } else {
      const next = attempts + 1;
      setAttempts(next);
      setIsVerifying(false);
      if (next >= MAX_ATTEMPTS) {
        toast({
          title: "Too many incorrect attempts",
          description: "Please log in again.",
          variant: "destructive",
        });
        sessionStorage.removeItem("postCaptchaRedirect");
        navigate("/", { replace: true });
        return;
      }
      setError("Incorrect answer. Please try again.");
      refresh();
    }
  }, [value, challenge.answer, attempts, isVerifying, navigate, refresh]);

  const onKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === "Enter") handleVerify();
  };

  return (
    <div className="min-h-screen flex flex-col relative bg-background overflow-y-auto">
      <Suspense fallback={<div className="fixed inset-0 -z-10 bg-gradient-to-br from-background via-background to-secondary/30" />}>
        <AuroraBackground />
      </Suspense>

      {/* Header — matches AuthScreen */}
      <header className="px-6 pt-4 pb-2 sm:pt-8 sm:pb-4 relative z-10">
        <div className="text-center">
          <Suspense fallback={<div className="w-16 h-16 sm:w-20 sm:h-20 mx-auto mb-2 sm:mb-4 bg-primary/20 rounded-full animate-pulse" />}>
            <MeowLogo size="lg" className="mx-auto mb-2 sm:mb-4" />
          </Suspense>
          <h1 className="font-display text-2xl sm:text-4xl font-bold text-primary mb-1 sm:mb-2 drop-shadow-sm">
            {t("app.name", "MEOW MEOW FRND APP")}
          </h1>
          <p className="text-primary/80 text-sm sm:text-lg">
            {t("app.tagline", "Real People. Real Connections")}
          </p>
        </div>
      </header>

      <main className="flex-1 flex flex-col items-center justify-start sm:justify-center px-4 sm:px-6 pb-6 sm:pb-8 relative z-10">
        <Card className="w-full max-w-md p-4 sm:p-6 bg-card/90 backdrop-blur-xl border border-primary/20 shadow-lg animate-slide-up">
          <div className="text-center mb-4">
            <div className="inline-flex items-center justify-center w-12 h-12 rounded-full bg-primary/10 mb-2">
              <ShieldCheck className="w-6 h-6 text-primary" />
            </div>
            <h2 className="font-display text-xl font-semibold text-foreground">
              Quick Security Check
            </h2>
            <p className="text-sm text-muted-foreground mt-1">
              Solve this simple math to confirm you're human.
            </p>
          </div>

          <div className="space-y-4">
            <div className="flex items-center justify-center gap-3 p-4 rounded-xl bg-primary/5 border border-primary/20">
              <span className="font-display text-3xl sm:text-4xl font-bold text-primary tabular-nums">
                {challenge.a} {challenge.op} {challenge.b} = ?
              </span>
              <button
                type="button"
                onClick={refresh}
                aria-label="Refresh challenge"
                className="ml-2 p-2 rounded-full hover:bg-primary/10 text-primary transition-colors"
              >
                <RefreshCw className="w-4 h-4" />
              </button>
            </div>

            <div className="space-y-2">
              <Label htmlFor="captcha-answer" className="text-sm font-semibold">
                Your Answer
              </Label>
              <Input
                ref={inputRef}
                id="captcha-answer"
                type="number"
                inputMode="numeric"
                autoComplete="off"
                placeholder="Enter the result"
                value={value}
                onChange={(e) => {
                  setValue(e.target.value);
                  if (error) setError(undefined);
                }}
                onKeyDown={onKeyDown}
                className={cn(
                  "h-12 rounded-xl border-2 transition-all bg-background/50 backdrop-blur-sm text-center text-lg tabular-nums",
                  error ? "border-destructive" : "border-input focus:border-primary"
                )}
              />
              {error && (
                <p className="text-xs text-destructive text-center">{error}</p>
              )}
              {attempts > 0 && attempts < MAX_ATTEMPTS && !error && (
                <p className="text-xs text-muted-foreground text-center">
                  {MAX_ATTEMPTS - attempts} attempts remaining
                </p>
              )}
            </div>

            <Button
              variant="aurora"
              size="lg"
              className="w-full group"
              onClick={handleVerify}
              disabled={isVerifying}
            >
              {isVerifying ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin mr-2" />
                  Verifying...
                </>
              ) : (
                <>
                  Verify & Continue
                  <ArrowRight className="w-4 h-4 ml-2 group-hover:translate-x-1 transition-transform" />
                </>
              )}
            </Button>

            <p className="text-[11px] text-center text-muted-foreground">
              This step helps block bots and automated logins.
            </p>
          </div>
        </Card>
      </main>
    </div>
  );
};

export default CaptchaScreen;
