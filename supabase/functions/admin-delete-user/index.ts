import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Tables keyed by user_id that we want to wipe on full deletion
const USER_ID_TABLES = [
  "absence_records", "attendance", "chat_wait_queue", "female_profiles",
  "group_memberships", "group_session_extensions", "group_video_access",
  "male_profiles", "matches", "message_reactions",
  "monthly_statements", "monthly_wallet_summary", "notifications",
  "password_reset_tokens", "pending_recharges",
  "policy_violation_alerts", "processing_logs", "public_female_profiles",
  "push_subscriptions", "rate_limit_tracking", "tutorial_progress",
  "user_consent", "user_friends", "user_languages", "user_photos",
  "user_roles", "user_service_roles", "user_settings", "user_status",
  "user_warnings", "users_wallet", "wallet_recharges", "wallet_transactions",
  "wallets", "withdrawal_requests", "women_availability", "women_chat_modes",
  "women_kyc", "women_payout_snapshots",
];

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const token = authHeader.replace("Bearer ", "");
    const { data: { user: caller } } = await supabaseAdmin.auth.getUser(token);
    if (!caller) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const { selfDelete } = body;
    const user_id = body.userId || body.user_id;

    if (!user_id) {
      return new Response(JSON.stringify({ error: "userId is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const isSelfDelete = selfDelete === true && user_id === caller.id;

    if (!isSelfDelete) {
      const { data: roleData } = await supabaseAdmin
        .from("user_roles")
        .select("role")
        .eq("user_id", caller.id)
        .eq("role", "admin")
        .maybeSingle();

      if (!roleData) {
        return new Response(JSON.stringify({ error: "Admin access required" }), {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    // Prevent deleting protected admin accounts
    const { data: targetUser } = await supabaseAdmin.auth.admin.getUserById(user_id);
    if (targetUser?.user) {
      const email = targetUser.user.email || "";
      const protectedPattern = /^admin([1-9]|1[0-5])@meow-meow\.com$/;
      if (protectedPattern.test(email)) {
        return new Response(JSON.stringify({ error: "Cannot delete protected admin account" }), {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    // 1. Wipe all user-owned rows across known tables (service role bypasses RLS)
    const cleanupErrors: string[] = [];
    await Promise.all(
      USER_ID_TABLES.map(async (table) => {
        const { error } = await supabaseAdmin.from(table).delete().eq("user_id", user_id);
        if (error && !error.message?.toLowerCase().includes("does not exist")) {
          cleanupErrors.push(`${table}: ${error.message}`);
        }
      })
    );

    // 2. Special two-column tables
    await Promise.all([
      supabaseAdmin.from("user_friends").delete().eq("friend_id", user_id),
      supabaseAdmin.from("user_blocks").delete().eq("blocked_by", user_id),
      supabaseAdmin.from("user_blocks").delete().eq("blocked_user_id", user_id),
      supabaseAdmin.from("matches").delete().eq("matched_user_id", user_id),
    ]);

    // 3. Delete the public profile row last
    await supabaseAdmin.from("profiles").delete().eq("user_id", user_id);

    // 4. Delete the auth user
    const { error } = await supabaseAdmin.auth.admin.deleteUser(user_id);
    if (error) {
      console.error("Error deleting auth user:", error);
      return new Response(JSON.stringify({
        error: error.message,
        cleanupErrors,
      }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({
      success: true,
      cleanupErrors: cleanupErrors.length ? cleanupErrors : undefined,
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("Unexpected error:", err);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
