
-- ─── 1. Drop ambiguous overloads of ledger_bill_session ───
-- Keep canonical: (uuid, text, uuid, uuid, integer, numeric, numeric, integer)
-- where param order is: p_session_id, p_session_type, p_man_id, p_woman_id, p_minute_number, p_man_charge, p_woman_earn, p_duration_seconds
DROP FUNCTION IF EXISTS public.ledger_bill_session(p_session_id uuid, p_session_type text, p_man_id uuid, p_woman_id uuid, p_man_charge numeric, p_woman_earn numeric, p_minute_number integer);
DROP FUNCTION IF EXISTS public.ledger_bill_session(p_session_id text, p_session_type text, p_man_id uuid, p_woman_id uuid, p_minute_number integer, p_man_charge numeric, p_woman_earn numeric, p_duration_seconds integer);
DROP FUNCTION IF EXISTS public.ledger_bill_session(p_session_id uuid, p_session_type text, p_man_id uuid, p_woman_id uuid, p_man_charge numeric, p_woman_earn numeric, p_minute_number integer, p_duration_seconds integer);

-- ─── 2. Drop ambiguous overload of process_chat_billing ───
-- Keep canonical: (p_session_id uuid, p_minutes numeric)
DROP FUNCTION IF EXISTS public.process_chat_billing(p_session_id text, p_man_id uuid, p_woman_id uuid, p_minutes numeric, p_idempotency text);

-- ─── 3. Drop ambiguous overload of process_group_billing ───
-- Keep canonical: (p_group_id uuid)
DROP FUNCTION IF EXISTS public.process_group_billing(p_group_id uuid, p_minutes numeric);

-- ─── 4. Close orphaned video call sessions ───
UPDATE public.video_call_sessions
SET ended_at = COALESCE(updated_at, created_at, now())
WHERE ended_at IS NULL
  AND status IN ('declined','rejected','missed','ended','cancelled');

-- ─── 5. Clear orphaned group_active_hosts ───
DELETE FROM public.group_active_hosts gah
WHERE NOT EXISTS (
  SELECT 1 FROM public.private_groups pg
  WHERE pg.id = gah.group_id AND pg.is_live = true
);

-- ─── 6. Backfill NULL balance_after in wallet_transactions ───
WITH ranked AS (
  SELECT 
    id,
    user_id,
    amount,
    created_at,
    SUM(amount) OVER (PARTITION BY user_id ORDER BY created_at, id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running
  FROM public.wallet_transactions
)
UPDATE public.wallet_transactions wt
SET balance_after = r.running
FROM ranked r
WHERE wt.id = r.id AND wt.balance_after IS NULL;

-- ─── 7. Add integrity trigger: is_live=true requires current_host_id ───
CREATE OR REPLACE FUNCTION public.validate_private_group_live_host()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.is_live = true AND NEW.current_host_id IS NULL THEN
    RAISE EXCEPTION 'private_groups.is_live cannot be true without current_host_id'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_private_group_live_host ON public.private_groups;
CREATE TRIGGER trg_validate_private_group_live_host
BEFORE INSERT OR UPDATE ON public.private_groups
FOR EACH ROW
EXECUTE FUNCTION public.validate_private_group_live_host();
