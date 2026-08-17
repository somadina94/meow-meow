import { toast } from "sonner";
/**
 * ProtectedRoute – single source of route guarding.
 *
 * Uses the global useAuthReady() hook so every component shares the same
 * session state. Role check result is cached in module-level state to avoid
 * redundant DB queries on every route navigation.
 */
import { useState, useEffect, useRef, Suspense } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/integrations/supabase/client';
import { useAuthReady, isSignedOut } from '@/hooks/useAuthReady';
import { Loader2 } from 'lucide-react';
import { ErrorBoundary } from '@/components/ErrorBoundary';

type RequiredRole = 'male' | 'female' | 'admin' | 'authenticated';

interface Props {
  children: React.ReactNode;
  requiredRole?: RequiredRole;
}

// ── Module-level role cache ─────────────────────────────────────────
// Caches the last role-check result per user to avoid 3x DB queries on every
// protected route mount. Invalidated on SIGNED_OUT.
interface RoleCacheEntry {
  userId: string;
  isAdmin: boolean;
  isFemale: boolean;
  isMale: boolean;
  timestamp: number;
}

let roleCache: RoleCacheEntry | null = null;
const ROLE_CACHE_TTL = 15_000; // BUG-04 FIX: 15s — reduces stale role window

function clearRoleCache() {
  roleCache = null;
}

// Captcha verification persistence — keyed per user in localStorage so a page
// refresh (or transient SIGNED_OUT flap during session restore) never forces
// the user back through CAPTCHA. Expires after 24h.
const CAPTCHA_TTL_MS = 24 * 60 * 60 * 1000;
function isCaptchaVerified(userId: string | undefined): boolean {
  if (!userId) return false;
  try {
    // Back-compat: legacy session flag still counts.
    if (sessionStorage.getItem('captchaVerifiedAt')) return true;
    const raw = localStorage.getItem(`captchaVerifiedFor:${userId}`);
    if (!raw) return false;
    const ts = parseInt(raw, 10);
    return Number.isFinite(ts) && Date.now() - ts < CAPTCHA_TTL_MS;
  } catch { return false; }
}

// Listen for sign-out to invalidate cache (module-level, runs once)
supabase.auth.onAuthStateChange((event) => {
  if (event === 'SIGNED_OUT') {
    clearRoleCache();
    // NOTE: do NOT clear captchaVerifiedFor:* here. SIGNED_OUT can fire on
    // transient token-refresh failures; clearing would log the user out of
    // their CAPTCHA grant on every refresh. The TTL handles staleness.
    try {
      sessionStorage.removeItem('captchaVerifiedAt');
      sessionStorage.removeItem('postCaptchaRedirect');
    } catch {}
  }
});


const ProtectedRoute = ({ children, requiredRole = 'authenticated' }: Props) => {
  const navigate = useNavigate();
  const { user, isReady } = useAuthReady();
  const [authorized, setAuthorized] = useState(false);
  const [checking, setChecking] = useState(true);
  const checkedForUser = useRef<string | null>(null);
  const REVALIDATE_INTERVAL_MS = 60_000;

  // Resolve role info — uses cache if valid
  const resolveRoles = async (userId: string, forceRefresh = false): Promise<RoleCacheEntry> => {
    // Return cached result if fresh
    if (!forceRefresh && roleCache && roleCache.userId === userId
        && (Date.now() - roleCache.timestamp) < ROLE_CACHE_TTL) {
      return roleCache;
    }

    const MAX_RETRIES = forceRefresh ? 1 : 3;
    let profileRes: any, femaleRes: any, adminRes: any;

    for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
      try {
        const timeout = new Promise((_, rej) =>
          setTimeout(() => rej(new Error('timeout')), 8000)
        );
        const queries = Promise.all([
          supabase.from('profiles').select('gender').eq('user_id', userId).maybeSingle(),
          supabase.from('female_profiles').select('user_id').eq('user_id', userId).maybeSingle(),
          supabase.from('user_roles').select('role').eq('user_id', userId).eq('role', 'admin').maybeSingle(),
        ]);
        [profileRes, femaleRes, adminRes] = (await Promise.race([queries, timeout])) as any;
        break;
      } catch (retryErr) {
        if (attempt < MAX_RETRIES) {
          console.warn(`[ProtectedRoute] Role check attempt ${attempt} failed, retrying...`);
          await new Promise(r => setTimeout(r, 1000 * attempt));
        } else {
          throw retryErr;
        }
      }
    }

    const isAdmin = !!adminRes.data;
    const isFemale = profileRes.data?.gender?.toLowerCase() === 'female' || !!femaleRes.data;
    const isMale = !isFemale && !isAdmin;

    const entry: RoleCacheEntry = { userId, isAdmin, isFemale, isMale, timestamp: Date.now() };
    roleCache = entry;
    return entry;
  };

  // Evaluate authorization against required role
  const evaluateAccess = (roles: RoleCacheEntry): { ok: boolean; to: string } => {
    let ok = false;
    let to = '/';

    switch (requiredRole) {
      case 'admin':
        ok = roles.isAdmin;
        if (!ok) to = roles.isFemale ? '/women-dashboard' : '/dashboard';
        break;
      case 'female':
        ok = roles.isFemale && !roles.isAdmin;
        if (!ok) to = roles.isAdmin ? '/admin' : '/dashboard';
        break;
      case 'male':
        ok = roles.isMale && !roles.isAdmin;
        if (!ok) to = roles.isAdmin ? '/admin' : roles.isFemale ? '/women-dashboard' : '/dashboard';
        break;
      case 'authenticated':
        ok = true;
        break;
    }

    return { ok, to };
  };

  // Initial role check on mount / user change
  useEffect(() => {
    if (!isReady) return;

    if (!user) {
      navigate('/', { replace: true });
      return;
    }

    // CAPTCHA gate — block dashboards until math CAPTCHA has been solved
    // (per user, 24h, persisted in localStorage so refresh doesn't kick them).
    const captchaOk = isCaptchaVerified(user.id);
    if (!captchaOk) {
      const target =
        requiredRole === 'admin' ? '/admin' :
        requiredRole === 'female' ? '/women-dashboard' :
        requiredRole === 'male' ? '/dashboard' :
        window.location.pathname + window.location.search;
      sessionStorage.setItem('postCaptchaRedirect', target);
      navigate('/captcha', { replace: true });
      return;
    }



    if (checkedForUser.current === user.id) return;

    if (requiredRole === 'authenticated') {
      checkedForUser.current = user.id;
      setAuthorized(true);
      setChecking(false);
      return;
    }

    let mounted = true;
    setChecking(true);

    (async () => {
      try {
        const roles = await resolveRoles(user.id);
        if (!mounted) return;

        const { ok, to } = evaluateAccess(roles);
        if (ok) {
          checkedForUser.current = user.id;
          setAuthorized(true);
        } else {
          navigate(to, { replace: true });
        }
      } catch (e) {
        console.error('[ProtectedRoute]', e);
        if (mounted) navigate('/', { replace: true });
      } finally {
        if (mounted) setChecking(false);
      }
    })();

    return () => { mounted = false; };
  }, [user?.id, isReady, requiredRole, navigate]);

  // Periodic re-validation: detect revoked roles while tab is open
  useEffect(() => {
    if (!authorized || !user || requiredRole === 'authenticated') return;

    const interval = setInterval(async () => {
      try {
        const roles = await resolveRoles(user.id, true);
        const { ok, to } = evaluateAccess(roles);
        if (!ok) {
          console.warn(`[ProtectedRoute] Role revoked for user ${user.id}, redirecting`);
          checkedForUser.current = null;
          setAuthorized(false);
          toast.error('Your access permissions have changed. Redirecting...');
          navigate(to, { replace: true });
        }
      } catch {
        // Silently ignore transient network errors during revalidation
      }
    }, REVALIDATE_INTERVAL_MS);

    return () => clearInterval(interval);
  }, [authorized, user?.id, requiredRole, navigate]);

  // Back-button guard — sign-out is already handled by module-level listener & useAuthReady
  useEffect(() => {
    const handlePopState = () => {
      if (isSignedOut()) {
        window.history.replaceState(null, '', '/');
        navigate('/', { replace: true });
      }
    };
    window.addEventListener('popstate', handlePopState);
    return () => window.removeEventListener('popstate', handlePopState);
  }, [navigate]);

  // React to sign-out via useAuthReady (no extra subscription needed)
  useEffect(() => {
    if (isReady && !user && authorized) {
      checkedForUser.current = null;
      setAuthorized(false);
      navigate('/', { replace: true });
    }
  }, [isReady, user, authorized, navigate]);

  if (!isReady || checking) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    );
  }

  return authorized ? (
    <ErrorBoundary showHomeButton>
      <Suspense fallback={
        <div className="min-h-screen bg-background flex items-center justify-center">
          <Loader2 className="h-8 w-8 animate-spin text-primary" />
        </div>
      }>
        {children}
      </Suspense>
    </ErrorBoundary>
  ) : null;
};

export default ProtectedRoute;
