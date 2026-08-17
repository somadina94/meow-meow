/**
 * Shared CORS utilities for all Edge Functions.
 * 
 * Restricts Access-Control-Allow-Origin to known origins in production.
 * Falls back to wildcard only in development.
 */

const ALLOWED_ORIGINS = [
  'https://meowmeow123.lovable.app',
  'https://meow-meow.com',
  'https://www.meow-meow.com',
  'https://app.meow-meow.com',
  // Add staging/preview origins as needed
  ...(Deno.env.get('ALLOWED_ORIGINS') || '').split(',').filter(Boolean),
];

export function getCorsHeaders(req: Request) {
  const origin = req.headers.get('origin') || '';
  
  // In development or if origin matches allowlist, reflect it
  const isAllowed = ALLOWED_ORIGINS.includes(origin) || origin.endsWith('.lovable.app');
  const allowedOrigin = isAllowed ? origin : ALLOWED_ORIGINS[0] || '*';
  
  return {
    'Access-Control-Allow-Origin': allowedOrigin,
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };
}

/** Super user email patterns - they bypass ALL balance requirements */
const SUPER_USER_PATTERNS = {
  female: /^female([1-9]|1[0-5])@meow-meow\.com$/i,
  male: /^male([1-9]|1[0-5])@meow-meow\.com$/i,
  admin: /^admin([1-9]|1[0-5])@meow-meow\.com$/i,
};

export const isSuperUserEmail = (email: string): boolean => {
  if (!email) return false;
  return (
    SUPER_USER_PATTERNS.female.test(email) ||
    SUPER_USER_PATTERNS.male.test(email) ||
    SUPER_USER_PATTERNS.admin.test(email)
  );
};
