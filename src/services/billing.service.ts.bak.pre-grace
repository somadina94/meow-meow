/**
 * billing.service.ts
 *
 * THE ONLY FILE that touches billing. No other file may call
 * bill_session_minute, bill_gift_or_tip, or modify wallets directly.
 *
 * Session types and their rates (read from DB, never hardcoded):
 *   chat               → chat_man_rate / chat_woman_rate
 *   audio_call         → audio_man_rate / audio_woman_rate
 *   video_call         → video_man_rate / video_woman_rate
 *   private_group_call → group_man_rate / group_woman_rate
 *                        (each active man pays group_man_rate; host earns
 *                         group_woman_rate per active man — spec ₹1/man/min)
 *   gift               → full price charged; gift_woman_pct% credited
 *   tip                → full amount charged; tip_woman_pct% credited
 */


import { supabase } from '@/integrations/supabase/client';

// ─── Types ──────────────────────────────────────────────────────────────

export type SessionType =
  | 'chat'
  | 'audio_call'
  | 'video_call'
  | 'private_group_call';

export interface UnifiedPricing {
  chat_man_rate: number;
  chat_woman_rate: number;
  audio_man_rate: number;
  audio_woman_rate: number;
  video_man_rate: number;
  video_woman_rate: number;
  group_man_rate: number;
  group_woman_rate: number;
  gift_woman_pct: number;
  tip_woman_pct: number;
  withdrawal_fee_pct: number;
  min_withdrawal_amount: number;
  currency: string;
}

export interface BillingResult {
  success: boolean;
  session_type?: SessionType;
  charged?: number;
  earned?: number;
  man_rate?: number;
  woman_rate?: number;
  minutes?: number;
  super_user_skip?: boolean;
  duplicate_skipped?: boolean;
  balance?: number;
  required?: number;
  error?: string;
}

export interface GiftTipResult {
  success: boolean;
  type?: 'gift' | 'tip';
  charged?: number;
  woman_credit?: number;
  woman_pct?: number;
  error?: string;
}

export interface ManBalance { balance: number; currency: string; }
export interface WomanBalance {
  available_balance: number;
  total_earned: number;
  paid_out: number;
  today_earnings: number;
  currency: string;
}

export interface StatementRow {
  statement_id: string;
  user_id: string;
  full_name: string;
  gender: 'male' | 'female';
  year: number;
  month: number;
  opening_balance: number;
  total_credit: number;
  total_debit: number;
  closing_balance: number;
  chat_amount: number;
  audio_call_amount: number;
  video_call_amount: number;
  group_call_amount: number;
  gift_amount: number;
  tip_amount: number;
  recharge_amount: number;
  payout_amount: number;
  payout_status: 'na' | 'pending' | 'approved' | 'paid' | 'rejected';
  pdf_url: string | null;
  excel_url: string | null;
  generated_at: string;
  paid_at: string | null;
}

export const PRICING_DEFAULTS: UnifiedPricing = {
  chat_man_rate: 4, chat_woman_rate: 2,
  audio_man_rate: 6, audio_woman_rate: 3,
  video_man_rate: 8, video_woman_rate: 4,
  group_man_rate: 4, group_woman_rate: 1,
  gift_woman_pct: 50, tip_woman_pct: 50,
  withdrawal_fee_pct: 5, min_withdrawal_amount: 5000,
  currency: 'INR',
};

// ─── Pricing ────────────────────────────────────────────────────────────

export async function fetchUnifiedPricing(): Promise<UnifiedPricing> {
  const { data, error } = await supabase.rpc('get_unified_pricing');
  if (error || !data) return PRICING_DEFAULTS;
  return data as unknown as UnifiedPricing;
}

export function minimumBalanceFor(sessionType: SessionType, pricing: UnifiedPricing): number {
  const rates: Record<SessionType, number> = {
    chat: pricing.chat_man_rate,
    audio_call: pricing.audio_man_rate,
    video_call: pricing.video_man_rate,
    private_group_call: pricing.group_man_rate,
  };
  return rates[sessionType] * 2;
}

// ─── Per-minute Billing ────────────────────────────────────────────────

/**
 * Pass `minuteIndex` (0,1,2,...) — the elapsed-minute counter for the session —
 * so the server can dedupe heartbeats deterministically.
 * Without it, the server falls back to wall-clock minute floor (less safe).
 */
export async function billMinute(
  sessionId: string, sessionType: SessionType, minutes: number,
  manId: string, womanId: string, manCount = 1, minuteIndex?: number,
): Promise<BillingResult> {
  const { data, error } = await supabase.rpc('bill_session_minute', {
    p_session_id: sessionId,
    p_session_type: sessionType,
    p_minutes: minutes,
    p_man_id: manId,
    p_woman_id: womanId,
    p_man_count: manCount,
    p_minute_index: minuteIndex ?? null,
  });
  if (error) return { success: false, error: error.message };
  return (data as unknown as BillingResult) ?? { success: false, error: 'No response' };
}

export const billChatMinute = (s: string, m: number, mid: string, wid: string, idx?: number) =>
  billMinute(s, 'chat', m, mid, wid, 1, idx);
export const billAudioCallMinute = (s: string, m: number, mid: string, wid: string, idx?: number) =>
  billMinute(s, 'audio_call', m, mid, wid, 1, idx);
export const billVideoCallMinute = (s: string, m: number, mid: string, wid: string, idx?: number) =>
  billMinute(s, 'video_call', m, mid, wid, 1, idx);
/** Group call: call ONCE PER ACTIVE MAN per heartbeat; woman earns per call. */
export const billGroupCallMinute = (s: string, m: number, mid: string, wid: string, idx?: number) =>
  billMinute(s, 'private_group_call', m, mid, wid, 1, idx);

/**
 * Final settlement at session end (or pause).
 *
 * Policy: ANY leftover seconds after the last full-minute heartbeat are
 * ROUNDED UP to a full chargeable minute. So a 1m12s session bills 2 min,
 * a 0m30s session bills 1 min, an exactly 1m00s session bills 1 min.
 *
 * Applies uniformly to chat, audio_call, video_call, private_group_call.
 *
 * Pass the TOTAL elapsed seconds since billing started (not the leftover).
 * Returns null only when elapsed lands exactly on a minute boundary
 * (leftover < 1s) so nothing extra needs charging.
 */
export const MIN_BILLABLE_SECONDS = 30;

export async function billFinalPartialMinute(
  sessionId: string,
  sessionType: SessionType,
  elapsedSeconds: number,
  manId: string,
  womanId: string,
  manCount = 1,
): Promise<BillingResult | null> {
  if (elapsedSeconds < 1) return null;
  const fullMinutesAlreadyBilled = Math.floor(elapsedSeconds / 60);
  const leftoverSec = elapsedSeconds - fullMinutesAlreadyBilled * 60;
  if (leftoverSec < 1 && fullMinutesAlreadyBilled >= 1) return null;
  // Grace: sub-30s sessions with zero full minutes billed are not charged
  // (covers network drops / accidental joins — audit Issue #14).
  if (fullMinutesAlreadyBilled === 0 && elapsedSeconds < MIN_BILLABLE_SECONDS) return null;
  return billMinute(
    sessionId, sessionType, 1.0,
    manId, womanId, manCount, fullMinutesAlreadyBilled,
  );
}


// ─── Gifts & Tips ──────────────────────────────────────────────────────

export async function sendGift(
  manId: string, womanId: string, giftPrice: number,
  description?: string, referenceId?: string,
): Promise<GiftTipResult> {
  const { data, error } = await supabase.rpc('bill_gift_or_tip', {
    p_man_id: manId, p_woman_id: womanId, p_amount: giftPrice,
    p_type: 'gift', p_description: description ?? null,
    p_reference_id: referenceId ?? null,
  });
  if (error) return { success: false, error: error.message };
  return (data as unknown as GiftTipResult) ?? { success: false, error: 'No response' };
}

export async function sendTip(
  manId: string, womanId: string, amount: number, description?: string,
): Promise<GiftTipResult> {
  const { data, error } = await supabase.rpc('bill_gift_or_tip', {
    p_man_id: manId, p_woman_id: womanId, p_amount: amount,
    p_type: 'tip', p_description: description ?? null, p_reference_id: null,
  });
  if (error) return { success: false, error: error.message };
  return (data as unknown as GiftTipResult) ?? { success: false, error: 'No response' };
}

// ─── Balances ──────────────────────────────────────────────────────────

export async function getManBalance(userId: string): Promise<number> {
  const { data } = await supabase.rpc('get_man_balance', { p_user_id: userId });
  if (!data) return 0;
  return Number((data as unknown as ManBalance).balance) || 0;
}

export async function getWomanBalance(userId: string): Promise<WomanBalance> {
  const { data } = await supabase.rpc('get_woman_balance', { p_user_id: userId });
  return (data as unknown as WomanBalance) ?? {
    available_balance: 0, total_earned: 0, paid_out: 0,
    today_earnings: 0, currency: 'INR',
  };
}

// ─── Admin: Statements & Payouts ──────────────────────────────────────

export async function listStatements(options?: {
  gender?: 'male' | 'female';
  year?: number; month?: number;
  payoutStatus?: 'pending' | 'approved' | 'paid' | 'rejected';
  userId?: string; limit?: number; offset?: number;
}): Promise<StatementRow[]> {
  const { data, error } = await supabase.rpc('admin_list_statements', {
    p_gender: options?.gender ?? null,
    p_year: options?.year ?? null,
    p_month: options?.month ?? null,
    p_payout_status: options?.payoutStatus ?? null,
    p_user_id: options?.userId ?? null,
    p_limit: options?.limit ?? 100,
    p_offset: options?.offset ?? 0,
  });
  if (error || !data) return [];
  return data as unknown as StatementRow[];
}

export async function updatePayout(
  statementId: string,
  updates: { status?: 'approved' | 'paid' | 'rejected'; pdfUrl?: string; excelUrl?: string; notes?: string; },
): Promise<{ success: boolean; error?: string }> {
  const { data, error } = await supabase.rpc('admin_update_payout', {
    p_statement_id: statementId,
    p_status: updates.status ?? null,
    p_pdf_url: updates.pdfUrl ?? null,
    p_excel_url: updates.excelUrl ?? null,
    p_notes: updates.notes ?? null,
  });
  if (error) return { success: false, error: error.message };
  return (data as { success: boolean }) ?? { success: true };
}

export async function runMonthlyClosing(year?: number, month?: number) {
  const { data, error } = await supabase.rpc('run_monthly_closing', {
    p_year: year ?? null, p_month: month ?? null,
  });
  if (error) return { success: false, error: error.message };
  return data as { success: boolean; [k: string]: unknown };
}

/** Admin "Generate Now" button — snapshots all women's current available
 *  balance into pending payout statements immediately. */
export async function generatePayoutSnapshotNow(): Promise<{ success: boolean; count?: number; error?: string }> {
  const { data, error } = await supabase.rpc('generate_payout_snapshot_unified');
  if (error) return { success: false, error: error.message };
  return data as { success: boolean; count?: number };
}
