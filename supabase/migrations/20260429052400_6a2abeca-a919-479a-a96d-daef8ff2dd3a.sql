-- 1. Archive table (mirror schema)
CREATE TABLE IF NOT EXISTS public.wallet_transactions_archive (
  id uuid PRIMARY KEY,
  wallet_id uuid,
  user_id uuid NOT NULL,
  type text NOT NULL,
  amount numeric NOT NULL,
  description text,
  reference_id text,
  status text NOT NULL DEFAULT 'completed',
  created_at timestamptz NOT NULL,
  idempotency_key text NOT NULL,
  session_id uuid,
  session_type text,
  transaction_type text,
  balance_after numeric,
  duration_seconds integer,
  rate_per_minute numeric,
  billing_metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  archived_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wta_user_created ON public.wallet_transactions_archive(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wta_created ON public.wallet_transactions_archive(created_at DESC);

ALTER TABLE public.wallet_transactions_archive ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users view own archived transactions" ON public.wallet_transactions_archive;
CREATE POLICY "Users view own archived transactions"
ON public.wallet_transactions_archive FOR SELECT
USING (auth.uid() = user_id OR public.has_role(auth.uid(), 'admin'));

DROP POLICY IF EXISTS "Service role manages archive" ON public.wallet_transactions_archive;
CREATE POLICY "Service role manages archive"
ON public.wallet_transactions_archive FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

-- 2. Archival function: move rows older than 3 months
CREATE OR REPLACE FUNCTION public.archive_old_wallet_transactions()
RETURNS TABLE(archived_count integer, cutoff_date timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cutoff timestamptz := now() - interval '3 months';
  v_count integer := 0;
BEGIN
  WITH moved AS (
    DELETE FROM public.wallet_transactions
    WHERE created_at < v_cutoff
    RETURNING *
  )
  INSERT INTO public.wallet_transactions_archive (
    id, wallet_id, user_id, type, amount, description, reference_id,
    status, created_at, idempotency_key, session_id, session_type,
    transaction_type, balance_after, duration_seconds, rate_per_minute,
    billing_metadata
  )
  SELECT
    id, wallet_id, user_id, type, amount, description, reference_id,
    status, created_at, idempotency_key, session_id, session_type,
    transaction_type, balance_after, duration_seconds, rate_per_minute,
    billing_metadata
  FROM moved
  ON CONFLICT (id) DO NOTHING;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN QUERY SELECT v_count, v_cutoff;
END;
$$;

-- 3. Unified query: live + archive
CREATE OR REPLACE FUNCTION public.query_wallet_transactions_unified(
  p_user_id uuid,
  p_include_archive boolean DEFAULT false,
  p_limit integer DEFAULT 500
)
RETURNS TABLE(
  id uuid, user_id uuid, type text, amount numeric, description text,
  reference_id text, status text, created_at timestamptz,
  session_type text, transaction_type text, balance_after numeric,
  duration_seconds integer, rate_per_minute numeric,
  billing_metadata jsonb, source text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id, user_id, type, amount, description, reference_id, status,
         created_at, session_type, transaction_type, balance_after,
         duration_seconds, rate_per_minute, billing_metadata, 'live'::text AS source
  FROM public.wallet_transactions
  WHERE user_id = p_user_id
  UNION ALL
  SELECT id, user_id, type, amount, description, reference_id, status,
         created_at, session_type, transaction_type, balance_after,
         duration_seconds, rate_per_minute, billing_metadata, 'archive'::text AS source
  FROM public.wallet_transactions_archive
  WHERE p_include_archive = true AND user_id = p_user_id
  ORDER BY created_at DESC
  LIMIT p_limit;
$$;

-- 4. Schedule daily archival at 02:30 IST (21:00 UTC prev day)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule('archive-wallet-transactions-daily')
    WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'archive-wallet-transactions-daily');
    PERFORM cron.schedule(
      'archive-wallet-transactions-daily',
      '0 21 * * *',
      $cron$ SELECT public.archive_old_wallet_transactions(); $cron$
    );
  END IF;
END $$;

-- 5. Update men/women balance functions to include archive (so historical balance stays correct)
CREATE OR REPLACE FUNCTION public.men_ledger_balance(p_man_id uuid)
RETURNS numeric
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT GREATEST(COALESCE(SUM(
    CASE WHEN type='credit' THEN amount WHEN type='debit' THEN -amount ELSE 0 END
  ), 0), 0)::numeric(12,2)
  FROM (
    SELECT type, amount FROM public.wallet_transactions
      WHERE user_id = p_man_id AND status='completed'
    UNION ALL
    SELECT type, amount FROM public.wallet_transactions_archive
      WHERE user_id = p_man_id AND status='completed'
  ) t;
$$;

CREATE OR REPLACE FUNCTION public.women_ledger_balance(p_woman_id uuid)
RETURNS numeric
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT GREATEST(COALESCE(SUM(
    CASE WHEN type='credit' THEN amount WHEN type='debit' THEN -amount ELSE 0 END
  ), 0), 0)::numeric(12,2)
  FROM (
    SELECT type, amount FROM public.wallet_transactions
      WHERE user_id = p_woman_id AND status='completed'
    UNION ALL
    SELECT type, amount FROM public.wallet_transactions_archive
      WHERE user_id = p_woman_id AND status='completed'
  ) t;
$$;