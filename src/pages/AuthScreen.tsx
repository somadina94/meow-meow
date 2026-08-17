import { useState, useCallback, useEffect, useRef, memo, lazy, Suspense } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card } from "@/components/ui/card";
import { Eye, EyeOff, Mail, Lock, ArrowRight, Loader2, ChevronUp, ChevronDown } from "lucide-react";
import { cn } from "@/lib/utils";
import { useAuthReady } from "@/hooks/useAuthReady";
import { classifyError } from "@/lib/errors";

// Lazy load non-critical components
const MeowLogo = lazy(() => import("@/components/MeowLogo"));
const AuroraBackground = lazy(() => import("@/components/AuroraBackground"));

// Inline translations for instant render - no async loading needed
const translations: Record<string, string> = {
  'app.name': 'MEOW MEOW FRND APP',
  'app.tagline': 'Real People. Real Connections',
  'auth.email': 'Email',
  'auth.password': 'Password',
  'auth.login': 'Login',
  'auth.signup': 'Sign Up',
  'auth.forgotPassword': 'Forgot Password?',
  'auth.noAccount': 'No account?',
  'auth.emailRequired': 'Email is required',
  'auth.invalidCredentials': 'Invalid email format',
  'auth.passwordRequired': 'Password is required',
  'auth.passwordTooShort': 'Password must be at least 8 characters',
  'common.loading': 'Loading...',
};

const t = (key: string, fallback?: string) => translations[key] || fallback || key;

// Memoized form inputs for better performance
const EmailInput = memo(({ 
  value, 
  onChange, 
  error, 
  placeholder 
}: { 
  value: string; 
  onChange: (v: string) => void; 
  error?: string; 
  placeholder: string;
}) => (
  <div className="space-y-2">
    <Label htmlFor="email" className="text-sm font-semibold">
      {placeholder}
    </Label>
    <div className="relative">
      <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
      <Input
        id="email"
        type="email"
        placeholder={placeholder}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className={cn(
          "h-12 pl-10 rounded-xl border-2 transition-all bg-background/50 backdrop-blur-sm",
          error ? "border-destructive" : "border-input focus:border-primary"
        )}
      />
    </div>
    {error && <p className="text-xs text-destructive">{error}</p>}
  </div>
));

EmailInput.displayName = 'EmailInput';

const PasswordInput = memo(({ 
  value, 
  onChange, 
  error, 
  placeholder,
  showPassword,
  onToggleShow 
}: { 
  value: string; 
  onChange: (v: string) => void; 
  error?: string; 
  placeholder: string;
  showPassword: boolean;
  onToggleShow: () => void;
}) => (
  <div className="space-y-2">
    <Label htmlFor="password" className="text-sm font-semibold">
      {placeholder}
    </Label>
    <div className="relative">
      <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
      <Input
        id="password"
        type={showPassword ? "text" : "password"}
        placeholder={placeholder}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className={cn(
          "h-12 pl-10 pr-10 rounded-xl border-2 transition-all bg-background/50 backdrop-blur-sm",
          error ? "border-destructive" : "border-input focus:border-primary"
        )}
      />
      <button
        type="button"
        onClick={onToggleShow}
        className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground transition-colors"
      >
        {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
      </button>
    </div>
    {error && <p className="text-xs text-destructive">{error}</p>}
  </div>
));

PasswordInput.displayName = 'PasswordInput';

const MAX_LOGIN_ATTEMPTS = 5;
const LOCKOUT_DURATION_MS = 60_000; // 60 seconds

const AuthScreen = () => {
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [errors, setErrors] = useState<{ email?: string; password?: string }>({});
  const [failedAttempts, setFailedAttempts] = useState(0);
  const [lockoutUntil, setLockoutUntil] = useState<number | null>(null);
  const [lockoutCountdown, setLockoutCountdown] = useState(0);
  const attemptsWindowRef = useRef<number>(Date.now());

  // Use centralized auth state to handle redirects
  const { user, isReady } = useAuthReady();
  const hasRedirected = useRef(false);
  
  useEffect(() => {
    if (!isReady || !user || hasRedirected.current) return;
    hasRedirected.current = true;
    
    // User is logged in, redirect to appropriate dashboard
    const redirectUser = async () => {
      try {
        const { preloadUserContext } = await import("@/hooks/useOptimizedAuth");
        
        // Context fetch with timeout
        const ctxPromise = preloadUserContext(user.id);
        const ctxTimeout = new Promise<never>((_, reject) => 
          setTimeout(() => reject(new Error('Context timeout')), 6000)
        );
        
        let context: Awaited<ReturnType<typeof preloadUserContext>>;
        try {
          context = await Promise.race([ctxPromise, ctxTimeout]);
        } catch {
          // Fallback navigation
          navigate("/dashboard");
          return;
        }
        
        if (context.isAdmin) {
          navigate("/admin");
        } else if (context.isFemale) {
          const approvalStatus = context.femaleProfile?.approval_status || context.profile?.approval_status;
          if (approvalStatus === 'pending') {
            navigate("/approval-pending");
          } else {
            navigate("/women-dashboard");
          }
        } else {
          navigate("/dashboard");
        }
      } catch (err) {
        console.warn('[Auth] Context check failed:', err);
        navigate("/dashboard"); // Fallback
      }
    };
    
    redirectUser();
  }, [user, isReady, navigate]);

  // Rate-limiting lockout countdown
  useEffect(() => {
    if (!lockoutUntil) return;
    const interval = setInterval(() => {
      const remaining = Math.max(0, Math.ceil((lockoutUntil - Date.now()) / 1000));
      setLockoutCountdown(remaining);
      if (remaining <= 0) {
        setLockoutUntil(null);
        setFailedAttempts(0);
        attemptsWindowRef.current = Date.now();
      }
    }, 1000);
    return () => clearInterval(interval);
  }, [lockoutUntil]);


  const validateEmail = useCallback((email: string) => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  }, []);

  const handleLogin = useCallback(async () => {
    // Rate limiting check
    if (lockoutUntil && Date.now() < lockoutUntil) {
      const { toast } = await import("@/hooks/use-toast");
      toast({ title: "Too many attempts", description: `Please wait ${lockoutCountdown} seconds before trying again.`, variant: "destructive" });
      return;
    }

    const newErrors: { email?: string; password?: string } = {};

    if (!email.trim()) {
      newErrors.email = t('auth.emailRequired');
    } else if (!validateEmail(email)) {
      newErrors.email = t('auth.invalidCredentials');
    }

    if (!password) {
      newErrors.password = t('auth.passwordRequired');
    } else if (password.length < 8) {
      newErrors.password = t('auth.passwordTooShort');
    }

    setErrors(newErrors);

    if (Object.keys(newErrors).length > 0) {
      const { toast } = await import("@/hooks/use-toast");
      toast({
        title: "Login Error",
        description: Object.values(newErrors).filter(Boolean).join(". "),
        variant: "destructive",
      });
      return;
    }

    setIsLoading(true);

    try {
      // Dynamic imports for auth
      const [{ supabase }, { toast }, { preloadUserContext }] = await Promise.all([
        import("@/integrations/supabase/client"),
        import("@/hooks/use-toast"),
        import("@/hooks/useOptimizedAuth"),
      ]);
      
      // Login with retry for transient DB timeouts (504/500)
      let authData: any = null;
      let lastError: any = null;
      const MAX_RETRIES = 3;

      for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
        try {
          const { data, error } = await supabase.auth.signInWithPassword({ email, password });
          if (error) {
            const status = (error as any)?.status;
            // Retry on server/timeout errors, NOT on auth errors (wrong password etc.)
            if ((status === 504 || status === 500 || status === 503) && attempt < MAX_RETRIES) {
              console.warn(`[Auth] Login attempt ${attempt} failed with ${status}, retrying...`);
              await new Promise(r => setTimeout(r, 1000 * attempt)); // backoff
              lastError = error;
              continue;
            }
            // Non-retryable error (likely wrong credentials)
            const newCount = failedAttempts + 1;
            setFailedAttempts(newCount);
            if (newCount >= MAX_LOGIN_ATTEMPTS) {
              const lockUntil = Date.now() + LOCKOUT_DURATION_MS;
              setLockoutUntil(lockUntil);
              toast({ title: "Account locked", description: "Too many failed attempts. Please wait 60 seconds.", variant: "destructive" });
            } else {
              toast({ title: classifyError(error).title, description: `${classifyError(error).message} (${MAX_LOGIN_ATTEMPTS - newCount} attempts remaining)`, variant: "destructive" });
            }
            setIsLoading(false);
            return;
          }
          authData = data;
          break;
        } catch (networkErr: any) {
          lastError = networkErr;
          if (attempt < MAX_RETRIES) {
            console.warn(`[Auth] Login attempt ${attempt} network error, retrying...`);
            await new Promise(r => setTimeout(r, 1000 * attempt));
            continue;
          }
        }
      }

      if (!authData?.user) {
        const msg = lastError ? "Server is busy. Please try again in a moment." : "Login failed. Please try again.";
        toast({ title: "Login Error", description: msg, variant: "destructive" });
        setIsLoading(false);
        return;
      }

      // Show success immediately
      toast({ title: "Welcome!", description: "Login successful" });

      // Preload dashboard routes in background
      import("./DashboardScreen").catch(() => {});
      import("./WomenDashboardScreen").catch(() => {});

      // Fetch user context with timeout to prevent stuck loading
      let context: Awaited<ReturnType<typeof preloadUserContext>>;
      try {
        const contextPromise = preloadUserContext(authData.user.id);
        const timeoutPromise = new Promise<never>((_, reject) => 
          setTimeout(() => reject(new Error('Context timeout')), 8000)
        );
        context = await Promise.race([contextPromise, timeoutPromise]);
      } catch (ctxErr) {
        console.warn('[Auth] Context fetch failed/timeout, using fallback navigation:', ctxErr);
        sessionStorage.setItem("postCaptchaRedirect", "/dashboard");
        navigate("/captcha");
        return;
      }

      // Determine destination based on context
      let destination = "/dashboard";
      if (context.isAdmin) {
        destination = "/admin";
      } else if (context.isFemale) {
        const approvalStatus = context.femaleProfile?.approval_status || context.profile?.approval_status;
        destination = approvalStatus === 'pending' ? "/approval-pending" : "/women-dashboard";
      }

      // Bot protection: route through math CAPTCHA before any dashboard
      sessionStorage.setItem("postCaptchaRedirect", destination);
      navigate("/captcha");
    } catch (error: any) {
      const { toast } = await import("@/hooks/use-toast");
      toast({ title: classifyError(error).title, description: classifyError(error).message, variant: "destructive" });
    } finally {
      setIsLoading(false);
    }
  }, [email, password, navigate, validateEmail, t]);

  // Debounced live email-format validation (AJAX-style UX)
  const emailDebounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const handleEmailChange = useCallback((value: string) => {
    setEmail(value);
    setErrors(prev => ({ ...prev, email: undefined }));
    if (emailDebounceRef.current) clearTimeout(emailDebounceRef.current);
    emailDebounceRef.current = setTimeout(() => {
      const v = value.trim();
      if (!v) return;
      const ok = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v);
      if (!ok) setErrors(prev => ({ ...prev, email: t('auth.invalidCredentials') }));
    }, 500);
  }, [t]);


  const handlePasswordChange = useCallback((value: string) => {
    setPassword(value);
    setErrors(prev => ({ ...prev, password: undefined }));
  }, []);

  const toggleShowPassword = useCallback(() => {
    setShowPassword(prev => !prev);
  }, []);

  const scrollRef = useRef<HTMLDivElement>(null);

  const scrollByAmount = useCallback((delta: number) => {
    const el = scrollRef.current;
    if (el) el.scrollBy({ top: delta, behavior: "smooth" });
  }, []);

  return (
    <div ref={scrollRef} className="min-h-screen flex flex-col relative bg-background overflow-y-auto">
      <Suspense fallback={<div className="fixed inset-0 -z-10 bg-gradient-to-br from-background via-background to-secondary/30" />}>
        <AuroraBackground />
      </Suspense>
      
      {/* Header */}
      <header className="px-6 pt-4 pb-2 sm:pt-8 sm:pb-4 relative z-10">
        <div className="text-center">
          <Suspense fallback={<div className="w-16 h-16 sm:w-20 sm:h-20 mx-auto mb-2 sm:mb-4 bg-primary/20 rounded-full animate-pulse" />}>
            <MeowLogo size="lg" className="mx-auto mb-2 sm:mb-4" />
          </Suspense>
          <h1 className="font-display text-2xl sm:text-4xl font-bold text-primary mb-1 sm:mb-2 drop-shadow-sm">
            {t('app.name', 'MEOW MEOW FRND APP')}
          </h1>
          <p className="text-primary/80 text-sm sm:text-lg">
            {t('app.tagline', 'Real People. Real Connections')}
          </p>
        </div>
      </header>

      {/* Main Content */}
      <main className="flex-1 flex flex-col items-center justify-start sm:justify-center px-4 sm:px-6 pb-6 sm:pb-8 relative z-10">
        <Card className="w-full max-w-md p-3 sm:p-6 bg-card/90 backdrop-blur-xl border border-primary/20 shadow-lg animate-slide-up">
          <div className="space-y-3 sm:space-y-6">
            <EmailInput 
              value={email}
              onChange={handleEmailChange}
              error={errors.email}
              placeholder={t('auth.email')}
            />

            <PasswordInput
              value={password}
              onChange={handlePasswordChange}
              error={errors.password}
              placeholder={t('auth.password')}
              showPassword={showPassword}
              onToggleShow={toggleShowPassword}
            />

            {/* Forgot Password Link */}
            <div className="text-right">
              <button
                onClick={() => navigate("/forgot-password")}
                className="text-sm text-primary hover:text-primary/80 transition-colors"
              >
                {t('auth.forgotPassword')}
              </button>
            </div>

            {/* Lockout Warning */}
            {lockoutUntil && lockoutCountdown > 0 && (
              <div className="p-3 bg-destructive/10 rounded-lg border border-destructive/20 text-center">
                <p className="text-sm text-destructive font-medium">
                  Too many attempts. Try again in {lockoutCountdown}s
                </p>
              </div>
            )}

            {/* Login + Sign Up Buttons (side by side) */}
            <div className="-mx-3 px-3 pt-2 pb-[calc(0.5rem+env(safe-area-inset-bottom))] bg-card/95 backdrop-blur-xl sm:mx-0 sm:p-0 sm:bg-transparent sm:backdrop-blur-none space-y-2">
              <div className="flex flex-row gap-2 sm:gap-3 w-full">
                <Button
                  variant="aurora"
                  size="lg"
                  className="flex-1 min-w-0 px-2 sm:px-4 group"
                  onClick={handleLogin}
                  disabled={isLoading || (!!lockoutUntil && lockoutCountdown > 0)}
                >
                  {isLoading ? (
                    <>
                      <Loader2 className="w-4 h-4 animate-spin mr-1" />
                      <span className="truncate">{t('common.loading')}</span>
                    </>
                  ) : lockoutUntil && lockoutCountdown > 0 ? (
                    <span className="truncate">Locked ({lockoutCountdown}s)</span>
                  ) : (
                    <>
                      <span className="truncate">{t('auth.login')}</span>
                      <ArrowRight className="w-4 h-4 transition-transform group-hover:translate-x-1" />
                    </>
                  )}
                </Button>
                <Button
                  variant="aurora"
                  size="lg"
                  className="flex-1 min-w-0 px-2 sm:px-4"
                  onClick={() => navigate("/register")}
                  disabled={isLoading}
                >
                  <span className="truncate">{t('auth.signup')}</span>
                </Button>
              </div>
              <a
                href="/PWA_Installation_Guide.docx"
                download
                className="block text-center text-xs sm:text-sm text-primary hover:text-primary/80 underline underline-offset-2 transition-colors"
              >
                📥 Download PWA Installation Guide
              </a>
            </div>
          </div>
        </Card>
      </main>

      {/* Floating scroll toggle — helps reach Sign Up button on small screens */}
      <div className="fixed right-3 bottom-[calc(1rem+env(safe-area-inset-bottom))] z-50 flex flex-col gap-2">
        <button
          type="button"
          aria-label="Scroll up"
          onClick={() => scrollByAmount(-300)}
          className="w-10 h-10 rounded-full bg-primary/90 text-primary-foreground shadow-lg backdrop-blur-md flex items-center justify-center hover:bg-primary transition-all active:scale-95 border border-primary/30"
        >
          <ChevronUp className="w-5 h-5" />
        </button>
        <button
          type="button"
          aria-label="Scroll down to Sign Up"
          onClick={() => scrollByAmount(300)}
          className="w-10 h-10 rounded-full bg-primary/90 text-primary-foreground shadow-lg backdrop-blur-md flex items-center justify-center hover:bg-primary transition-all active:scale-95 border border-primary/30"
        >
          <ChevronDown className="w-5 h-5" />
        </button>
      </div>
    </div>
  );
};

export default memo(AuthScreen);
