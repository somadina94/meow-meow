-- Create monthly_statements table
CREATE TABLE IF NOT EXISTS public.monthly_statements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  year integer NOT NULL,
  month integer NOT NULL,
  opening_balance numeric(10,2) NOT NULL DEFAULT 0,
  total_debit numeric(10,2) NOT NULL DEFAULT 0,
  total_credit numeric(10,2) NOT NULL DEFAULT 0,
  closing_balance numeric(10,2) NOT NULL DEFAULT 0,
  forwarded_balance numeric(10,2) NOT NULL DEFAULT 0,
  pdf_url text,
  excel_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, year, month)
);

ALTER TABLE public.monthly_statements ENABLE ROW LEVEL SECURITY;

CREATE POLICY admin_monthly_statements_all ON public.monthly_statements
  FOR ALL TO authenticated
  USING (has_role(auth.uid(), 'admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

-- Fix admin_search_statements to use p.user_id
DROP FUNCTION IF EXISTS public.admin_search_statements(uuid, integer, integer, integer, integer);

CREATE FUNCTION public.admin_search_statements(
  p_user_id uuid DEFAULT NULL,
  p_year integer DEFAULT NULL,
  p_month integer DEFAULT NULL,
  p_limit integer DEFAULT 200,
  p_offset integer DEFAULT 0
)
RETURNS TABLE(
  statement_id uuid,
  user_id uuid,
  full_name text,
  gender text,
  year integer,
  month integer,
  opening_balance numeric,
  total_debit numeric,
  total_credit numeric,
  closing_balance numeric,
  pdf_url text,
  excel_url text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
    SELECT
      ms.id AS statement_id,
      ms.user_id,
      p.full_name,
      p.gender,
      ms.year,
      ms.month,
      ms.opening_balance,
      ms.total_debit,
      ms.total_credit,
      ms.closing_balance,
      ms.pdf_url,
      ms.excel_url,
      ms.created_at
    FROM public.monthly_statements ms
    JOIN public.profiles p ON p.user_id = ms.user_id
    WHERE (p_user_id IS NULL OR ms.user_id = p_user_id)
      AND (p_year IS NULL OR ms.year = p_year)
      AND (p_month IS NULL OR ms.month = p_month)
    ORDER BY ms.year DESC, ms.month DESC, ms.created_at DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$;

-- Fix generate_monthly_statement to use profiles.user_id
CREATE OR REPLACE FUNCTION public.generate_monthly_statement(
  p_user_id uuid,
  p_year integer,
  p_month integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gender text;
  v_period_start timestamptz;
  v_period_end timestamptz;
  v_opening_balance numeric(10,2);
  v_total_debit numeric(10,2);
  v_total_credit numeric(10,2);
  v_closing_balance numeric(10,2);
  v_prev_year integer;
  v_prev_month integer;
  v_stmt_id uuid;
BEGIN
  SELECT gender INTO v_gender FROM public.profiles WHERE user_id = p_user_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  v_period_start := make_timestamptz(p_year, p_month, 1, 0, 0, 0, 'UTC');
  v_period_end   := v_period_start + interval '1 month';

  IF p_month = 1 THEN v_prev_year := p_year - 1; v_prev_month := 12;
  ELSE v_prev_year := p_year; v_prev_month := p_month - 1;
  END IF;

  SELECT ms.closing_balance INTO v_opening_balance
  FROM public.monthly_statements ms
  WHERE ms.user_id = p_user_id AND ms.year = v_prev_year AND ms.month = v_prev_month;

  IF v_opening_balance IS NULL THEN v_opening_balance := 0; END IF;

  IF v_gender = 'male' THEN
    SELECT
      COALESCE(SUM(CASE WHEN wt.type = 'debit' THEN wt.amount ELSE 0 END), 0),
      COALESCE(SUM(CASE WHEN wt.type = 'credit' THEN wt.amount ELSE 0 END), 0)
    INTO v_total_debit, v_total_credit
    FROM public.wallet_transactions wt
    WHERE wt.user_id = p_user_id
      AND wt.created_at >= v_period_start
      AND wt.created_at < v_period_end;
  ELSE
    SELECT
      0,
      COALESCE(SUM(we.amount), 0)
    INTO v_total_debit, v_total_credit
    FROM public.women_earnings we
    WHERE we.user_id = p_user_id
      AND we.created_at >= v_period_start
      AND we.created_at < v_period_end;
  END IF;

  v_closing_balance := v_opening_balance + v_total_credit - v_total_debit;

  INSERT INTO public.monthly_statements
    (user_id, year, month, opening_balance, total_debit, total_credit, closing_balance)
  VALUES
    (p_user_id, p_year, p_month, v_opening_balance, v_total_debit, v_total_credit, v_closing_balance)
  ON CONFLICT (user_id, year, month) DO UPDATE SET
    opening_balance = EXCLUDED.opening_balance,
    total_debit = EXCLUDED.total_debit,
    total_credit = EXCLUDED.total_credit,
    closing_balance = EXCLUDED.closing_balance,
    updated_at = now()
  RETURNING id INTO v_stmt_id;

  RETURN jsonb_build_object(
    'success', true,
    'statement_id', v_stmt_id,
    'opening_balance', v_opening_balance,
    'total_debit', v_total_debit,
    'total_credit', v_total_credit,
    'closing_balance', v_closing_balance
  );
END;
$$;