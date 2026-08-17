// Razorpay webhook: server-to-server payment confirmation as a safety net.
// Credits the NET wallet_amount stored in order notes (not the gross charged).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const GATEWAY_FEE_RATE = 0.03;
const enc = new TextEncoder();
const r2 = (n: number) => Math.round(n * 100) / 100;

async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(message));
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

  const SECRET = Deno.env.get("RAZORPAY_WEBHOOK_SECRET");
  const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
  const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const KEY_ID = Deno.env.get("RAZORPAY_KEY_ID");
  const KEY_SECRET = Deno.env.get("RAZORPAY_KEY_SECRET");
  if (!SECRET || !SUPABASE_URL || !SERVICE_ROLE || !KEY_ID || !KEY_SECRET) {
    return new Response("Server not configured", { status: 500 });
  }

  const signature = req.headers.get("x-razorpay-signature") ?? "";
  const raw = await req.text();
  const expected = await hmacSha256Hex(SECRET, raw);
  if (expected !== signature) {
    console.warn("[razorpay-webhook] invalid signature");
    return new Response("Invalid signature", { status: 400 });
  }

  let evt: any;
  try { evt = JSON.parse(raw); } catch { return new Response("Bad JSON", { status: 400 }); }
  const event = String(evt.event ?? "");
  if (event !== "payment.captured" && event !== "order.paid") {
    return new Response("ignored", { status: 200 });
  }

  const payment = evt.payload?.payment?.entity;
  if (!payment) return new Response("No payment entity", { status: 200 });

  // Webhook payment notes may not include wallet_amount (Razorpay copies order
  // notes only sometimes), so always re-fetch the order to get the canonical net.
  const orderId = payment.order_id as string | undefined;
  let userId: string | undefined = payment.notes?.user_id;
  let walletINR: number | undefined;
  const grossINR = Number(payment.amount) / 100;

  if (orderId) {
    const auth = "Basic " + btoa(`${KEY_ID}:${KEY_SECRET}`);
    const orderRes = await fetch(`https://api.razorpay.com/v1/orders/${orderId}`, {
      headers: { Authorization: auth },
    });
    if (orderRes.ok) {
      const order = await orderRes.json() as { notes?: { user_id?: string; wallet_amount?: string } };
      userId ??= order.notes?.user_id;
      const w = Number(order.notes?.wallet_amount ?? "");
      if (Number.isFinite(w) && w > 0) walletINR = r2(w);
    }
  }
  // Fallback: derive net from gross.
  if (!walletINR) walletINR = r2(grossINR / (1 + GATEWAY_FEE_RATE));

  const paymentId = payment.id as string;
  if (!userId || walletINR <= 0 || !paymentId) {
    return new Response("Missing fields", { status: 200 });
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE);
  const { error } = await admin.rpc("ledger_recharge", {
    p_user_id: userId,
    p_amount: walletINR,
    p_gateway: "razorpay",
    p_gateway_txn_id: paymentId,
    p_description: `Razorpay webhook \u20b9${walletINR} (gross \u20b9${r2(grossINR)}) ${event} ${paymentId}`,
  });
  if (error) {
    const msg = error.message ?? "";
    if (msg.includes("duplicate") || msg.toLowerCase().includes("already")) {
      return new Response("already credited", { status: 200 });
    }
    console.error("[razorpay-webhook] ledger_recharge failed", msg);
    return new Response("ledger error", { status: 500 });
  }
  return new Response("ok", { status: 200 });
});
