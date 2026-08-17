-- ─────────────────────────────────────────────────────────────────────────────
-- FIX 1: get_ledger_statement — "column reference 'created_at' is ambiguous"
--        The RETURNS TABLE has a `created_at` OUT column, which collides with
--        `wallet_transactions.created_at` inside the opening-balance subquery.
--        Solution: qualify all column references with table aliases.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_ledger_statement(
  p_user_id uuid,
  p_from_date text DEFAULT NULL,
  p_to_date text DEFAULT NULL
)
RETURNS TABLE(
  id uuid, session_id text, transaction_type text,
  debit numeric, credit numeric, description text,
  reference_id text, counterparty_id text, running_balance numeric,
  created_at timestamptz, duration_seconds integer, rate_per_minute numeric
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid := public.resolve_wallet_user_id(p_user_id);
  v_from timestamptz;
  v_to timestamptz;
  v_opening_balance numeric := 0;
  v_archive_cutoff timestamptz := now() - interval '3 months';
  v_need_archive boolean;
BEGIN
  IF v_user_id IS NULL THEN RETURN; END IF;

  IF auth.role() <> 'service_role'
     AND auth.uid() IS DISTINCT FROM v_user_id
     AND NOT public.has_role(auth.uid(), 'admin') THEN
    RAISE EXCEPTION 'Not allowed to view this statement';
  END IF;

  IF p_from_date IS NOT NULL THEN
    v_from := (p_from_date::date::timestamp AT TIME ZONE 'Asia/Kolkata');
  END IF;
  IF p_to_date IS NOT NULL THEN
    v_to := ((p_to_date::date + 1)::timestamp AT TIME ZONE 'Asia/Kolkata');
  END IF;

  v_need_archive := (v_from IS NULL) OR (v_from < v_archive_cutoff);

  IF v_from IS NOT NULL THEN
    SELECT GREATEST(
             COALESCE(SUM(CASE WHEN prev.type='credit' THEN prev.amount
                               WHEN prev.type='debit'  THEN -prev.amount
                               ELSE 0 END), 0), 0)
    INTO v_opening_balance
    FROM (
      SELECT wt.type, wt.amount
      FROM public.wallet_transactions wt
      WHERE wt.user_id = v_user_id
        AND wt.status='completed'
        AND wt.created_at < v_from
      UNION ALL
      SELECT wa.type, wa.amount
      FROM public.wallet_transactions_archive wa
      WHERE wa.user_id = v_user_id
        AND wa.status='completed'
        AND wa.created_at < v_from
    ) prev;
  END IF;

  RETURN QUERY
  WITH unified AS (
    SELECT wt.id, wt.session_id, wt.type, wt.transaction_type, wt.amount,
           wt.description, wt.reference_id, wt.idempotency_key, wt.created_at,
           wt.duration_seconds, wt.rate_per_minute
    FROM public.wallet_transactions wt
    WHERE wt.user_id = v_user_id AND wt.status='completed'
      AND (v_from IS NULL OR wt.created_at >= v_from)
      AND (v_to   IS NULL OR wt.created_at <  v_to)
    UNION ALL
    SELECT wa.id, wa.session_id, wa.type, wa.transaction_type, wa.amount,
           wa.description, wa.reference_id, wa.idempotency_key, wa.created_at,
           wa.duration_seconds, wa.rate_per_minute
    FROM public.wallet_transactions_archive wa
    WHERE v_need_archive AND wa.user_id = v_user_id AND wa.status='completed'
      AND (v_from IS NULL OR wa.created_at >= v_from)
      AND (v_to   IS NULL OR wa.created_at <  v_to)
  ), filtered AS (
    SELECT u.id,
           u.session_id::text AS session_id,
           COALESCE(u.transaction_type, u.type)::text AS transaction_type,
           CASE WHEN u.type='debit'  THEN u.amount ELSE 0::numeric END AS debit,
           CASE WHEN u.type='credit' THEN u.amount ELSE 0::numeric END AS credit,
           u.description,
           COALESCE(u.reference_id, u.idempotency_key)::text AS reference_id,
           NULL::text AS counterparty_id,
           u.created_at,
           COALESCE(u.duration_seconds,
             CASE WHEN u.rate_per_minute IS NOT NULL AND u.rate_per_minute > 0 AND u.amount > 0
                  THEN ROUND((u.amount / u.rate_per_minute) * 60)::integer
                  ELSE NULL END
           ) AS duration_seconds,
           u.rate_per_minute
    FROM unified u
  ), ordered AS (
    SELECT f.*,
           GREATEST(
             v_opening_balance + SUM(f.credit - f.debit)
               OVER (ORDER BY f.created_at, f.id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),
             0
           )::numeric AS running_balance
    FROM filtered f
  )
  SELECT o.id, o.session_id, o.transaction_type, o.debit, o.credit,
         o.description, o.reference_id, o.counterparty_id, o.running_balance,
         o.created_at, o.duration_seconds, o.rate_per_minute
  FROM ordered o
  ORDER BY o.created_at DESC, o.id DESC;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_ledger_statement(uuid, text, text) TO authenticated, service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- FIX 2: trg_video_call_ended — calls dropped function process_call_billing.
--        Reroute the trigger to the canonical SoT RPC `bill_session_minute`.
--        For audio_call / video_call (1-on-1, p_man_count=1).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.trg_video_call_ended()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_minutes numeric;
  v_session_type text;
  v_result jsonb;
BEGIN
  IF NEW.status IN ('ended', 'completed') AND OLD.status IS DISTINCT FROM NEW.status THEN
    -- Revert busy status
    PERFORM public.revert_busy_to_online(NEW.man_user_id);
    PERFORM public.revert_busy_to_online(NEW.woman_user_id);

    -- Auto-bill if not already billed and call had valid duration
    IF (NEW.total_earned = 0 OR NEW.total_earned IS NULL)
       AND (NEW.total_minutes = 0 OR NEW.total_minutes IS NULL)
       AND NEW.started_at IS NOT NULL
       AND NEW.ended_at IS NOT NULL
       AND EXTRACT(EPOCH FROM (NEW.ended_at - NEW.started_at)) > 0
    THEN
      -- Pro-rated minutes (rounded UP to whole second precision then /60)
      v_minutes := ROUND(EXTRACT(EPOCH FROM (NEW.ended_at - NEW.started_at)) / 60.0, 4);
      v_session_type := CASE COALESCE(NEW.call_type, 'video')
                          WHEN 'audio' THEN 'audio_call'
                          WHEN 'video' THEN 'video_call'
                          ELSE 'video_call'
                        END;

      v_result := public.bill_session_minute(
        p_session_id   => NEW.id,
        p_session_type => v_session_type,
        p_minutes      => v_minutes,
        p_man_id       => NEW.man_user_id,
        p_woman_id     => NEW.woman_user_id,
        p_man_count    => 1,
        p_minute_index => NULL
      );

      -- Persist totals on the session row for UI/history
      IF (v_result->>'success')::boolean IS TRUE THEN
        UPDATE public.video_call_sessions
           SET total_minutes = v_minutes,
               total_earned  = COALESCE((v_result->>'earned')::numeric, 0)
         WHERE id = NEW.id;
      END IF;
    END IF;
  ELSIF NEW.status IN ('declined', 'missed') AND OLD.status IS DISTINCT FROM NEW.status THEN
    PERFORM public.revert_busy_to_online(NEW.man_user_id);
    PERFORM public.revert_busy_to_online(NEW.woman_user_id);
  END IF;
  RETURN NEW;
END;
$function$;

-- ─────────────────────────────────────────────────────────────────────────────
-- FIX 3: Backfill — bill any past calls that were "ended" but never billed
--        because trigger crashed. Limited to last 24h to be safe.
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  r RECORD;
  v_minutes numeric;
  v_session_type text;
  v_result jsonb;
BEGIN
  FOR r IN
    SELECT id, call_id, call_type, man_user_id, woman_user_id, started_at, ended_at
    FROM public.video_call_sessions
    WHERE status IN ('ended','completed')
      AND (total_earned = 0 OR total_earned IS NULL)
      AND started_at IS NOT NULL
      AND ended_at IS NOT NULL
      AND ended_at > now() - interval '24 hours'
      AND EXTRACT(EPOCH FROM (ended_at - started_at)) > 0
  LOOP
    v_minutes := ROUND(EXTRACT(EPOCH FROM (r.ended_at - r.started_at)) / 60.0, 4);
    v_session_type := CASE COALESCE(r.call_type, 'video')
                        WHEN 'audio' THEN 'audio_call'
                        WHEN 'video' THEN 'video_call'
                        ELSE 'video_call'
                      END;
    BEGIN
      v_result := public.bill_session_minute(
        p_session_id   => r.id,
        p_session_type => v_session_type,
        p_minutes      => v_minutes,
        p_man_id       => r.man_user_id,
        p_woman_id     => r.woman_user_id,
        p_man_count    => 1,
        p_minute_index => NULL
      );
      IF (v_result->>'success')::boolean IS TRUE THEN
        UPDATE public.video_call_sessions
           SET total_minutes = v_minutes,
               total_earned  = COALESCE((v_result->>'earned')::numeric, 0)
         WHERE id = r.id;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Backfill skipped for %: %', r.id, SQLERRM;
    END;
  END LOOP;
END$$;