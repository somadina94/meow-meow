/**
 * Preload User Context
 * 
 * Standalone function to fetch user context in parallel on login.
 * Used by AuthScreen to determine post-login routing.
 * 
 * NOTE: The auth state singleton lives in useAuthReady.ts — do NOT
 * create a second onAuthStateChange listener here.
 */

import { supabase } from '@/integrations/supabase/client';

interface PreloadedUserContext {
  isAdmin: boolean;
  isFemale: boolean;
  tutorialCompleted: boolean;
  profile: {
    gender?: string | null;
    full_name?: string | null;
    approval_status?: string | null;
  } | null;
  femaleProfile: {
    user_id: string;
    approval_status: string;
  } | null;
}

/**
 * Preload user context on login — fetches admin role, tutorial progress,
 * profile, and female profile in parallel. Always fetches fresh data
 * since this guards security-sensitive routing (admin access, approval status).
 */
export async function preloadUserContext(userId: string): Promise<PreloadedUserContext> {
  const settled = await Promise.allSettled([
    supabase
      .from('user_roles')
      .select('role')
      .eq('user_id', userId)
      .eq('role', 'admin')
      .maybeSingle(),
    supabase
      .from('tutorial_progress')
      .select('completed')
      .eq('user_id', userId)
      .maybeSingle(),
    supabase
      .from('profiles')
      .select('gender, full_name, approval_status')
      .eq('user_id', userId)
      .maybeSingle(),
    supabase
      .from('female_profiles')
      .select('user_id, approval_status')
      .eq('user_id', userId)
      .maybeSingle(),
  ]);

  const [adminResult, tutorialResult, profileResult, femaleResult] = settled.map(r =>
    r.status === 'fulfilled' ? r.value : { data: null, error: r.status === 'rejected' ? r.reason : null }
  );

  return {
    isAdmin: !!adminResult.data,
    tutorialCompleted: !!tutorialResult.data?.completed,
    isFemale: profileResult.data?.gender?.toLowerCase() === 'female' || !!femaleResult.data,
    profile: profileResult.data ?? null,
    femaleProfile: femaleResult.data ?? null,
  };
}

/** @deprecated No-op — cache was removed. This export will be deleted in a future release. */
export function clearUserContextCache(): void {
  // Nothing to clear — preloadUserContext always fetches fresh data
}
