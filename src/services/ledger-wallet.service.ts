/**
 * Ledger Wallet Service
 *
 * Core billing engine for per-minute charging (chat, audio, video, group calls).
 * All financial operations are executed via atomic Supabase RPCs.
 *
 * NOTE: Pricing constants and SessionType have been removed from this module.
 * The single source of truth for pricing is the `chat_pricing` table, accessed
 * via `fetchUnifiedPricing()` / `useUnifiedPricing()` (see billing.service.ts).
 * Group call: men ₹4/min each, women earn ₹1/min per active man (no men = no earning).
 */

import { supabase } from '@/integrations/supabase/client';

// SessionType is re-exported from billing.service to keep a single canonical type.
export type { SessionType } from '@/services/billing.service';

// ──────────── Types ────────────
export interface BillingResult {
  success: boolean;
  charged?: number;
  earned?: number;
  minute_number?: number;
  error?: string;
  balance?: number;
  duplicate_skipped?: boolean;
}

export interface WalletBalance {
  balance: number;
  currency: string;
}

export interface StatementRow {
  id: string;
  session_id: string | null;
  session_type: string | null;
  transaction_type: string;
  debit: number;
  credit: number;
  description: string | null;
  reference_id: string | null;
  counterparty_id: string | null;
  running_balance: number;
  created_at: string;
  duration_seconds: number | null;
  rate_per_minute: number | null;
}

// ──────────── Billing ────────────
//
// Per-minute billing is performed exclusively by the canonical RPCs (Single
// Source of Truth — see mem://financial/single-source-of-truth):
//   • Chat   → `process_chat_billing`         (called via chat-manager edge fn)
//   • Audio  → `process_audio_billing`        (called from useP2PCall)
//   • Video  → `process_video_billing_v2`     (called from useP2PCall)
//   • Group  → `process_group_billing_v2`     (called from usePrivateGroupCall)
//
// The legacy client-side `billSession` / `billGroupCall` helpers (which used
// the non-canonical `ledger_bill_*` RPCs and double-wrote `women_earnings`)
// have been removed to enforce the SoT contract.


// ──────────── Wallet Operations ────────────

/** Get men's wallet balance */
export async function getMenBalance(userId: string): Promise<number> {
  const { data } = await supabase.rpc('get_men_wallet_balance', { p_user_id: userId });
  if (!data) return 0;
  return Number((data as Record<string, number>).balance) || 0;
}

/** Get women's wallet balance + today earnings */
export async function getWomenBalance(userId: string): Promise<{ balance: number; todayEarnings: number }> {
  const { data } = await supabase.rpc('get_women_wallet_balance', { p_user_id: userId });
  if (!data) return { balance: 0, todayEarnings: 0 };
  const d = data as Record<string, number>;
  return {
    balance: Number(d.available_balance) || 0,
    todayEarnings: Number(d.today_earnings) || 0,
  };
}

/** Recharge a man's wallet */
export async function rechargeWallet(userId: string, amount: number, referenceId: string, gateway: string): Promise<BillingResult> {
  const { data, error } = await supabase.rpc('ledger_recharge', {
    p_user_id: userId,
    p_amount: amount,
    p_reference_id: referenceId,
    p_gateway: gateway,
  });
  if (error) return { success: false, error: error.message };
  return (data as BillingResult) ?? { success: false, error: 'No response' };
}

// ──────────── Statements ────────────

/** Get ledger statement for a user (date range) */
export async function getStatement(userId: string, fromDate?: string, toDate?: string): Promise<StatementRow[]> {
  const { data, error } = await supabase.rpc('get_ledger_statement', {
    p_user_id: userId,
    p_from_date: fromDate || null,
    p_to_date: toDate || null,
  });
  if (error) throw error;
  if (!data) return [];
  return (data as unknown as StatementRow[]);
}

// ──────────── Payout ────────────

/** Trigger an on-demand payout snapshot (admin only) — captures all women's
 *  current wallet balance + Bank KYC details at the moment of click. */
export async function generatePayoutSnapshot(): Promise<{ success: boolean; count?: number; skipped?: number; error?: string }> {
  const { data, error } = await supabase.rpc('generate_payout_snapshot_now');
  if (error) return { success: false, error: error.message };
  const result = data as Record<string, unknown>;
  return {
    success: Boolean(result?.success),
    count: Number(result?.women_processed) || 0,
    skipped: Number(result?.women_skipped_no_kyc) || 0,
  };
}

/** Get payout snapshots */
export async function getPayoutSnapshots(month?: string) {
  let query = supabase
    .from('women_payout_snapshots')
    .select('*')
    .order('created_at', { ascending: false });
  if (month) {
    query = query.eq('ist_month', month);
  }
  const { data, error } = await query.limit(500);
  if (error) {
    console.error('[ledger] getPayoutSnapshots failed:', error);
    throw error;
  }
  return data || [];
}

// ──────────── Pricing Fetch ────────────

export interface ChatPricingData {
  ratePerMinute: number;
  womenEarningRate: number;
  audioRatePerMinute: number;
  audioWomenEarningRate: number;
  videoRatePerMinute: number;
  videoWomenEarningRate: number;
  groupCallRatePerMinute: number;
  groupCallWomenEarningRate: number;
  giftWomenPercent: number;
  withdrawalFeePercent: number;
  minWithdrawalBalance: number;
}

export async function fetchChatPricing(): Promise<ChatPricingData> {
  const { data } = await supabase
    .from('chat_pricing')
    .select('*')
    .eq('is_active', true)
    .limit(1)
    .single();

  if (!data) {
    // Fallback to spec defaults
    return {
      ratePerMinute: 4, womenEarningRate: 2,
      audioRatePerMinute: 6, audioWomenEarningRate: 3,
      videoRatePerMinute: 8, videoWomenEarningRate: 4,
      groupCallRatePerMinute: 4, groupCallWomenEarningRate: 1,
      giftWomenPercent: 50, withdrawalFeePercent: 5, minWithdrawalBalance: 5000,
    };
  }

  return {
    ratePerMinute: Number(data.rate_per_minute) || 4,
    womenEarningRate: Number(data.women_earning_rate) || 2,
    audioRatePerMinute: Number(data.audio_rate_per_minute) || 6,
    audioWomenEarningRate: Number(data.audio_women_earning_rate) || 3,
    videoRatePerMinute: Number(data.video_rate_per_minute) || 8,
    videoWomenEarningRate: Number(data.video_women_earning_rate) || 4,
    groupCallRatePerMinute: Number(data.group_call_rate_per_minute) || 4,
    groupCallWomenEarningRate: Number(data.group_call_women_earning_rate) || 1,
    giftWomenPercent: Number(data.gift_women_percent) || 50,
    withdrawalFeePercent: Number(data.withdrawal_fee_percent) || 5,
    minWithdrawalBalance: Number(data.min_withdrawal_balance) || 5000,
  };
}
