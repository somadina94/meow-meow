-- Allow 'on_demand_*' snapshot types from the admin Generate Now button
ALTER TABLE public.women_payout_snapshots
  DROP CONSTRAINT IF EXISTS women_payout_snapshots_snapshot_type_check;

ALTER TABLE public.women_payout_snapshots
  ADD CONSTRAINT women_payout_snapshots_snapshot_type_check
  CHECK (
    snapshot_type IN ('mid_month', 'end_month', 'monthly')
    OR snapshot_type LIKE 'on_demand_%'
  );