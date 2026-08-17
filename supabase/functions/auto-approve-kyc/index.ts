/**
 * Auto Approve KYC Edge Function
 * 
 * Admin-only function that validates and approves pending KYC submissions.
 * Each record is individually validated for completeness before approval.
 * Incomplete records are rejected with a specific reason.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version",
};

interface KYCRecord {
  id: string;
  user_id: string;
  full_name_as_per_bank: string | null;
  date_of_birth: string | null;
  id_type: string | null;
  id_number: string | null;
  bank_name: string | null;
  account_number: string | null;
  account_holder_name: string | null;
  ifsc_code: string | null;
  consent_given: boolean;
  consent_timestamp: string | null;
  selfie_url: string | null;
  aadhaar_front_url: string | null;
  aadhaar_back_url: string | null;
  id_proof_front_url: string | null;
  mobile_number: string | null;
  email_address: string | null;
  verification_status: string;
}

// Required text fields that must be non-empty
const REQUIRED_TEXT_FIELDS: (keyof KYCRecord)[] = [
  "full_name_as_per_bank",
  "date_of_birth",
  "id_type",
  "id_number",
  "bank_name",
  "account_number",
  "account_holder_name",
  "ifsc_code",
];

// At least one document proof must be present
const DOCUMENT_URL_FIELDS: (keyof KYCRecord)[] = [
  "aadhaar_front_url",
  "id_proof_front_url",
];

function validateKYCRecord(kyc: KYCRecord): { valid: boolean; reasons: string[] } {
  const reasons: string[] = [];

  // Check required text fields
  for (const field of REQUIRED_TEXT_FIELDS) {
    const value = kyc[field];
    if (!value || (typeof value === "string" && value.trim() === "")) {
      reasons.push(`Missing required field: ${field.replace(/_/g, " ")}`);
    }
  }

  // Check consent
  if (!kyc.consent_given) {
    reasons.push("Declaration consent not given");
  }
  if (!kyc.consent_timestamp) {
    reasons.push("Missing consent timestamp");
  }

  // Check at least one identity document uploaded
  const hasDocument = DOCUMENT_URL_FIELDS.some(
    (field) => kyc[field] && typeof kyc[field] === "string" && (kyc[field] as string).trim() !== ""
  );
  if (!hasDocument) {
    reasons.push("No identity document uploaded (Aadhaar front or ID proof front required)");
  }

  // Check selfie uploaded
  if (!kyc.selfie_url || kyc.selfie_url.trim() === "") {
    reasons.push("Selfie not uploaded");
  }

  // Validate IFSC format (Indian bank code: 4 letters + 0 + 6 alphanumeric)
  if (kyc.ifsc_code && !/^[A-Z]{4}0[A-Z0-9]{6}$/i.test(kyc.ifsc_code.trim())) {
    reasons.push("Invalid IFSC code format");
  }

  // Validate account number (numeric, 8-18 digits)
  if (kyc.account_number && !/^\d{8,18}$/.test(kyc.account_number.trim())) {
    reasons.push("Invalid account number format (must be 8-18 digits)");
  }

  return { valid: reasons.length === 0, reasons };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Auth guard: require admin role via proper JWT validation
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const token = authHeader.replace("Bearer ", "");

    const authClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user: caller }, error: authError } = await authClient.auth.getUser(token);
    if (authError || !caller) {
      return new Response(JSON.stringify({ success: false, error: "Invalid token" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: roleData } = await supabase
      .from("user_roles").select("role")
      .eq("user_id", caller.id).eq("role", "admin").maybeSingle();
    if (!roleData) {
      return new Response(JSON.stringify({ success: false, error: "Admin access required" }), {
        status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Parse optional request body for single-user approval
    let targetUserId: string | null = null;
    try {
      const body = await req.json();
      targetUserId = body?.user_id || null;
    } catch {
      // No body, process all pending
    }

    console.log(`[Auto-Approve-KYC] Admin ${caller.id} initiated KYC review${targetUserId ? ` for user ${targetUserId}` : " (all pending)"}`);

    // Fetch pending KYC records with all fields needed for validation
    let query = supabase
      .from("women_kyc")
      .select("id, user_id, full_name_as_per_bank, date_of_birth, id_type, id_number, bank_name, account_number, account_holder_name, ifsc_code, consent_given, consent_timestamp, selfie_url, aadhaar_front_url, aadhaar_back_url, id_proof_front_url, mobile_number, email_address, verification_status")
      .eq("verification_status", "pending");

    if (targetUserId) {
      query = query.eq("user_id", targetUserId);
    }

    const { data: pendingKYCs, error: fetchError } = await query;

    if (fetchError) {
      console.error("[Auto-Approve-KYC] Error fetching pending KYCs:", fetchError);
      throw fetchError;
    }

    if (!pendingKYCs || pendingKYCs.length === 0) {
      return new Response(
        JSON.stringify({ success: true, message: "No pending KYC records to review", approved: 0, rejected: 0 }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`[Auto-Approve-KYC] Found ${pendingKYCs.length} pending KYC records to review.`);

    const approved: string[] = [];
    const rejected: { user_id: string; reasons: string[] }[] = [];
    const errors: string[] = [];
    const now = new Date().toISOString();

    for (const kyc of pendingKYCs as KYCRecord[]) {
      const { valid, reasons } = validateKYCRecord(kyc);

      if (valid) {
        // Approve this record
        const { error: updateError } = await supabase
          .from("women_kyc")
          .update({
            verification_status: "approved",
            verified_at: now,
            verified_by: caller.id,
            rejection_reason: null,
            updated_at: now,
          })
          .eq("id", kyc.id);

        if (updateError) {
          errors.push(`Failed to approve KYC ${kyc.id}: ${updateError.message}`);
          continue;
        }

        // Update is_verified on profile tables
        await supabase
          .from("female_profiles")
          .update({ is_verified: true, updated_at: now })
          .eq("user_id", kyc.user_id);

        await supabase
          .from("profiles")
          .update({ is_verified: true, updated_at: now })
          .eq("user_id", kyc.user_id);

        approved.push(kyc.user_id);
        console.log(`[Auto-Approve-KYC] ✓ Approved KYC for user ${kyc.user_id} (${kyc.full_name_as_per_bank})`);
      } else {
        // Reject with specific reasons
        const rejectionReason = reasons.join("; ");
        const { error: rejectError } = await supabase
          .from("women_kyc")
          .update({
            verification_status: "rejected",
            rejection_reason: rejectionReason,
            verified_by: caller.id,
            updated_at: now,
          })
          .eq("id", kyc.id);

        if (rejectError) {
          errors.push(`Failed to reject KYC ${kyc.id}: ${rejectError.message}`);
          continue;
        }

        rejected.push({ user_id: kyc.user_id, reasons });
        console.log(`[Auto-Approve-KYC] ✗ Rejected KYC for user ${kyc.user_id}: ${rejectionReason}`);
      }
    }

    // Audit log
    await supabase.from("audit_logs").insert({
      admin_id: caller.id,
      action: "kyc_batch_review",
      action_type: "update",
      resource_type: "women_kyc",
      details: `Reviewed ${pendingKYCs.length} KYC records: ${approved.length} approved, ${rejected.length} rejected`,
      status: errors.length > 0 ? "partial" : "success",
    });

    return new Response(
      JSON.stringify({
        success: true,
        message: `Reviewed ${pendingKYCs.length} KYC records`,
        approved: approved.length,
        rejected: rejected.length,
        rejected_details: rejected,
        errors,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("[Auto-Approve-KYC] Error:", error);
    return new Response(
      JSON.stringify({ success: false, error: error instanceof Error ? error.message : "Unknown error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
