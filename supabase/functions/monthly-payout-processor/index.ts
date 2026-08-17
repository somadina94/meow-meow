// Monthly Wallet & Payout Processor
// Runs daily via cron at 00:00 IST (= 18:30 UTC previous day).
// Only executes the monthly cycle if today (in IST) is the 1st.
// Spec: capture women payouts from KYC (single source of truth), reset wallets, generate men's carry-forward statements.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Parse request to allow ?force=true for manual admin triggers
    const url = new URL(req.url);
    const force =
      url.searchParams.get("force") === "true" ||
      (req.headers.get("x-force-run") === "true");

    // Audit Issue #15: force=true must be admin-authenticated to prevent
    // anyone from prematurely closing the month.
    if (force) {
      const authHeader = req.headers.get("Authorization") ?? "";
      if (!authHeader.startsWith("Bearer ")) {
        return new Response(JSON.stringify({ success: false, error: "Unauthorized" }),
          { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const userClient = createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_ANON_KEY") ?? "",
        { global: { headers: { Authorization: authHeader } } },
      );
      const { data: { user } } = await userClient.auth.getUser();
      if (!user) {
        return new Response(JSON.stringify({ success: false, error: "Unauthorized" }),
          { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const { data: role } = await supabase.from("user_roles")
        .select("role").eq("user_id", user.id).eq("role", "admin").maybeSingle();
      if (!role) {
        return new Response(JSON.stringify({ success: false, error: "Admin only" }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
    }

    // Compute today's date in IST
    const istNow = new Date(
      new Date().toLocaleString("en-US", { timeZone: "Asia/Kolkata" }),
    );
    const istDay = istNow.getDate();

    if (!force && istDay !== 1) {
      return new Response(
        JSON.stringify({
          skipped: true,
          reason: `Not the 1st of month in IST (today is ${istDay})`,
          ist_date: istNow.toISOString(),
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        },
      );
    }


    // Run the canonical monthly payout RPC
    const { data, error } = await supabase.rpc("process_monthly_payout");

    if (error) {
      console.error("[monthly-payout-processor] RPC error:", error);
      return new Response(
        JSON.stringify({ success: false, error: error.message }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 500,
        },
      );
    }

    console.log("[monthly-payout-processor] Success:", JSON.stringify(data));

    // Archive a timestamped Excel snapshot to storage (never overwrites)
    let archive: { path?: string; error?: string } = {};
    try {
      const XLSX = await import("https://esm.sh/xlsx@0.18.5");
      const istNow = new Date(new Date().toLocaleString("en-US", { timeZone: "Asia/Kolkata" }));
      const pad = (n: number) => String(n).padStart(2, "0");
      const stamp = `${istNow.getFullYear()}-${pad(istNow.getMonth() + 1)}-${pad(istNow.getDate())}_${pad(istNow.getHours())}-${pad(istNow.getMinutes())}-${pad(istNow.getSeconds())}`;
      const monthKey = `${istNow.getFullYear()}-${pad(istNow.getMonth() + 1)}`;
      const filename = `payout-${stamp}.xlsx`;

      // Pull this month's snapshot rows
      const { data: snaps } = await supabase
        .from("women_payout_snapshots")
        .select("app_sno, beneficiary_purpose, account_holder_name, full_name, mobile_number, email_address, address, bank_account_number, ifsc_code, upi_vpa, wallet_balance_at_snapshot, ist_month, ist_year, snapshot_ist_date")
        .eq("ist_month", String(istNow.getMonth() + 1).padStart(2, "0"))
        .eq("ist_year", istNow.getFullYear())
        .order("app_sno", { ascending: true });

      const rows = (snaps || []).map((r: any, i: number) => [
        r.app_sno ?? i + 1,
        r.beneficiary_purpose || "Earnings Payout",
        r.account_holder_name || r.full_name || "—",
        r.mobile_number || "—",
        r.email_address || "—",
        r.address || "—",
        r.bank_account_number || "—",
        r.ifsc_code || "—",
        r.upi_vpa || "—",
        Number(r.wallet_balance_at_snapshot || 0).toFixed(2),
      ]);
      const total = (snaps || []).reduce((s: number, r: any) => s + Number(r.wallet_balance_at_snapshot || 0), 0);
      const headers = ["Beneficiary ID / S.No","Beneficiary Purpose","Name","Phone Number","Email ID","Address","Account Number","IFSC Code","UPI VPA","Amount (₹)"];
      const wsData = [
        ["Payout Statement (Auto — Monthly)"],
        [`Period: ${monthKey}`, "", "Currency: INR", "", `Women: ${rows.length}`, "", `Total: ₹${total.toFixed(2)}`, "", `Generated (IST): ${stamp}`],
        [],
        headers,
        ...rows,
      ];
      const ws = XLSX.utils.aoa_to_sheet(wsData);
      const wb = XLSX.utils.book_new();
      XLSX.utils.book_append_sheet(wb, ws, "Payouts");
      const buf = XLSX.write(wb, { bookType: "xlsx", type: "array" }) as ArrayBuffer;

      const path = `${monthKey}/${filename}`;
      const { error: upErr } = await supabase.storage
        .from("payout-exports")
        .upload(path, new Blob([buf], { type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" }), { upsert: false });
      if (upErr) archive = { error: upErr.message };
      else archive = { path };
    } catch (xe) {
      archive = { error: xe instanceof Error ? xe.message : String(xe) };
      console.error("[monthly-payout-processor] archive failed:", xe);
    }

    return new Response(
      JSON.stringify({ success: true, result: data, archive }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      },
    );
  } catch (e) {
    console.error("[monthly-payout-processor] Fatal error:", e);
    return new Response(
      JSON.stringify({
        success: false,
        error: e instanceof Error ? e.message : String(e),
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      },
    );
  }
});
