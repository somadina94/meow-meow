-- =====================================================================
-- Billing & Wallet Audit Fixes (Issues 2, 3, 4, 5, 6, 7, 8, 10, 11, 16, 17, 18, 19, 20)
-- =====================================================================

-- ---------- Issue #2 / #19: bill the first minute only when the call is actually ANSWERED ----------
-- Replace the AFTER INSERT trigger with an AFTER UPDATE trigger that fires
-- only when status transitions to 'active' or 'answered'. This covers both
-- audio_call (call_type='audio') and video_call (call_type='video'), since
-- both use video_call_sessions.

DROP TRIGGER IF EXISTS trg_video_call_first_minute_billing ON public.video_call_sessions;

CREATE OR REPLACE FUNCTION public.trg_call_first_minute_billing()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_session_type text;
BEGIN
  -- Only fire when the call has transitioned into an active/answered state.
  IF NEW.status IS NULL OR LOWER(NEW.status) NOT IN ('active','answered','connected','ongoing') THEN
    RETURN NEW;
  END IF;

  -- Skip if status was already active/answered on the previous row (avoid re-firing on later updates)
  IF TG_OP = 'UPDATE' AND OLD.status IS NOT NULL
     AND LOWER(OLD.status) IN ('active','answered','connected','ongoing') THEN
    RETURN NEW;
  END IF;

  -- Skip if either party is missing
  IF NEW.man_user_id IS NULL OR NEW.woman_user_id IS NULL THEN
    RETURN NEW;
  END IF;

  v_session_type := CASE LOWER(COALESCE(NEW.call_type, 'video'))
    WHEN 'audio' THEN 'audio_call'
    WHEN 'video' THEN 'video_call'
    ELSE 'video_call'
  END;

  BEGIN
    PERFORM public.bill_session_minute(
      p_session_id   => NEW.id,
      p_session_type => v_session_type,
      p_minutes      => 1.0,
      p_man_id       => NEW.man_user_id,
      p_woman_id     => NEW.woman_user_id,
      p_man_count    => 1,
      p_minute_index => 0
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'call first-minute billing failed: %', SQLERRM;
  END;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_video_call_first_minute_billing
AFTER UPDATE OF status ON public.video_call_sessions
FOR EACH ROW
EXECUTE FUNCTION public.trg_call_first_minute_billing();


-- ---------- Issue #20: allow service_role to SELECT wallet_transactions for admin debugging ----------
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='wallet_transactions'
      AND policyname='wallet_transactions_admin_only'
  ) THEN
    DROP POLICY wallet_transactions_admin_only ON public.wallet_transactions;
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='wallet_transactions'
      AND policyname='wallet_transactions_admin_or_service'
  ) THEN
    DROP POLICY wallet_transactions_admin_or_service ON public.wallet_transactions;
  END IF;

  CREATE POLICY wallet_transactions_admin_or_service
    ON public.wallet_transactions
    FOR SELECT TO authenticated, service_role
    USING (
      auth.role() = 'service_role' OR
      EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = auth.uid() AND role = 'admin'
      )
    );
END $$;


-- ---------- Issue #18: alias get_man_balance to get_men_wallet_balance (single SoT shape) ----------
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public' AND p.proname='get_men_wallet_balance'
  ) THEN
    EXECUTE $f$
      CREATE OR REPLACE FUNCTION public.get_man_balance(p_user_id uuid)
      RETURNS jsonb
      LANGUAGE sql
      STABLE SECURITY DEFINER
      SET search_path TO 'public'
      AS $alias$
        SELECT public.get_men_wallet_balance(p_user_id);
      $alias$;
    $f$;
    GRANT EXECUTE ON FUNCTION public.get_man_balance(uuid) TO authenticated, service_role;
  END IF;
END $$;


-- ---------- Issues #4, #5, #6, #8, #10, #11, #16, #17: drop legacy non-SoT billing/statement functions ----------
-- The Single Source of Truth is bill_session_minute + wallet_transactions.
-- These legacy functions either wrote to deprecated tables (women_earnings,
-- platform_ledger) or used buggy gender/period logic. Dropping them ensures
-- no caller can accidentally bypass the canonical path.
DROP FUNCTION IF EXISTS public.process_chat_billing(uuid, uuid, uuid, numeric) CASCADE;
DROP FUNCTION IF EXISTS public.process_chat_billing(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.process_audio_billing(uuid, uuid, uuid, numeric) CASCADE;
DROP FUNCTION IF EXISTS public.process_audio_billing(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.process_video_billing(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.process_video_billing_v2(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.process_group_billing(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.process_group_billing_v2(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.generate_monthly_statement(uuid, integer, integer) CASCADE;
DROP FUNCTION IF EXISTS public.admin_get_statement_detail(uuid, integer, integer) CASCADE;
DROP VIEW IF EXISTS public.admin_half_rule_audit CASCADE;


-- ---------- Issue #7: clean up phantom ₹0 rows + positive-amount constraint (only if women_earnings exists) ----------
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema='public' AND table_name='women_earnings'
  ) THEN
    EXECUTE 'DELETE FROM public.women_earnings WHERE amount IS NULL OR amount <= 0';
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints
      WHERE table_schema='public' AND table_name='women_earnings'
        AND constraint_name='chk_women_earnings_amount_positive'
    ) THEN
      EXECUTE 'ALTER TABLE public.women_earnings ADD CONSTRAINT chk_women_earnings_amount_positive CHECK (amount > 0)';
    END IF;
  END IF;
END $$;


-- ---------- Hardening: enforce wallet_transactions.amount > 0 (matches SoT contract) ----------
DO $$
BEGIN
  -- Remove any pre-existing ₹0 noise rows (completed status only, to be safe)
  DELETE FROM public.wallet_transactions
    WHERE (amount IS NULL OR amount = 0) AND status = 'completed';

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_schema='public' AND table_name='wallet_transactions'
      AND constraint_name='chk_wallet_transactions_amount_positive'
  ) THEN
    ALTER TABLE public.wallet_transactions
      ADD CONSTRAINT chk_wallet_transactions_amount_positive CHECK (amount > 0);
  END IF;
END $$;
