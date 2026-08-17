-- ============================================================
-- SYNC: Live DB schema changes not yet in migration files
-- Covers versions: 20260306152359 through 20260310212756
-- ============================================================

-- ============================================================
-- 1. user_fcm_tokens table (20260306171633)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.user_fcm_tokens (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token text NOT NULL,
  platform text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, token)
);

ALTER TABLE public.user_fcm_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own FCM tokens"
  ON public.user_fcm_tokens
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- 2. ledger_transactions table (20260310212557)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.ledger_transactions (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id uuid,
  transaction_type text NOT NULL,
  debit numeric NOT NULL DEFAULT 0.00,
  credit numeric NOT NULL DEFAULT 0.00,
  rate_per_minute numeric,
  duration_seconds integer,
  counterparty_id uuid,
  reference_id text,
  description text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.ledger_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own ledger transactions"
  ON public.ledger_transactions
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_ledger_transactions_user_id_created 
  ON public.ledger_transactions(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_ledger_transactions_session_id 
  ON public.ledger_transactions(session_id);

-- ============================================================
-- 3. admin_user_messages: allow null admin_id (20260306171641)
-- ============================================================
ALTER TABLE public.admin_user_messages
  ALTER COLUMN admin_id DROP NOT NULL;

-- ============================================================
-- 4. Performance indexes (20260306180535)
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user_created
  ON public.wallet_transactions(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_wallet_transactions_idempotency_key
  ON public.wallet_transactions(idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_women_earnings_user_created
  ON public.women_earnings(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_active_chat_sessions_status
  ON public.active_chat_sessions(status, man_user_id, woman_user_id)
  WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_video_call_sessions_status
  ON public.video_call_sessions(status, man_user_id, woman_user_id)
  WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_user_status_is_online
  ON public.user_status(is_online, last_seen)
  WHERE is_online = true;

-- ============================================================
-- 5. chat_pricing: add group call rates (20260306195114)
-- ============================================================
ALTER TABLE public.chat_pricing
  ADD COLUMN IF NOT EXISTS group_call_rate_per_minute numeric DEFAULT 3.00,
  ADD COLUMN IF NOT EXISTS group_call_women_earning_rate numeric DEFAULT 2.00;

-- ============================================================
-- 6. video_call_sessions: add started_at if missing (20260306193952)
-- ============================================================
ALTER TABLE public.video_call_sessions
  ADD COLUMN IF NOT EXISTS started_at timestamptz;

-- ============================================================
-- 7. get_transaction_month_summary RPC (20260308153238)
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_transaction_month_summary(
  p_user_id uuid,
  p_gender text,
  p_month_start timestamptz,
  p_month_end timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_opening_balance   numeric := 0;
    v_current_balance   numeric := 0;
    v_transactions      jsonb   := '[]'::jsonb;
    v_pricing           jsonb   := NULL;
    v_wallet_balance    numeric := 0;
    v_this_credits      numeric := 0;
    v_this_debits       numeric := 0;
    v_after_credits     numeric := 0;
    v_after_debits      numeric := 0;
    v_prior_earnings    numeric := 0;
    v_prior_debits      numeric := 0;
BEGIN
    IF auth.uid() IS NOT NULL AND auth.uid() != p_user_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Access denied');
    END IF;

    SELECT jsonb_build_object(
        'menChatRate',    rate_per_minute,
        'menVideoRate',   video_rate_per_minute,
        'womenChatRate',  women_earning_rate,
        'womenVideoRate', video_women_earning_rate
    ) INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    ORDER BY updated_at DESC
    LIMIT 1;

    IF p_gender = 'male' THEN
        SELECT COALESCE(balance, 0) INTO v_current_balance
        FROM public.wallets WHERE user_id = p_user_id;
    ELSE
        SELECT
            COALESCE((SELECT SUM(amount) FROM public.women_earnings WHERE user_id = p_user_id), 0)
            - COALESCE((SELECT SUM(amount) FROM public.wallet_transactions WHERE user_id = p_user_id AND type = 'debit'), 0)
            - COALESCE((SELECT SUM(amount) FROM public.withdrawal_requests WHERE user_id = p_user_id AND status = 'pending'), 0)
        INTO v_current_balance;
    END IF;

    IF p_gender = 'male' THEN
        v_wallet_balance := v_current_balance;

        SELECT
            COALESCE(SUM(CASE WHEN type = 'credit' THEN amount ELSE 0 END), 0),
            COALESCE(SUM(CASE WHEN type = 'debit'  THEN amount ELSE 0 END), 0)
        INTO v_this_credits, v_this_debits
        FROM public.wallet_transactions
        WHERE user_id = p_user_id
          AND created_at >= p_month_start AND created_at <= p_month_end;

        SELECT
            COALESCE(SUM(CASE WHEN type = 'credit' THEN amount ELSE 0 END), 0),
            COALESCE(SUM(CASE WHEN type = 'debit'  THEN amount ELSE 0 END), 0)
        INTO v_after_credits, v_after_debits
        FROM public.wallet_transactions
        WHERE user_id = p_user_id AND created_at > p_month_end;

        v_opening_balance := v_wallet_balance
                             - v_this_credits + v_this_debits
                             - v_after_credits + v_after_debits;
    ELSE
        SELECT COALESCE(SUM(amount), 0) INTO v_prior_earnings
        FROM public.women_earnings
        WHERE user_id = p_user_id AND created_at < p_month_start;

        SELECT COALESCE(SUM(amount), 0) INTO v_prior_debits
        FROM public.wallet_transactions
        WHERE user_id = p_user_id AND type = 'debit' AND created_at < p_month_start;

        v_opening_balance := v_prior_earnings - v_prior_debits;
    END IF;

    IF p_gender = 'male' THEN
        SELECT jsonb_agg(
            jsonb_build_object(
                'id',           id,
                'source',       'wallet_tx',
                'is_credit',    (type = 'credit'),
                'type',         type,
                'amount',       amount,
                'description',  COALESCE(description, ''),
                'status',       status,
                'created_at',   created_at,
                'reference_id', COALESCE(reference_id, upper(substring(id::text, 1, 8)))
            ) ORDER BY created_at ASC
        ) INTO v_transactions
        FROM public.wallet_transactions
        WHERE user_id = p_user_id
          AND created_at >= p_month_start AND created_at <= p_month_end;
    ELSE
        SELECT jsonb_agg(row ORDER BY row_ts ASC) INTO v_transactions
        FROM (
            SELECT
                jsonb_build_object(
                    'id',           id,
                    'source',       'wallet_tx',
                    'is_credit',    false,
                    'amount',       amount,
                    'description',  COALESCE(description, 'Debit'),
                    'status',       status,
                    'created_at',   created_at,
                    'reference_id', COALESCE(reference_id, upper(substring(id::text, 1, 8)))
                ) AS row,
                created_at AS row_ts
            FROM public.wallet_transactions
            WHERE user_id = p_user_id AND type = 'debit'
              AND created_at >= p_month_start AND created_at <= p_month_end

            UNION ALL

            SELECT
                jsonb_build_object(
                    'id',           'earning-' || id::text,
                    'source',       'women_earnings',
                    'is_credit',    true,
                    'amount',       amount,
                    'earning_type', earning_type,
                    'description',  COALESCE(description, earning_type || ' earnings'),
                    'status',       'completed',
                    'created_at',   created_at,
                    'reference_id', upper(substring(id::text, 1, 8))
                ) AS row,
                created_at AS row_ts
            FROM public.women_earnings
            WHERE user_id = p_user_id
              AND created_at >= p_month_start AND created_at <= p_month_end
        ) combined_rows;
    END IF;

    RETURN jsonb_build_object(
        'opening_balance', v_opening_balance,
        'current_balance', v_current_balance,
        'transactions',    COALESCE(v_transactions, '[]'::jsonb),
        'pricing_rates',   v_pricing
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM, 'detail', SQLSTATE);
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.get_transaction_month_summary(uuid, text, timestamptz, timestamptz) TO authenticated;

-- ============================================================
-- 8. Transaction query indexes (20260308153248)
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_wallet_tx_user_type_created
  ON public.wallet_transactions(user_id, type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_women_earnings_user_type_created
  ON public.women_earnings(user_id, earning_type, created_at DESC);

-- ============================================================
-- 9. sweep_stale_user_status function (20260306191153)
-- ============================================================
CREATE OR REPLACE FUNCTION public.sweep_stale_user_status()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.user_status
  SET is_online = false
  WHERE is_online = true
    AND last_seen < now() - interval '5 minutes';
END;
$$;

GRANT EXECUTE ON FUNCTION public.sweep_stale_user_status() TO service_role;

