CREATE TABLE IF NOT EXISTS public.pending_recharges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  txn_id text UNIQUE NOT NULL,
  user_id uuid NOT NULL,
  amount numeric NOT NULL,
  gateway text NOT NULL DEFAULT 'payu',
  status text NOT NULL DEFAULT 'pending',
  gateway_txn_id text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.pending_recharges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own recharges"
  ON public.pending_recharges
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Service role full access"
  ON public.pending_recharges
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);