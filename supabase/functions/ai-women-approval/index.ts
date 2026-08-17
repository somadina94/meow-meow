import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version",
};

interface FemaleProfile {
  id: string;
  user_id: string;
  full_name: string | null;
  primary_language: string | null;
  approval_status: string;
  account_status: string;
  performance_score: number;
  last_active_at: string | null;
  total_chats_count: number;
  avg_response_time_seconds: number;
  ai_approved: boolean;
  created_at: string;
  country: string | null;
  is_indian: boolean | null;
  is_earning_eligible: boolean | null;
}

interface LanguageGroup {
  id: string;
  name: string;
  languages: string[];
  max_women_users: number;
  current_women_count: number;
}

interface LanguageLimit {
  id: string;
  language_name: string;
  max_earning_women: number;
  current_earning_women: number;
  is_active: boolean;
}

// Language name to code mapping for flexible matching
const languageNameToCode: Record<string, string[]> = {
  'telugu': ['te', 'te-IN', 'Telugu'],
  'tamil': ['ta', 'ta-IN', 'Tamil'],
  'kannada': ['kn', 'kn-IN', 'Kannada'],
  'malayalam': ['ml', 'ml-IN', 'Malayalam'],
  'hindi': ['hi', 'hi-IN', 'Hindi'],
  'bengali': ['bn', 'bn-IN', 'Bengali'],
  'marathi': ['mr', 'mr-IN', 'Marathi'],
  'gujarati': ['gu', 'gu-IN', 'Gujarati'],
  'punjabi': ['pa', 'pa-IN', 'Punjabi'],
  'odia': ['or', 'or-IN', 'Odia', 'Oriya'],
  'urdu': ['ur', 'ur-IN', 'ur-PK', 'Urdu'],
  'english': ['en', 'en-IN', 'en-US', 'en-GB', 'English'],
  'arabic': ['ar', 'ar-SA', 'ar-EG', 'Arabic'],
  'spanish': ['es', 'es-ES', 'es-MX', 'Spanish'],
  'french': ['fr', 'fr-FR', 'French'],
  'german': ['de', 'de-DE', 'German'],
  'portuguese': ['pt', 'pt-BR', 'pt-PT', 'Portuguese'],
  'russian': ['ru', 'ru-RU', 'Russian'],
  'chinese': ['zh', 'zh-CN', 'zh-TW', 'Chinese'],
  'japanese': ['ja', 'ja-JP', 'Japanese'],
  'korean': ['ko', 'ko-KR', 'Korean'],
  'thai': ['th', 'th-TH', 'Thai'],
  'vietnamese': ['vi', 'vi-VN', 'Vietnamese'],
  'indonesian': ['id', 'id-ID', 'Indonesian'],
  'turkish': ['tr', 'tr-TR', 'Turkish'],
};

function getLanguageVariants(language: string | null): string[] {
  if (!language) return [];
  
  const lowerLang = language.toLowerCase().trim();
  
  // Check if it's a language name
  if (languageNameToCode[lowerLang]) {
    return languageNameToCode[lowerLang];
  }
  
  // Check if it's already a code, find all variants
  for (const [name, codes] of Object.entries(languageNameToCode)) {
    if (codes.some(c => c.toLowerCase() === lowerLang)) {
      return codes;
    }
  }
  
  // Return the original plus common variants
  return [language, language.toLowerCase(), language.toUpperCase()];
}

function matchesLanguageGroup(userLanguage: string | null, groupLanguages: string[]): boolean {
  if (!userLanguage) return false;
  
  const variants = getLanguageVariants(userLanguage);
  
  // Check if any variant matches any group language
  return variants.some(variant => 
    groupLanguages.some(gl => 
      gl.toLowerCase() === variant.toLowerCase() ||
      gl.toLowerCase().startsWith(variant.toLowerCase()) ||
      variant.toLowerCase().startsWith(gl.toLowerCase())
    )
  );
}

interface JwtClaims {
  sub?: unknown;
  exp?: unknown;
  nbf?: unknown;
  aud?: unknown;
  role?: unknown;
  [key: string]: unknown;
}

function decodeBase64Url(input: string): Uint8Array {
  const normalized = input.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(normalized.length + ((4 - normalized.length % 4) % 4), "=");
  const binary = atob(padded);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

function decodeJwtPart<T>(part: string): T {
  return JSON.parse(new TextDecoder().decode(decodeBase64Url(part))) as T;
}

async function verifyHs256Jwt(token: string): Promise<JwtClaims | null> {
  const jwtSecret = Deno.env.get("SUPABASE_JWT_SECRET") || Deno.env.get("JWT_SECRET");
  if (!jwtSecret) return null;

  const parts = token.split(".");
  if (parts.length !== 3) return null;

  const [encodedHeader, encodedPayload, encodedSignature] = parts;
  const header = decodeJwtPart<{ alg?: string }>(encodedHeader);
  if (header.alg !== "HS256") return null;

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(jwtSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const isValid = await crypto.subtle.verify(
    "HMAC",
    key,
    decodeBase64Url(encodedSignature),
    new TextEncoder().encode(`${encodedHeader}.${encodedPayload}`),
  );
  if (!isValid) return null;

  const claims = decodeJwtPart<JwtClaims>(encodedPayload);
  const now = Math.floor(Date.now() / 1000);
  if (typeof claims.exp === "number" && claims.exp <= now) return null;
  if (typeof claims.nbf === "number" && claims.nbf > now) return null;
  return claims;
}

async function getVerifiedClaims(
  authClient: any,
  token: string,
): Promise<{ claims: JwtClaims | null; error?: string }> {
  const { data, error } = await authClient.auth.getClaims(token);
  if (!error && data?.claims?.sub) {
    return { claims: data.claims as JwtClaims };
  }

  const fallbackClaims = await verifyHs256Jwt(token).catch(() => null);
  if (fallbackClaims?.sub) {
    return { claims: fallbackClaims };
  }

  return { claims: null, error: error?.message || "Unable to verify JWT claims" };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Auth guard: require authenticated user OR internal system caller (pg_cron).
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const token = authHeader.replace("Bearer ", "");

    // W2 fix: pg_cron invokes this fn with the SERVICE_ROLE key (no `sub` claim).
    // Treat that bearer as the system caller — only `auto_approve` is permitted
    // via this path; per-user actions still require a real JWT below.
    const isSystemCaller = token === supabaseServiceKey;
    let caller: { id: string } = { id: "" };

    if (!isSystemCaller) {
      // Verify JWT via getClaims (compatible with Supabase signing-keys system)
      const authClient = createClient(supabaseUrl, supabaseAnonKey, {
        global: { headers: { Authorization: authHeader } },
      });
      const { claims, error: authError } = await getVerifiedClaims(authClient, token);
      if (authError || typeof claims?.sub !== "string") {
        console.error("[ai-women-approval] auth failed:", authError);
        return new Response(JSON.stringify({ success: false, error: "Invalid token" }), {
          status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      caller = { id: claims.sub };
    }

    // Parse request body for action type
    let action = "auto_approve"; // default action
    let userId: string | null = null;
    
    try {
      const body = await req.json();
      action = body.action || "auto_approve";
      userId = body.user_id || null;
    } catch {
      // No body or invalid JSON, use defaults
    }

    // auto_approve is admin-only OR system-caller (pg_cron via service role).
    // request_reapproval can be done by the user themselves.
    if (action === "auto_approve") {
      if (!isSystemCaller) {
        const { data: roleData } = await supabase
          .from("user_roles").select("role")
          .eq("user_id", caller.id).eq("role", "admin").maybeSingle();
        if (!roleData) {
          return new Response(JSON.stringify({ success: false, error: "Admin access required" }), {
            status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }
      }
    } else if (action === "request_reapproval") {
      if (isSystemCaller) {
        return new Response(JSON.stringify({ success: false, error: "request_reapproval requires a user JWT" }), {
          status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      // Users can only reapply for themselves
      if (userId && userId !== caller.id) {
        const { data: roleData } = await supabase
          .from("user_roles").select("role")
          .eq("user_id", caller.id).eq("role", "admin").maybeSingle();
        if (!roleData) {
          return new Response(JSON.stringify({ success: false, error: "Cannot reapply for another user" }), {
            status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }
      }
      // Default userId to caller if not specified
      if (!userId) userId = caller.id;
    }

    console.log(`AI Women Approval - Action: ${action}`);

    // Handle different actions
    if (action === "request_reapproval" && userId) {
      return await handleReapprovalRequest(supabase, userId);
    }

    // Default: Run auto-approval process
    return await runAutoApproval(supabase);

  } catch (error: any) {
    console.error("AI Women Approval error:", error);
    return new Response(
      JSON.stringify({ success: false, error: error?.message || "Unknown error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

/**
 * Handle re-approval request from inactive users (30+ days inactive)
 * Allows them to get back into the active users list
 */
async function handleReapprovalRequest(supabase: any, userId: string) {
  console.log(`Processing re-approval request for user: ${userId}`);

  try {
    // Check if user exists and is disapproved/inactive
    const { data: profile, error: profileError } = await supabase
      .from("female_profiles")
      .select("*")
      .eq("user_id", userId)
      .maybeSingle();

    if (profileError || !profile) {
      // Check profiles table
      const { data: mainProfile } = await supabase
        .from("profiles")
        .select("*")
        .eq("user_id", userId)
        .eq("gender", "female")
        .maybeSingle();

      if (!mainProfile) {
        return new Response(
          JSON.stringify({ success: false, error: "User not found or not a female user" }),
          { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // Check if the user was disapproved due to inactivity or is inactive
    const isInactive = profile?.approval_status === "inactive" || 
                       profile?.approval_status === "disapproved" || 
                       profile?.ai_disapproval_reason?.includes("Inactive");

    if (!isInactive && profile?.approval_status === "approved") {
      return new Response(
        JSON.stringify({ success: false, error: "User is already approved" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Set user status to pending for re-approval
    const updateData = {
      approval_status: "pending",
      ai_approved: false,
      ai_disapproval_reason: null,
      account_status: "active",
      last_active_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    // Update female_profiles
    if (profile) {
      await supabase
        .from("female_profiles")
        .update(updateData)
        .eq("user_id", userId);
    }

    // Update profiles table
    await supabase
      .from("profiles")
      .update({
        approval_status: "pending",
        ai_approved: false,
        ai_disapproval_reason: null,
        account_status: "active",
        last_active_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq("user_id", userId);

    console.log(`✓ User ${userId} set to pending for re-approval`);

    // Immediately run approval for this user (as reapproval - goes to FREE list)
    await approveSpecificUser(supabase, userId, true);

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: "Re-approval request processed successfully. You are now approved.",
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error: any) {
    console.error("Re-approval request error:", error);
    return new Response(
      JSON.stringify({ success: false, error: error?.message || "Failed to process re-approval" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
}

/**
 * Approve a specific user immediately (reapproval flow)
 * Users who reapply after being inactive are approved but go to FREE users list
 */
async function approveSpecificUser(supabase: any, userId: string, isReapproval: boolean = true) {
  // Reapproved users go to FREE list (not earning eligible)
  // Only new users or monthly rotation can make them earning eligible
  const approvalData = {
    approval_status: "approved",
    ai_approved: true,
    auto_approved: true,
    ai_disapproval_reason: null,
    account_status: "active",
    performance_score: 100, // Reset performance score
    last_active_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
    // Reapproved users become FREE users (not earning eligible)
    is_earning_eligible: isReapproval ? false : undefined,
    earning_slot_assigned_at: isReapproval ? null : undefined,
    earning_badge_type: isReapproval ? null : undefined,
  };

  // Clean up undefined values
  const cleanedData = Object.fromEntries(
    Object.entries(approvalData).filter(([_, v]) => v !== undefined)
  );

  // Update female_profiles
  await supabase
    .from("female_profiles")
    .update(cleanedData)
    .eq("user_id", userId);

  // Update profiles
  await supabase
    .from("profiles")
    .update({
      approval_status: "approved",
      ai_approved: true,
      ai_disapproval_reason: null,
      account_status: "active",
      performance_score: 100,
      last_active_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      is_earning_eligible: isReapproval ? false : undefined,
      earning_slot_assigned_at: isReapproval ? null : undefined,
      earning_badge_type: isReapproval ? null : undefined,
    })
    .eq("user_id", userId);

  // Ensure women_availability entry exists (user becomes online capable)
  await supabase
    .from("women_availability")
    .upsert({
      user_id: userId,
      is_available: false,
      is_available_for_calls: false,
      current_chat_count: 0,
      current_call_count: 0,
      max_concurrent_chats: 3,
      max_concurrent_calls: 1,
      last_activity_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }, { onConflict: 'user_id' });

  console.log(`✓ User ${userId} approved successfully (isReapproval: ${isReapproval}, earning_eligible: ${!isReapproval})`);
}

/**
 * Run the automatic approval process for all pending women
 * This runs every 5 minutes via cron job
 */
async function runAutoApproval(supabase: any) {
  console.log("Starting AI Women Auto-Approval Process...");

  const results = {
    approved: 0,
    disapproved: 0,
    retained: 0,
    rotatedOut: 0,
    reactivated: 0,
    noLanguageGroupApproved: 0,
    errors: [] as string[],
  };

  // STEP 1: Get all pending female profiles from female_profiles table
  const { data: pendingFemales, error: pfError } = await supabase
    .from("female_profiles")
    .select("*")
    .eq("approval_status", "pending")
    .eq("account_status", "active");

  if (pfError) {
    console.error("Error fetching pending female profiles:", pfError);
    results.errors.push(`Error fetching pending female profiles: ${pfError.message}`);
  }

  console.log(`Found ${pendingFemales?.length || 0} pending female profiles in female_profiles table`);

  // STEP 2: Get all language groups
  const { data: languageGroups, error: lgError } = await supabase
    .from("language_groups")
    .select("*")
    .eq("is_active", true);

  if (lgError) {
    console.error("Error fetching language groups:", lgError);
  }

  console.log(`Found ${languageGroups?.length || 0} active language groups`);

  // STEP 3: Auto-approve ALL pending females (no restrictions)
  for (const woman of (pendingFemales || []) as FemaleProfile[]) {
    console.log(`Processing pending user: ${woman.full_name || woman.user_id}, language: ${woman.primary_language}`);

    // Find matching language group (optional, for tracking)
    let matchedGroup: LanguageGroup | null = null;
    
    for (const group of (languageGroups || []) as LanguageGroup[]) {
      if (matchesLanguageGroup(woman.primary_language, group.languages)) {
        matchedGroup = group;
        break;
      }
    }

    // Auto-approve the user - NO RESTRICTIONS
    const approvalData = {
      approval_status: "approved",
      ai_approved: true,
      auto_approved: true,
      ai_disapproval_reason: null,
      performance_score: 100,
      updated_at: new Date().toISOString(),
    };

    // Update female_profiles table
    const { error: updateError } = await supabase
      .from("female_profiles")
      .update(approvalData)
      .eq("id", woman.id);

    if (updateError) {
      console.error(`Error approving user ${woman.full_name}:`, updateError);
      results.errors.push(`Error approving ${woman.full_name}: ${updateError.message}`);
      continue;
    }

    // Also update profiles table if exists
    await supabase
      .from("profiles")
      .update({
        approval_status: "approved",
        ai_approved: true,
        ai_disapproval_reason: null,
        performance_score: 100,
        updated_at: new Date().toISOString(),
      })
      .eq("user_id", woman.user_id);

    // Insert into women_availability table for the approved woman
    const { error: availError } = await supabase
      .from("women_availability")
      .upsert({
        user_id: woman.user_id,
        is_available: false,
        is_available_for_calls: false,
        current_chat_count: 0,
        current_call_count: 0,
        max_concurrent_chats: 3,
        max_concurrent_calls: 1,
        last_activity_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }, { onConflict: 'user_id' });

    if (availError) {
      console.error(`Error creating women_availability for ${woman.full_name}:`, availError);
    } else {
      console.log(`✓ Created women_availability entry for ${woman.full_name}`);
    }

    if (matchedGroup) {
      // Increment group count
      await supabase
        .from("language_groups")
        .update({ 
          current_women_count: matchedGroup.current_women_count + 1,
          updated_at: new Date().toISOString(),
        })
        .eq("id", matchedGroup.id);

      console.log(`✓ AI approved ${woman.full_name} for language group: ${matchedGroup.name}`);
    } else {
      results.noLanguageGroupApproved++;
      console.log(`✓ AI approved ${woman.full_name} (no specific language group, using global)`);
    }

    results.approved++;
  }

  // STEP 4: Also check profiles table for female users with pending status
  const { data: pendingProfileFemales, error: ppfError } = await supabase
    .from("profiles")
    .select("*")
    .eq("gender", "female")
    .eq("approval_status", "pending")
    .eq("account_status", "active");

  if (!ppfError && pendingProfileFemales) {
    console.log(`Found ${pendingProfileFemales.length} additional pending females in profiles table`);

    for (const woman of pendingProfileFemales) {
      // Check if already approved in female_profiles
      const { data: existingFp } = await supabase
        .from("female_profiles")
        .select("id, approval_status")
        .eq("user_id", woman.user_id)
        .maybeSingle();

      if (existingFp?.approval_status === "approved") {
        // Sync the status
        await supabase
          .from("profiles")
          .update({
            approval_status: "approved",
            ai_approved: true,
            updated_at: new Date().toISOString(),
          })
          .eq("id", woman.id);
        continue;
      }

      // Find matching language group
      let matchedGroup: LanguageGroup | null = null;
      
      for (const group of (languageGroups || []) as LanguageGroup[]) {
        if (matchesLanguageGroup(woman.primary_language, group.languages)) {
          matchedGroup = group;
          break;
        }
      }

      // Auto-approve - NO RESTRICTIONS
      const { error: updateError } = await supabase
        .from("profiles")
        .update({
          approval_status: "approved",
          ai_approved: true,
          ai_disapproval_reason: null,
          performance_score: 100,
          updated_at: new Date().toISOString(),
        })
        .eq("id", woman.id);

      if (updateError) {
        console.error(`Error approving profile ${woman.full_name}:`, updateError);
        continue;
      }

      // Also update female_profiles if exists
      if (existingFp) {
        await supabase
          .from("female_profiles")
          .update({
            approval_status: "approved",
            ai_approved: true,
            auto_approved: true,
            ai_disapproval_reason: null,
            performance_score: 100,
            updated_at: new Date().toISOString(),
          })
          .eq("id", existingFp.id);
      }

      // Insert into women_availability table
      const { error: availError } = await supabase
        .from("women_availability")
        .upsert({
          user_id: woman.user_id,
          is_available: false,
          is_available_for_calls: false,
          current_chat_count: 0,
          current_call_count: 0,
          max_concurrent_chats: 3,
          max_concurrent_calls: 1,
          last_activity_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        }, { onConflict: 'user_id' });

      if (availError) {
        console.error(`Error creating women_availability for profile ${woman.full_name}:`, availError);
      } else {
        console.log(`✓ Created women_availability entry for profile ${woman.full_name}`);
      }

      if (matchedGroup) {
        await supabase
          .from("language_groups")
          .update({ 
            current_women_count: matchedGroup.current_women_count + 1,
            updated_at: new Date().toISOString(),
          })
          .eq("id", matchedGroup.id);
      }

      results.approved++;
      console.log(`✓ AI approved (from profiles) ${woman.full_name}`);
    }
  }

  // STEP 5: Process existing approved women for rotation (30-day inactivity check)
  await processApprovedWomenRotation(supabase, languageGroups || [], results);

  // STEP 6: Auto-reactivate users who were inactive but are now active again
  await processInactiveReactivation(supabase, results);

  // STEP 7: Assign earning slots to Indian women based on language limits
  // This uses the database function that respects limits and first-registered priority
  const earningSlotResult = await assignEarningSlots(supabase);
  console.log("Earning slot assignment result:", earningSlotResult);

  console.log("AI Women Auto-Approval Process completed:", results);

  return new Response(
    JSON.stringify({
      success: true,
      message: "AI Women Auto-Approval process completed",
      results: {
        ...results,
        earningSlots: earningSlotResult
      }
    }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
}

/**
 * Check and rotate out women who have been inactive for 30+ days
 */
async function processApprovedWomenRotation(supabase: any, languageGroups: LanguageGroup[], results: any) {
  try {
    // Get all approved women
    const { data: approvedWomen } = await supabase
      .from("female_profiles")
      .select("*")
      .eq("approval_status", "approved")
      .eq("account_status", "active");

    if (!approvedWomen) return;

    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    for (const woman of approvedWomen as FemaleProfile[]) {
      const lastActive = woman.last_active_at ? new Date(woman.last_active_at) : null;
      
      // Mark as inactive if offline for more than 30 days
      // They can request re-approval to come back
      if (lastActive && lastActive < thirtyDaysAgo) {
        await supabase
          .from("female_profiles")
          .update({
            approval_status: "inactive",
            ai_approved: false,
            ai_disapproval_reason: "Inactive for more than 30 days. Request re-approval to continue.",
            updated_at: new Date().toISOString(),
          })
          .eq("id", woman.id);

        // Sync to profiles
        await supabase
          .from("profiles")
          .update({
            approval_status: "inactive",
            ai_approved: false,
            ai_disapproval_reason: "Inactive for more than 30 days. Request re-approval to continue.",
            updated_at: new Date().toISOString(),
          })
          .eq("user_id", woman.user_id);

        results.rotatedOut++;
        console.log(`Marked ${woman.full_name} as inactive - 30+ days without activity`);
        continue;
      }

      // Performance check is now more lenient - only warn, don't disapprove
      if (woman.performance_score < 30) {
        console.log(`Warning: ${woman.full_name} has low performance: ${woman.performance_score}/100`);
        // Just log warning, don't disapprove
      }

      results.retained++;
    }
  } catch (error) {
    console.error("Error in rotation process:", error);
    results.errors.push(`Rotation error: ${error}`);
  }
}

/**
 * Automatically reactivate users who were marked inactive but have shown recent activity
 */
async function processInactiveReactivation(supabase: any, results: any) {
  try {
    // Get all inactive women
    const { data: inactiveWomen } = await supabase
      .from("female_profiles")
      .select("*")
      .eq("approval_status", "inactive")
      .eq("account_status", "active");

    if (!inactiveWomen || inactiveWomen.length === 0) return;

    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    for (const woman of inactiveWomen as FemaleProfile[]) {
      const lastActive = woman.last_active_at ? new Date(woman.last_active_at) : null;
      
      // If they've been active in the last 7 days, auto-reactivate them
      if (lastActive && lastActive > sevenDaysAgo) {
        await supabase
          .from("female_profiles")
          .update({
            approval_status: "approved",
            ai_approved: true,
            ai_disapproval_reason: null,
            performance_score: Math.max(woman.performance_score, 70), // Restore to at least 70
            updated_at: new Date().toISOString(),
          })
          .eq("id", woman.id);

        await supabase
          .from("profiles")
          .update({
            approval_status: "approved",
            ai_approved: true,
            ai_disapproval_reason: null,
            performance_score: Math.max(woman.performance_score, 70),
            updated_at: new Date().toISOString(),
          })
          .eq("user_id", woman.user_id);

        // Ensure women_availability exists
        await supabase
          .from("women_availability")
          .upsert({
            user_id: woman.user_id,
            is_available: false,
            is_available_for_calls: false,
            current_chat_count: 0,
            current_call_count: 0,
            max_concurrent_chats: 3,
            max_concurrent_calls: 1,
            last_activity_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          }, { onConflict: 'user_id' });

        results.reactivated++;
        console.log(`✓ Auto-reactivated ${woman.full_name} - recent activity detected`);
      }
    }
  } catch (error) {
    console.error("Error in reactivation process:", error);
    results.errors.push(`Reactivation error: ${error}`);
  }
}

/**
 * Assign earning slots to Indian women based on language limits
 * Only Indian women can earn, respecting max_earning_women per language
 * Priority: first registered (created_at ASC)
 */
async function assignEarningSlots(supabase: any) {
  console.log("Starting earning slot assignment...");
  
  const results = {
    slotsAssigned: 0,
    languagesProcessed: 0,
    errors: [] as string[]
  };

  try {
    // Get all active language limits
    const { data: languageLimits, error: llError } = await supabase
      .from("language_limits")
      .select("*")
      .eq("is_active", true);

    if (llError) {
      console.error("Error fetching language limits:", llError);
      results.errors.push(`Language limits error: ${llError.message}`);
      return results;
    }

    // First, reset all earning slots
    await supabase
      .from("female_profiles")
      .update({
        is_earning_eligible: false,
        earning_slot_assigned_at: null,
        earning_badge_type: null
      })
      .eq("is_earning_eligible", true);

    await supabase
      .from("profiles")
      .update({
        is_earning_eligible: false,
        earning_slot_assigned_at: null,
        earning_badge_type: null
      })
      .eq("is_earning_eligible", true);

    // Reset language_limits current_earning_women counts
    await supabase
      .from("language_limits")
      .update({
        current_earning_women: 0,
        updated_at: new Date().toISOString()
      });

    // For each language, assign slots to Indian women (first registered priority)
    for (const langLimit of (languageLimits || []) as LanguageLimit[]) {
      console.log(`Processing language: ${langLimit.language_name}, max slots: ${langLimit.max_earning_women}`);

      // Get Indian women for this language, ordered by created_at (first registered first)
      const { data: indianWomen, error: iwError } = await supabase
        .from("female_profiles")
        .select("id, user_id, full_name, primary_language, created_at, country")
        .eq("country", "India")
        .eq("approval_status", "approved")
        .eq("account_status", "active")
        .ilike("primary_language", langLimit.language_name)
        .order("created_at", { ascending: true })
        .limit(langLimit.max_earning_women);

      if (iwError) {
        console.error(`Error fetching Indian women for ${langLimit.language_name}:`, iwError);
        results.errors.push(`Error for ${langLimit.language_name}: ${iwError.message}`);
        continue;
      }

      let assignedCount = 0;
      for (const woman of (indianWomen || [])) {
        // Assign earning slot with star badge
        const { error: updateError } = await supabase
          .from("female_profiles")
          .update({
            is_earning_eligible: true,
            is_indian: true,
            earning_slot_assigned_at: new Date().toISOString(),
            earning_badge_type: "star",
            updated_at: new Date().toISOString()
          })
          .eq("id", woman.id);

        if (updateError) {
          console.error(`Error assigning slot to ${woman.full_name}:`, updateError);
          continue;
        }

        // Sync to profiles table
        await supabase
          .from("profiles")
          .update({
            is_earning_eligible: true,
            is_indian: true,
            earning_slot_assigned_at: new Date().toISOString(),
            earning_badge_type: "star",
            updated_at: new Date().toISOString()
          })
          .eq("user_id", woman.user_id);

        assignedCount++;
        results.slotsAssigned++;
        console.log(`✓ Assigned earning slot to ${woman.full_name} (${langLimit.language_name})`);
      }

      // Update language limit current count
      await supabase
        .from("language_limits")
        .update({
          current_earning_women: assignedCount,
          updated_at: new Date().toISOString()
        })
        .eq("id", langLimit.id);

      results.languagesProcessed++;
      console.log(`Completed ${langLimit.language_name}: ${assignedCount}/${langLimit.max_earning_women} slots assigned`);
    }

    // Mark all other Indian women as is_indian but not earning eligible
    await supabase
      .from("female_profiles")
      .update({ is_indian: true })
      .eq("country", "India")
      .is("is_indian", null);

    await supabase
      .from("profiles")
      .update({ is_indian: true })
      .eq("country", "India")
      .eq("gender", "female")
      .is("is_indian", null);

    console.log("Earning slot assignment completed:", results);
    return results;

  } catch (error: any) {
    console.error("Error in earning slot assignment:", error);
    results.errors.push(`General error: ${error?.message || error}`);
    return results;
  }
}
