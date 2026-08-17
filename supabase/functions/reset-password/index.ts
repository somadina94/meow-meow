import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version",
};

const rateLimitMap = new Map<string, { count: number; resetAt: number }>();
const RATE_LIMIT_WINDOW_MS = 15 * 60 * 1000;
const MAX_ATTEMPTS = 5;
const RESET_TOKEN_EXPIRY_MINUTES = 10;

function checkRateLimit(identifier: string): { allowed: boolean; remaining: number; resetIn: number } {
  const now = Date.now();
  const entry = rateLimitMap.get(identifier);
  if (!entry || now > entry.resetAt) {
    rateLimitMap.set(identifier, { count: 1, resetAt: now + RATE_LIMIT_WINDOW_MS });
    return { allowed: true, remaining: MAX_ATTEMPTS - 1, resetIn: RATE_LIMIT_WINDOW_MS };
  }
  if (entry.count >= MAX_ATTEMPTS) {
    return { allowed: false, remaining: 0, resetIn: entry.resetAt - now };
  }
  entry.count++;
  return { allowed: true, remaining: MAX_ATTEMPTS - entry.count, resetIn: entry.resetAt - now };
}

function validateEmail(email: string): boolean {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return typeof email === 'string' && email.length <= 255 && emailRegex.test(email);
}

function validatePhone(phone: string): boolean {
  const phoneRegex = /^[0-9+\-\s()]{8,20}$/;
  return typeof phone === 'string' && phoneRegex.test(phone);
}

function validatePassword(password: string): boolean {
  if (typeof password !== 'string' || password.length < 8 || password.length > 128) return false;
  return /[A-Z]/.test(password) && /[a-z]/.test(password) && /[0-9]/.test(password) && /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password);
}

function normalizePhone(phone: string): string {
  const digits = (phone || '').replace(/\D/g, '');
  let national = digits.startsWith('91') && digits.length > 10 ? digits.slice(2) : digits;
  if (national.length === 11 && national.startsWith('0')) national = national.slice(1);
  return national.length > 10 ? national.slice(-10) : national;
}

function phoneCandidates(phone: string): Set<string> {
  const digits = (phone || '').replace(/\D/g, '');
  const candidates = new Set<string>();
  const add = (value: string) => {
    if (!value) return;
    candidates.add(value);
    if (value.length > 10) candidates.add(value.slice(-10));
    if (value.startsWith('0') && value.length > 1) candidates.add(value.slice(1));
  };

  add(digits);
  if (digits.startsWith('91') && digits.length > 10) add(digits.slice(2));
  add(normalizePhone(phone));

  return new Set([...candidates].filter(value => value.length >= 8));
}

function phonesMatch(inputPhone: string, storedPhone: string): boolean {
  const inputCandidates = phoneCandidates(inputPhone);
  const storedCandidates = phoneCandidates(storedPhone);

  for (const value of inputCandidates) {
    if (storedCandidates.has(value)) return true;
  }

  // Legacy recovery: older India registrations could save +91 + leading 0 + first 9 digits.
  for (const stored of storedCandidates) {
    for (const input of inputCandidates) {
      if (stored.length === 9 && input.length === 10 && input.startsWith(stored)) return true;
      if (input.length === 9 && stored.length === 10 && stored.startsWith(input)) return true;
    }
  }

  return false;
}

function generateSecureToken(): string {
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return Array.from(array, b => b.toString(16).padStart(2, '0')).join('');
}

function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const clientIP = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || req.headers.get("x-real-ip") || "unknown";
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const body = await req.json();
    const { action, email, phone, token, newPassword } = body;

    const validActions = ['verify-account', 'verify-token', 'direct-reset'];
    if (!action || !validActions.includes(action)) {
      return jsonResponse({ error: "Invalid action" }, 400);
    }

    // ==========================================
    // ACTION: Verify account by email + phone → issue token
    // ==========================================
    if (action === "verify-account") {
      if (!email || !validateEmail(email)) return jsonResponse({ verified: false, error: "Invalid email format" }, 400);
      if (!phone || !validatePhone(phone)) return jsonResponse({ verified: false, error: "Invalid phone format" }, 400);

      const rateLimitKey = `verify:${clientIP}:${email.toLowerCase()}`;
      const rateCheck = checkRateLimit(rateLimitKey);
      if (!rateCheck.allowed) {
        return jsonResponse({ verified: false, error: "Too many attempts. Please try again later.", retryAfter: Math.ceil(rateCheck.resetIn / 1000) }, 429);
      }

      await new Promise(resolve => setTimeout(resolve, 200 + Math.random() * 200));

      // Look up user by email in profiles
      const { data: profileByEmail, error: profileLookupError } = await supabaseAdmin
        .from("profiles")
        .select("user_id, phone, email")
        .eq("email", email.toLowerCase())
        .maybeSingle();

      if (profileLookupError) {
        console.error("Error looking up profile:", profileLookupError);
        return jsonResponse({ verified: false, error: "Failed to verify account" }, 500);
      }

      let userId: string | null = profileByEmail?.user_id || null;
      let storedPhone: string | null = profileByEmail?.phone || null;

      if (!userId) {
        let page = 1;
        let found = false;
        while (!found && page <= 20) {
          const { data: usersPage, error: usersError } = await supabaseAdmin.auth.admin.listUsers({ page, perPage: 50 });
          if (usersError) break;
          const user = usersPage?.users?.find(u => u.email?.toLowerCase() === email.toLowerCase());
          if (user) {
            userId = user.id;
            found = true;
            const { data: profile } = await supabaseAdmin.from("profiles").select("phone").eq("user_id", user.id).maybeSingle();
            storedPhone = profile?.phone || null;
          }
          if (!usersPage?.users?.length || usersPage.users.length < 50) break;
          page++;
        }
      }

      if (!userId) return jsonResponse({ verified: false, error: "No account found with this email" });
      if (!storedPhone) return jsonResponse({ verified: false, error: "No phone number on file for this account" });

      if (!phonesMatch(phone, storedPhone)) {
        return jsonResponse({ verified: false, error: "Email and phone number do not match" });
      }

      // Invalidate any existing tokens for this user
      await supabaseAdmin
        .from("password_reset_tokens")
        .update({ used: true })
        .eq("user_id", userId)
        .eq("used", false);

      // Generate a secure time-limited token
      const resetToken = generateSecureToken();
      const expiresAt = new Date(Date.now() + RESET_TOKEN_EXPIRY_MINUTES * 60 * 1000).toISOString();

      const { error: insertError } = await supabaseAdmin
        .from("password_reset_tokens")
        .insert({ user_id: userId, token: resetToken, expires_at: expiresAt });

      if (insertError) {
        console.error("Error creating reset token:", insertError);
        return jsonResponse({ verified: false, error: "Failed to create reset token" }, 500);
      }

      console.log(`Reset token issued for user: ${userId}, expires: ${expiresAt}`);

      return jsonResponse({ verified: true, token: resetToken });
    }

    // ==========================================
    // ACTION: Verify reset token
    // ==========================================
    if (action === "verify-token") {
      if (!token || typeof token !== 'string') {
        return jsonResponse({ valid: false, error: "Invalid token" }, 400);
      }

      const rateLimitKey = `verify-token:${clientIP}`;
      const rateCheck = checkRateLimit(rateLimitKey);
      if (!rateCheck.allowed) {
        return jsonResponse({ valid: false, error: "Too many attempts." }, 429);
      }

      const { data: tokenData, error: tokenError } = await supabaseAdmin
        .from("password_reset_tokens")
        .select("user_id, expires_at, used")
        .eq("token", token)
        .maybeSingle();

      if (tokenError || !tokenData) {
        return jsonResponse({ valid: false, error: "Invalid or expired reset token" });
      }

      if (tokenData.used) {
        return jsonResponse({ valid: false, error: "This reset token has already been used" });
      }

      if (new Date(tokenData.expires_at) < new Date()) {
        return jsonResponse({ valid: false, error: "This reset token has expired. Please start again." });
      }

      return jsonResponse({ valid: true, userId: tokenData.user_id });
    }

    // ==========================================
    // ACTION: Direct password reset (now requires valid token)
    // ==========================================
    if (action === "direct-reset") {
      if (!token || typeof token !== 'string') {
        return jsonResponse({ success: false, error: "Reset token is required" }, 400);
      }

      if (!newPassword || !validatePassword(newPassword)) {
        return jsonResponse({ success: false, error: "Password must be 8+ characters with uppercase, lowercase, number, and symbol" }, 400);
      }

      const rateLimitKey = `reset:${clientIP}`;
      const rateCheck = checkRateLimit(rateLimitKey);
      if (!rateCheck.allowed) {
        return jsonResponse({ success: false, error: "Too many attempts.", retryAfter: Math.ceil(rateCheck.resetIn / 1000) }, 429);
      }

      // Validate the token
      const { data: tokenData, error: tokenError } = await supabaseAdmin
        .from("password_reset_tokens")
        .select("id, user_id, expires_at, used")
        .eq("token", token)
        .maybeSingle();

      if (tokenError || !tokenData) {
        return jsonResponse({ success: false, error: "Invalid reset token" }, 400);
      }

      if (tokenData.used) {
        return jsonResponse({ success: false, error: "This reset token has already been used" }, 400);
      }

      if (new Date(tokenData.expires_at) < new Date()) {
        return jsonResponse({ success: false, error: "Reset token has expired. Please start again." }, 400);
      }

      const userId = tokenData.user_id;

      // Update password
      const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(userId, { password: newPassword });

      if (updateError) {
        console.error("Password update error:", updateError);
        return jsonResponse({ success: false, error: "Failed to update password" }, 500);
      }

      // Mark token as used
      await supabaseAdmin
        .from("password_reset_tokens")
        .update({ used: true })
        .eq("id", tokenData.id);

      console.log(`Password reset successful for user: ${userId}`);
      return jsonResponse({ success: true });
    }

    return jsonResponse({ error: "Invalid action" }, 400);
  } catch (error) {
    console.error("Reset password error:", error);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});
