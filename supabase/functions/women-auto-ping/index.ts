import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceKey);

    // 1. Get unrecharged men (balance <= 0)
    const { data: unrechargedMen, error: menErr } = await supabase.rpc("get_unrecharged_men");
    if (menErr) throw menErr;
    if (!unrechargedMen?.length) {
      return new Response(JSON.stringify({ message: "No unrecharged men found", sent: 0 }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Get online women (active in last 5 min)
    const { data: onlineWomen, error: owErr } = await supabase.rpc("get_online_women_for_ping");
    if (owErr) throw owErr;

    // 3. Get offline women for daily ping
    const { data: offlineWomen, error: ofwErr } = await supabase.rpc("get_offline_women_for_daily_ping");
    if (ofwErr) throw ofwErr;

    let totalSent = 0;

    // Process ONLINE women → ping every 20 min
    if (onlineWomen?.length) {
      for (const woman of onlineWomen) {
        const firstName = (woman.full_name || "Someone").split(" ")[0];
        const message = `Hello, my name is ${firstName}. Please recharge so that we can participate in chat, audio or video call and group call 💬🎥`;

        for (const man of unrechargedMen) {
          // Check if already pinged in last 20 min
          const { data: existing } = await supabase
            .from("women_auto_ping_log")
            .select("last_sent_at")
            .eq("woman_user_id", woman.user_id)
            .eq("man_user_id", man.user_id)
            .eq("ping_type", "online")
            .maybeSingle();

          if (existing) {
            const lastSent = new Date(existing.last_sent_at);
            const minutesAgo = (Date.now() - lastSent.getTime()) / 60000;
            if (minutesAgo < 20) continue; // Skip, too recent
          }

          // Generate chat_id
          const chatId = [woman.user_id, man.user_id].sort().join("_");

          // Send message
          await supabase.from("chat_messages").insert({
            chat_id: chatId,
            sender_id: woman.user_id,
            receiver_id: man.user_id,
            message,
          });

          // Upsert ping log
          await supabase.from("women_auto_ping_log").upsert(
            {
              woman_user_id: woman.user_id,
              man_user_id: man.user_id,
              ping_type: "online",
              last_sent_at: new Date().toISOString(),
            },
            { onConflict: "woman_user_id,man_user_id,ping_type" }
          );

          totalSent++;
        }
      }
    }

    // Process OFFLINE women → ping once per day
    if (offlineWomen?.length) {
      for (const woman of offlineWomen) {
        const firstName = (woman.full_name || "Someone").split(" ")[0];
        const message = `Hello, my name is ${firstName}. Please recharge so that we can participate in chat, audio or video call and group call 💬🎥`;

        for (const man of unrechargedMen) {
          // Check if already pinged today
          const { data: existing } = await supabase
            .from("women_auto_ping_log")
            .select("last_sent_at")
            .eq("woman_user_id", woman.user_id)
            .eq("man_user_id", man.user_id)
            .eq("ping_type", "offline")
            .maybeSingle();

          if (existing) {
            const lastSent = new Date(existing.last_sent_at);
            const hoursAgo = (Date.now() - lastSent.getTime()) / 3600000;
            if (hoursAgo < 24) continue; // Skip, already sent today
          }

          const chatId = [woman.user_id, man.user_id].sort().join("_");

          await supabase.from("chat_messages").insert({
            chat_id: chatId,
            sender_id: woman.user_id,
            receiver_id: man.user_id,
            message,
          });

          await supabase.from("women_auto_ping_log").upsert(
            {
              woman_user_id: woman.user_id,
              man_user_id: man.user_id,
              ping_type: "offline",
              last_sent_at: new Date().toISOString(),
            },
            { onConflict: "woman_user_id,man_user_id,ping_type" }
          );

          totalSent++;
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        sent: totalSent,
        onlineWomen: onlineWomen?.length || 0,
        offlineWomen: offlineWomen?.length || 0,
        unrechargedMen: unrechargedMen?.length || 0,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Auto-ping error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
