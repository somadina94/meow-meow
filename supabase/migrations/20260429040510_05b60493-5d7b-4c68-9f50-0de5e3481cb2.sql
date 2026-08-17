-- Reset all financial data; preserve schema, RPCs, triggers, UI

-- 1) Clear canonical ledger
TRUNCATE TABLE public.wallet_transactions RESTART IDENTITY;

-- 2) Reset all wallet balances to 0 (trigger-protected; use SECURITY DEFINER bypass via direct SQL in migration context)
UPDATE public.wallets SET balance = 0, updated_at = now();

-- 3) Clear session billing records (chat / audio / video)
DO $$
BEGIN
  IF to_regclass('public.active_chat_sessions') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.active_chat_sessions RESTART IDENTITY CASCADE';
  END IF;
  IF to_regclass('public.chat_sessions') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.chat_sessions RESTART IDENTITY CASCADE';
  END IF;
  IF to_regclass('public.video_call_sessions') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.video_call_sessions RESTART IDENTITY CASCADE';
  END IF;
  IF to_regclass('public.audio_call_sessions') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.audio_call_sessions RESTART IDENTITY CASCADE';
  END IF;
  IF to_regclass('public.call_history') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.call_history RESTART IDENTITY CASCADE';
  END IF;
  IF to_regclass('public.chat_billing_log') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.chat_billing_log RESTART IDENTITY CASCADE';
  END IF;
END $$;

-- 4) Clear private group call billing/sessions
DO $$
BEGIN
  IF to_regclass('public.private_group_call_sessions') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.private_group_call_sessions RESTART IDENTITY CASCADE';
  END IF;
  IF to_regclass('public.private_group_participants') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.private_group_participants RESTART IDENTITY CASCADE';
  END IF;
  IF to_regclass('public.private_group_billing') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.private_group_billing RESTART IDENTITY CASCADE';
  END IF;
  IF to_regclass('public.group_call_sessions') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.group_call_sessions RESTART IDENTITY CASCADE';
  END IF;
END $$;

-- 5) Clear gifts & tips
DO $$
BEGIN
  IF to_regclass('public.gift_transactions') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.gift_transactions RESTART IDENTITY CASCADE';
  END IF;
  IF to_regclass('public.tip_transactions') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.tip_transactions RESTART IDENTITY CASCADE';
  END IF;
  IF to_regclass('public.tips') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.tips RESTART IDENTITY CASCADE';
  END IF;
END $$;

-- 6) Clear legacy financial tables (per SoT policy)
DO $$
BEGIN
  IF to_regclass('public.women_earnings') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.women_earnings RESTART IDENTITY CASCADE';
  END IF;
  IF to_regclass('public.platform_ledger') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.platform_ledger RESTART IDENTITY CASCADE';
  END IF;
  IF to_regclass('public.ledger_transactions') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.ledger_transactions RESTART IDENTITY CASCADE';
  END IF;
END $$;

-- 7) Clear payout / withdrawal history (financial reset)
DO $$
BEGIN
  IF to_regclass('public.withdrawal_requests') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.withdrawal_requests RESTART IDENTITY CASCADE';
  END IF;
  IF to_regclass('public.payout_statements') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.payout_statements RESTART IDENTITY CASCADE';
  END IF;
  IF to_regclass('public.payout_snapshots') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.payout_snapshots RESTART IDENTITY CASCADE';
  END IF;
END $$;
