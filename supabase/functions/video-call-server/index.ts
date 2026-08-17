// VID-C-02: video-call-server edge function
// Handles video call initiation with eligibility checks and balance validation

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { corsHeaders } from "../_shared/cors.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Verify the calling user
    const anonClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: authError } = await anonClient.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ success: false, error: "Invalid auth" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Rate limiting
    const { data: allowed } = await supabase.rpc("check_rate_limit", {
      p_user_id: user.id,
      p_function_name: "video-call-server",
      p_max_requests: 5,
      p_window_seconds: 60,
    });
    if (allowed === false) {
      return new Response(JSON.stringify({ success: false, error: "Rate limited. Please wait." }), {
        status: 429,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const { action, callerId, receiverId } = body;

    if (action === "initiate") {
      if (!callerId || !receiverId) {
        return new Response(JSON.stringify({ success: false, error: "Missing callerId or receiverId" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // 1. Get video call rate
      const { data: pricing } = await supabase
        .from("chat_pricing")
        .select("video_rate_per_minute")
        .eq("is_active", true)
        .maybeSingle();
      const ratePerMinute = pricing?.video_rate_per_minute ?? 8;
      const minBalance = ratePerMinute * 2; // Need at least 2 minutes (₹16)

      // 2. Check caller's wallet balance
      const { data: wallet } = await supabase
        .from("users_wallet")
        .select("balance")
        .eq("user_id", callerId)
        .maybeSingle();
      const balance = wallet?.balance ?? 0;

      if (balance < minBalance) {
        return new Response(JSON.stringify({
          success: false,
          error: `Insufficient balance. You need at least ₹${minBalance} to start a video call.`,
          balance,
          required: minBalance,
        }), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // 3. Check receiver is available
      const { data: receiverStatus } = await supabase
        .from("women_availability")
        .select("is_available_for_calls")
        .eq("user_id", receiverId)
        .maybeSingle();

      if (receiverStatus && !receiverStatus.is_available_for_calls) {
        return new Response(JSON.stringify({
          success: false,
          error: "This user is currently not available for video calls.",
        }), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // 4. Check no existing active/ringing call between these users
      const { data: existingCall } = await supabase
        .from("video_call_sessions")
        .select("call_id")
        .or(`man_user_id.eq.${callerId},woman_user_id.eq.${callerId}`)
        .in("status", ["ringing", "active"])
        .maybeSingle();

      if (existingCall) {
        return new Response(JSON.stringify({
          success: false,
          error: "You already have an active or ringing call.",
        }), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // 5. Create the video call session with status=ringing
      const callId = `call_${callerId}_${Date.now()}`;
      const { data: session, error: insertError } = await supabase
        .from("video_call_sessions")
        .insert({
          call_id: callId,
          man_user_id: callerId,
          woman_user_id: receiverId,
          status: "ringing",
          rate_per_minute: ratePerMinute,
        })
        .select("id, call_id")
        .single();

      if (insertError) {
        console.error("Failed to create call session:", insertError);
        return new Response(JSON.stringify({ success: false, error: "Failed to create call" }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      return new Response(JSON.stringify({
        success: true,
        sessionId: session.id,
        call_id: session.call_id,
        ratePerMinute,
      }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ success: false, error: "Unknown action" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("video-call-server error:", err);
    return new Response(JSON.stringify({ success: false, error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
