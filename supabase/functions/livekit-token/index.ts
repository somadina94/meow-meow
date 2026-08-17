// LiveKit JWT minting edge function.
//
// Self-hosted LiveKit Server reads its API_KEY/API_SECRET from your VPS
// config. The same values must be added as Lovable secrets so this
// function can sign access tokens.
//
// Required runtime secrets:
//   LIVEKIT_API_KEY
//   LIVEKIT_API_SECRET
//   LIVEKIT_WS_URL   e.g. wss://livekit.yourdomain.com
//
// Endpoint: POST { room, identity, name?, can_publish? }
// Response: { token, ws_url, room, identity, expires_at }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
import { AccessToken } from "https://esm.sh/livekit-server-sdk@2.7.2";
import { z } from "https://esm.sh/zod@3.23.8";

const BodySchema = z.object({
  room: z.string().min(1).max(64),
  identity: z.string().min(1).max(64),
  name: z.string().max(64).optional(),
  can_publish: z.boolean().optional().default(true),
});

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  try {
    // Auth: only signed-in users may mint tokens.
    const auth = req.headers.get("Authorization");
    if (!auth) return json({ error: "unauthorized" }, 401);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: auth } } },
    );
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return json({ error: "unauthorized" }, 401);

    const apiKey = Deno.env.get("LIVEKIT_API_KEY");
    const apiSecret = Deno.env.get("LIVEKIT_API_SECRET");
    const wsUrl = Deno.env.get("LIVEKIT_WS_URL");
    if (!apiKey || !apiSecret || !wsUrl) {
      return json({ error: "livekit_not_configured" }, 500);
    }

    const parsed = BodySchema.safeParse(await req.json());
    if (!parsed.success) {
      return json({ error: parsed.error.flatten().fieldErrors }, 400);
    }
    const { room, identity, name, can_publish } = parsed.data;

    // Identity must equal the auth uid — prevents impersonation.
    if (identity !== user.id) {
      return json({ error: "identity_mismatch" }, 403);
    }

    const ttlSec = 60 * 60; // 1h
    const at = new AccessToken(apiKey, apiSecret, {
      identity,
      name,
      ttl: ttlSec,
    });
    at.addGrant({
      room,
      roomJoin: true,
      canPublish: can_publish,
      canSubscribe: true,
      canPublishData: true,
    });

    const token = await at.toJwt();
    return json({
      token,
      ws_url: wsUrl,
      room,
      identity,
      expires_at: Math.floor(Date.now() / 1000) + ttlSec,
    });
  } catch (e) {
    console.error("[livekit-token] error", e);
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
