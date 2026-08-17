-- ============================================================
-- Migration: billing_rules_monthly_statements
-- Applied: 2026-03-12
-- Purpose:
--   1. Enforce correct billing rates per spec
--      Text/Group: men ₹4/min, women ₹2/min per man
--      Video:      men ₹8/min, women ₹4/min
--   2. Create monthly_statements table (admin-only RLS)
--   3. RPCs: generate_monthly_statement, admin_get_statement_detail,
--            admin_search_statements, admin_update_statement_urls
-- ============================================================

-- 1. Enforce correct billing rates
UPDATE public.chat_pricing SET
  rate_per_minute              = 4.00,
  women_earning_rate           = 2.00,
  video_rate_per_minute        = 8.00,
  video_women_earning_rate     = 4.00,
  group_call_rate_per_minute   = 4.00,
  group_call_women_earning_rate = 2.00,
  updated_at = now()
WHERE is_active = true;

-- 2. monthly_statements table (admin-only, internal ledger)
CREATE TABLE IF NOT EXISTS public.monthly_statements (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  year             integer NOT NULL,
  month            integer NOT NULL CHECK (month BETWEEN 1 AND 12),
  opening_balance  numeric(10,2) NOT NULL DEFAULT 0,
  total_debit      numeric(10,2) NOT NULL DEFAULT 0,
  total_credit     numeric(10,2) NOT NULL DEFAULT 0,
  closing_balance  numeric(10,2) NOT NULL DEFAULT 0,
  pdf_url          text,
  excel_url        text,
  word_url         text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, year, month)
);

ALTER TABLE public.monthly_statements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS monthly_statements_admin_only ON public.monthly_statements;
CREATE POLICY monthly_statements_admin_only ON public.monthly_statements
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

CREATE INDEX IF NOT EXISTS idx_monthly_statements_user_year_month
  ON public.monthly_statements(user_id, year DESC, month DESC);

-- 3. generate_monthly_statement RPC
--    Men  → wallet_transactions
--    Women → women_earnings
CREATE OR REPLACE FUNCTION public.generate_monthly_statement(
  p_user_id uuid,
  p_year    integer,
  p_month   integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_gender           text;
  v_period_start     timestamptz;
  v_period_end       timestamptz;
  v_opening_balance  numeric(10,2);
  v_total_debit      numeric(10,2);
  v_total_credit     numeric(10,2);
  v_closing_balance  numeric(10,2);
  v_prev_year        integer;
  v_prev_month       integer;
  v_stmt_id          uuid;
BEGIN
  SELECT gender INTO v_gender FROM public.profiles WHERE id = p_user_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  v_period_start := make_timestamptz(p_year, p_month, 1, 0, 0, 0, 'UTC');
  v_period_end   := v_period_start + interval '1 month';

  IF p_month = 1 THEN v_prev_year := p_year - 1; v_prev_month := 12;
  ELSE v_prev_year := p_year; v_prev_month := p_month - 1;
  END IF;

  SELECT closing_balance INTO v_opening_balance
  FROM public.monthly_statements
  WHERE user_id = p_user_id AND year = v_prev_year AND month = v_prev_month;
  IF v_opening_balance IS NULL THEN v_opening_balance := 0; END IF;

  IF v_gender = 'male' THEN
    SELECT
      COALESCE(SUM(CASE WHEN type = 'debit'  THEN amount ELSE 0 END), 0),
      COALESCE(SUM(CASE WHEN type = 'credit' THEN amount ELSE 0 END), 0)
    INTO v_total_debit, v_total_credit
    FROM public.wallet_transactions
    WHERE user_id = p_user_id
      AND created_at >= v_period_start AND created_at < v_period_end;
  ELSE
    SELECT
      COALESCE(SUM(CASE WHEN type = 'debit' THEN amount ELSE 0 END), 0),
      COALESCE(SUM(amount), 0)
    INTO v_total_debit, v_total_credit
    FROM public.women_earnings
    WHERE user_id = p_user_id
      AND created_at >= v_period_start AND created_at < v_period_end;
  END IF;

  v_closing_balance := v_opening_balance + v_total_credit - v_total_debit;

  INSERT INTO public.monthly_statements
    (user_id, year, month, opening_balance, total_debit, total_credit, closing_balance)
  VALUES
    (p_user_id, p_year, p_month, v_opening_balance, v_total_debit, v_total_credit, v_closing_balance)
  ON CONFLICT (user_id, year, month) DO UPDATE SET
    opening_balance = EXCLUDED.opening_balance,
    total_debit     = EXCLUDED.total_debit,
    total_credit    = EXCLUDED.total_credit,
    closing_balance = EXCLUDED.closing_balance
  RETURNING id INTO v_stmt_id;

  RETURN jsonb_build_object(
    'success',         true,
    'statement_id',    v_stmt_id,
    'opening_balance', v_opening_balance,
    'total_debit',     v_total_debit,
    'total_credit',    v_total_credit,
    'closing_balance', v_closing_balance
  );
END;
$$;

-- 4. admin_get_statement_detail RPC
CREATE OR REPLACE FUNCTION public.admin_get_statement_detail(
  p_user_id uuid,
  p_year    integer,
  p_month   integer
)
RETURNS TABLE (
  txn_date         timestamptz,
  transaction_id   text,
  session_id       text,
  txn_type         text,
  duration_minutes integer,
  debit            numeric,
  credit           numeric,
  balance_after    numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_gender       text;
  v_period_start timestamptz;
  v_period_end   timestamptz;
BEGIN
  SELECT gender INTO v_gender FROM public.profiles WHERE id = p_user_id;
  v_period_start := make_timestamptz(p_year, p_month, 1, 0, 0, 0, 'UTC');
  v_period_end   := v_period_start + interval '1 month';

  IF v_gender = 'male' THEN
    RETURN QUERY
      SELECT wt.created_at, wt.id::text, wt.session_id::text, wt.type,
             NULL::integer,
             CASE WHEN wt.type = 'debit'  THEN wt.amount ELSE 0 END,
             CASE WHEN wt.type = 'credit' THEN wt.amount ELSE 0 END,
             NULL::numeric
      FROM public.wallet_transactions wt
      WHERE wt.user_id = p_user_id
        AND wt.created_at >= v_period_start AND wt.created_at < v_period_end
      ORDER BY wt.created_at;
  ELSE
    RETURN QUERY
      SELECT we.created_at, we.id::text, we.session_id::text, we.earning_type,
             NULL::integer, 0::numeric, we.amount, NULL::numeric
      FROM public.women_earnings we
      WHERE we.user_id = p_user_id
        AND we.created_at >= v_period_start AND we.created_at < v_period_end
      ORDER BY we.created_at;
  END IF;
END;
$$;

-- 5. admin_search_statements RPC
CREATE OR REPLACE FUNCTION public.admin_search_statements(
  p_user_id uuid    DEFAULT NULL,
  p_year    integer DEFAULT NULL,
  p_month   integer DEFAULT NULL,
  p_limit   integer DEFAULT 50,
  p_offset  integer DEFAULT 0
)
RETURNS TABLE (
  statement_id     uuid,
  user_id          uuid,
  full_name        text,
  gender           text,
  year             integer,
  month            integer,
  opening_balance  numeric,
  total_debit      numeric,
  total_credit     numeric,
  closing_balance  numeric,
  pdf_url          text,
  excel_url        text,
  created_at       timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
    SELECT ms.id, ms.user_id, p.full_name, p.gender,
           ms.year, ms.month,
           ms.opening_balance, ms.total_debit, ms.total_credit, ms.closing_balance,
           ms.pdf_url, ms.excel_url, ms.created_at
    FROM public.monthly_statements ms
    JOIN public.profiles p ON p.id = ms.user_id
    WHERE (p_user_id IS NULL OR ms.user_id = p_user_id)
      AND (p_year   IS NULL OR ms.year  = p_year)
      AND (p_month  IS NULL OR ms.month = p_month)
    ORDER BY ms.year DESC, ms.month DESC, ms.created_at DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$;

-- 6. admin_update_statement_urls RPC
CREATE OR REPLACE FUNCTION public.admin_update_statement_urls(
  p_statement_id uuid,
  p_pdf_url      text DEFAULT NULL,
  p_excel_url    text DEFAULT NULL,
  p_word_url     text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.monthly_statements SET
    pdf_url   = COALESCE(p_pdf_url,   pdf_url),
    excel_url = COALESCE(p_excel_url, excel_url),
    word_url  = COALESCE(p_word_url,  word_url)
  WHERE id = p_statement_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Statement not found');
  END IF;
  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.generate_monthly_statement(uuid, integer, integer)            TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_statement_detail(uuid, integer, integer)            TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_search_statements(uuid, integer, integer, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_statement_urls(uuid, text, text, text)           TO authenticated;
