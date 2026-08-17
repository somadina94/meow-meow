
-- Make-whole: credit woman 50% of each unpaired video_call_charge
WITH unpaired AS (
  SELECT vc.id AS charge_id, vc.session_id, vc.amount AS charge_amt,
         vc.duration_seconds, vc.created_at, vc.reference_id
  FROM public.wallet_transactions vc
  WHERE vc.transaction_type='video_call_charge'
    AND NOT EXISTS (
      SELECT 1 FROM public.wallet_transactions ve
      WHERE ve.transaction_type='video_call_earning'
        AND ve.session_id IS NOT NULL
        AND ve.session_id = vc.session_id
    )
),
woman AS (
  SELECT w.user_id, w.id AS wallet_id
  FROM public.wallets w
  WHERE w.user_id = '04cad57a-2647-457e-beb4-9a5c60fbbe44'
)
INSERT INTO public.wallet_transactions
  (wallet_id, user_id, type, transaction_type, amount, description, reference_id, status,
   created_at, idempotency_key, session_id, session_type, duration_seconds, billing_metadata)
SELECT
  woman.wallet_id,
  woman.user_id,
  'credit',
  'video_call_earning',
  ROUND(unpaired.charge_amt * 0.5, 2),
  'Video Call Earning (make-whole): ' || ROUND(unpaired.duration_seconds/60.0, 1) || ' min',
  unpaired.reference_id,
  'completed',
  unpaired.created_at,
  'video_makewhole:' || unpaired.charge_id::text,
  unpaired.session_id,
  'video_call',
  unpaired.duration_seconds,
  jsonb_build_object('source','make_whole_v2026_04_29','from_charge_id', unpaired.charge_id)
FROM unpaired CROSS JOIN woman
ON CONFLICT (idempotency_key) DO NOTHING;

-- Resync wallet
WITH ledger AS (
  SELECT user_id, SUM(CASE WHEN type='credit' THEN amount ELSE -amount END) AS lsum
  FROM public.wallet_transactions GROUP BY user_id
)
UPDATE public.wallets w
SET balance = COALESCE(l.lsum,0), updated_at=now()
FROM ledger l
WHERE w.user_id = l.user_id
  AND ABS(COALESCE(w.balance,0) - COALESCE(l.lsum,0)) > 0.01;

-- Validator
DO $$
DECLARE v jsonb;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname='validate_financial_sot') THEN
    SELECT public.validate_financial_sot() INTO v;
    RAISE NOTICE 'SoT validator after make-whole: %', v;
  END IF;
END $$;
